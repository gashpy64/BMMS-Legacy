# BMMS Change Log

- Title: BMMS Change Log
- Audience: Gashpy Software (internal)
- Shipped: No
- Applies to: UN6c2a
- Last updated by: UN6c2a, based on 493cb45
- Status: Draft
- Verified against: for UN6c2a: git diff HEAD (493cb45) and the new files (BMMS/DashBoard/DashBoard.aspx(.cs, .designer.cs),
  BMMS/UserControl/MeetingSummary.ascx(.cs), BMMS/CSS/bmms-workbench.css, BMMSBAL/AgendaMgr.cs and MeetingMgr.cs,
  BMMSDAL/AgendaDB.cs and MeetingDB.cs, Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (read in full),
  BMMS-Rollback-AgendaWaitingFor-Step44.sql, BMMS-Test-AgendaWaitingFor-Step44.sql (header and the comparison part),
  BMMS-Check-InstalledSteps.sql, BMMS-Test-DashboardMeetings-Step42.sql, Tests/packs/dashboard/*, Tests/fixture/*,
  Tests/README.md, Database/README.md section Step UN6c2a and Known items), the tester run of 2026-11-14 07:52:25 and
  the owner's tests as given; for UN6c1: git diff against e3bff6b and the new files (BMMS/DashBoard/DashBoard.aspx(.cs, .designer.cs),
  BMMS/MasterPage/Main.Master(.cs, .designer.cs), BMMS/CSS/bmms-workbench.css, BMMS/UserControl/MeetingSummary.ascx.cs,
  BMMSBAL/AlertMgr.cs, ActionItemMgr.cs and Common.cs, BMMSDAL/AlertDB.cs and ActionItemDB.cs,
  Database/BMMS-Fix-DashboardAlerts-Step43.sql, BMMS-Rollback-DashboardAlerts-Step43.sql, BMMS-Test-DashboardAlerts-Step43.sql
  (header), BMMS-Check-InstalledSteps.sql, Tests/packs/dashboard/*, Tests/fixture/*, Database/README.md section Step UN6c1
  and Known items), the owner's tests and the tester run of 2026-11-13 as given; for UN6b: git diff against 0736c7f and the new files (BMMS/UserControl/MeetingSummary.ascx(.cs, .designer.cs),
  BMMS/DashBoard/DashBoard.aspx(.cs), BMMSBAL/MeetingMgr.cs and DepartmentMgr.cs, BMMSDAL/MeetingDB.cs and
  DepartmentDB.cs, Database/BMMS-Fix-DashboardMeetings-Step42.sql, BMMS-Rollback-DashboardMeetings-Step42.sql,
  BMMS-Test-DashboardMeetings-Step42.sql (header), BMMS-Check-InstalledSteps.sql, Tests/_runner/Run-Tests.ps1 and
  Tester.Common.ps1, Tests/packs/dashboard/*, Tests/fixture/*, Database/README.md section Step UN6b and Known
  items), the owner's tests and the tester run of 2026-11-12 as given; for RA1c2: git diff against 1db6ac6 (BMMS/Report/FollowupActionTaken.aspx(.cs, .designer.cs),
  MenuUserControl.ascx, XML/PageAccess.xml, PageSettings.xml, BMMS.csproj, the deleted Error/TestPage files,
  Tests/packs/access-matrix/*, Database/README.md section Step RA1c2), the tester result and the owner's tests as
  given; for RA1c1: git diff against 4946500 (BMMS/Report/ViewReport.aspx.cs, BMMS.csproj,
  XML/PageAccess.xml, PageAccessModule.cs, Tests/packs/access-matrix/*, .claude/agents/tester.md,
  Tests/README.md, Database/README.md section Step RA1c1), the owner's test result and the tester run of
  2026-11-11 as given; for WF3a2: CLAUDE.md, .claude/agents/tester.md, Tests/README.md, Tests/_runner/*,
  Tests/lib/run.js, Tests/packs/access-matrix/*, Database/README.md (section Step WF3a2 and Known items
  for later steps), the owner's test result and the tester run of 2026-11-11 as given; for WF3a1: Tests/README.md, Tests/_runner/*, .claude/agents/tester.md,
  .claude/hooks/tester-guard.ps1, Database/README.md (section Step WF3a1), the owner's test result; and for the rest: git tags and commit subjects (git for-each-ref refs/tags), Database/README.md, the diff
  of step RA1b (BMMS/Report/*.cs, PageAccessModule.cs, PageAccess.xml, MenuUserControl.ascx, BMMSBAL,
  BMMSDAL), Database/BMMS-Fix-ReportAccess-Step41.sql
- To confirm: the tag of UN6b (not set when this entry was written); the tag of RA1b (not set when this entry was written); the two new Lows (a) and (b) are not yet
  in Database/README.md, "Known items for later steps"

One entry per step, newest first. Each entry names the step, its tag and what changed for users,
for installers and in the database. Release entries (tags vX.Y.Z) collect the steps since the
previous release.

## UN6c2a - Dashboard My approvals panel, Waiting for me column, one rule for who may approve, wider Meetings card (tag not yet set, 2026-11-14; database step 44)

- For users: the Controller and the Manager have a new card, "My approvals (n)", above the Meetings and Alerts cards. It
  lists the items that wait for their approval (the Controller: the items the Manager has approved; the Manager: the items
  sent to him, as the creator's manager or by an alert, also one he removed from his list), of meetings whose agenda
  is open and whose date has not passed, newest meeting first, 10 to a page, with the columns Item, Committee, Meeting
  and Department; it follows the Committee drop-down and the Manager's Department drop-down. Nothing waiting: "Nothing is
  waiting for your approval." The User, Management, MD Secretariat and the Admin have no card. The Scheduled list has
  a ninth column, "Waiting for me" (Controller and Manager): how many items of the meeting wait for him now; Pending
  still counts every item still waiting for any approver (for a Manager also items of his departments that wait for
  another Manager, and items of a meeting whose date has passed). Clicking an item opens the Agenda Alert panel and marks
  only the person's own alert read; after Approve or Reject the panel, the counts, the Alerts card and the header
  follow. Approve and Reject now show only to a person who may approve the item (before: to every Controller at AMA
  and every Manager at AC, and the server refused what was not his), while the agenda is open and the meeting date
  has not passed. When the person could decide an item whose meeting date has passed, the panel opens without
  Approve and Reject and "The meeting date has passed, so this item can no longer be approved or rejected. It will be
  rejected when the agenda is finalized." now shows inside the panel, just above Close and "Remove from my list" (it
  showed in the page's message box under the panel). New messages: "Whether you may approve this item could not be
  checked, so it is shown read-only. Close it and open it again.", "The item could not be checked, so nothing was
  changed. Try again.", and for the card "The approvals could not be loaded. Reload the page to try again.", the
  server-busy text, "The approvals are not available: your account is not active. Sign in again." and "The approvals
  cannot be shown for this choice. Choose All committees or All my departments." The meeting date is now judged by
  the database server's date (before, the web server's date). Layout: the Meetings card is three parts of four of the
  content width beside the Alerts card (before, about two thirds); the cards stack at 1240 px and below (before, under
  1100 px) and stand side by side from 1241 px; the nine-column Scheduled list fits its card from 1241 px and scrolls
  inside the card when it is narrower. Described in the Overall manual, the Controller and Manager manuals (and the
  User and Admin manuals for what they do not have), and the Glossary.
- For developers: DashBoard.aspx(.cs) has the panel (`cardApprovals`, `grvApprovals`, `LoadApprovals`,
  `lnkApproval_Click`), `TryGetApprovalState`, `ShowAgendaPanelMessage` and a message paragraph inside the Agenda Alert
  panel; `BindAgendaDetails`, `btnApprove_Click` and `btnReject_Click` ask the server for the state instead of
  deciding from the role and the status; MeetingSummary.ascx(.cs) has the column "Waiting for me", the properties
  `CommitteeId` and `DepartmentId` and the event `FiltersChanged`; new `AgendaMgr` / `AgendaDB` methods
  `GetDashboardApprovals` and `GetAgendaApprovalState`; `MeetingMgr` / `MeetingDB.GetDashboardMeetings` has the extra
  output `WaitingShown`; CSS: grid 3fr / 1fr, the panel's grid area, the 1240 px rule, 4 px padding of the number cells
  and the Status cell (by column position).
- For installers: run BMMS-Fix-AgendaWaitingFor-Step44.sql (after step 43) before the new build, on BMMS_Test first,
  then the Test script in a new query window. The earlier build keeps working with step 44 installed.
  BMMS-Rollback-AgendaWaitingFor-Step44.sql puts the two replaced procedures back letter for letter (SHA-1 compared)
  and drops the three new objects (roll back the build first).
- Database: step 44, five objects (marker AgendaWaitingFor-Step44; 5 markers in BMMS-Check-InstalledSteps.sql): new
  fn_AgendaWaitingFor (one rule for who may approve; the database server's date), spr_GetAgendaApprovalState and
  spr_GetDashboardApprovals; replaced spr_UpdateAgendaByAgendaId (same behaviour and order of refusals 12, 8, 4, 5, 14;
  the test "may this user act" reads the function; it still does not check the meeting date) and
  spr_GetDashboardMeetings (one more OUTPUT parameter, @WaitingShown, and one more column, WaitingForMe, last). Reason 12
  (system account), 8 (user missing or inactive) and 4 (a role without the panel, a filter or a page that is not
  allowed, an unknown item). Grants nothing. Test script BMMS-Test-AgendaWaitingFor-Step44.sql: the earlier text of
  spr_UpdateAgendaByAgendaId is run beside the new one on 1352 cases (13 acting users x 13 items x 8 action words) with no
  difference allowed; 120 checks, all PASS (run of 2026-11-14 on BMMS_Test). BMMS-Test-DashboardMeetings-Step42.sql was adjusted in three
  places (71 checks either way); BMMS-Test-DashboardAlerts-Step43.sql is unchanged. The tester's baseline was updated
  for step 44.
- Tests: tester agent, run of 2026-11-14 07:52:25 (Tests/_results/2026-11-14_075225): PASSED, all 751 checks
  (selftest 8, access-matrix 472 with 440 cells ok, dashboard 274); fixture check 38 of 38. The dashboard pack gained
  the My approvals, Waiting for me, fit and meeting-date message checks (side by side at 1241 px and stacked at 1240
  px; the Scheduled list fits its card for the Controller and the Manager, nine columns, at 1366 and 1600 px and for
  Management, eight columns, at 1366 px; a Manager opening the item of a passed meeting sees no buttons and the
  message inside the panel; an item he can decide shows the buttons and no message). Measured: the Meetings card 864
  px wide, its table needs 793 px with the widest realistic cells in an 830 px box (37 px spare). The owner's tests
  passed.
- Known items (Database/README.md, "Known items for later steps"): the meeting-date rule is checked by the page only,
  not by the approval procedure (M6a); items of a meeting whose date has passed that are still at AC or AMA cannot be
  approved by anybody and are not listed in My approvals (on BMMS_Test 8 items are stuck at AC); a Manager's Pending
  can be larger than his Waiting for me until step UD1b; indexes are planned for step UN6e; a Controller may reject
  at AC by the rule, but the panel and the buttons are about AMA only; the browser console message "Permissions policy
  violation" from ScriptResource.axd does not come from the Dashboard (the owner's reading). Review Lows: a UserId 0 corner case in the
  function; the state procedure answers two flags for any item to any active user; the page still chooses the branch
  by the session role; a blank agenda number gives an empty link; the Short Text box may look editable when the buttons
  are hidden; the message sits at the bottom of a tall panel; the Status cell padding is set by column position.

## UN6c1 - Dashboard alert rules, Remove from my list, Action Items scope and Overdue, header count (tag not yet set, 2026-11-13; database step 43)

- For users: the Alerts card has the links Recent | Unread | All (Recent, the default, is every unread alert plus the
  read alerts of the last 7 days); the link you are on is bold; the card shows 10 alerts to a page. The muted line
  reads "type | committee | department | by [Name]" with the login ID as tooltip (a dash where no approver is
  recorded, for old approvals). The second column is "Date" (was "Created on") and shows the date of the event: the
  decision date for an approval, the edit date for an edited item. The buttons "Delete" are now "Remove from my
  list": the alert leaves only your list, an edit of the item brings it back unread, and an id that is not yours is
  refused ("This alert is not in your list."). The header "Alerts (n)" follows Approve, Reject, Remove, opening an
  alert and the three links, and reads "Alerts" without a number when it cannot be read. The Alerts and Action
  Items cards have load-failure and server-busy messages. The Admin gets no functional alerts ("No alerts.",
  "Alerts (0)") and no functional mail; the Controller still does not see ACA and ACR alerts and the Manager AMA
  and AMR. The Action Items card has a "Due date" column with a red "Overdue" word (due date before today by the
  database server's date, item neither complied nor confirmed), is ordered newest meeting first, has the links
  Show All | Read | Unread (the current one bold and kept when an item is opened or the page is changed), and a bold
  row means unread for you. Its scope is now decided on the server: the Controller and Management see every item
  that is not confirmed; the Manager and the User see the items of their departments whose minutes are finalised or
  confirmed; MD Secretariat and Admin have no card. Management can open an item but its Submit is refused ("You
  cannot change this action item: your role can only read it, or it is not an item of your department. Nothing was
  saved."; the button is still visible until step UN6d). What users will notice: items of another department are
  gone, Users and Managers no longer see items of open (draft) minutes, a Controller sees each open item in bold once
  after the update. The Committee drop-down narrows the Meetings card only; the Alerts and Action Items cards do not
  follow it. Described in the Overall manual and the four role manuals (Dashboard).
- For developers: DashBoard.aspx(.cs) reads the alerts a page of 10 at a time (custom paging, mode in ViewState) and
  the action items through the new procedures; Main.Master(.cs) has the count in its own UpdatePanel and
  `RefreshAlertCount()`; `Common.IsServerBusy` moved from MeetingSummary.ascx.cs to BMMSBAL/Common.cs; new
  AlertMgr / AlertDB (GetDashboardAlerts, GetAlertCount, RemoveAlertForUser) and ActionItemMgr / ActionItemDB
  (GetDashboardActionItems, OpenDashboardActionItem, SaveDashboardActionText); CSS for the bold current link, the
  person tooltip and the Overdue chip. The role is read from the database; the page sends the acting user id only.
- For installers: run BMMS-Fix-DashboardAlerts-Step43.sql (after step 42) before the new build, on BMMS_Test first,
  then the Test script in a new query window. BMMS-Rollback-DashboardAlerts-Step43.sql drops the eight new objects
  and restores the two mail procedures letter for letter (roll back the build first). The read rows that opening an
  action item created stay after a rollback.
- Database: step 43, ten objects (marker DashboardAlerts-Step43; 10 rows in BMMS-Check-InstalledSteps.sql): new
  fn_DashboardAlerts, spr_GetDashboardAlerts, spr_GetAlertCount, spr_RemoveAlertForUser, fn_DashboardActionItems,
  spr_GetDashboardActionItems, spr_OpenDashboardActionItem and spr_SaveDashboardActionText; replaced
  spr_GetAlertMailId and spr_GetAgendaUpdateMailId (the Admin role left out). Compatibility level 100 (ROW_NUMBER
  paging). Test script BMMS-Test-DashboardAlerts-Step43.sql. The tester's baseline was updated with
  Update-Baseline.ps1, and BMMS_Quality rebuilt with the extended fixture (35 fixture checks).
- Tests: Test script step 43, 128 numbered checks, all passed on BMMS_Test. Tester agent, run of 2026-11-13: PASSED,
  702 checks (selftest 8, access-matrix 472, dashboard 225). The dashboard pack gained the alert, action item,
  filter-kept and scope checks. The owner's tests on BMMS_Test passed.

## UN6b - Dashboard in cards; meeting list with status colours and counts by role (tag not yet set, 2026-11-12; database step 42)

- For users: the Dashboard has a new Meetings card in place of the old Scheduled Meetings list. It lists every
  scheduled meeting (no limit) and the last 10 completed meetings, for every role. A meeting dated today is
  Scheduled until the end of that day. Each meeting has a coloured status label: Open for submission (blue),
  Submission closed (orange), Agenda finalised (green), Minutes pending (red), Minutes finalised and Minutes
  confirmed (grey). The Controller, Management, the Manager (own departments) and the User (own department) also see
  Items, Approved, Rejected and a last column ("In progress" for the User, "Pending" for the others); MD
  Secretariat and Admin see no counts. The Controller, Management, MD Secretariat and Admin have a Committee
  drop-down and the title "Meetings". The Manager has the Committee drop-down, a Department drop-down only with two
  or more departments, the subtitle "Departments: [a, b]" (or "Department: [name]") and the title "Meetings, items
  of my departments" or "Meetings, [department] items". The User has no drop-down, the subtitle "Department:
  [name]" and the title "Meetings, [department] items". The Manager and the User see a completed meeting only when
  it has items of their department. The counts are read again after Approve or Reject. The Alerts card is compact:
  "Alert" (the link, with the alert type, committee and department below it) and "Created on" (dd-MMM-yyyy, with
  HH:mm below it). If the meeting list cannot be loaded the card says "The meeting list could not be loaded. Reload
  the page to try again." (or, for a timeout or lack of memory, "The server is busy and the meeting list could not
  be loaded. Wait a moment, then reload the page.") and the filters are hidden. The cards stack under 1100 px, and
  the Agenda Alert and Action Item Details panels fit narrow windows. Described in the Overall manual and the four
  role manuals (Dashboard).
- For developers: UserControl/MeetingSummary.ascx(.cs) is rewritten (role table `RoleViews`, titles, chips,
  failure and server-busy messages); DashBoard.aspx is a grid of cards (`.wb-dash`); DashBoard.aspx.cs calls
  `MeetingSummary1.Reload()` after Approve and Reject and has `FormatTimeOfDay` and `AlertDetails`;
  `MeetingMgr.GetDashboardMeetings` and `DepartmentMgr.GetDashboardDepartments` with their DAL methods; the
  Dashboard section of bmms-workbench.css. Scope is decided on the server from the acting user id.
- For installers: run BMMS-Fix-DashboardMeetings-Step42.sql (after step 41) before the new build, on BMMS_Test
  first. BMMS-Rollback-DashboardMeetings-Step42.sql drops the five objects (roll back the build first).
- Database: step 42, five read-only objects (marker DashboardMeetings-Step42; 5 rows in
  BMMS-Check-InstalledSteps.sql): fn_MeetingDashboardState, fn_UserDepartmentScope, fn_AgendaStatusGroup,
  spr_GetDashboardMeetings and spr_GetDashboardDepartments. Nothing is replaced; spr_GetScheduleMeet is unchanged
  and has no caller (to be dropped in a later step). Test script
  BMMS-Test-DashboardMeetings-Step42.sql. The tester's baseline was updated with Update-Baseline.ps1.
- Tests: Test script step 42, 71 of 71 (owner's run on BMMS_Test). Tester agent, run of 2026-11-12 21:46:42
  (Tests/_results/2026-11-12_214642), packs access-matrix and dashboard: PASSED, 649 checks, no new error-log
  line, memory at the start 1522 MB available of 7886 MB. The new pack dashboard (12 cases; the fixture has a new
  committee QA2). The tester's preflight now reads the available memory and warns below 1500 MB (never a refusal;
  a VOID or RUNNER FAILED summary says when the memory was low). The owner's tests passed: all six role views,
  widths 1366, 1024, 900 and 800 px, the two panels, the counts after Approve and Reject, the compact Alerts card,
  the failure test and the timeout test.
- Planned, not done: step UN6c (the header "Alerts (n)" refresh, "My approvals", the summary cards, "Waiting for
  me", the Alerts functional-alert rule for Admin); step WF3a3 (the tester reads its own result when a run moves
  to the background); step UN6e (an index on Agenda for the counts). Further follow-up items are in
  Database/README.md, "Known items for later steps".

## RA1c2 - Followup by Department in the Controller's Reports menu; Error/TestPage removed (tag not yet set, 2026-11-12; no database step)

- For users: the Controller's Reports menu has a new item, "Followup by Department", after Followup
  Summary (the Controller only; a Manager who opens it gets "Access denied"). It now shows only the
  meetings of the committee you choose (before, a meeting number that exists in two committees showed the
  items of both). Export to Pdf now works for this report (it used to print a fallback sentence); it still
  cannot print Tamil or Hindi text, so use Export to Word or Print for those. Described in the Controller manual.
- For developers: Report/FollowupActionTaken.aspx checks the role first in Page_Load and again first in
  Generate Report (PageAccessModule.RequireRole("controller"); PageAccess.xml roles="controller", was
  controller and manager); its title and heading are "Followup by Department" (new PageSettings.xml entry); the
  committee filter is made in the page because spr_GetActionItemByMeetingIdDeptId ignores @CommitteeId; the
  report table uses border='1' instead of '1px' and the stray style block is removed; the unused Send Mail code
  of the page is removed. Error/TestPage.aspx, .aspx.cs and .designer.cs are deleted with their BMMS.csproj
  entries and the PageAccess.xml comment. Counts: 44 pages on disk (45 before), 43 page entries in
  PageAccess.xml (44 before). The access-matrix pack has 55 addresses (56 before); the Followup by Department
  row is Controller "opens", Manager "Access denied"; the cell words "to be removed (RA1c1)" and "to be
  decided (RA1c2)" are retired, so no notes are left.
- For installers: nothing to run; the next site build has the new menu item and no TestPage.
- Database: no numbered step; no row in BMMS-Check-InstalledSteps.sql.
- Tests: tester agent, -Pack access-matrix: PASSED, all 477 checks passed, 0 notes. The owner's tests passed.
  The build check counts and the reviewer records are not given to the documentation stage.

## RA1c1 - Event Calendar and Report Print removed; ViewReport with no report (tag not yet set, 2026-11-11; no database step)

- For users: the Event Calendar and Report Print pages are gone (nothing in the menu or the report
  windows linked to them); an old bookmark to either address gets "Page not found". The report window
  (ViewReport.aspx): when it is opened with no report stored, for example by address or after the session
  ended, it shows "The report is no longer available. Close this window and click Generate again." (HTTP
  200, no error-log entry) instead of an error; the same message appears if Export to Pdf or Export to
  Word is clicked with no stored report. Management is still refused first ("Access denied") when the
  window is opened with no report kind. No user manual mentions either removed page (searched).
- For developers: BMMS/Report/EventCalendar.aspx and ReportPrint.aspx with their .cs and .designer.cs files
  are deleted, with their BMMS.csproj entries and PageAccess.xml lines (44 page entries, 3 public; the
  site has 45 pages). The comment in PageAccessModule.cs no longer names ReportPrint. The access-matrix
  pack has 56 addresses (60 before); the rows of the two pages are removed from expected.csv and from the
  not-in-menu file, and the pack README is updated. The tester agent's command timeout is raised
  (.claude/agents/tester.md: the Bash tool with timeout 600000, not in the background; guard unchanged).
- For installers: nothing to run; the next site build no longer has the two pages.
- Database: no numbered step; no row in BMMS-Check-InstalledSteps.sql.
- Tests: build checks passed (compile 0 errors; site precompile exit 0, 45 pages). Tester agent,
  -Pack access-matrix (Tests/_results/2026-11-11_230233): PASSED, all 485 checks; 448 matrix cells, 446
  ok, 0 failed, 2 notes (Followup Action Taken for the Controller and the Manager, to be decided in RA1c2);
  standing proof holds; no new line in the error log; 202 s. The owner's tests passed on 2026-11-11 (the
  Minutes report with Print, Export to Pdf and Export to Word; ViewReport.aspx opened directly as the
  Controller shows the message and as Management gives "Access denied"; the two removed addresses give
  "Page not found"). Reviewers: security Pass; ux and ui Pass with notes (Lows in the backlog).
- Later step, not in RA1c1: the tester's results-folder file (Tests/_results/latest.txt), so that the
  tester agent can find its results folder when its command moves to the background after 180 s.

## WF3a2 - Access-matrix pack, tester stage in the workflow, four security Lows closed (tag not yet set, 2026-11-11; no database step)

- For users: nothing. No product code changed and no page, message or role right changed. No user
  manual is touched.
- For developers: the tester has its first real pack, access-matrix (Tests/packs/access-matrix/): 60
  addresses by eight columns (qa_admin, qa_ctrl, qa_manager, qa_user, qa_mgmt, qa_mdsec, qa_inactive and
  a visitor not signed in), each cell opens, Access denied, sign-in page or Page not found. The
  expected files are drafted from the owner's access rules, approved by the owner and never changed by
  the tester. The pack agrees them with PageAccess.xml and the menu; a page on disk in neither
  expected.csv nor PageAccess.xml fails the run; not-in-menu.csv and home-link.csv are approved lists.
  Standing proof on every run: one entry of PageAccess.xml is changed in the site copy only and undone
  in a finally block; the run is VOID if the cell is not caught or the site copy's file differs from the
  working tree's afterwards. -ProofFullMatrix (owner only) runs it over every row. Notes "to be removed
  (RA1c1)" (Event Calendar, Report Print) and "to be decided (RA1c2)" (Followup Action Taken for the
  Controller and the Manager) are never failures. Workflow (CLAUDE.md): plans list "tester" and
  "owner by eye" checks; new step 5 Tester (Update-Baseline.ps1 first for a new database script; a
  failure goes to the owner as it is; the tester never changes a test); the report has six parts, the
  tester record verbatim as the sixth. Security: the four Lows of WF3a1 are closed (allow-list of server
  permissions before every run and again after the restore and before the baseline backup; read-back of
  the permissions on the site copy's connection file; the site copy runs from the runner's own IIS
  Express configuration that lets in only callers on this laptop (the loopback addresses), and every run probes each network address
  and stops unless it is refused; every run reads the Windows Firewall and prints a warning in the
  console and in results.md ("Firewall"); -LeaveSiteRunning is refused only when a profile lets inbound
  traffic in by default; the runner changes no Windows rule).
- For installers: nothing.
- Database: no numbered step; no row in BMMS-Check-InstalledSteps.sql.
- Tests: the owner's tests passed on 2026-11-11 and the expected files are approved. Tester run
  (Tests/_results/2026-11-11_215849): FAILED on exactly the two ViewReport.aspx cells (Controller and
  Manager: expected opens, seen HTTP 500; a known product defect, fixed in RA1c1); 501 checks, 499
  passed; self-test 3 of 3 planted failures caught; access matrix 464 cells, 444 ok, 2 failed, 0 owner
  to decide, 18 notes; standing proof holds; no request outside localhost; 170 s, about 510 page
  requests (measured runs 158 to 216 s, over the plan's two minutes; Tests/README.md says about three
  minutes). The one-time full-matrix proof changed exactly one cell. A later self-test with
  -LeaveSiteRunning passed, with the Firewall warning for the rule "WFD Driver-only (TCP-In)".
- Found, for the owner (Database/README.md, section Step WF3a2): Report/EventCalendar.aspx runs out of
  memory on every opening and every signed-in role may open it (removed in RA1c1); ViewReport.aspx
  opened directly gives the Controller and the Manager HTTP 500 (fixed in RA1c1); Followup Action Taken
  for the Controller and the Manager (RA1c2). The test from another machine is the owner's step. Lows
  are in "Known items for later steps".

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
- Not yet (done in WF3a2): the first real pack (the access matrix) and the change of the development
  workflow in CLAUDE.md.
- Tests: Setup ran to the end (fixture check 29 of 29); the selftest pack PASSED (5 checks, 3 of 3
  planted failures caught, about 20 seconds); -CheckOnly READY; -LeaveSiteRunning and -StopSite work;
  Update-Baseline.ps1 ran with the Fix script of step 41; the guard blocked every forbidden command,
  tool and path form tried. security-reviewer and ux-reviewer: pass, no High or Medium open. The
  owner's tests passed on 2026-11-11.
- Known items for later (Lows): in Database/README.md, "Known items for later steps". Four security
  Lows, closed in WF3a2: the pre-run check allow-list, the role check timing, the read-back
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
