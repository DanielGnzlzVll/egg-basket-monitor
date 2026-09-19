#include "power.h"

#include <esp_sleep.h>

#include "config.h"

#if STATUS_LED_IS_NEOPIXEL
#include <Adafruit_NeoPixel.h>
namespace {
Adafruit_NeoPixel led(1, PIN_STATUS_LED, NEO_GRB + NEO_KHZ800);

void setColor(uint8_t r, uint8_t g, uint8_t b) {
    led.setPixelColor(0, led.Color(r, g, b));
    led.show();
}

void blink(uint8_t r, uint8_t g, uint8_t b, int times, uint32_t onMs, uint32_t offMs) {
    for (int i = 0; i < times; i++) {
        setColor(r, g, b);
        delay(onMs);
        setColor(0, 0, 0);
        if (i != times - 1) delay(offMs);
    }
}
}  // namespace
#else
namespace {
void blinkSimple(int times, uint32_t onMs, uint32_t offMs) {
    for (int i = 0; i < times; i++) {
        digitalWrite(PIN_STATUS_LED, HIGH);
        delay(onMs);
        digitalWrite(PIN_STATUS_LED, LOW);
        if (i != times - 1) delay(offMs);
    }
}
}  // namespace
#endif

namespace power {

void initLed() {
#if STATUS_LED_IS_NEOPIXEL
    led.begin();
    led.show();
#else
    pinMode(PIN_STATUS_LED, OUTPUT);
    digitalWrite(PIN_STATUS_LED, LOW);
#endif
}

void showLed(LedPattern pattern) {
#if STATUS_LED_IS_NEOPIXEL
    switch (pattern) {
        case LedPattern::BootWaiting:
            blink(0, 0, 40, 1, 120, 0);
            break;
        case LedPattern::CalibrationEntered:
            blink(0, 60, 0, 2, 200, 150);
            break;
        case LedPattern::ConfigEntered:
            blink(0, 0, 60, 3, 200, 150);
            break;
        case LedPattern::ConfigActive:
            setColor(0, 0, 60);
            break;
        case LedPattern::PostSuccess:
            blink(0, 60, 0, 1, 150, 0);
            break;
        case LedPattern::PostFailed:
            blink(60, 0, 0, 1, 150, 0);
            break;
        case LedPattern::BatteryCutoff:
            blink(60, 0, 0, 3, 200, 150);
            break;
    }
#else
    switch (pattern) {
        case LedPattern::BootWaiting:
            blinkSimple(1, 120, 0);
            break;
        case LedPattern::CalibrationEntered:
            blinkSimple(2, 200, 150);
            break;
        case LedPattern::ConfigEntered:
            blinkSimple(3, 200, 150);
            break;
        case LedPattern::ConfigActive:
            digitalWrite(PIN_STATUS_LED, HIGH);
            break;
        case LedPattern::PostSuccess:
            blinkSimple(1, 150, 0);
            break;
        case LedPattern::PostFailed:
            blinkSimple(2, 100, 100);
            break;
        case LedPattern::BatteryCutoff:
            blinkSimple(5, 100, 100);
            break;
    }
#endif
}

void ledOff() {
#if STATUS_LED_IS_NEOPIXEL
    setColor(0, 0, 0);
#else
    digitalWrite(PIN_STATUS_LED, LOW);
#endif
}

float readBatteryVolts() {
    // ADC de 12 bits, atenuación por defecto ~11dB (rango ~0-3.3V en el pin).
    analogReadResolution(12);
    int raw = analogRead(PIN_BATTERY_ADC);
    float pinVolts = (raw / 4095.0f) * 3.3f;
    return pinVolts * BATTERY_DIVIDER_RATIO;
}

uint32_t readBatteryMillivolts() {
    return static_cast<uint32_t>(readBatteryVolts() * 1000.0f);
}

void deepSleepIndefinitely() {
    ledOff();
    Serial.flush();
    delay(50);  // deja que el USB-CDC termine de transmitir antes de cortar la energia
    esp_deep_sleep_start();
    while (true) {
        // No debería llegar aquí; esp_deep_sleep_start no retorna.
    }
}

void deepSleepFor(uint32_t minutes) {
    ledOff();
    Serial.flush();
    delay(50);  // deja que el USB-CDC termine de transmitir antes de cortar la energia
    uint64_t microseconds = static_cast<uint64_t>(minutes) * 60ULL * 1000000ULL;
    esp_sleep_enable_timer_wakeup(microseconds);
    esp_deep_sleep_start();
    while (true) {
        // No debería llegar aquí; esp_deep_sleep_start no retorna.
    }
}

}  // namespace power
