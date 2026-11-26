# Claude Desktop / claude.ai

- **Claude Desktop:** merge `claude_desktop_config.json` into your config (Settings → Developer → Edit Config). `mcp-remote` handles
  the Salesforce OAuth login (External Client App, per user). Restart Claude.
- **claude.ai (Team/Enterprise):** Settings → Connectors → Add custom connector → the Hosted MCP URL. Upload `playbook/PLAYBOOK.md`
  and the skills as Project knowledge, and paste `adapters/claude-code/CLAUDE.md` into the Project instructions.
- Start with: "Check if my ESM setup is correct" – Claude calls `get_codey_playbook`, then `check_esm_setup`.
