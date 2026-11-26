#!/usr/bin/env python3
"""Adds the Project Codey "build" subagent to an existing ESM Coworker Agent Script (retrieved draft), idempotently.
Usage: python3 scripts/merge-coworker.py path/to/ESM_Coworker.agent
Then: sf agent validate authoring-bundle --api-name ESM_Coworker ... and sf agent publish authoring-bundle --api-name ESM_Coworker ..."""
import sys, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
path = sys.argv[1]
src = open(path).read()
if 'subagent build:' in src:
    print('Coworker already has the Codey build subagent – nothing to do.'); sys.exit(0)
snip = open(os.path.join(ROOT, 'adapters/coworker/codey_build_subagent.agent.txt')).read()
router_line = re.search(r'^#\s{3}(- Setting up.*)$', snip, re.M).group(1)
go_build = '\n'.join(l for l in snip.split('\n') if l.strip().startswith('go_build:') or 'Project Codey build helper: setup' in l)
sub = snip[snip.index('subagent build:'):]
lines = src.split('\n')
# locate the start_agent block
start = next(i for i, l in enumerate(lines) if l.startswith('start_agent '))
end = next((i for i in range(start + 1, len(lines)) if lines[i] and not lines[i].startswith(' ')), len(lines))
acts = next(i for i in range(start, end) if lines[i].strip() == 'actions:' and lines[i].startswith(' ' * 8) and not lines[i].startswith(' ' * 12))
# router instruction line: indent like the previous instruction continuation line
prev = acts - 1
while not lines[prev].strip(): prev -= 1
indent = re.match(r'^(\s*)(\| )?', lines[prev]).group(1) + ('  ' if lines[prev].lstrip().startswith('| ') else '')
pos = next((i for i in range(start, acts) if '- A greeting' in lines[i] or '- Anything else' in lines[i]), acts)
lines.insert(pos, indent + router_line)
acts += 1
lines.insert(acts + 1, go_build)
out = '\n'.join(lines).rstrip() + '\n\n' + sub
open(path, 'w').write(out)
print('Merged the Codey build subagent into', path)
