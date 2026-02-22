from django.urls import path

from .views import (
    AdminProductDetailAPIView,
    AdminProductListCreateAPIView,
    BuilderItemListAPIView,
    CategoryListAPIView,
    ProductDetailAPIView,
    ProductListAPIView,
    TagListAPIView,
)

urlpatterns = [
    path("categories/", CategoryListAPIView.as_view(), name="category-list"),
    path("tags/", TagListAPIView.as_view(), name="tag-list"),
    path("products/", ProductListAPIView.as_view(), name="product-list"),
    path("products/<str:lookup>/", ProductDetailAPIView.as_view(), name="product-detail"),
    path("builder-items/", BuilderItemListAPIView.as_view(), name="builder-item-list"),
    path("admin/products/", AdminProductListCreateAPIView.as_view(), name="admin-product-list-create"),
    path("admin/products/<uuid:id>/", AdminProductDetailAPIView.as_view(), name="admin-product-detail"),
]
