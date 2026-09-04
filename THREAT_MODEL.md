# Container Security — Threat Model

Scope: the container image and its runtime configuration for a small Flask
service. The app itself is trivial on purpose — the subject under test is the
**Dockerfile and the resulting image**.

## Assets

- The running container's filesystem and process
- Any secret the app needs at runtime (represented here by `API_KEY`)
- The host it runs on, if the container escapes or gets excessive privilege

## Threats and mitigations

| Threat | Weak baseline | Mitigation | Evidence |
|---|---|---|---|
| Secret baked into the image, readable by anyone who pulls it | `ENV API_KEY=supersecret12345` in `Dockerfile.weak` | No secret in the image at all; injected at runtime via `docker run -e` / an orchestrator secret | `docker history` / Hadolint DL3064; `docker inspect` on the hardened image shows no such variable |
| Container compromise escalates to host / other containers | Process runs as root (default) | Dedicated unprivileged user (`app`, uid 100), `--no-create-home`, no shell login | `docker exec ... id` → `uid=100(app)` |
| Large, unpatched attack surface | `python:3.9` (old, full Debian) | Multi-stage build → `python:3.11-slim`, no build tools in the final image | Trivy: 9,314 → 183 vulnerabilities; 1.6 GB → 206 MB |
| Known-vulnerable dependency | `flask==2.0.1` (CVE-2023-30861) | Pinned to `flask==3.0.3` | Trivy no longer reports CVE-2023-30861 |
| Silent failure / no liveness signal | No `HEALTHCHECK` | `HEALTHCHECK` calling `/health` | `docker inspect` shows a health status |
| Whole build context copied into the image (secrets, `.git`, docs) | `COPY . .` | `.dockerignore` + explicit `COPY app/app.py .` | Image contains only the app file |

## Accepted risk

- **3 remaining CRITICAL findings** (`perl-base` in the `python:3.11-slim` base) have **no fixed version yet upstream** — Trivy confirms `Fixed Version: None`. The app doesn't use Perl. Next step: rebuild from a Python **distroless** base, which drops `perl-base` entirely (tracked below).
- The app runs Flask's built-in development server. Fine for this case study; a real deployment would run it behind `gunicorn`/`uwsgi`.

## Next hardening step

Rebuild `FROM gcr.io/distroless/python3-debian12` to remove the OS package
manager and remaining unused packages (including `perl-base`) entirely.
