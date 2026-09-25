#include "telemetry.h"

#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <time.h>

#include "config.h"

namespace {

struct RetryEntry {
    bool occupied = false;
    bool sensorOk = false;
    uint16_t distanceMm = 0;
    uint16_t stddevX100 = 0;
    uint8_t validCount = 0;
    uint32_t batteryMv = 0;
    // Hora real de la medición si el reloj ya estaba en hora (el RTC la
    // conserva durante el deep sleep una vez sincronizado por NTP); 0 si no.
    uint32_t capturedEpochS = 0;
    // Respaldo cuando no había hora: ciclos de sueño transcurridos, estimados.
    uint32_t minutesAgo = 0;
};

// RTC slow memory: sobrevive el deep sleep; ESP-IDF la reinicia en
// cualquier otro tipo de arranque (reset, flasheo, corte de alimentación).
RTC_DATA_ATTR RetryEntry retryBuffer[RETRY_BUFFER_SLOTS];
RTC_DATA_ATTR uint32_t bootCount = 0;

// 1700000000 ~= 2023-11-14, piso sano para saber si el reloj está en hora.
constexpr time_t MIN_VALID_EPOCH = 1700000000;

bool clockIsSet() {
    return time(nullptr) >= MIN_VALID_EPOCH;
}

// Sincroniza NTP para poder poner timestamps absolutos en las muestras del
// buffer de reintento. Si falla (sin internet real, DNS caído, etc.), las
// líneas se mandan sin timestamp explícito y Grafana Cloud les pone la hora
// de llegada.
bool syncTime() {
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    uint32_t start = millis();
    while (!clockIsSet() && millis() - start < 5000) {
        delay(100);
    }
    return clockIsSet();
}

// status: 0 = medición del ciclo, 1 = medición reenviada desde el buffer,
// 2 = el sensor falló (en ese caso no se manda distancia: un 0 ensuciaría
// la serie de distancia en Grafana).
void appendLine(String &body, const DeviceSettings &settings, bool sensorOk,
                 uint16_t distanceMm, float stddev, int validCount, uint8_t status,
                 uint32_t batteryMv, int32_t rssi, int64_t timestampEpochS) {
    char fields[160];
    if (sensorOk) {
        snprintf(fields, sizeof(fields),
                 "distance_mm=%u,stddev=%.1f,valid=%d,status=%u,battery_mv=%u,rssi=%d,boots=%u",
                 distanceMm, stddev, validCount, status, batteryMv, rssi, bootCount);
    } else {
        snprintf(fields, sizeof(fields), "valid=0,status=2,battery_mv=%u,rssi=%d,boots=%u",
                 batteryMv, rssi, bootCount);
    }

    char line[256];
    const char *tag = settings.deviceTag.length() ? settings.deviceTag.c_str() : DEFAULT_DEVICE_TAG;
    if (timestampEpochS > 0) {
        snprintf(line, sizeof(line), "eggbasket,device=%s %s %lld\n", tag, fields,
                 (long long)(timestampEpochS * 1000000000LL));
    } else {
        snprintf(line, sizeof(line), "eggbasket,device=%s %s\n", tag, fields);
    }
    body += line;
}

// Acepta lo que el usuario haya pegado en el portal (host solo, host con
// "https://", con barra final, o incluso una URL con el path equivocado o
// faltante como "https://prometheus-us-central1.grafana.net" a secas) y
// siempre arma la URL final correcta: esquema + host + INFLUX_WRITE_PATH.
// Cualquier path/query que el usuario haya incluido se descarta, porque el
// path de escritura Influx es el mismo para todas las cuentas.
String normalizeInfluxWriteUrl(const String &raw) {
    String s = raw;
    s.trim();
    if (s.length() == 0) return s;

    if (!s.startsWith("http://") && !s.startsWith("https://")) {
        s = "https://" + s;
    }

    int schemeEnd = s.indexOf("://") + 3;
    int pathStart = s.indexOf('/', schemeEnd);
    String hostPart = (pathStart == -1) ? s : s.substring(0, pathStart);
    while (hostPart.endsWith("/")) hostPart.remove(hostPart.length() - 1);

    return hostPart + INFLUX_WRITE_PATH;
}

int findSlotForNewEntry() {
    for (int i = 0; i < RETRY_BUFFER_SLOTS; i++) {
        if (!retryBuffer[i].occupied) return i;
    }
    // Buffer lleno: descartar la entrada más vieja (mayor minutesAgo, que
    // crece para todas por igual en cada ciclo).
    int oldest = 0;
    for (int i = 1; i < RETRY_BUFFER_SLOTS; i++) {
        if (retryBuffer[i].minutesAgo > retryBuffer[oldest].minutesAgo) oldest = i;
    }
    Serial.println("Buffer de reintento lleno: se descarta la muestra mas vieja");
    return oldest;
}

void queueReading(const SensorReading &reading, uint32_t batteryMv, uint32_t capturedEpochS) {
    RetryEntry &e = retryBuffer[findSlotForNewEntry()];
    e.occupied = true;
    e.sensorOk = reading.sensorOk;
    e.distanceMm = reading.medianDistanceMm;
    e.stddevX100 = static_cast<uint16_t>(reading.stddevMm * 100.0f);
    e.validCount = static_cast<uint8_t>(reading.validCount);
    e.batteryMv = batteryMv;
    e.capturedEpochS = capturedEpochS;
    e.minutesAgo = 0;
}

int queuedCount() {
    int n = 0;
    for (auto &entry : retryBuffer) {
        if (entry.occupied) n++;
    }
    return n;
}

void clearQueue() {
    for (auto &entry : retryBuffer) entry.occupied = false;
}

}  // namespace

namespace telemetry {

bool sendReading(const DeviceSettings &settings, const SensorReading &reading,
                  uint32_t batteryMv, int32_t rssi) {
    bootCount++;

    // Hora de esta medición según el RTC, antes de intentar NTP: si el WiFi
    // falla, la muestra se guarda igual con su hora real.
    uint32_t capturedEpochS = clockIsSet() ? static_cast<uint32_t>(time(nullptr)) : 0;

    // Las entradas sin hora real envejecen un ciclo más.
    for (auto &entry : retryBuffer) {
        if (entry.occupied) entry.minutesAgo += settings.sleepMinutes;
    }

    bool haveTime = (WiFi.status() == WL_CONNECTED) && syncTime();
    time_t nowEpoch = haveTime ? time(nullptr) : 0;
    if (!capturedEpochS && haveTime) capturedEpochS = static_cast<uint32_t>(nowEpoch);

    // Sin hora no se pueden mandar varias muestras de la misma serie: todas
    // llegarían con la hora de llegada y chocarían entre sí, y Grafana podría
    // quedarse con una vieja. En ese caso sólo va la actual y el buffer espera.
    int queued = queuedCount();
    bool sendQueued = haveTime && queued > 0;

    String body;
    if (sendQueued) {
        for (auto &entry : retryBuffer) {
            if (!entry.occupied) continue;
            int64_t ts = entry.capturedEpochS
                             ? static_cast<int64_t>(entry.capturedEpochS)
                             : static_cast<int64_t>(nowEpoch) - static_cast<int64_t>(entry.minutesAgo) * 60;
            appendLine(body, settings, entry.sensorOk, entry.distanceMm, entry.stddevX100 / 100.0f,
                       entry.validCount, /*status=*/1, entry.batteryMv, rssi, ts);
        }
    }
    appendLine(body, settings, reading.sensorOk, reading.medianDistanceMm, reading.stddevMm,
               reading.validCount, /*status=*/reading.sensorOk ? 0 : 2, batteryMv, rssi,
               haveTime ? nowEpoch : 0);

    if (WiFi.status() != WL_CONNECTED) {
        queueReading(reading, batteryMv, capturedEpochS);
        Serial.printf("Sin WiFi: muestra guardada (%d en el buffer)\n", queuedCount());
        return false;
    }

    String url = normalizeInfluxWriteUrl(settings.influxUrl);
    Serial.printf("Influx POST -> %s (%d muestra(s): %d del buffer + la actual%s)\n", url.c_str(),
                  (sendQueued ? queued : 0) + 1, sendQueued ? queued : 0,
                  (!haveTime && queued) ? "; sin hora NTP, el buffer espera" : "");
    Serial.print(body);  // exactamente lo que se envía, para comparar con la medición

    WiFiClientSecure client;
    client.setInsecure();  // sin pinning de certificado; ver docs/wiring.md para el trade-off

    HTTPClient http;
    http.setTimeout(HTTP_TIMEOUT_MS);
    int code = 0;
    if (http.begin(client, url)) {
        http.addHeader("Content-Type", "text/plain");
        http.setAuthorization(settings.influxUser.c_str(), settings.influxToken.c_str());
        code = http.POST(body);
        if (code > 0) {
            Serial.printf("Influx POST -> HTTP %d\n", code);
            if (code < 200 || code >= 300) Serial.println(http.getString());  // motivo del rechazo
        } else {
            Serial.printf("Influx POST -> error de conexion (%s)\n", http.errorToString(code).c_str());
        }
        http.end();
    } else {
        Serial.println("Influx POST -> http.begin() fallo, revisar influx_url guardada en el portal");
    }

    bool ok = code >= 200 && code < 300;
    // 400/413/422: Grafana rechazó los datos en sí (p. ej. una muestra vieja
    // o fuera de orden). Reenviarlos no va a funcionar nunca y trabaría el
    // buffer para siempre, así que se descartan. En cambio 401/403/404/429,
    // 5xx o errores de conexión son problemas pasajeros o de configuración:
    // ahí sí se guarda para reintentar.
    bool rejected = code == 400 || code == 413 || code == 422;

    if (ok) {
        if (sendQueued) clearQueue();
    } else if (rejected) {
        Serial.printf("Grafana rechazo los datos: se descartan (%d del buffer + la actual)\n",
                      sendQueued ? queued : 0);
        if (sendQueued) clearQueue();
    } else {
        queueReading(reading, batteryMv, capturedEpochS);
        Serial.printf("Muestra guardada para reintentar (%d en el buffer)\n", queuedCount());
    }
    return ok;
}

}  // namespace telemetry
