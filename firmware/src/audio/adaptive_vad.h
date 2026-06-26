// adaptive_vad.h - Fully adaptive VAD with calibration
#pragma once
#include <cstdint>
#include <algorithm>
#include <cmath>

enum VADState {
    VAD_CALIBRATING,    // Calibration at startup
    VAD_RUNNING,        // Normal operation
    VAD_RECALIBRATING   // Recalibration every hour
};

struct VADStats {
    float background_mean;      // Background mean value
    float background_variance;  // Background variance
    float background_std;       // Standard deviation
    int samples_collected;      // Samples collected for statistics
};

class AdaptiveVAD {
private:
    // Adaptation parameters
    static constexpr int CALIBRATION_SAMPLES = 500;      // Samples for calibration
    static constexpr int BACKGROUND_HISTORY = 1000;      // Background history size
    static constexpr float CHANGE_THRESHOLD = 3.0f;      // Sigma for change detection
    static constexpr float ZCR_MIN = 0.03f;             // Minimum ZCR for speech
    static constexpr float ZCR_MAX = 0.4f;              // Maximum ZCR for speech
    static constexpr unsigned long RECALIB_INTERVAL = 3600000; // 1 hour in ms

    // State
    VADState state_;
    unsigned long last_calibration_;

    // Background statistics
    VADStats stats_;
    float background_history_[BACKGROUND_HISTORY];
    int history_index_;
    int calibration_count_;

    // Temporal filtering
    int speech_frames_;
    int silence_frames_;
    static constexpr int MIN_SPEECH_FRAMES = 3;

    // Methods
    float calculate_energy(const int16_t* samples, size_t count);
    float calculate_zcr(const int16_t* samples, size_t count);
    void update_background_stats(float energy);
    void start_calibration();
    bool is_significant_change(float energy);
    float calculate_mean(float* data, int count);
    float calculate_variance(float* data, int count, float mean);

public:
    AdaptiveVAD();
    bool detect_speech(const int16_t* samples, size_t count);
    void reset_speech_state();  // Reset speech state between recordings
    VADState get_state() const { return state_; }
    VADStats get_stats() const { return stats_; }
    bool is_calibrated() const { return state_ == VAD_RUNNING; }
};