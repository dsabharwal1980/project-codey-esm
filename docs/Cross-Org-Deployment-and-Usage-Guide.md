# Project Codey – ESM Ease of Build
## Cross-Org Deployment & Usage Guide

| | |
|---|---|
| Product | Project Codey – Enterprise Sales Management (ESM) Ease of Build (PRD ESM-268) |
| Deliverables | 8 skills · master playbook + 11 runbooks · 3 knowledge packs · 9 MCP tools (3 PRD agent tools) · 4 HXL experience cards · Agentforce agent `ESM_Codey` · ESM Coworker extension · Codey Setup app · knowledge MCP server |
| Reference org | `esm264` (Communications Cloud / Vlocity CMT 900.665, OmniStudio 264.11, API 68) |
| Audience | Implementation consultants, Salesforce admins, solution architects, support teams who bring Codey to another org |

---

## 1. What you get

| Building block | What it is | Where |
|---|---|---|
| **Playbook** | Master instructions for every AI surface: routing (request → skill), golden rules (preview → approve → commit, sandbox by default, secrets never in chat), tools, cards, escalation | `playbook/PLAYBOOK.md` |
| **11 runbooks** | One per PRD user story (US-01 … US-11): flow, acceptance criteria, test script, evidence | `playbook/runbooks/` |
| **8 skills** | fresh-install, settings-health-check, permissions, upgrade-check, concepts-guide, pricing, customization, bulk-members – plain step-by-step instructions | `skills/<name>/SKILL.md` |
| **3 knowledge packs** | Concepts pack, Recommended settings pack, Release change list | `knowledge/` → in the org as Static Resources + Custom Metadata |
| **9 MCP tools** | Apex invocable tools exposed by the Salesforce Hosted MCP server `EsmCodeyEaseOfBuild` and as Agentforce actions | `force-app/.../classes/Codey*Tool.cls`, `tools/` |
| **4 HXL cards** | Approval, Health check report, Progress tracker, Upgrade impact report – UiWidgetBundles + Lightning Types; JSON schema + Slack / Teams / Markdown renderings for other surfaces | `force-app/.../uiWidgets`, `lightningTypes`, `hxl/` |
| **Agentforce agent** | `ESM_Codey` (Agent Script): router + 8 subagents = 8 skills | `force-app/.../aiAuthoringBundles/ESM_Codey` |
| **ESM Coworker extension** | A `build` subagent added to an existing ESM Coworker so it gets the same skills/tools/playbook | `adapters/coworker/`, `scripts/merge-coworker.py` |
| **Codey Setup app** | Lightning app: health check, upgrade impact, **secure Google Maps key form**, change log and jobs | `lwc/codeySetup`, `lwc/codeyCard`, app `Codey_Setup` |
| **Knowledge MCP server** | Optional Node MCP server: skills as prompts, packs as resources, `render_codey_card` | `mcp-server/` |

The **9 tools**:

| MCP tool | Apex class | Reads / changes | Card |
|---|---|---|---|
| `get_codey_playbook` | CodeyPlaybookTool | read | – |
| `check_esm_setup` | CodeyHealthCheckTool | read | Health check report |
| `manage_esm_permissions` | CodeyPermissionsTool | preview / commit | Approval |
| `apply_esm_change` | CodeyApplyChangeTool | preview / commit / undo | Approval |
| `run_esm_admin_jobs` (**PRD tool 1**) | CodeyAdminJobsTool + CodeyAdminJobRunner | preview / commit / status | Approval → Progress tracker |
| `preview_esm_price` (**PRD tool 2**) | CodeyPricePreviewTool | read (rolled back); commit keeps a test quote | price breakdown |
| `check_quote_members_bulk` (**PRD tool 3**) | CodeyBulkCheckTool + CodeyBulkCheckBatch | preview / commit / status | Approval → Progress tracker |
| `check_esm_upgrade_impact` | CodeyUpgradeImpactTool | read | Upgrade impact report |
| `track_codey_job` | CodeyTrackJobTool | read | Progress tracker |

---

## 2. How it fits together

```
Where people ask:   Slack · Teams · Claude / Claude Code · ChatGPT · Vibes · Cursor · Agentforce (Lightning) · ESM Coworker
                          │ load the playbook + skill (repo files, knowledge MCP prompts, or get_codey_playbook)
                          ▼
Agent:              picks the skill (routing table) → follows its steps → golden rules
                          │
                          ▼
Tools:              Salesforce Hosted MCP "EsmCodeyEaseOfBuild"  ⇄  same Apex as Agentforce actions (apex://Codey*Tool)
                          │ runs as the signed-in user (with sharing, USER_MODE writes)
                          ▼
Customer org:       ESM / CPQ settings · permission sets · CMT admin jobs · pricing plan · rules · quote members
                    Codey_Change_Log__c (every read, preview, approval, commit, undo) · Codey_Job__c (progress, resume)
                          │
                          ▼
Screens:            CodeyCard → HXL widgets (Lightning, Agentforce, Slack via Agentforce) · render_codey_card → Slack Block Kit / Teams Adaptive Card / Markdown
```

**Approval gate (built into the tools, not only the instructions):** a preview writes a Change Log record with a token =
SHA-256(tool + user + inputs), valid 30 minutes. A commit is refused unless the same user sends the same token **and the same
inputs**. In a production org a commit also needs `confirmProduction=true`. So nothing is saved without a preview the person saw.

---

## 3. Prerequisites in the target org

| # | Requirement | How to check | Notes |
|---|---|---|---|
| 1 | Communications Cloud (Vlocity CMT, namespace `vlocity_cmt`) with Enterprise Sales Management licences | Setup → Installed Packages; `check_esm_setup scope=prereq` after deploy | Codey references CMT global classes (admin jobs, cart actions, Integration Procedure service) – the deploy fails without the package. |
| 2 | OmniStudio (managed `omnistudio` or standard runtime) | Installed Packages | ESM screens and Integration Procedures. |
| 3 | `EnterpriseQuote` (Quote) and `EnterpriseOrder` (Order) record types, a price list and pricing plan | Health check prereq items | Loaded by the ESM configuration packs (data packs). |
| 4 | API version 68 (UiWidgetBundle, McpServerDefinition, AiAuthoringBundle) | `sf org display` → API version | Without 68: deploy core only (steps 1) and use text cards; the MCP server needs Hosted MCP. |
| 5 | **Salesforce Hosted MCP Servers** enabled (for Claude / ChatGPT / Cursor / Vibes / Slack apps) | Setup → search "MCP" | Without it, use Agentforce / Coworker surfaces only. |
| 6 | **Agentforce** enabled with Agent Script (AiAuthoringBundle) | `sf org list metadata -m AiAuthoringBundle` works | For the `ESM_Codey` agent and the Coworker extension. |
| 7 | (Optional) ESM New Experience + ESM Coworker (`ESM_Coworker` agent, `ESM_Coworker_Access`) | Agents list | Only for the Coworker extension. |
| 8 | Deploying user: System Administrator (Modify All Data, Customize Application, Author Apex) | – | Production deploys run the Codey tests (≥ 75% per class; they reach 80–100%). |
| 9 | Tools on your machine: Salesforce CLI (`sf` ≥ 2.100), Python 3.9+, Node 18+ (knowledge server only), git | `sf --version` | – |

**Sandbox first.** Deploy and test in a sandbox (fresh, upgraded, heavily customized – the PRD test strategy) before production.

---

## 4. Get the repository

```bash
git clone https://github.com/<owner>/project-codey-esm.git
cd project-codey-esm
sf org login web -a target-org -r https://test.salesforce.com      # or use your existing alias
```

Repository map: see `README.md`. Everything in `force-app/` is generated or hand-written source; `scripts/` builds the generated
parts from the Markdown/JSON source of truth (skills, playbook, packs).

---

## 5. Deploy – step by step

### 5.1 One command
```bash
bash scripts/deploy.sh target-org --check-only        # validate everything first (no changes)
bash scripts/deploy.sh target-org                     # deploy core, cards, MCP server, publish + activate ESM_Codey
bash scripts/deploy.sh target-org --with-coworker     # also extend an existing ESM Coworker
```

### 5.2 What the script does (run by hand if you prefer)

| Step | Command (summary) | Result |
|---|---|---|
| 0. Build | `python3 scripts/build-static-resources.py`, `build-cmdt.py`, `build-hxl.py`, `build-agents.py`, `build-mcp.py` | Static Resources from the Markdown, Custom Metadata from the packs, HXL widgets, Agent Script, MCP definition |
| 1. Core | `sf project deploy start -d objects -d customMetadata -d staticresources -d classes -d customPermissions -d permissionsets -d lwc -d tabs -d applications --test-level RunSpecifiedTests --tests CodeyCoreTest --tests CodeyToolsTest --tests CodeyJobsTest` | `Codey_Job__c`, `Codey_Change_Log__c`, 4 CMDT types + records, 3 Static Resources, 23 Apex classes + 4 test classes (23 tests), permission sets `ESM_Codey_User` / `ESM_Codey_Admin`, custom permission `Codey_Admin`, Codey Setup app |
| 2. HXL cards | `sf project deploy start -d uiWidgets -d lightningTypes --api-version 68.0` | `codeyApproval`, `codeyHealthReport`, `codeyProgress`, `codeyUpgradeImpact` + `codey*Result`, `codeyToolOutputValues` |
| 3. MCP server | `sf project deploy start -d mcpServerDefinitions --api-version 68.0` | Hosted MCP server **ESM Codey Ease of Build** with the 9 tools |
| 4. Agent | deploy `aiAuthoringBundles/ESM_Codey` → `sf agent validate authoring-bundle --api-name ESM_Codey` → `sf agent publish authoring-bundle --api-name ESM_Codey` → `sf agent activate --api-name ESM_Codey` | Employee agent `ESM_Codey` |
| 5. Coworker (optional) | retrieve `AiAuthoringBundle:ESM_Coworker` (draft) → `python3 scripts/merge-coworker.py …/ESM_Coworker.agent` → deploy → validate → publish → activate | New Coworker version with the `build` subagent; previous version kept for rollback |

**Order matters:** Apex before the MCP server and agent (they reference the classes); Lightning Types after `CodeyCard` exists.

**Publishing agents without the CLI compiler.** `sf agent validate/publish authoring-bundle` call the Agentforce authoring service
(`api.salesforce.com/einstein/ai-agent/...`). If your network blocks it (seen as `fetch failed` / proxy 502), deploy the draft bundle
with `sf project deploy start -d force-app/main/default/aiAuthoringBundles/ESM_Codey --api-version 68.0`, then open
**Agentforce Studio → Agents → ESM Codey** (new Agentforce Builder), check *Errors: 0*, click **Commit Version** → **Commit**, then
**Activate** → **Activate**. Same for the Coworker (a new version number is created; the previous one stays for rollback).
Verify: `SELECT VersionNumber, Status FROM BotVersion WHERE BotDefinition.DeveloperName = 'ESM_Codey'`.
Test without the UI from Apex: `Invocable.Action.createCustomAction('generateAiAgentResponse', 'ESM_Codey')` with `userMessage`.

### 5.3 Common deploy errors

| Error | Cause | Fix |
|---|---|---|
| `Entity type 'UiWidgetBundle' is not available in this api version` | API < 68 | Add `--api-version 68.0` (org must support it) |
| `Method is not visible: vlocity_cmt.<Class>.<init>()` | A CMT job class is not global in this package version | Set that job to `mode: manual` in `knowledge/recommended-settings.json`, re-run `build-cmdt.py`, remove its line from `CodeyAdminJobRunner.LiveStarter` |
| `Value too long for field: Description maximum length is:255` (MCP server) | Edited server description | Keep ≤ 255 chars (`build-mcp.py` asserts it) |
| Test failures on Quote / QuoteMember inserts | Org automation (validation rules, triggers) on Quote | Make the test data in `CodeyTestData` satisfy them, or deploy to a sandbox with the automation |
| `no ApexClass named … found` in permission sets | Class metadata missing | Every `.cls` needs its `.cls-meta.xml` |
| Agent publish: `Internal Error` | Action missing `outputs:` or an input name differs from the Apex variable | Re-generate with `build-agents.py` (names come from one spec) |

---

## 6. Connect the surfaces (MCP access)

### 6.1 External Client App per surface (per-user OAuth)
For each MCP client (Claude, ChatGPT, Cursor/Vibes, Slack app, Teams bot) create an **External Client App** in the target org
(Setup → External Client App Manager → New). In the reference org these are `ESM_MCP_Claude` and `ESM_MCP_Slack`; copy their settings:

| Setting | Value |
|---|---|
| Distribution | Local |
| OAuth | Enabled; **Callback URL** = the redirect URL your client shows (e.g. Claude / ChatGPT connector callback, `http://localhost:<port>/oauth/callback` for `mcp-remote`) |
| OAuth scopes | The scopes required by Salesforce Hosted MCP Servers (API access, refresh token / offline access, and the MCP / platform API scope listed in the Salesforce Hosted MCP help) |
| Security | PKCE required; refresh token valid until revoked (or your policy) |
| Policies | Permitted users: admin-approved; add the profiles / permission sets of Codey users |

Then open **Setup → MCP Servers → ESM Codey Ease of Build**, copy the **server URL**, and give the client the URL + the External
Client App's consumer key. Each person logs in as themselves; tools run with their permissions.

### 6.2 Surface by surface
| Surface | Do this | Details |
|---|---|---|
| Claude Code | `bash adapters/claude-code/install-skills.sh`; `claude mcp add --transport http esm-codey <URL>`; optional `claude mcp add codey-knowledge -- node mcp-server/src/index.js`; add `adapters/claude-code/CLAUDE.md` | `adapters/claude-code/` |
| Claude Desktop / claude.ai | merge `adapters/claude-desktop/claude_desktop_config.json` / add a custom connector | `adapters/claude-desktop/` |
| ChatGPT | Developer mode connector (URL + OAuth) or custom GPT with `adapters/chatgpt/instructions.md` + knowledge files | `adapters/chatgpt/` |
| Slack | Agentforce in Slack for `ESM_Codey` (recommended) or a Slack app with the Hosted MCP + `render_codey_card format=slack` | `adapters/slack/` |
| Microsoft Teams | Bot calling the Hosted MCP; cards via `render_codey_card format=adaptive` | `adapters/teams/` |
| Agentforce Vibes | `.vscode/mcp.json` + rules file | `adapters/vibes/` |
| Cursor | `.cursor/mcp.json` + `.cursor/rules/codey.mdc` | `adapters/cursor/` |
| Agentforce (Lightning, mobile) | Publish/activate `ESM_Codey`; add to the Agentforce panel | `adapters/agentforce/` |
| ESM Coworker | `bash scripts/deploy.sh target-org --with-coworker` | `adapters/coworker/` |

---

## 7. Permissions and users

| Permission set | For | Gives |
|---|---|---|
| `ESM_Codey_User` | Everyone who uses Codey (any surface, incl. Coworker) | All Codey Apex classes, read/create Change Log + Jobs, Custom Metadata read, Codey Setup app |
| `ESM_Codey_Admin` | Admins / consultants | + view/modify all logs and jobs, custom permission `Codey_Admin` (secure Google Maps key form) |

```bash
bash scripts/assign-perms.sh target-org consultant@acme.com admin
bash scripts/assign-perms.sh target-org rep1@acme.com,rep2@acme.com
```
Codey never grants more than the person has: changes also need the normal ESM / CPQ rights (e.g. permission to edit CPQ
settings, to assign permission sets, to run CMT admin jobs). Then let Codey give the ESM permission sets per user type
("Give the new sales team access") with the permissions skill.

---

## 8. Tune the knowledge packs to the target org (no code)

| Pack | Edit | Then |
|---|---|---|
| Recommended settings | `knowledge/recommended-settings.json` – settings (source, target, operator `equals / notBlank / exists / gte / lte / between / ranWithinDays / manual`, recommended, severity, reason, help link, fixable, secret), **user types → permission sets**, **admin jobs** (order, mode `batch / service / manual`, class, batch size, groups) | `python3 scripts/build-cmdt.py` → deploy `customMetadata` |
| Concepts pack | `knowledge/concepts-pack.md` (`## key` sections) | `python3 scripts/build-static-resources.py` → deploy `staticresources` |
| Release change list | `knowledge/release-change-list.json` – per release: component pattern (FlexCard / OmniScript / IntegrationProcedure), change, risk, advice | same as above. **The shipped list is a seed with sample entries – load the official list for each release.** |
| Playbook / skills / runbooks | Markdown files | `build-static-resources.py` (+ `build-agents.py` if you change agent steps) → deploy |

Checklist for a new org:
1. Permission set names per user type match the org (namespaced ones as `vlocity_cmt.Name`).
2. CPQ setting keys exist in this CMT version (e.g. the Google Maps key setting name – rule `Q_GOOGLE_MAPS`).
3. Admin jobs: every `batch` / `service` job is global in this CMT version (see §5.3); others `manual` with the CMT Administration path.
4. Console app name (rule `C_APP`) matches the org's ESM console app.
5. Owners: product team reviews the settings pack every release; release team publishes the release change list.

### 8.1 Address and serviceability provider (`Codey_Check_Provider__mdt.Default`)
| Mode | Behaviour | Use when |
|---|---|---|
| `Builtin` (shipped) | Address completeness + postal-code format per country; serviceability read from data already on the member | No external services yet; demos |
| `IntegrationProcedure` | Calls the ESM Integration Procedures (`ESM_checkAddressValidation`, `ESM_checkServiceQualificationV2`, configurable) that call your address / qualification services, then reads the results from the members | Production – your TMF endpoints configured in the IPs |
| `ApexClass` | Your class implementing `CodeyBulkCheck.Provider` | Any other service |
Batch size (default 200) and "write results to members" are on the same record.

---

## 9. Verify the installation

1. `bash scripts/smoke-test.sh target-org <an Enterprise Quote Id>` – read-only calls of every tool through the REST action endpoint.
2. App Launcher → **Codey Setup** → *Run health check* → the Health check report card renders; *Activity* shows the read.
3. Agentforce: `sf agent preview start --api-name ESM_Codey -o target-org`, then send "Check if my setup is correct".
4. MCP: in Claude Code, `/mcp` shows `esm-codey` with 9 tools; ask "What can Codey do?" then "Check my ESM settings".
5. Walk the 11 runbooks (`playbook/runbooks/US-xx.md`) and record evidence in `docs/test-results.md`.

Acceptance (PRD → proof):
| Story | Proof |
|---|---|
| US-01 Fresh install | prereq OK → install plan approved → permissions, Console, Maps key (secure page), admin jobs Completed, test quote priced, health check 0 Needs Fix |
| US-02 Health check | report < 2 min with reasons + help links incl. assets & performance; a fix only after approval |
| US-03 Permissions | missing sets per user type shown; assigned after approval; re-check OK |
| US-04 Admin jobs | documented order; progress; plain-language failure; resume from the failed step |
| US-05 Upgrade | customized screens with change, risk, action; merged version only as a suggestion |
| US-06 Data model | short answer with the org's own counts + help link |
| US-07 Pricing | plan explained step by step; change previewed with price effect; applied; tested; undo |
| US-08 Bulk members | file checked before load; background checks with progress; results file with reasons |
| US-09 Promotions & discounts | comparison + which applied on a sample quote and why |
| US-10 Linear relationships | scenarios explained; relationship previewed, approved, checked |
| US-11 QMB / context rules / Enrich Quote | drafted, previewed, approved, turned on (2nd approval), tested on sample members |
| Safety | every Committed Change Log has an earlier Previewed log with the same token and user |

---

## 10. Using Codey (sample requests)

| Ask | What happens |
|---|---|
| "Install Enterprise Sales Management on my new sandbox." | Fresh-install skill: prereqs → plan → approvals → progress → test quote → health check |
| "Check if my setup is correct." | Health check report; Fix it → Approval → re-check |
| "Give the new sales team access – profile Sales User." | Missing permission sets per user → Approval → assigned → re-check |
| "Run the admin jobs." / "Products look stale." | Admin-jobs preview → Approval → Progress tracker → resume on failure |
| "What will the next upgrade affect?" | Upgrade impact report (High first) |
| "Explain the difference between a Quote Member and a quote line item, using quote Acme Retail 60 sites." | Concept + real counts + help link |
| "Explain our price plan." / "Add a regional surcharge step at sequence 45." | Steps listed; change + price effect previewed; applied after approval; tested |
| "Which promotions and discounts applied on quote Q-00123 and why?" | Price breakdown per step |
| "Only allow Fibre 1G at sites in the North region." | Context rule drafted (inactive) → approval → turn on (2nd approval) → test |
| "Load these 4,000 sites onto this quote and check them." (attach CSV) | File check → Approval → background load + checks → results file |

---

## 11. Operating Codey

| Topic | Practice |
|---|---|
| Audit & usage tracking | `Codey_Change_Log__c`: tool, change type, target, status (Previewed / Committed / Failed / Rejected / Undone / Expired), before / after, approver, surface, production flag. Build reports on it (skill runs, approvals, errors) – PRD success measures. |
| Long jobs | `Codey_Job__c` – status, steps, progress, resume cursor, results file. One job per quote and tool at a time. |
| Undo | `apply_esm_change changeType=undo target=CL-…` (preview + approval) restores the previous value or deletes what was created. |
| Each release | Product team updates the Recommended settings pack; release team publishes the Release change list; re-run `build-*` scripts, deploy, re-publish agents. Re-run the 11 runbooks in a sandbox (PRD test strategy). |
| Secrets | Only through the Codey Setup page (masked, `Codey_Admin`), never in chat or tool inputs; tools refuse secret-like settings; logs store "set / not set" only. |
| Data protection | Member addresses stay in the org; results files are Salesforce Files on the quote. |

---

## 12. Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| "No preview token" / "inputs are not the same" / "preview expired" | Commit without a matching preview | Run the preview again, approve, commit with the same inputs within 30 min |
| "This is a PRODUCTION org" | Production guard | Confirm with the person, repeat commit with `confirmProduction=true` |
| Health check items "could not read" | User lacks read on CMT config objects | Assign the CMT admin / Codey admin permission sets |
| Admin job step "could not start" | Job class not global / no access | Mark it `manual` in the pack or assign CMT admin rights; resume |
| Price preview "has no active entry in price list" | Product not in the price list's pricebook | Pick a priced product or the right price list |
| Price preview error about callouts / uncommitted work | A package action does a callout after DML | Use `quoteId` to explain an existing quote instead; report the action |
| Bulk check serviceable = Unknown | Provider `Builtin` | Switch the provider to `IntegrationProcedure` with configured endpoints |
| Upgrade report empty | No customized components match the release list | Check the list patterns; `includeStandard=true` to see matches |
| MCP client sees no tools | ECA scopes / permitted users, or the server not deployed | Re-check §6.1; Setup → MCP Servers |
| Agent answers but cannot act | User lacks `ESM_Codey_User` | Assign it; employee agents run as the user |

---

## 13. Rollback / uninstall

1. Deactivate `ESM_Codey`; for the Coworker, activate the previous version (it is kept).
2. Delete the MCP server definition (Setup → MCP Servers) and the External Client Apps you created.
3. Remove permission set assignments, then delete (destructive deploy) in this order: agents → MCP server → Lightning Types → UiWidgets →
   app/tabs/LWCs → permission sets → Apex classes → Custom Metadata records/types → Static Resources → custom objects.
Settings Codey changed stay as they are; use the Change Log (before values) to revert any of them first (`undo`).

---

## 14. Security notes
- Runs with the asking user's permissions (`with sharing`, USER_MODE DML); no system-mode writes to business data.
- Sandbox by default; production needs explicit confirmation on every commit; all actions logged.
- Secrets are never in chat, tool inputs, logs or this repo.
- Approval is enforced server-side (token + identical inputs + same user + expiry), not only by prompt instructions.

## Appendix A – Component inventory
| Type | Names |
|---|---|
| Apex (tools) | CodeyPlaybookTool, CodeyHealthCheckTool, CodeyPermissionsTool, CodeyApplyChangeTool, CodeyAdminJobsTool, CodeyAdminJobRunner, CodeyPricePreviewTool, CodeyBulkCheckTool, CodeyBulkCheckBatch, CodeyBulkCheck, CodeyUpgradeImpactTool, CodeyTrackJobTool |
| Apex (shared / UI) | CodeyCore, CodeyResult, CodeyCard, CodeyCardItem, CodeyCardStat, CodeyCardButton, CodeyCards, CodeyCsv, CodeySetupController, CodeySecureSettingController |
| Apex tests | CodeyTestData, CodeyCoreTest, CodeyToolsTest, CodeyJobsTest (23 tests) |
| Objects | Codey_Job__c, Codey_Change_Log__c |
| Custom Metadata | Codey_Recommended_Setting__mdt (51), Codey_UserType_Permission__mdt (7), Codey_Admin_Job__mdt (9), Codey_Check_Provider__mdt (1) |
| Static Resources | Codey_Playbook, Codey_Concepts_Pack, Codey_Release_Change_List |
| HXL | UiWidgetBundle codeyApproval, codeyHealthReport, codeyProgress, codeyUpgradeImpact; LightningTypeBundle codey*Result, codeyToolOutputValues |
| MCP | McpServerDefinition EsmCodeyEaseOfBuild (9 tools) |
| Agentforce | AiAuthoringBundle ESM_Codey; Coworker `build` subagent |
| UI | LWC codeyCard, codeySetup; tab Codey_Setup + object tabs; app Codey_Setup |
| Access | Permission sets ESM_Codey_User, ESM_Codey_Admin; custom permission Codey_Admin |
