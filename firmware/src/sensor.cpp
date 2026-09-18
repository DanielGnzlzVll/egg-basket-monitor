#include "sensor.h"

#include <VL53L1X.h>
#include <Wire.h>
#include <math.h>

#include "config.h"

namespace {

VL53L1X vl53;

void powerOn() {
    pinMode(PIN_XSHUT, OUTPUT);
    digitalWrite(PIN_XSHUT, HIGH);
    delay(2);  // t_BOOT del VL53L1X tras salir de standby
}

void powerOff() {
    digitalWrite(PIN_XSHUT, LOW);
}

bool initSensor() {
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    vl53.setTimeout(500);
    if (!vl53.init()) {
        return false;
    }
    // Modo short: menos alcance pero mayor inmunidad a luz ambiente. El
    // rango real de esta instalación (345-450mm) cae cómodo dentro de este
    // modo, ver docs/superpowers/specs/2026-09-04-egg-basket-monitor-design.md
    vl53.setDistanceMode(VL53L1X::Short);
    vl53.setROISize(SENSOR_ROI_WIDTH, SENSOR_ROI_HEIGHT);
    vl53.setMeasurementTimingBudget(50000);
    vl53.startContinuous(50);
    return true;
}

}  // namespace

namespace sensor {

SensorReading readDistance() {
    SensorReading result;
    powerOn();

    if (!initSensor()) {
        powerOff();
        return result;
    }

    uint16_t samples[SENSOR_SAMPLE_COUNT];
    int validCount = 0;

    for (int i = 0; i < SENSOR_SAMPLE_COUNT; i++) {
        uint16_t mm = vl53.read();
        if (!vl53.timeoutOccurred() && vl53.ranging_data.range_status == VL53L1X::RangeValid) {
            samples[validCount++] = mm;
        }
        delay(10);
    }

    vl53.stopContinuous();
    powerOff();

    if (validCount == 0) {
        result.sensorOk = false;
        return result;
    }

    // Mediana
    for (int i = 0; i < validCount - 1; i++) {
        for (int j = i + 1; j < validCount; j++) {
            if (samples[j] < samples[i]) {
                uint16_t tmp = samples[i];
                samples[i] = samples[j];
                samples[j] = tmp;
            }
        }
    }
    uint16_t median = samples[validCount / 2];

    // Desviación estándar
    float mean = 0;
    for (int i = 0; i < validCount; i++) mean += samples[i];
    mean /= validCount;
    float variance = 0;
    for (int i = 0; i < validCount; i++) {
        float d = samples[i] - mean;
        variance += d * d;
    }
    variance /= validCount;

    result.medianDistanceMm = median;
    result.stddevMm = sqrtf(variance);
    result.validCount = validCount;
    result.sensorOk = true;
    return result;
}

void runCalibrationStream(uint32_t durationMs) {
    powerOn();
    if (!initSensor()) {
        Serial.println("VL53L1X: fallo de init, revisar cableado (ver docs/wiring.md)");
        powerOff();
        return;
    }

    uint32_t start = millis();
    while (millis() - start < durationMs) {
        uint16_t mm = vl53.read();
        if (!vl53.timeoutOccurred()) {
            Serial.printf("distancia_mm=%u status=%d\n", mm, static_cast<int>(vl53.ranging_data.range_status));
        } else {
            Serial.println("timeout leyendo el sensor");
        }
        delay(500);  // 2 Hz
    }

    vl53.stopContinuous();
    powerOff();
}

}  // namespace sensor
