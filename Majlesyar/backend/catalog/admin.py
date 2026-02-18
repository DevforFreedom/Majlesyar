from django.contrib import admin

from config.admin_mixins import PersianAdminFormMixin
from .models import BuilderItem, Category, Product


@admin.register(Category)
class CategoryAdmin(PersianAdminFormMixin, admin.ModelAdmin):
    list_display = ("name", "slug", "icon")
    search_fields = ("name", "slug")
    prepopulated_fields = {"slug": ("name",)}
    fieldsets = (
        (
            "اطلاعات دسته بندی",
            {
                "description": "راهنما: همه فیلدها را به فارسی/استاندارد وارد کنید. نکته: اسلاگ باید یکتا باشد.",
                "fields": ("name", "slug", "icon"),
            },
        ),
    )


@admin.register(Product)
class ProductAdmin(PersianAdminFormMixin, admin.ModelAdmin):
    list_display = ("name", "price", "available", "featured", "updated_at")
    list_filter = ("available", "featured", "categories")
    search_fields = ("name", "description", "contents")
    autocomplete_fields = ("categories",)
    list_editable = ("available", "featured")
    readonly_fields = ("created_at", "updated_at")
    fieldsets = (
        (
            "اطلاعات اصلی",
            {
                "description": "راهنما: نام و توضیحات محصول را واضح وارد کنید.",
                "fields": ("name", "description", "image"),
            },
        ),
        (
            "قیمت و وضعیت",
            {
                "description": "نکته: قیمت به تومان است. برای توافقی خالی بگذارید.",
                "fields": ("price", "available", "featured"),
            },
        ),
        (
            "دسته بندی و محتوا",
            {
                "description": "راهنما: دسته بندی ها، نوع مراسم و اقلام داخل پک را کامل ثبت کنید.",
                "fields": ("categories", "event_types", "contents"),
            },
        ),
        (
            "زمان بندی",
            {
                "description": "نکته: این فیلدها به صورت خودکار مدیریت می شوند.",
                "fields": ("created_at", "updated_at"),
            },
        ),
    )


@admin.register(BuilderItem)
class BuilderItemAdmin(PersianAdminFormMixin, admin.ModelAdmin):
    list_display = ("name", "group", "price", "required")
    list_filter = ("group", "required")
    search_fields = ("name",)
    fieldsets = (
        (
            "اطلاعات آیتم",
            {
                "description": "راهنما: این آیتم ها برای ساخت پک سفارشی استفاده می شوند.",
                "fields": ("name", "group", "price", "required", "image"),
            },
        ),
    )
