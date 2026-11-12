# BMMS tester

The tester runs fixed browser checks against a copy of the site on this laptop and reports
pass or fail with screenshots. It complements the owner's tests; it does not replace them.
It never changes the product, and it never uses BMMS or BMMS_Test.

- Database: `BMMS_Quality` only. The name is fixed in `Tests\_runner\Tester.Common.ps1`.
- Site: a copy of the working tree in `Tests\_site`, on http://localhost:18573
  (your own site stays on port 49573 with BMMS_Test).
- SQL logins: the site copy signs in to SQL Server as `bmms_site`, and the runner restores and
  checks as `bmms_tester`. Neither can open any database but BMMS_Quality; the runner asks the
  server to confirm that before every run. Your application login `bmms_app` is not used.
- Browser: the installed Chrome, driven by scripts (Playwright), without a visible window.
- Mail: BMMS_Quality has the safe default (localhost, port 25). No real mail can be sent.

## How to run

From the repository folder, in PowerShell 7:

```
pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -CheckOnly
pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack selftest
pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack access-matrix
```

- `-CheckOnly` runs no checks. It proves that the site copy is the current working tree, that it
  is on BMMS_Quality, that the baseline is current and the fixture intact.
- `-Pack <name>` runs the self-test and then the pack. Several packs: `-Pack a,b`.
- `-Pack access-matrix` (step WF3a2): what each role can open, against your rules. Its rules,
  files and cells: `Tests\packs\access-matrix\README.md`. It starts with its standing proof (below)
  and takes about three minutes in all (measured on this laptop: 2 min 40 s to 3 min 40 s; most of
  it is the site's first requests, which compile the pages).
- `-Pack dashboard` (step UN6b): the Dashboard's Meetings card per role (meetings, colours, statistics,
  filters, titles), the Alert and Action Item lists, and the page width at 1366, 1024 and 800 px. Its rules,
  files and rows: `Tests\packs\dashboard\README.md`. About two and a half minutes.
- `-Pack access-matrix -ProofFullMatrix` (you only; the tester agent cannot use it): the standing
  proof over every row instead of two. Exactly one cell must change. Use it when the pack itself
  changes.
- A run restores BMMS_Quality first. **Open windows on BMMS_Quality in SQL Server Management
  Studio are disconnected at the start of every run.** Windows on BMMS_Test are not affected.
- A run of the self-test alone takes about 20 seconds.

To look at the test data by hand:

```
pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack selftest -LeaveSiteRunning
pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -StopSite
```

- `-LeaveSiteRunning` does not stop the site copy at the end of the run. Open
  http://localhost:18573 and sign in with a `qa_` account; the passwords are in
  `Tests\local\credentials.json`. You see BMMS_Quality as restored for that run. Whatever you
  change there is gone at the next run.
- `-StopSite` stops it and does nothing else. The next tester run stops it too. If you forget,
  the site copy keeps running on port 18573 until then; it does no harm, and its data is
  replaced at the next run.
- The tester agent can use neither switch.

In the development workflow the `tester` agent runs the same command and returns a record.

## How to read the results

Each run writes a folder `Tests\_results\<date_time>\`. Open `results.md`.

| Result | Meaning | What to do |
|---|---|---|
| PASSED | Every check gave what was expected; the self-test caught its planted failures; no new line in the error log. | Go on to your own tests. |
| FAILED | At least one check did not give what was expected, or the error log has new lines, or a request to another host was stopped. | Read "Failed checks": expected, seen, screenshot. Decide whether the product or the expected result is wrong. |
| REFUSED | The tester would not start. Nothing was tested. | The first line says why (see "Refusals"). |
| VOID | The self-test did not catch its planted failures, the access matrix's standing proof failed (or the site copy's PageAccess.xml was not put back), a pack broke off, or the browser part stopped (the first line says which). | No result of that run counts. The tester itself needs attention: tell Claude. |
| RUNNER FAILED | The tester itself broke. | Nothing can be said about the site; the run does not count. Copy the first line to Claude. |
| READY | Check only; no pack was run. | Nothing. |

Other files in the folder: `results.json` (the same, for programs), `screenshots\` (every failed
check and the planted ones), `page-access-log-new.txt` and `error-log-new.txt` (the lines the
run added to the logs of the site copy), `installed-steps.txt` and `fixture-check.txt`
(what the two database checks found).

The words in the Expected and Seen columns: "opens" (the page asked for came back),
"Access denied", "Page not found", "sent to the sign-in page", "the error page", "no answer"
(the site did not reply) and "HTTP 500 (not expected)" (any other status code, with its
number). A log check reads, for example, "1 DENIED line".

The self-test: in every run the tester is given three deliberately wrong expectations. Each
must come out as a failure. That shows the tester can tell a failure from a pass. The three
rows marked "caught (planted)" in the results are therefore not failures; do not count them.

A refusal writes a DENIED line to the page access log, so new DENIED lines are normal for
checks that expect "Access denied". A new line in the error log always counts as a failure.

The access matrix adds these sections to `results.md`:

- **Access matrix**: one line per address, one column per role (the column names are explained
  under the heading). "ok" means the page gave what the cell says and the page access log agrees
  (one DENIED line for that user and page for a refusal, none otherwise). A failing cell reads,
  for example, "**FAIL** opens / seen HTTP 500 (not expected) (439)": what was expected, what was
  seen, and its number in "Failed checks". "note RA1c1" and "note RA1c2: ..." mark the cells of
  the next section.
- **Notes: cells that are not judged yet**: your decisions of 2026-11-11. "to be removed (RA1c1)"
  (Event Calendar, Report Print: the run does not open them) and "to be decided (RA1c2)"
  (Followup Action Taken for the Controller and the Manager: opened, what it shows is given).
  Never failures.
- **Cells for the owner to decide**: cells no written rule decides yet, with what the site does
  today; each counts as failed until you write the cell into `expected.csv`. Empty since your
  decisions of 2026-11-11, so the section is not shown.
- **Other notes for the owner**: facts the pack reports without failing, for example the page on
  disk that PageAccess.xml does not list, and menu links no menu bar item opens.
- **Standing proof of the access matrix**: before the matrix, the runner adds `user` to the entry
  of Report/MeetingCalendar.aspx in `Tests\_site\XML\PageAccess.xml` only (never in your working
  tree), runs two rows for every role, and puts your file back in a finally block. Exactly the one
  planted cell must come out different from the real matrix run; at the end the site copy's
  PageAccess.xml must have the same SHA-256 as yours. Otherwise the run is VOID.

What the tester cannot judge: looks (alignment, borders, spacing, the printed page, a document
opened in Word). Those stay with you; the screenshots and exports are there for that.

## Refusals

| The runner says | Cause | Remedy |
|---|---|---|
| "... is out of date: step N ...: Missing" | A database step was added after the baseline was taken. | `Update-Baseline.ps1` (below). |
| "BMMS-Quality-Fixture.sql has changed since the baseline was taken" | The fixture was edited. | `Setup-Quality.ps1` again (below). |
| "Tests\local\credentials.json is missing" | No setup on this machine yet. | `Setup-Quality.ps1`. |
| "Tests\local can be read by an account other than yours" | The folder's permissions were widened. | See "Credentials". |
| "The build of the working tree failed" | The code does not compile. | Fix the code; nothing was tested. |
| "does not name BMMS_Quality" / "does not show Database: BMMS_Quality" | The site copy is not on the tester's database. | Do not go on. Tell Claude; nothing was tested. |
| "Port 18573 is already in use" | Another program listens on the tester's port. | Close it, run again. |
| "... can open another database" / "... can open BMMS or BMMS_Test" / "... is a member of a server role" / "... holds CONTROL SERVER or an IMPERSONATE right" / "... holds the server permission(s) ... besides CONNECT SQL and VIEW ANY DATABASE" / "... was given ... on the server besides CONNECT SQL" | One of the tester's two SQL logins was given more than it should have (asked before every run and again after the restore). | Do not go on. Tell Claude; nothing was tested. |
| "Tests\_site\connectionStrings.config can still be read by an account other than yours" | Another account has its own entry on that file. The password was not written. | Tell Claude; nothing was tested. |
| "-LeaveSiteRunning is refused: the ... profile lets inbound traffic in by default" | A Windows Firewall profile is set to let inbound traffic in without a rule. | Run without `-LeaveSiteRunning`, or set that profile to block inbound traffic by default first. |
| "WARNING (firewall): rule ... lets inbound traffic in" (console) / "Firewall: **warning**" (results.md) | Not a refusal. An enabled inbound rule for IIS Express, System or any program covers port 18573, or a profile is off. On this laptop (2026-11-11): the Windows rule "WFD Driver-only (TCP-In)" (System, every port). The run goes on: the site copy serves only callers on this laptop, checked through every address at every start. | Nothing to do for the run. The tester changes no Windows rule. |
| "WARNING (memory): ... MB available" (console) / "Memory at the start: ... (**warning**: below 1500 MB)" (results.md) | Not a refusal (step UN6b). Less than 1500 MB of memory is available (Task Manager, Performance, Memory, "Available"). With too little memory the browser can be stopped or SQL Server can make queries wait, and the run can end VOID or with pages that "could not be loaded". A VOID or RUNNER FAILED run reads the memory again and says in its summary when it was low. | Close other programs (browsers, Visual Studio, SSMS windows not needed) and run again. |
| "The site copy answers on a network address of this machine" | The site copy answered through a network address of this laptop (it must refuse: HTTP 400 for that address as host name, HTTP 403 for "Host: localhost"). | Do not go on. Tell Claude; nothing was tested. |
| "... could not sign in to BMMS_Quality" | A tester login was dropped, re-created or its password changed outside setup. | `Setup-Quality.ps1` again. |
| "The Node packages are missing" | `Tests\node_modules` is not there. | `npm ci` in the `Tests` folder. |
| Anything else | | Copy the first line to Claude. Nothing was tested. |

## The test data (fixture)

BMMS_Quality holds only the seed rows of Reset Database and the fixture
(`Tests\fixture\BMMS-Quality-Fixture.sql`):

| Account | Role | Department |
|---|---|---|
| qa_admin | Admin | Admin |
| qa_ctrl | Controller | Secretarial |
| qa_manager | Manager | Credit |
| qa_manager2 | Manager | HRD (home) and Secretarial |
| qa_user | User | Credit, manager qa_manager |
| qa_user2 | User | HRD, manager qa_manager2 |
| qa_mgmt | Management | Secretarial |
| qa_mdsec | MD Secretariat | Secretarial |
| qa_inactive | User, inactive | Credit |

The four seeded users (admin, secuser, credmanager, creduser) are there too, with the default
password; the tester never signs in as them. Login names and passwords have at most 12
characters, because the sign-in page takes no more (the product's limit, recorded in "Known
items for later steps" in `Database\README.md`).

Committee QA1 "QA Test Committee" with a Chairman and a Member, and six meetings:

| Meeting | State | Items |
|---|---|---|
| 00001 | Agenda open; meeting 30 days ahead | At AC (2, one of HRD), AMA, ACA, AMR, ACR |
| 00002 | Submission date passed two days ago; meeting 10 days ahead | One at AC |
| 00003 | Agenda finalised; meeting 5 days ahead | One approved |
| 00004 | Meeting day passed; attendance entered; minutes in Draft | Two approved |
| 00005 | Minutes Finalised | Two approved, one a Followup with its action item |
| 00006 | Minutes Confirmed | One approved |

The dates are set again at the start of every run, relative to that day
(`BMMS-Quality-Fixture-Dates.sql`). `BMMS-Quality-Fixture-Check.sql` (read only) verifies all of
this after every restore.

## One-time setup and upkeep (owner, or Claude's main session on your approval)

These two scripts use your Windows login (sysadmin on the local SQL Server), work on
BMMS_Quality only, and end with a list of what they changed on the server. The tester agent
cannot run them.

**Setup** - when BMMS_Quality was copied afresh from BMMS_Test, or the fixture changed:

```
pwsh -NoProfile -File Tests\_runner\Setup-Quality.ps1 -ConfirmDatabase BMMS_Quality
```

It clears BMMS_Quality with the application's own Reset Database procedure, creates the SQL
logins `bmms_tester` (owner of BMMS_Quality) and `bmms_site` (a user in BMMS_Quality with the
roles db_datareader, db_datawriter and db_backupoperator and EXECUTE on the dbo schema, as
`bmms_app` has there), neither with a server role or access to any other database, builds the
fixture, writes `Tests\local\credentials.json` and takes the baseline backup
`BMMS_Quality_baseline.bak` in the SQL Server backup folder. BMMS_Quality must first have every
step installed (a restore of BMMS_Test gives that), and `bmms_app` must be linked with its three
roles.

**After a new database step** (step 42 and on):

```
pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-Name-Step42.sql
```

It restores the baseline, runs the Fix script, checks the fixture and the steps, and takes the
baseline again. If anything fails, the old baseline stays.

**Node packages** - once per machine, and after `Tests\package.json` changes: `npm ci` in the
`Tests` folder (needs the internet; nothing else in the tester does). No browser is downloaded:
the installed Chrome is used.

## Credentials

`Tests\local\credentials.json` holds the generated passwords of the nine test accounts and of
the two SQL logins `bmms_tester` and `bmms_site`. They are valid for BMMS_Quality only. Nothing in it is committed:
`Tests/local/` is in `.gitignore`. `Tests\credentials.json.example` shows the form only.

The folder `Tests\local` is readable by your Windows account only. The setup does this:

```
icacls Tests\local /inheritance:r /grant:r "<your account>:(OI)(CI)F"
```

To see the permissions: `icacls Tests\local`. One line, your account with `(F)`, is right. If
another account is listed, the runner refuses; run the command above again (your account name:
`whoami`), then `icacls Tests\local\* /reset /T`.

`Tests\_site\connectionStrings.config` (the site copy's connection string, with the
`bmms_site` password) is written by the runner at every run and is readable by your account
only as well. Your own `BMMS\connectionStrings.config` is not read by the tester.

How the database user stays linked to its login: the baseline backup holds the user `bmms_site`
with the identity (SID) of the server login `bmms_site`. A restore brings the same user back,
and it matches the login as long as the login is not dropped. Setup never drops a login; when
it runs again it only changes the password, which keeps the identity. If someone drops and
re-creates the login by hand, the next run refuses ("could not sign in to BMMS_Quality");
running `Setup-Quality.ps1` again links it.

The test account passwords are made by the application's own hash function
(`Common.HashPassword` in the built `BMMSBAL.dll`); the fixture script receives only the hashes.

## What is where

| Path | What | In git |
|---|---|---|
| `Tests\_runner\` | `Run-Tests.ps1`, `Setup-Quality.ps1`, `Update-Baseline.ps1`, `Tester.Common.ps1` | yes |
| `Tests\fixture\` | The fixture, its check and its dates script | yes |
| `Tests\lib\run.js` | The browser side | yes |
| `Tests\packs\<name>\` | One folder per pack (`pack.js`, and data files) | yes |
| `Tests\package.json`, `package-lock.json` | The one Node package (playwright-core) | yes |
| `Tests\_results\` | Results of every run | no |
| `Tests\_site\`, `Tests\_build\` | The site copy and its build | no |
| `Tests\local\` | Credentials and the baseline record | no |
| `.claude\agents\tester.md`, `.claude\hooks\tester-guard.ps1` | The agent and its guard | yes |

The site copy is rebuilt and re-synced from the working tree at the start of every run, so a
change made inside `Tests\_site` does not survive. The projects' own `bin` and `obj` folders are
not written by the tester.

## Found about the product while building the tester

Recorded in `Database\README.md` (section "Step WF3a1" and "Known items for later steps"):
the sign-in page takes at most 12 characters for the User ID and for the password; and
`Error\TestPage.aspx`, a leftover page that is not listed in `PageAccess.xml`, so every role gets
"Access denied" for it (to be removed with the unused pages).

Found by the access matrix (step WF3a2, recorded in the WF3a2 section of `Database\README.md`):
`Report\EventCalendar.aspx` runs out of memory on every opening (an endless loop) and every
signed-in role could open it, and ViewReport.aspx opened directly gave the Controller and the
Manager an error. Step RA1c1 removed Event Calendar and Report Print and made ViewReport.aspx show
"The report is no longer available" when it has no report.

## Limits

- Never BMMS, never BMMS_Test.
- No real mail. Nothing listens on port 25 unless smtp4dev is set to it; a pack that sends mail
  must say which of the two it expects.
- The site copy and other machines: while the site copy runs, port 18573 listens on this laptop
  (seen on 2026-11-11: on ::1 and on ::). Two guards since step WF3a2.

  The IP restriction. The site copy runs from the runner's own IIS Express configuration
  (`Tests\_build\iisexpress\applicationhost.config`), which lets in only callers on this laptop
  (127.0.0.1 and ::1). IIS Express listens through Windows (http.sys) on every address of the
  laptop and, without that restriction, answered a caller that sends "Host: localhost" through
  any of them (seen on 2026-11-11). Every run asks the site copy through each network address,
  with that address and with "Host: localhost" as host name, and stops unless both are refused
  (seen on 2026-11-11 for all five addresses: HTTP 400 and HTTP 403; localhost got the sign-in
  page).

  The firewall reading. Every run reads the Windows Firewall. An enabled inbound rule for IIS
  Express, System or any program that covers port 18573, or a profile that is off, is a warning in
  the console and in results.md ("Firewall"), not a refusal (your decision of 2026-11-11), because
  the IP restriction above is checked on every run. `-LeaveSiteRunning` is refused only when a
  profile lets inbound traffic in by default. Seen on 2026-11-11: all three profiles on and
  blocking by default; one warning, the Windows rule "WFD Driver-only (TCP-In)" (System, every
  port). The runner changes no Windows rule. A profile that is off filters nothing, as one that
  lets inbound traffic in by default: then the IP restriction is the only barrier. It is still only
  a warning (your decision), so read the "Firewall" line of results.md.

  Neither guard is a test from another machine. Do that once from another device (a phone on the
  same Wi-Fi, or the other laptop): with the site copy running, its address and port 18573 must
  give an error page, never the sign-in page (your test steps of WF3a2). Even so, do not leave the
  site running on a network you do not trust, and stop it with `-StopSite` when you have finished
  looking.
- Not a security audit.
- No judgement of looks.
- Packs are written in a step's build and reviewed; the tester agent runs them and cannot change
  them. A failed check goes to the owner as it is.
