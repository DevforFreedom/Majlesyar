--- /mnt/data/startup_linux_with_tls.sh	2026-03-21 11:07:27.450071590 +0000
+++ /mnt/data/startup_linux_with_apache_tls.sh	2026-03-21 11:09:09.470521990 +0000
@@ -26,7 +26,7 @@
 TLS_SERVER_NAME="${TLS_SERVER_NAME:-${DOMAIN}}"
 CERT_INSTALL_DIR="${CERT_INSTALL_DIR:-/etc/ssl/${APP_NAME}}"
 CERT_PFX_PASSWORD="${CERT_PFX_PASSWORD:-}"
-NGINX_SITE_NAME="${NGINX_SITE_NAME:-${APP_NAME}}"
+APACHE_SITE_NAME="${APACHE_SITE_NAME:-${APP_NAME}}"
 PROXY_HTTP_PORT="${PROXY_HTTP_PORT:-80}"
 PROXY_HTTPS_PORT="${PROXY_HTTPS_PORT:-443}"
 APP_BIND_HOST="${APP_BIND_HOST:-127.0.0.1}"
@@ -219,7 +219,7 @@
 }
 
 ensure_tls_dependencies() {
-  ensure_packages unzip openssl nginx ca-certificates
+  ensure_packages unzip openssl apache2 ca-certificates
 }
 
 extract_first_match() {
@@ -406,62 +406,90 @@
     "${IMAGE_NAME}" >/dev/null
 }
 
-write_nginx_config() {
-  (( TLS_ACTIVE )) || return
+apache_server_aliases() {
+  local aliases=()
+
+  if [[ -n "${DOMAIN}" && "${DOMAIN}" != "${TLS_SERVER_NAME}" ]]; then
+    aliases+=("${DOMAIN}")
+  fi
+
+  if [[ -n "${DOMAIN}" && "www.${DOMAIN}" != "${TLS_SERVER_NAME}" ]]; then
+    aliases+=("www.${DOMAIN}")
+  fi
+
+  if (( ${#aliases[@]} > 0 )); then
+    printf 'ServerAlias %s\n' "${aliases[*]}"
+  fi
+}
 
-  local nginx_conf_tmp
-  local nginx_conf_target
+disable_nginx_if_present() {
+  if ! command -v systemctl >/dev/null 2>&1; then
+    return
+  fi
+
+  if systemctl list-unit-files nginx.service >/dev/null 2>&1; then
+    if systemctl is-active --quiet nginx; then
+      log "Stopping nginx so Apache can bind ports ${PROXY_HTTP_PORT}/${PROXY_HTTPS_PORT} ..."
+      run_root systemctl stop nginx
+    fi
+    if systemctl is-enabled --quiet nginx; then
+      run_root systemctl disable nginx || true
+    fi
+  fi
+}
 
-  nginx_conf_tmp="$(mktemp)"
-  nginx_conf_target="/etc/nginx/sites-available/${NGINX_SITE_NAME}.conf"
+write_apache_config() {
+  (( TLS_ACTIVE )) || return
 
-  cat > "${nginx_conf_tmp}" <<EOF_NGINX
-server {
-    listen ${PROXY_HTTP_PORT};
-    listen [::]:${PROXY_HTTP_PORT};
-    server_name ${TLS_SERVER_NAME};
-
-    location / {
-        return 301 https://\$host\$request_uri;
-    }
-}
-
-server {
-    listen ${PROXY_HTTPS_PORT} ssl http2;
-    listen [::]:${PROXY_HTTPS_PORT} ssl http2;
-    server_name ${TLS_SERVER_NAME};
-
-    ssl_certificate ${FULLCHAIN_PATH};
-    ssl_certificate_key ${PRIVKEY_PATH};
-    ssl_session_timeout 1d;
-    ssl_session_cache shared:SSL:10m;
-    ssl_protocols TLSv1.2 TLSv1.3;
-    ssl_prefer_server_ciphers off;
-
-    client_max_body_size 50m;
-
-    location / {
-        proxy_pass http://${APP_BIND_HOST}:${APP_HOST_PORT};
-        proxy_http_version 1.1;
-        proxy_set_header Host \$host;
-        proxy_set_header X-Real-IP \$remote_addr;
-        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
-        proxy_set_header X-Forwarded-Proto https;
-        proxy_set_header X-Forwarded-Host \$host;
-        proxy_set_header Upgrade \$http_upgrade;
-        proxy_set_header Connection \"upgrade\";
-    }
-}
-EOF_NGINX
-
-  run_root install -m 644 "${nginx_conf_tmp}" "${nginx_conf_target}"
-  run_root ln -sfn "${nginx_conf_target}" "/etc/nginx/sites-enabled/${NGINX_SITE_NAME}.conf"
-  run_root rm -f /etc/nginx/sites-enabled/default
-  run_root nginx -t
-  run_root systemctl enable --now nginx
-  run_root systemctl reload nginx
+  local apache_conf_tmp
+  local apache_conf_target
+  local server_alias_line
+
+  apache_conf_tmp="$(mktemp)"
+  apache_conf_target="/etc/apache2/sites-available/${APACHE_SITE_NAME}.conf"
+  server_alias_line="$(apache_server_aliases)"
+
+  cat > "${apache_conf_tmp}" <<EOF_APACHE
+<VirtualHost *:${PROXY_HTTP_PORT}>
+    ServerName ${TLS_SERVER_NAME}
+    ${server_alias_line}
+
+    RewriteEngine On
+    RewriteRule ^/(.*)$ https://%{HTTP_HOST}/\$1 [R=301,L]
+</VirtualHost>
+
+<VirtualHost *:${PROXY_HTTPS_PORT}>
+    ServerName ${TLS_SERVER_NAME}
+    ${server_alias_line}
+
+    SSLEngine on
+    SSLCertificateFile ${FULLCHAIN_PATH}
+    SSLCertificateKeyFile ${PRIVKEY_PATH}
+
+    ProxyPreserveHost On
+    ProxyRequests Off
+    SSLProxyEngine Off
+
+    RequestHeader set X-Forwarded-Proto "https"
+    RequestHeader set X-Forwarded-Port "${PROXY_HTTPS_PORT}"
+    RequestHeader set X-Forwarded-Host "%{Host}i"
+
+    ProxyPass / http://${APP_UPSTREAM_HOST}:${APP_HOST_PORT}/ connectiontimeout=5 timeout=60 keepalive=On
+    ProxyPassReverse / http://${APP_UPSTREAM_HOST}:${APP_HOST_PORT}/
+</VirtualHost>
+EOF_APACHE
+
+  disable_nginx_if_present
+  run_root a2enmod ssl proxy proxy_http headers rewrite
+  run_root a2dissite 000-default.conf >/dev/null 2>&1 || true
+  run_root a2dissite default-ssl.conf >/dev/null 2>&1 || true
+  run_root install -m 644 "${apache_conf_tmp}" "${apache_conf_target}"
+  run_root a2ensite "${APACHE_SITE_NAME}.conf"
+  run_root apache2ctl configtest
+  run_root systemctl enable --now apache2
+  run_root systemctl reload apache2
 
-  rm -f "${nginx_conf_tmp}"
+  rm -f "${apache_conf_tmp}"
 }
 
 create_superuser_if_requested() {
@@ -491,10 +519,10 @@
   log "Logs: docker logs -f ${CONTAINER_NAME}"
 
   if (( TLS_ACTIVE )); then
-    log "Nginx site: /etc/nginx/sites-available/${NGINX_SITE_NAME}.conf"
+    log "Apache site: /etc/apache2/sites-available/${APACHE_SITE_NAME}.conf"
     log "Certificate chain: ${FULLCHAIN_PATH}"
     log "Private key: ${PRIVKEY_PATH}"
-    log "App is published internally at http://${APP_BIND_HOST}:${APP_HOST_PORT}"
+    log "App upstream target: http://${APP_UPSTREAM_HOST}:${APP_HOST_PORT}"
   fi
 }
 
@@ -516,7 +544,7 @@
   start_container
 
   if (( TLS_ACTIVE )); then
-    write_nginx_config
+    write_apache_config
   fi
 
   create_superuser_if_requested
