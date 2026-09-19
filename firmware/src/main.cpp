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
    Serial.println("\n=== Ciclo normal ===");

    SensorReading reading = sensor::readDistance();
    if (reading.sensorOk) {
        Serial.printf("Sensor: distancia=%u mm  stddev=%.1f  validas=%d/%d\n",
                      reading.medianDistanceMm, reading.stddevMm, reading.validCount,
                      SENSOR_SAMPLE_COUNT);
    } else {
        Serial.println("Sensor: fallo de lectura (revisar cableado I2C, ver docs/wiring.md)");
    }

    float batteryVolts = power::readBatteryVolts();
    uint32_t batteryMv = static_cast<uint32_t>(batteryVolts * 1000.0f);
    Serial.printf("Bateria: %.2f V\n", batteryVolts);

    if (batteryVolts < BATTERY_CUTOFF_VOLTS) {
        Serial.println("Bateria por debajo del corte: durmiendo indefinidamente");
        Serial.flush();
        power::showLed(LedPattern::BatteryCutoff);
        power::deepSleepIndefinitely();
        // no retorna
    }

    DeviceSettings cfg = settings::load();

    Serial.printf("Conectando a WiFi '%s'...\n", cfg.wifiSsid.c_str());
    WiFi.mode(WIFI_STA);
    WiFi.begin(cfg.wifiSsid.c_str(), cfg.wifiPassword.c_str());
    uint32_t start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_CONNECT_TIMEOUT_MS) {
        delay(100);
    }

    bool posted = false;
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("WiFi conectado: IP=%s  RSSI=%ddBm\n", WiFi.localIP().toString().c_str(),
                      WiFi.RSSI());
        posted = telemetry::sendReading(cfg, reading, batteryMv, WiFi.RSSI());
    } else {
        // Sin conexión: igual encolamos la muestra pasando rssi=0. El envío
        // en sí solo puede fallar (no hay red), pero sendReading se encarga
        // de guardarla en el buffer de reintento.
        Serial.println("WiFi: no conecto dentro del timeout, se guarda la muestra para reintentar");
        telemetry::sendReading(cfg, reading, batteryMv, 0);
    }

    Serial.println(posted ? "POST a Grafana Cloud: OK"
                           : "POST a Grafana Cloud: FALLO (muestra guardada para el proximo ciclo)");

    power::showLed(posted ? LedPattern::PostSuccess : LedPattern::PostFailed);

    WiFi.disconnect(true);
    Serial.printf("Durmiendo %u minutos...\n", cfg.sleepMinutes);
    Serial.flush();
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
