#!/usr/bin/env python3
"""Generates the four Project Codey HXL experience cards (UiWidgetBundle) and their Lightning Types (LightningTypeBundle)
from one definition, plus the portable JSON card schemas in hxl/cards/. Run from the repo root: python3 scripts/build-hxl.py"""
import json, os, uuid
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MD = os.path.join(ROOT, 'force-app/main/default')
uid = lambda: str(uuid.uuid5(uuid.NAMESPACE_URL, 'codey-' + str(next(counter))))
def _c():
    i = 0
    while True: i += 1; yield i
counter = _c()

def node(defn, attrs=None, children=None, meta=None):
    n = {'definition': defn}
    if attrs is not None: n['attributes'] = attrs
    if meta: n['meta'] = meta
    n['id'] = uid()
    if children is not None: n['children'] = children
    return n
def text(t, variant='body', color='default', weight=None, meta=None):
    a = {'text': t, 'variant': variant, 'color': color, 'isItalic': False, 'isStrikethrough': False}
    if weight: a['weight'] = weight
    return node('tile/text', a, meta=meta)
def row(children, gap='md', justify='start', align='center', wrap=False, meta=None):
    return node('tile/row', {'gap': gap, 'justify': justify, 'align': align, 'isWrapped': wrap}, children, meta)
def col(children, gap='xs', align='start', width='stretch', meta=None):
    return node('tile/column', {'align': align, 'gap': gap, 'width': width}, children, meta)
def badge(label, variant, cond): return node('tile/badge', {'label': label, 'variant': variant}, meta={'if': cond})
def icon(name, color, size='md'): return node('tile/icon', {'name': name, 'color': color, 'size': size, 'alt': ' '})
def msgbtn(label, variant, content, meta): return node('tile/button', {'label': label, 'variant': variant, 'actions': {'click': [{'definition': 'action/sendMessage', 'attributes': {'content': content}}]}}, meta=meta)
def linkbtn(label, variant, url, meta): return node('tile/button', {'label': label, 'variant': variant, 'actions': {'click': [{'definition': 'action/openLink', 'attributes': {'url': url, 'target': '_blank'}}]}}, meta=meta)

def header():
    return row([
        row([icon('{!$attrs.icon}', 'primary', 'lg'), col([text('{!$attrs.subtitle}', 'caption', 'muted'), text('{!$attrs.title}', 'h3')])], gap='sm'),
        badge('{!$attrs.badgeLabel}', '{!$attrs.badgeVariant}', '{!$attrs.hasBadge}')], justify='between', wrap=True)
def stats():
    return row([col([text('{!$s.label}', 'caption', 'muted'), text('{!$s.value}', 'h4'), text('{!$s.detail}', 'caption', 'muted')], meta={'forEach': '{!$attrs.stats}', 'forItem': '$s'})],
               gap='lg', align='start', wrap=True, meta={'if': '{!$attrs.hasStats}'})
def progress():
    return node('tile/progress', {'label': '{!$attrs.progressLabel}', 'value': '{!$attrs.progressValue}', 'max': 100, 'size': 'md', 'color': '{!$attrs.progressColor}', 'shape': 'linear'}, meta={'if': '{!$attrs.hasProgress}'})
def footer():
    return [
        text('{!$attrs.moreLabel}', 'caption', 'muted', meta={'if': '{!$attrs.hasMore}'}),
        node('tile/callout', {'title': '{!$attrs.calloutTitle}', 'description': '{!$attrs.calloutText}', 'variant': '{!$attrs.calloutVariant}'}, [], {'if': '{!$attrs.hasCallout}'}),
        text('{!$attrs.note}', 'caption', 'muted', meta={'if': '{!$attrs.hasNote}'}),
        row([msgbtn('{!$b.label}', '{!$b.variant}', '{!$b.message}', {'forEach': '{!$attrs.buttons}', 'forItem': '$b', 'if': '{!$b.isMessage}'}),
             linkbtn('{!$b.label}', '{!$b.variant}', '{!$b.url}', {'forEach': '{!$attrs.buttons}', 'forItem': '$b', 'if': '{!$b.isLink}'})],
            gap='sm', justify='end', wrap=True, meta={'if': '{!$attrs.hasButtons}'})]

def item_list(item_children):
    return col([text('{!$attrs.itemsTitle}', 'h5'), node('tile/separator', {'orientation': 'horizontal'}),
                col(item_children, gap='xs', align='stretch', width='auto', meta={'forEach': '{!$attrs.items}', 'forItem': '$it'})],
               gap='sm', align='stretch', width='auto', meta={'if': '{!$attrs.hasItems}'})
def item_head(show_value=True):
    right = [text('{!$it.value}', 'body', 'default', 'bold'), text('{!$it.detail}', 'caption', 'muted')] if show_value else []
    kids = [icon('{!$it.icon}', '{!$it.iconColor}'), col([text('{!$it.title}', 'body', 'default', 'bold'), text('{!$it.subtitle}', 'caption', 'muted')])]
    if right: kids.append(col(right, align='end', width='auto'))
    kids.append(badge('{!$it.badgeLabel}', '{!$it.badgeVariant}', '{!$it.hasBadge}'))
    return row(kids, gap='sm')
def item_actions():
    return row([msgbtn('{!$it.actionLabel}', 'secondary', '{!$it.actionMessage}', {'if': '{!$it.hasAction}'}),
                linkbtn('{!$it.linkLabel}', 'secondary', '{!$it.linkUrl}', {'if': '{!$it.hasLink}'})], gap='sm', justify='end')

CARDS = {
 'codeyApproval': dict(label='Codey Approval', desc='Project Codey Approval screen: exactly what will change, Before and After, Approve / Reject. Used before any change.',
   items=[item_head(False), row([col([text('Before', 'caption', 'muted'), text('{!$it.beforeValue}', 'body')]), icon('arrow-right', 'muted', 'sm'),
                                   col([text('After', 'caption', 'muted'), text('{!$it.afterValue}', 'body', 'default', 'bold')])], gap='sm', meta={'if': '{!$it.hasBefore}'}),
          text('{!$it.detail}', 'caption', 'muted')], progress=False),
 'codeyHealthReport': dict(label='Codey Health check report', desc='Project Codey Health check report: each setting OK, Warning or Needs Fix with the reason, a help link and a Fix it button.',
   items=[item_head(True), item_actions()], progress=False),
 'codeyProgress': dict(label='Codey Progress tracker', desc='Project Codey Progress tracker: long jobs (install, admin jobs, bulk checks), each step and where a failed job resumes.',
   items=[item_head(False), node('tile/progress', {'label': '{!$it.value}', 'value': '{!$it.percent}', 'max': 100, 'size': 'sm', 'color': '{!$it.barColor}', 'shape': 'linear'}, meta={'if': '{!$it.hasBar}'})], progress=True),
 'codeyUpgradeImpact': dict(label='Codey Upgrade impact report', desc='Project Codey Upgrade impact report: customized screens a release affects, risk level and suggested action.',
   items=[item_head(True), item_actions()], progress=False),
}
ATTRS = {  # widget input schema (subset of CodeyCard)
 'title': 'lightning__textType', 'subtitle': 'lightning__textType', 'icon': 'lightning__iconName', 'hasBadge': 'lightning__booleanType', 'badgeLabel': 'lightning__textType',
 'badgeVariant': 'lightning__textType', 'hasStats': 'lightning__booleanType', 'hasProgress': 'lightning__booleanType', 'progressLabel': 'lightning__textType',
 'progressValue': 'lightning__numberType', 'progressColor': 'lightning__textType', 'hasItems': 'lightning__booleanType', 'itemsTitle': 'lightning__textType',
 'hasMore': 'lightning__booleanType', 'moreLabel': 'lightning__textType', 'hasCallout': 'lightning__booleanType', 'calloutTitle': 'lightning__textType',
 'calloutText': 'lightning__multilineTextType', 'calloutVariant': 'lightning__textType', 'hasNote': 'lightning__booleanType', 'note': 'lightning__multilineTextType',
 'hasButtons': 'lightning__booleanType'}
LISTS = {
 'stats': {'label': 'lightning__textType', 'value': 'lightning__textType', 'detail': 'lightning__textType'},
 'buttons': {'label': 'lightning__textType', 'variant': 'lightning__textType', 'isLink': 'lightning__booleanType', 'isMessage': 'lightning__booleanType', 'url': 'lightning__textType', 'message': 'lightning__multilineTextType'},
 'items': {'icon': 'lightning__iconName', 'iconColor': 'lightning__textType', 'title': 'lightning__textType', 'subtitle': 'lightning__textType', 'value': 'lightning__textType',
           'detail': 'lightning__textType', 'hasBar': 'lightning__booleanType', 'percent': 'lightning__numberType', 'barColor': 'lightning__textType', 'hasBadge': 'lightning__booleanType',
           'badgeLabel': 'lightning__textType', 'badgeVariant': 'lightning__textType', 'hasBefore': 'lightning__booleanType', 'beforeValue': 'lightning__textType',
           'afterValue': 'lightning__textType', 'hasAction': 'lightning__booleanType', 'actionLabel': 'lightning__textType', 'actionMessage': 'lightning__multilineTextType',
           'hasLink': 'lightning__booleanType', 'linkLabel': 'lightning__textType', 'linkUrl': 'lightning__textType'}}
def title(k): return k[0].upper() + ''.join(' ' + c.lower() if c.isupper() else c for c in k[1:])
props = {k: {'title': title(k), 'lightning:type': t} for k, t in ATTRS.items()}
for k, fields in LISTS.items():
    props[k] = {'title': title(k), 'items': {'properties': {f: {'title': title(f), 'lightning:type': t} for f, t in fields.items()}, 'lightning:type': 'lightning__objectType'}, 'lightning:type': 'lightning__listType'}

for name, c in CARDS.items():
    body = [header(), stats()] + ([progress()] if c['progress'] else []) + [item_list(c['items'])] + footer()
    widget = {'type': 'lightning__agentforceWidget', 'title': c['label'], 'contentBody': {'widgetBody': node('tile/widget', None, [
        node('tile/container', {'variant': 'default', 'borderless': False, 'isVisible': True}, [col(body, gap='md', align='stretch', width='auto')])])}}
    d = os.path.join(MD, 'uiWidgets', name); os.makedirs(d, exist_ok=True)
    json.dump(widget, open(os.path.join(d, name + '.json'), 'w'), separators=(',', ':'))
    json.dump({'title': c['label'] + ' inputs', 'type': 'object', 'properties': {'attributes': {'properties': props, 'lightning:type': 'lightning__objectType'}}}, open(os.path.join(d, 'schema.json'), 'w'), separators=(',', ':'))
    open(os.path.join(d, name + '.uiwidget-meta.xml'), 'w').write(f'''<?xml version="1.0" encoding="UTF-8"?>
<UiWidgetBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <masterLabel>{c['label']}</masterLabel>
    <description>{c['desc']}</description>
    <widgetType>JSON</widgetType>
</UiWidgetBundle>
''')
    # Lightning Type that renders a Codey tool result with this widget
    lt = os.path.join(MD, 'lightningTypes', name + 'Result'); os.makedirs(lt, exist_ok=True)
    json.dump({'title': c['label'] + ' tool result', 'lightning:type': 'lightning__objectType', 'unevaluatedProperties': False, 'lightning:tags': ['mcp'],
               'properties': {'actionName': {'title': 'Action', 'lightning:type': 'lightning__textType'}, 'isSuccess': {'title': 'Success', 'lightning:type': 'lightning__booleanType'},
                              'outputValues': {'title': 'Output', 'lightning:type': 'c__codeyToolOutputValues'}}}, open(os.path.join(lt, 'schema.json'), 'w'), indent=2)
    attrs = {k: '{!$attrs.outputValues.card.' + k + '}' for k in list(ATTRS) + list(LISTS)}
    json.dump({'renderer': {'componentOverrides': {'$': {'definition': '@widget/c/' + name, 'attributes': dict(sorted(attrs.items()))}}}}, open(os.path.join(lt, 'renderer.json'), 'w'), indent=2)

ov = os.path.join(MD, 'lightningTypes', 'codeyToolOutputValues'); os.makedirs(ov, exist_ok=True)
json.dump({'title': 'Project Codey tool output', 'lightning:type': 'lightning__objectType', 'unevaluatedProperties': False, 'lightning:tags': ['mcp'], 'properties': {
    'success': {'title': 'Success', 'lightning:type': 'lightning__booleanType'}, 'mode': {'title': 'Mode', 'lightning:type': 'lightning__textType'},
    'message': {'title': 'Message', 'lightning:type': 'lightning__multilineTextType'}, 'previewToken': {'title': 'Preview token', 'lightning:type': 'lightning__textType'},
    'resultJson': {'title': 'Result JSON', 'lightning:type': 'lightning__multilineTextType'}, 'jobId': {'title': 'Job', 'lightning:type': 'lightning__textType'},
    'changeLogId': {'title': 'Change log', 'lightning:type': 'lightning__textType'}, 'nextStep': {'title': 'Next step', 'lightning:type': 'lightning__multilineTextType'},
    'fix': {'title': 'Fix', 'lightning:type': 'lightning__multilineTextType'}, 'card': {'title': 'Card', 'lightning:type': '@apexClassType/c__CodeyCard'}}}, open(os.path.join(ov, 'schema.json'), 'w'), indent=2)

# portable card schemas for non-Salesforce surfaces (Slack, Teams, Claude, ChatGPT)
hx = os.path.join(ROOT, 'hxl', 'cards'); os.makedirs(hx, exist_ok=True)
def js(t): return {'lightning__booleanType': 'boolean', 'lightning__numberType': 'number'}.get(t, 'string')
card_schema = {'$schema': 'https://json-schema.org/draft/2020-12/schema', '$id': 'https://github.com/project-codey-esm/hxl/codey-card.schema.json', 'title': 'CodeyCard',
  'description': 'Shared data of the four Project Codey experience screens. cardType: approval | health | progress | upgrade | price | planSteps | basic.',
  'type': 'object', 'properties': dict({'cardType': {'type': 'string', 'enum': ['approval', 'health', 'progress', 'upgrade', 'price', 'planSteps', 'basic']}},
  **{k: {'type': js(t)} for k, t in ATTRS.items()}, **{k: {'type': 'array', 'items': {'type': 'object', 'properties': {f: {'type': js(t)} for f, t in v.items()}}} for k, v in LISTS.items()}),
  'required': ['cardType', 'title']}
json.dump(card_schema, open(os.path.join(hx, 'codey-card.schema.json'), 'w'), indent=2)
for name, c in CARDS.items():
    json.dump({'name': name, 'label': c['label'], 'description': c['desc'], 'salesforceWidget': 'UiWidgetBundle:' + name, 'lightningType': 'LightningTypeBundle:' + name + 'Result',
               'dataSchema': 'codey-card.schema.json', 'cardType': {'codeyApproval': 'approval', 'codeyHealthReport': 'health', 'codeyProgress': 'progress', 'codeyUpgradeImpact': 'upgrade'}[name],
               'layout': ['header (icon, subtitle, title, badge)', 'stats', 'progress' if c['progress'] else None, 'items', 'more', 'callout', 'note', 'buttons']},
              open(os.path.join(hx, name + '.card.json'), 'w'), indent=2)
print('hxl ok')
