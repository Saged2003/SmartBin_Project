#include "../include/Config.h"
#include "MotorController.h"
#include "S3Communicator.h"
#include "SensorManager.h"
#include <Arduino.h>

SensorManager sensor;
MotorController motor;
S3Communicator s3Comm;

unsigned long stateStartTime = 0;

enum InternalState { WAITING_FOR_USER, SESSION_ACTIVE };
InternalState currentState = WAITING_FOR_USER;

void setup() {
    Serial.begin(115200);
    
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    
    sensor.init();
    motor.init();
    s3Comm.init();
    
    stateStartTime = millis();
    Serial.println(">>> Smart Bin System Ready! Waiting for Gateway Start Command... <<<");
}

void loop() {
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
                
                Serial.println("DEBUG Clean: [" + cleanMsg + "]");
                
                if (cleanMsg == "start" || cleanMsg == "START_BIN" || cleanMsg == "OPEN_BIN") {
                    currentState = SESSION_ACTIVE;
                    stateStartTime = millis();
                    Serial.println(">>> SESSION STARTED via Serial2: Waiting for items...");
                    motor.openLid();
                }
            }
            break;

        case SESSION_ACTIVE:
            if (digitalRead(BUTTON_PIN) == LOW) {
                Serial.println(">>> Manual End: Button Pressed.");
                s3Comm.sendSessionEnd(0);
                motor.closeLid();
                currentState = WAITING_FOR_USER;
                stateStartTime = now;
                delay(250); 
                break; 
            }

            int type = sensor.checkWasteTypeOnLid(); 
            
            if (type != 0) { 
                bool completedProperly = true;

                if (type == 2) { 
                    Serial.println("Action: Sorting Metal...");
                    motor.tiltToMetal();   
                    delay(1500); 
                    completedProperly = motor.resetToCenter(); 
                } 
                else if (type == 1) { 
                    Serial.println("Action: Sorting Plastic...");
                    motor.tiltToPlastic(); 
                    delay(1500);           
                    completedProperly = motor.resetToCenter(); 
                }

                if (!completedProperly) {
                    Serial.println(">>> Interrupt detected! Forcing IDLE state...");
                    s3Comm.sendSessionEnd(0);
                    motor.closeLid();
                    currentState = WAITING_FOR_USER;
                    stateStartTime = millis(); 
                    return; 
                }

                float currentPlasticLevel = sensor.getPlasticLevelPercentage();
                float currentMetalLevel = sensor.getMetalLevelPercentage();
                
                // Generate mock weight based on type
                float pWt = (type == 1) ? random(15, 30) : 0.0;
                float mWt = (type == 2) ? random(12, 25) : 0.0;
                
                s3Comm.sendItemUpdate(type, currentPlasticLevel, currentMetalLevel, pWt, mWt);
                Serial.println(">>> Sorting Complete. Ready for next item.");
            }

            if (now - stateStartTime > 30000) {
                Serial.println(">>> Session Timeout (30s). Returning to IDLE.");
                s3Comm.sendSessionEnd(0);
                motor.closeLid();
                currentState = WAITING_FOR_USER;
                stateStartTime = now;
            }
            break;
    }
}