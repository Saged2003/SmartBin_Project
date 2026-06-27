#include "NetworkManager.h"

NetworkManager::NetworkManager(String url, String id, String identToken) {
    baseUrl = url;
    binId = id;
    token = identToken;
}

void NetworkManager::initWiFi(const char* ssid, const char* password) {
    WiFi.begin(ssid, password);
    Serial.print("[Network] Connecting to WiFi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\n[Network] Connected! IP: " + WiFi.localIP().toString());
}

String NetworkManager::getQRCode() {
    if (WiFi.status() != WL_CONNECTED) return "";
    HTTPClient http;
    http.begin(baseUrl + "/api/esp/get-code/");
    http.addHeader("Content-Type", "application/json");

    String requestBody = "{\"bin_id\":\"" + binId + "\",\"hardware_token\":\"" + token + "\"}";
    int httpResponseCode = http.POST(requestBody);
    String qrCode = "";

    if (httpResponseCode == 200) {
        String response = http.getString();
        JsonDocument doc;
        deserializeJson(doc, response);
        qrCode = doc["code"].as<String>();
    }
    http.end();
    return qrCode;
}

bool NetworkManager::checkScan() {
    if (WiFi.status() != WL_CONNECTED) return false;
    HTTPClient http;
    http.begin(baseUrl + "/api/esp/check-scan/");
    http.addHeader("Content-Type", "application/json");

    String requestBody = "{\"bin_id\":\"" + binId + "\",\"hardware_token\":\"" + token + "\"}";
    int httpResponseCode = http.POST(requestBody);
    bool isScanned = false;

    if (httpResponseCode == 200) {
        String response = http.getString();
        JsonDocument doc;
        deserializeJson(doc, response);
        if (doc["status"] == "YES") isScanned = true;
    }
    http.end();
    return isScanned;
}

bool NetworkManager::updateCapacity(float capacity) {
    if (WiFi.status() != WL_CONNECTED) return false;
    HTTPClient http;
    http.begin(baseUrl + "/api/esp/update-capacity/");
    http.addHeader("Content-Type", "application/json");

    String requestBody = "{\"bin_id\":\"" + binId + "\",\"hardware_token\":\"" + token + "\",\"capacity\":" + String(capacity) + "}";
    int httpResponseCode = http.POST(requestBody);
    http.end();
    return (httpResponseCode == 200);
}

bool NetworkManager::endSession(int points, float weight) {
    if (WiFi.status() != WL_CONNECTED) return false;
    HTTPClient http;
    http.begin(baseUrl + "/api/esp/end-session/");
    http.addHeader("Content-Type", "application/json");

    String requestBody = "{\"bin_id\":\"" + binId + "\",\"hardware_token\":\"" + token + "\",\"points\":" + String(points) + ",\"weight\":" + String(weight) + "}";
    int httpResponseCode = http.POST(requestBody);
    http.end();
    return (httpResponseCode == 200);
}