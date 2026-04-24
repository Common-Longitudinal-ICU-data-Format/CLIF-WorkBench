# Tags & Versioning

Internal reference for maintainers. Describes Docker Hub tags and `.sif` filenames shipped alongside each release.

## Docker Hub tags

Every `./scripts/publish.sh all <X.Y.Z>` pushes the same image under three names:

| Tag | Type | Purpose |
|-----|------|---------|
| `:ml` | Floating | Latest ML image — moves with each publish |
| `:ai` | Floating | Latest AI image — moves with each publish |
| `:latest` | Floating | Alias for `:ml` |
| `:X.Y.Z-ml` | Frozen | Version-pinned ML image — never moves |
| `:X.Y.Z-ai` | Frozen | Version-pinned AI image — never moves |

Floating tags are convenient for sites that want auto-updates; frozen tags are required for any reproducible pipeline.

```
           Image A (April)          Image B (June)
           ┌──────────────────┐     ┌──────────────────┐
Frozen:    │  :0.1.0-ml       │     │  :0.2.0-ml       │
           └──────────────────┘     └──────────────────┘
                                            ▲
Floating:              :ml  ─────────────────┘  (moves to newer)
                       :latest ──────────────┘
```

Running `./scripts/publish.sh ml` with no version argument pushes only the floating `:ml` and `:latest` — fine for early development, but once external sites depend on the image, always pass a version.

## `.sif` filenames

`.sif` assets published to GitHub Releases follow:

```
clif-<kind>-<X.Y.Z>.sif           # e.g. clif-ml-0.1.0.sif
clif-<kind>-<X.Y.Z>.sif.sha256    # matching checksum file
```

`<kind>` is `ml` or `ai`. There is no floating `clif-ml.sif` asset — users who want "latest" pull from Docker Hub (`apptainer pull clif-ml.sif docker://clifconsortium/clif-workbench:ml`). Offline downloaders get a frozen version; that's a feature, not a bug.

Only the ML `.sif` (~1 GB) ships as a GitHub Release asset. The AI `.sif` (~10 GB) exceeds GitHub's 2 GB per-file cap; users needing it offline copy the file directly from a colleague's machine.
