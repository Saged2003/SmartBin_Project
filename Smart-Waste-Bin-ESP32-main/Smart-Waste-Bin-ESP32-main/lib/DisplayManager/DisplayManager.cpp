#include "DisplayManager.h"
#include "../../include/Config.h"

void DisplayManager::init() {
  tft = new Adafruit_ST7735(TFT_CS, TFT_DC, TFT_RST);
  tft->initR(INITR_BLACKTAB);
  tft->setRotation(1);
  tft->fillScreen(ST77XX_WHITE);
}

void DisplayManager::clearScreen() { tft->fillScreen(ST77XX_WHITE); }

void DisplayManager::showMessage(String msg, uint16_t color) {
  clearScreen();
  tft->setCursor(10, 60);
  tft->setTextColor(color);
  tft->setTextSize(2);
  tft->print(msg);
}

void DisplayManager::showQRCode(String text) {
  QRCode qrcode;
  uint8_t qrcodeData[qrcode_getBufferSize(3)];

  qrcode_initText(&qrcode, qrcodeData, 3, ECC_LOW, text.c_str());

  tft->fillScreen(ST77XX_WHITE);

  int scale = 4;
  int xOffset = (160 - (qrcode.size * scale)) / 2;
  int yOffset = (128 - (qrcode.size * scale)) / 2;

  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        tft->fillRect(xOffset + (x * scale), yOffset + (y * scale), scale,
                      scale, ST77XX_BLACK);
      }
    }
  }
}