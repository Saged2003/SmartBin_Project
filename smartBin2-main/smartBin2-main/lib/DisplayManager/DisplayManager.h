#ifndef DISPLAY_MANAGER_H
#define DISPLAY_MANAGER_H

#include "Config.h"
#include "qrcode.h"
#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>


class DisplayManager {
public:
  Adafruit_ST7735 tft;

  DisplayManager();
  void init();
  void drawQRCode(String text);
  void showMessage(String msg);
};

#endif