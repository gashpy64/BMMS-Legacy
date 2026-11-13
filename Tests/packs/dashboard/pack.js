'use strict';
/*
  dashboard - the Dashboard's Meetings card per role (step UN6b); the Alerts card rules, the header count and the
  Action Items due dates (step UN6c1).

  Data (this folder; the rules are in README.md):
    expected.json   per case: the account, the filter chosen, the drop-downs, subtitle, card title, the header of
                    the last statistics column, whether statistics are shown, and the Scheduled and Completed rows
                    (committee, meeting number, colour, label, counts); the first-page row counts of the Alert and
                    Action Item lists; the two headings of the Alerts card; the window widths of the layout checks;
                    step UN6c1: the header count per account, the three links of the Alerts card for one account,
                    the person named on some alerts, the due dates of the action items, the accounts of the
                    action checks, the accounts of the check of the link chosen (filterKept), the items of
                    the Action Items card per account (actionItemsList) and the accounts and items of the
                    scope checks (actionScope)

  What it checks
    1. Every case of expected.json: the rows in order, with colour class and label, the counts or no counts at
       all (MD Secretariat, Admin), the drop-downs, subtitle, title and header; the dates in dd-MMM-yyyy.
    2. The Alert and Action Item lists: the number of rows on their first page (an Alerts row is a compact row,
       .wb-dash-alert; the Alerts card opens on Recent), and the header "Alerts (n)" per account. The Admin: no
       rows, "No alerts.", "Alerts (0)".
    3. The inactive account cannot sign in; a visitor who opens the Dashboard ends on the sign-in page.
    4. At each width of expected.json: the page is no wider than the window; at 1366 px the Meetings and Alerts
       cards are side by side, below 1100 px stacked; the same with the Agenda Alert panel (qa_manager) and the
       Action Item Details panel (qa_user) open. At each width (qa_manager) the Alerts card: the two headings of
       expected.json, none cut and the grid no wider than its card; every date dd-MMM-yyyy with HH:mm below it,
       on at most two lines.

    5. Alerts card rules (step UN6c1, one account): Recent, Unread, All and its second page; the person named on
       an alert with the login ID as tooltip, a dash where no approver is recorded; in the Action Items card the
       due date and the word "Overdue".
    6. Alerts card actions (step UN6c1, last, because they change data): opening an alert lowers the header count
       without a page reload; "Remove from my list" removes the row for this person; the row id of another
       user put into the page is refused and changes nothing. (Approve and Reject are not driven: they send mail
       and the tester has no mail server; the owner checks the header after them.)
    8. The scope of the Action Items card (step UN6c1; which items each account sees is in check 2): an item
       without a mapping row of the person is unread and is read after opening, for that person only; Management
       opens read-only and its Submit is refused; a Submit with the id of another department's item is refused;
       a Submit inside the scope saves.
    7. The link chosen stays chosen (step UN6c1, owner's test): on both cards, with Unread chosen, opening an item
       or an alert leaves the mark on Unread and the list holds unread rows only; Read, Show All and Recent then
       show the rest with their own mark.

  It opens pages of the site copy and reads them; a panel it opens is left by opening the Dashboard again. Checks 1 to 5 write
  nothing but their check records (opening an alert marks it read). Check 6 removes one alert from a list; check 7 marks one action item and one alert as read; check 8 marks action items as read and saves one action text unchanged. The data is the fixture (Tests\fixture), restored and dated afresh before every run.
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

// ----- Step UN6c1: the Alerts card rules, the header count, the Action Items due dates -----

// "Alerts (n)" as the header shows it (Main.Master), or null when the link is not there
async function headerText(page) {
  return page.evaluate(() => {
    const a = Array.from(document.querySelectorAll('.wb-user a')).find((x) => /^Alerts/.test(x.textContent.replace(/\s+/g, ' ').trim()));
    return a ? a.textContent.replace(/\s+/g, ' ').trim() : null;
  });
}

// The Alerts card as shown: its rows (text of the link, the person named and the tooltip on the name, read or not),
// the pager's page numbers, the empty text, the message, and which of the three links is the current one
async function readAlertsCard(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const card = document.querySelector('.wb-dash-alerts');
    const table = document.querySelector('table[id$="_grvAlert"]');
    const rows = table ? Array.from(table.querySelectorAll(':scope > tbody > tr')).filter((tr) => tr.querySelector(':scope > td .wb-dash-alert')).map((tr) => {
      const actor = tr.querySelector('.wb-dash-alert-actor');
      return { text: txt(tr.querySelector('a[id*="lnkSource"]')), actor: txt(actor), login: actor ? (actor.getAttribute('title') || '') : null,
        meta: txt(tr.querySelector('.wb-dash-alert-meta')), unread: tr.classList.contains('bmms-row-unread') };
    }) : [];
    const pagerRow = table ? Array.from(table.querySelectorAll(':scope > tbody > tr')).find((tr) => tr.querySelector('table')) : null;
    const current = card ? txt(card.querySelector('.wb-dash-links .bmms-filter-current')) : '';
    const msg = document.querySelector('[id$="_pAlertsMessage"]');
    const pager = pagerRow ? Array.from(pagerRow.querySelectorAll(':scope table td')).map(txt).filter((x) => x).join(' ') : '';
    return { rows, pager, empty: txt(table ? table.querySelector('.divNoRecord') : null), message: txt(msg), current };
  });
}

async function chooseAlertMode(page, label) {
  await postBack(page, () => page.locator('.wb-dash-alerts .wb-dash-links a', { hasText: new RegExp('^\\s*' + label + '\\s*$') }).click());
}

// A mark in the page that a full reload would lose: the header must change without one
async function setMark(page) { await page.evaluate(() => { window.__qaNoReload = true; }); }
async function hasMark(page) { return page.evaluate(() => window.__qaNoReload === true); }

// The due-date cells of the Action Items card, by agenda number
async function readActionItems(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const table = document.querySelector('table[id$="_grvActionItem"]');
    if (!table) return null;
    const trs = Array.from(table.querySelectorAll(':scope > tbody > tr'));
    const head = trs.length ? Array.from(trs[0].querySelectorAll(':scope > th')).map(txt) : [];
    const no = head.indexOf('Agenda No'); const due = head.indexOf('Due date');
    const rows = {};
    const card = document.querySelector('.wb-dash-actions');
    const current = card ? txt(card.querySelector('.wb-dash-links .bmms-filter-current')) : '';
    const list = trs.slice(1).filter((tr) => tr.querySelector('a[id*="lnkActionItem"]')).map((tr) => (tr.classList.contains('bmms-row-unread') ? 'unread' : 'read'));
    trs.slice(1).forEach((tr) => {
      const td = Array.from(tr.querySelectorAll(':scope > td'));
      if (no < 0 || due < 0 || !td[no] || !td[due] || tr.querySelector('table')) return;
      rows[txt(td[no])] = { date: txt(td[due].querySelector('.wb-dash-date')), overdue: txt(td[due].querySelector('.wb-dash-overdue')), unread: tr.classList.contains('bmms-row-unread') };
    });
    return { head, rows, current, list };
  });
}

async function chooseActionMode(page, label) {
  await postBack(page, () => page.locator('.wb-dash-actions .wb-dash-links a', { hasText: new RegExp('^\\s*' + label + '\\s*$') }).click());
}

// 7. The link chosen stays chosen (owner's test of UN6c1): with Unread chosen, opening an item or an alert leaves the
//    mark on Unread and the list holds unread rows only, one less; the other links then show the rest.
//    It marks one action item and one alert of the account as read.
async function filterKeptChecks(t, data) {
  const f = data.filterKept;
  let role = f.actionAccount;
  let page = await t.session(f.actionAccount);
  await t.visit(page, DASHBOARD);
  const rec = (title, expected, seen) => {
    const e = JSON.stringify(expected); const s = JSON.stringify(seen);
    t.record({ title, role, address: DASHBOARD, expected: e, seen: s, pass: e === s });
  };
  const unreadRows = (n) => Array(n).fill('unread');
  const actions = async () => { const a = await readActionItems(page); return a ? { current: a.current, rows: a.list } : { current: '', rows: 'no grid' }; };
  const alerts = async () => { const c = await readAlertsCard(page); return { current: c.current, rows: c.rows.map((r) => (r.unread ? 'unread' : 'read')) }; };

  // The panel of the item or alert opened lies over the page: it is closed with its own X or Close button, as a user does
  const closePanel = async () => {
    const button = page.locator('input[type="submit"][value="X"]:visible, input[type="submit"][value="Close"]:visible').first();
    await postBack(page, () => button.click());
  };

  // Action Items card
  rec('Action Items of ' + f.actionAccount + ' at the start: Show All marked, every row unread', { current: 'Show All', rows: unreadRows(f.actionItems) }, await actions());
  await chooseActionMode(page, 'Unread');
  rec('Action Items, Unread chosen: Unread marked, the unread rows', { current: 'Unread', rows: unreadRows(f.actionItems) }, await actions());
  await postBack(page, () => page.locator('a[id*="lnkActionItem"]').first().click());
  rec('Action Items, an item opened under Unread: Unread still marked, the list holds unread rows only, one less',
    { current: 'Unread', rows: unreadRows(f.actionItems - 1) }, await actions());
  await closePanel();
  rec('Action Items, the panel closed again: Unread still marked, the same unread rows',
    { current: 'Unread', rows: unreadRows(f.actionItems - 1) }, await actions());
  await chooseActionMode(page, 'Read');
  rec('Action Items, Read chosen: Read marked, the one row just opened', { current: 'Read', rows: ['read'] }, await actions());
  await chooseActionMode(page, 'Show All');
  const all = await actions();
  rec('Action Items, Show All chosen: Show All marked, every row, one of them read',
    { current: 'Show All', rows: f.actionItems, read: 1 }, { current: all.current, rows: all.rows.length, read: Array.isArray(all.rows) ? all.rows.filter((r) => r === 'read').length : -1 });

  // Alerts card
  role = f.account;
  page = await t.session(f.account);
  await t.visit(page, DASHBOARD);
  await chooseAlertMode(page, 'Unread');
  rec('Alerts of ' + f.account + ', Unread chosen: Unread marked, the unread rows', { current: 'Unread', rows: unreadRows(f.alerts) }, await alerts());
  await postBack(page, () => page.locator('a[id*="lnkSource"]').first().click());
  rec('Alerts, an alert opened under Unread: Unread still marked, the list holds unread rows only, one less; the header follows',
    { current: 'Unread', rows: unreadRows(f.alerts - 1), header: 'Alerts (' + (f.alerts - 1) + ')' }, Object.assign(await alerts(), { header: await headerText(page) }));
  await closePanel();
  rec('Alerts, the panel closed again: Unread still marked, the same unread rows',
    { current: 'Unread', rows: unreadRows(f.alerts - 1) }, await alerts());
  await chooseAlertMode(page, 'Recent');
  const recent = await alerts();
  rec('Alerts, Recent chosen: Recent marked, every row, one of them read',
    { current: 'Recent', rows: f.alerts, read: 1 }, { current: recent.current, rows: recent.rows.length, read: recent.rows.filter((r) => r === 'read').length });
  await t.visit(page, DASHBOARD);
}

// 5. The rules of the Alerts card that change nothing: the three links and paging, the person named, the due dates
async function alertRuleChecks(t, data) {
  const m = data.alertModes;
  const page = await t.session(m.account);
  await t.visit(page, DASHBOARD);
  const rec = (title, expected, seen) => {
    const e = typeof expected === 'string' ? expected : JSON.stringify(expected); const s = typeof seen === 'string' ? seen : JSON.stringify(seen);
    t.record({ title, role: m.account, address: DASHBOARD, expected: e, seen: s, pass: e === s });
    return e === s;
  };
  await setMark(page);
  const header = await headerText(page);
  let card = await readAlertsCard(page);
  rec('Alerts card of ' + m.account + ', Recent (the default link): rows, no pager, the last row', { current: 'Recent', rows: m.recent, pager: '', last: m.recentLast },
    { current: card.current, rows: card.rows.length, pager: card.pager, last: card.rows.length ? card.rows[card.rows.length - 1].text : '' });
  rec('Recent: the read alert of 2 days ago is listed as read; the read alerts of 10 and 12 days ago are not listed', { youngRead: 'read', old: [] },
    { youngRead: (card.rows.find((r) => r.text === m.recentLast) || {}).unread === false ? 'read' : 'unread or missing', old: card.rows.filter((r) => m.allPage2.includes(r.text)).map((r) => r.text) });

  // The person who caused the alert, with the login ID as tooltip; a dash where nobody is recorded
  const actors = {};
  for (const [text, want] of Object.entries(data.alertActors)) { const r = card.rows.find((x) => x.text === text); actors[text] = r ? { name: r.actor, tooltip: r.login } : 'row missing'; }
  rec('Alerts: the person named on each alert and the tooltip (login ID); a dash without tooltip where no approver is recorded', data.alertActors, actors);
  const noBy = card.rows.filter((r) => !/ \| by \S/.test(r.meta)).map((r) => r.text);
  rec('Alerts: every row ends with "by" and a name or a dash', [], noBy);

  await chooseAlertMode(page, 'Unread');
  card = await readAlertsCard(page);
  rec('Unread: rows, all unread', { current: 'Unread', rows: m.unread, read: 0 }, { current: card.current, rows: card.rows.length, read: card.rows.filter((r) => !r.unread).length });

  await chooseAlertMode(page, 'All');
  card = await readAlertsCard(page);
  rec('All, page 1: ten rows and a pager with two pages', { current: 'All', rows: 10, pager: '1 2' }, { current: card.current, rows: card.rows.length, pager: card.pager });
  await postBack(page, () => page.locator('table[id$="_grvAlert"] table a', { hasText: /^2$/ }).click());
  card = await readAlertsCard(page);
  rec('All, page 2: the two older read alerts (nothing is deleted)', m.allPage2, card.rows.map((r) => r.text));

  await chooseAlertMode(page, 'Recent');
  card = await readAlertsCard(page);
  rec('Back to Recent: the first page again', { current: 'Recent', rows: m.recent }, { current: card.current, rows: card.rows.length });
  rec('The header count did not change with the links, and the page was not reloaded', { header: header, noReload: true }, { header: await headerText(page), noReload: await hasMark(page) });

  // Action Items card: due date and the word "Overdue"
  const ai = await readActionItems(page);
  const seenDue = {};
  for (const no of Object.keys(data.actionItemsDue)) {
    const r = ai && ai.rows[no];
    seenDue[no] = !r ? 'row missing' : (r.date === '' ? 'none' : (DATE_FORMAT.test(r.date) ? 'date' : 'bad date "' + r.date + '"')) + (r.overdue ? ' ' + r.overdue : '');
  }
  rec('Action Items: the due date (dd-MMM-yyyy) and the word Overdue only on the passed one; no due date, no mark', data.actionItemsDue, seenDue);
}

// 6. The actions of the Alerts card (they change the data; BMMS_Quality is restored before every run): the header
//    count follows without a page reload; Remove from my list; another user's alert id is refused
async function alertActionChecks(t, data) {
  const a = data.alertActions;
  const page = await t.session(a.account);
  await t.visit(page, DASHBOARD);
  const rec = (title, expected, seen, role) => {
    const e = typeof expected === 'string' ? expected : JSON.stringify(expected); const s = typeof seen === 'string' ? seen : JSON.stringify(seen);
    t.record({ title, role: role || a.account, address: DASHBOARD, expected: e, seen: s, pass: e === s });
    return e === s;
  };
  const hidden = 'input[id$="hdnAlertUserId"]';
  const removeButton = 'input[id$="btnDeleteAlert"]';
  // The page's message box, only while it is shown (its text stays in the markup when it is hidden again)
  const pageMessage = async (p) => p.evaluate(() => {
    const box = document.querySelector('[id$="divErrLogin"]'); const span = document.querySelector('[id$="spanErrLogin"]');
    return !box || !span || /divErrorHide/.test(box.className) ? '' : span.textContent.replace(/\s+/g, ' ').trim();
  });

  // Opening an alert marks it read: the header goes down by one, with no reload
  await setMark(page);
  let card = await readAlertsCard(page);
  rec('Before: header and rows of ' + a.account, { header: 'Alerts (' + a.unread + ')', rows: a.unread }, { header: await headerText(page), rows: card.rows.length });
  await postBack(page, () => page.locator('a[id*="lnkSource"]').first().click());
  rec('Opening an alert: the header count goes down by one without a page reload', { header: 'Alerts (' + (a.unread - 1) + ')', noReload: true },
    { header: await headerText(page), noReload: await hasMark(page) });
  rec('The button reads "Remove from my list"', 'Remove from my list', await page.locator(removeButton).inputValue().catch(() => 'button not found'));

  // Remove from my list: the row leaves this list; it was read already, so the count stays
  await postBack(page, () => page.locator(removeButton).click());
  card = await readAlertsCard(page);
  rec('Remove from my list: one row less, no message, header as before, no page reload', { rows: a.unread - 1, message: '', header: 'Alerts (' + (a.unread - 1) + ')', noReload: true },
    { rows: card.rows.length, message: await pageMessage(page), header: await headerText(page), noReload: await hasMark(page) });
  await chooseAlertMode(page, 'All');
  card = await readAlertsCard(page);
  rec('The removed alert is not under All either (it left this person\'s list)', a.unread - 1, card.rows.length);

  // Another user's row id sent with Remove: refused, nothing changes for either
  const other = await t.session(a.otherAccount);
  await t.visit(other, DASHBOARD);
  const otherBefore = (await readAlertsCard(other)).rows.length;
  await postBack(other, () => other.locator('a[id*="lnkSource"]').first().click());
  const foreignId = await other.locator(hidden).inputValue();
  await t.visit(other, DASHBOARD);
  await t.visit(page, DASHBOARD);
  await postBack(page, () => page.locator('a[id*="lnkSource"]').first().click());
  const ownId = await page.locator(hidden).inputValue();
  await page.evaluate(([sel, value]) => { document.querySelector(sel).value = value; }, [hidden, foreignId]);
  await postBack(page, () => page.locator(removeButton).click());
  const refusal = await pageMessage(page);
  // The alert opened for this is read now; one older than 7 days leaves Recent by the rule, so the list is counted under All
  await chooseAlertMode(page, 'All');
  card = await readAlertsCard(page);
  rec('Remove with the alert row id of ' + a.otherAccount + ' put in the page: refused with a message, own list (All) unchanged',
    { foreignIdUsed: true, message: 'This alert is not in your list.', rows: a.unread - 1 },
    { foreignIdUsed: /^\d+$/.test(foreignId) && foreignId !== ownId, message: refusal, rows: card.rows.length });
  await t.visit(other, DASHBOARD);
  await chooseAlertMode(other, 'All');
  rec('The list of ' + a.otherAccount + ' still has all its rows', otherBefore, (await readAlertsCard(other)).rows.length, a.otherAccount);

  // Approve and Reject are not driven here: they send mail, the tester has no mail server, and the failed mail writes
  // to the error log, which fails a run. The header after Approve and Reject is in the owner's checks; both go through
  // the same reload of the list (LoadAlertGRV) as Remove from my list.
}

// 8. The scope of the Action Items card (step UN6c1): the read state is each person's own, also for an item the
//    person has no mapping row for; Management opens read-only and its Submit saves nothing; a Submit for an item
//    outside the person's scope is refused. Which items each account sees is in check 2.
async function actionScopeChecks(t, data) {
  const a = data.actionScope;
  const rec = (role, title, expected, seen) => {
    const e = typeof expected === 'string' ? expected : JSON.stringify(expected); const s = typeof seen === 'string' ? seen : JSON.stringify(seen);
    t.record({ title, role, address: DASHBOARD, expected: e, seen: s, pass: e === s });
  };
  const pageMessage = async (p) => p.evaluate(() => {
    const box = document.querySelector('[id$="divErrLogin"]'); const span = document.querySelector('[id$="spanErrLogin"]');
    return !box || !span || /divErrorHide/.test(box.className) ? '' : span.textContent.replace(/\s+/g, ' ').trim();
  });
  const readState = async (p) => { const ai = await readActionItems(p); const o = {}; if (ai) for (const k of Object.keys(ai.rows)) o[k] = ai.rows[k].unread ? 'unread' : 'read'; return ai ? o : 'no card'; };
  const openItem = async (p, agendaNo) => postBack(p, () => p.locator('table[id$="_grvActionItem"] tr', { hasText: agendaNo }).locator('a[id*="lnkActionItem"]').click());
  const panelOpen = async (p) => p.locator('input[id$="hdnActionItemId"]').count().then((n) => n > 0);
  const closePanel = async (p) => postBack(p, () => p.locator('input[type="submit"][value="X"]:visible').first().click());
  const submit = 'input[id$="btnActionItemApprove"]';
  const hidden = 'input[id$="hdnActionItemId"]';
  const allUnread = (list) => { const o = {}; for (const k of list) o[k] = 'unread'; return o; };

  // The read state is the person's own: the Controller has no mapping row for the item, sees it unread, opens it
  const ctl = await t.session(a.opener);
  await t.visit(ctl, DASHBOARD);
  rec(a.opener, 'Action Items of ' + a.opener + ' before: every item unread, also ' + a.unmappedItem + ' (no mapping row of this person)', allUnread(data.actionItemsList[a.opener]), await readState(ctl));
  await openItem(ctl, a.unmappedItem);
  rec(a.opener, 'Opening ' + a.unmappedItem + ': the details panel opens', true, await panelOpen(ctl));
  await closePanel(ctl);
  const afterOpen = allUnread(data.actionItemsList[a.opener]); afterOpen[a.unmappedItem] = 'read';
  rec(a.opener, 'After opening: ' + a.unmappedItem + ' is read for ' + a.opener + ', the others still unread', afterOpen, await readState(ctl));
  await t.visit(ctl, DASHBOARD);
  rec(a.opener, 'The same after the Dashboard is opened afresh (the read state is kept)', afterOpen, await readState(ctl));

  // Management: sees every item, another person's opening does not mark it read; Submit saves nothing
  const mg = await t.session(a.readOnly);
  await t.visit(mg, DASHBOARD);
  rec(a.readOnly, 'Action Items of ' + a.readOnly + ': every item still unread (the read state of ' + a.opener + ' is not shared)', allUnread(data.actionItemsList[a.readOnly]), await readState(mg));
  await openItem(mg, a.unmappedItem);
  rec(a.readOnly, a.readOnly + ' opens ' + a.unmappedItem + ': the details panel opens', true, await panelOpen(mg));
  await postBack(mg, () => mg.locator(submit).click());
  rec(a.readOnly, 'Submit by ' + a.readOnly + ': refused with a message, the panel closes', { message: 'You cannot change this action item: your role can only read it, or it is not an item of your department. Nothing was saved.', panel: false },
    { message: await pageMessage(mg), panel: await panelOpen(mg) });

  // A Submit for an item outside the person's scope: the id of a Credit item put into the page of the HRD and
  // Secretarial manager
  const other = await t.session(a.otherAccount);
  await t.visit(other, DASHBOARD);
  await openItem(other, a.otherItem);
  const foreignId = await other.locator(hidden).inputValue();
  await t.visit(other, DASHBOARD);
  const m2 = await t.session(a.account);
  await t.visit(m2, DASHBOARD);
  await openItem(m2, a.ownItem);
  const ownId = await m2.locator(hidden).inputValue();
  await m2.evaluate(([sel, value]) => { document.querySelector(sel).value = value; }, [hidden, foreignId]);
  await postBack(m2, () => m2.locator(submit).click());
  rec(a.account, 'Submit by ' + a.account + ' with the id of ' + a.otherItem + ' (another department) put in the page: refused with a message',
    { foreignIdUsed: true, message: 'You cannot change this action item: your role can only read it, or it is not an item of your department. Nothing was saved.' },
    { foreignIdUsed: /^\d+$/.test(foreignId) && foreignId !== ownId, message: await pageMessage(m2) });
  await t.visit(m2, DASHBOARD);
  await openItem(m2, a.ownItem);
  await postBack(m2, () => m2.locator(submit).click());
  rec(a.account, 'Submit by ' + a.account + ' for ' + a.ownItem + ' (his department): saved, no message, the panel closes', { message: '', panel: false },
    { message: await pageMessage(m2), panel: await panelOpen(m2) });
  await t.visit(m2, DASHBOARD);
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
      // Step UN6c1 (scope): 'no card' where the role has no Action Items card (the card is not in the page at all)
      const hasCard = await page.locator('.wb-dash-actions').count() > 0;
      const actions = hasCard ? await rowCount(page, '_grvActionItem') : 'no card';
      const wantActions = data.actionItemsFirstPage[account];
      t.record({ title: 'Alert and Action Item lists of ' + account + ' (rows on the first page; Alerts on Recent)', role: account, address: DASHBOARD,
        expected: want + ' alerts, ' + wantActions + ' action items', seen: alerts + ' alerts, ' + actions + ' action items', pass: alerts === want && actions === wantActions });
      // Step UN6c1 (scope): which items, in the card's order (newest meeting first)
      const ai = hasCard ? await readActionItems(page) : null;
      const wantList = JSON.stringify(data.actionItemsList[account]);
      const seenList = JSON.stringify(ai ? Object.keys(ai.rows) : 'no card');
      t.record({ title: 'Action Items card of ' + account + ': the items by role and department', role: account, address: DASHBOARD, expected: wantList, seen: seenList, pass: wantList === seenList });
      // Step UN6c1: the header count is the number of unread alerts of the card's rule
      const wantHeader = 'Alerts (' + data.alertHeader[account] + ')';
      const header = await headerText(page);
      t.record({ title: 'Header count of ' + account, role: account, address: DASHBOARD, expected: wantHeader, seen: String(header), pass: header === wantHeader });
      if (want === 0) {
        const card = await readAlertsCard(page);
        t.record({ title: 'Alerts card of ' + account + ': no rows, the text "No alerts.", no message', role: account, address: DASHBOARD,
          expected: JSON.stringify({ rows: 0, empty: 'No alerts.', message: '' }), seen: JSON.stringify({ rows: card.rows.length, empty: card.empty, message: card.message }),
          pass: card.rows.length === 0 && card.empty === 'No alerts.' && card.message === '' });
      }
    }

    for (const c of data.cases) await runCase(t, c);

    // 3. The inactive account and a visitor
    const s = await t.signIn('inactive');
    const body = (await s.page.locator('body').innerText().catch(() => '')).replace(/\s+/g, ' ');
    const stayed = /\/default\.aspx$/i.test(s.where) && body.includes(INACTIVE_MESSAGE);
    t.record({ title: 'The inactive account cannot sign in, so it sees no meeting list', role: 'inactive', address: 'Default.aspx', expected: 'refused with "' + INACTIVE_MESSAGE + '"', seen: stayed ? 'refused with "' + INACTIVE_MESSAGE + '"' : 'landed on ' + s.where, pass: stayed });
    await s.context.close();
    await t.check({ role: 'anonymous', address: DASHBOARD, expected: 'signin', title: 'A visitor who opens the Dashboard ends on the sign-in page' });

    // 5. The Alerts card rules (before the width checks open alerts of the manager)
    await alertRuleChecks(t, data);

    // 4. Widths and layout
    await widthChecks(t, data);

    // 6. The actions of the Alerts card, last: they change data
    await alertActionChecks(t, data);
    await filterKeptChecks(t, data);
    await actionScopeChecks(t, data);
  },
};
