# Testing and Release

- Title: Testing and Release
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: WF3a1
- Last updated by: WF3a1, based on 14d780c
- Status: Draft
- Verified against: for the section "The tester (step WF3a1)": Tests/README.md, Tests/_runner/Tester.Common.ps1,
  Run-Tests.ps1 (exit codes, result words), Tests/lib/run.js (Chrome channel), Tests/package.json,
  .claude/agents/tester.md, .claude/hooks/tester-guard.ps1, Database/README.md (section Step WF3a1 and
  Known items for later steps), the owner's test result of 2026-11-11; none yet for the rest (leads from the old Architecture notes added in WF2b1); for the step 40
  section Database/BMMS-Test-RoleAccess-Step40.sql (header), the diff of the three changed Test scripts
  and the owner's test result of step RA1a; for the step 41 section Database/BMMS-Test-ReportAccess-Step41.sql
  (header), Database/README.md (section RA1b) and the owner's test result of step RA1b
- To confirm: how the tester stage enters the development workflow (CLAUDE.md changes with WF3a2); the count of 44 checks and the counts of the older Test scripts are Database/README.md's, not
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

## The tester (step WF3a1)

Step WF3a1 adds the infrastructure of a tester and nothing else. No product code changed, there is no
numbered database step and nothing changed for a user. The first real pack (the access matrix) and the
change to the development workflow in CLAUDE.md come with step WF3a2; neither exists yet.

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
| SQL logins | Two, made by the setup. bmms_tester owns BMMS_Quality; the runner restores and checks as this login. bmms_site is the site copy's login: a user in BMMS_Quality with db_datareader, db_datawriter, db_backupoperator and EXECUTE on the dbo schema. Neither has a server role or access to any other database. Before every run the runner asks the server, as each login, what it can reach, and refuses when that is more than BMMS_Quality (any other database, BMMS or BMMS_Test, a server role, CONTROL SERVER, IMPERSONATE). The application login bmms_app is not used |
| Browser | The installed Chrome, headless, driven by Node scripts (playwright-core). Requests to any host other than localhost are aborted and listed |
| Mail | BMMS_Quality has the safe default (localhost, port 25); no real mail can be sent |
| Packs | One folder per pack under Tests/packs (pack.js and data files). In WF3a1 the only pack is selftest. A pack is Node code: it is written in a step's build and reviewed there, and the tester cannot change it |

### How it is run

From the repository folder, in PowerShell 7:

- `pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -CheckOnly` - no checks run; it proves that the
  site copy is the current working tree and on BMMS_Quality, that the baseline is current and the
  fixture intact.
- `pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack [name]` (several: `-Pack a,b`) - the
  self-test always runs first, then the packs.
- For the owner only: `-LeaveSiteRunning` leaves the site copy on port 18573 after the run, to look at
  the fixture by hand; `-StopSite` stops it and does nothing else. The tester agent's guard allows
  neither.

Every run, in order: preflight (the two logins asked what they can reach); build of the working tree and
mirror to Tests/_site; proof that the copy is current; the copy's connection string written from fixed
parts (the local server, BMMS_Quality, the login bmms_site; BMMS/connectionStrings.config is not read)
and proved; restore of the baseline as bmms_tester; the fixture dates set again, relative to the day;
refusal unless every row of Database/BMMS-Check-InstalledSteps.sql reads Installed and the fixture check
passes; IIS Express started; sign-in as the fixture Admin and a check that the footer reads
"Database: BMMS_Quality"; the self-test and the packs; results written to Tests/_results/[date_time]/
(results.md and results.json, screenshots of every failed and planted check, the new lines of the site
copy's page access log and error log, installed-steps.txt, fixture-check.txt).

A run restores BMMS_Quality, so windows open on BMMS_Quality in SQL Server Management Studio are
disconnected at the start of every run. Windows on BMMS_Test are not affected. A run of the self-test
alone takes about 20 seconds.

### The result words

| Result | Exit code | Meaning |
|---|---|---|
| PASSED | 0 | Every check gave what was expected, the self-test caught its planted failures, and the error log has no new line |
| FAILED | 1 | A check did not give what was expected, or the error log has new lines, or a request to another host was stopped |
| REFUSED | 2 | The runner would not start; nothing was tested. The first line gives the reason (for example: the baseline is out of date, the fixture script changed since the baseline, a tester login can reach more than BMMS_Quality, port 18573 in use, the build failed) |
| VOID | 3 | The self-test did not catch its planted failures, a pack broke off, or the browser part stopped; no result of that run counts |
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
  Confirmed. It is one transaction. The fixture is not a numbered step and has no row in
  BMMS-Check-InstalledSteps.sql.
- BMMS-Quality-Fixture-Dates.sql sets the two date columns of the six meetings relative to today after
  every restore.
- BMMS-Quality-Fixture-Check.sql is read only: 29 checks, ending "FIXTURE CHECK: PASS (n checks)".
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
("out of date") until it is taken again:

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
`git status --short --ignored` before and after. [[CONFIRM: how the tester stage enters the development workflow; the change to CLAUDE.md comes with step WF3a2, so 02-Development-Environment ("The development workflow") does not name the tester stage yet]]

### Limits

- Never BMMS, never BMMS_Test.
- No real mail; nothing listens on port 25 unless smtp4dev is set to it.
- No judgement of looks, print or Word; not a security audit.
- A pack is Node code with the owner's rights; the localhost-only rule covers the browser's requests
  only. Every pack must be reviewed as code in the step that adds it.
- No retry: a check that fails once is reported as failed.
- While the site copy runs, port 18573 listens on this laptop (on the local loopback and on all IPv6
  addresses, seen on 2026-11-11). The Windows Firewall is on and has no rule that lets IIS Express in,
  and IIS Express answers only to the host name localhost; whether another machine can reach it has not
  been tested. Do not leave the site running (-LeaveSiteRunning) on a network you do not trust.
- Open items are in Database/README.md, "Known items for later steps". The first task of WF3a2 is four
  security Lows: the allow-list of the pre-run check, the timing of the role check, the read-back of
  the icacls permissions, and the reachability check for -LeaveSiteRunning.
- Facts found about the product while building, recorded in Database/README.md: the sign-in page takes at
  most 12 characters for User ID and password; Error/TestPage.aspx is an unlisted leftover page that
  every role is refused; PageAccess.xml has 46 page entries and the site 47 pages.

Result (owner's tests of step WF3a1, 2026-11-11): passed. Build checks: Setup ran to the end (fixture
check 29 of 29); Run-Tests.ps1 -Pack selftest PASSED; -CheckOnly READY; -LeaveSiteRunning and -StopSite
worked; Update-Baseline.ps1 ran with the re-runnable Fix script of step 41; the guard blocked every
forbidden command, tool and path form tried.

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
