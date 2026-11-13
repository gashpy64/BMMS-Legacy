# Security

- Title: Security
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: UN6c1 (the paragraph on the Dashboard alerts and Action Items under "Role and acting-user checks in procedures"); UN6b (the paragraph on the Dashboard meeting list under "Role and acting-user checks in procedures"); the rest RA1c2
- Last updated by: UN6c1, based on e3bff6b
- Status: Draft
- Verified against: for step UN6c1: Database/BMMS-Fix-DashboardAlerts-Step43.sql (the procedures and functions), BMMS/DashBoard/DashBoard.aspx.cs (what is sent and read back),
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
- To confirm: chapter not written yet (WF2b2); the step that closes the session-role lead
  (RA1d); the minimum SQL Server version (THROW in 24
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
  BMMS/XML/PageAccess.xml (login required, account active, `Session["RoleCode"]` in the page's roles). In
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
- Security lead (not fixed; owner decision, a later step RA1d closes it): only these nine pages check the role
  in the database (since step RA1b also Reports.aspx, Followup.aspx and ViewReport.aspx for the roles named above,
  and since RA1c2 FollowupActionTaken.aspx). Every other page follows the role stored in the session until sign-out, so after a role
  change an open session keeps the old role on those pages, and the menu keeps the old links until the next
  sign-in. [[CONFIRM: the step that closes this (named RA1d by the owner); its date and scope are not in the repository]]

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
