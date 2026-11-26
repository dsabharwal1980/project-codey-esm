# Project Codey – Enterprise Sales Management Ease of Build

AI agents that do the Enterprise Sales Management (ESM) build work for people – install and set up, check settings, give
permissions, run admin jobs, change pricing and rules, load and check thousands of quote members, check upgrades and explain how
ESM works – from **any AI surface** (Slack, Teams, Claude, ChatGPT, Agentforce Vibes, Cursor, Agentforce, ESM Coworker).
Every change is previewed, approved by a person, applied, checked and logged. (PRD ESM-268.)

```
Ask → agent looks at the org → follows the skill → preview → person approves → agent does the work and checks it → summary
```

## What's in the box
| | Count | Where |
|---|---|---|
| Playbook (routing, golden rules, tools, cards) | 1 | [playbook/PLAYBOOK.md](playbook/PLAYBOOK.md) |
| Runbooks – one per user story | 11 | [playbook/runbooks/](playbook/runbooks/) |
| Skills | 8 | [skills/](skills/) – fresh-install · settings-health-check · permissions · upgrade-check · concepts-guide · pricing · customization · bulk-members |
| Knowledge packs | 3 | [knowledge/](knowledge/) – concepts · recommended settings · release change list |
| MCP tools (3 = PRD agent tools) | 9 | [tools/](tools/) – Salesforce Hosted MCP server `EsmCodeyEaseOfBuild` |
| HXL experience cards | 4 | [hxl/](hxl/) – Approval · Health check report · Progress tracker · Upgrade impact report |
| Agentforce agent (Agent Script) | 1 | `ESM_Codey` – [adapters/agentforce/](adapters/agentforce/) |
| ESM Coworker extension | 1 | [adapters/coworker/](adapters/coworker/) |
| Surface adapters | 9 | [adapters/](adapters/) |
| Knowledge MCP server (optional) | 1 | [mcp-server/](mcp-server/) |
| Salesforce metadata | – | [force-app/](force-app/) |

## Quick start
```bash
bash scripts/deploy.sh <org-alias> --check-only      # validate
bash scripts/deploy.sh <org-alias> [--with-coworker] # deploy core, HXL cards, MCP server, agent
bash scripts/assign-perms.sh <org-alias> you@company.com admin
bash scripts/smoke-test.sh <org-alias> <enterprise-quote-id>
python3 scripts/showcase.py <org-alias>            # read-only report of every skill → docs/showcase/
```
Then connect your AI surface – see [adapters/README.md](adapters/README.md) – and ask *"Check if my ESM setup is correct."*

**Full instructions for another org:** [docs/Cross-Org-Deployment-and-Usage-Guide.md](docs/Cross-Org-Deployment-and-Usage-Guide.md)
(also as `.docx`).

## Documents
| Document | |
|---|---|
| **[What is included and how to see it](docs/What-Is-Included-and-How-to-See-It.md)** (also .docx) | start here – the 8 skills in plain words, 5 ways to see their output, read-only showcase results |
| [Cross-Org Deployment & Usage Guide](docs/Cross-Org-Deployment-and-Usage-Guide.md) | prerequisites, deploy, connect surfaces, tune packs, verify, operate, troubleshoot, rollback |
| [Release notes](docs/release-notes.md) | what's new for customers |
| [Setup help page with sample requests](docs/setup-help.md) | for end users |
| [Text for the four screens](hxl/screen-text.md) | UX copy |
| [Developer notes](docs/developer-notes.md) · [tool reference](tools/README.md) | CMT APIs used, design rules, extending |
| [Demo script](docs/demo-script.md) · [Test results](docs/test-results.md) | |

## Source of truth and generated files
Edit the Markdown/JSON; regenerate the org artefacts:
| Source | Script | Generates |
|---|---|---|
| playbook, skills, runbooks, concepts pack, release list | `scripts/build-static-resources.py` | Static Resources `Codey_Playbook`, `Codey_Concepts_Pack`, `Codey_Release_Change_List` |
| `knowledge/recommended-settings.json` | `scripts/build-cmdt.py` | Custom Metadata records + `recommended-settings.md` |
| card definition | `scripts/build-hxl.py` | UiWidgetBundles, Lightning Types, `hxl/cards/*.json` |
| tool spec | `scripts/build-agents.py`, `scripts/build-mcp.py`, `scripts/build-tool-docs.py` | `ESM_Codey.agent`, Coworker subagent, MCP server definition, tool schemas/docs |

## Safety
Sandbox by default · server-side approval gate (preview token bound to user + identical inputs, 30-minute expiry) · production
needs explicit confirmation · secrets only on the secure Codey Setup page · runs as the asking user · every action in the Codey Change Log.
