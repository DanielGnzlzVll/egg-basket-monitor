#include <Arduino.h>
#include <WiFi.h>

#include "boot_mode.h"
#include "config.h"
#include "portal.h"
#include "power.h"
#include "sensor.h"
#include "settings.h"
#include "telemetry.h"

namespace {

void runNormalCycle() {
    SensorReading reading = sensor::readDistance();

    float batteryVolts = power::readBatteryVolts();
    uint32_t batteryMv = static_cast<uint32_t>(batteryVolts * 1000.0f);

    if (batteryVolts < BATTERY_CUTOFF_VOLTS) {
        power::showLed(LedPattern::BatteryCutoff);
        power::deepSleepIndefinitely();
        // no retorna
    }

    DeviceSettings cfg = settings::load();

    WiFi.mode(WIFI_STA);
    WiFi.begin(cfg.wifiSsid.c_str(), cfg.wifiPassword.c_str());
    uint32_t start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_CONNECT_TIMEOUT_MS) {
        delay(100);
    }

    bool posted = false;
    if (WiFi.status() == WL_CONNECTED) {
        posted = telemetry::sendReading(cfg, reading, batteryMv, WiFi.RSSI());
    } else {
        // Sin conexión: igual encolamos la muestra pasando rssi=0. El envío
        // en sí solo puede fallar (no hay red), pero sendReading se encarga
        // de guardarla en el buffer de reintento.
        telemetry::sendReading(cfg, reading, batteryMv, 0);
    }

    power::showLed(posted ? LedPattern::PostSuccess : LedPattern::PostFailed);

    WiFi.disconnect(true);
    power::deepSleepFor(cfg.sleepMinutes);
    // no retorna
}

}  // namespace

void setup() {
    Serial.begin(115200);
    power::initLed();

    DeviceSettings existing = settings::load();
    BootMode mode = boot_mode::detect(existing.wifiSsid.length() > 0);

    switch (mode) {
        case BootMode::Config: {
            power::showLed(LedPattern::ConfigEntered);
            bool saved = portal::runConfigPortal();
            if (saved) {
                ESP.restart();
            }
            // Timeout sin guardar: si ya había config previa, se reintenta
            // el ciclo normal; si no había ninguna, se vuelve a levantar el
            // portal en el próximo arranque.
            if (existing.isComplete()) {
                runNormalCycle();
            } else {
                power::deepSleepFor(1);  // reintenta el portal pronto
            }
            break;
        }
        case BootMode::Calibration: {
            power::showLed(LedPattern::CalibrationEntered);
            Serial.println("Modo calibracion: distancia cruda durante 60s a 2Hz");
            sensor::runCalibrationStream(60000);
            ESP.restart();
            break;
        }
        case BootMode::Normal:
        default:
            runNormalCycle();
            break;
    }
}

void loop() {
    // Todo el trabajo pasa en setup(); el dispositivo duerme antes de llegar
    // aca. loop() no debería ejecutarse nunca.
}
