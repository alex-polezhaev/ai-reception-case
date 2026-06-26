// audio_system.cpp - Dual-slot audio pipeline: capture, VAD, and background upload tasks.
#include "audio_system.h"
#include "i2s/i2s_mic.h"
#include "adaptive_vad.h"
#include "server/server_api.h"
#include <esp_heap_caps.h>
#include <esp_log.h>
#include <WiFi.h>
#include <algorithm>
#include <cmath>

AudioSlot record_slot;
AudioSlot upload_slot;

extern I2SMic microphone;
extern char jwt_token[512];

// Function to get AdaptiveVAD statistics
void print_vad_stats() {
    static unsigned long last_print = 0;

    if (millis() - last_print > 30000) {  // Every 30 seconds
        ESP_LOGI("VAD_STATS", "📊 AdaptiveVAD running for %lu sec", millis() / 1000);
        last_print = millis();
    }
}

// Global VAD instance
AdaptiveVAD global_vad;

// Function to get VAD reference for external control
AdaptiveVAD* get_vad_instance() {
    return &global_vad;
}

// Function to reset VAD speech state between recordings
void reset_vad_speech_state() {
    global_vad.reset_speech_state();
}

// Function to get detailed VAD statistics
VADStats get_vad_detailed_stats() {
    return global_vad.get_stats();
}

bool init_audio_memory() {
    size_t slot_size = I2S_SAMPLE_RATE * AUDIO_RECORD_DURATION_SEC * sizeof(int16_t);

    ESP_LOGI("MEMORY", "Allocating record_slot %.1f MB", slot_size / 1024.0 / 1024.0);
    record_slot.pcm_data = (int16_t*)heap_caps_malloc(slot_size, MALLOC_CAP_SPIRAM);
    if (!record_slot.pcm_data) {
        ESP_LOGE("MEMORY", "Failed to allocate record_slot");
        return false;
    }

    ESP_LOGI("MEMORY", "Allocating upload_slot %.1f MB", slot_size / 1024.0 / 1024.0);
    upload_slot.pcm_data = (int16_t*)heap_caps_malloc(slot_size, MALLOC_CAP_SPIRAM);
    if (!upload_slot.pcm_data) {
        ESP_LOGE("MEMORY", "Failed to allocate upload_slot");
        free(record_slot.pcm_data);
        return false;
    }

    record_slot.used = true;
    upload_slot.used = true;

    ESP_LOGI("MEMORY", "Dual-slot system ready");
    return true;
}

bool init_audio_tasks() {
    BaseType_t result1 = xTaskCreatePinnedToCore(audio_capture_task, "Capture", 8192, nullptr, 5, nullptr, 0);
    BaseType_t result2 = xTaskCreatePinnedToCore(audio_upload_task, "Upload", 8192, nullptr, 3, nullptr, 1);

    return (result1 == pdPASS && result2 == pdPASS);
}

void audio_capture_task(void *parameter) {
    ESP_LOGI("CAPTURE", "Recording on core %d", xPortGetCoreID());
    vTaskDelay(pdMS_TO_TICKS(50));

    int16_t samples[512];
    size_t target_samples = I2S_SAMPLE_RATE * AUDIO_RECORD_DURATION_SEC;
    const unsigned long RECORD_INTERVAL_MS = 60000;

    while (true) {
        unsigned long cycle_start = millis();
        unsigned long start_time = millis();
        ESP_LOGI("CAPTURE", "Starting recording");

        // Reset VAD state before new recording
        reset_vad_speech_state();

        record_slot.sample_count = 0;
        record_slot.has_speech = false;
        record_slot.timestamp = time(nullptr);
        record_slot.used = true;

        // Fill slot
        while (record_slot.sample_count < target_samples) {
            size_t read = microphone.read(samples, 512);
            if (read == 0) {
                vTaskDelay(pdMS_TO_TICKS(10));
                continue;
            }

            size_t remaining = target_samples - record_slot.sample_count;
            size_t to_copy = std::min(read, remaining);

            memcpy(&record_slot.pcm_data[record_slot.sample_count], samples, to_copy * sizeof(int16_t));
            record_slot.sample_count += to_copy;

            if (!record_slot.has_speech) {
                record_slot.has_speech = global_vad.detect_speech(samples, to_copy);
                if (record_slot.has_speech) {
                    ESP_LOGI("CAPTURE", "Speech detected at sample %zu", record_slot.sample_count);
                }
            }

            // Periodically print VAD statistics
            print_vad_stats();

            if (record_slot.sample_count % (I2S_SAMPLE_RATE * 20) == 0) {
                float progress = (float)record_slot.sample_count / target_samples * 100;
                ESP_LOGI("CAPTURE", "Progress: %.0f%%", progress);
            }
        }

        unsigned long record_time = millis() - start_time;
        ESP_LOGI("CAPTURE", "Recording complete in %lu ms: %zu samples, speech=%s",
                 record_time, record_slot.sample_count, record_slot.has_speech ? "YES" : "NO");

        // Wait for upload_slot to free up
        while (!upload_slot.used) {
            ESP_LOGW("CAPTURE", "Waiting for upload_slot");
            vTaskDelay(pdMS_TO_TICKS(500));
        }

        // Copy to upload_slot
        ESP_LOGI("CAPTURE", "Copying to upload_slot");
        memcpy(upload_slot.pcm_data, record_slot.pcm_data, record_slot.sample_count * sizeof(int16_t));
        upload_slot.sample_count = record_slot.sample_count;
        upload_slot.has_speech = record_slot.has_speech;
        upload_slot.timestamp = record_slot.timestamp;
        upload_slot.used = false;

        ESP_LOGI("CAPTURE", "upload_slot ready");

        // Compensate for execution time
        unsigned long elapsed = millis() - cycle_start;
        if (elapsed < RECORD_INTERVAL_MS) {
            vTaskDelay(pdMS_TO_TICKS(RECORD_INTERVAL_MS - elapsed));
        } else {
            ESP_LOGW("CAPTURE", "Cycle exceeded 60s: %lu ms", elapsed);
        }
    }
}

void audio_upload_task(void *parameter) {
    ESP_LOGI("UPLOAD", "Upload on core %d", xPortGetCoreID());
    vTaskDelay(pdMS_TO_TICKS(100));

    while (true) {
        if (!upload_slot.used) {
            ESP_LOGI("UPLOAD", "Processing slot: %zu samples, speech=%s",
                     upload_slot.sample_count, upload_slot.has_speech ? "YES" : "NO");

            bool success = false;

            if (!upload_slot.has_speech) {
                // Send silence notification
                ESP_LOGI("UPLOAD", "No speech - sending silence");

                for (int attempt = 1; attempt <= 3; attempt++) {
                    ESP_LOGI("UPLOAD", "Silence attempt %d/3", attempt);

                    if (WiFi.status() != WL_CONNECTED) {
                        ESP_LOGW("UPLOAD", "WiFi disconnected");
                        vTaskDelay(pdMS_TO_TICKS(2000));
                        continue;
                    }

                    success = upload_silence_notification(upload_slot.timestamp);

                    if (success) {
                        ESP_LOGI("UPLOAD", "Silence succeeded on attempt %d", attempt);
                        break;
                    } else {
                        ESP_LOGW("UPLOAD", "Silence attempt %d failed", attempt);
                        if (attempt < 3) vTaskDelay(pdMS_TO_TICKS(2000));
                    }
                }

                // If all attempts failed - reboot
                if (!success) {
                    ESP_LOGE("UPLOAD", "❌ All silence attempts failed. Rebooting.");
                    vTaskDelay(pdMS_TO_TICKS(1000));
                    ESP.restart();
                }
            } else {
                // Send audio data
                ESP_LOGI("UPLOAD", "Starting audio upload");

                for (int attempt = 1; attempt <= 5; attempt++) {
                    ESP_LOGI("UPLOAD", "Audio attempt %d/5", attempt);

                    if (WiFi.status() != WL_CONNECTED) {
                        ESP_LOGW("UPLOAD", "WiFi disconnected");
                        vTaskDelay(pdMS_TO_TICKS(2000));
                        continue;
                    }

                    success = upload_audio_slot(upload_slot);

                    if (success) {
                        ESP_LOGI("UPLOAD", "Audio succeeded on attempt %d", attempt);
                        break;
                    } else {
                        ESP_LOGW("UPLOAD", "Audio attempt %d failed", attempt);
                        if (attempt < 5) vTaskDelay(pdMS_TO_TICKS(3000));
                    }
                }

                // If all 5 attempts failed - reboot
                if (!success) {
                    ESP_LOGE("UPLOAD", "❌ All 5 audio upload attempts failed. Rebooting.");
                    vTaskDelay(pdMS_TO_TICKS(1000));
                    ESP.restart();
                }
            }

            ESP_LOGI("UPLOAD", "Result: %s", success ? "SUCCESS" : "ERROR");
            upload_slot.used = true;

        } else {
            vTaskDelay(pdMS_TO_TICKS(200));
        }
    }
}
