#pragma once

#include <Arduino.h>

#include "sensor.h"
#include "settings.h"

namespace telemetry {

// Arma la(s) línea(s) Influx (la muestra actual + cualquiera pendiente en el
// buffer RTC) y hace un POST HTTPS a settings.influxUrl con Basic Auth.
// Devuelve true si el servidor respondió 2xx. En éxito, vacía el buffer de
// reintento; en fallo, encola la muestra actual en el buffer (descartando la
// más vieja si está lleno).
bool sendReading(const DeviceSettings &settings, const SensorReading &reading,
                  uint32_t batteryMv, int32_t rssi);

}  // namespace telemetry
