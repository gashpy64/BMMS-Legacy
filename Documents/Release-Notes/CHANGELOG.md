# BMMS Change Log

- Title: BMMS Change Log
- Audience: Gashpy Software (internal)
- Shipped: No
- Applies to: WF3a1
- Last updated by: WF3a1, based on 14d780c
- Status: Draft
- Verified against: for WF3a1: Tests/README.md, Tests/_runner/*, .claude/agents/tester.md,
  .claude/hooks/tester-guard.ps1, Database/README.md (section Step WF3a1), the owner's test result; and for the rest: git tags and commit subjects (git for-each-ref refs/tags), Database/README.md, the diff
  of step RA1b (BMMS/Report/*.cs, PageAccessModule.cs, PageAccess.xml, MenuUserControl.ascx, BMMSBAL,
  BMMSDAL), Database/BMMS-Fix-ReportAccess-Step41.sql
- To confirm: the tag of RA1b (not set when this entry was written); the two new Lows (a) and (b) are not yet
  in Database/README.md, "Known items for later steps"

One entry per step, newest first. Each entry names the step, its tag and what changed for users,
for installers and in the database. Release entries (tags vX.Y.Z) collect the steps since the
previous release.

## WF3a1 - Tester infrastructure; database BMMS_Quality with a fixture and a baseline (tag not yet set, 2026-11-11; no database step)

- For users: nothing. No product code changed and no page, message or role right changed. No user
  manual is touched.
- For developers: a tester runs fixed browser checks against a copy of the site on the development
  laptop and reports PASSED, FAILED, REFUSED, VOID, RUNNER FAILED or READY, with screenshots. It never
  changes the product and complements the owner's acceptance tests (looks, print and Word stay with
  the owner). Database: BMMS_Quality only (a restore of BMMS_Test, cleared with Reset Database, then a
  fixture, then a baseline backup restored at the start of every run); the tester never uses BMMS or
  BMMS_Test. Site: a copy in Tests/_site on http://localhost:18573 (IIS Express); the owner's site on
  port 49573 is untouched. Two SQL logins made by the setup, bmms_tester and bmms_site, with no server
  role and no access to another database; the runner asks the server to confirm that before every run.
  Runner: Tests/_runner/Run-Tests.ps1 (-CheckOnly, -Pack; for the owner -LeaveSiteRunning and
  -StopSite), Setup-Quality.ps1 (one time), Update-Baseline.ps1 (after a new database step). Every run
  includes a self-test with three deliberately wrong expectations that must fail. A tester subagent
  (.claude/agents/tester.md) is confined by a guard hook (.claude/hooks/tester-guard.ps1): it runs only
  the runner and git status --short and reads only Tests/_results.
- For installers: nothing to install on a server. A developer machine needs Node, `npm ci` in Tests,
  the installed Chrome, MSBuild, IIS Express, the database BMMS_Quality and the two logins (System
  manual 02, "The tester: what the development machine needs"). Local untracked folders: Tests/_results,
  _site, _build, local, node_modules.
- Database: no numbered step; no row in BMMS-Check-InstalledSteps.sql. The fixture runs only on a
  database named exactly BMMS_Quality.
- Not yet: the first real pack (the access matrix) and the change of the development workflow in
  CLAUDE.md come with step WF3a2.
- Tests: Setup ran to the end (fixture check 29 of 29); the selftest pack PASSED (5 checks, 3 of 3
  planted failures caught, about 20 seconds); -CheckOnly READY; -LeaveSiteRunning and -StopSite work;
  Update-Baseline.ps1 ran with the Fix script of step 41; the guard blocked every forbidden command,
  tool and path form tried. security-reviewer and ux-reviewer: pass, no High or Medium open. The
  owner's tests passed on 2026-11-11.
- Known items for later (Lows): in Database/README.md, "Known items for later steps". Four security
  Lows are the first task of WF3a2: the pre-run check allow-list, the role check timing, the read-back
  of the icacls permissions and the reachability check for -LeaveSiteRunning (port 18573 listens on the
  local loopback and on all IPv6 addresses, the Windows Firewall is on with no allow rule for IIS
  Express; reachability from another machine is not tested). Facts found about the product: the sign-in
  page takes at most 12 characters for User ID and password; Error/TestPage.aspx is an unlisted leftover
  page that every role is refused; PageAccess.xml has 46 page entries and the site 47 pages.

## RA1b - Minutes report in every status for the Controller and Management; Reports for Management (tag not yet set, 2026-11-10; database step 41)

- For users: the Controller and Management (Management is the role code mgmt) see the Minutes report
  for every meeting that has minutes, in every status: Draft (not finalised), Finalised or Confirmed.
  Each meeting shows "Minutes status: [status]"; a draft also shows the bordered note "DRAFT - not
  finalised; this is not the approved text of the minutes." at the start and at the end of the meeting.
  The status line and the note are in Print, Export to Pdf and Export to Word. The list on screen has a
  "Minutes status" column. Management gets a Reports menu with Minutes, Followup and Followup Summary (all
  committees in the list); in Management's Followup each item shows its minutes status, and Followup
  Summary has a "Minutes status" column. Management has no Minutes Extract. The Manager and every other
  role keep finalised and confirmed minutes only; the Controller's Followup is unchanged (no status). A
  meeting with no minutes rows (agenda not finalised) is not listed; an empty list says "No meetings with
  minutes for this committee.". New texts: "Your session is no longer valid. Please log in again." and "You
  are not allowed to see this report.". Followup, Cancel now returns to the same report (before, it opened
  the page without a report code and gave the error page). Management with an address other than its
  three reports, or with ViewReport.aspx before any report was generated, gets "Access denied".
- Owner principle (decided 2026-11-10): the Admin is superior for the technical menu items; the
  Controller is superior for the functional items and gets all functional rights. Written into the
  System manual (chapters 01 and 08), the Glossary, the Controller manual, the Admin manual and the
  Overall manual's section for Management.
- For installers: run BMMS-Fix-ReportAccess-Step41.sql after step 40 and before deploying the build (the
  build calls the new procedures; without them the Controller's and Management's Minutes report and
  Management's Followup show the error page). BMMS-Rollback-ReportAccess-Step41.sql drops the three
  procedures (roll back the build first). BMMS-Check-InstalledSteps.sql has a row for step 41 (3 markers).
- Database: step 41 adds spr_GetMinutesReportMeetingsAllStatus, spr_GetMinutesReportAllStatus and
  spr_GetFollowupReportForManagement (read only; @ActingUserId; OUTPUT @Result and @Reason, 8 acting user
  missing or inactive, 4 another role; no rows when refused). Replaces nothing; spr_GetMinutesReport and
  spr_GetMinutesReportMeetings of step 22 unchanged. Marker ReportAccess-Step41. No data changes.
- Code: PageAccess.xml adds mgmt to Report/Reports.aspx, Report/Followup.aspx and Report/ViewReport.aspx;
  PageAccessModule.HasRole and RefuseRequest (RequireRole behaves as before); Reports.aspx and Followup.aspx
  refuse an unknown report code and check the role in the database; ViewReport.aspx fails closed for
  Management (only minutes, followup and summary, never ?pdf=1); the menu block for Management;
  HTML_Report (status line, draft note), ReportsMgr, MinutesDB and ActionItemDB (the three calls).
- Tests on BMMS_Test (owner): the database Test script BMMS-Test-ReportAccess-Step41.sql passed every row
  (44 checks according to Database/README.md); the browser table passed for the Controller, Management,
  Manager, User, Admin and MD Secretariat, the RA1a regression, Followup Cancel, a 1366 px window and real
  Print, Export to Pdf and Export to Word of a draft; the error log was clean and PageAccessLog.txt showed
  the expected lines.
- Known items for later (Lows): the Lows listed for RA1b in Database/README.md, "Known items for later
  steps" (the Controller's Followup stays a query built in the code and shows no mark; Followup ignores the
  From and To dates; active committees only; other pages that open ViewReport.aspx do not clear the report
  kind; the role is read twice per request; a database error gives the finalised-only Minutes report; the
  step 41 procedures do not test IsSystem; Reason 8 is a message with no link to sign-in; Management's
  Followup repeats the draft note for every draft item; the Followup page shows unused From and To date
  boxes; the 150 px "Minutes status" column and the border attribute of the draft note). Two more from the
  owner's tests, to be added to that list by the owner (Database/README.md is outside Documents/):
  (a) in the PDF of a draft, the top border of the DRAFT note touches the "Minutes status" line;
  (b) on the Followup report page the View button's onclick calls a script function that is not defined on
  that page (the browser console shows an error; the page still works). (b) was already there before
  RA1b (baseline code) and is not new in RA1b.

## RA1a - Role access: user accounts and code masters for Admin only (tag access-ra1a, 2026-11-10; database step 40)

- For users: Admin only: User Master, Department, Designation, Member Type, Subject Type and Decision
  Type (Master menu); Reset Password, Backup Database and Audit Trail (Admin menu; Audit Trail now
  after System Settings, before Reset Database). SMTP Configuration, System Settings and Reset
  Database stay Admin only. The Controller keeps Member Master, Committee Master, Committee Member
  Tag / UnTag, Meeting Master, Meeting - Member Tag / UnTag and Attendance; it has no Admin menu, its
  Reports menu has no Audit Trail, and it changes only its own password. A Controller who opens one
  of the hidden pages by address gets the "Access denied" page. A Controller who still reaches a
  user or member type change sees "You are not allowed to [action]. Only an Admin can change other
  users' accounts." or "Only an Admin can change member types.". Management and MD Secretariat: no
  change.
- For installers: run BMMS-Fix-RoleAccess-Step40.sql after step 39 (either order with the build).
  Re-running step 13, 14, 18 or 21 afterwards needs step 40 again. BMMS-Rollback-RoleAccess-Step40.sql
  undoes it. BMMS-Check-InstalledSteps.sql has a row for step 40 (3 markers).
- Database: step 40 replaces fn_UserChangeRefusal (no Controller branch: the Controller has the
  rule of the other non-Admin roles, Reason 4 for everything on another account),
  spr_AddEditMemberType and spr_DeleteMemberTypeByMemberTypeId (Admin only, Reason 4; RAISERROR
  instead of THROW). Marker RoleAccess-Step40 in 3 objects. No data changes.
- Code: PageAccess.xml (nine pages admin only); the menu; the page check
  PageAccessModule.RequireRole("admin") in Page_Load of the nine pages (role read from the database,
  DENIED-PAGE in the page access log) and in the Reset Password and Backup Database buttons.
- Tests on BMMS_Test: BMMS-Test-RoleAccess-Step40.sql 43 of 43 PASS; the Controller expectations of
  BMMS-Test-UserProtection-Stage1.sql (142), BMMS-Test-UserStatus-Stage2a.sql (50) and
  BMMS-Test-MemberTypes-Step21.sql (100) changed for step 40, all PASS.
- Open (security lead): only these nine pages check the role in the database; every other page
  follows the role in the session until sign-out. A later step (RA1d) is to close this.

## WF2b1 - System manual chapters 01-05 (tag docs-wf2b1, 2026-11-09)

- WF2b1: System manual chapters 01-05 from the BMMS_Test catalog export of 2026-11-09; old
  Documentation/ folder merged into System-Manual and removed (Pages.xlsx kept).
- For users: no change. For installers: no change. Database: no change.

## WF2a - Documents baseline and the doc-writer agent

- Documents/ folder with its index, register, update matrix, header-block rules and skeletons of
  every manual, chapter and data-flow file; the diagram notation and a first glossary.
- The doc-writer agent and the documentation stage in the development workflow.
- Export and check scripts and the Gashpy Software Word template.
- For users: no change. For installers: no change. Database: no change.

## Baseline: state at 021e946

The documents start from commit 021e946 (tag user-ud1a, 2026-11-09). Everything before it is
listed in the appendix below, one line per tag, taken mechanically from git. The step sections
of Database/README.md describe each database step in full.

## Appendix: tags up to the documents baseline

Oldest first. Date is the tag date; subject is the subject of the tagged commit.

| Tag | Date | Subject |
|------------------------|------------|------------------------------------------------------------|
| BMMS-Recovered-Baseline | 2026-10-02 | Recovered BMMS legacy baseline |
| critical-1-7 | 2026-10-11 | Fix request validation and client IDs on .NET 4.8; fix user edit password handling |
| critical-5 | 2026-10-11 | Delete pages: read the procedure Result and show the reference message when a delete is blocked |
| critical-done | 2026-10-11 | Store 'no manager' as NULL; add FK_Users_ManagerId; NULL-safe ManagerId reads |
| ui-pilot | 2026-10-13 | UI pilot: Workbench theme for master page, Login, Department and Meeting |
| ui-batch-1 | 2026-10-14 | UI batch 1: Workbench theme for Designation, Member Type, Subject Type and Decision Type masters |
| db-user-delete | 2026-10-14 | User delete: refuse when the user has history; add 21 user-id foreign keys, tests and test-copy-first run order |
| ui-batch-2 | 2026-10-14 | UI batch 2: Workbench theme for Committee, Member, User and the two member tagging pages |
| user-protection-1 | 2026-10-15 | User protection stage 1: own-account, last Admin/Controller and role limits with reason codes |
| user-status-2a-meeting-locks-1 | 2026-10-16 | UI: inactive users (status column, deactivate/activate, login and per-request checks) and meeting locks (members, attendance, finalization pages) |
| meeting-locks-2 | 2026-10-16 | UI: meeting date/committee lock, agenda lock with Controller option, minutes confirm lock, appointment-date member filter, System Settings page |
| user-status-2b | 2026-10-17 | UI: inactive manager refusal (Reason 11), alert mail to every recipient, no reset mail to inactive users |
| user-system-admin-3 | 2026-10-18 | Stage 3 (step 18): system account in the application |
| member-types-21 | 2026-10-19 | Member type master and tagging pages use scope |
| organisation-settings-19 | 2026-10-19 | Member type master and tagging pages use scope |
| agenda-routing-20 | 2026-10-19 | UI step 20: agenda routing, Dashboard buttons by role, minutes attendance layout |
| minutes-gating-22 | 2026-10-19 | UI step 22: minutes and minutes extract lists only finalized or confirmed meetings |
| meeting-dates-24 | 2026-10-19 | UI step 24: meeting date validation and mail after save |
| report-print-25 | 2026-10-19 | UI step 25: working Print and PDF for the minutes, extract, followup and agenda reports |
| public-files-26 | 2026-10-19 | UI step 26: Notice, Agenda Approval and Sitting Fees PDFs no longer written to the public Files/PDF folder |
| notice-mail-28 | 2026-10-19 | Step 28: Notice Send Mail works; error log keeps the first error of each day |
| workflow-order-23 | 2026-10-20 | Step 23: workflow order messages and page checks |
| reset-safe-29 | 2026-10-21 | Step 29: Reset Database page, 300 s timeout, shared default password |
| smtp-default-30 | 2026-10-23 | Step 30 UI: SMTP page accepts empty login, From required, reset page and dialog mention mail settings, wider email check |
| branding-b2 | 2026-10-23 | Step B2: neutral product branding, remove previous organisation images and unused masters, one product name |
| error-handler-e1 | 2026-10-23 | Step E1: show and log errors on UpdatePanel pages (ScriptManager async error handler, message bar, log entry per error) |
| error-handler-e2 | 2026-10-24 | Step E2: global error handler, fixed error page text, redacted request-validation log |
| error-handler-e2b | 2026-10-24 | Step E2b: Exit returns to the failed page; signed-out visitors go to login |
| branding-b3 | 2026-10-24 | Step B3: product artwork and one colour scheme |
| unicode-text-31 | 2026-10-28 | Database step 31: Unicode text columns (varchar(max) to nvarchar(max)) |
| unicode-text-u1b | 2026-10-28 | U1b: UTF-8 mail and responses, Noto Serif PDF fonts, stop for Tamil/Hindi in PDF |
| dashboard-404-f1-e2c | 2026-10-29 | Step F1 and E2c: Dashboard alert link no longer crashes, fixed Page not found page, no version headers |
| dashboard-f2 | 2026-10-29 | Dashboard: guard hidden-field ids and bad alert data (F2) |
| committee-data-f3 | 2026-10-29 | Committee data layer: no crash on NULL values, date required on save (F3) |
| stored-html-a1a | 2026-10-30 | Step A1a: stored rich text cleaned on save and display, plain text encoded |
| file-names-n1 | 2026-10-30 | Step N1: safe names for uploaded files |
| meeting-gate-m1 | 2026-10-31 | Step M1: meeting Edit and Delete for the whole meeting date; sort header fix; saved but mail not sent message |
| sort-headers-a1b1 | 2026-10-31 | Step A1b-1: unique sort header IDs and sort handlers on seven more grids |
| master-html-a1b2 | 2026-10-31 | A1b-2 groups 1-2: encode master data shown on screen |
| state-master-s1 | 2026-10-31 | S1: complete the State_Master list |
| master-html-a1b3 | 2026-10-31 | A1b-2 group 3: encode grid labels on the backup page and seven reports |
| send-mail-sm1 | 2026-11-01 | SM1: Send Mail attachments as plain files, clearing after send, plain messages |
| agenda-date-m4 | 2026-11-01 | M4: no new agenda items after the meeting date; notice after the submission date |
| mail-after-save-m2-m3 | 2026-11-01 | M2 and M3: send mail only after a successful save; plain warning when the mail fails |
| agenda-edit-delete-m5-n4 | 2026-11-01 | M5 and N4: no edit or delete of agenda items after the meeting date; Finalisation keeps the item's text |
| agenda-dashboard-m6a | 2026-11-01 | M6a: Dashboard Approve and Reject refused after the meeting date |
| meeting-delete-d1 | 2026-11-01 | Step D1: deleting a meeting removes its alerts and refuses past or in-use meetings |
| subjectno-n5 | 2026-11-01 | Step N5: empty Subject No stays empty and an approved item's number cannot be changed |
| file-names-n2 | 2026-11-01 | Step N2: attachment and agenda text names come from the server and are checked where they are read |
| agenda-approval-print-ap1 | 2026-11-02 | AP1: restore Print option on Agenda Approval; PDF lists only Controller-approved items |
| editor-a2a | 2026-11-04 | Step A2a: own rich-text editor on Agenda Entry and Update Minutes |
| editor-a3 | 2026-11-04 | Step A3: own rich-text editor on Dashboard, Followup and Send Mail |
| editor-a4 | 2026-11-04 | Step A4: remove FreeTextBox from the project |
| layout-a2b | 2026-11-05 | A2b: card layout for Agenda Entry and Update Minutes; secondary button states fixed |
| comments-c1 | 2026-11-06 | C1: comment editors by role (Manager and Controller comments editable only by their role) |
| header-popups-h1 | 2026-11-06 | WIP H1: header visible in Dashboard popups (untested) |
| manager-department-c2 | 2026-11-07 | C2: Manager sees and edits department agenda items; Entered by column; server checks |
| names-un2 | 2026-11-07 | UN2: person's name with login tooltip in header; logged-in check by UserId; login ID in access log (step 34) |
| footer-f1 | 2026-11-07 | F1: footer version 1.1.0 from AssemblyInformationalVersion; database name for Admin and Controller |
| names-un3 | 2026-11-07 | UN3: Name (login) in user pickers, Audit Trail and backup list |
| grid-width-g1 | 2026-11-07 | G1: User Master grid fits inside its card; sort arrow stays with its heading |
| viewstate-pw1 | 2026-11-07 | PW1: password hash no longer kept in the User Master list |
| names-un4 | 2026-11-08 | UN4: who and when on Manager/Controller comments (step 35); M7: Add shows Meeting No, not MeetingId |
| alerts-al1 | 2026-11-08 | AL1: an edited agenda item re-alerts the next approver (step 36); header counts unread alerts only |
| mail-ml1 | 2026-11-08 | Step ML1 (step 37): mail when an agenda item is updated |
| mail-ml1b | 2026-11-08 | Step ML1b: an Entry item keeps no agenda text file name |
| mail-ml2a | 2026-11-08 | Step ML2a: keep the configured Bcc and send each address once |
| mail-ml2b | 2026-11-09 | Step ML2b: comment, Subject No and date format in the agenda mails |
| user-um2 | 2026-11-09 | UM1+UM2: User Master email accepts digits, capitals and hyphen (50 characters); user grid keeps Edit, Deactivate and Delete inside the card |
| user-un6a | 2026-11-09 | UN6a (step 38): due date for Followup decisions on Update Minutes |
| user-un6a1 | 2026-11-09 | UN6a1: due date not passed keeps the stored date; build works with or without step 38; clearer save message |
| user-ml2c | 2026-11-09 | ML2c: a bad To or Bcc address is skipped and logged, the mail fails only when nobody valid is left (Reset Password and Notice need a valid To); one shared helper for reading the item after save |
| workflow-wf1 | 2026-11-09 | WF1: reviewer subagents (security, UX, UI) and development workflow in CLAUDE.md |
| user-ud1a | 2026-11-09 | UD1a: user role and department history, multi-department Managers (step 39) |
