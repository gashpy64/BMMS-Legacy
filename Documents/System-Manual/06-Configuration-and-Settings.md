# Configuration and Settings

- Title: Configuration and Settings
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: GM1a (step 56: the setting GovernanceLogFrom); UD1b (step 53: the setting DeptNoManagerAction and the System Settings card text); access-ra1a
- Commit: 32c619d
- Last updated by: GM1a, based on 32c619d (the paragraph on GovernanceLogFrom; the rest of the chapter was last updated by UD1b, based on db1d641)
- Status: Draft
- Verified against: for GM1a: Database/BMMS-Fix-GovernanceLog-Step56.sql (the setting insert and the comment of fn_GovernanceHistoryStart), Database/README.md (section Step GM1a); none yet (leads from the old Architecture notes added in WF2b1); for
  "Page access policy" BMMS/XML/PageAccess.xml and BMMS/PageAccessModule.cs (step RA1a); for UD1b:
  BMMS/Master/SystemSettings.aspx and .aspx.cs (the card, the messages), Database/BMMS-Fix-DepartmentApprovers-Step53.sql
  (fn_AgendaRoute, spr_AddEditAgenda comments), BMMSBAL/MeetingMgr.cs (Reason 29 text)
- To confirm: chapter not written yet (WF2b2); leads from the old Architecture notes to verify

## Configuration files

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: Web.config holds the ASP.NET settings and reads connectionStrings from connectionStrings.config]]
[[CONFIRM: lead from old Architecture notes: connectionStrings.config is not tracked; copy connectionStrings.config.example]]
[[CONFIRM: lead from old Architecture notes: XML/PageSettings.xml and XML/ReportSettings.xml hold page and report settings]]

## Application settings (AppSettings.xml)

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: XML/AppSettings.xml holds the page title, footer text, common messages, and the login-id and password lengths]]

## Database settings rows

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: the SMTP settings are stored in the database and edited on the SMTP Server Config page]]
[[CONFIRM: lead from old Architecture notes: the App_Setting table holds the system settings (added in step 16)]]

Setting DeptNoManagerAction (App_Setting row added by step 39; read since step 53, UD1b). Values `refuse` (the default,
also used when the row is missing or holds another value) and `controller`. It is read by fn_AgendaRoute when a User saves
a new agenda item whose department has no active Manager (an active Manager of the department other than the creator;
the Reporting Person is an active Controller: the item goes to the Controllers whatever the setting says):

- `refuse`: the item is not saved; Reason 29, "Not saved: the department [department name] has no active Manager. Ask the Admin
  to nominate a Manager for the department."
- `controller`: the item is saved at AMA (Agenda.RouteNote 'N'), the Controllers get the alert, and the save message and the
  "has been Created" mail add "Sent to the Controller: the department had no active Manager."

Items entered by a Manager or by the Controller are not affected. A change of the value is written to Audit_Trail_Master
(chapter 04, "Settings rows").

Setting GovernanceLogFrom (App_Setting row inserted by step 56, GM1a, when missing). A date and time as text
(`CONVERT(..., 126)`), the install time of step 56. fn_GovernanceHistoryStart reads it: the Governance Matrix and the change
log record the Reporting Person and the department status from the later of this value and the last Reset Database (Reset
Database clears the log and does not touch App_Setting). No page changes it. It is not a System Settings card. Before that date the
Governance Matrix says "Reporting Person not recorded before [date]: the route to the Controller is not shown for earlier dates." and
"Department status not recorded before [date]: today's status is shown." (chapter 04, "Step 56 (GM1a)" and "Settings rows").
A change of DeptNoManagerAction or AgendaControllerBypass is also written to the governance change log (change type ST) since step 56.

## System Settings page

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: the App_Setting rows are edited on the System Settings page]]

The card "Department without an active Manager" (BMMS/Master/SystemSettings.aspx; shown only when the setting row exists) offers
"A new agenda item is" with the choices "Refused (default)" and "Sent to the Controller", and the help text "Used when a new
agenda item's department has no active Manager. A change is written to the audit trail." (before step 53: "Stored now, used from
a later step: today agenda items are routed as before."). Only an Admin may save it. The two confirmation messages after Save
(BMMS/Master/SystemSettings.aspx.cs, btnSaveDeptRule_Click) are "Saved: when a department has no active Manager, a new agenda
item will be sent to the Controller. The setting is now in use." and "Saved: when a department has no active Manager, a new agenda item will be
refused. The setting is now in use." (until step 53 they ended "This is stored now and used from a later step.").

## Page access policy

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: XML/PageAccess.xml lists the roles allowed per page and the mode (LogOnly or Enforce)]]

What BMMS/XML/PageAccess.xml shows (read for step RA1a). The root element `pageAccess` has the
attribute `mode`; the file in the repository has `Enforce` (`LogOnly` blocks nothing and logs what
would be denied). `<public>` lists Default.aspx, Logout.aspx and Error/ErrorPage.aspx. `<pages>` lists
each other page with `roles`: `*` (any logged-in user) or role codes separated by commas (admin,
controller, manager, user, mgmt, md_sect). A page that is not listed is not allowed. The file is read by
BMMS.Security.PageAccessModule, cached and reloaded when it changes (chapter 05, "PageAccessModule").

Since step RA1a these pages are `admin` only (they were `admin,controller` or, for Audit Trail,
`controller`): Master/Department.aspx, Master/Designation.aspx, Master/MemberType.aspx,
Master/SubjectType.aspx, Master/DecisionType.aspx, Master/User.aspx, Master/ResetPassword.aspx,
Master/BackupDatabase.aspx and Report/AuditTrail.aspx. Master/ResetDatabase.aspx,
Master/SMTPServerConfig.aspx and Master/SystemSettings.aspx stay `admin`. The Controller keeps
Master/Member.aspx, Committee.aspx, CommitteeMember.aspx, Meeting.aspx, MeetingMember.aspx and
Attendance.aspx (`admin,controller`).

These nine pages are also protected by a check inside the page (`RequireRole`, chapter 05), which
reads the role from the database, so they stay closed to other roles in `LogOnly` mode too. When you
change the roles of a page in this file, change the menu (BMMS/UserControl/MenuUserControl.ascx) in
step with it.
