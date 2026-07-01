# SmartBin Standalone Gateway Test Guide

This guide provides a comprehensive, step-by-step checklist to safely execute the standalone `TEST_MODE` for the ESP32 Gateway and verify the entire end-to-end ecosystem (ESP32 -> Django -> Flutter).

## 1. Pre-Flight Checklist

Before flashing the hardware, ensure your environment is configured correctly.

**A. ESP32 Code Configuration (`main.cpp`)**
Locate the global variables section at the top of your `src/main.cpp` (or where you defined `TEST_MODE`) and verify the following:
- **Test Mode Enable**: Ensure the test mode boolean is set to true.
  ```cpp
  bool TEST_MODE = true;
  ```
- **Wi-Fi Credentials**:
  ```cpp
  const char *ssid = "YOUR_WIFI_SSID";
  const char *password = "YOUR_WIFI_PASSWORD";
  ```
- **Cloud MQTT Details**:
  ```cpp
  const char *mqtt_host = "YOUR_CLOUD_BROKER_URL";
  const int mqtt_port = 8883; // Must be 8883 for Secure MQTT (TLS/SSL)
  const char *mqtt_user = "YOUR_MQTT_USER";
  const char *mqtt_password = "YOUR_MQTT_PASSWORD";
  ```

**B. Backend Configuration**
Ensure your Django application and MQTT listeners are actively running.
1. **Django Server**: Start your Daphne/Channels ASGI server.
   ```bash
   python manage.py runserver 
   # or daphne <project_name>.asgi:application
   ```
2. **MQTT Listener**: Start your standalone Python MQTT listener script (e.g., `mqtt_listener.py` or management command) that ingests IoT data to your Django DB.

---

## 2. Flashing & Hardware Boot

**A. Connect and Flash**
1. Connect the ESP32-S3 Gateway to your computer via USB.
2. In VS Code (PlatformIO), ensure the correct `COM` port is selected in the bottom taskbar.
3. Click the **Upload** (right arrow) button to compile and flash the C++ code to the ESP32.

**B. Serial Monitor Setup**
1. Open the PlatformIO Serial Monitor (plug icon).
2. Ensure the baud rate is set to **115200** (this matches `Serial.begin(115200);` in `setup()`).

**C. Verification Logs**
Upon successful boot, you must see the following sequence in the Serial Monitor:
```text
Connecting to YOUR_WIFI_SSID
.......
WiFi connected
IP address: 192.168.x.x
>>> ESP32-S3 IoT Gateway Ready <<<
Attempting MQTT connection...connected
```
*If it fails to connect to MQTT, it will print `failed, rc=... try again in 5 seconds`.*

---

## 3. Testing Scenario 1: ESP32 to App (Mock Data Pipeline)

Because `TEST_MODE = true` is enabled, the ESP32 will simulate internal sensor communications and publish mock data (e.g., 50% bin capacity) automatically every 10 seconds.

**A. ESP32 Serial Monitor**
Look for a repeating log indicating the mocked sensor payload is being sent to the Cloud MQTT broker. It should look something like:
```text
[TEST MODE] Publishing mock update to smartbin/BIN-01/update: {"hardware_token":"secret-token-123","capacity":50.0}
```

**B. Django Terminal**
Look at your MQTT listener/Django terminal. It should acknowledge receipt of the message and DB save:
```text
[MQTT] Received message on topic smartbin/BIN-01/update
[DB] Saved updated capacity (50.0%) for Bin: BIN-01
[WebSocket] Broadcasting capacity update to active Flutter clients...
```

**C. Flutter App UI**
Open the Flutter app and navigate to the Bin Status screen. 
- You should see the capacity dynamically update to **50%**.
- This should happen in real-time (via WebSockets/SSE) **without** you needing to manually refresh or pull down the screen.

---

## 4. Testing Scenario 2: App to ESP32 (QR Scan / Open Command)

This tests the reverse pipeline: the Flutter App pushing an action through the cloud down to the physical bin.

**A. Action in Flutter App**
1. Navigate to the Scanner/Home tab in the Flutter app.
2. Perform the action: Tap the **"Open Bin"** button (or simulate scanning the active QR code for `BIN-01`).

**B. Django Terminal**
Look at your Django web server logs for the incoming HTTP/API request:
```text
POST /api/bins/open_command/ HTTP/1.1" 200 OK
[MQTT] Publishing command 'OPEN_BIN' to topic smartbin/BIN-01/command
```

**C. ESP32 Serial Monitor**
Watch the Serial Monitor immediately after pressing the button. You MUST see the incoming MQTT payload and the subsequent activation command sent to the internal components:
```text
Message arrived [smartbin/BIN-01/command]: {"cmd":"OPEN_BIN"}
start
```
*(Note: `start` is printed by `Serial1.println("start");` when the `START_BIN` or `OPEN_BIN` command triggers the `S3AppController` state change).*

---
**Troubleshooting**: If Scenario 2 fails, verify that the ESP32 successfully subscribed to the `smartbin/BIN-01/command` topic during boot, and ensure your Flutter app is targeting the correct `BIN_ID`.
