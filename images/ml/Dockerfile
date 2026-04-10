# =============================================================================
# clif-workbench:ml
# Stateless base image for CLIF projects requiring data + classical ML stack
#
# Usage (mount data + project code, run via .sh or single file):
#   docker run --rm \
#     -v /site/clif_data:/data \
#     -v /site/my-project:/project \
#     clif-workbench:ml \
#     bash /project/run.sh
# =============================================================================

FROM python:3.12-slim-bookworm

LABEL org.opencontainers.image.title="clif-workbench:ml"
LABEL org.opencontainers.image.description="CLIF ecosystem ML image — Python 3.12, uv, data stack, classical ML"
LABEL org.opencontainers.image.source="https://github.com/Common-Longitudinal-ICU-data-Format/CLIF-WorkBench"
LABEL org.opencontainers.image.vendor="CLIF Consortium"

# --- Install uv ---
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# --- System dependencies ---
# libgomp1: OpenMP runtime (polars, duckdb parallel execution)
# git: needed for editable installs from git repos
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# --- Environment configuration ---
ENV UV_SYSTEM_PYTHON=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# --- Custom shell config ---
COPY container_bashrc /root/.bashrc

# --- Install Python packages ---
COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# --- Verify core imports ---
RUN python -c "\
import clifpy; \
import pandas; \
import polars; \
import duckdb; \
import sklearn; \
import statsmodels; \
print(f'clif-workbench:ml OK — clifpy={clifpy.__version__}, pandas={pandas.__version__}')"

# --- Workspace ---
WORKDIR /project

CMD ["python"]
