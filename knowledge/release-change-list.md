# Release change list
Owner: Release team · published with every release · **SEED – sample entries showing the format; replace with the official list for each release before relying on it**

## 268 – Release 268
| Component (pattern) | Kind | What changed | Risk | Advice for customized copies |
|---|---|---|---|---|
| `cfCpqConfigureCart*` | FlexCard | Cart configurator layout and event names reworked for the working cart. | High | Compare your copy with the new standard card; move custom fields into the new slots; re-test add/configure/price. |
| `cfCpqCartItems*` | FlexCard | Line item actions moved to a shared action menu. | Medium | Re-apply custom actions to the new action menu definition. |
| `cfCpqMultiSite*` | FlexCard | Multi-site group screens use the new grid table component. | High | Custom columns must be re-created as grid column definitions. |
| `cfCpqMultisite*` | FlexCard | Multi-site containers load members page by page. | Medium | Check custom data sources still pass page size and offset. |
| `cfESM_SelfService*` | FlexCard | Self-service order screens: new styling hooks. | Low | Check custom CSS overrides render correctly. |
| `CPQ/PriceLineItems` | IntegrationProcedure | Adds pricing context for location-based pricing. | Medium | If customized, merge the new 'SetLocationContext' step before pricing. |
| `ESM/CreateSubOrders*` | IntegrationProcedure | Sub-order creation supports batching by member. | Medium | Keep your custom steps; take the new batching inputs from the standard version. |
| `MultiService/StartCheckoutQuote` | IntegrationProcedure | Checkout validation returns structured errors. | Low | If you parse error messages, switch to the structured error list. |
| `ESM/GetAllGroups` | IntegrationProcedure | Returns group member counts. | Low | No action unless you post-process the response. |
| `ESM*` | OmniScript | ESM OmniScripts get the new navigation component. | Medium | Re-check custom step navigation and conditional views. |

## 266 – Release 266
| Component (pattern) | Kind | What changed | Risk | Advice for customized copies |
|---|---|---|---|---|
| `cfCpqCartSummaryContainer*` | FlexCard | Totals block shows one-time and recurring separately. | Low | Check custom total labels. |
