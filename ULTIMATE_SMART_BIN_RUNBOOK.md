# ULTIMATE SMART BIN RUNBOOK

> [!IMPORTANT]
> This runbook is the definitive guide to configure, launch, and test the entire Smart Bin ecosystem end-to-end. Follow these instructions precisely to ensure the Dual ESP32 setup, Django backend, and Flutter frontend communicate flawlessly.

## 1. Environment & IP Configuration

Before starting any service, the local IP address must be synchronized across all components.

### 1.1 Find Your Host IP Address (Windows)
1. Open PowerShell or Command Prompt.
2. Run the command: `ipconfig`
3. Look for the `IPv4 Address` under your active network adapter (e.g., Wireless LAN adapter Wi-Fi).
4. Example: `192.168.1.100`. Use this IP for all configurations below.

### 1.2 Configuration Checklist

> [!CAUTION]
> Failure to update the IP in ANY of these files will result in broken communication.

#### Django Backend (SmartBin_API)
- [ ] `settings.py` (or your `.env` file): Update `ALLOWED_HOSTS = ['192.168.1.100', 'localhost', '127.0.0.1']`
- [ ] MQTT Configuration (usually in `settings.py` or a dedicated `mqtt.py`): Ensure `MQTT_BROKER_HOST = '192.168.1.100'`
- [ ] Redis Configuration: Ensure Redis is pointing to the correct host if not using `localhost`.

#### Flutter Frontend (smart_bin_application)
- [ ] API Base URL: Update your API constants file (e.g., `lib/core/constants/api_constants.dart` or similar) to `http://192.168.1.100:8000/` or specific api path.
- [ ] WebSockets URL: Update the WebSocket connection string to `ws://192.168.1.100:8000/ws/`

#### ESP32 Hardware (smartBin2-main / Smart-Waste-Bin-ESP32-main)
- [ ] Gateway Node (`main.cpp` or config file): 
  - Update `WIFI_SSID` and `WIFI_PASSWORD` to match your local network.
  - Update `MQTT_SERVER` or `MQTT_BROKER` to `'192.168.1.100'`.

---

## 2. Backend Boot Sequence (Django & Services)

Launch these services in separate terminal windows.

### 2.1 Start Redis Server
Redis is required for WebSockets/Channels to manage real-time communication.
**Command (if using WSL or native Redis on Windows):**
```bash
redis-server
```
**Verification Log:** Look for `Ready to accept connections`.

### 2.2 Start Mosquitto MQTT Broker
**Command:**
```bash
mosquitto -v
```
*(Use `-v` for verbose logging to see incoming connections).*
**Verification Log:** Look for `mosquitto version X.X.X running`.

### 2.3 Start Django ASGI Server (Daphne/Uvicorn)
To support both HTTP requests and WebSockets.
**Command:**
```bash
cd SmartBin_API
python manage.py runserver 0.0.0.0:8000
```
*(Alternatively, use Daphne/Uvicorn if configured for production-like testing).*
**Verification Log:** Look for `Starting ASGI/Channels version...` and `Quit the server with CTRL-BREAK`.

### 2.4 Start MQTT Background Listener
Runs a persistent loop to capture hardware telemetry and save it to the DB.
**Command:**
```bash
cd SmartBin_API
python manage.py run_mqtt_listener
```
*(Or your specific management command script).*
**Verification Log:** Look for `Connected to MQTT Broker with result code 0` and `Subscribed to topic: #` (or specific topics).

### 2.5 Verify Jazzmin Admin Dashboard
1. Open a browser and navigate to `http://192.168.1.100:8000/admin/`
2. Log in with your superuser credentials.
3. Verify the Jazzmin themed UI loads and database tables (like Bin Status/Telemetry) are accessible.

---

## 3. Hardware Setup & Flashing (Dual ESP32)

### 3.1 Wiring Guide
> [!WARNING]
> Do not cross 5V and 3.3V power rails. Ensure both ESP32 boards share a common Ground (GND).

**Sensor Node (Handles Sensors/Actuators):**
- Connected to Ultrasonic Sensor (Trig/Echo).
- Connected to Servo Motor (PWM pin).
- **UART Wiring:** TX Pin -> Gateway RX Pin | RX Pin -> Gateway TX Pin.
- **Power:** GND -> Common GND rail.

**Gateway Node (Handles Wi-Fi & MQTT):**
- **UART Wiring:** TX Pin -> Sensor Node RX Pin | RX Pin -> Sensor Node TX Pin.
- **Power:** GND -> Common GND rail.

### 3.2 Flashing & Serial Monitoring
1. Connect the **Sensor Node** via USB. Select its COM port in your IDE (Arduino/PlatformIO) and upload its specific firmware.
2. Connect the **Gateway Node** via USB. Select its COM port, upload its firmware.
3. Open the Serial Monitor for the **Gateway Node** (Baud rate typically 115200).

**Expected Gateway Serial Logs:**
```text
Connecting to WiFi...
WiFi connected! IP: 192.168.1.101
Connecting to MQTT Broker...
MQTT Connected!
UART Initialized. Waiting for Sensor Node data...
```

---

## 4. Frontend Boot Sequence (Flutter)

### 4.1 Build and Run
1. Navigate to the Flutter project folder.
**Commands:**
```bash
cd smart_bin_application
flutter clean
flutter pub get
flutter run
```

### 4.2 Verify Real-Time Connection
- Upon app launch, check the Flutter debug console.
- **Expected Logs:** Look for logs indicating HTTP success (`GET /api/... - 200 OK`) and WebSocket connection (`WebSocket channel connected to ws://192.168.1.100:8000/...`).

---

## 5. The "Full Circle" Verification Scenarios

> [!TIP]
> Perform these scenarios to prove complete bi-directional integration across all layers of the stack.

### Scenario A: Hardware to UI (Telemetry Flow)
**Action:** Place an object (simulating trash) in front of the Sensor Node's Ultrasonic sensor.

**Expected Exact Path & Logs:**
1. **Sensor Node:** Detects distance change. Computes new capacity percentage.
2. **UART Transfer:** Sensor Node sends payload over Serial TX to Gateway Node RX.
3. **Gateway Node:** Receives payload, formats as JSON.
   - *Serial Log:* `Publishing to topic smartbin/telemetry: {"capacity": 85}`
4. **MQTT Broker:** Routes the message.
   - *Mosquitto Log:* `Received PUBLISH from gatewayClient...`
5. **Django Listener:** Captures the MQTT message.
   - *Django Terminal Log:* `Received message on smartbin/telemetry. Saving to DB...`
6. **Database Save:** Django ORM writes a new telemetry record.
7. **WebSocket Broadcast:** Django Channels triggers a group send to all connected clients.
8. **Flutter UI:** App receives WebSocket frame and dynamically updates the Bin Capacity gauge/progress bar without requiring a manual pull-to-refresh.

### Scenario B: UI to Hardware (Actuation Flow)
**Action:** Press the "Open Lid" button or scan a valid QR code in the Flutter app.

**Expected Exact Path & Logs:**
1. **Flutter App:** Sends a POST request or WebSocket command to the backend.
2. **Django API:** Receives the request, validates it.
   - *Django Server Log:* `POST /api/commands/open-lid - 200 OK`
3. **Django MQTT Publish:** Backend publishes a command to the MQTT broker.
   - *Mosquitto Log:* `Received PUBLISH from djangoServer (topic: smartbin/commands)...`
4. **Gateway Node:** Receives the MQTT message (subscribed to command topic).
   - *Serial Log:* `Message arrived on topic: smartbin/commands. Payload: {"command":"open"}`
5. **UART Transfer:** Gateway Node sends simple command char (e.g., 'O') via TX to Sensor Node RX.
6. **Sensor Node:** Parses the UART command and triggers the Servo Motor logic.
7. **Servo Actuates:** The physical bin lid opens!
