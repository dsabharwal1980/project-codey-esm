#!/usr/bin/env node
// Project Codey ESM knowledge MCP server (stdio).
// Gives any MCP client (Claude Desktop / Claude Code, ChatGPT developer mode, Cursor, Vibes, custom Slack/Teams bots) the Codey playbook,
// the 8 skills (as prompts), the 11 runbooks and the 3 knowledge packs, and renders Codey HXL cards for surfaces without HXL.
// The org work itself is done by the Salesforce Hosted MCP server "EsmCodeyEaseOfBuild" – connect it next to this one.
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { loadContent, search } from './content.js';
import { render } from './cards.js';
import { realpathSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function buildServer(content = loadContent()) {
  const server = new McpServer({ name: 'codey-knowledge', version: '1.0.0' });
  const text = (t) => ({ content: [{ type: 'text', text: typeof t === 'string' ? t : JSON.stringify(t, null, 2) }] });
  const md = 'text/markdown';

  // ------------------------------------------------------------ resources
  server.registerResource('playbook', 'codey://playbook', { title: 'Project Codey ESM playbook', description: 'Routing, golden rules, tools and cards. Read first.', mimeType: md },
    async (uri) => ({ contents: [{ uri: uri.href, text: content.playbook }] }));
  for (const s of Object.values(content.skills)) {
    server.registerResource('skill-' + s.name, `codey://skills/${s.name}`, { title: s.title, description: s.description, mimeType: md },
      async (uri) => ({ contents: [{ uri: uri.href, text: s.raw }] }));
  }
  for (const [k, v] of Object.entries(content.runbooks)) {
    server.registerResource('runbook-' + k, `codey://runbooks/${k}`, { title: `Runbook ${k}`, description: v.split('\n')[0].replace(/^#\s*/, ''), mimeType: md },
      async (uri) => ({ contents: [{ uri: uri.href, text: v }] }));
  }
  const json = (name, uriStr, title, description, data) => server.registerResource(name, uriStr, { title, description, mimeType: 'application/json' },
    async (uri) => ({ contents: [{ uri: uri.href, text: JSON.stringify(data, null, 2) }] }));
  server.registerResource('concepts-pack', 'codey://knowledge/concepts', { title: 'Concepts pack', description: 'ESM data model, pricing, promotions vs discounts, rules, serviceability.', mimeType: md },
    async (uri) => ({ contents: [{ uri: uri.href, text: content.concepts }] }));
  json('recommended-settings', 'codey://knowledge/recommended-settings', 'Recommended settings pack', 'Settings, permission sets per user type, admin jobs.', content.recommendedSettings);
  json('release-change-list', 'codey://knowledge/release-change-list', 'Release change list', 'Changed components per release, with advice.', content.releaseChangeList);
  json('card-schema', 'codey://hxl/card-schema', 'Codey HXL card schema', 'Shared data of the four experience screens.', content.cardSchema);
  json('salesforce-tools', 'codey://tools', 'Codey Salesforce MCP tools', 'The 9 tools of the EsmCodeyEaseOfBuild Hosted MCP server.', content.mcpTools);

  // ------------------------------------------------------------ prompts (one per skill)
  const rules = content.playbookSections.rules || '';
  for (const s of Object.values(content.skills)) {
    server.registerPrompt(s.name, { title: s.title, description: s.description, argsSchema: { request: z.string().describe('What the person asked, e.g. "Check if my setup is correct"').optional() } },
      ({ request }) => ({ messages: [{ role: 'user', content: { type: 'text', text:
        `Follow this Project Codey skill using the tools of the Salesforce MCP server EsmCodeyEaseOfBuild.\n\n${rules}\n\n${s.text}\n\nRequest: ${request || '(ask the person what they need)'}` } }] }));
  }

  // ------------------------------------------------------------ tools
  server.registerTool('list_codey_skills', { title: 'List Codey skills', description: 'Lists the 8 Project Codey ESM skills, the routing table and the Salesforce MCP tools they use. Call first.', inputSchema: {} },
    async () => text({ skills: Object.values(content.skills).map((s) => ({ name: s.name, description: s.description })), routing: content.playbookSections.routing,
      salesforceTools: content.mcpTools.map((t) => t.toolName) }));

  server.registerTool('get_codey_skill', { title: 'Get Codey skill', description: 'Returns a skill (with the golden rules), a runbook (US-01..US-11) or a playbook section.',
    inputSchema: { name: z.string().describe('fresh-install, settings-health-check, permissions, upgrade-check, concepts-guide, pricing, customization, bulk-members; US-xx; or overview, routing, rules, tools, cards, escalation') } },
    async ({ name }) => {
      const k = String(name).trim().toLowerCase().replace(/^skill:|^esm-/, '').replace(/^runbook:/, '');
      if (content.skills[k]) return text(rules + '\n\n' + content.skills[k].text);
      const rb = Object.keys(content.runbooks).find((r) => r.toLowerCase() === k);
      if (rb) return text(content.runbooks[rb]);
      if (content.playbookSections[k]) return text(content.playbookSections[k]);
      return { isError: true, content: [{ type: 'text', text: `Unknown "${name}". Skills: ${Object.keys(content.skills).join(', ')}; runbooks: ${Object.keys(content.runbooks).join(', ')}.` }] };
    });

  server.registerTool('search_codey_knowledge', { title: 'Search Codey knowledge', description: 'Keyword search over the playbook, skills, runbooks and the concepts pack.',
    inputSchema: { query: z.string(), limit: z.number().int().min(1).max(10).optional() } },
    async ({ query, limit }) => text(search(content, query, limit || 5).map((d) => ({ id: d.id, text: d.text.slice(0, 4000) }))));

  server.registerTool('get_recommended_settings', { title: 'Get recommended settings', description: 'Recommended settings pack (optionally one area: Prereq, Quoting, AddAssets, Performance, Console, Permissions, AdminJobs), permission sets per user type and admin jobs.',
    inputSchema: { area: z.string().optional() } },
    async ({ area }) => {
      const p = content.recommendedSettings;
      return text(area ? { ...p, settings: p.settings.filter((s) => s.area.toLowerCase() === String(area).toLowerCase()) } : p);
    });

  server.registerTool('render_codey_card', { title: 'Render Codey card', description: 'Turns the "card" returned by a Codey Salesforce tool into Slack Block Kit, a Microsoft Teams Adaptive Card or Markdown, so the Approval, Health check report, Progress tracker and Upgrade impact screens look the same on every surface.',
    inputSchema: { card: z.record(z.string(), z.any()).describe('The card object from the tool result'), format: z.enum(['markdown', 'slack', 'adaptive']).optional() } },
    async ({ card, format }) => {
      try { return text(render(card, format || 'markdown')); } catch (e) { return { isError: true, content: [{ type: 'text', text: e.message }] }; }
    });
  return server;
}

const isMain = (() => { try { return pathToFileURL(realpathSync(process.argv[1])).href === import.meta.url; } catch { return false; } })();
if (isMain) {
  await buildServer().connect(new StdioServerTransport());
}
