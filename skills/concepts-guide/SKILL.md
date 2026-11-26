---
name: esm-concepts-guide
description: Answer ESM product questions in plain words with examples from the customer's own org and a help link – Enterprise Quote, Quote Members, quote line items, Enterprise Orders, pricing, promotions vs discounts, linear relationships, Quote Member Binding, context rules, Enrich Quote, address checks and serviceability. Changes nothing.
triggers: ["explain", "what is", "difference between", "how does", "quote member", "promotion vs discount", "why did this discount apply"]
tools: [get_codey_playbook, preview_esm_price]
cards: []
runbooks: [US-06, US-09]
---

# Skill: Concepts guide

**Purpose:** short, correct answers so the design is right the first time.
**Example request:** "Explain the difference between a Quote Member and a quote line item."

## Steps
1. **Find the topic** – `get_codey_playbook topic=concept:<key>`; keys: `data-model`, `quote-member-vs-line-item`,
   `enterprise-order`, `pricing-plan`, `attribute-pricing`, `location-pricing`, `frame-contract-pricing`,
   `promotions-vs-discounts`, `linear-relationships`, `quote-member-binding`, `context-rules`, `enrich-quote`,
   `address-serviceability`, `admin-jobs`. Use `topic=concept:all` to search when unsure.
2. **Use real examples** – pass `quoteId=<quote>` (or ask for one / use the most recent Enterprise Quote) so the answer shows
   real counts and names (members, groups, lines, orders) from the org.
3. **Promotions and discounts on a sample quote** (US-09) – `preview_esm_price quoteId=<quote>` (read) or with sample
   products, and explain which promotions and discounts applied, at which pricing step, and why.
4. **Answer briefly**: 3–6 sentences or a small comparison table + one example from the org + the help link from the pack.

## Rules
- Only the concepts pack and tool results are sources. If the pack doesn't cover it, say so and give the closest help link.

## Result
A clear answer with an example and a help link.
