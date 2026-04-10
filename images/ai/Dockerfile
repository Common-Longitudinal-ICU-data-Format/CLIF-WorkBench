# =============================================================================
# clif-workbench:ai
# Stateless base image for CLIF projects requiring GPU + deep learning stack
#
# Base: nvidia/cuda:12.8.0-devel-ubuntu22.04
# Python 3.12 installed via deadsnakes PPA
# Uses uv for dependency installation
#
# Usage (mount data + project code, run via .sh or single file):
#   docker run --rm --gpus all \
#     -v /site/clif_data:/data \
#     -v /site/CLIFATRON:/project \
#     clif-workbench:ai \
#     bash /project/run.sh
# =============================================================================

FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

LABEL org.opencontainers.image.title="clif-workbench:ai"
LABEL org.opencontainers.image.description="CLIF ecosystem AI image — CUDA 12.8, Python 3.12, PyTorch, transformers, deepspeed"
LABEL org.opencontainers.image.source="https://github.com/Common-Longitudinal-ICU-data-Format/CLIF-WorkBench"
LABEL org.opencontainers.image.vendor="CLIF Consortium"

# --- Prevent interactive prompts during apt install ---
ENV DEBIAN_FRONTEND=noninteractive

# --- Install Python 3.12 via deadsnakes PPA ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3.12-distutils \
    && rm -rf /var/lib/apt/lists/*

# --- Set Python 3.12 as default ---
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# --- Install uv ---
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# --- System dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# --- Environment configuration ---
ENV UV_SYSTEM_PYTHON=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# --- Custom shell config ---
COPY container_bashrc /root/.bashrc

# --- Install PyTorch first (largest dep, separate layer for caching) ---
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system \
    "torch>=2.8.0" \
    --index-url https://download.pytorch.org/whl/cu128

# --- Install remaining packages ---
COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# --- Verify core imports ---
RUN python -c "\
import torch; \
import transformers; \
import clifpy; \
print(f'clif-workbench:ai OK — PyTorch={torch.__version__}, CUDA={torch.cuda.is_available()}, clifpy={clifpy.__version__}')"

# --- Workspace ---
WORKDIR /project

CMD ["python"]
