# ULTIMATE SYSTEM RUNBOOK
**The Definitive End-to-End Testing & Deployment Manual for the SmartBin Ecosystem**

This manual serves as the absolute source of truth for deploying, testing, and verifying the entire 4-part system simultaneously: Django Backend, Flutter Frontend, ESP32 Gateway Node, and ESP32 Sensor Node.

---

## 1. Pre-requisites & IP Configuration

To ensure all 4 components can communicate over the local network, they must all point to the IP address of the machine hosting the backend (Django, Redis, Mosquitto).

### Step 1.1: Extract Host IPv4 Address
1. Open a PowerShell/Command Prompt terminal.
2. Run the command: `ipconfig`
3. Locate your active Wireless LAN adapter and note the `IPv4 Address` (e.g., `192.168.1.100`). This is your **HOST_IP**.

### Step 1.2: Update File Paths
You MUST update the hardcoded IP addresses in the following files before booting the system.

**Django Backend:**
- File: `SmartBin_API/backend/settings.py`
  - Update `MQTT_BROKER_URL` to your `HOST_IP`. (Ensure Redis is running on localhost, or update `REDIS_URL` if needed).

**Flutter Frontend:**
- File: `smart_bin_application/lib/api_constants.dart`
  - Update `baseUrl`: `http://<HOST_IP>:8000/api`
  - Update `mediaUrl`: `http://<HOST_IP>:8000`

**ESP32 Gateway Node:**
- File: `smartBin2-main/smartBin2-main/src/main.cpp` (or corresponding main file)
  - Update `mqtt_server` variable: `const char *mqtt_server = "<HOST_IP>";`
  - Ensure the Wi-Fi `ssid` and `password` match your network.

---

## 2. Backend Boot Sequence

The backend ecosystem consists of 4 independent services that must be running simultaneously. Open 4 separate terminal windows.

### Terminal 1: Redis Server (for WebSockets)
- **Command:** `redis-server` (or run via WSL/Docker if on Windows)
- **Expected Log:** `Ready to accept connections tcp`

### Terminal 2: Mosquitto MQTT Broker
- **Command:** `mosquitto -v`
- **Expected Log:** `mosquitto version <version> running`

### Terminal 3: Django Daphne Server (API & WebSockets)
- **Navigate:** `cd SmartBin_API`
- **Command:** `daphne backend.asgi:application` OR `python manage.py runserver 0.0.0.0:8000`
- **Expected Log:** `Starting ASGI/Channels version...` / `Application instance starting...`

### Terminal 4: Custom MQTT Background Listener
- **Navigate:** `cd SmartBin_API`
- **Command:** `python manage.py run_mqtt_listener`
- **Expected Log:** `Connected to MQTT broker with result code 0` / `Subscribed to sensor topics`

> [!IMPORTANT]
> Verify that Terminal 2 (Mosquitto) shows a connection log from the Django MQTT listener (e.g., `New client connected`).

---

## 3. Hardware Wiring & Flashing (Dual Node)

### 3.1 Hardware Wiring

**UART Cross-Wiring (Communication between nodes):**
- **Gateway Node Tx** $\rightarrow$ **Sensor Node Rx**
- **Gateway Node Rx** $\rightarrow$ **Sensor Node Tx**
- **Shared Ground:** Connect the GND pin of the Gateway Node to the GND pin of the Sensor Node. This is strictly required for reliable UART communication.

**Peripherals:**
- **Sensor Node:** Connect the Ultrasonic Sensor (Trig/Echo) and the Servo Motor signal pin.
- **Gateway Node:** Ensure it has sufficient power to maintain Wi-Fi and MQTT connections continuously.

### 3.2 Pre-flight Code Check
Before compiling and flashing to the ESP32s:
- **MQTT v2 API:** Verify that the Gateway codebase utilizes MQTT Callback API version 2 for robust, non-blocking reconnections.
- **Identifiers:** Ensure all variables and JSON keys use standard technical identifiers (e.g., `bin_capacity`, `distance_cm`). Ensure no personal names or arbitrary labels exist in the JSON payload structures.

### 3.3 Flashing & Verification
Flash the Sensor Node, then flash the Gateway Node. Open the Serial Monitor for the Gateway Node (Baud Rate: 115200).

**Expected Serial Monitor Outputs:**
1. `Connecting to WiFi...`
2. `WiFi connected. IP address: 192.168.x.x`
3. `Attempting MQTT connection...`
4. `MQTT Connected.`
5. `Subscribed to topic: smartbin/command/open` (or similar)

---

## 4. Frontend Boot Sequence

1. Open a new terminal and navigate to the Flutter project: `cd smart_bin_application`
2. **Clean Project:** `flutter clean`
3. **Get Dependencies:** `flutter pub get`
4. **Run Application:** `flutter run` (Select your connected device or emulator)

**Verification:**
- Ensure the app launches and can fetch data on the home screen (verifies REST API connection to Django).
- Verify no WebSocket connection errors are thrown in the Flutter debug console.

---

## 5. "Live" End-to-End Verification Scenarios (The Ultimate Test)

To prove the entire ecosystem is flawlessly integrated, execute these two real-time scenarios and observe the logs.

### Scenario A: Waste Detection Loop (Hardware $\rightarrow$ Frontend)
**Action:** Place an object in front of the ultrasonic sensor to simulate waste.

**Verification Checkpoints (Strict Order):**
1. **Sensor Node (Serial Monitor):** `Distance calculated: X cm` $\rightarrow$ `Transmitting UART payload: {"distance": X}`
2. **Gateway Node (Serial Monitor):** `Received UART data: {"distance": X}` $\rightarrow$ `Publishing to MQTT topic smartbin/sensor_data: {"capacity": Y%}`
3. **Mosquitto (Terminal 2):** `Received PUBLISH from <gateway_client_id> (d0, q0, r0, m0, 'smartbin/sensor_data', ...)`
4. **MQTT Listener (Terminal 4):** `Received message on topic smartbin/sensor_data` $\rightarrow$ `Processed capacity update: Y%`
5. **Django Console (Terminal 3):** `WebSocket Broadcast: Sending capacity update to group 'bin_updates'`
6. **Flutter App (UI & Debug Console):** Debug console shows `WebSocket message received: {"type": "capacity_update", "value": Y}` $\rightarrow$ The physical device UI animates/updates to reflect the new capacity.

### Scenario B: QR Scan to Servo Loop (Frontend $\rightarrow$ Hardware)
**Action:** Tap the "Scan QR to Open" button in the Flutter app (or trigger the respective API call).

**Verification Checkpoints (Strict Order):**
1. **Flutter App (Debug Console):** `Sending POST request to /api/qr-scan with payload...`
2. **Django Console (Terminal 3):** `POST /api/qr-scan HTTP/1.1 200 OK` $\rightarrow$ `QR Validated. Initiating bin open command.`
3. **Mosquitto (Terminal 2):** `Received PUBLISH from <django_client_id> (d0, q0, r0, m0, 'smartbin/command/open', ...)`
4. **Gateway Node (Serial Monitor):** `MQTT Callback Triggered. Topic: smartbin/command/open, Message: {"action": "open"}` $\rightarrow$ `Sending UART command to Sensor Node: O`
5. **Sensor Node (Serial Monitor):** `Received UART command: O` $\rightarrow$ `Actuating servo to 90 degrees.` $\rightarrow$ (Physical servo mechanism physically opens).

> [!TIP]
> If any step in these scenarios fails to produce the expected log, the break in the chain is exactly at that point. Use this to rapidly isolate network, routing, or parsing errors.
