# manager-scope pack (step UD1c, database step 54)

Since step 54 a Manager's departments are the departments of which he is an active Manager (fn_ManagerDepartments,
from fn_DepartmentManagers of step 53), not his home department alone. Agenda Entry, the four Manager reports and the
Reporting Person list of User Master read them; the procedures check them again with the acting user.

Run: `pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack manager-scope`. About a minute.

## The fixture it reads

| Account | Role | Departments | Why |
|---|---|---|---|
| qa_manager4 | Manager | Credit (home), HRD | a Manager of two departments (step UD1c); saved last in the fixture, after every item, so nothing of the other accounts changes |
| qa_admin | Admin | Admin | User Master |

Meeting QA1 00001 (agenda open, 30 days ahead) has five Credit items entered by qa_user and the HRD item QA1-00001-006
entered by qa_user2. QA1 has seven approved Credit items (meetings 00001, 00003 to 00006) and three minutes rows of
finalised or confirmed minutes (00005, 00006); HRD has none. The fixture check (Tests\fixture\BMMS-Quality-Fixture-Check.sql)
checks qa_manager4 and his departments (D004 home, D003).

## Checks (`expected.json`)

1. Agenda Entry as qa_manager4: the Department filter is shown and enabled with "All my departments", "Credit (home)",
   "HRD", the first chosen; the card note "Items of your departments and the items you entered."; meeting QA1 00001
   lists the six items for All (Agenda No | Department | Entered by), only QA1-00001-006 for HRD, the five Credit items
   for Credit (home). The rows are compared as sets (both lists sorted; owner 2026-11-24): the page orders them by
   status, which is not part of UD1c. Agenda Entry and User Master post back in full: the pack waits for the new page
   to load before it reads it.
2. Edit of QA1-00001-006 (a colleague's item of his second department): the form opens with the item, its department
   "HRD" in the fixed box (no drop-down) and no refusal message; Cancel.
3. Add on QA1 00001: the Department drop-down is shown with "Credit (home)" and "HRD", "Credit (home)" chosen, and the
   fixed box is hidden; Cancel.
4. Agenda Summary, Agenda Details, Minutes and Minutes Extract as qa_manager4: the Department drop-down is enabled with
   "All my departments", "Credit (home)", "HRD", the first chosen. Agenda Summary of QA1 (all meetings), View: the seven
   approved Credit items; with HRD: the grid with its "no records" text and no rows. Minutes of QA1, View: the three
   minutes rows (Credit); with HRD: the same "no records" grid. Each time the grid must be shown and no message line
   (a page that failed or showed no grid does not pass).
5. User Master as qa_admin, Add: Department HRD gives the Reporting Person list "- Select -", "Controller (secuser)",
   "QA Controller (qa_ctrl)", "QA Manager Four (qa_manager4)", "QA Manager Two (qa_manager2)"; Department Credit gives
   "- Select -", "Controller (secuser)", "Manager (credmanager)", "QA Controller (qa_ctrl)", "QA Manager (qa_manager)",
   "QA Manager Four (qa_manager4)", "QA Manager Three (qa_manager3)"; after each change "- Select -" is chosen; no entry
   reads "(not allowed now)"; Cancel.

## What it does not do

- It saves nothing (no Save, Update, Approve or Reject): a new item sends mail, which fails without a mail server and
  writes a line to the error log, and any new line in the error log makes the run FAILED.
- It does not post a department that is not in a drop-down: ASP.NET event validation refuses it before the page code
  runs (and writes to the error log). The procedures' own refusals (Reason 30 for a new item or an Update outside his
  departments, Reason 31 for a Reporting Person that is not allowed, Reason 4 for a report of a department that is not
  his) are checked by `Database\BMMS-Test-ManagerScope-Step54.sql`.
- "(not allowed now)" needs a user whose Reporting Person is no longer allowed; the fixture has none. Owner check.
- It writes nothing to the database; the data is the fixture, restored before every run.
