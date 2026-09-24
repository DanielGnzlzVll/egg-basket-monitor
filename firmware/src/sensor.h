#pragma once

#include <Arduino.h>

struct SensorReading {
    uint16_t medianDistanceMm = 0;
    float stddevMm = 0.0f;
    int validCount = 0;
    bool sensorOk = false;
};

namespace sensor {

// Enciende el VL53L0X (suelta XSHUT), lo inicializa, toma SENSOR_SAMPLE_COUNT
// lecturas y devuelve mediana + desviación estándar de las válidas. Vuelve a
// apagar el sensor (XSHUT bajo) antes de retornar.
SensorReading readDistance();

// Modo calibración: imprime distancia cruda por serial a 2Hz durante
// durationMs. No calcula mediana (para ver el rango crudo mientras se ajusta
// el ángulo).
void runCalibrationStream(uint32_t durationMs);

}  // namespace sensor
