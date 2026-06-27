import os
from django.apps import AppConfig
from django.db.models.signals import post_migrate

def create_admin_user(sender, **kwargs):
    from django.contrib.auth.models import User
    from api.models import Profile
    try:
        username = os.environ.get('ROOT_ADMIN_USER', 'super_admin')
        email = os.environ.get('ROOT_ADMIN_EMAIL', 'sagedryan775@gmail.com')
        password = os.environ.get('ROOT_ADMIN_PASS', 'Admin@12345')
        if not User.objects.filter(username=username).exists():
            user = User.objects.create_superuser(username, email, password)
            Profile.objects.create(
                user=user,
                points=0,
                milestone_points=0,
                weight=0.0,
                co2_saved=0.0,
                deposits=0,
                is_employee=True,
                is_approved_employee=True,
                full_name="Super Admin"
            )
    except Exception:
        pass

class ApiConfig(AppConfig):
    name = 'api'
    def ready(self):
        post_migrate.connect(create_admin_user, sender=self)