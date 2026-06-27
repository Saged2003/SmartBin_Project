from django.contrib import admin
from .models import Profile, Compound, Bin, Activity, Reward, RedeemedReward


class ProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'points', 'milestone_points', 'deposits', 'is_employee', 'is_approved_employee', 'streak_count')
    search_fields = ('user__username', 'user__email', 'full_name', 'phone')
    list_filter = ('is_employee', 'is_approved_employee', 'premium_unlocked')


class CompoundAdmin(admin.ModelAdmin):
    list_display = ('name', 'address', 'lat', 'lng', 'status')
    search_fields = ('name', 'address')
    list_filter = ('status',)


class BinAdmin(admin.ModelAdmin):
    list_display = ('bin_id', 'status', 'capacity', 'crowd_level', 'current_user', 'lat', 'lng')
    search_fields = ('bin_id',)
    list_filter = ('status', 'crowd_level')


class ActivityAdmin(admin.ModelAdmin):
    list_display = ('user', 'material_type', 'points', 'weight', 'co2_saved_in_activity', 'date')
    search_fields = ('user__username', 'material_type')
    list_filter = ('material_type', 'date')


class RewardAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'cost', 'required_points', 'tier', 'is_premium', 'is_active', 'stock_quantity')
    search_fields = ('name', 'category', 'description')
    list_filter = ('category', 'tier', 'is_premium', 'is_active')


class RedeemedRewardAdmin(admin.ModelAdmin):
    list_display = ('user', 'reward', 'redeemed_at')
    search_fields = ('user__username', 'reward__name')
    list_filter = ('redeemed_at',)


admin.site.register(Profile, ProfileAdmin)
admin.site.register(Compound, CompoundAdmin)
admin.site.register(Bin, BinAdmin)
admin.site.register(Activity, ActivityAdmin)
admin.site.register(Reward, RewardAdmin)
admin.site.register(RedeemedReward, RedeemedRewardAdmin)