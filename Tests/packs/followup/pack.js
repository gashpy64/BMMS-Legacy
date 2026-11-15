'use strict';
/*
  followup - the Followup page (Master/Followup.aspx) by role (step UN6d).

  Data (this folder; the rules are in README.md):
    expected.json   the accounts, the rows the list shows with the default filters (all committees, all
                    departments, Both), the texts of the read-only line and of the two success messages.

  What it checks
    1. The MD Secretariat (qa_mdsec) reads only: after View the list with every row, the read-only line above
       it, no Submit button, every Confirmed tick disabled and the Action Text button of each row says "View".
       Opening the action text of a row: the title ":: View Action Text", no Save button, a Close button and
       the read-only line inside the panel; Close closes it.
    2. The Controller (qa_ctrl) may save: after View the same rows, no read-only line, the Submit button,
       every tick enabled, the Action Text button says "Edit". Opening the action text: the title ":: Edit
       Action Text", Save and Cancel, no line in the panel. Save with the text unchanged: the panel closes and
       "The action text was saved." is shown as a success. Submit with the ticks unchanged: "The confirmations
       were saved." as a success, every row still listed with its tick as before.

  A post forged for the MD Secretariat (a Save or Submit the page does not render) cannot be sent: ASP.NET's
  event validation refuses it before the page runs, and that writes the error log. The server's refusal of
  every role but the Controller is proven by BMMS-Test-FollowupSave-Step46.sql.

  It writes the Controller's Save and Submit, each with the values the fixture already has (the same action
  text, the same ticks); the data is the fixture (Tests\fixture), restored and dated afresh before every run.
*/
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const FOLLOWUP = 'Master/Followup.aspx';

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

// What the page shows: the list, the line above it, Submit, the message box, the Action Text panel
async function readPage(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const shown = (el) => !!el && el.offsetParent !== null;
    const grid = document.querySelector('table[id$="grvFollowup"]');
    const rows = grid ? Array.from(grid.querySelectorAll(':scope > tbody > tr')).filter((tr) => tr.querySelector('input[type="checkbox"]')) : [];
    const list = rows.map((tr) => {
      const no = tr.querySelector('[id*="lblAgendaNo"]');
      const tick = tr.querySelector('input[type="checkbox"]');
      const btn = tr.querySelector('input[id*="btnActionText"]');
      return { agendaNo: txt(no), checked: !!tick && tick.checked, enabled: !!tick && !tick.disabled, button: btn ? btn.value : '' };
    });
    const line = document.querySelector('[id$="pFollowupReadOnly"]');
    const box = document.querySelector('[id$="divErrLogin"]');
    const span = document.querySelector('[id$="spanErrLogin"]');
    const panel = document.querySelector('[id$="pnlActionText"]');
    const panelLine = document.querySelector('[id$="pActionTextPanelMessage"]');
    const save = document.querySelector('input[id$="btnActionTextSave"]');
    const cancel = document.querySelector('input[id$="btnActionTextCancel"]');
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
    };
  });
}

const sorted = (list) => list.map((r) => r.agendaNo).sort();

module.exports = {
  title: 'Followup: the MD Secretariat reads only, the Controller saves',
  async run(t) {
    const data = readExpected();
    const rec = (role, title, expected, seen) => {
      const e = JSON.stringify(expected); const s = JSON.stringify(seen);
      t.record({ title, role, address: FOLLOWUP, expected: e, seen: s, pass: e === s });
    };
    const wantRows = data.rows.slice().sort();

    // 1. The MD Secretariat
    {
      const role = data.readOnlyAccount;
      const page = await t.session(role);
      const opened = await t.visit(page, FOLLOWUP);
      rec(role, role + ' opens the Followup page', 'opens', opened.kind);
      await postBack(page, () => page.locator('input[id$="btnViewFollowup"]').click());
      let p = await readPage(page);
      rec(role, 'View as ' + role + ': every row, the read-only line, no Submit, every tick disabled, "View" on each row',
        { rows: wantRows, line: data.readOnlyLine, submit: false, ticksEnabled: 0, buttons: wantRows.map(() => 'View') },
        { rows: sorted(p.list), line: p.line, submit: p.submit, ticksEnabled: p.list.filter((r) => r.enabled).length, buttons: p.list.map((r) => r.button) });
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

    // 2. The Controller
    {
      const role = data.saveAccount;
      const page = await t.session(role);
      const opened = await t.visit(page, FOLLOWUP);
      rec(role, role + ' opens the Followup page', 'opens', opened.kind);
      await postBack(page, () => page.locator('input[id$="btnViewFollowup"]').click());
      let p = await readPage(page);
      const ticksBefore = p.list.map((r) => r.agendaNo + ' ' + (r.checked ? '1' : '0')).sort();
      rec(role, 'View as ' + role + ': every row, no read-only line, Submit, every tick enabled, "Edit" on each row',
        { rows: wantRows, line: '', submit: true, ticksEnabled: wantRows.length, buttons: wantRows.map(() => 'Edit') },
        { rows: sorted(p.list), line: p.line, submit: p.submit, ticksEnabled: p.list.filter((r) => r.enabled).length, buttons: p.list.map((r) => r.button) });
      if (p.list.length) {
        await postBack(page, () => page.locator('table[id$="grvFollowup"] input[id*="btnActionText"]').first().click());
        p = await readPage(page);
        rec(role, role + ' opens the action text of a row: ":: Edit Action Text", Save and Cancel, no line in the panel',
          { panel: true, title: ':: Edit Action Text', save: true, cancel: 'Cancel', panelLine: '' },
          { panel: p.panel, title: p.title, save: p.save, cancel: p.cancel, panelLine: p.panelLine });
        await postBack(page, () => page.locator('input[id$="btnActionTextSave"]').click());
        p = await readPage(page);
        rec(role, 'Save with the text unchanged: the panel closes, "' + data.actionTextSaved + '" as a success',
          { panel: false, message: data.actionTextSaved, kind: 'success' }, { panel: p.panel, message: p.message, kind: p.kind });
      }
      await postBack(page, () => page.locator('input[id$="btnSubmit"]').click());
      p = await readPage(page);
      rec(role, 'Submit with the ticks unchanged: "' + data.confirmedSaved + '" as a success, every row with its tick as before',
        { message: data.confirmedSaved, kind: 'success', ticks: ticksBefore },
        { message: p.message, kind: p.kind, ticks: p.list.map((r) => r.agendaNo + ' ' + (r.checked ? '1' : '0')).sort() });
      await t.visit(page, 'DashBoard/DashBoard.aspx');
    }
  },
};
