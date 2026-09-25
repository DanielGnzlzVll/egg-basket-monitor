#include "boot_mode.h"

#include <Arduino.h>

#include "config.h"
#include "power.h"

namespace boot_mode {

namespace {

// true si hay una PC por USB con un monitor serie abierto leyendo el puerto.
// En batería o con un cargador no hay host USB: HWCDC lo detecta en ~5 ms
// (no llegan los SOF del host) y no se espera nada. Con la PC conectada pero
// sin monitor abierto se espera SERIAL_MONITOR_WAIT_MS, que es lo que tarda el
// monitor en reconectarse después de un reset o de flashear.
bool serialMonitorOpen() {
#if AUTO_CALIBRATION_ON_SERIAL && ARDUINO_USB_MODE && ARDUINO_USB_CDC_ON_BOOT
    delay(20);  // HWCDC arranca suponiendo "conectado" hasta confirmar lo contrario
    if (!HWCDC::isPlugged()) {
        return false;
    }
    uint32_t start = millis();
    while (millis() - start < SERIAL_MONITOR_WAIT_MS) {
        if (Serial) {  // el host leyó el puerto: hay un monitor abierto
            Serial.println("Monitor serie detectado: modo calibracion automatico");
            return true;
        }
        delay(10);
    }
#endif
    return false;
}

}  // namespace

BootMode detect(bool hasStoredWifi) {
    pinMode(PIN_BOOT_BUTTON, INPUT_PULLUP);

    if (!hasStoredWifi) {
        // Primer arranque de fábrica: no hay a qué conectarse, entra directo
        // al portal sin exigir que se sostenga el botón.
        return BootMode::Config;
    }

    // Debounce corto: si el botón no está presionado en este instante, el
    // usuario no lo está sosteniendo desde antes del reset/wake, así que no
    // vale la pena esperar la ventana completa. Esto mantiene el ciclo
    // normal en los ~6s originales del presupuesto energético.
    delay(30);
    if (digitalRead(PIN_BOOT_BUTTON) == HIGH) {
        return serialMonitorOpen() ? BootMode::Calibration : BootMode::Normal;
    }

    uint32_t start = millis();
    uint32_t elapsed = 0;
    while (digitalRead(PIN_BOOT_BUTTON) == LOW && elapsed < BOOT_DECISION_WINDOW_MS) {
        elapsed = millis() - start;
        if (elapsed % 500 < 50) {
            power::showLed(LedPattern::BootWaiting);
        }
        delay(20);
    }

    if (elapsed < CALIBRATION_HOLD_MIN_MS) {
        // Presión corta accidental: se ignora, como si no se hubiera tocado.
        return serialMonitorOpen() ? BootMode::Calibration : BootMode::Normal;
    }
    if (elapsed <= CALIBRATION_HOLD_MAX_MS) {
        return BootMode::Calibration;
    }
    return BootMode::Config;
}

}  // namespace boot_mode
