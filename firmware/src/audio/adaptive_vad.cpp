// adaptive_vad.cpp - Self-calibrating voice activity detector (energy + ZCR).
#include "adaptive_vad.h"
#include <Arduino.h>  // For millis()
#include <esp_log.h>
#include <cmath>

static const char* TAG = "ADAPTIVE_VAD";

AdaptiveVAD::AdaptiveVAD()
    : state_(VAD_CALIBRATING), last_calibration_(millis()),
      history_index_(0), calibration_count_(0),
      speech_frames_(0), silence_frames_(0) {

    // Initialize statistics
    stats_ = {0.0f, 0.0f, 0.0f, 0};
    std::fill(background_history_, background_history_ + BACKGROUND_HISTORY, 0.0f);

    ESP_LOGI(TAG, "🎯 AdaptiveVAD started. Beginning calibration...");
    start_calibration();
}

bool AdaptiveVAD::detect_speech(const int16_t* samples, size_t count) {
    if (!samples || count == 0) {
        return false;
    }

    // 1. Calculate signal parameters
    float energy = calculate_energy(samples, count);
    float zcr = calculate_zcr(samples, count);

    // 2. Background adapts continuously; scheduled recalibration is intentionally disabled.

    // 3. Process depending on state
    switch (state_) {
        case VAD_CALIBRATING:
        case VAD_RECALIBRATING:
            // Collect calibration data
            background_history_[calibration_count_] = energy;
            calibration_count_++;

            if (calibration_count_ >= CALIBRATION_SAMPLES) {
                // Calibration complete - compute statistics
                stats_.background_mean = calculate_mean(background_history_, CALIBRATION_SAMPLES);
                stats_.background_variance = calculate_variance(background_history_, CALIBRATION_SAMPLES, stats_.background_mean);
                stats_.background_std = sqrt(stats_.background_variance);
                stats_.samples_collected = CALIBRATION_SAMPLES;

                // Switch to running mode
                state_ = VAD_RUNNING;
                history_index_ = 0;

                ESP_LOGI(TAG, "✅ Calibration complete:");
                ESP_LOGI(TAG, "   📊 Mean: %.0f", stats_.background_mean);
                ESP_LOGI(TAG, "   📈 Variance: %.0f", stats_.background_variance);
                ESP_LOGI(TAG, "   📏 Sigma: %.0f", stats_.background_std);
                ESP_LOGI(TAG, "   🎯 Threshold: %.0f", stats_.background_mean + CHANGE_THRESHOLD * stats_.background_std);
            } else {
                // Log calibration progress every 50 samples
                if (calibration_count_ % 50 == 0) {
                    ESP_LOGI(TAG, "🔧 Calibrating: %d/%d (%.0f%%)",
                             calibration_count_, CALIBRATION_SAMPLES,
                             (float)calibration_count_ / CALIBRATION_SAMPLES * 100);
                }
            }
            return false; // No speech detection during calibration

        case VAD_RUNNING:
            // Update rolling background history
            update_background_stats(energy);

            // Check for significant change
            bool energy_spike = is_significant_change(energy);
            bool zcr_ok = (zcr >= ZCR_MIN) && (zcr <= ZCR_MAX);
            bool current_speech = energy_spike && zcr_ok;

            // Temporal filtering
            if (current_speech) {
                speech_frames_++;
                silence_frames_ = 0;
            } else {
                silence_frames_++;
                if (silence_frames_ > 5) {
                    speech_frames_ = 0;
                }
            }

            bool speech_detected = speech_frames_ >= MIN_SPEECH_FRAMES;

            // Log when speech is detected
            if (speech_detected) {
                float threshold = stats_.background_mean + CHANGE_THRESHOLD * stats_.background_std;
                ESP_LOGI(TAG, "🗣️  SPEECH: E=%.0f (bg=%.0f±%.0f, thr=%.0f) ZCR=%.3f",
                         energy, stats_.background_mean, stats_.background_std, threshold, zcr);
            }

            // Continuous debug output
            static int debug_counter = 0;
            debug_counter++;

            // If speech active - log every 3 calls (more frequent)
            // If silence - log every 20 calls (less frequent)
            bool should_log = speech_detected ? (debug_counter % 3 == 0) : (debug_counter % 20 == 0);

            if (should_log) {
                float threshold = stats_.background_mean + CHANGE_THRESHOLD * stats_.background_std;
                ESP_LOGI(TAG, "%s E=%.0f thr=%.0f ZCR=%.3f E_ok=%s ZCR_ok=%s frames=%d [%s]",
                         speech_detected ? "🗣️ " : "🔇",
                         energy, threshold, zcr,
                         energy_spike ? "Y" : "N", zcr_ok ? "Y" : "N",
                         speech_frames_,
                         speech_detected ? "ACTIVE_SPEECH" : "silence");
            }

            // Periodic diagnostics (every 10 seconds)
            static unsigned long last_diag = 0;
            if (millis() - last_diag > 10000) {
                float threshold = stats_.background_mean + CHANGE_THRESHOLD * stats_.background_std;
                ESP_LOGI(TAG, "📈 Diagnostics: bg=%.0f±%.0f, threshold=%.0f, current=%.0f",
                         stats_.background_mean, stats_.background_std, threshold, energy);
                last_diag = millis();
            }

            return speech_detected;
    }

    return false;
}

float AdaptiveVAD::calculate_energy(const int16_t* samples, size_t count) {
    uint64_t sum = 0;
    for (size_t i = 0; i < count; i++) {
        sum += abs(samples[i]);
    }
    return (float)sum / count;
}

float AdaptiveVAD::calculate_zcr(const int16_t* samples, size_t count) {
    if (count < 2) return 0.0f;

    int zero_crossings = 0;
    for (size_t i = 1; i < count; i++) {
        if ((samples[i] >= 0) != (samples[i-1] >= 0)) {
            zero_crossings++;
        }
    }

    return (float)zero_crossings / (count - 1);
}

void AdaptiveVAD::update_background_stats(float energy) {
    // Update only if energy is close to current background (not speech)
    float threshold = stats_.background_mean + CHANGE_THRESHOLD * stats_.background_std;

    if (energy < threshold) {
        // Looks like background noise - update history
        background_history_[history_index_] = energy;
        history_index_ = (history_index_ + 1) % BACKGROUND_HISTORY;

        // Recalculate statistics from recent data
        int samples_to_use = std::min(stats_.samples_collected + 1, BACKGROUND_HISTORY);
        stats_.background_mean = calculate_mean(background_history_, samples_to_use);
        stats_.background_variance = calculate_variance(background_history_, samples_to_use, stats_.background_mean);
        stats_.background_std = sqrt(stats_.background_variance);
        stats_.samples_collected = samples_to_use;
    }
}

void AdaptiveVAD::start_calibration() {
    state_ = (stats_.samples_collected > 0) ? VAD_RECALIBRATING : VAD_CALIBRATING;
    calibration_count_ = 0;
    last_calibration_ = millis();

    const char* mode = (state_ == VAD_RECALIBRATING) ? "Recalibration" : "Calibration";
    ESP_LOGI(TAG, "🔧 %s started. Learning background (%d samples)...", mode, CALIBRATION_SAMPLES);
}

bool AdaptiveVAD::is_significant_change(float energy) {
    if (stats_.background_std == 0) return false; // Not yet calibrated

    float threshold = stats_.background_mean + CHANGE_THRESHOLD * stats_.background_std;
    return energy > threshold;
}

float AdaptiveVAD::calculate_mean(float* data, int count) {
    if (count == 0) return 0.0f;

    float sum = 0;
    for (int i = 0; i < count; i++) {
        sum += data[i];
    }
    return sum / count;
}

float AdaptiveVAD::calculate_variance(float* data, int count, float mean) {
    if (count <= 1) return 0.0f;

    float sum = 0;
    for (int i = 0; i < count; i++) {
        float diff = data[i] - mean;
        sum += diff * diff;
    }
    return sum / (count - 1);
}

void AdaptiveVAD::reset_speech_state() {
    speech_frames_ = 0;
    silence_frames_ = 0;
    ESP_LOGI(TAG, "🔄 Resetting speech state between recordings");
}