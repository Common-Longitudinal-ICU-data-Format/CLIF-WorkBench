#!/usr/bin/env bash
# Install Apptainer into your home directory — no admin / no sudo required.
#
# What this does:
#   1. Downloads the Apptainer .deb release from GitHub
#   2. Extracts it to $PREFIX (default: $HOME/.local/apptainer)
#   3. Rearranges the layout so the binary finds its config
#   4. Prints one export line you add to ~/.bashrc
#
# Why .deb extraction: Apptainer ships prebuilt binaries inside its Debian
# package. We unpack the package with dpkg-deb (no install step, no sudo)
# and relocate it under your home. Works on any Linux distro that has
# dpkg-deb OR `ar` + `tar` (both are part of binutils; nearly always present).
#
# Requirements (all satisfied on a normal Linux workstation / HPC login node):
#   - x86_64 or aarch64 architecture
#   - curl
#   - user namespaces enabled (kernel default on any recent distro)
#   - ~250 MB of free disk in $HOME
#
# Usage:
#   bash docs/install/install-apptainer.sh
#
# Customize via env vars:
#   APPTAINER_VERSION=1.4.5          # pin a specific version (default: latest)
#   APPTAINER_PREFIX=$HOME/apptainer # install location (default: $HOME/.local/apptainer)

set -euo pipefail

# ---------- pretty output ----------
if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else             B=""; G=""; Y=""; R=""; N=""
fi
say()  { echo "${B}==>${N} $*"; }
warn() { echo "${Y}[!]${N} $*" >&2; }
die()  { echo "${R}[x] $*${N}" >&2; exit 1; }

# ---------- config ----------
PREFIX="${APPTAINER_PREFIX:-$HOME/.local/apptainer}"
VERSION="${APPTAINER_VERSION:-}"
ARCH=$(uname -m)

case "$ARCH" in
  x86_64)  DEB_ARCH="amd64" ;;
  aarch64|arm64) DEB_ARCH="arm64" ;;
  *) die "Unsupported architecture: $ARCH (need x86_64 or aarch64)" ;;
esac

# ---------- sanity checks ----------
[ "$(uname -s)" = "Linux" ] || die "This installer is Linux-only. On macOS see docs/install/README-macos.md; on Windows use WSL (see docs/install/README-windows.md)."
command -v curl >/dev/null 2>&1 || die "curl is required. Install curl first (ask IT if needed)."

# user namespaces — required for unprivileged apptainer
USERNS_OK=0
[ "$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo 0)" = "1" ] && USERNS_OK=1
MNS=$(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo 0)
[ "$MNS" -gt 0 ] 2>/dev/null && USERNS_OK=1

if [ "$USERNS_OK" != "1" ]; then
  die "user namespaces are disabled on this machine.

Ask your admin to run ONE of these as root (both are harmless and standard):

    sysctl -w kernel.unprivileged_userns_clone=1
    echo 'kernel.unprivileged_userns_clone=1' > /etc/sysctl.d/90-apptainer.conf

Then re-run this script."
fi

# ---------- resolve version ----------
if [ -z "$VERSION" ]; then
  say "Looking up latest Apptainer release on GitHub"
  VERSION=$(curl -sfL https://api.github.com/repos/apptainer/apptainer/releases/latest \
              | grep '"tag_name"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
  [ -n "$VERSION" ] || die "Could not detect latest version. Pin one with APPTAINER_VERSION=X.Y.Z and re-run."
fi

DEB="apptainer_${VERSION}_${DEB_ARCH}.deb"
URL="https://github.com/apptainer/apptainer/releases/download/v${VERSION}/${DEB}"

say "Installing Apptainer ${B}$VERSION${N} ($DEB_ARCH) into ${B}$PREFIX${N}"

# ---------- refuse to overwrite silently ----------
if [ -x "$PREFIX/usr/bin/apptainer" ]; then
  EXISTING=$("$PREFIX/usr/bin/apptainer" --version 2>/dev/null || echo unknown)
  warn "Existing install found: $EXISTING"
  echo "    Remove $PREFIX and re-run, or set APPTAINER_PREFIX to a different location."
  exit 1
fi

# ---------- download + extract ----------
TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

say "Downloading $URL"
curl -fL --progress-bar -o "$TMP/apptainer.deb" "$URL" \
  || die "Download failed. Check network, or pin an older version with APPTAINER_VERSION=."

mkdir -p "$PREFIX"
say "Extracting"
if command -v dpkg-deb >/dev/null 2>&1; then
  dpkg-deb -x "$TMP/apptainer.deb" "$PREFIX"
elif command -v ar >/dev/null 2>&1; then
  (cd "$TMP" && ar x apptainer.deb)
  DATA=$(ls "$TMP"/data.tar.* | head -1)
  [ -n "$DATA" ] || die "No data.tar.* in deb — extraction failed"
  tar -xf "$DATA" -C "$PREFIX"
else
  die "Need 'dpkg-deb' or 'ar' to extract the .deb. Install 'binutils' (no sudo: use conda/spack) or ask IT."
fi

# Apptainer expects config next to the binary: <bin>/../etc/apptainer/,
# but the deb places it at $PREFIX/etc/ . Mirror it under $PREFIX/usr/ .
say "Fixing config layout for relocated install"
mkdir -p "$PREFIX/usr/etc" "$PREFIX/usr/var"
cp -a "$PREFIX/etc/." "$PREFIX/usr/etc/"
cp -a "$PREFIX/var/." "$PREFIX/usr/var/"

BIN="$PREFIX/usr/bin/apptainer"
[ -x "$BIN" ] || die "Install failed: $BIN not found"

# ---------- verify ----------
say "Verifying"
INSTALLED_VER=$("$BIN" --version)
echo "    $INSTALLED_VER"

# ---------- PATH guidance ----------
BIN_DIR="$PREFIX/usr/bin"
BASHRC="$HOME/.bashrc"
ALREADY_IN_RC=0
grep -qsF "$BIN_DIR" "$BASHRC" 2>/dev/null && ALREADY_IN_RC=1

echo
say "${G}Done.${N}"
cat <<EOF

Add Apptainer to your PATH:

    # this shell (now):
    export PATH=$BIN_DIR:\$PATH

EOF

if [ "$ALREADY_IN_RC" = 0 ]; then
cat <<EOF
    # future shells (permanent):
    echo 'export PATH=$BIN_DIR:\$PATH' >> ~/.bashrc

EOF
else
  echo "    (~/.bashrc already references $BIN_DIR — skipping)"
  echo
fi

cat <<EOF
Then pull a CLIF image:

    apptainer pull clif-ml.sif docker://clifconsortium/clif-workbench:ml

If your home directory has a small quota (common on HPC),
redirect the cache first:

    export APPTAINER_CACHEDIR=/scratch/\$USER/.apptainer/cache
    export APPTAINER_TMPDIR=/scratch/\$USER/tmp
    mkdir -p \$APPTAINER_CACHEDIR \$APPTAINER_TMPDIR

Full CLIF usage guide: docs/apptainer-guide.md
Apptainer upstream docs: https://apptainer.org/docs/user/latest/
EOF
