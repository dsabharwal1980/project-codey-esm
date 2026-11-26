// Loads the Project Codey content from the repo (single source of truth) – no copies.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const ROOT = resolve(process.env.CODEY_ROOT || join(here, '..', '..'));

const read = (p) => readFileSync(join(ROOT, p), 'utf8');
const stripFront = (t) => t.replace(/^---\n[\s\S]*?\n---\n/, '');

export function frontMatter(t) {
  const m = t.match(/^---\n([\s\S]*?)\n---\n/);
  const out = {};
  if (!m) return out;
  for (const line of m[1].split('\n')) {
    const i = line.indexOf(':');
    if (i > 0) out[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  return out;
}

/** "## key" sections of a Markdown document. */
export function sections(text) {
  const out = {};
  for (const part of ('\n' + text).split('\n## ').slice(1)) {
    const nl = part.indexOf('\n');
    out[(nl < 0 ? part : part.slice(0, nl)).trim().toLowerCase()] = '## ' + part.trim();
  }
  return out;
}

export function loadContent() {
  if (!existsSync(join(ROOT, 'playbook', 'PLAYBOOK.md'))) throw new Error(`Project Codey content not found under ${ROOT}. Set CODEY_ROOT to the repo folder.`);
  const playbook = read('playbook/PLAYBOOK.md');
  const skills = {};
  for (const d of readdirSync(join(ROOT, 'skills'))) {
    const p = join('skills', d, 'SKILL.md');
    if (!existsSync(join(ROOT, p))) continue;
    const raw = read(p);
    const fm = frontMatter(raw);
    skills[d] = { name: d, title: fm.name || d, description: fm.description || '', text: stripFront(raw), raw };
  }
  const runbooks = {};
  for (const f of readdirSync(join(ROOT, 'playbook', 'runbooks')).filter((f) => f.endsWith('.md'))) runbooks[f.replace('.md', '')] = read(join('playbook', 'runbooks', f));
  const concepts = read('knowledge/concepts-pack.md');
  return {
    playbook, playbookSections: sections(playbook), skills, runbooks,
    concepts, conceptSections: sections(concepts),
    recommendedSettings: JSON.parse(read('knowledge/recommended-settings.json')),
    releaseChangeList: JSON.parse(read('knowledge/release-change-list.json')),
    cardSchema: JSON.parse(read('hxl/cards/codey-card.schema.json')),
    mcpTools: JSON.parse(read('tools/mcp-tools.json'))
  };
}

/** Simple keyword search across playbook, skills, runbooks and concepts. */
export function search(content, query, limit = 5) {
  const terms = String(query || '').toLowerCase().split(/\W+/).filter((t) => t.length > 2);
  const docs = [];
  for (const [k, v] of Object.entries(content.playbookSections)) docs.push({ id: 'playbook:' + k, text: v });
  for (const s of Object.values(content.skills)) docs.push({ id: 'skill:' + s.name, text: s.text });
  for (const [k, v] of Object.entries(content.runbooks)) docs.push({ id: 'runbook:' + k, text: v });
  for (const [k, v] of Object.entries(content.conceptSections)) docs.push({ id: 'concept:' + k, text: v });
  return docs
    .map((d) => {
      const low = d.text.toLowerCase();
      const score = terms.reduce((n, t) => n + (low.split(t).length - 1) + (d.id.includes(t) ? 5 : 0), 0);
      return { ...d, score };
    })
    .filter((d) => d.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);
}
