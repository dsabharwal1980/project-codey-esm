### ESM settings health check  `Needs Fix`
_Communications Cloud licence Active · 168 CPQ settings read · Sandbox · scope all_
**OK:** 41 · **Warning:** 6 · **Needs Fix:** 2

**Items to look at**
- [Needs Fix] **Asset reference ids for parent/root** — Adding assets to a quote relies on asset reference ids.  Current: false · Recommended: true (AddAssets) [Help](https://help.salesforce.com/s/articleView?id=ind.comms_add_assets_to_quote.htm&type=5)
  - reply: _Fix it: preview apply_esm_change changeType=cpqSetting target=UseAssetReferenceIdForParentAndRoot value=true and ask me to approve._
- [Warning] **Core logs off** — Detailed logs slow down every cart call.  Current: true · Recommended: false (Performance)
  - reply: _Fix it: preview apply_esm_change changeType=cpqSetting target=EnableCoreLogs value=false and ask me to approve._
_Read-only check. A fix changes nothing until you approve its preview._
**Fix all fixable items** → reply "Preview fixes for all fixable Needs Fix and Warning items from the health check."
**Run again** → reply "Run the ESM settings health check again."
