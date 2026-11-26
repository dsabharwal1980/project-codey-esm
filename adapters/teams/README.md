# Microsoft Teams

Use a Teams bot (or Copilot Studio / Azure bot) that calls the Hosted MCP server with per-user OAuth (an External Client App for Teams).
Render each tool card with `render_codey_card format=adaptive` and send it as an Adaptive Card; `Action.Submit` data carries
`codeyMessage` – send it back to the agent as the person's reply. Same playbook instructions as `adapters/chatgpt/instructions.md`.
