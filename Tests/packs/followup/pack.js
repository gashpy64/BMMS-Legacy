'use strict';
/*
  followup - the Followup page (Master/Followup.aspx) by role (steps UN6d and FU1).

  Data (this folder; the rules are in README.md):
    expected.json   the accounts, the rows the list shows with the default filters (all committees, all
                    departments, Both), the row the Controller confirms and reopens, the name shown for the
                    Controller, and the texts of the lines and messages.

  What it checks (step FU1: a confirmed followup is final; Reopen with a reason)
    1. The Controller (qa_ctrl):
       - View: every row Pending with the Status drop-down (Pending chosen), no Reopen, "Edit" on each row, the
         Submit button, no read-only line.
       - The action text of a row: ":: Edit Action Text", Save and Cancel; Save unchanged: "The action text was
         saved." as a success.
       - Submit with no row changed: "No followup was changed to Confirmed. Nothing was saved."; every row still
         Pending.
       - Confirmed chosen on one row, Submit: "1 followup was confirmed." as a success; that row: "Confirmed",
         "Confirmed by QA Controller (qa_ctrl) on dd-MMM-yyyy HH:mm", no drop-down, Reopen, "View"; the other
         rows as before.
       - The action text of the confirmed row: ":: View Action Text", no Save, Close, the line that it is
         confirmed.
       - Filter Confirmed: only that row, and no Submit (no Pending row).
       - Reopen: ":: Reopen Followup" with the item; Save with no reason: "Enter the reason for reopening." in
         the panel; a reason with "<b": the browser's message about "<" and "&#" (reopenCheck) in the panel, nothing sent; a reason
         with & and quotes: "The followup was reopened." as a success; the row Pending again with the drop-down,
         "Reopened by QA Controller (qa_ctrl) on [date]: [reason]" (the text exactly as typed), "Edit", no
         Reopen.
    2. The MD Secretariat (qa_mdsec), after the Controller: every row, the read-only line, no Submit, no
       drop-down and no Reopen anywhere, "View" on each row, every row "Pending", the reopened row with its
       reopen line; the action text: ":: View Action Text", no Save, Close, the read-only line; Close.

  A post forged for the MD Secretariat (a Save, Submit or Reopen the page does not render) cannot be sent:
  ASP.NET's event validation refuses it before the page runs, and that writes the error log. The server's
  refusal of every role but the Controller is proven by BMMS-Test-FollowupFinal-Step47.sql.

  It writes: the Controller's Save of the action text (unchanged), the Confirm of one row and its Reopen, so the
  row ends as the fixture has it (not confirmed) with two history rows; the data is the fixture (Tests\fixture),
  restored and dated afresh before every run.
*/
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const FOLLOWUP = 'Master/Followup.aspx';
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

async function postBack(page, action) {
  await Promise.all([
    page.waitForResponse((r) => /followup\.aspx/i.test(r.url()) && r.request().method() === 'POST', { timeout: 30000 }),
    action(),
  ]);
  await settle(page);
}

// What the page shows: the list, the line above it, Submit, the message box, the Action Text and Reopen panels
async function readPage(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const shown = (el) => !!el && el.offsetParent !== null;
    const grid = document.querySelector('table[id$="grvFollowup"]');
    const rows = grid ? Array.from(grid.querySelectorAll(':scope > tbody > tr')).filter((tr) => tr.querySelector('[id*="lblAgendaNo"]')) : [];
    const list = rows.map((tr) => {
      const no = tr.querySelector('[id*="lblAgendaNo"]');
      const ddl = tr.querySelector('select[id*="ddlStatus"]');
      const reopen = tr.querySelector('input[id*="btnReopen"]');
      const btn = tr.querySelector('input[id*="btnActionText"]');
      const word = tr.querySelector('.wb-followup-status');
      const line = tr.querySelector('.wb-followup-status-line');
      return {
        agendaNo: txt(no),
        ddl: ddl ? ddl.value : '',
        reopen: !!reopen,
        button: btn ? btn.value : '',
        word: txt(word),
        line: txt(line),
      };
    });
    const line = document.querySelector('[id$="pFollowupReadOnly"]');
    const box = document.querySelector('[id$="divErrLogin"]');
    const span = document.querySelector('[id$="spanErrLogin"]');
    const panel = document.querySelector('[id$="pnlActionText"]');
    const panelLine = document.querySelector('[id$="pActionTextPanelMessage"]');
    const save = document.querySelector('input[id$="btnActionTextSave"]');
    const cancel = document.querySelector('input[id$="btnActionTextCancel"]');
    const reopenPanel = document.querySelector('[id$="pnlReopen"]');
    const reopenItem = document.querySelector('[id$="pReopenItem"]');
    const reopenLine = document.querySelector('[id$="pReopenPanelMessage"]');
    const reopenCheck = document.getElementById('pReopenCheck');
    return {
      list,
      line: shown(line) ? txt(line) : '',
      submit: shown(document.querySelector('input[id$="btnSubmit"]')),
      message: !box || /divErrorHide/.test(box.className) ? '' : txt(span),
      kind: !box || /divErrorHide/.test(box.className) ? 'none' : (/msg-success/.test(box.className) ? 'success' : 'warning'),
      panel: !!panel && !!cancel,
      title: panel ? txt(panel.querySelector('.divHeader')) : '',
      save: shown(save),
      cancel: cancel ? cancel.value : '',
      panelLine: shown(panelLine) ? txt(panelLine) : '',
      reopenPanel: !!reopenPanel && !!document.querySelector('input[id$="btnReopenSave"]'),
      reopenTitle: reopenPanel ? txt(reopenPanel.querySelector('.divHeader')) : '',
      reopenItem: txt(reopenItem),
      reopenLine: shown(reopenLine) ? txt(reopenLine) : '',
      reopenCheck: shown(reopenCheck) ? txt(reopenCheck) : '',
    };
  });
}

const sorted = (list) => list.map((r) => r.agendaNo).sort();
const rowOf = (p, no) => p.list.find((r) => r.agendaNo === no) || {};
const others = (p, no) => p.list.filter((r) => r.agendaNo !== no);
const rowLocator = (page, no) => page.locator('table[id$="grvFollowup"] > tbody > tr')
  .filter({ has: page.locator('[id*="lblAgendaNo"]', { hasText: no }) });

module.exports = {
  title: 'Followup: the Controller confirms and reopens, the MD Secretariat reads only',
  async run(t) {
    const data = readExpected();
    const rec = (role, title, expected, seen) => {
      const e = JSON.stringify(expected); const s = JSON.stringify(seen);
      t.record({ title, role, address: FOLLOWUP, expected: e, seen: s, pass: e === s });
    };
    const wantRows = data.rows.slice().sort();
    const target = data.confirmRow;
    const confirmedLine = new RegExp('^Confirmed by ' + data.saveAccountName.replace(/[()]/g, '\\$&') + ' on ' + DATE + '$');
    const reopenedLine = (reason) => new RegExp('^Reopened by ' + data.saveAccountName.replace(/[()]/g, '\\$&') + ' on ' + DATE
      + ': ' + reason.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$');
    const pendingCtl = (r) => r.ddl === '0' && !r.reopen && r.button === 'Edit' && r.word === '';

    // 1. The Controller
    {
      const role = data.saveAccount;
      const page = await t.session(role);
      const opened = await t.visit(page, FOLLOWUP);
      rec(role, role + ' opens the Followup page', 'opens', opened.kind);
      await postBack(page, () => page.locator('input[id$="btnViewFollowup"]').click());
      let p = await readPage(page);
      rec(role, 'View as ' + role + ': every row Pending with the drop-down (Pending), no Reopen, "Edit", Submit, no read-only line',
        { rows: wantRows, line: '', submit: true, pending: wantRows.length },
        { rows: sorted(p.list), line: p.line, submit: p.submit, pending: p.list.filter(pendingCtl).length });

      if (p.list.length) {
        await postBack(page, () => rowLocator(page, target).locator('input[id*="btnActionText"]').click());
        p = await readPage(page);
        rec(role, role + ' opens the action text of a Pending row: ":: Edit Action Text", Save and Cancel, no line in the panel',
          { panel: true, title: ':: Edit Action Text', save: true, cancel: 'Cancel', panelLine: '' },
          { panel: p.panel, title: p.title, save: p.save, cancel: p.cancel, panelLine: p.panelLine });
        await postBack(page, () => page.locator('input[id$="btnActionTextSave"]').click());
        p = await readPage(page);
        rec(role, 'Save with the text unchanged: the panel closes, "' + data.actionTextSaved + '" as a success',
          { panel: false, message: data.actionTextSaved, kind: 'success' }, { panel: p.panel, message: p.message, kind: p.kind });
      }

      // Submit with no row changed: nothing is sent
      await postBack(page, () => page.locator('input[id$="btnSubmit"]').click());
      p = await readPage(page);
      rec(role, 'Submit with no row changed: "' + data.nothingChanged + '", every row still Pending',
        { message: data.nothingChanged, kind: 'warning', pending: wantRows.length },
        { message: p.message, kind: p.kind, pending: p.list.filter(pendingCtl).length });

      // Confirm one row
      await rowLocator(page, target).locator('select[id*="ddlStatus"]').selectOption('1');
      await postBack(page, () => page.locator('input[id$="btnSubmit"]').click());
      p = await readPage(page);
      let r = rowOf(p, target);
      rec(role, 'Confirmed chosen on ' + target + ', Submit: "' + data.confirmedOne + '" as a success; the row Confirmed with who and when, no drop-down, Reopen, "View"; the other rows Pending',
        { message: data.confirmedOne, kind: 'success', word: 'Confirmed', line: true, ddl: '', reopen: true, button: 'View', othersPending: wantRows.length - 1 },
        { message: p.message, kind: p.kind, word: r.word, line: confirmedLine.test(r.line || ''), ddl: r.ddl, reopen: r.reopen, button: r.button,
          othersPending: others(p, target).filter(pendingCtl).length });
      if (!confirmedLine.test(r.line || '')) rec(role, 'The confirmed line as shown (for the record)', 'Confirmed by ' + data.saveAccountName + ' on [date]', r.line);

      // The action text of the confirmed row is View for the Controller too
      await postBack(page, () => rowLocator(page, target).locator('input[id*="btnActionText"]').click());
      p = await readPage(page);
      rec(role, role + ' opens the action text of the confirmed row: ":: View Action Text", no Save, Close, the confirmed line in the panel',
        { panel: true, title: ':: View Action Text', save: false, cancel: 'Close', panelLine: data.confirmedReadLine },
        { panel: p.panel, title: p.title, save: p.save, cancel: p.cancel, panelLine: p.panelLine });
      await postBack(page, () => page.locator('input[id$="btnActionTextCancel"]').click());

      // Only confirmed rows: no Submit
      await page.locator('input[id*="rdoConfirmStatus"][value="1"]').check();
      await postBack(page, () => page.locator('input[id$="btnViewFollowup"]').click());
      p = await readPage(page);
      rec(role, 'Filter Confirmed, View: only ' + target + ', no Submit (no Pending row)',
        { rows: [target], submit: false }, { rows: sorted(p.list), submit: p.submit });
      await page.locator('input[id*="rdoConfirmStatus"][value="-1"]').check();
      await postBack(page, () => page.locator('input[id$="btnViewFollowup"]').click());

      // Reopen
      await postBack(page, () => rowLocator(page, target).locator('input[id*="btnReopen"]').click());
      p = await readPage(page);
      rec(role, 'Reopen on ' + target + ': the panel "' + data.reopenTitle + '" names the item, no line',
        { reopenPanel: true, title: data.reopenTitle, item: true, line: '' },
        { reopenPanel: p.reopenPanel, title: p.reopenTitle, item: p.reopenItem.indexOf(target) >= 0, line: p.reopenLine });
      await postBack(page, () => page.locator('input[id$="btnReopenSave"]').click());
      p = await readPage(page);
      rec(role, 'Reopen Save with no reason: "' + data.reopenBlank + '" in the panel, the panel stays, the row still Confirmed',
        { reopenPanel: true, line: data.reopenBlank, word: 'Confirmed' },
        { reopenPanel: p.reopenPanel, line: p.reopenLine, word: rowOf(p, target).word });
      await page.locator('textarea[id$="txtReopenReason"]').fill('QA <b>bold</b>');
      await page.locator('input[id$="btnReopenSave"]').click();
      p = await readPage(page);
      rec(role, 'Reopen Save with "<b" in the reason: "' + data.reopenCheck + '" in the panel, nothing sent, the panel stays',
        { reopenPanel: true, check: data.reopenCheck }, { reopenPanel: p.reopenPanel, check: p.reopenCheck });
      await page.locator('textarea[id$="txtReopenReason"]').fill('  ' + data.reopenReason + '  ');
      await postBack(page, () => page.locator('input[id$="btnReopenSave"]').click());
      p = await readPage(page);
      r = rowOf(p, target);
      rec(role, 'Reopen Save with a reason: "' + data.reopened + '" as a success, the panel closed; the row Pending with the drop-down, the reopen line with the reason as typed (trimmed), "Edit", no Reopen',
        { message: data.reopened, kind: 'success', reopenPanel: false, ddl: '0', line: true, button: 'Edit', reopen: false },
        { message: p.message, kind: p.kind, reopenPanel: p.reopenPanel, ddl: r.ddl, line: reopenedLine(data.reopenReason).test(r.line || ''),
          button: r.button, reopen: r.reopen });
      if (!reopenedLine(data.reopenReason).test(r.line || '')) rec(role, 'The reopen line as shown (for the record)', 'Reopened by ' + data.saveAccountName + ' on [date]: ' + data.reopenReason, r.line);
      await t.visit(page, 'DashBoard/DashBoard.aspx');
    }

    // 2. The MD Secretariat
    {
      const role = data.readOnlyAccount;
      const page = await t.session(role);
      const opened = await t.visit(page, FOLLOWUP);
      rec(role, role + ' opens the Followup page', 'opens', opened.kind);
      await postBack(page, () => page.locator('input[id$="btnViewFollowup"]').click());
      let p = await readPage(page);
      rec(role, 'View as ' + role + ': every row Pending, the read-only line, no Submit, no drop-down, no Reopen, "View" on each row; the reopen line on ' + target,
        { rows: wantRows, line: data.readOnlyLine, submit: false, ddl: 0, reopen: 0, buttons: wantRows.map(() => 'View'), words: wantRows.map(() => 'Pending'), reopenLine: true },
        { rows: sorted(p.list), line: p.line, submit: p.submit, ddl: p.list.filter((x) => x.ddl !== '').length, reopen: p.list.filter((x) => x.reopen).length,
          buttons: p.list.map((x) => x.button), words: p.list.map((x) => x.word), reopenLine: reopenedLine(data.reopenReason).test(rowOf(p, target).line || '') });
      if (p.list.length) {
        await postBack(page, () => page.locator('table[id$="grvFollowup"] input[id*="btnActionText"]').first().click());
        p = await readPage(page);
        rec(role, role + ' opens the action text of a row: ":: View Action Text", no Save, Close, the read-only line in the panel',
          { panel: true, title: ':: View Action Text', save: false, cancel: 'Close', panelLine: data.readOnlyLine },
          { panel: p.panel, title: p.title, save: p.save, cancel: p.cancel, panelLine: p.panelLine });
        await postBack(page, () => page.locator('input[id$="btnActionTextCancel"]').click());
        p = await readPage(page);
        rec(role, 'Close: the panel closes, no message', { panel: false, message: '' }, { panel: p.panel, message: p.message });
      }
      await t.visit(page, 'DashBoard/DashBoard.aspx');
    }
  },
};
