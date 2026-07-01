import os
import json
import time
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

import paho.mqtt.client as mqtt
from django.conf import settings
from api.views import verify_hardware_token, broadcast_bin_update
from api.models import Bin, Profile, Activity
from django.contrib.auth.models import User
from django.utils import timezone
from django.db import transaction


from django.core.cache import cache

def handle_capacity_update(bin_id, payload):
    try:
        data = json.loads(payload)
        hardware_token = data.get('hardware_token', '')
        capacity = float(data.get('capacity', 0.0))

        cached_token = cache.get(f"bin_{bin_id}_hw_token")
        if cached_token is None:
            bin_obj = Bin.objects.filter(bin_id=bin_id).first()
            if not bin_obj:
                return
            cached_token = bin_obj.hardware_token or "NONE"
            cache.set(f"bin_{bin_id}_hw_token", cached_token, timeout=3600)
        
        if cached_token != "NONE" and cached_token != hardware_token:
            return

        crowd_level = 'Low Crowd'
        if capacity >= 80:
            crowd_level = 'High Crowd'
        elif capacity >= 50:
            crowd_level = 'Medium Crowd'
            
        cache.set(f"bin_{bin_id}_capacity", capacity, timeout=3600)
        cache.set(f"bin_{bin_id}_crowd_level", crowd_level, timeout=3600)

        # Broadcast map update - can pull from cache in views
        broadcast_bin_update()
    except Exception:
        pass


def handle_session_end(bin_id, payload):
    try:
        data = json.loads(payload)
        hardware_token = data.get('hardware_token', '')
        bin_obj = Bin.objects.get(bin_id=bin_id)
        if not verify_hardware_token(bin_obj, hardware_token):
            return

        user = bin_obj.current_user
        if user:
            with transaction.atomic():
                profile, created = Profile.objects.select_for_update().get_or_create(user=user)

                weight_g = float(data.get('weight_g', data.get('weight', 0.0)))
                is_metal_str = data.get('is_metal')
                is_metal = str(is_metal_str).lower() == 'true' if is_metal_str is not None else None
                material_type = data.get('material', data.get('material_type'))
                
                if material_type is not None:
                    material_type = material_type.lower()
                
                from api.services import process_deposit_payload
                process_deposit_payload(profile, weight_g, is_metal=is_metal, material_type=material_type)

        bin_obj.status = 'idle'
        bin_obj.current_user = None
        bin_obj.current_qr_code = None
        
        cached_capacity = cache.get(f"bin_{bin_id}_capacity")
        cached_crowd_level = cache.get(f"bin_{bin_id}_crowd_level")
        if cached_capacity is not None:
            bin_obj.capacity = cached_capacity
        if cached_crowd_level is not None:
            bin_obj.crowd_level = cached_crowd_level
            
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
    print("Connected to MQTT broker successfully!")
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
    import uuid
    broker_url = getattr(settings, 'MQTT_HOST', '127.0.0.1')
    broker_port = int(getattr(settings, 'MQTT_PORT', 1883))
    broker_user = getattr(settings, 'MQTT_USER', 'smartbin')
    broker_password = getattr(settings, 'MQTT_PASSWORD', 'smartbin123')

    client_id = f"django_mqtt_listener_{uuid.uuid4().hex[:8]}"
    print(f"Starting MQTT listener. Broker: {broker_url}:{broker_port} | Client ID: {client_id}")
    
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
    if broker_user:
        client.username_pw_set(broker_user, broker_password)
    if broker_port == 8883:
        client.tls_set()
    client.on_connect = on_connect
    client.on_message = on_message

    print(f"Attempting to connect to {broker_url}:{broker_port}...")
    client.connect(broker_url, broker_port, 60)
    
    # loop_forever() handles reconnections automatically
    client.loop_forever()


if __name__ == '__main__':
    run()