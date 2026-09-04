# Container Security — hardening a Docker image, with real scan results

[![CI](https://github.com/hasinosec/container-security/actions/workflows/ci.yml/badge.svg)](https://github.com/hasinosec/container-security/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A small Flask app, containerised two ways: `Dockerfile.weak` (deliberately
insecure, kept in the repo for comparison) and `Dockerfile` (hardened). Every
number below is real scanner output, saved in [`docs/evidence/`](docs/evidence/)
— nothing here is estimated or written to look good.

## Before / after

| | `Dockerfile.weak` | `Dockerfile` |
| --- | --- | --- |
| Base image | `python:3.9` (unpinned, full Debian) | `python:3.11-slim`, multi-stage |
| Image size | 1.6 GB | **206 MB** (87% smaller) |
| Vulnerabilities (Trivy) | **9,314** (232 Critical, 1,840 High) | **183** (3 Critical, 53 High) — 98% fewer |
| Runs as | root | `app`, uid 100 |
| Secret in image | `API_KEY` baked into `ENV` | none |
| Healthcheck | none | `HEALTHCHECK` against `/health` |

Full evidence: [`trivy-weak-summary.txt`](docs/evidence/trivy-weak-summary.txt),
[`trivy-hardened-summary.txt`](docs/evidence/trivy-hardened-summary.txt),
[`hadolint-weak.txt`](docs/evidence/hadolint-weak.txt),
[`hadolint-hardened.txt`](docs/evidence/hadolint-hardened.txt).

The single biggest driver of the vulnerability count on the weak image:
`linux-libc-dev` alone accounts for 660 Critical/High findings, and a full
**ImageMagick** install (bundled in the `python:3.9` base, several packages,
~60 CVEs each) that this app never touches. Multi-stage + slim removes both —
see [`docs/decisions.md`](docs/decisions.md).

## What each hardening step actually did

1. **Multi-stage build.** The builder stage installs Python dependencies; the
   final stage copies only the installed packages across — no compiler, no
   pip cache, no build tooling in the image that actually runs.
2. **`python:3.11-slim` instead of `python:3.9`.** Current, and slim strips
   packages a full image ships that a Flask app never needs.
3. **Non-root user.** A dedicated `app` user (uid 100), no login shell, no
   home directory login access — `docker exec ... id` confirms it.
4. **No secret in the image.** `API_KEY` is gone from `Dockerfile`; injected
   at runtime instead (`docker run -e API_KEY=...` here; a real deployment
   would use a secrets manager).
5. **Pinned, patched dependency.** `flask==2.0.1` (CVE-2023-30861) →
   `flask==3.0.3`.
6. **`.dockerignore`.** `COPY . .` in the weak version pulls in the whole
   build context — `.git`, docs, `Dockerfile.weak` itself. The hardened
   version copies only `app.py`.
7. **`HEALTHCHECK`.** Real liveness signal against `/health`.

## A real bug this hit

The first hardened build **crashed on startup**:
`ModuleNotFoundError: No module named 'flask'`. The non-root user had no
`$HOME` set, so `pip install --user`'s packages weren't found at runtime.
Fixed with `ENV HOME=/home/app` before `USER app`. Left in
[`docs/decisions.md`](docs/decisions.md) on purpose — locking a container
down for real hits problems a tutorial usually skips.

## What's still open

3 Critical findings remain (`perl-base`, no upstream fix yet, and unused by
this app) and 2 High findings in build-tool metadata. See
[`THREAT_MODEL.md`](THREAT_MODEL.md) for the full breakdown and the accepted
risk. Next step: rebuild from a **distroless** base to drop `perl-base` (and
the OS package manager) entirely.

## Reproduce it yourself

```bash
docker build -f Dockerfile.weak -t container-security:weak .
docker build -t container-security:hardened .

trivy image container-security:weak  --severity CRITICAL,HIGH
trivy image container-security:hardened --severity CRITICAL,HIGH

hadolint Dockerfile.weak
hadolint Dockerfile

docker run -d -p 8080:8080 container-security:hardened
curl localhost:8080/health
```

## CI

`.github/workflows/ci.yml` runs on every push: Hadolint blocks on real errors,
and Trivy scans the built image and reports High/Critical findings without
blocking yet — it starts gating once the distroless follow-up closes out the
3 remaining Critical findings.
