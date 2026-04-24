# Building and Publishing CLIF-WorkBench Images

Internal reference for maintainers. End users should not read this — they use [`docs/apptainer-guide.md`](../apptainer-guide.md).

## Pipeline

```
   Dockerfile                docker build            docker push           apptainer build
   (source of                ───────────►  image  ───────────►  DockerHub  ───────────►  .sif file
    truth)                                                                                │
                                                                                          ▼
                                                                        GitHub Releases (ML only, < 2 GB)
```

Docker is the build tool. Docker Hub is the canonical registry. `.sif` files on GitHub Releases are an offline fallback for the ML image.

## Prerequisites

- Docker daemon running (`docker info`).
- Docker Hub credentials with push access to `clifconsortium/clif-workbench` (`docker login`).
- Apptainer installed, for the optional `.sif` build step (`apptainer --version`).
- `gh` CLI authenticated, for uploading `.sif` to a GitHub Release (`gh auth status`).

## Build

```bash
./scripts/build.sh ml     # ML image
./scripts/build.sh ai     # AI image (slow, large)
./scripts/build.sh all
```

Tagged locally as `clif-workbench:ml`, `clif-workbench:ai`, `clif-workbench:latest` (ML only).

## Test

```bash
./scripts/test-images.sh ml
./scripts/test-images.sh ai
./scripts/test-images.sh all
```

Runs smoke-test Python imports inside the image.

## Publish to Docker Hub

```bash
docker login                          # first time only
./scripts/publish.sh ml  0.1.0        # pushes :ml, :latest, :0.1.0-ml
./scripts/publish.sh ai  0.1.0        # pushes :ai, :0.1.0-ai
./scripts/publish.sh all 0.1.0        # both

# Use a different org (default: clifconsortium)
DOCKERHUB_ORG=myorg ./scripts/publish.sh all 0.1.0
```

See [versioning.md](versioning.md) for the tag naming convention.

## Publish `.sif` (optional, offline fallback)

After the Docker image is built locally, convert to `.sif` and upload to the matching GitHub Release:

```bash
# Convert — produces clif-ml-0.1.0.sif (+ .sha256)
./scripts/build-sif.sh ml 0.1.0

# Upload to the GH Release v0.1.0 (ML only; AI > 2 GB and won't upload)
./scripts/publish-sif.sh ml 0.1.0
```

The AI `.sif` is intentionally **not** published to GitHub Releases — it exceeds the 2 GB per-file cap. Users needing an offline AI image should either (a) pull once on an internet-facing machine and `scp` the `.sif`, or (b) we set up a Zenodo mirror if a site requests it.

## Full release flow (example)

```bash
./scripts/build.sh all
./scripts/test-images.sh all
./scripts/publish.sh all 0.1.0

# Tag the release in git
git tag v0.1.0 && git push --tags
gh release create v0.1.0 --generate-notes

# Ship the ML .sif alongside the release
./scripts/build-sif.sh ml 0.1.0
./scripts/publish-sif.sh ml 0.1.0
```

## Image internals

- `images/ml/Dockerfile` — `python:3.12-slim-bookworm` base, installs `uv`, system libs (`libgomp1`, `git`, `curl`), then `requirements.txt`.
- `images/ai/Dockerfile` — `nvidia/cuda:12.8.0-devel-ubuntu22.04` base, installs Python 3.12 via deadsnakes, `uv`, PyTorch (CUDA 12.8), then `requirements.txt`.
- Each Dockerfile ends with a `python -c "import ..."` sanity-check layer so a broken build fails at `docker build`, not at runtime.

To add a package: edit the relevant `requirements.txt`, rebuild, test, publish with a bumped version.
