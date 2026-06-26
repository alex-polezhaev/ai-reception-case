FROM python:3.11-slim

WORKDIR /app

# Install minimal system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install the CPU-only build of PyTorch
RUN pip install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir fastapi uvicorn numpy pydantic

COPY main.py .

# Pre-download the model to reduce startup time
RUN python -c "import torch; torch.hub.load('snakers4/silero-vad', 'silero_vad', force_reload=True, onnx=False, trust_repo=True)"

EXPOSE 8003

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]

