# Slack

Two options – both use the same org tools and playbook.

1. **Agentforce in Slack (recommended):** publish and activate the `ESM_Codey` agent (adapters/agentforce), then in Setup →
   Agentforce Agents → ESM_Codey → Connections → Slack, connect your Slack workspace. People DM the agent or @-mention it;
   HXL cards render as Slack messages.
2. **Slackbot / your own Slack app with MCP:** register the Hosted MCP server with the External Client App `ESM_MCP_Slack`
   (per-user OAuth). Load the playbook as the bot's system instructions (`adapters/chatgpt/instructions.md` works as is).
   Render cards with `render_codey_card format=slack` (codey-knowledge server) and post the `blocks`; when a person clicks a
   button, send its `value` back to the agent as their reply (Approve / Fix it / Resume).

Bulk members: people attach the spreadsheet in Slack; the bot reads it and passes the rows as `membersCsv`, or uploads it to the
quote and passes the `contentDocumentId`.
