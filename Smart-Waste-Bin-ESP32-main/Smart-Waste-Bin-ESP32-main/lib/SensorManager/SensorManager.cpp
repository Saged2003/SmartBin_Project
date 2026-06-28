#include "SensorManager.h"
#include "../../include/Config.h"

void SensorManager::init() {
  pinMode(DOOR_TRIG, OUTPUT);
  pinMode(DOOR_ECHO, INPUT_PULLDOWN);
  digitalWrite(DOOR_TRIG, LOW);

  pinMode(U1_TRIG, OUTPUT);
  pinMode(U1_ECHO, INPUT);
  pinMode(U2_TRIG, OUTPUT);
  pinMode(U2_ECHO, INPUT);
  digitalWrite(U1_TRIG, LOW);
  digitalWrite(U2_TRIG, LOW);

  pinMode(U3_ECHO, INPUT);
  pinMode(U4_ECHO, INPUT);

  pinMode(PIN_INDUCTIVE, INPUT);
}

float SensorManager::getSingleDistance(uint8_t trigPin, uint8_t echoPin) {
  float readings[3];
  for (int i = 0; i < 3; i++) {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    long duration = pulseIn(echoPin, HIGH, 30000);
    if (duration == 0) {
      readings[i] = -1.0;
    } else {
      float distance = (duration / 2.0) * 0.0343;
      if (distance > BIN_HEIGHT_CM + 10.0) distance = BIN_HEIGHT_CM;
      readings[i] = distance;
    }
    delay(10);
  }

  // Sort the 3 readings to find the median
  for (int i = 0; i < 2; i++) {
    for (int j = i + 1; j < 3; j++) {
      if (readings[i] > readings[j]) {
        float temp = readings[i];
        readings[i] = readings[j];
        readings[j] = temp;
      }
    }
  }

  return readings[1]; // Return the median reading
}

bool SensorManager::isWastePresent() {
  float distance = getSingleDistance(DOOR_TRIG, DOOR_ECHO);
  if (distance > 0 && distance < DOOR_THRESHOLD_CM) {
    return true;
  }
  return false;
}

bool SensorManager::isMetalDetected() {
  int sensorValue = analogRead(PIN_INDUCTIVE);
  if (sensorValue < 500) {
    return true;
  }
  return false;
}

int SensorManager::checkWasteTypeOnLid() {
  if (isWastePresent()) {
    delay(150);
    if (isMetalDetected()) {
      return 2;
    } else {
      return 1;
    }
  }
  return 0;
}

float SensorManager::calculatePercentage(float distance1, float distance2) {
  float validDistance = 0;
  int validCount = 0;

  if (distance1 >= 0) {
    validDistance += distance1;
    validCount++;
  }
  if (distance2 >= 0) {
    validDistance += distance2;
    validCount++;
  }

  if (validCount == 0)
    return 0.0;

  float avgDistance = validDistance / validCount;

  if (avgDistance >= BIN_HEIGHT_CM)
    return 0.0;

  float percentage = ((BIN_HEIGHT_CM - avgDistance) / BIN_HEIGHT_CM) * 100.0;

  if (percentage > 100.0)
    percentage = 100.0;
  if (percentage < 0.0)
    percentage = 0.0;

  return percentage;
}

float SensorManager::getPlasticLevelPercentage() {
  float d1 = getSingleDistance(U1_TRIG, U1_ECHO);
  delay(50);
  float d2 = getSingleDistance(U2_TRIG, U2_ECHO);

  return calculatePercentage(d1, d2);
}

float SensorManager::getMetalLevelPercentage() {
  float d3 = getSingleDistance(U3_TRIG, U3_ECHO);
  delay(50);
  float d4 = getSingleDistance(U4_TRIG, U4_ECHO);

  return calculatePercentage(d3, d4);
}