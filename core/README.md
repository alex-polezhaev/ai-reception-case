# Core: backend (the "brain")

Swift/Vapor backend that turns raw audio captured by edge devices into a structured, human-readable report delivered over Telegram.

## Overview

Edge devices send raw PCM audio chunks to the API. The backend groups those chunks into conversation sessions, trims silence, transcribes the speech, runs an LLM analysis, and pushes the resulting structured report to the operator through a Telegram Mini App and bot. Work is passed between stages over a Postgres-backed message queue (**PGMQ**): `session-queue`, `transcription-queue`, `analysis-queue`.

Pipeline components:

- **APIServer**: Vapor HTTP API. Authenticates devices via JWT, ingests PCM audio chunks and device events, and enqueues work.
- **SessionWorker**: Groups incoming PCM chunks into sessions and uses **Silero VAD** to detect speech and trim silence, producing a clean session WAV.
- **TranscriptionWorker**: Sends session audio to **OpenAI Whisper** for speech-to-text.
- **AnalysisWorker**: Runs an **OpenAI LLM** over the transcript to produce a structured summary / analysis.
- **MiniApp**: Telegram Mini App + bot (Vapor + Leaf templates, HMAC verification of Telegram init data) that delivers the report to the operator.

Transcription and analysis run on the OpenAI cloud API; only Silero VAD runs locally as an internal service.

Device endpoints: `GET /device/boot/:deviceid` (handshake, issues the device JWT), `POST /device/upload/:deviceid` (PCM chunk), `POST /device/silence/:deviceid`, `POST /device/log/:deviceid`. All but `boot` are authenticated with the device JWT (Bearer token) and validate the device ID.

Storage: **Supabase** Postgres (schema, sessions, devices, logs; PGMQ lives inside Postgres) plus **S3-compatible** object storage with separate buckets for raw device PCM (`S3_DEVICE_PCM_BUCKET`) and processed session WAV (`S3_SESSIONS_WAV_BUCKET`).

## Tech / stack

- Swift 6.1 / Vapor 4, SwiftPM (see `workers/Package.swift`)
- Leaf templates for the Telegram Mini App
- Supabase Swift, Soto (S3), AsyncHTTPClient, swift-crypto, JWT
- Silero VAD service (Python, `silero-vad/`)
- docker-compose per service, orchestrated via the root `Makefile`
- Configuration via `.env` (copy from `.env.example`)

## Structure

```
core/
├── workers/          # Swift/Vapor sources (APIServer, MiniApp, *Worker, Shared)
│   ├── Sources/
│   ├── Resources/    # Leaf templates for the Telegram Mini App
│   └── Package.swift
├── silero-vad/       # Silero VAD service (Python) + Dockerfile
├── supabase/         # Supabase config, migrations, seed
├── nginx/            # Reverse proxy
├── dozzle/           # Log viewer
├── portainer/        # Container management
├── Makefile          # docker-compose orchestration
└── .env.example      # Environment template
```

## Build & run

1. Copy the example environment file and fill in real values (all secrets in `.env.example` are placeholders):

   ```sh
   cp .env.example .env
   # edit .env
   ```

2. Build the Swift workers locally with SwiftPM (from `workers/`):

   ```sh
   cd workers
   swift build -c release
   ```

3. Or run the full stack with docker-compose via the `Makefile`:

   ```sh
   make create-network
   make docker-build-prod
   ```

   Individual services can be brought up with the per-service targets
   (`build-workers-prod`, `build-silero-vad-prod`, `build-nginx-prod`, etc.).

---

[← project root](../README.md)
