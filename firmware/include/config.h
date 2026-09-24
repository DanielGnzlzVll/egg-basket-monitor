#pragma once

#include <Arduino.h>

// ---------------------------------------------------------------------------
// Pinout — ver docs/wiring.md para el diagrama completo.
//
// En el ESP32-C3 SuperMini el número serigrafiado junto a cada pin ES el
// número de GPIO (el pin marcado "4" en la placa es GPIO4): no hay alias
// tipo D0/D1 como en otras placas Arduino/ESP8266. Por eso cada constante de
// abajo lleva el número tal cual aparece impreso en la placa (GPIOx_...) y
// además un alias con el nombre funcional (PIN_...) que es el que usa el
// resto del firmware.
//
// Se evita el bus I2C por defecto del C3 (GPIO8/GPIO9) porque GPIO8 es el
// LED RGB integrado y GPIO9 es el botón BOOT; el I2C se remapea a GPIO4/5.
// ---------------------------------------------------------------------------
constexpr int GPIO4_SDA = 4;          // marcado "4" en la placa
constexpr int GPIO5_SCL = 5;          // marcado "5" en la placa
constexpr int GPIO6_XSHUT = 6;        // marcado "6" en la placa
constexpr int GPIO3_BATTERY_ADC = 3;  // marcado "3" en la placa
constexpr int GPIO9_BOOT = 9;         // marcado "9" en la placa; boton BOOT integrado
constexpr int GPIO8_LED = 8;          // marcado "8" en la placa; LED RGB integrado

constexpr int PIN_I2C_SDA = GPIO4_SDA;
constexpr int PIN_I2C_SCL = GPIO5_SCL;
constexpr int PIN_XSHUT = GPIO6_XSHUT;
constexpr int PIN_BATTERY_ADC = GPIO3_BATTERY_ADC;
constexpr int PIN_BOOT_BUTTON = GPIO9_BOOT;  // activo en bajo, pull-up interno
constexpr int PIN_STATUS_LED = GPIO8_LED;

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
// El VL53L0X (módulo TOF200C) no tiene ROI: el cono de 25° es fijo.
constexpr int SENSOR_SAMPLE_COUNT = 20;

// ---------------------------------------------------------------------------
// Batería
// ---------------------------------------------------------------------------
// 2.0 porque el divisor usa dos resistencias IGUALES entre si (R1=R2): el
// punto medio siempre queda a mitad de camino sin importar el valor absoluto
// (1M/1M, 100k/100k, etc. dan el mismo 2.0). Solo cambia si R1 != R2.
constexpr float BATTERY_DIVIDER_RATIO = 2.0f;
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

// Ruta fija del endpoint de compatibilidad Influx de Grafana Cloud. Es igual
// para cualquier cuenta/region: lo unico que cambia entre usuarios es el
// host. telemetry.cpp la agrega automaticamente a lo que se haya guardado en
// el portal, aunque el usuario haya pegado solo el host (con o sin path,
// con o sin "https://") — asi un error de tipeo como pegar la URL de
// Prometheus sin esta ruta ya no rompe el envio.
constexpr const char *INFLUX_WRITE_PATH = "/api/v1/push/influx/write";

constexpr int RETRY_BUFFER_SLOTS = 3;
