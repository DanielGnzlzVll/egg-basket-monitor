#pragma once

#include <Arduino.h>

#include "config.h"

// Envuelve Preferences (NVS) para guardar todo lo que antes vivía en
// secrets.h. Se llena desde el portal de configuración (portal.cpp) y se lee
// en el ciclo normal (main.cpp / telemetry.cpp).
struct DeviceSettings {
    String wifiSsid;
    String wifiPassword;
    String influxUrl;
    String influxUser;    // Instance ID de Grafana Cloud
    String influxToken;   // Access Policy token
    String deviceTag;
    uint32_t sleepMinutes = DEFAULT_SLEEP_MINUTES;

    bool isComplete() const {
        return wifiSsid.length() > 0 && influxUrl.length() > 0 &&
               influxUser.length() > 0 && influxToken.length() > 0;
    }
};

namespace settings {

// Carga la configuración guardada. Si no hay nada, devuelve una instancia
// con deviceTag/sleepMinutes por defecto y el resto vacío.
DeviceSettings load();

// Persiste toda la configuración de una vez (llamado al guardar el portal).
void save(const DeviceSettings &settings);

// Borra toda la configuración guardada (no usado por firmware normal, útil
// para pruebas manuales vía serial).
void clear();

}  // namespace settings
