# Developer notes – Project Codey ESM

## Discovery in the reference org (esm264, Vlocity CMT 900.665, OmniStudio 264.11, API 68)
| Area | Finding | Used by |
|---|---|---|
| Admin jobs | Global entry points: `vlocity_cmt.CMTAdminJobService.startProductHierarchyMaintenanceJob(Id)`; global batches with public constructors: `UpdateAllProdAttribJSONBatchJob()`, `FixProductAttribJSONBatchJob()`, `ProductAttributesCacheBatchJob()`, `PromotionExpirationBatch()`, `UpdateAttributeConfigurableBatchJob(Datetime)`. `EPCProductVersionBatchJob` has no visible constructor; Clear Managed Platform Cache and Refresh Pricebook are not exposed → **manual** steps (CMT Administration). | `CodeyAdminJobRunner.LiveStarter`, `Codey_Admin_Job__mdt` |
| Pricing | CPQ cart invocables `vlocity_cmt.CpqCartCreateCartInvocable` (AccountId, Name, objectType, OpportunityId, priceListName), `CpqCartAddProductInvocable` (cartId, itemId = PricebookEntry Id, quantity, price), `CpqCartGetCartItemsInvocable` (cartId, price). Per-line pricing steps in `QuoteLineItem.vlocity_cmt__PricingLogData__c` → `LogData.<charge code>[]` with LogSequence, LogType PRICE/ADJUSTMENT, StartValue, EndValue, PromotionId, DiscountId, PricingAdjustmentId. Pricing plan `DEFAULT_PRICING_PLAN` with 12 steps (`vlocity_cmt__PricingPlanStep__c`). | `CodeyPricePreviewTool` (savepoint + rollback) |
| Address / serviceability | ESM IPs `ESM_checkAddressValidation` (QuotememberIds, QuoteId), `ESM_checkServiceQualificationV2` (ObjectType, QuoteId, QuotememberIds, SelectedServiceName); results on `vlocity_cmt__QuoteMember__c` (AddressValidationResult Valid/Invalid/Partial/Success/Fails, AddressValidationMessage, ServiceabilityData TMF JSON, MaxDownloadSpeed, BroadbandConnectionType, ServiceabilityLastCheckedDate). | `CodeyBulkCheck` providers |
| HXL | `UiWidgetBundle` (JSON, `lightning__agentforceWidget`, tile primitives: widget, container, column, row, text, icon, badge, progress, callout, separator, accordion, button with action/sendMessage or action/openLink) + `LightningTypeBundle` (schema `{actionName, isSuccess, outputValues}`, tag `mcp`, renderer `@widget/c/<name>`), output values with `@apexClassType/c__<CardClass>`. | `scripts/build-hxl.py` |
| Hosted MCP | `McpServerDefinition` tools with `apiDefinition {apiIdentifier aa:apex-<Class>, apiSource API_CATALOG, operation <Class>}`, `descriptionOverride` ≤ 1,024, server description ≤ 255. Per-user OAuth via External Client Apps. | `scripts/build-mcp.py` |
| Existing UC-8 / Coworker | UC-8 MCP server `EsmMultiSiteQuoting` (17 tools), `ESM_Coworker` Agent Script agent (subagents sites/discounts/explain/deal). Codey is self-contained (no dependency on UC-8 classes) so it ports to other orgs; the Coworker gets one extra subagent. | `scripts/merge-coworker.py` |

## Design rules
- One result shape (`CodeyResult`) and one card type (`CodeyCard`) for every tool; builders never fail a tool.
- Preview → approval → commit is enforced in `CodeyCore.requireApproval` (token = SHA-256 of tool + user + normalised inputs; 30-minute expiry; same user; open preview log). `mode`, `previewToken`, `confirmProduction`, `surface`, `jobId` are not hashed.
- Production guard (`CodeyCore.guardProduction`), secrets refused (`CodeyCore.isSecretName`) and masked in reads.
- Writes `AccessLevel.USER_MODE`; audit/job records in system mode so every action is logged.
- Long work in Queueable / Batch with state on `Codey_Job__c` (steps JSON, cursor) → resumable, one job per quote/tool.
- Generated artefacts (static resources, CMDT, HXL, agents, MCP definition, tool docs) come from the Markdown/JSON in the repo via `scripts/build-*.py` – edit the source, not the output.

## Extending
- New health rule → add to `knowledge/recommended-settings.json` → `build-cmdt.py`.
- New admin job → `adminJobs[]` (global batch with a no-arg constructor works through the generic `Type.forName` path).
- New change type → `CodeyApplyChangeTool.build()` + allow-list; add to the spec in `build-agents.py` description.
- New tool → Apex invocable returning `CodeyResult` → add to `tools/mcp-tools.json` and `TOOLS` in `build-agents.py` → rebuild.
