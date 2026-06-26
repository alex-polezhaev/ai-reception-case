# Silero VAD microservice

A small FastAPI service that wraps the [Silero VAD](https://github.com/snakers4/silero-vad)
model. It takes one minute of 16 kHz / 16-bit PCM audio and returns a per-second binary
speech mask, so the backend can tell which seconds of a recording contain speech before
spending money on transcription.

## Endpoints

| Method | Path      | Description |
|--------|-----------|-------------|
| `POST` | `/vad`    | Body: `{ "pcm_data": [int, ...] }`. Exactly 960000 samples (16000 Hz × 60 s). Returns `{ "speech_mask": [0/1, ...] }` with 60 elements, one per second. |
| `GET`  | `/health` | Liveness/readiness check. Returns model and format info. |

## Run with Docker

The service expects the shared external network and a `SILERO_VAD_PORT` value (see the
parent `core` env). It listens on port `8003` inside the container.

```bash
# from core/silero-vad
docker compose up -d --build
```

Or build and run the image directly:

```bash
docker build -t silero-vad .
docker run -p 8003:8003 silero-vad
```

The Silero model is pre-downloaded at image build time to keep startup fast.
