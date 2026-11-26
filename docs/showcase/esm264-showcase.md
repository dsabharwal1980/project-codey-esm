# Project Codey – read-only showcase (salesforce-1zm7lm)

Org: **esm264** (Enterprise Edition trial, production-type) · run 2026-11-26 11:58 · quote used for examples: `0Q0Ws00000ALtIHKA1`

Only read / explain calls were made: no previews, no commits, no changes to ESM settings, quotes, products or permissions. Each call adds one usage line (surface "showcase") to the Codey Change Log.

| # | Skill | What it shows | Result |
|---|---|---|---|
| 1 | Playbook | Routing table: which skill answers which request | ✅ Pick ONE skill from the request (routing table of 11 request types → 8 skills). |
| 2 | Playbook | Golden rules every agent follows | ✅ Golden rules – preview → explicit approval → commit, sandbox by default, secrets never in chat, verify, log. |
| 3 | Fresh install (read-only part) | Prerequisite check before an install | ✅ ESM health check: 7 OK, 0 Warning, 0 Needs Fix. Everything matches the recommended settings. |
| 4 | Settings health check | Full health check report: OK / Warning / Needs Fix | ✅ ESM health check: 44 OK, 7 Warning, 0 Needs Fix. |
| 5 | Settings health check | Health check of one area (add assets to quote) | ✅ ESM health check: 4 OK, 0 Warning, 0 Needs Fix. Everything matches the recommended settings. |
| 6 | Permissions (read-only part) | Recommended permission sets per user type and admin jobs (knowledge pack) | ✅ 51 recommended settings, permission sets for 7 user types, 9 admin jobs in documented order. |
| 7 | Permissions (read-only part) | Permission health in the org | ✅ ESM health check: 8 OK, 0 Warning, 0 Needs Fix. Everything matches the recommended settings. |
| 8 | Admin jobs (read-only part) | Admin job history check | ✅ ESM health check: 0 OK, 4 Warning, 0 Needs Fix. |
| 9 | Upgrade check | Customized screens a release affects | ✅ Release 268: 74 affected screens/procedures (11 High, 24 Medium) out of 556 customized ESM/CPQ components checked. Note: the release change list is a seed/sampl |
| 10 | Concepts guide | Quote Member vs quote line item, with real data from a quote | ✅ A Quote Member answers where; a quote line item answers what – with this quote's real counts. |
| 11 | Concepts guide | Data model explained with real data | ✅ Enterprise Quote → Quote Members + Groups → lines → Enterprise Order → sub-orders, with real counts. |
| 12 | Pricing | The pricing plan explained step by step | ✅ Pricing plan (DEFAULT_PRICING_PLAN), 12 steps in order: |
| 13 | Pricing / Promotions & discounts | Prices, promotions and discounts on an existing quote (read-only) | ✅ Whole quote: 10,020 lines, one-time 835,000, recurring 150,300 per month; 84 promotions, 1 discount (fixed – see note) |
| 14 | Customization (read-only part) | Context rules explained + quoting settings they need | ✅ Context rules decide product eligibility by member context (region, technology). |
| 15 | Customization (read-only part) | Quoting settings (context rules, promotions, bulk updates) | ✅ ESM health check: 13 OK, 0 Warning, 0 Needs Fix. Everything matches the recommended settings. |
| 16 | Bulk members (read-only part) | Address and serviceability explained with the quote's numbers | ✅ Address verification and serviceability explained, with the quote's numbers. |
| 17 | Progress tracker | Latest Codey background job (if any) | ℹ️ expected: No Codey job found. |

## Note on step 13 (found during this showcase)
The version of `preview_esm_price` deployed in esm264 builds its totals and counts from the first 200 lines and the first 50 promotions only,
so for this 10,020-line quote it reported "200 lines, 17,000 one-time, 3,060 per month, 50 promotions". The correct whole-quote figures
(read-only query) are **10,020 lines (1,670 offers), 835,000 one-time, 150,300 per month, 84 applied promotions, 1 discount**.
The repository version is fixed (totals and counts always cover the whole quote; step detail stays capped at 200 lines) and validated in
esm264 with a check-only deploy (23/23 tests); it was **deployed on 26 Nov 2026** after your approval; re-check: "Priced 10020 lines (step detail for the first 200): one-time 835,000, recurring 150,300 per month; 84 promotions, 1 discount".

## Cards that need a change to appear

The **Approval** card appears on every preview and the **Progress tracker** on every background job. They were not produced here because that would start a preview or a job. Sample renderings: `hxl/samples/markdown/approval.md` and `hxl/samples/markdown/progress.md` (Slack and Teams versions next to them).


## 1. Playbook – Routing table: which skill answers which request

Tool: `CodeyPlaybookTool` · inputs: `{"topic": "routing"}`

**What the agent gets back (message):**

```
## routing
Pick ONE skill from the request. If two match, take the first in this table; ask one question only if you really cannot tell.

| The person says something like… | Skill | Runbook |
|---|---|---|
| "Install / set up ESM on my sandbox", "new project, get me a working base" | fresh-install | US-01 |
| "Check my settings", "is my setup correct", "why does adding assets fail", "health check" | settings-health-check | US-02 |
| "Give the new sales team access", "user can't see the quote", "which permission sets" | permissions | US-03 |
| "Run the admin jobs", "refresh product JSON / hierarchy", "products or prices look stale" | fresh-install (step admin jobs) – tool `run_esm_admin_jobs` | US-04 |
| "What will the next upgrade affect", "release impact on our customized screens" | upgrade-check | US-05 |
| "Explain Quote Member vs quote line item", "how do EQ and EO fit", any how-it-works question | concepts-guide | US-06 |
| "Explain our price plan", "add a regional surcharge step", "location / attribute / frame contract pricing" | pricing | US-07 |
| "Load these 4,000 sites and check them", "address verification", "serviceability for many members" | bulk-members | US-08 |
| "Which promotions / discounts applied and why", "promotion in the cart vs discount on EQ/EO" | concepts-guide (+ `preview_esm_price`) | US-09 |
| "Linear relationships", "upgrade path between products" | customization | US-10 |
| "Quote Member Binding", "context rule", "only allow this product at sites in the North region", "Enrich Quote options" | customization | US-11 |
```

**Next step suggested:** Follow the steps; every change is preview -> explicit approval -> commit.


## 2. Playbook – Golden rules every agent follows

Tool: `CodeyPlaybookTool` · inputs: `{"topic": "rules"}`

**What the agent gets back (message):**

```
## rules
Golden rules – they apply to every skill and every surface. Never break them, even if asked.

1. **Look before you act.** Start with a read: `check_esm_setup`, `get_codey_playbook`, or a read of the records involved.
2. **Preview → explicit approval → commit.** Every change is two calls: `mode=preview` (show the Approval card: what, before,
   after, how many), wait for a clear "yes / approve" from the person in this conversation, then `mode=commit` with the
   `previewToken` and the SAME inputs. "Reject", silence or a changed request = no commit. A preview token lasts 30 minutes.
3. **Sandbox by default.** Tools tell you when the org is production; production changes need the person to say so
   explicitly (`confirmProduction=true`) after you warn them.
4. **Secrets are never typed in chat.** For the Google Maps key (or any key) send the person to the secure "Codey Setup"
   page (Google Maps key form). Never ask for, repeat or log a key.
5. **Never invent values.** Prices, settings, permission set names, product names come from tools or the knowledge packs.
   If something is unknown, say so and ask.
6. **Safe to run again.** Tools skip what already exists. If a long job stopped, resume it (`mode=commit` with the same
   jobId or `track_codey_job`) – do not start a second one. One job per quote and tool at a time.
7. **Work as the person who asked.** Tools run with that user's permissions; if a tool says "no access", explain which
   permission set is missing (permissions skill) – never work around it.
8. **Show the card, keep text short.** Each tool returns `message`, `nextStep`, `fix` and a `card`. Surfaces that render HXL
   cards show the card; others summarise in at most 5 lines and one table.
9. **Check the result.** After every commit run the check named in the skill (re-read, health check, sample quote) and
   report OK / not OK.
10. **Log.** Every preview and commit is written to the Codey Change Log automatically; mention the log id in the summary.
11. **Upgrades only report and suggest.** Never overwrite a customer customization; a merged version is a suggestion for review.
```

**Next step suggested:** Follow the steps; every change is preview -> explicit approval -> commit.


## 3. Fresh install (read-only part) – Prerequisite check before an install

Tool: `CodeyHealthCheckTool` · inputs: `{"scope": "prereq"}`

**What the agent gets back (message):**

```
ESM health check: 7 OK, 0 Warning, 0 Needs Fix. Everything matches the recommended settings.
```

**Next step suggested:** No action needed.

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### ESM settings health check  `All OK`
_Communications Cloud licence Active · 168 CPQ settings read · Production org · scope Prereq_
**OK:** 7 · **Warning:** 0 · **Needs Fix:** 0

**All checks passed**
- [OK] **Communications Cloud package** — ESM runs on the Communications Cloud (vlocity_cmt) managed package. (Prereq) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_download_and_migrate_enterprise_sales_management_datapacks_to_a_summer_23_org.htm&type=5)
- [OK] **OmniStudio package** — ESM screens and Integration Procedures run on OmniStudio. (Prereq) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_download_and_migrate_enterprise_sales_management_datapacks_to_a_summer_23_org.htm&type=5)
- [OK] **Active price list** — Quotes need at least one active price list. (Prereq) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Pricing plan** — Pricing needs a pricing plan with steps. (Prereq) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Active offers in the catalog** — Configuration packs load the offers you sell; none are active. (Prereq) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_download_and_migrate_enterprise_sales_management_datapacks_to_a_summer_23_org.htm&type=5)
- [OK] **Enterprise Order record type** — Enterprise Orders are Orders with the EnterpriseOrder record type. (Prereq) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Enterprise Quote record type** — Enterprise Quotes are Quotes with the EnterpriseQuote record type. (Prereq) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
_Read-only check. A fix changes nothing until you approve its preview._
**Run again** → reply "Run the ESM settings health check again."


## 4. Settings health check – Full health check report: OK / Warning / Needs Fix

Tool: `CodeyHealthCheckTool` · inputs: `{"scope": "all"}`

**What the agent gets back (message):**

```
ESM health check: 44 OK, 7 Warning, 0 Needs Fix.
```

**Next step suggested:** Offer the fixes: each Fix it starts a preview (apply_esm_change / manage_esm_permissions / run_esm_admin_jobs) that the person must approve.

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### ESM settings health check  `Warnings`
_Communications Cloud licence Active · 168 CPQ settings read · Production org · scope all_
**OK:** 44 · **Warning:** 7 · **Needs Fix:** 0

**Items to look at**
- [Warning] **Product attribute cache ran in the last 30 days** — Run the admin jobs after every catalog or pricing load.  Current: no completed run found · Recommended: within 30 days (AdminJobs) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5)
  - reply: _Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve._
- [Warning] **Product attribute JSON ran in the last 30 days** — Run the admin jobs after every catalog or pricing load.  Current: no completed run found · Recommended: within 30 days (AdminJobs) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5)
  - reply: _Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve._
- [Warning] **Product hierarchy maintenance ran in the last 30 days** — Run the admin jobs after every catalog or pricing load.  Current: no completed run found · Recommended: within 30 days (AdminJobs) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5)
  - reply: _Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve._
- [Warning] **Product versions ran in the last 30 days** — Run the admin jobs after every catalog or pricing load.  Current: no completed run found · Recommended: within 30 days (AdminJobs) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5)
  - reply: _Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve._
- [Warning] **App visibility by profile (check by hand)** — Make the ESM console app visible to the ESM profiles in Setup → App Manager.  Current: check by hand (Console) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_esm_enable_app_visibility_profile.htm&type=5)
  - reply: _Check by hand in Setup: App visibility by profile (check by hand) (see Help)._
- [Warning] **Enhanced event handling (check by hand)** — Set in the console app settings; cannot be read automatically.  Current: check by hand (Console) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_esm_enable_enhanced_event_handling.htm&type=5)
  - reply: _Check by hand in Setup: Enhanced event handling (check by hand) (see Help)._
- [Warning] **Google Maps key** — Maps for quote member addresses need a key. Enter it on the Codey Setup page – never in chat. (Setting key name may differ per release; adjust in this pack.)  Current: (not set) (Console) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_create_and_add_your_google_maps_api_key.htm&type=5)
  - reply: _Open App Launcher → Codey Setup and enter the Google Maps key in the secure form (never in chat)._
_Read-only check. A fix changes nothing until you approve its preview._
**Fix all fixable items** → reply "Preview fixes for all fixable Needs Fix and Warning items from the health check."
**Run again** → reply "Run the ESM settings health check again."


## 5. Settings health check – Health check of one area (add assets to quote)

Tool: `CodeyHealthCheckTool` · inputs: `{"scope": "assets"}`

**What the agent gets back (message):**

```
ESM health check: 4 OK, 0 Warning, 0 Needs Fix. Everything matches the recommended settings.
```

**Next step suggested:** No action needed.

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### ESM settings health check  `All OK`
_Communications Cloud: not checked · 168 CPQ settings read · Production org · scope AddAssets_
**OK:** 4 · **Warning:** 0 · **Needs Fix:** 0

**All checks passed**
- [OK] **Asset reference ids for parent/root** — Adding assets to a quote relies on asset reference ids for the hierarchy. (AddAssets) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_add_assets_to_quote.htm&type=5)
- [OK] **MACD line action status** — Should be set deliberately for MACD quotes. (AddAssets) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_add_assets_to_quote.htm&type=5)
- [OK] **Keep asset price** — Assets added to a quote keep their contracted price. (AddAssets) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_add_assets_to_quote.htm&type=5)
- [OK] **Retain asset price on non-price change** — A non-price change on an asset should not re-price it. (AddAssets) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_add_assets_to_quote.htm&type=5)
_Read-only check. A fix changes nothing until you approve its preview._
**Run again** → reply "Run the ESM settings health check again."


## 6. Permissions (read-only part) – Recommended permission sets per user type and admin jobs (knowledge pack)

Tool: `CodeyPlaybookTool` · inputs: `{"topic": "settings"}`

**What the agent gets back (message):**

```
## recommended-settings
| Area | Setting | Rule | Severity | Why |
|---|---|---|---|---|
| AddAssets | Asset reference ids for parent/root | equals true | NeedsFix | Adding assets to a quote relies on asset reference ids for the hierarchy. |
| AddAssets | MACD line action status | exists | Warning | Should be set deliberately for MACD quotes. |
| AddAssets | Keep asset price | equals true | Warning | Assets added to a quote keep their contracted price. |
| AddAssets | Retain asset price on non-price change | equals true | Warning | A non-price change on an asset should not re-price it. |
| AdminJobs | Product attribute cache ran in the last 30 days | ranWithinDays 30 | Warning | Run the admin jobs after every catalog or pricing load. |
| AdminJobs | Product attribute JSON ran in the last 30 days | ranWithinDays 30 | Warning | Run the admin jobs after every catalog or pricing load. |
| AdminJobs | Product hierarchy maintenance ran in the last 30 days | ranWithinDays 30 | Warning | Run the admin jobs after every catalog or pricing load. |
| AdminJobs | Product versions ran in the last 30 days | ranWithinDays 30 | Warning | Run the admin jobs after every catalog or pricing load. |
| Console | Enterprise Sales console app | exists | Warning | Users open ESM from the console app; make it visible to ESM profiles. |
| Console | App visibility by profile (check by hand) | manual | Warning | Make the ESM console app visible to the ESM profiles in Setup → App Manager. |
| Console | Enhanced event handling (check by hand) | manual | Warning | Set in the console app settings; cannot be read automatically. |
| Console | Google Maps key | notBlank | Warning | Maps for quote member addresses need a key. Enter it on the Codey Setup page – never in chat. (Setting key name may differ per release; adjust in this pack.) |
| Performance | Add products – group batch size | between 1..10 | Warning | Small batches keep within platform limits on large quotes. |
| Performance | CPQ cache | equals true | NeedsFix | Cart performance depends on the CPQ cache. |
| Performance | Core logs off | equals false | Warning | Detailed logs slow down every cart call; turn on only to debug. |
| Performance | Context rules cache mode | equals inmemmode | Warning | In-memory mode is faster for context rule evaluation. |
| Performance | Eligibility matrix logging off | equals false | Warning | Eligibility logs slow down product lists. |
| Performance | Product hierarchy batch size | between 1..50 |
…(shortened)
```

**Next step suggested:** Follow the steps; every change is preview -> explicit approval -> commit.


## 7. Permissions (read-only part) – Permission health in the org

Tool: `CodeyHealthCheckTool` · inputs: `{"scope": "permissions"}`

**What the agent gets back (message):**

```
ESM health check: 8 OK, 0 Warning, 0 Needs Fix. Everything matches the recommended settings.
```

**Next step suggested:** No action needed.

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### ESM settings health check  `All OK`
_Communications Cloud: not checked · 168 CPQ settings read · Production org · scope Permissions_
**OK:** 8 · **Warning:** 0 · **Needs Fix:** 0

**All checks passed**
- [OK] **Permission set CommunicationsCloudRuntime** — Recommended for at least one ESM user type; missing in the org. (Permissions) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
- [OK] **Permission set CPQ_Admin_All** — Recommended for at least one ESM user type; missing in the org. (Permissions) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
- [OK] **Permission set CPQ_Runtime_CartOperations** — Recommended for at least one ESM user type; missing in the org. (Permissions) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
- [OK] **Permission set CPQ_Runtime_CPQCartUI** — Recommended for at least one ESM user type; missing in the org. (Permissions) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
- [OK] **Permission set EPCAdminUser** — Recommended for at least one ESM user type; missing in the org. (Permissions) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
- [OK] **Permission set ESM_Codey_User** — Recommended for at least one ESM user type; missing in the org. (Permissions) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
- [OK] **Permission set ESM_Runtime** — Recommended for at least one ESM user type; missing in the org. (Permissions) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
- [OK] **Users with ESM runtime access** — No active user has the ESM runtime permission set. (Permissions) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
_Read-only check. A fix changes nothing until you approve its preview._
**Run again** → reply "Run the ESM settings health check again."


## 8. Admin jobs (read-only part) – Admin job history check

Tool: `CodeyHealthCheckTool` · inputs: `{"scope": "adminjobs"}`

**What the agent gets back (message):**

```
ESM health check: 0 OK, 4 Warning, 0 Needs Fix.
```

**Next step suggested:** Offer the fixes: each Fix it starts a preview (apply_esm_change / manage_esm_permissions / run_esm_admin_jobs) that the person must approve.

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### ESM settings health check  `Warnings`
_Communications Cloud: not checked · 168 CPQ settings read · Production org · scope AdminJobs_
**OK:** 0 · **Warning:** 4 · **Needs Fix:** 0

**Items to look at**
- [Warning] **Product attribute cache ran in the last 30 days** — Run the admin jobs after every catalog or pricing load.  Current: no completed run found · Recommended: within 30 days (AdminJobs) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5)
  - reply: _Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve._
- [Warning] **Product attribute JSON ran in the last 30 days** — Run the admin jobs after every catalog or pricing load.  Current: no completed run found · Recommended: within 30 days (AdminJobs) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5)
  - reply: _Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve._
- [Warning] **Product hierarchy maintenance ran in the last 30 days** — Run the admin jobs after every catalog or pricing load.  Current: no completed run found · Recommended: within 30 days (AdminJobs) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5)
  - reply: _Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve._
- [Warning] **Product versions ran in the last 30 days** — Run the admin jobs after every catalog or pricing load.  Current: no completed run found · Recommended: within 30 days (AdminJobs) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_run_maintenance_jobs.htm&type=5)
  - reply: _Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve._
_Read-only check. A fix changes nothing until you approve its preview._
**Fix all fixable items** → reply "Preview fixes for all fixable Needs Fix and Warning items from the health check."
**Run again** → reply "Run the ESM settings health check again."


## 9. Upgrade check – Customized screens a release affects

Tool: `CodeyUpgradeImpactTool` · inputs: `{}`

**What the agent gets back (message):**

```
Release 268: 74 affected screens/procedures (11 High, 24 Medium) out of 556 customized ESM/CPQ components checked. Note: the release change list is a seed/sample until the official list for this release is loaded.
```

**Next step suggested:** Start with High items. On request, suggest a combined version for one screen for review (never deploy it without approval).

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### Upgrade impact – release 268  `Review before upgrading`
_556 customized screens checked_
**High:** 11 · **Medium:** 24 · **Low:** 39

**Affected customized screens**
- [High] **cpqConfigureCartLineItems v5** — Cart configurator layout and event names reworked for the working cart. · customized: version 5 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqConfigureCartLineItems v5 for release 268 for my review (do not deploy)._
- [High] **cpqConfigureCartItem v5** — Cart configurator layout and event names reworked for the working cart. · customized: version 5 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqConfigureCartItem v5 for release 268 for my review (do not deploy)._
- [High] **cpqConfigureCartChildProducts v4** — Cart configurator layout and event names reworked for the working cart. · customized: version 4 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqConfigureCartChildProducts v4 for release 268 for my review (do not deploy)._
- [High] **cpqConfigureCart v2** — Cart configurator layout and event names reworked for the working cart. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqConfigureCart v2 for release 268 for my review (do not deploy)._
- [High] **cpqConfigureCartAttributes v2** — Cart configurator layout and event names reworked for the working cart. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqConfigureCartAttributes v2 for release 268 for my review (do not deploy)._
- [High] **cpqMultiSiteGroupsList v2** — Multi-site group screens use the new grid table component. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultiSiteGroupsList v2 for release 268 for my review (do not deploy)._
- [High] **cpqMultiSiteGroupsMember v2** — Multi-site group screens use the new grid table component. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultiSiteGroupsMember v2 for release 268 for my review (do not deploy)._
- [High] **cpqMultiSiteGroupTemplate v3** — Multi-site group screens use the new grid table component. · customized: version 3 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultiSiteGroupTemplate v3 for release 268 for my review (do not deploy)._
- [High] **cpqMultisiteGridTable v4** — Multi-site group screens use the new grid table component. · customized: version 4 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultisiteGridTable v4 for release 268 for my review (do not deploy)._
- [High] **cpqMultiSiteCombobox v2** — Multi-site group screens use the new grid table component. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultiSiteCombobox v2 for release 268 for my review (do not deploy)._
- [High] **cpqMultisiteGroupSelectorContainerWrapper v1** — Multi-site group screens use the new grid table component. · customized: author SDB27 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultisiteGroupSelectorContainerWrapper v1 for release 268 for my review (do not deploy)._
- [Medium] **cpqCartItems v3** — Line item actions moved to a shared action menu. · customized: version 3 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqCartItems v3 for release 268 for my review (do not deploy)._
- [Medium] **cpqCartItemsAction v2** — Line item actions moved to a shared action menu. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqCartItemsAction v2 for release 268 for my review (do not deploy)._
- [Medium] **cpqMultiSiteGroupsList v2** — Multi-site containers load members page by page. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultiSiteGroupsList v2 for release 268 for my review (do not deploy)._
- [Medium] **cpqMultiSiteGroupsMember v2** — Multi-site containers load members page by page. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultiSiteGroupsMember v2 for release 268 for my review (do not deploy)._
- [Medium] **cpqMultiSiteGroupTemplate v3** — Multi-site containers load members page by page. · customized: version 3 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultiSiteGroupTemplate v3 for release 268 for my review (do not deploy)._
- [Medium] **cpqMultisiteGridTable v4** — Multi-site containers load members page by page. · customized: version 4 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultisiteGridTable v4 for release 268 for my review (do not deploy)._
- [Medium] **cpqMultiSiteCombobox v2** — Multi-site containers load members page by page. · customized: version 2 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultiSiteCombobox v2 for release 268 for my review (do not deploy)._
- [Medium] **cpqMultisiteGroupSelectorContainerWrapper v1** — Multi-site containers load members page by page. · customized: author SDB27 (FlexCard)
  - reply: _Suggest a combined version of the customized FlexCard cpqMultisiteGroupSelectorContainerWrapper v1 for release 268 for my review (do not deploy)._
- [Medium] **CPQ/PriceLineItems v12** — Adds pricing context for location-based pricing. · customized: version 12 (IntegrationProcedure)
  - reply: _Suggest a combined version of the customized IntegrationProcedure CPQ/PriceLineItems v12 for release 268 for my review (do not deploy)._
- [Medium] **ESM/CreateSubOrders v12** — Sub-order creation supports batching by member. · customized: version 12 (IntegrationProcedure)
  - reply: _Suggest a combined version of the customized IntegrationProcedure ESM/CreateSubOrders v12 for release 268 for my review (do not deploy)._
- [Medium] **ESM/CreateSubOrdersInBatch v7** — Sub-order creation supports batching by member. · customized: version 7 (IntegrationProcedure)
  - reply: _Suggest a combined version of the customized IntegrationProcedure ESM/CreateSubOrdersInBatch v7 for release 268 for my review (do not deploy)._
- [Medium] **ESM/CreateEnterpriseOrder (Multi-Language) v12** — ESM OmniScripts get the new navigation component. · customized: version 12 (OmniScript)
  - reply: _Suggest a combined version of the customized OmniScript ESM/CreateEnterpriseOrder (Multi-Language) v12 for release 268 for my review (do not deploy)._
- [Medium] **ESM/QuoteEnrichForNumberAssignment (English) v18** — ESM OmniScripts get the new navigation component. · customized: version 18 (OmniScript)
  - reply: _Suggest a combined version of the customized OmniScript ESM/QuoteEnrichForNumberAssignment (English) v18 for release 268 for my review (do not deploy)._
- [Medium] **ESM/QuoteEnrichForPayment (English) v11** — ESM OmniScripts get the new navigation component. · customized: version 11 (OmniScript)
  - reply: _Suggest a combined version of the customized OmniScript ESM/QuoteEnrichForPayment (English) v11 for release 268 for my review (do not deploy)._
_49 more screens in the details_
> **Release list:** Sample entries – load the official release change list before relying on this report.
_Report only: nothing is changed. A combined version is a suggestion for your review._


## 10. Concepts guide – Quote Member vs quote line item, with real data from a quote

Tool: `CodeyPlaybookTool` · inputs: `{"topic": "concept:quote-member-vs-line-item", "quoteId": "0Q0Ws00000ALtIHKA1"}`

**What the agent gets back (message):**

```
## quote-member-vs-line-item
A **Quote Member** answers *where* (a site/location, with address, serviceability and its group). A **quote line item**
answers *what* (the product, attributes, quantity and price). One member can have many lines; a group-level line covers all
members in that group without copying a line per member until orders are created. Example to give from the org: "Quote
<name> has <n> members in <n> groups and <n> lines; group <g> line <offer> applies to its <n> members."

### Example from your org
Quote "UC-8 Load test L10000 (1670 sites)" (EnterpriseQuote) for Acme: 1670 quote members, 0 quote groups, 10020 quote line items (0 group-level, 10020 member-level), 0 orders.
```

**Next step suggested:** Follow the steps; every change is preview -> explicit approval -> commit.


## 11. Concepts guide – Data model explained with real data

Tool: `CodeyPlaybookTool` · inputs: `{"topic": "concept:data-model", "quoteId": "0Q0Ws00000ALtIHKA1"}`

**What the agent gets back (message):**

```
## data-model
**Enterprise Quote (EQ)** – a standard Quote with the `EnterpriseQuote` record type. It holds the commercial offer for a
multi-site customer. **Quote Members** (`vlocity_cmt__QuoteMember__c`) are the sites/locations (premises, service points,
service or subscriber accounts) on the quote. **Quote Groups** (`vlocity_cmt__QuoteGroup__c`) bundle members that get the
same offer (for example "Retail stores – Fibre"). **Quote line items (QLI)** are the products: a group-level line is configured
once and applies to every member of the group; member-level lines belong to one member. The **working cart** is a temporary
cart used to configure and price a group/members before the result is applied back to the EQ.
**Enterprise Order (EO)** – the Order with the `EnterpriseOrder` record type created from an accepted EQ; it is split into
**sub-orders** per member/group for fulfilment (Create Final Orders), via the configured sub-order procedures.
Flow: `Account → Opportunity → Enterprise Quote → Quote Members + Groups → Lines (working cart) → Price/Validate → Proposal → Enterprise Order → Sub-orders`.
Help: https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5

### Example from your org
Quote "UC-8 Load test L10000 (1670 sites)" (EnterpriseQuote) for Acme: 1670 quote members, 0 quote groups, 10020 quote line items (0 group-level, 10020 member-level), 0 orders.
```

**Next step suggested:** Follow the steps; every change is preview -> explicit approval -> commit.


## 12. Pricing – The pricing plan explained step by step

Tool: `CodeyPricePreviewTool` · inputs: `{"explainPlan": true}`

**What the agent gets back (message):**

```
Pricing plan (DEFAULT_PRICING_PLAN), 12 steps in order:
1. ABP Custom Class – CustomPricingPlanStepImpl.GetMatrixPrice
10. Initialize Pricing Context – DefaultPricingPlanImplementation.InitializePricingContext
20. Load Price List Entries – DefaultPricingPlanImplementation.LoadTightestMatchPriceListEntries
30. Initialize Pricing Variables – DefaultPricingPlanImplementation.InitializePricingVariables
35. Apply Context Discounts – DefaultPricingPlanImplementation.ApplyContextDiscounts
40. Apply Offer Adjustments – DefaultPricingPlanImplementation.ApplyOfferAdjustments
50. Apply Promotion Adjustments – DefaultPricingPlanImplementation.ApplyPromotionAdjustments
60. Apply Charge Manual Adjustments – DefaultPricingPlanImplementation.ApplyChargeManualAdjustments
70. Calculate Rollups – DefaultPricingPlanImplementation.CalculateRollups
75. Load Margin Ranges – DefaultPricingPlanImplementation.LoadMarginRanges
80. Save Line Items – DefaultPricingPlanImplementation.SaveLineItems
90. Apply Parent Variables – DefaultPricingPlanImplementation.ApplyParentVariables
```

**Next step suggested:** Explain each step in one line (concept:pricing-plan). For a change, use apply_esm_change changeType=pricingPlanStep with a preview.

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### Pricing plan steps  `12 steps`
_DEFAULT_PRICING_PLAN_

**Steps**
- [Active] **1. ABP Custom Class** — CustomPricingPlanStepImpl · GetMatrixPrice
- [Active] **10. Initialize Pricing Context** — DefaultPricingPlanImplementation · InitializePricingContext
- [Active] **20. Load Price List Entries** — DefaultPricingPlanImplementation · LoadTightestMatchPriceListEntries
- [Active] **30. Initialize Pricing Variables** — DefaultPricingPlanImplementation · InitializePricingVariables
- [Active] **35. Apply Context Discounts** — DefaultPricingPlanImplementation · ApplyContextDiscounts
- [Active] **40. Apply Offer Adjustments** — DefaultPricingPlanImplementation · ApplyOfferAdjustments
- [Active] **50. Apply Promotion Adjustments** — DefaultPricingPlanImplementation · ApplyPromotionAdjustments
- [Active] **60. Apply Charge Manual Adjustments** — DefaultPricingPlanImplementation · ApplyChargeManualAdjustments
- [Active] **70. Calculate Rollups** — DefaultPricingPlanImplementation · CalculateRollups
- [Active] **75. Load Margin Ranges** — DefaultPricingPlanImplementation · LoadMarginRanges
- [Active] **80. Save Line Items** — DefaultPricingPlanImplementation · SaveLineItems
- [Active] **90. Apply Parent Variables** — DefaultPricingPlanImplementation · ApplyParentVariables


## 13. Pricing / Promotions & discounts – Prices, promotions and discounts on an existing quote (read-only)

Tool: `CodeyPricePreviewTool` · inputs: `{"quoteId": "0Q0Ws00000ALtIHKA1"}`

**What the agent gets back (message):**

```
Priced 200 lines: one-time 17,000, recurring 3,060 per month; 50 promotions, 1 discounts. (existing quote, read-only)
```

**Next step suggested:** Explain which promotions and discounts applied, at which step, and why (concept:promotions-vs-discounts).

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### Prices on UC-8 Load test L10000 (1670 sites)  `Read only`
_Recurring 3,060/mo · one-time 17,000_
**Changes:** 47 · **Updated:** 47

**What will change**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Internet Security Software ×1.00** — list 41.4/mo · 0 one-time → **net 41.4/mo · 0 one-time**
- [Priced] **CPE ×1.00** — list 0.9/mo · 0 one-time → **net 0.9/mo · 0 one-time**
- [Priced] **Installation ×1.00** — list 0/mo · 500 one-time → **net 0/mo · 500 one-time**
- [Priced] **Public Wi-Fi ×1.00** — list 7.2/mo · 0 one-time → **net 7.2/mo · 0 one-time**
- [Priced] **LTE Backup ×1.00** — list 13.5/mo · 0 one-time → **net 13.5/mo · 0 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Internet Security Software ×1.00** — list 41.4/mo · 0 one-time → **net 41.4/mo · 0 one-time**
- [Priced] **CPE ×1.00** — list 0.9/mo · 0 one-time → **net 0.9/mo · 0 one-time**
- [Priced] **Installation ×1.00** — list 0/mo · 500 one-time → **net 0/mo · 500 one-time**
- [Priced] **Public Wi-Fi ×1.00** — list 7.2/mo · 0 one-time → **net 7.2/mo · 0 one-time**
- [Priced] **LTE Backup ×1.00** — list 13.5/mo · 0 one-time → **net 13.5/mo · 0 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Internet Security Software ×1.00** — list 41.4/mo · 0 one-time → **net 41.4/mo · 0 one-time**
- [Priced] **CPE ×1.00** — list 0.9/mo · 0 one-time → **net 0.9/mo · 0 one-time**
- [Priced] **Installation ×1.00** — list 0/mo · 500 one-time → **net 0/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
- [Priced] **Business Internet Essential ×1.00** — list 27/mo · 0 one-time → **net 90/mo · 500 one-time**
_22 more changes in the details_
> **Production org:** This is a production org: the change needs your explicit confirmation for production.
_50 promotions, 1 discounts applied. Nothing is saved until you approve. Every change is logged._


## 14. Customization (read-only part) – Context rules explained + quoting settings they need

Tool: `CodeyPlaybookTool` · inputs: `{"topic": "concept:context-rules"}`

**What the agent gets back (message):**

```
## context-rules
**Context rules** decide eligibility/availability of products using context (e.g. the member's region or technology).
A ruleset (`vlocity_cmt__ContextRuleset__c`) holds rules (`vlocity_cmt__ContextRule__c`) with an expression on context
dimensions, linked to a product. Requires CPQ setting `ContextRulesEnabled = True`; caches (`ContextRulesCacheMode`) and
the context eligibility admin jobs may need refreshing.
Help: https://help.salesforce.com/s/articleView?id=ind.comms_create_and_enable_context_rules_for_products_on_quote_members_in_enterprise_sales_management.htm&type=5
```

**Next step suggested:** Follow the steps; every change is preview -> explicit approval -> commit.


## 15. Customization (read-only part) – Quoting settings (context rules, promotions, bulk updates)

Tool: `CodeyHealthCheckTool` · inputs: `{"scope": "quoting"}`

**What the agent gets back (message):**

```
ESM health check: 13 OK, 0 Warning, 0 Needs Fix. Everything matches the recommended settings.
```

**Next step suggested:** No action needed.

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### ESM settings health check  `All OK`
_Communications Cloud: not checked · 168 CPQ settings read · Production org · scope Quoting_
**OK:** 13 · **Warning:** 0 · **Needs Fix:** 0

**All checks passed**
- [OK] **CPQ actions for agents** — Agents use the CPQ cart invocable actions. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Bulk attribute update** — Lets attribute changes apply to many lines in the background. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Bulk price update** — Lets price changes apply to many lines in the background. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Bulk pricing procedure** — Group/bulk pricing uses this Integration Procedure. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Context rules enabled** — Needed for context rules on products for quote members. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_create_and_enable_context_rules_for_products_on_quote_members_in_enterprise_sales_management.htm&type=5)
- [OK] **Eligibility matrix** — Product eligibility for quote members is read from this matrix. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Enterprise Order record type setting** — Tells CPQ which Order record type is an Enterprise Order. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Enterprise Quote record type setting** — Tells CPQ which Quote record type is an Enterprise Quote. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Implicit pricing** — Re-prices automatically after cart changes. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Default pricing plan** — Pricing uses the plan named here. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Promotions enabled** — Promotions in the working cart need this. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Submit orders procedure** — Submitting sub-orders uses this Integration Procedure. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
- [OK] **Create sub-orders procedure** — Create Final Orders uses this Integration Procedure. (Quoting) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_your_enterprise_sales_management_implementation_63687.htm&type=5)
_Read-only check. A fix changes nothing until you approve its preview._
**Run again** → reply "Run the ESM settings health check again."


## 16. Bulk members (read-only part) – Address and serviceability explained with the quote's numbers

Tool: `CodeyPlaybookTool` · inputs: `{"topic": "concept:address-serviceability", "quoteId": "0Q0Ws00000ALtIHKA1"}`

**What the agent gets back (message):**

```
## address-serviceability
**Address verification** validates each member's address (result on the member: Valid / Partial / Invalid + message).
**Serviceability** checks which technologies and speeds are available at the site (serviceability data, max download/upload
speed, connection type). In ESM these run through Integration Procedures (`ESM_checkAddressValidation`,
`ESM_checkServiceQualificationV2`) calling the customer's address/qualification services. For thousands of members they must
run in background batches.

### Example from your org
Quote "UC-8 Load test L10000 (1670 sites)" (EnterpriseQuote) for Acme: 1670 quote members, 0 quote groups, 10020 quote line items (0 group-level, 10020 member-level), 0 orders.
```

**Next step suggested:** Follow the steps; every change is preview -> explicit approval -> commit.


## 17. Progress tracker – Latest Codey background job (if any)

Tool: `CodeyTrackJobTool` · inputs: `{}`

**What the agent gets back (message):**

```
No Codey job found.
```

**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**

### Could not complete the request  `Not done`
> **How to fix:** Check the message above; if it repeats, stop and hand over with the change log id (escalation in the playbook).
_No Codey job found._


