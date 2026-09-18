#include "telemetry.h"

#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <time.h>

#include "config.h"

namespace {

struct RetryEntry {
    bool occupied = false;
    uint16_t distanceMm = 0;
    uint16_t stddevX100 = 0;
    uint8_t validCount = 0;
    uint32_t batteryMv = 0;
    uint32_t minutesAgo = 0;
};

// RTC slow memory: sobrevive deep sleep, se borra solo con power-on-reset
// real (celda desconectada / botón EN mantenido con USB desconectado).
RTC_DATA_ATTR RetryEntry retryBuffer[RETRY_BUFFER_SLOTS];
RTC_DATA_ATTR uint32_t bootCount = 0;

// Sincroniza NTP para poder poner timestamps absolutos en las muestras del
// buffer de reintento. Si falla (sin internet real, DNS caído, etc.), las
// líneas se mandan sin timestamp explícito y Grafana Cloud les pone la hora
// de llegada.
bool syncTime() {
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    time_t now = time(nullptr);
    uint32_t start = millis();
    // 1700000000 ~= 2023-11-14, piso sano para detectar que NTP ya contestó.
    while (now < 1700000000 && millis() - start < 5000) {
        delay(100);
        now = time(nullptr);
    }
    return now >= 1700000000;
}

void appendLine(String &body, const DeviceSettings &settings, uint16_t distanceMm,
                 float stddev, int validCount, uint8_t status, uint32_t batteryMv,
                 int32_t rssi, int64_t timestampEpochS) {
    char line[256];
    const char *tag = settings.deviceTag.length() ? settings.deviceTag.c_str() : DEFAULT_DEVICE_TAG;

    if (timestampEpochS > 0) {
        int64_t ns = timestampEpochS * 1000000000LL;
        snprintf(line, sizeof(line),
                 "eggbasket,device=%s distance_mm=%u,stddev=%.1f,valid=%d,status=%u,"
                 "battery_mv=%u,rssi=%d,boots=%u %lld\n",
                 tag, distanceMm, stddev, validCount, status, batteryMv, rssi, bootCount,
                 (long long)ns);
    } else {
        snprintf(line, sizeof(line),
                 "eggbasket,device=%s distance_mm=%u,stddev=%.1f,valid=%d,status=%u,"
                 "battery_mv=%u,rssi=%d,boots=%u\n",
                 tag, distanceMm, stddev, validCount, status, batteryMv, rssi, bootCount);
    }
    body += line;
}

int findSlotForNewEntry() {
    for (int i = 0; i < RETRY_BUFFER_SLOTS; i++) {
        if (!retryBuffer[i].occupied) return i;
    }
    // Buffer lleno: descartar la entrada más vieja (mayor minutesAgo).
    int oldest = 0;
    for (int i = 1; i < RETRY_BUFFER_SLOTS; i++) {
        if (retryBuffer[i].minutesAgo > retryBuffer[oldest].minutesAgo) oldest = i;
    }
    return oldest;
}

}  // namespace

namespace telemetry {

bool sendReading(const DeviceSettings &settings, const SensorReading &reading,
                  uint32_t batteryMv, int32_t rssi) {
    bootCount++;

    // Las entradas ya guardadas envejecen un ciclo más, hayan podido
    // enviarse o no en esta pasada.
    for (auto &entry : retryBuffer) {
        if (entry.occupied) entry.minutesAgo += settings.sleepMinutes;
    }

    bool haveTime = syncTime();
    time_t nowEpoch = haveTime ? time(nullptr) : 0;

    String body;
    for (auto &entry : retryBuffer) {
        if (!entry.occupied) continue;
        int64_t ts = haveTime ? (nowEpoch - static_cast<int64_t>(entry.minutesAgo) * 60) : 0;
        appendLine(body, settings, entry.distanceMm, entry.stddevX100 / 100.0f, entry.validCount,
                   /*status=*/1, entry.batteryMv, rssi, ts);
    }
    appendLine(body, settings, reading.medianDistanceMm, reading.stddevMm, reading.validCount,
               /*status=*/reading.sensorOk ? 0 : 2, batteryMv, rssi,
               haveTime ? nowEpoch : 0);

    WiFiClientSecure client;
    client.setInsecure();  // sin pinning de certificado; ver docs/wiring.md para el trade-off

    HTTPClient http;
    http.setTimeout(HTTP_TIMEOUT_MS);
    bool ok = false;
    if (http.begin(client, settings.influxUrl)) {
        http.addHeader("Content-Type", "text/plain");
        http.setAuthorization(settings.influxUser.c_str(), settings.influxToken.c_str());
        int code = http.POST(body);
        ok = (code >= 200 && code < 300);
        http.end();
    }

    if (ok) {
        for (auto &entry : retryBuffer) entry.occupied = false;
    } else {
        int slot = findSlotForNewEntry();
        retryBuffer[slot].occupied = true;
        retryBuffer[slot].distanceMm = reading.medianDistanceMm;
        retryBuffer[slot].stddevX100 = static_cast<uint16_t>(reading.stddevMm * 100.0f);
        retryBuffer[slot].validCount = static_cast<uint8_t>(reading.validCount);
        retryBuffer[slot].batteryMv = batteryMv;
        retryBuffer[slot].minutesAgo = 0;
    }

    return ok;
}

}  // namespace telemetry
