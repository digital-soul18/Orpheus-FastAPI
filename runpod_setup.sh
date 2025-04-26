#!/bin/bash
# Orpheus-FastAPI Setup Script for RunPod (No Docker)
set -e

echo "Setting up Orpheus-FastAPI on RunPod..."

# Install dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y python3.10 python3-pip python3-venv libsndfile1 ffmpeg portaudio19-dev wget git cmake build-essential libcurl4-openssl-dev

# Create directories
echo "Creating directories..."
mkdir -p outputs models

# Set up virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install PyTorch with CUDA
echo "Installing PyTorch with CUDA..."
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Install other dependencies
echo "Installing project dependencies..."
pip3 install -r requirements.txt

# Download Orpheus model if not present
MODEL_NAME=${ORPHEUS_MODEL_NAME:-Orpheus-3b-FT-Q8_0.gguf}
echo "Checking for model $MODEL_NAME..."

if [ ! -f "models/$MODEL_NAME" ]; then
  echo "Downloading model from HuggingFace..."
  wget -P models https://huggingface.co/timonharz/$MODEL_NAME/resolve/main/$MODEL_NAME
else
  echo "Model already exists."
fi

# Set up environment variables
cat > .env <<EOF
# Orpheus-FastAPI Configuration
ORPHEUS_API_URL=http://127.0.0.1:5006/v1/completions
ORPHEUS_API_TIMEOUT=120
ORPHEUS_MAX_TOKENS=8192
ORPHEUS_TEMPERATURE=0.6
ORPHEUS_TOP_P=0.9
ORPHEUS_SAMPLE_RATE=24000
ORPHEUS_MODEL_NAME=$MODEL_NAME
ORPHEUS_PORT=5005
ORPHEUS_HOST=0.0.0.0
EOF

echo "Environment configured."

# Start llama.cpp server in background
echo "Starting llama.cpp server..."
# Check if llama.cpp is installed
if [ ! -f "llama.cpp/llama-server" ]; then
  echo "llama.cpp not found, downloading and compiling..."
  git clone https://github.com/ggerganov/llama.cpp.git
  cd llama.cpp
  mkdir build
  cd build
  cmake .. -DGGML_CUDA=ON
  cmake --build . --config Release
  cd ../..
fi

# Launch llama.cpp server
nohup llama.cpp/build/bin/llama-server -m models/$MODEL_NAME \
  --port 5006 \
  --host 0.0.0.0 \
  --n-gpu-layers 29 \
  --ctx-size 8192 \
  --n-predict 8192 \
  --rope-scaling linear > llama-server.log 2>&1 &

LLAMA_PID=$!
echo "Llama.cpp server started with PID: $LLAMA_PID"

# Give the server some time to start
echo "Waiting for llama.cpp server to initialize..."
sleep 10

# Start Orpheus-FastAPI
echo "Starting Orpheus-FastAPI server..."
echo "Access the web UI at http://[your-runpod-url]:5005"
echo "API endpoint available at http://[your-runpod-url]:5005/v1/audio/speech"
echo "Press Ctrl+C to stop the servers"

# Start the FastAPI server
python app.py

# Cleanup function
cleanup() {
  echo "Shutting down servers..."
  kill $LLAMA_PID
  echo "Servers stopped."
  exit 0
}

# Set up trap to catch termination signals
trap cleanup SIGINT SIGTERM

# Wait for user to terminate
wait