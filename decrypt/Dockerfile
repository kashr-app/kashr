# Use a Python 3 base image
FROM python:3.9-slim

# Install dependencies, including OpenSSL and git
RUN apt-get update && \
    apt-get install -y \
#    build-essential \
    build-essential libssl-dev libffi-dev \
    python3-dev cargo pkg-config \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install cryptography from GitHub
RUN pip3 install --no-cache-dir git+https://github.com/pyca/cryptography.git

# Create a directory for your app
WORKDIR /app

# Copy the Python script into the container (Optional if you are mounting volume)
# COPY decrypt_backup.py /app/

# Set the entrypoint to run the script
ENTRYPOINT ["python3", "decrypt_backup.py"]
