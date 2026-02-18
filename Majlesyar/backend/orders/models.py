from django.db import models
import uuid
from django.contrib.auth import get_user_model
from django.core.validators import MinValueValidator

from catalog.models import Product


User = get_user_model()


def generate_order_public_id() -> str:
    return f"ORD-{uuid.uuid4().hex[:8].upper()}"


class Order(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "در انتظار"
        CONFIRMED = "confirmed", "تایید شده"
        PREPARING = "preparing", "در حال آماده سازی"
        SHIPPED = "shipped", "ارسال شده"
        DELIVERED = "delivered", "تحویل شده"

    public_id = models.CharField(
        max_length=20,
        unique=True,
        db_index=True,
        verbose_name="کد سفارش",
        help_text="نکته: کد یکتای سفارش به صورت خودکار تولید می شود.",
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        verbose_name="وضعیت سفارش",
        help_text="نکته: وضعیت جاری سفارش را مشخص می کند.",
    )

    customer_name = models.CharField(
        max_length=255,
        verbose_name="نام مشتری",
        help_text="نکته: نام و نام خانوادگی گیرنده سفارش.",
    )
    customer_phone = models.CharField(
        max_length=32,
        verbose_name="شماره موبایل",
        help_text="نکته: شماره تماس معتبر مشتری (فرمت 09xxxxxxxxx).",
    )
    customer_province = models.CharField(
        max_length=128,
        verbose_name="استان",
        help_text="نکته: استان مقصد برای تحویل سفارش.",
    )
    customer_address = models.TextField(
        verbose_name="آدرس تحویل",
        help_text="نکته: آدرس کامل و دقیق برای ارسال سفارش.",
    )
    customer_notes = models.TextField(
        blank=True,
        verbose_name="یادداشت مشتری",
        help_text="نکته: توضیحات تکمیلی مشتری (اختیاری).",
    )

    delivery_date = models.DateField(
        verbose_name="تاریخ تحویل",
        help_text="نکته: تاریخ تحویل سفارش.",
    )
    delivery_window = models.CharField(
        max_length=64,
        verbose_name="بازه زمانی تحویل",
        help_text="نکته: بازه زمانی انتخابی برای تحویل.",
    )

    payment_method = models.CharField(
        max_length=64,
        verbose_name="روش پرداخت",
        help_text="نکته: روش پرداخت انتخاب شده توسط مشتری.",
    )
    total = models.PositiveIntegerField(
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name="مبلغ کل (تومان)",
        help_text="نکته: مجموع نهایی سفارش به تومان.",
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name="زمان ثبت",
        help_text="نکته: زمان ثبت سفارش به صورت خودکار.",
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name="آخرین بروزرسانی",
        help_text="نکته: زمان آخرین ویرایش سفارش به صورت خودکار.",
    )

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "سفارش"
        verbose_name_plural = "سفارش ها"

    def save(self, *args, **kwargs):
        if not self.public_id:
            while True:
                candidate = generate_order_public_id()
                if not Order.objects.filter(public_id=candidate).exists():
                    self.public_id = candidate
                    break
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return self.public_id


class OrderItem(models.Model):
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        verbose_name="شناسه",
        help_text="نکته: این شناسه به صورت خودکار ساخته می شود.",
    )
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="items",
        verbose_name="سفارش",
        help_text="نکته: سفارشی که این آیتم به آن تعلق دارد.",
    )
    product = models.ForeignKey(
        Product,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        verbose_name="محصول مرجع",
        help_text="نکته: در صورت انتخاب محصول آماده، این فیلد پر می شود.",
    )
    name = models.CharField(
        max_length=255,
        verbose_name="نام آیتم",
        help_text="نکته: نام نمایشی آیتم سفارش.",
    )
    quantity = models.PositiveIntegerField(
        validators=[MinValueValidator(1)],
        verbose_name="تعداد",
        help_text="نکته: تعداد این آیتم در سفارش.",
    )
    price = models.PositiveIntegerField(
        validators=[MinValueValidator(0)],
        verbose_name="قیمت واحد (تومان)",
        help_text="نکته: قیمت هر واحد آیتم به تومان.",
    )
    is_custom_pack = models.BooleanField(
        default=False,
        verbose_name="پک سفارشی",
        help_text="نکته: اگر فعال باشد آیتم از نوع پک سفارشی است.",
    )
    custom_config = models.JSONField(
        default=dict,
        blank=True,
        null=True,
        verbose_name="پیکربندی سفارشی",
        help_text="نکته: جزییات ترکیب پک سفارشی به صورت JSON.",
    )

    class Meta:
        verbose_name = "آیتم سفارش"
        verbose_name_plural = "آیتم های سفارش"

    def __str__(self) -> str:
        return f"{self.name} x {self.quantity}"


class OrderNote(models.Model):
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        verbose_name="شناسه",
        help_text="نکته: این شناسه به صورت خودکار ساخته می شود.",
    )
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="notes",
        verbose_name="سفارش",
        help_text="نکته: سفارشی که این یادداشت برای آن ثبت شده است.",
    )
    note = models.TextField(
        verbose_name="متن یادداشت",
        help_text="نکته: توضیحات داخلی مربوط به سفارش را ثبت کنید.",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name="زمان ثبت یادداشت",
        help_text="نکته: زمان ثبت این یادداشت به صورت خودکار.",
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="order_notes",
        verbose_name="ثبت کننده",
        help_text="نکته: کاربری که این یادداشت را ثبت کرده است.",
    )

    class Meta:
        ordering = ["created_at"]
        verbose_name = "یادداشت سفارش"
        verbose_name_plural = "یادداشت های سفارش"

    def __str__(self) -> str:
        return f"یادداشت سفارش {self.order.public_id}"
