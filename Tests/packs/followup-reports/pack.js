'use strict';
/*
  followup-reports - the Followup reports show who confirmed or reopened each followup (step FU2b, database step 49).

  Data (this folder; the rules are in README.md):
    expected.json   the accounts, the committee, the row the Controller confirms (confirmRow) and the row he confirms
                    and reopens (reopenRow, with its meeting number and the reason typed), the name the pages show for
                    the Controller, the labels of the Confirmed Status choice, and the messages of the Followup page.

  What it checks
    1. Set-up on the Followup page (qa_ctrl): confirmRow and reopenRow confirmed in one Submit, then reopenRow
       reopened with the reason (the reason has & and quotes and "<5", which the page lets through).
    2. Followup (fc=followup), qa_ctrl: the Confirmed Status choices Both / Confirmed / Pending; View: a "Followup status" column
       and no Minutes status column; confirmRow "Confirmed" with "Confirmed by [name] on [dd-MMM-yyyy HH:mm]";
       reopenRow "Pending" with "Reopened by [name] on [date]: [reason]" (the reason as typed, shown as text);
       Pending chosen: reopenRow listed, confirmRow not, every row "Pending". Generate: the report (ViewReport.aspx)
       has a FOLLOWUP STATUS block for every row of View and the same two lines.
    3. Followup Summary (fc=summary), qa_ctrl: View shows the word only (no line); Generate: a "Followup status"
       column with only "Pending" and "Confirmed", both present, and no "Reopened by" anywhere.
    4. Followup (fc=followup), qa_mgmt: View has the "Followup status" column and the Minutes status column, and reopenRow's
       reopen line; Generate: the FOLLOWUP STATUS blocks and the minutes status lines.
    5. Followup by Department, qa_ctrl: the meeting of reopenRow, every department; View has a "Followup status" column with
       reopenRow's word and reopen line; Print and Generate Report: the report has the word and the line.

  It changes data: two Confirms and a Reopen (reopenRow ends Pending, confirmRow Confirmed). The data is the fixture
  (Tests\fixture), restored and dated afresh before every run. Run after the followup pack: its rows are other rows.
*/
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const FOLLOWUP = 'Master/Followup.aspx';
const REPORT = 'Report/Followup.aspx';
const DEPARTMENT = 'Report/FollowupActionTaken.aspx';
const VIEWREPORT = 'Report/ViewReport.aspx';
const DATE = '\\d{2}-[A-Z][a-z]{2}-\\d{4} \\d{2}:\\d{2}';

function readExpected() {
  let text = fs.readFileSync(path.join(DIR, 'expected.json'), 'utf8');
  if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
  return JSON.parse(text);
}

async function settle(page) {
  await page.waitForFunction(() => !(window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager
    && Sys.WebForms.PageRequestManager.getInstance().get_isInAsyncPostBack()), null, { timeout: 30000 });
}

async function postBack(page, pattern, action) {
  await Promise.all([
    page.waitForResponse((r) => pattern.test(r.url()) && r.request().method() === 'POST', { timeout: 30000 }),
    action(),
  ]);
  await settle(page);
}

const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// The message box of a page
async function message(page) {
  return page.evaluate(() => {
    const box = document.querySelector('[id$="divErrLogin"]'); const span = document.querySelector('[id$="spanErrLogin"]');
    return !box || !span || /divErrorHide/.test(box.className) ? '' : span.textContent.replace(/\s+/g, ' ').trim();
  });
}

// A report grid (grvFollowup): the header texts and, per agenda number, the status word and line of the column headed
// statusHeader (expected.json, "Followup status")
async function readGrid(page, statusHeader) {
  return page.evaluate((statusHeader) => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const table = document.querySelector('table[id$="grvFollowup"]');
    if (!table) return { present: false, head: [], rows: {}, count: 0 };
    const trs = Array.from(table.querySelectorAll(':scope > tbody > tr'));
    const head = trs.length ? Array.from(trs[0].querySelectorAll(':scope > th')).map(txt) : [];
    const no = head.indexOf('Agenda No'); const st = head.indexOf(statusHeader);
    const rows = {}; let count = 0;
    trs.slice(1).forEach((tr) => {
      const td = Array.from(tr.querySelectorAll(':scope > td'));
      if (no < 0 || !td[no]) return;
      count++;
      const cell = st >= 0 ? td[st] : null;
      rows[txt(td[no])] = { word: txt(cell && cell.querySelector('.wb-followup-status')), line: txt(cell && cell.querySelector('.wb-followup-status-line')) };
    });
    return { present: true, head, rows, count };
  }, statusHeader);
}

// The report the page stored for ViewReport.aspx, read in a new window of the same session
async function readReport(t, page) {
  const context = page.context();
  const before = new Set(context.pages());
  const report = await context.newPage();
  try {
    await t.visit(report, VIEWREPORT);
    return await report.evaluate(() => {
      const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
      const text = document.body ? document.body.innerText.replace(/\s+/g, ' ') : '';
      // The Followup status column of the Summary's tables (the header row is the first row with that text)
      const values = [];
      document.querySelectorAll('table').forEach((table) => {
        const trs = Array.from(table.querySelectorAll('tr'));
        if (!trs.length) return;
        const head = Array.from(trs[0].querySelectorAll('td, th')).map(txt);
        const at = head.indexOf('Followup status');
        if (at < 0) return;
        trs.slice(1).forEach((tr) => { const c = tr.querySelectorAll('td, th')[at]; if (c) values.push(txt(c)); });
      });
      return { text, values };
    });
  } finally {
    await report.close().catch(() => null);
    // The popup that Generate opens by itself is closed too
    for (const p of context.pages()) if (!before.has(p) && p !== page) await p.close().catch(() => null);
  }
}

async function chooseCommittee(page, committee) {
  const value = await page.locator('select[id$="ddlCommittee"] option', { hasText: committee }).first().getAttribute('value');
  await postBack(page, /\.aspx/i, () => page.locator('select[id$="ddlCommittee"]').selectOption(value));
}

module.exports = {
  title: 'Followup reports: who confirmed or reopened each followup (Followup, Followup Summary, Followup by Department)',
  async run(t) {
    const data = readExpected();
    const rec = (role, title, expected, seen, address) => {
      const e = JSON.stringify(expected); const s = JSON.stringify(seen);
      t.record({ title, role, address: address || REPORT, expected: e, seen: s, pass: e === s });
    };
    const confirmedLine = new RegExp('^Confirmed by ' + esc(data.controllerName) + ' on ' + DATE + '$');
    const reopenedLine = new RegExp('^Reopened by ' + esc(data.controllerName) + ' on ' + DATE + ': ' + esc(data.reopenReason) + '$');
    const confirmedIn = new RegExp('Confirmed by ' + esc(data.controllerName) + ' on ' + DATE);
    const reopenedIn = new RegExp('Reopened by ' + esc(data.controllerName) + ' on ' + DATE + ': ' + esc(data.reopenReason));
    const count = (text, word) => text.split(word).length - 1;

    // 1. Set-up on the Followup page
    const ctl = await t.session(data.controller);
    {
      await t.visit(ctl, FOLLOWUP);
      await postBack(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnViewFollowup"]').click());
      const row = (no) => ctl.locator('table[id$="grvFollowup"] > tbody > tr').filter({ has: ctl.locator('[id*="lblAgendaNo"]', { hasText: no }) });
      await row(data.confirmRow).locator('select[id*="ddlStatus"]').selectOption('1');
      await row(data.reopenRow).locator('select[id*="ddlStatus"]').selectOption('1');
      await postBack(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnSubmit"]').click());
      rec(data.controller, 'Set-up, Followup page: ' + data.confirmRow + ' and ' + data.reopenRow + ' confirmed in one Submit', data.confirmedTwo, await message(ctl), FOLLOWUP);
      await postBack(ctl, /followup\.aspx/i, () => row(data.reopenRow).locator('input[id*="btnReopen"]').click());
      await ctl.locator('textarea[id$="txtReopenReason"]').fill(data.reopenReason);
      await postBack(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnReopenSave"]').click());
      rec(data.controller, 'Set-up, Followup page: ' + data.reopenRow + ' reopened with the reason', data.reopened, await message(ctl), FOLLOWUP);
    }

    // 2. Followup, the Controller
    let viewCount = 0;
    {
      const opened = await t.visit(ctl, REPORT + '?fc=followup');
      rec(data.controller, 'Followup report opens', 'opens', opened.kind);
      const labels = await ctl.evaluate(() => Array.from(document.querySelectorAll('[id$="rdoConfirmStatus"] label')).map((l) => l.textContent.trim()));
      rec(data.controller, 'Confirmed Status choices: Both, Confirmed, Pending ("Not Confirmed" is "Pending")', data.confirmLabels, labels);
      await chooseCommittee(ctl, data.committee);
      await postBack(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnViewFollowup"]').click());
      let g = await readGrid(ctl, data.statusHeader);
      viewCount = g.count;
      const c = g.rows[data.confirmRow] || {}; const r = g.rows[data.reopenRow] || {};
      rec(data.controller, 'View: a "' + data.statusHeader + '" column, no Minutes status column; ' + data.confirmRow + ' Confirmed with who and when; ' + data.reopenRow + ' Pending with the reopen line (the reason as typed)',
        { status: true, minutes: false, confirmWord: 'Confirmed', confirmLine: true, reopenWord: 'Pending', reopenLine: true },
        { status: g.head.includes(data.statusHeader), minutes: g.head.includes('Minutes status'), confirmWord: c.word || '', confirmLine: confirmedLine.test(c.line || ''),
          reopenWord: r.word || '', reopenLine: reopenedLine.test(r.line || '') });
      if (!reopenedLine.test(r.line || '')) rec(data.controller, 'The reopen line as shown (for the record)', 'Reopened by ' + data.controllerName + ' on [date]: ' + data.reopenReason, r.line || '');

      await ctl.locator('input[id*="rdoConfirmStatus"][value="0"]').check();
      await postBack(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnViewFollowup"]').click());
      g = await readGrid(ctl, data.statusHeader);
      rec(data.controller, 'Pending chosen, View: ' + data.reopenRow + ' listed, ' + data.confirmRow + ' not, every row "Pending"',
        { reopen: true, confirm: false, allPending: true },
        { reopen: !!g.rows[data.reopenRow], confirm: !!g.rows[data.confirmRow], allPending: g.count > 0 && Object.values(g.rows).every((x) => x.word === 'Pending') });
      await ctl.locator('input[id*="rdoConfirmStatus"][value="-1"]').check();

      await postBack(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnGenerateReport"]').click());
      const rep = await readReport(t, ctl);
      rec(data.controller, 'Generate: a FOLLOWUP STATUS block for every row of View, the Confirm line and the reopen line (the reason as text)',
        { blocks: viewCount, confirmed: true, reopened: true },
        { blocks: count(rep.text, 'FOLLOWUP STATUS'), confirmed: confirmedIn.test(rep.text), reopened: reopenedIn.test(rep.text) }, VIEWREPORT);
    }

    // 3. Followup Summary, the Controller
    {
      await t.visit(ctl, REPORT + '?fc=summary');
      await chooseCommittee(ctl, data.committee);
      await postBack(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnViewFollowup"]').click());
      const g = await readGrid(ctl, data.statusHeader);
      const c = g.rows[data.confirmRow] || {}; const r = g.rows[data.reopenRow] || {};
      rec(data.controller, 'Summary, View: the word only, no line (' + data.confirmRow + ' Confirmed, ' + data.reopenRow + ' Pending)',
        { confirm: 'Confirmed', reopen: 'Pending', lines: 0 },
        { confirm: c.word || '', reopen: r.word || '', lines: Object.values(g.rows).filter((x) => x.line !== '').length });
      await postBack(ctl, /followup\.aspx/i, () => ctl.locator('input[id$="btnGenerateReport"]').click());
      const rep = await readReport(t, ctl);
      const kinds = Array.from(new Set(rep.values)).sort();
      rec(data.controller, 'Summary, Generate: a "Followup status" column with Pending and Confirmed only (one per row of View), no "Reopened by", no "FOLLOWUP STATUS"',
        { values: ['Confirmed', 'Pending'], cells: g.count, reopened: false, blocks: 0 },
        { values: kinds, cells: rep.values.length, reopened: /Reopened by/.test(rep.text), blocks: count(rep.text, 'FOLLOWUP STATUS') }, VIEWREPORT);
    }

    // 4. Followup, Management
    {
      const mg = await t.session(data.management);
      await t.visit(mg, REPORT + '?fc=followup');
      await chooseCommittee(mg, data.committee);
      await postBack(mg, /followup\.aspx/i, () => mg.locator('input[id$="btnViewFollowup"]').click());
      const g = await readGrid(mg, data.statusHeader);
      const r = g.rows[data.reopenRow] || {};
      rec(data.management, 'Management, View: the "' + data.statusHeader + '" column and the Minutes status column; ' + data.reopenRow + ' Pending with the reopen line',
        { status: true, minutes: true, word: 'Pending', line: true, rows: viewCount },
        { status: g.head.includes(data.statusHeader), minutes: g.head.includes('Minutes status'), word: r.word || '', line: reopenedLine.test(r.line || ''), rows: g.count });
      await postBack(mg, /followup\.aspx/i, () => mg.locator('input[id$="btnGenerateReport"]').click());
      const rep = await readReport(t, mg);
      rec(data.management, 'Management, Generate: a FOLLOWUP STATUS block and a minutes status line for every row, the reopen line',
        { blocks: viewCount, minutes: viewCount, reopened: true },
        { blocks: count(rep.text, 'FOLLOWUP STATUS'), minutes: count(rep.text, 'Minutes status:'), reopened: reopenedIn.test(rep.text) }, VIEWREPORT);
    }

    // 5. Followup by Department, the Controller
    {
      const opened = await t.visit(ctl, DEPARTMENT);
      rec(data.controller, 'Followup by Department opens', 'opens', opened.kind, DEPARTMENT);
      await chooseCommittee(ctl, data.committee);
      const meeting = await ctl.evaluate((no) => {
        const s = document.querySelector('select[id$="ddlMeetingNoFrom"]');
        const o = s ? Array.from(s.options).find((x) => parseInt(x.text.trim(), 10) === no) : null;
        return o ? o.value : '';
      }, data.reopenMeetingNo);
      await postBack(ctl, /followupactiontaken\.aspx/i, () => ctl.locator('select[id$="ddlMeetingNoFrom"]').selectOption(meeting));
      await postBack(ctl, /followupactiontaken\.aspx/i, () => ctl.locator('input[id$="btnSubmit"]').click());
      const g = await readGrid(ctl, data.statusHeader);
      const r = g.rows[data.reopenRow] || {};
      rec(data.controller, 'Followup by Department, View (meeting ' + data.reopenMeetingNo + ', every department): a "' + data.statusHeader + '" column; ' + data.reopenRow + ' Pending with the reopen line; no message',
        { status: true, word: 'Pending', line: true, message: '' },
        { status: g.head.includes(data.statusHeader), word: r.word || '', line: reopenedLine.test(r.line || ''), message: await message(ctl) }, DEPARTMENT);
      await postBack(ctl, /followupactiontaken\.aspx/i, () => ctl.locator('input[id*="rdoViewFormat"][value="Print"]').check());
      await postBack(ctl, /followupactiontaken\.aspx/i, () => ctl.locator('input[id$="btnSubmit"]').click());
      await postBack(ctl, /followupactiontaken\.aspx/i, () => ctl.locator('input[id$="btnCreatePDF"]').click());
      const rep = await readReport(t, ctl);
      rec(data.controller, 'Followup by Department, Generate Report: the word and the reopen line of ' + data.reopenRow + ' in the report',
        { pending: true, reopened: true },
        { pending: /Pending/.test(rep.text), reopened: reopenedIn.test(rep.text) }, VIEWREPORT);
    }
  },
};
