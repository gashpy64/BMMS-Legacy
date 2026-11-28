# Configuration and Settings

- Title: Configuration and Settings
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: WF2c2 (the whole chapter written: configuration files, AppSettings.xml, PageSettings.xml and ReportSettings.xml, the database settings rows, the System Settings page, the Page access policy completed; closes DA-G-023); GM1a (step 56: the setting GovernanceLogFrom); UD1b (step 53: the setting DeptNoManagerAction and the System Settings card text); access-ra1a
- Commit: f8d57ed
- Last updated by: WF2c2, based on f8d57ed (the whole chapter; the paragraphs on DeptNoManagerAction, GovernanceLogFrom, the "Department without an active Manager" card and the page access text of RA1a are kept as they were); GM1a, based on 32c619d (the paragraph on GovernanceLogFrom); UD1b, based on db1d641
- Status: Draft
- Verified against: for WF2c2: BMMS/Web.config, BMMS/XML/AppSettings.xml, PageSettings.xml, ReportSettings.xml and PageAccess.xml (read in full or in the part named), BMMSBAL/Common.cs (GetAppSetting, GetReportSettings, InitSetup, MondifyAppSettings), BMMSBAL/RichTextLimits.cs, BMMSBAL/OrganisationDetails.cs (the settings, the logo, the logo messages), BMMS/PageAccessModule.cs (read in full), BMMS/Master/SystemSettings.aspx and .aspx.cs (read in full), the GetAppSetting callers found by search in BMMS, BMMSBAL and BMMSDAL, BMMS/Default.aspx.cs, ChangePasswordFirst.aspx.cs, Master/ChangePassword.aspx.cs and Master/User.aspx.cs (the length settings), Database/BMMS-Fix-MeetingLocks-Step16.sql, BMMS-Fix-OrganisationSettings-Step19.sql, BMMS-Fix-WorkflowOrder-Step23.sql, BMMS-Fix-UpdateMail-Step37.sql, BMMS-Fix-UserHistory-Step39.sql, BMMS-Fix-GovernanceLog-Step56.sql and BMMS-Fix-DatabaseLocal-Step57.sql (the setting rows and the two settings procedures), the BMMS_Test catalog export catalog-20261128-3172059 (modules spr_SetAppSetting, spr_SetDepartmentManagerRule, fn_AgendaRoute, fn_AgendaChangeRefusal, fn_WorkflowState, fn_SettingOn, spr_GetGovernanceSettings; columns.txt and parameters.txt for Users.LoginName and Password), chapters 02, 03, 04, 05 and 07 of this manual (the links); earlier: for GM1a: Database/BMMS-Fix-GovernanceLog-Step56.sql (the setting insert and the comment of fn_GovernanceHistoryStart), Database/README.md (section Step GM1a); for "Page access policy" BMMS/XML/PageAccess.xml and BMMS/PageAccessModule.cs (step RA1a); for UD1b: BMMS/Master/SystemSettings.aspx and .aspx.cs (the card, the messages), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_AgendaRoute, spr_AddEditAgenda comments), BMMSBAL/MeetingMgr.cs (Reason 29 text)
- To confirm: which of the RichTextMaxChars and RichTextMaxTotalChars values a live site should use (the repository holds the defaults; the companion settings named in the Web.config comment are in Database/README.md, step A2a, not re-read); whether the installed site keeps compilation debug="true" (see chapter 03, "Web application install", point 4); whether the installed site runs PageAccess.xml in Enforce mode (the repository file does)

## Configuration files

Everything an installer touches is in `BMMS/Web.config`, in `BMMS/connectionStrings.config` (not tracked) and in the four files of `BMMS/XML`. The sections below say what each holds. How Web.config reaches a server is in chapter 03, "Web application install", point 4: the runtime Web.config of a server is not overwritten by a deployment, so a line a step adds is added by hand.

### BMMS/Web.config

Only the settings an installer or a developer may need to touch are listed. The assembly, handler and module lines for ASP.NET AJAX are the framework's and are not described.

| Setting | Value in the repository | What it does |
|---|---|---|
| `appSettings` key `RichTextMaxChars` | 200000 | Largest size of one rich-text editor, in characters of the editor's HTML. A missing, empty or not-a-positive-whole-number value gives the default 200000 (BMMSBAL/RichTextLimits.cs). Used by the editor control, its script and the server check; the text shown on refusal is "The text is too long. Shorten it or attach the document as a file." |
| `appSettings` key `RichTextMaxTotalChars` | 600000 | The same limit for all editors of one page together; default 600000. The comment in Web.config says: raise `httpRuntime` maxRequestLength, the IIS maxAllowedContentLength and the UpdatePanel timeout together with these two values (Database/README.md, step A2a) |
| `connectionStrings configSource="connectionStrings.config"` | the file next to Web.config | The `connectionStrings` section is read from that file. The data layer reads the connection named `ConnectionString` (BMMSDAL/ConnectDB.cs) |
| `authentication mode="Windows"` | Windows | The setting is the ASP.NET default of the project. BMMS signs people in on its own page (Default.aspx) with a session, not with Windows or forms authentication; PageAccessModule says in its code that there is no forms cookie to clear |
| `sessionState` | `timeout="10"`, `mode="InProc"` | A session ends after 10 minutes without a request and is held in the memory of the application, so an application pool recycle or a restart signs every user out (chapter 03, point 5). The module reads this section only for the session cookie name (default ASP.NET_SessionId) |
| `httpRuntime` | `requestValidationMode="2.0"`, `enableVersionHeader="false"` | Request validation works as in ASP.NET 2.0 (at page level); the ASP.NET version header is not sent |
| `compilation debug` | `true` | Debug symbols are compiled into the pages. The comment in Web.config says to set it to true only during development, because it affects performance. Whether a live site keeps it is open (see To confirm) |
| `system.webServer/security/requestFiltering/hiddenSegments` | `PDF`, `SqlBackup`, `Log` | Any URL that has one of these as a whole path segment gets 404 (step 26): generated PDFs, database backups and error logs are never served to a browser |
| `system.webServer/staticContent` | `remove` then `mimeMap` for `.woff2`, type `font/woff2` | Step AZ1: Azure App Service has no MIME type for `.woff2` and answered 404 for the fonts; the remove first avoids a duplicate entry where IIS already knows it |
| `system.webServer/httpProtocol/customHeaders` | `remove` of `X-Powered-By` | The header is not sent (step E2c) |
| `system.web/globalization` | request and response encoding utf-8 | Step U1b |
| `httpModules` and `system.webServer/modules` | `PageAccess` = BMMS.Security.PageAccessModule | Registers the page access check; see "Page access policy" below |

`BMMS/connectionStrings.config` is not tracked by git. How it is made, the placeholders for its parts and the Local/Azure switch (`Tools/Switch-Db.ps1`, step HK1) are in chapter 02, "Connection settings (placeholders only)". On Azure App Service the connection string set in the portal overrides the file; that is chapter 03, "Web application install", point 3. Neither is repeated here.

### The four files of BMMS/XML

| File | One line |
|---|---|
| AppSettings.xml | Text and number settings read by `Common.GetAppSetting` (page title, common messages, login and password lengths): see "Application settings (AppSettings.xml)" |
| PageSettings.xml | The tab title and address of each page, read by `Common.InitSetup`: see "Page and report settings" |
| ReportSettings.xml | The width of the report pop-ups, read by `Common.GetReportSettings`: see "Page and report settings" |
| PageAccess.xml | The roles allowed per page and the mode (`LogOnly` or `Enforce`), read by PageAccessModule: see "Page access policy" |

The four files are part of the site and are deployed with it (chapter 03, "Web application install"). `AppSettings.xml`, `PageSettings.xml` and `ReportSettings.xml` are read from disk at each call (no cache: each call loads the file); `PageAccess.xml` is cached and reloaded when it changes.

## Application settings (AppSettings.xml)

The root element is `appSettings`; each `add` has a `key` and a `value`. `Common.GetAppSetting(key)` loads the file, returns the value of the first element with that key, and returns an empty string when the key is missing. This is not the `appSettings` section of Web.config and not the App_Setting table (chapter 04, "Settings rows"). `Common.MondifyAppSettings` can write a value back to the file; a search of the C#, ASPX and master files finds no call of it.

| Key | Value in the repository | Where the code reads it |
|---|---|---|
| PageTitle | BMMS - Board Minutes and Meeting Software | `Common.InitSetup` (the tab title is this text followed by the page's title from PageSettings.xml); Default.aspx.cs (the login page title, this text followed by " - Login"); MasterPage/Main.Master.cs and MainNoMenu.Master.cs (the title when the session has none) |
| CommonErrMsg | The Web server may be busy or down.  Please try again later or contact your System Administrator | No caller found by search: the text is not shown by any page |
| delete_reference | You cannot delete this record, because it has references. | BMMSBAL/DepartmentMgr.cs, MeetingMgr.cs (the Meeting-in-use refusal) and UserMgr.cs; the delete handlers of Master/Agenda, Committee, CommitteeMember, DecisionType, Department, Designation, Member, MeetingMember and SubjectType |
| data.notDelete | This is master record.  So you cannot delete. | Master/Committee.aspx.cs (delete) |
| delete_msg | Record deleted successfully. | Master/Committee.aspx.cs (delete, shown in green) |
| NoRecord | No such records found | Default.aspx.cs (kept in the session key NoRecord at sign-in) |
| LoginIdMaxLength | 12 | Default.aspx.cs and Master/User.aspx.cs (the MaxLength of the Login ID box) |
| PasswordMaxLength | 12 | Default.aspx.cs, ChangePasswordFirst.aspx.cs, Master/ChangePassword.aspx.cs and Master/User.aspx.cs (the MaxLength of the password boxes). Master/ResetPassword.aspx.cs has the call in a comment and makes a password of 8 characters |
| PasswordMinLength | 6 | ChangePasswordFirst.aspx.cs, Master/ChangePassword.aspx.cs (a new password) and Master/User.aspx.cs (the password of a new user, on Save only) |

The three length keys:

- LoginIdMaxLength is only a limit of the box in the browser. No server code was found that compares the Login ID with it; the database column Users.LoginName holds 50 characters (catalog) and spr_AddEditUser takes 50. A Login ID longer than the box allows therefore reaches the server if the box is bypassed.
- PasswordMaxLength is only a limit of the boxes. No server code compares a password with it.
- PasswordMinLength is checked on the server, in the code-behind of the three pages. The test is `Length <= PasswordMinLength` on the trimmed password, so a password must be longer than the value (with 6 it needs 7 characters), while the message says "Password length minimum of 6 characters in length". The test is not in a stored procedure.

The page and report keys of the older notes (footer text) are not in this file: the footer of the master pages shows the version and, for the Admin and the Controller only, the name of the connected database (`Common.FooterDatabaseName`).

## Page and report settings (PageSettings.xml, ReportSettings.xml)

**PageSettings.xml.** The root is `pageSettings`. Each `page` has a `Name` attribute and two children: `pageTitle` and `pageURL`. A page calls `Common.InitSetup(className)` at the start; when nobody is signed in the call redirects to the login page; otherwise it finds the `page` whose `Name` equals the class name and stores in the session the tab title (`PageTitle` of AppSettings.xml followed by the `pageTitle` text) and the address (`pageURL`). Pages that do not call it (see the "InitSetup" column of chapter 05, "Pages and master pages") take nothing from this file; they are still protected by the page access check. A page whose class name has no entry keeps the session values of the previous page.

**ReportSettings.xml.** The root is `repoSettings`; `add` elements with `key` and `value`, read by `Common.GetReportSettings(key)` (an empty string for a missing key). The three keys are the width, in pixels, of the report text in the pop-up and in the page text:

| Key | Value in the repository | Read by |
|---|---|---|
| MinutesReport_Width | 560 | Report/Reports.aspx.cs (the Minutes report pop-up and its text) |
| MinutesExtractReport_Width | 560 | Report/Reports.aspx.cs (the Minutes Extract report) |
| FollowupReport_Width | 560 | Report/Followup.aspx.cs (the Followup and Followup Summary reports) |

## Database settings rows

The App_Setting table (SettingCode, SettingValue, Description) holds the settings that the Admin may change, or that the procedures read. Chapter 04, "Settings rows", lists the keys from the procedure side; the table below adds, for each row, the step, the values and which page edits it. The catalog has no data, so the values come from the Fix scripts. Every row is added only when it is missing, so a re-run keeps the value of the Admin.

| Row (SettingCode) | Added by | Values | Read by | Edited on |
|---|---|---|---|---|
| AgendaControllerBypass | Step 16 (BMMS-Fix-MeetingLocks-Step16.sql) | '1' (the default, on) or '0'; with no row the procedures read '1' | fn_AgendaChangeRefusal (the agenda lock after finalisation); spr_GetGovernanceSettings and fn_SettingOn (the Governance Matrix); BMMS/Master/SystemSettings.aspx.cs | System Settings, card "Agenda" |
| OrganisationName, OrganisationShortName, OrganisationTerm, CertificateSignOff, RegisteredOfficeLabel, RegisteredOfficeLine1, RegisteredOfficeLine2, RegisteredOfficeCity, RegisteredOfficePinCode, OrganisationPhone, OrganisationFax, OrganisationEmail | Step 19 (BMMS-Fix-OrganisationSettings-Step19.sql): 12 rows, each with an empty value | Text, empty means not set; lengths 150, 100, 30 (letters and spaces), 150, 60, 100, 100, 60, 12 (digits, spaces, hyphens), 60, 60, 100 | spr_GetOrganisationSettings, read through BMMSBAL/OrganisationDetails.cs by the notices, minutes, reports, certificates and mail headers | System Settings, card "Organisation details" |
| WorkflowOrderFrom | Step 23 (BMMS-Fix-WorkflowOrder-Step23.sql) | The install time of step 23 as text (`CONVERT(..., 126)`) | fn_WorkflowState: a meeting created on or after it follows the order agenda, attendance, minutes; an older one keeps the earlier behaviour | None (no page and no procedure changes it) |
| MailSenderUserId | Step 37 (BMMS-Fix-UpdateMail-Step37.sql) | A user ID as text; pre-set to the active, non-system Controller-role user with Login ID Controller, else empty | No procedure and no C# file reads it; BMMS-Check-InstalledSteps.sql reads it to report whether it names an active Controller-role user. The mail goes out From the From Mail Id of SMTP Configuration (chapter 07) | None (set by a script; Database/README.md, step ML1). The rollback of step 37 deletes the row |
| DeptNoManagerAction | Step 39 (BMMS-Fix-UserHistory-Step39.sql); read since step 53 | 'refuse' (the default) or 'controller' | fn_AgendaRoute (a new item whose department has no active Manager); spr_GetGovernanceSettings and fn_SettingOn (the Governance Matrix); SystemSettings.aspx.cs | System Settings, card "Department without an active Manager" |
| GovernanceLogFrom | Step 56 (BMMS-Fix-GovernanceLog-Step56.sql) | The install time of step 56 as text (`CONVERT(..., 126)`) | fn_GovernanceHistoryStart | None |

Not rows of the table: OrganisationLogo is only an audit entry (the file is `Files/Branding/report-logo.png`, kept by the application); the SMTP settings are the table SMTP_Master, edited on the SMTP Configuration page (chapter 07, "Mail server settings"), not App_Setting rows. Step 57 changes procedures only and adds no row. Reset Database does not touch App_Setting, so every row survives a reset.

What every change has in common (spr_SetAppSetting, spr_SetDepartmentManagerRule, spr_SetOrganisationSettings): only an active Admin may save (the procedures refuse anyone else); a changed value writes one row to Audit_Trail_Master (Audit_Table 'App_Setting', Field_Name 'SettingValue', old and new value; saving the same value writes none; the organisation save writes one row per changed field); the procedures run in one transaction. spr_SetAppSetting accepts only AgendaControllerBypass with '0' or '1'.

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

BMMS/Master/SystemSettings.aspx and .aspx.cs, menu group Utilities, heading "System Settings". PageAccess.xml lists it for `admin` only. The save procedures refuse a user who is not an active Admin as well: the page then shows "Only an Admin can change system settings." (on the Department rule card "Not saved: only an Admin can change system settings."), and for a user missing or inactive "Your session is no longer valid. Please log in again." The page loads all four cards on the first request; a failure goes to the error page. A save shows its message in the bar above the cards (green for a success).

| Card | Fields and buttons | What a save writes | Messages |
|---|---|---|---|
| Agenda | The tick box "Controller can add, edit and delete agenda items after the agenda is finalized"; help "Applies until the minutes are finalized. Default: on." and, when a change was recorded, "Last changed by [name] on [date and time]."; Save, Cancel (Cancel goes to the Dashboard). The box shows ticked when the row is missing | AgendaControllerBypass '1' or '0'. A changed value: one Audit_Trail_Master row and one governance change log row (type ST) | "Successfully updated."; "The value is not valid." |
| Department without an active Manager | See below; shown only when the row DeptNoManagerAction exists | DeptNoManagerAction 'refuse' or 'controller'. A changed value: one Audit_Trail_Master row and one governance change log row (type ST) | See below |
| Organisation details (printed on notices, minutes, reports and certificates) | Twelve text boxes (Organisation name 150, Short name 100, Organisation term 30, Certificate sign-off 150, Office label 60, Office address line 1 and 2 100 each, City 60, PIN code 12, Phone 60, Fax 60, E-mail 100) and the button "Save organisation details". An empty field is left out of the printed output. An error-style note above the cards says "Organisation details are not set. Notices, minutes, reports and certificates print no organisation name or address until you fill them in below." while the Organisation name is empty | All twelve rows in one transaction, or none; one Audit_Trail_Master row per changed field | "Organisation details saved."; "Not saved: [field label] is not valid. Line breaks and characters outside Windows-1252 are not allowed." (the typed values stay in the boxes) |
| Organisation logo (printed at the top of PDFs and reports) | The current logo or the line "No logo is set: printed output shows the organisation name in its place."; the file box "New logo" (.png, .jpg, .jpeg, .gif); help "PNG, JPEG or GIF, at most 500 KB and 1000 x 300 pixels. It is stored as a PNG."; the buttons "Upload logo" and "Remove logo" (browser question "Remove the organisation logo?") | The audit row only (Key_Value 'OrganisationLogo', Field_Name 'LogoFile', new value "Uploaded: [format, size]" or "Removed"); the file `Files/Branding/report-logo.png` is written or deleted by the application after the audit row is saved. The file name and type sent by the browser are ignored | "Choose an image file first."; "Logo saved ([detail])."; "Logo removed."; "No logo is set."; "The logo is larger than 500 KB."; "The logo must be a PNG, JPEG or GIF image."; "The file is not a valid image (it is damaged or incomplete)."; "The file is not a valid image."; "The logo must be at most 1000 x 300 pixels (this one is [width] x [height])."; "Record Not Saved" |

The card "Department without an active Manager" (BMMS/Master/SystemSettings.aspx; shown only when the setting row exists) offers
"A new agenda item is" with the choices "Refused (default)" and "Sent to the Controller", and the help text "Used when a new
agenda item's department has no active Manager. A change is written to the audit trail." (before step 53: "Stored now, used from
a later step: today agenda items are routed as before."). Only an Admin may save it. The two confirmation messages after Save
(BMMS/Master/SystemSettings.aspx.cs, btnSaveDeptRule_Click) are "Saved: when a department has no active Manager, a new agenda
item will be sent to the Controller. The setting is now in use." and "Saved: when a department has no active Manager, a new agenda item will be
refused. The setting is now in use." (until step 53 they ended "This is stored now and used from a later step."). A value
that is not one of the two gives "Not saved: the value is not valid."

The SMTP settings are not on this page. They are edited on the SMTP Configuration page: see chapter 07, "Mail server settings".

## Page access policy

BMMS/XML/PageAccess.xml is read by BMMS.Security.PageAccessModule (BMMS/PageAccessModule.cs), which runs on every `.aspx` request after the session is available. The rules, in the order the module applies them:

1. A page listed under `<public>` (Default.aspx, Logout.aspx, Error/ErrorPage.aspx) is always allowed.
2. Every other page needs a signed-in user (a UserId in the session); otherwise the request goes to the login page. This holds in both modes.
3. The session must still match the database (user active, same role, same departments); otherwise the session ends and the login page says why (chapter 05, "PageAccessModule").
4. The role of the session must be listed for the page. A page that is not listed is refused. In `Enforce` mode a refusal is the "Access denied" page, HTTP 403, with the text "Your role does not have access to this page." and a link back to the Dashboard. In `LogOnly` mode nothing is refused for a role reason and the request that would have been refused is written to the log as WOULD-DENY. Any `mode` value other than `Enforce` (case ignored) counts as `LogOnly`.

Only `.aspx` requests are checked; images, scripts and files under Files/ are not. If PageAccess.xml cannot be read, only the login and session checks apply and a POLICY-NOT-LOADED line is written. The file is cached and reloaded when it changes (a cache dependency on the file), so an edit takes effect on the next request without a recycle; a failed read is cached for 30 seconds. The log is `App_Data\PageAccessLog.txt` (tab-separated: time, action, user, role, page, reason; actions include DENIED, WOULD-DENY, DENIED-PAGE, SESSION-ENDED, SESSION-CHECK-ERROR and POLICY-NOT-LOADED); App_Data is not served to browsers and no code removes or rotates the file. `RequireRole` inside a page is a second check that works in both modes (chapter 05, "PageAccessModule").

The page-by-role table is in chapter 05, "Pages and master pages" (the Roles column of each folder's table).

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

Drawn from: BMMS/Web.config, BMMS/XML/*.xml, BMMSBAL/Common.cs, BMMSBAL/RichTextLimits.cs, BMMSBAL/OrganisationDetails.cs, BMMS/PageAccessModule.cs, BMMS/Master/SystemSettings.aspx(.cs), the Fix scripts of steps 16, 19, 23, 37, 39, 53 and 56, the BMMS_Test catalog export of 2026-11-28.
