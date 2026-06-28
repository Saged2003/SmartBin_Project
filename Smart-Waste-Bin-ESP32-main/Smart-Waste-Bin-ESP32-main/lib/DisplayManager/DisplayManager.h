#ifndef DISPLAY_MANAGER_H
#define DISPLAY_MANAGER_H

#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <Arduino.h>
#include <qrcode.h>


class DisplayManager {
public:
  void init();
  void showQRCode(String text);
  void clearScreen();
  void showMessage(String msg, uint16_t color);

private:
  Adafruit_ST7735 *tft;
};

#endif