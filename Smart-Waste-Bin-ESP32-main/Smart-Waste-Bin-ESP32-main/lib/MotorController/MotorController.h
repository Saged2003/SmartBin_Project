#ifndef MOTOR_CONTROLLER_H
#define MOTOR_CONTROLLER_H

#include <Arduino.h>
#include <AccelStepper.h>

class MotorController {
public:
    void init();
    
    bool tiltToPlastic();
    bool tiltToMetal();
    bool resetToCenter();
    
    bool runToPosition();
};

#endif