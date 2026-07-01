#ifndef MOTOR_CONTROLLER_H
#define MOTOR_CONTROLLER_H

#include <AccelStepper.h>
#include <Arduino.h>
#include <ESP32Servo.h>


class MotorController {
public:
  void init();

  bool tiltToPlastic();
  bool tiltToMetal();
  bool resetToCenter();

  bool runToPosition();
  
  void openLid();
  void closeLid();
private:
  Servo lidServo;
};

#endif