# Firmware - ESP32-S3 reception device

ESP32-S3 firmware that captures room audio, detects speech on-device, and uploads recorded PCM chunks to the backend over HTTP.

## Overview

The device samples an I2S MEMS microphone at 16 kHz and runs an **adaptive VAD** (Voice Activity Detector) that continuously adapts to the ambient noise floor to separate speech from silence. Detected speech fills fixed-length PCM buffers (**AudioSlots**) allocated in PSRAM; each completed slot is uploaded as a discrete `application/octet-stream` HTTP POST to `/device/upload/{DEVICE_ID}`. It does **not** stream audio. When no speech is detected, the device reports a silence interval instead.

On first boot (or after pressing the reset button) the device exposes an open Wi-Fi access point (`Ai-Reception-<DEVICE_ID>`) with a **captive portal** for Wi-Fi provisioning; credentials are stored on-device for subsequent boots. At boot it authenticates against the backend and obtains a Bearer JWT used for all subsequent requests.

Backend device endpoints used: `/device/boot`, `/device/upload/{DEVICE_ID}`, `/device/silence`, `/device/log`.

## Tech / stack

- [PlatformIO](https://platformio.org/) + Arduino framework
- Board: `4d_systems_esp32s3_gen4_r8n16` (ESP32-S3 **N16R8**, 16 MB flash / 8 MB PSRAM); environment `esp32-s3-n16r8`
- [`tzapu/WiFiManager`](https://github.com/tzapu/WiFiManager) - Wi-Fi captive portal
- [`bblanchon/ArduinoJson`](https://github.com/bblanchon/ArduinoJson) - JSON encoding

## Structure

```
firmware/
├── platformio.ini        # board, build flags, dependencies
├── Makefile              # dev / prod / erase convenience targets
└── src/
    ├── main.cpp          # entry point, main loop
    ├── audio/            # AudioSlots + adaptive VAD
    ├── i2s/              # I2S MEMS microphone driver
    ├── server/           # backend HTTP API client
    ├── boot/             # boot-time authentication
    └── portal/           # Wi-Fi captive portal
```

Pin assignments and several runtime parameters (sample rate, GPIOs, server URL, device ID) are wired through `build_flags` in [`platformio.ini`](./platformio.ini). Note that some values listed there (`MAX_UPLOAD_RETRIES`, `MIN_BUFFER_SLOTS`, `MAX_BUFFER_SLOTS`, `PSRAM_USAGE_PERCENT`, `I2S_BUFFER_SAMPLES`, `WIFI_AP_SSID`) are **compile-time constants defined in source** and are not actually read from the build flags; changing those flags has no effect without editing the code.

## Build & run

Built with PlatformIO. Two environment variables are injected into the firmware at build time via `${sysenv.*}`:

| Env var | Description | Example |
|---|---|---|
| `SERVER_URL` | Base URL of the backend | `https://core.your-domain.example` |
| `DEVICE_ID` | Unique identifier for this device | `desk-01` |

Build and flash directly:

```bash
SERVER_URL="https://core.your-domain.example" \
DEVICE_ID="desk-01" \
pio run -e esp32-s3-n16r8 -t upload
```

Or use the `Makefile` convenience targets (`DEVICE_ID` is required):

```bash
make dev  DEVICE_ID="desk-01"   # builds against the local dev SERVER_URL
make prod DEVICE_ID="desk-01"   # builds against the production SERVER_URL
make erase                      # full flash erase
```

Serial monitor runs at `115200` baud; upload speed is `921600`.

---

[← project root](../README.md)
