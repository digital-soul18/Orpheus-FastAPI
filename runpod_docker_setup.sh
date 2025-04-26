#!/bin/bash
# Orpheus-FastAPI Docker Compose Setup for RunPod
set -e

echo "Setting up Orpheus-FastAPI with Docker Compose on RunPod..."

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  # Use newer method for installing Docker keyring
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io
fi

# Ensure Docker daemon is running
echo "Ensuring Docker daemon is running..."
systemctl start docker
systemctl enable docker
systemctl status docker

# Install Docker Compose if not installed
if ! command -v docker-compose &> /dev/null; then
  echo "Installing Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# Clone repository if not already cloned
if [ ! -d "Orpheus-FastAPI" ]; then
  echo "Cloning Orpheus-FastAPI repository..."
  git clone https://github.com/timonharz/Orpheus-FastAPI.git
  cd Orpheus-FastAPI
else
  echo "Repository already exists, navigating to it..."
  cd Orpheus-FastAPI
fi

# Update model download URL to use timonharz's repository
echo "Updating model download source in docker-compose.yml..."
sed -i 's|wget -P /app/models https://huggingface.co/lex-au/${ORPHEUS_MODEL_NAME}/resolve/main/${ORPHEUS_MODEL_NAME}|wget -P /app/models https://huggingface.co/timonharz/${ORPHEUS_MODEL_NAME}/resolve/main/${ORPHEUS_MODEL_NAME}|g' docker-compose.yml

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
  echo "Creating .env file..."
  cat > .env <<EOF
# Orpheus-FastAPI Docker Compose Configuration
ORPHEUS_API_URL=http://llama-cpp-server:5006/v1/completions
ORPHEUS_API_TIMEOUT=120
ORPHEUS_MAX_TOKENS=8192
ORPHEUS_TEMPERATURE=0.6
ORPHEUS_TOP_P=0.9
ORPHEUS_SAMPLE_RATE=24000
ORPHEUS_MODEL_NAME=Orpheus-3b-FT-Q8_0.gguf
ORPHEUS_PORT=5005
ORPHEUS_HOST=0.0.0.0
UID=$(id -u)
GID=$(id -g)
EOF
fi

# Create models directory
mkdir -p models

echo "Starting Docker Compose services..."
docker-compose up -d

echo "Orpheus-FastAPI is now running with Docker Compose!"
echo "Access the web UI at http://[your-runpod-url]:5005"
echo "API endpoint available at http://[your-runpod-url]:5005/v1/audio/speech"
echo "Streaming endpoint available at http://[your-runpod-url]:5005/v1/audio/speech/stream"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop services: docker-compose down"