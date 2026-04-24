# Install

Pick your platform. **Apptainer is the recommended runtime** on Linux and
macOS because it matches how the images run on university HPC. On Windows
the recommended path is WSL2 + Apptainer for the same reason.

| Platform | Guide | Default runtime |
|----------|-------|-----------------|
| Linux / HPC | [README-linux.md](README-linux.md) | Apptainer (no admin) |
| macOS | [README-macos.md](README-macos.md) | Apptainer via Lima VM |
| Windows | [README-windows.md](README-windows.md) | WSL2 + Apptainer |

Before installing anything, run the readiness check for your platform —
it tells you exactly what you need:

```bash
# Linux / macOS
bash docs/smoke-test/check-container-readiness.sh

# Windows
powershell -ExecutionPolicy Bypass -File docs\smoke-test\check-container-readiness.ps1
```

## Files here

- `install-apptainer.sh` — unprivileged Apptainer installer for Linux (also used inside WSL on Windows). No sudo required.
- `README-linux.md`, `README-macos.md`, `README-windows.md` — step-by-step guides per OS.
