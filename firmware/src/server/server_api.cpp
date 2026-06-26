// server_api.cpp - Backend HTTP API: audio upload, silence and crash-log reporting.
#include "server_api.h"
#include "audio/audio_system.h"
#include <esp_system.h>
#include <esp_log.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <esp_heap_caps.h>

extern char jwt_token[512];

bool upload_audio_slot(const AudioSlot& slot) {
    // Validate size
    size_t expected_size = I2S_SAMPLE_RATE * AUDIO_RECORD_DURATION_SEC * sizeof(int16_t);
    size_t actual_size = slot.sample_count * sizeof(int16_t);

    if (actual_size != expected_size) {
        ESP_LOGE("UPLOAD", "Invalid size: %zu instead of %zu bytes", actual_size, expected_size);
        return false;
    }

    HTTPClient http;
    char url[256];
    snprintf(url, sizeof(url), "%s/device/upload/%s", SERVER_BASE_URL, DEVICE_ID);

    ESP_LOGI("UPLOAD", "POST %s (%zu bytes)", url, actual_size);

    if (!http.begin(url)) {
        ESP_LOGE("UPLOAD", "HTTP begin failed");
        return false;
    }

    http.addHeader("Content-Type", "application/octet-stream");
    http.addHeader("Authorization", String("Bearer ") + jwt_token);
    http.addHeader("X-Timestamp", String(slot.timestamp));
    http.addHeader("X-Sample-Rate", String(I2S_SAMPLE_RATE));
    http.addHeader("X-Sample-Count", String(slot.sample_count));

    unsigned long start_time = millis();
    int code = http.POST((uint8_t*)slot.pcm_data, actual_size);
    unsigned long upload_time = millis() - start_time;

    if (code == HTTP_CODE_OK) {
        ESP_LOGI("UPLOAD", "Uploaded in %lu ms", upload_time);
    } else {
        String response = http.getString();
        ESP_LOGE("UPLOAD", "HTTP %d (%lu ms): %s", code, upload_time, response.c_str());
    }

    http.end();
    return code == HTTP_CODE_OK;
}

bool upload_silence_notification(uint32_t timestamp) {
    HTTPClient http;
    char url[256];
    snprintf(url, sizeof(url), "%s/device/silence/%s", SERVER_BASE_URL, DEVICE_ID);

    ESP_LOGI("SILENCE", "POST %s (timestamp: %u)", url, timestamp);

    if (!http.begin(url)) {
        ESP_LOGE("SILENCE", "HTTP begin failed");
        return false;
    }

    http.addHeader("Content-Type", "application/json");
    http.addHeader("Authorization", String("Bearer ") + jwt_token);
    http.addHeader("X-Timestamp", String(timestamp));

    unsigned long start_time = millis();
    int code = http.POST("");  // Empty body
    unsigned long upload_time = millis() - start_time;

    if (code == HTTP_CODE_OK) {
        ESP_LOGI("SILENCE", "Silence notification sent in %lu ms", upload_time);
    } else {
        String response = http.getString();
        ESP_LOGE("SILENCE", "HTTP %d (%lu ms): %s", code, upload_time, response.c_str());
    }

    http.end();
    return code == HTTP_CODE_OK;
}

bool check_and_send_crash_log() {
    esp_reset_reason_t reason = esp_reset_reason();

    // Check only crashes, not normal restarts
    if (reason != ESP_RST_PANIC && reason != ESP_RST_WDT && reason != ESP_RST_BROWNOUT) {
        return true; // Not a crash, all good
    }

    const char* crash_type;
    switch(reason) {
        case ESP_RST_PANIC: crash_type = "Exception/Panic"; break;
        case ESP_RST_WDT: crash_type = "Watchdog Timeout"; break;
        case ESP_RST_BROWNOUT: crash_type = "Brownout/Power"; break;
        default: crash_type = "Unknown Crash"; break;
    }

    ESP_LOGW("CRASH", "Crash detected: %s", crash_type);

    HTTPClient http;
    char url[256];
    snprintf(url, sizeof(url), "%s/device/log/%s", SERVER_BASE_URL, DEVICE_ID);

    ESP_LOGI("CRASH", "POST %s", url);

    if (!http.begin(url)) {
        ESP_LOGE("CRASH", "HTTP begin failed");
        return false;
    }

    http.addHeader("Content-Type", "application/json");
    http.addHeader("Authorization", String("Bearer ") + jwt_token);

    // Collect extended system information
    uint32_t free_heap = esp_get_free_heap_size();
    uint32_t min_free_heap = esp_get_minimum_free_heap_size();
    uint32_t free_psram = heap_caps_get_free_size(MALLOC_CAP_SPIRAM);
    const char* idf_version = esp_get_idf_version();
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);

    // Build simplified crash log
    char json_body[512];
    snprintf(json_body, sizeof(json_body),
        "{"
        "\"level\":\"error\","
        "\"message\":\"Device crash: %s (reason:%d)\""
        "}",
        crash_type, (int)reason);

    unsigned long start_time = millis();
    int code = http.POST(json_body);
    unsigned long upload_time = millis() - start_time;

    if (code == HTTP_CODE_OK) {
        ESP_LOGI("CRASH", "Crash log sent in %lu ms", upload_time);
    } else {
        String response = http.getString();
        ESP_LOGE("CRASH", "HTTP %d (%lu ms): %s", code, upload_time, response.c_str());
    }

    http.end();
    return code == HTTP_CODE_OK;
}
