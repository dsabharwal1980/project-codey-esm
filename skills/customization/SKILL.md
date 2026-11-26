---
name: esm-customization
description: Set up linear relationships, Quote Member Binding, context rules for products on quote members and Enrich Quote options – explain the best option, draft the rule or setting, preview, apply after approval and test on sample members.
triggers: ["linear relationship", "quote member binding", "context rule", "only allow this product", "enrich quote", "north region"]
tools: [get_codey_playbook, apply_esm_change, preview_esm_price, check_esm_setup]
cards: [Approval]
runbooks: [US-10, US-11]
---

# Skill: Customization

**Purpose:** the quote fits the customer's process.
**Example request:** "Only allow this product at sites in the North region."

## Steps
1. **Explain the best option** (`get_codey_playbook topic=concept:<key>`):
   - restrict products by member attributes (region, technology) → **context rule** (`context-rules`);
   - copy member fields into product attributes → **Quote Member Binding** (`quote-member-binding`);
   - related products / upgrade paths → **linear relationship** (`linear-relationships`);
   - what the Enrich Quote step offers → **Enrich Quote options** (`enrich-quote`).
   Check prerequisites first, e.g. `ContextRulesEnabled` via `check_esm_setup scope=quoting`.
2. **Draft** – fill the change for `apply_esm_change`:
   - `changeType=contextRule` – ruleset name, rule expression / ad-hoc expression, object (product), failure message, active;
   - `changeType=attributeBinding` – attribute code, object class, quote member field API name;
   - `changeType=linearRelationship` – product, related product, relationship type, min/max;
   - `changeType=enrichQuoteOption` – the CPQ setting key and value for the option.
3. **Preview → approve → apply** (`mode=preview` Approval card with the drafted record, then `mode=commit`). Rules are created
   inactive first when the person prefers; then "turn on" is a second approved change.
4. **Test on sample members** – for context rules, pick 2–3 members inside and outside the condition and show the
   eligibility result (`preview_esm_price` with `locations=`); for QMB check the attribute value on a sample line.
   Run the admin jobs for context rules/attributes caches if the tool says so.

## Result
A working rule or setting, tested; change log ids; `undo` available.
Help: [Quote Member Binding](https://help.salesforce.com/s/articleView?id=ind.comms_apply_product_attributes_with_quote_member_binding.htm&type=5) ·
[Context rules on quote members](https://help.salesforce.com/s/articleView?id=ind.comms_create_and_enable_context_rules_for_products_on_quote_members_in_enterprise_sales_management.htm&type=5) ·
[Enrich Quote options](https://help.salesforce.com/s/articleView?id=ind.comms_t_customize_the_enrich_quote_options_57749.htm&type=5) ·
[Linear relationships](https://help.salesforce.com/s/articleView?id=ind.comms_t_linear_relationships_between_products_in_enterprise_salesmanagement_57023.htm&type=5)
