# 🗑️ Smart Bin Project - ESP32 Pin Mapping

جدول توصيلات المكونات مع لوحة **ESP32 (38-Pin Development Board)**.

| المكون (Component) | طرف المكون (Pin) | طرف الـ ESP32 (GPIO) | ملاحظات هامة (Hardware Tips) |
| :--- | :--- | :--- | :--- |
| **TFT LCD (1.8")** | VCC / LED | **3.3V** | الـ LED يوصل بـ 3.3V للإضاءة الدائمة |
| | GND | **GND** | أرضي مشترك |
| | CS | **GPIO 5** | Chip Select |
| | RESET | **GPIO 4** | Reset Signal |
| | **A0 (DC)** | **GPIO 27** | **(تعديلك المختار - آمن جداً)** |
| | SDA (MOSI) | **GPIO 23** | SPI Data |
| | SCK (CLK) | **GPIO 18** | SPI Clock |
| **Inductive Sensor**| Signal (Out) | **GPIO 34** | **Voltage Divider** (10k/20k) لخفض الـ 12V |
| **IR Sensor** | Signal (Out) | **GPIO 35** | Input Only Pin |
| **4 Ultrasonics** | Trigger (A,B) | **GPIO 13,14** | موصلين بالتوازي لجميع الحساسات |
| | Echo 1 | **GPIO 32** | للحساس الأول |
| | Echo 2 | **GPIO 33** | للحساس الثاني |
| | Echo 3 | **GPIO 25** | للحساس الثالث |
| | Echo 4 | **GPIO 26** | للحساس الرابع |
| **2 Load Cells** | SCK (All) | **GPIO 22** | Clock مشترك لوحدات HX711 |
| | DT 1 | **GPIO 21** | Data لول لود سيل |
| | DT 2 | **GPIO 19** | Data لتاني لود سيل (بعيداً عن GPIO 12) |
| **Stepper Motor** | STEP | **GPIO 17** | نبضات الحركة |
| | DIR | **GPIO 16** | تحديد الاتجاه |
| **Push Button** | Signal | **GPIO 15** | يوصل بـ GND (استخدم INPUT_PULLUP) |

---

### ⚠️ ملاحظات الطاقة (Power Management)
* **NEMA 17 Stepper:** يجب استخدام مصدر طاقة **12V خارجي** وتوصيل مكثف **100µF** بين (VMOT & GND) في درايفر DRV8825.
* **Common Ground:** تأكدي من ربط جميع الـ Grounds (البطارية، الـ ESP32، الدرايفر) معاً.
* **Logic Levels:** الـ ESP32 تعمل بـ **3.3V**. أي إشارة تدخل من حساس المعادن (12V) يجب خفضها بمقسم جهد.