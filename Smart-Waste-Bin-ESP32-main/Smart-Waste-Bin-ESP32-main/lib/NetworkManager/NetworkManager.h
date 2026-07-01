#ifndef NETWORK_MANAGER_H
#define NETWORK_MANAGER_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFi.h>


class NetworkManager {
private:
  String baseUrl;
  String binId;
  String token;

public:
  NetworkManager(String url, String id, String identToken);

  void initWiFi(const char *ssid, const char *password);
  String getQRCode();
  bool checkScan();
  bool updateCapacity(float capacity);
  bool endSession(int points, float weight, String materialType);
};

#endif