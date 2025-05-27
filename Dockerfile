# Use base image with specified PyTorch and CUDA versions
ARG PYTORCH="1.11.0"
ARG CUDA="11.3"
ARG CUDNN="8"
FROM pytorch/pytorch:${PYTORCH}-cuda${CUDA}-cudnn${CUDNN}-devel

# Set environment variables
ENV TORCH_CUDA_ARCH_LIST="6.0 6.1 7.0+PTX"
ENV TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
ENV CMAKE_PREFIX_PATH="$(dirname $(which conda))/../"
ENV DEBIAN_FRONTEND=noninteractive

# Remove existing NVIDIA repository sources to avoid conflicts
RUN rm -f /etc/apt/sources.list.d/cuda* /etc/apt/sources.list.d/nvidia* && \
    apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 curl ca-certificates && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub | gpg --dearmor -o /usr/share/keyrings/nvidia-cuda-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    apt-get purge --autoremove -y curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    libglib2.0-0 \
    libsm6 \
    libxrender-dev \
    libxext6 \
    libgl1-mesa-dev \
    ffmpeg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    torch==1.11.0 \
    torchvision==0.12.0 \
    torchaudio==0.11.0 \
    opencv-python \
    pillow \
    transformers==4.18.0

# Pre-download Segformer feature extractor weights
RUN python3 -m pip install --no-cache-dir requests datasets && \
    python3 -c "from transformers import SegformerFeatureExtractor; SegformerFeatureExtractor.from_pretrained('nvidia/segformer-b0-finetuned-ade-512-512')"

# Set working directory
WORKDIR /home/segformer_docker/TEST_SEG_OTA
