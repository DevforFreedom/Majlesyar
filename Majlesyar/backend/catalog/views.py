from django.db.models import Q
from rest_framework import generics
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from .models import BuilderItem, Category, Product
from .serializers import (
    BuilderItemSerializer,
    CategorySerializer,
    ProductSerializer,
    ProductWriteSerializer,
)
from orders.permissions import IsStaffUser


class CategoryListAPIView(generics.ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


class ProductListAPIView(generics.ListAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        queryset = Product.objects.prefetch_related("categories").all()

        category_id = self.request.query_params.get("category")
        if category_id:
            queryset = queryset.filter(categories__id=category_id)

        event_type = self.request.query_params.get("event_type")
        if event_type:
            queryset = queryset.filter(event_types__contains=[event_type])

        featured = self.request.query_params.get("featured")
        if featured is not None:
            queryset = queryset.filter(featured=featured.lower() == "true")

        available = self.request.query_params.get("available")
        if available is not None:
            queryset = queryset.filter(available=available.lower() == "true")

        search = self.request.query_params.get("search")
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search)
                | Q(description__icontains=search)
                | Q(contents__icontains=search)
            )

        return queryset.distinct()


class ProductDetailAPIView(generics.RetrieveAPIView):
    queryset = Product.objects.prefetch_related("categories").all()
    serializer_class = ProductSerializer
    lookup_field = "id"


class BuilderItemListAPIView(generics.ListAPIView):
    queryset = BuilderItem.objects.all()
    serializer_class = BuilderItemSerializer


class AdminProductListCreateAPIView(generics.ListCreateAPIView):
    permission_classes = [IsStaffUser]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_queryset(self):
        queryset = Product.objects.prefetch_related("categories").all()

        search = self.request.query_params.get("search")
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search)
                | Q(description__icontains=search)
                | Q(contents__icontains=search)
            )

        available = self.request.query_params.get("available")
        if available is not None:
            queryset = queryset.filter(available=available.lower() == "true")

        featured = self.request.query_params.get("featured")
        if featured is not None:
            queryset = queryset.filter(featured=featured.lower() == "true")

        category_id = self.request.query_params.get("category")
        if category_id:
            queryset = queryset.filter(categories__id=category_id)

        return queryset.distinct()

    def get_serializer_class(self):
        if self.request.method == "POST":
            return ProductWriteSerializer
        return ProductSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        product = serializer.save()
        response_serializer = ProductSerializer(product, context={"request": request})
        headers = self.get_success_headers(response_serializer.data)
        return Response(response_serializer.data, status=201, headers=headers)


class AdminProductDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsStaffUser]
    parser_classes = [JSONParser, MultiPartParser, FormParser]
    lookup_field = "id"

    def get_queryset(self):
        return Product.objects.prefetch_related("categories").all()

    def get_serializer_class(self):
        if self.request.method in ("PATCH", "PUT"):
            return ProductWriteSerializer
        return ProductSerializer

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop("partial", False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        product = serializer.save()
        response_serializer = ProductSerializer(product, context={"request": request})
        return Response(response_serializer.data)
