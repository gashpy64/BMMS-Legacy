# Testing and Release

- Title: Testing and Release
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: FU2b (the section "Step 49 (FU2b): the Test script, the changed expectation of step 47, the followup-reports pack"); FU2a (the section "Step 48 (FU2a): the Test script, the changed expectations of steps 43 and 45, the dashboard pack check 18"); FU1 (the section "Step 47 (FU1): the Test script, the followup pack and the run"); UN6d (the step 46 Test script section "Step 46 (UN6d): the Followup saves", the followup pack, the dashboard pack check 8, the packs line of the tester table); UN6c2b (the step 45 Test script section, "The dashboard pack since step UN6c2b", the fixture and baseline notes); UN6c2a (the step 44 Test script section, "The dashboard pack since step UN6c2a", check 4 of the dashboard pack, the fixture and baseline notes); UN6c1 (the step 43 Test script section, "The dashboard pack since step UN6c1", the fixture and baseline notes); UN6b (the step 42 Test script section, the dashboard pack, the memory preflight, the fixture's committee QA2, the baseline upkeep note); the rest RA1c2
- Last updated by: FU2b, based on c4300b5
- Status: Draft
- Verified against: for step FU2b: Database/README.md (section Step FU2b: the Test script description, the changed expected value, the tester paragraph, "What to run where"), Tests/packs/followup-reports/README.md (read), BMMS-Test-FollowupFinal-Step47.sql (diff), the Test results and the tester runs 2026-11-17_133514 and 2026-11-17_135000 as given; the step 49 Test script and pack.js were not read in full;
  for step FU2a: Database/README.md (section Step FU2a: the Test script description, the changed expected values, the tester paragraph, "What to run where"), Tests/packs/dashboard/README.md (diff), Database/BMMS-Test-DashboardAlerts-Step43.sql and BMMS-Test-DashboardSummary-Step45.sql (diff stat only), the Test script result (43 of 43) and the tester run 2026-11-16_181041 as given; the step 48 Test script and pack.js were not read in full;
  for step FU1: Database/README.md (section Step FU1: the Test script description, the tester paragraph, the changed expected values, "What to run where"), Tests/packs/followup/README.md (read in full), Tests/README.md and Database/BMMS-Check-InstalledSteps.sql (diff), the Test script result (95 of 95) and the tester run 2026-11-16_133023 as given; the Test script itself and pack.js were not read in full;
  for step UN6d: Database/README.md (section Step UN6d: the Test script description, the tester paragraph, the changed expected values), Tests/packs/followup/README.md and expected.json, Tests/packs/dashboard/README.md and expected.json (diff), Tests/packs/access-matrix/README.md and Tests/README.md (diff), the Test script result (56 of 56) and the tester runs of 2026-11-15 as given; the Test script itself (632 lines) and pack.js were not read in full;
  for step UN6c2b: Database/README.md (section Step UN6c2b: the Test script description, Known items), Tests/packs/dashboard/README.md and Tests/README.md (diff), Database/BMMS-Rollback-AgendaWaitingFor-Step44.sql (diff), the tester run of 2026-11-15 (dashboard pack 388 checks PASSED) and the owner's tests as given; the Test scripts themselves (1329 lines for step 45) were not read in full;
  for step UN6c2a: Database/BMMS-Test-AgendaWaitingFor-Step44.sql (header, parts 1 and 2 up to the comparison and the named cases; the 1352 cases counted from its actor, item and action lists), Tests/packs/dashboard/README.md, expected.json and pack.js (diff), Tests/README.md (diff), Tests/fixture/BMMS-Quality-Fixture*.sql (diff), Database/README.md (section Step UN6c2a, Known items), the tester run of 2026-11-14 07:52:25 and the owner's tests as given; for step UN6c1: Database/BMMS-Test-DashboardAlerts-Step43.sql (header), Tests/packs/dashboard/README.md,
  expected.json and pack.js (diff), Tests/README.md (diff), Tests/fixture/BMMS-Quality-Fixture*.sql (diff),
  Database/README.md (section Step UN6c1, Known items), the owner's test result and the tester run of 2026-11-13 as given
  (702 checks PASSED); for step UN6b: Database/BMMS-Test-DashboardMeetings-Step42.sql (header, guards, part 1),
  Tests/packs/dashboard/README.md, expected.json (case names), pack.js (header), Tests/README.md (diff),
  Tests/_runner/Run-Tests.ps1, Tester.Common.ps1 and Setup-Quality.ps1 (diff), Tests/fixture/BMMS-Quality-Fixture-Check.sql
  (diff), Database/README.md (section Step UN6b, Known items), the owner's test result and the tester run of
  2026-11-12 (Tests/_results/2026-11-12_214642, PASSED, 649 checks) as given for the step, not re-read; for step RA1c2: git diff against 1db6ac6 of Tests/packs/access-matrix/expected.csv,
  README.md and pack.js, BMMS/XML/PageAccess.xml, and the tester result (477 checks) as given for the step, not re-read; for step RA1c1 (the access-matrix pack section): git diff against 4946500 of
  Tests/packs/access-matrix/expected.csv and README.md, .claude/agents/tester.md, Tests/README.md,
  BMMS/XML/PageAccess.xml, Database/README.md (section Step RA1c1), the tester run of 2026-11-11
  (Tests/_results/2026-11-11_230233) as given for the step, not re-read; for the sections "The tester (steps WF3a1 and WF3a2)" and "The access-matrix pack (step WF3a2)":
  CLAUDE.md (steps 1, 5 and 6), .claude/agents/tester.md, Tests/README.md, Tests/packs/access-matrix/
  (README.md, expected.csv header and the two RA1c rows, not-in-menu.csv, home-link.csv, planted.json),
  Database/README.md (section Step WF3a2 and Known items for later steps), the owner's test result and
  the tester agent's run of 2026-11-11 as given for the step (Tests/_results/2026-11-11_215849, not
  re-read); for the section "The tester (step WF3a1)": Tests/README.md, Tests/_runner/Tester.Common.ps1,
  Run-Tests.ps1 (exit codes, result words), Tests/lib/run.js (Chrome channel), Tests/package.json,
  .claude/agents/tester.md, .claude/hooks/tester-guard.ps1, Database/README.md (section Step WF3a1 and
  Known items for later steps), the owner's test result of 2026-11-11; none yet for the rest (leads from the old Architecture notes added in WF2b1); for the step 40
  section Database/BMMS-Test-RoleAccess-Step40.sql (header), the diff of the three changed Test scripts
  and the owner's test result of step RA1a; for the step 41 section Database/BMMS-Test-ReportAccess-Step41.sql
  (header), Database/README.md (section RA1b) and the owner's test result of step RA1b
- To confirm: the UN6b tester result (649 checks, access-matrix and dashboard together, run folder 2026-11-12_214642, memory 1522 MB available of 7886 MB) is as given for the step, not re-read from the results folder; the count of the step 42 Test script (71 in the owner's run) is as given, not recounted; the number of checks of the dashboard pack alone and its run time are not recorded here; the fixture check count after QA2 (29 before, three rows added) was not re-run; the counts of the RA1c2 run (477 checks) are as given for the step, not re-read from the results folder; the run time and counts of the RA1c1 run are as given for the step, not re-read from the results folder; the run times and request count of the access matrix are the owner's measurements as given for the step, not re-measured; the count of 44 checks and the counts of the older Test scripts are Database/README.md's, not
  recounted from the scripts; the three UN6d tester runs (871, 399 and 871 checks) are as given for the step, and which packs each held and the number of checks of the followup pack alone are not recorded here; chapter not written yet (WF2b2); leads from the old Architecture notes to verify

## Test database

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: database tests run on a test copy (BMMS_Test or BMMS_bak1), never first on BMMS]]

## Test scripts and how to run them

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: every step has a test script that runs inside a transaction and rolls back]]

### Step 40 (RA1a): role access

Database/BMMS-Test-RoleAccess-Step40.sql (BMMS_Test only; refuses the name BMMS; stops when step 40 is
not installed). Part 1 reads the markers of step 40 and the older markers (steps 13, 14, 18, 21), the
parameters and that no THROW is left in the two member type procedures. Part 2 runs in one transaction
that is rolled back, with made-up users, a department and a member type (ZZ40...): a Controller is
refused (Reason 4) on Create, Edit, RoleChange, Deactivate, Activate, Delete and ResetPassword of another
account, and may Edit and ResetPassword its own; the Reason 1, 7 and 8 cases stay; an Admin may do all
of it; a Manager is refused as before; the user procedures and the User Master list flags end to end;
the member type Save and Delete (Controller refused, Admin allowed); nothing left after the rollback and
every identity counter put back. Result on BMMS_Test (owner's run for RA1a): 43 of 43 PASS.

Older Test scripts changed for step 40: only their Controller expectations (each changed line carries a
"Step 40 (RA1a)" comment). After step 40 they pass on BMMS_Test; on a database without step 40 those
cases fail.

| Script | Result with step 40 | What changed |
|---|---|---|
| BMMS-Test-UserProtection-Stage1.sql | 142 PASS | The Controller acting on a Manager, User, Management or MD Secretariat user, and creating a Manager, User, Management or MD Secretariat user: Reason 4 instead of 0; spr_CheckUserChange, Controller resets a User's password: Reason 4; the list flags of the MD Secretariat row for a Controller: 0 0 0 |
| BMMS-Test-UserStatus-Stage2a.sql | 50 PASS | The Controller deactivates or activates a User: Reason 4; the list flag CanDeactivate of a User row for a Controller: 0 |
| BMMS-Test-MemberTypes-Step21.sql | 100 PASS | The Controller's save, edit and delete of a member type: Reason 4. The display order case of reserved type 3 now acts as the Admin and keeps its result (Reason 7), renamed "by an Admin"; two setup lines (no check row) have the Admin save and edit the types the later cases use |

The other user and member type Test scripts are unchanged and PASS. The Rollback script restores the earlier
texts; BMMS-Check-InstalledSteps.sql shows step 40 Installed, 3 of 3.

### Step 41 (RA1b): report access

Database/BMMS-Test-ReportAccess-Step41.sql (BMMS_Test only; refuses the name BMMS; stops when step 41 is
not installed). Part 1 only reads: the three markers, the parameters, the result columns (the old columns in
the same order plus the new ones) and that the step 22 procedures are unchanged. Part 2 runs in one
transaction that is rolled back, with made-up users, a committee, meetings, agenda items, minutes rows and
action items (ZZ41...): who may call each procedure (Controller and Management the two Minutes procedures;
Management only the Followup one; Manager, User, Admin and MD Secretariat Reason 4; an inactive, unknown or
missing acting user Reason 8; a refused call returns no rows); the meeting list in every status with the
marks (a meeting without a minutes row and another committee's meetings left out); the minutes rows (every
meeting, one meeting, a range, a department, a subject number range); the step 22 procedures still F and C
only; spr_GetFollowupReportForManagement against a copy of the Controller's code-built query for nine
filter combinations (the same rows by count and ActionItemId); nothing left after the rollback and every
identity counter put back. Count: 44 checks according to Database/README.md. Unchanged Test scripts that
must still pass with step 41: BMMS-Test-MinutesGating-Step22.sql (36), BMMS-Test-UnicodeText-Step31.sql (41),
BMMS-Test-WorkflowOrder-Step23.sql (53) and BMMS-Test-RoleAccess-Step40.sql (43).

Result (owner's run on BMMS_Test for step RA1b): every row of the database Test script passed, and the
browser table passed for the Controller, Management, Manager, User, Admin and MD Secretariat, the RA1a
regression (the nine Admin-only addresses), Followup Cancel, a 1366 px window, and real Print, Export to Pdf
and Export to Word of a draft; the error log was clean and PageAccessLog.txt showed the expected lines. Two
Low findings of that test are in the change log (RA1b).

### Step 42 (UN6b): Dashboard meetings

Database/BMMS-Test-DashboardMeetings-Step42.sql (BMMS_Test only; refuses the name BMMS and any name that does not
start with BMMS; stops when step 42 is not installed). Part 1 only reads: the five markers, the parameters (7 with 4
OUTPUT for spr_GetDashboardMeetings, 3 with 2 OUTPUT for spr_GetDashboardDepartments), the result columns in order,
that spr_GetScheduleMeet is unchanged (still the GETDATE() rule, no step 42 marker) and that on this database every
agenda item is in one of the groups approved, rejected or in progress. Part 2 runs in one transaction that is
rolled back, with made-up departments, users, committees, meetings and agenda items (ZZ42...):

- the colour rules of fn_MeetingDashboardState on fixed dates, in their order (grey, red, green, orange, blue); a
  meeting dated today is scheduled and not red; the submission date itself is still open; a meeting with no date
  is scheduled;
- fn_UserDepartmentScope (open rows and the home department; a closed row left out; a user without history rows
  gets the home department) and fn_AgendaStatusGroup (the four groups add up to all items);
- spr_GetDashboardMeetings: who may call it (the six roles; another role, an inactive, unknown or missing user
  refused); every scheduled meeting ordered by date; the last 10 completed meetings, newest first, for every role
  (13 completed test meetings: exactly 10 shown, with one committee and with all committees); for a Manager and a
  User only completed meetings with an item of their department(s); the statistics per role and department filter;
  NULL statistics for MD Secretariat and Admin; the refused filters;
- spr_GetDashboardDepartments (a Manager's departments, home first; a User's department; another role and an
  inactive user refused);
- rows outside the test unchanged after the rollback, and every identity counter put back.

Result on BMMS_Test (owner's run for UN6b): 71 of 71 PASS. Its first version stopped at test 7 (error 547,
CK_User_Department_Closed: the Manager's closed department row had no ClosedOn, ClosedBy and CloseReason); the
test data now has CloseReason 'C'. The owner's other checks passed: all six role views, the widths 1366, 1024, 900
and 800 px, the Agenda Alert and Action Item Details panels, the counts after Approve and Reject, the compact
Alerts card, the failure test and the timeout test. Step 42 replaces nothing, so no older Test script is changed.

### Step 43 (UN6c1): Dashboard alerts and action items

Database/BMMS-Test-DashboardAlerts-Step43.sql (BMMS_Test only; run it in a new query window). 128 numbered
checks, all passed in the owner's run. It covers: every alert type with an old and a young read alert and the edge
of the seven days; the person and event date per alert type, with an ordinary approval (30 seconds between the two
dates) and an edit after the decision; Recent, Unread, All, paging and the header count; the role filters; the
Admin and the system account (empty list, count 0); the mail recipient lists per branch (no Admin); Remove (own
row, another user's, unknown); that spr_UpdateAlertByUserId marks one user's row only; the Action Items card on
made-up rows per role (Controller, Management, a Manager with two departments, a Manager with one, a User, a User
of a department without items, MD Secretariat and Admin refused with Reason 4, an inactive, a missing and an
unknown acting user Reason 8; an item of a third department; an item with open minutes shown only to Controller and
Management; a confirmed item gone; a stale mapping row that shows nothing); the read state per person and the four
conditions of IsOverdue; opening an item (one row created, none at the second opening, an outside item Reason 4 and
no row, Management's opening leaves the item unchanged); saving the action text (Controller, Manager and User
inside their scope; Management, MD Secretariat, Admin, another department, open minutes for a User and a confirmed
item refused; only the text is written); that every database user who can run the step 42 procedure can run the
eight of step 43; and the Rollback's two texts installed inside the test's transaction and compared with the saved
originals. The Fix, Rollback, Fix sequence was checked on BMMS_Test.

## The tester (steps WF3a1 and WF3a2)

Step WF3a1 added the infrastructure of a tester. Step WF3a2 added the first real pack (the access
matrix, described in "The access-matrix pack (step WF3a2)"), the tester stage in the development
workflow (CLAUDE.md, step 5) and closed the four security Lows of WF3a1. Neither step changed product
code, added a numbered database step or changed anything for a user.

### What it is

The tester runs fixed browser checks against a copy of the site on the development laptop and reports
pass or fail with screenshots. It never changes the product. It complements the owner's acceptance
tests and does not replace them: looks (borders, spacing, the printed page, a document opened in Word)
stay with the owner. The owner's guide to it is Tests/README.md; the design and the build report are in
Database/README.md, section "Step WF3a1". What the development machine needs is in
02-Development-Environment ("The tester: what the development machine needs").

| Part | What it is |
|---|---|
| Database | BMMS_Quality only: a restore of BMMS_Test made for the tester, cleared with the application's Reset Database procedure, then a fixture, then a baseline backup (BMMS_Quality_baseline.bak) that is restored at the start of every run. The tester never uses BMMS or BMMS_Test; the name BMMS_Quality is a constant in Tests/_runner/Tester.Common.ps1, and every sqlcmd call goes through one function that accepts BMMS_Quality only (and master for the one RESTORE statement) |
| Site | A copy of the working tree in Tests/_site, rebuilt (MSBuild into Tests/_build, so bin and obj are untouched) and re-synced at every run, served by IIS Express on http://localhost:18573. The owner's own site (port 49573, BMMS_Test) is not touched |
| SQL logins | Two, made by the setup. bmms_tester owns BMMS_Quality; the runner restores and checks as this login. bmms_site is the site copy's login: a user in BMMS_Quality with db_datareader, db_datawriter, db_backupoperator and EXECUTE on the dbo schema. Neither has a server role or access to any other database. Before every run the runner asks the server, as each login, what it can reach, and refuses when that is more than BMMS_Quality (any other database, BMMS or BMMS_Test, a server role, CONTROL SERVER, IMPERSONATE). Since WF3a2 the server permissions are an allow-list: in effect only CONNECT SQL and VIEW ANY DATABASE, and granted to the login only CONNECT SQL, otherwise the run is refused; the check is made again after the restore (Run-Tests.ps1), and Update-Baseline.ps1 makes it after the Fix scripts and before the baseline backup. The application login bmms_app is not used |
| Browser | The installed Chrome, headless, driven by Node scripts (playwright-core). Requests to any host other than localhost are aborted and listed |
| Mail | BMMS_Quality has the safe default (localhost, port 25); no real mail can be sent |
| Packs | One folder per pack under Tests/packs (pack.js and data files). The packs are selftest (WF3a1), access-matrix (WF3a2), dashboard (UN6b) and followup (UN6d). A pack is Node code: it is written in a step's build and reviewed there, and the tester cannot change it |

### How it is run

From the repository folder, in PowerShell 7:

- `pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -CheckOnly` - no checks run; it proves that the
  site copy is the current working tree and on BMMS_Quality, that the baseline is current and the
  fixture intact.
- `pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack [name]` (several: `-Pack a,b`) - the
  self-test always runs first, then the packs.
- For the owner only: `-LeaveSiteRunning` leaves the site copy on port 18573 after the run, to look at
  the fixture by hand; `-StopSite` stops it and does nothing else; `-Pack access-matrix -ProofFullMatrix`
  runs the standing proof of the access matrix over every row (see below). The tester agent's guard
  allows none of them.

Every run, in order: preflight (since step UN6b it starts with the memory reading, below; then the two logins
asked what they can reach); build of the working tree and
mirror to Tests/_site; proof that the copy is current; the copy's connection string written from fixed
parts (the local server, BMMS_Quality, the login bmms_site; BMMS/connectionStrings.config is not read)
and proved; restore of the baseline as bmms_tester; the fixture dates set again, relative to the day;
refusal unless every row of Database/BMMS-Check-InstalledSteps.sql reads Installed and the fixture check
passes; IIS Express started; sign-in as the fixture Admin and a check that the footer reads
"Database: BMMS_Quality"; the self-test and the packs; results written to Tests/_results/[date_time]/
(results.md and results.json, screenshots of every failed and planted check, the new lines of the site
copy's page access log and error log, installed-steps.txt, fixture-check.txt).

The memory reading (step UN6b, owner decision of 2026-11-12). The preflight reads the machine's available memory
(Task Manager's "Available") through `Get-QaMemory` in Tests/_runner/Tester.Common.ps1, from the CIM class
Win32_PerfFormattedData_PerfOS_Memory, else from Get-Counter; it never stops a run. It prints "Memory: [n] MB
available of [m] MB." and, below 1500 MB (`QaMemoryWarnMB`), "WARNING (memory): ..." and the run goes on: it is
never a refusal. results.md has a line "Memory at the start: ..." (with "warning: below 1500 MB" when low). A run
that ends VOID or RUNNER FAILED reads the memory again, and its summary says when it was low at the start or the
end ("The machine was low on memory ...", which may be the cause). Why: on 2026-11-12 a starved machine (SQL
Server memory grants waiting, 711 MB available of 7.9 GB) made the Dashboard's Meetings card show "could not be
loaded" for a Manager and a User, which looked like a product fault (Database/README.md, section Step UN6b, Finding
A). The reading on the run of 2026-11-12 21:46:42 was 1522 MB available of 7886 MB.

A run restores BMMS_Quality, so windows open on BMMS_Quality in SQL Server Management Studio are
disconnected at the start of every run. Windows on BMMS_Test are not affected. A run of the self-test
alone takes about 20 seconds.

### The result words

| Result | Exit code | Meaning |
|---|---|---|
| PASSED | 0 | Every check gave what was expected, the self-test caught its planted failures, and the error log has no new line |
| FAILED | 1 | A check did not give what was expected, or the error log has new lines, or a request to another host was stopped |
| REFUSED | 2 | The runner would not start; nothing was tested. The first line gives the reason (for example: the baseline is out of date, the fixture script changed since the baseline, a tester login can reach more than BMMS_Quality, port 18573 in use, the build failed) |
| VOID | 3 | The self-test did not catch its planted failures, the access matrix's standing proof failed (or the site copy's PageAccess.xml was not put back), a pack broke off, or the browser part stopped; no result of that run counts |
| RUNNER FAILED | 4 | The tester itself broke; nothing can be said about the site |
| READY | 0 | Check only; no pack was run |

### The self-test

Every run includes the pack selftest: three true controls, one log control, one sign-in control and
three deliberately wrong expectations that must fail. The three planted failures are shown in the
results as "caught (planted)" and are not failures. If one of them comes out as a pass, the result is
VOID: the tester could not tell a failure from a pass. Build result of WF3a1: selftest PASSED, 5 checks,
3 of 3 planted failures caught.

### The fixture and the baseline

BMMS_Quality holds only the seed rows of Reset Database and the fixture (Tests/fixture/):

- BMMS-Quality-Fixture.sql stops unless the database is exactly BMMS_Quality and in the cleared state. It
  creates nine accounts through the application's own procedures as the seeded Admin (qa_admin, qa_ctrl,
  qa_manager, qa_manager2, qa_user, qa_user2, qa_mgmt, qa_mdsec, qa_inactive; login names and passwords
  have at most 12 characters because the sign-in page takes no more), the committee QA1 with a Chairman
  and a Member, and six meetings 00001 to 00006 in the states agenda open, submission date passed, agenda
  finalised, minutes in Draft, minutes Finalised (with a Followup and its action item) and minutes
  Confirmed. Since step UN6b it also creates the committee QA2 ("QA Dashboard Committee"): twelve meetings
  (00001 dated today with no items; 00002 to 00012 completed, with Credit items, 00003 with a Secretarial item
  only) and twelve agenda items, so that every role whose scope allows it has more than ten completed meetings
  and the cap of 10 shows. All nine accounts existed already (qa_user2 is an active HRD User). Saving QA2 writes
  its Committee alert, so every account but qa_ctrl has one alert more than before. It is one transaction. The
  fixture is not a numbered step and has no row in BMMS-Check-InstalledSteps.sql.
- BMMS-Quality-Fixture-Dates.sql sets the two date columns of the meetings relative to today after every
  restore (since UN6b the QA2 meetings too).
- BMMS-Quality-Fixture-Check.sql is read only: 29 checks before UN6b, 32 after it, 35 since step UN6c1, 38 since
  step UN6c2a, 39 since step UN6c2b (committee QA9, inactive), ending "FIXTURE CHECK: PASS (n checks)".
- Step UN6c2a extended the fixture again: two items on QA2 00001 as direct rows with no alerts (QA2-00001-1, Credit,
  at AMA, which waits for the Controller; QA2-00001-2, Secretarial, at AC, saved by qa_ctrl, so not routed to
  anybody), and the meeting QA2 00013, 40 days back with its agenda still open, with its item QA2-00013-1 (Credit, at
  AC, saved by qa_user, so routed to qa_manager) and its Agenda alert for qa_manager only, already read (the
  item of a passed meeting that its Manager could have decided). QA2 now has thirteen meetings and fifteen items;
  Tests/_runner/Setup-Quality.ps1 still prints the older "twelve meetings and twelve agenda items" in its closing summary.
- Step UN6c1 extended the fixture: three Followups (two on QA1 00005, one on 00006; before, one), three alerts read
  by qa_user, item QA1-00005-001 without a recorded approver; the dates script sets every alert date and the three
  due dates relative to the day of the run; for the scope of the Action Items card QA1-00006-001 keeps the mapping
  row of qa_user only and two Followups are added on QA2 (QA2-00003-1, Secretarial, minutes finalised, mapped to
  qa_ctrl only; QA2-00002-1, Credit, minutes in draft, mapped to qa_user only).
- The test account passwords are generated at setup, hashed with the application's own hash function and
  kept only in Tests/local/credentials.json (not committed).

The baseline is built once by Tests/_runner/Setup-Quality.ps1 (run with the owner's Windows login, with
-ConfirmDatabase BMMS_Quality; BMMS_Quality must first have every step installed and bmms_app linked with
its three roles): clear with the Reset Database procedure, create the two logins, build the fixture, write
the credentials file, take BMMS_Quality_baseline.bak in the server's backup folder and restore it once as
bmms_tester as the proof. It ends with the list of what it changed on the server. The user bmms_site
stays linked through every restore because the baseline holds it with the identity (SID) of the server
login and the setup never drops the login (a second run only changes the password).

### Upkeep after a new database step

After a numbered database step (step 42 and on) the baseline is out of date and every run is refused
("out of date") until it is taken again; step 42 (UN6b) was the first such step: its Fix script was installed in
the baseline with Update-Baseline.ps1, then BMMS_Quality was built afresh with the extended fixture
(Setup-Quality.ps1, 2026-11-12). Step 43 (UN6c1) was done the same way: Update-Baseline.ps1 -FixScript, then
Setup-Quality.ps1 with the extended fixture. Step 44 (UN6c2a) likewise: the tester run of 2026-11-14 ran on the
baseline with step 44 and the extended fixture. Step 45 (UN6c2b) likewise, with the fixture committee QA9 added
to the fixture (the fixture check has 39 checks). In the workflow this is done on the owner's approval of the
build, before the tester runs (CLAUDE.md, step 5):

`pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-[name]-Step[n].sql`

It works as bmms_tester, never as the sysadmin login: it restores the baseline, runs the Fix script
(only a file named BMMS-Fix-[name].sql from Database/; a script with USE or a sqlcmd command such as
:connect, :r or !! is refused before anything runs, so the older Fix scripts that contain USE [BMMS] are
refused), checks that the connection is still on BMMS_Quality, runs the fixture check and the Check
script, and takes the baseline again. If any part fails the old baseline stays. When the fixture script
changes, run Setup-Quality.ps1 again instead. The "out of date" refusal itself was not exercised in
WF3a1 (it needs a step 42). The Node packages are installed once per machine with `npm ci` in the Tests
folder (needs the internet; nothing else in the tester does).

### The tester agent

`.claude/agents/tester.md` defines a subagent (tools Read and Bash) confined by the guard hook
`.claude/hooks/tester-guard.ps1`, declared in its frontmatter. It may run only the runner
(`Run-Tests.ps1 -CheckOnly` or `-Pack [name][,[name]...]`, each written exactly so) and
`git status --short` (also with `--ignored` and `--untracked-files=all`). It reads only files inside
Tests/_results/; Tests/local/ and every connectionStrings.config are out of reach whatever way a path is
written (an allowed list; paths that start with a backslash or a double slash, that have a colon after
the drive letter or that contain a tilde are refused). It has no Write or Edit tool, no Grep or Glob and
no sqlcmd. The hook fails closed (its command ends with `|| exit 2`). It returns a fixed record (run
folder, result word, the three proofs, checks, failed checks with screenshot, log lines, requests outside
localhost, working tree before and after). A failed check goes to the owner as it is; the agent never
proposes a fix and does not run a failed pack again. As with doc-writer, the main session also compares
`git status --short --ignored` before and after. Since WF3a2 its record also has the access-matrix
line, the standing proof and the cells for the owner to decide; a cell "owner to decide" counts as
failed. Until step RA1c2 a note word ("to be removed (RA1c1)", "to be decided (RA1c2)") was counted
under notes only; no cell uses a note word now and the pack no longer accepts them.

The tester stage in the workflow (CLAUDE.md, step 5; 02-Development-Environment, "The development
workflow"): after the fixes of the reviewers' findings and before the owner's tests, the main session
runs the tester agent with the step's packs, always at least access-matrix. A step with a new
database script first brings the baseline up to date with Tests/_runner/Update-Baseline.ps1, on the
owner's approval of the build. A failed check goes to the owner as it is, with the main session's
reading of it (product, expected result or fixture); no product code, test or expected result is
changed to make it pass without the owner's word, and the tester never writes or changes a test, a
pack or an expected result. A REFUSED, VOID or RUNNER FAILED result is reported, and the tester is
run again once the cause is removed. Every plan lists its browser checks in two sets, "tester" and
"owner by eye" (looks, print, Word, PDF layout), and the report to the owner has the tester record
verbatim as its part 6.

## The access-matrix pack (step WF3a2)

The pack proves, on every run, that what each role can open matches the owner's access rules, and it
fails when it does not. The rules, their short names and the cells decided by the owner are in
Tests/packs/access-matrix/README.md; this section says how the pack is built and run.

| File | What | Who changes it |
|---|---|---|
| expected.csv | One row per address (55 since step RA1c2, which removed the Error/TestPage.aspx row; 56 after step RA1c1; 60 before RA1c1 removed Event Calendar and Report Print), one column per role (admin, controller, manager, user, mgmt, mdsec, inactive, and visitor, a browser that is not signed in), and the rule each row comes from. Each cell is opens, Access denied, sign-in page or Page not found (or "owner to decide", below) | The owner, or Claude on the owner's instruction; never the tester. Drafted from the owner's access rules, not generated from PageAccess.xml; approved by the owner and checked in |
| not-in-menu.csv | Pages a role can open without a menu link, a reason per row | The owner (an approved list) |
| home-link.csv | Which roles have the Home link: Management has it; Admin and MD Secretariat do not | The owner |
| planted.json | The one change the standing proof makes | Claude, in a reviewed step |
| pack.js | The checks | Claude, in a reviewed step |

What the pack checks, in order:

1. The files are complete: every cell is one of the allowed words, every row has a rule, every row of
   not-in-menu.csv has a reason, no address twice.
2. Every .aspx page on disk is in expected.csv or in PageAccess.xml; a page in neither fails the run.
3. Agreement: each decided cell is compared with what PageAccess.xml lets through; a difference is a
   failed check for the owner to decide (the XML or the cell). On the rows that narrow the XML's roles
   by their own check (page_rule RA1b) only a cell that opens where the XML refuses counts.
4. The matrix: each role signs in and opens each address (Logout last); what comes back and the lines of
   the page access log (one DENIED line for that user and page for a refusal, none otherwise) are
   compared with the cell. qa_inactive cannot sign in ("Your account is inactive"), so its column is the
   visitor's.
5. The menu: each role's links are read on the Dashboard. Every link must be an address in expected.csv
   that opens for that role; every page a role opens must have a link or a row in not-in-menu.csv; a row
   there that no longer applies fails; the Home link must match home-link.csv.

The standing proof (the proof that the pack can fail). Before the matrix, on every run, Run-Tests.ps1
changes one entry of PageAccess.xml in the site copy only, Tests/_site/XML/PageAccess.xml, never in
the working tree: it adds the role user to Report/MeetingCalendar.aspx (planted.json). It runs the two
rows of planted.json for every column; exactly one cell must come out different, qa_user on Meeting
Calendar ("Access denied" expected, "opens" seen). The change is undone in a finally block. At the end
of the run the hash (SHA-256) of Tests/_site/XML/PageAccess.xml is compared with the working tree's
file, and the run is VOID if they differ, or if the proof gave any other result. -ProofFullMatrix (owner
only) runs the proof over every row; the one-time full proof of 2026-11-11 changed exactly one cell.

No notes are left (step RA1c2). The two note words "to be removed (RA1c1)" and "to be decided (RA1c2)" are
retired: the first was used for Report/EventCalendar.aspx and Report/ReportPrint.aspx until RA1c1 removed the
pages, the second for Report/FollowupActionTaken.aspx until RA1c2 decided it. The only special cell word left:

| Cell word | Meaning |
|---|---|
| owner to decide | No written rule decides the cell; it counts as failed until the owner decides it. None at present |

Report/FollowupActionTaken.aspx ("Followup by Department") is expected to "open" for the Controller and to give
"Access denied" to the Manager and every other role (decided by the owner, option A; Controller only).

Report/ViewReport.aspx opened directly (no report kind) is expected to "open" for the Controller and the
Manager (the page shows "The report is no longer available. Close this window and click Generate again.")
and "Access denied" for Management. Until step RA1c1 the Controller and the Manager got HTTP 500 and the
pack failed those two cells (a product defect, recorded in Database/README.md); step RA1c1 fixed it. The two
Page-not-found rows (Master/NoSuchPage.aspx, Images/no-such-file.png) are kept as observed, and the
drafting rule D0 (a role has a page only when a written rule gives it) is confirmed by the owner.

results.md of an access-matrix run adds the sections "Access matrix" (one line per address, one column
per role), the notes, "Cells for the owner to decide", "Other notes for the owner" and "Standing proof
of the access matrix", and a line "Firewall" (see "Limits").

Result of the step (tester agent, run of 2026-11-11, Tests/_results/2026-11-11_215849): FAILED on exactly
the two ViewReport.aspx cells (Controller and Manager: expected "opens", seen HTTP 500). 501 checks, 499
passed; self-test 3 of 3 planted failures caught; access matrix 464 cells, 444 ok, 2 failed, 0 owner to
decide, 18 notes; standing proof holds; no request outside localhost. Run time 170 s (measured runs
158 to 216 s; about 510 page requests; most of the time is the site's first requests, which compile the
pages). The plan's aim was about two minutes; Tests/README.md says about three minutes. The owner's tests
of WF3a2 passed on 2026-11-11 and the expected files are approved.

Result of step RA1c1 (tester agent, `-Pack access-matrix`, Tests/_results/2026-11-11_230233): PASSED, all
485 checks; access matrix 448 cells, 446 ok, 0 failed, 2 notes (Followup Action Taken for the Controller and
the Manager, to be decided in RA1c2); standing proof holds; no new line in the error log; 202 s. The
tester agent's command timeout is now 10 minutes (the Bash tool's timeout set to 600000, not in the
background), because an access-matrix run takes about 4 minutes; the guard is unchanged. The tester's
results-folder file (Tests/_results/latest.txt, so that the agent can find its results folder when its
command moves to the background after 180 s) is a later step, not part of RA1c1. The owner's tests of
RA1c1 passed on 2026-11-11.

Result of step RA1c2 (tester agent, `-Pack access-matrix`): PASSED, all 477 checks passed, 0 notes; the pack has
55 addresses. The owner's tests of RA1c2 passed. The run folder and the run time are not recorded here.

### Limits

- Never BMMS, never BMMS_Test.
- No real mail; nothing listens on port 25 unless smtp4dev is set to it.
- No judgement of looks, print or Word; not a security audit.
- A pack is Node code with the owner's rights; the localhost-only rule covers the browser's requests
  only. Every pack must be reviewed as code in the step that adds it.
- No retry: a check that fails once is reported as failed.
- While the site copy runs, port 18573 listens on this laptop (on the local loopback and on all IPv6
  addresses, seen on 2026-11-11). Since WF3a2 the site copy runs from the runner's own IIS Express
  configuration (Tests/_build/iisexpress/applicationhost.config, made from IIS Express's template at
  every start), which lets in only callers on this laptop (the loopback addresses; the IP restriction module); this configuration is
  localhost-only. At every start the runner asks the site copy through each network address of the
  machine, with that address and with "Host: localhost" as host name, and stops unless both are refused
  (no connection, HTTP 400 or HTTP 403). The runner also reads the Windows Firewall at every run: an
  enabled inbound rule that lets traffic in for IIS Express, System or any program on port 18573, or a
  profile that is off, is printed as a warning in the console and in results.md ("Firewall"); it is not
  a refusal. -LeaveSiteRunning is refused only when a profile lets inbound traffic in by default. The
  runner changes no Windows rule. On the development laptop on 2026-11-11 the one warning is the rule
  "WFD Driver-only (TCP-In)". These guards test from this machine; they are not a test from another
  machine (Tests/README.md gives the owner's step). Do not leave the site running on a network you do
  not trust.
- The four security Lows of WF3a1 (allow-list of server permissions, role check timing, read-back of the
  icacls permissions on the site copy's connection file before the password is written, reachability)
  are closed in WF3a2. Other open items are in Database/README.md, "Known items for later steps".
- Facts found about the product while building, recorded in Database/README.md: the sign-in page takes at
  most 12 characters for User ID and password; Error/TestPage.aspx was an unlisted leftover page that
  every role was refused (removed in step RA1c2); PageAccess.xml had 46 page entries and the site 47 pages (44
  and 45 after step RA1c1 removed Event Calendar and Report Print; 43 and 44 since RA1c2 removed TestPage).

Result (owner's tests of step WF3a1, 2026-11-11): passed. Build checks: Setup ran to the end (fixture
check 29 of 29); Run-Tests.ps1 -Pack selftest PASSED; -CheckOnly READY; -LeaveSiteRunning and -StopSite
worked; Update-Baseline.ps1 ran with the re-runnable Fix script of step 41; the guard blocked every
forbidden command, tool and path form tried.

## The dashboard pack (step UN6b)

Run with `-Pack dashboard` (Tests/README.md; about two and a half minutes). It proves on every run that the
Dashboard's Meetings card shows each role the meetings, colours and statistics of the owner's rules (Database/README.md,
section Step UN6b), that the Alert and Action Item lists still show what they showed, and that the page fits the
window. Its own README is Tests/packs/dashboard/README.md.

| File | What | Who changes it |
|---|---|---|
| expected.json | The cases (12: Controller on all committees, on QA2 with exactly 10 completed rows shown, and on QA1; Management; MD Secretariat; Admin; the Manager with one department; the Manager with two departments on all, on HRD and on Secretarial; the User of Credit and the User of HRD), each with the account, the filter chosen, the drop-downs, the subtitle, the card title, the last column header, whether statistics are shown and the Scheduled and Completed rows; the first-page row counts of the Alert and Action Item lists; the two headings of the Alerts card; the window widths | The owner, or Claude on the owner's instruction (the build report lists it under "expectations changed"); never the tester |
| pack.js | The checks | Claude, in a reviewed step |

A row is `committee | meeting number | colour | label | Items Approved Rejected Pending`; the colour is the class of
the status chip, the label its text, and the four counts only where statistics are shown. For MD Secretariat and
Admin the shared lists are compared without the counts, and the pack also checks that no statistics word (Items,
Approved, Rejected, Pending, In progress) is anywhere in the Meetings card. Scheduled rows are by meeting date,
oldest first; Completed rows newest first, at most 10 for every role.

What the pack checks, in order:

1. Each case: no message, the card title, the subtitle, the drop-downs, the column headers, the Scheduled and
   Completed rows in order, the empty texts, the dates in dd-MMM-yyyy.
2. The Alert and Action Item lists: the number of rows on their first page per account (an Alerts row is a compact
   row: the Source link with the alert type, committee and department below it).
3. The inactive account is refused at sign-in; a visitor who opens the Dashboard ends on the sign-in page.
4. At 1366, 1241, 1240, 1024 and 800 px (qa_manager; 1241 and 1240 since step UN6c2a): the page is no wider than
   the window and the content area does not scroll sideways; the Meetings and Alerts cards side by side at 1366 and
   1241 px and stacked at 1240 px and below (the breakpoint was 1100 px until step UN6c2a); the same width check
   with the Agenda Alert panel open (qa_manager) and the Action Item Details panel open (qa_user). At each width the
   Alerts card (qa_manager): the headings "Alert" and "Created on" whole and the grid no wider than its card; every
   date dd-MMM-yyyy with HH:mm below it, on at most two lines.

The data is the fixture (see "The fixture and the baseline"): QA1 has meetings 00001 Open for submission, 00002
Submission closed and 00003 Agenda finalised (scheduled), 00004 Minutes pending, 00005 Minutes finalised and 00006
Minutes confirmed (completed); QA2 is described there. The pack cannot see looks, colours or print: those stay in
the owner's checks by eye.

Result of the step (tester agent, run of 2026-11-12 21:46:42, Tests/_results/2026-11-12_214642, packs access-matrix
and dashboard): PASSED, 649 checks, no new error-log line; memory at the start 1522 MB available of 7886 MB. The
owner's tests of UN6b passed. The tester agent could not read its own result when the run moved to the background
(a later step, WF3a3; Database/README.md, Known items).

### The dashboard pack since step UN6c1

The pack (Tests/packs/dashboard/README.md) gained checks 5 to 8 and 225 checks in all; expected.json gained
`alertHeader` (the header count per account), `alertModes` (the three links for one account), `alertActors` (the
person named on some alerts), `actionItemsDue` (the due dates), `alertActions` and `filterKept`, `actionScope` and
`actionItemsList` (the Action Items card per account). The Alerts card heading is "Date" now.

- Alerts card rules (qa_user): Recent, Unread and All with their row counts and the second page of All; the person
  named on an alert with the login ID as tooltip and a dash where no approver is recorded; the header count unchanged
  by the links and no page reload; the Admin: no rows, "No alerts." and "Alerts (0)".
- Action Items card: the due date and the word "Overdue" on one item only; the items per account (Controller and
  Management every item that is not confirmed; Manager and User the items of their departments with finalised or
  confirmed minutes; MD Secretariat and Admin no card).
- Actions (last, they change data; BMMS_Quality is restored before every run): opening an alert lowers the header
  count by one; "Remove from my list" takes the row out, also under All; another user's row id put into the page is
  refused with "This alert is not in your list."; the link chosen stays chosen on both cards when an item or an
  alert is opened under Unread; an item with no mapping row is unread and read after opening, for that person only;
  Management's Submit is refused; a Submit with another department's item id is refused.
- Changed expected values, each with its cause: alertsFirstPage of the Admin 10 to 0 (no functional alerts for the
  Admin role); alertHeadings "Alert, Created on" to "Alert, Date"; actionItemsFirstPage of all eight accounts was 1; it is now by the scope
  rule (controller 5, manager 3, manager2 1, user 3, user2 0, mgmt 5; admin and mdsec: no card), and the fixture has
  more Followups.
- Not in the pack: Approve and Reject (they send mail; the tester has no mail server) and the "could not be
  loaded" messages (a pack has no database access to deny EXECUTE); these are the owner's checks.

Result of the step: tester agent, run of 2026-11-13: PASSED, 702 checks (selftest 8, access-matrix 472, dashboard
225; fixture check 35). An earlier run of the same day was VOID: once, in the standing proof of the access matrix,
Report/MeetingCalendar.aspx answered HTTP 500 to the User on the first requests after the site copy started; the
repeat PASSED and it was not reproduced (Database/README.md, Known items). The owner's tests passed.

### The dashboard pack since step UN6c2a

The pack (Tests/packs/dashboard/README.md) gained checks 9 to 11 and 274 checks in all; expected.json gained
`approvals`, `approvalFilters` and `approvalOpen` (My approvals), `waiting` in the cases of qa_ctrl, qa_manager and
qa_manager2 (the Waiting for me column), `meetingsFit` (account, window width and number of columns of the fit check)
and `pastItem` (the meeting-date message).

- My approvals (check 9): the panel per account and its rows, newest meeting first; no panel for qa_user, qa_user2,
  qa_mgmt, qa_mdsec and qa_admin. With committee QA Dashboard Committee chosen qa_ctrl sees QA2-00001-1 only; qa_manager2
  with HRD chosen sees his item, with Secretarial chosen "Nothing is waiting for your approval." (QA2-00001-2 is
  Secretarial and at AC but not routed to him). qa_ctrl opens QA1-00001-002 from the panel: the Agenda Alert panel
  with Approve and Reject, his alert of that item read (header from 1 to 0, no page reload), the row still in the
  panel. qa_user opens his alert of QA1-00001-003: no Approve and no Reject. Check 1 also checks the Waiting for me
  column for qa_ctrl, qa_manager and qa_manager2, and that the column is not there for the other cases.
- The Scheduled list fits its card (check 10): qa_ctrl and qa_manager (nine columns) at 1366 and 1600 px, qa_mgmt
  (eight columns) at 1366 px: the cards side by side, the number of columns, the table no wider than its scroll box,
  no empty gap at its right (1 px allowed), and the heading "Waiting for me" on at most two lines.
- The meeting-date message (check 11, last, because opening an item from My approvals marks qa_manager's alert of it
  read): qa_manager opens the alert of QA2-00013-1 (on the last page of All): no Approve and no Reject, the message
  "The meeting date has passed, so this item can no longer be approved or rejected. It will be rejected when the
  agenda is finalized." inside the panel at most 40 px above the buttons and not covered; then QA1-00001-001 from My
  approvals: Approve and Reject and no message.
- The fixture grew (see "The fixture and the baseline"): two items on QA2 00001 and the passed meeting QA2 00013.
  Fixture check 38 of 38. Statistics of QA2 00001 follow the new items (2 0 0 2 for all departments).
- Not in the pack: Approve and Reject themselves (mail), the "could not be loaded" messages (no database access).

Result of the step: tester agent, run of 2026-11-14 07:52:25 (Tests/_results/2026-11-14_075225): PASSED, all 751
checks (selftest 8, access-matrix 472 with 440 cells ok, dashboard 274); fixture check 38 of 38; the baseline was
the one with step 44. New checks passed: the cards side by side at 1241 px and stacked at 1240 px; the Scheduled list
fits its card for the Controller and the Manager (nine columns) at 1366 and 1600 px and for Management (eight columns)
at 1366 px; qa_manager opening the item of a passed meeting (QA2-00013-1) gets no buttons and the message inside the
panel; an item he can decide shows the buttons and no message. Measured: the Meetings card 864 px wide, its table
needs 793 px with the widest realistic cells in an 830 px box (37 px spare). The owner's tests passed.

### Step 44 (UN6c2a): approval rule, My approvals and Waiting for me

Database/BMMS-Test-AgendaWaitingFor-Step44.sql (BMMS_Test only; run it in a new query window; it refuses the name
BMMS and any name that does not start with BMMS, and stops when step 44 is not installed). One numbered row per
check, a summary row (Passed, Failed, Skipped); the row about the login itmgruser reads SKIPPED in a database
without that account. 120 checks, all PASS (run of 2026-11-14 on BMMS_Test). Part 1 reads only: the markers (the five of step 44 and
the markers of the earlier steps that the two replaced procedures keep), parameters and result columns, that the
objects step 44 does not change carry no marker, that no EXECUTE is denied, and that every database user who can run
step 42's procedure can run the four procedures of step 44. Part 2: on the data of the database, read only, for
every active user and every agenda item the function gives what the rule of step 20 gives; then, inside one
transaction that is rolled back, with made-up data (ZZ44): the earlier text of spr_UpdateAgendaByAgendaId installed
under a temporary name and both procedures run on the same 1352 cases (13 kinds of acting user x 13 items x 8 action
words; the script expects 32 allowed, and refusals with Reason 14 688 times, Reason 12 104, Reason 8 312, Reason 5
144 and Reason 4 72), where Result, Reason, ReasonDetail and everything written must be the same in every case; named
cases (among them a Manager whose alert row was removed from his list still approves; a Manager of the same department
who is not routed is refused; the Controller approves at AMA and rejects at AC but cannot approve at AC; the system
account Reason 12; the procedure still approves an item of a past meeting, as before); the items of the departments
of itmgruser that are not routed to him, each refused with Reason 14; the function's flags; the approval state; the
meeting list with the earlier text beside the new one (every column of before unchanged) and WaitingForMe; My
approvals by role, filter and page; and the Rollback's two texts installed inside the transaction and compared with
the texts step 44 was built from by SHA-1. Afterwards nothing of ZZ44 is left, the agenda and alert tables are
unchanged and every identity counter is put back. The Fix, Rollback, Fix sequence was checked on BMMS_Test.
BMMS-Test-DashboardMeetings-Step42.sql was adjusted in three places (its checks of the parameter count and of the
result columns of spr_GetDashboardMeetings, and its own result table, each marked "Replaced by step 44"): it
expects the step 44 shape when step 44 is installed and the step 42 shape otherwise, 71 checks either way.
BMMS-Test-DashboardAlerts-Step43.sql passes unchanged (128).

### Step 45 (UN6c2b): summary cards and the Committee filter

Database/BMMS-Test-DashboardSummary-Step45.sql (BMMS_Test only; run it in a new query window). 66 numbered checks, all
PASS (run of 2026-11-14 on BMMS_Test). Part 1 reads only: the markers (new and kept), parameters and result columns;
that fn_AgendaStatusGroup and fn_DashboardActionItems are unchanged (SHA-1); that no feature above compatibility
level 100 is used; EXECUTE for every database user who can run step 42's procedures; the condition of the step 44
Rollback's guard. Part 2, inside one rolled-back transaction with made-up data (ZZ45: three departments, the six roles,
an inactive user, an active, a second active and an inactive committee, meetings today, later, without a date and
past, 147 items in every status, 6 action items): the committee function; 26 fixed summary cases (counts, filters,
Reasons 4, 8 and 12); for 320 cases (every active Controller, Management user, Manager and User x every committee value
x every department of the scope) the summary equals an independent count and the totals of the Scheduled list; 60
calls with an inactive, unknown or negative committee refused with Reason 4 by all four procedures; the MD Secretariat's
rows equal Management's, without Waiting for me, My approvals or Action Items; the earlier texts beside the new ones
on 730 cases each (meeting list: no difference but the MD Secretariat's statistics; My approvals: none; Action Items:
the earlier rows of the chosen committee and department); the Action Items called without the new parameters as in
step 43; the step 45 Rollback's three texts installed inside the transaction and compared by SHA-1.

The Test scripts of the earlier steps after step 45 (each change marked "Replaced by step 45" and applied only when
step 45 is installed; each passes with step 45 installed and with it rolled back):
BMMS-Test-DashboardMeetings-Step42.sql (71: the two MD Secretariat cases expect the statistics),
BMMS-Test-DashboardAlerts-Step43.sql (128: the parameter count of spr_GetDashboardActionItems is 5, 2 of them OUTPUT)
and BMMS-Test-AgendaWaitingFor-Step44.sql (120: its two comparisons of the meeting list with the step 42 text expect an
MD Secretariat user to have StatisticsShown 1). The step 44 Rollback refuses while step 45 is installed; run on
BMMS_Test with step 45 installed it refused and the checksum of all 204 module definitions was the same before and
after.

The dashboard pack since step UN6c2b (Tests/packs/dashboard/README.md): expected.json gained `inProgressMeaning`,
`inProgressMeaningWaiting`, `inProgressWaitingAccounts`, `summary`, `summaryFilters`, `alertsNote`, `inactiveCommittee`,
`summaryWidths`, `approvalsHeadingKept` and `tableFit`. Check 1 also checks the "In progress" header and its tooltip,
the MD Secretariat's statistics and the User's Committee drop-down. New checks: 12 (the cards per account, the
meaning of "In progress", Unread alerts equal to the header count, the note of the Alerts card), 13 (both filters on
every card), 14 (My approvals keeps its count through the postbacks; it failed 21 times on the build of step UN6c2a,
run 2026-11-14_221927, all other 277 checks passed), 15 (the inactive committee is offered to nobody), 16 (the cards
at 1366, 1280, 1097, 960 and 640 px) and 17 (the Meetings tables at narrow widths: qa_manager and qa_ctrl with a
simulated 17 px scrollbar at 1280, 1097, 960 and 768 px, and at 800 px without it; at least 24 px to spare). The
summary values come from an independent count of the fixture (qa_ctrl and qa_mgmt 6 in progress and 2 rejected;
qa_manager and qa_user 4 and 2; qa_manager2 2 and 0; qa_user2 1 and 0; qa_mdsec and qa_admin no cards).

The pack cannot put an inactive committee id into the Committee drop-down (ASP.NET's event validation rejects a value
the drop-down did not offer, which writes the error log and fails the run); the server's refusal is proven by the step
45 Test script (60 calls). The state of "My approvals (-)" on a failed or refused load cannot be reached by the tester
(no database access in a pack) and is an owner check.

The fixture grew by committee QA9 "QA Inactive Committee" (inactive; a direct row without members, meetings or alert,
so no account's alerts change); BMMS-Quality-Fixture-Check.sql has 39 checks (38 before).

Result of the step: tester agent, run of 2026-11-15 (Tests/_results/2026-11-15_003506): the dashboard pack PASSED, 388
checks. SQL Test script 45 passed on BMMS_Test and the Test scripts of steps 42 to 44 pass with and without step 45.
The owner's tests passed. This record states the dashboard pack only; the other packs of the run are not stated here.

### Step 46 (UN6d): the Followup saves

Database/BMMS-Test-FollowupSave-Step46.sql (BMMS_Test only; run it in a new query window). 56 numbered checks, all PASS
(run of 2026-11-15 on BMMS_Test). Part 1 reads only: the markers, the parameters, no result set, no feature above
compatibility level 100; spr_UpdateActionItem is still the step 31 text (SHA-1); the objects of steps 43 and 45 are
unchanged; EXECUTE for every database user who can run step 42's procedure. Part 2, inside one rolled-back transaction
with made-up data (ZZ46: one department, a committee, a meeting with finalised minutes, the six roles, an inactive
Controller, 17 action items with two mapping rows each): the Submit on six twin pairs against spr_UpdateActionItem row
by row (both ticks from every start of IsComplied and IsConfirmed, a mapping row already at StatusId 0): every column of
Action_Item and the mapping rows the same; the Action Text on a confirmed twin pair with a Unicode text, the same as
spr_UpdateActionItem; each role refused for both procedures (Manager, User, Management, MD Secretariat, Admin: Reason
4; the system account: 12; an inactive Controller, an unknown user, 0 and NULL: 8) with every ZZ46 row unchanged; the
Submit by the Controller refused as a whole, every row as it was, when one row is bad (an unknown item last of four and
first of four, an id given twice, a tick of 2 or missing, an id that is not a whole number, with a space, negative, too
large or of 11 digits, an element other than i, two roots, another root name, no list); the three good rows of those
lists alone saved; an empty list (Result 1, nothing written); the test's own transaction still open after the refusals;
the Action Text refused for an unknown and a NULL item; the Rollback's two DROPs inside the transaction. Afterwards the
agenda, minutes, action item and mapping tables are unchanged and every identity counter is put back. The Fix, Fix
again, Rollback, Rollback again (refused), Fix sequence was checked on BMMS_Test. The Test scripts of earlier steps pass
unchanged with step 46 installed: BMMS-Test-UnicodeText-Step31.sql (41), BMMS-Test-DashboardAlerts-Step43.sql (128) and
BMMS-Test-DashboardSummary-Step45.sql (66).

The followup pack (Tests/packs/followup/README.md; new in step UN6d; run with `-Pack followup`): `expected.json` holds
the read-only account (`readOnlyAccount`, qa_mdsec), the saving account (`saveAccount`, qa_ctrl), the five rows of the
list with the default filters (`rows`), the read-only line (`readOnlyLine`) and the two success messages
(`actionTextSaved`, `confirmedSaved`). Check 1, qa_mdsec: the page opens; after View the five rows, the read-only line
above the list, no Submit, every Is Confirmed tick disabled, "View" on every Action Text button; the Action Text panel
titled ":: View Action Text", no Save, a Close button, the line inside the panel; Close closes it without a message.
Check 2, qa_ctrl: after View the five rows, no line, Submit, ticks enabled, "Edit"; the panel ":: Edit Action Text"
with Save and Cancel and no line; Save with the text unchanged shows "The action text was saved."; Submit with the
ticks unchanged shows "The confirmations were saved." and every row keeps its tick. Not in the pack: a forged Save or
Submit for the MD Secretariat (the page does not render the buttons and ASP.NET's event validation refuses a post for a
control it did not render; the server's refusal is proven by the Test script), the failure messages and the too-long
message (owner checks). The Controller's Save and Submit write the values the fixture already has.

The dashboard pack since step UN6d (Tests/packs/dashboard/README.md): expected.json gained `actionScope.readOnlyLine`
and `actionScope.savedMessage`. Check 8 changed: qa_ctrl's Action Item Details panel has Submit and Cancel, no Close
and no line; qa_mgmt's panel has no Submit, no Cancel, Close and the line "You can read this action item. Your role
cannot change it." (before, its Submit was clicked and the server refused it; the server's refusal is still proven by
the step 43 Test script), and Close closes without a message; qa_manager2's Submit with another department's id closes
the panel and the list is read again (the message as before); his own Submit with Read chosen shows "The action text
was saved." as a success, with Read still chosen and the item listed (before: no message). The access-matrix pack's
expected.csv is unchanged (the page still opens for md_sect); the text of rule W6 in its README changed to say that the
MD Secretariat reads Followup only.

The tester's baseline: the new step needs `Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript
BMMS-Fix-FollowupSave-Step46.sql` and then `Setup-Quality.ps1`; the fixture is unchanged.

Result of the step: tester agent, runs of 2026-11-15 (folders 2026-11-15_090800, 871 checks; 100359, 399 checks; 124820,
871 checks), all PASSED, with the packs access-matrix, dashboard and followup as given for the step (not re-read from
the results folder; which packs each run held is not recorded here). SQL Test script 46 passed on BMMS_Test (56 of 56),
and the Test scripts of steps 31, 43 and 45 pass. The owner's tests passed. The layout fault C (the footer under an
open Followup panel) was seen as fixed only after a hard refresh (Ctrl+F5), because the stylesheet is cached.

### Step 47 (FU1): the Test script, the followup pack and the run

BMMS-Test-FollowupFinal-Step47.sql runs on BMMS_Test only, in a new query window: 95 numbered checks, all PASS on
2026-11-16. Part 1 checks the markers (and the kept markers of steps 46 and 39), the parameters and result sets, that no
feature above compatibility level 100 is used, the new table (columns, identity, key, default, the two foreign keys and
their delete rule, the two check constraints, the index), that no module updates or deletes the table by name, and
EXECUTE for every database user. Part 2 runs in one rolled-back transaction with made-up data (prefix ZZ47): only the rows
sent are written, with their history rows; a row already confirmed is skipped; the step 46 shape (the attribute c) and
16 more bad lists are refused as a whole; the Action Text is saved on a Pending item and refused (Reason 26) on a
confirmed one; Reopen with the reason trimmed, refused (Reason 27) when not confirmed and (Reason 4) for a NULL, empty
or blank reason, 500 characters kept and 501 cut by the parameter type; every role and the system, inactive, missing, 0
and NULL user refused for the three saves and the list (the MD Secretariat reads the list); parity of
spr_GetFollowupList with the earlier View_Action_Item query for 24 filter combinations (the same ids in the same order);
a reopened item counted as not confirmed in fn_DashboardActionItems, View_Action_Item and
spr_GetFollowupReportForManagement; the history rows gone with their item (spr_UpdateMinutes, spr_DeleteAgendaByAgendaId,
spr_AgendaFinalizeByMeetingId and a direct DELETE); spr_DeleteUserByUserId refusing a user with history rows (Reason 6).
Afterwards every table and identity counter is as before. The Rollback restores the step 46 and step 39 texts exactly
(compared by SHA-1) and keeps the table; after it the step 46 Test script passes 56 of 56. While step 47 is installed the
step 46 Test script runs no check and names the step 47 Test; BMMS-Test-ResetDatabase.sql counts 30 keys to Users when
the table exists (40 PASS). The Test scripts of steps 31, 39, 43, 45, 41, the user delete and user protection scripts and
BMMS-Test-FK-Procedures.sql pass unchanged. The Fix, the Test scripts and the Rollback must be run in the order given in
Database/README.md (section Step FU1, "What to run where"); step 47 and the FU1 build are installed and deployed together.

The followup pack since step FU1 (Tests/packs/followup/README.md): expected.json gained the row the Controller confirms
and reopens (`confirmRow`), the Controller's displayed name, the reopen reason typed and the new messages. Check 1,
qa_ctrl (now first): View (five Pending rows with the Status drop-down, "Edit"); the Action Text saved unchanged; Submit
with no row changed ("No followup was changed to Confirmed. Nothing was saved."); the Confirm of one row ("1 followup was
confirmed.", "Confirmed by [name (login)] on [date]", no drop-down, Reopen, "View"); its action text read-only with the
confirmed line; the filter Confirmed without Submit; the Reopen panel (no reason, "<b" stopped in the browser, a reason
with &, quotes and surrounding spaces saved and shown as typed); the row Pending again with its "Reopened by" line.
Check 2, qa_mdsec, afterwards: the five rows as text, no drop-down, no Reopen, "View", the reopen line. The row ends not
confirmed, as in the fixture. Not in the pack: a second Controller (skipped rows, Reasons 26 and 27 from the page),
"Confirmed (before history)", the failure messages and the too-long messages: owner checks. The access-matrix and
dashboard packs are unchanged.

The tester's baseline for step 47: `Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript
BMMS-Fix-FollowupFinal-Step47.sql`, then `Setup-Quality.ps1`; the fixture is unchanged. A copy of BMMS_Quality (a restore)
carries the tester's login as its dbo and keeps a bmms_site user, so Update-Baseline.ps1 refuses until the copy's owner is
changed and the user dropped; Tests/README.md ("One-time setup and upkeep") says how. The runner call needs a foreground
timeout of about 600 seconds (the run took 288 seconds).

Result of the step: tester run 2026-11-16_133023 (access-matrix, dashboard, followup; baseline updated for step 47):
PASSED, 878 checks (selftest 8, access-matrix 472, dashboard 385, followup 16), error log clean, 288 s. SQL Test script 47
passed on BMMS_Test (95 of 95). The owner's tests passed (SQL on BMMS_Test; browser as Controller and MD Secretariat, Chrome
and Edge).

### Step 48 (FU2a): the Test script, the changed expectations of steps 43 and 45, the dashboard pack check 18

BMMS-Test-DashboardFollowupFinal-Step48.sql runs on BMMS_Test only, in a new query window: 43 numbered checks, all PASS
on 2026-11-16. One transaction, rolled back, with made-up data (prefix ZZ48). It checks the markers, the parameters, the 35
columns of the four objects, that no feature above compatibility level 100 is used, that no marker of steps 46 and 47 is
carried, and the Rollback guards; the card per role (Controller, Management, Manager and User: no confirmed item, the
reopened item with IsReopened 1 and its status columns; MD Secretariat, Admin, the system account, an inactive and no user
refused); fn_DashboardActionItems against the step 43 text installed under another name, for every user of the database,
28 columns both ways; the opening of a confirmed item per role (returned, marked read, StatusId 0), outside the scope and
for the other roles; the save: Reason 26 in the scope, Reason 4 first for Management and the roles without the card, outside
the scope and for an unknown item, Reason 8; a Pending, a reopened and a confirmed-once item (latest row a Confirm, now
not confirmed) still save; the caller's transaction left open; afterwards Action_Item, ActionItem_User_Map,
Action_Item_Status_History and every identity counter are as before.

The Test scripts of steps 43 and 45 follow the step 48 marker (changed with the owner's approval of 2026-11-16):

| Script | Check | Without step 48 | With step 48 |
|---|---|---|---|
| BMMS-Test-DashboardAlerts-Step43.sql | table #AI, and the columns of the three read objects | 28 columns | 35 columns |
| BMMS-Test-DashboardAlerts-Step43.sql | The Controller opens the confirmed item 6 | Reason 4, nothing returned or written | Reason 0, returned, read row written |
| BMMS-Test-DashboardAlerts-Step43.sql | Save by the Controller, the confirmed item | Reason 4 | Reason 26 |
| BMMS-Test-DashboardSummary-Step45.sql | table #AI (#AIO unchanged), the columns of spr_GetDashboardActionItems | 28 columns | 35 columns |
| BMMS-Test-DashboardSummary-Step45.sql | fn_DashboardActionItems SHA-1 | the step 43 text | the step 48 text |

The reason: those scripts read the result sets with INSERT ... EXEC into a table of a fixed number of columns, which
stops with an error, not a failed check, when the columns change. BMMS-Test-FollowupFinal-Step47.sql and
BMMS-Test-AgendaWaitingFor-Step44.sql are not changed. Results on BMMS_Test with step 48: Test 48 43 of 43, Test 43 128 of
128, Test 44 120 of 120, Test 45 66 of 66, Test 47 95 of 95 (Test 46 runs no check while step 47 is installed, as before).
Also run on BMMS_Test: the Fix, the Fix again, the Rollbacks of steps 43 and 45 (refused), the Rollback of step 48 (texts
compared by SHA-1), the Rollback of step 48 again (refused), the Fix.

The dashboard pack since step FU2a (Tests/packs/dashboard/README.md): check 18, `followupFinal`, last of the pack. QA
Test Committee, meeting 00005, agenda 001 is confirmed by qa_ctrl on the Followup page; the card lists it for nobody; a
stale row of qa_user opens it read-only with the line "This followup is confirmed and can no longer be changed." and who
confirmed it; Submit in a stale panel of qa_manager gets the Reason 26 message, nothing saved, the panel stays open;
qa_ctrl reopens it; "Overdue" and "Reopened" show in the row and who reopened it in the panel. The item is left Pending.
The followup pack, run after it, sees the "Reopened by" line under that row; its expected values are unchanged (the same
check count, all pass). The access-matrix pack is unchanged. The fixture is unchanged. The tester's baseline for step 48:
`Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-DashboardFollowupFinal-Step48.sql`.

Result of the step: tester run 2026-11-16_181041 (access-matrix, dashboard, followup; baseline with step 48): PASSED, 890
checks (selftest 8, access-matrix 472, dashboard 397, followup 16), 3 planted failures caught, standing proof held, 0
error-log lines, 0 outside requests, 345 s. Test script 48 passed on BMMS_Test (43 of 43). The owner's tests passed on
BMMS_Test (2026-11-17): Chrome and Edge at 1366 and 1024 px (the Reopened chip with Overdue; the status line, also with a
500-character reason, "Confirmed (before history)" and an inactive name; a stale confirmed row read-only for User, Manager
and Management; two browsers for the Reason 26 message with the panel kept open; the Followup page unchanged); the error
log was clean.

### Step 49 (FU2b): the Test script, the changed expectation of step 47, the followup-reports pack

BMMS-Test-FollowupReports-Step49.sql runs on BMMS_Test only, in a new query window: 33 numbered checks, all PASS on
2026-11-17. One transaction, rolled back, with made-up data (prefix ZZ49). It checks the markers, the parameters, the columns,
that no feature above compatibility level 100 is used, that the new objects carry no marker of steps 46 to 48, and the Rollback
guard of step 47; who may call the two procedures (every role, the system account, an inactive and no user); the status columns
of a Pending, a Confirmed, a "before history", a Reopened, a re-confirmed and a confirmed-with-a-Reopen-as-latest-row item, an
inactive actor and a nameless actor; the tie-break (AgendaNo, ActionItemId) in the two reports and the Followup list; parity:
the Controller's rows against a copy of the query the code built before (24 filter combinations, 0 differ), Management's against
spr_GetFollowupReportForManagement with the minutes status (24, 0), Followup by Department against
spr_GetActionItemByMeetingIdDeptId with the committee and subject range the page applied (12, 0); the 27 blank characters each
alone and all together refused by spr_ReopenFollowup, U+200C alone and a reason with a zero-width space inside saved; afterwards
the three tables and every identity counter as before.

The Test script of step 47 follows the step 49 marker (changed with the owner's approval of 2026-11-17):

| Script | Check | Without step 49 | With step 49 |
|---|---|---|---|
| BMMS-Test-FollowupFinal-Step47.sql | Parity with the old query (the order of the copy #ZZ47Old) | ROW_NUMBER over ..., IsConfirmed, ActionItemId | ..., IsConfirmed, AgendaNo, ActionItemId (the expected "24, 0" unchanged) |

The reason: spr_GetFollowupList now orders by AgendaNo before ActionItemId. Results on BMMS_Test with step 49: Test 49 33 of 33,
Test 41 44 of 44, Test 43 128 of 128, Test 44 120 of 120, Test 45 66 of 66, Test 47 95 of 95, Test 48 43 of 43. Also run on
BMMS_Test: the Fix, the Fix again, the Rollback of step 47 (refused), the Rollback of step 49 (texts compared by SHA-1), the
Rollback of step 49 again (refused), the Fix. BMMS-Check-InstalledSteps.sql: step 47 Installed 6 of 6, step 49 Installed 5 of 5.
Build checks: the list of 27 code points in BMMSBAL against the lists in the Fix and Test scripts (the same), and
IsBlankReopenReason for every character of the Basic Multilingual Plane against the list (0 differ).

The followup-reports pack (Tests/packs/followup-reports: pack.js, expected.json, README.md; run after the followup pack): qa_ctrl
confirms QA Test Committee meeting 00005 agenda 002 and meeting 00006 agenda 001 in one Submit on the Followup page and reopens
the second with a reason. Then it reads, as the browser shows them (View and Generate; the report in ViewReport.aspx): Followup
and Followup Summary as qa_ctrl and qa_mgmt (the Confirmed Status choices Both, Confirmed, Pending; the "Followup status" column
and, for Management, the Minutes status column; the Confirm and reopen lines; the FOLLOWUP STATUS block per row; the Summary with
the word only) and Followup by Department as qa_ctrl (View and Print). 14 checks. Not in the pack: Export to Pdf and Export to
Word (owner checks), the refusals and the parity (the Test script), "Confirmed (before history)", an inactive name and "an
unknown user" (the fixture has none). The fixture, the access-matrix, dashboard and followup packs are unchanged. The tester's
baseline for step 49: `Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-FollowupReports-Step49.sql`.

Result of the step: tester run 2026-11-17_133514 (access-matrix, dashboard, followup, followup-reports; baseline with step 49):
PASSED, 904 checks (selftest 8, access-matrix 472, dashboard 397, followup 16, followup-reports 14); after the header change
("Followup status") run 2026-11-17_135000 (selftest and followup-reports): PASSED, 19. The owner's tests passed on 2026-11-17
(SQL on BMMS_Test and the browser).

## Reviewer stage

[[CONFIRM: not written yet (WF2b2)]]

## Documentation stage

[[CONFIRM: not written yet (WF2b2)]]

## Release tags and versions

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: build with Visual Studio, Rebuild Solution (BMMS.sln), 0 errors]]
[[CONFIRM: lead from old Architecture notes: release order is back up BMMS, run the step's script, then deploy the matching build straight away (the scripts say when the order matters)]]
[[CONFIRM: lead from old Architecture notes: branch modernization; one tag per release; files staged by explicit path; rebuilt binaries stay out of commits]]

## Exporting the documents

[[CONFIRM: not written yet (WF2b2)]]
