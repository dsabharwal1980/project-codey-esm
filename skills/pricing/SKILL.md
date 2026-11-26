---
name: esm-pricing
description: Explain price plans step by step and guide safe pricing changes – new pricing plan steps, attribute-based, location-based and frame contract pricing – previewed with their price effect, approved, applied and tested on a sample quote.
triggers: ["price plan", "pricing step", "surcharge", "attribute based pricing", "location pricing", "frame contract", "why is this price"]
tools: [get_codey_playbook, preview_esm_price, apply_esm_change, run_esm_admin_jobs]
cards: [Approval]
runbooks: [US-07]
---

# Skill: Pricing

**Purpose:** pricing right the first time; mistakes are costly.
**Example request:** "Add a regional surcharge step to our price plan."

## Steps
1. **Explain the current plan** – `preview_esm_price explainPlan=true` returns the active pricing plan steps in order
   (sequence, name, implementation, method, active) – explain each in one line using `concept:pricing-plan`.
2. **Work out the change** – which kind:
   - new / changed pricing plan step → `apply_esm_change changeType=pricingPlanStep` (name, sequence, implementation, method,
     parameters, active);
   - attribute-based pricing → pricing matrix / attribute price list entries (`concept:attribute-pricing`);
   - location-based pricing → custom quote fields for location + Integration Procedure changes (`concept:location-pricing`;
     developer surfaces deploy the IP/field changes);
   - frame contract pricing → `concept:frame-contract-pricing`.
   List the fields needed and ask for missing values (never invent amounts).
3. **Preview with the price effect** – `apply_esm_change mode=preview` (Approval card: before/after of the step list) AND
   `preview_esm_price products=<sample> proposedStep=<json>` to show the price before vs after on a sample (nothing saved).
4. **Apply after approval** – `apply_esm_change mode=commit previewToken=…`. If the pricing cache must refresh, run the
   pricing admin jobs (`run_esm_admin_jobs jobs=pricing`).
5. **Test on a sample quote** – `preview_esm_price` again with the same sample; confirm the new step appears and the total
   moved as expected. Offer `apply_esm_change mode=undo changeLogId=…` if not.

## Result
A tested pricing change: before/after total on the sample, change log id.
Help: [Set pricing for locations](https://help.salesforce.com/s/articleView?id=ind.comms_t_set_pricing_for_locations_58428.htm&type=5) ·
[Custom quote fields for location](https://help.salesforce.com/s/articleView?id=ind.comms_t_create_custom_quote_fields_for_location_58559.htm&type=5) ·
[IPs for location pricing](https://help.salesforce.com/s/articleView?id=ind.comms_t_modify_integration_procedures_for_location_based_pricing_58583.htm&type=5)
