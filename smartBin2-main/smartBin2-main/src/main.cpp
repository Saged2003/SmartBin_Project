#include "BLEManager.h"
#include "DisplayManager.h"
#include "S3AppController.h"
#include <Arduino.h>
#include <ArduinoJson.h>
#include <ArduinoOTA.h>
#include <PubSubClient.h>
#include <WiFi.h>


const char *ssid = "Roqaya";
const char *password = "1234567";
const char *mqtt_server = "192.168.43.111";
const int mqtt_port = 1883;

String BIN_ID = "BIN001";
String HARDWARE_TOKEN = "MY_SECRET_TOKEN_123";

WiFiClient espClient;
PubSubClient client(espClient);

DisplayManager display;
S3AppController app;
BLEManager bleManager;

bool needsNewQR = true;
unsigned long lastWifiCheck = 0;
unsigned long lastReconnectAttempt = 0;

void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  unsigned long wifiTimeout = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    if (millis() - wifiTimeout > 15000) {
      Serial.println("\nWiFi connection timeout");
      return;
    }
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

void callback(char *topic, byte *payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("]: ");
  for (unsigned int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();

  String topicStr = String(topic);
  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, payload, length);

  if (error) {
    Serial.print("deserializeJson() failed: ");
    Serial.println(error.c_str());
    return;
  }

  if (topicStr.endsWith("/qr_code")) {
    String code = doc["code"];
    app.receiveBackendCommand("QR:" + code);
  } else if (topicStr.endsWith("/command")) {
    String cmd = doc["cmd"];
    if (cmd == "START_BIN") {
      app.receiveBackendCommand("START_BIN");
    }
  }
}

void reconnect() {
  if (millis() - lastReconnectAttempt > 5000) {
    lastReconnectAttempt = millis();
    Serial.print("Attempting MQTT connection...");
    if (client.connect(BIN_ID.c_str())) {
      Serial.println("connected");

      String qrTopic = "smartbin/" + BIN_ID + "/qr_code";
      String cmdTopic = "smartbin/" + BIN_ID + "/command";
      client.subscribe(qrTopic.c_str(), 1);
      client.subscribe(cmdTopic.c_str(), 1);

      if (needsNewQR) {
        String reqTopic = "smartbin/" + BIN_ID + "/request_qr";
        String reqPayload = "{\"hardware_token\":\"" + HARDWARE_TOKEN + "\"}";
        client.publish(reqTopic.c_str(), reqPayload.c_str());
        needsNewQR = false;
      }
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
    }
  }
}

void setup() {
  Serial.begin(115200);
  display.init();
  app.init();
  bleManager.init(BIN_ID);

  setup_wifi();

  ArduinoOTA.setHostname(BIN_ID.c_str());
  ArduinoOTA.begin();

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);

  Serial.println(">>> ESP32-S3 IoT Gateway Ready <<<");
}

void loop() {
  unsigned long now = millis();

  if (WiFi.status() == WL_CONNECTED) {
    ArduinoOTA.handle();
    if (!client.connected()) {
      reconnect();
    }
    client.loop();
  } else if (now - lastWifiCheck > 30000) {
    lastWifiCheck = now;
    setup_wifi();
  }

  app.run();
}