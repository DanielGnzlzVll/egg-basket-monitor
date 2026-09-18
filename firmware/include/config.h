#pragma once

#include <Arduino.h>

// ---------------------------------------------------------------------------
// Pinout — ver docs/wiring.md para el diagrama completo.
// Se evitan los pines I2C por defecto del C3 SuperMini (GPIO8/9): GPIO8 es
// el LED RGB integrado y GPIO9 es el botón BOOT.
// ---------------------------------------------------------------------------
constexpr int PIN_I2C_SDA = 4;
constexpr int PIN_I2C_SCL = 5;
constexpr int PIN_XSHUT = 6;
constexpr int PIN_BATTERY_ADC = 3;
constexpr int PIN_BOOT_BUTTON = 9;   // activo en bajo, pull-up interno
constexpr int PIN_STATUS_LED = 8;    // RGB integrado del C3 SuperMini

// La mayoría de las placas "C3 SuperMini" traen un WS2812 direccionable en
// GPIO8. Algunas variantes traen en cambio un LED simple de un solo color.
// Si el LED no enciende con colores o queda siempre apagado, cambiar a 0 y
// power.cpp usa digitalWrite/parpadeo simple en su lugar.
#define STATUS_LED_IS_NEOPIXEL 1

// ---------------------------------------------------------------------------
// Umbrales de arranque
// ---------------------------------------------------------------------------
constexpr uint32_t BOOT_DECISION_WINDOW_MS = 8500;   // ventana total de lectura del botón
constexpr uint32_t CALIBRATION_HOLD_MIN_MS = 3000;   // 3-8s => modo calibración
constexpr uint32_t CALIBRATION_HOLD_MAX_MS = 8000;
constexpr uint32_t CONFIG_HOLD_MIN_MS = 8000;        // >8s => modo config

// ---------------------------------------------------------------------------
// Portal de configuración (WiFiManager)
// ---------------------------------------------------------------------------
constexpr const char *AP_SSID = "EggBasket-Setup";
constexpr const char *AP_PASSWORD = "eggbasket2026"; // cambiar antes de flashear si se desea
constexpr uint32_t PORTAL_TIMEOUT_S = 5 * 60;        // 5 minutos sin actividad

// ---------------------------------------------------------------------------
// Medición
// ---------------------------------------------------------------------------
constexpr int SENSOR_SAMPLE_COUNT = 20;
constexpr uint16_t SENSOR_ROI_WIDTH = 4;   // SPADs, ROI mínimo del VL53L1X
constexpr uint16_t SENSOR_ROI_HEIGHT = 4;

// ---------------------------------------------------------------------------
// Batería
// ---------------------------------------------------------------------------
constexpr float BATTERY_DIVIDER_RATIO = 2.0f;   // divisor 1M/1M
constexpr float BATTERY_CUTOFF_VOLTS = 3.3f;

// ---------------------------------------------------------------------------
// Config por defecto (usada solo si no hay nada guardado en NVS)
// ---------------------------------------------------------------------------
constexpr const char *DEFAULT_DEVICE_TAG = "cocina";
constexpr uint32_t DEFAULT_SLEEP_MINUTES = 60;
constexpr uint32_t MIN_SLEEP_MINUTES = 5;
constexpr uint32_t MAX_SLEEP_MINUTES = 1440;

constexpr uint32_t WIFI_CONNECT_TIMEOUT_MS = 15000;
constexpr uint32_t HTTP_TIMEOUT_MS = 10000;

constexpr int RETRY_BUFFER_SLOTS = 3;
