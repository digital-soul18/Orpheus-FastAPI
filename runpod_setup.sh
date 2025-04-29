#!/bin/bash
# Orpheus-FastAPI Setup Script for RunPod (No Docker)
#
# To enable Canary speech recognition model:
# CANARY_MODEL_ENABLED=true ./runpod_setup.sh
#
set -e

# Check if --install-canary was passed
INSTALL_CANARY=false
for arg in "$@"; do
  if [[ "$arg" == "--install-canary" ]]; then
    INSTALL_CANARY=true
    export CANARY_MODEL_ENABLED=true
    echo "⚠️ Installing Canary STT model (--install-canary flag detected)"
  fi
done

# Check for direct install command
if [[ "$1" == "install-canary" ]]; then
  echo "⚠️ Running NeMo installation for Canary STT..."
  # Install Python dependencies for NeMo
  pip3 install --no-cache-dir text-unidecode omegaconf
  
  # Install NeMo with ASR support
  NEMO_BRANCH='r2.3.0'
  pip3 install --no-cache-dir git+https://github.com/NVIDIA/NeMo.git@${NEMO_BRANCH}#egg=nemo_toolkit[asr]
  
  # Set CANARY_MODEL_ENABLED=true in .env
  if [ -f ".env" ]; then
    sed -i 's/CANARY_MODEL_ENABLED=.*/CANARY_MODEL_ENABLED=true/g' .env
    if ! grep -q "CANARY_MODEL_ENABLED" .env; then
      echo "# Canary STT Model Configuration" >> .env
      echo "CANARY_MODEL_ENABLED=true" >> .env
    fi
  fi
  
  echo "✅ NeMo installed successfully"
  echo "✅ Canary STT model will be downloaded on next server start"
  echo "✅ CANARY_MODEL_ENABLED=true set in .env"
  exit 0
fi

echo "Setting up Orpheus-FastAPI on RunPod..."

# Install dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y python3.10 python3-pip python3-venv libsndfile1 ffmpeg portaudio19-dev wget git cmake build-essential libcurl4-openssl-dev sox

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
pip3 install httpx omegaconf

# Check if we should install NeMo for Canary model
if [ -f ".env" ]; then
  # Source the environment variables from .env
  CANARY_ENABLED_VALUE=$(grep -E "^CANARY_MODEL_ENABLED\s*=\s*(true|false)" .env | sed -E 's/^CANARY_MODEL_ENABLED\s*=\s*//')
  echo "CANARY_MODEL_ENABLED from .env: ${CANARY_ENABLED_VALUE}"
  if [ "${CANARY_ENABLED_VALUE}" = "true" ]; then
    export CANARY_MODEL_ENABLED=true
  fi
fi

echo "Final CANARY_MODEL_ENABLED: ${CANARY_MODEL_ENABLED}"

# Force installation if explicitly running with CANARY_MODEL_ENABLED=true
if [[ "${CANARY_MODEL_ENABLED}" == "true" || "${INSTALL_CANARY}" == "true" ]]; then
  echo "Installing NVIDIA NeMo for Canary STT model..."
  # Install Python dependencies for NeMo
  pip3 install --no-cache-dir text-unidecode omegaconf
  
  # Install NeMo with ASR support
  NEMO_BRANCH='r2.3.0'
  pip3 install --no-cache-dir git+https://github.com/NVIDIA/NeMo.git@${NEMO_BRANCH}#egg=nemo_toolkit[asr]
  echo "NeMo installation completed"
  
  echo "NeMo installation status: $?"
  echo "Verifying NeMo installation..."
  pip3 list | grep -E 'nemo|omegaconf|text-unidecode'
fi

# Download Orpheus model if not present
MODEL_NAME=${ORPHEUS_MODEL_NAME:-Orpheus-3b-FT-Q8_0.gguf}
echo "Checking for model $MODEL_NAME..."

if [ ! -f "models/$MODEL_NAME" ]; then
  echo "Downloading model from HuggingFace..."
  wget -P models https://huggingface.co/timonharz/$MODEL_NAME/resolve/main/$MODEL_NAME
else
  echo "Model already exists."
fi

# Check if we should download the Canary model
if [[ "${CANARY_MODEL_ENABLED}" == "true" ]]; then
  echo "Canary STT model will be downloaded at startup when required"
fi

# Set up environment variables - preserve existing .env if it exists
if [ -f ".env" ]; then
  echo "Existing .env file found, preserving and updating settings..."
  
  # Load existing .env values as defaults
  if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
  fi
  
  # Back up the existing file
  cp .env .env.backup
  
  # Update CANARY_MODEL_ENABLED to true if we're running with it enabled
  if [[ "${CANARY_MODEL_ENABLED}" == "true" ]]; then
    sed -i 's/CANARY_MODEL_ENABLED=.*/CANARY_MODEL_ENABLED=true/g' .env
    
    # If the variable doesn't exist in the file, add it
    if ! grep -q "CANARY_MODEL_ENABLED" .env; then
      echo "# Canary STT Model Configuration" >> .env
      echo "CANARY_MODEL_ENABLED=true" >> .env
    fi
    
    echo "Updated .env with CANARY_MODEL_ENABLED=true"
  fi
  
else
  # Create new .env file if none exists
  echo "Creating new .env file..."
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

# Canary STT Model Configuration
CANARY_MODEL_ENABLED=${CANARY_MODEL_ENABLED:-true}

# OpenAI API Configuration - Replace with your API key
# OPENAI_API_KEY=your-openai-api-key-here
EOF
fi

echo "Environment configured."

# Start llama.cpp server in background
echo "Starting llama.cpp server..."

# Check if llama.cpp directory exists first
if [ -d "llama.cpp" ]; then
  echo "llama.cpp directory exists, checking for binary..."
  
  # Check if the llama-server binary exists in any of the potential locations
  if [ -f "llama.cpp/llama-server" ]; then
    echo "Using existing llama-server from llama.cpp directory"
    LLAMA_SERVER="llama.cpp/llama-server"
  elif [ -f "llama.cpp/build/bin/llama-server" ]; then
    echo "Using existing llama-server from llama.cpp/build/bin directory"
    LLAMA_SERVER="llama.cpp/build/bin/llama-server"
  elif [ -f "llama.cpp/server" ]; then
    echo "Using existing llama-server from older llama.cpp build"
    LLAMA_SERVER="llama.cpp/server"
  else
    echo "llama.cpp directory exists but no server binary found, recompiling..."
    cd llama.cpp
    mkdir -p build
    cd build
    cmake .. -DGGML_CUDA=ON
    cmake --build . --config Release
    cd ../..
    
    # Check if build succeeded
    if [ -f "llama.cpp/build/bin/llama-server" ]; then
      LLAMA_SERVER="llama.cpp/build/bin/llama-server"
    else
      echo "Failed to find llama-server after build, checking alternative locations..."
      LLAMA_SERVER=$(find llama.cpp -name "llama-server" -type f | head -1)
      if [ -z "$LLAMA_SERVER" ]; then
        echo "ERROR: Could not find llama-server binary. Please install manually."
        exit 1
      fi
    fi
  fi
else
  # Fresh install of llama.cpp
  echo "llama.cpp not found, downloading and compiling..."
  git clone https://github.com/ggerganov/llama.cpp.git
  cd llama.cpp
  mkdir -p build
  cd build
  cmake .. -DGGML_CUDA=ON
  cmake --build . --config Release
  cd ../..
  
  # Check if build succeeded
  if [ -f "llama.cpp/build/bin/llama-server" ]; then
    LLAMA_SERVER="llama.cpp/build/bin/llama-server"
  else
    echo "Failed to find llama-server after build, checking alternative locations..."
    LLAMA_SERVER=$(find llama.cpp -name "llama-server" -type f | head -1)
    if [ -z "$LLAMA_SERVER" ]; then
      echo "ERROR: Could not find llama-server binary. Please install manually."
      exit 1
    fi
  fi
fi

# Launch llama.cpp server using detected binary
echo "Starting llama.cpp server with: $LLAMA_SERVER"
nohup $LLAMA_SERVER -m models/$MODEL_NAME \
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