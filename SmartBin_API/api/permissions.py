import os
from rest_framework.permissions import BasePermission

class IsRootSuperAdmin(BasePermission):
    def has_permission(self, request, view):
        admin_email = os.environ.get('ROOT_ADMIN_EMAIL', 'admin@smartbin.com')
        return bool(
            request.user and
            request.user.is_authenticated and
            request.user.is_superuser and
            request.user.email == admin_email
        )