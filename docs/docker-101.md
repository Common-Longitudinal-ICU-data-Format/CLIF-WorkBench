# Docker 101 for CLIF Sites

A beginner-friendly guide to running CLIF projects using Docker and Singularity/Apptainer.

---

## Table of Contents

- [What is Docker?](#what-is-docker)
- [Key Terminology](#key-terminology)
- [How CLIF-WorkBench Uses Docker](#how-clif-workbench-uses-docker)
- [Installing Docker](#installing-docker)
- [Pulling CLIF Images](#pulling-clif-images)
- [Running CLIF Projects](#running-clif-projects)
- [Mounting Data and Code](#mounting-data-and-code)
- [Extra Packages at Runtime](#extra-packages-at-runtime)
- [Common Commands Cheat Sheet](#common-commands-cheat-sheet)
- [Singularity / Apptainer for HPC](#singularity--apptainer-for-hpc)
- [Troubleshooting](#troubleshooting)

---

## What is Docker?

Imagine you order a meal kit. The box arrives with every ingredient pre-measured, every tool included, and step-by-step instructions. It doesn't matter what kitchen you have — the result is the same every time.

**Docker is that meal kit for software.**

```
  YOUR COMPUTER (the "Host")
  ┌─────────────────────────────────────────────────────┐
  │                                                     │
  │   Your files, your OS, your setup                   │
  │                                                     │
  │   ┌───────────────────────────────────────────┐     │
  │   │         DOCKER CONTAINER                  │     │
  │   │  ┌─────────────────────────────────────┐  │     │
  │   │  │  Python 3.12                        │  │     │
  │   │  │  clifpy, pandas, scikit-learn ...   │  │     │
  │   │  │  Everything pre-installed           │  │     │
  │   │  │  Same on every computer             │  │     │
  │   │  └─────────────────────────────────────┘  │     │
  │   │                                           │     │
  │   │   /data    ← your CLIF data (mounted)     │     │
  │   │   /project ← your project code (mounted)  │     │
  │   └───────────────────────────────────────────┘     │
  │                                                     │
  └─────────────────────────────────────────────────────┘
```

**Why this matters for CLIF:**
Every CLIF consortium site has different computers, operating systems, and Python versions. Instead of each site spending hours installing packages and debugging, everyone pulls the same Docker image and gets an identical environment in minutes.

---

## Key Terminology

```
  ┌──────────────┐     docker build      ┌──────────────┐
  │              │    ──────────────►     │              │
  │  Dockerfile  │     (recipe book)     │    Image     │
  │  (recipe)    │                       │   (cake)     │
  │              │                       │              │
  └──────────────┘                       └──────┬───────┘
                                                │
                                          docker run
                                                │
                                                ▼
                                         ┌──────────────┐
                                         │              │
                                         │  Container   │
                                         │ (slice of    │
                                         │  cake you    │
                                         │  can eat)    │
                                         └──────────────┘
```

| Term | What it is | Analogy |
|------|-----------|---------|
| **Dockerfile** | A text file with instructions to build an image | A recipe |
| **Image** | A snapshot of an environment (Python, packages, tools) | A cake made from the recipe |
| **Container** | A running instance of an image | A slice of cake you're eating right now |
| **Host** | Your actual computer running Docker | Your kitchen |
| **Mount / Volume** | A shared folder between your computer and the container | A window between two rooms |
| **Tag** | A version label on an image (e.g., `:ml`, `:ai`) | A sticker on the cake box |

> **You don't need to build images.** The CLIF-WorkBench images are pre-built and published to Docker Hub. You just **pull** (download) and **run**.

---

## How CLIF-WorkBench Uses Docker

CLIF-WorkBench provides two pre-built images. Think of them as two different toolboxes:

```
  ┌─────────────────────────────────┐
  │      clif-workbench:ml          │
  │  ┌───────────────────────────┐  │
  │  │  Python 3.12 + uv         │  │
  │  │  clifpy, pandas, polars   │  │
  │  │  duckdb, scikit-learn     │  │
  │  │  statsmodels, matplotlib  │  │
  │  │  streamlit, plotly ...    │  │
  │  └───────────────────────────┘  │
  │  Size: ~700-900 MB              │
  │  For: Most CLIF projects        │
  └─────────────────────────────────┘

  ┌─────────────────────────────────┐
  │      clif-workbench:ai          │
  │  ┌───────────────────────────┐  │
  │  │  Everything in :ml PLUS   │  │
  │  │  CUDA 12.8 (GPU support)  │  │
  │  │  PyTorch, transformers    │  │
  │  │  deepspeed, accelerate    │  │
  │  │  xgboost, optuna, wandb   │  │
  │  └───────────────────────────┘  │
  │  Size: ~8-10 GB                 │
  │  For: CLIFATRON, CLIF-RL        │
  └─────────────────────────────────┘
```

**The images are stateless** — they contain only the software environment. Your data and project code live on your computer and are "mounted" into the container when you run it:

```
  Your Computer                         Docker Container
  ┌──────────────┐                      ┌──────────────┐
  │              │     mount            │              │
  │  /clif_data/ │ ──────────────────►  │  /data/      │
  │  (parquets)  │                      │              │
  │              │                      │              │
  │  /CLIF-C2D2/ │ ──────────────────►  │  /project/   │
  │  (code)      │     mount            │              │
  └──────────────┘                      └──────────────┘

  Nothing is copied. The container sees your files
  directly through the mount. Changes go both ways.
```

---

## Installing Docker

### Step 1: Determine your processor

| OS | How to check | What to download |
|----|-------------|-----------------|
| **macOS** | Apple menu → About This Mac. Processor says "Intel" or starts with "M" (M1, M2, M3...) | Intel → "Mac with Intel chip". M-series → "Mac with Apple Silicon" |
| **Windows** | Right-click "This PC" → Properties. Check processor name | ARM → "Windows ARM64". Otherwise → "Windows AMD64" |
| **Linux** | Run `uname -m` in terminal | `x86_64` = AMD64. `aarch64` = ARM64 |

### Step 2: Install Docker Desktop

Download from [docker.com/get-started](https://www.docker.com/get-started/) and run the installer.

```
  ⚠️  You need admin / sudo privileges to INSTALL Docker.
      After installation, you do NOT need admin to USE it.

  ⚠️  Windows users: the installer may prompt you to update WSL
      (Windows Subsystem for Linux). Allow this — it requires admin.
```

### Step 3: Verify the installation

Open a terminal (PowerShell on Windows, Terminal on macOS/Linux) and run:

```bash
docker --version
```

You should see something like:

```
Docker version 29.x.x, build xxxxxxx
```

If you get "command not found", make sure Docker Desktop is running (look for the whale icon in your taskbar/menu bar).

---

## Pulling CLIF Images

"Pulling" means downloading the image from Docker Hub to your computer. You only need to do this once (or when you want to update).

```bash
# For most projects (classical ML, ETL, analysis)
docker pull clifconsortium/clif-workbench:ml

# For deep learning projects (CLIFATRON, CLIF-RL)
docker pull clifconsortium/clif-workbench:ai
```

Verify the download:

```bash
docker image ls
```

You should see:

```
REPOSITORY                        TAG     SIZE
clifconsortium/clif-workbench     ml      ~900MB
clifconsortium/clif-workbench     ai      ~10GB
```

---

## Running CLIF Projects

### The basic pattern

Every CLIF project run follows the same pattern:

```
docker run --rm -v YOUR_DATA:/data -v YOUR_PROJECT:/project IMAGE COMMAND
```

Let's break that down:

```
  docker run                               ← "start a container"
    --rm                                   ← "delete the container when done"
    -v /path/to/clif_data:/data            ← "mount my data folder"
    -v /path/to/CLIF-C2D2:/project         ← "mount my project code"
    clifconsortium/clif-workbench:ml       ← "use this image"
    bash /project/run.sh                   ← "run this command inside"
```

```
  ┌─────────────── What each flag does ──────────────────┐
  │                                                      │
  │  --rm         Clean up after yourself. Without       │
  │               this, stopped containers pile up       │
  │               like dirty dishes.                     │
  │                                                      │
  │  -v A:B       "Volume mount". Makes folder A on      │
  │               your computer appear as folder B       │
  │               inside the container.                  │
  │                                                      │
  │  -it          "Interactive terminal". Use this       │
  │               when you want to type commands         │
  │               inside the container (debugging).      │
  │                                                      │
  │  --gpus all   Give the container access to your      │
  │               GPU(s). Only needed for :ai image.     │
  │                                                      │
  └──────────────────────────────────────────────────────┘
```

### Example: Running CLIF-C2D2

```bash
docker run --rm \
  -v /home/scientist/clif_data:/data \
  -v /home/scientist/CLIF-C2D2:/project \
  clifconsortium/clif-workbench:ml \
  bash /project/run.sh
```

### Example: Running a single Python file

```bash
docker run --rm \
  -v /home/scientist/clif_data:/data \
  -v /home/scientist/clif_niv_rojas:/project \
  clifconsortium/clif-workbench:ml \
  python /project/analysis.py
```

### Example: GPU workload (CLIFATRON)

```bash
docker run --rm --gpus all \
  -v /home/scientist/clif_data:/data \
  -v /home/scientist/CLIFATRON:/project \
  clifconsortium/clif-workbench:ai \
  bash /project/run.sh
```

### Example: Interactive debugging

```bash
docker run -it --rm \
  -v /home/scientist/clif_data:/data \
  -v /home/scientist/CLIF-C2D2:/project \
  clifconsortium/clif-workbench:ml \
  bash
```

You'll see the prompt change to `[clif-ml] /project $` — you're now inside the container. Type `exit` or press `Ctrl-D` to leave.

---

## Mounting Data and Code

Mounts are the bridge between your computer and the container. Here's how paths work on each OS:

### macOS / Linux

```bash
-v /home/scientist/clif_data:/data
-v /home/scientist/CLIF-C2D2:/project
```

### Windows (PowerShell)

```powershell
-v C:\Users\scientist\Documents\clif_data:/data
-v C:\Users\scientist\Documents\CLIF-C2D2:/project
```

### Windows (Git Bash / WSL)

```bash
-v //c/Users/scientist/Documents/clif_data:/data
-v //c/Users/scientist/Documents/CLIF-C2D2:/project
```

```
  ┌──────────── How mounts work ─────────────────┐
  │                                               │
  │  Host path         Container path             │
  │  (your computer)   (inside Docker)            │
  │                                               │
  │  /clif_data/    →  /data/                     │
  │    patient.parquet    patient.parquet          │
  │    vitals.parquet     vitals.parquet           │
  │    labs.parquet       labs.parquet             │
  │                                               │
  │  /CLIF-C2D2/    →  /project/                  │
  │    run.sh             run.sh                   │
  │    main.py            main.py                  │
  │    config.yaml        config.yaml              │
  │                                               │
  │  Changes are shared instantly both ways.       │
  │  Output files written to /data/ appear on      │
  │  your computer in /clif_data/.                 │
  └───────────────────────────────────────────────┘
```

> **Important**: If your project writes output files, make sure it writes them to `/data/` (or a subfolder). Anything written elsewhere inside the container is **lost** when the container stops (because of `--rm`).

---

## Extra Packages at Runtime

If your project needs a Python package that's not in the image, add it to the top of your `run.sh`:

```bash
#!/bin/bash
# Install extra packages (takes ~2-5 seconds with uv)
uv pip install --system firthlogist

# Then run your code
python /project/analysis.py
python /project/report.py
```

For faster repeat runs, mount a **uv cache volume** so packages are downloaded only once:

```bash
docker run --rm \
  -v /home/scientist/clif_data:/data \
  -v /home/scientist/my-project:/project \
  -v /home/scientist/uv_cache:/root/.cache/uv \
  clifconsortium/clif-workbench:ml \
  bash /project/run.sh
```

```
  ┌────────── Without cache mount ──────────┐
  │                                         │
  │  Run 1:  uv pip install firthlogist     │
  │          ↓ downloads from internet      │
  │          ✓ installed (5 sec)            │
  │                                         │
  │  Run 2:  uv pip install firthlogist     │
  │          ↓ downloads AGAIN              │
  │          ✓ installed (5 sec)            │
  └─────────────────────────────────────────┘

  ┌─────────── With cache mount ────────────┐
  │                                         │
  │  Run 1:  uv pip install firthlogist     │
  │          ↓ downloads from internet      │
  │          ✓ installed (5 sec)            │
  │          cache saved to host            │
  │                                         │
  │  Run 2:  uv pip install firthlogist     │
  │          ↓ found in cache!              │
  │          ✓ installed (instant)          │
  └─────────────────────────────────────────┘
```

---

## Common Commands Cheat Sheet

```
  ┌────────────────────────────────────────────────────────────────┐
  │  COMMAND                              │  WHAT IT DOES          │
  ├────────────────────────────────────────┼────────────────────────┤
  │  docker pull IMAGE:TAG                │  Download an image     │
  │  docker image ls                      │  List downloaded images│
  │  docker run --rm IMAGE CMD            │  Run and auto-cleanup  │
  │  docker run -it --rm IMAGE bash       │  Interactive shell     │
  │  docker ps                            │  List running          │
  │                                       │  containers            │
  │  docker stop CONTAINER_ID             │  Stop a container      │
  │  docker system prune                  │  Clean up unused       │
  │                                       │  images/containers     │
  │  exit  (or Ctrl-D)                    │  Leave interactive     │
  │                                       │  container             │
  └────────────────────────────────────────┴────────────────────────┘
```

---

## Singularity / Apptainer for HPC

Many hospital and university HPC (High Performance Computing) clusters **do not allow Docker** because Docker requires root privileges, which is a security concern on shared systems.

**Singularity** (and its community fork **Apptainer**) solve this — they run containers **without root** and are the standard on HPC clusters.

> Apptainer is the newer name for Singularity. The commands are identical —
> just replace `singularity` with `apptainer` if your cluster uses Apptainer.

```
  ┌─────────── Docker vs Singularity ────────────┐
  │                                               │
  │  Docker                 Singularity           │
  │  ──────                 ───────────           │
  │  Needs root to run      Runs as normal user   │
  │  Uses layered images    Uses single .sif file │
  │  -v for mounts          --bind for mounts     │
  │  --gpus all for GPU     --nv for GPU          │
  │  Common on laptops,     Common on HPC         │
  │  cloud, servers         clusters              │
  │                                               │
  │  Same images work with both!                  │
  │  Singularity can pull directly from           │
  │  Docker Hub.                                  │
  └───────────────────────────────────────────────┘
```

### Installing Singularity / Apptainer

Check if it's already installed (most HPC clusters have it):

```bash
singularity --version
# or
apptainer --version
```

If not installed, ask your HPC admin, or install yourself:

**Ubuntu / Debian:**

```bash
# Apptainer (recommended — actively maintained)
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:apptainer/ppa
sudo apt update
sudo apt install -y apptainer
```

**CentOS / RHEL / Rocky:**

```bash
# Apptainer via EPEL
sudo dnf install -y epel-release
sudo dnf install -y apptainer
```

**From source** (if you don't have admin — installs to your home directory):

See the [Apptainer installation guide](https://apptainer.org/docs/admin/main/installation.html).

> **macOS / Windows**: Singularity/Apptainer only runs natively on Linux.
> If you're on macOS or Windows, use Docker instead.

### Pulling CLIF Images

Singularity pulls Docker Hub images and converts them to a single `.sif` file:

```bash
# Pull once — creates a portable .sif file
singularity pull clif-ml.sif docker://clifconsortium/clif-workbench:ml
singularity pull clif-ai.sif docker://clifconsortium/clif-workbench:ai
```

```
  ┌────────── What happens when you pull ──────────┐
  │                                                 │
  │  Docker Hub                    Your cluster     │
  │  ┌────────────┐               ┌──────────────┐ │
  │  │ clif-      │  singularity  │              │ │
  │  │ workbench  │ ────pull────► │ clif-ml.sif  │ │
  │  │ :ml        │               │ (single file)│ │
  │  └────────────┘               └──────────────┘ │
  │                                                 │
  │  The .sif file is portable — you can copy it    │
  │  to any machine, USB drive, or shared folder.   │
  └─────────────────────────────────────────────────┘
```

> **Tip**: The `.sif` file can be large (~1GB for ML, ~10GB for AI). Pull it once to a shared location on your cluster (e.g., `/shared/containers/`) so other users don't need to re-download.

### Running CLIF Projects with Singularity

The pattern is almost the same as Docker, just different flag names:

```
  Docker flag         Singularity equivalent
  ───────────         ──────────────────────
  docker run          singularity exec
  -v A:B              --bind A:B
  --gpus all          --nv
  --rm                (not needed — Singularity is stateless by default)
```

**CPU workload:**

```bash
singularity exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/CLIF-C2D2:/project \
  clif-ml.sif \
  bash /project/run.sh
```

**GPU workload:**

```bash
singularity exec --nv \
  --bind /path/to/clif_data:/data \
  --bind /path/to/CLIFATRON:/project \
  clif-ai.sif \
  bash /project/run.sh
```

**Interactive shell:**

```bash
singularity shell \
  --bind /path/to/clif_data:/data \
  clif-ml.sif
```

**Single Python file:**

```bash
singularity exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/my-project:/project \
  clif-ml.sif \
  python /project/analysis.py
```

### Singularity on HPC with SLURM

If your cluster uses SLURM for job scheduling, here's an example job script:

```bash
#!/bin/bash
#SBATCH --job-name=clif-analysis
#SBATCH --output=clif-%j.out
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00

# For GPU jobs, add:
# #SBATCH --gres=gpu:1
# #SBATCH --partition=gpu

singularity exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/my-project:/project \
  /shared/containers/clif-ml.sif \
  bash /project/run.sh
```

Submit with:

```bash
sbatch my_job.sh
```

### Singularity Cheat Sheet

```
  ┌────────────────────────────────────────────────────────────────┐
  │  COMMAND                              │  WHAT IT DOES          │
  ├────────────────────────────────────────┼────────────────────────┤
  │  singularity pull X.sif docker://IMG  │  Download image from   │
  │                                       │  Docker Hub            │
  │  singularity exec X.sif CMD           │  Run a command         │
  │  singularity shell X.sif              │  Interactive shell     │
  │  singularity exec --nv X.sif CMD      │  Run with GPU access   │
  │  singularity inspect X.sif            │  Show image metadata   │
  │  singularity cache clean              │  Free up disk space    │
  └────────────────────────────────────────┴────────────────────────┘
```

---

## Troubleshooting

### "command not found: docker"

Docker Desktop is not running, or not installed. Launch Docker Desktop and try again.

### "permission denied" on Linux

Add your user to the `docker` group:

```bash
sudo usermod -aG docker $USER
```

Then **log out and log back in** for the change to take effect.

### "no matching manifest for linux/arm64"

The image was built for a different processor architecture. This can happen on Apple Silicon Macs. Try adding:

```bash
docker run --platform linux/amd64 ...
```

### Container can't see my files

Make sure the `-v` (Docker) or `--bind` (Singularity) path is correct and the folder exists on your computer. Paths are case-sensitive on Linux/macOS.

### Output files disappear after the container stops

Write output to a mounted folder (`/data/`). Anything written to non-mounted paths inside the container is lost when it stops.

### "CUDA not available" in the AI image

- Make sure you're using `--gpus all` (Docker) or `--nv` (Singularity)
- Verify your host has NVIDIA drivers installed: `nvidia-smi`
- The host driver must support CUDA 12.8+ (driver version >= 555)
