#ifndef S3_COMMUNICATOR_H
#define S3_COMMUNICATOR_H

#include <Arduino.h>
#include <ArduinoJson.h>

class S3Communicator {
public:
    void init();
    void sendItemUpdate(int type, float pLvl, float mLvl, float pWt, float mWt);
    void sendSessionEnd(int points);
    void sendQRCommand(String qrCode);
    void sendStartCommand();
};

#endif