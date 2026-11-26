# Claude Code

1. Install the skills (copies `skills/*/SKILL.md` into your Claude Code skills folder):
   ```bash
   bash adapters/claude-code/install-skills.sh            # user level (~/.claude/skills)
   bash adapters/claude-code/install-skills.sh --project  # this repo only (.claude/skills)
   ```
2. Add the Salesforce tools (Hosted MCP – OAuth opens in the browser on first use):
   ```bash
   claude mcp add --transport http esm-codey "<HOSTED_MCP_URL of EsmCodeyEaseOfBuild>"
   ```
3. Optional – the knowledge server (prompts, packs, card renderer):
   ```bash
   claude mcp add codey-knowledge -- node "$(pwd)/mcp-server/src/index.js"
   ```
4. Put `adapters/claude-code/CLAUDE.md` in your project (or append it to yours) so every session follows the playbook.

Developer-surface extras (only Claude Code / Cursor / Vibes can do these, with the Salesforce CLI): install packages, deploy
configuration packs with the OmniStudio/Vlocity build tool, retrieve a customized FlexCard and prepare a merged version for review.
