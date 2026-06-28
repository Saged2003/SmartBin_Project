#ifndef S3_APP_CONTROLLER_H
#define S3_APP_CONTROLLER_H

#include "DisplayManager.h"
#include <Arduino.h>
#include <ArduinoJson.h>


enum S3State { STATE_INIT, STATE_SESSION, STATE_COOLDOWN, STATE_IDLE };

class S3AppController {
private:
  S3State currentState;
  unsigned long cooldownStartTime;
  int earnedPoints;
  float lastTotalWeight;
  int lastType; // Track last material type (1=plastic, 2=metal)

  void drawSessionScreen();
  void updateReadings(int type, float pLvl, float mLvl, float pWt, float mWt);
  void drawScoreScreen(int points);

public:
  void init();
  void run();

  void receiveBackendCommand(String cmd);

  bool isIdle();
};

#endif