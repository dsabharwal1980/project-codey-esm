#!/usr/bin/env python3
"""Converts docs/*.md (headings, paragraphs, lists, tables, code blocks, bold/code inline) to .docx. Usage: python3 scripts/build-docx.py [file.md ...]"""
import os, re, sys
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAVY = RGBColor(0x00, 0x1E, 0x5B)

def shade(cell, hexcolor):
    tcPr = cell._tc.get_or_add_tcPr(); s = OxmlElement('w:shd'); s.set(qn('w:val'), 'clear'); s.set(qn('w:color'), 'auto'); s.set(qn('w:fill'), hexcolor); tcPr.append(s)

def inline(par, text, size=None, bold=False):
    for part in re.split(r'(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))', text):
        if not part: continue
        if part.startswith('**') and part.endswith('**'): r = par.add_run(part[2:-2]); r.bold = True
        elif part.startswith('`') and part.endswith('`'): r = par.add_run(part[1:-1]); r.font.name = 'Consolas'; r.font.size = Pt(8.5)
        elif part.startswith('['): m = re.match(r'\[([^\]]+)\]\(([^)]+)\)', part); r = par.add_run(m.group(1) + (f' ({m.group(2)})' if m.group(2).startswith('http') else ''))
        else: r = par.add_run(part.replace('\\|', '|'))
        if bold: r.bold = True
        if size: r.font.size = Pt(size)

def convert(md_path, out_path):
    doc = Document()
    st = doc.styles['Normal']; st.font.name = 'Calibri'; st.font.size = Pt(10.5)
    for s in doc.sections: s.left_margin = s.right_margin = Cm(2); s.top_margin = s.bottom_margin = Cm(1.8)
    lines = open(md_path, encoding='utf-8').read().split('\n')
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.startswith('```'):
            code = []; i += 1
            while i < len(lines) and not lines[i].startswith('```'): code.append(lines[i]); i += 1
            p = doc.add_paragraph(); r = p.add_run('\n'.join(code)); r.font.name = 'Consolas'; r.font.size = Pt(8)
            p.paragraph_format.left_indent = Cm(0.5); i += 1; continue
        if ln.startswith('|') and i + 1 < len(lines) and re.match(r'^\|[\s:|-]+\|$', lines[i + 1].strip()):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                if not re.match(r'^\|[\s:|-]+\|$', lines[i].strip()):
                    rows.append([c.strip() for c in re.split(r'(?<!\\)\|', lines[i].strip())[1:-1]])
                i += 1
            n = max(len(r) for r in rows)
            t = doc.add_table(rows=len(rows), cols=n); t.style = 'Table Grid'; t.alignment = WD_TABLE_ALIGNMENT.LEFT
            for ri, row in enumerate(rows):
                for ci in range(n):
                    cell = t.cell(ri, ci); cell.text = ''
                    inline(cell.paragraphs[0], row[ci] if ci < len(row) else '', size=8.5, bold=(ri == 0))
                    if ri == 0: shade(cell, 'DCE8F7')
            doc.add_paragraph(); continue
        m = re.match(r'^(#{1,4})\s+(.*)', ln)
        if m:
            h = doc.add_heading(level=min(len(m.group(1)), 3) if len(m.group(1)) > 1 else 0)
            inline(h, m.group(2))
            for r in h.runs: r.font.color.rgb = NAVY
            i += 1; continue
        if ln.strip() == '---': i += 1; continue
        m = re.match(r'^(\s*)([-*]|\d+\.)\s+(.*)', ln)
        if m:
            p = doc.add_paragraph(style='List Number' if m.group(2)[0].isdigit() else 'List Bullet'); inline(p, m.group(3)); i += 1; continue
        if ln.startswith('>'):
            p = doc.add_paragraph(); inline(p, ln.lstrip('> ')); p.paragraph_format.left_indent = Cm(0.7); i += 1; continue
        if ln.strip():
            p = doc.add_paragraph(); inline(p, ln.strip())
        i += 1
    doc.save(out_path)
    print('wrote', os.path.relpath(out_path, ROOT))

files = sys.argv[1:] or [os.path.join(ROOT, 'docs', 'Cross-Org-Deployment-and-Usage-Guide.md')]
for f in files: convert(f, f[:-3] + '.docx')
