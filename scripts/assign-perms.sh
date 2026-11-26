#!/usr/bin/env bash
# Assigns the Codey permission sets. Usage: bash scripts/assign-perms.sh <org-alias> <username>[,<username>...] [admin]
set -euo pipefail
ORG="${1:?org}"; USERS="${2:?usernames}"; LEVEL="${3:-user}"
PS="ESM_Codey_User"; [[ "$LEVEL" == "admin" ]] && PS="ESM_Codey_User,ESM_Codey_Admin"
for u in ${USERS//,/ }; do
  for p in ${PS//,/ }; do sf org assign permset -o "$ORG" -n "$p" -b "$u" || true; done
done
