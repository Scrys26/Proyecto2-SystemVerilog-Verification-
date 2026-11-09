#!/usr/bin/env bash
# Publica results/ en la rama 'runs' sin tocar tu rama de trabajo.
# Uso: scripts/publish_runs.sh "mensaje opcional"
# Usa un worktree temporal: tu arbol de trabajo y tu rama actual no cambian.
set -euo pipefail

MSG="${1:-resultados de corrida}"
MAX_KB=200   # limite por archivo; si uno lo supera, aborta (evita subir logs por error)

[ -d results ] || { echo "No existe results/"; exit 1; }

# Proteccion contra archivos pesados
big=$(find results -type f -size +"${MAX_KB}"k || true)
if [ -n "$big" ]; then
  echo "Archivos mayores a ${MAX_KB} KB en results/ (no se publica):"
  echo "$big"
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
TMP=$(mktemp -d)
trap 'git -C "$REPO_ROOT" worktree remove --force "$TMP" 2>/dev/null || true' EXIT

cd "$REPO_ROOT"
git fetch origin runs 2>/dev/null || true

if git show-ref --verify --quiet refs/remotes/origin/runs; then
  git worktree add -B runs "$TMP" origin/runs
else
  git worktree add --detach "$TMP"
  git -C "$TMP" checkout --orphan runs
  git -C "$TMP" rm -rf . >/dev/null 2>&1 || true
fi

mkdir -p "$TMP/results"
cp -r results/. "$TMP/results/"
git -C "$TMP" add results
if git -C "$TMP" diff --cached --quiet; then
  echo "Sin cambios que publicar."; exit 0
fi
git -C "$TMP" commit -m "$MSG ($(git rev-parse --short HEAD))"
git -C "$TMP" push origin runs
echo "Publicado en origin/runs. En tu maquina: git fetch origin runs && git checkout origin/runs -- results/"
