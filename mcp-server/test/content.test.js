import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, search, sections } from '../src/content.js';
import { render } from '../src/cards.js';
import { buildServer } from '../src/index.js';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';

const c = loadContent();

test('loads 8 skills, 11 runbooks and the three packs', () => {
  assert.equal(Object.keys(c.skills).length, 8);
  assert.equal(Object.keys(c.runbooks).length, 11);
  assert.ok(c.conceptSections['quote-member-vs-line-item']);
  assert.ok(c.recommendedSettings.settings.length > 40);
  assert.ok(c.releaseChangeList.releases.length >= 1);
  assert.equal(c.mcpTools.length, 9);
});

test('playbook has the golden rules and routing', () => {
  assert.match(c.playbookSections.rules, /preview/i);
  assert.match(c.playbookSections.routing, /settings-health-check/);
});

test('search finds the pricing skill', () => {
  const r = search(c, 'regional surcharge pricing step');
  assert.ok(r.some((d) => d.id === 'skill:pricing'));
});

test('sections parser', () => {
  assert.deepEqual(Object.keys(sections('## a\nx\n## b\ny')), ['a', 'b']);
});

const card = {
  cardType: 'health', title: 'ESM settings health check', subtitle: 'Sandbox', hasBadge: true, badgeLabel: 'Needs Fix', badgeVariant: 'error',
  hasStats: true, stats: [{ label: 'OK', value: '40' }, { label: 'Needs Fix', value: '2' }], hasProgress: true, progressValue: 50, progressLabel: '50% done',
  hasItems: true, itemsTitle: 'Items to look at',
  items: [{ title: 'CPQ cache', subtitle: 'Cart performance depends on it', hasBadge: true, badgeLabel: 'Needs Fix', badgeVariant: 'error', hasAction: true, actionLabel: 'Fix it',
    actionMessage: 'Fix it: preview apply_esm_change ...', hasLink: true, linkLabel: 'Help', linkUrl: 'https://help.salesforce.com' },
  { title: 'Setting', hasBefore: true, beforeValue: 'true', afterValue: 'false' }],
  hasCallout: true, calloutTitle: 'Note', calloutText: 'x', calloutVariant: 'warning',
  hasNote: true, note: 'Read-only check.', hasButtons: true, buttons: [{ label: 'Approve', variant: 'primary', isMessage: true, message: 'Approve' }, { label: 'Help', isLink: true, url: 'https://help' }]
};

test('renders markdown, slack and adaptive cards', () => {
  assert.match(render(card), /ESM settings health check/);
  assert.match(render(card), /true → \*\*false\*\*/);
  const s = render(card, 'slack');
  assert.equal(s.blocks[0].type, 'header');
  assert.ok(s.blocks.some((b) => b.type === 'actions'));
  const a = render(card, 'adaptive');
  assert.equal(a.type, 'AdaptiveCard');
  assert.equal(a.actions.length, 2);
  assert.throws(() => render({}, 'markdown'));
});

test('MCP server lists tools, prompts and resources and answers calls', async () => {
  const server = buildServer(c);
  const [ct, st] = InMemoryTransport.createLinkedPair();
  await server.connect(st);
  const client = new Client({ name: 'test', version: '1.0.0' });
  await client.connect(ct);
  const tools = (await client.listTools()).tools.map((t) => t.name);
  assert.deepEqual(tools.sort(), ['get_codey_skill', 'get_recommended_settings', 'list_codey_skills', 'render_codey_card', 'search_codey_knowledge']);
  assert.equal((await client.listPrompts()).prompts.length, 8);
  assert.ok((await client.listResources()).resources.length >= 24);
  const skill = await client.callTool({ name: 'get_codey_skill', arguments: { name: 'pricing' } });
  assert.match(skill.content[0].text, /Golden rules|preview/i);
  const p = await client.getPrompt({ name: 'settings-health-check', arguments: { request: 'Check if my setup is correct' } });
  assert.match(p.messages[0].content.text, /check_esm_setup/);
  const r = await client.callTool({ name: 'render_codey_card', arguments: { card, format: 'slack' } });
  assert.match(r.content[0].text, /header/);
  await client.close();
});
