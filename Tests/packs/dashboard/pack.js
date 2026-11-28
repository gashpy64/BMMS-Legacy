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
                    scope checks (actionScope);
                    step UN6c2a: the accounts and widths of the fit check of the Scheduled list (meetingsFit) and
                    the item of a passed meeting with its alert and message (pastItem);
                    step UN6c2b: the meaning of "In progress" (inProgressMeaning), the summary cards per account
                    (summary) and with one filter chosen (summaryFilters), the note of the Alerts card (alertsNote),
                    the inactive committee (inactiveCommittee), the widths of the card checks (summaryWidths), the
                    accounts of the heading check (approvalsHeadingKept)

  What it checks
    1. Every case of expected.json: the rows in order, with colour class and label, the counts or no counts at
       all (MD Secretariat, Admin), the drop-downs, subtitle, title and header; the dates in dd-MMM-yyyy.
    2. The Alert and Action Item lists: the number of rows on their first page (an Alerts row is a compact row,
       .wb-dash-alert; the Alerts card opens on Recent), and the header "Alerts (n)" per account. The Admin: no
       rows, "No alerts.", "Alerts (0)".
    3. The inactive account cannot sign in; a visitor who opens the Dashboard ends on the sign-in page.
    4. At each width of expected.json: the page is no wider than the window; above 1240 px the Meetings and Alerts
       cards are side by side, at 1240 px and below stacked (step UN6c2a; 1100 px before); the same with the Agenda Alert panel (qa_manager) and the
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
       opens read-only: no Submit and no Cancel, Close and the read-only line (step UN6d); the Controller's panel
       has Submit and Cancel and no Close; a Submit with the id of another department's item is refused and the
       list is read again; a Submit inside the scope saves with "The action text was saved." and the list is read
       again with the link chosen (step UN6d).
    9. My approvals (step UN6c2a): the panel per account (no panel for the User, Management, MD Secretariat and
       the Admin), its rows, the filters at the top; opening a row shows the Agenda Alert panel with Approve and
       Reject and marks the person's own alert read; a User who opens an alert of an item sees neither button.
       In check 1 the cases of the Controller and the Managers also check the "Waiting for me" column. (Approve and
       Reject themselves are not driven: they send mail.)
   10. The Scheduled list fits its card (step UN6c2a): per account and width of meetingsFit, the cards side by side,
       the number of columns, the table no wider than its scroll box, no empty gap at its right, "Waiting for me"
       on at most two lines.
   11. The meeting-date message (step UN6c2a, step M6a; last, because opening an item from My approvals marks an
       alert read): qa_manager opens the read alert of QA2-00013-1 (meeting 40 days ago, agenda open, routed to
       him) on the last page of All: no Approve or Reject, the message inside the panel just above the buttons and
       not covered; an item he can decide, opened from My approvals, shows the buttons and no message.
   12. The summary cards (step UN6c2b): per account the In progress and Rejected cards (value, label, scope line), the
       meaning of "In progress" on the In progress card, Unread alerts equal to the header count, no message; no cards
       for the MD Secretariat and the Admin; the note of the Alerts card. In check 1 the In progress header has the
       same sentence as its tooltip.
   13. The filters reach every card (step UN6c2b): per case of summaryFilters, after the choice: the two item cards,
       My approvals (heading with its count), the Action Items card; the Alerts card's rows and Unread alerts as before.
   14. The heading "My approvals (n)" keeps its count through the postbacks of the other cards (step UN6c2b).
   15. The inactive committee is offered to nobody (step UN6c2b): it is not in the Committee drop-down of any account.
       (A value put into the drop-down by hand is refused by ASP.NET's event validation before the page sees it, and
       that writes the error log; the server's own refusal of an inactive committee is in the step 45 Test script.)
   16. The summary cards at each width of summaryWidths (step UN6c2b): the page no wider than the window, every card
       inside the row and none of its text cut.
   17. The Meetings tables fit their card at narrow widths (step UN6c2b, owner's tests at 200 % zoom; tableFit): per
       account and width, the Scheduled list with its columns and the Completed list no wider than their scroll box
       (table and box scrollWidth not above the box's clientWidth), the page not scrolling sideways, and where
       minSlack is given each list's narrowest width (the table set to 1 px for the measurement and put back) at
       least minSlack px below the box's clientWidth. A classic vertical scrollbar (Windows Edge, about 17 px) is
       taken into account by a window narrower by `scrollbar` px: headless Chrome draws no classic scrollbar, and a
       table that fits is as wide as its box, so its scrollWidth alone cannot show the room to spare.
    7. The link chosen stays chosen (step UN6c1, owner's test): on both cards, with Unread chosen, opening an item
       or an alert leaves the mark on Unread and the list holds unread rows only; Read, Show All and Recent then
       show the rest with their own mark.

   18. A confirmed followup is final on the Dashboard (step FU2a; last of all, because it confirms and reopens a
       followup): a page of qa_user loaded and a panel of qa_manager opened before the Controller confirms the item
       on the Followup page; the card lists it for nobody; the stale row opens read-only with the line and who
       confirmed it; Submit in the stale panel gets the Reason 26 message, nothing saved, the panel stays open
       read-only with the saved text; the Controller reopens it; the row shows "Overdue" and "Reopened" (orange)
       and the panel who reopened it and why.

  It opens pages of the site copy and reads them; a panel it opens is left by opening the Dashboard again. Checks 1 to 5 write
  nothing but their check records (opening an alert marks it read). Check 6 removes one alert from a list; check 7 marks one action item and one alert as read; check 8 marks action items as read and saves one action text unchanged; check 18 confirms and reopens QA1-00005-001 (it ends Pending, with a Confirm and a Reopen history row; the followup pack, run after, sees the reopen line under that row). The data is the fixture (Tests\fixture), restored and dated afresh before every run.
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
      if (!table) return { present: false, head: [], rows: [], empty: null, dates: [], waiting: {}, tip: null };
      const trs = Array.from(table.querySelectorAll(':scope > tbody > tr'));
      if (trs.length && !trs[0].querySelector('th')) return { present: true, head: [], rows: [], empty: txt(trs[0]), dates: [], waiting: {}, tip: null };
      const head = trs.length ? Array.from(trs[0].querySelectorAll(':scope > th')).map(txt) : [];
      // Step UN6c2b: the tooltip of the In progress header (the eighth column, Items Approved Rejected In progress)
      const ths = trs.length ? Array.from(trs[0].querySelectorAll(':scope > th')) : [];
      const tip = ths[7] ? ths[7].getAttribute('title') : null;
      const dates = [];
      const waiting = {};
      const rows = trs.slice(1).map((tr) => {
        const td = Array.from(tr.querySelectorAll(':scope > td'));
        const chip = td[3] ? td[3].querySelector('.wb-chip') : null;
        const colour = chip ? (Array.from(chip.classList).find((c) => /^wb-chip-/.test(c)) || '').replace('wb-chip-', '') : '';
        tr.querySelectorAll('.wb-dash-date').forEach((d) => { if (txt(d)) dates.push(txt(d)); });
        const parts = [txt(td[0] && td[0].querySelector('.wb-dash-committee')), txt(td[0] && td[0].querySelector('.wb-dash-meeting-no')), colour, txt(chip)];
        // Step UN6c2a: the "Waiting for me" cell is read on its own (below), not with the statistics
        const counts = td.slice(4).filter((c) => !c.classList.contains('wb-dash-waiting')).map(txt);
        if (counts.length) parts.push(counts.join(' '));
        const wcell = td.find((c) => c.classList.contains('wb-dash-waiting'));
        if (wcell && txt(wcell)) waiting[parts[0] + ' | ' + parts[1]] = txt(wcell);
        return parts.join(' | ');
      });
      return { present: true, head, rows, empty: null, dates, waiting, tip };
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


// Step UN6c2b (owner, 2026-11-14): the meaning of "In progress" in full for the Controller and the Managers (the roles
// with "Waiting for me"), the first half for every other role
const meaningFor = (data, account) => (data.inProgressWaitingAccounts.includes(account) ? data.inProgressMeaningWaiting : data.inProgressMeaning);

async function runCase(t, c, data) {
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
  // Step UN6c2a: "Waiting for me" is the last column of the Scheduled list, for a Controller and a Manager only (the
  // cases with a "waiting" entry); the Completed list never has it
  const hasWaiting = c.waiting !== undefined;
  for (const [label, g] of [['Scheduled', card.scheduled], ['Completed (last 10)', card.completed]]) {
    const want = label === 'Scheduled' && hasWaiting ? wantHead.concat(['Waiting for me']) : wantHead;
    if (g.head.length || g.rows.length) rec(label + ': column headers', want, g.head);
  }
  // Step UN6c2b: the In progress header carries the meaning of "In progress" as its tooltip
  if (c.statistics) {
    for (const [label, g] of [['Scheduled', card.scheduled], ['Completed (last 10)', card.completed]]) {
      if (g.head.length) rec(label + ': the In progress header has the meaning of "In progress" (for this role) as its tooltip', meaningFor(data, c.account), g.tip);
    }
  }
  if (hasWaiting) rec('Waiting for me: the meetings with items waiting for this person, and how many', c.waiting, card.scheduled.waiting);
  else rec('no Waiting for me column', false, card.scheduled.head.includes('Waiting for me') || card.completed.head.includes('Waiting for me'));
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
      // Step FU2a: the word "Reopened" and the colour of its chip (read by check 18 only)
      const reopened = td[due].querySelector('.wb-dash-reopened');
      rows[txt(td[no])] = { date: txt(td[due].querySelector('.wb-dash-date')), overdue: txt(td[due].querySelector('.wb-dash-overdue')), unread: tr.classList.contains('bmms-row-unread'),
        reopened: txt(reopened), reopenedChip: reopened ? (Array.from(reopened.classList).find((c) => /^wb-chip-/.test(c)) || '') : '' };
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
  // Step UN6d: the buttons of the details panel (a button the server does not render is not in the page) and its line
  const panelButtons = async (p) => p.evaluate(() => {
    const shown = (sel) => { const el = document.querySelector(sel); return !!el && el.offsetParent !== null; };
    const line = document.querySelector('[id$="pActionItemPanelMessage"]');
    return { submit: shown('input[id$="btnActionItemApprove"]'), cancel: shown('input[id$="btnActionItemCancel"]'),
      close: shown('input[id$="btnActionItemClose"]'), line: line && line.offsetParent !== null ? line.textContent.replace(/\s+/g, ' ').trim() : '' };
  });
  const messageKind = async (p) => p.evaluate(() => {
    const box = document.querySelector('[id$="divErrLogin"]');
    return !box || /divErrorHide/.test(box.className) ? 'none' : (/msg-success/.test(box.className) ? 'success' : 'warning');
  });

  // The read state is the person's own: the Controller has no mapping row for the item, sees it unread, opens it
  const ctl = await t.session(a.opener);
  await t.visit(ctl, DASHBOARD);
  rec(a.opener, 'Action Items of ' + a.opener + ' before: every item unread, also ' + a.unmappedItem + ' (no mapping row of this person)', allUnread(data.actionItemsList[a.opener]), await readState(ctl));
  await openItem(ctl, a.unmappedItem);
  rec(a.opener, 'Opening ' + a.unmappedItem + ': the details panel opens', true, await panelOpen(ctl));
  // Step UN6d: a role that may save sees Submit and Cancel, no Close, no read-only line
  rec(a.opener, 'Details panel of ' + a.opener + ': Submit and Cancel, no Close, no read-only line', { submit: true, cancel: true, close: false, line: '' }, await panelButtons(ctl));
  await closePanel(ctl);
  const afterOpen = allUnread(data.actionItemsList[a.opener]); afterOpen[a.unmappedItem] = 'read';
  rec(a.opener, 'After opening: ' + a.unmappedItem + ' is read for ' + a.opener + ', the others still unread', afterOpen, await readState(ctl));
  await t.visit(ctl, DASHBOARD);
  rec(a.opener, 'The same after the Dashboard is opened afresh (the read state is kept)', afterOpen, await readState(ctl));

  // Management: sees every item, another person's opening does not mark it read. Step UN6d: its panel has no Submit
  // and no Cancel, only Close, and the line that it can only read (the server's refusal of a Submit by Management is
  // proven by the step 43 Test script; a button the page does not render cannot be clicked)
  const mg = await t.session(a.readOnly);
  await t.visit(mg, DASHBOARD);
  rec(a.readOnly, 'Action Items of ' + a.readOnly + ': every item still unread (the read state of ' + a.opener + ' is not shared)', allUnread(data.actionItemsList[a.readOnly]), await readState(mg));
  await openItem(mg, a.unmappedItem);
  rec(a.readOnly, a.readOnly + ' opens ' + a.unmappedItem + ': the details panel opens', true, await panelOpen(mg));
  rec(a.readOnly, 'Details panel of ' + a.readOnly + ': no Submit, no Cancel, Close, and the read-only line', { submit: false, cancel: false, close: true, line: a.readOnlyLine },
    await panelButtons(mg));
  await postBack(mg, () => mg.locator('input[id$="btnActionItemClose"]').click());
  rec(a.readOnly, 'Close by ' + a.readOnly + ': the panel closes, no message', { panel: false, message: '' }, { panel: await panelOpen(mg), message: await pageMessage(mg) });

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
  rec(a.account, 'Submit by ' + a.account + ' with the id of ' + a.otherItem + ' (another department) put in the page: refused with a message, the panel closes, the list read again',
    { foreignIdUsed: true, message: 'You cannot change this action item: your role can only read it, or it is not an item of your department. Nothing was saved.', panel: false, listed: true },
    { foreignIdUsed: /^\d+$/.test(foreignId) && foreignId !== ownId, message: await pageMessage(m2), panel: await panelOpen(m2),
      listed: Object.keys((await readActionItems(m2) || { rows: {} }).rows).includes(a.ownItem) });
  // Step UN6d: a Submit inside the scope saves with a success message; the panel closes and the list is read again
  // with the link chosen (Read: the item was opened above, so it is read)
  await t.visit(m2, DASHBOARD);
  await chooseActionMode(m2, 'Read');
  await openItem(m2, a.ownItem);
  await postBack(m2, () => m2.locator(submit).click());
  const after = await readActionItems(m2);
  rec(a.account, 'Submit by ' + a.account + ' for ' + a.ownItem + ' (his department) under Read: saved with a success message, the panel closes, the list read again under Read',
    { message: a.savedMessage, kind: 'success', panel: false, current: 'Read', listed: true },
    { message: await pageMessage(m2), kind: await messageKind(m2), panel: await panelOpen(m2), current: after ? after.current : 'no card',
      listed: !!after && Object.keys(after.rows).includes(a.ownItem) });
  await t.visit(m2, DASHBOARD);
}

// 9. My approvals (step UN6c2a): the panel per account, with the filters, and opening a row
async function readApprovals(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const card = document.querySelector('.wb-dash-approvals');
    if (!card) return 'no panel';
    const table = card.querySelector('table[id$="_grvApprovals"]');
    const rows = table ? Array.from(table.querySelectorAll(':scope > tbody > tr')).filter((tr) => tr.querySelector('a[id*="lnkApproval"]')).map((tr) => {
      const td = Array.from(tr.querySelectorAll(':scope > td'));
      return [txt(tr.querySelector('a[id*="lnkApproval"]')), txt(td[1]), txt(td[2] && td[2].querySelector('.wb-dash-meeting-no')), txt(td[3])].join(' | ');
    }) : [];
    return { title: txt(card.querySelector('.wb-dash-card-title')), rows, empty: txt(table ? table.querySelector('.divNoRecord') : null), message: txt(card.querySelector('[id$="_pApprovalsMessage"]')) };
  });
}

async function approvalChecks(t, data) {
  const rec = (role, title, expected, seen) => {
    const e = typeof expected === 'string' ? expected : JSON.stringify(expected); const s = typeof seen === 'string' ? seen : JSON.stringify(seen);
    t.record({ title, role, address: DASHBOARD, expected: e, seen: s, pass: e === s });
  };
  const shown = (a) => (a === 'no panel' ? a : { title: a.title, rows: a.rows });

  // Who has the panel, and what waits for him
  for (const [account, want] of Object.entries(data.approvals)) {
    const page = await t.session(account);
    await t.visit(page, DASHBOARD);
    const a = await readApprovals(page);
    rec(account, 'My approvals of ' + account + ': the panel and its rows (item | committee | meeting | department), newest meeting first', want, shown(a));
    if (a !== 'no panel') rec(account, 'My approvals of ' + account + ': no message in the panel', '', a.message);
  }

  // The panel follows the filters at the top
  for (const f of data.approvalFilters) {
    const page = await t.session(f.account);
    await t.visit(page, DASHBOARD);
    if (f.committee) await postBack(page, () => page.selectOption('select[id$="_ddlCommittee"]', { label: f.committee }));
    if (f.department) await postBack(page, () => page.selectOption('select[id$="_ddlDepartment"]', { label: f.department }));
    const a = await readApprovals(page);
    rec(f.account, 'My approvals of ' + f.account + ' with ' + (f.committee ? 'committee ' + f.committee : 'department ' + f.department) + ' chosen',
      { title: f.title, rows: f.rows, empty: f.rows.length ? '' : 'Nothing is waiting for your approval.' }, a === 'no panel' ? a : { title: a.title, rows: a.rows, empty: a.empty });
    await t.visit(page, DASHBOARD);
  }

  // Opening a row: the Agenda Alert panel with Approve and Reject; the person's own alert of the item is read now
  const o = data.approvalOpen;
  const page = await t.session(o.account);
  await t.visit(page, DASHBOARD);
  await setMark(page);
  rec(o.account, 'Before opening ' + o.item + ' from My approvals: the header', o.headerBefore, String(await headerText(page)));
  await postBack(page, () => page.locator('.wb-dash-approvals tr', { hasText: o.item }).locator('a[id*="lnkApproval"]').click());
  const buttons = async (p) => ({ approve: await p.locator('input[id$="btnApprove"]').isVisible().catch(() => false), reject: await p.locator('input[id$="btnReject"]').isVisible().catch(() => false) });
  rec(o.account, 'Opening ' + o.item + ' from My approvals: the Agenda Alert panel with Approve and Reject, the item\'s own alert read (header), no page reload',
    { agendaNo: o.item, approve: true, reject: true, header: o.headerAfter, noReload: true },
    Object.assign({ agendaNo: await page.locator('input[id$="txtAgendaNo"]').inputValue().catch(() => 'panel not open') }, await buttons(page), { header: String(await headerText(page)), noReload: await hasMark(page) }));
  const still = await readApprovals(page);
  rec(o.account, 'The item is still in My approvals (it was opened, not decided)', data.approvals[o.account].rows, still === 'no panel' ? still : still.rows);
  await t.visit(page, DASHBOARD);

  // A person without the panel who opens an alert of an item: no Approve, no Reject (the buttons come from the server)
  const viewer = await t.session(o.viewer);
  await t.visit(viewer, DASHBOARD);
  await chooseAlertMode(viewer, 'All');
  await postBack(viewer, () => viewer.locator('.wb-dash-alerts tr', { hasText: o.viewerAlert }).locator('a[id*="lnkSource"]').first().click());
  rec(o.viewer, o.viewer + ' opens the alert ' + o.viewerAlert + ': the panel opens without Approve and Reject',
    { open: true, approve: false, reject: false },
    Object.assign({ open: await viewer.locator('input[id$="txtAgendaNo"]').isVisible().catch(() => false) }, await buttons(viewer)));
  await t.visit(viewer, DASHBOARD);
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

// 10. Step UN6c2a: the Scheduled list fits its card. At each account and width of meetingsFit: the Meetings and Alerts
//     cards side by side, the number of columns, the table no wider than its scroll box (scrollWidth not above
//     clientWidth), no empty gap at its right, and the heading "Waiting for me" on at most two lines
async function meetingsFitChecks(t, data) {
  for (const f of data.meetingsFit) {
    const page = await t.session(f.account);
    await page.setViewportSize({ width: f.width, height: 768 });
    await t.visit(page, DASHBOARD);
    const m = await page.evaluate(() => {
      const table = document.querySelector('table[id$="_grvScheduled"]');
      const box = table ? table.closest('.wb-table-scroll') : null;
      const card = document.querySelector('.wb-dash-meetings'), alerts = document.querySelector('.wb-dash-alerts');
      if (!table || !box || !card || !alerts) return null;
      const heads = Array.from(table.querySelectorAll('tr th')).filter((th) => th.offsetParent !== null);
      const waiting = heads.find((th) => th.textContent.replace(/\s+/g, ' ').trim() === 'Waiting for me');
      let lines = null;
      if (waiting) {
        const range = document.createRange(); range.selectNodeContents(waiting);
        lines = new Set(Array.from(range.getClientRects()).filter((r) => r.width > 0 && r.height > 0).map((r) => Math.round(r.top))).size;
      }
      const a = alerts.getBoundingClientRect(), c = card.getBoundingClientRect();
      return { sideBySide: a.left >= c.right - 1, columns: heads.length, scroll: table.scrollWidth, client: box.clientWidth,
        gap: Math.round(box.clientWidth - table.getBoundingClientRect().width), waitingLines: lines };
    });
    const want = { layout: 'side by side', columns: f.columns, fits: true, gap: 0, waitingLines: f.columns === 9 ? 'at most 2' : 'no column' };
    const seen = !m ? 'Scheduled list or a card not found' : { layout: m.sideBySide ? 'side by side' : 'stacked', columns: m.columns,
      fits: m.scroll <= m.client, gap: m.gap <= 1 ? 0 : m.gap,
      waitingLines: m.waitingLines === null ? 'no column' : (m.waitingLines <= 2 ? 'at most 2' : m.waitingLines + ' lines') };
    const e = JSON.stringify(want), s = typeof seen === 'string' ? seen : JSON.stringify(seen);
    t.record({ title: 'Width ' + f.width + ' px, ' + f.account + ': the Scheduled list (' + f.columns + ' columns) fits its card beside Alerts, no sideways scroll, no gap'
        + (m ? ' (table ' + m.scroll + ' px, box ' + m.client + ' px)' : ''),
      role: f.account, address: DASHBOARD, expected: e, seen: s, pass: e === s, screenshot: e === s ? '' : await t.shot(page, 'meetings-fit-' + f.account + '-' + f.width) });
    await page.setViewportSize({ width: 1366, height: 768 });
  }
}

// 11. Step UN6c2a (step M6a): an item the person could decide, of a meeting whose date has passed (agenda still open):
//     the Agenda Alert panel opens without Approve and Reject, with the meeting-date message inside the panel next to
//     the buttons, not covered; an item the person can decide shows no such message
async function pastItemChecks(t, data) {
  const p = data.pastItem;
  const page = await t.session(p.account);
  await page.setViewportSize({ width: 1366, height: 768 });
  const panelState = () => page.evaluate(() => {
    const msg = document.querySelector('[id$="_pAgendaPanelMessage"]');
    const panel = document.querySelector('[id$="_pnlAgenda"]');
    const close = document.querySelector('input[id$="_btnAgendaClose"]');
    const shown = !!msg && msg.offsetParent !== null;
    let onTop = false, nextToButtons = false;
    if (shown) {
      msg.scrollIntoView({ block: 'center' });
      const b = msg.getBoundingClientRect();
      const hit = document.elementFromPoint(b.left + b.width / 2, b.top + b.height / 2);
      onTop = !!hit && (hit === msg || msg.contains(hit));
      if (close) { const cb = close.getBoundingClientRect(); nextToButtons = cb.top >= b.bottom - 1 && cb.top - b.bottom <= 40; }
    }
    return { message: shown ? msg.textContent.replace(/\s+/g, ' ').trim() : '', inPanel: !!(shown && panel && panel.contains(msg)), onTop, nextToButtons };
  });
  const buttons = async () => ({ approve: await page.locator('input[id$="btnApprove"]').isVisible().catch(() => false), reject: await page.locator('input[id$="btnReject"]').isVisible().catch(() => false) });
  const rec = (title, want, seen) => {
    const e = JSON.stringify(want), s = typeof seen === 'string' ? seen : JSON.stringify(seen);
    t.record({ title, role: p.account, address: DASHBOARD, expected: e, seen: s, pass: e === s });
    return e === s;
  };

  // The alert is read and 40 days old: on the last page of All
  await t.visit(page, DASHBOARD);
  await chooseAlertMode(page, 'All');
  const pages = (await readAlertsCard(page)).pager.split(' ').map(Number).filter((n) => n > 0);
  const last = pages.length ? Math.max.apply(null, pages) : 1;
  if (last > 1) await postBack(page, () => page.locator('table[id$="_grvAlert"] table a', { hasText: new RegExp('^' + last + '$') }).click());
  const link = page.locator('.wb-dash-alerts tr', { hasText: p.alert }).locator('a[id*="lnkSource"]').first();
  if (!(await link.count())) {
    rec(p.account + ' opens the alert ' + p.alert + ' (All, last page)', 'alert listed', 'alert not listed on page ' + last + ' of All');
  } else {
    await postBack(page, () => link.click());
    const seen = Object.assign({ agendaNo: await page.locator('input[id$="txtAgendaNo"]').inputValue().catch(() => 'panel not open') }, await buttons(), await panelState());
    const ok = rec(p.account + ' opens the alert ' + p.alert + ' (meeting date passed, agenda open, routed to him): no Approve or Reject; the meeting-date message inside the panel, next to the buttons, not covered',
      { agendaNo: p.item, approve: false, reject: false, message: p.message, inPanel: true, onTop: true, nextToButtons: true }, seen);
    if (!ok) await t.shot(page, 'past-item-panel');
  }
  await t.visit(page, DASHBOARD);

  // An item he can decide (from My approvals): Approve and Reject, and no message in the panel
  await postBack(page, () => page.locator('.wb-dash-approvals tr', { hasText: p.decidableItem }).locator('a[id*="lnkApproval"]').click());
  rec(p.account + ' opens ' + p.decidableItem + ' from My approvals: Approve and Reject, no message in the panel',
    { agendaNo: p.decidableItem, approve: true, reject: true, message: '' },
    Object.assign({ agendaNo: await page.locator('input[id$="txtAgendaNo"]').inputValue().catch(() => 'panel not open') }, await buttons(), { message: (await panelState()).message }));
  await t.visit(page, DASHBOARD);
}

// ----- Step UN6c2b: the summary cards and the filters on every card -----

// The summary cards as shown: 'no cards', or per card its value (the hidden "count not available" text left out),
// label, scope line and note; the message under the cards
async function readSummary(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const box = document.querySelector('.wb-dash-summary');
    if (!box) return 'no cards';
    const value = (p) => {
      if (!p) return '';
      const c = p.cloneNode(true);
      c.querySelectorAll('.wb-visually-hidden').forEach((h) => h.remove());
      return txt(c);
    };
    const cards = Array.from(box.querySelectorAll('.wb-dash-stat')).map((s) => ({
      value: value(s.querySelector('.wb-dash-stat-value')), label: txt(s.querySelector('.wb-dash-stat-label')),
      scope: txt(s.querySelector('.wb-dash-stat-scope')), note: txt(s.querySelector('.wb-dash-stat-note')),
    }));
    return { cards, message: txt(box.querySelector('.wb-dash-stat-message')) };
  });
}

// The two item cards as 'value, label, scope' x 2 (the form of expected.json)
const itemCards = (s) => (s === 'no cards' ? s : s.cards.slice(0, 2).reduce((a, c) => a.concat([c.value, c.label, c.scope]), []));

// 12. Per account: the cards, Unread alerts = the header count, the meaning on the In progress card, the Alerts note
async function summaryChecks(t, data) {
  for (const [account, want] of Object.entries(data.summary)) {
    const page = await t.session(account);
    await page.setViewportSize({ width: 1366, height: 768 });
    await t.visit(page, DASHBOARD);
    const s = await readSummary(page);
    const header = await headerText(page);
    const unread = data.alertHeader[account];
    const e = want === 'no cards' ? 'no cards' : { items: want, unread: [String(unread), 'Unread alerts', 'Your alerts, not filtered'], note: meaningFor(data, account), message: '' };
    const seen = s === 'no cards' ? s : { items: itemCards(s), unread: s.cards[2] ? [s.cards[2].value, s.cards[2].label, s.cards[2].scope] : 'no card',
      note: s.cards[0] ? s.cards[0].note : '', message: s.message };
    const ej = JSON.stringify(e), sj = JSON.stringify(seen);
    t.record({ title: 'Summary cards of ' + account + (want === 'no cards' ? ': none' : ': In progress and Rejected (value, label, scope), Unread alerts, the meaning of In progress'),
      role: account, address: DASHBOARD, expected: ej, seen: sj, pass: ej === sj, screenshot: ej === sj ? '' : await t.shot(page, 'summary-' + account) });
    if (want !== 'no cards') {
      const same = s.cards[2] && header === 'Alerts (' + s.cards[2].value + ')';
      t.record({ title: 'Summary cards of ' + account + ': Unread alerts equals the header count', role: account, address: DASHBOARD,
        expected: 'Alerts (' + unread + ')', seen: (s.cards[2] ? 'card ' + s.cards[2].value + ', ' : 'no card, ') + 'header ' + String(header), pass: !!same && header === 'Alerts (' + unread + ')' });
    }
    // The meaning of "In progress" as a visible line under the lists: only where the statistics are shown and no card
    // carries it (the MD Secretariat)
    const line = await page.evaluate(() => { const n = document.querySelector('[id$="_pInProgressNote"]'); return n ? n.textContent.replace(/\s+/g, ' ').trim() : 'no line'; });
    const wantLine = data.inProgressLine.includes(account) ? 'In progress: ' + meaningFor(data, account) : 'no line';
    t.record({ title: 'Meetings card of ' + account + ': the meaning of In progress as a visible line ' + (wantLine === 'no line' ? 'not shown (a card carries it, or no statistics)' : 'under the lists'),
      role: account, address: DASHBOARD, expected: wantLine, seen: line, pass: line === wantLine });
    const note = await page.evaluate(() => { const n = document.querySelector('.wb-dash-alerts .wb-dash-note'); return n ? n.textContent.replace(/\s+/g, ' ').trim() : 'no note'; });
    t.record({ title: 'Alerts card of ' + account + ': the note that the filters do not apply', role: account, address: DASHBOARD, expected: data.alertsNote, seen: note, pass: note === data.alertsNote });
  }
}

// 13. One filter chosen: every card that follows it, and the Alerts card and Unread alerts that do not
async function filterAllCardsChecks(t, data) {
  for (const f of data.summaryFilters) {
    const page = await t.session(f.account);
    await page.setViewportSize({ width: 1366, height: 768 });
    await t.visit(page, DASHBOARD);
    const alertsBefore = await alertRowCount(page);
    const before = await readSummary(page);
    const unreadBefore = before === 'no cards' || !before.cards[2] ? 'no card' : before.cards[2].value;
    if (f.committee) await postBack(page, () => page.selectOption('select[id$="_ddlCommittee"]', { label: f.committee }));
    if (f.department) await postBack(page, () => page.selectOption('select[id$="_ddlDepartment"]', { label: f.department }));
    const s = await readSummary(page);
    const a = await readApprovals(page);
    const hasCard = await page.locator('.wb-dash-actions').count() > 0;
    const ai = hasCard ? await readActionItems(page) : null;
    const want = { cards: f.cards, message: '', approvals: f.approvals, actionItems: f.actionItems, alertRows: alertsBefore, unread: unreadBefore };
    const seen = { cards: itemCards(s), message: s === 'no cards' ? '' : s.message, approvals: a === 'no panel' ? a : a.title,
      actionItems: ai ? Object.keys(ai.rows) : 'no card', alertRows: await alertRowCount(page),
      unread: s === 'no cards' || !s.cards[2] ? 'no card' : s.cards[2].value };
    const ej = JSON.stringify(want), sj = JSON.stringify(seen);
    t.record({ title: f.account + ' with ' + (f.committee ? 'committee ' + f.committee : 'department ' + f.department)
        + ' chosen: the item cards, My approvals and Action Items follow it; the Alerts card and Unread alerts do not',
      role: f.account, address: DASHBOARD, expected: ej, seen: sj, pass: ej === sj, screenshot: ej === sj ? '' : await t.shot(page, 'filters-' + f.account) });
    await t.visit(page, DASHBOARD);
  }
}

// 15. The inactive committee is not offered in the Committee drop-down of any account
async function inactiveCommitteeChecks(t, data) {
  for (const account of Object.keys(data.alertsFirstPage)) {
    const page = await t.session(account);
    await t.visit(page, DASHBOARD);
    const options = await page.evaluate(() => { const s = document.querySelector('select[id$="_ddlCommittee"]'); return s ? Array.from(s.options).map((o) => o.text.trim()) : null; });
    const seen = options === null ? 'no drop-down' : (options.includes(data.inactiveCommittee) ? 'listed' : 'not listed');
    t.record({ title: 'Committee drop-down of ' + account + ': the inactive committee "' + data.inactiveCommittee + '" is not offered', role: account, address: DASHBOARD,
      expected: 'not listed', seen, pass: seen === 'not listed' });
  }
}

// 16. The summary cards at each width: the page no wider than the window, every card inside the row, no text cut
async function summaryWidthChecks(t, data) {
  for (const account of ['controller', 'manager2']) {
    const page = await t.session(account);
    for (const width of data.summaryWidths) {
      await page.setViewportSize({ width, height: 768 });
      await t.visit(page, DASHBOARD);
      const m = await measure(page);
      const notes = widthVerdict(m);
      const c = await page.evaluate(() => {
        const box = document.querySelector('.wb-dash-summary');
        if (!box) return null;
        const b = box.getBoundingClientRect();
        const cards = Array.from(box.querySelectorAll('.wb-dash-stat'));
        const out = cards.filter((s) => { const r = s.getBoundingClientRect(); return r.left < b.left - 1 || r.right > b.right + 1; }).length;
        const cut = cards.filter((s) => s.scrollWidth > s.clientWidth + 1).length
          + Array.from(box.querySelectorAll('.wb-dash-stat p')).filter((p) => p.scrollWidth > p.clientWidth + 1).length;
        const rows = new Set(cards.map((s) => Math.round(s.getBoundingClientRect().top))).size;
        return { cards: cards.length, out, cut, rows };
      });
      if (!c) notes.push('no summary cards');
      else {
        if (c.cards !== 3) notes.push(c.cards + ' cards');
        if (c.out) notes.push(c.out + ' card(s) outside the row');
        if (c.cut) notes.push(c.cut + ' card or text box(es) cut');
      }
      t.record({ title: 'Width ' + width + ' px, ' + account + ': the summary cards fit (no sideways scroll, every card inside the row, no text cut)'
          + (c ? ' (' + c.rows + ' row(s) of cards)' : ''),
        role: account, address: DASHBOARD, expected: 'fits', seen: notes.length ? notes.join('; ') : 'fits', pass: notes.length === 0,
        screenshot: notes.length ? await t.shot(page, 'summary-width-' + account + '-' + width) : '' });
    }
    await page.setViewportSize({ width: 1366, height: 768 });
  }
}

// 17. The Meetings tables at narrow widths: no column cut off, no scroll inside the card, no page sideways scroll
async function tableFitChecks(t, data) {
  for (const f of data.tableFit) {
    const page = await t.session(f.account);
    const scrollbar = f.scrollbar || 0;
    const minSlack = f.minSlack || 0;
    await page.setViewportSize({ width: f.width - scrollbar, height: 900 });
    await t.visit(page, DASHBOARD);
    const m = await page.evaluate(() => {
      const one = (suffix) => {
        const table = document.querySelector('table[id$="' + suffix + '"]');
        const box = table ? table.closest('.wb-table-scroll') : null;
        if (!table || !box) return null;
        const columns = Array.from(table.querySelectorAll('tr:first-child th')).filter((th) => th.offsetParent !== null).length;
        const r = { columns, table: table.scrollWidth, box: box.scrollWidth, client: box.clientWidth };
        const keep = table.style.width;
        table.style.width = '1px';
        r.narrowest = Math.ceil(table.getBoundingClientRect().width);
        table.style.width = keep;
        return r;
      };
      return { s: one('_grvScheduled'), c: one('_grvCompleted'), doc: document.documentElement.scrollWidth, win: window.innerWidth };
    });
    const notes = [];
    if (!m.s || !m.c) notes.push('a Meetings table is missing');
    else {
      if (m.s.columns !== f.columns) notes.push('Scheduled has ' + m.s.columns + ' columns');
      for (const [name, g] of [['Scheduled', m.s], ['Completed', m.c]]) {
        if (g.table > g.client || g.box > g.client) notes.push(name + ' ' + Math.max(g.table, g.box) + ' px in a ' + g.client + ' px box');
        else if (minSlack && g.narrowest + minSlack > g.client) notes.push(name + ' only ' + (g.client - g.narrowest) + ' px to spare (narrowest ' + g.narrowest + ' px, box ' + g.client + ' px; ' + minSlack + ' wanted)');
      }
    }
    if (m.doc > m.win) notes.push('page ' + m.doc + ' px in a ' + m.win + ' px window');
    t.record({ title: 'Width ' + f.width + ' px' + (scrollbar ? ' with a ' + scrollbar + ' px scrollbar' : '') + ', ' + f.account + ': the Scheduled list (' + f.columns + ' columns) and the Completed list fit their card'
        + (minSlack ? ' with at least ' + minSlack + ' px to spare' : '') + ', no page sideways scroll'
        + (m.s ? ' (Scheduled narrowest ' + m.s.narrowest + ' px, box ' + m.s.client + ' px)' : ''),
      role: f.account, address: DASHBOARD, expected: 'fits', seen: notes.length ? notes.join('; ') : 'fits', pass: notes.length === 0,
      screenshot: notes.length ? await t.shot(page, 'table-fit-' + f.account + '-' + f.width) : '' });
    await page.setViewportSize({ width: 1366, height: 768 });
  }
}

// 14. Step UN6c2b: the heading "My approvals (n)" keeps its count through the postbacks of the other cards (a heading
//     without a count was seen once). Per account of approvalsHeadingKept, after each action the heading is the one of
//     approvals (the count does not change: nothing is decided). Last, because opening an alert or an action item
//     marks it read.
async function approvalsHeadingChecks(t, data) {
  for (const account of data.approvalsHeadingKept.accounts) {
    const want = data.approvals[account].title;
    const page = await t.session(account);
    await page.setViewportSize({ width: 1366, height: 768 });
    await t.visit(page, DASHBOARD);
    const title = async () => { const a = await readApprovals(page); return a === 'no panel' ? a : a.title; };
    const closePanel = async () => {
      const button = page.locator('input[type="submit"][value="X"]:visible, input[type="submit"][value="Close"]:visible').first();
      if (await button.count()) await postBack(page, () => button.click());
    };
    const rec = (after, seen) => t.record({ title: 'My approvals heading of ' + account + ' after ' + after + ': the count is shown', role: account, address: DASHBOARD,
      expected: want, seen: String(seen), pass: seen === want });
    rec('opening the Dashboard', await title());
    const steps = [
      ['Alerts: Unread', () => chooseAlertMode(page, 'Unread')],
      ['Alerts: All', () => chooseAlertMode(page, 'All')],
      ['Alerts: Recent', () => chooseAlertMode(page, 'Recent')],
      ['Action Items: Unread', () => chooseActionMode(page, 'Unread')],
      ['Action Items: Show All', () => chooseActionMode(page, 'Show All')],
      ['opening an action item and closing it', async () => {
        const link = page.locator('a[id*="lnkActionItem"]').first();
        if (await link.count()) { await postBack(page, () => link.click()); await closePanel(); }
      }],
      ['opening an alert and closing it', async () => {
        const link = page.locator('a[id*="lnkSource"]').first();
        if (await link.count()) { await postBack(page, () => link.click()); await closePanel(); }
      }],
    ];
    for (const [after, act] of steps) {
      await act();
      const seen = await title();
      rec(after, seen);
      if (seen !== want) await t.shot(page, 'approvals-heading-' + account + '-' + after.replace(/[^A-Za-z]+/g, '-'));
    }
    await t.visit(page, DASHBOARD);
  }
}

// 18. Step FU2a (step 48): a confirmed followup is final on the Dashboard too. Two pages opened before the confirm (a
//     second sign-in of each account, so the stale page stays as it was): the row of one account and the open panel of
//     another. The Controller confirms the item on the Followup page; the card lists it for nobody; the stale row opens
//     read-only with the line and who confirmed it; Submit in the stale panel is refused with the Reason 26 message, the
//     panel stays open read-only with the saved text; the Controller reopens it; the row shows Overdue and Reopened and
//     the panel who reopened it and why. The item is left Pending (with a Confirm and a Reopen history row).
const FOLLOWUP = 'Master/Followup.aspx';

async function postBackOn(page, urlPattern, action) {
  await Promise.all([
    page.waitForResponse((r) => urlPattern.test(r.url()) && r.request().method() === 'POST', { timeout: 30000 }),
    action(),
  ]);
  await settle(page);
}

async function readActionPanel(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const shown = (el) => !!el && el.offsetParent !== null;
    const line = document.querySelector('[id$="pActionItemPanelMessage"]');
    const status = document.querySelector('[id$="pActionItemStatus"]');
    const box = document.querySelector('[id$="ftxtActionText_box"]');
    const errBox = document.querySelector('[id$="divErrLogin"]'); const span = document.querySelector('[id$="spanErrLogin"]');
    return {
      open: !!document.querySelector('input[id$="hdnActionItemId"]'),
      submit: shown(document.querySelector('input[id$="btnActionItemApprove"]')),
      cancel: shown(document.querySelector('input[id$="btnActionItemCancel"]')),
      close: shown(document.querySelector('input[id$="btnActionItemClose"]')),
      line: shown(line) ? txt(line) : '',
      status: shown(status) ? txt(status) : '',
      editable: !!box && box.getAttribute('contenteditable') === 'true',
      text: txt(box),
      pageMessage: !errBox || !span || /divErrorHide/.test(errBox.className) ? '' : txt(span),
    };
  });
}

async function followupFinalChecks(t, data) {
  const f = data.followupFinal;
  const rec = (role, title, expected, seen, address) => {
    const e = JSON.stringify(expected); const s = JSON.stringify(seen);
    t.record({ title, role, address: address || DASHBOARD, expected: e, seen: s, pass: e === s });
  };
  const DATE = '\\d{2}-[A-Z][a-z]{2}-\\d{4} \\d{2}:\\d{2}';
  const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const confirmedBy = new RegExp('^Confirmed by ' + esc(f.controllerName) + ' on ' + DATE + '$');
  const reopenedBy = new RegExp('^Reopened by ' + esc(f.controllerName) + ' on ' + DATE + ': ' + esc(f.reopenReason) + '$');
  const openItem = async (p) => postBack(p, () => p.locator('table[id$="_grvActionItem"] tr', { hasText: f.item }).locator('a[id*="lnkActionItem"]').click());
  const listed = async (p) => { const ai = await readActionItems(p); return ai ? Object.keys(ai.rows).includes(f.item) : 'no card'; };
  const followupRow = (p) => p.locator('table[id$="grvFollowup"] > tbody > tr').filter({ has: p.locator('[id*="lblAgendaNo"]', { hasText: f.item }) });
  const followupMessage = async (p) => p.evaluate(() => {
    const box = document.querySelector('[id$="divErrLogin"]'); const span = document.querySelector('[id$="spanErrLogin"]');
    return !box || !span || /divErrorHide/.test(box.className) ? '' : span.textContent.replace(/\s+/g, ' ').trim();
  });
  const followupView = async (p) => {
    await t.visit(p, FOLLOWUP);
    await postBackOn(p, /followup\.aspx/i, () => p.locator('input[id$="btnViewFollowup"]').click());
  };

  const staleRow = await t.signIn(f.staleRow);
  const stalePanel = await t.signIn(f.stalePanel);
  try {
    // Before the confirm: the row on one page, the open panel on another
    await t.visit(staleRow.page, DASHBOARD);
    rec(f.staleRow, 'Before the confirm: ' + f.item + ' is in the Action Items card of ' + f.staleRow + ' (this page is kept as it is)', true, await listed(staleRow.page));
    await t.visit(stalePanel.page, DASHBOARD);
    await openItem(stalePanel.page);
    let p = await readActionPanel(stalePanel.page);
    const savedText = p.text;
    rec(f.stalePanel, 'Before the confirm: ' + f.stalePanel + ' opens ' + f.item + ': editable, Submit and Cancel, no Close, no line, no status line (never confirmed)',
      { open: true, submit: true, cancel: true, close: false, line: '', status: '', editable: true },
      { open: p.open, submit: p.submit, cancel: p.cancel, close: p.close, line: p.line, status: p.status, editable: p.editable });

    // The Controller confirms the item on the Followup page
    const ctl = await t.session(f.controller);
    await followupView(ctl);
    await followupRow(ctl).locator('select[id*="ddlStatus"]').selectOption('1');
    await postBackOn(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnSubmit"]').click());
    rec(f.controller, 'Followup page: ' + f.controller + ' confirms ' + f.item, f.confirmedOne, await followupMessage(ctl), FOLLOWUP);

    // R20: the card lists it for nobody
    const seenLists = {}; const wantLists = {};
    for (const account of f.listAccounts) {
      const page = await t.session(account);
      await t.visit(page, DASHBOARD);
      wantLists[account] = false; seenLists[account] = await listed(page);
    }
    rec(f.listAccounts.join(', '), 'After the confirm: ' + f.item + ' is in the Action Items card of nobody', wantLists, seenLists);

    // R18, R17: the stale row opens the confirmed item read-only, with the line and who confirmed it
    await openItem(staleRow.page);
    p = await readActionPanel(staleRow.page);
    rec(f.staleRow, 'The stale row of ' + f.staleRow + ' opens the confirmed item: read-only, no Submit, no Cancel, Close, the line "' + f.confirmedLine + '", the status line who confirmed it and when, no page message',
      { open: true, submit: false, cancel: false, close: true, editable: false, line: f.confirmedLine, status: true, pageMessage: '' },
      { open: p.open, submit: p.submit, cancel: p.cancel, close: p.close, editable: p.editable, line: p.line, status: confirmedBy.test(p.status), pageMessage: p.pageMessage });
    if (!confirmedBy.test(p.status)) rec(f.staleRow, 'The status line as shown (for the record)', 'Confirmed by ' + f.controllerName + ' on [date]', p.status);
    rec(f.staleRow, 'After opening it, the item is not in the card of ' + f.staleRow + ' (the list was read again)', false, await listed(staleRow.page));

    // R16: Submit in the panel opened before the confirm: Reason 26, nothing saved, the panel stays open read-only
    await stalePanel.page.locator('[id$="ftxtActionText_box"]').fill(f.typed);
    await postBack(stalePanel.page, () => stalePanel.page.locator('input[id$="btnActionItemApprove"]').click());
    p = await readActionPanel(stalePanel.page);
    rec(f.stalePanel, 'Submit in the panel ' + f.stalePanel + ' opened before the confirm: "' + f.notSaved + '" in the panel; the panel stays open, read-only, Close only; the saved text (not the text typed); who confirmed it; no page message',
      { open: true, submit: false, cancel: false, close: true, editable: false, line: f.notSaved, status: true, text: savedText, typedLost: true, pageMessage: '' },
      { open: p.open, submit: p.submit, cancel: p.cancel, close: p.close, editable: p.editable, line: p.line, status: confirmedBy.test(p.status), text: p.text,
        typedLost: p.text !== f.typed, pageMessage: p.pageMessage });
    rec(f.stalePanel, 'After the refused Submit, the item is not in the card of ' + f.stalePanel + ' (the list was read again)', false, await listed(stalePanel.page));
    await postBack(stalePanel.page, () => stalePanel.page.locator('input[id$="btnActionItemClose"]').click());
    p = await readActionPanel(stalePanel.page);
    rec(f.stalePanel, 'Close: the panel closes, no message', { open: false, pageMessage: '' }, { open: p.open, pageMessage: p.pageMessage });

    // The Controller reopens it on the Followup page
    await followupView(ctl);
    await postBackOn(ctl, /followup\.aspx/i, () => followupRow(ctl).locator('input[id*="btnReopen"]').click());
    await ctl.locator('textarea[id$="txtReopenReason"]').fill(f.reopenReason);
    await postBackOn(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnReopenSave"]').click());
    rec(f.controller, 'Followup page: ' + f.controller + ' reopens ' + f.item, f.reopened, await followupMessage(ctl), FOLLOWUP);

    // R19: the row is back with Overdue and Reopened (orange); another item has no Reopened
    const page = await t.session(f.staleRow);
    await t.visit(page, DASHBOARD);
    const ai = await readActionItems(page);
    const row = ai && ai.rows[f.item];
    const other = ai && ai.rows[f.otherItem];
    rec(f.staleRow, 'After the reopen: ' + f.item + ' is in the card again with "Overdue" and "Reopened" (orange chip); ' + f.otherItem + ' has no "Reopened"',
      { listed: true, overdue: 'Overdue', reopened: 'Reopened', chip: 'wb-chip-orange', other: '' },
      { listed: !!row, overdue: row ? row.overdue : '', reopened: row ? row.reopened : '', chip: row ? row.reopenedChip : '', other: other ? other.reopened : 'row missing' });

    // R17: the panel of the reopened item: editable again, who reopened it and why
    await openItem(page);
    p = await readActionPanel(page);
    rec(f.staleRow, f.staleRow + ' opens the reopened item: editable, Submit and Cancel, no line, the status line who reopened it, when and why',
      { open: true, submit: true, cancel: true, close: false, editable: true, line: '', status: true },
      { open: p.open, submit: p.submit, cancel: p.cancel, close: p.close, editable: p.editable, line: p.line, status: reopenedBy.test(p.status) });
    if (!reopenedBy.test(p.status)) rec(f.staleRow, 'The status line as shown (for the record)', 'Reopened by ' + f.controllerName + ' on [date]: ' + f.reopenReason, p.status);
    await t.visit(page, DASHBOARD);
  } finally {
    await staleRow.context.close().catch(() => null);
    await stalePanel.context.close().catch(() => null);
  }
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

    for (const c of data.cases) await runCase(t, c, data);

    // 12, 13, 15. Step UN6c2b: the summary cards, the filters on every card, the inactive committee (they change no data)
    await summaryChecks(t, data);
    await filterAllCardsChecks(t, data);
    await inactiveCommitteeChecks(t, data);

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
    // 10. Step UN6c2a: the Scheduled list fits its card beside Alerts
    await meetingsFitChecks(t, data);
    // 16. Step UN6c2b: the summary cards at each width
    await summaryWidthChecks(t, data);
    // 17. Step UN6c2b: the Meetings tables fit their card at 960 and 800 px
    await tableFitChecks(t, data);

    // 6. The actions of the Alerts card, last: they change data
    await alertActionChecks(t, data);
    await filterKeptChecks(t, data);
    await actionScopeChecks(t, data);
    await approvalChecks(t, data);
    // 11. Step UN6c2a: the meeting-date message in the Agenda Alert panel (last: opening the item from My approvals
    //     marks qa_manager's own alert of it read)
    await pastItemChecks(t, data);
    // 14. Step UN6c2b: the My approvals heading keeps its count (last: it opens alerts and action items)
    await approvalsHeadingChecks(t, data);
    // 18. Step FU2a: a confirmed followup is final on the Dashboard (last of all: it confirms and reopens a followup)
    await followupFinalChecks(t, data);
  },
};
