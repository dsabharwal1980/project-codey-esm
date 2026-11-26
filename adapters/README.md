# Surface adapters

The skills, playbook and knowledge packs are plain Markdown/JSON and work on **any AI surface**. An adapter only says *how that
surface loads them* and *how it reaches the Salesforce tools*. Two connections are used everywhere:

| Connection | What it gives | How |
|---|---|---|
| **Salesforce Hosted MCP server `EsmCodeyEaseOfBuild`** | the 9 Codey tools (they run in the org as the signed-in user) | Streamable HTTP + per-user OAuth through an External Client App (see docs/Cross-Org-Deployment-and-Usage-Guide.md §6) |
| **Codey knowledge MCP server** (`mcp-server/`, optional) | skills as prompts, playbook / packs as resources, `render_codey_card` | stdio: `node mcp-server/src/index.js` |

Surfaces without MCP prompts can read the same content through the org tool `get_codey_playbook`.

| Surface | Adapter |
|---|---|
| Claude Code | [claude-code/](claude-code/) – skills installed as Claude Code skills + both MCP servers |
| Claude Desktop / claude.ai | [claude-desktop/](claude-desktop/) |
| ChatGPT (developer mode / custom GPT) | [chatgpt/](chatgpt/) |
| Slack (Slackbot / Agentforce in Slack) | [slack/](slack/) |
| Microsoft Teams | [teams/](teams/) |
| Agentforce Vibes (VS Code) | [vibes/](vibes/) |
| Cursor | [cursor/](cursor/) |
| Agentforce (Lightning, Slack, mobile) | [agentforce/](agentforce/) – the `ESM_Codey` Agent Script agent |
| ESM Coworker | [coworker/](coworker/) – adds the `build` subagent to an existing Coworker |
