# BMMS Change Log

- Title: BMMS Change Log
- Audience: Gashpy Software (internal)
- Shipped: No
- Applies to: MF1; AZ2; AZ1; UI2a; UI1; GM1a; IU1; UD1c; UD1b; DA1; MR1; RA1d; UN6e; FU2b; FU2a; FU1
- Commit: 00b6062
- Last updated by: MF1, based on 00b6062 (the MF1 entry)
- Status: Draft
- Verified against: for MF1: git diff HEAD (00b6062) (BMMS/Master/MinutesFinalization.aspx(.cs, .designer.cs) and MinutesConfirmation.aspx(.cs, .designer.cs), BMMSBAL/HtmlCleaner.cs and MinutesMgr.cs, BMMS/CSS/bmms-workbench.css, Database/README.md section Step MF1 and Known items), BMMSBAL/MeetingMgr.cs (MinutesNotUpdatedMessage), the build, reviewer, tester (2026-11-27_115855, 2026-11-27_121332) and owner results as given; for AZ2: git diff HEAD (1b5ec0a) (Database/BMMS-Check-InstalledSteps.sql, Database/README.md section Step AZ2 and Known items) and the new files (BMMS-Fix-DatabaseLocal-Step57.sql: guards and closing lines read; the Rollback and Test scripts of step 57 read at their headers and guards), the Test, tester and owner results as given; for AZ1: git diff HEAD (00838ed) (.gitignore, BMMS/BMMS.csproj, BMMSBAL/BMMSBAL.csproj, BMMS/Web.config, BMMS/JScript/ddlevelsmenu.js, BMMSBAL/WordUtilities.cs, Tests/_runner/Tester.Common.ps1, the deleted BMMSBAL/DocToString.cs, the deleted and moved files under bin, Database/README.md section Step AZ1 and Known items) and the new files Lib/iTextSharp/README.txt and Lib/AjaxControlToolkit/README.txt (read in full), the build, tester (2026-11-26_224034, 2026-11-26_225141) and owner results as given; for UI2a: git diff HEAD (3744571) (BMMS/Master/AgendaFinalization.aspx, MinutesFinalization.aspx, MinutesConfirmation.aspx and Followup.aspx, BMMS/XML/PageSettings.xml, BMMS/CSS/bmms-workbench.css (comment only), Tests/README.md, Database/README.md Known items), the owner's tests and the tester runs 2026-11-26_174407, 2026-11-26_175022 and 2026-11-26_213510 as given; for UI1: git diff 2e1cf53 (BMMS/CSS/bmms-workbench.css and bmms-forms.css read in full; the 18 changed .aspx pages named by the requirement, not read line by line; Database/README.md Known items), the owner's tests and the tester runs 2026-11-26_131553 and 2026-11-26_135255 as given; for GM1a: git diff 32c619d (BMMS/Master/Department.aspx.cs, BMMS/PageAccessModule.cs, BMMS/UserControl/MenuUserControl.ascx, BMMS/XML/PageAccess.xml and PageSettings.xml, BMMSBAL/DepartmentMgr.cs, BMMSDAL/DepartmentDB.cs, Database/BMMS-Check-InstalledSteps.sql (listed), the guards added to the Fix and Rollback scripts of steps 47 and 54 (listed), Tests/packs/access-matrix/expected.csv, Database/README.md section Step GM1a and Known items) and the new files (BMMS/Report/GovernanceMatrix.aspx(.cs) and BMMSBAL/GovernanceMgr.cs read in full; BMMSDAL/GovernanceDB.cs method names; BMMS-Fix-GovernanceLog-Step56.sql: the table, the setting, fn_GovernanceRefusal, fn_GovernanceDeptList and the five read procedures read, the rest at the comment blocks; the Rollback and Test scripts of step 56 not read line by line), the Test, tester and owner results as given (the tester run folder 2026-11-25_170101 as named); for IU1: git diff 79f50ea (BMMS/Master/Meeting.aspx.cs, Committee.aspx.cs, ResetPassword.aspx(.cs, .designer.cs), BMMSBAL/AlertMgr.cs and UserMgr.cs, BMMSDAL/AlertDB.cs and UserDB.cs, Database/BMMS-Check-InstalledSteps.sql, the guards added to the Fix scripts of steps 23 and 53 and the Rollback of step 53, the three changed Test scripts, Database/README.md section Step IU1 and Known items) and the new files (BMMS-Fix-InactiveUsers-Step55.sql: the three new objects read in full, the alert and action item row inserts of the three replaced procedures read; the Rollback and Test scripts of step 55 not read line by line), the Test, tester and owner results as given (the tester run folder 2026-11-25_105953 as named in Database/README.md); BMMS/Master/ResetPassword.aspx.cs read for the old inactive message; for UD1c: git diff HEAD (42cb88c) (BMMS/Master/Agenda.aspx(.cs), BMMS/Master/User.aspx.cs, BMMS/Report/Reports.aspx.cs, BMMSBAL/DepartmentMgr.cs, MeetingMgr.cs, UserMgr.cs and ReportsMgr.cs, BMMSDAL/MinutesDB.cs, Database/BMMS-Check-InstalledSteps.sql, the guards added to the Fix and Rollback scripts of steps 33 and 53, the changed Test scripts of steps 33 and 44, Tests/README.md, Tests/_runner/*, Tests/fixture/*, Tests/packs/session-check/README.md, Database/README.md section Step UD1c and Known items) and the new files (BMMS-Fix-ManagerScope-Step54.sql: the seven new objects, spr_GetAgendaByMeetingIdDeptId and the comment blocks and Reason checks of the other two read, the long procedure texts not read line by line; the Rollback and Test scripts of step 54 not read; Tests/packs/manager-scope/README.md read in full), the Test and tester results and the owner's tests as given (the tester run folder names were not given); BMMSBAL/AgendaMgr.cs, BMMSDAL/AgendaDB.cs, DepartmentDB.cs and UserDB.cs were listed by the diff stat only; for UD1b: git diff db1d641 (BMMS/Master/Agenda.aspx.cs, SystemSettings.aspx, User.aspx.cs, BMMS/DashBoard/DashBoard.aspx(.cs), BMMS/CSS/bmms-workbench.css, BMMSBAL/AgendaMgr.cs, MeetingMgr.cs and UserMgr.cs, BMMSDAL/AgendaDB.cs, Database/BMMS-Check-InstalledSteps.sql, the guards added to the Fix and Rollback scripts of earlier steps, the changed Test scripts, Tests/README.md, Tests/_runner/*, Tests/fixture/* (listed), Tests/packs/dashboard and session-check (diff), Database/README.md section Step UD1b and Known items) and the new files (BMMS-Fix-DepartmentApprovers-Step53.sql: header, functions and mail and alert procedures read, the long save and user procedures only at their comment blocks and alert statements; the Rollback and Test scripts of step 53 not read line by line; Tests/packs/two-approvers/README.md read in full), the Test and tester results as given (run 2026-11-23_182026); for DA1: git diff 5f8c4fe (CLAUDE.md, .claude/agents/doc-writer.md, .gitignore, Database/README.md Known items, Documents/README.md, Documents/_build/Check-Documents.ps1, DocTools.ps1 and Export-Documents.ps1) and the new files (.claude/agents/doc-auditor.md read in full; .claude/hooks/doc-auditor-guard.ps1 header and rule lines; Documents/_build/Export-Catalog.ps1 parameters and rules; Documents/Audit/README.md read in full), the test results and the live checks of 2026-11-19 as given; for MR1: git diff e1b90dc (BMMSBAL/UserMgr.cs and MeetingMgr.cs, Database/BMMS-Check-InstalledSteps.sql, the Fix scripts of steps 39 and 44, the Test scripts of steps 20, 35, 39 and 44, Tests/README.md, Tests/packs/session-check/*, Database/README.md section Step MR1 and Known items) and the new files (the Fix, Rollback and Test scripts of step 52, taken from Database/README.md, not read line by line), the Test results, the tester run 2026-11-19_145521 as given; the owner's tests of MR1 as given; for RA1d: git diff d642746 (BMMS/PageAccessModule.cs, BMMS/Default.aspx.cs, BMMS/Global.asax.cs, BMMSBAL/UserMgr.cs, BMMSDAL/UserDB.cs, Database/BMMS-Check-InstalledSteps.sql, Database/BMMS-Test-SystemAccount-Stage3.sql, Tests/README.md, Database/README.md) and the new files (Database/BMMS-Fix-SessionCheck-Step51.sql read in full; the Rollback and Test scripts of step 51 not read line by line; Tests/packs/session-check/README.md), Database/README.md section Step RA1d and Known items, the Test results, the tester run 2026-11-19_104149 and the owner's tests as given; for UN6e: git diff dbc48ca (BMMS/DashBoard/DashBoard.aspx.cs, BMMS/MasterPage/Main.Master.cs and MainNoMenu.Master.cs, BMMS/Default.aspx.cs, BMMS/Master/Committee.aspx, BMMS.csproj, Database/BMMS-Check-InstalledSteps.sql, Tests/README.md, Tests/_runner/Run-Tests.ps1) and the new files (BMMS/AssetVersion.cs read in full; BMMS-Fix-Indexes-Step50.sql header; Tests/packs/page-assets/README.md), Database/README.md section Step UN6e and Known items, the owner's tests and the tester run 2026-11-18_123549 as given; for FU2b: git diff c4300b5 (BMMS/Report/Followup.aspx(.cs) and FollowupActionTaken.aspx(.cs), BMMS/Master/Followup.aspx(.cs), BMMS/FollowupStatusText.cs, BMMSBAL/ReportsMgr.cs and ActionItemMgr.cs, BMMSDAL/ActionItemDB.cs, Database/BMMS-Check-InstalledSteps.sql, the Rollback and Test of step 47, Database/README.md section Step FU2b and Known items), Database/BMMS-Fix-FollowupReports-Step49.sql (read), the Test results, the tester runs 2026-11-17_133514 and 2026-11-17_135000 and the owner's tests as given;
  for FU2a: git diff 9336d29 (BMMS/DashBoard/DashBoard.aspx(.cs, .designer.cs), BMMS/Master/Followup.aspx.cs, BMMS/CSS/bmms-workbench.css, BMMS/BMMS.csproj, Database/BMMS-Check-InstalledSteps.sql, the Rollbacks and Tests of steps 43 and 45, Tests/packs/dashboard/*) and the new files (BMMS/FollowupStatusText.cs read in full; the three step 48 scripts: the Reason lines of the Fix script only), Database/README.md section Step FU2a and Known items, the Test results, the tester run 2026-11-16_181041 and the owner's tests as given;
  for FU1: git diff 3d571c4 (BMMS/Master/Followup.aspx(.cs, .designer.cs), BMMS/CSS/bmms-workbench.css, BMMSBAL/ActionItemMgr.cs, BMMSDAL/ActionItemDB.cs, Database/BMMS-Check-InstalledSteps.sql, Tests/README.md, Tests/packs/followup/*), Database/README.md section Step FU1 and Known items; the three step 47 scripts were not read line by line (their content is taken from Database/README.md), the Test result (95 of 95), the tester run 2026-11-16_133023 and the owner's tests as given;
  for UN6d: git diff ce7358a 276e402 (BMMS/DashBoard/DashBoard.aspx(.cs), BMMS/Master/Followup.aspx(.cs), BMMSBAL/ActionItemMgr.cs, BMMSDAL/ActionItemDB.cs, BMMS/CSS/CommonHTML.css and bmms-workbench.css, Database/BMMS-Fix-FollowupSave-Step46.sql and BMMS-Rollback-FollowupSave-Step46.sql (read in full), BMMS-Check-InstalledSteps.sql, Database/README.md section Step UN6d and Known items, Tests/README.md, Tests/packs/followup/*, Tests/packs/dashboard/README.md and expected.json, Tests/packs/access-matrix/README.md), Claude outputs/un6d-requirements.md, the Test script and tester results and the owner's tests as given; for UN6c2b: git diff f3cbd7e~1 f3cbd7e (BMMS/DashBoard/DashBoard.aspx(.cs), BMMS/UserControl/MeetingSummary.ascx(.cs), BMMS/CSS/bmms-workbench.css, BMMSBAL/AgendaMgr.cs and ActionItemMgr.cs, BMMSDAL/AgendaDB.cs and ActionItemDB.cs, Database/BMMS-Fix-DashboardSummary-Step45.sql (read), BMMS-Rollback-AgendaWaitingFor-Step44.sql, BMMS-Check-InstalledSteps.sql, Database/README.md section Step UN6c2b and Known items, Tests/README.md, Tests/packs/dashboard/README.md), the tester run of 2026-11-15 and the owner's tests as given; for UN6c2a: git diff HEAD (493cb45) and the new files (BMMS/DashBoard/DashBoard.aspx(.cs, .designer.cs),
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
- To confirm: the tag of UD1c (not set when this entry was written); the tag of UD1b (not set when this entry was written); the tag of UN6b (not set when this entry was written); the tag of RA1b (not set when this entry was written); the two new Lows (a) and (b) are not yet
  in Database/README.md, "Known items for later steps"

One entry per step, newest first. Each entry names the step, its tag and what changed for users,
for installers and in the database. Release entries (tags vX.Y.Z) collect the steps since the
previous release.

## MF1 - The Minutes Items list on Finalize Minutes and Minutes Confirmation (tag not yet set, 2026-11-27; code only, no database step; code not yet committed, based on 00b6062)

- For users (Controller): after Committee Name and Meeting No are chosen, Finalize Minutes and Minutes Confirmation show a second
  card "Minutes Items": a read-only list with the columns Agenda No, Subject No, Short Text, Decision and Actual Resolution, in Agenda
  No order, not sortable. A minute not yet saved in Update Minutes shows "Not yet recorded" in Decision and Actual Resolution; a saved
  minute with no text shows "Not recorded"; a Subject No that is empty or 0 shows "-"; a meeting without minutes shows "No items in
  this meeting." Actual Resolution is shown as plain text (formatting removed, special characters as typed). The list is hidden when
  the committee or the meeting goes back to -Select- or changes, and on Cancel. After Finalize or Confirm the meeting stays chosen and
  the list is read again.
- The confirm question now carries counts (fixed text and numbers only). Finalize Minutes: "Do you want to Finalize this Meeting
  Minutes? Items: [n]."; with minutes not saved on a meeting created before step 23: "Do you want to Finalize this Meeting Minutes?
  Items: [n]. Not yet saved in Update Minutes: [m]."; with minutes not saved on a meeting created after step 23: "Items: [n]. Not yet
  saved in Update Minutes: [m]. These minutes cannot be finalized until every item is saved in Update Minutes. Nothing will be
  finalized."; with no minutes: "This meeting has no minutes to finalize. Nothing will be finalized." Minutes Confirmation: "Do you
  want to Confirm this Meeting Minutes? Items: [n]." Finalize and Confirm stay clickable; after OK the server answers as before.
- Advance warning on Finalize Minutes, in the page's message block with the warning look, when the meeting is chosen: for a meeting
  created after step 23 with minutes not saved or no minutes, the server's own refusal text ("[m] of the [n] minutes have not been
  updated yet. Update every item (Minutes, Update Minutes) before finalizing the minutes." or "This meeting has no minutes to
  finalize (no agenda item was approved)."), only when its agenda is finalized and its attendance recorded (otherwise the server
  refuses for the agenda or the attendance first, which is not forecast); for an older meeting without minutes the page's own
  "No Minutes For the selected Committee/Meeting". It is cleared when the committee or meeting changes, on Cancel and by the message
  of Finalize.
- In the code: MinutesMgr.GetMinutesItemList and the class MinutesItemList (BMMSBAL/MinutesMgr.cs) read the existing
  spr_GetMinutesByMeetingId and give the rows and the counts; HtmlCleaner.ToPlainText (BMMSBAL/HtmlCleaner.cs) turns the rich text into
  plain text; both pages have the new handler ddlMeeting_SelectedIndexChanged (owner-approved exception: the control had AutoPostBack
  but no handler); the shared rule td.wb-col-text in bmms-workbench.css wraps long text. No procedure, table or Reason changed; no
  acting-user check added to the minutes procedures (a separate step).
- Results: build and site precompile 0 errors; the encoding check (12 of 12); reviewers: security Pass, ux Pass with notes (two Medium
  fixed), ui Pass with notes (Low only); tester run 2026-11-27_115855 PASSED, 940 of 940 checks, and after the owner's change C8 run
  2026-11-27_121332 access-matrix PASSED, 485 of 485, error log 0 new lines; owner tests by eye PASSED (2026-11-27, Work Laptop,
  BMMS_Test, Chrome and Edge at 1366 and 1024 px).
- Open items (Lows) are in Database/README.md, "Known items for later steps": a single unbroken string wider than the column scrolls
  the list sideways; Agenda No is sorted as text; no hint for 0 items on Minutes Confirmation; no advance warning when the agenda or
  attendance is missing; the default confirm text is held in two places on each page.
- Documents: System-Manual/05-Application-Code, User-Manuals/03-Controller, Data-Flow/03-Program-to-Program/08-Minutes,
  Documents/README.md (the register entry of 03-Controller and the header).

## AZ2 - No reference to another database in two procedures, so the database deploys to Azure SQL Database (tag not yet set, 2026-11-27; database step 57; no C# change; not yet committed, based on 1b5ec0a)

- For users: nothing changes on the screens. Member Type save and System Settings organisation save behave as before, with the same
  refusal messages.
- In the database (step 57, BMMS-Fix-DatabaseLocal-Step57.sql, marker DatabaseLocal-Step57): spr_SetOrganisationSettings and
  spr_AddEditMemberType no longer read master.dbo.spt_values for the list of control characters; each makes the same 33 characters
  (0 to 31 and 127) with a numbers list inside the procedure. The SSMS deploy to Azure SQL Database had failed with SQL71562 because of
  that reference. Parameters, result sets, Reasons and messages are unchanged; no table, column or data change. The markers of steps 19,
  21 and 40 stay in the texts.
- For installers: guards are the database name like BMMS% and step 56; the Fix ends with the count of references to another database or
  server (0 expected; the x.n.value row of spr_SaveFollowupConfirmed is left out). BMMS-Rollback-DatabaseLocal-Step57.sql puts the step 19
  and step 40 texts back and refuses on Azure SQL Database. BMMS-Test-DatabaseLocal-Step57.sql has 30 checks and also runs on Azure.
  BMMS-Check-InstalledSteps.sql has three markers for step 57.
- Re-run rule: a re-run of the Fix script of step 19, 21 or 40, or of the Rollback script of step 40, after step 57 brings
  master.dbo.spt_values back: step 57 reads Partly; run step 57 again.
- Install order: Work Laptop BMMS_Test, then the tester's baseline (Update-Baseline.ps1), then the Base Laptop's BMMS_Test, then the
  Azure redeploy. The Azure copy (step 51) has a hand change of 2026-11-18 (view dbo.vw_spt_values_P, not in git); the redeploy replaces
  it.
- Results: Test 57 30 of 30; Test 19 52 of 52, Test 21 100 of 100, Test 40 43 of 43; BMMS-Check-InstalledSteps.sql every step Installed
  (53 rows); the Rollback restored both texts with the same SHA-256 as before step 57. Baseline of BMMS_Quality updated with step 57;
  tester access-matrix PASSED, 485 of 485 (Tests\_results\2026-11-27_000952), error log 0 new lines. Owner tests by eye 1 to 5 PASSED
  (2026-11-27, Work Laptop, BMMS_Test). The check on Azure (redeploy) is still to be done.
- Open items (Lows) are in Database/README.md, "Known items for later steps": the C1 characters (step CC1), the guards of the older
  Fix scripts, THROW kept in spr_SetOrganisationSettings, two message wordings of the Fix.
- Documents: System-Manual 03, 04 and 10, Documents/README.md (header). No user manual and no Data-Flow file changed.

## AZ1 - Release build from a fresh clone, third-party DLLs from Lib, the https menu 404 and the .woff2 fonts (tag az1, 2026-11-26; code and project files only, no database step; code not yet committed, based on 00838ed)

- For users: nothing changes on the screens, except two faults found on the first Azure publish. Over https every page no longer shows
  a 404 text above the header (the menu's IFRAME shim is off, `enableshim: false` in JScript/ddlevelsmenu.js; the menus still open
  over drop-down lists in Chrome and Edge). The Public Sans fonts (.woff2) are served with the MIME type font/woff2, so they no
  longer answer 404 on Azure App Service.
- For installers and developers: After pulling this change, Build or Rebuild Solution before opening the site (every page shows
  BMMS - Error until then). The pull deletes itextsharp.dll and AjaxControlToolkit.dll from `BMMS\bin`, and only the build copies them
  back from Lib.
- For installers and developers: Debug and Release now build cleanly from a fresh clone (the Release build failed with CS0246 in
  BMMSBAL: the projects pointed at `..\BMMS\dll\`, a folder git does not track). Every third-party DLL is in `Lib\` (as
  `Lib\HtmlAgilityPack`) and every reference has a HintPath into Lib: `Lib\iTextSharp\itextsharp.dll` (4.0.2.0) and
  `Lib\AjaxControlToolkit\AjaxControlToolkit.dll` (1.0.20229.20821), both moved with git mv from `BMMS\bin`, each with a README.txt
  (version, size, SHA-256, where it is used). No licence text came with either copy: the READMEs name the licence as to be
  confirmed (iTextSharp MPL 1.1 / LGPL, toolkit Ms-PL); the owner adds the texts.
- Office is removed: the Microsoft.Office.Interop.Word reference, the VBIDE COM reference, `BMMSBAL/DocToString.cs` and
  `WordUtilities.CreateWord` (none was used at run time). Word is not needed on the server or the build machine; Export to Word
  of a report still sends HTML as a .doc download.
- Removed from git: the Interop, office, Vbe.Interop and SQL Server (BatchParser, Replication) DLLs under `BMMSBAL\bin\Debug` and
  `BMMS\bin\backupdlls`, and `BMMS\bin\stdole.dll`. Nothing is tracked under any bin or obj folder, which ends the permanent
  " M BMMS/bin/stdole.dll" in git status after a build.
- BMMS/Web.config, system.webServer: staticContent `remove` and `mimeMap` for .woff2 (font/woff2). A runtime Web.config kept
  apart from the repository's needs the same lines.
- Tests/_runner/Tester.Common.ps1: the tester's build no longer passes /p:ReferencePath, so it proves the references resolve
  from Lib.
- In the database: nothing (no database step, no baseline update).
- Results: build checks passed (fresh clone Rebuild Debug and Release, 0 errors, every third-party reference resolved from Lib;
  site precompile 0 errors; the .woff2 MIME entry checked on IIS Express). Reviewers: no High or Medium. Tester
  Tests\_results\2026-11-26_224034 PASSED, 940 of 940 (access-matrix, page-assets, dashboard, followup, followup-reports,
  manager-scope), error log 0 new lines; again with `Tests\_build\out` and `Tests\_site\bin` emptied (2026-11-26_225141):
  access-matrix and page-assets PASSED, 496 of 496. Owner tests PASSED (2026-11-26, Work Laptop, BMMS_Test). The check on Azure is
  deferred until after step AZ2.
- Not in this step: UTC dates, hiding Backup on Azure, the machine key, a Release Web.config transform, mail STARTTLS, Azure
  exact-text checks. Open items (Lows) are in Database/README.md, "Known items for later steps": the licence texts, the review of
  the two old library versions, the dead shim code in ddlevelsmenu.js.
- Documents: System-Manual 01, 02, 03, 05 and 10. No user manual changed.

## UI2a - The Masters look on Agenda Finalize, Finalize Minutes, Minutes Confirmation and Followup (tag ui2a, 2026-11-26; code only, no database step; code not yet committed, based on 3744571)

- For users: Agenda Finalize, Finalize Minutes, Minutes Confirmation and Minutes > Followup now look like the Masters (Committee
  Master is the reference). The old ":: Title" header is replaced by a breadcrumb and a page title that follow the menu names:
  "Agenda / Agenda Finalize", "Minutes / Finalize Minutes", "Minutes / Minutes Confirmation", "Minutes / Followup". The browser
  tab title follows the same names (PageSettings.xml: Agenda Finalize, Finalize Minutes, and new entries Minutes Confirmation
  and Followup).
- Labels have no colon ("Committee Name"). The existing * markers sit in the label (red, bold); no new markers. The Reopen panel
  on Followup keeps its label "Reason for reopening :" (the three panels keep their look).
- Finalize, Confirm, View and Submit are the primary button; Cancel is the secondary one, in the Masters' order. The confirmations
  of Finalize and Confirm are unchanged.
- Agenda Finalize: the pending agenda items are a Masters list headed "Pending Agenda Details" with the columns S.No., Agenda No,
  Subject Type Name, Short Text, Agenda Status. The Committee Name and Meeting No columns are removed (they repeat the choice
  above the list; owner test G1). Sorting is unchanged.
- Followup: the filter is one column of rows: Meeting Date From (from date, "to", to date; * in this label), Committee Name,
  Department, Meeting No. Search (Particular / Between), Meeting No., Confirmed Status (Both / Confirmed / Pending); then View and
  Cancel. The list (grid, Status column, Reopen, Submit, history) and the three panels keep their behaviour and look (a later
  step). MD Secretariat reads only, as before.
- Not changed: control IDs, events, validation, messages, role checks; Print, PDF, Word and ViewReport output.
- For installers and in the database: nothing in the database. PageSettings.xml has two new entries (Followup, MinutesConfirmation)
  and two changed titles. Tests/README.md now says: run the dashboard pack before the followup pack (the followup pack writes
  data the dashboard pack expects untouched).
- Tests: build and site precompile clean; security-reviewer Pass; ux-reviewer and ui-reviewer Pass with Low notes (backlogged);
  after G1 / G2 ui-reviewer and ux-reviewer Pass. Tester runs: 2026-11-26_174407 VOID (followup listed before dashboard);
  2026-11-26_175022 PASSED 940 of 940 (access-matrix, page-assets, dashboard, followup, followup-reports, manager-scope); after
  G1 / G2 2026-11-26_213510 PASSED 940 of 940, same order; error log 0 new lines. Owner's tests passed 2026-11-26 (the four pages
  against Committee Master at 1366 and 1024 px, the Agenda Finalize list, the confirm dialogs, Followup as Controller and as
  MD Secretariat, calendars in front).
- Documents: User-Manuals/03-Controller.md (Followup: title, filter layout), System-Manual/05-Application-Code.md,
  System-Manual/10-Testing-and-Release.md (pack order). No manual describes Agenda Finalize, Finalize Minutes or Minutes
  Confirmation yet, and 00-Overall names none of the changed texts, so neither is changed. Known items for later steps (see
  Database/README.md): the undefined validation functions, the tab-title separator, candidate UI3 (Followup list), CAL1
  (calendar pop-up behind the next field on Masters with dates, pre-existing), MF1 (planned next: minutes items on Finalize
  Minutes and Minutes Confirmation), and the action item rows MD Secretariat receives but can never open (decide with GM1b / RS1).

## UI1 - Uniform field labels and three width fixes (tag ui1, 2026-11-26; code only, no database step; code not yet committed, based on 2e1cf53)

- For users: the field labels of the older pages now look like the labels of the Masters: bold, left aligned, in a 200 px column.
  The label text (colons kept) and the controls are unchanged; an existing * marker stays where it was and is now bold (it was already red).
  Pages: Agenda Finalize, Finalize Minutes, Minutes Confirmation, Minutes > Followup, and the report filter pages of the Reports
  menu (Send Mail, Committee Master, Meeting Master, Committee Member, Meeting Calendar, Sitting Fees Applicable, Sitting Fees,
  Attendance Details, Agenda Approval, Notice, Agenda Summary / Agenda Details / Minutes / Minutes Extract, Followup / Followup
  Summary, Followup by Department). Pages outside this list do not change.
- F1 (found in the owner's test): on Agenda Finalize, Finalize Minutes, Minutes Confirmation, Attendance Details and Meeting
  Calendar the labels start 16 px in from the card's border, as on the Masters.
- W1 Dashboard Meetings card: the tighter cell spacing and the smaller column headings (13 px) now apply at every window width
  and for every role, not only at 1240 px and below, so the list fits its card at 1366 and 1024 px. A committee name without
  spaces breaks inside the word.
- W2 Agenda Entry list strip (Committee Name, Meeting No, a Manager's Department, Add): at 800 px all four fit on one row; when the
  row is full, whole items move to the next line (below the narrow-window breakpoint each item takes the full width).
- W3 Report filter drop-downs: no longer a fixed width; as wide as their space, at most 300 px and at least 12em, so a filter row stays
  inside its card at 1024 px. The meeting and subject number pickers stay at 80 px.
- Not changed: Print, PDF and Word export output, the chips, the Followup status column, label text, control IDs, C# behaviour.
  Required fields that have no * marker are not changed (listed only).
- For installers and in the database: nothing. The rules are in BMMS/CSS/bmms-workbench.css (one shared rule on the Masters' label
  class, a drop-down rule, the Dashboard cell spacing) and BMMS/CSS/bmms-forms.css (the Agenda Entry strip).
- Tests: owner's tests passed 2026-11-26 (labels on all listed pages, the F1 inset, drop-downs and number pickers, Dashboard, the
  Agenda Entry strip, print, PDF and Word unchanged, no new error-log lines). Tester runs passed: 2026-11-26_131553 (access-matrix,
  page-assets, dashboard, followup, followup-reports, manager-scope: 940 of 940) and 2026-11-26_135255 after F1 (page-assets,
  access-matrix: 496 of 496).
- Documents: no user manual changed (none describes label position or drop-down width; the "Status label is coloured" lines are
  about the Dashboard status chip, which is unchanged). Known items for later steps: see Database/README.md.

## GM1a - The Governance Matrix and the governance change log (tag not yet set, 2026-11-25; database step 56; code not yet committed, based on 32c619d)

- For users (Controller and Admin): the new read-only screen "Governance Matrix". The Admin opens it from the Admin menu (breadcrumb
  "Admin / Governance Matrix"), the Controller from the Reports menu (breadcrumb "Reports / Governance Matrix"). Manager, User,
  Management and MD Secretariat get "Access denied". No control on it saves anything. Two views, switched by the buttons "Matrix" and
  "Change log".
- Matrix view: the filters "As on" (default today; the state at the end of that day), "Department" and "Transaction", and Show. One row
  for each transaction and department ("All departments" where the rule is not per department): Transaction, Department, Who enters,
  Who approves (Managers as "Any one of: ..."), Controller(s), Rule note. People as "Name (login)"; an inactive person is never shown as
  able to act; on a past date someone inactive now is marked "(inactive now)"; the protected system account is shown in Admin rows only,
  marked "(system account)". The transactions: agenda entry by a User, by a Manager and by the Controller, Manager approval or
  rejection, Controller approval or rejection, agenda finalisation, minutes update, finalisation and confirmation, Followup save, confirm
  and reopen, action items (who receives them, who can open them on the Dashboard), meeting and committee create and update,
  attendance, User Master, Department Master and System Settings. The rule notes give the route to the Controller (the Reporting Person
  is a Controller), refused new items (the Reporting Person is inactive), the setting "Department without an active Manager", inactive
  departments (no new agenda items) and, for page rules, the roles of the page. A Settings block ("Department without an active Manager"
  and "Controller changes the agenda after finalisation", as on the date) and a "Read-only access" block (Management: "Dashboard (read
  only), Minutes report, Followup report, Followup Summary report"; MD Secretariat: "Dashboard, Followup page (read only)"), built from
  the page rules and the menu.
- Past dates: before the history start "History starts on [date]. Choose that date or a later one." and no rows; after today "The As-on
  date cannot be after today. Choose today or an earlier date."; notes "As on [date], end of the day. The rules are those installed
  now.", "Deleted users are not shown; see the change log.", and, where not recorded, "Reporting Person not recorded before [date]: the
  route to the Controller is not shown for earlier dates." and "Department status not recorded before [date]: today's status is shown."
- Change log view: From and To (default the last 30 days), User (a deleted user "(deleted)"), Department and Change type; columns Changed
  on, Changed by, Change, User, Department or setting, Old value, New value and Source ("Recorded", "From history", "From audit
  trail"). Change types: User added, Role changed, Home department changed, Manager department added, Manager department removed,
  Reporting Person changed, Activated, Deactivated, Deleted, Department activated, Department deactivated, Setting changed. A save that
  changes nothing writes no row. A range that is not valid: "Choose a From date that is not after the To date, and a To date that is not
  after today."
- Both views: Print (landscape, without the header, the menu, the filters and the buttons), Export to Excel (CSV; a cell that starts
  with = + - @, a tab or a carriage return gets a leading '), Export to PDF. Every fresh visit starts from the defaults; the choices
  are kept within the page.
- For users (Admin, Department Master): the save now checks the signed-in user in the database: "Not saved: your account is not active.
  Sign in again. Nothing was changed." and "Not saved: only an Admin can change departments. Nothing was changed."; a department made
  active or inactive is recorded in the change log.
- For installers: database step 56 (BMMS-Fix-GovernanceLog-Step56.sql; marker GovernanceLog-Step56; 27 markers in
  BMMS-Check-InstalledSteps.sql), after step 55; needs steps 39, 53, 54 and 55. Roll back the build FIRST, then
  BMMS-Rollback-GovernanceLog-Step56.sql (seven texts back letter for letter, SHA-1 compared; the table, its rows, its key, the DENY and
  the setting row are kept, so the Check reads step 56 Partly, 1 of 27). The Fix and Rollback scripts of steps 47 and 54 stop while
  step 56 is installed (guards added). A re-run of the Fix script of step 2, 3, 6, 10, 13, 16, 18, 21, 29 or 30 brings back an older
  text: step 56 reads Partly. Install the build after the Fix. The Fix back-fills the log at the first install from the step 39 history
  and the audit rows of the two settings (on BMMS_Test: 79 and 6 rows).
- In the database: new table Governance_Change_Log (key to Users on ChangedBy; DENY INSERT, UPDATE and DELETE to public; written only by
  the procedures inside their transaction); App_Setting row GovernanceLogFrom; 12 new functions (the dated functions over User_Role and
  User_Department, fn_GovernanceMatrixPeople and others); 7 new procedures (the read procedures with @ActingUserId, Reasons 8, 4, 32, 33
  and 34, and the internal writers spr_WriteGovernanceChange and spr_WriteGovernanceUserChanges: EXECUTE denied to public, refused at
  nesting level 1); replaced spr_AddEditUser, spr_SetUserStatusByUserId, spr_DeleteUserByUserId, spr_AddEditDepartment (@ActingUserId,
  Reasons 8 and 4), spr_SetDepartmentManagerRule, spr_SetAppSetting and spr_sys_ResetDatabase (clears the log before Users; App_Setting
  untouched). New Reason codes 32, 33 and 34. Keys to Users 32 (was 31). A user who is ChangedBy of a log row cannot be deleted (Reason 6,
  group "user changes").
- In the code: BMMS/Report/GovernanceMatrix.aspx(.cs, .designer.cs), BMMSBAL/GovernanceMgr.cs, BMMSDAL/GovernanceDB.cs,
  BMMS/PageAccessModule.cs (RolesForPage), BMMS/XML/PageAccess.xml and PageSettings.xml, BMMS/UserControl/MenuUserControl.ascx,
  BMMS/CSS/bmms-workbench.css, BMMS/Master/Department.aspx.cs, BMMSBAL/DepartmentMgr.cs, BMMSDAL/DepartmentDB.cs.
- For the tester: the access-matrix row for the new page (Admin and Controller open; the others Access denied); the baseline brought up
  to date with Update-Baseline.ps1 -FixScript BMMS-Fix-GovernanceLog-Step56.sql. BMMS-Test-ResetDatabase.sql: keys to Users 32 (31 before),
  with the owner's approval.
- Results: SQL on BMMS_Test: Test 56 49 of 49; every older Test script passes with step 56; Fix, Rollback, Fix cycle letter for letter.
  Tester on BMMS_Quality (Tests/_results/2026-11-25_170101): PASSED 505 of 505, error log 0 new lines. Owner browser tests 2026-11-25:
  all passed (filters, breadcrumb, defaults, print preview of both views in Chrome and Edge, the Controller's view, dates, change log
  rows, exports, error log clean).
- Documents: Documents/README.md (the register entries of 03-Controller and 04-Admin), the Controller and Admin manuals (the new
  screen "Governance Matrix", and in the Admin manual the Department Master save messages), System-Manual 03, 04, 05, 06, 08 and 10,
  Data-Flow 15-Governance-Matrix (new), 02-User-Master and 12-System-Settings.
- Open items for later steps are in Database/README.md, "Known items for later steps" (the Step GM1a lines).

## IU1 - Inactive users and the Admin role in the Meeting and Committee mails, the action items and Reset Password (tag not yet set, 2026-11-25; database step 55; code not yet committed, based on 79f50ea)

- For users (Controller, Admin; Meeting and Committee): the Created and Updated mail (MC, MU, CC, CU) goes to the person who saved (To)
  and, in Bcc, to exactly the users who get the alert of the same event: active users other than the person who saved and the
  Admin role (the protected system account is never in the list). A user without a mail address keeps the alert and gets no mail.
  With nobody to mail, no mail is sent and the screen says, in green: "The meeting was saved. No mail was sent because there were no
  recipients." (Committee: "The committee was saved. No mail was sent because there were no recipients."). The address checks and
  "The meeting was saved, but the mail could not be sent. The error is in the error log." are unchanged.
- For users (Controller, Committee): the Committee Created and Updated mail, switched off in the code since the baseline, is sent
  again after a successful save, by the path of the Meeting page, with the same messages: "The committee was saved, but the mail
  could not be sent. The error is in the error log." A mail failure never undoes the save.
- For users (all roles, action items): when minutes are finalised the action items are given only to active users other than the
  Admin role (and the system account); the Admin gets none. No back-fill for a user made active later. The late action item route
  (inactive creator to the active Controllers) and the Dashboard scope are unchanged. Existing action item rows of the Admin and of
  users now inactive are kept; no screen or count shows them.
- For users (Admin, Reset Password): the list shows active and inactive users, an inactive one marked "(inactive)" (never the
  system account). The reset of an inactive user works and sends no mail: green "The password was reset to the default password.
  No mail was sent because the user is inactive." (before: "Password reset; no mail sent because the account is inactive."). The other
  messages are unchanged. The acting user is checked in the database (an active Admin for another user's account).
- Security (G3): Reset Password reads the mail address and the active status of the chosen user from the database
  (spr_GetResetPasswordMail, under the acting-user check of the reset), never from a page value; the hidden field hdnEmailId is
  removed.
- For installers: database step 55 (BMMS-Fix-InactiveUsers-Step55.sql; marker InactiveUsers-Step55; 6 markers in
  BMMS-Check-InstalledSteps.sql), after step 54; needs steps 23, 53 and 54. Roll back the build FIRST, then
  BMMS-Rollback-InactiveUsers-Step55.sql (three texts back letter for letter, SHA-1 compared; refuses when step 55 is not installed;
  no data to undo). The Fix scripts of steps 23 and 53 and the Rollback script of step 53 stop while step 55 is installed. A re-run
  of the Fix script of step 8, 15, 16, 17, 18 or 21 brings back an older text: step 55 reads Partly. Install the build after the
  Fix. Before a fresh install check that every user has an address of his own (an Admin who shares an address receives the mails
  of the others).
- In the database: new fn_FunctionalUsers (one rule for the users of alert rows, mails and action item rows),
  spr_GetMeetingCommitteeMailId and spr_GetResetPasswordMail; replaced spr_AddEditMeeting, spr_AddEditCommittee and
  spr_MinutesFinalizeByMeetingId. No new Reason code, table, column or key.
- In the code: BMMS/Master/Meeting.aspx.cs, Committee.aspx.cs, ResetPassword.aspx(.cs, .designer.cs), BMMSBAL (AlertMgr, UserMgr) and
  BMMSDAL (AlertDB, UserDB).
- For the tester: baseline updated with Update-Baseline.ps1 -FixScript BMMS-Fix-InactiveUsers-Step55.sql; no pack changed. Three older
  expected texts changed with the owner's approval (the Admin role gets no action item row): BMMS-Test-SystemAccount-Stage3.sql
  check 45, BMMS-Test-FK-Procedures.sql check 17 and BMMS-Test-UserStatus-Stage2b.sql check 51.
- Results: build checks passed (compile, site precompile, SQL parse with NOEXEC). BMMS_Test: Test 55 48 of 48; Fix, Rollback, Fix
  cycle clean; every older Test script passes with and without step 55. Tester: access-matrix and session-check PASSED, 497 of 497.
  Owner browser tests passed 2026-11-25 13:50 on BMMS_Test.
- Open items (Known items in Database/README.md, not changes): a mail that reaches only some of the alert users still says
  "Successfully Saved" (later step ML2d); the To of a Meeting or Committee mail can be an Admin (G2); the Created mail of a Manager's
  or the Controller's new item goes only to the Reporting Person (G1); the Reset Password success text "New passward was sent through
  mail." keeps its spelling; the Low review notes.

## UD1c - Lists for Managers with several departments (tag not yet set, 2026-11-24; database step 54; code not yet committed, based on 42cb88c)

- For users (Manager): "a Manager's departments" are the departments of which he is an active Manager; every list, filter and check
  below reads them (a User has his own department, the Controller every department).
- For users (Manager, Agenda Entry): the list strip has a Department filter: "All my departments" (chosen when the page opens), then
  his departments, the home department marked "(home)" and an inactive one "(inactive)". The list holds the items of the chosen scope
  and the items he entered, with the columns Entered by and Department; with one department chosen it holds that department's items
  only (his own items of other departments are then not listed). The card note reads "Items of your departments and the items you
  entered." Edit and Update of a colleague's item are allowed for any of his departments (an inactive one too); the page and the
  database check again, and Update never changes the department, the status or the creator. Edit of an item of another department
  that he did not enter: "You can open only the agenda items of your departments and the items you entered." A new item: with
  several active departments a Department drop-down (his home department chosen); with one the department is fixed; another
  department is refused with "Not saved: you are not a Manager of that department." and nothing is saved. A Manager's new item also
  alerts the other active Managers of its department. The Created mail names the department he chose. Users are unchanged.
- For users (Admin, User Master): the Reporting Person list is the active Controllers and the active Managers of the chosen
  department, never the user himself; "- Select -" stays allowed. A current Reporting Person outside the list is shown with
  " (not allowed now)" and Save is refused while he is chosen: "Not saved: the Reporting Person must be a Manager of the user's
  department or a Controller. Choose another, or - Select -." Changing the Department sets the Reporting Person to "- Select -".
  The database refuses the same on Create and on every Update, also when the Reporting Person is unchanged.
- For users (reports): Agenda Summary, Agenda Details, Minutes and Minutes Extract: the Manager's Department drop-down is "All my
  departments", then his departments (home and inactive marked). A department that is not his is refused with "You are not allowed to
  see this report."; Print, PDF and Word follow the rows of Generate. The Controller's and Management's reports show the same rows as
  before. When a Manager's departments cannot be read, Agenda Entry and the reports say so and disable Add, or View and Generate.
- For users (Dashboard): unchanged; its departments equal a Manager's departments for every active Manager (proved by the Test script).
- For installers: database step 54 (BMMS-Fix-ManagerScope-Step54.sql; marker ManagerScope-Step54; 10 markers in
  BMMS-Check-InstalledSteps.sql), after step 53; needs steps 33, 39, 52 and 53. Roll back the build first, then
  BMMS-Rollback-ManagerScope-Step54.sql (three texts back letter for letter, SHA-1 compared; refuses when step 54 is not installed;
  no data to undo). The Fix and Rollback scripts of steps 33 and 53 stop while step 54 is installed. A re-run of the Fix script of
  13, 16, 17, 18, 31 or 35 brings back an older text of spr_AddEditAgendaByManager or spr_AddEditUser: steps 53 and 54 read Partly.
  Install the build after the Fix.
- In the database: new fn_ManagerDepartments, fn_ReportingPersonAllowed, spr_GetManagerDepartments, spr_GetReportingPersonList,
  spr_GetAgendaReport, spr_GetMinutesReportByUser and spr_GetReportSubjectNos; replaced spr_GetAgendaByMeetingIdDeptId (new optional
  parameter @DepartmentId), spr_AddEditAgendaByManager and spr_AddEditUser; Reason 30 (a Manager's new item or Update outside his
  departments) and Reason 31 (Reporting Person not allowed). spr_GetMgrControllerByDeptId and spr_GetMinutesReport are kept and no
  longer called. The reports no longer build SQL text in the code.
- In the code: BMMS/Master/Agenda.aspx(.cs, .designer.cs), BMMS/Master/User.aspx.cs, BMMS/Report/Reports.aspx.cs, BMMSBAL (ReportsMgr,
  AgendaMgr, DepartmentMgr, UserMgr, MeetingMgr) and BMMSDAL (AgendaDB, DepartmentDB, UserDB, MinutesDB).
- For the tester: the fixture has eleven qa_ accounts (qa_manager4, Manager of Credit as home department and HRD, is new); new pack
  manager-scope; session-check check 4b now expects one open item and the Secretarial line only (qa_manager4 is a second Manager of
  HRD); the Test scripts of steps 33 (check 3 follows fn_ManagerDepartments) and 44 (check 15 compares the function rows with the rule
  written out) were changed.
- Results: build checks passed (compile, site precompile, SQL parse with NOEXEC). BMMS_Test: Test 54 42 of 42; Fix twice; Rollback
  letter for letter and again (refused); every older Test script as before (Test 44 121 PASS with step 54 installed and rolled back,
  Test 33 7 PASS). Tester runs PASSED: five packs (access-matrix, dashboard, two-approvers, manager-scope, session-check) 926 of 926,
  then manager-scope alone 22 of 22. owner browser tests passed 24-Nov-2026.
- Open items (Known items in Database/README.md, not changes): Agenda Summary and Agenda Details open as a PDF only (pre-existing
  since step 25); the filter with one department narrows the list to that department (by design); the Low review notes.

## DA1 - Documentation audit tooling (tag not yet set, 2026-11-19; no database step; code not yet committed, based on 5f8c4fe)

- For users: nothing changed; no page, message or database object changed.
- For installers: nothing to install on a server. .gitignore now ignores /BMMS/App_Data/.
- For developers: a doc-auditor agent (.claude/agents/doc-auditor.md; model sonnet; tools Read, Grep, Glob, Write, Bash) audits
  Documents/ against the documents standard (Documents/Standards/documents-spec.md, the owner's standard, copied in), the code, the
  Database scripts and a read-only catalog of BMMS_Test. It writes one run folder Documents/Audit/DA-[yyyymmdd]-[short SHA of
  HEAD]/ with four files (Audit-Summary.md, Coverage-Matrix.md, Gap-Register.md, Drift-Register.md) and nothing else. It runs at each
  release candidate and on the owner's request; it is not part of the per-step gate (CLAUDE.md). Method and table of runs:
  Documents/Audit/README.md.
- Guard (.claude/hooks/doc-auditor-guard.ps1): writes only those four files of that folder; no Edit, MultiEdit or NotebookEdit; Bash
  only one read-only git command; reads of connectionStrings.config and of files under `Log\` and `App_Data\` refused; Grep globs limited
  to an extension allow-list; any other tool blocked (it fails closed).
- Documents/_build/Export-Catalog.ps1: a read-only catalog of a database (SELECT only); -Server and -Database are mandatory; written
  to `%LOCALAPPDATA%\BMMS-Audit\catalog-<yyyymmdd>-<short SHA>\`, outside the repository (a folder inside the working tree is refused); a
  fingerprint shows no schema change during the export.
- Documents: an optional header field Commit. Check-Documents.ps1 warns when it is empty or missing; Export-Documents.ps1 refuses a
  release export of a document without it; Documents/Audit/ is never exported. Password-hash, salt and dpapi patterns were added to
  the secret scan. .claude/agents/doc-writer.md has changed rules; one DA1 entry is in Known items of Database/README.md.
- Results: guard, 108 offline tests passed (security review: Pass with notes). Live checks of 2026-11-19: a doc-auditor Write to
  Documents/README.md was refused by the guard; a Write to Documents/Audit/DA-20261119-5f8c4fe/Gap-Register.md was allowed. Catalog
  export of BMMS_Test: 213 module texts, fingerprint unchanged. First run DA-20261119-5f8c4fe finished (21 of 21 documents): 43 gaps
  (Critical 5, High 12, Medium 19, Low 7), 43 drift items (Outdated 29, To confirm 14), no stubs needed. Check-Documents: 0
  failures, 42 Commit warnings. Security review of the run folder: Pass with notes (one Low).
- Open items: (a) the run-folder date is not compared with today's date (accepted by the owner); (b) the doc-writer guard has no read
  rule; (c) found in the live run: the doc-auditor guard's fail-closed rule also blocks the agent's hand-back tool (SubagentHandback),
  so the doc-auditor cannot return its record and the main session reads the run folder's Audit-Summary.md instead (not changed in
  DA1; needs the owner's decision); (d) Low review note: the Audit-Summary traceability gives the full repository address.
- Test-script slip of 2026-11-19: a test script of this step deleted files through the PowerShell alias RD; the owner restored them,
  and the test script was rewritten.

## UD1b - Any Manager of the item's department approves (tag not yet set, 2026-11-23; database step 53; code not yet committed, based on db1d641)

- For users (Manager): an item at the Manager step (AC) is approved or rejected by every active Manager of its department, never by
  the person who entered it. The Reporting Person of the creator and the alert rows no longer decide; the Reporting Person still
  shows where pages and mails name him. The first decision wins; a second Manager gets the existing "You cannot approve or reject
  this agenda item at its current stage ([status name]). Reload the Dashboard to see its current state." A Manager's decision after
  the meeting date stays refused. The Controller's rules are unchanged.
- For users (User, Controller): the route of a new item of a User, in this order: Reporting Person inactive: refused (unchanged);
  Reporting Person an active Controller: straight to the Controllers; the department has an active Manager other than the creator:
  it waits for all its Managers; otherwise the System Settings choice "Department without an active Manager": "Refused (default)":
  "Not saved: the department [department name] has no active Manager. Ask the Admin to nominate a Manager for the department."; "Sent
  to the Controller": the item is saved and the save message and the "has been Created" mail add "Sent to the Controller: the
  department had no active Manager." No active Controller: refused (unchanged). Items entered by a Manager or the Controller keep
  their route.
- For users (alerts): on a route to the Managers every active Manager of the department gets an unread alert; no alert goes to the
  Admin role any more (agenda, approve and reject, meeting, committee; older Admin rows stay and are not listed). When one Manager
  decides, the other Managers' alerts become handled: under All only, greyed, with "Handled by [Name (login)] on [dd-MMM-yyyy]";
  when a Manager leaves a department the waiting alerts of it show "No longer Manager of the department ([dd-MMM-yyyy])"; when the
  Controller moves an item at AC to another department the old department's Managers' alerts show "Item moved to another department
  ([dd-MMM-yyyy])" (a move back makes them live again). A handled alert is never counted as unread and never becomes unread again;
  "Remove from my list" still works; the Agenda Alert panel opened from one shows the same line. A new, re-activated or newly mapped
  Manager gets the alerts of the waiting items of his departments.
- For users (mail): the "has been Created" mail goes to every active Manager of the department; the approve and reject mails also
  to the other Managers of the department; a handled Manager gets no later mail of the item; no mail to the Admin role; a Manager's
  or the Controller's own item does not Bcc a Reporting Person of the Admin role.
- For users (Admin, User Master): changing a Manager's role, removing a department or deactivating him is refused (the three-line
  message of step 52) only when no other Manager of the department could decide the waiting items; when it is allowed the message
  says "Saved. [n] waiting approval alert(s) of [departments] were closed; the other Managers of the department still have them."
  (Deactivate: "User deactivated. ..."). The protected system account may make these changes (as an Admin). System Settings: the card
  text is now "Used when a new agenda item's department has no active Manager."; the two Save messages now end "The setting is now in use."
  (until now "This is stored now and used from a later step.").
- For installers: database step 53 (BMMS-Fix-DepartmentApprovers-Step53.sql; marker DepartmentApprovers-Step53; 21 markers in
  BMMS-Check-InstalledSteps.sql), after step 52; needs steps 39, 44 and 52. Roll back the build first, then
  BMMS-Rollback-DepartmentApprovers-Step53.sql (18 texts back letter for letter, SHA-1 compared; the columns and rows stay; it ends
  with two counts: alert rows of Managers outside the department, and items nobody could decide). The Fix scripts of steps 20, 24,
  36, 37, 43 and 52 and the Rollback scripts of steps 36, 37, 39, 43, 44 and 52 stop while step 53 is installed. A re-run of the Fix
  script of 13, 16, 17, 18, 31 or 35 brings back an older text: step 53 reads Partly, run it again. The Fix back-fills the unread
  alert rows of the waiting items (run as the first active Admin other than the system account; with none it says the back-fill did
  NOT run). Install the build after the Fix.
- In the database: new fn_DepartmentManagers and the internal spr_SetManagerAlertRows; 18 objects replaced (fn_AgendaRoute,
  fn_AgendaWaitingFor, fn_ManagerReleaseRefusal, fn_DashboardAlerts, spr_GetDashboardAlerts, spr_GetAlertCount, spr_GetAlertMailId,
  spr_GetAgendaUpdateMailId, spr_GetAgendaCreationMailId, spr_RerouteWaitingAgendas, spr_AddEditCommittee, spr_AddEditMeeting,
  spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController, spr_UpdateAgendaByAgendaId, spr_AddEditUser,
  spr_SetUserStatusByUserId); new columns Alert_User_Map.HandledReason ('H', 'N', 'M'), HandledBy (a key to Users: 31 keys to
  Users), HandledOn and Agenda.RouteNote; Reason 29 added.
- In the code: BMMS/Master/Agenda.aspx.cs (the route check by department, the Controller line in the save message and the mail, no
  Bcc to a Reporting Person of the Admin role), BMMS/DashBoard/DashBoard.aspx and .aspx.cs and BMMS/CSS/bmms-workbench.css (the
  handled row and its line), BMMS/Master/User.aspx.cs and BMMSBAL/UserMgr.cs (the closed-alerts sentence), BMMSBAL/AgendaMgr.cs,
  MeetingMgr.cs and BMMSDAL/AgendaDB.cs (the department parameter, Reason 29, the Controller line), BMMS/Master/SystemSettings.aspx
  (the card text).
- Tests: Test 53 70 of 70 on BMMS_Test; every changed older test passes with step 53 installed and rolled back (Test 44: 121 checks with step 53 installed, 120 with it rolled back);
  Tests 16, 31, 36 and 37 date their meeting ahead. Tester: new account qa_manager3 (Credit), new pack two-approvers, session-check
  check 4b on qa_manager2, dashboard values for qa_manager2, the fixture dates meetings 00004 to 00006 ahead. Tester run
  Tests\_results\2026-11-23_182026: PASSED, 909 of 909 checks (access-matrix 472, dashboard 397, two-approvers 15, session-check
  20); error log 0 new lines. Owner browser tests passed 24-Nov-2026 (all seven; the error log clean).
- Documents: System-Manual 02, 03, 04, 06, 07, 08, 10; Data-Flow 00, 02, 03/02, 03, 04, 05, 06, 07, 09, 12, 14 and Workflows 01, 04,
  05 (the stub files written only for the part this step touched); user manuals 00 to 04 and the Glossary.
- Open items (Database/README.md, Known items): the unlocked read of the department's Managers in spr_AddEditAgenda (race); the cut of
  a very long Released text; the handled line joined to another panel line; the muted Source link of a handled row; the Rollback's
  second count as a PRINT; a handled row is never bold.

## MR1 - A Manager stays needed while items routed to him wait, also on Deactivate; the meeting-date rule in the database (tag not yet set, 2026-11-19; database step 52; code not yet committed, based on e1b90dc)

- For users (Admin, User Master): a Manager is refused (nothing changed) when the Admin changes his role away from Manager, removes
  one of his departments or, new, deactivates him, while items routed to him wait. The message box shows one line per part: the
  header "Not saved: this Manager is still needed."; "[n] item(s) routed to them is/are still open for approval: approve or reject
  it/them first."; "[n] item(s) routed to them belongs/belong to meetings whose date has passed and whose agenda was never
  finalized: the Controller should finalize the agenda of those meetings first (finalizing rejects the items not yet approved).";
  for the last active Manager of a department "Last active Manager of [department] ([n] item(s) of the department waiting): give
  the department another active Manager first."; and "Nothing was changed." The lines about the Manager's own items never suggest
  another Manager. Before, the personal count did not agree with the Dashboard (items of past meetings were counted but not shown
  in My approvals).
- For users (Manager, Controller): a Manager's approve or reject of an item after the meeting date is also refused by the
  database, with the Dashboard's text "The meeting date has passed, so this item can no longer be approved or rejected. It will be
  rejected when the agenda is finalized."; nothing is saved, no mail, no alert. The Dashboard's own check normally stops it first.
  The Controller closes such items with Agenda Finalization, which rejects every item not yet approved. No page changed.
- For installers: database step 52 (BMMS-Fix-ManagerRelease-Step52.sql; marker ManagerRelease-Step52), after step 51; needs steps 39,
  44 and 51. Rollback: roll back the build first, then BMMS-Rollback-ManagerRelease-Step52.sql (the four texts back letter for
  letter, SHA-1 compared). The Fix scripts of steps 39 and 44 now stop while step 52 is installed. A re-run of another step that
  holds one of the four objects (2, 3, 6, 10, 13, 14, 16, 17, 18, 20, 21, 29, 30, 31, 35, 42) brings back an older text: run step
  52 again. The date is the database server's date (UTC on Azure SQL Database: Known item).
- In the database: fn_ManagerReleaseRefusal, spr_AddEditUser, spr_SetUserStatusByUserId (step 39) and spr_UpdateAgendaByAgendaId
  (step 44) replaced. Rule 12's personal part reads fn_AgendaWaitingFor and counts open (Kind P) and past (Kind Q) items; Reason 24
  ReasonDetail is `open:<n>|past:<n>|<department part>`; Deactivate of an active Manager runs rule 12; Reason 28 for a Manager's
  decision after the meeting date. No table or data change; nothing granted.
- For developers: BMMSBAL/UserMgr.cs builds the Reason 24 message from the parts (a ReasonDetail in the step 39 form gets the step
  39 message); BMMSBAL/MeetingMgr.cs maps Reason 28 to the Dashboard's text.
- For the tester: session-check pack, new check 4b: qa_admin's change of qa_manager to User is refused with the lines of 2 open and
  1 past item; nothing changes. Baseline: Update-Baseline.ps1 with step 52.
- Older tests (Test scripts only): Tests 20 and 35 have their open meetings dated ahead; Test 39 takes the Reason 24 detail of step
  52 and has a new check (59 checks); Test 44 takes Reason 28 and counts the 6 intended differences of check 28 apart.
- Repair during the build: a re-run of the step 44 Fix script on BMMS_Test (before its guard existed) put step 44 texts back; the Fix
  scripts of steps 45, 48 and 52 were run again and 213 module texts were compared with BMMS_Quality (only the four of step 52
  differ). Backlog: audit every Fix script's re-run guard before an install-all script (Database/README.md, Known items).
- Results: BMMS_Test: Test 52 28 of 28; Step 20 56/56; Step 35 28/28; Step 39 59/59; Step 44 120/120; UserStatus-Stage2a 50/50;
  Stage2b 63/63; SystemAccount-Stage3 51/51; UserProtection-Stage1 142/142; Step 23 53/53; Step 24 36/36; Step 51 18/18. Tester run
  Tests\_results\2026-11-19_145521: PASSED, 894 checks, 894 passed, 0 failed (the self-test's 3 planted wrong expectations were
  caught and are not counted): selftest 8, access-matrix 472, dashboard 397, session-check 20; error log 0 new lines.
  The owner's tests passed on BMMS_Test on 2026-11-19: the Check script (step 52 Installed, 4 of 4), Test 52 28 of 28,
  Step 39 59 of 59, Step 44 120 of 120; in the browser: mgruser's role change and Deactivate refused with (b) 8 items; with
  meeting C06-00004 and an item of depuser added, two parts (1 open, 8 past); with itmgruser's HRD removed, three parts
  for the role change and the Deactivate (HRD 9 items of the department), HRD then given back; the message boxes fine in
  Chrome and Edge; mgruser's My approvals shows only C06-00004-001, an old item opened from Alerts shows the meeting-date
  message with no Approve or Reject; mgruser approved C06-00004-001 (mail sent); the Controller finalized 00004 (its item
  rejected, mail sent) and 00001 (2 items rejected, mails sent); the refusal then counted 6; the error log clean.

## RA1d - A signed-in user whose role, departments or status changed is signed out at the next click (tag not yet set, 2026-11-19; database step 51; code not yet committed, based on d642746)

- For users: when the Admin changes your role or your departments, or deactivates your account, your next click takes you to the
  sign-in page. A changed role or department shows "Your access has changed. Please sign in again."; a deactivated or missing
  account shows "Your account is inactive. Contact the administrator." Work that was not saved is lost. This holds for every page,
  for the buttons that refresh part of a page, for the report window and for the PDF and Word exports. Nothing changes for a user
  whose access did not change, and nothing changes in who can open which page. If the database cannot be reached during the check,
  you stay signed in, the page shows the error page (or the error bar for a part-page refresh) and the next click checks again.
  The Admin's own account follows the same rule; so does the protected system account.
- For installers: database step 51 (BMMS-Fix-SessionCheck-Step51.sql), installed after step 50, needs steps 18, 39 and 40. INSTALL
  IT BEFORE THIS BUILD: without it every signed-in request fails closed and nobody can work. The real BMMS database on the Work
  Laptop is at step 37 and this build is not to be run against it. Rollback: roll back the build first, then
  BMMS-Rollback-SessionCheck-Step51.sql. A re-run of an earlier step leaves step 51 Installed (one marker, SessionCheck-Step51).
  App_Data/PageAccessLog.txt now also receives SESSION-ENDED lines (user id, login, page, reason: "role X to Y", "departments
  changed", "inactive" or "missing") and SESSION-CHECK-ERROR lines.
- In the database: one new read-only procedure, spr_GetUserAccessState (@UserId): UserId, RoleCode, RoleName, AccountStatus,
  IsSystem and DepartmentSet (Users.DepartmentId, a vertical bar, the open department rows with the home one marked "h"). No table,
  view or data change; nothing granted.
- For developers: the session keeps the role and a department stamp from sign-in (Session["DepartmentSet"]); PageAccessModule reads
  the procedure once per request, compares, and on a difference logs, calls Session.Abandon (so Session_End closes the login rows),
  expires the session cookie and redirects with `?status=changed` or `?status=inactive`; Default.aspx maps these two fixed codes to
  fixed texts. RequireRole and HasRole reuse the module's read, so there is still one database call per request. Values written to
  the page access log are cleaned of control characters. Session_End runs its audit call inside a try/catch with an error log line and
  reads the UserId with int.TryParse. Closes the lead of RA1a (pages other than the nine followed the session role until sign-out).
- For the tester: new pack session-check (BMMS_Quality only, run last): the Admin changes qa_mdsec's role, adds Credit to qa_manager2
  and deactivates qa_user2; each user's next click lands on the sign-in page with its message and a new ASP.NET_SessionId cookie;
  qa_ctrl, unchanged, is never interrupted; the users are put back in a finally block. The tester's baseline is brought up to date with
  Update-Baseline.ps1 and step 51. Test only: BMMS-Test-SystemAccount-Stage3.sql check 44 now expects "0 0" (step 43 leaves the Admin
  out of functional mails by design).
- Results: BMMS_Test: Test 51 18 of 18; Step 39 58 of 58; UserProtection-Stage1 142 of 142; UserStatus-Stage2a 50 of 50;
  UserStatus-Stage2b 63 of 63; Step 40 43 of 43; SystemAccount-Stage3 51 of 51. Tester run 2026-11-19_104149: PASSED, 510 checks,
  507 passed and 0 failed (the 3 others are the self-test's planted wrong expectations, all caught): selftest 8, access-matrix 472
  (440 matrix cells, all ok), page-assets 11, session-check 19; 0 new error log lines. The owner's tests passed on BMMS_Test on 2026-11-19: the Check script (step 51 Installed, 1 of 1),
  Test 51 18 of 18 and SystemAccount-Stage3 51 of 51; the browser tests: a role changed, a department changed, a user
  made inactive, an Admin made a User while on Department Master (SESSION-ENDED, not DENIED-PAGE), the Dashboard filter
  redirect, two tabs, the report window and the Word export refused, the database offline (the safe error page, the
  session kept, three SESSION-CHECK-ERROR lines) and back online without a new sign-in; the error log held only the lines
  of the offline test.
- Open points (Database/README.md, Known items): the Audit Trail shows an ended session as a normal sign-out; the sign-out closes the
  open login rows of the user's other browsers too; the sign-in page opens inside the report window when that is the next request;
  PageAccessModule checks .aspx paths only (a future .ashx or .asmx must be added); the session id is not renewed at sign-in; the
  expired cookie is not Secure; check 44 of the SystemAccount test would also pass on an empty list; the error page does not say that
  the session is still valid; eight pages still read the user id with Convert.ToInt16 (they fail for a user id above 32767).
- Documents: System-Manual 03, 04, 05, 08 and 10, Data-Flow 03-Program-to-Program/01-Login-and-Session, this entry and the header of
  the README. No user manual changed: the sign-in and common-problem sections of the manuals are not written yet (WF2d); the text
  for them is in the To confirm of the 00-Overall register entry in the README. Shot list: the sign-in page with each of the two messages.

## UN6e - Indexes for the Dashboard lists, the Action Items list out of ViewState, a version stamp on the stylesheet links, the tester names its results folder (tag not yet set, 2026-11-18; database step 50; code not yet committed, based on dbc48ca)

- For users: nothing changes on screen. The Dashboard (Controller, Manager, User), the Followup page and the Followup reports look
  and work as before. After a stylesheet change the browser fetches the new file by itself; nobody has to clear the cache.
- For installers: database step 50 (BMMS-Fix-Indexes-Step50.sql), installed after step 49. It creates three nonclustered indexes:
  IX_Alert_User_Map_UserId_StatusId, IX_Alert_Master_SourceType_SourceTypeId and IX_Agenda_MeetingId. It changes no primary key,
  table, procedure, function or data. The Fix is re-runnable and stops on an index of the same name with another definition (or
  another index with the same first key column). BMMS-Rollback-Indexes-Step50.sql drops only these three, and only with the step 50
  definition. There is no procedure text, so re-running an earlier step does not remove step 50 (the Check script has one marker
  per index). The build does not need step 50; either order. After a stylesheet change no browser cache has to be cleared; Ctrl+F5
  is a fallback only.
- In the database (R28): the indexes were chosen by logical reads on a copy of BMMS_Test filled to about one year of use; a candidate
  is kept when it at least halves the reads of its table in a path the Dashboard or the Followup page calls. Examples: Meetings card,
  Manager, 7,577 to 863 reads in all; My approvals, Manager, 1,171 to 319; Alerts 381 to 309; Summary 177 to 91. Seven other
  candidates were measured and dropped (chapter 04, "Indexes added by step 50 (UN6e)").
- For developers (R29, stage A): the Dashboard's Action Items list is no longer kept in ViewState (DashBoard.aspx.cs; paging reads it
  again with the acting user and the filters; the grids keep only their row state). Controller's Dashboard on the filled copy:
  899,196 to 21,908 characters of ViewState; on a copy of BMMS_Test 23,316 to 7,788. Stage B (display-only row controls without
  ViewState) is not built (owner decision); the Followup page is unchanged.
- For developers (R30): BMMS/AssetVersion.cs; every local stylesheet link of both master pages, Default.aspx and the content links of
  Agenda, MinutesUpdate, Committee and Meeting gets ?v= and the first 8 hex characters of the SHA-256 of the file, computed once per
  file and kept for the life of the application (a deployment or recycle refreshes it). A missing file gives a link without ?v=, no
  error and no log line. Local .js links are not stamped.
- For the tester (R31, WF3a3): the runner prints "Results folder: Tests\_results\<run>" at the start and the end and writes
  `Tests\_results\latest.txt`; the guard and agent files are unchanged. `Tests\README.md` has the two-SQL-instance wording and the
  note that `BMMS\App_Data` must exist. New pack page-assets: the stylesheet stamps on ten pages and the Controller's Dashboard
  ViewState at most 12,900 characters (the fixture value 10,312 plus about 25 percent; the old code gives 24,288).
- Results: owner's tests passed on BMMS_Test on 2026-11-18 (Test 50 9 of 9; 42 71, 43 128, 44 120, 45 66, 47 95, 48 43, 49 33;
  Check: step 50 Installed 3 of 3; browser in Chrome and Edge at 100 percent). Tester run 2026-11-18_123549: PASSED, 915 checks
  (selftest 8, access-matrix 472, dashboard 397, followup 16, followup-reports 14, page-assets 11).
- Documents: System-Manual 02, 03, 04, 05 and 10, Data-Flow 09-Dashboard-and-Alerts (two rows), this entry and the README register
  note. No user manual changed (nothing is visible); no screenshots.

## FU2b - The Followup reports show who confirmed or reopened each followup (tag not yet set, 2026-11-17; database step 49; code not yet committed, based on c4300b5)

- For users: Followup, Followup Summary (Controller and Management) and Followup by Department (Controller). The Confirmed
  Status choice is Both, Confirmed, Pending ("Not Confirmed" is now "Pending"). The View grids have a "Followup status"
  column: the word "Pending" or "Confirmed" and a line "Confirmed by [name] ([login]) on [dd-MMM-yyyy HH:mm]" or "Reopened
  by [name] ([login]) on [date]: [reason]", the same texts as the Followup page ("Confirmed (before history)", an inactive
  name marked, "an unknown user"); the Summary shows the word only. The generated Followup report has a FOLLOWUP STATUS block
  per item, the printed Summary a "Followup status" column (the word), Followup by Department the word and line under the
  subject (View and print). Management keeps its "Minutes status" column. A refused request (role not allowed, or a missing,
  inactive or system account) shows "You are not allowed to see this report." or "Your session is no longer valid. Please log
  in again." and no rows, Export included; Followup by Department is for the Controller only. The rows, order and filters are
  as before, with agenda number, then action item, for rows equal on the other keys (also on the Followup page's list). The
  Reopen reason that holds only blank characters (including tab, line breaks, no-break and zero-width spaces; 27 characters)
  is refused with "Enter the reason for reopening."; when the browser check of the reason fires only one message shows.
  Described in the Overall manual (Management) and the Controller manual.
- For developers: ReportsMgr.GetFollowupReport and ActionItemDB.GetFollowupReport call spr_GetFollowupReport for both roles;
  ActionItemMgr.GetFollowupByDepartmentReport and ActionItemDB.GetFollowupByDepartmentReport call
  spr_GetFollowupByDepartmentReport; removed: ActionItemDB.GetFollowup(string), GetFollowupReportForManagement,
  GetActionItemByMeetingIdDeptId and their BAL wrappers. New: FollowupStatusText.Word and Line, ActionItemMgr.IsBlankReopenReason
  and ReopenBlankCharacters. Report/Followup.aspx.cs: StatusCellHtml, StatusBlockHtml, the minutes status by the role read from the
  database. See System-Manual/05 and Data-Flow/03-Program-to-Program/10.
- For installers: install step 49 and deploy the build together. Run BMMS-Fix-FollowupReports-Step49.sql after steps 41, 47 and
  48 (marker FollowupReports-Step49, 5 markers in the Check script), on BMMS_Test first. It adds fn_FollowupStatusLatest,
  spr_GetFollowupReport and spr_GetFollowupByDepartmentReport and replaces spr_GetFollowupList and spr_ReopenFollowup (they keep
  the step 47 marker). The Rollback puts the step 47 texts back; the Rollback of step 47 refuses while step 49 is installed; a
  re-run of step 47 removes step 49 (Partly, 3 of 5): run step 49 again. Tester baseline: Update-Baseline.ps1 with step 49.
- Tests: Test 49 33 of 33, Test 41 44, Test 43 128, Test 44 120, Test 45 66, Test 47 95, Test 48 43 on BMMS_Test. Tester on
  BMMS_Quality: run 2026-11-17_133514 PASSED 904 (selftest 8, access-matrix 472, dashboard 397, followup 16, followup-reports
  14); after the header change run 2026-11-17_135000 PASSED 19. Owner's tests passed 2026-11-17.
- Known items (Database/README.md): a 500-character reason without spaces in the Word export; spr_GetFollowupReportForManagement
  and spr_GetActionItemByMeetingIdDeptId have no caller (drop list).
  The Word export opens in Web Layout, where a long word without spaces runs past the window edge (Print Layout wraps it
  inside the margins; baseline, every report; no code change in FU2b). Also listed: the bold action text and the style typo in
  the Followup report (baseline), the Followup page's "Nothing was saved." message after an Action Text save, and a method
  count in System-Manual/05.

## FU2a - A confirmed followup is final on the Dashboard too; who confirmed or reopened it; "Reopened" in the Action Items card (tag not yet set, 2026-11-17; database step 48; code not yet committed, based on 9336d29)

- For users: Dashboard, Action Items card and Action Item Details panel. In the Due date column a pending item that the
  Controller reopened carries an orange "Reopened" label, with "Overdue" when both apply; there is no "Confirmed" label,
  and the card still lists no confirmed item. The panel shows one line under the action text: "Reopened by [Name (login)]
  on [dd-MMM-yyyy HH:mm]: [reason]", "Confirmed by [Name (login)] on [dd-MMM-yyyy HH:mm]" or "Confirmed (before history)",
  the same texts as on the Followup page (a long reason wraps). A confirmed item that is reached from a stale card row, or
  from a panel opened before the confirm, opens read-only for every role (also Management): the editor is read-only,
  Submit and Cancel are hidden, Close is shown and the line reads "This followup is confirmed and can no longer be
  changed." (it replaces "This item no longer exists."). Submit on an item confirmed in the meantime is refused for
  every role: "This followup is confirmed and can no longer be changed. Nothing was saved."; the panel stays open,
  read-only, with the saved text and the status line. Opening a confirmed item marks it read for that person, as any
  item. Described in the Overall manual (Dashboard) and the User, Manager and Controller manuals (Dashboard).
- For developers: new class BMMS/FollowupStatusText.cs (added to BMMS.csproj), used by Master/Followup.aspx.cs and
  DashBoard.aspx.cs; DashBoard.aspx.cs: `SetActionItemPanelMode`, `CanSaveActionText`, `ActionItemStatusCaption`,
  `ShowActionItemStatus`, `IsReopened`, `ShowConfirmedAfterSave`; the markup has the paragraph `pActionItemStatus` and the
  placeholder `phReopened`; CSS `.wb-dash-reopened` and `.wb-dash-status-line`. ActionItemMgr and ActionItemDB are not
  changed. See System-Manual/05 and Data-Flow/03-Program-to-Program/09.
- For installers: install step 48 and deploy the build together. Run BMMS-Fix-DashboardFollowupFinal-Step48.sql after
  steps 43, 45 and 47 (marker DashboardFollowupFinal-Step48, 5 markers in the Check script), on BMMS_Test first. The step adds
  fn_DashboardActionItemScope and replaces fn_DashboardActionItems, spr_GetDashboardActionItems, spr_OpenDashboardActionItem
  and spr_SaveDashboardActionText (the markers of steps 43 and 45 are kept; the three read objects return 35 columns instead
  of 28). The Rollback puts the step 43 and 45 texts back; the Rollbacks of steps 43 and 45 refuse while step 48 is
  installed; a re-run of step 43 or 45 removes step 48 (run step 48 again). Tester baseline: Update-Baseline.ps1 with
  step 48.
- In the database: the new Reason 26 of spr_SaveDashboardActionText (a confirmed item, nothing saved, for every role that
  may save; the role checks and the scope come first, under UPDLOCK and HOLDLOCK); spr_OpenDashboardActionItem returns a
  confirmed item of the person's scope (a read row it creates gets StatusId 0 then). The Dashboard has no count of action
  items, so no count changes. Out of scope (step FU2b): Report/Followup.aspx, Report/FollowupActionTaken.aspx and
  ReportsMgr.GetFollowupReport.
- Tests: Test script 48 43 of 43, Test 43 128 of 128, Test 44 120 of 120, Test 45 66 of 66, Test 47 95 of 95 on BMMS_Test
  (the expected values of the Test scripts of steps 43 and 45 follow the step 48 marker). Tester run 2026-11-16_181041
  (access-matrix, dashboard, followup): PASSED, 890 checks; the dashboard pack has the new check 18. The owner's browser tests
  passed on BMMS_Test (2026-11-17, Chrome and Edge at 1366 and 1024 px).

## FU1 - A confirmed followup becomes final; Reopen with a reason; who confirmed and when (tag not yet set, 2026-11-16; database step 47; code not yet committed, based on 3d571c4)

- For users: Followup page (Master menu "Minutes"). The list has a Status column in place of the Is Confirmed tick, and the
  filter label reads "Pending" (was "Not Confirmed"). The Controller has a drop-down Pending / Confirmed on each Pending
  row. Submit confirms only the rows changed to Confirmed and is hidden while the list has no Pending row. Messages: "[n]
  followups were confirmed." or "1 followup was confirmed.", with "[m] had already been confirmed." when another
  Controller confirmed rows in the meantime; "No followup was confirmed. [m] had already been confirmed." when all were
  skipped; "No followup was changed to Confirmed. Nothing was saved." when no row was changed (nothing is sent). A
  confirmed row is final: no drop-down, "Confirmed by [Name (login)] on [dd-MMM-yyyy HH:mm]" ("Confirmed (before
  history)" for an item confirmed before this step), and its Action Text opens as View (":: View Action Text", Close, the
  line "This followup is confirmed and can no longer be changed. Reopen it to change the action text."). A save of the
  action text of an item confirmed in the meantime is refused: "This followup is confirmed and can no longer be changed.
  Nothing was saved. Click View to read the list again." New: the Controller's Reopen button on a confirmed row and the
  panel ":: Reopen Followup" with a mandatory reason of at most 500 characters ("Enter the reason for reopening.", "The
  reason can be at most 500 characters.", and in the browser, with nothing sent, `Remove the "<" or "&#" from the reason,
  then save again.` for a "<" followed by a letter, "!", "/" or "?", or "&#"); saved: "The followup was reopened."; the row
  is Pending again with "Reopened by [Name (login)] on [date]: [reason]" (shown as text). A reopen of an item no longer
  confirmed: "This followup is no longer confirmed. Nothing was saved. Click View to read the list again." The MD
  Secretariat reads only (the Status as text, no Submit, no Reopen, the line "You can read the followups. Your role cannot
  change them."). A reopened item counts as not confirmed everywhere (the Dashboard Action Items card, the Followup
  reports). Described in the Controller manual (Followup), the Overall manual (MD Secretariat and Management) and the
  Glossary (MD Secretariat).
- For developers: Followup.aspx(.cs): `BindFollowup` (the list through `ActionItemMgr.GetFollowupList` with the filters
  kept in ViewState; the ViewState copy of the whole list is gone), the Status cell built and HTML-encoded in
  `grvFollowup_RowDataBound`, `btnSubmit_Click` (only the changed rows), the Reopen panel (`btnReopenSave_Click`, the
  script `FollowupReopenCheck`), `RebindAfterSave`. `ActionItemMgr` / `ActionItemDB`: `SaveFollowupConfirmed` (a list of
  ids, out Saved and Skipped), `ReopenFollowup`, `GetFollowupList`. CSS: `.wb-followup-status*` and
  `.wb-followup-reopen*` (bmms-workbench.css). See System-Manual/05 and Data-Flow/03-Program-to-Program/09.
- For installers: install step 47 and deploy the FU1 build together (the build of step UN6d cannot Submit with step 47; the
  FU1 build cannot list without it). Run BMMS-Fix-FollowupFinal-Step47.sql after step 46, on BMMS_Test first, then the
  Test scripts in new query windows, then the tester's baseline (`Update-Baseline.ps1 -FixScript`, then
  `Setup-Quality.ps1`). BMMS-Rollback-FollowupFinal-Step47.sql (roll back the build first) restores the step 46 and step 39
  texts and keeps the table; roll back step 47 before step 46. A re-run of step 46, 2, 6, 10, 13 or 39 afterwards reads step
  47 Partly: run step 47 again. See System-Manual/03, "Installing step 47 on a test database".
- Database: step 47 (marker FollowupFinal-Step47; 5 markers and the table, 6 rows in BMMS-Check-InstalledSteps.sql). New
  table Action_Item_Status_History (one Confirm or Reopen row per action, who and when, the reason; cascading delete with
  its item). Replaced: spr_SaveFollowupConfirmed (ids only, skips rows already confirmed, writes a Confirm row; OUTPUT
  @Saved, @Skipped), spr_SaveFollowupActionText (Reason 26 for a confirmed item), spr_DeleteUserByUserId (a user with
  history rows is refused, Reason 6). New: spr_ReopenFollowup (@ReopenReason NVARCHAR(500); Reason 27 when the item is not
  confirmed) and spr_GetFollowupList (Controller and MD Secretariat only; the same ids in the same order as the earlier
  query, proven in the Test). New Reason codes 26 and 27. Grants nothing. Test script
  BMMS-Test-FollowupFinal-Step47.sql: 95 numbered checks, all PASS on BMMS_Test; the Rollback restores the step 46 and
  step 39 texts exactly, and the step 46 Test then passes 56 of 56 (while step 47 is installed it names the step 47 Test);
  the Test scripts of steps 31, 39, 41, 43, 45 and the user delete and reset database scripts pass.
- Tests: tester run 2026-11-16_133023 (access-matrix, dashboard, followup; baseline updated for step 47): PASSED, 878
  checks (selftest 8, access-matrix 472, dashboard 385, followup 16), error log clean, 288 s. The followup pack was
  rewritten (Controller first, then the MD Secretariat). The owner's tests passed (BMMS_Test; Chrome and Edge; Controller
  and MD Secretariat).
- Known items (Database/README.md, "Known items for later steps"): the history table is not in the Audit Trail report; who
  and when are not shown in the Followup reports or the Dashboard panel; a reason over 500 characters sent by another
  caller is cut without a refusal; the list is not read again after a refused save; the Status column width at 1024 px
  is an owner check; the line "Enter the reason for reopening." of an earlier empty Save stays shown above the browser's "<" message; the list order has
  no agenda number tie-breaker; the identity counter of the history table is not restarted by Reset Database.

## UN6d - Submit hidden on read-only action items; the Followup page saves decided on the server (tag un6d, 2026-11-15; database step 46; code commit 276e402)

- For users: Dashboard, Action Item Details panel: the Controller, the Manager and the User see Submit and Cancel (the
  Controller no longer has Close); every other role (in practice Management) sees Close only, the action text read-only
  and the line "You can read this action item. Your role cannot change it." After a Submit that saved, the panel closes,
  the Action Items list is read again (the link Show All, Read or Unread, the page and the filters kept) and
  "The action text was saved." is shown; a refused Submit also closes the panel and reads the list again, with the
  message as before. A save that failed, a busy server or a text that is too long keeps the panel open with the text and
  shows its message on a line inside the panel (the page's message box lay under the open panel). Followup page (Master
  menu "Minutes"): only the Controller saves. The MD Secretariat reads only: the line "You can read the followups. Your
  role cannot change them." above the list, no Submit, the Is Confirmed ticks cannot be changed, "View" in place of
  "Edit" on the Action Text button, and the panel ":: View Action Text" without Save, with Close and the same line
  (before, the manuals said the MD Secretariat works on Followup, and the page let it save). The Controller's Action
  Text Save shows "The action text was saved." (before: no message) and Submit "The confirmations were saved." (before:
  "Successfully Saved"). Submit saves every row of the list in one step: all rows or none. A refused save (a role that
  may not change followups, or an item that no longer exists) says "You cannot change the followups: your role can only
  read them, or an item on the list no longer exists. Nothing was saved. Click View to read the list again."; an inactive
  account "Your account is not active. Nothing was saved. Sign in again."; a failed save "The action text could not be
  saved. Nothing was saved. Try again." or "The confirmations could not be saved. Nothing was saved. Try again." (and the
  "The server is busy ..." forms), no longer the error page. Layout faults found in the owner's test of the Followup page
  and fixed: A (caused by this step) the new message lines drew their background under the filter rows; B (old, since
  step A2a) the 600 px editor sat at the left of the Followup panels while the buttons were centred; C (old, present
  since commit ba361c3, step H1, not caused by this step) with a panel open and a long list the page footer was drawn as a
  narrow column at the right edge of the window. After a stylesheet change the page must be reloaded with Ctrl+F5
  (the stylesheets are cached; fault C was seen as fixed only after a hard refresh). Described in the Overall manual
  (the Action Items table, MD Secretariat and Management), the User, Manager and Controller manuals (the action text
  Submit; the Controller's new section "Followup") and the Glossary (MD Secretariat).
- For developers: DashBoard.aspx(.cs): `canSave` by session role, the line `pActionItemPanelMessage`,
  `ShowActionItemPanelMessage` and `HideActionItemPanelMessage`, `LoadActionItemGRV` after a done or refused save.
  Followup.aspx(.cs): `CanSave` (display only), `pFollowupReadOnly`, `litActionTextTitle`, `pActionTextPanelMessage`,
  `CloseActionTextPanel`, `HasSessionUser`; both handlers call the server with the acting user id, catch every failure
  (error log, a message, no error page) and read the item ids with `int.TryParse`. `ActionItemMgr` / `ActionItemDB`:
  new `SaveFollowupActionText` and `SaveFollowupConfirmed` (the list built with `XmlWriter`); the `UpdateActionItem`
  wrappers are removed. CSS: `.wb-followup-row` and `.wb-followup-popup` (bmms-workbench.css) and `display: flow-root`
  in the popup rule of CommonHTML.css (fault C).
- For installers: run BMMS-Fix-FollowupSave-Step46.sql (after step 45) before the new build, on BMMS_Test first, then the
  Test scripts in new query windows and the tester's baseline (`Update-Baseline.ps1 -FixScript`, then
  `Setup-Quality.ps1`). The earlier build keeps working with step 46 installed. BMMS-Rollback-FollowupSave-Step46.sql
  drops the two procedures (roll back the build first); a second run is refused. See System-Manual/03, "Installing step
  46 on a test database".
- Database: step 46, two new procedures (marker FollowupSave-Step46; 2 markers in BMMS-Check-InstalledSteps.sql):
  spr_SaveFollowupActionText and spr_SaveFollowupConfirmed (Reason 12 system account, 8 no usable or inactive acting user,
  4 another role than Controller, an item that does not exist, or for the Submit a list that cannot be read). Only an
  active Controller saves; what a save writes is what spr_UpdateActionItem wrote. spr_UpdateActionItem is not changed
  and has no caller (drop list). Grants nothing. Test script BMMS-Test-FollowupSave-Step46.sql: 56 numbered checks,
  all PASS on BMMS_Test; the Test scripts of steps 31 (41), 43 (128) and 45 (66) pass.
- Tests: tester agent, runs of 2026-11-15 (2026-11-15_090800, 871 checks; 100359, 399 checks; 124820, 871 checks), all
  PASSED, with the packs access-matrix, dashboard and followup; new pack followup; dashboard pack check 8 changed (see
  System-Manual/10); the rule W6 of the access-matrix pack reworded, expected.csv unchanged. The owner's tests passed.
- Known items (Database/README.md, "Known items for later steps"): the Submit overwrites a tick changed by another
  Controller in between (lost update); the saves set no UpdatedOn or UpdatedBy and write no audit row; opening a panel
  for an item that is gone, View and the drop-down handlers still go to the error page; nothing sets IsComplied to 1;
  the buttons follow the session role while the server decides; a Controller with an empty list sees Submit and a
  saved message; the MD Secretariat's two "View" buttons in a row are told apart by the column headings only; the View
  button calls a script function that does not exist and the meeting date boxes are not used by the list.

## UN6c2b - Dashboard summary cards, the Committee filter on every card, "In progress" for every role (tag not yet set, 2026-11-15; database step 45; code commit f3cbd7e)

- For users: the Controller, Management, the Manager and the User have three summary cards above the Dashboard cards:
  "Items in progress", "Items rejected" (for the User "[department] items in progress" and "[department] items
  rejected"; for a Manager "Items of my departments ...", or the department chosen) and "Unread alerts". The item cards
  count the items of scheduled meetings only, with the line "Scheduled meetings, all committees" or the committee's
  name, and follow the Committee drop-down and the Manager's Department drop-down; "Unread alerts" says "Your alerts,
  not filtered". A count that cannot be read shows a dash (hidden text "count not available"), never 0, with a message
  under the cards. MD Secretariat and the Admin have no cards. The Committee drop-down now also narrows the Action
  Items card (with the Manager's Department drop-down), and the User has a Committee drop-down (all active
  committees). A committee that is not active is refused: "The counts cannot be shown for this choice.", "The
  approvals cannot be shown for this choice.", "The action items cannot be shown for this choice." and the meeting
  list's text, each followed by "Choose All committees." (and "or All my departments." only for a Manager with two or
  more departments, where that drop-down is shown; before, the approvals text always named both). The Alerts card
  says "Your own alerts, for every committee. The filters at the top do not apply." The last count of the Meetings lists
  is headed "In progress" for every role (before, "Pending" for the Controller, Management and the Manager); the
  heading has the tooltip, and the In progress card the same sentence: for the Controller and the Manager "Items not
  yet approved or rejected. For a Manager this includes items waiting for someone else; 'Waiting for me' is the part
  waiting for you.", for every other role "Items not yet approved or rejected."; where no card shows it (MD Secretariat)
  a line "In progress: ..." under the lists. MD Secretariat now sees the statistics (read-only, as Management). The
  heading "My approvals (n)" keeps its count when an alert or an action item is opened or closed and when the Alerts and
  Action Items links are used (it lost the count before); on a failed or refused load it reads "My approvals (-)" with
  the hidden text "count not available". Layout: at 1240 px and below the Meetings cells are tighter (and the status chip
  may wrap), and below 960 px a list wider than its card scrolls inside the card with the Meeting column kept in view;
  the page never scrolls sideways. Described in the Overall manual (new subsection "The summary cards", the table of
  roles), the User, Manager, Controller and Admin manuals and the Glossary (entries "In progress" and "Summary cards").
- For developers: MeetingSummary.ascx(.cs) has the cards (`divSummaryCards`, `LoadSummary`, `SetUnreadAlerts`,
  `SetCount`, `ShowSummaryDashes`, `ItemsOf`), `ChoiceHint`, `InProgressMeaningFor` and the role table with "In
  progress" for every role and the Committee drop-down for the User; DashBoard.aspx(.cs) passes the unread count,
  sends both filters to the Action Items card (`HasActionItemsCard`, `ActionItemsFilterMessage`), reloads it when a
  filter changes and keeps the My approvals count in ViewState (`ShowApprovalsMessage` shows the dash); new
  `AgendaMgr` / `AgendaDB.GetDashboardSummary` and an overload of `ActionItemMgr` / `ActionItemDB.GetDashboardActionItems`
  with committee and department (the old signature sends 0 and 0); CSS: the card row, the 1240 px and 959 px rules.
- For installers: run BMMS-Fix-DashboardSummary-Step45.sql (after step 44) before the new build, on BMMS_Test first,
  then the Test scripts in new query windows. The earlier build keeps working with step 45 installed.
  BMMS-Rollback-DashboardSummary-Step45.sql puts the three replaced procedures back letter for letter (SHA-1 compared) and
  drops the two new objects (roll back the build first). BMMS-Rollback-AgendaWaitingFor-Step44.sql now refuses while
  step 45 is installed: roll step 45 back first.
- Database: step 45, five objects (marker DashboardSummary-Step45; 5 markers in BMMS-Check-InstalledSteps.sql): new
  fn_DashboardCommitteeFilter (0, or an active committee) and spr_GetDashboardSummary (@InProgress and @Rejected for
  scheduled meetings; Reason 12, 8 and 4); replaced spr_GetDashboardMeetings (the committee rule; statistics for the
  MD Secretariat), spr_GetDashboardApprovals (the committee rule) and spr_GetDashboardActionItems (@CommitteeId and
  @DepartmentId, last and optional). Reason 4 for an inactive, unknown or negative committee in all four Dashboard
  procedures. Grants nothing. Test script BMMS-Test-DashboardSummary-Step45.sql: 66 numbered checks, all PASS on
  BMMS_Test; the Test scripts of steps 42, 43 and 44 pass with and without step 45.
- Tests: the Test script of step 45 passes on BMMS_Test; the Test scripts of steps 42 to 44 pass with and without
  step 45; tester agent, run of 2026-11-15 (Tests/_results/2026-11-15_003506): dashboard pack PASSED, 388 checks (new
  checks 12 to 17: the cards, the filters on every card, the My approvals count kept, the inactive committee offered to
  nobody, the cards at five widths, the Meetings tables at narrow widths with a simulated scrollbar; fixture check 39,
  with the inactive committee QA9). The owner's tests passed.

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
