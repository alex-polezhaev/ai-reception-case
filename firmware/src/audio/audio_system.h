// audio_system.h - Audio slot model and capture/upload task declarations.
#pragma once
#include <cstdint>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include "adaptive_vad.h"  // For VADStats

struct AudioSlot {
    int16_t* pcm_data;
    uint32_t timestamp;
    bool has_speech;
    size_t sample_count;
    bool used;  // false = ready to send
};

extern AudioSlot record_slot;
extern AudioSlot upload_slot;
extern AdaptiveVAD global_vad;

bool init_audio_memory();
bool init_audio_tasks();
void audio_capture_task(void *parameter);
void audio_upload_task(void *parameter);
void print_vad_stats();
void reset_vad_speech_state();
VADStats get_vad_detailed_stats();