# CLAUDE.md - Orpheus TTS FastAPI Guide

## Build & Run Commands
- Run server: `python app.py` or `uvicorn app:app --host 0.0.0.0 --port 5005 --reload`
- Run tests: `pytest tests/`
- Run single test: `pytest tests/test_speechpipe.py::test_function_name -v`
- Docker: `docker compose up --build`
- Create env file: `cp .env.example .env`

## Code Style Guidelines
- **Imports**: Standard lib → third-party → local (grouped, alphabetical)
- **Formatting**: 4-space indentation, 100 char line limit
- **Types**: Use explicit type annotations with Python's typing module
- **Naming**: snake_case for variables/functions, PascalCase for classes
- **Error Handling**: Use specific exception types, log errors appropriately
- **Documentation**: Docstrings for functions and classes (Google style)
- **Constants**: UPPER_CASE, defined at module level
- **Async**: Use async/await pattern for FastAPI routes and streaming

## Performance Patterns
- Use caching for repeated operations
- Optimize buffer sizes for audio processing (100ms chunks)
- Process long text in logical sentence-based batches with crossfades
- Optimize for GPU type (RTX GPUs get 4 workers, 32 token batches)
- Vectorize tensor operations and use CUDA streams when available

## Voice & Emotion Format
- Voice format: `"voice": "tara"` (use voice ID from README list)
- Emotion tags: `<laugh>`, `<sigh>`, `<chuckle>`, `<cough>`, `<sniffle>`, etc.