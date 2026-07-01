from django.db import models
from django.contrib.auth.models import User


REWARD_CATEGORY_CHOICES = [
    ('general', 'General'),
    ('cafe', 'Cafe'),
    ('restaurant', 'Restaurant'),
    ('telecom', 'Telecom'),
    ('retail', 'Retail'),
    ('cash', 'Cash'),
    ('grocery', 'Grocery'),
    ('entertainment', 'Entertainment'),
    ('voucher', 'Voucher'),
    ('premium', 'Premium'),
]

ICON_CATEGORY_CHOICES = [
    ('cafe', 'Cafe'),
    ('restaurant', 'Restaurant'),
    ('telecom', 'Telecom'),
    ('retail', 'Retail'),
    ('cash', 'Cash'),
    ('grocery', 'Grocery'),
    ('entertainment', 'Entertainment'),
    ('voucher', 'Voucher'),
    ('premium', 'Premium'),
]

MATERIAL_TYPE_CHOICES = [
    ('metal', 'Metal'),
    ('non_metal', 'Non-Metal'),
    ('plastic', 'Plastic'),
    ('paper', 'Paper'),
    ('glass', 'Glass'),
    ('trash', 'Trash'),
]


class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    points = models.IntegerField(default=0)
    premium_unlocked = models.BooleanField(default=False)
    weight = models.FloatField(default=0.0)
    co2_saved = models.FloatField(default=0.0)
    full_name = models.CharField(max_length=100, null=True, blank=True)
    phone = models.CharField(max_length=20, null=True, blank=True)
    address = models.CharField(max_length=200, null=True, blank=True)
    deposits = models.IntegerField(default=0)
    is_employee = models.BooleanField(default=False, db_index=True)
    is_approved_employee = models.BooleanField(default=False)
    profile_picture = models.ImageField(upload_to='profiles/', null=True, blank=True)

    def __str__(self):
        return self.user.username


class Compound(models.Model):
    name = models.CharField(max_length=100)
    address = models.CharField(max_length=200)
    lat = models.FloatField(null=True, blank=True, db_index=True)
    lng = models.FloatField(null=True, blank=True, db_index=True)
    status = models.CharField(max_length=50, default='available')

    def __str__(self):
        return self.name


class Bin(models.Model):
    name = models.CharField(max_length=100, null=True, blank=True)
    compound = models.ForeignKey(Compound, on_delete=models.CASCADE, related_name='bins', null=True, blank=True)
    bin_id = models.CharField(max_length=50, unique=True)
    hardware_token = models.CharField(max_length=100, unique=True, null=True, blank=True)
    current_qr_code = models.CharField(max_length=100, null=True, blank=True)
    lat = models.FloatField(null=True, blank=True, db_index=True)
    lng = models.FloatField(null=True, blank=True, db_index=True)
    status = models.CharField(max_length=50, default='idle', db_index=True)
    capacity = models.FloatField(default=0.0)
    crowd_level = models.CharField(max_length=50, default='Low Crowd')
    current_user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)

    def __str__(self):
        return self.bin_id


class Activity(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, db_index=True)
    weight = models.FloatField(default=0.0)
    points = models.IntegerField(default=0)
    co2_saved_in_activity = models.FloatField(default=0.0)
    material_type = models.CharField(max_length=50, choices=MATERIAL_TYPE_CHOICES, default='plastic')
    date = models.DateTimeField(auto_now_add=True, db_index=True)


class Reward(models.Model):
    name = models.CharField(max_length=100)
    category = models.CharField(max_length=50, choices=REWARD_CATEGORY_CHOICES, default='general')
    tier = models.IntegerField(default=1)
    icon_category = models.CharField(max_length=50, choices=ICON_CATEGORY_CHOICES, default='voucher')
    description = models.CharField(max_length=100)
    cost = models.IntegerField(null=True, blank=True)
    required_points = models.IntegerField(default=0)
    discount_percentage = models.FloatField(null=True, blank=True)
    is_premium = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    stock_quantity = models.IntegerField(default=-1)
    dynamic_limit = models.IntegerField(default=-1)
    valid_until = models.DateField(null=True, blank=True)

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name


class RedeemedReward(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    reward = models.ForeignKey(Reward, on_delete=models.CASCADE)
    redeemed_at = models.DateTimeField(auto_now_add=True)
    promo_code = models.CharField(max_length=50, null=True, blank=True)

    def __str__(self):
        return f"{self.user.username} - {self.reward.name}"


class MaterialConfig(models.Model):
    material_type = models.CharField(max_length=50, unique=True, db_index=True)
    points_per_g = models.FloatField(default=0.0)
    co2_per_g = models.FloatField(default=0.0)

    def __str__(self):
        return self.material_type