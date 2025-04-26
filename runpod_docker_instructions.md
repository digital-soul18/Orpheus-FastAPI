# Running Orpheus-FastAPI on RunPod with Docker Compose

This guide explains how to run Orpheus-FastAPI on RunPod using Docker Compose for easier setup and management.

## Steps to Run on RunPod

1. **Start a RunPod instance**:
   - Choose a GPU pod (RTX 4090, A100, or similar)
   - Use Ubuntu 22.04 or newer base image

2. **Download the setup script**:
   ```bash
   # In your RunPod terminal, download the Docker setup script
   wget https://raw.githubusercontent.com/timonharz/Orpheus-FastAPI/main/runpod_docker_setup.sh
   
   # Make the script executable
   chmod +x runpod_docker_setup.sh
   
   # Run the setup script as root
   sudo ./runpod_docker_setup.sh
   ```

3. **Configure model (optional)**:
   You can select a different model by editing the .env file before running docker-compose:
   ```bash
   # Edit the .env file
   nano .env
   
   # Change the ORPHEUS_MODEL_NAME value to one of:
   # - Orpheus-3b-FT-Q2_K.gguf (faster inference, lower quality)
   # - Orpheus-3b-FT-Q4_K_M.gguf (balanced quality/speed)
   # - Orpheus-3b-FT-Q8_0.gguf (highest quality, default)
   # - Language-specific models like: Orpheus-3b-French-FT-Q8_0.gguf
   
   # After changing .env, restart the services:
   cd Orpheus-FastAPI
   docker-compose down
   docker-compose up -d
   ```

4. **Access the services**:
   - In RunPod dashboard, go to "Connect" > "HTTP Service" 
   - Set port to 5005
   - Open the provided URL to access the web interface

5. **Use the API endpoints**:
   ```
   http://<your-runpod-url>:5005/v1/audio/speech         # Regular endpoint
   http://<your-runpod-url>:5005/v1/audio/speech/stream  # Streaming endpoint
   ```

## What the Docker Setup Does

The `runpod_docker_setup.sh` script:

1. Installs Docker and Docker Compose if not already installed
2. Clones the Orpheus-FastAPI repository
3. Updates the model download URL to use the correct repository
4. Creates a default .env file with configuration settings
5. Builds and starts the services in detached mode

## Docker Compose Services

The setup includes three main services:

1. **model-init**: Downloads the model from HuggingFace
2. **llama-cpp-server**: Runs the inference server with GPU acceleration
3. **orpheus-fastapi**: Runs the FastAPI application to handle API requests

## Managing the Services

- **View logs**: `docker-compose logs -f`
- **Stop services**: `docker-compose down`
- **Restart services**: `docker-compose restart`
- **View running containers**: `docker ps`

## Troubleshooting

- If you encounter GPU issues, you may need to adjust the `--n-gpu-layers` parameter in the docker-compose.yml file
- Check logs with `docker-compose logs -f` for detailed error messages
- Ensure you have sufficient disk space for the models (typically 2-4GB each)
- Verify that port 5005 is exposed in the RunPod HTTP settings