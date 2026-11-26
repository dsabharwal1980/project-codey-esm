#!/usr/bin/env bash
# Deploys Project Codey ESM to a Salesforce org in the right order.
# Usage: bash scripts/deploy.sh <org-alias> [--with-coworker] [--skip-agent] [--check-only]
set -euo pipefail
ORG="${1:?usage: bash scripts/deploy.sh <org-alias> [--with-coworker] [--skip-agent] [--check-only]}"; shift || true
WITH_COWORKER=0; SKIP_AGENT=0; CHECK=""
for a in "$@"; do case "$a" in --with-coworker) WITH_COWORKER=1;; --skip-agent) SKIP_AGENT=1;; --check-only) CHECK="--dry-run";; esac; done
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
D=force-app/main/default
TESTS="--tests CodeyCoreTest --tests CodeyToolsTest --tests CodeyJobsTest"

echo "== 0. Build generated content from the repo (static resources, custom metadata, HXL, agents)"
python3 scripts/build-static-resources.py
python3 scripts/build-cmdt.py
python3 scripts/build-hxl.py
python3 scripts/build-agents.py
python3 scripts/build-mcp.py

echo "== 1. Core: objects, knowledge packs, Apex tools, permission sets, Codey Setup app (with tests)"
sf project deploy start -o "$ORG" $CHECK -d $D/objects -d $D/customMetadata -d $D/staticresources -d $D/classes -d $D/customPermissions \
  -d $D/permissionsets -d $D/lwc -d $D/tabs -d $D/applications --test-level RunSpecifiedTests $TESTS --wait 60

echo "== 2. HXL experience cards (UiWidgetBundle + LightningTypeBundle, API 68+)"
sf project deploy start -o "$ORG" $CHECK -d $D/uiWidgets -d $D/lightningTypes --api-version 68.0 --wait 30

echo "== 3. Salesforce Hosted MCP server EsmCodeyEaseOfBuild"
sf project deploy start -o "$ORG" $CHECK -d $D/mcpServerDefinitions --api-version 68.0 --wait 30

if [[ -n "$CHECK" ]]; then echo "Check-only run finished."; exit 0; fi

if [[ $SKIP_AGENT -eq 0 ]]; then
  echo "== 4. Agentforce agent ESM_Codey (Agent Script)"
  sf project deploy start -o "$ORG" -d $D/aiAuthoringBundles/ESM_Codey --api-version 68.0 --wait 30
  sf agent validate authoring-bundle --api-name ESM_Codey -o "$ORG" --json
  sf agent publish authoring-bundle --api-name ESM_Codey -o "$ORG" --json
  sf agent activate --api-name ESM_Codey -o "$ORG" || echo "Activate ESM_Codey in Setup → Agentforce Agents if this failed."
fi

if [[ $WITH_COWORKER -eq 1 ]]; then
  echo "== 5. Extend the ESM Coworker with the Codey build subagent"
  TMP="$(mktemp -d)"; mkdir -p "$TMP/force-app"
  printf '{"packageDirectories":[{"path":"force-app","default":true}],"sourceApiVersion":"68.0"}' > "$TMP/sfdx-project.json"
  ( cd "$TMP" && sf project retrieve start -o "$ORG" -m "AiAuthoringBundle:ESM_Coworker" --wait 10 )
  python3 scripts/merge-coworker.py "$TMP/force-app/main/default/aiAuthoringBundles/ESM_Coworker/ESM_Coworker.agent"
  ( cd "$TMP" && sf project deploy start -o "$ORG" -d force-app/main/default/aiAuthoringBundles/ESM_Coworker --wait 30 )
  sf agent validate authoring-bundle --api-name ESM_Coworker -o "$ORG" --json --source-dir "$TMP/force-app/main/default/aiAuthoringBundles/ESM_Coworker" || true
  sf agent publish authoring-bundle --api-name ESM_Coworker -o "$ORG" --json
  sf agent activate --api-name ESM_Coworker -o "$ORG" || echo "Activate the new ESM_Coworker version in Setup if this failed."
fi
echo "Done. Next: bash scripts/assign-perms.sh $ORG <username> [admin]; then bash scripts/smoke-test.sh $ORG"
