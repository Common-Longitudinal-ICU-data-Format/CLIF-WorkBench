# CLIF-WorkBench container readiness check (Windows).
# Read-only: detects environment and prints commands you can run.
# Assumes you do NOT have admin — user-space options come first.
# Works on stock Windows PowerShell 5.1 and PowerShell 7+.

$ErrorActionPreference = 'Continue'

function H($t) { Write-Host $t -ForegroundColor Cyan }
function Ok($t) { Write-Host "  [OK] $t" -ForegroundColor Green }
function No($t) { Write-Host "  [--] $t" -ForegroundColor Red }
function D($t)  { Write-Host "       $t" -ForegroundColor DarkGray }

H "=== CLIF-WorkBench Container Readiness ==="
Write-Host ""

# ---------- environment ----------
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$osCap = if ($os) { $os.Caption } else { "Windows" }
$osBuild = if ($os) { [int]$os.BuildNumber } else { 0 }
$arch = $env:PROCESSOR_ARCHITECTURE
$isAdmin = ([Security.Principal.WindowsPrincipal]::new(
              [Security.Principal.WindowsIdentity]::GetCurrent())
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

H "Environment:"
Write-Host "  OS:     $osCap (build $osBuild, $arch)"
Write-Host ("  User:   {0} - {1}" -f $env:USERNAME, $(if ($isAdmin) {'admin'} else {'standard user (NOT admin)'}))
Write-Host "  Shell:  PowerShell $($PSVersionTable.PSVersion)"
Write-Host ""

# ---------- WSL (primary on Windows -> Apptainer path) ----------
$wslPresent  = $false
$wslDistros  = @()
$wslApptainer = $false

$wslExe = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($wslExe) {
    $null = & wsl.exe --status 2>$null
    if ($LASTEXITCODE -eq 0) {
        $wslPresent = $true
        $raw = & wsl.exe -l -q 2>$null
        if ($LASTEXITCODE -eq 0 -and $raw) {
            $wslDistros = $raw -split "`r?`n" |
                ForEach-Object { ($_ -replace "`0","").Trim() } |
                Where-Object  { $_ -ne "" }
        }
        if ($wslDistros.Count -gt 0) {
            $probe = & wsl.exe -- bash -lc "command -v apptainer >/dev/null 2>&1 || command -v singularity >/dev/null 2>&1 && echo yes" 2>$null
            if ($probe -match "yes") { $wslApptainer = $true }
        }
    }
}

H "WSL (Apptainer path):"
if ($wslPresent) {
    Ok "WSL installed"
    if ($wslDistros.Count -gt 0) { D ("distros: " + ($wslDistros -join ", ")) }
    if ($wslApptainer) {
        Ok "Apptainer/Singularity found inside WSL"
    } else {
        No "Apptainer/Singularity not found inside WSL"
    }
} else {
    No "WSL not installed"
}
Write-Host ""

# ---------- Docker Desktop (fallback) ----------
$dockerCmd   = Get-Command docker -ErrorAction SilentlyContinue
$dockerWorks = $false
$dockerVer   = ""
if ($dockerCmd) {
    $dockerVer = & docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $dockerVer) { $dockerWorks = $true }
}

H "Docker Desktop (fallback):"
if ($dockerWorks) {
    Ok "installed ($dockerVer), daemon reachable"
} elseif ($dockerCmd) {
    No "installed but daemon not running (start Docker Desktop)"
} else {
    No "not installed"
}
Write-Host ""

# ---------- disk ----------
$cFree = [math]::Round((Get-PSDrive C -ErrorAction SilentlyContinue).Free / 1GB, 1)
H "Disk:"
if ($cFree -lt 25) {
    Write-Host "  $cFree GB free on C: (recommend >= 25 GB for AI image)" -ForegroundColor Yellow
} else {
    Write-Host "  $cFree GB free on C:"
}
Write-Host ""

# ---------- recommendation ----------
H "-> RECOMMENDATION"
$ml = "clifconsortium/clif-workbench:ml"
$ai = "clifconsortium/clif-workbench:ai"
$exit = 0

if ($wslPresent -and $wslApptainer) {
@"
  WSL + Apptainer detected. Pull a CLIF image from inside WSL:

      wsl -- apptainer pull clif-ml.sif docker://$ml
      wsl -- apptainer pull clif-ai.sif docker://$ai

  Or enter the WSL shell and work there:

      wsl
      apptainer pull clif-ml.sif docker://$ml
      apptainer exec --bind /mnt/c/path/to/data:/data clif-ml.sif bash /project/run.sh

  Full guide: docs\apptainer-guide.md
"@ | Write-Host
    $exit = 0
}
elseif ($wslPresent) {
@"
  WSL is installed, Apptainer is not. You can install Apptainer inside
  WSL with NO Windows admin (you only need sudo inside the WSL distro,
  which every WSL user has by default).

      wsl                                            # open your WSL distro

      # inside WSL (Ubuntu/Debian):
      sudo apt-get update
      sudo apt-get install -y software-properties-common
      sudo add-apt-repository -y ppa:apptainer/ppa
      sudo apt-get update
      sudo apt-get install -y apptainer
      apptainer --version

      # then pull:
      apptainer pull clif-ml.sif docker://$ml

  Full guide: docs\apptainer-guide.md
"@ | Write-Host
    $exit = 1
}
elseif ($dockerWorks) {
@"
  No WSL, but Docker Desktop works. Use Docker:

      docker pull $ml
      docker pull $ai

  Note: Docker is a supported fallback. If you later need HPC-identical
  workflows (submitting to institutional HPC), enable WSL and switch to
  Apptainer — see docs\apptainer-guide.md.
"@ | Write-Host
    $exit = 0
}
elseif ($isAdmin) {
@"
  No container runtime installed. You have admin — enable WSL for the
  HPC-identical path (recommended):

      wsl --install

  (Installs WSL2 + Ubuntu; requires one reboot. Re-run this script
  afterward to get the 'install Apptainer inside WSL' instructions.)

  Alternative (Docker only, simpler):

      Install Docker Desktop: https://www.docker.com/products/docker-desktop/

  Full guide: docs\apptainer-guide.md
"@ | Write-Host
    $exit = 1
}
else {
@"
  You cannot install a container runtime without admin. Please send
  this to your IT admin:

  ----------------------------------------------------------------
  Subject: Request: Enable WSL2 (or install Docker Desktop) for research

  Hi,

  I need to run CLIF-WorkBench container images
  (https://hub.docker.com/u/clifconsortium) for ICU data research.

  Could you please either:
    (a) enable WSL2 on my machine ("wsl --install" from an admin
        PowerShell; requires one reboot) — I will then install
        Apptainer inside the WSL distro myself, or
    (b) install Docker Desktop
        (https://www.docker.com/products/docker-desktop/)

  Option (a) is preferred: it matches how our institutional HPC runs
  these same containers with Apptainer.
  ----------------------------------------------------------------
"@ | Write-Host
    $exit = 2
}

Write-Host ""
Write-Host "Exit: $exit  (0=ready, 1=user-installable, 2=needs admin)" -ForegroundColor DarkGray
exit $exit
