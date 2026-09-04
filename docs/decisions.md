# Decisions

## Why a weak Dockerfile at all

`Dockerfile.weak` is committed on purpose, alongside the real hardened
`Dockerfile`. The point of this repo is to show the *difference* a set of
concrete decisions makes, with real scanner numbers on both sides — not just
assert that the final one is "secure."

## Why multi-stage

`pip install` needs a compiler toolchain for some packages and leaves cache
files behind. None of that belongs in the image that actually runs. The
builder stage installs dependencies; the final stage copies only the
resulting `site-packages` directory across. This is most of the 1.6 GB → 206 MB
size drop, and it removes a lot of the OS-level attack surface along with it
(fewer installed packages = fewer CVEs to track).

## Why `python:3.11-slim` and not `python:3.9`

3.9 was chosen for the weak version deliberately — it's old enough that the
base Debian layer alone carries thousands of unpatched OS package CVEs.
`3.11-slim` is current and slim strips out packages a full image ships that
this app never uses.

## Why a real bug is documented here

The first hardened build crashed on startup:

```
ModuleNotFoundError: No module named 'flask'
```

`pip install --user` puts packages under a path derived from `$HOME`. The
final-stage user was created with `--no-create-home`, so `$HOME` was never
set to `/home/app`, and Python's user-site lookup silently found nothing.
Fix: `ENV HOME=/home/app` before `USER app`. Left in on purpose — this is
the kind of failure that's easy to hit for real when you actually build a
locked-down container, not something a tutorial usually shows.

## Why the 3 remaining Critical findings weren't chased further (yet)

They're all `perl-base` in the Debian base layer, and Trivy reports
`Fixed Version: None` for all three — there is no patched version to move to
yet. Pinning harder or rebuilding wouldn't fix them. The honest next step is
a distroless base, which removes `perl-base` (and the OS package manager
entirely) rather than patching it.

## What's intentionally not covered here

Signing (cosign) and admission-control enforcement (Kyverno) belong to the
Kubernetes and CI/CD pipeline projects, where the image is actually deployed
and gated — not to a single-repo Dockerfile exercise.
