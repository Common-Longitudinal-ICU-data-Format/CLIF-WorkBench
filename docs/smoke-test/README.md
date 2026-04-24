# Container Readiness Checks

Before installing container tooling or filing a ticket with IT, run the
script for your platform. Each script is **read-only** — it checks what is
installed, what is missing, and prints copy-paste commands. It installs
nothing.

Scripts assume you do **not** have admin/sudo. User-space options are
always suggested first; "ask IT" is the last resort.

## Linux / macOS / HPC

```bash
bash docs/smoke-test/check-container-readiness.sh
```

## Windows

```powershell
# PowerShell 7:
pwsh -File docs\smoke-test\check-container-readiness.ps1

# Stock Windows PowerShell 5.1:
powershell -ExecutionPolicy Bypass -File docs\smoke-test\check-container-readiness.ps1
```

## What the script checks

| Layer                  | Linux/macOS                                              | Windows                                              |
|------------------------|----------------------------------------------------------|------------------------------------------------------|
| **Apptainer (primary)**| direct install, `module load apptainer`, CVMFS path      | Apptainer inside a WSL distro                        |
| **Docker (fallback)**  | `docker` + daemon + `docker` group                       | Docker Desktop + daemon                              |
| **Install prereqs**    | user namespaces (unprivileged install), disk space       | WSL2 present, admin status, disk space               |

## Exit codes

| Code | Meaning                                                                 |
|------|-------------------------------------------------------------------------|
| 0    | Ready — Apptainer or Docker is usable now. Script printed a `pull`.     |
| 1    | Installable without admin — script printed the exact steps.            |
| 2    | Needs admin / IT — script printed a request template you can email.     |

## Next steps after a ready report

- Install guides: [`docs/install/`](../install/) (per-OS step-by-step)
- Apptainer usage: [`docs/apptainer-guide.md`](../apptainer-guide.md)
- Docker usage: top-level [`README.md`](../../README.md)
