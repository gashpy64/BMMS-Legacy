'use strict';
/*
  dashboard - the Dashboard's Meetings card per role (step UN6b).

  Data (this folder; the rules are in README.md):
    expected.json   per case: the account, the filter chosen, the drop-downs, subtitle, card title, the header of
                    the last statistics column, whether statistics are shown, and the Scheduled and Completed rows
                    (committee, meeting number, colour, label, counts); the first-page row counts of the Alert and
                    Action Item lists; the two headings of the Alerts card; the window widths of the layout checks

  What it checks
    1. Every case of expected.json: the rows in order, with colour class and label, the counts or no counts at
       all (MD Secretariat, Admin), the drop-downs, subtitle, title and header; the dates in dd-MMM-yyyy.
    2. The Alert and Action Item lists still show the same number of rows on their first page (an Alerts row is
       a compact row, .wb-dash-alert, since Finding B).
    3. The inactive account cannot sign in; a visitor who opens the Dashboard ends on the sign-in page.
    4. At each width of expected.json: the page is no wider than the window; at 1366 px the Meetings and Alerts
       cards are side by side, below 1100 px stacked; the same with the Agenda Alert panel (qa_manager) and the
       Action Item Details panel (qa_user) open. At each width (qa_manager) the Alerts card: the two headings of
       expected.json, none cut and the grid no wider than its card; every date dd-MMM-yyyy with HH:mm below it,
       on at most two lines.

  It opens pages of the site copy and reads them; a panel it opens is left by opening the Dashboard again. It writes nothing but its
  check records. The data is the fixture (Tests\fixture), restored and dated afresh before every run.
*/
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const DASHBOARD = 'DashBoard/DashBoard.aspx';
const INACTIVE_MESSAGE = 'Your account is inactive';
const DATE_FORMAT = /^\d{2}-[A-Z][a-z]{2}-\d{4}$/;
const TIME_FORMAT = /^\d{2}:\d{2}$/;

function readExpected() {
  let text = fs.readFileSync(path.join(DIR, 'expected.json'), 'utf8');
  if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);   // a byte order mark, if an editor wrote one
  const data = JSON.parse(text);
  // A named list (rowsScheduledAll, rowsCompletedAll) is shared by several cases; where no statistics are shown
  // (MD Secretariat, Admin) its rows are compared without their counts (the fifth part)
  const rows = (v, statistics) => ((typeof v === 'string' ? data[v] : v) || [])
    .map((r) => (statistics ? r : r.split(' | ').slice(0, 4).join(' | ')));
  for (const c of data.cases) { c.scheduledRows = rows(c.scheduled, c.statistics); c.completedRows = rows(c.completed, c.statistics); }
  return data;
}

// Waits until an ASP.NET partial postback (UpdatePanel) has finished
async function settle(page) {
  await page.waitForFunction(() => !(window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager
    && Sys.WebForms.PageRequestManager.getInstance().get_isInAsyncPostBack()), null, { timeout: 30000 });
}

async function postBack(page, action) {
  await Promise.all([
    page.waitForResponse((r) => /dashboard\.aspx/i.test(r.url()) && r.request().method() === 'POST', { timeout: 30000 }),
    action(),
  ]);
  await settle(page);
}

// What the Meetings card shows, read from the page
async function readCard(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : null);
    const q = (sel) => document.querySelector(sel);
    const options = (sel) => { const s = q(sel); return s ? Array.from(s.options).map((o) => o.text.trim()) : null; };
    const grid = (suffix) => {
      const table = q('table[id$="' + suffix + '"]');
      if (!table) return { present: false, head: [], rows: [], empty: null, dates: [] };
      const trs = Array.from(table.querySelectorAll(':scope > tbody > tr'));
      if (trs.length && !trs[0].querySelector('th')) return { present: true, head: [], rows: [], empty: txt(trs[0]), dates: [] };
      const head = trs.length ? Array.from(trs[0].querySelectorAll(':scope > th')).map(txt) : [];
      const dates = [];
      const rows = trs.slice(1).map((tr) => {
        const td = Array.from(tr.querySelectorAll(':scope > td'));
        const chip = td[3] ? td[3].querySelector('.wb-chip') : null;
        const colour = chip ? (Array.from(chip.classList).find((c) => /^wb-chip-/.test(c)) || '').replace('wb-chip-', '') : '';
        tr.querySelectorAll('.wb-dash-date').forEach((d) => { if (txt(d)) dates.push(txt(d)); });
        const parts = [txt(td[0] && td[0].querySelector('.wb-dash-committee')), txt(td[0] && td[0].querySelector('.wb-dash-meeting-no')), colour, txt(chip)];
        const counts = td.slice(4).map(txt);
        if (counts.length) parts.push(counts.join(' '));
        return parts.join(' | ');
      });
      return { present: true, head, rows, empty: null, dates };
    };
    const card = q('.wb-dash-meetings');
    return {
      title: txt(q('.wb-dash-meetings .wb-dash-card-title')),
      subtitle: txt(q('[id$="_pSubtitle"]')),
      message: txt(q('[id$="_pMeetingsMessage"]')),
      committeeOptions: options('select[id$="_ddlCommittee"]'),
      departmentOptions: options('select[id$="_ddlDepartment"]'),
      scheduled: grid('_grvScheduled'),
      completed: grid('_grvCompleted'),
      cardText: card ? card.innerText : '',
    };
  });
}


async function runCase(t, c) {
  const page = await t.session(c.account);
  const seen0 = await t.visit(page, DASHBOARD);
  if (seen0.kind !== 'opens') {
    t.record({ title: c.name + ': the Dashboard opens', role: c.account, address: DASHBOARD, expected: 'opens', seen: seen0.kind, pass: false, screenshot: await t.shot(page, c.account + '-dashboard') });
    return;
  }
  if (c.committee) await postBack(page, () => page.selectOption('select[id$="_ddlCommittee"]', { label: c.committee }));
  if (c.department) await postBack(page, () => page.selectOption('select[id$="_ddlDepartment"]', { label: c.department }));
  const card = await readCard(page);
  const failures = [];
  const rec = (what, expected, seen) => {
    const pass = JSON.stringify(expected) === JSON.stringify(seen);
    if (!pass) failures.push(what);
    t.record({ title: c.name + ': ' + what, role: c.account, address: DASHBOARD + (c.committee ? ' (' + c.committee + ')' : '') + (c.department ? ' (' + c.department + ')' : ''),
      expected: typeof expected === 'string' ? expected : JSON.stringify(expected), seen: typeof seen === 'string' ? seen : JSON.stringify(seen), pass });
    return pass;
  };

  rec('no message in the Meetings card', null, card.message);
  rec('card title', c.title, card.title);
  rec('subtitle', c.subtitle, card.subtitle);
  rec('Committee drop-down ' + (c.committeeFilter ? 'shown, "All committees" first, QA1 and QA2 listed' : 'not shown'),
    c.committeeFilter ? 'shown' : 'not shown',
    card.committeeOptions === null ? 'not shown'
      : (card.committeeOptions[0] === 'All committees' && card.committeeOptions.includes('QA Test Committee') && card.committeeOptions.includes('QA Dashboard Committee') ? 'shown' : 'shown: ' + card.committeeOptions.join(', ')));
  rec('Department drop-down', c.departmentOptions, card.departmentOptions);

  const wantHead = ['Meeting', 'Meeting date', 'Submit agenda by', 'Status'].concat(c.statistics ? ['Items', 'Approved', 'Rejected', c.lastHeader] : []);
  for (const [label, g] of [['Scheduled', card.scheduled], ['Completed (last 10)', card.completed]]) {
    if (g.head.length || g.rows.length) rec(label + ': column headers', wantHead, g.head);
  }
  rec('Scheduled rows (in order)', c.scheduledRows, card.scheduled.rows);
  rec('Scheduled: empty text', c.scheduledRows.length ? null : 'No scheduled meetings.', card.scheduled.empty);
  rec('Completed rows (in order, at most 10)', c.completedRows, card.completed.rows);
  rec('Completed: empty text', c.completedRows.length ? null : 'No completed meetings.', card.completed.empty);
  const badDates = card.scheduled.dates.concat(card.completed.dates).filter((d) => !DATE_FORMAT.test(d));
  rec('dates in the application format dd-MMM-yyyy', [], badDates);
  if (!c.statistics) {
    const words = ['Items', 'Approved', 'Rejected', 'Pending', 'In progress'].filter((w) => card.cardText.includes(w));
    rec('no statistics anywhere in the Meetings card', [], words);
  }
  if (failures.length) t.record({ title: c.name + ': screenshot of the failed case', role: c.account, address: DASHBOARD, expected: 'see the checks above', seen: failures.length + ' failed', pass: false, screenshot: await t.shot(page, c.account + '-' + c.name) });
}

async function rowCount(page, suffix) {
  return page.evaluate((s) => {
    const table = document.querySelector('table[id$="' + s + '"]');
    if (!table) return -1;
    const trs = Array.from(table.querySelectorAll(':scope > tbody > tr'));
    // data rows: not the header, not the pager row (which holds a nested table)
    return trs.filter((tr) => !tr.querySelector(':scope > th') && !tr.querySelector('table') && !tr.querySelector('.divNoRecord')).length;
  }, suffix);
}

// Data rows of the Alerts grid: the compact rows (each holds one .wb-dash-alert); -1 when the grid is missing
async function alertRowCount(page) {
  return page.evaluate(() => {
    const table = document.querySelector('table[id$="_grvAlert"]');
    if (!table) return -1;
    return Array.from(table.querySelectorAll(':scope > tbody > tr')).filter((tr) => tr.querySelector(':scope > td .wb-dash-alert')).length;
  });
}

// The Alerts card as laid out: its headings (text, cut or not), whether the grid is wider than its scroll box,
// and per date cell the date, the time and the number of lines they take
async function readAlertsLayout(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const table = document.querySelector('table[id$="_grvAlert"]');
    if (!table) return null;
    const box = table.closest('.wb-table-scroll');
    const headRow = Array.from(table.querySelectorAll(':scope > tbody > tr')).find((tr) => tr.querySelector(':scope > th'));
    const heads = headRow ? Array.from(headRow.querySelectorAll(':scope > th')).map((th) => ({ text: txt(th), cut: th.scrollWidth > th.clientWidth + 1 })) : [];
    const dates = Array.from(table.querySelectorAll('td.wb-dash-alert-when')).map((td) => {
      const range = document.createRange();
      range.selectNodeContents(td);
      const tops = [];
      Array.from(range.getClientRects()).filter((r) => r.width > 0 && r.height > 0).forEach((r) => {
        if (!tops.some((top) => Math.abs(top - r.top) < 3)) tops.push(r.top);
      });
      return { date: txt(td.querySelector('.wb-dash-date')), time: txt(td.querySelector('.wb-dash-time')), lines: tops.length };
    });
    return { heads, gridWider: box ? box.scrollWidth > box.clientWidth + 1 : false, dates };
  });
}

// Finding B: at this width the Alerts headings are whole and every date is on at most two lines
async function alertsChecks(t, page, w, data) {
  const a = await readAlertsLayout(page);
  if (!a) { t.record({ title: 'Width ' + w.width + ' px: the Alerts card has its grid', role: 'manager', address: DASHBOARD, expected: 'grid shown', seen: 'no grid', pass: false, screenshot: await t.shot(page, 'alerts-' + w.width) }); return; }
  const texts = a.heads.map((h) => h.text);
  const notes = [];
  if (JSON.stringify(texts) !== JSON.stringify(data.alertHeadings)) notes.push('headings ' + JSON.stringify(texts));
  const cut = a.heads.filter((h) => h.cut).map((h) => h.text);
  if (cut.length) notes.push('cut: ' + cut.join(', '));
  if (a.gridWider) notes.push('the grid is wider than its card');
  t.record({ title: 'Width ' + w.width + ' px: Alerts headings ' + data.alertHeadings.join(', ') + ', none cut', role: 'manager', address: DASHBOARD,
    expected: 'whole', seen: notes.length ? notes.join('; ') : 'whole', pass: notes.length === 0, screenshot: notes.length ? await t.shot(page, 'alerts-headings-' + w.width) : '' });
  const bad = a.dates.filter((d) => !DATE_FORMAT.test(d.date) || !TIME_FORMAT.test(d.time) || d.lines > 2)
    .map((d) => d.date + ' ' + d.time + ' (' + d.lines + ' lines)');
  if (!a.dates.length) bad.push('no alert dates to measure');
  const want = 'all ' + a.dates.length + ' dates';
  t.record({ title: 'Width ' + w.width + ' px: Alerts dates dd-MMM-yyyy with HH:mm, at most two lines', role: 'manager', address: DASHBOARD,
    expected: want, seen: bad.length ? bad.join('; ') : want, pass: bad.length === 0, screenshot: bad.length ? await t.shot(page, 'alerts-dates-' + w.width) : '' });
}

async function measure(page) {
  return page.evaluate(() => {
    const r = (sel) => { const el = document.querySelector(sel); if (!el) return null; const b = el.getBoundingClientRect(); return { left: b.left, right: b.right, top: b.top, bottom: b.bottom }; };
    const ca = document.getElementById('contentArea');
    return {
      win: window.innerWidth, doc: document.documentElement.scrollWidth,
      caScroll: ca ? ca.scrollWidth : 0, caClient: ca ? ca.clientWidth : 0,
      meetings: r('.wb-dash-meetings'), alerts: r('.wb-dash-alerts'),
    };
  });
}

function widthVerdict(m) {
  const notes = [];
  if (m.doc > m.win) notes.push('page ' + m.doc + ' px in a ' + m.win + ' px window');
  if (m.caScroll > m.caClient + 1) notes.push('content area scrolls sideways (' + m.caScroll + ' > ' + m.caClient + ')');
  return notes;
}

async function widthChecks(t, data) {
  const page = await t.session('manager');
  for (const w of data.widths) {
    await page.setViewportSize({ width: w.width, height: w.height });
    await t.visit(page, DASHBOARD);
    const m = await measure(page);
    const notes = widthVerdict(m);
    t.record({ title: 'Width ' + w.width + ' px: the page is no wider than the window', role: 'manager', address: DASHBOARD, expected: 'fits', seen: notes.length ? notes.join('; ') : 'fits', pass: notes.length === 0, screenshot: notes.length ? await t.shot(page, 'width-' + w.width) : '' });
    let layout = 'unknown';
    if (m.meetings && m.alerts) layout = m.alerts.left >= m.meetings.right - 1 ? 'side by side' : (m.alerts.top >= m.meetings.bottom - 1 ? 'stacked' : 'overlapping');
    t.record({ title: 'Width ' + w.width + ' px: Meetings and Alerts cards ' + w.layout, role: 'manager', address: DASHBOARD, expected: w.layout, seen: layout, pass: layout === w.layout, screenshot: layout !== w.layout ? await t.shot(page, 'layout-' + w.width) : '' });
    await alertsChecks(t, page, w, data);

    // The Agenda Alert panel (an alert of an agenda item waiting for qa_manager)
    const opened = await openAgendaAlert(page);
    if (!opened) t.record({ title: 'Width ' + w.width + ' px: an Agenda Alert panel can be opened', role: 'manager', address: DASHBOARD, expected: 'opened', seen: 'not opened', pass: false, screenshot: await t.shot(page, 'agenda-panel-' + w.width) });
    else {
      const pm = await measure(page);
      const pn = widthVerdict(pm);
      t.record({ title: 'Width ' + w.width + ' px with the Agenda Alert panel open: no wider than the window', role: 'manager', address: DASHBOARD, expected: 'fits', seen: pn.length ? pn.join('; ') : 'fits', pass: pn.length === 0, screenshot: pn.length ? await t.shot(page, 'agenda-panel-width-' + w.width) : '' });
      // The panel is left open: the next width opens the Dashboard afresh
    }
  }
  await page.setViewportSize({ width: 1366, height: 768 });

  const upage = await t.session('user');
  for (const w of data.widths) {
    await upage.setViewportSize({ width: w.width, height: w.height });
    await t.visit(upage, DASHBOARD);
    const link = upage.locator('a[id*="lnkActionItem"]').first();
    if (!(await link.count())) { t.record({ title: 'Width ' + w.width + ' px: an Action Item Details panel can be opened', role: 'user', address: DASHBOARD, expected: 'opened', seen: 'no action item link', pass: false }); continue; }
    await postBack(upage, () => link.click());
    const shown = await upage.locator('.MyPopupOuter').first().isVisible().catch(() => false);
    if (!shown) { t.record({ title: 'Width ' + w.width + ' px: an Action Item Details panel can be opened', role: 'user', address: DASHBOARD, expected: 'opened', seen: 'not opened', pass: false, screenshot: await t.shot(upage, 'action-panel-' + w.width) }); continue; }
    const pm = await measure(upage);
    const pn = widthVerdict(pm);
    t.record({ title: 'Width ' + w.width + ' px with the Action Item Details panel open: no wider than the window', role: 'user', address: DASHBOARD, expected: 'fits', seen: pn.length ? pn.join('; ') : 'fits', pass: pn.length === 0, screenshot: pn.length ? await t.shot(upage, 'action-panel-width-' + w.width) : '' });
    // The panel is left open: the next width opens the Dashboard afresh
  }
  await t.visit(upage, DASHBOARD);
  await upage.setViewportSize({ width: 1366, height: 768 });
}

// Opens the first alert whose panel is the Agenda Alert panel (an alert of another kind is closed again)
async function openAgendaAlert(page) {
  const links = page.locator('a[id*="lnkSource"]');
  const n = Math.min(await links.count(), 3);
  for (let i = 0; i < n; i++) {
    await postBack(page, () => links.nth(i).click());
    if (await page.locator('.MyPopupOuter').first().isVisible().catch(() => false)) return true;
    const close = page.locator('input[id$="btnClose"]');
    if (await close.isVisible().catch(() => false)) await postBack(page, () => close.click());
  }
  return false;
}

module.exports = {
  title: 'Dashboard: meetings, colours and statistics per role; layout widths',
  async run(t) {
    const data = readExpected();

    // 2 first: opening a panel later marks an alert as read, which does not change the counts but keeps this
    // check independent of the order
    for (const [account, want] of Object.entries(data.alertsFirstPage)) {
      const page = await t.session(account);
      await t.visit(page, DASHBOARD);
      const alerts = await alertRowCount(page);
      const actions = await rowCount(page, '_grvActionItem');
      const wantActions = data.actionItemsFirstPage[account];
      t.record({ title: 'Alert and Action Item lists unchanged for ' + account + ' (rows on the first page)', role: account, address: DASHBOARD,
        expected: want + ' alerts, ' + wantActions + ' action items', seen: alerts + ' alerts, ' + actions + ' action items', pass: alerts === want && actions === wantActions });
    }

    for (const c of data.cases) await runCase(t, c);

    // 3. The inactive account and a visitor
    const s = await t.signIn('inactive');
    const body = (await s.page.locator('body').innerText().catch(() => '')).replace(/\s+/g, ' ');
    const stayed = /\/default\.aspx$/i.test(s.where) && body.includes(INACTIVE_MESSAGE);
    t.record({ title: 'The inactive account cannot sign in, so it sees no meeting list', role: 'inactive', address: 'Default.aspx', expected: 'refused with "' + INACTIVE_MESSAGE + '"', seen: stayed ? 'refused with "' + INACTIVE_MESSAGE + '"' : 'landed on ' + s.where, pass: stayed });
    await s.context.close();
    await t.check({ role: 'anonymous', address: DASHBOARD, expected: 'signin', title: 'A visitor who opens the Dashboard ends on the sign-in page' });

    // 4. Widths and layout
    await widthChecks(t, data);
  },
};
