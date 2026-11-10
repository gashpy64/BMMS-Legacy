# Security

- Title: Security
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: RA1b (step 41)
- Last updated by: RA1b (step 41), based on 1d1bbbe
- Status: Draft
- Verified against: for step RA1b (step 41): BMMS/PageAccessModule.cs (HasRole, RefuseRequest,
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
- Security lead (not fixed; owner decision, a later step RA1d closes it): only these nine pages check the role
  in the database (since step RA1b also Reports.aspx, Followup.aspx and ViewReport.aspx for the roles named above). Every other page follows the role stored in the session until sign-out, so after a role
  change an open session keeps the old role on those pages, and the menu keeps the old links until the next
  sign-in. [[CONFIRM: the step that closes this (named RA1d by the owner); its date and scope are not in the repository]]

## Role and acting-user checks in procedures

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: open known item, see "Known database limitations" in chapter 04: 24 procedures use THROW on BMMS_Test although the house rule for compatibility level 100 says no THROW; it runs because the server is SQL Server 17; the owner has to decide the minimum SQL Server version]]
[[CONFIRM: lead from old Architecture notes: the stored procedures decide which changes a role may make; dbo.fn_UserChangeRefusal (step 13 onwards) says who may change which user]]
[[CONFIRM: lead from old Architecture notes: nobody can delete, deactivate or change the role of their own account; the last active ordinary Admin and the last active Controller cannot be deleted, deactivated or given another role (checked under a lock in the same transaction)]]
Since step 40 (RA1a), dbo.fn_UserChangeRefusal has no branch for the Controller. An Admin may change any user (the rules below still apply); every other role, the Controller included, may only Edit and ResetPassword its own account, and Create or any action on another account is refused with Reason 4 ("You are not allowed to [action]. Only an Admin can change other users' accounts."). Until step 40 a Controller could change Manager, User, Management and MD Secretariat accounts. spr_AddEditMemberType and spr_DeleteMemberTypeByMemberTypeId refuse anyone but an active Admin with Reason 4 ("Only an Admin can change member types."; Reason 8 for a missing or inactive acting user). The Reason codes and the procedures are in chapter 04.
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
