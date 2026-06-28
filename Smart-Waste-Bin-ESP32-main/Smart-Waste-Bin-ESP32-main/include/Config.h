#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

#define TFT_CS 5
#define TFT_RST 4
#define TFT_DC 27
#define TFT_MOSI 23
#define TFT_SCLK 18

#define CAM_RX 16
#define CAM_TX 17

#define U1_TRIG 25
#define U1_ECHO 33
#define U2_TRIG 26
#define U2_ECHO 36

#define U3_TRIG 25
#define U3_ECHO 32
#define U4_TRIG 26
#define U4_ECHO 39

#define STEP_PIN 2
#define DIR_PIN 15
#define ENABLE_PIN 13

#define BUTTON_PIN 12

#define PIN_INDUCTIVE 34

#define DOOR_TRIG 14
#define DOOR_ECHO 27

#define WIFI_SSID "Your_WiFi_Name"
#define WIFI_PASSWORD "Your_WiFi_Password"
#define API_BASE_URL "http://192.168.1.10:8000"
#define BIN_ID "BIN-01"
#define HARDWARE_TOKEN "secret-token-123"

const float BIN_HEIGHT_CM = 68.5;

const int STEPS_TO_PLASTIC = 400;
const int STEPS_TO_METAL = -400;
const int STEPS_CENTER = 0;

const float DOOR_THRESHOLD_CM = 7.0;

enum SystemState {
  STATE_INIT,
  STATE_IDLE,
  STATE_SHOW_QR,
  STATE_SESSION_ACTIVE,
  STATE_PROCESSING_WASTE,
  STATE_SORTING,
  STATE_SENDING_DATA,
  STATE_ERROR
};

#endif