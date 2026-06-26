# AI Reception - Bill of Materials (Reference)

> **Honesty note.** This BOM is **derived from the firmware**, not from a
> published schematic. The repository ships firmware, CAD, and backend. It does
> **not** include an electrical schematic, a PCB, or a wiring diagram. The board,
> the GPIO assignments, and the audio configuration below are **certain** because
> they come straight from `firmware/platformio.ini` and the firmware source. The
> **specific microphone part, the microSD module, connectors, and passives are
> NOT specified anywhere in the repo**. They are marked **"reference /
> representative"** and are educated suggestions for a part that would satisfy
> the firmware's requirements. Treat anything labeled *reference* as a starting
> point to verify against your real build, not as the exact component used.

See [`hardware/README.md`](README.md) for the 3D-printed enclosure and
print settings, and [`docs/architecture.md`](../docs/architecture.md) for how the
hardware fits the full system.

---

## 1. What the firmware actually requires

These facts are load-bearing and taken directly from the source:

| Requirement | Value | Source |
|---|---|---|
| MCU board | ESP32-S3 **N16R8** (`4d_systems_esp32s3_gen4_r8n16`), 16 MB flash / 8 MB PSRAM | `platformio.ini` (`board`, `board_upload.flash_size = 16MB`, `psram_type = opi`) |
| PSRAM | Required (`-DBOARD_HAS_PSRAM`); two ~1.83 MB audio slots allocated in PSRAM | `platformio.ini`, `audio_system.cpp` |
| USB | Native USB CDC on boot (`ARDUINO_USB_MODE=1`, `ARDUINO_USB_CDC_ON_BOOT=1`) | `platformio.ini` |
| Microphone interface | I2S, MEMS, **mono / left channel**, 16 kHz, 32-bit I2S slots (downsampled to 16-bit PCM) | `i2s_mic.cpp` (`I2S_CHANNEL_FMT_ONLY_LEFT`), `platformio.ini` |
| Reset / re-provision button | Momentary, on **GPIO18**, `INPUT_PULLUP` (active-low) | `platformio.ini` (`RESET_BUTTON_PIN=18`), `main.cpp` |
| Power | USB-C (board-supplied); firmware watches for brownout resets | `check_and_send_crash_log()` handles `ESP_RST_BROWNOUT` |

The firmware drives an I2S MEMS microphone and reads one button. There is **no
code** that references an SD card, an LED, a battery gauge, or any other
peripheral. The microSD-over-SPI line below is therefore **purely a reference
option**, included because the task asked for it: *the firmware does not use
microSD.*

---

## 2. Bill of materials

Legend: **Exact** = pinned by the firmware/repo · **Reference** = representative
suggestion, verify against your real build.

| # | Component | Suggested part | Qty | Confidence | Notes |
|---|---|---|---|---|---|
| 1 | **MCU dev board** | ESP32-S3 **N16R8** module/dev board (16 MB flash, 8 MB OPI PSRAM); PlatformIO board id `4d_systems_esp32s3_gen4_r8n16` | 1 | **Exact (board id)** / Reference (exact vendor board) | Any ESP32-S3 N16R8 board with exposed I2S-capable GPIOs 15/16/17 and a USB-C port works. The PlatformIO board id is a definition match, not necessarily the physical board purchased. |
| 2 | **I2S MEMS microphone** | INMP441 (or ICS-43434 / SPH0645LM4H) I2S MEMS mic breakout | 1 | **Interface exact, part Reference** | Firmware needs an I2S mic, mono, 16 kHz, std-I2S format. INMP441 is the most common 24-bit I2S MEMS mic on a breakout and matches the `>> 11` scaling / 32-bit slot reads. The exact mic is **not specified in the repo**. |
| 3 | **Reset / re-provision button** | Momentary tactile push button (SPST, normally-open) | 1 | **Pin exact (GPIO18), part Reference** | Wired GPIO18 ↔ GND; firmware uses internal pull-up. Short press = noop, long press (>3 s) = clear Wi-Fi + reboot. |
| 4 | **USB-C cable + 5 V supply** | USB-C data/power cable, 5 V phone-style adapter | 1 | **Interface exact, part Reference** | Powers and flashes the board over native USB. No on-board battery in firmware. |
| 5 | **microSD module (SPI)** | microSD breakout over SPI + microSD card | 0-1 | **Reference / NOT USED** | Requested in the task as "if present." **The firmware contains no SD-card code**. Include only if you add local logging yourself. Listed for completeness, not because the device needs it. |
| 6 | **Hook-up wiring / headers** | Dupont jumpers or soldered wires; pin headers | as needed | Reference | For mic ↔ board and button ↔ board. |
| 7 | **Enclosure (3D-printed)** | `mic-v7-main.step` (round body) + `mic-v7-case-mic-hole.step` (cap / front cover with the mic hole) | 1 set | **Exact (in repo)** | PLA, ~0.2 mm layers, 15-20% infill, see [`hardware/README.md`](README.md). |

> Passives (decoupling caps, pull-up/pull-down resistors beyond the MCU's
> internal pull-ups), screws, and adhesives are **not** specified in the repo and
> are left to the builder. None are referenced by the firmware.

---

## 3. Wiring / pin table

All pin assignments are **exact**: pulled verbatim from the `build_flags` in
[`firmware/platformio.ini`](../firmware/platformio.ini) and confirmed in
`firmware/src/i2s/i2s_mic.cpp` and `firmware/src/main.cpp`.

### I2S MEMS microphone → ESP32-S3

| Signal | Build flag | GPIO | I2S role |
|---|---|---|---|
| Serial data (mic → ESP) | `I2S_SD_GPIO` | **15** | `data_in_num` (SD / DOUT) |
| Word select (LRCLK) | `I2S_WS_GPIO` | **16** | `ws_io_num` (WS / LRCL) |
| Bit clock (BCLK) | `I2S_SCK_GPIO` | **17** | `bck_io_num` (SCK / BCLK) |
| Power | - | 3V3 | Mic VDD |
| Ground | - | GND | Mic GND |
| Channel select (L/R) | - | GND* | *Reference:* tie to GND for left channel, firmware uses `I2S_CHANNEL_FMT_ONLY_LEFT`. Pin name is mic-specific. |

I2S driver config (`i2s_mic.cpp`): `I2S_NUM_0`, master + RX, std-I2S comm
format, left-channel-only, `dma_buf_count = 8`, `dma_buf_len = 512`.

### Button → ESP32-S3

| Signal | Build flag | GPIO | Wiring |
|---|---|---|---|
| Reset / re-provision | `RESET_BUTTON_PIN` | **18** | Button between GPIO18 and GND; `INPUT_PULLUP`, active-low. |

### Audio configuration (firmware constants, exact)

| Setting | Build flag | Value |
|---|---|---|
| Sample rate | `I2S_SAMPLE_RATE` | 16000 Hz |
| Bits per I2S slot | `I2S_BITS_PER_SAMPLE` | 32 (stored/uploaded as 16-bit PCM) |
| Capture buffer | `I2S_BUFFER_SAMPLES` | 256 samples |
| DMA buffers | `I2S_DMA_BUF_COUNT` / `I2S_DMA_BUF_LEN` | 8 / 512 |
| Slot duration | `AUDIO_RECORD_DURATION_SEC` | 60 s (≈1.83 MB per slot in PSRAM) |
| PSRAM budget | `PSRAM_USAGE_PERCENT` | 80% |
| Slot pool bounds | `MIN_BUFFER_SLOTS` / `MAX_BUFFER_SLOTS` | 2 / 10 |
| Captive-portal AP | `WIFI_AP_SSID` | `Ai-Reception-<DEVICE_ID>` (open) |

---

## 4. ASCII wiring sketch (reference)

```
   I2S MEMS mic (e.g. INMP441 - reference part)        ESP32-S3 N16R8
   ┌──────────────┐                                    ┌──────────────┐
   │ VDD          ├────────────── 3V3 ─────────────────┤ 3V3          │
   │ GND          ├────────────── GND ─────────────────┤ GND          │
   │ SD  (DOUT)   ├──────────────────────────── GPIO15 ┤ I2S_SD       │
   │ WS  (LRCL)   ├──────────────────────────── GPIO16 ┤ I2S_WS       │
   │ SCK (BCLK)   ├──────────────────────────── GPIO17 ┤ I2S_SCK      │
   │ L/R   ──► GND (left channel)                       │              │
   └──────────────┘                                    │              │
                                                        │              │
   Momentary button                                     │              │
   ┌──────────────┐                                     │              │
   │  ┌─o o─┐     ├──────────────────────────── GPIO18 ┤ RESET_BUTTON │
   │  └─────┘     ├────────────── GND ─────────────────┤ GND          │
   └──────────────┘                                     │  USB-C ◄── 5V power / flash
                                                        └──────────────┘
```

---

## 5. 3D-print notes

Printable enclosure source files live in `hardware/`. From
[`hardware/README.md`](README.md):

- **Material:** PLA
- **Layer height:** ~0.2 mm
- **Infill:** 15-20%
- **Supports:** as needed (depends on part orientation)
- **Formats:** `.step` (parametric CAD source, edit in Fusion/FreeCAD/SolidWorks/Onshape)

Parts: enclosure `enclosure/mic-v7-main.step` (round body) +
`enclosure/mic-v7-case-mic-hole.step` (cap / front cover with the mic hole).

---

## 6. Summary of inferences (read this)

| Item | Status |
|---|---|
| ESP32-S3 N16R8 board, GPIO 15/16/17/18, USB-C, PSRAM, 16 kHz mono I2S | **Confirmed from firmware**, not inferred |
| Specific microphone model (INMP441 etc.) | **Inferred**, repo only specifies "I2S MEMS mic," not a part number |
| Mic L/R-select pin wiring | **Inferred**, pin name/position is mic-specific; left-channel requirement is exact |
| microSD-over-SPI module | **Inferred & NOT USED**, no SD code exists in the firmware |
| USB-C power supply / cable spec | **Inferred**, board uses native USB; exact PSU not specified |
| Passives, connectors, fasteners, adhesives | **Inferred / builder's choice**, none referenced in the repo |
| Enclosure, print settings, pin map, audio config | **Confirmed from repo** |
