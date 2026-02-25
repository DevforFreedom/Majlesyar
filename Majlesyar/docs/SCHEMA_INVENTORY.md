# Schema Inventory

This document lists every schema surface in the project.

## 1) Database Schemas (Django Models)

Source files:

- `backend/catalog/models.py`
- `backend/orders/models.py`
- `backend/site_settings/models.py`

Models:

- `catalog.Category`: `id`, `name`, `slug`, `icon`
- `catalog.Tag`: `id`, `name`, `slug`
- `catalog.Product`: `id`, `name`, `url_slug`, `description`, `price`, `event_types`, `contents`, `image`, `image_alt`, `image_name`, `featured`, `available`, `created_at`, `updated_at`, `categories`, `tags`
- `catalog.BuilderItem`: `id`, `name`, `group`, `price`, `required`, `image`
- `orders.Order`: `id`, `public_id`, `status`, `customer_name`, `customer_phone`, `customer_province`, `customer_address`, `customer_notes`, `delivery_date`, `delivery_window`, `payment_method`, `total`, `created_at`, `updated_at`
- `orders.OrderItem`: `id`, `order`, `product`, `name`, `quantity`, `price`, `is_custom_pack`, `custom_config`
- `orders.OrderNote`: `id`, `order`, `note`, `created_at`, `created_by`
- `site_settings.SiteSetting`: `id`, `min_order_qty`, `lead_time_hours`, `allowed_provinces`, `delivery_windows`, `payment_methods`, `updated_at`

## 2) API Request/Response Schemas (DRF Serializers)

Source files:

- `backend/catalog/serializers.py`
- `backend/orders/serializers.py`
- `backend/site_settings/serializers.py`

Serializer classes:

- `CategorySerializer`
- `TagSerializer`
- `ProductSerializer`
- `ProductWriteSerializer`
- `BuilderItemSerializer`
- `OrderNoteSerializer`
- `OrderItemSerializer`
- `OrderSerializer`
- `CustomerInputSerializer`
- `DeliveryInputSerializer`
- `OrderItemInputSerializer`
- `OrderCreateSerializer`
- `OrderStatusUpdateSerializer`
- `OrderNoteCreateSerializer`
- `SiteSettingSerializer`

## 3) OpenAPI Schema (Machine-Readable API Contract)

Routes:

- `GET /api/schema/` (raw OpenAPI)
- `GET /api/docs/` (Swagger UI)

Configured in:

- `backend/config/urls.py`
- `backend/config/settings.py` (`SPECTACULAR_SETTINGS`)

Generated export file:

- `backend/schema_openapi.yaml`

OpenAPI component schema names currently include:

- `BuilderItem`
- `Category`
- `CustomerInput`
- `DeliveryInput`
- `GroupEnum`
- `Order`
- `OrderCreate`
- `OrderItem`
- `OrderItemInput`
- `OrderNote`
- `OrderNoteCreate`
- `OrderStatusUpdate`
- `PatchedOrderStatusUpdate`
- `PatchedProductWrite`
- `Product`
- `ProductWrite`
- `SiteSetting`
- `StatusEnum`
- `Tag`
- `TokenObtainPair`
- `TokenRefresh`

## 4) Frontend Structured Data Schemas (SEO JSON-LD)

Source:

- `src/components/SEO.tsx`

Schema.org types used:

- `Organization`
- `ContactPoint`
- `PostalAddress`
- `FoodEstablishment`
- `GeoCoordinates`
- `OpeningHoursSpecification`
- `City`
- `State`
- `OfferCatalog`
- `Offer`
- `Service`
- `AggregateRating`
- `WebSite`
- `SearchAction`
- `Product`
- `Brand`
- `BreadcrumbList`
- `ListItem`
- `FAQPage`
- `Question`
- `Answer`

## 5) XML Schema Namespace Usage

- Sitemap XML namespace appears in `backend/config/site_views.py`:
  - `http://www.sitemaps.org/schemas/sitemap/0.9`

## 6) Frontend Tooling JSON Schema

- `components.json` uses:
  - `$schema: https://ui.shadcn.com/schema.json`

