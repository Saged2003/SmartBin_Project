#ifndef SENSOR_MANAGER_H
#define SENSOR_MANAGER_H

#include <Arduino.h>

class SensorManager {
public:
  void init();

  float getPlasticLevelPercentage();
  float getMetalLevelPercentage();

  bool isWastePresent();
  bool isMetalDetected();
  int checkWasteTypeOnLid();

  float getSingleDistance(uint8_t trigPin, uint8_t echoPin);

private:
  float calculatePercentage(float distance1, float distance2);
};

#endif