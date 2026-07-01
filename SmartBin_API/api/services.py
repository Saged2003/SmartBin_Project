import json
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.utils import timezone
from .models import Activity, MaterialConfig

def trigger_websocket_ui_broadcast(user_profile, earned_points=0):
    """
    Pushes updated data down the open ASGI Daphne Channel link to the Flutter app.
    """
    try:
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"user_{user_profile.user.username}",
                {
                    "type": "user_update",
                    "message": {
                        "points": user_profile.points,
                        "points_added": earned_points,
                        "co2_saved": round(user_profile.co2_saved, 4),
                        "weight": round(user_profile.weight, 4),
                        "deposits": user_profile.deposits
                    }
                }
            )
    except Exception as e:
        print(f"WebSocket trigger failed: {e}")

def process_deposit_payload(user_profile, weight_g, is_metal=None, material_type=None):
    """
    Resolves material classification, calculates points and CO2 saved based on the active matrix,
    persists updates, and triggers a real-time broadcast.
    """
    # 1. Resolve material classification
    if material_type is None and is_metal is not None:
        material_key = 'metal' if is_metal else 'non_metal'
    else:
        material_key = material_type.lower() if material_type else 'trash'

    # 2. Points and CO2 Multiplier Matrix
    system_matrix = {
        'metal': {'points_per_g': 0.15, 'co2_per_g': 0.0095},
        'non_metal': {'points_per_g': 0.05, 'co2_per_g': 0.0015},
        'plastic': {'points_per_g': 0.10, 'co2_per_g': 0.0015},
        'paper': {'points_per_g': 0.06, 'co2_per_g': 0.0009},
        'glass': {'points_per_g': 0.04, 'co2_per_g': 0.0003},
        'trash': {'points_per_g': 0.00, 'co2_per_g': 0.0000},
    }

    # Fetch configuration from the database, fallback to system_matrix
    try:
        db_config = MaterialConfig.objects.get(material_type=material_key)
        config = {
            'points_per_g': db_config.points_per_g,
            'co2_per_g': db_config.co2_per_g
        }
    except MaterialConfig.DoesNotExist:
        config = system_matrix.get(material_key, {'points_per_g': 0.0, 'co2_per_g': 0.0})

    # 3. Precision Mathematics
    earned_points = round(weight_g * config['points_per_g'])
    co2_saved = round(weight_g * config['co2_per_g'], 4)

    # 4. Database Persistence
    user_profile.points += earned_points
    user_profile.co2_saved += co2_saved
    
    # The previous code stored weight in kg, so we convert weight_g to kg.
    weight_kg = weight_g / 1000.0
    user_profile.weight += weight_kg
    user_profile.deposits += 1
    
    if user_profile.points >= 1000 and not user_profile.premium_unlocked:
        user_profile.premium_unlocked = True
        
    user_profile.save()

    # 5. History Logging
    Activity.objects.create(
        user=user_profile.user,
        points=earned_points,
        weight=weight_kg,
        co2_saved_in_activity=co2_saved,
        material_type=material_key,
    )

    # 6. Real-Time Frontend Broadcast via WebSockets
    trigger_websocket_ui_broadcast(user_profile, earned_points)
