#include <WiFi.h>
#include <PubSubClient.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <Update.h>
#include <HTTPClient.h>
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* mqtt_server = "192.168.43.219"; 
const int mqtt_port = 1883;
WiFiClient espClient;
PubSubClient client(espClient);
#define BIN_ID "BIN-001"
#define HARDWARE_TOKEN "SECURE_TOKEN_123"
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  String message;
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);
  if (String(topic) == "smartbin/BIN-001/command") {
    StaticJsonDocument<200> doc;
    deserializeJson(doc, message);
    const char* cmd = doc["cmd"];
    if (String(cmd) == "START_BIN") {
      Serial.println("Unlocking Bin Door...");
      delay(5000); 
      StaticJsonDocument<200> outDoc;
      outDoc["bin_id"] = BIN_ID;
      outDoc["hardware_token"] = HARDWARE_TOKEN;
      outDoc["points"] = 10;
      outDoc["weight"] = 1.2;
      outDoc["material_type"] = "plastic";
      char outBuffer[256];
      serializeJson(outDoc, outBuffer);
      client.publish("smartbin/BIN-001/end_session", outBuffer);
    }
  }
}
void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect(BIN_ID)) {
      Serial.println("connected");
      client.subscribe("smartbin/BIN-001/command");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      pServer->getAdvertising()->start();
    }
};
void setup() {
  Serial.begin(115200);
  BLEDevice::init(BIN_ID);
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();
  WiFi.begin(ssid, password);
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 10) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    client.setServer(mqtt_server, mqtt_port);
    client.setCallback(callback);
    reconnect();
  } else {
    Serial.println("WiFi not connected. Running in offline/BLE mode.");
  }
  float capacity = 45.0; 
  if (WiFi.status() == WL_CONNECTED) {
    StaticJsonDocument<200> capDoc;
    capDoc["bin_id"] = BIN_ID;
    capDoc["hardware_token"] = HARDWARE_TOKEN;
    capDoc["capacity"] = capacity;
    char capBuffer[256];
    serializeJson(capDoc, capBuffer);
    client.publish("smartbin/BIN-001/capacity", capBuffer);
  } else {
    String bleData = String("CAPACITY:") + String(capacity);
    pCharacteristic->setValue(bleData.c_str());
    pCharacteristic->notify();
  }
  Serial.println("Going to deep sleep for 30 minutes...");
  esp_sleep_enable_timer_wakeup(30 * 60 * 1000000ULL); 
  esp_deep_sleep_start();
}
void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!client.connected()) {
      reconnect();
    }
    client.loop();
  }
}