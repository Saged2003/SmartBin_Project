#include "S3Communicator.h"
#include "../../include/Config.h" 

void S3Communicator::init() {
    Serial2.begin(115200, SERIAL_8N1, CAM_RX, CAM_TX);
}

void S3Communicator::sendItemUpdate(int type, float pLvl, float mLvl, float pWt, float mWt) {
    JsonDocument doc;
    doc["req"] = "update";
    doc["type"] = type;
    doc["pLvl"] = pLvl;
    doc["mLvl"] = mLvl;
    doc["pWt"] = pWt;
    doc["mWt"] = mWt;
    
    serializeJson(doc, Serial2);
    Serial2.println();
}

void S3Communicator::sendSessionEnd(int points) {
    JsonDocument doc;
    doc["req"] = "end";
    doc["pts"] = points;
    
    serializeJson(doc, Serial2);
    Serial2.println();
}

void S3Communicator::sendQRCommand(String qrCode) {
    Serial2.println("QR:" + qrCode);
}

void S3Communicator::sendStartCommand() {
    Serial2.println("START_BIN");
}