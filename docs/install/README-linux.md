# Install on Linux / HPC

**Default path: Apptainer (no admin needed).** Apptainer is the right choice
for university HPC and institutional Linux machines. It runs as your normal
user, needs no daemon, and produces a single portable `.sif` file.

Docker is only for sites that already have it installed. Installing Docker
always requires admin.

---

## 1. Check what you have first

```bash
bash docs/smoke-test/check-container-readiness.sh
```

The script looks at your machine and prints the exact next command to run.
If it says "Apptainer is ready" or "available via `module load apptainer`",
you're done — skip to "Pull a CLIF image" below.

## 2. Install Apptainer (no admin)

Most HPC clusters already have it. If the smoke test says it's missing,
install it into your home directory:

```bash
bash docs/install/install-apptainer.sh
```

What this does:
- Downloads the official Apptainer release (~30 MB)
- Extracts it to `~/.local/apptainer/` — **does not touch system files**
- Prints one `export PATH=...` line to add to your `~/.bashrc`

Requirements — already satisfied on any modern Linux:
- `curl` (for downloading)
- Kernel user namespaces enabled — the script checks this and tells you what to ask IT if not

After install, make it permanent:

```bash
echo 'export PATH=$HOME/.local/apptainer/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
apptainer --version
```

## 3. Pull a CLIF image

```bash
apptainer pull clif-ml.sif  docker://clifconsortium/clif-workbench:ml
apptainer pull clif-ai.sif  docker://clifconsortium/clif-workbench:ai   # GPU/PyTorch (~10 GB)
```

**HPC tip — redirect cache off your quota-limited home:**

```bash
export APPTAINER_CACHEDIR=/scratch/$USER/.apptainer/cache
export APPTAINER_TMPDIR=/scratch/$USER/tmp
mkdir -p $APPTAINER_CACHEDIR $APPTAINER_TMPDIR
```

## 4. Run something

```bash
apptainer exec \
  --bind /path/to/clif_data:/data \
  --bind /path/to/your-project:/project \
  clif-ml.sif \
  bash /project/run.sh
```

For full usage (GPU, SLURM jobs, overlays, offline install, troubleshooting),
see [`docs/apptainer-guide.md`](../apptainer-guide.md).

---

## Optional: Docker (requires admin)

Only do this if your institution expects Docker instead of Apptainer.
Every command below needs `sudo`; hand the whole block to IT if you
don't have it.

### Ubuntu / Debian

```bash
# 1. Add Docker's package repository
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 2. Install Docker Engine
sudo apt-get update
sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# 3. Let your user run docker without sudo (optional but recommended)
sudo usermod -aG docker $USER
newgrp docker     # or log out and back in
docker run --rm hello-world
```

### RHEL / Rocky / Alma

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
docker run --rm hello-world
```

After Docker is working, pull a CLIF image:

```bash
docker pull clifconsortium/clif-workbench:ml
```

---

## Troubleshooting

**"user namespaces disabled" when running the installer**  
Your kernel has unprivileged user namespaces turned off. Ask your admin to run:

```bash
sudo sysctl -w kernel.unprivileged_userns_clone=1
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/90-apptainer.conf
```

**"No space left on device" during pull**  
Your `$HOME` or `/tmp` is full. Redirect the cache (see "HPC tip" above).

**"dpkg-deb: command not found" on a non-Debian distro**  
The installer falls back to `ar` (part of `binutils`) — if neither is present,
install `binutils` via your package manager, or ask your admin to install
Apptainer system-wide from [apptainer.org](https://apptainer.org).
