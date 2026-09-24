#include "sensor.h"

#include <VL53L0X.h>
#include <Wire.h>
#include <math.h>

#include "config.h"

namespace {

// El módulo instalado es un TOF200C, que lleva un VL53L0X (no un VL53L1X):
// los dos contestan en 0x29 pero el VL53L0X usa direcciones de registro de
// 8 bits y el VL53L1X de 16, así que la librería del VL53L1X nunca pasaba de
// init(). Ver docs/wiring.md.
VL53L0X vl53;

// Estado de medición del VL53L0X (bits 6..3 de RESULT_RANGE_STATUS) que
// corresponde a "medición completa"; el resto son fallos de señal, sigma,
// fase o hardware.
constexpr uint8_t RANGE_STATUS_VALID = 11;

// 8190/8191 mm es lo que devuelve el VL53L0X cuando no hay objetivo en rango.
constexpr uint16_t RANGE_OUT_OF_RANGE_MM = 8190;

void powerOn() {
    // XSHUT se suelta en vez de forzarlo a 3.3 V: el módulo lo trae con
    // pull-up a su propio regulador. El pull-up interno cubre módulos sin él.
    pinMode(PIN_XSHUT, INPUT_PULLUP);
    // t_BOOT del VL53L0X es 1.2 ms como máximo, pero no tiene registro de
    // "arrancado" que consultar; se deja margen de sobra.
    delay(50);
}

void powerOff() {
    pinMode(PIN_XSHUT, OUTPUT);
    digitalWrite(PIN_XSHUT, LOW);
}

bool initSensor() {
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    vl53.setTimeout(500);
    if (!vl53.init()) {
        return false;
    }
    // 50 ms por medición en vez de los ~33 ms por defecto: menos ruido, y el
    // rango real de esta instalación (345-450mm) no necesita el perfil de
    // largo alcance.
    vl53.setMeasurementTimingBudget(50000);
    vl53.startContinuous();
    return true;
}

// Como readRangeContinuousMillimeters() de la librería, pero devuelve además
// el estado de la medición, que la librería descarta. false = timeout.
bool readMeasurement(uint16_t &mm, uint8_t &status) {
    uint32_t start = millis();
    while ((vl53.readReg(VL53L0X::RESULT_INTERRUPT_STATUS) & 0x07) == 0) {
        if (millis() - start > vl53.getTimeout()) {
            return false;
        }
    }
    status = (vl53.readReg(VL53L0X::RESULT_RANGE_STATUS) >> 3) & 0x0F;
    mm = vl53.readReg16Bit(VL53L0X::RESULT_RANGE_STATUS + 10);
    vl53.writeReg(VL53L0X::SYSTEM_INTERRUPT_CLEAR, 0x01);
    return true;
}

bool isValid(uint16_t mm, uint8_t status) {
    return status == RANGE_STATUS_VALID && mm < RANGE_OUT_OF_RANGE_MM;
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
        uint16_t mm;
        uint8_t status;
        if (readMeasurement(mm, status) && isValid(mm, status)) {
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
        Serial.println("VL53L0X: fallo de init, revisar cableado (ver docs/wiring.md)");
        powerOff();
        return;
    }

    uint32_t start = millis();
    while (millis() - start < durationMs) {
        uint16_t mm;
        uint8_t status;
        if (readMeasurement(mm, status)) {
            Serial.printf("distancia_mm=%u status=%u%s\n", mm, status,
                          isValid(mm, status) ? "" : " (invalida)");
        } else {
            Serial.println("timeout leyendo el sensor");
        }
        delay(500);  // 2 Hz
    }

    vl53.stopContinuous();
    powerOff();
}

}  // namespace sensor
