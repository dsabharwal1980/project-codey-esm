#!/usr/bin/env python3
"""Generates the Salesforce Hosted MCP server definition EsmCodeyEaseOfBuild from tools/mcp-tools.json."""
import json, os
from xml.sax.saxutils import escape
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tools = json.load(open(os.path.join(ROOT, 'tools/mcp-tools.json')))
desc = 'Project Codey ESM ease of build: playbook, health check, permissions, approved changes, admin jobs, price preview, bulk member checks, upgrade impact. Runs as the user; preview, approval, commit; logged.'
assert len(desc) <= 255
x = ['<?xml version="1.0" encoding="UTF-8"?>', '<McpServerDefinition xmlns="http://soap.sforce.com/2006/04/metadata">', f'    <description>{escape(desc)}</description>', '    <masterLabel>ESM Codey Ease of Build</masterLabel>']
for t in tools:
    assert len(t['description']) <= 1024, t['toolName']
    x += ['    <tools>', '        <apiDefinition>', f"            <apiIdentifier>aa:apex-{t['apexClass']}</apiIdentifier>", '            <apiSource>API_CATALOG</apiSource>',
          f"            <operation>{t['apexClass']}</operation>", '        </apiDefinition>', f"        <descriptionOverride>{escape(t['description'])}</descriptionOverride>",
          f"        <toolName>{t['toolName']}</toolName>", f"        <toolTitle>{t['title']}</toolTitle>", '    </tools>']
x.append('</McpServerDefinition>')
d = os.path.join(ROOT, 'force-app/main/default/mcpServerDefinitions'); os.makedirs(d, exist_ok=True)
open(os.path.join(d, 'EsmCodeyEaseOfBuild.mcpServerDefinition-meta.xml'), 'w').write('\n'.join(x) + '\n')
print('mcp definition ok:', len(tools), 'tools')
