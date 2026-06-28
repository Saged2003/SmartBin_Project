#include "TempQRServer.h"

TempQRServer::TempQRServer() : server(80) {
  currentToken = "f1e2d3c4-b5a6-7890-abcd-ef1234567890";
}

void TempQRServer::init() {
  WiFi.mode(WIFI_AP_STA);
  WiFi.begin("tarek", "Qry@..462000");
  WiFi.softAP("SmartBin_QR_Screen", "12345678");

  Serial.println("\n--- Network Status ---");
  Serial.print("Mobile Screen IP: ");
  Serial.println(WiFi.softAPIP());

  Serial.print("Connecting to Internet...");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to Internet! Router IP: " +
                 WiFi.localIP().toString());

  server.on("/", [this]() {
    String html = "<html><head><meta charset='UTF-8'><meta name='viewport' "
                  "content='width=device-width, initial-scale=1'>";
    html += "<style>";
    html += "body { display: flex; flex-direction: column; align-items: "
            "center; justify-content: center; height: 100vh; margin: 0; "
            "background: #2c3e50; color: white; font-family: sans-serif; }";
    html += ".container { background: white; padding: 30px; border-radius: "
            "15px; color: #333; text-align: center; box-shadow: 0 10px 20px "
            "rgba(0,0,0,0.3); }";
    html += ".pixel { width: 6px; height: 6px; } .row { display: flex; } "
            ".black { background: black; } .white { background: white; }";
    html +=
        ".status-busy { color: #e74c3c; font-weight: bold; font-size: 24px; }";
    html += ".level-bar { width: 200px; background: #ddd; height: 20px; "
            "border-radius: 10px; margin: 10px auto; overflow: hidden; }";
    html +=
        ".fill { height: 100%; background: #27ae60; transition: width 0.5s; }";
    html += "</style>";

    html += "<script>";
    html += "function refresh() {";
    html += "  fetch('/data').then(r => r.json()).then(d => {";
    html += "    let root = document.getElementById('content');";
    html += "    if(d.isBusy) {";
    html += "      root.innerHTML = `<h2 class='status-busy'>⚠️ Bin is "
            "Busy</h2>` + ";
    html += "                       `<h3>Time Remaining: ${d.timer} "
            "seconds</h3>` + ";
    html += "                       `<hr><p>Last Waste: "
            "<b>${d.lastType}</b></p>` + ";
    html += "                       `<p>Plastic: ${d.pLvl}%</p><div "
            "class='level-bar'><div class='fill' "
            "style='width:${d.pLvl}%'></div></div>` + ";
    html += "                       `<p>Metal: ${d.mLvl}%</p><div "
            "class='level-bar'><div class='fill' "
            "style='width:${d.mLvl}%'></div></div>`;";
    html += "    } else {";
    html += "      root.innerHTML = `<h3>Scan QR Code to Start</h3><div "
            "id='qr'>${d.qr}</div><p>Session Code: ${d.token}</p>`;";
    html += "    }";
    html += "  });";
    html += "}";
    html += "setInterval(refresh, 1000);";
    html += "</script></head><body><div class='container' "
            "id='content'>Loading...</div></body></html>";
    this->server.send(200, "text/html", html);
  });

  server.on("/data", [this]() {
    String json = "{";
    json += "\"isBusy\":" + String(isBusy ? "true" : "false") + ",";
    json += "\"timer\":" + String(sessionTimer) + ",";
    json += "\"lastType\":\"" + lastWasteType + "\",";
    json += "\"pLvl\":" + String(plasticLevel) + ",";
    json += "\"mLvl\":" + String(metalLevel) + ",";
    json += "\"token\":\"" + currentToken + "\",";
    json += "\"qr\":\"" + getQRAsHTML() + "\"";
    json += "}";
    this->server.send(200, "application/json", json);
  });

  server.begin();
  Serial.println("HTTP Server is UP and Running!");
}

void TempQRServer::handleClient() { server.handleClient(); }

String TempQRServer::getQRAsHTML() {
  QRCode qrcode;
  uint8_t qrcodeData[qrcode_getBufferSize(3)];
  qrcode_initText(&qrcode, qrcodeData, 3, 0, currentToken.c_str());

  String html = "";
  for (uint8_t y = 0; y < qrcode.size; y++) {
    html += "<div class='row'>";
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        html += "<div class='pixel black'></div>";
      } else {
        html += "<div class='pixel white'></div>";
      }
    }
    html += "</div>";
  }
  return html;
}

void TempQRServer::updateToken(String newToken) { currentToken = newToken; }