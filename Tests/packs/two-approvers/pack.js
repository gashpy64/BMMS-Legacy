'use strict';
/*
  two-approvers - two Managers of one department (step UD1b, database step 53).

  Since step 53 every active Manager of an item's department may approve or reject it at AC. The fixture
  (Tests\fixture) has two Managers of Credit: qa_manager and qa_manager3 (qa_manager3 was also a Manager of HRD until
  the HRD item was saved, then HRD was removed from him by qa_admin). Data (this folder; the rules are in README.md):
    expected.json   the two accounts, the rows of My approvals, the Waiting for me counts, the alerts of the two
                    items waiting at AC, qa_manager3's header count and the number of rows under All, the items whose
                    row of qa_manager3 is handled by qa_manager ('H'), the item whose row is closed because he is no
                    longer a Manager of its department ('N'), and the label of the remove button.

  What it checks
    1. qa_manager and qa_manager3: My approvals has both waiting Credit items (QA1-00001-001, QA1-00002-001); the
       Meetings card's Waiting for me column counts them (meetings QA1 00001 and 00002); both items' alerts are under
       Unread for qa_manager3, and listed under All (not removed, no handled line) for qa_manager (the dashboard pack's
       check 11 opens one of them from his My approvals earlier in the same run, which marks it read).
    2. qa_manager3: the header reads Alerts (4) (the two items and the two committee alerts); no handled row is under
       Recent or Unread.
    3. qa_manager3, under All (every page): the rows of the ten items qa_manager decided are greyed (bmms-row-handled),
       not bold, with the line "Handled by QA Manager (qa_manager) on dd-MMM-yyyy"; the row of QA1-00001-006 is greyed
       with "No longer Manager of the department (dd-MMM-yyyy)"; 15 rows in all.
    4. qa_manager3 opens the QA1-00001-006 row: the Agenda Alert panel shows the same line, no Approve, no Reject; the
       header stays Alerts (4) (the row was read already). "Remove from my list": the row leaves All (14 rows), the
       header stays Alerts (4).

  It does not press Approve or Reject: they send mail, the tester has no mail server, and a failed mail writes to the
  error log, which fails a run. Approve by one Manager and the other's row turning "Handled by ..." is an owner check.

  It writes: qa_manager3's QA1-00001-006 row removed from his list (StatusId 0). The data is the fixture, restored
  before every run.
*/
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const DASHBOARD = 'DashBoard/DashBoard.aspx';
const DATE = '\\d{2}-[A-Z][a-z]{2}-\\d{4}';

function readExpected() {
  let text = fs.readFileSync(path.join(DIR, 'expected.json'), 'utf8');
  if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
  return JSON.parse(text);
}

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

// "Alerts (n)" as the header shows it
async function headerText(page) {
  return page.evaluate(() => {
    const a = Array.from(document.querySelectorAll('.wb-user a')).find((x) => /^Alerts/.test(x.textContent.replace(/\s+/g, ' ').trim()));
    return a ? a.textContent.replace(/\s+/g, ' ').trim() : null;
  });
}

// The rows of the Alerts card on the page shown: the link text, the handled line, greyed, bold; and the pager's numbers
async function readAlertsPage(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const table = document.querySelector('table[id$="_grvAlert"]');
    const trs = table ? Array.from(table.querySelectorAll(':scope > tbody > tr')) : [];
    const rows = trs.filter((tr) => tr.querySelector(':scope > td .wb-dash-alert')).map((tr) => ({
      text: txt(tr.querySelector('a[id*="lnkSource"]')),
      handled: txt(tr.querySelector('.wb-dash-alert-handled')),
      greyed: tr.classList.contains('bmms-row-handled'),
      bold: tr.classList.contains('bmms-row-unread'),
    }));
    const pagerRow = trs.find((tr) => tr.querySelector('table'));
    const pages = pagerRow ? Array.from(pagerRow.querySelectorAll(':scope table td')).map(txt).filter((x) => /^\d+$/.test(x)) : [];
    return { rows, pages };
  });
}

// Every row of the chosen list, page by page
async function readAllAlerts(page) {
  let first = await readAlertsPage(page);
  const rows = first.rows.slice();
  const pages = first.pages.filter((p) => p !== '1');
  for (const p of pages) {
    await postBack(page, () => page.locator('table[id$="_grvAlert"] a', { hasText: new RegExp('^\\s*' + p + '\\s*$') }).first().click());
    const next = await readAlertsPage(page);
    rows.push(...next.rows);
  }
  return rows;
}

async function chooseAlertMode(page, label) {
  await postBack(page, () => page.locator('.wb-dash-alerts .wb-dash-links a', { hasText: new RegExp('^\\s*' + label + '\\s*$') }).click());
}

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
    return { title: txt(card.querySelector('.wb-dash-card-title')), rows };
  });
}

// The Waiting for me column of the Scheduled list: committee | meeting -> count
async function readWaiting(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const table = document.querySelector('table[id$="_grvScheduled"]');
    const waiting = {};
    if (!table) return waiting;
    Array.from(table.querySelectorAll(':scope > tbody > tr')).forEach((tr) => {
      const td = Array.from(tr.querySelectorAll(':scope > td'));
      const cell = td.find((c) => c.classList.contains('wb-dash-waiting'));
      if (td.length && cell && txt(cell)) waiting[txt(td[0].querySelector('.wb-dash-committee')) + ' | ' + txt(td[0].querySelector('.wb-dash-meeting-no'))] = txt(cell);
    });
    return waiting;
  });
}

function sortedObject(o) {
  const r = {};
  Object.keys(o).sort().forEach((k) => { r[k] = o[k]; });
  return r;
}

module.exports = {
  title: 'Two approvers: both Managers of a department see its waiting items; the other Managers\' handled rows',
  async run(t) {
    const data = readExpected();
    const rec = (role, title, expected, seen, extra) => {
      const e = typeof expected === 'string' ? expected : JSON.stringify(expected);
      const s = typeof seen === 'string' ? seen : JSON.stringify(seen);
      t.record(Object.assign({ title, role, address: DASHBOARD, expected: e, seen: s, pass: e === s }, extra || {}));
      return e === s;
    };

    // 1. Both Managers: My approvals, Waiting for me, the alerts of the two waiting items under Unread
    for (const account of data.managers) {
      const page = await t.session(account);
      await t.visit(page, DASHBOARD);
      const a = await readApprovals(page);
      rec(account, 'My approvals of ' + account + ': both waiting Credit items (item | committee | meeting | department)',
        data.approvals, a === 'no panel' ? a : { title: a.title, rows: a.rows });
      rec(account, 'Waiting for me of ' + account + ': one item in QA1 00001 and one in QA1 00002',
        sortedObject(data.waiting), sortedObject(await readWaiting(page)));
      if (account === data.second) {
        await chooseAlertMode(page, 'Unread');
        const unread = (await readAllAlerts(page)).map((r) => r.text);
        rec(account, 'Unread alerts of ' + account + ': the alerts of both waiting items are there',
          data.waitingAlerts, data.waitingAlerts.filter((x) => unread.includes(x)));
      } else {
        // The dashboard pack (its check 11, step UN6c2a / M6a) opens QA1-00001-001 from qa_manager's My approvals in the
        // same run, which marks his alert of it read; so for him the alerts are looked for under All (owner 2026-11-23)
        await chooseAlertMode(page, 'All');
        const rows = await readAllAlerts(page);
        rec(account, 'Alerts of ' + account + ' under All: the alerts of both waiting items are listed (not removed), with no handled line',
          data.waitingAlerts.map((x) => ({ alert: x, listed: true, handledLine: '' })),
          data.waitingAlerts.map((x) => { const r = rows.find((y) => y.text === x); return { alert: x, listed: !!r, handledLine: r ? r.handled : '' }; }));
      }
      await t.visit(page, DASHBOARD);
    }

    // 2. qa_manager3: the header; no handled row under Recent or Unread
    const who = data.second;
    const page = await t.session(who);
    await t.visit(page, DASHBOARD);
    rec(who, 'The header of ' + who + ' counts his unread alerts only (the handled rows are read and not counted)', data.secondHeader, String(await headerText(page)));
    const marked = data.handledItems.concat([data.noLongerItem]);
    for (const mode of ['Recent', 'Unread']) {
      await chooseAlertMode(page, mode);
      const rows = await readAllAlerts(page);
      rec(who, mode + ' of ' + who + ': no handled row (no handled line, none of the handled items)',
        { handledLines: 0, handledItems: [] },
        { handledLines: rows.filter((r) => r.handled !== '').length, handledItems: rows.map((r) => r.text).filter((x) => marked.includes(x)) });
    }

    // 3. Under All, every page: the handled rows greyed, not bold, with their line in words
    await chooseAlertMode(page, 'All');
    const allShot = await t.shot(page, 'two-approvers-all-page-1');
    let all = await readAllAlerts(page);
    rec(who, 'All of ' + who + ': every row of the list (the screenshot is page 1, for the greyed rows by eye)', data.allRows, all.length,
      { detail: all.map((r) => r.text + (r.handled ? ' [' + r.handled + ']' : '')).join('; '), screenshot: allShot });
    const handledLine = new RegExp('^Handled by ' + data.handledBy.replace(/[()]/g, '\\$&') + ' on ' + DATE + '$');
    const handledSeen = all.filter((r) => data.handledItems.includes(r.text));
    rec(who, 'All of ' + who + ': the rows of the items qa_manager decided: greyed, not bold, "Handled by ' + data.handledBy + ' on dd-MMM-yyyy"',
      { items: data.handledItems.slice().sort(), greyed: true, bold: false, line: true },
      { items: handledSeen.map((r) => r.text).sort(), greyed: handledSeen.every((r) => r.greyed), bold: handledSeen.some((r) => r.bold),
        line: handledSeen.length > 0 && handledSeen.every((r) => handledLine.test(r.handled)) },
      { detail: handledSeen.map((r) => r.text + ': ' + r.handled).join('; ') });
    const n = all.find((r) => r.text === data.noLongerItem);
    const nLine = new RegExp('^No longer Manager of the department \\(' + DATE + '\\)$');
    rec(who, 'All of ' + who + ': the row of ' + data.noLongerItem + ': greyed, not bold, "No longer Manager of the department (dd-MMM-yyyy)"',
      { found: true, greyed: true, bold: false, line: true },
      n ? { found: true, greyed: n.greyed, bold: n.bold, line: nLine.test(n.handled) } : { found: false, greyed: false, bold: false, line: false },
      { detail: n ? n.handled : 'row not found' });
    const others = all.filter((r) => !marked.includes(r.text));
    rec(who, 'All of ' + who + ': the other rows have no handled line and are not greyed', { handledLines: 0, greyed: 0 },
      { handledLines: others.filter((r) => r.handled !== '').length, greyed: others.filter((r) => r.greyed).length },
      { detail: 'rows with a handled line or greyed: ' + (others.filter((r) => r.handled !== '' || r.greyed).map((r) => r.text).join('; ') || 'none') });

    // 4. Opening the N row: the same line in the panel, no Approve or Reject; then Remove from my list
    await t.visit(page, DASHBOARD);
    await chooseAlertMode(page, 'All');
    let opened = false;
    for (let guard = 0; guard < 5 && !opened; guard += 1) {
      const link = page.locator('table[id$="_grvAlert"] a[id*="lnkSource"]', { hasText: data.noLongerItem });
      if (await link.count()) {
        await postBack(page, () => link.first().click());
        opened = true;
      } else {
        const p = await readAlertsPage(page);
        const next = p.pages.find((x) => Number(x) > guard + 1);
        if (!next) break;
        await postBack(page, () => page.locator('table[id$="_grvAlert"] a', { hasText: new RegExp('^\\s*' + next + '\\s*$') }).first().click());
      }
    }
    const panel = await page.evaluate(() => {
      const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
      const shown = (sel) => { const el = document.querySelector(sel); return !!el && el.offsetParent !== null; };
      return { message: txt(document.querySelector('[id$="pAgendaPanelMessage"]')), approve: shown('input[id$="btnApprove"]'), reject: shown('input[id$="btnReject"]'),
        remove: (document.querySelector('input[id$="btnDeleteAgendaAlert"]') || {}).value || '' };
    });
    rec(who, who + ' opens the ' + data.noLongerItem + ' row: the panel shows the same line, no Approve, no Reject, "' + data.removeButton + '"; the header unchanged',
      { opened: true, line: true, approve: false, reject: false, remove: data.removeButton, header: data.secondHeader },
      { opened, line: new RegExp('No longer Manager of the department \\(' + DATE + '\\)').test(panel.message), approve: panel.approve, reject: panel.reject,
        remove: panel.remove, header: String(await headerText(page)) },
      { detail: panel.message, screenshot: await t.shot(page, 'two-approvers-no-longer-manager') });
    if (opened) {
      await postBack(page, () => page.locator('input[id$="btnDeleteAgendaAlert"]').click());
      await t.visit(page, DASHBOARD);
      await chooseAlertMode(page, 'All');
      all = await readAllAlerts(page);
      rec(who, 'Remove from my list on the ' + data.noLongerItem + ' row: it leaves All; the header unchanged',
        { rows: data.allRows - 1, found: false, header: data.secondHeader },
        { rows: all.length, found: all.some((r) => r.text === data.noLongerItem), header: String(await headerText(page)) });
    }
    await t.visit(page, DASHBOARD);
  },
};
