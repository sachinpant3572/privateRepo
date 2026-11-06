#!/usr/bin/env python3
"""Builds the phone-friendly reader for the top-down games bible: one HTML page
holding the main volume and the four dossiers, with a contents sidebar, full-text
search and working cross-links. Needs the `markdown` package (pip install markdown).

Usage: python3 reference/build_viewer.py <out.html>
"""
import html
import json
import re
import sys
from pathlib import Path

import markdown

HERE = Path(__file__).resolve().parent
DOCS = [
    ("main", "README.md", "Main volume"),
    ("sv", "games/stardew_valley.md", "Stardew Valley"),
    ("srpg", "games/survival_rpg.md", "Survival RPG"),
    ("cl", "games/crashlands.md", "Crashlands 1 & 2"),
    ("b2b", "games/bad2bad_apocalypse.md", "Bad 2 Bad: Apocalypse"),
]
FILE_TO_KEY = {Path(path).name: key for key, path, _ in DOCS}
FILE_TO_KEY["README.md"] = "main"


def render(key: str, text: str) -> str:
    body = markdown.markdown(text, extensions=["tables", "toc", "sane_lists"])
    # Give every id a per-document prefix so the five documents can share a page.
    body = re.sub(r'id="([^"]+)"', lambda m: f'id="{key}--{m.group(1)}"', body)
    body = re.sub(r'href="([^"]+)"', lambda m: f'href="{_link(key, html.unescape(m.group(1)))}"', body)
    body = body.replace('<a href="http', '<a target="_blank" rel="noopener" href="http')
    body = body.replace("<table>", '<div class="tw"><table>').replace("</table>", "</table></div>")
    return f'<article class="doc" id="{key}--top" data-doc="{key}"{"" if key == "main" else " hidden"}>{body}</article>'


def _link(key: str, href: str) -> str:
    if href.startswith("http"):
        return html.escape(href)
    if href.startswith("#"):
        return f"#{key}--{href[1:]}"
    path, _, anchor = href.partition("#")
    target = FILE_TO_KEY.get(Path(path).name)
    if target is None:
        return html.escape(href)
    return f"#{target}--{anchor}" if anchor else f"#{target}--top"


def nav(key: str, label: str, body: str) -> str:
    levels = (1, 2) if key == "main" else (2,)
    items = []
    for level, ident, title in re.findall(r'<h([123]) id="([^"]+)">(.*?)</h\1>', body):
        if int(level) in levels and not (key != "main" and int(level) == 1):
            text = re.sub(r"<[^>]+>", "", title)
            items.append(f'<li class="l{level}"><a href="#{ident}">{text}</a></li>')
    return f'<section class="navdoc"><a class="navtitle" href="#{key}--top">{label}</a><ul>{"".join(items)}</ul></section>'


PAGE = """<title>Top-Down Games Bible</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,800&family=Literata:opsz,wght@7..72,400;7..72,600&family=JetBrains+Mono:wght@500&display=swap">
<style>
/* Layout: field-guide reader. Sticky top bar; contents + search in a left rail (a drawer on phones); one document at a time on the right. */
:root {
  --paper: #f3f5f7; --panel: #ffffff; --ink: #17202a; --muted: #5a6672; --line: #d5dbe1;
  --accent: #1f6f8b; --mark: #f6d77a; --code: #e9eef2; --bar-h: 64px;
  --display: "Bricolage Grotesque", "Segoe UI", system-ui, sans-serif;
  --body: "Literata", Georgia, "Times New Roman", serif;
  --mono: "JetBrains Mono", ui-monospace, Menlo, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --paper: #0f1419; --panel: #151c23; --ink: #e6edf3; --muted: #93a1ad; --line: #26313b;
  --accent: #6cc3e0; --mark: #7a5f12; --code: #1c252e; color-scheme: dark } }
:root[data-theme="dark"] {
  --paper: #0f1419; --panel: #151c23; --ink: #e6edf3; --muted: #93a1ad; --line: #26313b;
  --accent: #6cc3e0; --mark: #7a5f12; --code: #1c252e; color-scheme: dark }
html, body { height: 100%; }
body { margin: 0; background: var(--paper); color: var(--ink); font: 16px/1.6 var(--body); }
body::before { content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--panel); }
.bar { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; display: flex; align-items: center; gap: 12px;
  padding-block: 10px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  background: var(--panel); border-bottom: 1px solid var(--line); }
.bar h1 { font: 800 19px/1.1 var(--display); margin: 0; letter-spacing: -.01em; }
.bar .sub { font: 500 11px var(--mono); color: var(--muted); text-transform: uppercase; letter-spacing: .08em; }
.bar .spacer { flex: 1; }
.btn { font: 500 13px var(--mono); color: var(--ink); background: var(--paper); border: 1px solid var(--line); border-radius: 6px; padding: 7px 12px; cursor: pointer; }
.btn:focus-visible, a:focus-visible, input:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.wrap { display: grid; grid-template-columns: 300px minmax(0, 1fr); }
.rail { position: sticky; top: calc(env(safe-area-inset-top, 0px) + var(--bar-h)); height: calc(100vh - var(--bar-h) - env(safe-area-inset-top, 0px)); overflow-y: auto;
  border-right: 1px solid var(--line); background: var(--panel); padding: 14px 14px 40px; }
#toggle { display: none; }
@media (max-width: 860px) {
  .wrap { grid-template-columns: minmax(0, 1fr); }
  .rail { position: fixed; inset: calc(env(safe-area-inset-top, 0px) + var(--bar-h)) 0 0 0; height: auto; z-index: 4; border-right: 0;
    padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
  .rail:not(.open) { display: none; }
  #toggle { display: inline-block; }
}
#q { width: 100%; box-sizing: border-box; font: 15px var(--body); color: var(--ink); background: var(--paper); border: 1px solid var(--line); border-radius: 6px; padding: 9px 11px; }
.navdoc { margin-top: 16px; }
.navtitle { display: block; font: 800 14px var(--display); color: var(--ink); text-decoration: none; padding: 4px 0; }
.navdoc ul { list-style: none; margin: 2px 0 0; padding: 0; }
.navdoc li a { display: block; color: var(--muted); text-decoration: none; font-size: 14px; line-height: 1.35; padding: 4px 0 4px 10px; border-left: 2px solid transparent; }
.navdoc li.l1 a { font: 600 12px var(--mono); text-transform: uppercase; letter-spacing: .05em; color: var(--ink); margin-top: 8px; padding-left: 0; }
.navdoc li a:hover, .navdoc li a.here { color: var(--accent); border-left-color: var(--accent); }
#results { list-style: none; margin: 14px 0 0; padding: 0; display: grid; gap: 10px; }
#results a { display: block; text-decoration: none; color: var(--ink); background: var(--paper); border: 1px solid var(--line); border-radius: 6px; padding: 9px 10px; }
#results .where { font: 500 11px var(--mono); color: var(--muted); text-transform: uppercase; letter-spacing: .05em; }
#results .t { font: 600 14px var(--display); display: block; margin: 2px 0; }
#results .snip { font-size: 13px; color: var(--muted); }
#results mark, .doc mark { background: var(--mark); color: inherit; border-radius: 2px; }
main { min-width: 0; padding-block: 24px 80px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
.doc { max-width: 860px; margin: 0 auto; }
.doc h1, .doc h2, .doc h3 { font-family: var(--display); line-height: 1.15; text-wrap: balance; scroll-margin-top: calc(var(--bar-h) + 16px); }
.doc h1 { font-size: clamp(28px, 5vw, 40px); font-weight: 800; letter-spacing: -.02em; margin: 1.4em 0 .4em; }
.doc h1:first-child { margin-top: 0; }
.doc h2 { font-size: 24px; font-weight: 800; margin: 2em 0 .5em; padding-top: .6em; border-top: 1px solid var(--line); }
.doc h3 { font-size: 18px; font-weight: 600; margin: 1.5em 0 .4em; }
.doc p, .doc li { max-width: 68ch; }
.doc a { color: var(--accent); overflow-wrap: anywhere; }
.doc code { font: 13px var(--mono); background: var(--code); padding: 1px 5px; border-radius: 4px; }
.doc hr { border: 0; border-top: 1px solid var(--line); margin: 2em 0; }
.doc blockquote { margin: 1em 0; padding: 4px 16px; border-left: 3px solid var(--accent); color: var(--muted); }
.tw { overflow-x: auto; margin: 1em 0; border: 1px solid var(--line); border-radius: 8px; background: var(--panel); }
.tw table { border-collapse: collapse; font-size: 14px; line-height: 1.45; min-width: 100%; }
.tw th, .tw td { text-align: left; vertical-align: top; padding: 8px 10px; border-bottom: 1px solid var(--line); }
.tw th { font: 600 12px var(--mono); text-transform: uppercase; letter-spacing: .04em; color: var(--muted); background: var(--paper); position: sticky; top: 0; }
.tw tr:last-child td { border-bottom: 0; }
.tw td { min-width: 9ch; }
</style>
<header class="bar">
  <button class="btn" id="toggle" aria-expanded="false" aria-controls="rail">Contents</button>
  <div><h1>Top-Down Games Bible</h1><div class="sub">Stardew · Survival RPG · Crashlands 1-2 · Bad 2 Bad · for Solvera</div></div>
  <span class="spacer"></span>
</header>
<div class="wrap">
  <nav class="rail" id="rail" aria-label="Contents and search">
    <label for="q" class="sub">Search all five documents</label>
    <input id="q" type="search" placeholder="e.g. auto-aim, piracy, day cycle" autocomplete="off">
    <ul id="results" hidden></ul>
    <div id="toc">__NAV__</div>
  </nav>
  <main id="main">__DOCS__</main>
</div>
<script>
const LABELS = __LABELS__;
const rail = document.getElementById('rail');
const toggle = document.getElementById('toggle');
const q = document.getElementById('q');
const results = document.getElementById('results');
const toc = document.getElementById('toc');
const bar = document.querySelector('.bar');
// Keep the rail and jump targets below the header, whose height changes with the screen width.
function syncBar() { document.documentElement.style.setProperty('--bar-h', bar.offsetHeight + 'px'); }
window.addEventListener('resize', syncBar);
syncBar();

function showFor(id) {
  const el = id && document.getElementById(id);
  const doc = el ? el.closest('.doc') : document.querySelector('.doc[data-doc="main"]');
  document.querySelectorAll('.doc').forEach(d => { d.hidden = d !== doc; });
  document.querySelectorAll('.navdoc li a').forEach(a => a.classList.toggle('here', a.getAttribute('href') === '#' + id));
  if (el && el !== doc) el.scrollIntoView(); else window.scrollTo(0, 0);
}
window.addEventListener('hashchange', () => showFor(location.hash.slice(1)));
document.addEventListener('click', e => {
  const a = e.target.closest('a[href^="#"]');
  if (!a) return;
  if (window.matchMedia('(max-width: 860px)').matches && rail.contains(a)) setRail(false);
  if (a.getAttribute('href') === location.hash) { e.preventDefault(); showFor(location.hash.slice(1)); }
});
function setRail(open) { rail.classList.toggle('open', open); toggle.setAttribute('aria-expanded', String(open)); }
toggle.onclick = () => setRail(!rail.classList.contains('open'));

// Full-text search over sections (each heading plus the text up to the next heading).
const sections = [];
document.querySelectorAll('.doc').forEach(doc => {
  let cur = null;
  for (const node of doc.children) {
    if (/^H[1-3]$/.test(node.tagName)) {
      cur = { id: node.id, title: node.textContent, doc: doc.dataset.doc, text: '' };
      sections.push(cur);
    } else if (cur) cur.text += ' ' + node.textContent;
  }
});
function esc(s) { return s.replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
function snippet(text, term) {
  const i = text.toLowerCase().indexOf(term);
  const start = Math.max(0, i - 60);
  const part = (start ? '…' : '') + text.slice(start, i + 120).trim() + '…';
  return esc(part).replace(new RegExp(term.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'ig'), m => '<mark>' + m + '</mark>');
}
q.addEventListener('input', () => {
  const term = q.value.trim().toLowerCase();
  results.hidden = term.length < 2; toc.hidden = term.length >= 2;
  if (term.length < 2) return;
  const hits = sections.filter(s => (s.title + ' ' + s.text).toLowerCase().includes(term))
    .sort((a, b) => (b.title.toLowerCase().includes(term) ? 1 : 0) - (a.title.toLowerCase().includes(term) ? 1 : 0)).slice(0, 40);
  results.innerHTML = hits.length ? hits.map(s => '<li><a href="#' + s.id + '"><span class="where">' + esc(LABELS[s.doc]) + '</span><span class="t">' + esc(s.title) + '</span><span class="snip">' + snippet(s.text || s.title, term) + '</span></a></li>').join('')
    : '<li class="snip">No section mentions "' + esc(term) + '". Try a shorter word.</li>';
});
showFor(location.hash.slice(1));
</script>
"""


def main() -> None:
    out = Path(sys.argv[1])
    docs, navs = [], []
    for key, path, label in DOCS:
        body = render(key, (HERE / path).read_text())
        docs.append(body)
        navs.append(nav(key, label, body))
    page = (PAGE.replace("__NAV__", "".join(navs)).replace("__DOCS__", "".join(docs))
            .replace("__LABELS__", json.dumps({k: label for k, _, label in DOCS})))
    out.write_text(page)
    print("wrote", out, f"({len(page) // 1024} KB)")


if __name__ == "__main__":
    main()
