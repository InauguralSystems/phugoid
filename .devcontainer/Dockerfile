# Self-contained dev/CI image for phugoid.
#
# phugoid is a *consumer* of EigenScript: it runs .eigs programs against the
# runtime. This image builds EigenScript at a pinned tag and puts it on PATH,
# so the tag below IS the version pin — bump EIGS_REF to move the runtime.
#
# Rung 0 is headless by contract (see README): no SDL, no X11. The headless
# binary resolves its stdlib relative to itself, so the source tree stays at
# /opt/eigenscript with src/ on PATH (the fleet devcontainer pattern).
#
# The same image backs Codespaces AND CI (.github/workflows/test.yml runs the
# suite inside it via devcontainers/ci), so "green in my Codespace" and "green
# in CI" can't drift.
FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
 && rm -rf /var/lib/apt/lists/*

ARG EIGS_REF=v0.41.0
RUN git clone --depth 1 --branch "${EIGS_REF}" \
        https://github.com/InauguralSystems/EigenScript.git /opt/eigenscript \
 && make -C /opt/eigenscript CC=gcc

ENV PATH="/opt/eigenscript/src:${PATH}"
WORKDIR /workspaces/phugoid
