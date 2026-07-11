# Use official lightweight Python image
FROM python:3.12-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    POETRY_VERSION=1.8.2 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    PATH="/opt/poetry/bin:$PATH"

# Install system dependencies (needed for compilation of some packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3 -

# Set working directory
WORKDIR /app

# Copy poetry dependency files
COPY pyproject.toml poetry.lock* ./

# Install dependencies only (cached layer)
RUN poetry install --no-root --only main

# Copy source code and config files
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./

# Make sure virtualenv binaries are in path
ENV PATH="/app/.venv/bin:$PATH"

# Expose port
EXPOSE 8000

# Start command
# We run uvicorn with factory function main:create_app
CMD ["uvicorn", "app.main:create_app", "--host", "0.0.0.0", "--port", "8000"]
