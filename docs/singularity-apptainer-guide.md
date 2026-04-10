# Singularity / Apptainer Guide

Apptainer (formerly Singularity) is the container runtime used on most university HPC clusters. Unlike Docker, it runs as your normal user — no root, no daemon. Images are single read-only `.sif` files that are easy to share, audit, and reproduce. This guide covers everything you need to run CLIF-WorkBench images on an HPC cluster.

> Throughout this guide we use `singularity` in commands. If your cluster provides Apptainer, replace `singularity` with `apptainer` everywhere — the flags and behavior are identical.

## Prerequisites

**Container runtime.** Most clusters provide Apptainer or Singularity as a module or system-wide install:

```bash
module load apptainer          # or: module load singularity
singularity --version          # verify it's available
```

**Internet access.** You need internet on the node where you pull images (usually the login node). Compute nodes typically do not have internet.

**Disk space.** The `.sif` files need storage:

| Image | `.sif` size | Cache needed during pull |
|-------|-------------|------------------------|
| `clif-workbench:ml` | ~1 GB | ~2-3 GB |
| `clif-workbench:ai` | ~10 GB | ~20-25 GB |

> If your home directory has a small quota, set the cache directory before pulling:
> ```bash
> export SINGULARITY_CACHEDIR=/scratch/$USER/.singularity/cache
> export SINGULARITY_TMPDIR=/scratch/$USER/tmp
> mkdir -p $SINGULARITY_CACHEDIR $SINGULARITY_TMPDIR
> ```

**For GPU workloads** (`:ai` image only):
- NVIDIA drivers must be installed on compute nodes (this is your cluster admin's responsibility)
- The container has CUDA 12.8, which requires host driver **>= 525**
- Check your driver: run `nvidia-smi` on a compute node — the driver version is on the top line

## Quick Start

### Pull images

Run this on the login node (it has internet):

```bash
singularity pull clif-ml.sif docker://clifconsortium/clif-workbench:ml
singularity pull clif-ai.sif docker://clifconsortium/clif-workbench:ai
```

For reproducible pipelines, pull a version-pinned image (see [Docker Tags & Versioning](docker-tags-and-versioning.md)):

```bash
singularity pull clif-ml-0.1.0.sif docker://clifconsortium/clif-workbench:0.1.0-ml
```

After a successful pull, clean the layer cache to reclaim space:

```bash
singularity cache clean
```

### Run a CPU workload

```bash
singularity exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/my-project:/project \
  clif-ml.sif \
  bash /project/run.sh
```

### Run a GPU workload

```bash
singularity exec --nv \
  --bind /path/to/clif_data:/data \
  --bind /path/to/CLIFATRON:/project \
  clif-ai.sif \
  bash /project/run.sh
```

### Interactive shell

```bash
singularity shell --bind /path/to/clif_data:/data clif-ml.sif
```

### Run a single Python command

```bash
singularity exec clif-ml.sif python -c "import clifpy; print(clifpy.__version__)"
```

## SLURM Job Script Examples

> Replace partition names, GPU syntax, and paths with what your cluster uses. Run `sinfo` to see available partitions.

### Basic CPU job (ML image)

```bash
#!/bin/bash
#SBATCH --job-name=clif-etl
#SBATCH --output=clif-etl-%j.log
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --partition=normal        # <-- replace with your cluster's partition

set -euo pipefail

module load apptainer             # some clusters have it system-wide; skip if so

singularity exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/my-project:/project \
  /path/to/clif-ml.sif \
  bash /project/run.sh
```

### GPU job (AI image)

```bash
#!/bin/bash
#SBATCH --job-name=clif-train
#SBATCH --output=clif-train-%j.log
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --partition=gpu           # <-- replace with your cluster's GPU partition
#SBATCH --gres=gpu:1              # some clusters use --gpus=1 or --gres=gpu:a100:1

set -euo pipefail

module load apptainer

# Verify GPU is visible before starting
singularity exec --nv /path/to/clif-ai.sif \
  python -c "import torch; assert torch.cuda.is_available(), 'No GPU found'"

singularity exec --nv \
  --bind /path/to/clif_data:/data \
  --bind /path/to/CLIFATRON:/project \
  /path/to/clif-ai.sif \
  bash /project/run.sh
```

### Multi-GPU job

```bash
#!/bin/bash
#SBATCH --job-name=clif-multi-gpu
#SBATCH --output=clif-multi-gpu-%j.log
#SBATCH --cpus-per-task=32
#SBATCH --mem=256G
#SBATCH --time=48:00:00
#SBATCH --partition=gpu
#SBATCH --gres=gpu:4

set -euo pipefail

module load apptainer

singularity exec --nv \
  --bind /path/to/clif_data:/data \
  --bind /path/to/CLIFATRON:/project \
  /path/to/clif-ai.sif \
  python -m torch.distributed.run \
    --nproc_per_node=4 \
    /project/train.py
```

### Array job (batch processing)

```bash
#!/bin/bash
#SBATCH --job-name=clif-batch
#SBATCH --output=clif-batch-%A_%a.log
#SBATCH --array=0-9
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --partition=normal

set -euo pipefail

module load apptainer

singularity exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/my-project:/project \
  /path/to/clif-ml.sif \
  python /project/process_batch.py --batch-id "$SLURM_ARRAY_TASK_ID"
```

## Key Differences from Docker

| Concept | Docker | Singularity / Apptainer |
|---------|--------|------------------------|
| Mount a directory | `-v /host:/container` | `--bind /host:/container` |
| Enable GPU | `--gpus all` | `--nv` |
| Run a command | `docker run IMAGE CMD` | `singularity exec IMAGE CMD` |
| Interactive shell | `docker run -it IMAGE bash` | `singularity shell IMAGE` |
| Image format | Layered (stored in daemon) | Single `.sif` file |
| Filesystem | Writable by default | Read-only by default |
| Auto-mounted dirs | None (fully isolated) | `$HOME`, `$PWD`, `/tmp`, `/dev` |
| Root required | Yes (daemon runs as root) | No |
| Install extra packages | `pip install` in run.sh | Need `--writable-tmpfs` flag |

### Watch out for auto-mounts

Singularity mounts your home directory by default. If you have Python packages in `~/.local/lib/python3.12/site-packages/`, they can **shadow** packages inside the container. For example, a CPU-only `torch` in your home directory could override the GPU-enabled one in the `:ai` image.

Fixes:

```bash
# Option A: block user site-packages
export PYTHONNOUSERSITE=1

# Option B: don't mount home at all
singularity exec --no-home ...

# Option C: full isolation (then explicitly --bind what you need)
singularity exec --contain --bind /path/to/data:/data ...
```

### Watch out for host environment leaking in

If you have conda environments or loaded modules, their `$PATH` and `$PYTHONPATH` can leak into the container. Use `--cleanenv` to start clean, but note that this also strips `$SLURM_*` variables:

```bash
singularity exec --cleanenv \
  --env SLURM_JOB_ID=$SLURM_JOB_ID \
  --bind /path/to/data:/data \
  clif-ml.sif bash /project/run.sh
```

Or simply `module purge` before running Singularity.

## Installing Extra Packages

The `.sif` image is read-only, so `uv pip install` in your `run.sh` needs a writable layer. Four options, from simplest to most permanent:

### Option 1: `--writable-tmpfs` (recommended)

Adds a temporary in-memory writable layer. Packages are lost when the container exits, but `uv` reinstalls them in seconds.

```bash
singularity exec --writable-tmpfs \
  --bind /path/to/clif_data:/data \
  --bind /path/to/project:/project \
  clif-ml.sif \
  bash /project/run.sh
```

Where `run.sh` contains:

```bash
#!/bin/bash
uv pip install --system firthlogist sas7bdat
python /project/analysis.py
```

### Option 2: Overlay image (persistent)

Packages survive across runs without rebuilding the `.sif`.

```bash
# Create a 1 GB ext3 overlay (one-time)
dd if=/dev/zero of=clif-overlay.img bs=1M count=1024
mkfs.ext3 -F clif-overlay.img

# Run with the overlay
singularity exec --overlay clif-overlay.img \
  --bind /path/to/data:/data \
  clif-ml.sif \
  bash -c "uv pip install --system firthlogist && python /project/analysis.py"
```

> Some clusters restrict overlay usage. Check your site's documentation.

### Option 3: Offline wheel bundles (air-gapped clusters)

For clusters with no internet at all — download wheels on a connected machine, copy them over.

```bash
# On a machine with internet
pip download -d ./wheels firthlogist sas7bdat

# Copy wheels/ to the cluster, then:
singularity exec --writable-tmpfs \
  --bind ./wheels:/wheels \
  --bind /path/to/project:/project \
  clif-ml.sif \
  bash -c "uv pip install --system --no-index --find-links /wheels firthlogist sas7bdat \
    && python /project/analysis.py"
```

### Option 4: Custom `.sif` from a definition file

Bake extra packages permanently into a new image.

```
# clif-custom.def
Bootstrap: docker
From: clifconsortium/clif-workbench:ml

%post
    uv pip install --system firthlogist sas7bdat

%runscript
    python "$@"
```

```bash
singularity build clif-custom.sif clif-custom.def    # may need --fakeroot
```

> Building requires `fakeroot` capability (most modern clusters have it) or root on another machine. Build elsewhere and copy the `.sif` to the cluster if needed.

## CLIF Consortium HPC Resources

Many CLIF sites run workloads on institutional HPC clusters. The table below links to each site's container documentation to help you get started.

| Institution | HPC Cluster | Apptainer / Singularity Docs |
|-------------|-------------|------------------------------|
| Cornell | CAC | [CAC Homepage](https://www.cac.cornell.edu/) |
| Harvard | FASRC / Cannon | [Singularity on the Cluster](https://docs.rc.fas.harvard.edu/kb/singularity-on-the-cluster/) |
| Johns Hopkins | ARCH / Rockfish | [Singularity Tutorial](https://docs.arch.jhu.edu/en/latest/3_Tutorials/containers/Tutorial_Singularity.html) |
| Northwestern | Quest | [Singularity on Quest](https://rcdsdocs.it.northwestern.edu/tutorials/software-management/singularity/singularity-quest.html) |
| U Chicago | RCC / Midway | [Singularity](https://docs.rcc.uchicago.edu/software/apps-and-envs/singularity/) |
| U Colorado | CURC / Alpine | [Containerization](https://curc.readthedocs.io/en/latest/software/containerization.html) |
| U Michigan | ARC / Great Lakes | [Containers](https://documentation.its.umich.edu/arc-software/containers) |
| U Minnesota | MSI | [Singularity FAQ](https://msi.umn.edu/support/faq/how-do-i-use-singularity-centos-7) |
| U Penn | PMACS | [HPC: Singularity](https://hpcwiki.pmacs.upenn.edu/wiki/index.php/HPC:Singularity) |
| U Toronto | SciNet / Alliance Canada | [Apptainer](https://docs.alliancecan.ca/wiki/Apptainer) |
| UCSF | Wynton | [Apptainer](https://wynton.ucsf.edu/hpc/software/apptainer.html) |
| Yale | YCRC | [Containers](https://docs.ycrc.yale.edu/clusters-at-yale/guides/containers/) |

> If your site is not listed or a link is outdated, please open an issue or PR on the [CLIF-WorkBench repository](https://github.com/Common-Longitudinal-ICU-data-Format/CLIF-WorkBench).

## Troubleshooting

### Cache directory fills up

Singularity caches Docker layers in `~/.singularity/cache` (or `~/.apptainer/cache`). On quota-limited home directories this can fail during pull.

```bash
export SINGULARITY_CACHEDIR=/scratch/$USER/.singularity/cache
singularity pull clif-ml.sif docker://clifconsortium/clif-workbench:ml
singularity cache clean
```

### "No space left on device" during pull

The pull writes temp files to `TMPDIR` (default `/tmp`), which may be small on login nodes.

```bash
export SINGULARITY_TMPDIR=/scratch/$USER/tmp
mkdir -p $SINGULARITY_TMPDIR
```

### CUDA version mismatch

```
CUDA driver version is insufficient for CUDA runtime version
```

The `:ai` image has CUDA 12.8. The host driver must be **>= 525**. Check with `nvidia-smi` on a compute node (top line shows driver version). If the driver is too old, contact your HPC admin — you cannot update it yourself.

### `fakeroot` errors when building from a `.def` file

Some clusters don't enable fakeroot by default. Ask your admin to run:

```bash
singularity config fakeroot --add $USER
```

Or build on a different machine (laptop, cloud VM) and copy the `.sif` to the cluster.

### Python packages from `~/.local` shadow container packages

Symptom: `import torch` loads a CPU-only torch from your home directory instead of the GPU-enabled one in the container.

```bash
# Add to the top of your run.sh:
export PYTHONNOUSERSITE=1

# Or run with --no-home:
singularity exec --no-home --bind /path/to/data:/data clif-ai.sif ...
```

### Container sees wrong Python or packages

If the cluster has a conda environment or modules loaded, they can leak into the container via `$PATH`.

```bash
# Option A: purge modules before running
module purge
singularity exec ...

# Option B: clean environment (re-pass any SLURM vars you need)
singularity exec --cleanenv \
  --env SLURM_JOB_ID=$SLURM_JOB_ID \
  --env SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID \
  clif-ml.sif bash /project/run.sh
```

### "Permission denied" on bound directories

Singularity runs as your user, not root. You need read access to bound directories:

```bash
ls -la /path/to/clif_data    # need at least r-x on dirs, r-- on files
```

## Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `SINGULARITY_CACHEDIR` | Layer cache location during pull | `/scratch/$USER/.singularity/cache` |
| `SINGULARITY_TMPDIR` | Temp space during build/pull | `/scratch/$USER/tmp` |
| `SINGULARITY_BIND` | Default bind mounts (skip `--bind` flags) | `/data/clif:/data,/home/$USER/project:/project` |
| `SINGULARITY_NO_HOME` | Prevent home dir mount (set to `1`) | `1` |
| `PYTHONNOUSERSITE` | Prevent `~/.local` packages from loading | `1` |

> For Apptainer, replace the `SINGULARITY_` prefix with `APPTAINER_` (e.g., `APPTAINER_CACHEDIR`).
