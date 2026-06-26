// main.cpp - Firmware entry point: boot, WiFi provisioning, auth, and audio tasks.
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <esp_log.h>

#include "audio/audio_system.h"
#include "i2s/i2s_mic.h"
#include "portal/portal.h"
#include "boot/boot_auth.h"
#include "server/server_api.h"

char jwt_token[512] = {0};
I2SMic microphone;

void setup() {
    delay(1000);
    Serial.begin(115200);
    delay(1000);

    ESP_LOGI("SETUP", "AI-Reception ESP32-S3");

    pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);

    if (!init_audio_memory()) ESP.restart();

    WiFiManager wm;
    portal_start(wm);

    uint32_t server_time;
    if (!boot_auth(jwt_token, sizeof(jwt_token), &server_time)) ESP.restart();
    set_system_time(server_time);

    // Check and send crash log if one occurred
    check_and_send_crash_log();

    if (!microphone.begin() || !init_audio_tasks()) ESP.restart();

    ESP_LOGI("SETUP", "Done");
}

void loop() {
    static unsigned long last_stats = 0;
    static bool pressed = false;
    static unsigned long start = 0;
    static bool long_press_handled = false;

    // Reset / recalibration button
    if (digitalRead(RESET_BUTTON_PIN) == LOW) {
        if (!pressed) {
            pressed = true;
            start = millis();
            long_press_handled = false;
        } else {
            unsigned long hold_time = millis() - start;

            // Long press (3+ sec) - reset WiFi
            if (hold_time > 3000 && !long_press_handled) {
                ESP_LOGI("MAIN", "🗑️ Long press - reset WiFi");
                WiFiManager wm;
                wm.resetSettings();
                ESP.restart();
            }
        }
    } else {
        pressed = false;
        long_press_handled = false;
    }

    delay(100);
}