#!/usr/bin/env python3
"""Generates tools/<tool>.schema.json and tools/README.md (developer notes) from the tool spec in build-agents.py."""
import json, os, importlib.util
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('ba', os.path.join(ROOT, 'scripts/build-agents.py'))
ba = importlib.util.module_from_spec(spec); spec.loader.exec_module(ba)
mcp = {t['toolName']: t for t in json.load(open(os.path.join(ROOT, 'tools/mcp-tools.json')))}
JT = {'string': 'string', 'boolean': 'boolean', 'number': 'integer'}
PRD = {'run_esm_admin_jobs': 'PRD agent tool 1 – Admin jobs tool', 'preview_esm_price': 'PRD agent tool 2 – Price preview tool', 'check_quote_members_bulk': 'PRD agent tool 3 – Bulk address and serviceability tool'}
CARD = {'check_esm_setup': 'Health check report', 'manage_esm_permissions': 'Approval', 'apply_esm_change': 'Approval', 'run_esm_admin_jobs': 'Approval (preview) / Progress tracker',
        'preview_esm_price': 'Approval-style price breakdown', 'check_quote_members_bulk': 'Approval (preview) / Progress tracker', 'check_esm_upgrade_impact': 'Upgrade impact report',
        'track_codey_job': 'Progress tracker', 'get_codey_playbook': '–'}
md = ['# Codey MCP tools – developer notes', '',
      'All tools are Apex `@InvocableMethod` classes exposed by the Salesforce Hosted MCP server **EsmCodeyEaseOfBuild** (`apiSource=API_CATALOG`, `aa:apex-<Class>`) and, with identical inputs/outputs, as Agentforce actions (`apex://<Class>`). They run `with sharing` as the signed-in user; writes use `AccessLevel.USER_MODE`.', '',
      '**Common output (`CodeyResult`)**: `success`, `mode` (read/preview/commit/status), `message`, `previewToken`, `resultJson`, `jobId`, `changeLogId`, `nextStep`, `fix`, `card` (`CodeyCard`, see hxl/cards/codey-card.schema.json).', '',
      '**Approval gate**: a preview stores a `Codey_Change_Log__c` (Status Previewed, 30-minute expiry) with token = SHA-256(tool | user | normalised inputs). A commit must send that token and the same inputs (re-hashed) as the same user; otherwise it is refused. Production orgs also require `confirmProduction=true`. Every read and change is logged (PRD usage tracking).', '',
      '| Tool | Apex class | Card | Notes |', '|---|---|---|---|']
os.makedirs(os.path.join(ROOT, 'tools'), exist_ok=True)
for name, (cls, title, desc, inputs) in ba.TOOLS.items():
    schema = {'$schema': 'https://json-schema.org/draft/2020-12/schema', 'title': name, 'description': mcp[name]['description'], 'x-apex-class': cls,
              'type': 'object', 'properties': {n: {'type': JT[t], 'description': d} for n, t, d, r in inputs}, 'required': [n for n, t, d, r in inputs if r],
              'x-output': {n: {'type': JT[t], 'description': d} for n, t, d in ba.OUT} | {'card': {'$ref': '../hxl/cards/codey-card.schema.json'}}}
    json.dump(schema, open(os.path.join(ROOT, 'tools', name + '.schema.json'), 'w'), indent=2)
    md.append(f'| `{name}` | `{cls}` | {CARD[name]} | {PRD.get(name, "")} |')
md += ['', '## Inputs per tool', '']
for name, (cls, title, desc, inputs) in ba.TOOLS.items():
    md += [f'### {name}' + (f' ({PRD[name]})' if name in PRD else ''), '', mcp[name]['description'], '', '| Input | Type | Required | Description |', '|---|---|---|---|']
    md += [f'| `{n}` | {JT[t]} | {"yes" if r else ""} | {d} |' for n, t, d, r in inputs] + ['']
md += ['## Errors', '', 'Tools never throw to the client: `success=false`, `message` (what happened) and `fix` (plain-language next step). Common: no preview token / inputs changed / preview expired (run preview again); production confirmation needed; missing access (permissions skill); a job already running (track it).', '',
       '## Configuration (per org, no code change)', '', '- `Codey_Recommended_Setting__mdt` – rules of the health check (source, target, operator, recommended, severity, reason, help link, fixable, secret).',
       '- `Codey_UserType_Permission__mdt` – permission sets per user type.', '- `Codey_Admin_Job__mdt` – admin jobs, order, mode (batch / service / manual), class, batch size, groups.',
       '- `Codey_Check_Provider__mdt` – address/serviceability provider: Builtin, IntegrationProcedure (default ESM IPs) or ApexClass implementing `CodeyBulkCheck.Provider`.',
       '- Static Resources `Codey_Playbook`, `Codey_Concepts_Pack`, `Codey_Release_Change_List` – built from the repo (`scripts/build-static-resources.py`).']
open(os.path.join(ROOT, 'tools', 'README.md'), 'w').write('\n'.join(md) + '\n')
print('tool docs ok')
