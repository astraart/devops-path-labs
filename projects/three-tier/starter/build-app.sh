#!/usr/bin/env bash
# Собирает notes-api из репозитория-спутника в ansible/roles/app/files/notes-api.
# Go ставить не нужно: сборка идёт в официальном образе golang. Нужен Docker.
set -euo pipefail

SRC="${NOTES_API_SRC:-$HOME/devops-path-labs/apps/notes-api}"
VERSION="${VERSION:-0.1.0}"
OUT="$(cd "$(dirname "$0")" && pwd)/ansible/roles/app/files"

docker run --rm --user "$(id -u):$(id -g)" \
    -e CGO_ENABLED=0 -e GOCACHE=/tmp/gocache -e GOMODCACHE=/tmp/gomod \
    -v "$SRC":/src:ro -v "$OUT":/out -w /src \
    golang:1.27-trixie \
    go build -trimpath -ldflags "-s -w -X main.version=$VERSION" -o /out/notes-api .
echo "Готово: $OUT/notes-api"
