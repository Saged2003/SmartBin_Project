from django.contrib import admin
from django.contrib.auth.models import Group
from .models import Profile, Compound, Bin, Activity, Reward, RedeemedReward, MaterialConfig


class ProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'points', 'deposits', 'is_employee', 'is_approved_employee')
    search_fields = ('user__username', 'user__email', 'full_name', 'phone')
    list_filter = ('is_employee', 'is_approved_employee', 'premium_unlocked')


class BinInline(admin.TabularInline):
    model = Bin
    extra = 1
    fields = ('bin_id', 'name', 'status', 'capacity')

class CompoundAdmin(admin.ModelAdmin):
    list_display = ('name', 'address', 'lat', 'lng', 'status')
    search_fields = ('name', 'address')
    list_filter = ('status',)
    inlines = [BinInline]


class BinAdmin(admin.ModelAdmin):
    list_display = ('bin_id', 'name', 'compound', 'status', 'capacity', 'crowd_level', 'current_user', 'lat', 'lng')
    search_fields = ('bin_id',)
    list_filter = ('status', 'crowd_level')


class ActivityAdmin(admin.ModelAdmin):
    list_display = ('user', 'material_type', 'points', 'weight', 'date')
    search_fields = ('user__username', 'material_type')
    list_filter = ('material_type', 'date')


class RewardAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'cost', 'required_points', 'is_premium', 'is_active')
    search_fields = ('name', 'category', 'description')
    list_filter = ('category', 'is_premium', 'is_active')
    exclude = ('tier', 'stock_quantity', 'dynamic_limit')


class RedeemedRewardAdmin(admin.ModelAdmin):
    list_display = ('user', 'reward', 'redeemed_at')
    search_fields = ('user__username', 'reward__name')
    list_filter = ('redeemed_at',)

    def has_add_permission(self, request):
        return False


class MaterialConfigAdmin(admin.ModelAdmin):
    list_display = ('material_type', 'points_per_g', 'co2_per_g')
    search_fields = ('material_type',)


admin.site.register(Profile, ProfileAdmin)
admin.site.register(Compound, CompoundAdmin)
admin.site.register(Bin, BinAdmin)
admin.site.register(Activity, ActivityAdmin)
admin.site.register(Reward, RewardAdmin)
admin.site.register(RedeemedReward, RedeemedRewardAdmin)
admin.site.register(MaterialConfig, MaterialConfigAdmin)
admin.site.unregister(Group)