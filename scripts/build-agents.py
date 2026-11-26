#!/usr/bin/env python3
"""Generates the Agent Script for the Project Codey agents from one tool spec (inputs/outputs match the Apex
@InvocableVariable names exactly):
  force-app/main/default/aiAuthoringBundles/ESM_Codey/ESM_Codey.agent   - standalone Agentforce employee agent (8 skills = 8 subagents)
  adapters/coworker/codey_build_subagent.agent.txt                      - "build" subagent + router line for an existing ESM Coworker
  scripts/merge-coworker.py uses the snippet to extend a retrieved Coworker draft.
Run from the repo root: python3 scripts/build-agents.py"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
I = '    '

S, B, N = 'string', 'boolean', 'number'
OUT = [('success', B, 'True when the request worked.'), ('message', S, 'Plain-language result to tell the person.'),
       ('previewToken', S, 'Returned by a preview; pass it back with mode=commit and the same inputs only after the person approved.'),
       ('nextStep', S, 'Suggested next action.'), ('fix', S, 'How to resolve a problem when success is false.'),
       ('jobId', S, 'Background job id to track.'), ('changeLogId', S, 'Codey Change Log record (audit, undo).'),
       ('resultJson', S, 'Structured details as JSON.')]
TOOLS = {
 'get_codey_playbook': ('CodeyPlaybookTool', 'Get Codey Playbook', 'Read-only: Project Codey playbook, a skill, a runbook, a concept (with real examples from a quote), the recommended settings or the release change list.', [
     ('topic', S, 'overview, routing, rules, skill:<name>, runbook:US-01..US-11, concept:<key> or concept:all, settings, releases, index.', False),
     ('quoteId', S, 'Optional quote Id or name for real examples in concept answers.', False), ('surface', S, 'Where the request comes from, for example Agentforce or Coworker.', False)]),
 'check_esm_setup': ('CodeyHealthCheckTool', 'Check ESM Setup', 'Read-only ESM settings health check: OK / Warning / Needs Fix per item with reason, help link and fix.', [
     ('scope', S, 'all (default), prereq, quoting, assets, performance, console, permissions or adminjobs.', False), ('surface', S, 'Where the request comes from.', False)]),
 'manage_esm_permissions': ('CodeyPermissionsTool', 'Manage ESM Permissions', 'Preview, then after approval assign, the recommended ESM permission sets for a user type. Only adds.', [
     ('mode', S, 'preview (default) or commit after the person approved.', False), ('userType', S, 'Sales rep, Sales manager, Admin, Pricing admin, Product designer, Service agent or Coworker user.', True),
     ('users', S, 'Comma-separated usernames, e-mails, names or Ids.', False), ('profile', S, 'Profile name.', False), ('role', S, 'Role name.', False),
     ('previewToken', S, 'Token from the preview, for commit.', False), ('confirmProduction', B, 'true only if the person confirmed a production change.', False), ('surface', S, 'Where the request comes from.', False)]),
 'apply_esm_change': ('CodeyApplyChangeTool', 'Apply ESM Change', 'Approved configuration change with Before/After preview and undo: CPQ setting, Enrich Quote option, pricing plan step, context rule, Quote Member Binding, linear relationship.', [
     ('mode', S, 'preview (default) or commit after the person approved.', False),
     ('changeType', S, 'cpqSetting, enrichQuoteOption, generalSetting, pricingPlanStep, contextRule, contextRuleset, attributeBinding, linearRelationship, record or undo.', True),
     ('target', S, 'Setting name, object API name (record) or change log CL-... (undo).', False), ('value', S, 'New setting value.', False),
     ('fieldsJson', S, 'JSON with the fields for record changes.', False), ('recordId', S, 'Existing record to update.', False), ('reason', S, 'Why the change is made.', False),
     ('previewToken', S, 'Token from the preview, for commit.', False), ('confirmProduction', B, 'true only if the person confirmed a production change.', False), ('surface', S, 'Where the request comes from.', False)]),
 'run_esm_admin_jobs': ('CodeyAdminJobsTool', 'Run ESM Admin Jobs', 'ESM admin jobs in the documented order with progress; preview, commit after approval, status, resume.', [
     ('mode', S, 'preview (default), commit after approval, or status.', False), ('jobs', S, 'default, catalog, pricing, promotions, repair or job keys.', False),
     ('jobId', S, 'Codey job id for status or resume.', False), ('previewToken', S, 'Token from the preview, for commit.', False),
     ('confirmProduction', B, 'true only if the person confirmed running jobs in production.', False), ('surface', S, 'Where the request comes from.', False)]),
 'preview_esm_price': ('CodeyPricePreviewTool', 'Preview ESM Price', 'Price a sample quote without saving (every step, promotions, discounts); explain the pricing plan or an existing quote; simulate a new pricing step.', [
     ('mode', S, 'preview (default) or commit to keep a test quote after approval.', False), ('products', S, 'Comma-separated product names, codes or Ids.', False),
     ('quantity', N, 'Quantity per product.', False), ('account', S, 'Account Id or name.', False), ('priceList', S, 'Price list name.', False),
     ('quoteId', S, 'Existing quote to explain (read-only).', False), ('explainPlan', B, 'true to list the pricing plan steps.', False),
     ('proposedStepJson', S, 'Pricing plan step JSON to simulate.', False), ('previewToken', S, 'Token from the preview, for commit.', False),
     ('confirmProduction', B, 'true only if the person confirmed in production.', False), ('surface', S, 'Where the request comes from.', False)]),
 'check_quote_members_bulk': ('CodeyBulkCheckTool', 'Check Quote Members Bulk', 'Load many quote members from a spreadsheet and check addresses and serviceability in the background, with a results file.', [
     ('mode', S, 'preview (default), commit after approval, or status.', False), ('quoteId', S, 'Enterprise Quote Id or name.', True),
     ('membersCsv', S, 'CSV text with a header row (name/site, street/address, city, state, postal code, country).', False),
     ('contentDocumentId', S, 'ContentDocument Id (069...) of an attached CSV.', False), ('checks', S, 'address, serviceability, or none.', False),
     ('onlyUnchecked', B, 'false to re-check every member.', False), ('jobId', S, 'Codey job id for status or resume.', False),
     ('previewToken', S, 'Token from the preview, for commit.', False), ('confirmProduction', B, 'true only if the person confirmed in production.', False), ('surface', S, 'Where the request comes from.', False)]),
 'check_esm_upgrade_impact': ('CodeyUpgradeImpactTool', 'Check ESM Upgrade Impact', 'Read-only: customized ESM screens a release affects, risk and suggested action.', [
     ('targetRelease', S, 'Release, for example 268 (default newest).', False), ('includeStandard', B, 'true to also list non-customized components.', False), ('surface', S, 'Where the request comes from.', False)]),
 'track_codey_job': ('CodeyTrackJobTool', 'Track Codey Job', 'Read-only progress of a Codey background job: steps, errors, results file, resume.', [
     ('jobId', S, 'Codey job id or CJ-... name.', False), ('quoteId', S, 'Quote Id or name for its latest job.', False), ('tool', S, 'run_esm_admin_jobs or check_quote_members_bulk.', False), ('surface', S, 'Where the request comes from.', False)]),
}

RULES = '''Golden rules (Project Codey playbook):
- Look before you act: start with a read (check_esm_setup, get_codey_playbook or a preview).
- Every change is two calls: mode=preview, then tell the person exactly what will change (the card shows Before and After) and ask for a clear yes. Only after an explicit "yes / approve" in this conversation, call the same action with mode=commit, the previewToken and the SAME inputs. "No", silence or a changed request means no commit.
- If an action says the org is production, warn the person; only if they confirm, repeat the commit with confirmProduction = true.
- Never ask for, repeat or pass a secret (Google Maps key or any key) in chat: send the person to App Launcher → Codey Setup → Google Maps key.
- Never invent values (prices, settings, permission sets, products). Use the action results and the playbook.
- Long jobs: one at a time; track them with track_codey_job; a failed job resumes from where it stopped.
- After every commit, run the check named in the step and say OK or not OK, with the change log id.
- Keep answers short: at most 5 lines and one small list; the card shows the details.'''

SUBAGENTS = [
 ('setup', 'Fresh install and admin jobs', 'Install and set up Enterprise Sales Management on a sandbox (prerequisites, configuration packs, permission sets, Console, Google Maps, admin jobs, a priced test quote) and run the admin jobs.',
  ['get_codey_playbook', 'check_esm_setup', 'manage_esm_permissions', 'apply_esm_change', 'run_esm_admin_jobs', 'preview_esm_price', 'track_codey_job'],
  '''Follow skill:fresh-install (call {!@actions.get_codey_playbook} with topic skill:fresh-install if you need the full steps).
  1. Check prerequisites with {!@actions.check_esm_setup} scope prereq. A missing licence or package cannot be fixed by you: say what to request.
  2. Show the install plan (packs, permission sets, Console, Google Maps, admin jobs, test quote, health check) and ask to go ahead.
  3. Configuration packs are loaded by an admin or a developer tool (OmniStudio/Vlocity build tool); ask the person to confirm they are loaded.
  4. Permission sets: {!@actions.manage_esm_permissions} preview, approval, commit.
  5. Console: {!@actions.check_esm_setup} scope console; fixes with {!@actions.apply_esm_change} (preview, approval, commit). Google Maps key: only on the Codey Setup page.
  6. Admin jobs: {!@actions.run_esm_admin_jobs} preview, approval, commit; then {!@actions.track_codey_job} with the jobId. Explain failures in plain words and offer resume (preview with jobId, approval, commit with jobId). Manual steps are done by the person in CMT Administration.
  7. Test quote: {!@actions.preview_esm_price} with one offer the person names; keep it only after approval (mode commit, same inputs, previewToken).
  8. Finish with {!@actions.check_esm_setup} scope all and a short summary.'''),
 ('health', 'Settings health check', 'Check whether the org has the quoting, add-assets-to-quote, performance, Console, permission and admin-job settings ESM needs, and fix items after approval.',
  ['check_esm_setup', 'apply_esm_change', 'manage_esm_permissions', 'run_esm_admin_jobs', 'get_codey_playbook'],
  '''Follow skill:settings-health-check.
  1. Run {!@actions.check_esm_setup} (scope all, or the area the person names). Give the counts, then the Needs Fix and Warning items (name, current, recommended, why). Never show masked values.
  2. A fix is always a preview first: CPQ settings with {!@actions.apply_esm_change} changeType cpqSetting, target and value from the item's fix; permissions with {!@actions.manage_esm_permissions}; admin jobs with {!@actions.run_esm_admin_jobs}. Commit only after an explicit yes. A Warning may be a deliberate choice: ask before fixing it.
  3. Re-run {!@actions.check_esm_setup} for that area and report the new status.'''),
 ('access', 'Permissions', 'Give each ESM user type the right permission sets: compare, preview, assign after approval, check again.',
  ['manage_esm_permissions', 'get_codey_playbook', 'check_esm_setup'],
  '''Follow skill:permissions.
  1. Find the user type and the users (names, usernames, a profile or a role); ask once if unclear. The recommended sets per user type are in {!@actions.get_codey_playbook} topic settings.
  2. {!@actions.manage_esm_permissions} mode preview; say per user what is missing.
  3. Only after an explicit yes: mode commit with previewToken and the same inputs.
  4. Preview again to confirm everyone is OK. Never remove permission sets.'''),
 ('pricing', 'Pricing', 'Explain price plans and pricing steps, preview pricing changes (new steps, attribute, location and frame contract pricing) with their price effect, apply after approval and test on a sample quote.',
  ['preview_esm_price', 'apply_esm_change', 'run_esm_admin_jobs', 'get_codey_playbook'],
  '''Follow skill:pricing.
  1. Explain the current plan with {!@actions.preview_esm_price} explainPlan true; one line per step (concept:pricing-plan).
  2. Work out the change and the fields needed; ask for missing values, never invent amounts. For attribute, location or frame contract pricing read the concept with {!@actions.get_codey_playbook}.
  3. Preview: {!@actions.apply_esm_change} changeType pricingPlanStep (fieldsJson) AND {!@actions.preview_esm_price} with sample products and proposedStepJson to show the price before and after. Nothing is saved.
  4. After an explicit yes: commit the apply_esm_change with the same inputs and previewToken. If prices are cached, run {!@actions.run_esm_admin_jobs} jobs pricing (preview, approval, commit).
  5. Test: {!@actions.preview_esm_price} with the same sample; offer undo (changeType undo, target the change log) if the result is wrong.
  To explain why a quote has its prices, promotions and discounts, call {!@actions.preview_esm_price} with quoteId.'''),
 ('customize', 'Customization', 'Set up linear relationships, Quote Member Binding, context rules for products on quote members and Enrich Quote options: explain, draft, preview, apply after approval, test.',
  ['get_codey_playbook', 'apply_esm_change', 'preview_esm_price', 'check_esm_setup', 'run_esm_admin_jobs'],
  '''Follow skill:customization.
  1. Explain the best option using {!@actions.get_codey_playbook} concept context-rules, quote-member-binding, linear-relationships or enrich-quote. Check prerequisites (for context rules: ContextRulesEnabled with {!@actions.check_esm_setup} scope quoting).
  2. Draft the change for {!@actions.apply_esm_change}: contextRule (name, ruleset, product, expression, failureMessage; created inactive), contextRuleset, attributeBinding (attribute, objectClass, fieldApiName), linearRelationship (product, relatedProduct, relationshipType), enrichQuoteOption (target setting, value).
  3. Preview, explicit yes, commit. Turning a rule on is a second approved change.
  4. Test on sample members or a sample quote with {!@actions.preview_esm_price}; caches may need {!@actions.run_esm_admin_jobs} jobs catalog.'''),
 ('members', 'Bulk members', 'Load many quote members from a spreadsheet and check addresses and serviceability in the background, with progress and a results file.',
  ['check_quote_members_bulk', 'track_codey_job', 'get_codey_playbook'],
  '''Follow skill:bulk-members.
  1. Read the spreadsheet the person attached and pass its rows as membersCsv (or the file id as contentDocumentId) to {!@actions.check_quote_members_bulk} mode preview with the quote. Report recognised columns, rows to load, duplicates and rows with errors.
  2. Only after an explicit yes: mode commit with previewToken and the same inputs.
  3. Track with {!@actions.track_codey_job}; when completed, give the results file and the counts (valid / partial / invalid, serviceable / not) and the top reasons.'''),
 ('upgrade', 'Upgrade check', 'Show which customized ESM screens a new release affects, with risk and suggested action; suggest a combined version for review only.',
  ['check_esm_upgrade_impact', 'get_codey_playbook'],
  '''Follow skill:upgrade-check.
  1. Call {!@actions.check_esm_upgrade_impact} (targetRelease if the person names one). Give the counts and the High items first with the suggested action.
  2. If the person asks for a combined version of a screen, explain that it is prepared as a suggestion for review on a developer surface and never saved without approval.
  If the release list is a sample, say so.'''),
 ('concepts', 'Concepts guide', 'Answer questions about Enterprise Quotes, Quote Members, quote lines, Enterprise Orders, pricing, promotions and discounts, linear relationships, Quote Member Binding, context rules, Enrich Quote and serviceability, with examples from the org.',
  ['get_codey_playbook', 'preview_esm_price'],
  '''Follow skill:concepts-guide.
  1. Call {!@actions.get_codey_playbook} with topic concept:<key> (data-model, quote-member-vs-line-item, enterprise-order, pricing-plan, attribute-pricing, location-pricing, frame-contract-pricing, promotions-vs-discounts, linear-relationships, quote-member-binding, context-rules, enrich-quote, address-serviceability, admin-jobs) and, when a quote is open or named, quoteId for real examples.
  2. Which promotions and discounts applied on a quote, and why: {!@actions.preview_esm_price} with quoteId.
  3. Answer in 3 to 6 sentences or a small comparison, with one example from the org and the help link. Only use the pack and action results.'''),
]

def action_def(key, suffix=''):
    cls, label, desc, inputs = TOOLS[key]
    L = [f'{I*2}{key}{suffix}:', f'{I*3}description: "{desc}"', f'{I*3}label: "{label}"', f'{I*3}require_user_confirmation: False',
         f'{I*3}include_in_progress_indicator: True', f'{I*3}progress_indicator_message: "{label}"', f'{I*3}target: "apex://{cls}"', f'{I*3}inputs:']
    for n, t, d, req in inputs:
        L += [f'{I*4}{n}: {t}', f'{I*5}description: "{d}"', f'{I*5}label: "{n}"', f'{I*5}is_required: {"True" if req else "False"}']
    L.append(f'{I*3}outputs:')
    for n, t, d in OUT:
        L += [f'{I*4}{n}: {t}', f'{I*5}description: "{d}"', f'{I*5}label: "{n}"', f'{I*5}is_displayable: False', f'{I*5}filter_from_agent: False']
    return L

def invocations(keys, suffix=''):
    L = []
    for k in keys:
        L.append(f'{I*3}{k}: @actions.{k}{suffix}')
        for n, *_ in TOOLS[k][3]:
            L.append(f'{I*4}with {n} = ' + ('"Agentforce"' if n == 'surface' else '...'))
    return L

def subagent(name, label, desc, keys, steps, transitions, suffix='', surface='Agentforce'):
    L = [f'subagent {name}:', f'{I}label: "{label}"', f'{I}description: "{desc}"', '', f'{I}reasoning:', f'{I*2}instructions: ->']
    first = True
    for line in steps.strip().split('\n'):
        L.append(f'{I*3}{"| " if first else "  "}{line.strip()}')
        first = False
    L += [f'{I*3}  Use only the results of the actions; keep the golden rules.', f'{I*2}actions:']
    L += [l.replace('"Agentforce"', f'"{surface}"') for l in invocations(keys, suffix)]
    for t, d in transitions: L += [f'{I*3}go_{t}: @utils.transition to @subagent.{t}', f'{I*4}description: "{d}"']
    L += ['', f'{I}actions:']
    for k in keys: L += action_def(k, suffix) + ['']
    return L

def agent():
    L = ['system:', f'{I}instructions: |']
    intro = ('You are Codey for Enterprise Sales Management (ESM), a Project Codey agent. You set up, check, change and explain ESM for consultants, admins, '
             'architects and support teams, using the Codey actions and the Project Codey playbook.')
    L += [f'{I*2}{intro}', '']
    L += [f'{I*2}{l}' for l in RULES.split('\n')]
    L += ['', f'{I*2}The user\'s current context is: app {{!@variables.currentAppName}}, object {{!@variables.currentObjectApiName}}, page {{!@variables.currentPageType}}, record {{!@variables.currentRecordId}}.',
          f'{I}messages:', f'{I*2}welcome: "Hi, I am Codey for Enterprise Sales Management. I can install and set up ESM, check your settings, give permissions, run admin jobs, change pricing and rules, load and check thousands of sites, check upgrades and explain how ESM works. What do you need?"',
          f'{I*2}error: "Something went wrong on my side. Nothing was changed; try again."', '',
          'config:', f'{I}developer_name: "ESM_Codey"', f'{I}agent_label: "ESM Codey"',
          f'{I}description: "Project Codey agent for Enterprise Sales Management ease of build: fresh install, settings health check, permissions, admin jobs, pricing, customization, bulk member checks, upgrade impact and concepts, with preview and approval before every change."',
          f'{I}agent_type: "AgentforceEmployeeAgent"', '', 'language:', f'{I}default_locale: "en_US"', f'{I}additional_locales: ""', f'{I}all_additional_locales: False', '',
          'variables:']
    for v, d in [('currentAppName', 'Salesforce Application Name'), ('currentObjectApiName', 'The API name of the current Salesforce object'), ('currentPageType', 'Page type (record, list, home)'), ('currentRecordId', 'The Salesforce ID of the current record')]:
        L += [f'{I}{v}: mutable string', f'{I*2}description: "{d}"', f'{I*2}visibility: "External"']
    L += ['', 'start_agent router:', f'{I}label: "Router"', f'{I}description: "Send the request to the right Codey skill."', '', f'{I}reasoning:', f'{I*2}instructions: ->',
          f'{I*3}| Choose the skill for the request:',
          f'{I*3}  - install or set up ESM, a new sandbox, run or refresh the admin jobs, products or prices look stale: {{!@actions.go_setup}}',
          f'{I*3}  - check my settings, is my setup correct, health check, a setting problem, adding assets fails, slow cart: {{!@actions.go_health}}',
          f'{I*3}  - access, permission sets, a user cannot see something, a new team: {{!@actions.go_access}}',
          f'{I*3}  - price plan, pricing step, surcharge, attribute / location / frame contract pricing, why a price is what it is: {{!@actions.go_pricing}}',
          f'{I*3}  - context rule, only allow a product at some sites, Quote Member Binding, linear relationship, Enrich Quote options: {{!@actions.go_customize}}',
          f'{I*3}  - load many sites or quote members, address verification, serviceability, a spreadsheet of sites: {{!@actions.go_members}}',
          f'{I*3}  - the next upgrade or release, customized screens: {{!@actions.go_upgrade}}',
          f'{I*3}  - how something works, explain, difference between, promotions vs discounts: {{!@actions.go_concepts}}',
          f'{I*3}  - a greeting or "what can you do": answer in one sentence with the list of skills.',
          f'{I*2}actions:']
    for name, label, desc, *_ in SUBAGENTS: L += [f'{I*3}go_{name}: @utils.transition to @subagent.{name}', f'{I*4}description: "{label}: {desc}"']
    L.append('')
    for name, label, desc, keys, steps in SUBAGENTS:
        trans = [('concepts', 'The person asks how something works.')] if name != 'concepts' else [('pricing', 'The person wants to change pricing.')]
        L += subagent(name, label, desc, keys, steps, trans) + ['']
    return '\n'.join(L).rstrip() + '\n'

def coworker_snippet():
    keys = ['get_codey_playbook', 'check_esm_setup', 'manage_esm_permissions', 'apply_esm_change', 'run_esm_admin_jobs', 'preview_esm_price', 'check_quote_members_bulk', 'check_esm_upgrade_impact', 'track_codey_job']
    steps = '''You are the build helper inside the ESM Coworker (Project Codey). For setup, settings, permissions, admin jobs, pricing plans, rules, bulk site checks, upgrades and how-it-works questions:
  - First call {!@actions.get_codey_playbook} with the matching skill (skill:fresh-install, skill:settings-health-check, skill:permissions, skill:pricing, skill:customization, skill:bulk-members, skill:upgrade-check, skill:concepts-guide) and follow it; for concepts pass the open quote as quoteId.
  - Settings check: {!@actions.check_esm_setup}. Permissions: {!@actions.manage_esm_permissions}. Settings, pricing steps and rules: {!@actions.apply_esm_change}. Admin jobs: {!@actions.run_esm_admin_jobs}. Prices and steps of this quote or a sample: {!@actions.preview_esm_price}. Load and check many sites on this quote: {!@actions.check_quote_members_bulk}. Upgrades: {!@actions.check_esm_upgrade_impact}. Progress: {!@actions.track_codey_job}.
  - Every change is mode preview first; say in one sentence what will change and ask for a clear yes; only then mode commit with the previewToken and the same inputs. Production needs confirmProduction true after the user confirms. Never ask for keys in chat (Codey Setup page).
  Answer in at most two short sentences, using only what the actions returned.'''
    L = ['# --- Project Codey: add this line to the ESM Coworker router instructions ---',
         '#   - Setting up or checking ESM (settings, permissions, admin jobs), pricing plan changes, context rules, Quote Member Binding, linear relationships, loading or checking many sites, upgrade impact, or how ESM works: use {!@actions.go_build}.',
         '# --- and this action to the router actions ---',
         f'{I*3}go_build: @utils.transition to @subagent.build', f'{I*4}description: "Project Codey build helper: setup, settings health, permissions, admin jobs, pricing plans, rules, bulk site checks, upgrade impact, concepts."',
         '# --- new subagent (append at the end of the agent) ---']
    L += subagent('build', 'Codey build helper', 'Project Codey skills inside the Coworker: setup, settings health check, permissions, admin jobs, pricing plans and steps, rules (context rules, Quote Member Binding, linear relationships, Enrich Quote), bulk site checks, upgrade impact and concepts.',
                  keys, steps, [], suffix='_codey', surface='Coworker')
    return '\n'.join(L).rstrip() + '\n'

if __name__ == '__main__':
    d = os.path.join(ROOT, 'force-app/main/default/aiAuthoringBundles/ESM_Codey'); os.makedirs(d, exist_ok=True)
    open(os.path.join(d, 'ESM_Codey.agent'), 'w').write(agent())
    open(os.path.join(d, 'ESM_Codey.bundle-meta.xml'), 'w').write('<?xml version="1.0" encoding="UTF-8"?>\n<AiAuthoringBundle xmlns="http://soap.sforce.com/2006/04/metadata">\n    <bundleType>AGENT</bundleType>\n</AiAuthoringBundle>\n')
    c = os.path.join(ROOT, 'adapters/coworker'); os.makedirs(c, exist_ok=True)
    open(os.path.join(c, 'codey_build_subagent.agent.txt'), 'w').write(coworker_snippet())
    print('agents ok')
