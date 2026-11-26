# Project Codey – Enterprise Sales Management

When the request is about Enterprise Sales Management (ESM) setup, settings, permissions, admin jobs, pricing, rules, quote members,
upgrades or how ESM works:
1. Use the `esm-codey` MCP tools. Call `get_codey_playbook` first (or read playbook/PLAYBOOK.md) and pick the skill from the routing table.
2. Follow the skill in skills/<name>/SKILL.md step by step.
3. Golden rules: look before you act; every change is `mode=preview` → show the Approval card → wait for an explicit yes →
   `mode=commit` with the `previewToken` and the SAME inputs; sandbox by default (production needs `confirmProduction=true` after the
   person confirms); never ask for or pass secrets in chat (Codey Setup page); never invent values; verify after every commit.
4. Show tool cards as Markdown (`render_codey_card` from the codey-knowledge server, or summarise title, badge, rows and buttons).
