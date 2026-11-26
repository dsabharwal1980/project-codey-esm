---
name: esm-permissions
description: Give each ESM user type the right permission sets – compare recommended with what users have, preview, assign after approval and check again. Use for "give the new sales team access", "user can't see the quote", "which permission sets do I need".
triggers: ["give access", "permission set", "can't see", "new sales team", "new users esm"]
tools: [manage_esm_permissions, check_esm_setup, get_codey_playbook]
cards: [Approval]
runbooks: [US-03]
---

# Skill: Permissions

**Purpose:** users with the correct permission sets – the most frequent "I can't see it" problem.
**Example request:** "Give the new sales team access."

## Steps
1. **Know the user types.** `get_codey_playbook topic=settings` lists the recommended permission sets per user type
   (Sales rep, Sales manager, Admin, Pricing admin, Product designer, Service agent, Codey user).
2. **Find the users** – usernames, names, a profile or a role ("the new sales team" → ask which profile/role or names once).
3. **Compare** – `manage_esm_permissions mode=preview userType=<type> users=<list>` (or `profile=` / `role=`). The Approval
   card shows, per user, the missing permission sets (and permission set licences, if needed) and what will be assigned.
   Users who already have everything are listed as OK.
4. **Assign after approval** – `mode=commit previewToken=<token>` with the same inputs. Missing licences are reported, not
   forced.
5. **Check again** – run `manage_esm_permissions mode=preview` again; all users should be OK.

## Rules
- Never remove permission sets (only add). Removing is a manual admin decision.
- The agent works with the asking user's rights; if they cannot assign permission sets, say so.

## Result
`Assigned <n> permission sets to <n> users (<type>). Already OK: <n>. Licences missing: <list>.`
Help: [Permission guidelines](https://help.salesforce.com/s/articleView?id=ind.comms_guidelines_for_enterprise_sales_management_permissions.htm&type=5)
