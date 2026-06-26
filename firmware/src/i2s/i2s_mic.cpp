// i2s_mic.cpp - I2S microphone driver: capture, DC removal, and 16-bit scaling.
#include "i2s_mic.h"
#include <esp_err.h>
#include <algorithm>

static_assert(I2S_BITS_PER_SAMPLE == 16 || I2S_BITS_PER_SAMPLE == 32, "Unsupported bits per sample");

I2SMic::I2SMic()
    : initialized_(false), alpha_(0.995f), dc_offset_(0) {}

bool I2SMic::begin() {
    if (initialized_) return true;

    i2s_config_t config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
        .sample_rate = I2S_SAMPLE_RATE,
        .bits_per_sample = (i2s_bits_per_sample_t)(I2S_BITS_PER_SAMPLE),
        .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = I2S_DMA_BUF_COUNT,
        .dma_buf_len = I2S_DMA_BUF_LEN,
        .use_apll = false,
        .tx_desc_auto_clear = false,
        .fixed_mclk = 0
    };

    i2s_pin_config_t pins = {
        .bck_io_num = I2S_SCK_GPIO,
        .ws_io_num = I2S_WS_GPIO,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num = I2S_SD_GPIO
    };

    if (i2s_driver_install(I2S_NUM_0, &config, 0, NULL) != ESP_OK) return false;
    if (i2s_set_pin(I2S_NUM_0, &pins) != ESP_OK) return false;

    initialized_ = true;
    return true;
}

size_t I2SMic::read(int16_t* pcm_buffer, size_t max_samples) {
    if (!initialized_) return 0;

    size_t bytes_read = 0;
    size_t to_read_bytes = max_samples * sizeof(int32_t);
    int32_t* raw_buffer = new int32_t[max_samples];

    esp_err_t result = i2s_read(I2S_NUM_0, raw_buffer, to_read_bytes, &bytes_read, 100 / portTICK_PERIOD_MS);
    size_t samples_read = bytes_read / sizeof(int32_t);

    if (result == ESP_OK && samples_read > 0) {
        for (size_t i = 0; i < samples_read; ++i) {
            dc_offset_ = alpha_ * dc_offset_ + (1.0f - alpha_) * raw_buffer[i];
            int32_t filtered = raw_buffer[i] - dc_offset_;
            int32_t scaled = filtered >> 11;  // Scale 32-bit mic sample down to 16-bit range (>>11 = /2048)
            if (scaled < -32768) scaled = -32768;
            else if (scaled > 32767) scaled = 32767;
            pcm_buffer[i] = static_cast<int16_t>(scaled);
        }
    }

    delete[] raw_buffer;
    return samples_read;
}