#include "boot_mode.h"

#include <Arduino.h>

#include "config.h"
#include "power.h"

namespace boot_mode {

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
        return BootMode::Normal;
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
        // Presión corta accidental: se ignora, sigue el ciclo normal.
        return BootMode::Normal;
    }
    if (elapsed <= CALIBRATION_HOLD_MAX_MS) {
        return BootMode::Calibration;
    }
    return BootMode::Config;
}

}  // namespace boot_mode
