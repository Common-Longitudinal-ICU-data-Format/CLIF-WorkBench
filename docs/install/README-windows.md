# Install on Windows

**Default path: WSL2 + Apptainer inside WSL.** This matches how the images
run on HPC — same commands, same `.sif` files, same behavior. Use this path
if there's any chance you'll later submit these workloads to an institutional
HPC cluster.

Docker Desktop is the fallback if WSL is not allowed on your machine or if
you only need local, Docker-style use.

---

## 1. Check what you have

Open **PowerShell** (Start menu → type `PowerShell`) and run:

```powershell
powershell -ExecutionPolicy Bypass -File docs\smoke-test\check-container-readiness.ps1
```

The script tells you whether WSL is installed, whether Apptainer is inside
it, and the exact next command to run.

---

## 2. Enable WSL2 (one-time, needs admin)

Skip this step if the smoke test already reports "WSL installed".

Open PowerShell **as Administrator** (right-click → *Run as administrator*)
and run:

```powershell
wsl --install
```

This:
- Enables the Windows Subsystem for Linux feature
- Installs WSL2 (the fast, VM-based version)
- Installs Ubuntu as the default Linux distribution
- Requires **one reboot** when it finishes

If you don't have admin rights on your Windows account, send this block to
your IT admin — enabling WSL is a one-time change and doesn't affect anything
else on the machine.

After reboot, Ubuntu launches automatically and asks you to create a Linux
username + password. You'll use this whenever you type `wsl` from PowerShell.

---

## 3. Install Apptainer inside WSL (no Windows admin needed)

From PowerShell:

```powershell
wsl
```

You're now in the Ubuntu shell inside WSL. Run (you will need the Linux
password you set in step 2 — that's *sudo inside WSL*, not Windows admin):

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:apptainer/ppa
sudo apt-get update
sudo apt-get install -y apptainer
apptainer --version
```

**Or** if for any reason the PPA install fails, use the no-sudo fallback
installer from this repo:

```bash
cd /mnt/c/path/to/CLIF-WorkBench     # adjust to where you cloned it
bash docs/install/install-apptainer.sh
echo 'export PATH=$HOME/.local/apptainer/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

## 4. Pull a CLIF image

Inside WSL:

```bash
apptainer pull clif-ml.sif docker://clifconsortium/clif-workbench:ml
apptainer pull clif-ai.sif docker://clifconsortium/clif-workbench:ai
```

Your Windows drives are mounted inside WSL at `/mnt/c`, `/mnt/d`, etc., so
files on your Windows desktop are directly reachable:

```bash
apptainer exec \
  --bind /mnt/c/Users/you/clif_data:/data \
  --bind /mnt/c/Users/you/my-project:/project \
  clif-ml.sif bash /project/run.sh
```

## 5. Daily use

From PowerShell, either:

```powershell
wsl                                  # drops you into the Linux shell
```

or run a one-off Apptainer command from PowerShell:

```powershell
wsl -- apptainer pull clif-ml.sif docker://clifconsortium/clif-workbench:ml
```

---

## Alternative: Docker Desktop (simpler, Windows-only)

If WSL isn't an option, Docker Desktop is the fallback. It needs admin once
to install, then runs as a normal app.

1. Download **Docker Desktop for Windows** from
   <https://www.docker.com/products/docker-desktop/>
2. Run the installer (requires admin). Accept defaults.
3. Reboot, launch Docker Desktop, wait for the whale icon in the system tray
   to go steady.

Pull a CLIF image from PowerShell:

```powershell
docker pull clifconsortium/clif-workbench:ml
docker run --rm -v C:\Users\you\clif_data:/data `
                -v C:\Users\you\my-project:/project `
                clifconsortium/clif-workbench:ml bash /project/run.sh
```

---

## Troubleshooting

**"Virtualization is disabled" during `wsl --install`**  
Enable VT-x (Intel) or AMD-V in your computer's BIOS/UEFI. This is a one-time
firmware change — on most machines, press F2 / Del / F10 during boot to enter
setup, find *CPU / Advanced / Virtualization*, set it to Enabled, save, reboot.
On corporate machines you may need IT to do this.

**`wsl` hangs or "Element not found"**  
Update the WSL kernel: from an admin PowerShell, `wsl --update`, then `wsl --shutdown`, then open `wsl` again.

**Apptainer pull is very slow / fills up C: drive**  
Move the WSL cache to a bigger drive:

```bash
# inside WSL:
export APPTAINER_CACHEDIR=/mnt/d/apptainer-cache
export APPTAINER_TMPDIR=/mnt/d/tmp
mkdir -p $APPTAINER_CACHEDIR $APPTAINER_TMPDIR
```

For full container usage, see [`docs/apptainer-guide.md`](../apptainer-guide.md).
