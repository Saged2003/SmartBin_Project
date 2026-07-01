# MASTER DEPLOYMENT MANUAL

This document is the definitive operational guide for deploying, configuring, and verifying the 4-part Smart Bin Ecosystem: Django backend, Flutter mobile application, Gateway ESP32 (Node 1), and Sensor/Action ESP32 (Node 2).

## 1. System Architecture Overview
The system relies on four interconnected components that communicate over standard IP networks, MQTT, and UART:
- **Django Backend:** Acts as the central nervous system. It provides REST APIs for the Flutter application, serves WebSockets (via Daphne ASGI server) for real-time UI updates, and bridges HTTP data to the MQTT broker.
- **Flutter Application:** The user-facing mobile frontend. It interacts with Django via HTTP POST/GET requests and listens to WebSocket channels for live feedback.
- **Gateway ESP32 (Node 1):** The network interface for the physical hardware. It connects to the local WiFi, subscribes to Mosquitto MQTT topics, and relays backend commands downstream via a physical UART connection.
- **Sensor/Action ESP32 (Node 2):** The physical execution unit. It receives UART commands from Node 1, drives the servos to open the bin lid, reads ultrasonic sensor data, and sends status reports back up the UART chain.

## 2. Pre-flight & Network Unity
To ensure seamless communication, all components must reside on the same local area network without isolation.
1. **Connect Host PC and ESP32s** to the same 2.4GHz WiFi network (e.g., `YOUR_WIFI_SSID`).
2. **Disable AP-Isolation** (Client Isolation) on your router to allow devices to discover each other.
3. **Extract Host IPv4:**
   - On Windows, open PowerShell and type: `ipconfig`
   - Locate your active Wireless LAN adapter and note the `IPv4 Address` (e.g., `192.168.1.2`). This IP will serve as your global `BASE_URL` and `MQTT_SERVER`.

## 3. Backend Full Sequence
Execute these commands sequentially in separate terminal instances from your project root (`SmartBin_API`):

1. **Start Redis Server:**
   ```bash
   redis-server
   ```
2. **Start Mosquitto MQTT Broker:**
   Ensure your `mosquitto.conf` permits anonymous connections and listens on `0.0.0.0` (or `listener 1883 0.0.0.0` / `allow_anonymous true`).
   ```bash
   mosquitto -c /path/to/mosquitto.conf -v
   ```
3. **Activate Virtual Environment & Apply Migrations:**
   ```bash
   venv\Scripts\activate
   python manage.py makemigrations
   python manage.py migrate
   ```
4. **Seed the Database:**
   ```bash
   python manage.py seed_rewards
   ```
5. **Run the MQTT Background Listener:**
   ```bash
   python manage.py run_mqtt
   ```
6. **Launch Daphne ASGI Server:**
   ```bash
   daphne backend.asgi:application -b 0.0.0.0 -p 8000
   ```

## 4. Hardware Wiring & Flashing (Dual Node)

### Node 1 (Gateway ESP32) - `smartBin2-main` Project
1. Open `src/main.cpp` in the Gateway project.
2. Update the network credentials and MQTT IP to match your host PC:
   ```cpp
   const char *ssid = "YOUR_WIFI_SSID";
   const char *password = "YOUR_WIFI_PASSWORD";
   const char *mqtt_server = "YOUR_HOST_IPV4"; // e.g., "192.168.1.2"
   ```
3. Flash the code to the Gateway Node.

### Node 2 (Sensor/Action ESP32) - `Smart-Waste-Bin-ESP32-main` Project
1. **Wiring Specifications:**
   - **Ultrasonic Sensor (HC-SR04):** VCC to 5V (or 3.3V depending on tolerance), GND to GND, TRIG to pin 5, ECHO to pin 18.
   - **Servos:** Signal wires to Motor Controller pins (e.g., Plastic Servo to pin 13, Metal Servo to pin 12).
   - **Cross-UART Wiring to Node 1:**
     - Connect **Node 1 TX** to **Node 2 RX**.
     - Connect **Node 1 RX** to **Node 2 TX**.
     - **CRITICAL:** Connect **Node 1 GND** to **Node 2 GND**.
2. Flash the code to the Sensor/Action Node.

## 5. Frontend Setup
In the Flutter codebase (`smart_bin_application`), update the API constants to point to the host PC running Django:
1. Open `lib/api_constants.dart`.
2. Update the base URL using your host IPv4 address:
   ```dart
   static const String baseUrl = 'http://YOUR_HOST_IPV4:8000/api'; // e.g., 'http://192.168.1.2:8000/api'
   ```
3. Run the Flutter application:
   ```bash
   flutter run
   ```

## 6. The End-to-End Live Scenario
1. **User Action:** The user taps "Scan QR" in the Flutter App and successfully scans the bin's physical QR code.
2. **Flutter HTTP POST:** The app sends `{"code": "..."}` to the Django endpoint `/user/scan-qr/`.
3. **Django Processing:** Django validates the QR, updates the Bin status in the DB, and broadcasts a WebSocket message to update the frontend.
4. **MQTT Dispatch:** Django simultaneously publishes `{"cmd": "START_BIN"}` to Mosquitto under the topic `smartbin/{bin_id}/command`.
5. **Gateway MQTT Callback:** Node 1 receives the MQTT message, parses the JSON, and sends the string `"start"` over its TX pin.
6. **Sensor Action Trigger:** Node 2 receives `"start"` on its RX pin via UART, wakes up the servo motors to open the lid, and begins listening to the ultrasonic sensors for waste disposal.

## 7. Troubleshooting Guide
- **WebSockets not connecting in Flutter:**
  - Verify Daphne is running and not just the standard `runserver`.
  - Ensure the host firewall (Windows Defender) allows inbound connections on port 8000.
- **ESP32 fails to connect to MQTT:**
  - Check the Mosquitto terminal for connection refusal logs.
  - Ensure `mosquitto.conf` has `allow_anonymous true` and `listener 1883 0.0.0.0`.
  - Verify `mqtt_server` in Node 1's `main.cpp` perfectly matches the host's IPv4 address.
- **UART Data Garbled or Missing:**
  - Double-check that TX goes to RX and RX goes to TX.
  - **Most common fix:** Ensure the GND pins of both ESP32 boards are connected together. Without a shared ground, UART signals will float and corrupt.

---

# END-TO-END QR SCAN INTEGRATION AUDIT

An unbroken signal chain verification checklist to monitor during testing:

### 1. Flutter Scanner (Console Output)
- **Action:** Point the camera at a valid QR Code.
- **Verify:** Monitor the Flutter Debug Console. Look for a successful `POST` request to `/user/scan-qr/` returning `Status Code: 200`.

### 2. Django API / Daphne Server
- **Action:** Monitor the terminal running Daphne.
- **Verify:** Look for the incoming HTTP POST request to `/api/user/scan-qr/`.
- **Verify:** Look for WebSocket broadcast logs showing `scanned successfully` or status change.

### 3. Mosquitto Broker Logs
- **Action:** Monitor the terminal running `mosquitto -v`.
- **Verify:** Ensure you see a log output showing a `PUBLISH` event to the topic `smartbin/<BIN_ID>/command` with the payload containing `{"cmd": "START_BIN"}`.

### 4. ESP32 Gateway Node (Serial Monitor - 115200 baud)
- **Action:** Open the Serial Monitor connected to Node 1.
- **Verify:** Look for the MQTT callback log: `Message arrived [smartbin/BIN001/command]: {"cmd": "START_BIN"}`.
- **Verify:** Immediately following, look for logs indicating the command is being forwarded to the S3AppController (`START_BIN` dispatched).

### 5. ESP32 Sensor Node (Serial Monitor - 115200 baud)
- **Action:** Open the Serial Monitor connected to Node 2.
- **Verify:** Look for UART reception log: `>>> Gateway command received! Starting Session...`.
- **Verify:** Listen for the physical servo motor engaging to tilt the lid and open the bin.
