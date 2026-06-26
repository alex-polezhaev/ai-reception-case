# Silero VAD service: FastAPI endpoint that takes 60s of 16-bit PCM audio
# and returns a per-second binary speech mask using the Silero VAD model.
import os
import torch
import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

# Load the Silero VAD model the correct way
model, utils = torch.hub.load(repo_or_dir='snakers4/silero-vad',
                              model='silero_vad',
                              force_reload=False,
                              onnx=False,
                              trust_repo=True)

(get_speech_timestamps, save_audio, read_audio, VADIterator, collect_chunks) = utils

torch.set_num_threads(1)

class AudioData(BaseModel):
    pcm_data: list[int]  # PCM 16000Hz 16-bit data for 1 minute (960000 samples)

class VADResponse(BaseModel):
    speech_mask: list[int]  # Binary array [1,1,0,0,1...] where each element = 1 second

@app.post("/vad", response_model=VADResponse)
async def detect_voice_activity(data: AudioData):
    try:
        print(f"[VAD] Received request with {len(data.pcm_data)} samples")

        # Verify that exactly 60 seconds of data arrived (960000 samples)
        expected_samples = 16000 * 60  # 960000
        if len(data.pcm_data) != expected_samples:
            print(f"[VAD] Size error: expected {expected_samples}, got {len(data.pcm_data)}")
            raise HTTPException(
                status_code=400,
                detail=f"Invalid PCM data length: expected {expected_samples} samples for 60 seconds, got {len(data.pcm_data)}"
            )

        # Convert 16-bit PCM data for Silero VAD
        pcm_array = np.array(data.pcm_data, dtype=np.float32)
        print(f"[VAD] Raw 16-bit signal: min={pcm_array.min():.0f}, max={pcm_array.max():.0f}, mean={pcm_array.mean():.0f}")

        # Normalize 16-bit data
        # 16-bit PCM: range from -32768 to 32767
        # Silero expects values in the range [-1, 1]
        if np.abs(pcm_array).max() > 1.0:
            # Normalize 16-bit data
            pcm_array = pcm_array / 32768.0  # For 16-bit: 2^15
            print(f"[VAD] Normalized: min={pcm_array.min():.3f}, max={pcm_array.max():.3f}")

        # Clip values to the [-1, 1] range
        pcm_array = np.clip(pcm_array, -1.0, 1.0)

        # Convert to torch tensor
        wav = torch.from_numpy(pcm_array)
        print(f"[VAD] Tensor created: shape={wav.shape}, dtype={wav.dtype}")

        # Get speech timestamps with the correct parameters
        print("[VAD] Starting voice activity detection...")
        speech_timestamps = get_speech_timestamps(
            wav,
            model,
            sampling_rate=16000,
            threshold=0.5,  # Detection threshold
            min_speech_duration_ms=250,  # Minimum speech duration
            min_silence_duration_ms=100,  # Minimum silence duration
            window_size_samples=1024,  # Window size
            speech_pad_ms=30  # Padding around speech
        )

        print(f"[VAD] Found {len(speech_timestamps)} speech segments:")
        for i, segment in enumerate(speech_timestamps):
            start_sec = segment['start'] / 16000
            end_sec = segment['end'] / 16000
            print(f"[VAD]   Segment {i+1}: {start_sec:.2f}s - {end_sec:.2f}s")

        # Build a binary array for 60 seconds
        speech_mask = [0] * 60

        # Fill the mask based on detected speech segments
        for segment in speech_timestamps:
            start_sec = int(segment['start'] / 16000)  # convert samples to seconds
            end_sec = int(segment['end'] / 16000)

            # Mark all seconds within the segment
            for sec in range(start_sec, min(end_sec + 1, 60)):
                speech_mask[sec] = 1

        speech_count = sum(speech_mask)
        print(f"[VAD] Result: {speech_count} seconds with speech out of 60")
        print(f"[VAD] Mask: {''.join(map(str, speech_mask[:20]))}...")

        return VADResponse(speech_mask=speech_mask)

    except HTTPException:
        raise
    except Exception as e:
        print(f"[VAD] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "ok", "model": "silero_vad", "format": "16-bit PCM"}
