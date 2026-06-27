from rest_framework import serializers
from .models import Compound, Activity, Reward, Profile, Bin, RedeemedReward


class CompoundSerializer(serializers.ModelSerializer):
    class Meta:
        model = Compound
        fields = '__all__'


class ActivitySerializer(serializers.ModelSerializer):
    t = serializers.CharField(source='material_type', read_only=True)

    class Meta:
        model = Activity
        fields = '__all__'


class RewardSerializer(serializers.ModelSerializer):
    class Meta:
        model = Reward
        fields = '__all__'


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profile
        fields = '__all__'
        read_only_fields = ['user', 'points', 'milestone_points', 'premium_unlocked', 'streak_count', 'last_activity_date', 'weight', 'co2_saved', 'deposits']


class BinSerializer(serializers.ModelSerializer):
    distance_km = serializers.FloatField(read_only=True, required=False)

    class Meta:
        model = Bin
        fields = '__all__'
        extra_kwargs = {'hardware_token': {'write_only': True}}


class RedeemedRewardSerializer(serializers.ModelSerializer):
    class Meta:
        model = RedeemedReward
        fields = '__all__'