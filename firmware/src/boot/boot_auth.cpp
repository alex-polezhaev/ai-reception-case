// boot_auth.cpp - Device boot authentication: fetches JWT and server time.
#include "boot_auth.h"
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <esp_log.h>
#include <sys/time.h>

#define TAG "BOOT_AUTH"
#define TIME_TAG "TIME"

bool boot_auth(char *jwt_out, size_t jwt_max, uint32_t *unix_time_out) {
    *jwt_out = 0;
    *unix_time_out = 0;

    char url[256];
    snprintf(url, sizeof(url), "%s/device/boot/%s", SERVER_BASE_URL, DEVICE_ID);

    ESP_LOGI(TAG, "Starting boot authentication");
    ESP_LOGI(TAG, "URL: %s", url);
    ESP_LOGI(TAG, "WiFi status: %d", WiFi.status());

    if (WiFi.status() != WL_CONNECTED) {
        ESP_LOGE(TAG, "WiFi not connected");
        return false;
    }

    HTTPClient http;
    http.setTimeout(10000);

    if (!http.begin(url)) {
        ESP_LOGE(TAG, "http.begin() failed");
        return false;
    }

    ESP_LOGI(TAG, "Sending HTTP GET...");
    int code = http.GET();
    ESP_LOGI(TAG, "HTTP status: %d", code);

    if (code != HTTP_CODE_OK) {
        ESP_LOGE(TAG, "HTTP GET error: %d", code);
        http.end();
        return false;
    }

    String response = http.getString();
    http.end();

    ESP_LOGI(TAG, "Response length: %d bytes", response.length());
    if (response.length() == 0) {
        ESP_LOGE(TAG, "Empty response from server");
        return false;
    }

    ESP_LOGI(TAG, "JSON: %s", response.c_str());

    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, response);
    if (err) {
        ESP_LOGE(TAG, "JSON parse error: %s", err.c_str());
        return false;
    }

    const char *jwt = doc["jwt"];
    uint32_t unix_time = doc["time"];

    if (!jwt || unix_time == 0) {
        ESP_LOGE(TAG, "jwt or time missing");
        serializeJsonPretty(doc, Serial);
        return false;
    }

    strncpy(jwt_out, jwt, jwt_max - 1);
    jwt_out[jwt_max - 1] = '\0';
    *unix_time_out = unix_time;

    ESP_LOGI(TAG, "Success: JWT(%.20s...) length=%d; Time=%u", jwt_out, (int)strlen(jwt_out), *unix_time_out);
    return true;
}

void set_system_time(uint32_t unix_time) {
    struct timeval tv = {
        .tv_sec = (time_t)unix_time,
        .tv_usec = 0
    };
    settimeofday(&tv, nullptr);

    time_t now = time(nullptr);
    ESP_LOGI(TIME_TAG, "System time set: %lu (%s)", (unsigned long)now, ctime(&now));
}