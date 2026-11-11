'use strict';
/*
  selftest - runs at the start of every tester run (step WF3a1).

  It proves that the tester can tell a pass from a failure. Three addresses are opened twice:
  once with the true expectation (a control: it must pass) and once with a deliberately wrong
  expectation (planted: it must FAIL). If a planted check passes, the tester cannot be trusted
  and Run-Tests.ps1 declares the whole run void.

  The facts used here are plain rules of BMMS/XML/PageAccess.xml:
    Master/User.aspx          Admin only
    DashBoard/DashBoard.aspx  every signed-in role
    Master/ChangePassword.aspx every signed-in role
  and a visitor who is not signed in is sent to the sign-in page.
*/
const cases = [
  { role: 'manager', address: 'Master/User.aspx', truth: 'denied', wrong: 'opens' },
  { role: 'admin', address: 'DashBoard/DashBoard.aspx', truth: 'opens', wrong: 'notfound' },
  { role: 'user', address: 'Master/ChangePassword.aspx', truth: 'opens', wrong: 'denied' },
];

module.exports = {
  title: 'Self-test of the tester',
  async run(t) {
    for (const c of cases) {
      const control = await t.check({ role: c.role, address: c.address, expected: c.truth, title: 'Control: ' + c.role + ' opens ' + c.address });
      if (c.truth === 'denied') {
        const lines = control.accessLog.filter((l) => /\tDENIED(-PAGE)?\t/.test(l) && l.includes(c.address));
        t.record({
          title: 'Control: the refusal is written to the page access log', role: c.role, address: c.address,
          expected: '1 DENIED line', seen: lines.length + ' DENIED line' + (lines.length === 1 ? '' : 's'), pass: lines.length === 1, accessLog: lines,
        });
      }
      await t.check({ role: c.role, address: c.address, expected: c.wrong, planted: true, title: 'Planted wrong expectation: ' + c.role + ' opens ' + c.address });
    }
    await t.check({ role: 'anonymous', address: 'DashBoard/DashBoard.aspx', expected: 'signin', title: 'Control: a visitor who is not signed in opens DashBoard/DashBoard.aspx' });
  },
};
