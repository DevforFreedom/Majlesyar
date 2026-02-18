from django.db import models
from django.core.validators import MinValueValidator


class SiteSetting(models.Model):
    """
    مدل تک رکوردی برای تنظیمات سراسری فروشگاه.
    همیشه با کلید اصلی 1 ذخیره می شود.
    """

    id = models.PositiveSmallIntegerField(
        primary_key=True,
        default=1,
        editable=False,
        verbose_name="شناسه",
        help_text="نکته: تنظیمات سایت فقط یک رکورد دارد و شناسه آن همواره 1 است.",
    )
    min_order_qty = models.PositiveIntegerField(
        default=40,
        validators=[MinValueValidator(1)],
        verbose_name="حداقل تعداد سفارش",
        help_text="نکته: مشتری باید حداقل این تعداد را برای ثبت سفارش وارد کند.",
    )
    lead_time_hours = models.PositiveIntegerField(
        default=48,
        validators=[MinValueValidator(0)],
        verbose_name="حداقل زمان آماده سازی (ساعت)",
        help_text="نکته: فاصله زمانی لازم از ثبت سفارش تا زمان تحویل.",
    )
    allowed_provinces = models.JSONField(
        default=list,
        blank=True,
        verbose_name="استان های مجاز",
        help_text="نکته: استان های قابل ارسال را به صورت لیست JSON وارد کنید.",
    )
    delivery_windows = models.JSONField(
        default=list,
        blank=True,
        verbose_name="بازه های تحویل",
        help_text="نکته: بازه های زمانی تحویل را به صورت لیست JSON وارد کنید.",
    )
    payment_methods = models.JSONField(
        default=list,
        blank=True,
        verbose_name="روش های پرداخت",
        help_text="نکته: روش های پرداخت فعال/غیرفعال را به صورت JSON تنظیم کنید.",
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name="آخرین بروزرسانی",
        help_text="نکته: زمان آخرین بروزرسانی این تنظیمات.",
    )

    class Meta:
        verbose_name = "تنظیمات سایت"
        verbose_name_plural = "تنظیمات سایت"

    def save(self, *args, **kwargs):
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def load(cls) -> "SiteSetting":
        instance, _ = cls.objects.get_or_create(pk=1)
        return instance

    def __str__(self) -> str:
        return "تنظیمات سراسری سایت"
