'use strict';
/*
  access-matrix - what each role can open, against the owner's rules (step WF3a2).

  Data (this folder; the rules are in README.md):
    expected.csv     one row per address, one column per role, the rule of the row
    not-in-menu.csv  pages a role opens without a menu link, each with its reason
    home-link.csv    which roles have the Home link
    planted.json     the row(s) and the cell of the standing proof

  Phases (given by Run-Tests.ps1 through run.js):
    main          the files, the pages on disk, the agreement with PageAccess.xml, the matrix, the menu
    planted       the standing proof: Tests\_site\XML\PageAccess.xml carries the planted change; only
                  the rows of planted.json, every column; the planted cell is marked so
    planted-full  the same with every row (the one-time proof of the build, owner only)

  It reads files and opens pages of the site copy; it writes nothing but its check records.
*/
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const COLUMNS = ['admin', 'controller', 'manager', 'user', 'mgmt', 'mdsec', 'inactive', 'visitor'];
const SIGNED_IN = ['admin', 'controller', 'manager', 'user', 'mgmt', 'mdsec'];
const WORDS = {
  'opens': 'opens', 'Access denied': 'denied', 'sign-in page': 'signin', 'Page not found': 'notfound',
  'owner to decide': 'decide',
};
const INACTIVE_MESSAGE = 'Your account is inactive';

// ---------------------------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------------------------
function parseCsv(text) {
  const rows = []; let row = []; let field = ''; let quoted = false;
  text = String(text).replace(/^\uFEFF/, '');
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { row.push(field); field = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(field); field = '';
      if (row.some((f) => f !== '')) rows.push(row);
      row = [];
    } else field += ch;
  }
  row.push(field);
  if (row.some((f) => f !== '')) rows.push(row);
  const head = rows.shift() || [];
  return { head, rows: rows.map((r) => Object.fromEntries(head.map((h, i) => [h, (r[i] || '').trim()]))) };
}

function readCsv(name) { return parseCsv(fs.readFileSync(path.join(DIR, name), 'utf8')); }

function pagePart(address) { return String(address).split('?')[0]; }
function key(address) { const [p, q] = String(address).split('?'); return p.toLowerCase() + (q === undefined ? '' : '?' + q); }

// PageAccess.xml read as text (no package): <public> pages and <pages> entries with their roles.
function readPageAccess(file) {
  const text = fs.readFileSync(file, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
  const pub = new Set(); const pages = new Map();
  const block = (name) => { const m = text.match(new RegExp('<' + name + '>([\\s\\S]*?)</' + name + '>')); return m ? m[1] : ''; };
  for (const m of block('public').matchAll(/<page\s+path="([^"]+)"/g)) pub.add(m[1].toLowerCase());
  for (const m of block('pages').matchAll(/<page\s+path="([^"]+)"\s+roles="([^"]*)"/g)) pages.set(m[1].toLowerCase(), m[2].split(',').map((r) => r.trim()).filter(Boolean));
  const mode = (text.match(/<pageAccess\s+mode="([^"]+)"/) || [])[1] || '';
  return { pub, pages, mode };
}

// Role codes of the database for the columns (PageAccess.xml speaks in these).
const ROLE_CODE = { admin: 'admin', controller: 'controller', manager: 'manager', user: 'user', mgmt: 'mgmt', mdsec: 'md_sect' };

// What the module lets through, by PageAccess.xml only: 'allowed' | 'refused' | 'signin'.
function xmlVerdict(xml, address, column) {
  const p = pagePart(address).toLowerCase();
  if (xml.pub.has(p)) return 'allowed';
  if (column === 'visitor' || column === 'inactive') return 'signin';
  if (!p.endsWith('.aspx')) return 'allowed';   // the module looks at .aspx requests only
  const roles = xml.pages.get(p);
  if (!roles) return 'refused';
  return roles.includes('*') || roles.includes(ROLE_CODE[column]) ? 'allowed' : 'refused';
}

function listPages(root) {
  const out = [];
  const walk = (dir, rel) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const r = rel ? rel + '/' + e.name : e.name;
      if (e.isDirectory()) { if (!/^(bin|obj|App_Data|Log|Files|node_modules)$/i.test(e.name)) walk(path.join(dir, e.name), r); }
      else if (/\.aspx$/i.test(e.name)) out.push(r);
    }
  };
  walk(root, '');
  return out.sort();
}

// ---------------------------------------------------------------------------------------------
// The pack
// ---------------------------------------------------------------------------------------------
module.exports = {
  title: 'Access matrix: what each role can open',
  async run(t) {
    const phase = t.phase || 'main';
    const problems = [];

    // 1. The files.
    const expected = readCsv('expected.csv');
    const needCols = ['address'].concat(COLUMNS, ['rule', 'page_rule']);
    for (const c of needCols) if (!expected.head.includes(c)) problems.push('expected.csv has no column "' + c + '"');
    const rows = expected.rows;
    const seen = new Set();
    for (const r of rows) {
      if (!r.address) { problems.push('a row of expected.csv has no address'); continue; }
      if (seen.has(key(r.address))) problems.push('expected.csv has ' + r.address + ' twice');
      seen.add(key(r.address));
      if (!r.rule) problems.push(r.address + ': no rule');
      for (const c of COLUMNS) if (!(r[c] in WORDS)) problems.push(r.address + ', ' + c + ': "' + r[c] + '" is not a cell word');
      if (r.page_rule && r.page_rule !== 'RA1b' && r.page_rule !== 'missing on purpose') problems.push(r.address + ': page_rule "' + r.page_rule + '" is unknown');
    }
    const notInMenu = readCsv('not-in-menu.csv').rows;
    for (const n of notInMenu) {
      if (!n.reason) problems.push('not-in-menu.csv: ' + n.role + ' ' + n.address + ' has no reason');
      if (n.role !== '*' && !SIGNED_IN.includes(n.role)) problems.push('not-in-menu.csv: unknown role "' + n.role + '"');
    }
    const homeLink = readCsv('home-link.csv').rows;
    for (const c of SIGNED_IN) if (!homeLink.find((h) => h.role === c && /^(yes|no)$/.test(h.home) && h.rule)) problems.push('home-link.csv: no row (yes or no, with a rule) for ' + c);
    const planted = JSON.parse(fs.readFileSync(path.join(DIR, 'planted.json'), 'utf8'));
    for (const a of planted.rows) if (!rows.find((r) => key(r.address) === key(a))) problems.push('planted.json: row ' + a + ' is not in expected.csv');

    t.record({
      title: 'The expected files are complete (cell words, a rule per row, a reason per not-in-menu row)',
      role: '-', address: 'Tests/packs/access-matrix', expected: 'complete', seen: problems.length ? problems.length + ' problem(s)' : 'complete',
      pass: problems.length === 0, detail: problems.slice(0, 20).join('; '), proof: phase !== 'main',
    });
    if (problems.length) throw new Error('the expected files of the pack are not complete: ' + problems[0]);

    const siteXml = path.join(t.siteDir, 'XML', 'PageAccess.xml');
    const treeXml = path.join(t.repo, 'BMMS', 'XML', 'PageAccess.xml');

    // The planted phases: the rows of the proof (or every row) for every column.
    if (phase === 'planted' || phase === 'planted-full') {
      const site = readPageAccess(siteXml);
      const roles = site.pages.get(planted.page.toLowerCase()) || [];
      const inPlace = roles.includes(planted.addRole);
      t.record({
        title: 'Standing proof: the site copy carries the planted change (' + planted.addRole + ' added to ' + planted.page + ')',
        role: '-', address: 'Tests/_site/XML/PageAccess.xml', expected: 'changed', seen: inPlace ? 'changed' : 'not changed', pass: inPlace, proof: true,
      });
      if (!inPlace) return;
      const proofRows = phase === 'planted' ? rows.filter((r) => planted.rows.some((a) => key(a) === key(r.address))) : rows;
      await runMatrix(t, proofRows, { proof: true, planted: planted.cell });
      return;
    }

    // 2. Pages on disk against expected.csv and PageAccess.xml.
    const xml = readPageAccess(treeXml);
    const onDisk = listPages(t.siteDir);
    const expPages = new Set(rows.filter((r) => r.page_rule !== 'missing on purpose').map((r) => pagePart(r.address).toLowerCase()));
    const inXml = (p) => xml.pub.has(p) || xml.pages.has(p);
    const neither = [], xmlOnly = [], expOnly = [], missing = [];
    for (const p of onDisk) {
      const k = p.toLowerCase();
      if (!expPages.has(k) && !inXml(k)) neither.push(p);
      else if (!expPages.has(k)) xmlOnly.push(p);
      else if (!inXml(k)) expOnly.push(p);
    }
    const diskSet = new Set(onDisk.map((p) => p.toLowerCase()));
    for (const r of rows) if (r.page_rule !== 'missing on purpose' && /\.aspx$/i.test(pagePart(r.address)) && !diskSet.has(pagePart(r.address).toLowerCase())) missing.push(r.address);
    for (const p of [...xml.pub, ...xml.pages.keys()]) if (!diskSet.has(p)) missing.push(p + ' (PageAccess.xml)');
    t.record({
      title: 'Every page on disk is in expected.csv or in PageAccess.xml', role: '-', address: onDisk.length + ' pages on disk',
      expected: 'none in neither', seen: neither.length ? neither.length + ' in neither' : 'none in neither', pass: neither.length === 0,
      detail: neither.length ? 'In neither: ' + neither.join(', ') : '',
    });
    t.record({
      title: 'Every page on disk is in expected.csv', role: '-', address: onDisk.length + ' pages on disk',
      expected: 'all', seen: xmlOnly.length ? xmlOnly.length + ' only in PageAccess.xml' : 'all', pass: xmlOnly.length === 0,
      detail: xmlOnly.length ? 'Only in PageAccess.xml: ' + xmlOnly.join(', ') : '',
    });
    t.record({
      title: 'Every address of expected.csv and of PageAccess.xml is a page on disk', role: '-', address: 'expected.csv, PageAccess.xml',
      expected: 'all on disk', seen: missing.length ? missing.length + ' not on disk' : 'all on disk', pass: missing.length === 0,
      detail: missing.length ? 'Not on disk: ' + missing.join(', ') : '',
    });
    t.record({
      title: 'Note: pages in expected.csv that PageAccess.xml does not list (the module refuses them to every role)', role: '-', address: 'PageAccess.xml',
      expected: 'reported', seen: 'reported', pass: true, detail: expOnly.length ? expOnly.join(', ') : 'none',
    });
    t.record({
      title: 'PageAccess.xml is in Enforce mode', role: '-', address: 'BMMS/XML/PageAccess.xml', expected: 'Enforce', seen: xml.mode || '(none)', pass: xml.mode === 'Enforce',
    });

    // 3. Agreement of the decided cells with PageAccess.xml.
    const diffs = [];
    for (const r of rows) {
      if (r.page_rule === 'missing on purpose') continue;
      for (const c of COLUMNS) {
        const kind = WORDS[r[c]];
        if (kind === 'decide') continue;
        const v = xmlVerdict(xml, r.address, c);
        const cellLetsThrough = kind !== 'denied' && !(kind === 'signin' && v === 'signin');
        let differs;
        if (v === 'signin') differs = kind !== 'signin';
        else if (r.page_rule === 'RA1b') differs = v === 'refused' && cellLetsThrough;
        else differs = (v === 'refused') !== (kind === 'denied');
        if (differs) diffs.push(r.address + ' / ' + c + ': expected.csv "' + r[c] + '", PageAccess.xml ' + (v === 'allowed' ? 'lets it through' : v === 'refused' ? 'refuses it' : 'sends to the sign-in page'));
      }
    }
    t.record({
      title: 'The decided cells of expected.csv agree with PageAccess.xml', role: '-', address: rows.length + ' rows',
      expected: 'no difference', seen: diffs.length ? diffs.length + ' difference(s)' : 'no difference', pass: diffs.length === 0,
      detail: diffs.length ? 'For the owner to decide (the XML or the cell): ' + diffs.join('; ') : '',
    });

    // 4. and 5. The menu (read first, on the Dashboard) and the matrix.
    const menus = {};
    for (const c of SIGNED_IN) menus[c] = await readMenu(t, c);
    for (const c of SIGNED_IN) checkMenu(t, c, menus[c], rows, notInMenu, homeLink);
    await runMatrix(t, rows, { proof: false, planted: null });
  },
};

// The links a role sees: the menu bar, its drop-down lists and the header (Logout is a button, not a link).
async function readMenu(t, column) {
  const page = await t.session(column);
  await t.visit(page, 'DashBoard/DashBoard.aspx');
  // A drop-down list counts only when an item of the menu bar opens it (rel="<its id>"): the lists are in the
  // page for every role, but a role without the menu bar item cannot open them. Links of a list that no item
  // opens are kept apart (reported as a note).
  const found = await page.evaluate(() => {
    const out = [], unreachable = [];
    const take = (list, where, into) => list.forEach((a) => {
      const href = a.getAttribute('href') || '';
      if (!href || href === '#' || /^javascript:/i.test(href)) return;
      into.push({ where, text: (a.textContent || '').trim(), url: a.href });
    });
    const rels = new Set(Array.from(document.querySelectorAll('#ddtopmenubar a[rel]')).map((a) => a.getAttribute('rel')));
    take(document.querySelectorAll('#ddtopmenubar a[href]'), 'menu bar', out);
    document.querySelectorAll('ul.ddsubmenustyle').forEach((ul) => {
      take(ul.querySelectorAll('a[href]'), 'drop-down ' + ul.id, rels.has(ul.id) ? out : unreachable);
    });
    take(document.querySelectorAll('.wb-user a[href]'), 'header', out);
    return { out, unreachable };
  });
  const links = found.out.map((l) => {
    let u = null; try { u = new URL(l.url); } catch (e) { /* kept as text */ }
    const address = u ? (u.pathname.replace(/^\/+/, '') + u.search) : l.url;
    return Object.assign(l, { address, local: !!u && (u.hostname === 'localhost' || u.hostname === '127.0.0.1') });
  });
  links.unreachable = found.unreachable;
  return links;
}

function checkMenu(t, column, links, rows, notInMenu, homeLink) {
  const byKey = new Map(rows.map((r) => [key(r.address), r]));
  const bad = [];
  for (const l of links) {
    const r = byKey.get(key(l.address));
    if (!l.local) bad.push('"' + l.text + '" (' + l.where + ') leaves the site: ' + l.address);
    else if (!r) bad.push('"' + l.text + '" (' + l.where + ') ' + l.address + ' is not an address in expected.csv');
    else if (WORDS[r[column]] !== 'opens') bad.push('"' + l.text + '" (' + l.where + ') ' + l.address + ' is "' + r[column] + '" for ' + column);
  }
  t.record({
    title: 'Menu of ' + column + ': every link is an address of expected.csv that opens for the role', role: column, address: links.length + ' links',
    expected: 'all open', seen: bad.length ? bad.length + ' link(s) wrong' : 'all open', pass: bad.length === 0, detail: bad.join('; '),
  });
  const hidden = links.unreachable || [];
  t.record({
    title: 'Note: links in the page of ' + column + ' that no menu bar item opens (in the markup, not reachable by the menu)', role: column, address: hidden.length + ' links',
    expected: 'reported', seen: 'reported', pass: true,
    detail: hidden.length ? hidden.map((l) => '"' + l.text + '" (' + l.where + ')').join(', ') : 'none',
  });

  const linked = new Set(links.map((l) => key(l.address)));
  const approved = notInMenu.filter((n) => n.role === '*' || n.role === column);
  const unlinked = [];
  for (const r of rows) {
    if (WORDS[r[column]] !== 'opens' || linked.has(key(r.address))) continue;
    if (!approved.find((n) => key(n.address) === key(r.address))) unlinked.push(r.address);
  }
  const stale = [];
  for (const n of approved) {
    const r = byKey.get(key(n.address));
    if (!r) { stale.push(n.role + ' ' + n.address + ': not an address in expected.csv'); continue; }
    if (linked.has(key(n.address))) stale.push(n.role + ' ' + n.address + ': the role has a link to it');
    else if (WORDS[r[column]] === 'denied' || WORDS[r[column]] === 'signin') stale.push(n.role + ' ' + n.address + ': it is "' + r[column] + '" for ' + column);
  }
  t.record({
    title: 'Menu of ' + column + ': every page the role opens has a link or a row in not-in-menu.csv, and no row there is stale', role: column, address: 'not-in-menu.csv',
    expected: 'none left over', seen: unlinked.length + stale.length ? (unlinked.length + stale.length) + ' left over' : 'none left over', pass: unlinked.length + stale.length === 0,
    detail: [].concat(unlinked.length ? ['Opens without a link or an approved row: ' + unlinked.join(', ')] : [], stale.length ? ['Rows that do not apply: ' + stale.join(', ')] : []).join('; '),
  });

  const rule = homeLink.find((h) => h.role === column);
  const has = links.some((l) => l.where === 'menu bar' && /^home$/i.test(l.text));
  const want = rule.home === 'yes';
  t.record({
    title: 'Menu of ' + column + ': Home link ' + (want ? 'shown' : 'not shown') + ' (' + rule.rule + ')', role: column, address: 'menu bar',
    expected: want ? 'Home link' : 'no Home link', seen: has ? 'Home link' : 'no Home link', pass: has === want,
  });
}

// Every column in parallel; within a column the rows in file order, Logout.aspx last.
async function runMatrix(t, rows, opts) {
  const ordered = rows.filter((r) => key(r.address) !== 'logout.aspx').concat(rows.filter((r) => key(r.address) === 'logout.aspx'));
  await Promise.all(COLUMNS.map((c) => runColumn(t, c, ordered, opts)));
}

async function runColumn(t, column, rows, opts) {
  let page, context = null;
  if (column === 'visitor') ({ context, page } = await t.anonymousPage());
  else if (column === 'inactive') {
    const s = await t.signIn('inactive');
    context = s.context; page = s.page;
    const msg = (await page.locator('[id$="spanErrLogin"]').innerText().catch(() => '')).trim();
    const refused = /\/default\.aspx$/i.test(s.where) && msg.indexOf(INACTIVE_MESSAGE) >= 0;
    t.record({
      title: 'qa_inactive: sign-in refused with "' + INACTIVE_MESSAGE + '"', role: 'inactive', address: 'Default.aspx', expected: 'refused', seen: refused ? 'refused' : 'landed on ' + s.where + (msg ? ' (' + msg.slice(0, 80) + ')' : ''),
      pass: refused, proof: opts.proof,
    });
  } else page = await t.session(column);

  const login = (column === 'visitor') ? null : t.creds.accounts[column].login;
  try {
    for (const r of rows) {
      const kind = WORDS[r[column]];
      if (column !== 'visitor' && column !== 'inactive' && key(r.address) !== 'logout.aspx') page = await t.session(column);
      const mark = t.logMark();
      const seen = await t.visit(page, r.address);
      const lines = t.logSince(mark).filter((l) => {
        const f = l.split('\t');
        if (f.length < 5 || pagePart(f[4]).toLowerCase() !== pagePart(r.address).toLowerCase()) return false;
        return login ? f[2].indexOf('(' + login + ')') >= 0 : f[2].trim() === '';
      });
      const denials = lines.filter((l) => /\tDENIED(-PAGE)?\t/.test(l)).length;
      let pass, logNote = '';
      if (kind === 'decide') pass = false;
      else {
        pass = seen.kind === kind;
        const wantDenials = kind === 'denied' ? 1 : 0;
        if (denials !== wantDenials) { pass = false; logNote = '; page access log: ' + denials + ' DENIED line(s) for this user and page, ' + wantDenials + ' expected'; }
      }
      const isPlanted = !!opts.planted && key(opts.planted.address) === key(r.address) && opts.planted.column === column;
      let screenshot = '';
      if (!pass || isPlanted) screenshot = await t.shot(page, column + '-' + r.address);
      t.record({
        title: column + ' opens ' + r.address, role: column, address: r.address, expected: kind, seen: seen.kind,
        detail: 'HTTP ' + seen.status + (seen.path ? ', ended on ' + seen.path : '') + logNote + (seen.kind.startsWith('http-') || seen.kind === 'no-answer' ? ' - ' + seen.note : ''),
        pass, planted: isPlanted, proof: opts.proof, screenshot, accessLog: lines,
        grid: { row: r.address, column, cell: r[column], rule: r.rule },
      });
      if (key(r.address) === 'logout.aspx' && column !== 'visitor' && column !== 'inactive') await t.endSession(column);
    }
  } finally {
    if (context) await context.close().catch(() => null);
  }
}
