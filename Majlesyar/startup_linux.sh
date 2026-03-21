#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="${APP_NAME:-majlesyar}"
IMAGE_NAME="${IMAGE_NAME:-${APP_NAME}:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-${APP_NAME}}"
HOST_PORT="${HOST_PORT:-80}"
APP_PORT="${APP_PORT:-8000}"
CPU_LIMIT="${CPU_LIMIT:-2.0}"
MEMORY_LIMIT="${MEMORY_LIMIT:-2g}"
MEMORY_SWAP_LIMIT="${MEMORY_SWAP_LIMIT:-2g}"
DOMAIN="${DOMAIN:-}"
PUBLIC_URL="${PUBLIC_URL:-}"
APT_USE_IRAN_MIRROR="${APT_USE_IRAN_MIRROR:-0}"
REPO_URL="${REPO_URL:-https://github.com/codeeefactory/Majlesyar.git}"
REPO_REF="${REPO_REF:-main}"
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-/opt/majlesyar-src}"
PROJECT_SUBDIR="${PROJECT_SUBDIR:-Majlesyar}"

ADMIN_USERNAME="${ADMIN_USERNAME:-}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

TLS_MODE="${TLS_MODE:-auto}"
CERTIFICATES_ZIP="${CERTIFICATES_ZIP:-}"
TLS_SERVER_NAME="${TLS_SERVER_NAME:-${DOMAIN}}"
CERT_INSTALL_DIR="${CERT_INSTALL_DIR:-/etc/ssl/${APP_NAME}}"
CERT_PFX_PASSWORD="${CERT_PFX_PASSWORD:-}"
NGINX_SITE_NAME="${NGINX_SITE_NAME:-${APP_NAME}}"
PROXY_HTTP_PORT="${PROXY_HTTP_PORT:-80}"
PROXY_HTTPS_PORT="${PROXY_HTTPS_PORT:-443}"
PUBLIC_SERVER_IP="${PUBLIC_SERVER_IP:-}"
APP_BIND_HOST="${APP_BIND_HOST:-}"
APP_UPSTREAM_HOST="${APP_UPSTREAM_HOST:-}"
APP_HOST_PORT="${APP_HOST_PORT:-18000}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR=""
ENV_FILE=""
DB_FILE=""
MEDIA_DIR=""
TLS_ACTIVE=0
FULLCHAIN_PATH=""
PRIVKEY_PATH=""

log() {
  printf '[startup] %s\n' "$*"
}

fail() {
  printf '[startup][error] %s\n' "$*" >&2
  exit 1
}

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "This step needs root privileges. Install sudo or run as root."
  fi
}

require_linux() {
  local os
  os="$(uname -s)"
  [[ "${os}" == "Linux" ]] || fail "This script must run on Linux (detected: ${os})."
}

set_runtime_paths() {
  DEPLOY_DIR="${ROOT_DIR}/.deploy"
  ENV_FILE="${DEPLOY_DIR}/.env.production"
  DB_FILE="${DEPLOY_DIR}/db.sqlite3"
  MEDIA_DIR="${DEPLOY_DIR}/media"

  if [[ -z "${CERTIFICATES_ZIP}" ]]; then
    CERTIFICATES_ZIP="${ROOT_DIR}/certificates.zip"
  fi
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    fail "git is required but apt-get is unavailable on this system."
  fi

  log "git not found. Installing git..."
  run_root apt-get update
  run_root apt-get install -y git ca-certificates
}

is_repo_layout() {
  [[ -f "${ROOT_DIR}/Dockerfile" && -d "${ROOT_DIR}/backend" ]]
}

bootstrap_repo_if_needed() {
  is_repo_layout && return

  [[ -n "${REPO_URL}" ]] || fail \
    "Dockerfile/backend not found in ${ROOT_DIR}. For first-boot startup usage set REPO_URL (and optionally PROJECT_SUBDIR/REPO_REF)."

  ensure_git
  log "Project files not found in script directory. Bootstrapping from ${REPO_URL} ..."

  run_root mkdir -p "$(dirname "${BOOTSTRAP_DIR}")"

  if [[ -d "${BOOTSTRAP_DIR}/.git" ]]; then
    run_root git -C "${BOOTSTRAP_DIR}" fetch --all --tags
    run_root git -C "${BOOTSTRAP_DIR}" checkout "${REPO_REF}"
    run_root git -C "${BOOTSTRAP_DIR}" pull --ff-only origin "${REPO_REF}"
  else
    run_root rm -rf "${BOOTSTRAP_DIR}"
    run_root git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${BOOTSTRAP_DIR}"
  fi

  local candidate_root="${BOOTSTRAP_DIR}"
  if [[ -n "${PROJECT_SUBDIR}" ]]; then
    candidate_root="${BOOTSTRAP_DIR}/${PROJECT_SUBDIR}"
  fi

  [[ -f "${candidate_root}/Dockerfile" ]] || fail \
    "Dockerfile not found after clone. Checked: ${candidate_root}/Dockerfile"
  [[ -d "${candidate_root}/backend" ]] || fail \
    "backend/ not found after clone. Checked: ${candidate_root}/backend"

  ROOT_DIR="${candidate_root}"
  log "Using project directory: ${ROOT_DIR}"
}

ensure_repo_layout() {
  bootstrap_repo_if_needed
  [[ -f "${ROOT_DIR}/Dockerfile" ]] || fail "Dockerfile not found in ${ROOT_DIR}."
  [[ -d "${ROOT_DIR}/backend" ]] || fail "backend/ not found in ${ROOT_DIR}."
}

configure_apt_iran_mirrors() {
  [[ "${APT_USE_IRAN_MIRROR}" == "1" ]] || {
    log "Skipping Iranian APT mirrors (APT_USE_IRAN_MIRROR=${APT_USE_IRAN_MIRROR})."
    return
  }

  if ! command -v apt-get >/dev/null 2>&1; then
    log "APT not found; skipping update."
    return
  fi

  log "Updating APT..."
  run_root apt-get update
}

ensure_packages() {
  local missing=()
  local pkg

  command -v apt-get >/dev/null 2>&1 || fail "apt-get is required to install missing packages on Debian/Ubuntu."

  for pkg in "$@"; do
    if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
      missing+=("${pkg}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    log "Installing packages: ${missing[*]}"
    run_root apt-get update
    run_root apt-get install -y "${missing[@]}"
  fi
}

resolve_tls_mode() {
  case "${TLS_MODE}" in
    auto)
      if [[ -f "${CERTIFICATES_ZIP}" ]]; then
        TLS_ACTIVE=1
      else
        TLS_ACTIVE=0
      fi
      ;;
    on|true|1)
      TLS_ACTIVE=1
      ;;
    off|false|0)
      TLS_ACTIVE=0
      ;;
    *)
      fail "Invalid TLS_MODE=${TLS_MODE}. Use auto, on, or off."
      ;;
  esac

  if (( TLS_ACTIVE )); then
    [[ -f "${CERTIFICATES_ZIP}" ]] || fail "TLS is enabled but certificates zip was not found: ${CERTIFICATES_ZIP}"
    [[ -n "${TLS_SERVER_NAME}" ]] || fail "TLS requires DOMAIN or TLS_SERVER_NAME to be set."
  fi
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1; then
    return
  fi

  log "Docker not found. Installing Docker Engine..."

  if ! command -v curl >/dev/null 2>&1; then
    run_root apt-get update
    run_root apt-get install -y curl
  fi

  if [[ "${EUID}" -eq 0 ]]; then
    sh -c "$(curl -fsSL https://get.docker.com)"
  else
    curl -fsSL https://get.docker.com | sudo sh
  fi

  if command -v systemctl >/dev/null 2>&1; then
    run_root systemctl enable --now docker
  fi
}

ensure_tls_dependencies() {
  ensure_packages unzip openssl nginx ca-certificates
}

extract_first_match() {
  local search_dir="$1"
  shift

  find "${search_dir}" -maxdepth 2 -type f \( "$@" \) | head -n 1 || true
}

install_certificates() {
  (( TLS_ACTIVE )) || return

  local work_dir
  local pfx_file
  local pem_file
  local key_file
  local leaf_cert
  local privkey_raw
  local privkey_clean
  local fullchain_source

  work_dir="$(mktemp -d)"
  trap 'rm -rf "${work_dir}"' RETURN

  log "Extracting certificates from ${CERTIFICATES_ZIP} ..."
  unzip -oq "${CERTIFICATES_ZIP}" -d "${work_dir}"

  pfx_file="$(extract_first_match "${work_dir}" -iname '*.pfx' -o -iname '*.p12')"
  pem_file="$(extract_first_match "${work_dir}" -iname '*.pem')"
  key_file="$(extract_first_match "${work_dir}" -iname '*.key' -o -iname '*privkey*.pem' -o -iname '*private*.pem')"

  leaf_cert="${work_dir}/leaf-cert.pem"
  privkey_raw="${work_dir}/privkey-raw.pem"
  privkey_clean="${work_dir}/privkey.pem"

  if [[ -n "${pfx_file}" ]]; then
    [[ -n "${CERT_PFX_PASSWORD}" ]] || fail "Found ${pfx_file}, but CERT_PFX_PASSWORD is empty. Set it before running the script."

    log "Extracting certificate and private key from PFX bundle..."
    openssl pkcs12 -in "${pfx_file}" -clcerts -nokeys -passin "pass:${CERT_PFX_PASSWORD}" -out "${leaf_cert}"
    openssl pkcs12 -in "${pfx_file}" -nocerts -nodes -passin "pass:${CERT_PFX_PASSWORD}" -out "${privkey_raw}"
    awk '/-----BEGIN .*PRIVATE KEY-----/,/-----END .*PRIVATE KEY-----/' "${privkey_raw}" > "${privkey_clean}"

    if [[ ! -s "${privkey_clean}" ]]; then
      fail "Could not extract a private key from ${pfx_file}."
    fi

    if [[ -n "${pem_file}" ]]; then
      fullchain_source="${pem_file}"
    else
      awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' "${leaf_cert}" > "${leaf_cert}.clean"
      fullchain_source="${leaf_cert}.clean"
    fi

    key_file="${privkey_clean}"
  fi

  [[ -n "${pem_file:-}" || -n "${fullchain_source:-}" ]] || fail "No PEM certificate was found in ${CERTIFICATES_ZIP}."
  [[ -n "${key_file:-}" ]] || fail "No private key was found. Provide a PFX bundle or a PEM key file in ${CERTIFICATES_ZIP}."

  if [[ -z "${fullchain_source:-}" ]]; then
    fullchain_source="${pem_file}"
  fi

  FULLCHAIN_PATH="${CERT_INSTALL_DIR}/fullchain.pem"
  PRIVKEY_PATH="${CERT_INSTALL_DIR}/privkey.pem"

  run_root install -d -m 755 "${CERT_INSTALL_DIR}"
  run_root install -m 644 "${fullchain_source}" "${FULLCHAIN_PATH}"
  run_root install -m 600 "${key_file}" "${PRIVKEY_PATH}"

  log "Installed certificate chain to ${FULLCHAIN_PATH}"
  log "Installed private key to ${PRIVKEY_PATH}"
}

generate_secret_key() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 48
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(64))
PY
    return
  fi

  fail "Cannot generate DJANGO_SECRET_KEY automatically (need openssl or python3)."
}

build_allowed_hosts() {
  local ip host_list
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  host_list="localhost,127.0.0.1"

  if [[ -n "${ip}" ]]; then
    host_list="${host_list},${ip}"
  fi
  if [[ -n "${DOMAIN}" ]]; then
    host_list="${host_list},${DOMAIN}"
  fi
  if [[ -n "${TLS_SERVER_NAME}" && "${TLS_SERVER_NAME}" != "${DOMAIN}" ]]; then
    host_list="${host_list},${TLS_SERVER_NAME}"
  fi

  printf '%s' "${host_list}"
}

build_public_url() {
  if [[ -n "${PUBLIC_URL}" ]]; then
    printf '%s' "${PUBLIC_URL}"
    return
  fi

  if (( TLS_ACTIVE )); then
    printf 'https://%s' "${TLS_SERVER_NAME}"
    return
  fi

  if [[ -n "${DOMAIN}" ]]; then
    printf 'https://%s' "${DOMAIN}"
    return
  fi

  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -n "${ip}" ]]; then
    printf 'http://%s:%s' "${ip}" "${HOST_PORT}"
  else
    printf 'http://localhost:%s' "${HOST_PORT}"
  fi
}

write_env_file() {
  mkdir -p "${DEPLOY_DIR}" "${MEDIA_DIR}"
  touch "${DB_FILE}"

  local secret_key allowed_hosts public_url
  secret_key="${DJANGO_SECRET_KEY:-$(generate_secret_key)}"
  allowed_hosts="$(build_allowed_hosts)"
  public_url="$(build_public_url)"

  umask 077
  cat > "${ENV_FILE}" <<EOF_ENV
PORT=${APP_PORT}
DJANGO_DEBUG=0
DJANGO_SECRET_KEY=${secret_key}
DJANGO_ALLOWED_HOSTS=${allowed_hosts}
CORS_ALLOWED_ORIGINS=${public_url}
CSRF_TRUSTED_ORIGINS=${public_url}
EOF_ENV
  umask 022
}

detect_server_ip() {
  if [[ -n "${PUBLIC_SERVER_IP}" ]]; then
    printf '%s' "${PUBLIC_SERVER_IP}"
    return
  fi

  local ip
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
  if [[ -n "${ip}" ]]; then
    printf '%s' "${ip}"
    return
  fi

  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -n "${ip}" ]]; then
    printf '%s' "${ip}"
  fi
}

configure_bind_hosts() {
  local detected_ip
  detected_ip="$(detect_server_ip)"

  if [[ -z "${APP_BIND_HOST}" ]]; then
    APP_BIND_HOST="${detected_ip:-0.0.0.0}"
  fi

  if [[ -z "${APP_UPSTREAM_HOST}" ]]; then
    if [[ "${APP_BIND_HOST}" == "0.0.0.0" ]]; then
      APP_UPSTREAM_HOST="${detected_ip:-127.0.0.1}"
    else
      APP_UPSTREAM_HOST="${APP_BIND_HOST}"
    fi
  fi
}

build_image() {
  log "Building image ${IMAGE_NAME} ..."
  docker build -t "${IMAGE_NAME}" "${ROOT_DIR}"
}

start_container() {
  local port_args=()

  if (( TLS_ACTIVE )); then
    port_args=(-p "${APP_BIND_HOST}:${APP_HOST_PORT}:${APP_PORT}")
  else
    port_args=(-p "${HOST_PORT}:${APP_PORT}")
  fi

  log "Starting container ${CONTAINER_NAME} ..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    --cpus "${CPU_LIMIT}" \
    --memory "${MEMORY_LIMIT}" \
    --memory-swap "${MEMORY_SWAP_LIMIT}" \
    --env-file "${ENV_FILE}" \
    "${port_args[@]}" \
    -v "${DB_FILE}:/app/db.sqlite3" \
    -v "${MEDIA_DIR}:/app/media" \
    "${IMAGE_NAME}" >/dev/null
}

write_nginx_config() {
  (( TLS_ACTIVE )) || return

  local nginx_conf_tmp
  local nginx_conf_target

  nginx_conf_tmp="$(mktemp)"
  nginx_conf_target="/etc/nginx/sites-available/${NGINX_SITE_NAME}.conf"

  cat > "${nginx_conf_tmp}" <<EOF_NGINX
server {
    listen ${PROXY_HTTP_PORT};
    listen [::]:${PROXY_HTTP_PORT};
    server_name ${TLS_SERVER_NAME};

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen ${PROXY_HTTPS_PORT} ssl http2;
    listen [::]:${PROXY_HTTPS_PORT} ssl http2;
    server_name ${TLS_SERVER_NAME};

    ssl_certificate ${FULLCHAIN_PATH};
    ssl_certificate_key ${PRIVKEY_PATH};
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    client_max_body_size 50m;

    location / {
        proxy_pass http://${APP_UPSTREAM_HOST}:${APP_HOST_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
    }
}
EOF_NGINX

  run_root install -m 644 "${nginx_conf_tmp}" "${nginx_conf_target}"
  run_root ln -sfn "${nginx_conf_target}" "/etc/nginx/sites-enabled/${NGINX_SITE_NAME}.conf"
  run_root rm -f /etc/nginx/sites-enabled/default
  run_root nginx -t
  run_root systemctl enable --now nginx
  run_root systemctl reload nginx

  rm -f "${nginx_conf_tmp}"
}

create_superuser_if_requested() {
  if [[ -z "${ADMIN_USERNAME}" || -z "${ADMIN_PASSWORD}" ]]; then
    log "Skipping superuser creation (set ADMIN_USERNAME and ADMIN_PASSWORD to enable)."
    return
  fi

  log "Creating/updating Django superuser ${ADMIN_USERNAME} ..."
  docker exec \
    -e DJANGO_SUPERUSER_USERNAME="${ADMIN_USERNAME}" \
    -e DJANGO_SUPERUSER_EMAIL="${ADMIN_EMAIL}" \
    -e DJANGO_SUPERUSER_PASSWORD="${ADMIN_PASSWORD}" \
    "${CONTAINER_NAME}" \
    python manage.py createsuperuser --noinput || true
}

print_result() {
  local public_url
  public_url="$(build_public_url)"

  log "Deployment complete."
  log "Container: ${CONTAINER_NAME}"
  log "URL: ${public_url}"
  log "Admin: ${public_url}/admin/"
  log "Swagger: ${public_url}/api/docs/"
  log "Logs: docker logs -f ${CONTAINER_NAME}"

  if (( TLS_ACTIVE )); then
    log "Nginx site: /etc/nginx/sites-available/${NGINX_SITE_NAME}.conf"
    log "Certificate chain: ${FULLCHAIN_PATH}"
    log "Private key: ${PRIVKEY_PATH}"
    log "App listener: http://${APP_BIND_HOST}:${APP_HOST_PORT}"
    log "Nginx upstream: http://${APP_UPSTREAM_HOST}:${APP_HOST_PORT}"
  fi
}

main() {
  require_linux
  configure_apt_iran_mirrors
  ensure_repo_layout
  set_runtime_paths
  resolve_tls_mode
  configure_bind_hosts

  if (( TLS_ACTIVE )); then
    ensure_tls_dependencies
    install_certificates
  fi

  ensure_docker
  write_env_file
  build_image
  start_container

  if (( TLS_ACTIVE )); then
    write_nginx_config
  fi

  create_superuser_if_requested
  print_result
}

main "$@"
