#ifndef BLE_MANAGER_H
#define BLE_MANAGER_H

#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>


#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

class BLEManager {
public:
  BLEServer *pServer = NULL;
  BLECharacteristic *pCharacteristic = NULL;
  bool deviceConnected = false;
  String queuedData = "[]";

  class MyServerCallbacks : public BLEServerCallbacks {
    BLEManager *bleMgr;

  public:
    MyServerCallbacks(BLEManager *mgr) : bleMgr(mgr) {}
    void onConnect(BLEServer *pServer) { bleMgr->deviceConnected = true; }
    void onDisconnect(BLEServer *pServer) {
      bleMgr->deviceConnected = false;
      pServer->startAdvertising();
    }
  };

  class WriteCallback : public BLECharacteristicCallbacks {
    BLEManager *bleMgr;

  public:
    WriteCallback(BLEManager *mgr) : bleMgr(mgr) {}
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = String(pCharacteristic->getValue().c_str());
      if (value == "CLEAR") {
        bleMgr->clearQueue();
      }
    }
  };

  void init(String binId) {
    BLEDevice::init(binId.c_str());
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks(this));

    BLEService *pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ |
                                 BLECharacteristic::PROPERTY_WRITE |
                                 BLECharacteristic::PROPERTY_NOTIFY);

    pCharacteristic->addDescriptor(new BLE2902());
    pCharacteristic->setCallbacks(new WriteCallback(this));
    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
  }

  void queueOfflineData(String jsonPayload) {
    if (queuedData == "[]") {
      queuedData = "[" + jsonPayload + "]";
    } else {
      queuedData = queuedData.substring(0, queuedData.length() - 1) + "," +
                   jsonPayload + "]";
    }
    pCharacteristic->setValue(queuedData.c_str());
    pCharacteristic->notify();
  }

  void clearQueue() {
    queuedData = "[]";
    pCharacteristic->setValue(queuedData.c_str());
  }
};

extern BLEManager bleManager;

#endif