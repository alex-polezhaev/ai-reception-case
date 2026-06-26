// i2s_mic.h - I2SMic interface for reading PCM samples from the I2S microphone.
#pragma once
#include <driver/i2s.h>
#include <cstdint>

class I2SMic {
public:
    I2SMic();
    bool begin();
    size_t read(int16_t* pcm_buffer, size_t max_samples);

private:
    bool initialized_;
    float alpha_;
    float dc_offset_;
};