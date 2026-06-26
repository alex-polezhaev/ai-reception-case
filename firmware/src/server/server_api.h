// server_api.h - Server upload/reporting API declarations.
#pragma once
#include <cstdint>

struct AudioSlot;

bool upload_audio_slot(const AudioSlot& slot);
bool upload_silence_notification(uint32_t timestamp);
bool check_and_send_crash_log();
