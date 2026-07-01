import json
import uuid
import paho.mqtt.client as mqtt
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from django.db import transaction
from api.models import Bin, Profile, Activity
from django.core.cache import cache


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


def process_payload(client, bin_obj, action, payload, bin_id=None):
    if bin_obj:
        bin_id = bin_obj.bin_id
        hw_token = payload.get('hardware_token')
        if bin_obj.hardware_token and bin_obj.hardware_token != hw_token:
            return
    if action == 'request_qr' and bin_obj:
        new_code = str(uuid.uuid4())
        bin_obj.current_qr_code = new_code
        bin_obj.status = 'idle'
        bin_obj.save()
        client.publish(f"smartbin/{bin_id}/qr_code", json.dumps({"code": new_code}))
    elif action in ('update', 'capacity'):
        capacity = float(payload.get('capacity', 0.0))
        if capacity >= 80:
            crowd_level = 'High Crowd'
        elif capacity >= 50:
            crowd_level = 'Medium Crowd'
        else:
            crowd_level = 'Low Crowd'
        cache.set(f"bin_{bin_id}_capacity", capacity, timeout=3600)
        cache.set(f"bin_{bin_id}_crowd_level", crowd_level, timeout=3600)
        broadcast_bin_update()
    elif action in ('session_end', 'end_session'):
        user = bin_obj.current_user
        if user:
            with transaction.atomic():
                profile, created = Profile.objects.select_for_update().get_or_create(user=user)

                weight_g = float(payload.get('weight_g', payload.get('weight', 0.0)))
                is_metal_str = payload.get('is_metal')
                is_metal = str(is_metal_str).lower() == 'true' if is_metal_str is not None else None
                material_type = payload.get('material', payload.get('material_type'))
                
                if material_type is not None:
                    material_type = material_type.lower()
                
                from api.services import process_deposit_payload
                process_deposit_payload(profile, weight_g, is_metal=is_metal, material_type=material_type)

        bin_obj.status = 'idle'
        bin_obj.current_user = None
        bin_obj.current_qr_code = None
        bin_obj.save()
        broadcast_bin_update()


def on_connect(client, userdata, flags, reason_code, properties):
    print("Connected to MQTT Broker!")
    client.subscribe("smartbin/+/update")
    client.subscribe("smartbin/+/session_end")
    client.subscribe("smartbin/+/end_session")
    client.subscribe("smartbin/+/capacity")
    client.subscribe("smartbin/+/request_qr")


def on_message(client, userdata, msg):
    try:
        print(f"[MQTT] Received message on topic {msg.topic}")
        payload = json.loads(msg.payload.decode('utf-8'))
        topic_parts = msg.topic.split('/')
        bin_id = topic_parts[1]
        action = topic_parts[2]
        
        cached_token = cache.get(f"bin_{bin_id}_hw_token")
        if cached_token is None:
            bin_obj = Bin.objects.filter(bin_id=bin_id).first()
            if not bin_obj:
                return
            cached_token = bin_obj.hardware_token or "NONE"
            cache.set(f"bin_{bin_id}_hw_token", cached_token, timeout=3600)
            
        if action in ('update', 'capacity'):
            hw_token = payload.get('hardware_token') if not isinstance(payload, list) else payload[0].get('hardware_token')
            if cached_token != "NONE" and cached_token != hw_token:
                return
            if isinstance(payload, list):
                for item in payload:
                    process_payload(client, None, action, item, bin_id=bin_id)
            else:
                process_payload(client, None, action, payload, bin_id=bin_id)
            return
            
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
    broker_url = getattr(settings, 'MQTT_HOST', '127.0.0.1')
    broker_port = getattr(settings, 'MQTT_PORT', 1883)
    broker_user = getattr(settings, 'MQTT_USER', 'smartbin')
    broker_password = getattr(settings, 'MQTT_PASSWORD', 'smartbin123')
    if broker_user and broker_password:
        client.username_pw_set(broker_user, broker_password)
    
    if int(broker_port) == 8883:
        client.tls_set()
        
    try:
        print(f"Connecting to MQTT broker at {broker_url}:{broker_port}...")
        client.connect(broker_url, int(broker_port), 60)
        client.loop_forever()
    except Exception as e:
        print(f"MQTT Error: {e}")