'use strict';
/*
  page-assets - the version stamp of the stylesheet links and the ViewState of the Dashboard (step UN6e, R29 and R30).

  Data (this folder; the rules are in README.md):
    expected.json   pages   the role and the address of each page visited and its local stylesheets, in the order of
                            the page (a file linked twice is listed twice);
                    viewState  the role, the address and the largest __VIEWSTATE (characters of the field) allowed.

  What it checks
    1. On each page of "pages": the local stylesheet links of the page (<link rel="stylesheet"> on this site), in order,
       are the files listed, and each ends with ?v= and the first 8 hex characters (lower case) of the SHA-256 of that
       file in the site copy (Tests\_site). A link to another host, or to a handler that is not a .css file (the AJAX
       toolkit's WebResource.axd), is not counted.
    2. For each row of "viewState": the __VIEWSTATE field of the page, as first loaded, is not longer than maxBytes.

  It changes no data: it only opens pages.
*/
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const DIR = __dirname;

function readExpected() {
  let text = fs.readFileSync(path.join(DIR, 'expected.json'), 'utf8');
  if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
  return JSON.parse(text);
}

// The first 8 hex characters of the SHA-256 of a file of the site copy, or "missing"
function stampOf(siteDir, relative) {
  const full = path.resolve(siteDir, relative);
  if (!full.toLowerCase().startsWith(path.resolve(siteDir).toLowerCase() + path.sep)) return 'outside';
  try { return crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex').slice(0, 8); }
  catch (e) { return 'missing'; }
}

async function pageFor(t, role) {
  if (role === 'anonymous') return t.anonymousPage();
  return { context: null, page: await t.session(role) };
}

module.exports = {
  title: 'Page assets: ?v=<stamp> on every local stylesheet link; the ViewState of the Dashboard',
  async run(t) {
    const data = readExpected();
    const rec = (role, title, expected, seen, address, pass) => {
      const e = typeof expected === 'string' ? expected : JSON.stringify(expected);
      const s = typeof seen === 'string' ? seen : JSON.stringify(seen);
      t.record({ title, role, address, expected: e, seen: s, pass: pass === undefined ? e === s : pass });
    };

    // 1. The stylesheet links
    for (const p of data.pages) {
      const { context, page } = await pageFor(t, p.role);
      try {
        const opened = await t.visit(page, p.address);
        const links = await page.evaluate(() => Array.from(document.querySelectorAll('link'))
          .filter((l) => (l.getAttribute('rel') || '').toLowerCase() === 'stylesheet')
          .map((l) => l.href));
        const origin = new URL(page.url()).origin;
        // A local stylesheet file: on this site and ending in .css (a handler such as WebResource.axd, which the
        // AJAX toolkit links for its calendar and which carries its own t= stamp, is not a file and is not counted)
        const seen = links.filter((h) => new URL(h).origin === origin && /\.css$/i.test(new URL(h).pathname)).map((h) => {
          const u = new URL(h);
          return decodeURIComponent(u.pathname).replace(/^\/+/, '') + u.search;
        });
        const expected = p.css.map((c) => c + '?v=' + stampOf(t.siteDir, c));
        rec(p.role, p.address + ' opens and each local stylesheet link ends with ?v= and the 8 hex characters of its file',
          { opens: 'opens', links: expected }, { opens: opened.kind, links: seen }, p.address);
      } finally {
        if (context) await context.close().catch(() => null);
      }
    }

    // 2. The ViewState of the page as first loaded
    for (const v of data.viewState) {
      const { context, page } = await pageFor(t, v.role);
      try {
        const opened = await t.visit(page, v.address);
        const size = await page.evaluate(() => { const f = document.getElementById('__VIEWSTATE'); return f ? f.value.length : -1; });
        rec(v.role, v.address + ' as first loaded: __VIEWSTATE at most ' + v.maxBytes + ' characters',
          'opens, at most ' + v.maxBytes, opened.kind + ', ' + size, v.address,
          opened.kind === 'opens' && size >= 0 && size <= v.maxBytes);
      } finally {
        if (context) await context.close().catch(() => null);
      }
    }
  },
};
