# Docker Tags & Versioning

## What is a tag?

A Docker **image** is a zip file of your entire environment. A **tag** is just a **name sticker** you put on that zip file.

## What happens when you build

```bash
./scripts/build.sh ml
```

This creates one image and sticks **two labels** on it:

```
clif-workbench:ml        ← the "ml" sticker
clif-workbench:latest    ← the "latest" sticker (because ml is the default)
```

Both stickers point to **the exact same image**. No duplication.

## What happens when you publish

```bash
./scripts/publish.sh ml 0.1.0
```

This takes that same image and pushes it to Docker Hub **three times** (same image, three names):

```
clifconsortium/clif-workbench:ml          ← "give me the latest ml"
clifconsortium/clif-workbench:latest      ← "give me whatever's default"
clifconsortium/clif-workbench:0.1.0-ml    ← "give me exactly this version"
```

## Why version tags matter

Imagine you publish `0.1.0` in April, then update packages and publish `0.2.0` in June:

```
April:   :ml  →  points to 0.1.0 image
June:    :ml  →  points to 0.2.0 image (MOVED!)
```

The `:ml` tag is **floating** — it always points to the latest build. So if a site does `docker pull clif-workbench:ml`, they always get the newest.

But `:0.1.0-ml` **never moves**. A site that needs reproducibility pins to that:

```bash
# Always latest (for sites that want auto-updates)
docker pull clifconsortium/clif-workbench:ml

# Frozen in time (for sites that need reproducibility)
docker pull clifconsortium/clif-workbench:0.1.0-ml
```

## Visual summary

```
           Image A (built April)     Image B (built June)
           ┌──────────────────┐      ┌──────────────────┐
Tags:      │  :0.1.0-ml       │      │  :0.2.0-ml       │
(frozen)   │                  │      │                  │
           └──────────────────┘      └──────────────────┘
                                            ▲
Tags:                                       │
(floating)          :ml  ───────────────────┘  (moved to newer)
                    :latest ────────────────┘
```

## Without a version

```bash
./scripts/publish.sh ml        # no version arg
```

Only pushes `:ml` and `:latest`. No versioned tag. Fine for early development, but once sites depend on it, start passing versions.

## All available tags

| Tag | Type | Description |
|-----|------|-------------|
| `ml` | Floating | Latest ML image (data + classical ML) |
| `ai` | Floating | Latest AI image (+ PyTorch/CUDA 12.8) |
| `latest` | Floating | Alias for `ml` |
| `X.Y.Z-ml` | Frozen | Version-pinned ML image |
| `X.Y.Z-ai` | Frozen | Version-pinned AI image |
