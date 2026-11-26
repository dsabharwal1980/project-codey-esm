#!/usr/bin/env python3
"""Bundle playbook, skills, runbooks and knowledge packs into Static Resources served by the get_codey_playbook tool,
so every AI surface (MCP, Agentforce, Coworker) reads the same text as the repo.
Usage: python3 scripts/build-static-resources.py  (run from the repo root after editing any Markdown)"""
import os, re, glob, json
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'force-app/main/default/staticresources')
os.makedirs(OUT, exist_ok=True)
def meta(name, ctype, desc):
    open(os.path.join(OUT, f'{name}.resource-meta.xml'), 'w').write(f'''<?xml version="1.0" encoding="UTF-8"?>
<StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
    <cacheControl>Private</cacheControl>
    <contentType>{ctype}</contentType>
    <description>{desc}</description>
</StaticResource>
''')
def strip_front(t): return re.sub(r'^---\n.*?\n---\n', '', t, flags=re.S)
parts = []
pb = open(os.path.join(ROOT, 'playbook/PLAYBOOK.md')).read()
parts.append('\n## ' + pb.split('\n## ', 1)[1])  # keep the "## key" sections, drop the title
for f in sorted(glob.glob(os.path.join(ROOT, 'skills/*/SKILL.md'))):
    key = os.path.basename(os.path.dirname(f))
    body = strip_front(open(f).read()).replace('\n## ', '\n### ')
    parts.append(f'\n## skill:{key}\n' + body.split('\n', 1)[1])
for f in sorted(glob.glob(os.path.join(ROOT, 'playbook/runbooks/US-*.md'))):
    key = os.path.basename(f)[:-3]
    body = open(f).read().replace('\n## ', '\n### ')
    parts.append(f'\n## runbook:{key}\n' + body.split('\n', 1)[1])
open(os.path.join(OUT, 'Codey_Playbook.txt'), 'w').write(''.join(parts).strip() + '\n')
meta('Codey_Playbook', 'text/plain', 'Project Codey ESM: playbook, 8 skills and 11 runbooks (sections "## key"). Built from the repo.')
cp = open(os.path.join(ROOT, 'knowledge/concepts-pack.md')).read()
open(os.path.join(OUT, 'Codey_Concepts_Pack.txt'), 'w').write('\n## ' + cp.split('\n## ', 1)[1])
meta('Codey_Concepts_Pack', 'text/plain', 'Project Codey ESM: Concepts pack (sections "## key"). Built from the repo.')
rc = json.load(open(os.path.join(ROOT, 'knowledge/release-change-list.json')))
json.dump(rc, open(os.path.join(OUT, 'Codey_Release_Change_List.json'), 'w'), indent=1)
meta('Codey_Release_Change_List', 'application/json', 'Project Codey ESM: Release change list. Built from the repo.')
for n in ['Codey_Playbook.txt', 'Codey_Concepts_Pack.txt', 'Codey_Release_Change_List.json']:
    print(n, os.path.getsize(os.path.join(OUT, n)), 'bytes')
