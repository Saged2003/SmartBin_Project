
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
