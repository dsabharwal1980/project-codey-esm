# Project Codey for ESM – what is included and how to see it

A short, plain guide. For installation details see the *Cross-Org Deployment & Usage Guide*.

## 1. What was prepared – in one table

| Building block | In plain words | How many |
|---|---|---|
| **Playbook** | The rule book every AI agent reads first: which skill to use for which request, and the golden rules (always preview, wait for approval, never ask for secrets in chat, check the result, log everything). | 1 |
| **Skills** | Step-by-step instructions for one job each (see section 2). The agent follows them like a checklist. | 8 |
| **Runbooks** | One per user story in the PRD: what to ask, what should happen, how to test it. | 11 |
| **Knowledge packs** | Expert content the agent reads instead of guessing: how ESM works (concepts), the recommended settings, and what changes in each release. | 3 |
| **Tools** | The actions in Salesforce that the skills use (read the settings, preview a change, apply it after approval, run admin jobs, price a sample, check thousands of sites…). Available to any AI tool through the MCP server *ESM Codey Ease of Build*, and to Agentforce. | 9 |
| **Experience cards (HXL)** | The four screens people see: **Approval**, **Health check report**, **Progress tracker**, **Upgrade impact report**. They look the same in Lightning, Agentforce, Slack, Teams, Claude and ChatGPT. | 4 |
| **Agents** | *ESM Codey* (new Agentforce agent) and the *ESM Coworker* (now with a "Codey build helper"). | 2 |
| **Codey Setup app** | A Lightning app to run the health check and upgrade check without any AI, enter the Google Maps key securely, and see everything Codey did. | 1 |

## 2. The 8 skills

| Skill | What it does | Ask it like this | Changes anything? | Screen you see |
|---|---|---|---|---|
| **Fresh install** | Checks prerequisites, then guides the install: packs, permission sets, Console, Google Maps key, admin jobs, a priced test quote, a final health check. | "Install ESM on my new sandbox." | Yes – each step only after you approve | Approval, Progress tracker, Health check report |
| **Settings health check** | Compares the org's quoting, add-assets, performance, Console, permission and admin-job settings with the recommended ones. | "Check if my setup is correct." | **No** (fixes only after approval) | Health check report (+ Approval for a fix) |
| **Permissions** | Shows which permission sets each user type is missing and assigns them after approval. | "Give the new sales team access." | Yes – after approval; never removes | Approval |
| **Upgrade check** | Lists the customized screens a release affects, with risk and a suggested action. | "What will the next upgrade affect?" | **No** | Upgrade impact report |
| **Concepts guide** | Explains ESM in plain words with examples from your own org (Quote Members, lines, orders, pricing, promotions vs discounts, rules…). | "Explain Quote Member vs quote line item." | **No** | Text answer |
| **Pricing** | Explains the price plan step by step; previews a pricing change with its price effect; applies it after approval and tests it. Can also price a sample without saving. | "Explain our price plan." / "Add a regional surcharge step." | Explaining: **no**. Changing: after approval | Price breakdown, Approval |
| **Customization** | Sets up context rules, Quote Member Binding, linear relationships and Enrich Quote options: explain, draft, preview, approve, test. | "Only allow this product at sites in the North region." | Explaining: **no**. Setting up: after approval | Approval |
| **Bulk members** | Loads thousands of sites from a spreadsheet and checks addresses and serviceability in the background, with a results file. | "Load these 4,000 sites and check them." | Yes – after approval | Approval, Progress tracker |

The **admin jobs** (run in the documented order, with progress and resume) are part of *Fresh install* and can also be asked for on their own: "Run the admin jobs."

## 3. How to see the output in a new org

After the deploy (`bash scripts/deploy.sh <org>`) and giving yourself access (`bash scripts/assign-perms.sh <org> <your username> admin`), there are five ways – pick the one that suits you.

| Way | Needs | What you see | Good for |
|---|---|---|---|
| **A. Codey Setup app** | Nothing else – App Launcher → *Codey Setup* | *Health check* tab → the Health check report card; *Upgrade impact* tab → the Upgrade impact card; *Google Maps key* (secure form); *Activity* → every read, preview and change | Seeing the cards without any AI tool |
| **B. ESM Codey agent in Lightning** | Agentforce panel (the agent is active) | Ask any sample question; the agent follows the skill and shows the card in the conversation | Demo of the full experience in Salesforce |
| **C. ESM Coworker** | ESM New Experience + Coworker installed | Inside a quote, ask "Check my ESM settings" or "Explain the price steps of this quote" | Users who already work in the Coworker |
| **D. Any AI tool (Claude, ChatGPT, Slack, Teams, Vibes, Cursor)** | Connect the MCP server *ESM Codey Ease of Build* (see `adapters/`) | Same answers; cards shown as text, Slack blocks or Teams cards | People who live in those tools |
| **E. One-command showcase report** | Salesforce CLI | `python3 scripts/showcase.py <org>` runs every **read-only** step of every skill and writes `docs/showcase/<org>-showcase.md` with the real answers and cards | A safe first look at a new org – nothing is changed |

Without any org at all, the four cards can be seen in `hxl/samples/` (Markdown, Slack and Teams versions).

## 4. Safe to try (read-only) vs needs approval

| Read-only – try freely | Asks for approval first |
|---|---|
| Settings health check (any area) · Prerequisite check · Upgrade check · Concepts guide · Explain the price plan · Explain prices, promotions and discounts of a quote · Price a sample **without saving** · Recommended settings and permission sets per user type · Job progress | Any fix of a setting · Assigning permission sets · Running admin jobs · Pricing plan changes · Context rules / Quote Member Binding / linear relationships / Enrich Quote options · Loading or checking quote members · Keeping a test quote · Undo |

Every request – read or change – is written to the *Codey Change Log* (who, what, when, before/after), which is how usage is tracked.

## 5. Read-only showcase run in esm264 (real results)

Ran on 26 Nov 2026 with `scripts/showcase.py` – only reads, no previews and no changes (CPQ settings 168 before and after, no jobs started).

| Skill | What was shown | Result in esm264 |
|---|---|---|
| Playbook | Routing and golden rules | Returned to the agent as written in the repo |
| Fresh install (read-only part) | Prerequisites | 7 OK, 0 Warning, 0 Needs Fix |
| Settings health check | All areas / add assets to quote | 44 OK, 7 Warning, 0 Needs Fix / 4 OK |
| Permissions (read-only part) | Recommended sets per user type; permission health | 7 user types; 8 OK |
| Admin jobs (read-only part) | Admin job history | 4 Warning – the admin jobs have never been run in this org |
| Upgrade check | Release 268 (sample release list) | 556 customized components checked, 74 affected (11 High, 24 Medium) |
| Concepts guide | Quote Member vs line item; data model | Answered with the real numbers of the largest quote (1,670 members) |
| Pricing | Price plan | 12 steps explained in order |
| Pricing / promotions & discounts | Prices of an existing quote | Whole quote: 10,020 lines, 835,000 one-time, 150,300 per month, 84 promotions, 1 discount (see note) |
| Customization (read-only part) | Context rules explained; quoting settings | 13 OK – context rules are enabled |
| Bulk members (read-only part) | Address and serviceability explained with the quote's numbers | Answered |
| Progress tracker | Latest background job | No job yet (expected – nothing has been run) |

Real screenshots of these screens: [`docs/Showcase-with-Screens`](Showcase-with-Screens.md).
The full report with every answer and rendered card: [`docs/showcase/esm264-showcase.md`](showcase/esm264-showcase.md).
**Note:** the deployed price explanation counted only the first 200 lines and 50 promotions of this very large quote; the figures above are the correct whole-quote numbers. This was fixed and deployed afterwards (with your approval); the tool now reports these whole-quote figures.

The 7 warnings in this org: 4 admin jobs never run, Google Maps key not set, and 2 Console settings to check by hand in Setup.

## 6. Quick start for a new org (checklist)

1. Deploy: `bash scripts/deploy.sh <org>` (add `--with-coworker` if the org has the ESM Coworker).
2. Access: `bash scripts/assign-perms.sh <org> <your username> admin`.
3. Safe first look: `python3 scripts/showcase.py <org>` → open `docs/showcase/<org>-showcase.md`.
4. See the cards: App Launcher → **Codey Setup** → *Run health check* and *Check upgrade impact*.
5. Talk to it: open the Agentforce panel → **ESM Codey** → "Check if my setup is correct."
6. Try a change (sandbox): "Fix the core logs setting" → Approval card → *Approve* → the change is applied and logged → "Undo that change".
