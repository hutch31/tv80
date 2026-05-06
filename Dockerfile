# Use the official Ubuntu base image
FROM ubuntu:22.04

# Set environment variables to non-interactive to avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install dependencies
RUN apt-get update && \
    apt-get install -y apt-transport-https curl gnupg software-properties-common gzip

# Install JDK 11
RUN apt-get update && \
    apt-get install -y openjdk-11-jdk

# Install Scala using Coursier (non-interactive)
RUN curl -fL https://github.com/coursier/coursier/releases/latest/download/cs-x86_64-pc-linux.gz | gzip -d > cs && \
    chmod +x cs && \
    ./cs setup --yes && \
    mv ~/.local/share/coursier/bin/* /usr/local/bin/

# Install SBT using the official recommendation
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list && \
    echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list && \
    curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import && \
    chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg && \
    apt-get update && \
    apt-get install -y sbt
		    
# Install dependencies
RUN apt-get update && \
    apt-get install -y git help2man perl make autoconf g++ flex bison ccache libgoogle-perftools-dev numactl perl-doc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install dependencies
RUN apt-get update && \
    apt-get install -y python3.10 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install cocotb and cocotb-bus
RUN pip install cocotb==1.8.1 cocotb-bus 

# Install latest reed-solo
RUN pip install --upgrade reedsolo

# Install Verilator
RUN git clone https://github.com/verilator/verilator.git && \
    cd verilator && \
    git checkout v5.022 && \
    autoconf && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf verilator

RUN apt-get update && apt-get install -y sdcc iverilog

# Set the working directory
WORKDIR /app

# Default command
CMD ["bash"]# Use an official Debian runtime as a parent image