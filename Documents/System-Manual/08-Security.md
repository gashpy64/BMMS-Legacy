# Security

- Title: Security
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: WF2c2 (the chapter written: sign-in and passwords, session, page access complete, role and acting-user checks, procedures that rely on page access only, input and output, uploads, audit trail, Azure SQL Database, recommended hardening; the three Outdated drift rows closed: MD Secretariat statistics, the meeting-date rule in the database, the THROW count); GM1a (step 56: the paragraph "Step 56 (GM1a)" under "Role and acting-user checks in procedures"); IU1 (step 55: section "Page access", the new bullet "Decision rules in the database since step 55 (IU1)"); UD1c (step 54: section "Page access", the new bullet "Decision rules in the database since step 54 (UD1c)"); UD1b (step 53: section "Page access", the bullet "Decision rules in the database since step 53 (UD1b)"); MR1 (step 52: section "Page access", the bullet "Decision rules in the database"); RA1d (step 51: section "Page access": layer 1b, the session check on every request, and the former security lead replaced by "Session check since step RA1d"); FU2b (the paragraph "Step 49 (FU2b)" under "Role and acting-user checks in procedures": the report procedures with the acting user, the refusals, no string SQL on the Followup reports, the one list of blank reopen characters); FU2a (the paragraph "Step 48 (FU2a)" under "Role and acting-user checks in procedures": role checks before the lock, a confirmed followup final for every role, the status texts); FU1 (the paragraph "Step 47 (FU1)" under "Role and acting-user checks in procedures": the Followup list, the final confirmed state, Reopen, the reason text and its encoding); UN6d (the paragraph on the Followup saves and the Action Item Details panel under "Role and acting-user checks in procedures"); UN6c2b (the paragraph on the summary cards and the Committee filter under "Role and acting-user checks in procedures"); UN6c2a (the paragraph on the approval rule under "Role and acting-user checks in procedures"); UN6c1 (the paragraph on the Dashboard alerts and Action Items under "Role and acting-user checks in procedures"); UN6b (the paragraph on the Dashboard meeting list under "Role and acting-user checks in procedures"); the rest RA1c2
- Commit: f8d57ed
- Last updated by: WF2c2, based on f8d57ed (the whole chapter); GM1a, based on 32c619d
- Status: Draft
- Verified against: for step WF2c2: BMMS/Default.aspx.cs, ChangePasswordFirst.aspx(.cs), Master/ChangePassword.aspx.cs and ResetPassword.aspx.cs, BMMSBAL/Common.cs (HashPassword, VerifyPassword, ProtectSecret, UnprotectSecret, IsLoggedIn), BMMS/Web.config, XML/AppSettings.xml and PageAccess.xml, PageAccessModule.cs, Global.asax.cs, Logout.aspx.cs, JScript/Validation.js (ChangePasswordValidation, ChkPasswordRules), BMMSBAL/HtmlCleaner.cs, SafeFileName.cs, OrganisationDetails.cs (PrepareLogo, UploadLogo), Sql_Backup_Mgr.cs, BMMSDAL/CommonDB.cs, Master/Agenda.aspx.cs, Member.aspx.cs, SystemSettings.aspx.cs and Report/SendMail.aspx.cs (the upload code), the aspx files (Grep for ValidateRequest), Database/BMMS-Fix-GovernanceLog-Step56.sql (the DENY lines 227, 1044 and 1045), Database/README.md (Known items for later steps, Step GM1a C5), and in the catalog export of 2026-11-28 (step 57; outside the repository) parameters.txt, columns.txt and the module texts of fn_UserChangeRefusal, spr_GetUserAccessState, spr_AgendaFinalizeByMeetingId, spr_UpdateMinutes, spr_MinutesFinalizeByMeetingId, spr_MinutesConfirmByMeetingId, spr_AddEditCommittee, spr_DeleteDepartmentByDeptId, spr_UpdateAgendaByAgendaId, spr_GetDashboardMeetings and spr_GetDashboardSummary; the roles and permissions of bmms_app and public's step 56 DENY rows on the Azure copy are the owner's check of 2026-11-28 (read-only queries, as given); chapters 03, 04, 05, 06 and 07 for the links; for step GM1a: Database/BMMS-Fix-GovernanceLog-Step56.sql (the table, the DENY, fn_GovernanceRefusal, the five read procedures and the Reason lines of spr_AddEditDepartment and the other replaced procedures read), BMMS/Report/GovernanceMatrix.aspx.cs and BMMSBAL/GovernanceMgr.cs (read in full), BMMS/Master/Department.aspx.cs (diff), Database/README.md (section Step GM1a: the rules and grants, not the findings); the refusal at nesting level 1 of the internal procedures is taken from Database/README.md and the header comments, the procedure text not read line by line; for step IU1: Database/BMMS-Fix-InactiveUsers-Step55.sql (fn_FunctionalUsers, spr_GetMeetingCommitteeMailId and spr_GetResetPasswordMail read in full), BMMS/Master/ResetPassword.aspx.cs (diff), Database/README.md (section Step IU1: the rules, not the findings); for step UD1c: Database/BMMS-Fix-ManagerScope-Step54.sql (the seven new objects and the Reason 30 and 31 checks read), BMMS/Master/Agenda.aspx.cs, BMMS/Master/User.aspx.cs and BMMS/Report/Reports.aspx.cs (diff), Database/README.md (section Step UD1c: the rules, not the findings); for step UD1b: Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_DepartmentManagers, fn_AgendaWaitingFor, spr_SetManagerAlertRows and the comment of spr_UpdateAgendaByAgendaId read), Database/README.md (section Step UD1b: the rules, not the findings); for step MR1: Database/README.md (section Step MR1: the rules, not the findings), BMMSBAL/MeetingMgr.cs and UserMgr.cs (diff); for step RA1d: BMMS/PageAccessModule.cs, BMMS/Default.aspx.cs, BMMS/Global.asax.cs (diff), BMMSBAL/UserMgr.cs and BMMSDAL/UserDB.cs (diff), Database/BMMS-Fix-SessionCheck-Step51.sql (read in full), Database/README.md (section Step RA1d: the rules, not the findings), Tests/packs/session-check/README.md, the Test and tester results as given;
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
- To confirm:

## Sign-in and passwords

### The sign-in flow (BMMS/Default.aspx.cs, btnLogin_Click)

1. The Login ID and the password are trimmed. The lookup (`UserMgr.GetUserByLoginName`, the procedure spr_GetUserByLoginName) only reads the user's row, with the stored password text; it does not compare the password. The lookup and the password check were split in database step 1 (Database/README.md, run order), because a salted hash cannot be compared inside the query.
2. No row for the Login ID, or a password that `Common.VerifyPassword` does not accept: the same message "Invalid User Id / Password", and both boxes are emptied. The session counts the failed tries (`Session["LoginCount"]`), but nothing acts on the count: the call that would lock the account after three tries is commented out in the code, and spr_LockUserByUserId is retired (chapter 04). There is no lock-out.
3. Password accepted but `AccountStatus` is not 1: "Your account is inactive. Contact the administrator." This is tested after the password, so the message does not tell a stranger that a Login ID exists.
4. Active account: the page reads the access state once (`UserMgr.GetUserAccessState`, spr_GetUserAccessState; a missing or inactive user gets the inactive message), records the sign-in in Audit_Trial_Login (spr_RecordLoginByUserId), and puts the user id, names, role code and department stamp in the session. A database error shows "Database not connected" and writes the error log.
5. If the password typed is the default password the page opens ChangePasswordFirst.aspx, otherwise the Dashboard.

A stored value that is not in the form `iterations.salt.hash` (the old single-blob form) is refused by `VerifyPassword`, so that user gets "Invalid User Id / Password". The line in btnLogin_Click that re-hashes an old-format value after a successful check therefore never runs: `IsLegacyFormat` is true only for the old form, which `VerifyPassword` has already refused (BMMS/Default.aspx.cs lines 137 and 138, BMMSBAL/Common.cs line 643).

### Password storage (BMMSBAL/Common.cs, HashPassword and VerifyPassword)

- PBKDF2 through `Rfc2898DeriveBytes` (the constructor with password, salt and iteration count; the code names no hash algorithm), 100,000 iterations (constant `HashIterations`), a 16-byte random salt per password from `RNGCryptoServiceProvider`, a 32-byte derived key.
- The stored form is `100000.<base64 salt>.<base64 hash>` in Users.Password. `VerifyPassword` reads the iteration count, the salt and the hash from the stored text, so the count can be raised for new passwords without breaking old ones.
- The comparison XORs the two byte arrays and tests the result at the end (a fixed-time comparison, written inline in `VerifyPassword`; the separate `FixedTimeEquals` helper is not called).
- No hash value is written in any document. The four user-list procedures still return the Password column to the server (the hashes do not reach a page; Database/README.md, Known items).

### The default password and the first sign-in

One default password is fixed in the source (`Common.DefaultPassword`; its value is not written here). Reset Password (Admin) sets it, and Reset Database seeds the default users with its hash. The sign-in page compares the typed password with it and sends the user to ChangePasswordFirst.aspx.

- ChangePasswordFirst.aspx and Master/ChangePassword.aspx check on the server: the old password (`VerifyPassword`) and a new password longer than PasswordMinLength. The new password is hashed and saved by spr_ResetPasswordByUserId under the rule `fn_UserChangeRefusal` action ResetPassword (an own account is allowed).
- The server does not check that the new password differs from the default password, and does not compare it with the confirmation box. The browser script does check the confirmation and a complexity rule (`ChangePasswordValidation`, `ChkPasswordRules`, BMMS/JScript/Validation.js: a digit, a lower-case letter, an upper-case letter and a special character).
- The redirect to ChangePasswordFirst.aspx is made once by Default.aspx. PageAccessModule does not know whether the user has changed the default password, so nothing on the server forces the change before other pages are opened.
- After a change on ChangePasswordFirst.aspx the page shows "Your password changed successfully" and goes back to the sign-in page; on Master/ChangePassword.aspx the page shows "Successfully Saved" and the session continues.

### Inactive and changed accounts

Users.AccountStatus is 1 (active) or 0 (inactive). Sign-in refuses an inactive account after the password check (step 3 above). After sign-in PageAccessModule reads the status, the role and the department set again on every checked request and ends the session when the user is missing, inactive or changed (section "Session" and "Page access"). A user who is deactivated, or whose role or departments change, is sent back to the sign-in page with a fixed text.

### The sign-in password limits

AppSettings.xml holds LoginIdMaxLength (12), PasswordMaxLength (12) and PasswordMinLength (6); chapter 06, "Application settings (AppSettings.xml)", has the table and the files that read them. What matters here:

- The box limit (the MaxLength attribute of the Login ID and password boxes: Default.aspx.cs, ChangePasswordFirst.aspx.cs, Master/ChangePassword.aspx.cs, Master/User.aspx.cs) is a browser limit only. No server code compares the typed text with PasswordMaxLength or LoginIdMaxLength, so a longer text that reaches the server by another route is accepted.
- The minimum is checked on the server, in the code-behind of ChangePasswordFirst, ChangePassword and (on Save of a new user) User Master, not in a stored procedure. The test is `Length <= PasswordMinLength`, so a password must have more characters than the value: with 6 it needs 7, while the message says "Password length minimum of 6 characters in length". Reset Password does not use the settings; it sets the default password.

What an installer can do about the sign-in facts above (no lock-out; no forced change of the default password; no server check that a new password differs from the default or matches the confirmation box; the box limits only in the browser): after a Reset Password, or for a new user, the person signs in and changes the password at once; a failed sign-in is not recorded anywhere (a wrong password or an unknown Login ID writes nothing; chapter 04, "The audit tables"), so the only control against repeated tries is who can reach the sign-in page, for example by limiting the network that can reach the site.

### The old Triple DES routine and the DPAPI value

`Common.DecryptVal` (with its encrypt counterpart in BMMSBAL/Common.cs) is the older routine, kept for values saved before DPAPI. It derives its key from fixed text in the source code and uses a fixed IV, so a value stored in that form is not protected against anyone who has the source. The routine is reached only through `Common.UnprotectSecret`, for a stored value that does not start with `dpapi:` (marked transitional in the code). `Common.ProtectSecret` writes the DPAPI form (machine scope, prefix `dpapi:`); no key is held in code or configuration for a value with that prefix (chapter 07, "Where the settings live and who edits them", says the same for the SMTP password).

Installer action after an upgrade (owner decision D4):

1. Sign in as the Admin and save the SMTP password once on SMTP Configuration (it is saved in the DPAPI form).
2. Check that the stored value now starts with `dpapi:`. The value is in table SMTP_Master, column Password. Check only that the start of the text is `dpapi:` (for example compare `LEFT(Password, 6)`); do not select or print the whole value.

Users.Password does not use this routine: it holds the PBKDF2 form.

## Session

- Mode and timeout (BMMS/Web.config): `<sessionState timeout="10" mode="InProc"/>`: the session lives in the memory of the web application (it is lost when the application restarts or is recycled, and it is not shared between servers) and ends after 10 minutes without a request (the timeout is in minutes). Deleting a folder inside the application folder restarts the application (Database/README.md, Known items).
- Authentication: Web.config has `<authentication mode="Windows"/>`. The application sets no forms-authentication cookie: "signed in" means that `Session["UserId"]` holds a whole number above 0 (`Common.IsLoggedIn`), set by Default.aspx after a successful sign-in.
- The session check (step 51, RA1d): PageAccessModule reads spr_GetUserAccessState on every checked request and ends the session when the user is missing, inactive, or has another role or department set than at sign-in. The details are in "Page access", "Session check since step RA1d".
- Session_End (Global.asax.cs): when a session times out or is abandoned it calls the audit procedure that closes the user's open login rows, inside a try/catch that writes the error log; Logout.aspx does the same, then `Session.Clear()`, `Session.Abandon()` and a redirect to the sign-in page.
- The session id is not renewed at sign-in: Default.aspx puts the user into the session the browser already holds and does not abandon it first (Database/README.md, Known items, step RA1d).
- The session cookie has the default name `ASP.NET_SessionId` (no `cookieName` in Web.config). Web.config has no `httpCookies` or `requireSSL` setting, so the cookie is HttpOnly but not marked Secure (Database/README.md, Known items, step RA1d). The cookie that PageAccessModule expires when it ends a session is HttpOnly and not Secure either.
- What an installer can do: serve the site over HTTPS only (a redirect from http to https at the web server or hosting level), so that the session cookie is never sent over a plain connection; Web.config does not do this.

## Page access

Four layers decide who may do what. In the order a request meets them:

1. Layer 1, by address: PageAccessModule (BMMS/PageAccessModule.cs, registered in Web.config in both `httpModules` and `system.webServer/modules`) runs after the session is available. It looks at a request only when its application-relative path ends in `.aspx`; any other request (a static file, WebResource.axd, ScriptResource.axd) is not seen by it. Pages listed under `<public>` in BMMS/XML/PageAccess.xml (Default.aspx, Logout.aspx, Error/ErrorPage.aspx) pass. For every other page it requires a signed-in session, then layer 1b, then the role in the policy.
2. Layer 1b, the session check of step 51 (below): the session must still match the database.
3. Layer 2, by the page: `PageAccessModule.RequireRole(...)` and `HasRole(...)` read the role from the database for the page or the action (below).
4. Layer 3, the database: procedures that check the acting user and the role and answer with a Reason (next section).

The mode is the `mode` attribute of the root element of PageAccess.xml: `LogOnly` blocks nothing for role reasons and writes WOULD-DENY lines to `App_Data\PageAccessLog.txt`; `Enforce` (the value in the repository file) answers a refused request with the "Access denied" page, HTTP 403, and a DENIED line. The sign-in requirement applies in both modes. A page that is not listed is treated as not allowed. When the policy file cannot be read, only the sign-in requirement and the session check are applied and POLICY-NOT-LOADED is written to the log (the policy is cached for 30 seconds in that case and reloaded when the file changes otherwise). `RequireRole` does not depend on the mode.

The six roles (Roles.RoleCode) are admin, controller, manager, user, mgmt (Management) and md_sect (MD Secretariat). PageAccess.xml lists, per page, the roles allowed (`*` is any signed-in user); the menu (MenuUserControl.ascx) shows each role the links it may open. The menu is built from `Session["RoleCode"]` and is not a security check. The Governance Matrix (Report/GovernanceMatrix.aspx) shows the rules that apply, read from PageAccess.xml itself (`RolesForPage`).

How a page is protected, by step:


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

The stored procedures decide which changes a role may make, so that a request that gets past the page checks still meets a rule in the database. dbo.fn_UserChangeRefusal (step 13 onwards; text in the catalog export of 2026-11-28) says who may change which user. It returns a Reason number, 0 for allowed, and is called by spr_AddEditUser (Create, Edit, RoleChange), spr_SetUserStatusByUserId, spr_DeleteUserByUserId, spr_ResetPasswordByUserId and spr_CheckUserChange. In the order the function tests:

- Acting user 0, missing or inactive: Reason 8.
- The protected system account (Users.IsSystem = 1): nobody may Edit, Delete, Deactivate or change the role of it, even the account itself; only the account itself may reset its password (Reason 7 otherwise). It takes no part in the workflow (it is left out of fn_FunctionalUsers and of the approver functions).
- Own account: no Delete, Deactivate or RoleChange of yourself (Reason 1).
- Role: an Admin may do anything the other rules allow; every other role, the Controller included, may only Edit and ResetPassword its own account (Reason 4).
- The last active ordinary Admin (the system account does not count) and the last active Controller cannot be deleted, deactivated or given another role (Reasons 2 and 3). The procedures take a lock on the Users table (`UPDLOCK, HOLDLOCK`) before they call the function, in the same transaction, so two changes at the same moment cannot both pass.

Every protected procedure returns one row Result, Reason, ReasonDetail (Result 1 done, 0 refused; chapter 04, "Result, Reason and ReasonDetail"); the data layer reads it into a result object (UserMgr.cs: `UserChangeResult`, MeetingMgr.cs: `MeetingChangeResult`) and the page turns the Reason into a sentence. A refusal is never raised as an error, and a database error is never turned into Result 0. The procedures roll back in a CATCH block and raise the error again (`THROW;` or RAISERROR); `BMMSDAL/CommonDB.cs` catches the exception and throws it again (`throw ex`), so it reaches the page's error handling (the error log and the fixed error page, chapter 05, "Error handling"). A result table without a Reason column raises an InvalidOperationException in the data layer.

The acting user is the signed-in user, taken from the server-side session only (`Session["UserId"]`, 0 when missing; for example `ActingUserId()` in Master/User.aspx.cs) and passed as @ActingUserId. 54 stored procedures in the catalog export of 2026-11-28 take @ActingUserId (parameters.txt: 57 modules, with the functions fn_AgendaChangeRefusal, fn_GovernanceRefusal and fn_UserChangeRefusal); a missing, 0 or inactive acting user is refused (Reason 8), and for the Dashboard and report procedures the protected system account gets Reason 12. Other procedures take the user as @UserId, @UpdatedBy or @CreatedBy (see the next list).

SQL Server version (owner decision D3, statement of 2026-11-28): "No minimum SQL Server version is set. BMMS is tested on SQL Server 2025 (17.x) Express and Developer and on Azure SQL Database; older versions are not tested." The catalog export of 2026-11-28 holds 24 THROW statements in 23 modules (chapter 04, "A refusal is not a database error"), although the house rule for Database/ scripts is no THROW at compatibility level 100; BMMS_Test runs them at level 100.

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
count; since step 45 (UN6c2b) the MD Secretariat gets the statistics too (read only, as Management; no Waiting for me column), and only the Admin gets the meetings without counts (NULL, @StatisticsShown 0). The
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
has passed): the page reads it from spr_GetAgendaApprovalState before it shows the buttons and before a decision,
and since step 52 (MR1) spr_UpdateAgendaByAgendaId refuses a Manager's approve or reject after the meeting date with
Reason 28 by the function's DateOpen flag (nothing saved, no mail, no alert; the Controller's reject is not refused; see "Decision rules in the
database since step 52" under "Page access"). The grants are
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
### Procedures that rely on page access only

These procedures, read in the catalog export of 2026-11-28 (parameters.txt and the module text), check no role and no acting user. Only PageAccess.xml (layer 1) and the menu keep another role away from them (Database/README.md, Known items: step GM1a C7 and step IU1 G6 for the first five, step GM1a for the last).

| Procedure | What it takes | What it checks | Recorded user |
|---|---|---|---|
| spr_AgendaFinalizeByMeetingId | @MeetingId only | The meeting exists (Reason 4) and its agenda is Open (Reason 3) | The minutes it creates are written with the literal user id 1 |
| spr_UpdateMinutes | @CreatedBy and @UpdatedBy | Meeting found (4), minutes not confirmed (7), workflow order (17, 18), due date (22) | The two parameters are written as given; neither is checked as an active user or by role |
| spr_MinutesFinalizeByMeetingId | @MeetingId and @UserId | Meeting found (4), status (3), workflow order (17, 18, 19) | @UserId is written as UpdatedBy of the meeting and of the new action items; it is not checked |
| spr_MinutesConfirmByMeetingId | @MeetingId and @UserId | Meeting found (4), minutes finalized (3) | @UserId is written as UpdatedBy of the meeting; it is not checked |
| spr_AddEditCommittee | The committee columns, @CreatedBy and @UpdatedBy; no @Result or Reason | Nothing about the user | @CreatedBy gives the department of the alert and is left out of the alert recipients |
| spr_DeleteDepartmentByDeptId | @DeptId only | The department is not used by agenda items or users (Reason 5) and has no open or past mapping (Reason 25) | None; it writes no log row and runs without a transaction |

The step 56 change of spr_AddEditDepartment (acting user, Reasons 8 and 4) did not cover the delete. The Designation, Subject Type and Decision Type save procedures take only @CreatedBy and @UpdatedBy, and their delete procedures only the id (parameters.txt; Database/README.md, Known items, step RA1a).

## Input and output handling

### Request validation

`httpRuntime requestValidationMode="2.0"` (Web.config) keeps ASP.NET request validation on for pages (it does not check other requests). `ValidateRequest="false"` is set on 11 pages (Grep of the aspx files): ChangePasswordFirst, Logout, Master/AgendaFinalization, Attendance, BackupDatabase, ChangePassword, MinutesConfirmation, MinutesFinalization, ResetPassword, SMTPServerConfig and Report/AttendanceDetails. Agenda Entry, Update Minutes, the Dashboard, Followup and Send Mail have it on (Database/README.md, steps A2a and A3): a `<` followed by a letter in a plain text box there gives the safe error page and one error-log entry with the value replaced by "(value not logged)".

### Rich text (BMMSBAL/HtmlCleaner.cs)

Rich text from the editor is cleaned to an allow-list before it is saved or shown.

- Kept: p, br, b, strong, i, em, u, ul, ol, li, table, thead, tbody, tr, th, td; `align` (left, right, center, justify) on p, td and th, also read from `style="text-align:..."`; colspan and rowspan from 1 to 100 on td and th. Every table is written with `border="1" cellpadding="4" cellspacing="0"`.
- Changed: div becomes p, h1 to h6 a bold paragraph, tfoot tbody.
- Removed with their content: script, style, iframe, frame, frameset, object, embed, applet, param, noscript, template, svg, math, head, title, meta, link, base, xml, input, select, option, optgroup, textarea, button, img, picture, source, audio, video, track, canvas, map, area, caption, col, colgroup, and comments.
- Any other tag (a, span, font, o:p, code ...) is removed and its text kept; every other attribute is removed.
- The output is written by the cleaner, never taken from HtmlAgilityPack, and the text uses only `&amp;`, `&lt;`, `&gt;` and `&nbsp;` as entities. Nesting deeper than 200 levels keeps the text only. A text it cannot read is returned as encoded plain text. Cleaning the output again gives the same text.

### Output

Text from the database or from a user is encoded on output with `HttpUtility.HtmlEncode` (grid templates, literals in encode mode, report and Followup status texts), or set with `InnerText`. The message boxes of the pages set `spanErrLogin.InnerHtml`, so a message that holds user text must be encoded first; System Settings does this (`HttpUtility.HtmlEncode(message)`), the sign-in page and ChangePassword set fixed texts. The sign-in page shows the `status` query value only through two fixed codes. The Notice page still shows an exception message in "The notice could not be sent: [message]" (HTML-encoded; Database/README.md, Known items).

### Dynamic SQL and SQL text in the code

- Stored procedures: in the catalog export of 2026-11-28 the only dynamic SQL is two calls of `EXEC sp_executesql @Sql` in spr_sys_ResetDatabase (lines 132 and 363 of its text), which reset identity counters from a list of table names inside the procedure; no parameter reaches the string. There is no `EXEC(` with a string and no `EXEC @variable` in a spr_ or fn_ module. See chapter 04, "Dynamic SQL in the stored procedures". This replaces the older lead that found none.
- Reports: since step 54 (UD1c) no report query is built in `ReportsMgr`; the report procedures take parameters (chapter 04, "Report queries built in the code").
- Text queries still run through `CommonDB.GetDataTableFromQuery` (a Grep of the code): `SELECT DB_NAME()` (UtilitiesDB), and the constant queries of AgendaDB, MinutesDB and UserDB that read sys.parameters (chapter 04 names them); none takes user input.
- Database backup (BMMSBAL/Sql_Backup_Mgr.cs): the one `BACKUP DATABASE` statement is built in C#; the database name comes from the connection and is bracket-escaped (`]` doubled), and the path is a SQL parameter (`@path`). The path is built by the Backup Database page from a fixed folder and a generated file name.

## Uploads

Every upload goes to a folder under the site. Names are made by `BMMSBAL/SafeFileName.cs` (step N1): only the file name is kept (no folder); letters of any script with their marks, digits, space, dot, hyphen, underscore and round brackets are kept, other white space becomes one space and every other character becomes `_`; repeated dots become one; at most 100 characters with the extension kept; an empty name becomes `file`; a Windows reserved name (CON, PRN, AUX, NUL, COM1 to COM9, LPT1 to LPT9) gets `_` in front. `IsPlainName` (step N2) tests a stored name again where it is read (no folder, no character Windows refuses in a file name, at most 255 characters). `MakeUnique` adds " (2)" and so on when the name exists.

| Upload | Where it is saved | How the name is made | What is checked |
|---|---|---|---|
| Agenda attachment (Master/Agenda.aspx.cs, btnAddFile_Click) | Files/AgendaAttach | `Attach-[Agenda No]-` followed by the cleaned name, made unique | The extension of the made name is .pdf (case ignored); nothing else (not the content). Refused text: "Attachment upload suppport pdf files only." Rich text over the limit refuses the post |
| Agenda text file (btnAddAgentaText_Click) | Files/AgendaText | `[Agenda No]-` followed by the cleaned name, made unique | The same: extension .pdf only. Refused text: "Agenda text upload suppport pdf files only." |
| Member photo (Master/Member.aspx.cs) | Files/MemberPhoto | A name made from the member code (easy to guess) | No check of type or size; the file is saved under the .jpg name whatever it holds |
| Member CV (resume) | Files/MemberResume | A name made from the member code (easy to guess) | No check of type or size |
| Send Mail attachment (Report/SendMail.aspx.cs) | Files/Temp | `[a new GUID, 32 hex digits]_` followed by the cleaned name; one attachment per mail, a new file replaces the earlier one | Empty or not received: refused. No type check. Files in Temp older than 24 hours are removed by the page when someone attaches a file |
| Organisation logo (Master/SystemSettings.aspx.cs, OrganisationDetails.cs) | Files/Branding/report-logo.png (a fixed name) | The file name and the type the browser sends are ignored; only the bytes are used | Admin only. At most 500 KB; must decode completely as PNG, JPEG or GIF with a sound file structure and be at most 1000 x 300 pixels; it is re-drawn and saved as PNG. The upload is recorded in the database first (spr_RecordOrganisationLogo) |

Uploads over the ASP.NET default of 4 MB (Web.config sets no `maxRequestLength`) are refused before the page runs and show the safe error page.

Files served by the web server:

- Web.config hides three whole path segments from browsers (`requestFiltering/hiddenSegments`): `PDF`, `SqlBackup` and `Log`. A URL with one of them gets 404. These hold generated PDFs, database backups and error logs. `App_Data` (the page access log) is never served by ASP.NET.
- Files/AgendaAttach, Files/AgendaText, Files/MemberPhoto, Files/MemberResume and Files/Temp are not hidden: a file there can be fetched by its address without signing in (the pages link to them directly, for example `../Files/AgendaAttach/[file name]`). The same holds for Files/Branding/report-logo.png, which the HTML reports show as an image. A login-checked download page (the item of step 27; move `~/Files/Temp` to App_Data and add Temp to the hidden segments) is not built (Database/README.md, Known items).
- What an installer can do now: treat these folders as readable by anyone who knows or guesses a file name; restrict access to Files/MemberPhoto and Files/MemberResume first (their names are easy to guess), then to the other folders, at the web server, or keep the site off the open internet, until that step exists; keep nothing confidential in the agenda attachments, agenda texts, photos, CVs or Send Mail attachments that must not be read without signing in. Backups are written to Files/SqlBackup (hidden), inside the site folder.

## Audit trail

Four audit tables, the change log of step 56 and three history tables. Which columns each has is in the catalog (columns.txt); who writes each is in chapter 04, "The audit tables" and "History tables". None has a purge procedure; Reset Database clears the audit tables (and the log) and keeps one row of its own.

| Table | What it records | Written by | Read by |
|---|---|---|---|
| Audit_Trial_Login | One sign-in: Login_DateTime, Logout_DateTime, Login_Status (O open, C closed), User_IP_Address, Server_Url, Login_Name | spr_RecordLoginByUserId at sign-in; spr_AddEditAuditTrialLogin at Logout and Session_End (closes every open row of the user, in every window; a session ended by the session check also shows as a normal sign-out, with the reason only in the page access log) | No page or procedure shows it |
| Audit_Trail_Master | One field change: Audit_Type, Audit_Table, Key_Field, Key_Value, Field_Name, Old_Value, New_Value, Update_By, Update_On | The agenda save and decision procedures, spr_UpdateMinutes (a due date change), the settings procedures, the logo record procedure and Reset Database (chapter 04, "The audit tables") | Report/AuditTrail.aspx (Admin only) through spr_GetAuditTrailMasterByUserId, by user and date range; the last change of a setting |
| Audit_Trail_SendMail | A mail sent: Mail_To, subject, body, attachment path, time, Mail_Send_By | spr_SaveSendMail, called from Mail_Mgr.SendWebEmail after a mail is sent (every mail type that uses it) | No page shows it. The attachment column holds the full server path of the file |
| Audit_Trail_SqlBackup | One database backup: file name, user, time, IP address, server URL | spr_AddEditAuditTrailSqlBackup from Backup Database | Master/BackupDatabase.aspx through spr_GetAuditTrailSqlBackup |
| Governance_Change_Log | One change of users, departments or settings: ChangedOn, EffectiveOn, ChangedBy (key to Users), ChangeType, user and department as they were, SettingCode, old and new values, Source | Only the seven procedures that change users, departments and settings, inside their transaction, through spr_WriteGovernanceChange and spr_WriteGovernanceUserChanges. INSERT, UPDATE and DELETE on the table are denied to public, and EXECUTE on the two writing procedures too (step 56), so the application login cannot write it directly | spr_GetGovernanceChangeLog and the Governance Matrix (Admin and Controller); a user who is ChangedBy of a row cannot be deleted |
| User_Role and User_Department | One role or department of a user for a period (EffectiveFrom, EffectiveTo, CreatedBy, ClosedBy, CloseReason C, D or R) | spr_AddEditUser, spr_SetUserStatusByUserId, spr_DeleteUserByUserId and Reset Database | The session check (department set), the Manager and approver functions, and the Governance Matrix for past dates |
| Action_Item_Status_History | One Confirm or Reopen of a followup: Action, Reason (up to 1000 characters, 500 by the procedure), ActedBy, ActedOn | spr_SaveFollowupConfirmed and spr_ReopenFollowup; no procedure updates or deletes the rows | spr_GetFollowupList, fn_FollowupStatusLatest (the Followup reports and the Dashboard's scope function) |

Gaps recorded in Database/README.md, Known items: Agenda comment changes, the Followup Action Text save and Confirm and Reopen write nothing to Audit_Trail_Master; the Audit Trail page does not show Audit_Trial_Login, SendMail or Action_Item_Status_History.

## Azure SQL Database

The firewall of the Azure server (client IP rules, error 40615) is in chapter 03, "Azure SQL firewall" (under "Redeploying the Azure copy from a local copy").

Local copies (BMMS_Test, BMMS_Quality; Database/README.md, step GM1a, C5): the application's database user (bmms_app; bmms_site on BMMS_Quality) has `db_datareader`, `db_datawriter` and EXECUTE on schema dbo. The step 56 script (Database/BMMS-Fix-GovernanceLog-Step56.sql, lines 227, 1044 and 1045) denies INSERT, UPDATE and DELETE on dbo.Governance_Change_Log, and EXECUTE on spr_WriteGovernanceChange and spr_WriteGovernanceUserChanges, to `public`, not to bmms_app by name; the procedures that change users, departments and settings write the log through ownership chaining (all objects are dbo). Chapter 02 names `db_backupoperator` for bmms_app in BMMS_Quality as well.

Azure copy (the owner's check of 2026-11-28 on the Azure server, database BMMS_Test: a read-only query of sys.database_principals, sys.database_role_members and sys.database_permissions):

- bmms_app is a SQL user (authentication type INSTANCE) with default schema dbo.
- Roles: `db_backupoperator`, `db_datareader`, `db_datawriter`. db_backupoperator has no effect on Azure SQL Database, where BACKUP is not allowed (the Backup Database page cannot work there; Database/README.md, Known items, step AZ1).
- Permissions: GRANT CONNECT on the database; GRANT EXECUTE on schema dbo; GRANT EXECUTE on dbo.spr_GetDashboardApprovals (redundant with the schema grant; a tidy-up item only).
- No permission row with bmms_app as grantee is a DENY.

The step 56 DENY rows are present on the Azure copy (the owner's check of 2026-11-28, a read-only query of public's DENY rows on the Azure server, database BMMS_Test): 5 rows, all class OBJECT_OR_COLUMN, grantee public: DENY DELETE, INSERT and UPDATE on dbo.Governance_Change_Log, and DENY EXECUTE on dbo.spr_WriteGovernanceChange and dbo.spr_WriteGovernanceUserChanges.

## Recommended hardening

The open items of "Known items for later steps" in Database/README.md, each one line with its step, and one item that is the owner's decision of 2026-11-28 (WF2c2) and not yet in Known items (marked as such under "Azure copy"). Items marked fixed or closed in Known items are left out. This section gives no other advice.

### Before the fresh install (the "pre-install security pass" items)

- Step AZ1: iTextSharp 4.0.2 and AjaxControlToolkit 1.0.20229 stay at their old versions; review them (known vulnerabilities, upgrade path) before the fresh install.
- Step GM1a (C7): Agenda finalisation, Minutes update, Minutes finalisation and Minutes confirmation are guarded only by PageAccess.xml and the menu: spr_AgendaFinalizeByMeetingId, spr_UpdateMinutes, spr_MinutesFinalizeByMeetingId and spr_MinutesConfirmByMeetingId take no acting user (or do not check its role), so nothing in the database refuses another role. Add the acting-user and Controller checks in the procedures.
- Step GM1a (gate B): spr_sys_ResetDatabase fails as bmms_app at its first DBCC CHECKIDENT (error 2557; DBCC CHECKIDENT needs table ownership or db_owner or db_ddladmin, which bmms_app has for no table; proven on BMMS_Test on 2026-11-25). Fix to decide: module signing (certificate), or run the reset only from the install script as dbo. Do not grant db_ddladmin or db_owner to bmms_app.
- Step RA1d: PageAccessModule checks only paths ending in .aspx. The project has no .ashx, .asmx or .svc today; a future handler type must be added to the check (login, role and session checks; a handler without a session counts as not signed in) in the same step that adds it.
- Step RA1d: the session id is not renewed at sign-in (Default.aspx keeps the session id the browser had before signing in).

### Azure copy (owner's decision of 2026-11-28, WF2c2; not yet in Known items)

- Review the roles of bmms_app before the demo goes public: on the Azure copy it has db_backupoperator, which has no effect there, and an object grant on spr_GetDashboardApprovals that the schema grant makes redundant.

### Sign-in and session

- Step WF3a1 (owner, 2026-11-11): the sign-in page limits the password to 12 characters (PasswordMaxLength); twelve is short for today's guidance, and raising it touches the sign-in page, the two change-password pages, Reset Password and User Master.
- Step RA1d: the expired cookie of an ended session is HttpOnly but not Secure, as the session cookie itself (no requireSSL on this site).

### Page access

- Step RA1b (review): the other pages that open ViewReport.aspx (Agenda Approval, Notice, Sitting Fees) neither set nor clear Session["ViewReportKind"]; after a role change to Management during a session a kind left by an earlier Minutes or Followup report could let ViewReport show such a report (`?pdf=1` is refused to Management anyway). Clear the kind wherever Session["ViewReport"] or Session["ReportPdf"] is set.

### Procedures and acting user

- Step RA1a (Low): the Designation, Subject Type and Decision Type procedures take no acting user and check no role; only PageAccess.xml and the page keep the Controller out.
- Step GM1a review and step UD1a review: spr_DeleteDepartmentByDeptId takes no acting user, writes no log row and runs its checks and the delete without a transaction (a mapping added at the same moment gives error 547 and the error page).
- Step IU1 review (security Low): spr_AddEditCommittee does no acting-user check and returns no Result and Reason (G6).
- Step IU1 review (security Low): spr_GetResetPasswordMail lets any active role read its own address and status (acting user = target); the page is for the Admin only. Add an active-Admin check if the procedure should refuse it.
- Step IU1 review (security Low): the Meeting and Committee Bcc is read again after the save, not from the alert rows of the event; a status or role change in the same moment could make the two differ by that user.
- Step UD1c review (security Low): spr_GetAgendaByMeetingIdDeptId does not check that @UserId is an active account other than the system account.
- Step UD1b review (security Low, race): spr_AddEditAgenda reads the department's Managers without a lock; a deactivation of the last Manager at the same moment can leave a new item at AC with nobody to approve it.
- Step UD1a review (Low): on Update, a department already mapped but inactive can be made the home department through a direct call of spr_AddEditUser; two Managers leaving one department at the same moment can deadlock in spr_AddEditUser (one save is rolled back).
- Step RA1b review (Low): the step 41 procedures test AccountStatus = 1 but not IsSystem = 0; the protected system account has the Admin role and gets Reason 4.
- Step UN6c1 review (security Low): the four alert and header procedures and the three action item procedures accept every active account as acting user and do not look at IsSystem; the system account is refused by its Admin role (Reason 4 or an empty list).
- Step UN6c1 and review: spr_UpdateAlertByAlertUserId has no owner check and no caller (with spr_GetAlertByUserId and spr_GetActionItemByUserId, to drop in a later database step).
- Step UN6c1 review (security Low): spr_OpenDashboardActionItem checks the scope and then writes the person's own read row in a second statement; an item that leaves the scope in between still gets that read row.
- Step UN6c2a review (security Low): spr_GetAgendaApprovalState tells any active user, for any agenda item id, whether the meeting's agenda is open and whether its date has passed (two yes/no flags); the Agenda Alert panel chooses its fields and the action word from the role in the session (a role changed during a session gives Reason 14, not a bypass).
- Step UN6c2b review (security Low): spr_GetDashboardMeetings and spr_GetDashboardActionItems have no Reason 12 of their own.
- Step M4 (Agenda Entry): spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController do not refuse a new item after the meeting date; only the page checks.
- Step PW1 (known item): the four user-list procedures (spr_GetUser, spr_GetActiveUserList, spr_GetMgrControllerByDeptId, spr_GetUserListForUserPage) still return the Password column; the hashes stay on the server.

### Input and uploads

- Step 27 (known item): a login-checked download page for agenda attachments and agenda text, member photos and CVs, and Send Mail attachments (move `~/Files/Temp` to App_Data, then add Temp to the hidden segments); until then these files can be fetched by URL without signing in.
- Agenda uploads (known items): only the extension .pdf is checked on the server, any content with that name is stored; files of items never saved, files unticked later and replaced agenda texts stay in Files/AgendaAttach and Files/AgendaText (nothing removes them); the Agenda No goes into the saved file name without cleaning (a committee code with a backslash, a slash or `..` would change the folder); two uploads of the same name at the same moment can overwrite each other.
- Member (known item): the photo and resume paths (hidden text boxes) are stored as posted; the photo and resume uploads have no type check.
- Step CC1 (before the fresh install): spr_SetOrganisationSettings and spr_AddEditMemberType accept the C1 characters 129, 141, 143, 144 and 157; decide whether to refuse 128 to 159 or these five.
- Known item: the Notice page shows "The notice could not be sent: [message]" with the exception text (HTML-encoded); replace it with a fixed text.
- Known item (optional): ViewState encryption on the six pages whose ViewState is still readable (DashBoard, Attendance, Minutes Confirmation, Minutes Finalization, Attendance Details and Notice); none carries a password.
- Known item: database backups should be written outside the web root (`~/Files/SqlBackup` is hidden but inside the site folder).

### Mail

- Known item (step 30): Mail_Mgr never sets EnableSsl, so there is no TLS or STARTTLS; a provider that requires an encrypted connection refuses every mail.
- Step IU1 owner tests (2026-11-25): an Admin who shares an e-mail address with other users receives their mails; before the fresh install check that every user has an address of his own.

### Audit and logs

- Step RA1d: the Audit Trail shows a session ended by the check as a normal sign-out (status C and the logout time) with no reason; the reason is only in PageAccessLog.txt.
- Step RA1d: Session_End closes every open login row of the user, also those of another browser in which the user is still signed in; a second login of the same user closes the first row without a logout time (known item, step UN2).
- Step FU1 and step UN6d (known items): the Confirm and Reopen rows of Action_Item_Status_History are the record of who did it, but no Audit_Trail_Master row is written; the Action Text save and the Submit set no UpdatedOn or UpdatedBy on Action_Item and write no audit row.
- Known item (step UN4): Agenda Entry comment changes are not in the Audit Trail.
- Known item: the Send Mail audit row stores the full server path of the attachment.
- Step GM1a review (security and UX Low): the change log range has no upper limit and no paging; a range of years returns and exports every row in one request (Admin and Controller only).
- Step DA1 (known item): the doc-writer guard has no read rule for protected files (connectionStrings.config, files under Log and App_Data), unlike the doc-auditor's.

### Scripts and rollbacks

- Step HK1 (O2, open): BMMS.csproj lists connectionStrings.config as Content, so a Publish copies the Base Laptop's file, with its password, to App Service; keep it out of Publish and document the portal connection string as the only source on Azure.
- Step AZ2 (pre-install guard audit): BMMS-Fix-OrganisationSettings-Step19.sql, BMMS-Fix-MemberTypes-Step21.sql, BMMS-Fix-RoleAccess-Step40.sql and BMMS-Rollback-RoleAccess-Step40.sql still contain master.dbo.spt_values and do not stop while step 57 is installed; add guards before the fresh install.
- Step AZ2 (security Low): BMMS-Fix-DatabaseLocal-Step57.sql prints "Step 57 installed" also when the count of references to another database or server is above 0.
- Step AZ2: the Azure copy of BMMS_Test has an undocumented hand change of 2026-11-18 (view dbo.vw_spt_values_P, not in git); the redeploy replaces it; check afterwards that the view is gone.
- Step MR1 (pre-install install-all script): audit every Fix script's re-run guard; a Fix script that accepts "already this step's text" by marker can silently replace the text of a later step.
- Step GM1a review and step IU1 review (security Low): the Rollback scripts of steps 54, 55 and 56 check only that the step is installed and compare their texts at the end; a later change to one of the texts would be overwritten. A pre-check per text could refuse instead.
- Step GM1a review (security Low): the page's default As-on date is the web server's date and the "today" of the procedures the database server's; across midnight on two machines the default could be refused (Reason 33) for a moment.
- Step RA1d review (security Low, check 44): BMMS-Test-SystemAccount-Stage3.sql check 44 also passes when spr_GetAlertMailId returns an empty ACA list for any reason; changing the check needs the owner's word.
- Step WF3a1 security review (Low): Update-Baseline.ps1's scan does not see USE inside dynamic SQL or a three-part name (the wall is that bmms_tester can open no other database); linked servers are not checked; new error-log lines of the site copy are copied to Tests/_results, so confirm that the error log never carries connection details; the restore sets SINGLE_USER from a connection on master, so another connection can take the single slot; a pack is Node code with the owner's rights and must be reviewed as code.
