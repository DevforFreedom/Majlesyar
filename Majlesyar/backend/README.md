# Backend (Django + DRF)

This backend powers catalog data, site settings, checkout/order creation, order tracking, and admin order operations.

## Stack

- Django
- Django REST Framework
- django-unfold (admin theme)
- django-cors-headers
- djangorestframework-simplejwt
- drf-spectacular (OpenAPI + Swagger)
- SQLite by default (optional Postgres)

## Quick Start (Windows)

From repository root:

```powershell
py -m venv backend/.venv
backend\.venv\Scripts\python -m pip install -r backend\requirements.txt
cd backend
..\backend\.venv\Scripts\python manage.py migrate
..\backend\.venv\Scripts\python manage.py seed_initial_data
..\backend\.venv\Scripts\python manage.py createsuperuser
..\backend\.venv\Scripts\python manage.py runserver
```

Server: `http://localhost:8000`

## Key URLs

- Admin: `http://localhost:8000/admin/`
- Swagger: `http://localhost:8000/api/docs/`
- OpenAPI schema: `http://localhost:8000/api/schema/`
- API base: `http://localhost:8000/api/v1/`

## Product Images

- Product image upload is supported in:
  - `POST /api/v1/admin/products/`
  - `PATCH /api/v1/admin/products/{id}/`
- Use `multipart/form-data` and send the file in `image_file`.
- Validation:
  - Must be a valid image
  - Max size: 5MB
- Files are served under `/media/...` (toggle with `SERVE_MEDIA=1|0`).

## Admin CSRF on Production

If admin login returns `403 CSRF verification failed` on hosted domains, set:

- `CSRF_TRUSTED_ORIGINS` (comma-separated, with scheme), e.g.
  - `https://packetop.runflare.run,https://your-domain.com`
- `DJANGO_ALLOWED_HOSTS` to include your domain(s).

This project also enables reverse-proxy headers by default:

- `USE_X_FORWARDED_HOST=1`
- `SECURE_PROXY_SSL_HEADER=('HTTP_X_FORWARDED_PROTO','https')`

In addition, CSRF middleware is proxy-aware and domain-agnostic:

- It accepts requests when `Origin` matches `Host`/`X-Forwarded-Host`.
- This avoids hardcoding one fixed domain when your host/domain changes.

## Seed Data

Initial data lives in:

- `backend/seed/initial_data.json`

Seed command:

```powershell
cd backend
..\backend\.venv\Scripts\python manage.py seed_initial_data
```

## Optional Postgres via Docker Compose

From repository root:

```powershell
docker compose --profile postgres up --build
```

If you want backend to use Postgres in Compose, set:

```powershell
$env:USE_POSTGRES="1"
docker compose --profile postgres up --build
```
