#include "settings.h"

#include <Preferences.h>

#include "config.h"

namespace {
constexpr const char *NVS_NAMESPACE = "cfg";
}

namespace settings {

DeviceSettings load() {
    Preferences prefs;
    DeviceSettings result;

    prefs.begin(NVS_NAMESPACE, /*readOnly=*/true);
    result.wifiSsid = prefs.getString("wifi_ssid", "");
    result.wifiPassword = prefs.getString("wifi_pass", "");
    result.influxUrl = prefs.getString("influx_url", "");
    result.influxUser = prefs.getString("influx_user", "");
    result.influxToken = prefs.getString("influx_token", "");
    result.deviceTag = prefs.getString("device_tag", DEFAULT_DEVICE_TAG);
    result.sleepMinutes = prefs.getUInt("sleep_min", DEFAULT_SLEEP_MINUTES);
    prefs.end();

    return result;
}

void save(const DeviceSettings &s) {
    Preferences prefs;
    prefs.begin(NVS_NAMESPACE, /*readOnly=*/false);
    prefs.putString("wifi_ssid", s.wifiSsid);
    prefs.putString("wifi_pass", s.wifiPassword);
    prefs.putString("influx_url", s.influxUrl);
    prefs.putString("influx_user", s.influxUser);
    prefs.putString("influx_token", s.influxToken);
    prefs.putString("device_tag", s.deviceTag);
    prefs.putUInt("sleep_min", s.sleepMinutes);
    prefs.end();
}

void clear() {
    Preferences prefs;
    prefs.begin(NVS_NAMESPACE, /*readOnly=*/false);
    prefs.clear();
    prefs.end();
}

}  // namespace settings
