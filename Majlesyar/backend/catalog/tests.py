from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Category, Product


class AdminProductApiTests(APITestCase):
    def setUp(self):
        user_model = get_user_model()
        self.staff_user = user_model.objects.create_user(
            username="staff",
            password="pass12345",
            is_staff=True,
        )
        self.normal_user = user_model.objects.create_user(
            username="normal",
            password="pass12345",
            is_staff=False,
        )
        self.category_one = Category.objects.create(name="Conference", slug="conference", icon="C")
        self.category_two = Category.objects.create(name="Luxury", slug="luxury", icon="L")

    def _staff_auth(self):
        self.client.force_authenticate(user=self.staff_user)

    def test_staff_can_create_product_using_frontend_payload_shape(self):
        self._staff_auth()
        payload = {
            "name": "محصول تست",
            "description": "توضیحات",
            "price": 123000,
            "category_ids": [str(self.category_one.id), str(self.category_two.id)],
            "event_types": ["conference", "party"],
            "contents": ["آیتم 1", "آیتم 2"],
            "image": "/placeholder.svg",
            "featured": True,
            "available": True,
        }

        response = self.client.post(reverse("admin-product-list-create"), payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("id", response.data)
        self.assertEqual(response.data["name"], payload["name"])
        self.assertCountEqual(response.data["category_ids"], payload["category_ids"])

        created = Product.objects.get(id=response.data["id"])
        self.assertEqual(created.price, payload["price"])
        self.assertCountEqual(
            list(created.categories.values_list("id", flat=True)),
            [self.category_one.id, self.category_two.id],
        )

    def test_staff_can_patch_product_categories_and_flags(self):
        self._staff_auth()
        product = Product.objects.create(
            name="Old product",
            description="desc",
            price=10000,
            event_types=["conference"],
            contents=["item"],
            featured=False,
            available=True,
        )
        product.categories.set([self.category_one])

        payload = {
            "name": "Updated product",
            "category_ids": [str(self.category_two.id)],
            "available": False,
            "featured": True,
            "image": None,
        }
        url = reverse("admin-product-detail", kwargs={"id": str(product.id)})
        response = self.client.patch(url, payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["name"], "Updated product")
        self.assertCountEqual(response.data["category_ids"], [str(self.category_two.id)])
        self.assertFalse(response.data["available"])
        self.assertTrue(response.data["featured"])

    def test_staff_can_delete_product(self):
        self._staff_auth()
        product = Product.objects.create(
            name="Delete product",
            description="desc",
            price=10000,
            event_types=[],
            contents=[],
        )
        url = reverse("admin-product-detail", kwargs={"id": str(product.id)})

        response = self.client.delete(url)

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Product.objects.filter(id=product.id).exists())

    def test_non_staff_cannot_create_product(self):
        self.client.force_authenticate(user=self.normal_user)
        payload = {
            "name": "محصول",
            "category_ids": [str(self.category_one.id)],
            "event_types": [],
            "contents": [],
            "featured": False,
            "available": True,
        }

        response = self.client.post(reverse("admin-product-list-create"), payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
