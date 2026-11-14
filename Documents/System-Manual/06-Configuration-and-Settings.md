# Configuration and Settings

- Title: Configuration and Settings
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: access-ra1a
- Last updated by: RA1a (step 40), based on ea268e5
- Status: Draft
- Verified against: none yet (leads from the old Architecture notes added in WF2b1); for
  "Page access policy" BMMS/XML/PageAccess.xml and BMMS/PageAccessModule.cs (step RA1a)
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

## System Settings page

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: the App_Setting rows are edited on the System Settings page]]

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
