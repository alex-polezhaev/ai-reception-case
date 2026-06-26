// boot_auth.h - Boot authentication and system clock initialization API.
#pragma once
#include <cstdint>
#include <cstddef>

bool boot_auth(char *jwt_out, size_t jwt_max, uint32_t *unix_time_out);
void set_system_time(uint32_t unix_time);