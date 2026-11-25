# Security

- Title: Security
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: GM1a (step 56: the paragraph "Step 56 (GM1a)" under "Role and acting-user checks in procedures"); IU1 (step 55: section "Page access", the new bullet "Decision rules in the database since step 55 (IU1)"); UD1c (step 54: section "Page access", the new bullet "Decision rules in the database since step 54 (UD1c)"); UD1b (step 53: section "Page access", the bullet "Decision rules in the database since step 53 (UD1b)"); MR1 (step 52: section "Page access", the bullet "Decision rules in the database"); RA1d (step 51: section "Page access": layer 1b, the session check on every request, and the former security lead replaced by "Session check since step RA1d"); FU2b (the paragraph "Step 49 (FU2b)" under "Role and acting-user checks in procedures": the report procedures with the acting user, the refusals, no string SQL on the Followup reports, the one list of blank reopen characters); FU2a (the paragraph "Step 48 (FU2a)" under "Role and acting-user checks in procedures": role checks before the lock, a confirmed followup final for every role, the status texts); FU1 (the paragraph "Step 47 (FU1)" under "Role and acting-user checks in procedures": the Followup list, the final confirmed state, Reopen, the reason text and its encoding); UN6d (the paragraph on the Followup saves and the Action Item Details panel under "Role and acting-user checks in procedures"); UN6c2b (the paragraph on the summary cards and the Committee filter under "Role and acting-user checks in procedures"); UN6c2a (the paragraph on the approval rule under "Role and acting-user checks in procedures"); UN6c1 (the paragraph on the Dashboard alerts and Action Items under "Role and acting-user checks in procedures"); UN6b (the paragraph on the Dashboard meeting list under "Role and acting-user checks in procedures"); the rest RA1c2
- Commit: 32c619d
- Last updated by: GM1a, based on 32c619d
- Status: Draft
- Verified against: for step GM1a: Database/BMMS-Fix-GovernanceLog-Step56.sql (the table, the DENY, fn_GovernanceRefusal, the five read procedures and the Reason lines of spr_AddEditDepartment and the other replaced procedures read), BMMS/Report/GovernanceMatrix.aspx.cs and BMMSBAL/GovernanceMgr.cs (read in full), BMMS/Master/Department.aspx.cs (diff), Database/README.md (section Step GM1a: the rules and grants, not the findings); the refusal at nesting level 1 of the internal procedures is taken from Database/README.md and the header comments, the procedure text not read line by line; for step IU1: Database/BMMS-Fix-InactiveUsers-Step55.sql (fn_FunctionalUsers, spr_GetMeetingCommitteeMailId and spr_GetResetPasswordMail read in full), BMMS/Master/ResetPassword.aspx.cs (diff), Database/README.md (section Step IU1: the rules, not the findings); for step UD1c: Database/BMMS-Fix-ManagerScope-Step54.sql (the seven new objects and the Reason 30 and 31 checks read), BMMS/Master/Agenda.aspx.cs, BMMS/Master/User.aspx.cs and BMMS/Report/Reports.aspx.cs (diff), Database/README.md (section Step UD1c: the rules, not the findings); for step UD1b: Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_DepartmentManagers, fn_AgendaWaitingFor, spr_SetManagerAlertRows and the comment of spr_UpdateAgendaByAgendaId read), Database/README.md (section Step UD1b: the rules, not the findings); for step MR1: Database/README.md (section Step MR1: the rules, not the findings), BMMSBAL/MeetingMgr.cs and UserMgr.cs (diff); for step RA1d: BMMS/PageAccessModule.cs, BMMS/Default.aspx.cs, BMMS/Global.asax.cs (diff), BMMSBAL/UserMgr.cs and BMMSDAL/UserDB.cs (diff), Database/BMMS-Fix-SessionCheck-Step51.sql (read in full), Database/README.md (section Step RA1d: the rules, not the findings), Tests/packs/session-check/README.md, the Test and tester results as given;
  for step FU2b: Database/BMMS-Fix-FollowupReports-Step49.sql (the role and Reason lines of the three new procedures and spr_ReopenFollowup, read), BMMS/Report/Followup.aspx.cs and FollowupActionTaken.aspx.cs (diff: the refusals, HtmlEncode of the status texts), BMMSBAL/ActionItemMgr.cs, ReportsMgr.cs and BMMSDAL/ActionItemDB.cs (diff: GetFollowup(string) removed), Database/README.md (section Step FU2b, the rules, not the findings);
  for step FU2a: Database/BMMS-Fix-DashboardFollowupFinal-Step48.sql (the Reason lines of the three procedures), BMMS/DashBoard/DashBoard.aspx.cs (diff: SetActionItemPanelMode, ShowConfirmedAfterSave, InnerText), Database/README.md (section Step FU2a, the rules, not the findings); the system account refusal is taken from the step 43 rule as described in README, not re-read in the script;
  for step FU1: BMMS/Master/Followup.aspx and .aspx.cs (the "<" check, HtmlEncode in grvFollowup_RowDataBound, the reason checks, the Reason texts), BMMSBAL/ActionItemMgr.cs and BMMSDAL/ActionItemDB.cs (diff), Database/README.md (section Step FU1, the rules; the procedure texts of step 47 as described there, the script not read line by line);
  for step UN6d: Database/BMMS-Fix-FollowupSave-Step46.sql (both procedures, read in full), BMMS/Master/Followup.aspx.cs and BMMS/DashBoard/DashBoard.aspx.cs (diff), BMMSBAL/ActionItemMgr.cs and BMMSDAL/ActionItemDB.cs (diff), Database/README.md (section Step UN6d, the rule, not the findings); for step UN6c2b: Database/BMMS-Fix-DashboardSummary-Step45.sql (fn_DashboardCommitteeFilter, spr_GetDashboardSummary, the Reason checks of the three replaced procedures), BMMS/UserControl/MeetingSummary.ascx.cs and BMMS/DashBoard/DashBoard.aspx.cs (diff), Database/README.md (section Step UN6c2b and its Known items); and before: for step UN6c2a: Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (fn_AgendaWaitingFor, spr_GetAgendaApprovalState, spr_GetDashboardApprovals, spr_UpdateAgendaByAgendaId, spr_GetDashboardMeetings, read in full), BMMS/DashBoard/DashBoard.aspx.cs (what is sent, what is read back), BMMSDAL/AgendaDB.cs (diff), Database/README.md (section Step UN6c2a, the rule and the hardening, not the findings); for step UN6c1: Database/BMMS-Fix-DashboardAlerts-Step43.sql (the procedures and functions), BMMS/DashBoard/DashBoard.aspx.cs (what is sent and read back),
  Database/README.md (section Step UN6c1, rules); for step UN6b: Database/BMMS-Fix-DashboardMeetings-Step42.sql (spr_GetDashboardMeetings,
  spr_GetDashboardDepartments, fn_UserDepartmentScope), BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (what is
  sent, what is read back, the encoding), BMMSDAL/MeetingDB.cs and DepartmentDB.cs (diff), Database/README.md
  (section Step UN6b, scope and filters); for step RA1c2: git diff against 1db6ac6 (BMMS/Report/FollowupActionTaken.aspx(.cs),
  BMMS/XML/PageAccess.xml, BMMS/UserControl/MenuUserControl.ascx); for step RA1b (step 41): BMMS/PageAccessModule.cs (HasRole, RefuseRequest,
  ReadDatabaseRole), BMMS/Report/Reports.aspx.cs, Followup.aspx.cs, ViewReport.aspx.cs,
  BMMS/XML/PageAccess.xml, Database/BMMS-Fix-ReportAccess-Step41.sql (header, guards); before: none yet
  (leads from the old Architecture notes added in WF2b1); the THROW
  pointer is from 04-Database.md and the BMMS_Test catalog export of 2026-11-09; for the RA1a
  paragraphs BMMS/PageAccessModule.cs, BMMS/XML/PageAccess.xml, BMMS/UserControl/MenuUserControl.ascx,
  the Page_Load of the nine pages, Database/BMMS-Fix-RoleAccess-Step40.sql (fn_UserChangeRefusal),
  BMMSBAL/UserMgr.cs and MemberTypeMgr.cs
- To confirm: chapter not written yet (WF2b2); the minimum SQL Server version (THROW in 24
  procedures, pointer to chapter 04); leads from the old Architecture notes to verify;
  lead from the old Errata notes: values still stored in the old Triple DES format (empty-string
  key, fixed IV) in the live database

## Sign-in and passwords

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: passwords are stored as PBKDF2 (RFC 2898) hashes, 100,000 iterations, a 16-byte random salt per password, in the form iterations.salt.hash]]
[[CONFIRM: lead from old Architecture notes: the login lookup and the password check are separate (step 1); a user who logs in with the default password goes straight to the first-login password change]]
[[CONFIRM: lead from old Architecture notes: Users.AccountStatus is 1 (active) or 0 (inactive); login refuses an inactive account after the password check, and the page-access module re-reads the status on every request]]
The old Triple DES routine in BMMSBAL/Common.cs (DecryptVal and its encrypt counterpart), kept for values saved before DPAPI, derives its key from a hash of a fixed, empty text and uses a fixed IV in the code; it has no real secret key. [[CONFIRM: lead from old Errata notes: the old Triple DES routine kept for values saved before DPAPI uses no real secret key (a key derived from an empty string and a fixed IV), so a value still stored in the old format, for example an SMTP password or an old Users.Password value, can be read by anyone who can read the database; check the live database for values still in the old format]]

## Page access

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: the roles are admin, controller, manager, user, mgmt, md_sect; the menu and PageAccess.xml decide which pages a role opens]]

How a page is protected (read from the code for step RA1a; the rest of this section is still to be written).

- Layer 1, by address: BMMS.Security.PageAccessModule checks every .aspx request against
  BMMS/XML/PageAccess.xml (login required, the session still matching the database (see "Session check since step
  RA1d" below), `Session["RoleCode"]` in the page's roles). In
  `Enforce` mode a refused request gets the "Access denied" page (HTTP 403) and a DENIED line in
  `App_Data\PageAccessLog.txt`.
- Layer 2, by the page: since step RA1a the nine pages that only an Admin may use call
  `PageAccessModule.RequireRole("admin")` first in `Page_Load` (and in the Reset Password and Backup
  Database button handlers). It reads the user's role and account status from the database by the session's
  `UserId`, so it holds when PageAccess.xml is in `LogOnly` mode, for a session opened before a deployment and
  for a role changed during the session. A refusal writes DENIED-PAGE to the same log, answers the "Access
  denied" page and ends the request; a database error refuses (fail closed). The nine pages: Master/User,
  Department, Designation, MemberType, SubjectType, DecisionType, ResetPassword, BackupDatabase and
  Report/AuditTrail.
- Layer 3, the database: the user and member type procedures refuse a Controller (below).
- The menu (MenuUserControl.ascx) hides the links by `Session["RoleCode"]`; it is not a security check.
- Who may use what since RA1a: Admin only: User Master, Department, Designation, Member Type, Subject Type,
  Decision Type, Reset Password, Backup Database, Audit Trail, SMTP Configuration, System Settings and Reset
  Database. The Controller keeps Member Master, Committee Master, Committee Member Tag / UnTag, Meeting
  Master, Meeting - Member Tag / UnTag and Attendance, and changes only its own password.
- Owner principle (decided 2026-11-10): the Admin is superior for the technical items and the Controller is
  superior for the functional items and gets all functional rights. The first list above is the technical
  group; the Controller's functional rights are the agenda, meeting, minutes, follow-up and report pages.
- Report pages since step RA1b (step 41), checked in the page, with the role read from the database:
  - `PageAccessModule.HasRole(roles)` is new: true for an active user with one of the roles, read from the
    database as `RequireRole` reads it; it refuses nothing, a page uses it to choose a path; a database error
    gives false and an entry in the error log. `PageAccessModule.RefuseRequest(reason)` is new: it refuses the
    current request as `RequireRole` does (DENIED-PAGE in the log with the reason, the "Access denied" page,
    `Response.End`), for a request the page itself rejects.
  - `PageAccess.xml` adds mgmt to Report/Reports.aspx, Report/Followup.aspx and Report/ViewReport.aspx. Reports.aspx:
    any `rc` other than minutes, minutes_extract, agenda_summary and agenda_details is refused ("unknown report
    code"); minutes needs controller, manager or mgmt; the other three need controller or manager, so
    Management with another code is refused on the server. Followup.aspx: any `fc` other than followup and
    summary is refused; the roles are controller and mgmt; a session whose role is mgmt but whose database role
    could not be read is refused (never given the Controller's path).
  - The every-status Minutes report is chosen by `rc == "minutes"` and `HasRole("controller", "mgmt")`, for every
    request, not from the address or ViewState. A database error that hides the role gives the finalised-only
    report (less data, never more). The three step 41 procedures check the acting user again in the database
    (Reason 8 missing or inactive; Reason 4 another role) and return no rows when refused.
  - ViewReport.aspx: for a user whose database role is mgmt, or whose session role is mgmt (fail closed), Page_Load
    refuses a missing, empty or unknown `Session["ViewReportKind"]` and `?pdf=1`; only minutes, followup and
    summary pass. Reports.aspx and Followup.aspx clear the kind on Generate and set it after the report is
    stored. This covers the report, `?pdf=1` and the Export to Word and Export to Pdf postbacks; Print is the
    browser printing the page. The other roles are not affected.
  - Unchanged: Management gets no Minutes Extract and no agenda report.
- Followup by Department since step RA1c2 (Report/FollowupActionTaken.aspx): `PageAccess.xml` gives it
  `roles="controller"` (the Manager had it before), and the page calls `PageAccessModule.RequireRole("controller")`
  first in `Page_Load` and again first in the Generate Report handler, with the role read from the database as in
  RA1a. A Manager, or any other role, gets the "Access denied" page. The Generate Report handler runs the same
  input checks as the View button (committee, meeting and ranges) before it builds the report, clears
  `Session["ViewReportKind"]` before it stores the report (so a kind left by an earlier Minutes or Followup report
  does not stay behind), and the grid labels of meeting number, time, agenda number, subject number and department
  name are HTML-encoded. This is the tenth page that checks the role in the database (the nine of RA1a),
  beside the report pages of RA1b.
- Decision rules in the database since step 52 (MR1): a Manager's approve or reject of an item after the meeting date is refused
  by spr_UpdateAgendaByAgendaId (Reason 28; nothing saved, no mail, no alert), so the rule no longer depends on the Dashboard page
  alone; the Controller's reject is not refused. A Manager who has items routed to him cannot be released (role changed away from
  Manager, a department removed, Deactivate) while they wait (Reason 24); the personal part reads the one rule of who may decide an
  item (fn_AgendaWaitingFor). The date is the database server's date.
- Decision rules in the database since step 53 (UD1b): who may approve or reject an item at AC is every active Manager of the item's
  department (fn_DepartmentManagers: role Manager read from Users, active, not the protected system account, an open department
  mapping), never the item's creator; the creator's Reporting Person and the alert rows no longer decide. The rule is one function
  (fn_AgendaWaitingFor) read by the approval procedure, by the panel and the buttons, and by rule 12. The item is locked first,
  so the first decision wins and a second Manager gets Reason 14. The route of a new item is decided in the database
  (fn_AgendaRoute); the page's route check is only a first look, and the procedure refuses again (Reason 29, 11, 15). The
  procedure that writes and releases the Managers' alert rows (spr_SetManagerAlertRows) is internal: it refuses a direct call
  (@@NESTLEVEL 1) and an acting user who is unknown or inactive; the protected system account is allowed because, as an Admin, it
  may change users in User Master. The Admin role gets no alert rows and no functional mail. A user who handled an alert row
  (Alert_User_Map.HandledBy, a key to Users) cannot be deleted. Nothing is granted to any role by the step.
- Decision rules in the database since step 54 (UD1c): a Manager's departments are one rule, fn_ManagerDepartments (the
  departments of which he is an active Manager by fn_DepartmentManagers), read in the database at the moment of each use and never
  taken from a posted value or from the session. A Manager's new item is refused (Reason 30) outside his active departments, and an
  Update outside his departments of an item he did not enter; the Agenda Entry page checks first and the procedure again. The
  Agenda Summary, Agenda Details, Minutes and Minutes Extract procedures (spr_GetAgendaReport, spr_GetMinutesReportByUser,
  spr_GetReportSubjectNos) and the Manager's department list (spr_GetManagerDepartments) take the acting user: an unknown, inactive
  or system account gets Reason 8, another role or a Manager's department that is not his Reason 4, and no rows. The reports no
  longer build SQL text in the code. The Reporting Person must be an active Controller or an active Manager of the user's
  department, never the user himself (fn_ReportingPersonAllowed); spr_AddEditUser refuses otherwise (Reason 31) on Create and on
  every Update; spr_GetReportingPersonList answers the Admin only. Nothing is granted to any role by the step.
- Decision rules in the database since step 55 (IU1): the users who get a functional alert row, mail or action item row are one
  rule, fn_FunctionalUsers (active, not the protected system account, not the Admin role), read in the database. The Bcc of the
  Meeting and Committee mails comes from spr_GetMeetingCommitteeMailId, which takes the acting user only and refuses an acting user
  who is missing or inactive (Reason 8) or who has a role other than Admin or Controller (Reason 4). The Reset Password mail no
  longer trusts the page: the address and the active status of the chosen user are read by spr_GetResetPasswordMail, under the
  acting-user check of the reset itself (fn_UserChangeRefusal, action 'ResetPassword'), and the page's hidden field for the address is
  removed. Nothing is granted to any role by the step.
- Session check since step RA1d (step 51), which closes the earlier gap that only the pages above read the role
  from the database and every other page followed `Session["RoleCode"]` until sign-out:
  - What is checked: every .aspx request that PageAccess.xml does not open to visitors, with its postbacks and
    UpdatePanel postbacks, the report pop-up Report/ViewReport.aspx, the PDF and Word exports and
    ChangePasswordFirst.aspx. Not checked: Default.aspx, Logout.aspx, Error/ErrorPage.aspx (public in
    PageAccess.xml), WebResource.axd, ScriptResource.axd and static files. The module sees paths ending in .aspx
    only; the project has no .ashx, .asmx or .svc, and a handler type added later must be added to the check in the
    same step.
  - What is compared: at sign-in the session keeps the role (`Session["RoleCode"]`) and a department stamp
    (`Session["DepartmentSet"]`: Users.DepartmentId, "|", the user's open department rows of step 39 with the home
    department marked, for example "4|4h,5"), both from spr_GetUserAccessState. On every request the module reads
    the same procedure once (the result is kept for the request, and RequireRole and HasRole reuse it, so there is
    one database call per checked request) and compares: user missing, user inactive, role different (trimmed, case
    ignored), department set different or missing from the session. The protected system account follows the same
    rule.
  - On a difference: one SESSION-ENDED line in `App_Data\PageAccessLog.txt` (user, role, page, "UserId [n]; [reason]",
    the reason being "missing", "inactive", "role X to Y" or "departments changed"); `Session.Abandon` without
    `Clear`, so Session_End still finds the UserId and closes the open login rows as at sign-out; the session cookie
    (the cookieName of the sessionState section, ASP.NET_SessionId by default) is expired; the redirect to the
    sign-in page with `?status=inactive` (missing or inactive) or `?status=changed` (role or departments). Default.aspx
    compares the value with these two fixed codes and shows a fixed text ("Your account is inactive. Contact the
    administrator." or "Your access has changed. Please sign in again."); any other value shows nothing and is never
    written to the page. An UpdatePanel postback gets the redirect in the ASP.NET AJAX form and the pop-up and the
    exports get it before any byte of the page or file. Unsaved work is lost.
  - On a database error during the check: the session is kept, the page does not run, the safe error page is shown
    (HTTP 500; the error bar for an UpdatePanel postback), the error is written to the error log and one
    SESSION-CHECK-ERROR line to the page access log; the next request checks again (fail closed for that request
    only). Sign-in keeps "Database not connected". Before step RA1d a database error let the request through.
  - Logged values: every value written to the page access log is cleaned of control characters (tab, line breaks), so a
    line always has six columns.
  - Session_End (Global.asax.cs) calls the audit procedure inside a try/catch that writes the error log, and reads
    the UserId with int.TryParse (a UserId that does not parse or is not above 0 skips the call).
  - Unchanged: who may open which page. The menu still hides links by `Session["RoleCode"]` and is not a check; after
    a change the session ends before the menu is built.
  - Deployment: step 51 must be installed before this build, or every signed-in request fails closed. Roll back the
    build first, then the Rollback script of step 51.

## Role and acting-user checks in procedures

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: open known item, see "Known database limitations" in chapter 04: 24 procedures use THROW on BMMS_Test although the house rule for compatibility level 100 says no THROW; it runs because the server is SQL Server 17; the owner has to decide the minimum SQL Server version]]
[[CONFIRM: lead from old Architecture notes: the stored procedures decide which changes a role may make; dbo.fn_UserChangeRefusal (step 13 onwards) says who may change which user]]
[[CONFIRM: lead from old Architecture notes: nobody can delete, deactivate or change the role of their own account; the last active ordinary Admin and the last active Controller cannot be deleted, deactivated or given another role (checked under a lock in the same transaction)]]
Since step 40 (RA1a), dbo.fn_UserChangeRefusal has no branch for the Controller. An Admin may change any user (the rules below still apply); every other role, the Controller included, may only Edit and ResetPassword its own account, and Create or any action on another account is refused with Reason 4 ("You are not allowed to [action]. Only an Admin can change other users' accounts."). Until step 40 a Controller could change Manager, User, Management and MD Secretariat accounts. spr_AddEditMemberType and spr_DeleteMemberTypeByMemberTypeId refuse anyone but an active Admin with Reason 4 ("Only an Admin can change member types."; Reason 8 for a missing or inactive acting user). The Reason codes and the procedures are in chapter 04.
The Dashboard meeting list since step 42 (UN6b) takes its scope from the database, not from the page. The page
sends the acting user id (`Session["UserId"]`) and two filter values (a committee id and a department id, 0 for all).
spr_GetDashboardMeetings and spr_GetDashboardDepartments read the acting user's role and account status
themselves (Users and Roles; an inactive or missing user gets Reason 8 and no rows), take a Manager's or a User's
departments from fn_UserDepartmentScope (the open User_Department rows and the home department), and check both
filter values against that scope: a department that is not one of the user's, or any department for another role,
or a committee that does not exist gives Reason 4 and no rows. So a changed drop-down value or a forged post-back
cannot widen what a Manager or a User sees: a completed meeting is listed only when it has an item of one of the
user's departments, and the counts cover only those items. Controller and Management see every meeting and every
count; MD Secretariat and Admin get the meetings but the counts are not computed (NULL, @StatisticsShown 0). The
page takes the role code and the statistics flag from the procedure, never from ViewState, the query string or
`Session["RoleCode"]`. Both procedures read only and change no data. Department names, committee names and
other text from the database are encoded on output (`HttpUtility.HtmlEncode` in the grid templates, `InnerText`,
a Literal in encode mode). A failure is written to the error log and the card shows a fixed message; no SQL
text or exception detail reaches the page. The recommended hardening is unchanged: the page itself is still
protected by the page-access module like every page (`*` in PageAccess.xml); the meeting list adds no new page
and no new address.
The Dashboard Alerts card, the header count and the Action Items card since step 43 (UN6c1) work the same way:
the page sends the acting user id and, for the alerts, a mode (R, U or A) and a page number; the role is read
from the database by the procedures and never from the page or `Session["RoleCode"]`. fn_DashboardAlerts is the
one listing rule (an Admin gets no functional alerts; a Controller does not get ACA and ACR, a Manager does not
get AMA and AMR), fn_DashboardActionItems the one scope rule (a Controller and Management every item that is not
confirmed; a Manager and a User the items of their departments whose minutes are finalised or confirmed; MD
Secretariat and Admin none). spr_RemoveAlertForUser changes a row only when it is the acting user's own: the row
id comes back from the page in a hidden field, and another user's or an unknown id gives Reason 4 and changes
nothing. spr_OpenDashboardActionItem and spr_SaveDashboardActionText check the scope again on the server whatever
the page sends: Management can open an item but its save is refused (Reason 4), as are MD Secretariat, Admin and
an item of another department; the scope is part of the UPDATE itself. Opening an item writes only the person's
own read row. A mode other than R, U or A and a page number below 1 give Reason 4. The two mail procedures leave
the Admin role out. Failures are written to the error log and the cards show fixed messages.
Who may approve or reject an agenda item since step 44 (UN6c2a) is one rule on the server, the function
fn_AgendaWaitingFor, and every use of it agrees: the My approvals panel (spr_GetDashboardApprovals), the Waiting
for me column (spr_GetDashboardMeetings), the Approve and Reject buttons (spr_GetAgendaApprovalState) and the
approval itself (spr_UpdateAgendaByAgendaId, Reason 14 for what the rule does not allow). The page sends the acting
user id (and, for the panel, a committee id, a department id and a page number); the role is read from the database.
The function returns nothing for an inactive user and for the protected system account, and nothing for a role
other than Manager and Controller; spr_GetDashboardApprovals and spr_GetAgendaApprovalState refuse the system
account as such (Reason 12) before they look at the role. A Manager sees and may decide only the items routed to
him (he is the creator's manager, or has a row in Alert_User_Map for the item's alert), whatever drop-down value is
posted: a department that is not his, any department for a Controller, an unknown committee or a page below 1 gives
Reason 4 and no rows. The three read procedures take the date from the database server (GETDATE()), and the page no longer compares
the meeting date with the web server's date. The meeting-date rule (no decision once the meeting date
has passed) is enforced by the page, which reads it from spr_GetAgendaApprovalState before it shows the buttons and
before a decision; spr_UpdateAgendaByAgendaId does not look at the date. Recommended hardening: refuse in the
procedure by the function's DateOpen flag, which is a change of behaviour and a later step. The grants are
unchanged: step 44 grants nothing and the application login keeps EXECUTE on the schema.
The summary cards and the Committee filter since step 45 (UN6c2b) work the same way. spr_GetDashboardSummary takes the
acting user id, a committee id and a department id, and reads the role and the departments from the database: the
Controller, Management, Manager and User get counts; MD Secretariat and Admin get Reason 4 and no counts; the system
account Reason 12; a missing or inactive user Reason 8. The Committee filter is one function,
fn_DashboardCommitteeFilter, read by all four Dashboard procedures (meeting list, summary, My approvals, Action Items):
0, or an active committee; an inactive, unknown or negative id gives Reason 4 and no rows, whatever the drop-down
sent. The Action Items procedure now takes the department filter too and checks it against the user's departments
(any department is refused for the Controller and Management). The page may send a stale or forged department value
(it sends the last one chosen even when the drop-down is not shown); the server checks it and a wrong one gives
Reason 4, dashes and a message, never other people's data. The count a card cannot read is shown as a dash with the
text "count not available", never as 0. Step 45 grants nothing and the application login keeps EXECUTE on the schema.
The two saves of the Followup page (Master/Followup.aspx) since step 46 (UN6d) are decided on the server. The page
sends the acting user id (`Session["UserId"]`; a session without a usable id is sent to the sign-in page) and the item
id or the list of item ids and ticks. spr_SaveFollowupActionText and spr_SaveFollowupConfirmed read the role and the
account status from the database: only an active Controller that is not the system account may save; the system
account gets Reason 12, a missing, 0, NULL or inactive user Reason 8, every other role (Manager, User, Management, MD
Secretariat, Admin) Reason 4, and a refused call writes nothing. The Submit is one call and one transaction, so one
refused row (an item that does not exist, an id given twice, a tick other than 0 or 1, a list that cannot be read)
refuses the whole Submit. The list is built with XmlWriter and read as XML by the procedure, and the ids are checked
as whole numbers, so nothing the page sends is read as markup or as SQL. Before step 46 the page called
spr_UpdateActionItem with no acting user, so any session that reached the page, the MD Secretariat too, could save.
What the page shows by role (Save, Submit, the ticks, the read-only line, "View" in place of "Edit") follows
`Session["RoleCode"]` and is for display only: a forged post-back of a hidden button is still refused by the
procedure. The same holds for the Dashboard's Action Item Details panel since UN6d (Submit and Cancel for the
Controller, Manager and User, Close and a read-only line for every other role): the buttons follow the session
role, and spr_SaveDashboardActionText (step 43, not changed) decides. A role changed while a person is signed in
shows the old buttons until the next sign-in, and a save is then refused or allowed by the new role. PageAccess.xml is
not changed: the Followup page still opens for controller and md_sect. Step 46 grants nothing and the application
login keeps EXECUTE on the schema. A failed save is written to the error log and the page shows a fixed message.
Step 47 (FU1) keeps the same rules and adds three. (1) The Followup list is read through spr_GetFollowupList with the
acting user id: only an active Controller or MD Secretariat that is not the system account gets rows (Reason 12 for the
system account, 8 for a missing, 0, NULL or inactive user, 4 for any other role); the result is always one result set,
empty when refused. (2) A confirmed followup is final on the server, not only on the page: spr_SaveFollowupActionText
refuses an item that is confirmed (Reason 26) and spr_SaveFollowupConfirmed skips a row that is already confirmed and
counts it, so a stale page cannot overwrite or confirm twice; the page's own Pending test is for display only. (3) Only
spr_ReopenFollowup (an active Controller, same Reasons 12, 8 and 4) turns a confirmed item back to Pending, one item
per call, with a reason that must not be blank (Reason 4); an item that is not confirmed gives Reason 27. Every confirm
and every reopen writes one row of Action_Item_Status_History (who, when, and for a reopen the reason); no procedure
updates or deletes those rows. The XML list of spr_SaveFollowupConfirmed now accepts the attribute id only: the
attribute c that the build of step 46 sent makes the whole call a refusal (Reason 4), so the old build cannot save
after step 47. The reopen reason is plain text: the page checks its length (500 characters) and refuses a "<" followed
by a letter, "!", "/" or "?", or "&#" in the browser, because ASP.NET request validation would otherwise send the person
to the error page; every text from the database that the Status cell shows (names, reason, date) is HTML-encoded with
HttpUtility.HtmlEncode and written through a Literal. spr_DeleteUserByUserId refuses a user who has history rows
(Reason 6), so the record of who acted keeps its person. Step 47 grants nothing; the application login keeps EXECUTE on
the schema.
Step 48 (FU2a) carries the finality of a confirmed followup to the Dashboard, again on the server. spr_SaveDashboardActionText
checks in this order: the role (Reason 8 for a missing, 0 or inactive user; Reason 4 for Management, MD Secretariat,
Admin and the system account), then, in one transaction (its own only when the caller has none), the item read under
UPDLOCK, HOLDLOCK together with the scope rule (an item outside the person's scope, or unknown, whether confirmed or
not, gives Reason 4, so a confirmed item outside the scope is not revealed), then a confirmed item in scope gives
Reason 26 and nothing is saved, for every role that may save; only then the UPDATE. The lock closes the gap between the
test and the write, so a confirm that comes in between is not overwritten. A stale page, a panel opened before the
confirm or a forged post-back therefore cannot change a confirmed item; what the panel shows (read-only, no Submit) is
for display only. spr_OpenDashboardActionItem now returns a confirmed item, but only one in the person's scope (the same
scope function, fn_DashboardActionItemScope; the card itself still lists no confirmed item). Who confirmed or reopened
an item (name, login, time and the reopen reason, at most 500 characters) is shown only to a person who may open that
item. Every such text is plain text: the panel sets it with InnerText and so encodes it. Step 48 grants nothing; the
application login keeps EXECUTE on the schema.
Step 49 (FU2b) moves the Followup reports to procedures that decide on the server. spr_GetFollowupReport (Followup and
Followup Summary) reads the role of @ActingUserId in the database (active, not the system account): Reason 8 for a missing,
0, inactive or system account, Reason 4 for every role but the Controller and Management, then the same columns with no rows;
the minutes columns are filled for Management only. spr_GetFollowupByDepartmentReport allows the Controller only (Reason 4 for
Management too, Reason 8 as above). The page passes the session's UserId and shows the refusal text for Reason 8 or 4 in View,
Generate and Export; the page's own RequireRole check stays first. The Followup reports no longer build SQL text in the code:
the one path that ran a string (ActionItemDB.GetFollowup) is removed, the filters (including the subject range of Followup by
Department, two integer parameters parsed on the page) go as parameters, and the committee and subject filters that the page
did in row filters are in the procedure. The status texts (names, login, reason, date) are plain text: every one is
HtmlEncode-d before it is written in the grid cell, the report HTML and the printed Summary; the reason is at most 500
characters. spr_ReopenFollowup and the page now refuse a reopen reason that holds only blank characters by one list of 27
characters (tab, line breaks, the Unicode spaces, zero-width space and BOM), the same list in C# and in the procedure, so a
reason of zero-width spaces can no longer pass the page and be stored or be refused with a misleading message. Step 49 grants
nothing; the application login keeps EXECUTE on the schema.
Step 56 (GM1a) adds the Governance Matrix, read only, and a change log that only the procedures can write. (1) Page: Report/GovernanceMatrix.aspx
is listed for admin and controller in PageAccess.xml, and its Page_Load calls RequireRole("admin", "controller") first, so the role is read
from the database on every request. The page has no control that saves. (2) Reads: spr_GetGovernanceMatrix, spr_GetGovernanceSettings,
spr_GetGovernanceDepartments, spr_GetGovernanceChangeLog and spr_GetGovernanceLogUsers take the session's user id and check it again
in fn_GovernanceRefusal: Reason 8 for a missing, 0 or inactive user, Reason 4 for every role but Admin and Controller, then no rows;
the date is checked on the server (Reason 32 before the history start, 33 missing or after today, 34 for the change log range), whatever
the page sends. (3) The log: Governance_Change_Log has DENY INSERT, UPDATE and DELETE to public, so the application's database users
(db_datareader, db_datawriter, EXECUTE on schema dbo) cannot write it directly; the seven procedures that change users, departments and
settings write it inside their transaction (ownership chaining, all objects dbo) through spr_WriteGovernanceChange and
spr_WriteGovernanceUserChanges, which are denied to public and refuse a call at nesting level 1. A key to Users on ChangedBy keeps the
record of who acted: a user who is ChangedBy of a row cannot be deleted (Reason 6, group "user changes"). (4) Department Master: since
step 56 spr_AddEditDepartment takes the signed-in user and refuses an inactive or missing user (Reason 8) and any role but Admin
(Reason 4) before it changes anything, so the save no longer depends on the page check alone. (5) Output: every value on the page is plain
text, encoded by the grids, the literals and the exports; the CSV puts a ' before a cell that begins with = + - @, a tab or a
carriage return, so a spreadsheet does not read it as a formula; the downloads carry X-Content-Type-Options: nosniff; the page is sent
no-cache and no-store. Step 56 grants nothing new beyond the DENY and the two denied procedures.
[[CONFIRM: lead from old Architecture notes: the acting user is the logged-in user, passed as @ActingUserId; a missing or inactive acting user is refused]]
[[CONFIRM: lead from old Architecture notes: one protected system account (Users.IsSystem = 1) cannot be edited, deleted, deactivated or given another role, even by itself; only it can change its own password; it takes no part in the workflow (step 18)]]
[[CONFIRM: lead from old Architecture notes: every protected procedure returns one row Result, Reason, ReasonDetail (1 done, 0 refused); the page turns the Reason into a sentence; a database error is re-raised, not reported as a refusal]]

## Input and output handling

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Errata notes: a scan of the stored procedures for dynamic SQL (EXEC of a string, sp_executesql) found none; this lead is contradicted by the 2026-11-09 BMMS_Test catalog export, where spr_sys_ResetDatabase calls sp_executesql twice (see "Dynamic SQL in the stored procedures" in chapter 04, Database); decide what chapter 08 says after the owner has read chapter 04]]
[[CONFIRM: lead from old Errata notes: report queries built in ReportsMgr and the database backup (Sql_Backup_Mgr) are the calls that do not use a stored procedure]]

## Uploads

[[CONFIRM: not written yet (WF2b2)]]

## Audit trail

[[CONFIRM: not written yet (WF2b2)]]

## Recommended hardening

[[CONFIRM: not written yet (WF2b2)]]
