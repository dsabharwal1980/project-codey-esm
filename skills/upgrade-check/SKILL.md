---
name: esm-upgrade-check
description: Show how a new release affects the org's customized ESM screens and components, with risk level and suggested action; on request suggest a combined (merged) version for review. Reports only – nothing is saved without review. Use for "what will the next upgrade affect".
triggers: ["upgrade", "next release", "what will the upgrade affect", "customized screens", "release impact"]
tools: [check_esm_upgrade_impact, get_codey_playbook, apply_esm_change]
cards: [Upgrade impact report, Approval]
runbooks: [US-05]
---

# Skill: Upgrade check

**Purpose:** upgrade without losing customizations.
**Example request:** "What will the next upgrade affect?"

## Steps
1. **Which release?** Default: the next release in the Release change list (`get_codey_playbook topic=releases`).
2. **List customized screens and compare** – `check_esm_upgrade_impact targetRelease=<release>`. The tool lists the org's
   customized ESM/CPQ FlexCards, OmniScripts, Integration Procedures and LWCs (custom copies or overrides of standard
   components), matches them with the release change list, and rates each: High / Medium / Low with a suggested action.
3. **Show the Upgrade impact report** card (text: table screen – what changed – risk – action).
4. **On request, suggest a combined version** for one screen. On developer surfaces (Claude Code, Cursor): retrieve the
   customer's version and the new standard version, produce a 3-way merge proposal as a file/branch for review. Never deploy
   it without the person's review and approval (then deploy with the standard deploy action, preview first).
5. **Plan** – order High items first, suggest testing in a sandbox refreshed with the new release.

## Rules
- Report and suggest only. Never overwrite a customer customization automatically.

## Result
`<n> customized screens checked: High <n>, Medium <n>, Low <n>. Top action: …`
