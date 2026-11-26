---
name: esm-settings-health-check
description: Compare the org's ESM settings and permissions with the recommended settings pack and show OK / Warning / Needs Fix with the reason, a help link and a fix. Read-only; nothing changes unless the person approves a fix. Use for "check my settings", "is my setup correct", "health check".
triggers: ["check my settings", "is my setup correct", "health check", "settings problem", "add assets to quote fails", "slow cart"]
tools: [check_esm_setup, apply_esm_change, manage_esm_permissions, get_codey_playbook]
cards: [Health check report, Approval]
runbooks: [US-02]
---

# Skill: Settings health check

**Purpose:** find setting problems before they cause errors. Returns in about two minutes.
**Example request:** "Check if my setup is correct."

## Steps
1. **Run the check** – `check_esm_setup scope=all` (or one area: `quoting`, `assets`, `performance`, `console`,
   `permissions`, `adminjobs`, `prereq`). It finds the installed version, reads the quoting settings, the settings for adding
   assets to a quote, permissions, Console settings, admin job history and performance settings, and compares them with the
   Recommended settings pack.
2. **Show the Health check report** card. In text-only surfaces: one line with the counts, then a table of the Needs Fix and
   Warning items (setting – current – recommended – why). Never print values the tool masked.
3. **Offer fixes.** For each fixable item the row has a *Fix it* button / suggested reply. A fix always goes through a
   preview: `apply_esm_change changeType=cpqSetting target=<key> value=<recommended> mode=preview` → Approval card → on
   "approve" `mode=commit`. Permission items → *permissions* skill. Admin job items → `run_esm_admin_jobs`.
   Items marked "check by hand" → give the Setup path and help link.
4. **Re-check** the changed area (`check_esm_setup scope=<area>`) and report the new status.

## Rules
- Read-only until approved. Group several fixes in one preview only if the person asks for "fix all".
- A Warning may be a deliberate customer choice: ask before "fixing" it.
- Values marked secret (keys, passwords, tokens) are always masked.

## Result
`OK <n> · Warning <n> · Needs Fix <n>` and what was fixed (with change log ids).
Help: [Add assets to quote](https://help.salesforce.com/s/articleView?id=ind.comms_add_assets_to_quote.htm&type=5) ·
[Customize your implementation](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5) ·
[Permission guidelines](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
