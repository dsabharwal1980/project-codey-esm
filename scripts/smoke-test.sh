#!/usr/bin/env bash
# Read-only smoke test of the Codey tools through the invocable action REST endpoint (nothing is changed).
# Usage: bash scripts/smoke-test.sh <org-alias> [quoteId]
set -euo pipefail
ORG="${1:?org}"; QUOTE="${2:-}"
call() { # $1 class, $2 json inputs
  echo "--- $1"
  sf api request rest "/services/data/v64.0/actions/custom/apex/$1" -o "$ORG" --method POST --body "{\"inputs\":[$2]}" \
    | python3 -c 'import json,sys; r=json.load(sys.stdin)[0]; o=r.get("outputValues") or {}; print("success" if r.get("isSuccess") else "ERROR", "|", (o.get("message") or r.get("errors"))[:400] if isinstance(o.get("message") or r.get("errors"), str) else (o.get("message") or r.get("errors")))'
}
call CodeyPlaybookTool '{"topic":"index","surface":"smoke-test"}'
call CodeyHealthCheckTool '{"scope":"all","surface":"smoke-test"}'
call CodeyUpgradeImpactTool '{"surface":"smoke-test"}'
call CodeyPricePreviewTool '{"explainPlan":true,"surface":"smoke-test"}'
call CodeyAdminJobsTool '{"jobs":"default","surface":"smoke-test"}'
call CodeyPermissionsTool "{\"userType\":\"Admin\",\"users\":\"$(sf org display -o "$ORG" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["username"])')\",\"surface\":\"smoke-test\"}"
if [[ -n "$QUOTE" ]]; then
  call CodeyPricePreviewTool "{\"quoteId\":\"$QUOTE\",\"surface\":\"smoke-test\"}"
  call CodeyBulkCheckTool "{\"quoteId\":\"$QUOTE\",\"checks\":\"address\",\"surface\":\"smoke-test\"}"
  call CodeyPlaybookTool "{\"topic\":\"concept:quote-member-vs-line-item\",\"quoteId\":\"$QUOTE\",\"surface\":\"smoke-test\"}"
fi
echo "Previews were created only as Codey Change Log records (status Previewed, they expire in 30 minutes)."
