from django.contrib import admin

from config.admin_mixins import PersianAdminFormMixin
from .models import SiteSetting


@admin.register(SiteSetting)
class SiteSettingAdmin(PersianAdminFormMixin, admin.ModelAdmin):
    list_display = ("min_order_qty", "lead_time_hours", "updated_at")
    readonly_fields = ("updated_at",)
    fieldsets = (
        (
            "قوانین سفارش",
            {
                "description": "راهنما: حداقل تعداد و زمان آماده سازی سفارش را تنظیم کنید.",
                "fields": ("min_order_qty", "lead_time_hours"),
            },
        ),
        (
            "تنظیمات ارسال",
            {
                "description": "نکته: مقادیر را به صورت JSON معتبر وارد کنید.",
                "fields": ("allowed_provinces", "delivery_windows"),
            },
        ),
        (
            "تنظیمات پرداخت",
            {
                "description": "راهنما: روش های پرداخت را با وضعیت فعال/غیرفعال ثبت کنید.",
                "fields": ("payment_methods", "updated_at"),
            },
        ),
    )

    def has_add_permission(self, request):
        if SiteSetting.objects.exists():
            return False
        return super().has_add_permission(request)
