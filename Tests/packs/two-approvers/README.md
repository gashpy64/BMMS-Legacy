# two-approvers pack (step UD1b, database step 53)

Since step 53 every active Manager of an agenda item's department may approve or reject it while it waits at AC
(not the creator himself). When one of them decides, the rows of the other Managers on the item's alert are marked
handled ("Handled by <name (login)> on dd-MMM-yyyy"); a Manager whose department is taken away has his rows of the
waiting items closed ("No longer Manager of the department (dd-MMM-yyyy)"). Those rows are listed under All only,
greyed, with that line, and never counted as unread.

Run: `pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack two-approvers`. About a minute.

## The fixture it reads

| Account | Role | Departments | Why |
|---|---|---|---|
| qa_manager | Manager | Credit | the first Manager of Credit; he decided the Credit items of the fixture |
| qa_manager3 | Manager | Credit | the second Manager of Credit (step UD1b). He was also a Manager of HRD until the HRD item QA1-00001-006 was saved; then qa_admin removed HRD from him, so his row of that item is closed ('N') |

qa_manager3 has, by the real procedures of step 53 (Tests\fixture\BMMS-Quality-Fixture.sql):
- an unread row on the two Credit items waiting at AC, QA1-00001-001 and QA1-00002-001;
- a row marked handled by qa_manager ('H') on each of the ten Credit items qa_manager approved or rejected:
  QA1-00001-002 to -005, QA1-00003-001, QA1-00004-001 and -002, QA1-00005-001 and -002, QA1-00006-001;
- a row closed by qa_admin ('N') on QA1-00001-006 (HRD, at AC);
- the two committee alerts (QA1, QA2), unread.

The fixture check (Tests\fixture\BMMS-Quality-Fixture-Check.sql) checks the account and these rows.

## Checks (`expected.json`)

1. qa_manager and qa_manager3, each: My approvals "My approvals (2)" with QA1-00001-001 (QA Test Committee, No 00001,
   Credit) and QA1-00002-001 (No 00002, Credit); the Waiting for me column of the Meetings card: 1 in QA1 00001 and 1
   in QA1 00002; both items' alerts: for qa_manager3 under Unread; for qa_manager listed under All, not removed and with
   no handled line (owner 2026-11-23: the dashboard pack's check 11, step UN6c2a / M6a, opens QA1-00001-001 from his My
   approvals earlier in the same run, which marks his alert of it read).
2. qa_manager3: the header reads "Alerts (4)" (the two waiting items and the two committee alerts); under Recent and
   under Unread no row has a handled line and none of the eleven handled items is listed.
3. qa_manager3, under All (every page of it): 15 rows; the ten rows handled by qa_manager are greyed
   (`bmms-row-handled`), not bold, with "Handled by QA Manager (qa_manager) on dd-MMM-yyyy"; the QA1-00001-006 row is
   greyed, not bold, with "No longer Manager of the department (dd-MMM-yyyy)"; the other four rows have no handled line
   and are not greyed. The date is the day the baseline was built (the dates script does not move it), so only its
   form is checked.
4. qa_manager3 opens the QA1-00001-006 row: the Agenda Alert panel shows the same line, no Approve, no Reject, the
   button "Remove from my list"; the header stays "Alerts (4)" (the row was read already). Remove from my list: the
   row leaves All (14 rows); the header stays "Alerts (4)".

Owner by eye: whether the greyed rows under All look greyed and stay legible, and their line reads well (the pack checks
the class and the words only); the screenshot `two-approvers-all-page-1` shows page 1 of All.

Not driven: Approve and Reject (they send mail; the tester has no mail server, and a failed mail writes to the error
log, which fails a run). That one Manager's decision turns the other Manager's row into "Handled by ..." is proven by
BMMS-Test-DepartmentApprovers-Step53.sql and is in the owner's browser checks.

It writes: qa_manager3's QA1-00001-006 row removed from his list. The data is restored before every run.
