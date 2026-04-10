# CLIF-WorkBench

Standardized Docker base images for the [CLIF](https://github.com/Common-Longitudinal-ICU-data-Format) (Common Longitudinal ICU data Format) ecosystem. Pre-built environments so CLIF project sites can pull, mount data + code, and run — no local Python setup required.

## Images

| Image | Base | Size | Use for |
|-------|------|------|---------|
| `clif-workbench:ml` | `python:3.12-slim-bookworm` | ~700-900 MB | ETL, clinical analysis, classical ML (most CLIF projects) |
| `clif-workbench:ai` | `nvidia/cuda:12.8.0-devel-ubuntu22.04` | ~8-10 GB | Deep learning with GPU (CLIFATRON, CLIF-RL) |

Both images include: **Python 3.12**, **uv** (fast package manager), **clifpy**, pandas, polars, duckdb, scikit-learn, statsmodels, matplotlib, streamlit, and more.

The **AI image** additionally includes: PyTorch (CUDA 12.8), transformers, deepspeed, accelerate, xgboost, optuna, trl, wandb, shap.

## Quick Start

### Pull an image

```bash
docker pull clifconsortium/clif-workbench:ml
docker pull clifconsortium/clif-workbench:ai
```

### Run a project

Mount your CLIF data to `/data` and project code to `/project`, then execute:

```bash
# Run a project's pipeline script
docker run --rm \
  -v /path/to/clif_data:/data \
  -v /path/to/CLIF-C2D2:/project \
  clifconsortium/clif-workbench:ml \
  bash /project/run.sh

# Or run a single Python file
docker run --rm \
  -v /path/to/clif_data:/data \
  -v /path/to/my-project:/project \
  clifconsortium/clif-workbench:ml \
  python /project/analysis.py
```

### GPU workloads

```bash
docker run --rm --gpus all \
  -v /path/to/clif_data:/data \
  -v /path/to/CLIFATRON:/project \
  clifconsortium/clif-workbench:ai \
  bash /project/run.sh
```

### Interactive shell

```bash
docker run -it --rm \
  -v /path/to/clif_data:/data \
  clifconsortium/clif-workbench:ml \
  bash
```

## Singularity / Apptainer

For sites where Docker is not available (e.g., HPC clusters), pull the Docker Hub images directly as Singularity `.sif` files:

```bash
singularity pull clif-ml.sif docker://clifconsortium/clif-workbench:ml
singularity pull clif-ai.sif docker://clifconsortium/clif-workbench:ai
```

```bash
# CPU workload
singularity exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/project:/project \
  clif-ml.sif \
  bash /project/run.sh

# GPU workload
singularity exec --nv \
  --bind /path/to/clif_data:/data \
  --bind /path/to/project:/project \
  clif-ai.sif \
  bash /project/run.sh
```

> **Note:** Apptainer is the community fork of Singularity — commands are identical, just replace `singularity` with `apptainer`.

> For SLURM job scripts, offline usage, troubleshooting, and site-specific HPC docs, see [docs/singularity-apptainer-guide.md](docs/singularity-apptainer-guide.md).

## Extra Packages

If your project needs a package not in the image, install it at runtime in your `run.sh`:

```bash
#!/bin/bash
# run.sh
uv pip install --system firthlogist sas7bdat   # ~2-5 seconds with uv
python /project/analysis.py
python /project/report.py
```

For faster repeat runs, mount a uv cache volume:

```bash
docker run --rm \
  -v /path/to/clif_data:/data \
  -v /path/to/project:/project \
  -v /path/to/uv_cache:/root/.cache/uv \
  clifconsortium/clif-workbench:ml \
  bash /project/run.sh
```

## Build Locally

```bash
# Build ML image
./scripts/build.sh ml

# Build AI image
./scripts/build.sh ai

# Build both
./scripts/build.sh all
```

## Publish to Docker Hub

```bash
# First time: log in to Docker Hub
docker login

# Push ML image
./scripts/publish.sh ml

# Push AI image
./scripts/publish.sh ai

# Push both with a version tag
./scripts/publish.sh all 0.1.0

# Use a different Docker Hub org
DOCKERHUB_ORG=myorg ./scripts/publish.sh all
```

## Test Images

```bash
./scripts/test-images.sh ml
./scripts/test-images.sh ai
./scripts/test-images.sh all
```

## Tags

| Tag | Description |
|-----|-------------|
| `ml` | Latest ML image (data + classical ML) |
| `ai` | Latest AI image (+ PyTorch/CUDA 12.8) |
| `latest` | Alias for `ml` |
| `X.Y.Z-ml`, `X.Y.Z-ai` | Version-pinned images |

## Project Structure

```
CLIF-WorkBench/
├── docs/
│   ├── docker-tags-and-versioning.md
│   └── singularity-apptainer-guide.md
├── images/
│   ├── ml/                    # ML image build context
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── container_bashrc
│   │   └── .dockerignore
│   └── ai/                    # AI image build context
│       ├── Dockerfile
│       ├── requirements.txt
│       ├── container_bashrc
│       └── .dockerignore
├── scripts/
│   ├── build.sh               # Build images locally
│   ├── publish.sh             # Push to Docker Hub
│   └── test-images.sh         # Smoke tests
```
