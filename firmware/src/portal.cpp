#include "portal.h"

#include <WiFi.h>
#include <WiFiManager.h>

#include "config.h"
#include "power.h"
#include "settings.h"

namespace {
bool g_formSubmitted = false;

void onSaveConfig() {
    g_formSubmitted = true;
}
}  // namespace

namespace portal {

bool runConfigPortal() {
    DeviceSettings existing = settings::load();

    char sleepBuf[8];
    snprintf(sleepBuf, sizeof(sleepBuf), "%u",
             existing.sleepMinutes ? existing.sleepMinutes : DEFAULT_SLEEP_MINUTES);

    WiFiManager wm;
    wm.setConfigPortalTimeout(PORTAL_TIMEOUT_S);
    wm.setSaveConfigCallback(onSaveConfig);
    wm.setSaveParamsCallback(onSaveConfig);

    WiFiManagerParameter influxUrl(
        "influx_url", "Influx write URL (Grafana Cloud)", existing.influxUrl.c_str(), 200,
        "required placeholder='https://influx-prod-XX.grafana.net/api/v1/push/influx/write'");
    WiFiManagerParameter influxUser("influx_user", "Instance ID", existing.influxUser.c_str(),
                                     64, "required");
    WiFiManagerParameter influxToken(
        "influx_token", "API token (dejar en blanco para no cambiarlo)", "", 150,
        "type='password'");
    WiFiManagerParameter deviceTag(
        "device_tag", "Nombre del dispositivo",
        existing.deviceTag.length() ? existing.deviceTag.c_str() : DEFAULT_DEVICE_TAG, 32,
        "required");
    WiFiManagerParameter sleepMinutes("sleep_minutes", "Intervalo de sueno (minutos)", sleepBuf,
                                        6, "required type='number' min='5' max='1440'");

    wm.addParameter(&influxUrl);
    wm.addParameter(&influxUser);
    wm.addParameter(&influxToken);
    wm.addParameter(&deviceTag);
    wm.addParameter(&sleepMinutes);

    power::showLed(LedPattern::ConfigEntered);
    power::showLed(LedPattern::ConfigActive);

    g_formSubmitted = false;
    wm.startConfigPortal(AP_SSID, AP_PASSWORD);

    if (!g_formSubmitted) {
        return false;  // timeout sin que nadie completara el formulario
    }

    DeviceSettings updated;
    updated.wifiSsid = WiFi.SSID();
    updated.wifiPassword = WiFi.psk();
    updated.influxUrl = influxUrl.getValue();
    updated.influxUser = influxUser.getValue();

    String newToken = influxToken.getValue();
    updated.influxToken = newToken.length() ? newToken : existing.influxToken;

    updated.deviceTag = deviceTag.getValue();

    long minutes = String(sleepMinutes.getValue()).toInt();
    if (minutes < static_cast<long>(MIN_SLEEP_MINUTES)) minutes = MIN_SLEEP_MINUTES;
    if (minutes > static_cast<long>(MAX_SLEEP_MINUTES)) minutes = MAX_SLEEP_MINUTES;
    updated.sleepMinutes = static_cast<uint32_t>(minutes);

    if (!updated.isComplete()) {
        return false;
    }

    settings::save(updated);
    return true;
}

}  // namespace portal
