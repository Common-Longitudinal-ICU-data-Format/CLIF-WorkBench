# CLIF-WorkBench

Apptainer containers for the [CLIF](https://github.com/Common-Longitudinal-ICU-data-Format) (Common Longitudinal ICU data Format) ecosystem. Pre-built environments so CLIF project sites can install one `.sif` file, mount data + code, and run — no local Python setup required.

## Images

| Image | Base | `.sif` size | Use for |
|-------|------|-------------|---------|
| `clif-workbench:ml` | `python:3.12-slim-bookworm` | ~1 GB | ETL, clinical analysis, classical ML (most CLIF projects) |
| `clif-workbench:ai` | `nvidia/cuda:12.8.0-devel-ubuntu22.04` | ~10 GB | Deep learning with GPU (CLIFATRON, CLIF-RL) |

Both images include: **Python 3.12**, **uv** (fast package manager), **clifpy**, pandas, polars, duckdb, scikit-learn, statsmodels, matplotlib, streamlit, and more.

The **AI image** additionally includes: PyTorch (CUDA 12.8), transformers, deepspeed, accelerate, xgboost, optuna, trl, wandb, shap.

## Install — pick your path

### Path 1 — Online pull (recommended when your machine has internet)

```bash
apptainer pull clif-ml.sif docker://clifconsortium/clif-workbench:ml
apptainer pull clif-ai.sif docker://clifconsortium/clif-workbench:ai
```

> `docker://` is just the URL scheme Apptainer uses to fetch from a container registry — you do not need Docker installed.

For reproducibility, pin to a version:

```bash
apptainer pull clif-ml-0.1.0.sif docker://clifconsortium/clif-workbench:0.1.0-ml
```

### Path 2 — Download `.sif` from GitHub Releases (no registry access)

The ML image is published as a `.sif` asset on each tagged release. Download from a web-connected machine, transfer to your cluster, verify checksum:

```bash
wget https://github.com/Common-Longitudinal-ICU-data-Format/CLIF-WorkBench/releases/download/v0.1.0/clif-ml-0.1.0.sif
wget https://github.com/Common-Longitudinal-ICU-data-Format/CLIF-WorkBench/releases/download/v0.1.0/clif-ml-0.1.0.sif.sha256
sha256sum -c clif-ml-0.1.0.sif.sha256
```

> The AI image exceeds GitHub's 2 GB per-file cap, so it's not on Releases — use Path 1 or Path 3.

### Path 3 — Copy a `.sif` from a colleague (fully offline)

A `.sif` file is self-contained. If anyone at your site (or a collaborating site) already has the image, just copy the file:

```bash
# On the source machine
sha256sum clif-ai.sif > clif-ai.sif.sha256
scp clif-ai.sif clif-ai.sif.sha256 user@your-cluster:~/

# On your cluster
sha256sum -c clif-ai.sif.sha256
```

Always verify the checksum after transfer.

## Run a project

Mount your CLIF data to `/data` and project code to `/project`, then execute:

```bash
# CPU workload (ML image)
apptainer exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/CLIF-C2D2:/project \
  clif-ml.sif \
  bash /project/run.sh

# GPU workload (AI image)
apptainer exec --nv \
  --bind /path/to/clif_data:/data \
  --bind /path/to/CLIFATRON:/project \
  clif-ai.sif \
  bash /project/run.sh

# Single Python file
apptainer exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/my-project:/project \
  clif-ml.sif \
  python /project/analysis.py

# Interactive shell
apptainer shell --bind /path/to/clif_data:/data clif-ml.sif
```

## Extra packages

If your project needs a package not in the image, install it at runtime in your `run.sh`:

```bash
#!/bin/bash
# run.sh
uv pip install --system firthlogist sas7bdat   # ~2–5 seconds with uv
python /project/analysis.py
python /project/report.py
```

The `.sif` is read-only, so you need a writable layer — pass `--writable-tmpfs` when running:

```bash
apptainer exec --writable-tmpfs \
  --bind /path/to/clif_data:/data \
  --bind /path/to/project:/project \
  clif-ml.sif \
  bash /project/run.sh
```

For persistent installs across runs, or for air-gapped clusters with no pip access, see [docs/apptainer-guide.md](docs/apptainer-guide.md#installing-extra-packages).

## HPC / SLURM

For SLURM job scripts, cache-directory tuning, environment footguns, institutional HPC docs, and troubleshooting, see:

➡️ **[docs/apptainer-guide.md](docs/apptainer-guide.md)**

## Tags

| Tag | Description |
|-----|-------------|
| `ml` | Latest ML image (data + classical ML) |
| `ai` | Latest AI image (+ PyTorch/CUDA 12.8) |
| `latest` | Alias for `ml` |
| `X.Y.Z-ml`, `X.Y.Z-ai` | Version-pinned images |

## Project structure

```
CLIF-WorkBench/
├── docs/
│   ├── apptainer-guide.md          # HPC/SLURM/troubleshooting (user-facing)
│   └── maintainers/                # Build + release docs (internal)
├── images/
│   ├── ml/                         # ML image build context
│   └── ai/                         # AI image build context
├── scripts/
│   ├── build.sh                    # Build images (maintainer)
│   ├── build-sif.sh                # Convert image to .sif (maintainer)
│   ├── publish.sh                  # Publish images to registry (maintainer)
│   ├── publish-sif.sh              # Upload .sif to GitHub Releases (maintainer)
│   └── test-images.sh              # Smoke tests (maintainer)
```

## For maintainers

The images are built with Docker, pushed to Docker Hub, and (for the ML image) also packaged as `.sif` assets on GitHub Releases. End users never need Docker.

- [Building and publishing images](docs/maintainers/building-images.md)
- [Tags & versioning](docs/maintainers/versioning.md)
