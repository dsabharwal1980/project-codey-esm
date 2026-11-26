---
name: esm-fresh-install
description: Install and set up Enterprise Sales Management on a new sandbox – prerequisites, configuration packs, permission sets, Console and Google Maps, admin jobs, then a priced test Enterprise Quote and a health check. Use for "install ESM", "set up ESM on my sandbox", "give me a working base".
triggers: ["install enterprise sales management", "set up esm", "new sandbox", "fresh install", "run the admin jobs"]
tools: [check_esm_setup, manage_esm_permissions, apply_esm_change, run_esm_admin_jobs, preview_esm_price, track_codey_job, get_codey_playbook]
cards: [Approval, Progress tracker, Health check report]
runbooks: [US-01, US-04]
---

# Skill: Fresh install

**Purpose:** a working ESM sandbox, a priced test Enterprise Quote and a short summary – in hours, not days.
**Example requests:** "Install Enterprise Sales Management on my new sandbox." · "Run the admin jobs."

## Inputs to collect (ask only for what is missing)
- Target org (must be a sandbox unless the person explicitly confirms production).
- Which configuration packs (default: the ESM base packs for the installed release).
- User types that need access (default: Admin = the person asking; Sales rep).
- Whether Google Maps is used (address maps on quote members).

## Steps
1. **Check prerequisites** – `check_esm_setup scope=prereq`. Needs: Communications Cloud (vlocity_cmt) package, OmniStudio,
   Enterprise Quote / Enterprise Order record types, an active price list and pricing plan, the CPQ quoting features.
   - Anything *Needs Fix* that is a licence or package → stop and tell the person what to request (escalation). Packages
     are installed by an admin or, on developer surfaces (Claude Code, Cursor), with the Salesforce CLI package install.
2. **Show the install plan** as an Approval card (one preview per step group below) and wait for approval. The plan lists, in
   order: configuration packs → permission sets → Console settings → Google Maps key → admin jobs → test quote → health check.
3. **Configuration packs** (data packs). On developer surfaces deploy them with the OmniStudio / Vlocity build tool
   (`vlocity packDeploy -job <job>.yaml`) per the help article "Download and migrate configuration packs". On chat
   surfaces, confirm with the person that the packs are loaded, then continue. Re-running is safe (packs upsert).
4. **Permission sets** – follow the *permissions* skill for the user types (`manage_esm_permissions`).
5. **Console settings** – `check_esm_setup scope=console`; fix items with `apply_esm_change` (preview → approve → commit).
   Enhanced event handling and app visibility by profile are set in Setup; give the exact path and help link if the tool
   reports them as "check by hand".
6. **Google Maps key (if used)** – never in chat. Send the person to **App Launcher → Codey Setup → Google Maps key**, where
   the key is entered in a masked field. Then re-run `check_esm_setup scope=console` to confirm it is set (value masked).
7. **Admin jobs** – `run_esm_admin_jobs mode=preview` (default set, documented order) → Approval → `mode=commit` → show
   the Progress tracker; poll with `track_codey_job` every ~60 s or when asked. If a job fails, explain it in plain words
   (the tool returns `fix`) and offer **Resume** (restarts from the failed step only). Manual steps (e.g. Clear Managed
   Platform Cache) are shown as "do in CMT Administration" with the help link.
8. **Test Enterprise Quote** – `preview_esm_price` with one simple offer (ask which; or the first active offer the tool
   suggests) → show the price breakdown → on approval `mode=commit` keeps it as "Codey Test Quote <date>".
9. **Health check** – run the *settings-health-check* skill and include the counts in the summary.

## Verification
- Every step's tool returned success; admin-job tracker is *Completed* (manual steps confirmed).
- Test quote exists and has a total price > 0 (or the person accepted a zero-price offer).
- Health check has no *Needs Fix* items, or each remaining one is accepted by the person.

## Failure handling
- Package/licence missing → escalate (cannot be fixed by the agent).
- A job running already → do not start another; track it.
- Data pack errors → show the failing pack and record, suggest re-running that pack only.

## Result
`Done: ESM ready on <org>; packs <n>; permission sets <n users>; admin jobs <n> completed; test quote <name> <total>.`
Help: [Download and migrate configuration packs](https://help.salesforce.com/s/articleView?id=ind.comms_download_and_migrate_enterprise_sales_management_datapacks_to_a_summer_23_org.htm&type=5) ·
[Run maintenance jobs](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5) ·
[Google Maps key](https://help.salesforce.com/s/articleView?id=ind.comms_create_and_add_your_google_maps_api_key.htm&type=5) ·
[Console: enhanced event handling](https://help.salesforce.com/s/articleView?id=ind.comms_esm_enable_enhanced_event_handling.htm&type=5) ·
[Console: app visibility by profile](https://help.salesforce.com/s/articleView?id=ind.comms_esm_enable_app_visibility_profile.htm&type=5)
