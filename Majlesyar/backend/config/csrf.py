from __future__ import annotations

from urllib.parse import urlsplit

from django.conf import settings
from django.core.exceptions import DisallowedHost
from django.middleware.csrf import CsrfViewMiddleware, RejectRequest
from django.utils.http import is_same_domain


class ProxyAwareCsrfViewMiddleware(CsrfViewMiddleware):
    """
    Keep normal Django CSRF behavior, but add a proxy-aware fallback:
    if Origin host matches Host/X-Forwarded-Host, treat it as same-origin.
    This prevents domain-change breakage behind reverse proxies without disabling CSRF.
    """

    def _candidate_hosts(self, request) -> set[str]:
        hosts: set[str] = set()

        for header in (
            "HTTP_X_FORWARDED_HOST",
            "HTTP_HOST",
            "HTTP_X_ORIGINAL_HOST",
            "HTTP_X_REAL_HOST",
            "HTTP_X_FORWARDED_SERVER",
        ):
            raw = request.META.get(header, "")
            if not raw:
                continue
            for part in raw.split(","):
                host = part.strip().lower()
                if not host:
                    continue
                hosts.add(host)
                hosts.add(host.split(":")[0])

        forwarded = request.META.get("HTTP_FORWARDED", "")
        if forwarded:
            for item in forwarded.split(","):
                for pair in item.split(";"):
                    bits = pair.split("=", 1)
                    if len(bits) != 2:
                        continue
                    key = bits[0].strip().lower()
                    value = bits[1].strip().strip('"').lower()
                    if key != "host" or not value:
                        continue
                    hosts.add(value)
                    hosts.add(value.split(":")[0])

        server_name = request.META.get("SERVER_NAME", "").strip().lower()
        if server_name:
            hosts.add(server_name)
            server_port = request.META.get("SERVER_PORT", "").strip()
            if server_port and server_port not in {"80", "443"}:
                hosts.add(f"{server_name}:{server_port}")

        try:
            app_host = request.get_host().lower()
        except DisallowedHost:
            app_host = ""
        if app_host:
            hosts.add(app_host)
            hosts.add(app_host.split(":")[0])

        forwarded_port = request.META.get("HTTP_X_FORWARDED_PORT", "").split(",")[0].strip()
        if forwarded_port and forwarded_port not in {"80", "443"}:
            for host in list(hosts):
                hosts.add(f"{host.split(':')[0]}:{forwarded_port}")

        return hosts

    def _origin_verified(self, request) -> bool:
        if super()._origin_verified(request):
            return True

        origin = request.META.get("HTTP_ORIGIN", "")
        if not origin:
            return False

        try:
            parsed = urlsplit(origin)
        except ValueError:
            return False

        if not parsed.netloc:
            return False

        forwarded_proto = request.META.get("HTTP_X_FORWARDED_PROTO", "").split(",")[0].strip().lower()
        is_secure = request.is_secure() or forwarded_proto == "https"
        if is_secure and parsed.scheme != "https":
            return False

        return any(is_same_domain(parsed.netloc.lower(), host) for host in self._candidate_hosts(request))

    def _check_referer(self, request) -> None:
        try:
            super()._check_referer(request)
            return
        except RejectRequest as original_error:
            referer = request.META.get("HTTP_REFERER")
            if not referer:
                # Some proxies/browsers omit Referer on same-origin form POSTs.
                # Allow token validation to decide in this case.
                if getattr(settings, "CSRF_PROXY_ALLOW_MISSING_REFERER", True):
                    return
                raise original_error

            try:
                parsed = urlsplit(referer)
            except ValueError:
                raise original_error

            if "" in (parsed.scheme, parsed.netloc):
                raise original_error

            if parsed.scheme != "https":
                raise original_error

            if any(is_same_domain(parsed.netloc.lower(), host) for host in self._candidate_hosts(request)):
                return

            raise original_error
