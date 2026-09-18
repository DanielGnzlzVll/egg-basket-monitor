#pragma once

#include <Arduino.h>

struct SensorReading {
    uint16_t medianDistanceMm = 0;
    float stddevMm = 0.0f;
    int validCount = 0;
    bool sensorOk = false;
};

namespace sensor {

// Enciende el VL53L1X (XSHUT alto), lo inicializa con el ROI reducido y modo
// short, toma SENSOR_SAMPLE_COUNT lecturas y devuelve mediana + desviación
// estándar. Vuelve a apagar el sensor (XSHUT bajo) antes de retornar.
SensorReading readDistance();

// Modo calibración: imprime distancia cruda por serial a 2Hz durante
// durationMs. No calcula mediana ni ROI reducido (para ver el rango crudo
// mientras se ajusta el ángulo).
void runCalibrationStream(uint32_t durationMs);

}  // namespace sensor
