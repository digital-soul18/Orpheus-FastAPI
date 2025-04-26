# Running Orpheus-FastAPI on RunPod (No Docker)

This guide explains how to run Orpheus-FastAPI directly on RunPod without using Docker.

## Steps to Run on RunPod

1. **Start a RunPod instance**:
   - Choose a GPU pod (RTX 4090, A100, or similar)
   - Use Ubuntu 22.04 or newer base image

2. **Set up the project**:
   ```bash
   # Clone the repository
   git clone https://github.com/timonharz/Orpheus-FastAPI.git
   cd Orpheus-FastAPI
   
   # Make the setup script executable
   chmod +x runpod_setup.sh
   
   # Run the setup script as root
   sudo ./runpod_setup.sh
   ```

3. **Configure model (optional)**:
   You can select a different model by setting the environment variable before running the script:
   ```bash
   # For faster inference (lower quality)
   export ORPHEUS_MODEL_NAME=Orpheus-3b-FT-Q2_K.gguf
   
   # For balanced quality/speed
   export ORPHEUS_MODEL_NAME=Orpheus-3b-FT-Q4_K_M.gguf
   
   # For highest quality (default)
   export ORPHEUS_MODEL_NAME=Orpheus-3b-FT-Q8_0.gguf
   
   # For multilingual support (example: French)
   export ORPHEUS_MODEL_NAME=Orpheus-3b-French-FT-Q8_0.gguf
   
   sudo ./runpod_setup.sh
   ```

4. **Access the web interface**:
   - In RunPod dashboard, go to "Connect" > "HTTP Service" 
   - Set port to 5005
   - Open the provided URL to access the web interface

5. **Use the API**:
   The API endpoint will be available at:
   ```
   http://<your-runpod-url>:5005/v1/audio/speech
   ```

## What the Setup Script Does

The `runpod_setup.sh` script:

1. Installs system dependencies (Python, ffmpeg, etc.)
2. Creates a Python virtual environment
3. Installs PyTorch with CUDA support
4. Installs project dependencies
5. Downloads the specified Orpheus model
6. Sets up environment variables
7. Compiles and launches llama.cpp server
8. Starts the Orpheus-FastAPI server

## Manual Control

If you prefer to run the services manually:

1. To stop both servers: Press Ctrl+C in the terminal

2. To start services separately:
   ```bash
   # Start llama.cpp server
   llama.cpp/build/bin/llama-server -m models/$MODEL_NAME \
     --port 5006 \
     --host 0.0.0.0 \
     --n-gpu-layers 29 \
     --ctx-size 8192 \
     --n-predict 8192 \
     --rope-scaling linear
   
   # In another terminal, start Orpheus-FastAPI
   source venv/bin/activate
   python app.py
   ```

## Troubleshooting

- If you encounter GPU memory issues, reduce the `--n-gpu-layers` parameter
- Check `llama-server.log` for llama.cpp server errors
- Ensure port 5005 and 5006 are not being used by other services