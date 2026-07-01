import uuid
import math
import os
import json
import firebase_admin
import paho.mqtt.publish as publish
from firebase_admin import credentials, messaging
from django.core.mail import send_mail
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from rest_framework.authtoken.models import Token
from django_ratelimit.decorators import ratelimit
from django.db.models import Sum, Count
from django.db.models.functions import ExtractHour
from django.conf import settings
from django.utils import timezone
from django.db import transaction
from .models import Profile, Bin, Activity, Reward, RedeemedReward
from .serializers import ActivitySerializer, RewardSerializer, BinSerializer, ProfileSerializer
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.core.cache import cache


def broadcast_bin_update():
    try:
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


def haversine(lat1, lon1, lat2, lon2):
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


def verify_hardware_token(bin_obj, provided_token):
    if bin_obj.hardware_token and bin_obj.hardware_token != provided_token:
        return False
    return True


@api_view(['POST'])
def register_user(request):
    username = request.data.get('username')
    password = request.data.get('password')
    email = request.data.get('email')
    full_name = request.data.get('full_name','')
    phone = request.data.get('phone','')
    is_employee = request.data.get('is_employee', False)

    if User.objects.filter(username=username).exists():
        return Response({'error': 'exists'}, status=400)

    user = User.objects.create_user(username=username, password=password, email=email)
    Profile.objects.create(
        user=user, points=0, weight=0.0, co2_saved=0.0,
        deposits=0, is_employee=is_employee, is_approved_employee=False,
        full_name=full_name, phone=phone
    )
    token, created = Token.objects.get_or_create(user=user)

    if is_employee:
        try:
            admin_email = getattr(settings, 'SUPER_ADMIN_EMAIL', 'admin@smartbin.com')
            send_mail(
                'New Employee Registration Request',
                f'User {username} ({email}) requested to join as an employee.',
                admin_email,
                [admin_email],
                fail_silently=True,
            )
        except Exception:
            pass

    return Response({
        'message': 'ok',
        'token': token.key,
        'points': 0,
        'username': username,
        'is_employee': is_employee,
        'is_approved_employee': False
    })


@ratelimit(key='ip', rate='5/m', block=False)
@api_view(['POST'])
def login_user(request):
    admin_email = getattr(settings, 'SUPER_ADMIN_EMAIL', 'admin@smartbin.com')
    username = request.data.get('username')
    is_root_admin = False

    try:
        user_check = User.objects.get(username=username)
        if user_check.email == admin_email and user_check.is_superuser:
            is_root_admin = True
    except User.DoesNotExist:
        pass

    if getattr(request, 'limited', False) and not is_root_admin:
        return Response({'error': 'Too many requests. Try again later.'}, status=429)

    password = request.data.get('password')
    user = authenticate(username=username, password=password)

    if user is not None:
        token, created = Token.objects.get_or_create(user=user)
        profile, created_profile = Profile.objects.get_or_create(user=user)

        if created_profile:
            profile.points = 0
            profile.weight = 0.0
            profile.co2_saved = 0.0
            profile.deposits = 0
            profile.save()

        return Response({
            'message': 'ok',
            'token': token.key,
            'points': profile.points,
            'username': username,
            'is_employee': profile.is_employee,
            'is_approved_employee': profile.is_approved_employee,
            'is_root_admin': is_root_admin,
            'is_superuser': user.is_superuser,
            'is_staff': user.is_staff
        })
    return Response({'error': 'wrong'}, status=400)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_profile(request):
    username = request.query_params.get('username')
    try:
        user = User.objects.get(username=username)
        admin_email = getattr(settings, 'SUPER_ADMIN_EMAIL', 'admin@smartbin.com')
        request_is_root = (request.user.email == admin_email and request.user.is_superuser)
        if request.user.username != username and not request_is_root:
            return Response({'error': 'unauthorized'}, status=403)

        profile, created = Profile.objects.get_or_create(user=user)
        is_root_admin = (user.email == admin_email and user.is_superuser)

        return Response({
            'points': profile.points,
            'premium_unlocked': profile.premium_unlocked,
            'weight': profile.weight,
            'co2_saved': round(profile.co2_saved, 2),
            'deposits': profile.deposits,
            'full_name': profile.full_name or '',
            'email': user.email or '',
            'phone': profile.phone or '',
            'address': profile.address or '',
            'is_employee': profile.is_employee,
            'is_approved_employee': profile.is_approved_employee,
            'is_root_admin': is_root_admin,
            'is_superuser': user.is_superuser,
            'is_staff': user.is_staff,
            'profile_picture': profile.profile_picture.url if profile.profile_picture else None
        })
    except Exception:
        return Response({'error': 'not found'}, status=404)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def validate_session(request):
    try:
        user = User.objects.get(username=request.user.username)
        if not user.is_active:
            return Response({'error': 'inactive'}, status=401)
        return Response({'message': 'valid'}, status=200)
    except User.DoesNotExist:
        return Response({'error': 'not found'}, status=404)


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def update_profile(request):
    user = request.user
    profile, created = Profile.objects.get_or_create(user=user)
    if 'email' in request.data:
        user.email = request.data.get('email')
        user.save()

    serializer = ProfileSerializer(profile, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response({
            'message': 'updated',
            'profile_picture': profile.profile_picture.url if profile.profile_picture else None
        })
    return Response({'error': str(serializer.errors)}, status=400)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def approve_employee(request):
    admin_email = getattr(settings, 'SUPER_ADMIN_EMAIL', 'admin@smartbin.com')
    if not (request.user.email == admin_email and request.user.is_superuser):
        return Response({'error': 'unauthorized'}, status=403)

    target_username = request.data.get('username')
    action = request.data.get('action')
    try:
        target_user = User.objects.get(username=target_username)
        profile, created = Profile.objects.get_or_create(user=target_user)
        if action == 'approve':
            profile.is_approved_employee = True
            profile.save()
            return Response({'message': 'approved'})
        elif action == 'reject':
            target_user.delete()
            return Response({'message': 'rejected'})
    except Exception as error:
        return Response({'error': str(error)}, status=400)


@ratelimit(key='ip', rate='10/m', block=False)
@api_view(['POST'])
def esp_get_code(request):
    if getattr(request, 'limited', False):
        return Response({'error': 'Too many requests. Try again later.'}, status=429)

    bin_id = request.data.get('bin_id')
    hardware_token = request.data.get('hardware_token')
    try:
        bin_obj, created = Bin.objects.get_or_create(bin_id=bin_id)
        if not created and not verify_hardware_token(bin_obj, hardware_token):
            return Response({'error': 'Unauthorized Hardware'}, status=403)

        if not bin_obj.hardware_token and hardware_token:
            bin_obj.hardware_token = hardware_token
            bin_obj.save()

        if bin_obj.status != 'idle':
            return Response({'code': bin_obj.current_qr_code, 'status': bin_obj.status})

        new_code = str(uuid.uuid4())
        bin_obj.current_qr_code = new_code
        bin_obj.save()
        return Response({'code': new_code, 'status': 'idle'})
    except Exception as error:
        return Response({'error': str(error)}, status=400)


@ratelimit(key='ip', rate='5/m', block=False)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def user_scan_qr(request):
    admin_email = getattr(settings, 'SUPER_ADMIN_EMAIL', 'admin@smartbin.com')
    is_root_admin = (request.user.email == admin_email and request.user.is_superuser)
    if getattr(request, 'limited', False) and not is_root_admin:
        return Response({'error': 'Too many requests. Try again later.'}, status=429)

    code = request.data.get('code')
    user = request.user
    try:
        bin_obj = Bin.objects.get(current_qr_code=code)
        if bin_obj.status != 'idle':
            return Response({'error': 'invalid code'}, status=400)

        bin_obj.current_user = user
        bin_obj.status = 'scanned'
        bin_obj.save()
        broadcast_bin_update()

        broker_url = getattr(settings, 'MQTT_HOST', '127.0.0.1')
        broker_port = getattr(settings, 'MQTT_PORT', 1883)
        broker_user = getattr(settings, 'MQTT_USER', 'smartbin')
        broker_password = getattr(settings, 'MQTT_PASSWORD', 'smartbin123')
        command_payload = json.dumps({"cmd": "OPEN_BIN"})
        try:
            auth = {'username': broker_user, 'password': broker_password} if broker_user else None
            tls = {'tls_version': 2} if int(broker_port) == 8883 else None # TLS enabled
            publish.single(f"smartbin/{bin_obj.bin_id}/command", payload=command_payload, hostname=broker_url, port=int(broker_port), auth=auth, tls=tls)
        except Exception as e:
            print(f"MQTT Error in views: {e}")
        return Response({'message': 'scanned successfully'})
    except Bin.DoesNotExist:
        return Response({'error': 'invalid code'}, status=404)


@ratelimit(key='ip', rate='10/m', block=False)
@api_view(['POST'])
def esp_check_scan(request):
    if getattr(request, 'limited', False):
        return Response({'error': 'Too many requests. Try again later.'}, status=429)

    bin_id = request.data.get('bin_id')
    hardware_token = request.data.get('hardware_token')
    try:
        bin_obj = Bin.objects.get(bin_id=bin_id)
        if not verify_hardware_token(bin_obj, hardware_token):
            return Response({'error': 'Unauthorized Hardware'}, status=403)

        if not bin_obj.hardware_token and hardware_token:
            bin_obj.hardware_token = hardware_token
            bin_obj.save()

        if bin_obj.status == 'scanned':
            bin_obj.status = 'active'
            bin_obj.save()
            broadcast_bin_update()
            return Response({'status': 'YES'})
        return Response({'status': 'NO'})
    except Bin.DoesNotExist:
        return Response({'error': 'bin not found'}, status=404)


@ratelimit(key='ip', rate='10/m', block=False)
@api_view(['POST'])
def esp_end_session(request):
    if getattr(request, 'limited', False):
        return Response({'error': 'Too many requests. Try again later.'}, status=429)

    bin_id = request.data.get('bin_id')
    hardware_token = request.data.get('hardware_token')
    points = int(request.data.get('points', 0))
    weight = float(request.data.get('weight', 0.0))
    material_type = request.data.get('material_type', 'plastic').lower()
    try:
        bin_obj = Bin.objects.get(bin_id=bin_id)
        if not verify_hardware_token(bin_obj, hardware_token):
            return Response({'error': 'Unauthorized Hardware'}, status=403)

        if not bin_obj.hardware_token and hardware_token:
            bin_obj.hardware_token = hardware_token
            bin_obj.save()

        user = bin_obj.current_user
        if user:
            with transaction.atomic():
                profile, created = Profile.objects.select_for_update().get_or_create(user=user)

                weight_g = float(request.data.get('weight_g', request.data.get('weight', 0.0)))
                is_metal_str = request.data.get('is_metal')
                is_metal = str(is_metal_str).lower() == 'true' if is_metal_str is not None else None
                material_type = request.data.get('material', request.data.get('material_type'))
                
                if material_type is not None:
                    material_type = material_type.lower()
                
                from api.services import process_deposit_payload
                process_deposit_payload(profile, weight_g, is_metal=is_metal, material_type=material_type)

        bin_obj.status = 'idle'
        bin_obj.current_user = None
        bin_obj.current_qr_code = None
        
        from django.core.cache import cache
        cached_capacity = cache.get(f"bin_{bin_id}_capacity")
        cached_crowd_level = cache.get(f"bin_{bin_id}_crowd_level")
        if cached_capacity is not None:
            bin_obj.capacity = cached_capacity
        if cached_crowd_level is not None:
            bin_obj.crowd_level = cached_crowd_level
            
        bin_obj.save()
        broadcast_bin_update()
        return Response({'message': 'session ended'})
    except Bin.DoesNotExist:
        return Response({'error': 'bin not found'}, status=404)


@ratelimit(key='ip', rate='10/m', block=False)
@api_view(['POST'])
def esp_update_capacity(request):
    if getattr(request, 'limited', False):
        return Response({'error': 'Too many requests. Try again later.'}, status=429)

    bin_id = request.data.get('bin_id')
    hardware_token = request.data.get('hardware_token')
    capacity = float(request.data.get('capacity', 0.0))
    try:
        bin_obj = Bin.objects.get(bin_id=bin_id)
        if not verify_hardware_token(bin_obj, hardware_token):
            return Response({'error': 'Unauthorized Hardware'}, status=403)

        if not bin_obj.hardware_token and hardware_token:
            bin_obj.hardware_token = hardware_token

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
                pass

        broadcast_bin_update()
        return Response({'message': 'Capacity updated successfully'})
    except Bin.DoesNotExist:
        return Response({'error': 'Bin not found'}, status=404)
    except Exception as error:
        return Response({'error': str(error)}, status=400)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def employee_update_location(request):
    profile, created = Profile.objects.get_or_create(user=request.user)
    if not profile.is_employee or not profile.is_approved_employee:
        return Response({'error': 'unauthorized'}, status=403)

    bin_id = request.data.get('bin_id')
    try:
        bin_obj = Bin.objects.filter(bin_id=bin_id).first()
        if bin_obj:
            serializer = BinSerializer(bin_obj, data=request.data, partial=True)
        else:
            serializer = BinSerializer(data=request.data, partial=True)
        
        if serializer.is_valid():
            serializer.save()
            broadcast_bin_update()
            return Response({'message': 'location updated'})
        else:
            return Response({'error': str(serializer.errors)}, status=400)
    except Exception as error:
        return Response({'error': str(error)}, status=400)


@api_view(['GET'])
def get_all_bins(request):
    lat_str = request.query_params.get('lat')
    lng_str = request.query_params.get('lng')
    page = int(request.query_params.get('page', 1))
    limit = int(request.query_params.get('limit', 10))
    start = (page - 1) * limit
    end = start + limit

    try:
        bins = Bin.objects.all()
        bins_data = BinSerializer(bins, many=True).data

        for b in bins_data:
            cached_capacity = cache.get(f"bin_{b['bin_id']}_capacity")
            if cached_capacity is not None:
                b['capacity'] = cached_capacity
            
            cached_crowd_level = cache.get(f"bin_{b['bin_id']}_crowd_level")
            if cached_crowd_level is not None:
                b['crowd_level'] = cached_crowd_level

        if lat_str and lng_str:
            try:
                u_lat = float(lat_str)
                u_lng = float(lng_str)
                for b in bins_data:
                    if b['lat'] is not None and b['lng'] is not None:
                        dist = haversine(u_lat, u_lng, b['lat'], b['lng'])
                        b['distance_km'] = round(dist, 2)
                    else:
                        b['distance_km'] = None
                bins_data.sort(key=lambda x: x['distance_km'] if x['distance_km'] is not None else float('inf'))
            except ValueError:
                pass

        paginated_data = bins_data[start:end]
        return Response(paginated_data)
    except Exception as e:
        return Response({'error': str(e)}, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_activities(request):
    username = request.query_params.get('username')
    admin_email = getattr(settings, 'SUPER_ADMIN_EMAIL', 'admin@smartbin.com')
    request_is_root = (request.user.email == admin_email and request.user.is_superuser)
    if request.user.username != username and not request_is_root:
        return Response({'error': 'unauthorized'}, status=403)

    page = int(request.query_params.get('page', 1))
    limit = int(request.query_params.get('limit', 10))
    start = (page - 1) * limit
    end = start + limit
    try:
        user = User.objects.get(username=username)
        activities = Activity.objects.filter(user=user)
        
        start_date_str = request.query_params.get('start_date')
        end_date_str = request.query_params.get('end_date')
        
        if start_date_str:
            try:
                activities = activities.filter(date__gte=start_date_str)
            except ValueError:
                pass
                
        if end_date_str:
            try:
                activities = activities.filter(date__lte=end_date_str)
            except ValueError:
                pass
                
        activities = activities.order_by('-date')
        total_activities = activities.count()
        paginated_activities = activities[start:end]
        serializer = ActivitySerializer(paginated_activities, many=True)
        return Response({
            'total_activities': total_activities,
            'page': page,
            'limit': limit,
            'data': serializer.data
        })
    except Exception:
        return Response({'error': 'not found'}, status=404)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_rewards(request):
    username = request.query_params.get('username')
    category_filter = request.query_params.get('category', 'All')
    user_points = 0
    premium_unlocked = False

    if username:
        try:
            u = User.objects.get(username=username)
            p, created = Profile.objects.get_or_create(user=u)
            user_points = p.points
            premium_unlocked = p.premium_unlocked
        except Exception:
            pass

    rewards = Reward.objects.all()
    if category_filter.strip().lower() != 'all':
        normalized_cat = category_filter.strip().lower()
        rewards = rewards.filter(category__iexact=normalized_cat)

    data = []
    now = timezone.now()

    for r in rewards:
        if r.is_premium and user_points < 1000:
            continue

        r_data = RewardSerializer(r, context={'request': request}).data

        is_expired = r.valid_until and r.valid_until < now.date()
        is_out_of_stock = r.stock_quantity == 0

        if r.dynamic_limit > 0 and username:
            user_redeemed_count = RedeemedReward.objects.filter(user__username=username, reward=r).count()
            if user_redeemed_count >= r.dynamic_limit:
                is_out_of_stock = True

        if is_expired:
            r_data['status'] = 'expired'
            r_data['progress_percentage'] = 0.0
        elif is_out_of_stock:
            r_data['status'] = 'out_of_stock'
            r_data['progress_percentage'] = 0.0
        elif r.is_premium and not premium_unlocked:
            r_data['status'] = 'locked'
            r_data['progress_percentage'] = min(user_points / 1000.0, 1.0)
        elif user_points >= r.required_points:
            r_data['status'] = 'redeem'
            r_data['progress_percentage'] = 1.0
        else:
            r_data['status'] = 'locked'
            target = r.required_points
            r_data['progress_percentage'] = min(user_points / target, 1.0) if target > 0 else 0.0

        data.append(r_data)

    points_left = 1000 - user_points if user_points < 1000 else 0
    return Response({
        'rewards': data,
        'user_points': user_points,
        'points_left': points_left,
        'premium_unlocked': premium_unlocked,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@transaction.atomic
def redeem_reward(request):
    reward_id = request.data.get('reward_id')
    original_price = request.data.get('original_price')
    user = request.user
    try:
        profile, created = Profile.objects.select_for_update().get_or_create(user=user)
        reward = Reward.objects.select_for_update().get(id=reward_id)
        now = timezone.now()

        if reward.valid_until and reward.valid_until < now.date():
            return Response({'error': 'reward expired'}, status=400)

        if reward.stock_quantity == 0:
            return Response({'error': 'reward out of stock'}, status=400)

        if reward.dynamic_limit > 0:
            user_redeemed_count = RedeemedReward.objects.filter(user=user, reward=reward).count()
            if user_redeemed_count >= reward.dynamic_limit:
                return Response({'error': 'reward limit reached'}, status=400)

        if reward.is_premium and not profile.premium_unlocked:
            return Response({'error': 'premium rewards locked'}, status=400)



        if profile.points < reward.required_points:
            return Response({'error': 'not enough points to unlock/redeem'}, status=400)

        profile.points -= reward.required_points
        profile.save()

        if reward.stock_quantity > 0:
            reward.stock_quantity -= 1
            reward.save()

        import string
        import random
        promo_code = 'SB-' + ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))

        RedeemedReward.objects.create(user=user, reward=reward, promo_code=promo_code)
        response_data = {
            'message': 'redeemed successfully',
            'new_points': profile.points,
            'promo_code': promo_code
        }

        if reward.discount_percentage is not None and original_price is not None:
            price = float(original_price)
            discount_amount = price * (reward.discount_percentage / 100.0)
            final_price = price - discount_amount
            response_data['discount_percentage'] = reward.discount_percentage
            response_data['original_price'] = price
            response_data['discount_amount'] = discount_amount
            response_data['final_price'] = final_price

        return Response(response_data)
    except Reward.DoesNotExist:
        return Response({'error': 'invalid reward'}, status=404)
    except Exception as error:
        return Response({'error': str(error)}, status=400)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_stats(request):
    admin_email = getattr(settings, 'SUPER_ADMIN_EMAIL', 'admin@smartbin.com')
    if not (request.user.email == admin_email and request.user.is_superuser):
        return Response({'error': 'unauthorized'}, status=403)

    try:
        total_co2 = Profile.objects.aggregate(Sum('co2_saved'))['co2_saved__sum'] or 0.0
        total_deposits = Profile.objects.aggregate(Sum('deposits'))['deposits__sum'] or 0
        peak_hours = list(Activity.objects.annotate(hour=ExtractHour('date')).values('hour').annotate(count=Count('id')))
        employees = Profile.objects.filter(is_employee=True).values('user__username', 'full_name', 'is_approved_employee')

        return Response({
            'total_co2_saved': round(total_co2, 2),
            'total_usage_rate': total_deposits,
            'peak_hours': peak_hours,
            'employees': list(employees)
        })
    except Exception as e:
        return Response({'error': str(e)}, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_redemption_history(request):
    try:
        user = request.user
        history = RedeemedReward.objects.filter(user=user).select_related('reward')
        
        start_date_str = request.query_params.get('start_date')
        end_date_str = request.query_params.get('end_date')
        
        if start_date_str:
            try:
                history = history.filter(redeemed_at__gte=start_date_str)
            except ValueError:
                pass
                
        if end_date_str:
            try:
                history = history.filter(redeemed_at__lte=end_date_str)
            except ValueError:
                pass
                
        history = history.order_by('-redeemed_at')
        data = []
        for h in history:
            data.append({
                'id': h.id,
                'reward_name': h.reward.name,
                'icon_category': h.reward.icon_category,
                'redeemed_at': h.redeemed_at.isoformat() if h.redeemed_at else None,
                'promo_code': h.promo_code
            })
        return Response({'history': data})
    except Exception as e:
        return Response({'error': str(e)}, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_leaderboard(request):
    try:
        top_profiles = Profile.objects.filter(is_employee=False, is_approved_employee=False).order_by('-co2_saved', '-points')[:50]
        data = []
        for rank, p in enumerate(top_profiles, start=1):
            data.append({
                'rank': rank,
                'username': p.user.username,
                'points': p.points,
                'co2_saved': round(p.co2_saved, 2),
                'profile_picture': p.profile_picture.url if p.profile_picture else None
            })
        return Response(data, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


import hmac
import hashlib

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def sync_ble_offline(request):
    try:
        user = request.user
        payload = request.data.get('payload')
        signature = request.data.get('signature')
        bin_id = request.data.get('bin_id')
        
        if not payload or not signature or not bin_id:
            return Response({'error': 'Missing data'}, status=status.HTTP_400_BAD_REQUEST)
            
        bin_obj = Bin.objects.filter(bin_id=bin_id).first()
        if not bin_obj or not bin_obj.hardware_token:
            return Response({'error': 'Invalid bin'}, status=status.HTTP_400_BAD_REQUEST)
            
        secret_key = bin_obj.hardware_token.encode('utf-8')
        payload_bytes = json.dumps(payload, separators=(',', ':')).encode('utf-8')
        expected_signature = hmac.new(secret_key, payload_bytes, hashlib.sha256).hexdigest()
        
        if not hmac.compare_digest(expected_signature, signature):
            return Response({'error': 'Invalid signature'}, status=status.HTTP_403_FORBIDDEN)
            
        sessions = payload if isinstance(payload, list) else [payload]
        profile, _ = Profile.objects.get_or_create(user=user)
        
        from api.services import process_deposit_payload
        for session in sessions:
            weight_g = float(session.get('weight_g', session.get('weight', 0.0)))
            is_metal_str = session.get('is_metal')
            is_metal = str(is_metal_str).lower() == 'true' if is_metal_str is not None else None
            material_type = session.get('material', session.get('material_type'))
            if material_type:
                material_type = material_type.lower()
                
            process_deposit_payload(profile, weight_g, is_metal=is_metal, material_type=material_type)
            
        return Response({'message': 'Offline data synced successfully'}, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)