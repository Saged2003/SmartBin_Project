import os
import json
import time
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

import paho.mqtt.client as mqtt
from django.conf import settings
from api.views import verify_hardware_token, broadcast_bin_update, send_fcm_notification, calculate_co2_saved
from api.models import Bin, Profile, Activity
from django.contrib.auth.models import User
from django.utils import timezone
from django.db import transaction


def handle_capacity_update(bin_id, payload):
    try:
        data = json.loads(payload)
        hardware_token = data.get('hardware_token', '')
        capacity = float(data.get('capacity', 0.0))

        bin_obj = Bin.objects.get(bin_id=bin_id)
        if not verify_hardware_token(bin_obj, hardware_token):
            return

        bin_obj.capacity = capacity
        if capacity >= 80:
            bin_obj.crowd_level = 'High Crowd'
        elif capacity >= 50:
            bin_obj.crowd_level = 'Medium Crowd'
        else:
            bin_obj.crowd_level = 'Low Crowd'
        bin_obj.save()

        if capacity >= 90.0:
            employee_profiles = Profile.objects.filter(is_employee=True, is_approved_employee=True)
            for emp in employee_profiles:
                if emp.fcm_token:
                    send_fcm_notification(emp.fcm_token, "Bin Full Alert", f"Bin {bin_id} has reached {capacity}% capacity and needs collection.")
        broadcast_bin_update()
    except Exception:
        pass


def handle_session_end(bin_id, payload):
    try:
        data = json.loads(payload)
        hardware_token = data.get('hardware_token', '')
        points = int(data.get('points', 0))
        weight = float(data.get('weight', 0.0))
        material_type = data.get('material_type', 'plastic').lower()

        bin_obj = Bin.objects.get(bin_id=bin_id)
        if not verify_hardware_token(bin_obj, hardware_token):
            return

        user = bin_obj.current_user
        if user:
            with transaction.atomic():
                profile, created = Profile.objects.select_for_update().get_or_create(user=user)

                from datetime import timedelta
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
                saved_co2 = calculate_co2_saved(weight, material_type)
                profile.co2_saved += saved_co2

                while profile.milestone_points >= 1000:
                    profile.premium_unlocked = True
                    profile.milestone_points -= 1000
                    if profile.fcm_token:
                        send_fcm_notification(profile.fcm_token, "Premium Unlocked!", "Congratulations! You reached 1000 points and unlocked Premium Rewards.")
                profile.save()
                Activity.objects.create(user=user, points=final_points, weight=weight, co2_saved_in_activity=saved_co2, material_type=material_type)

        bin_obj.status = 'idle'
        bin_obj.current_user = None
        bin_obj.current_qr_code = None
        bin_obj.save()
        broadcast_bin_update()
    except Exception:
        pass


def handle_qr_request(client, bin_id, payload):
    import uuid
    try:
        data = json.loads(payload)
        hardware_token = data.get('hardware_token', '')

        bin_obj, created = Bin.objects.get_or_create(bin_id=bin_id)
        if not created and not verify_hardware_token(bin_obj, hardware_token):
            return

        new_code = str(uuid.uuid4())
        bin_obj.current_qr_code = new_code
        bin_obj.status = 'idle'
        bin_obj.save()

        qr_topic = f"smartbin/{bin_id}/qr_code"
        qr_payload = json.dumps({"code": new_code})
        client.publish(qr_topic, qr_payload)
    except Exception:
        pass


def on_connect(client, userdata, flags, reason_code, properties):
    client.subscribe("smartbin/+/update")
    client.subscribe("smartbin/+/capacity")
    client.subscribe("smartbin/+/session_end")
    client.subscribe("smartbin/+/end_session")
    client.subscribe("smartbin/+/request_qr")


def on_message(client, userdata, msg):
    topic_parts = msg.topic.split('/')
    if len(topic_parts) < 3:
        return

    bin_id = topic_parts[1]
    action = topic_parts[2]

    if action in ('update', 'capacity'):
        handle_capacity_update(bin_id, msg.payload.decode())
    elif action in ('session_end', 'end_session'):
        handle_session_end(bin_id, msg.payload.decode())
    elif action == 'request_qr':
        handle_qr_request(client, bin_id, msg.payload.decode())


def run():
    broker_url = getattr(settings, 'MQTT_BROKER_URL', '127.0.0.1')
    broker_port = int(getattr(settings, 'MQTT_BROKER_PORT', 1883))

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="django_mqtt_listener")
    client.on_connect = on_connect
    client.on_message = on_message

    backoff = 1
    while True:
        try:
            client.connect(broker_url, broker_port, 60)
            client.loop_forever()
        except Exception:
            time.sleep(min(backoff, 30))
            backoff = min(backoff * 2, 30)


if __name__ == '__main__':
    run()