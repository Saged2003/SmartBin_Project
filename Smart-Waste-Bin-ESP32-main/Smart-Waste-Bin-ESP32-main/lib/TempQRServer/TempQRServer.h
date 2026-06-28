#ifndef TEMP_QR_SERVER_H
#define TEMP_QR_SERVER_H

#include <Arduino.h>
#include <WebServer.h>
#include <WiFi.h>
#include <qrcode.h>


class TempQRServer {
public:
  TempQRServer();
  void init();
  void handleClient();
  void updateToken(String newToken);

  bool isBusy = false;
  int sessionTimer = 0;
  float plasticLevel = 0.0;
  float metalLevel = 0.0;
  String lastWasteType = "Waiting...";

  String getQRAsHTML();

private:
  WebServer server;
  String currentToken;
};

#endif