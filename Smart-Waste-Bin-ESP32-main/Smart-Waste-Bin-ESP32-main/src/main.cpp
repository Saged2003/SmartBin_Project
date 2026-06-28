#include "../include/Config.h"
#include "MotorController.h"
#include "S3Communicator.h"
#include "SensorManager.h"
#include "driver/uart.h"
#include <Arduino.h>
#include <ArduinoOTA.h>
#include <WiFi.h>


SensorManager sensor;
MotorController motor;
S3Communicator s3Comm;

unsigned long stateStartTime = 0;
unsigned long lastApiCheck = 0;
String currentQR = "";

enum InternalState { WAITING_FOR_USER, SESSION_ACTIVE };
InternalState currentState = WAITING_FOR_USER;

void setup() {
  Serial.begin(115200);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  sensor.init();
  motor.init();
  s3Comm.init();

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long wifiTimeout = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - wifiTimeout < 10000) {
    delay(500);
  }

  ArduinoOTA.setHostname("SmartBin-ESP32");
  ArduinoOTA.begin();

  stateStartTime = millis();
  Serial.println(">>> Smart Bin System Ready! <<<");
}

void loop() {
  ArduinoOTA.handle();
  unsigned long now = millis();

  switch (currentState) {

  case WAITING_FOR_USER:
    if (Serial2.available()) {
      String incomingMsg = Serial2.readStringUntil('\n');
      
      String cleanMsg = "";
      for (int i = 0; i < incomingMsg.length(); i++) {
        char c = incomingMsg[i];
        if (isAlphaNumeric(c) || c == '_') {
          cleanMsg += c;
        }
      }
      
      if (cleanMsg == "START_BIN" || cleanMsg == "start") {
        Serial.println(">>> Gateway command received! Starting Session...");
        currentState = SESSION_ACTIVE;
        stateStartTime = millis();
      }
    }

    if (now - lastApiCheck > 10000) {
      float pLvl = sensor.getPlasticLevelPercentage();
      float mLvl = sensor.getMetalLevelPercentage();
      s3Comm.sendItemUpdate(0, pLvl, mLvl, 0.0, 0.0);
      lastApiCheck = now;
    }
    break;

  case SESSION_ACTIVE:

    if (digitalRead(BUTTON_PIN) == LOW) {
      Serial.println(">>> Manual End: Button Pressed.");
      s3Comm.sendSessionEnd(40);
      currentState = WAITING_FOR_USER;
      stateStartTime = now;
      delay(250);
      break;
    }

    int type = sensor.checkWasteTypeOnLid();
    if (type != 0) {
      bool completedProperly = true;

      if (type == 2) {
        motor.tiltToMetal();
        delay(1500);
        completedProperly = motor.resetToCenter();
      } else if (type == 1) {
        motor.tiltToPlastic();
        delay(1500);
        completedProperly = motor.resetToCenter();
      }

      if (!completedProperly) {
        Serial.println(">>> Interrupt detected! Forcing IDLE state...");
        s3Comm.sendSessionEnd(40);
        currentState = WAITING_FOR_USER;
        stateStartTime = millis();
        return;
      }

      float currentPlasticLevel = sensor.getPlasticLevelPercentage();
      float currentMetalLevel = sensor.getMetalLevelPercentage();

      s3Comm.sendItemUpdate(type, currentPlasticLevel, currentMetalLevel, 0.0,
                            0.0);
    }

    if (now - stateStartTime > 30000) {
      Serial.println(">>> Session Timeout (30s). Returning to IDLE.");
      s3Comm.sendSessionEnd(40);
      currentState = WAITING_FOR_USER;
      stateStartTime = now;
    }
    break;
  }
}