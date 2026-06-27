import json
import uuid
import paho.mqtt.client as mqtt
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from django.db import transaction
from api.models import Bin, Profile, Activity


def broadcast_bin_update():
    try:
        from channels.layers import get_channel_layer
        from asgiref.sync import async_to_sync
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                "map_updates",
                {
                    "type": "bin_update",
                    "message": "update"
                }
            )
    except Exception:
        pass


def process_payload(client, bin_obj, action, payload):
    bin_id = bin_obj.bin_id
    hw_token = payload.get('hardware_token')
    if bin_obj.hardware_token and bin_obj.hardware_token != hw_token:
        return
    if action == 'request_qr':
        new_code = str(uuid.uuid4())
        bin_obj.current_qr_code = new_code
        bin_obj.status = 'idle'
        bin_obj.save()
        client.publish(f"smartbin/{bin_id}/qr_code", json.dumps({"code": new_code}))
    elif action in ('update', 'capacity'):
        capacity = float(payload.get('capacity', 0.0))
        bin_obj.capacity = capacity
        if capacity >= 80:
            bin_obj.crowd_level = 'High Crowd'
        elif capacity >= 50:
            bin_obj.crowd_level = 'Medium Crowd'
        else:
            bin_obj.crowd_level = 'Low Crowd'
        bin_obj.save()
        broadcast_bin_update()
        if capacity >= 90.0:
            from api.views import send_fcm_notification
            employee_profiles = Profile.objects.filter(is_employee=True, is_approved_employee=True)
            for emp in employee_profiles:
                if emp.fcm_token:
                    send_fcm_notification(emp.fcm_token, "Bin Full Alert", f"Bin {bin_id} has reached {capacity}% capacity.")
    elif action in ('session_end', 'end_session'):
        points = int(payload.get('points', 0))
        weight = float(payload.get('weight', 0.0))
        material_type = payload.get('material_type', 'plastic').lower()
        user = bin_obj.current_user
        if user:
            with transaction.atomic():
                profile, created = Profile.objects.select_for_update().get_or_create(user=user)

                now_date = timezone.now().date()
                streak_multiplier = 1.0

                if profile.last_activity_date:
                    if profile.last_activity_date == now_date - timedelta(days=1):
                        profile.streak_count += 1
                    elif profile.last_activity_date < now_date - timedelta(days=1):
                        profile.streak_count = 1
                else:
                    profile.streak_count = 1

                profile.last_activity_date = now_date

                if profile.streak_count >= 7:
                    streak_multiplier = 2.0
                elif profile.streak_count >= 3:
                    streak_multiplier = 1.5

                final_points = int(points * streak_multiplier)

                profile.points += final_points
                profile.milestone_points += final_points
                profile.weight += weight
                profile.deposits += 1
                from api.views import calculate_co2_saved
                saved_co2 = calculate_co2_saved(weight, material_type)
                profile.co2_saved += saved_co2
                while profile.milestone_points >= 1000:
                    profile.premium_unlocked = True
                    profile.milestone_points -= 1000
                    if profile.fcm_token:
                        from api.views import send_fcm_notification
                        send_fcm_notification(profile.fcm_token, "Premium Unlocked!", "Congratulations! You reached 1000 points and unlocked Premium Rewards.")
                profile.save()
                Activity.objects.create(user=user, points=final_points, weight=weight, co2_saved_in_activity=saved_co2, material_type=material_type)
        bin_obj.status = 'idle'
        bin_obj.current_user = None
        bin_obj.current_qr_code = None
        bin_obj.save()
        broadcast_bin_update()


def on_connect(client, userdata, flags, reason_code, properties):
    client.subscribe("smartbin/+/update")
    client.subscribe("smartbin/+/session_end")
    client.subscribe("smartbin/+/end_session")
    client.subscribe("smartbin/+/capacity")
    client.subscribe("smartbin/+/request_qr")


def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode('utf-8'))
        topic_parts = msg.topic.split('/')
        bin_id = topic_parts[1]
        action = topic_parts[2]
        bin_obj = Bin.objects.filter(bin_id=bin_id).first()
        if not bin_obj:
            return
        if isinstance(payload, list):
            for item in payload:
                process_payload(client, bin_obj, action, item)
        else:
            process_payload(client, bin_obj, action, payload)
    except Exception:
        pass


def start_mqtt():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_message = on_message
    broker_url = getattr(settings, 'MQTT_BROKER_URL', '127.0.0.1')
    broker_port = getattr(settings, 'MQTT_BROKER_PORT', 1883)
    try:
        client.connect(broker_url, broker_port, 60)
        client.loop_forever()
    except Exception:
        pass