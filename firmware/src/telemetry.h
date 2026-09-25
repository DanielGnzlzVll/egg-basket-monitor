#pragma once

#include <Arduino.h>

#include "sensor.h"
#include "settings.h"

namespace telemetry {

// Arma las líneas Influx (las pendientes del buffer RTC + la muestra actual,
// cada una con su hora real) y las manda en un solo POST HTTPS a
// settings.influxUrl con Basic Auth. Devuelve true si el servidor respondió
// 2xx, y en ese caso vacía el buffer. Si falla la conexión o el servidor
// (5xx, 401/403/404/429), guarda la muestra actual para el próximo ciclo; si
// Grafana rechaza los datos (400/413/422), los descarta en vez de reintentar
// para siempre. Sin WiFi sólo guarda la muestra.
bool sendReading(const DeviceSettings &settings, const SensorReading &reading,
                  uint32_t batteryMv, int32_t rssi);

}  // namespace telemetry
