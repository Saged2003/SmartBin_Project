# ULTIMATE GATEWAY DEEP TEST MANUAL

**Purpose:** This document is the definitive, academic-grade runbook for executing an end-to-end integration test of the Smart Bin Ecosystem. It covers the exact procedures, underlying data flows, and configuration locations required to validate the ESP32 Gateway, the Django Web/WebSocket Backend, and the Flutter Mobile Application functioning synchronously over a global Cloud MQTT architecture.

---

## SECTION 1: The Pre-Flight Code Configuration (The "Where" & "How")

Before hardware is flashed or servers are booted, the software state must be precisely aligned. We must configure the Wi-Fi credentials, the Cloud MQTT Broker (HiveMQ) credentials, and activate the internal hardware test mock.

### 1.1 Configuring the ESP32 Firmware (C++)
**File Location:** Typically found in `src/main.cpp` or a dedicated `include/config.h` within your ESP32 PlatformIO/Arduino project.

You must explicitly define your local Wi-Fi and your Cloud MQTT broker credentials so the ESP32 can route packets to the public internet.

```cpp
// Example Configuration Block
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// HiveMQ Cloud configuration
const char* mqtt_server = "your-cluster-url.s1.eu.hivemq.cloud"; 
const int mqtt_port = 8883; // 8883 is MANDATORY for secure MQTTS (SSL/TLS)
const char* mqtt_user = "your_hivemq_username";
const char* mqtt_pass = "your_hivemq_password";
```
*Why 8883?* Port 1883 is unencrypted MQTT. Port 8883 forces the ESP32 to negotiate an SSL/TLS tunnel with HiveMQ, ensuring payload encryption over the public internet.

### 1.2 The `TEST_MODE` Flag & Mock Injection
**File Location:** In your main `loop()` function or global variable declarations in `src/main.cpp`.

Find and ensure the following flag is set:
```cpp
bool TEST_MODE = true;
```

**Deep Logic Explanation:** 
In a production deployment, the ESP32 acts as a transparent gateway, reading raw bytes from the subordinate Node MCU via a physical UART interface (`Serial1`). When `TEST_MODE = true;` is active, the firmware conditionally bypasses the `Serial1.read()` hardware buffer entirely. 
Instead, it utilizes a non-blocking `millis()` timer. Every 10,000 milliseconds (10 seconds), the timer triggers an internal function that constructs a mock JSON string: 
`{"hardware_token": "BIN_001", "capacity": 50.0}`. 
This bypasses hardware dependencies (like ultrasonic sensors) and allows us to rigorously test the cloud transport and backend ingestion logic in isolation.

### 1.3 Configuring the Django Backend (Python)
**File Location:** Open `settings.py` (or your `.env` file) in your Django project root.

The backend must possess the exact same HiveMQ credentials to subscribe to the topics the ESP32 is publishing to.
```python
# settings.py
MQTT_SERVER = "your-cluster-url.s1.eu.hivemq.cloud"
MQTT_PORT = 8883
MQTT_USER = "your_hivemq_username"
MQTT_PASSWORD = "your_hivemq_password"
MQTT_USE_TLS = True
```

---

## SECTION 2: Flashing the ESP32 (The Hardware Setup)

With the firmware configured, we must compile the C++ code into machine binaries and write it to the ESP32's flash memory.

### 2.1 Flashing via VS Code (PlatformIO)
1. Connect the ESP32 to your PC via a data-capable Micro-USB or USB-C cable.
2. Open the ESP32 project folder in VS Code.
3. Click the **PlatformIO** icon (the alien head) in the left sidebar.
4. Expand **Project Tasks** -> **esp32dev** (or your specific board) -> **General**.
5. Click **Upload**. PlatformIO will automatically detect the active `COM` port (e.g., `COM3` on Windows, `/dev/ttyUSB0` on Linux/Mac).

### 2.2 Opening the Serial Monitor & Baud Rate
Immediately after flashing, you must observe the boot sequence.
1. Click the **Serial Monitor** icon (the plug icon at the bottom blue status bar of PlatformIO).
2. Ensure the baud rate is set to `115200`. *Why 115200?* It is the standard clock speed for ESP32 UART communication; mismatched baud rates result in unreadable garbage characters (`⸮⸮⸮`).

### 2.3 The Boot Sequence Log Analysis
You will see logs outputting rapidly. Here is the exact sequence and its technical meaning:
1. `Connecting to Wi-Fi [YOUR_WIFI_SSID]...` - The ESP radio is authenticating with your router.
2. `Wi-Fi Connected. IP: 192.168.1.X` - DHCP lease acquired. The ESP is now on the network.
3. `Setting up Secure Connection (setInsecure)...` - **Crucial Step:** The `espClient.setInsecure()` method tells the WiFiClientSecure library to bypass X.509 certificate validation. We are establishing an encrypted TLS tunnel but skipping the verification of the Certificate Authority (CA) to save memory/processing overhead on the microcontroller.
4. `Connecting to MQTT Broker...` - Sending the CONNECT packet to HiveMQ on port 8883.
5. `MQTT Connected!` - The SSL/TLS handshake succeeded, and HiveMQ accepted the username/password.
6. `Subscribed to topic: bin/BIN_001/command` - The gateway is now actively listening for commands from the Django backend.

---

## SECTION 3: Booting the Django Backend & WebSockets (Terminal by Terminal)

The backend requires two simultaneous processes: an ASGI server to handle HTTP/WebSockets, and a background daemon to listen to the MQTT broker.

### 3.1 Activating the Environment
Open a terminal in your Django project root and activate the Python virtual environment:
**Windows:** `.\env\Scripts\activate`
**Mac/Linux:** `source env/bin/activate`

### 3.2 Starting the ASGI Server (Terminal 1)
To support WebSockets, a standard synchronous WSGI server (like Gunicorn or `runserver`) is insufficient. We must use an ASGI (Asynchronous Server Gateway Interface) server like Daphne or Uvicorn.
**Command:** 
```bash
daphne -b 0.0.0.0 -p 8000 smartbin.asgi:application
# OR if using uvicorn:
uvicorn smartbin.asgi:application --host 0.0.0.0 --port 8000
```
*Why ASGI?* HTTP requests are short-lived. WebSockets require long-lived, persistent TCP connections. ASGI allows Django Channels to multiplex thousands of these persistent connections concurrently without blocking threads.

### 3.3 Starting the MQTT Listener (Terminal 2)
Open a *second* terminal, activate the `env` again, and run the custom management command or daemon script that subscribes to the telemetry topic.
**Command:**
```bash
python manage.py mqtt_listener
# OR
python mqtt_worker.py
```

### 3.4 The Deep Data Flow: Ingestion to Broadcast
When the ESP32 publishes the mock `{"capacity": 50.0}` to the topic `bin/BIN_001/telemetry`, the following occurs in microseconds:
1. **Ingestion:** The `paho-mqtt` client in Terminal 2 receives the binary payload and decodes it to a UTF-8 JSON string.
2. **Parsing & Persistence:** The Python script parses the JSON, looks up the `Bin` model in the PostgreSQL/SQLite database matching `hardware_token="BIN_001"`, and updates its `current_capacity` to `50.0`. `bin.save()` is called.
3. **Event Trigger:** A Django Signal (or direct function call post-save) triggers Django Channels.
4. **WebSocket Broadcast:** Channels uses Redis (the channel layer) to publish a message to the group `bin_BIN_001_updates`. Daphne (in Terminal 1) receives this over Redis and pushes the frame down the open TCP WebSocket connection to any connected Flutter clients.

---

## SECTION 4: Flutter Mobile App (The UI & Real-Time Sync)

The mobile application is the terminal endpoint for the user. We will run it on physical hardware to prove external network capability.

### 4.1 Running on Physical Hardware
Connect your physical Android or iOS device. Ensure USB Debugging is enabled.
Open a terminal in your Flutter project directory.
**Command:**
```bash
flutter devices # Find your device ID
flutter run -d <your_device_id>
```

### 4.2 The 4G/Mobile Data Test
Once the app is installed and running, **disable Wi-Fi on your phone**. Force the phone to use 4G/5G mobile data.
*Why?* If the phone is on the same local Wi-Fi as the ESP32 or the Django server, you might accidentally succeed via Local Area Network (LAN) routing. By forcing the phone onto a cellular network, you mathematically prove that your system is functioning as a globally distributed IoT architecture via the public internet.

### 4.3 Visual Verification of UI Constraints
Navigate to the Bin Status screen. Verify the specific aesthetic constraints programmed earlier:
- **Background:** Must be a rich, deep blue (`Colors.blue[900]` or similar Hex).
- **Typography:** The text displaying the capacity and bin name must be strictly `Colors.black`. Note: This is an intentional UI constraint test, ensuring the styling layer correctly overrides default Material themes.

---

## SECTION 5: The Execution & Data Flow Verification (The Climax)

With all three nodes (ESP32, Django, Flutter) active, we test the bi-directional data flow.

### Scenario A: App to Hardware (Command Execution)
**Action:** The user taps the "Unlock" or "Scan QR" button in the Flutter app.
**The Exact Data Flow:**
1. **Flutter:** Executes an HTTP `POST` request to `https://your-django-server.com/api/bins/BIN_001/unlock/`.
2. **Django:** The View receives the POST, authenticates the user, and uses the `paho-mqtt` library to execute: `client.publish("bin/BIN_001/command", "start")`. The HTTP response returns `200 OK` to the app.
3. **HiveMQ Broker:** Routes the message to the subscribed ESP32.
4. **ESP32 Callback:** The `mqttCallback(char* topic, byte* payload, unsigned int length)` function fires.
5. **Hardware Execution:** The ESP32 parses the string. It matches `"start"`. In a production unit, it would pull a GPIO pin HIGH to trigger a relay. In our test, look at the **PlatformIO Serial Monitor**; you must see it print:
   `> COMMAND RECEIVED: start`
   `> Executing Motor Sequence...`

### Scenario B: Hardware to App (Telemetry Stream)
**Action:** Do nothing. Wait 10 seconds.
**The Exact Data Flow:**
1. **ESP32:** The `millis()` timer triggers `TEST_MODE` logic. It executes `client.publish("bin/BIN_001/telemetry", "{\"capacity\": 50.0}")`.
2. **Django Listener:** Terminal 2 catches the payload, saves `50.0` to the DB, and dispatches the WebSocket event.
3. **Daphne (Terminal 1):** Routes the WebSocket frame over the internet to the cellular network.
4. **Flutter UI:** The `StreamBuilder` or `WebSocketChannel` listening in Dart receives the JSON frame. `setState()` is called. The screen seamlessly repaints, jumping the visual capacity indicator to 50% without the user touching the screen.

---

## SECTION 6: Troubleshooting & Edge Cases

When executing distributed systems testing, specific failure codes pinpoint exact bottlenecks.

### 6.1 ESP32 Error: `rc=-2`
**Symptom:** Serial monitor prints `MQTT Connect failed, rc=-2`.
**Diagnosis:** `rc=-2` means the network connection failed entirely. 
**Fix:** Verify the ESP32 actually acquired a Wi-Fi IP address. Verify your HiveMQ URL is correct and you are using Port 8883. If it says `rc=5`, that means unauthorized (check username/password).

### 6.2 Django Silent Failure (Topic Mismatch)
**Symptom:** ESP32 publishes successfully, but Django never updates the DB.
**Diagnosis:** The MQTT Listener is subscribed to the wrong topic. MQTT topics are strictly case-sensitive.
**Fix:** Check Terminal 2 logs. Ensure the ESP32 is publishing to `bin/BIN_001/telemetry` and Django is subscribed to `bin/+/telemetry` (using the `+` wildcard) or the exact exact string.

### 6.3 Flutter UI Stagnant (WebSocket Drop)
**Symptom:** Django receives the MQTT message and updates the DB, but the Flutter app remains at the old capacity value until manually refreshed.
**Diagnosis:** The WebSocket connection has been severed, likely due to a cellular network change or Daphne timeout.
**Fix:** Implement a heartbeat/ping-pong mechanism in Flutter using `web_socket_channel`. Check the Daphne terminal (Terminal 1) for `Disconnect` logs. Ensure the Flutter app attempts to aggressively reconnect to `wss://your-django-server/ws/bin/BIN_001/` upon connection loss.
