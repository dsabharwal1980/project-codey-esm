#!/usr/bin/env bash
# Installs the 8 Project Codey ESM skills as Claude Code skills (folder per skill with SKILL.md).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${1:-}" == "--project" ]]; then DEST="$ROOT/.claude/skills"; else DEST="${HOME}/.claude/skills"; fi
mkdir -p "$DEST"
for d in "$ROOT"/skills/*/; do
  name="esm-$(basename "$d")"
  mkdir -p "$DEST/$name"
  cp "$d/SKILL.md" "$DEST/$name/SKILL.md"
  cp "$ROOT/playbook/PLAYBOOK.md" "$DEST/$name/PLAYBOOK.md"
  echo "installed $name"
done
echo "Done: $DEST"
