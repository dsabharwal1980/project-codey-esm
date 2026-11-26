# Test results

## Automated (Apex) – reference org esm264
23 tests in CodeyCoreTest, CodeyToolsTest, CodeyJobsTest – all passing. Coverage per class: CodeyCards, CodeyCard*, CodeyCsv,
CodeyResult, CodeyTrackJobTool 100%; CodeyCore 97%; CodeyPlaybookTool 97%; CodeyAdminJobsTool 97%; CodeyHealthCheckTool 95%;
CodeyApplyChangeTool 95%; CodeyPermissionsTool 94%; CodeyPricePreviewTool 94%; CodeyUpgradeImpactTool 94%; CodeyBulkCheckTool 91%;
CodeySetupController 90%; CodeyBulkCheckBatch 89%; CodeyAdminJobRunner 87%; CodeyBulkCheck 80%.

Safety assertions in the tests: commit without/with a wrong/expired token is refused; the same commit twice is refused; price
preview leaves no quote behind (count before = after); secrets are refused by apply_esm_change and never logged by the Codey Setup page.

## Knowledge MCP server (Node)
6 tests passing (content load, routing/rules, search, card rendering for Markdown / Slack / Adaptive Card, MCP list/call/prompt over an in-memory transport).

## Live tests in the reference org (esm264, production-type trial org)
| # | Test | Result |
|---|---|---|
| 1 | `check_esm_setup scope=all` | 44 OK, 7 Warning, 0 Needs Fix in about 1 minute; warnings = admin jobs never run, Google Maps key not set, 2 Console items to check by hand. Secret CPQ values masked. |
| 2 | `get_codey_playbook concept:quote-member-vs-line-item` + quote | Answer with real data: 170 members, 0 groups, 1,020 lines (all member-level), 0 orders |
| 3 | `check_esm_upgrade_impact` (release 268, seed list) | 556 customized ESM/CPQ components scanned, 74 matched (11 High, 24 Medium); flagged as seed list |
| 4 | `preview_esm_price explainPlan=true` | 12 pricing plan steps in order (DEFAULT_PRICING_PLAN) |
| 5 | `preview_esm_price quoteId=<170-site quote>` | read only; deployed version reported "200 lines, 17,000 / 3,060" because totals were built from the first 200 lines – whole quote is 1,020 lines, 85,000 one-time, 15,300/month, 8 promotions, 1 discount. Fixed in the repository (totals/counts over the whole quote), validated, not yet deployed |
| 6 | `preview_esm_price products=VEPC_OFFERING_PUBLIC_WIFI quantity=2` | priced through the real CPQ cart actions: 16/month; **Quote count 452 before = 452 after** (rolled back) |
| 7 | `manage_esm_permissions` preview (Admin) | 1 missing permission set listed, Approval card, nothing assigned |
| 8 | `run_esm_admin_jobs` preview | 8 jobs in order: 5 automatic, 3 manual; nothing started |
| 9 | `check_quote_members_bulk` preview (address) | 0 unchecked members on the test quote (all checked earlier); Approval card |
| 10 | Approval gate round trip (`apply_esm_change` on an inert test setting) | commit with changed value → refused; commit without production confirmation → refused (preview stays open); approved + confirmed → created (CL-000009); same commit again → nothing to change; undo preview → committed (CL-000010) → setting removed |
| 11 | Agent `ESM_Codey` (active v1): "Check if my ESM setup is correct. Only the performance settings" | routed to the health skill, called check_esm_setup scope performance: "all OK – 11 checks passed" |
| 12 | Agent: "Explain Quote Member vs quote line item using quote …" | concept + real counts from the quote |
| 13 | Agent: "Run the ESM admin jobs." | showed the preview (5 automatic, 3 manual), warned it is a production org and asked for approval; **0 jobs started** |
| 14 | ESM Coworker v33 (active): "Check my ESM performance settings" | routed to the Codey build helper; ran check_esm_setup scope performance; logged in Codey Change Log |

Not run as commits in this org (would change shared configuration): admin jobs, permission set assignment, bulk member load. Their commit
paths are covered by the Apex tests and should be run in a sandbox (PRD test strategy: fresh, upgraded, heavily customized org;
1k / 5k / 10k members).
