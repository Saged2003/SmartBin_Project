import requests
import time
BASE_URL = 'http://10.149.11.200:8000/api'
BIN_ID = 'BIN-001'
print('=======================================')
print('🤖 ESP32 Simulator Started...')
print('=======================================\n')
print('1. Asking server for a new QR Code...')
response = requests.post(f'{BASE_URL}/esp/get-code/', json={'bin_id': BIN_ID})
if response.status_code == 200:
    code = response.json().get('code')
    print(f'✅ Success! The new code is: {code}\n')
    print('📱 ACTION REQUIRED IN APP:')
    print("   Open your Flutter App, tap 'Enter Code' and type/paste the code above.")
    print("   (Or use a free online QR generator to make a QR from this code and scan it with the app's camera!)\n")
else:
    print('❌ Error getting code:', response.text)
    exit()
input('👉 Press ENTER here ONLY AFTER you have successfully scanned/entered the code in the app...')
print('\n2. User finished dropping waste. Sending points to server...')
points_earned = 50
weight_dropped = 2.5
end_response = requests.post(f'{BASE_URL}/esp/end-session/', json={'bin_id': BIN_ID, 'points': points_earned, 'weight': weight_dropped})
if end_response.status_code == 200:
    print(f'✅ Success! Sent {points_earned} points and {weight_dropped}kg to the user.')
    print('🎉 Now go check the App (Home or Profile), pull to refresh or change tabs, and see your points!\n')
else:
    print('❌ Error ending session:', end_response.text)