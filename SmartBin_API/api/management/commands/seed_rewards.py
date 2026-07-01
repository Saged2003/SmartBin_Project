from django.core.management.base import BaseCommand
from api.models import Reward
from django.utils import timezone
from datetime import timedelta

class Command(BaseCommand):
    help = 'Seeds the database with a comprehensive list of realistic rewards'

    def handle(self, *args, **kwargs):
        self.stdout.write('Deleting existing rewards...')
        Reward.objects.all().delete()

        now = timezone.now()

        rewards_data = [
            # Cafe
            {
                "name": "Free Medium Coffee",
                "category": "Cafe",
                "icon_category": "cafe",
                "description": "Redeem this voucher for any medium coffee of your choice at participating Starbucks locations.",
                "cost": 150,
                "required_points": 100,
                "discount_percentage": 100,
                "is_premium": False,
                "stock_quantity": 100,
                "tier": 1,
            },
            {
                "name": "20% Off Pastries",
                "category": "Cafe",
                "icon_category": "cafe",
                "description": "Get a 20% discount on any fresh pastry or baked good.",
                "cost": 50,
                "required_points": 50,
                "discount_percentage": 20,
                "is_premium": False,
                "stock_quantity": -1,
                "tier": 1,
            },
            # Restaurant
            {
                "name": "Free Burger Meal",
                "category": "Restaurant",
                "icon_category": "restaurant",
                "description": "Enjoy a free Whopper meal with fries and a drink.",
                "cost": 500,
                "required_points": 500,
                "discount_percentage": 100,
                "is_premium": False,
                "stock_quantity": 50,
                "tier": 2,
            },
            {
                "name": "15% Off Total Bill",
                "category": "Restaurant",
                "icon_category": "restaurant",
                "description": "Apply a 15% discount to your entire order at KFC.",
                "cost": 200,
                "required_points": 200,
                "discount_percentage": 15,
                "is_premium": False,
                "stock_quantity": -1,
                "tier": 1,
            },
            # Telecom
            {
                "name": "1GB Mobile Data",
                "category": "Telecom",
                "icon_category": "telecom",
                "description": "Add 1GB of high-speed mobile data to your current plan.",
                "cost": 300,
                "required_points": 300,
                "discount_percentage": None,
                "is_premium": False,
                "stock_quantity": -1,
                "tier": 1,
            },
            {
                "name": "100 Free Minutes",
                "category": "Telecom",
                "icon_category": "telecom",
                "description": "Get 100 free local minutes valid for 7 days.",
                "cost": 250,
                "required_points": 200,
                "discount_percentage": None,
                "is_premium": False,
                "stock_quantity": -1,
                "tier": 1,
            },
            # Retail
            {
                "name": "25% Off Adidas Shoes",
                "category": "Retail",
                "icon_category": "retail",
                "description": "Exclusive discount on all running shoes at official retail locations.",
                "cost": 800,
                "required_points": 800,
                "discount_percentage": 25,
                "is_premium": False,
                "stock_quantity": 20,
                "tier": 3,
            },
            {
                "name": "$10 Amazon Gift Card",
                "category": "Retail",
                "icon_category": "retail",
                "description": "A $10 digital gift card applied directly to your Amazon account.",
                "cost": 1000,
                "required_points": 1000,
                "discount_percentage": None,
                "is_premium": True,
                "stock_quantity": 15,
                "tier": 4,
            },
            # Grocery
            {
                "name": "Free Eco-friendly Bag",
                "category": "Grocery",
                "icon_category": "grocery",
                "description": "Redeem a reusable, durable eco-friendly shopping bag.",
                "cost": 100,
                "required_points": 100,
                "discount_percentage": 100,
                "is_premium": False,
                "stock_quantity": 200,
                "tier": 1,
            },
            {
                "name": "10% Off Fresh Produce",
                "category": "Grocery",
                "icon_category": "grocery",
                "description": "Get a 10% discount on all fresh vegetables and fruits.",
                "cost": 300,
                "required_points": 250,
                "discount_percentage": 10,
                "is_premium": False,
                "stock_quantity": -1,
                "tier": 2,
            },
            # Cash / Vouchers
            {
                "name": "$5 PayPal Cash",
                "category": "Cash",
                "icon_category": "cash",
                "description": "Receive $5 directly into your linked PayPal account.",
                "cost": 600,
                "required_points": 600,
                "discount_percentage": None,
                "is_premium": True,
                "stock_quantity": 50,
                "tier": 3,
            },
            {
                "name": "$20 Visa Prepaid Card",
                "category": "Cash",
                "icon_category": "cash",
                "description": "A digital prepaid card loaded with $20 for online shopping.",
                "cost": 2200,
                "required_points": 2000,
                "discount_percentage": None,
                "is_premium": True,
                "stock_quantity": 10,
                "tier": 5,
            },
            # Entertainment
            {
                "name": "1 Free Movie Ticket",
                "category": "Entertainment",
                "icon_category": "entertainment",
                "description": "Enjoy any standard 2D movie screening for free.",
                "cost": 850,
                "required_points": 800,
                "discount_percentage": 100,
                "is_premium": False,
                "stock_quantity": 30,
                "tier": 3,
            },
            {
                "name": "1 Month Spotify Premium",
                "category": "Entertainment",
                "icon_category": "entertainment",
                "description": "Unlock ad-free music listening with 1 month of Spotify Premium.",
                "cost": 1200,
                "required_points": 1000,
                "discount_percentage": 100,
                "is_premium": True,
                "stock_quantity": 25,
                "tier": 4,
            },
            # Premium Exclusives
            {
                "name": "VIP Spa Day Access",
                "category": "Premium",
                "icon_category": "premium",
                "description": "Exclusive VIP access to luxury spa facilities including massage and sauna.",
                "cost": 5000,
                "required_points": 5000,
                "discount_percentage": 100,
                "is_premium": True,
                "stock_quantity": 5,
                "tier": 5,
                "valid_until": now + timedelta(days=30),
            },
            {
                "name": "Exclusive Flight Upgrade",
                "category": "Premium",
                "icon_category": "premium",
                "description": "Upgrade your economy seat to Business Class on any short-haul flight.",
                "cost": 10000,
                "required_points": 10000,
                "discount_percentage": None,
                "is_premium": True,
                "stock_quantity": 2,
                "tier": 5,
                "valid_until": now + timedelta(days=90),
            }
        ]

        created_count = 0
        for reward_data in rewards_data:
            Reward.objects.create(**reward_data)
            created_count += 1

        self.stdout.write(self.style.SUCCESS(f'Successfully seeded {created_count} rewards.'))