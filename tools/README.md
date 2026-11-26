# Codey MCP tools – developer notes

All tools are Apex `@InvocableMethod` classes exposed by the Salesforce Hosted MCP server **EsmCodeyEaseOfBuild** (`apiSource=API_CATALOG`, `aa:apex-<Class>`) and, with identical inputs/outputs, as Agentforce actions (`apex://<Class>`). They run `with sharing` as the signed-in user; writes use `AccessLevel.USER_MODE`.

**Common output (`CodeyResult`)**: `success`, `mode` (read/preview/commit/status), `message`, `previewToken`, `resultJson`, `jobId`, `changeLogId`, `nextStep`, `fix`, `card` (`CodeyCard`, see hxl/cards/codey-card.schema.json).

**Approval gate**: a preview stores a `Codey_Change_Log__c` (Status Previewed, 30-minute expiry) with token = SHA-256(tool | user | normalised inputs). A commit must send that token and the same inputs (re-hashed) as the same user; otherwise it is refused. Production orgs also require `confirmProduction=true`. Every read and change is logged (PRD usage tracking).

| Tool | Apex class | Card | Notes |
|---|---|---|---|
| `get_codey_playbook` | `CodeyPlaybookTool` | – |  |
| `check_esm_setup` | `CodeyHealthCheckTool` | Health check report |  |
| `manage_esm_permissions` | `CodeyPermissionsTool` | Approval |  |
| `apply_esm_change` | `CodeyApplyChangeTool` | Approval |  |
| `run_esm_admin_jobs` | `CodeyAdminJobsTool` | Approval (preview) / Progress tracker | PRD agent tool 1 – Admin jobs tool |
| `preview_esm_price` | `CodeyPricePreviewTool` | Approval-style price breakdown | PRD agent tool 2 – Price preview tool |
| `check_quote_members_bulk` | `CodeyBulkCheckTool` | Approval (preview) / Progress tracker | PRD agent tool 3 – Bulk address and serviceability tool |
| `check_esm_upgrade_impact` | `CodeyUpgradeImpactTool` | Upgrade impact report |  |
| `track_codey_job` | `CodeyTrackJobTool` | Progress tracker |  |

## Inputs per tool

### get_codey_playbook

Read-only. CALL THIS FIRST in a new conversation about Enterprise Sales Management (ESM) setup. Returns the Project Codey playbook (routing, golden rules), a skill (topic=skill:fresh-install|settings-health-check|permissions|upgrade-check|concepts-guide|pricing|customization|bulk-members), a runbook (runbook:US-01..US-11), a concept (concept:<key>, add quoteId for real examples from the org), the recommended settings (settings) or the release change list (releases); topic=index lists all. Follow the skill it routes to. Golden rules: look first; every change is mode=preview, show the Approval card, wait for an explicit yes, then mode=commit with the previewToken and the SAME inputs; secrets never in chat; keep replies short.

| Input | Type | Required | Description |
|---|---|---|---|
| `topic` | string |  | overview, routing, rules, skill:<name>, runbook:US-01..US-11, concept:<key> or concept:all, settings, releases, index. |
| `quoteId` | string |  | Optional quote Id or name for real examples in concept answers. |
| `surface` | string |  | Where the request comes from, for example Agentforce or Coworker. |

### check_esm_setup

Read-only ESM settings health check (about 1 minute). scope: all (default), prereq (fresh-install prerequisites), quoting, assets (add assets to quote), performance, console, permissions, adminjobs. Returns each item as OK / Warning / Needs Fix with the reason, current vs recommended value (secrets masked), a help link and a Fix it message, plus a Health check report card. Nothing changes. Offer fixes one by one; each fix is a preview the person approves (apply_esm_change, manage_esm_permissions or run_esm_admin_jobs).

| Input | Type | Required | Description |
|---|---|---|---|
| `scope` | string |  | all (default), prereq, quoting, assets, performance, console, permissions or adminjobs. |
| `surface` | string |  | Where the request comes from. |

### manage_esm_permissions

Give ESM users the recommended permission sets for their user type (Sales rep, Sales manager, Admin, Pricing admin, Product designer, Service agent, Coworker user). Inputs: userType, users (usernames, e-mails, names or Ids) or profile / role. ALWAYS mode=preview first: the Approval card lists per user what is missing. Only after the person explicitly approves, call mode=commit with the previewToken and the same inputs. Only adds, never removes. Production orgs also need confirmProduction=true after the person confirms.

| Input | Type | Required | Description |
|---|---|---|---|
| `mode` | string |  | preview (default) or commit after the person approved. |
| `userType` | string | yes | Sales rep, Sales manager, Admin, Pricing admin, Product designer, Service agent or Coworker user. |
| `users` | string |  | Comma-separated usernames, e-mails, names or Ids. |
| `profile` | string |  | Profile name. |
| `role` | string |  | Role name. |
| `previewToken` | string |  | Token from the preview, for commit. |
| `confirmProduction` | boolean |  | true only if the person confirmed a production change. |
| `surface` | string |  | Where the request comes from. |

### apply_esm_change

Approved ESM configuration change with Before/After preview and undo. changeType: cpqSetting or enrichQuoteOption (target=setting name, value), generalSetting, pricingPlanStep (fieldsJson name, sequence, implementation, method, parameters, active; recordId to update), contextRule (fieldsJson name, ruleset, product, expression, failureMessage; created inactive), contextRuleset, attributeBinding (Quote Member Binding: attribute, objectClass, fieldApiName), linearRelationship (product, relatedProduct, relationshipType), record (allow-listed ESM objects), undo (target=change log CL-...). ALWAYS mode=preview, show the Approval card, wait for an explicit yes, then mode=commit with previewToken and the same inputs. Never pass secrets (keys) – they go through the secure Codey Setup page.

| Input | Type | Required | Description |
|---|---|---|---|
| `mode` | string |  | preview (default) or commit after the person approved. |
| `changeType` | string | yes | cpqSetting, enrichQuoteOption, generalSetting, pricingPlanStep, contextRule, contextRuleset, attributeBinding, linearRelationship, record or undo. |
| `target` | string |  | Setting name, object API name (record) or change log CL-... (undo). |
| `value` | string |  | New setting value. |
| `fieldsJson` | string |  | JSON with the fields for record changes. |
| `recordId` | string |  | Existing record to update. |
| `reason` | string |  | Why the change is made. |
| `previewToken` | string |  | Token from the preview, for commit. |
| `confirmProduction` | boolean |  | true only if the person confirmed a production change. |
| `surface` | string |  | Where the request comes from. |

### run_esm_admin_jobs (PRD agent tool 1 – Admin jobs tool)

ESM admin (maintenance) jobs in the documented order with progress. jobs: default (recommended), catalog, pricing, promotions, repair, or job keys. mode=preview lists the jobs (automatic and manual steps); after the person approves, mode=commit with previewToken and same inputs starts them in the background and returns a jobId and a Progress tracker card. mode=status (jobId) shows progress and plain-language errors. A failed run resumes from the failed step: mode=preview with jobId, approval, then mode=commit with jobId. Only one run at a time.

| Input | Type | Required | Description |
|---|---|---|---|
| `mode` | string |  | preview (default), commit after approval, or status. |
| `jobs` | string |  | default, catalog, pricing, promotions, repair or job keys. |
| `jobId` | string |  | Codey job id for status or resume. |
| `previewToken` | string |  | Token from the preview, for commit. |
| `confirmProduction` | boolean |  | true only if the person confirmed running jobs in production. |
| `surface` | string |  | Where the request comes from. |

### preview_esm_price (PRD agent tool 2 – Price preview tool)

Price a sample quote WITHOUT saving anything (rolled back): products (names/codes/Ids), optional quantity, account, priceList. Returns total, price per line, every pricing step (list price, promotions, discounts, manual adjustments) and the promotions and discounts applied. explainPlan=true lists the pricing plan steps in order. quoteId (without products) explains an existing quote's prices read-only. proposedStepJson simulates a new pricing plan step: before vs after. mode=commit (after approval, same inputs + previewToken) keeps the sample as a test quote (fresh install).

| Input | Type | Required | Description |
|---|---|---|---|
| `mode` | string |  | preview (default) or commit to keep a test quote after approval. |
| `products` | string |  | Comma-separated product names, codes or Ids. |
| `quantity` | integer |  | Quantity per product. |
| `account` | string |  | Account Id or name. |
| `priceList` | string |  | Price list name. |
| `quoteId` | string |  | Existing quote to explain (read-only). |
| `explainPlan` | boolean |  | true to list the pricing plan steps. |
| `proposedStepJson` | string |  | Pricing plan step JSON to simulate. |
| `previewToken` | string |  | Token from the preview, for commit. |
| `confirmProduction` | boolean |  | true only if the person confirmed in production. |
| `surface` | string |  | Where the request comes from. |

### check_quote_members_bulk (PRD agent tool 3 – Bulk address and serviceability tool)

Load many quote members from a spreadsheet and check addresses and serviceability in the background (10,000+ members, batches, retries, resume). Inputs: quoteId (Id or name), membersCsv (header row: name/site, street/address, city, state, postal code/zip, country – read the attached spreadsheet and pass its rows) or contentDocumentId (069...), checks (address, serviceability; none to only load). ALWAYS mode=preview first (columns, rows to load, duplicates, rows with errors); after the person approves, mode=commit with previewToken and same inputs. Then track_codey_job; when done share the results file.

| Input | Type | Required | Description |
|---|---|---|---|
| `mode` | string |  | preview (default), commit after approval, or status. |
| `quoteId` | string | yes | Enterprise Quote Id or name. |
| `membersCsv` | string |  | CSV text with a header row (name/site, street/address, city, state, postal code, country). |
| `contentDocumentId` | string |  | ContentDocument Id (069...) of an attached CSV. |
| `checks` | string |  | address, serviceability, or none. |
| `onlyUnchecked` | boolean |  | false to re-check every member. |
| `jobId` | string |  | Codey job id for status or resume. |
| `previewToken` | string |  | Token from the preview, for commit. |
| `confirmProduction` | boolean |  | true only if the person confirmed in production. |
| `surface` | string |  | Where the request comes from. |

### check_esm_upgrade_impact

Read-only upgrade check: which customized ESM screens and procedures (FlexCards, OmniScripts, Integration Procedures) a release affects (targetRelease, default newest in the release change list), what changed, a risk level (High / Medium / Low) and a suggested action, as an Upgrade impact report card. includeStandard=true also lists components that are not customized. Reports only; a combined (merged) version is a suggestion for review and is never deployed without approval.

| Input | Type | Required | Description |
|---|---|---|---|
| `targetRelease` | string |  | Release, for example 268 (default newest). |
| `includeStandard` | boolean |  | true to also list non-customized components. |
| `surface` | string |  | Where the request comes from. |

### track_codey_job

Read-only progress of a Project Codey background job (admin jobs, bulk member checks): jobId (or CJ-... name), or quoteId / tool for the latest job. Returns status, percent done, each step, plain-language errors, the results file link and whether it can resume, as a Progress tracker card. Check about once a minute while running; do not start a second job.

| Input | Type | Required | Description |
|---|---|---|---|
| `jobId` | string |  | Codey job id or CJ-... name. |
| `quoteId` | string |  | Quote Id or name for its latest job. |
| `tool` | string |  | run_esm_admin_jobs or check_quote_members_bulk. |
| `surface` | string |  | Where the request comes from. |

## Errors

Tools never throw to the client: `success=false`, `message` (what happened) and `fix` (plain-language next step). Common: no preview token / inputs changed / preview expired (run preview again); production confirmation needed; missing access (permissions skill); a job already running (track it).

## Configuration (per org, no code change)

- `Codey_Recommended_Setting__mdt` – rules of the health check (source, target, operator, recommended, severity, reason, help link, fixable, secret).
- `Codey_UserType_Permission__mdt` – permission sets per user type.
- `Codey_Admin_Job__mdt` – admin jobs, order, mode (batch / service / manual), class, batch size, groups.
- `Codey_Check_Provider__mdt` – address/serviceability provider: Builtin, IntegrationProcedure (default ESM IPs) or ApexClass implementing `CodeyBulkCheck.Provider`.
- Static Resources `Codey_Playbook`, `Codey_Concepts_Pack`, `Codey_Release_Change_List` – built from the repo (`scripts/build-static-resources.py`).
