# Configuration and Settings

- Title: Configuration and Settings
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: user-ud1a
- Last updated by: WF2b1, based on 3dd0eec
- Status: Draft
- Verified against: none yet (leads from the old Architecture notes added in WF2b1)
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
