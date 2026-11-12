# Testing and Release

- Title: Testing and Release
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: UN6b (the step 42 Test script section, the dashboard pack, the memory preflight, the fixture's committee QA2, the baseline upkeep note); the rest RA1c2
- Last updated by: UN6b, based on 0736c7f
- Status: Draft
- Verified against: for step UN6b: Database/BMMS-Test-DashboardMeetings-Step42.sql (header, guards, part 1),
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
  recounted from the scripts; chapter not written yet (WF2b2); leads from the old Architecture notes to verify

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
| Packs | One folder per pack under Tests/packs (pack.js and data files). The packs are selftest (WF3a1), access-matrix (WF3a2) and dashboard (UN6b). A pack is Node code: it is written in a step's build and reviewed there, and the tester cannot change it |

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
- BMMS-Quality-Fixture-Check.sql is read only: 29 checks before UN6b, with three more rows for QA2 since (not
  recounted), ending "FIXTURE CHECK: PASS (n checks)".
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
(Setup-Quality.ps1, 2026-11-12). In the workflow this is done on the owner's approval of the
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
4. At 1366, 1024 and 800 px (qa_manager): the page is no wider than the window and the content area does not scroll
   sideways; the Meetings and Alerts cards side by side at 1366 px and stacked below 1100 px; the same width check
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
