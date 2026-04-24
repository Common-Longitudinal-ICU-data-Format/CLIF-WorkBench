# Install on macOS

**Default path: Apptainer inside a lightweight Linux VM via Lima.** This
matches exactly how the images run on HPC, so your local workflow and your
cluster workflow stay identical. No admin password once Homebrew is set up.

Docker Desktop is the simpler alternative if you only care about local use
and will never submit to HPC.

---

## 1. Check what you have

```bash
bash docs/smoke-test/check-container-readiness.sh
```

If Docker Desktop is already installed and you don't plan to use HPC, you can
stop there — skip to "Pull a CLIF image with Docker" below.

## 2. Install Apptainer (via Lima) — recommended

Lima is a tiny Linux VM manager for macOS. We use a pre-made Lima template
that boots an Ubuntu VM with Apptainer already installed.

### Prerequisites

[Homebrew](https://brew.sh/). If you don't have it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

(Homebrew installs into `/opt/homebrew` on Apple Silicon or `/usr/local` on
Intel. It will ask for your user password once; you do **not** need to be a
full admin — a standard macOS account is fine.)

### Install Lima + start the Apptainer VM

```bash
brew install lima

# Start a VM called "apptainer" using the upstream template.
# On Apple Silicon, force x86_64 so it matches the clifconsortium images.
limactl start --name=apptainer --arch=x86_64 template://apptainer

# Enter the VM — you land in a shell where 'apptainer' is on PATH.
limactl shell apptainer
```

Verify inside the VM:

```bash
apptainer --version
```

### Pull a CLIF image (inside the VM)

```bash
apptainer pull clif-ml.sif docker://clifconsortium/clif-workbench:ml
```

Your Mac's home folder is auto-mounted inside the VM at the same path, so
data on your Mac is directly reachable:

```bash
apptainer exec \
  --bind $HOME/clif_data:/data \
  --bind $HOME/my-project:/project \
  clif-ml.sif bash /project/run.sh
```

### Daily use

```bash
limactl start apptainer      # boot the VM (fast after first time)
limactl shell apptainer      # open a shell inside
limactl stop apptainer       # shut it down when done
```

---

## Alternative: Docker Desktop (simpler, Mac-only)

If you don't need HPC parity, Docker Desktop is the shortest path:

1. Download **Docker Desktop for Mac** from
   <https://www.docker.com/products/docker-desktop/>
2. Install the `.dmg` (drag-and-drop). Standard macOS account works — the
   first launch asks for your user password to install a helper tool.
3. Launch Docker Desktop and wait for the whale icon to go steady in the menu bar.

Pull a CLIF image:

```bash
docker pull clifconsortium/clif-workbench:ml
```

**Apple Silicon note:** `clifconsortium/*` images are x86_64. Docker Desktop
emulates x86_64 automatically (via Rosetta). It works but is slower than on
Intel Macs — this is a good reason to use the Lima path above for anything
heavy.

---

## Troubleshooting

**`limactl start` fails with "qemu" or "vz" errors on Apple Silicon**  
Try the Virtualization.framework driver (faster than QEMU):

```bash
limactl start --name=apptainer --arch=x86_64 --vm-type=vz template://apptainer
```

**Docker Desktop hangs on first launch**  
Reset it from *Settings → Troubleshoot → Reset to factory defaults*, then
launch again.

**Want to move the Lima disk off your home volume?**  
Set `LIMA_HOME=/Volumes/Something/lima` before `limactl start`.

For full container usage, see [`docs/apptainer-guide.md`](../apptainer-guide.md).
