'use strict';
/*
  session-check - a change of role, departments or status ends the session at the user's next click (step RA1d).

  The rules are in README.md (this folder). In short:
    0. The Admin (qa_admin) reads User Master: qa_mdsec is MD Secretariat, qa_manager2 is a Manager of HRD and
       Secretarial, qa_user2 is an active User, as the fixture has them. Otherwise a fixture user was left changed
       (by an earlier pack of this run: the runner restores BMMS_Quality before every run) and the pack stops
       with a failed check, changing nothing.
    1. qa_mdsec, qa_manager2, qa_user2 and qa_ctrl sign in and open the Dashboard.
    2. The Admin changes qa_mdsec's role to Management in User Master. qa_mdsec's next click lands on the sign-in
       page with "Your access has changed. Please sign in again."; one SESSION-ENDED line "role md_sect to mgmt".
    3. The Admin adds Credit to qa_manager2 (a removal of Secretarial is refused by step 39 rule 12: qa_manager2
       is the last active Manager of Secretarial with an item waiting). qa_manager2's next Dashboard filter (an
       UpdatePanel postback) lands on the sign-in page with the same text, with no script error and no error bar;
       one SESSION-ENDED line "departments changed".
    4. The Admin deactivates qa_user2. qa_user2's next click lands on the sign-in page with the inactive text;
       one SESSION-ENDED line "inactive".
    After each ended session the ASP.NET_SessionId cookie of that browser differs from the one before (the ended
    session's cookie was expired): after a fresh sign-in for qa_mdsec and qa_manager2; on the sign-in page for
    qa_user2, who cannot sign in.
    5. qa_ctrl, unchanged, opens a page after every change and is never sent to the sign-in page; no
       SESSION-ENDED line for qa_ctrl or qa_admin.
    6. Finally (also after a failure): the three users are put back through User Master, and User Master must
       show them as at the start (qa_manager2 by removing Credit again). A user that could not be put back is a
       failed check that names it.

  It writes: three user changes and their reversal (User Master, as the Admin), so the users end as the fixture
  has them, with closed and reopened history rows. Run it as the last pack of a run.
*/

const USERS = 'Master/User.aspx';
const DASH = 'DashBoard/DashBoard.aspx';
const CHANGED_TEXT = 'Your access has changed. Please sign in again.';
const SESSION_COOKIE = 'ASP.NET_SessionId';
const INACTIVE_TEXT = 'Your account is inactive. Contact the administrator.';

async function fullPost(page, action) {
  await Promise.all([
    page.waitForResponse((r) => /user\.aspx/i.test(r.url()) && r.request().method() === 'POST', { timeout: 60000 }),
    action(),
  ]);
  await page.waitForLoadState('domcontentloaded');
}

// The User Master grid: one entry per login
async function readUsers(page) {
  return page.evaluate(() => {
    const txt = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
    const out = {};
    document.querySelectorAll('table[id$="grvUser"] tr').forEach((tr) => {
      const login = tr.querySelector('[id*="lblLoginName"]');
      if (!login) return;
      out[txt(login)] = {
        role: txt(tr.querySelector('[id*="lblRoleName"]')),
        departments: txt(tr.querySelector('[id*="lblDepartmentName"]')),
        active: !/wb-row-inactive/.test(tr.className),
      };
    });
    return out;
  });
}

async function pageMessage(page) {
  return page.evaluate(() => {
    const span = document.querySelector('[id$="spanErrLogin"]');
    return span ? span.textContent.replace(/\s+/g, ' ').trim() : '';
  });
}

// The value of the session cookie in the page's browser context ('' when there is none)
async function sessionCookie(page) {
  const all = await page.context().cookies();
  const c = all.find((x) => x.name === SESSION_COOKIE);
  return c ? c.value : '';
}

// Signs in again in the same browser context (the page is on the sign-in page); returns the path it lands on
async function signInHere(page, account) {
  await page.locator('[id$="txtLoginName"]').fill(account.login);
  await page.locator('[id$="txtPassword"]').fill(account.password);
  await Promise.all([
    page.waitForURL((u) => !/\/default\.aspx$/i.test(new URL(u).pathname), { timeout: 60000 }).catch(() => null),
    page.locator('[id$="btnLogin"]').click(),
  ]);
  await page.waitForLoadState('domcontentloaded');
  return new URL(page.url()).pathname;
}

function rowOf(page, login) {
  return page.locator('table[id$="grvUser"] tr').filter({ has: page.locator('[id*="lblLoginName"]', { hasText: login }) });
}

async function openUsers(t, page) {
  const v = await t.visit(page, USERS);
  if (v.kind !== 'opens') throw new Error('User Master did not open for the Admin (' + v.kind + ')');
}

async function editUser(page, login) {
  await fullPost(page, () => rowOf(page, login).locator('input[id*="btnEdit"]').first().click());
}

async function save(page) {
  await fullPost(page, () => page.locator('input[id$="btnSave"]').click());
  return pageMessage(page);
}

async function setRole(page, label) {
  await fullPost(page, () => page.selectOption('select[id$="ddlRole"]', { label }));
}

async function setDepartment(page, name, on) {
  const box = page.locator('[id$="cblDepartments"]').getByLabel(name, { exact: true });
  if (on) await box.check(); else await box.uncheck();
}

async function setStatus(page, login) {
  page.once('dialog', (d) => d.accept().catch(() => null));
  await fullPost(page, () => rowOf(page, login).locator('input[id*="btnStatus"]').first().click());
  return pageMessage(page);
}

const ok = (u, want) => !!u && u.role === want.role && u.active === want.active
  && want.departments.every((d) => u.departments.indexOf(d) >= 0) && (want.only === undefined || u.departments.split(',').length === want.only);

module.exports = {
  title: 'Session check: a change of role, departments or status ends the session at the next click',
  async run(t) {
    const acc = t.creds.accounts;
    const L = { mdsec: acc.mdsec.login, manager2: acc.manager2.login, user2: acc.user2.login, ctrl: acc.controller.login, admin: acc.admin.login };
    const fixture = {
      [L.mdsec]: { role: 'MD Secretariat', active: true, departments: [] },
      [L.manager2]: { role: 'Manager', active: true, departments: ['HRD', 'Secretarial'], only: 2 },
      [L.user2]: { role: 'User', active: true, departments: [] },
    };
    const rec = (role, title, expected, seen, extra) => {
      const e = JSON.stringify(expected); const s = JSON.stringify(seen);
      return t.record(Object.assign({ title, role, address: USERS, expected: e, seen: s, pass: e === s }, extra || {}));
    };
    const endedLines = (lines, login) => lines.filter((l) => /\tSESSION-ENDED\t/.test(l) && l.indexOf('(' + login + ')') >= 0);
    const signinStatus = (page) => { try { return new URL(page.url()).searchParams.get('status') || ''; } catch (e) { return ''; } };

    const admin = await t.session('admin');
    await openUsers(t, admin);
    const before = await readUsers(admin);
    const start = {};
    Object.keys(fixture).forEach((login) => { start[login] = ok(before[login], fixture[login]); });
    rec('admin', 'Before any change: User Master shows qa_mdsec, qa_manager2 and qa_user2 as the fixture has them (a fixture user left changed by an earlier pack of this run fails here)',
      { [L.mdsec]: true, [L.manager2]: true, [L.user2]: true }, start, { detail: JSON.stringify(before[L.mdsec]) + ' ' + JSON.stringify(before[L.manager2]) + ' ' + JSON.stringify(before[L.user2]) });
    if (!start[L.mdsec] || !start[L.manager2] || !start[L.user2]) return;

    const changed = { role: false, dept: false, status: false };
    try {
      // 1. The users sign in and open the Dashboard
      const pages = {};
      for (const role of ['mdsec', 'manager2', 'user2', 'controller']) {
        pages[role] = await t.session(role);
        const v = await t.visit(pages[role], DASH);
        rec(role, role + ' signs in and opens the Dashboard', 'opens', v.kind, { address: DASH });
      }
      const ctrlClick = async (address, when) => {
        const v = await t.visit(pages.controller, address);
        rec('controller', 'qa_ctrl (unchanged) opens ' + address + ' ' + when + ': no interruption', 'opens', v.kind, { address });
      };
      const mark = t.logMark();

      // 2. Role changed: MD Secretariat to Management
      await openUsers(t, admin);
      await editUser(admin, L.mdsec);
      await setRole(admin, 'Management');
      let msg = await save(admin);
      changed.role = msg === 'Successfully Saved';
      rec('admin', 'The Admin changes qa_mdsec to Management: "Successfully Saved"', 'Successfully Saved', msg);
      let cookieBefore = await sessionCookie(pages.mdsec);
      let v = await t.visit(pages.mdsec, DASH);
      let text = await pageMessage(pages.mdsec);
      rec('mdsec', 'qa_mdsec\'s next click: the sign-in page with "' + CHANGED_TEXT + '"',
        { kind: 'signin', status: 'changed', message: CHANGED_TEXT }, { kind: v.kind, status: signinStatus(pages.mdsec), message: text },
        { address: DASH, screenshot: await t.shot(pages.mdsec, 'mdsec-role-changed') });
      let landed = await signInHere(pages.mdsec, acc.mdsec);
      let cookieAfter = await sessionCookie(pages.mdsec);
      rec('mdsec', 'qa_mdsec signs in again in the same browser: the Dashboard, with another ASP.NET_SessionId than before (the ended session\'s cookie was expired)',
        { dashboard: true, hadCookie: true, newCookie: true, differs: true },
        { dashboard: /\/dashboard\/dashboard\.aspx$/i.test(landed), hadCookie: cookieBefore !== '', newCookie: cookieAfter !== '', differs: cookieAfter !== cookieBefore },
        { address: 'Default.aspx' });
      await t.endSession('mdsec');
      await ctrlClick('Master/Meeting.aspx', 'after the role change');

      // 3. Department added (a removal of Secretarial is refused by step 39 rule 12 in the fixture); the next
      //    request is an UpdatePanel postback of the Dashboard
      await openUsers(t, admin);
      await editUser(admin, L.manager2);
      await setDepartment(admin, 'Credit', true);
      msg = await save(admin);
      changed.dept = msg === 'Successfully Saved';
      rec('admin', 'The Admin adds Credit to qa_manager2: "Successfully Saved"', 'Successfully Saved', msg);
      cookieBefore = await sessionCookie(pages.manager2);
      const errors = [];
      const onError = (e) => errors.push(String(e.message || e).slice(0, 160));
      pages.manager2.on('pageerror', onError);
      const committee = pages.manager2.locator('select[id$="_ddlCommittee"]');
      const options = await committee.locator('option').count();
      await Promise.all([
        pages.manager2.waitForURL((u) => /\/default\.aspx$/i.test(new URL(u).pathname), { timeout: 60000 }).catch(() => null),
        committee.selectOption({ index: options > 1 ? 1 : 0 }),
      ]);
      await pages.manager2.waitForLoadState('domcontentloaded');
      pages.manager2.off('pageerror', onError);
      const onSignin = /\/default\.aspx$/i.test(new URL(pages.manager2.url()).pathname);
      text = await pageMessage(pages.manager2);
      rec('manager2', 'qa_manager2\'s next Dashboard filter (UpdatePanel postback): the sign-in page with "' + CHANGED_TEXT + '", no script error',
        { signin: true, status: 'changed', message: CHANGED_TEXT, scriptErrors: [] },
        { signin: onSignin, status: signinStatus(pages.manager2), message: text, scriptErrors: errors },
        { address: DASH, screenshot: await t.shot(pages.manager2, 'manager2-departments-changed') });
      landed = onSignin ? await signInHere(pages.manager2, acc.manager2) : '';
      cookieAfter = await sessionCookie(pages.manager2);
      rec('manager2', 'qa_manager2 signs in again in the same browser: the Dashboard, with another ASP.NET_SessionId than before',
        { dashboard: true, hadCookie: true, newCookie: true, differs: true },
        { dashboard: /\/dashboard\/dashboard\.aspx$/i.test(landed), hadCookie: cookieBefore !== '', newCookie: cookieAfter !== '', differs: cookieAfter !== cookieBefore },
        { address: 'Default.aspx' });
      await t.endSession('manager2');
      await ctrlClick('Report/Reports.aspx?rc=minutes', 'after the department change');

      // 4. Deactivated
      await openUsers(t, admin);
      msg = await setStatus(admin, L.user2);
      changed.status = msg === 'User deactivated';
      rec('admin', 'The Admin deactivates qa_user2: "User deactivated"', 'User deactivated', msg);
      cookieBefore = await sessionCookie(pages.user2);
      v = await t.visit(pages.user2, DASH);
      text = await pageMessage(pages.user2);
      rec('user2', 'qa_user2\'s next click: the sign-in page with "' + INACTIVE_TEXT + '"',
        { kind: 'signin', status: 'inactive', message: INACTIVE_TEXT }, { kind: v.kind, status: signinStatus(pages.user2), message: text },
        { address: DASH, screenshot: await t.shot(pages.user2, 'user2-inactive') });
      cookieAfter = await sessionCookie(pages.user2);
      rec('user2', 'qa_user2 (inactive, cannot sign in) on the sign-in page: another ASP.NET_SessionId than before (the ended session\'s cookie was expired)',
        { hadCookie: true, differs: true }, { hadCookie: cookieBefore !== '', differs: cookieAfter !== cookieBefore },
        { address: 'Default.aspx', detail: cookieAfter === '' ? 'no session cookie on the sign-in page' : 'a new session cookie' });
      await t.endSession('user2');
      await ctrlClick(DASH, 'after the deactivation');

      // The page access log: one SESSION-ENDED line per ended session, with its reason; none for the others
      const lines = t.logSince(mark);
      const one = (login, pattern) => {
        const l = endedLines(lines, login);
        return l.length === 1 && pattern.test(l[0]) && /\tUserId \d+; /.test(l[0]);
      };
      rec('admin', 'PageAccessLog: exactly one SESSION-ENDED line per ended session (user id, login, page, reason); none for qa_ctrl and qa_admin',
        { [L.mdsec]: true, [L.manager2]: true, [L.user2]: true, [L.ctrl]: 0, [L.admin]: 0, checkErrors: 0 },
        { [L.mdsec]: one(L.mdsec, /role md_sect to mgmt$/), [L.manager2]: one(L.manager2, /departments changed$/), [L.user2]: one(L.user2, /inactive$/),
          [L.ctrl]: endedLines(lines, L.ctrl).length, [L.admin]: endedLines(lines, L.admin).length,
          checkErrors: lines.filter((l) => /\tSESSION-CHECK-ERROR\t/.test(l)).length },
        { accessLog: lines });
    } finally {
      // 6. Put the three users back, whatever happened above
      const problems = [];
      const attempt = async (name, fn) => { try { await fn(); } catch (e) { problems.push(name + ': ' + String(e.message || e).split('\n')[0].slice(0, 160)); } };
      await attempt('admin page', async () => { await openUsers(t, admin); });
      let now = await readUsers(admin).catch(() => ({}));
      if (!ok(now[L.mdsec], fixture[L.mdsec])) {
        await attempt(L.mdsec, async () => { await openUsers(t, admin); await editUser(admin, L.mdsec); await setRole(admin, 'MD Secretariat'); await save(admin); });
      }
      now = await readUsers(admin).catch(() => ({}));
      if (!ok(now[L.manager2], fixture[L.manager2])) {
        await attempt(L.manager2, async () => { await openUsers(t, admin); await editUser(admin, L.manager2); await setDepartment(admin, 'Credit', false); await setDepartment(admin, 'Secretarial', true); await save(admin); });
      }
      now = await readUsers(admin).catch(() => ({}));
      if (!ok(now[L.user2], fixture[L.user2])) {
        await attempt(L.user2, async () => { await openUsers(t, admin); await setStatus(admin, L.user2); });
      }
      await attempt('admin page', async () => { await openUsers(t, admin); });
      const after = await readUsers(admin).catch(() => ({}));
      const same = (login) => JSON.stringify(after[login] || null) === JSON.stringify(before[login]);
      rec('admin', 'Finally: qa_mdsec, qa_manager2 and qa_user2 are as before the pack (a user left changed is named here)',
        { [L.mdsec]: true, [L.manager2]: true, [L.user2]: true, problems: [] },
        { [L.mdsec]: same(L.mdsec), [L.manager2]: same(L.manager2), [L.user2]: same(L.user2), problems },
        { detail: 'changed during the pack: ' + JSON.stringify(changed) + '; after: ' + JSON.stringify(after[L.mdsec]) + ' ' + JSON.stringify(after[L.manager2]) + ' ' + JSON.stringify(after[L.user2]) });
    }
  },
};
