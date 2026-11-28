'use strict';
/*
  manager-scope - lists for a Manager of several departments (step UD1c, database step 54).

  A Manager's departments are those of which he is an active Manager (fn_ManagerDepartments). The fixture (Tests\fixture)
  has qa_manager4, a Manager of Credit (home) and HRD, saved after every item. Data (this folder; the rules are in
  README.md): expected.json.

  What it checks
    1. Agenda Entry as qa_manager4: the Department filter ("All my departments", "Credit (home)", "HRD"), the card note;
       meeting QA1 00001 listed for All, for HRD and for Credit (Agenda No | Department | Entered by).
    2. Edit of the HRD item entered by qa_user2 (a colleague's item of his second department): the form opens with the
       item and its department shown fixed; Cancel.
    3. Add on meeting 00001: the Department drop-down offers his two departments, the home department chosen; Cancel.
    4. The four reports as qa_manager4: the Department drop-down ("All my departments" first, chosen and enabled);
       Agenda Summary and Minutes of QA1 viewed for All (his departments' rows) and for HRD (none).
    5. User Master as qa_admin, Add: the Reporting Person list for HRD and for Credit (the active Controllers and the
       Managers of the department, "Name (login)"), "- Select -" chosen after each Department change; none shown
       "(not allowed now)"; Cancel.

  It saves nothing: no Save, Update, Approve or Reject (a new item sends mail, which fails without a mail server and
  writes to the error log). A department that is not in a drop-down cannot be posted from the browser (ASP.NET event
  validation refuses it before the page code runs, and writes to the error log); the database's own refusals
  (Reason 30, Reason 31, Reason 4) are checked by Database\BMMS-Test-ManagerScope-Step54.sql. The "(not allowed now)"
  row needs a changed user and is an owner check.
*/
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const AGENDA = 'Master/Agenda.aspx';
const USERS = 'Master/User.aspx';

function readExpected() {
  let text = fs.readFileSync(path.join(DIR, 'expected.json'), 'utf8');
  if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
  return JSON.parse(text);
}

async function settle(page) {
  await page.waitForLoadState('domcontentloaded');
  await page.waitForFunction(() => !(window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager
    && Sys.WebForms.PageRequestManager.getInstance().get_isInAsyncPostBack()), null, { timeout: 30000 });
}

// A postback of the page: waits for its POST answer and for the page to settle. Agenda Entry and User Master post back
// in full (the browser loads a new document), so there it also waits until the new document has loaded; before, a check
// could read the page between the two documents (blank). The reports post back in part (UpdatePanel): no new document.
const FULL_POSTBACK = /\/master\/(agenda|user)\.aspx/i;
async function postBack(page, pageRx, action) {
  const full = FULL_POSTBACK.test(pageRx.source.replace(/\\/g, ''));
  const loaded = full ? page.waitForNavigation({ waitUntil: 'load', timeout: 60000 }) : Promise.resolve();
  await Promise.all([
    page.waitForResponse((r) => pageRx.test(r.url()) && r.request().method() === 'POST', { timeout: 30000 }),
    loaded,
    action(),
  ]);
  await settle(page);
}

// Step UD1c (owner 2026-11-24): the Agenda Entry rows are compared as sets; the page orders them by status
const sorted = (list) => list.slice().sort();

// The texts of a drop-down, the chosen one, whether it is shown and enabled
async function readSelect(page, selector) {
  return page.evaluate((sel) => {
    const el = document.querySelector(sel);
    if (!el) return { found: false, shown: false, enabled: false, options: [], selected: '' };
    const txt = (o) => o.textContent.replace(/\s+/g, ' ').trim();
    return { found: true, shown: el.offsetParent !== null, enabled: !el.disabled,
      options: Array.from(el.options).map(txt), selected: el.selectedIndex >= 0 ? txt(el.options[el.selectedIndex]) : '' };
  }, selector);
}

async function chooseOption(page, pageRx, selector, label) {
  const now = await readSelect(page, selector);
  if (now.selected === label) return;
  await postBack(page, pageRx, () => page.locator(selector).selectOption({ label }));
}

// The Agenda Entry list: "Agenda No | Department | Entered by", in the grid's order
async function readAgendaList(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const table = document.querySelector('table[id$="_grvAgenda"]');
    if (!table) return [];
    return Array.from(table.querySelectorAll('tr')).filter((tr) => tr.querySelector('[id*="lblAgendaNo"]')).map((tr) =>
      [txt(tr.querySelector('[id*="lblAgendaNo"]')), txt(tr.querySelector('[id*="lblDepartmentName"]')), txt(tr.querySelector('[id*="lblEnteredBy"]'))].join(' | '));
  });
}

// The report after View: whether the grid is shown, whether it shows its "no records" text (the grid's empty
// template), the page's message line, and the rows "Agenda No | Department". An empty list counts only when the grid
// is shown with its "no records" text and no message: a page that failed or never showed the grid does not pass.
async function readReportRows(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const table = document.querySelector('table[id$="_grvMinutes"]');
    const shown = !!table && table.offsetParent !== null;
    const msg = document.querySelector('[id$="_spanErrLogin"]');
    const msgShown = !!msg && msg.offsetParent !== null && txt(msg) !== '';
    const rows = shown ? Array.from(table.querySelectorAll('tr')).filter((tr) => tr.querySelector('[id*="lblAgendaNo"]')).map((tr) =>
      [txt(tr.querySelector('[id*="lblAgendaNo"]')), txt(tr.querySelector('[id*="lblDepartmentName"]'))].join(' | ')) : [];
    return { grid: shown, noRecords: shown && !!table.querySelector('.divNoRecord'), message: msgShown ? txt(msg) : '', rows };
  });
}

module.exports = {
  title: 'Manager scope: the lists of a Manager of two departments (Agenda Entry, reports, Reporting Person)',
  async run(t) {
    const data = readExpected();
    const rec = (role, address, title, expected, seen, extra) => {
      const e = typeof expected === 'string' ? expected : JSON.stringify(expected);
      const s = typeof seen === 'string' ? seen : JSON.stringify(seen);
      t.record(Object.assign({ title, role, address, expected: e, seen: s, pass: e === s }, extra || {}));
      return e === s;
    };
    const AGENDA_RX = /\/master\/agenda\.aspx/i;
    const FILTER = 'select[id$="_ddlListDepartment"]';
    const who = data.manager;

    // 1. Agenda Entry: the filter, the card note, the list for All, HRD and Credit
    let page = await t.session(who);
    await t.visit(page, AGENDA);
    const filter = await readSelect(page, FILTER);
    rec(who, AGENDA, 'Agenda Entry of ' + who + ': the Department filter (shown, enabled) and its entries, "All my departments" chosen',
      { shown: true, enabled: true, options: data.filterOptions, selected: data.filterOptions[0] },
      { shown: filter.shown, enabled: filter.enabled, options: filter.options, selected: filter.selected });
    await chooseOption(page, AGENDA_RX, 'select[id$="_ddlCommittee"]', data.committee);
    await chooseOption(page, AGENDA_RX, 'select[id$="_ddlMeeting"]', data.meeting);
    const note = await page.evaluate(() => { const p = document.querySelector('.bmms-card-note'); return p ? p.textContent.replace(/\s+/g, ' ').trim() : ''; });
    rec(who, AGENDA, 'Agenda Entry of ' + who + ': the card note', data.cardNote, note);
    rec(who, AGENDA, 'Agenda Entry of ' + who + ', QA1 ' + data.meeting + ', All my departments: the items of Credit and HRD (Agenda No | Department | Entered by; compared as a set, sorted)',
      sorted(data.listAll), sorted(await readAgendaList(page)), { screenshot: await t.shot(page, 'manager-scope-agenda-all') });
    await chooseOption(page, AGENDA_RX, FILTER, 'HRD');
    rec(who, AGENDA, 'Agenda Entry of ' + who + ', HRD: the HRD item only (compared as a set)', sorted(data.listHrd), sorted(await readAgendaList(page)));
    await chooseOption(page, AGENDA_RX, FILTER, 'Credit (home)');
    rec(who, AGENDA, 'Agenda Entry of ' + who + ', Credit (home): the Credit items only (compared as a set, sorted)', sorted(data.listCredit), sorted(await readAgendaList(page)));
    await chooseOption(page, AGENDA_RX, FILTER, data.filterOptions[0]);

    // 2. Edit of the colleague's HRD item: opens, department fixed; Cancel
    const editRow = page.locator('table[id$="_grvAgenda"] tr', { has: page.locator('[id*="lblAgendaNo"]', { hasText: data.editItem }) });
    let opened = { found: false };
    if (await editRow.count()) {
      await postBack(page, AGENDA_RX, () => editRow.first().locator('input[id*="btnEdit"]').click());
      opened = await page.evaluate(() => {
        const v = (sel) => { const el = document.querySelector(sel); return el ? (el.value || '').trim() : null; };
        const shown = (sel) => { const el = document.querySelector(sel); return !!el && el.offsetParent !== null; };
        return { found: true, form: shown('input[id$="_btnSave"]'), item: v('input[id$="_txtAgendaNo"]'), department: v('input[id$="_txtDepartment"]'),
          departmentFixed: shown('input[id$="_txtDepartment"]') && !shown('select[id$="_ddlDepartment"]'),
          message: (document.querySelector('[id$="_spanErrLogin"]') || {}).textContent || '' };
      });
      opened.message = opened.message.replace(/\s+/g, ' ').trim();
    }
    rec(who, AGENDA, who + ' opens ' + data.editItem + ' (entered by qa_user2, HRD): the form opens with the item, its department shown fixed, no refusal',
      { found: true, form: true, item: data.editItem, department: data.editDepartment, departmentFixed: true, message: '' },
      opened, { screenshot: await t.shot(page, 'manager-scope-edit-hrd-item') });
    if (opened.form) await postBack(page, AGENDA_RX, () => page.locator('input[id$="_btnCancel"]').click());

    // 3. Add on meeting 00001: his two active departments, the home department chosen; Cancel
    await t.visit(page, AGENDA);
    await chooseOption(page, AGENDA_RX, 'select[id$="_ddlCommittee"]', data.committee);
    await chooseOption(page, AGENDA_RX, 'select[id$="_ddlMeeting"]', data.meeting);
    await postBack(page, AGENDA_RX, () => page.locator('input[id$="_btnAdd"]').click());
    const dept = await readSelect(page, 'select[id$="_ddlDepartment"]');
    const fixedShown = await page.evaluate(() => { const el = document.querySelector('input[id$="_txtDepartment"]'); return !!el && el.offsetParent !== null; });
    rec(who, AGENDA, 'Add of ' + who + ': the Department drop-down offers his two departments, the home department chosen; no fixed box',
      { shown: true, options: data.newItemOptions, selected: data.newItemSelected, fixedBox: false },
      { shown: dept.shown, options: dept.options, selected: dept.selected, fixedBox: fixedShown },
      { screenshot: await t.shot(page, 'manager-scope-add-departments') });
    if (dept.shown) await postBack(page, AGENDA_RX, () => page.locator('input[id$="_btnCancel"]').click());

    // 4. The four reports: the Department drop-down; Agenda Summary and Minutes viewed for All and for HRD
    const REPORTS_RX = /\/report\/reports\.aspx/i;
    for (const rc of data.reports) {
      const address = 'Report/Reports.aspx?rc=' + rc;
      await t.visit(page, address);
      const d = await readSelect(page, 'select[id$="_ddlDepartment"]');
      rec(who, address, rc + ' of ' + who + ': the Department drop-down (enabled) and its entries, "All my departments" chosen',
        { enabled: true, options: data.reportOptions, selected: data.reportOptions[0] },
        { enabled: d.enabled, options: d.options, selected: d.selected });
      if (rc === 'agenda_summary' || rc === 'minutes') {
        const expectedAll = rc === 'minutes' ? data.minutesAll : data.agendaSummaryAll;
        await chooseOption(page, REPORTS_RX, 'select[id$="_ddlCommittee"]', data.committee);
        await postBack(page, REPORTS_RX, () => page.locator('input[id$="_btnView"]').click());
        rec(who, address, rc + ' of ' + who + ', QA1, all meetings, All my departments: the grid shown with his departments\' rows (Agenda No | Department), no message',
          { grid: true, noRecords: false, message: '', rows: expectedAll }, await readReportRows(page),
          { screenshot: await t.shot(page, 'manager-scope-' + rc + '-all') });
        await chooseOption(page, REPORTS_RX, 'select[id$="_ddlDepartment"]', 'HRD');
        await postBack(page, REPORTS_RX, () => page.locator('input[id$="_btnView"]').click());
        rec(who, address, rc + ' of ' + who + ', QA1, HRD: the grid shown with its "no records" text and no rows, no message (HRD has no approved item or minute)',
          { grid: true, noRecords: true, message: '', rows: [] }, await readReportRows(page),
          { screenshot: await t.shot(page, 'manager-scope-' + rc + '-hrd') });
      }
    }

    // 5. User Master as qa_admin, Add: the Reporting Person list per department; "- Select -" after each change; Cancel
    const USERS_RX = /\/master\/user\.aspx/i;
    const admin = data.admin;
    page = await t.session(admin);
    await t.visit(page, USERS);
    await postBack(page, USERS_RX, () => page.locator('input[id$="_btnAdd"]').click());
    for (const [label, expected] of [['HRD', data.reportingHrd], ['Credit', data.reportingCredit]]) {
      await chooseOption(page, USERS_RX, 'select[id$="_ddlDepartment"]', label);
      const m = await readSelect(page, 'select[id$="_ddlManager"]');
      rec(admin, USERS, 'User Master, Add, Department ' + label + ': the Reporting Person list ("- Select -", the active Controllers, the Managers of ' + label + '), "- Select -" chosen, none "(not allowed now)"',
        { options: expected, selected: '- Select -', notAllowed: 0 },
        { options: m.options, selected: m.selected, notAllowed: m.options.filter((x) => /\(not allowed now\)/.test(x)).length },
        { screenshot: await t.shot(page, 'manager-scope-reporting-' + label.toLowerCase()) });
    }
    await postBack(page, USERS_RX, () => page.locator('input[id$="_btnCancel"]').click());
    await t.visit(page, 'DashBoard/DashBoard.aspx');
  },
};
