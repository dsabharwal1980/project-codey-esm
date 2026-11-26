#!/usr/bin/env python3
"""Read-only showcase of the Project Codey skills in any org.
Runs only read/explain calls (no previews, no commits, no changes to ESM data or settings) and writes a Markdown report with the
message, key figures and the rendered experience card of each step.
Each read adds one usage line to the Codey Change Log (built-in usage tracking) – nothing else is written.

Usage: python3 scripts/showcase.py <org-alias> [enterprise-quote-id]
Output: docs/showcase/<org-alias>-showcase.md
"""
import json, os, subprocess, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORG = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)
QUOTE = sys.argv[2] if len(sys.argv) > 2 else None


def sf(*args):
    r = subprocess.run(['sf', *args, '-o', ORG, '--json'], capture_output=True, text=True)
    return json.loads(r.stdout or '{}')


def query(soql):
    return sf('data', 'query', '-q', soql).get('result', {}).get('records', [])


def call(cls, inputs):
    r = subprocess.run(['sf', 'api', 'request', 'rest', f'/services/data/v64.0/actions/custom/apex/{cls}', '-o', ORG,
                        '--method', 'POST', '--body', json.dumps({'inputs': [dict(inputs, surface='showcase')]})], capture_output=True, text=True)
    try:
        d = json.loads(r.stdout)[0]
    except Exception:
        return {'success': False, 'message': (r.stdout + r.stderr)[:500]}
    o = d.get('outputValues') or {}
    if not d.get('isSuccess'):
        o = {'success': False, 'message': str(d.get('errors'))}
    return o


def card_md(card):
    if not card:
        return '_(no card)_'
    r = subprocess.run(['node', os.path.join(ROOT, 'mcp-server/src/render-cli.js'), 'markdown'], input=json.dumps(card), capture_output=True, text=True)
    return r.stdout.strip() or '_(card could not be rendered)_'


def figures(o):
    try:
        d = json.loads(o.get('resultJson') or '{}')
    except Exception:
        return {}
    return d


if not QUOTE:
    rows = query("SELECT vlocity_cmt__QuoteId__c q, COUNT(Id) c FROM vlocity_cmt__QuoteMember__c GROUP BY vlocity_cmt__QuoteId__c ORDER BY COUNT(Id) DESC LIMIT 1")
    QUOTE = rows[0]['q'] if rows else None
org = sf('org', 'display').get('result', {})
org_name = (query('SELECT Name, OrganizationType, IsSandbox FROM Organization') or [{}])[0]

STEPS = [
    # (skill / building block, what it shows, class, inputs)
    ('Playbook', 'Routing table: which skill answers which request', 'CodeyPlaybookTool', {'topic': 'routing'}),
    ('Playbook', 'Golden rules every agent follows', 'CodeyPlaybookTool', {'topic': 'rules'}),
    ('Fresh install (read-only part)', 'Prerequisite check before an install', 'CodeyHealthCheckTool', {'scope': 'prereq'}),
    ('Settings health check', 'Full health check report: OK / Warning / Needs Fix', 'CodeyHealthCheckTool', {'scope': 'all'}),
    ('Settings health check', 'Health check of one area (add assets to quote)', 'CodeyHealthCheckTool', {'scope': 'assets'}),
    ('Permissions (read-only part)', 'Recommended permission sets per user type and admin jobs (knowledge pack)', 'CodeyPlaybookTool', {'topic': 'settings'}),
    ('Permissions (read-only part)', 'Permission health in the org', 'CodeyHealthCheckTool', {'scope': 'permissions'}),
    ('Admin jobs (read-only part)', 'Admin job history check', 'CodeyHealthCheckTool', {'scope': 'adminjobs'}),
    ('Upgrade check', 'Customized screens a release affects', 'CodeyUpgradeImpactTool', {}),
    ('Concepts guide', 'Quote Member vs quote line item, with real data from a quote', 'CodeyPlaybookTool', {'topic': 'concept:quote-member-vs-line-item', 'quoteId': QUOTE}),
    ('Concepts guide', 'Data model explained with real data', 'CodeyPlaybookTool', {'topic': 'concept:data-model', 'quoteId': QUOTE}),
    ('Pricing', 'The pricing plan explained step by step', 'CodeyPricePreviewTool', {'explainPlan': True}),
    ('Pricing / Promotions & discounts', 'Prices, promotions and discounts on an existing quote (read-only)', 'CodeyPricePreviewTool', {'quoteId': QUOTE}),
    ('Customization (read-only part)', 'Context rules explained + quoting settings they need', 'CodeyPlaybookTool', {'topic': 'concept:context-rules'}),
    ('Customization (read-only part)', 'Quoting settings (context rules, promotions, bulk updates)', 'CodeyHealthCheckTool', {'scope': 'quoting'}),
    ('Bulk members (read-only part)', 'Address and serviceability explained with the quote\'s numbers', 'CodeyPlaybookTool', {'topic': 'concept:address-serviceability', 'quoteId': QUOTE}),
    ('Progress tracker', 'Latest Codey background job (if any)', 'CodeyTrackJobTool', {}),
]

out = [f"# Project Codey – read-only showcase ({org.get('alias') or ORG})", '',
       f"Org: **{org_name.get('Name', ORG)}** ({'Sandbox' if org_name.get('IsSandbox') else org_name.get('OrganizationType', '')}) · run {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')} · quote used for examples: `{QUOTE}`", '',
       'Only read / explain calls were made: no previews, no commits, no changes to ESM settings, quotes, products or permissions. '
       'Each call adds one usage line (surface "showcase") to the Codey Change Log.', '',
       '| # | Skill | What it shows | Result |', '|---|---|---|---|']
detail = []
for i, (skill, what, cls, inputs) in enumerate(STEPS, 1):
    inputs = {k: v for k, v in inputs.items() if v is not None}
    o = call(cls, inputs)
    ok = o.get('success')
    msg = (o.get('message') or '').strip()
    first = next((l.strip() for l in msg.split('\n') if l.strip() and not l.lstrip().startswith(('#', '|'))), '')[:160]
    expected = (not ok) and 'No Codey job found' in msg
    out.append(f"| {i} | {skill} | {what} | {'✅' if ok else ('ℹ️ expected:' if expected else '⚠️')} {first} |")
    detail += [f'## {i}. {skill} – {what}', '', f'Tool: `{cls}` · inputs: `{json.dumps(inputs)}`', '']
    body = msg if len(msg) < 2500 else msg[:2500] + '\n…(shortened)'
    detail += ['**What the agent gets back (message):**', '', '```', body, '```', '']
    if o.get('nextStep'):
        detail += [f"**Next step suggested:** {o['nextStep']}", '']
    if o.get('card'):
        detail += ['**Experience card (as shown on text surfaces; Lightning / Agentforce show the HXL widget):**', '', card_md(o['card']), '']
    detail.append('')
    print(f'{i:2}. {skill}: {"ok" if ok else ("expected (nothing to track yet)" if expected else "NOT OK")} – {first}')

out += ['', '## Cards that need a change to appear', '',
        'The **Approval** card appears on every preview and the **Progress tracker** on every background job. They were not produced here because that would '
        'start a preview or a job. Sample renderings: `hxl/samples/markdown/approval.md` and `hxl/samples/markdown/progress.md` (Slack and Teams versions next to them).', '']
os.makedirs(os.path.join(ROOT, 'docs/showcase'), exist_ok=True)
path = os.path.join(ROOT, 'docs/showcase', f'{org.get("alias") or ORG}-showcase.md')
open(path, 'w').write('\n'.join(out + [''] + detail) + '\n')
print('report:', os.path.relpath(path, ROOT))
