#include "DisplayManager.h"

DisplayManager::DisplayManager()
    : tft(TFT_CS, TFT_DC, TFT_MOSI, TFT_SCLK, TFT_RST) {}

void DisplayManager::init() {
  tft.initR(INITR_BLACKTAB);
  tft.setRotation(0);
  tft.fillScreen(ST77XX_BLACK);
}

void DisplayManager::drawQRCode(String text) {
  tft.fillScreen(ST77XX_WHITE);

  QRCode qrcode;
  uint8_t qrcodeData[qrcode_getBufferSize(QR_VERSION)];

  qrcode_initText(&qrcode, qrcodeData, QR_VERSION, 0, text.c_str());

  int qrSize = qrcode.size * QR_SCALE;
  int startX = (TFT_WIDTH - qrSize) / 2;
  int startY = (TFT_HEIGHT - qrSize) / 2;

  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        tft.fillRect(startX + x * QR_SCALE, startY + y * QR_SCALE, QR_SCALE,
                     QR_SCALE, ST77XX_BLACK);
      }
    }
  }
}

void DisplayManager::showMessage(String msg) {
  tft.setTextSize(1);
  tft.setTextColor(ST77XX_BLACK);
  tft.setCursor(10, TFT_HEIGHT - 20);
  tft.print(msg);
}