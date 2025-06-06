"""
URL configuration for music_rental project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView
from .admin_site import roknsound_admin_site

# Use our custom admin site
admin.site = roknsound_admin_site

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", TemplateView.as_view(template_name="index.html"), name="home"),
    path("inventory/", include("inventory.urls")),
    path("rentals/", include("rentals.urls")),
    path("payments/", include("payments.urls")),
    path("users/", include("users.urls")),  # Keep users URLs first
    path("accounts/", include("allauth.urls")),  # Include all allauth URLs
]

# Serve media files in development (keep this)
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
