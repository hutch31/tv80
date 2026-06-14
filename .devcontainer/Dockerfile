# Use the 0.8 chiselware container as the base image
FROM ghcr.io/chiselware/dev-full:0.8.0

# Install cocotb and cocotb-bus
RUN apt-get update && apt-get install -y sdcc
RUN pip install --break-system-packages cocotb==1.9.2 cocotb-bus

