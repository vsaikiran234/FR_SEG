# Use base image with specified PyTorch and CUDA versions
ARG PYTORCH="1.11.0"
ARG CUDA="11.3"
ARG CUDNN="8"
FROM pytorch/pytorch:${PYTORCH}-cuda${CUDA}-cudnn${CUDNN}-devel

# Set environment variables
ENV TORCH_CUDA_ARCH_LIST="6.0 6.1 7.0+PTX"
ENV TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
ENV CMAKE_PREFIX_PATH="$(dirname $(which conda))/../"

# Add missing NVIDIA GPG key (optional fix for apt-get issues)
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

# Install required system packages
RUN apt-get update && apt-get install -y \
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
    torch torchvision torchaudio \
    opencv-python pillow transformers

# Pre-download Segformer feature extractor weights (optional optimization)
RUN python3 -c "from transformers import SegformerFeatureExtractor; SegformerFeatureExtractor.from_pretrained('nvidia/segformer-b0-finetuned-ade-512-512')"
