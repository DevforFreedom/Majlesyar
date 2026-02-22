from __future__ import annotations

from django import forms
from django.db import models


class PersianAdminFormMixin:
    """
    Add consistent Persian hints/notes and ensure field widgets are visible/readable.
    """

    class Media:
        css = {"all": ("admin/css/persian-admin-overrides.css",)}
        js = ("admin/js/clear-image-input.js",)

    placeholder_map = {
        "name": "نام را وارد کنید",
        "slug": "نمونه: economic-pack",
        "url_slug": "نمونه: vip-pack",
        "description": "توضیحات را وارد کنید",
        "event_types": 'مثال: ["conference", "memorial"]',
        "contents": 'مثال: ["آب معدنی", "میوه", "شیرینی"]',
        "image_name": "مثال: pak-terhim-luxury",
        "image_alt": "مثال: پک ترحیم کامل با بطری آب و میوه",
        "price": "مثال: 120000",
        "customer_name": "نام کامل مشتری",
        "customer_phone": "09xxxxxxxxx",
        "customer_province": "نام استان",
        "customer_address": "آدرس کامل تحویل",
        "delivery_window": "مثال: 10-12",
        "payment_method": "مثال: pay-later",
        "note": "متن یادداشت را وارد کنید",
    }
    help_text_map = {
        "name": "نام محصول یا آیتم را کوتاه، دقیق و قابل فهم وارد کنید.",
        "slug": "اسلاگ باید انگلیسی، یکتا و بدون فاصله باشد.",
        "url_slug": "بخش پایانی آدرس محصول را وارد کنید (فقط انگلیسی، عدد و خط تیره).",
        "description": "توضیح کامل و واضحی از محصول برای نمایش در سایت وارد کنید.",
        "categories": "دسته‌بندی‌های مرتبط با این محصول را انتخاب کنید.",
        "tags": "تگ‌های مرتبط با این محصول را انتخاب کنید.",
        "event_types": "نوع مراسم را با مقدارهای معتبر مثل conference یا memorial ثبت کنید.",
        "contents": "اقلام داخل پک را به صورت لیست ثبت کنید.",
        "image": "تصویر واضح و باکیفیت محصول را انتخاب کنید.",
        "image_name": "نام فایل تصویر را کوتاه و معنی‌دار وارد کنید.",
        "image_alt": "متن جایگزین تصویر را توصیفی و واضح وارد کنید.",
        "price": "قیمت را به تومان ثبت کنید. در صورت توافقی بودن، فیلد را خالی بگذارید.",
        "available": "اگر محصول قابل سفارش است این گزینه را فعال نگه دارید.",
        "featured": "برای نمایش محصول در بخش ویژه، این گزینه را فعال کنید.",
    }

    def _build_placeholder(self, db_field: models.Field, label: str) -> str:
        if db_field.name in self.placeholder_map:
            return self.placeholder_map[db_field.name]

        if isinstance(db_field, (models.PositiveIntegerField, models.IntegerField)):
            return "عدد وارد کنید"
        if isinstance(db_field, models.DateField):
            return "تاریخ را انتخاب کنید"
        if isinstance(db_field, models.TextField):
            return f"{label} را وارد کنید"
        if isinstance(db_field, models.CharField):
            return f"{label} را وارد کنید"
        return ""

    def formfield_for_dbfield(self, db_field, request, **kwargs):
        formfield = super().formfield_for_dbfield(db_field, request, **kwargs)
        if formfield is None:
            return formfield

        widget = formfield.widget
        label = formfield.label or str(db_field.verbose_name)

        if hasattr(widget, "attrs"):
            widget.attrs.setdefault("dir", "rtl")
            widget.attrs.setdefault("style", "width: 100%;")

            if isinstance(
                widget,
                (
                    forms.TextInput,
                    forms.Textarea,
                    forms.NumberInput,
                    forms.URLInput,
                    forms.EmailInput,
                ),
            ):
                placeholder = self._build_placeholder(db_field, label)
                if placeholder:
                    widget.attrs.setdefault("placeholder", placeholder)

        explicit_help_text = self.help_text_map.get(db_field.name)
        help_text = (formfield.help_text or "").strip()
        if explicit_help_text:
            formfield.help_text = explicit_help_text
        elif not help_text:
            formfield.help_text = f"نکته: مقدار «{label}» را دقیق وارد کنید."
        elif "نکته:" not in help_text:
            formfield.help_text = f"{help_text} | نکته: قبل از ذخیره، مقدار این فیلد را بررسی کنید."

        return formfield
