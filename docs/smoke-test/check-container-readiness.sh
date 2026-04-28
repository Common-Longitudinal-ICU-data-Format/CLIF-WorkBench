#!/usr/bin/env bash
# CLIF-WorkBench container readiness check (Linux / macOS).
# Read-only: detects environment and prints commands you can run.
# Assumes you do NOT have admin/sudo — user-space options come first.

set -u

if [ -t 1 ]; then
  B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'
else
  B=""; G=""; Y=""; R=""; D=""; N=""
fi

echo "${B}=== CLIF-WorkBench Container Readiness ===${N}"
echo

# ---------- environment ----------
KERNEL=$(uname -s)
ARCH=$(uname -m)
IS_MAC=0; IS_WSL=0
if [ "$KERNEL" = "Darwin" ]; then
  OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
  IS_MAC=1
elif [ -r /etc/os-release ]; then
  . /etc/os-release
  OS_NAME="${NAME:-Linux} ${VERSION_ID:-}"
  grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1
else
  OS_NAME="$KERNEL"
fi

if [ "$(id -u)" = 0 ]; then PRIV="root"
elif sudo -n true 2>/dev/null;   then PRIV="passwordless sudo"
else PRIV="standard user (no sudo)"
fi

echo "${B}Environment:${N}"
echo "  OS:     $OS_NAME ($ARCH)"
[ "$IS_WSL" = 1 ] && echo "  WSL:    yes"
echo "  User:   $(id -un) — $PRIV"
echo "  Shell:  ${SHELL:-unknown}"
echo

# ---------- Apptainer (primary) ----------
APP_CMD=""; APP_VER=""
if command -v apptainer >/dev/null 2>&1; then
  APP_CMD="apptainer"; APP_VER=$(apptainer --version 2>/dev/null)
elif command -v singularity >/dev/null 2>&1; then
  APP_CMD="singularity"; APP_VER=$(singularity --version 2>/dev/null)
fi

MODULE_AVAIL=0
if [ -z "$APP_CMD" ] && command -v module >/dev/null 2>&1; then
  if module avail apptainer 2>&1 | grep -qi apptainer; then MODULE_AVAIL=1
  elif module avail singularity 2>&1 | grep -qi singularity; then MODULE_AVAIL=1
  fi
fi

CVMFS_BIN=/cvmfs/oasis.opensciencegrid.org/mis/apptainer/bin/apptainer
CVMFS_AVAIL=0
[ -x "$CVMFS_BIN" ] && CVMFS_AVAIL=1

USERNS_OK=0
if [ "$IS_MAC" = 0 ]; then
  [ "$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo 0)" = "1" ] && USERNS_OK=1
  MNS=$(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo 0)
  [ "$MNS" -gt 0 ] 2>/dev/null && USERNS_OK=1
fi

# macOS-specific: Apptainer ships inside a Lima VM (template://apptainer).
# Detect Lima itself, the state of an "apptainer" VM if one exists, and
# Homebrew (the standard installer for Lima on macOS).
LIMA_CMD=""; LIMA_VER=""; LIMA_APPT_STATE=""; BREW_CMD=""
if [ "$IS_MAC" = 1 ]; then
  if command -v limactl >/dev/null 2>&1; then
    LIMA_CMD="limactl"
    LIMA_VER=$(limactl --version 2>/dev/null | head -n1)
    LIMA_APPT_STATE=$(limactl list --format '{{.Name}} {{.Status}}' 2>/dev/null \
      | awk '$1=="apptainer"{print $2; exit}')
  fi
  command -v brew >/dev/null 2>&1 && BREW_CMD="brew"
fi

echo "${B}Apptainer (primary):${N}"
if [ -n "$APP_CMD" ]; then
  echo "  ${G}[OK]${N} $APP_CMD installed — $APP_VER"
else
  echo "  ${R}[--]${N} not installed"
  [ "$MODULE_AVAIL" = 1 ] && echo "  ${G}[OK]${N} available via: module load apptainer"
  [ "$CVMFS_AVAIL"  = 1 ] && echo "  ${G}[OK]${N} available via CVMFS: $CVMFS_BIN"
  if [ "$IS_MAC" = 1 ]; then
    if [ -n "$LIMA_CMD" ]; then
      echo "  ${G}[OK]${N} Lima installed — $LIMA_VER"
      case "$LIMA_APPT_STATE" in
        Running)
          echo "  ${G}[OK]${N} Lima VM 'apptainer' is running — apptainer reachable via: limactl shell apptainer" ;;
        Stopped)
          echo "  ${Y}[..]${N} Lima VM 'apptainer' exists but is stopped — start with: limactl start apptainer" ;;
        "")
          echo "  ${Y}[..]${N} no Lima VM named 'apptainer' yet — create with: limactl start --name=apptainer --arch=x86_64 template://apptainer" ;;
        *)
          echo "  ${Y}[..]${N} Lima VM 'apptainer' state: $LIMA_APPT_STATE" ;;
      esac
    elif [ -n "$BREW_CMD" ]; then
      echo "  ${Y}[..]${N} Homebrew present, Lima not installed — installable without admin: brew install lima"
    else
      echo "  ${R}[--]${N} Lima not installed and Homebrew not found — install Homebrew first, then 'brew install lima'"
    fi
  else
    if [ "$USERNS_OK" = 1 ]; then
      echo "  ${G}[OK]${N} user namespaces enabled — unprivileged install possible"
    else
      echo "  ${R}[--]${N} user namespaces disabled — unprivileged install blocked"
    fi
  fi
fi
echo

# ---------- Docker (fallback) ----------
DOCKER_OK=0; DOCKER_MSG="not installed"
if command -v docker >/dev/null 2>&1; then
  DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || true)
  if [ -n "$DOCKER_VER" ]; then
    DOCKER_OK=1
    if [ "$(id -u)" = 0 ] || id -nG 2>/dev/null | grep -qw docker; then
      DOCKER_MSG="installed ($DOCKER_VER), daemon reachable, user in docker group"
    else
      DOCKER_MSG="installed ($DOCKER_VER), but user NOT in docker group"
      DOCKER_OK=0
    fi
  else
    DOCKER_MSG="installed, but daemon not running or no permission"
  fi
fi

echo "${B}Docker (fallback):${N}"
if [ "$DOCKER_OK" = 1 ]; then
  echo "  ${G}[OK]${N} $DOCKER_MSG"
else
  echo "  ${D}[--] $DOCKER_MSG${N}"
fi
echo

# ---------- disk ----------
KB=$(df -k "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "${KB:-}" ] && [ "$KB" -gt 0 ] 2>/dev/null; then
  GB=$(( KB / 1024 / 1024 ))
  if [ "$GB" -lt 25 ]; then
    echo "${B}Disk:${N}   ${Y}${GB} GB free in \$HOME${N} (recommend >= 25 GB for AI image pull)"
  else
    echo "${B}Disk:${N}   ${GB} GB free in \$HOME"
  fi
  echo
fi

# ---------- recommendation ----------
echo "${B}-> RECOMMENDATION${N}"
ML="clifconsortium/clif-workbench:ml"
AI="clifconsortium/clif-workbench:ai"
EXIT=0

if [ -n "$APP_CMD" ]; then
  cat <<EOF
  Apptainer is ready. Pull a CLIF image:

      $APP_CMD pull clif-ml.sif docker://$ML
      $APP_CMD pull clif-ai.sif docker://$AI      # GPU/PyTorch (optional)

  Run a workload:

      $APP_CMD exec --bind /path/to/clif_data:/data clif-ml.sif bash /project/run.sh

  Full guide: docs/apptainer-guide.md
EOF
elif [ "$MODULE_AVAIL" = 1 ]; then
  cat <<EOF
  Apptainer is available via environment modules (no install needed, no admin):

      module load apptainer
      apptainer pull clif-ml.sif docker://$ML

  If \$HOME has a small quota (common on HPC), redirect cache first:

      export APPTAINER_CACHEDIR=/scratch/\$USER/.apptainer/cache
      export APPTAINER_TMPDIR=/scratch/\$USER/tmp
      mkdir -p \$APPTAINER_CACHEDIR \$APPTAINER_TMPDIR

  Full guide: docs/apptainer-guide.md
EOF
elif [ "$CVMFS_AVAIL" = 1 ]; then
  cat <<EOF
  Apptainer is available through CVMFS (no install, no admin):

      export PATH=/cvmfs/oasis.opensciencegrid.org/mis/apptainer/bin:\$PATH
      apptainer pull clif-ml.sif docker://$ML

  Full guide: docs/apptainer-guide.md
EOF
elif [ "$IS_MAC" = 1 ] && [ -n "$LIMA_CMD" ] && [ "$LIMA_APPT_STATE" = "Running" ]; then
  cat <<EOF
  Apptainer is reachable via the running Lima VM 'apptainer'. From this Mac:

      limactl shell apptainer
      # inside the VM:
      apptainer pull clif-ml.sif docker://$ML
      apptainer pull clif-ai.sif docker://$AI      # GPU/PyTorch (optional)

  Your Mac \$HOME is auto-mounted into the VM at the same path, so data on
  the host is directly reachable from inside the container.

  Full guide: docs/install/README-macos.md
EOF
elif [ "$IS_MAC" = 1 ] && [ -n "$LIMA_CMD" ] && [ "$LIMA_APPT_STATE" = "Stopped" ]; then
  cat <<EOF
  Lima VM 'apptainer' already exists — just start it (no admin needed):

      limactl start apptainer
      limactl shell apptainer
      apptainer pull clif-ml.sif docker://$ML

  Full guide: docs/install/README-macos.md
EOF
  EXIT=1
elif [ "$IS_MAC" = 1 ] && [ -n "$LIMA_CMD" ]; then
  cat <<EOF
  Lima is installed. Create the Apptainer VM (no admin needed):

      limactl start --name=apptainer --arch=x86_64 template://apptainer
      limactl shell apptainer
      apptainer pull clif-ml.sif docker://$ML

  On Apple Silicon, --arch=x86_64 keeps you binary-compatible with the
  clifconsortium images and HPC. If 'qemu'/'vz' errors appear, retry with
  '--vm-type=vz'.

  Full guide: docs/install/README-macos.md
EOF
  EXIT=1
elif [ "$IS_MAC" = 1 ] && [ -n "$BREW_CMD" ]; then
  cat <<EOF
  Recommended (HPC parity): install Lima + Apptainer template via Homebrew.
  No admin password needed beyond the one Homebrew already has:

      brew install lima
      limactl start --name=apptainer --arch=x86_64 template://apptainer
      limactl shell apptainer
      apptainer pull clif-ml.sif docker://$ML

EOF
  if [ "$DOCKER_OK" = 1 ]; then
    cat <<EOF
  Alternative (already-working Docker on this machine):

      docker pull $ML

EOF
  else
    cat <<EOF
  Alternative (Mac-only, no HPC parity): install Docker Desktop from
      https://www.docker.com/products/docker-desktop/
  then: docker pull $ML

EOF
  fi
  echo "  Full guide: docs/install/README-macos.md"
  EXIT=1
elif [ "$DOCKER_OK" = 1 ]; then
  cat <<EOF
  Apptainer not found, but Docker works — use it as a fallback:

      docker pull $ML
      docker pull $AI

  Apptainer is preferred for HPC-identical workflows. See docs/apptainer-guide.md.
EOF
elif [ "$IS_MAC" = 1 ]; then
  cat <<EOF
  Recommended (HPC parity): install Homebrew, then Lima + Apptainer template.
  No admin account needed — a standard macOS user can do this:

      /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      brew install lima
      limactl start --name=apptainer --arch=x86_64 template://apptainer
      limactl shell apptainer
      apptainer pull clif-ml.sif docker://$ML

  Alternative (Mac-only, no HPC parity): install Docker Desktop from
      https://www.docker.com/products/docker-desktop/
  then: docker pull $ML

  Note: clifconsortium/* images are x86_64. On Apple Silicon, both paths
  emulate x86_64 (Docker Desktop via Rosetta, Lima via QEMU/vz).
  Full guide: docs/install/README-macos.md
EOF
  EXIT=1
elif [ "$USERNS_OK" = 1 ]; then
  cat <<EOF
  No admin needed — install Apptainer into your home directory. User
  namespaces are enabled, which is all you need.

  1. Grab the latest relocatable binary from:
         https://github.com/apptainer/apptainer/releases
     (asset name like "apptainer-<version>-1.x86_64.tar.gz")

  2. Extract + add to PATH (no sudo):

         mkdir -p \$HOME/apptainer
         tar -xzf apptainer-*.tar.gz -C \$HOME/apptainer --strip-components=1
         export PATH=\$HOME/apptainer/bin:\$PATH
         echo 'export PATH=\$HOME/apptainer/bin:\$PATH' >> ~/.bashrc

  3. Verify + pull:

         apptainer --version
         apptainer pull clif-ml.sif docker://$ML

  Upstream docs: https://apptainer.org/docs/admin/main/installation.html
  CLIF guide:    docs/apptainer-guide.md
EOF
  EXIT=1
else
  cat <<EOF
  Your account cannot install a container runtime on its own. Please send
  the following to your IT / HPC admin:

  ----------------------------------------------------------------
  Subject: Request: Apptainer for containerized research workloads

  Hi,

  I need to run CLIF-WorkBench container images
  (https://hub.docker.com/u/clifconsortium) for ICU data research.

  Could you please either:
    (a) install Apptainer >= 1.0 system-wide, or
    (b) make it available via "module load apptainer", or
    (c) enable user namespaces so I can install unprivileged Apptainer
        (sysctl kernel.unprivileged_userns_clone=1)

  Apptainer runs as a normal user (no daemon, no root at runtime) and
  is standard on HPC clusters. More info: https://apptainer.org
  ----------------------------------------------------------------

  If this machine has Docker and my account gets added to the "docker"
  group, Docker is a supported fallback.
EOF
  EXIT=2
fi

echo
echo "${D}Exit: $EXIT  (0=ready, 1=user-installable, 2=needs admin)${N}"
exit $EXIT
