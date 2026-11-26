# BMMS Documents

- Title: BMMS Documents - index, register and rules
- Audience: Gashpy Software (owner, developers, doc-writer)
- Shipped: No
- Applies to: AZ2 (header only; no user manual changed, so no register entry, the layout table and the update matrix are unchanged); AZ1 (header only; no user manual changed, so no register entry, the layout table and the update matrix are unchanged); UI2a (header; the register entry of 03-Controller; the layout table and the update matrix are unchanged); GM1a (header; the register entries of 03-Controller and 04-Admin; the layout table and the update matrix are unchanged); IU1 (header; the register entries of 00-Overall, 03-Controller and 04-Admin; the layout table and the update matrix are unchanged); UD1c (header; the register entries of 00-Overall, 02-Manager and 04-Admin; the layout table and the update matrix are unchanged); UD1b (header; the register entries of the five manuals and the Glossary; the layout table is unchanged); MR1 (header; the To confirm of the 04-Admin entry; no user manual text changed); RA1d (header; the register entry of 00-Overall gets one To confirm point, no manual text changed); UN6e (no register entry changed: no user manual changed, nothing is visible); FU2b (register entries of 00-Overall and 03-Controller); FU2a (register entries of 00-Overall, 01-User, 02-Manager and 03-Controller); FU1 (register entries of 00-Overall, 03-Controller and Glossary); UN6d
- Commit: 1b5ec0a
- Last updated by: AZ2, based on 1b5ec0a (header only)
- Status: Draft
- Verified against: for AZ2: the step's diff (no page, field, button or message text changed, so no user manual and no register entry); for AZ1: the step's diff (no page, field, button or message text changed, so no user manual and no register entry); for UI2a: the step's diff and the Followup manual text read for internal words by eye; Documents/_build/Check-UserManuals.ps1 (not run by the doc-writer); for GM1a: the step's diff and the new files (BMMS/Report/GovernanceMatrix.aspx(.cs) and BMMSBAL/GovernanceMgr.cs read in full; the manual text was read for internal words by eye); Documents/_build/Check-UserManuals.ps1 (the rules read, not run: the doc-writer has no way to run it); for IU1: the step's diff; the IU1 manual text was read for internal words by eye (the register entries name what each manual was checked against); Documents/_build/Check-UserManuals.ps1 (the rules read, not run: the doc-writer has no way to run it); for UD1c: the step's diff; the UD1c manual text was read for internal words by eye (the register entries name what each manual was checked against); CLAUDE.md, Documents/_build/Check-UserManuals.ps1 (the rules read, not run: the doc-writer has no way to run it); for UD1b: the step's diff and the user-manual search (no internal word found by search; the register entries name what each manual was checked against); CLAUDE.md, Documents/_build/Check-UserManuals.ps1 (the rules read, not run: the doc-writer has no way to run it); for MR1: the step's diff and the user-manual search (the User Master message of a Manager still needed is in no manual: the Admin manual is not written yet for User Master; the Dashboard text of a passed meeting date is unchanged in the Manager and Controller manuals), BMMSBAL/UserMgr.cs and MeetingMgr.cs (the message texts); for RA1d: the step's diff and the user-manual search (the sign-in message "Your access has changed. Please sign in again." is in no manual; the sections "Signing in and your password" and "Common problems" of the role manuals are not written yet), BMMS/Default.aspx.cs (the message texts); for UN6e: the step's diff and the user-manual search (no manual describes ViewState, stylesheets, indexes or the tester); the register entries of the manuals and the Glossary: see there; CLAUDE.md, .claude/agents/doc-writer.md, Documents/_build/*.ps1, Tests/README.md
  (the update matrix lines for the tester)
- To confirm:

This folder holds the BMMS documents. They are kept in git and committed with the code of the
step that changed them. Only the exports of the Overall manual and the four role manuals ship
with an installation (as PDF, and Word where wanted). The Markdown source is never shipped.
Everything else here is internal.

## Layout

| Path | Content | Shipped |
|---|---|---|
| README.md | This index, the register of the user manuals, the rules and the update matrix | No |
| User-Manuals/00-Overall.md | Overall manual: purpose, roles, who does what, life cycle, statuses, MD Secretariat and Management, help | Yes (export) |
| User-Manuals/01-User.md | Manual for the User role | Yes (export) |
| User-Manuals/02-Manager.md | Manual for the Manager role | Yes (export) |
| User-Manuals/03-Controller.md | Manual for the Controller role | Yes (export) |
| User-Manuals/04-Admin.md | Manual for the Admin role | Yes (export) |
| User-Manuals/Glossary.md | Terms used in the manuals | Yes (appended to the Overall manual's export, not exported on its own) |
| User-Manuals/images/ | Screenshots supplied by Gashpy Software | Yes (inside the exports) |
| System-Manual/01 to 10 | Developer and installer manual | No |
| Data-Flow/00-Notation.md | Diagram notation used in Data-Flow | No |
| Data-Flow/01-Context.md | Context diagram | No |
| Data-Flow/02-Level1-Modules.md | Level 1 modules and the process-by-table R/W matrix | No |
| Data-Flow/03-Program-to-Program/ | One file per feature area | No |
| Data-Flow/04-Workflows/ | One file per workflow (swim lanes per role) | No |
| Release-Notes/CHANGELOG.md | One entry per step and per release | No |
| Export/ | Word and PDF exports, made per release; ignored by git except Export/README.md | No (the PDFs of the manuals are what ships) |
| _build/ | Export and check scripts, the Gashpy Word template, the catalog export of BMMS_Test (Export-Catalog.ps1) | No |
| Standards/documents-spec.md | The documents standard: the rules an audit checks the documents against (a copy of the owner's project document; changed only by the owner's word) | No |
| Audit/ | Documentation audits by the doc-auditor agent: Audit/README.md and one folder per run, `DA-yyyymmdd-<short SHA>/` (Audit-Summary, Coverage-Matrix, Gap-Register, Drift-Register). Internal: never exported, never given to a client | No |

The older folder `Documentation/` was merged into System-Manual and removed in step WF2b1 (see
System-Manual/01, "Superseded documents"); only `Documentation/Pages.xlsx` remains, until the
owner has compared it with `BMMS/XML/PageAccess.xml`.

## Rules for every document

- Markdown, plain ASCII, LF line endings. Diagrams in Mermaid (see Data-Flow/00-Notation.md).
- Every statement is traceable to code, a procedure, a setting or a Test script. What cannot be
  verified is marked inline as `[[CONFIRM: what is open]]` and listed under "To confirm".
- No secrets: no connection strings, passwords, real mail addresses, real names, server names or
  IP addresses. Use placeholders such as `<server>`, `<database>`, `user@example.com`,
  `<Company name>`.
- In quoted message texts, a part the screen fills in is written in square brackets, for example
  "Saved. Not restored: [departments]"; never as `<departments>`, which pandoc reads as HTML.
- Screenshots are taken by Gashpy Software. A document never contains an invented picture; it
  holds a placeholder line until the picture exists:
  `[Screenshot: <screen> - supplied by Gashpy Software]`
- The export refuses any document with an inline `[[CONFIRM: ...]]` or a non-empty
  "To confirm" field.

### Header block (internal documents)

Every document outside User-Manuals starts with its title and this block:

```
# <Title>

- Title: <Title>
- Audience: <who reads it>
- Shipped: No
- Applies to: <git tag or step>
- Commit: <short SHA the document was last verified against>
- Last updated by: <step>, based on <commit the step started from>
- Status: Draft | Reviewed by owner | Current
- Verified against: <files or procedures read>
- To confirm: <open points; empty before an export>
```

The `Commit` field (step DA1) is the commit the document was last verified against, right after
`Applies to`. `Check-Documents.ps1` warns when it is missing or empty; a release export refuses a
document without it (a draft export only warns).

### User manuals

A user manual carries only its title and three lines; its full header block is in the register
below, with the `Commit` field there.

```
# <Title>

- Audience: <role>
- Version: filled in at export
- Date: filled in at export
```

A user manual contains no internal material: no table names, procedure or function names, step
numbers or codes, Reason codes, file paths, unfixed weaknesses, reviewer findings or internal
decisions. Second person ("you"), plain English. `Documents/_build/Check-UserManuals.ps1` must
find nothing before a manual is exported.

Each role manual (01 to 04) uses the same template:

1. What you can and cannot do
2. Signing in and your password
3. Screens - one subsection per screen: Purpose; Fields and buttons; Steps; Messages and what to
   do (the texts as the screen shows them); Notes
4. Tasks by goal
5. Alerts and mails you receive
6. Common problems
7. Quick reference

### Shot list format

The doc-writer lists every screen that a step changed:

| Screen | State to show | File name |
|---|---|---|
| User Master | Edit of a Manager with two departments ticked | images/admin-user-master-edit-manager.png |

File names: lower case, `<manual>-<screen>-<state>.png`, inside User-Manuals/images/.

## Register of the user manuals

### User-Manuals/00-Overall.md

- Title: BMMS Overall Manual
- Audience: Everyone who uses BMMS, and the people who decide on it
- Shipped: Yes (PDF export)
- Applies to: IU1 (section "The Dashboard meeting list, by role": the paragraph on the mail of a saved meeting or committee and its three messages, the paragraph on the action items given at finalisation); UD1c (section "The Dashboard meeting list, by role": "My approvals and Waiting for me": the new paragraph on a Manager's departments); UD1b (section "The Dashboard meeting list, by role": "My approvals and Waiting for me": who approves at the Manager step, the route of a new item, the new paragraph on handled alerts, the Admin gets no alert); FU2b (section "MD Secretariat and Management": the Followup and Followup Summary items, the new paragraph on the Followup status column, the Confirmed Status choices and the refusal messages, three screenshot placeholders); FU2a (section "The Dashboard meeting list, by role": the Action Items card: the Reopened label, the status line under the action text, a confirmed item read-only, the message after Submit on a confirmed item; the Management row and paragraph; four screenshot placeholders); FU1 (section "MD Secretariat and Management": the paragraph on the Followup screen: the Status column as text, no Submit or Reopen, who confirmed and reopened, a confirmed followup is final; the first Followup screenshot placeholder reworded); UN6d (section "The Dashboard meeting list, by role": the Action Items table and the paragraph on Submit in the Action Item Details panel; the section "MD Secretariat and Management": the MD Secretariat reads Followup only, four screenshot placeholders); UN6c2b (section "The Dashboard meeting list, by role": the table of roles, "In progress" and "Waiting for me", the new subsection "The summary cards", "My approvals and Waiting for me": the heading with a dash, the hint of a refused choice, the Committee drop-down sentence, the layout paragraph; the Dashboard paragraph of "MD Secretariat and Management"); UN6c2a (section "The Dashboard meeting list, by role": the Waiting for me column, "In progress", "Pending" and "Waiting for me", the new subsection "My approvals and Waiting for me", the layout paragraph, the Committee drop-down sentence; the Dashboard paragraph of "MD Secretariat and Management"); UN6c1 (section "The Dashboard meeting list, by role": the Alerts card, the header count, the Action Items card; the Dashboard paragraph of "MD Secretariat and Management"); UN6b (sections "The Dashboard meeting list, by role", "Meeting status on the Dashboard" and the Dashboard paragraph of "MD Secretariat and Management"); the rest RA1b (step 41)
- Commit: 79f50ea
- Last updated by: IU1, based on 79f50ea
- Status: Draft
- Verified against: for IU1: BMMS/Master/Meeting.aspx.cs and Committee.aspx.cs (the three messages, the green kind), Database/BMMS-Fix-InactiveUsers-Step55.sql (fn_FunctionalUsers, the rows of the finalisation) and Database/README.md (section Step IU1, with the owner's tests); the text was read for internal words by eye;
  for UD1c: BMMS/Master/Agenda.aspx.cs, BMMS/Report/Reports.aspx.cs and BMMS/Master/User.aspx.cs (diff), Database/BMMS-Fix-ManagerScope-Step54.sql (fn_ManagerDepartments, fn_ReportingPersonAllowed) and Database/README.md (section Step UD1c);
  for UD1b: BMMS/Master/Agenda.aspx.cs (the route and save messages), BMMS/DashBoard/DashBoard.aspx and .aspx.cs (HandledCaption: the three handled lines), BMMSBAL/MeetingMgr.cs and UserMgr.cs (the message texts), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_AgendaRoute, fn_AgendaWaitingFor, fn_DepartmentManagers, the alert and mail procedures) and Database/README.md (section Step UD1b);
  for FU2b: BMMS/Report/Followup.aspx and .aspx.cs (the Followup status column, the Pending choice, StatusCellHtml, StatusBlockHtml, the Summary column, the refusals), BMMS/FollowupStatusText.cs (Word, Line), BMMSBAL/ReportsMgr.cs (ReportRefusedMessage), Database/README.md (section Step FU2b) and the owner's tests as given;
  for FU2a: BMMS/DashBoard/DashBoard.aspx and .aspx.cs (diff: the Reopened chip, pActionItemStatus, SetActionItemPanelMode, the two constants of the confirmed line and message, ShowConfirmedAfterSave), BMMS/FollowupStatusText.cs (the status texts and the date format), Database/README.md (section Step FU2a) and the owner's tests as given;
  for FU1: BMMS/Master/Followup.aspx and Followup.aspx.cs (the read-only look for the MD Secretariat: the Status text, the line, no Submit and no Reopen, "View", the Status cell texts), Database/README.md (section Step FU1), the tester run 2026-11-16_133023 and the owner's tests as given;
  for UN6d: git diff ce7358a 276e402 of BMMS/DashBoard/DashBoard.aspx and DashBoard.aspx.cs (the buttons by role, the read-only line, the saved message, the list read again, the failure messages inside the panel) and BMMS/Master/Followup.aspx and Followup.aspx.cs (the read-only look for a role that is not the Controller: the line, the ticks, "View", the panel ":: View Action Text" with Close), Database/README.md (section Step UN6d and its Known items), the tester runs of 2026-11-15 and the owner's tests as given;
  for UN6c2b: git diff f3cbd7e~1 f3cbd7e of BMMS/DashBoard/DashBoard.aspx and DashBoard.aspx.cs (the Alerts card note, the My approvals heading and its dash, the filter messages), BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (the cards, labels, scope line, the meaning of In progress, the hint, the role table, the messages), BMMS/CSS/bmms-workbench.css (the 1240 px and 959 px rules), Database/BMMS-Fix-DashboardSummary-Step45.sql (who has the cards, what is counted, the Committee rule), Database/README.md (section Step UN6c2b and its Known items), the tester run of 2026-11-15 and the owner's tests as given;
  for UN6c2a: BMMS/DashBoard/DashBoard.aspx (the My approvals card, headings, empty text, the message paragraph inside the Agenda Alert panel) and DashBoard.aspx.cs (all message texts, LoadApprovals, lnkApproval_Click, BindAgendaDetails, btnApprove_Click and btnReject_Click read in full),
  BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (the Waiting for me column, its tooltip, when it is shown), BMMS/CSS/bmms-workbench.css (diff: the 3 to 1 grid, the 1240 px rule), Database/BMMS-Fix-AgendaWaitingFor-Step44.sql
  (who may decide, what IsWaiting needs, who has the panel), Database/README.md (section Step UN6c2a and its Known items), the tester run of 2026-11-14 and the owner's tests as given; for UN6c1: BMMS/DashBoard/DashBoard.aspx and DashBoard.aspx.cs (links, column headings, buttons, message texts),
  BMMS/MasterPage/Main.Master.cs (the header count), Database/BMMS-Fix-DashboardAlerts-Step43.sql (the listing rules, the Action Items
  scope, Overdue, who may save), Database/README.md (section Step UN6c1), the owner's tests as given; for UN6b: BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (role table, titles, columns, chips, messages),
  BMMS/DashBoard/DashBoard.aspx (card titles and column headers), DashBoard.aspx.cs (diff: the Alerts card date, time and
  detail line, the counts read again after Approve and Reject), Database/BMMS-Fix-DashboardMeetings-Step42.sql (the
  status rules, the groups, the scope), Database/README.md (section Step UN6b), the owner's test result as given;
  for the section "MD Secretariat and Management": BMMS/UserControl/MenuUserControl.ascx
  (Reports menu of Management), BMMS/Report/Reports.aspx(.cs), BMMS/Report/Followup.aspx(.cs),
  BMMS/Report/ViewReport.aspx.cs, BMMS/XML/PageAccess.xml, BMMSBAL/ReportsMgr.cs (message texts),
  BMMSBAL/HTML_Report.cs (status line, draft note), Database/BMMS-Fix-ReportAccess-Step41.sql
- To confirm: the IU1 text (who gets the Meeting and Committee mails, the three messages after the save, the action items given at finalisation) was written from the code and the procedures and not compared with a screenshot; where it belongs in the Overall manual (there is no "Meetings and committees" section yet) is for the owner to place; the UD1c paragraph on a Manager's departments (the same departments on Agenda Entry, the reports and the Reporting Person list, written from the code and the procedures, no screenshot); the UD1b text (who approves at the Manager step, the order of the route of a new item, the three handled lines, the Admin's alerts) was written from the code and the procedures and not compared with a screenshot (the handled lines and the greyed rows are for the owner's eye; two screenshot placeholders in the Manager manual); for the sign-in sections of the role manuals (written in WF2d): since step RA1d a person whose role, departments or status the Admin changed is taken to the sign-in page at the next click, with "Your access has changed. Please sign in again." (role or departments changed) or "Your account is inactive. Contact the administrator." (inactive); unsaved work is lost; the text and where it belongs (Signing in, Common problems) are for the owner to place, and there are two screenshot needs (see the shot list of RA1d); the text of FU2b (the Followup status column, its word and line, the FOLLOWUP STATUS block, the refusal messages) was written from the code and not compared with a screenshot (three screenshot placeholders); the Action Items text of FU2a (the Reopened label, the status line, the read-only panel of a confirmed item, the message after Submit) was written from the code and not compared with a screenshot (four screenshot placeholders); manual not written yet (WF2d1), except the section "MD Secretariat and Management" and the two
  Dashboard sections of UN6b (the Alerts card and Action Items card text of UN6c1 was written from the code and not
  compared with a screenshot; "the alerts of the Controller's own decisions" and "the Manager's own decisions" word the
  rule that a Controller does not list the controller approved and rejected alerts and a Manager the manager approved
  and rejected alerts: the owner confirms the wording); the meaning of the Approved, Rejected and Pending counts is worded from the item
  statuses in the code (the owner confirms the wording); the colour names on the status labels (blue, orange,
  green, red, grey) are taken from the code and are to be compared with the screenshots; what MD Secretariat uses beyond reading Followup and the dashboard (the owner's decision of 2026-11-15 that it reads Followup only is written from Database/README.md, section Step UN6d; the text of "MD Secretariat and Management" and of the Action Items table of Management was written from the code and not compared with a screenshot); whether the owner wants the Management
  reports described only here (the rules give Management no manual of its own) or also as a short
  manual; the button names "View" and "Generate" on the report pages are taken from the code
  comments and the step test table, not from the page markup

### User-Manuals/01-User.md

- Title: BMMS User Manual
- Audience: User role
- Shipped: Yes (PDF export)
- Applies to: UD1b (section "Alerts and mails you receive": where a new item goes and the Controller line; section "Common problems": the refusal when the department has no active Manager); FU2a (section "Screens", Dashboard: the paragraph on the Reopened label, the status line, a confirmed item read-only and the message after Submit); UN6d (section "Screens", Dashboard: the paragraph on changing the action text, Submit and Cancel, the saved message and the failure messages); UN6c2b (section "Screens", Dashboard: the summary cards, the Committee drop-down, the heading In progress and its meaning, the message for a choice that cannot be used); UN6c2a (section "Screens", Dashboard: the description of In progress, no My approvals or Waiting for me, the layout and the Committee drop-down sentences); UN6c1 (section "Screens", Dashboard: Alerts card and Action Items card); UN6b (section "Screens", Dashboard only); the rest user-ud1a
- Commit: db1d641
- Last updated by: UD1b, based on db1d641
- Status: Draft
- Verified against: for UD1b: BMMS/Master/Agenda.aspx.cs (CheckNewItemRoute, the save message, GenerateMail), BMMSBAL/MeetingMgr.cs (the Reason 29 text, the Controller line), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_AgendaRoute, spr_GetAgendaCreationMailId) and Database/README.md (section Step UD1b);
  for FU2a: BMMS/DashBoard/DashBoard.aspx and .aspx.cs (diff: the Reopened chip, the status line, the read-only panel of a confirmed item, the message after Submit), BMMS/FollowupStatusText.cs, Database/README.md (section Step FU2a) and the owner's tests as given;
  for UN6d: BMMS/DashBoard/DashBoard.aspx and .aspx.cs (the Action Item Details panel: Submit and Cancel for the User, the saved message, the list read again, the failure messages on the line inside the panel), Database/README.md (section Step UN6d), the tester runs of 2026-11-15 and the owner's tests as given;
  for UN6c2b: BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (the role table: the User has the Committee drop-down; the cards, labels "[department] items in progress", the scope line, the meaning of In progress, the messages), BMMS/DashBoard/DashBoard.aspx and .aspx.cs (the Action Items message for a refused choice), Database/README.md (section Step UN6c2b), the tester run of 2026-11-15 and the owner's tests as given;
  for UN6c2a: BMMS/UserControl/MeetingSummary.ascx.cs (the Waiting for me column only for the roles the server names), BMMS/DashBoard/DashBoard.aspx.cs (the panel is hidden for every role but Controller and Manager), BMMS/CSS/bmms-workbench.css (diff),
  Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (the roles that have the panel), the tester run of 2026-11-14 and the owner's tests as given; for UN6c1: BMMS/DashBoard/DashBoard.aspx and DashBoard.aspx.cs (links, headings, message texts),
  BMMS/MasterPage/Main.Master.cs, Database/BMMS-Fix-DashboardAlerts-Step43.sql, Database/README.md (section Step UN6c1), the owner's
  tests as given; for UN6b: BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (role table, titles, columns, chips,
  messages), BMMS/DashBoard/DashBoard.aspx (card titles and column headers), DashBoard.aspx.cs (diff), Database/README.md
  (section Step UN6b), the owner's test result as given; before: none yet
- To confirm: manual not written yet (WF2d2), except the Dashboard screen and, since UD1b, the first part of "Alerts and mails you receive" and the first entry of "Common problems" (the Agenda Entry screen itself is not described in this manual yet: where the route and the refusal messages belong is for the owner to place); the Dashboard screen (the Alerts and Action Items text of UN6c1 and FU2a too) was written from the
  code and has not been compared with a screenshot; the meaning of "In progress" (items still waiting for approval) is
  worded from the code

### User-Manuals/02-Manager.md

- Title: BMMS Manager Manual
- Audience: Manager role
- Shipped: Yes (PDF export)
- Applies to: UD1c (section "Screens": the new subsections "Agenda Entry (your departments)" and "Reports (Agenda Summary, Agenda Details, Minutes, Minutes Extract)", three screenshot placeholders; section "Alerts and mails you receive": the alert to the other Managers for a Manager's new item); UD1b (section "Screens", Dashboard: My approvals (every Manager of the department), Step 3 and the new message, the paragraph on handled alerts, two screenshot placeholders; section "Alerts and mails you receive"); FU2a (section "Screens", Dashboard: the paragraph on the Reopened label, the status line, a confirmed item read-only and the message after Submit); UN6d (section "Screens", Dashboard: the paragraph on changing the action text, Submit and Cancel, the saved message and the failure messages); UN6c2b (section "Screens", Dashboard: the summary cards, the heading In progress and its meaning, the Committee and Department drop-downs on every card, My approvals heading with a dash, the messages for a choice that cannot be used, the layout sentence); UN6c2a (section "Screens", Dashboard: the My approvals card, the Waiting for me column, Pending and Waiting for me, deciding an item, the meeting-date and could-not-be-checked messages, the layout and the drop-down sentences); UN6c1 (section "Screens", Dashboard: Alerts card and Action Items card); UN6b (section "Screens", Dashboard only); the rest user-ud1a
- Commit: 42cb88c
- Last updated by: UD1c, based on 42cb88c
- Status: Draft
- Verified against: for UD1c: BMMS/Master/Agenda.aspx and Agenda.aspx.cs (the Department filter, the card note, the new-item department, the messages, DepartmentsRefusedMessage), BMMS/Report/Reports.aspx.cs (the Department drop-down, the refusal messages), BMMSBAL/DepartmentMgr.cs (the texts "All my departments", "(home)", "(inactive)"), BMMSBAL/MeetingMgr.cs (the Reason 30 text), BMMSBAL/ReportsMgr.cs (ReportRefusedMessage), Database/BMMS-Fix-ManagerScope-Step54.sql (spr_GetAgendaByMeetingIdDeptId, spr_AddEditAgendaByManager comment and Reason 30 checks, the report procedures) and Database/README.md (section Step UD1c and Known items: Agenda Summary and Agenda Details open as a PDF);
  for UD1b: BMMS/DashBoard/DashBoard.aspx and .aspx.cs (HandledCaption, lblHandled, the panel line, diff), BMMS/CSS/bmms-workbench.css (diff), BMMSBAL/UserMgr.cs (the closed-alerts sentence), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_AgendaWaitingFor, fn_DepartmentManagers, spr_SetManagerAlertRows, spr_UpdateAgendaByAgendaId comment, the mail procedures) and Database/README.md (section Step UD1b);
  for FU2a: BMMS/DashBoard/DashBoard.aspx and .aspx.cs (diff: the Reopened chip, the status line, the read-only panel of a confirmed item, the message after Submit), BMMS/FollowupStatusText.cs, Database/README.md (section Step FU2a) and the owner's tests as given;
  for UN6d: BMMS/DashBoard/DashBoard.aspx and .aspx.cs (the Action Item Details panel: Submit and Cancel for the Manager, the saved message, the list read again with the Committee and Department filters kept, the failure messages on the line inside the panel), Database/README.md (section Step UN6d), the tester runs of 2026-11-15 and the owner's tests as given;
  for UN6c2b: BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (the cards, the Manager's labels with one, several or a chosen department, ChoiceHint: the Department drop-down shown only with two or more departments, the meaning of In progress for the Manager), BMMS/DashBoard/DashBoard.aspx and .aspx.cs (the My approvals heading and its dash, the Action Items message, the Alerts note), BMMS/CSS/bmms-workbench.css, Database/BMMS-Fix-DashboardSummary-Step45.sql, Database/README.md (section Step UN6c2b), the tester run of 2026-11-15 and the owner's tests as given;
  for UN6c2a: BMMS/DashBoard/DashBoard.aspx (the My approvals card, empty text, the message paragraph inside the Agenda Alert panel, the buttons) and DashBoard.aspx.cs (all message texts, LoadApprovals, lnkApproval_Click, BindAgendaDetails, btnApprove_Click and btnReject_Click read in full),
  BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (the Waiting for me column, the Department drop-down passed on), BMMS/CSS/bmms-workbench.css (diff), Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (which items are routed to a Manager, what IsWaiting needs),
  Database/README.md (section Step UN6c2a and its Known items), the tester run of 2026-11-14 and the owner's tests as given; for UN6c1: BMMS/DashBoard/DashBoard.aspx and DashBoard.aspx.cs (links, headings, message texts),
  BMMS/MasterPage/Main.Master.cs, Database/BMMS-Fix-DashboardAlerts-Step43.sql, Database/README.md (section Step UN6c1), the owner's
  tests as given; for UN6b: BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (role table, Department drop-down for two
  or more departments, titles, columns, chips, messages), BMMS/DashBoard/DashBoard.aspx (card titles and column headers),
  DashBoard.aspx.cs (diff), Database/README.md (section Step UN6b), the owner's test result as given; before: none yet
- To confirm: the Agenda Entry and Reports text of UD1c (the Department filter and drop-downs, the messages, the Edit and Update rules, "Agenda Summary and Agenda Details open as a PDF; print them from the PDF viewer", the alert to the other Managers) was written from the code and the procedures and not compared with a screenshot (three screenshot placeholders); the column names "Entered by" and "Department" of the Agenda Entry list are taken from the requirement, not read in the page markup; the rest of Agenda Entry and Reports is not written yet; manual not written yet (WF2d2), except the Dashboard screen, the two UD1c screens and, since UD1b, the first part of "Alerts and mails you receive"; the handled-alert text of UD1b (the three lines, greyed under All, the panel line; the Manager's second click after another Manager decided) was written from the code and the procedures and not compared with a screenshot (two screenshot placeholders); the Dashboard screen (the Alerts and Action Items text of UN6c1 and FU2a too) was written from the
  code and has not been compared with a screenshot; that the Alerts and Action Items cards do not follow the Department drop-down (read from the fact that the server rule takes the acting user only); the meaning of "Pending" (items waiting with the Manager or the
  Controller) is worded from the code; that the narrow-window panel layout (labels above the fields below about 720
  pixels) is described as the owner saw it, from Database/README.md

### User-Manuals/03-Controller.md

- Title: BMMS Controller Manual
- Audience: Controller role
- Shipped: Yes (PDF export)
- Applies to: UI2a (section "Screens", Followup: how to open it, the title, the filter box "Find followups" and the order of its rows, labels without a colon, View as the main button, one screenshot placeholder); GM1a (section "What you can and cannot do": one sentence on the shared Governance Matrix; section "Screens": the new subsection "Governance Matrix", four screenshot placeholders); IU1 (section "Alerts and mails you receive": the Meeting and Committee mails, the three messages after the save, the action items given at finalisation); UD1b (section "Screens", Dashboard: My approvals also lists the items that went straight to the Controllers; section "Alerts and mails you receive"); FU2b (section "What you can and cannot do": the Followup and Followup Summary paragraph on the Followup status (the Pending choice, the column, the line, the FOLLOWUP STATUS block, the Summary word, the refusal messages), the Followup by Department paragraph (the Followup status column and the printed status, the refusal messages), five screenshot placeholders; section "Screens", Followup: the blank reason message and the single message of the reason check); FU2a (section "Screens", Dashboard: the paragraph on the Reopened label, the status line, a confirmed item read-only and the message after Submit); FU1 (section "Screens", Followup: the filter label Pending, the Status column and drop-down, Submit confirming only the changed rows and its messages, a confirmed followup final with "Confirmed by" and "Confirmed (before history)", View of a confirmed action text, Reopen with its panel, reason and messages, the "Reopened by" line, five screenshot placeholders); UN6d (section "Screens": the paragraph on changing the action text in the Dashboard, and the new screen "Followup" with its messages and two screenshot placeholders); UN6c2b (section "Screens", Dashboard: the summary cards, the heading In progress and its meaning, the Committee drop-down on every card, My approvals heading with a dash, the messages for a choice that cannot be used, the layout sentence); UN6c2a (section "Screens", Dashboard: the My approvals card, the Waiting for me column, Pending and Waiting for me, deciding an item, the meeting-date and could-not-be-checked messages, the layout and the Committee drop-down sentences); UN6c1 (section "Screens", Dashboard: Alerts card and Action Items card); UN6b (section "Screens", Dashboard); the rest RA1c2
- Commit: 3744571
- Last updated by: UI2a, based on 3744571 (the Followup screen: title, filter layout)
- Status: Draft
- Verified against: for UI2a: BMMS/Master/Followup.aspx (diff: the breadcrumb, the title, the card header "Find followups", the order of the filter rows, the labels, the buttons), BMMS/XML/PageSettings.xml (diff: the tab title), the owner's tests as given; the text was read for internal words by eye;
  for GM1a: BMMS/Report/GovernanceMatrix.aspx and .aspx.cs (read in full: the filters, buttons, headings, all message texts, the defaults, the exports), BMMSBAL/GovernanceMgr.cs (read in full: the transactions, the change type names, the setting texts, the rule notes, the Read-only access block, the CSV rule), BMMS/UserControl/MenuUserControl.ascx and BMMS/XML/PageAccess.xml (diff: the Reports menu entry, Admin and Controller only), Database/README.md (section Step GM1a, with the owner's tests as given); the text was read for internal words by eye;
  for IU1: BMMS/Master/Meeting.aspx.cs and Committee.aspx.cs (the messages, GenerateMail), Database/BMMS-Fix-InactiveUsers-Step55.sql (fn_FunctionalUsers, spr_GetMeetingCommitteeMailId) and Database/README.md (section Step IU1, with the owner's tests); the text was read for internal words by eye;
  for UD1b: BMMS/Master/Agenda.aspx.cs (GenerateMail, the Controller line), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_AgendaRoute, spr_GetAgendaCreationMailId, spr_AddEditAgendaByController comment, spr_GetAlertMailId) and Database/README.md (section Step UD1b);
  for FU2b: BMMS/Report/Followup.aspx and .aspx.cs, BMMS/Report/FollowupActionTaken.aspx and .aspx.cs (the Followup status column, the Pending choice, the status block and column of the printed reports, the refusals), BMMS/FollowupStatusText.cs (Word, Line), BMMS/Master/Followup.aspx and .aspx.cs (diff: the reason check), BMMSBAL/ReportsMgr.cs (ReportRefusedMessage), Database/README.md (section Step FU2b) and the owner's tests as given;
  for FU2a: BMMS/DashBoard/DashBoard.aspx and .aspx.cs (diff: the Reopened chip, the status line, the read-only panel of a confirmed item, the message after Submit), BMMS/FollowupStatusText.cs, Database/README.md (section Step FU2a) and the owner's tests as given;
  for FU1: BMMS/Master/Followup.aspx and .aspx.cs (read in full: the filter, the Status cell, the buttons Edit, View, Reopen, Save, Cancel, Close, Submit, the panels ":: Edit Action Text", ":: View Action Text" and ":: Reopen Followup", all message texts, the browser check of the reason), Database/README.md (section Step FU1), the tester run 2026-11-16_133023 and the owner's tests as given;
  for UN6d: BMMS/Master/Followup.aspx and .aspx.cs (the filter fields, the list columns, the buttons Edit, View, Save, Cancel, Submit, the panel ":: Edit Action Text", all message texts, the all-or-nothing Submit), BMMS/DashBoard/DashBoard.aspx and .aspx.cs (the Action Item Details panel: Submit and Cancel, no Close, the saved message), Database/README.md (section Step UN6d), the tester runs of 2026-11-15 and the owner's tests as given;
  for UN6c2b: BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (the cards, the labels "Items in progress" and "Items rejected", the meaning of In progress for the Controller, ChoiceHint), BMMS/DashBoard/DashBoard.aspx and .aspx.cs (the My approvals heading and its dash, the Action Items message, the Alerts note), BMMS/CSS/bmms-workbench.css, Database/BMMS-Fix-DashboardSummary-Step45.sql, Database/README.md (section Step UN6c2b), the tester run of 2026-11-15 and the owner's tests as given;
  for UN6c2a: BMMS/DashBoard/DashBoard.aspx (the My approvals card, empty text, the message paragraph inside the Agenda Alert panel, the buttons) and DashBoard.aspx.cs (all message texts, LoadApprovals, lnkApproval_Click, BindAgendaDetails, btnApprove_Click and btnReject_Click read in full: the Controller is shown Approve and Reject only where he may approve),
  BMMS/UserControl/MeetingSummary.ascx and .ascx.cs (the Waiting for me column), BMMS/CSS/bmms-workbench.css (diff), Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (which items a Controller may decide, what IsWaiting needs),
  Database/README.md (section Step UN6c2a and its Known items), the tester run of 2026-11-14 and the owner's tests as given; for UN6c1: BMMS/DashBoard/DashBoard.aspx and DashBoard.aspx.cs (links, headings, message texts),
  BMMS/MasterPage/Main.Master.cs, Database/BMMS-Fix-DashboardAlerts-Step43.sql, Database/README.md (section Step UN6c1), the owner's
  tests as given; for the Dashboard screen (UN6b): BMMS/UserControl/MeetingSummary.ascx and .ascx.cs, BMMS/DashBoard/DashBoard.aspx
  (card titles and column headers), DashBoard.aspx.cs (diff), Database/README.md (section Step UN6b), the owner's test
  result as given; for "What you can and cannot do": BMMS/XML/PageAccess.xml, BMMS/UserControl/MenuUserControl.ascx,
  BMMS/Report/FollowupActionTaken.aspx(.cs) (Followup by Department, step RA1c2),
  BMMS/Report/Reports.aspx.cs, BMMSBAL/ReportsMgr.cs, BMMSBAL/HTML_Report.cs,
  Database/BMMS-Fix-ReportAccess-Step41.sql, the owner's principle of 2026-11-10 (Admin superior for the
  technical items, Controller superior for the functional items)
- To confirm: the Followup filter text of UI2a (the box "Find followups", the row order, the breadcrumb and title) was written from the page markup and not compared with a screenshot (one screenshot placeholder); the manual does not describe Agenda Finalize, Finalize Minutes or Minutes Confirmation yet; the Governance Matrix text of GM1a was written from the code and the owner's tests as given and not compared with a screenshot (four screenshot placeholders); that Print leaves out the header, menu, filters and buttons and prints landscape is taken from the step requirement and the owner's print preview tests, not from a screenshot; the IU1 text in "Alerts and mails you receive" (the Meeting and Committee mails, the three messages, the action items given at finalisation) was written from the code and the procedures and not compared with a screenshot; the Meeting and Committee screens are not described in this manual yet, so the messages are placed in "Alerts and mails you receive" (the owner places them); the first part of "Alerts and mails you receive" (UD1b) was written from the code and the procedures, and where a Controller moves an item to another department (Agenda Entry) is described only in that section because the Agenda Entry screen is not written in this manual yet; the Followup status text of FU2b (the column, the word and line, the FOLLOWUP STATUS block, the Followup by Department status, the refusal messages) was written from the code and not compared with a screenshot (five screenshot placeholders); the Action Items text of FU2a (the Reopened label, the status line, the read-only panel of a confirmed item, the message after Submit) was written from the code and not compared with a screenshot; manual not written yet (WF2d3), except the first section in part, the Dashboard screen and the Followup screen (written
  from the code, not compared with a screenshot; the Followup section does not describe the Meeting Date boxes of the filter, which the list's query does not use; "Pending" worded from the item statuses in the code; the Followup text of FU1 (Status, Confirmed, Reopen) was written from the code and not compared with a screenshot, and the date and time in "Confirmed by" and "Reopened by" are the database server's, not checked against the Controller's clock; the Alerts and
  Action Items text of UN6c1 likewise); the wording of the
  owner's principle as the owner wants it in a shipped manual; the button names "View" and "Generate" as
  shown on the report page; the Followup by Department wording (the owner looks at the page's function in a
  later review), and that Export to Pdf cannot print Tamil or Hindi (taken from the step requirement)

### User-Manuals/04-Admin.md

- Title: BMMS Admin Manual
- Audience: Admin role
- Shipped: Yes (PDF export)
- Applies to: GM1a (section "What you can and cannot do": one sentence on the shared Governance Matrix; section "Screens": the new subsections "Department Master (saving a department)" and "Governance Matrix", four screenshot placeholders); IU1 (section "Screens": the new subsection "Reset Password", one screenshot placeholder; section "Alerts and mails you receive": the Meeting and Committee mails and the action items); UD1c (section "Screens", User Master: the Reporting Person list, "(not allowed now)", the refusal message, one screenshot placeholder); UD1b (section "Screens": the new subsections "User Master (Managers and their departments)" and "System Settings (Department without an active Manager)", two screenshot placeholders; section "Alerts and mails you receive"); UN6c2b (section "Screens", Dashboard: no summary cards, the In progress heading, the Alerts card note, the layout sentence); UN6c2a (section "Screens", Dashboard: no My approvals card, no Waiting for me column, the layout sentence); UN6c1 (section "Screens", Dashboard: no functional alerts, no Action Items card); UN6b (section "Screens", Dashboard); the rest RA1b (step 41)
- Commit: 32c619d
- Last updated by: GM1a, based on 32c619d
- Status: Draft
- Verified against: for GM1a: BMMS/Report/GovernanceMatrix.aspx and .aspx.cs and BMMSBAL/GovernanceMgr.cs (read in full), BMMS/Master/Department.aspx.cs and BMMSBAL/DepartmentMgr.cs (diff: the two refusal messages), BMMS/UserControl/MenuUserControl.ascx and BMMS/XML/PageAccess.xml (diff: the Admin menu entry), Database/README.md (section Step GM1a, with the owner's tests as given); the text was read for internal words by eye;
  for IU1: BMMS/Master/ResetPassword.aspx and .aspx.cs (read: the list, the button, the confirmation, all message texts), BMMSBAL/UserMgr.cs (diff), Database/BMMS-Fix-InactiveUsers-Step55.sql (spr_GetResetPasswordMail) and Database/README.md (section Step IU1, with the owner's tests); the text was read for internal words by eye;
  for UD1c: BMMS/Master/User.aspx.cs (diff: LoadMgrController, NotAllowedManagerChosen, the page check, the Department change), BMMSBAL/UserMgr.cs (the Reason 31 text and " (not allowed now)"), Database/BMMS-Fix-ManagerScope-Step54.sql (fn_ReportingPersonAllowed, spr_GetReportingPersonList, the Reason 31 checks) and Database/README.md (section Step UD1c);
  for UD1b: BMMS/Master/User.aspx.cs (the save and status messages, diff), BMMSBAL/UserMgr.cs (ReleasedMessage and the Reason 24 lines), BMMS/Master/SystemSettings.aspx and .aspx.cs (the card and its messages), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_ManagerReleaseRefusal, spr_SetManagerAlertRows, fn_AgendaRoute) and Database/README.md (section Step UD1b);
  for UN6c2b: BMMS/UserControl/MeetingSummary.ascx.cs (the cards are hidden when the server refuses the role; the Admin gets no statistics), Database/BMMS-Fix-DashboardSummary-Step45.sql (Reason 4 for the Admin), BMMS/DashBoard/DashBoard.aspx (the Alerts note), BMMS/CSS/bmms-workbench.css, Database/README.md (section Step UN6c2b);
  for UN6c2a: BMMS/DashBoard/DashBoard.aspx.cs (LoadApprovals: the panel is hidden for the Admin), BMMS/UserControl/MeetingSummary.ascx.cs (the Waiting for me column), BMMS/CSS/bmms-workbench.css (diff), Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (no panel for the Admin role); for UN6c1: BMMS/DashBoard/DashBoard.aspx.cs (the card is hidden for the Admin), Database/BMMS-Fix-DashboardAlerts-Step43.sql
  (the Admin gets no alerts, no mail, no Action Items card), Database/README.md (section Step UN6c1); for the Dashboard screen (UN6b): BMMS/UserControl/MeetingSummary.ascx and .ascx.cs, BMMS/DashBoard/DashBoard.aspx
  (card titles and column headers), DashBoard.aspx.cs (diff), Database/BMMS-Fix-DashboardMeetings-Step42.sql (the
  Admin gets no counts), Database/README.md (section Step UN6b); for "What you can and cannot do": BMMS/XML/PageAccess.xml,
  BMMS/UserControl/MenuUserControl.ascx (Master, Admin and Reports menus by role), the owner's principle of 2026-11-10
- To confirm: the Governance Matrix and Department Master text of GM1a was written from the code and the owner's tests as given and not compared with a screenshot (four screenshot placeholders); that Print leaves out the header, menu, filters and buttons and prints landscape is taken from the step requirement and the owner's print preview tests; the Department Master screen is otherwise not written in this manual yet (only the save messages are), and "Successfully Saved" and "Record Not Saved" are read from Department.aspx.cs; the Notes sentence "a user who made a recorded change cannot be deleted afterwards" is taken from Database/README.md (the delete refusal text the User Master screen shows for it was not read and is not in the manual); the Reset Password text of IU1 (the list with "(inactive)", the four messages) was written from the code and not compared with a screenshot (one screenshot placeholder); the messages the screen shows when the reset is refused by the rules of User Master (for example a role other than Admin) are not listed in the manual; the Meeting and Committee mail sentence in "Alerts and mails you receive" was written from the code and not compared with a screenshot; the Reporting Person text of UD1c (the list, "(not allowed now)", the refusal message, that the check is made on every save) was written from the code and the procedures and not compared with a screenshot (one screenshot placeholder); the owner checks "(not allowed now)" by eye (the tester's fixture has no such user); the Admin text of UD1b (the subsections User Master (Managers and their departments) and System Settings, written from the code and not compared with a screenshot; two screenshot placeholders; both screens are otherwise not written in this manual yet); the sentence about alerts closed for a Manager is worded in the singular or plural by the code, the manual gives the plural form; for the User Master screen (written in WF2d3): since step MR1 a role change away from Manager, a removed department and a Deactivate of an active Manager are refused while items routed to the Manager wait (since step 53 only when no other Manager of the department could decide them); the message box shows "Not saved: this Manager is still needed." and one line per part (items still open for approval; items of past meetings whose agenda was never finalized, which the Controller closes with Agenda Finalization; last active Manager of a department), then "Nothing was changed." The texts are in the CHANGELOG entry of MR1 and are for the owner to place in the Admin manual; one screenshot need (the message box with two and with three parts); manual not written yet (WF2d3), except the first section in part and the Dashboard screen (written
  from the code, not compared with a screenshot); the wording of the
  owner's principle as the owner wants it in a shipped manual; whether the Admin may also use the
  functional masters that PageAccess.xml opens to both Admin and Controller (Member, Committee,
  Committee Member, Meeting, Meeting Member, Attendance), which sits beside "Controller is superior for
  the functional items" and is not described in the manual yet

### User-Manuals/Glossary.md

- Title: BMMS Glossary
- Audience: Everyone who uses BMMS
- Shipped: Yes (appended to the Overall manual's export)
- Applies to: UD1b (entries "Approve, reject" and the Manager row of the role table; the new entries "Handled alert" and "Sent to the Controller"); FU1 (entry "MD Secretariat"); UN6d (entry "MD Secretariat"); UN6c2b (entries "In progress" and "Summary cards", and "Waiting for me"); UN6c2a (entries "Meeting date passed", "My approvals" and "Waiting for me"); RA1b (step 41)
- Commit: db1d641
- Last updated by: UD1b, based on db1d641
- Status: Draft
- Verified against: for UD1b: BMMS/DashBoard/DashBoard.aspx.cs (HandledCaption), BMMSBAL/MeetingMgr.cs (the Controller line), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_AgendaRoute, fn_AgendaWaitingFor) and Database/README.md (section Step UD1b); for FU1: BMMS/Master/Followup.aspx.cs (CanSave, the Status cell for a reader, "View"); for UN6d: BMMS/Master/Followup.aspx.cs (CanSave, the read-only line, "View", the disabled ticks), Database/README.md (section Step UN6d); for UN6c2b: BMMS/UserControl/MeetingSummary.ascx.cs (InProgressMeaning, the cards), Database/BMMS-Fix-DashboardSummary-Step45.sql; for UN6c2a: BMMS/DashBoard/DashBoard.aspx.cs (message texts, BindAgendaDetails), BMMS/UserControl/MeetingSummary.ascx.cs (the Waiting for me column), Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (who has the panel, what IsWaiting needs); for step RA1b (step 41): BMMS/XML/PageAccess.xml, BMMS/UserControl/MenuUserControl.ascx
  (Reports menu of Management), BMMS/Report/Reports.aspx.cs, Followup.aspx.cs, BMMSBAL/HTML_Report.cs
  (Minutes status, draft note), BMMSBAL/ReportsMgr.cs; and before: BMMS/XML/PageAccess.xml (role codes and the pages of each role; the nine
  Admin-only pages of step RA1a), BMMS/PageAccessModule.cs (RequireRole), BMMS/UserControl/MenuUserControl.ascx
  (Master and Admin menus by role), Database/BMMS-Fix-RoleAccess-Step40.sql (the Controller has
  no rights on other accounts),
  BMMS/UserControl/MenuUserControl.ascx (screen names), BMMS/Default.aspx.cs (the dashboard after
  sign-in; the first sign-in goes to the password change), BMMS/DashBoard/DashBoard.aspx.cs
  (Approve and Reject shown to the Manager at AC and to the Controller at AMA; the decision is saved
  when its mail fails; the meeting-date message; Admin, mgmt and md_sect view only),
  BMMS/DashBoard/DashBoard.aspx and BMMS/Master/Agenda.aspx (Proposed Resolution),
  BMMS/Master/MinutesUpdate.aspx (Actual Resolution), BMMS/Master/AgendaFinalization.aspx.cs and
  spr_CheckAgendaApprovedByMeetingId on BMMS_Test (Agenda Finalize rejects the items still at AC or
  AMA), BMMS/Master/Followup.aspx and BMMS/Report/Followup.aspx (Followup, Followup Summary),
  Database/BMMS-Fix-CommentAuthor-Step35.sql (no approval after the agenda is
  finalized), Database/BMMS-Fix-MinutesDueDate-Step38.sql (due date of follow-up decisions), the alert
  procedures on BMMS_Test (removing an alert changes only the alert),
  Database/BMMS-Fix-AgendaRouting-Step20.sql (routing to the Manager or the Controllers),
  Database/BMMS-Fix-UserHistory-Step39.sql (home department, several departments for a Manager),
  Database/README.md (In Attendance, Special Invitee, Invitee as member tags)
- To confirm: the display names of the roles as stored in the database (the glossary uses the
  names the code and PageAccess.xml use); what the Management role uses beyond the dashboard and the three reports of RA1b; what MD
  Secretariat uses beyond reading Followup and the dashboard

## Update matrix

Which change updates which document. The doc-writer uses it after every step.

| A step changes | Update |
|---|---|
| A page, a field, a button or a message text | The role manuals that use the page, 00-Overall where it is described, the Data-Flow files of that feature area, the shot list |
| A procedure, a table, a column or a Reason code | System-Manual/04-Database, the Data-Flow files that use it, System-Manual/08-Security where a rule or a role check changed |
| A setting (App_Setting row, AppSettings.xml, System Settings page) | System-Manual/06-Configuration-and-Settings, 04-Admin |
| An approval, routing, alert or status rule | Data-Flow/04-Workflows, 00-Overall, 02-Manager, 03-Controller (and 01-User where the User sees it) |
| Mail (when, to whom, content) | System-Manual/07-Mail, the role manuals' "Alerts and mails you receive", the workflows |
| Install, step order, a Fix, Rollback, Check or Test script | System-Manual/03-Deployment-and-Installation, System-Manual/10-Testing-and-Release, this README |
| A new numbered database step | Also the tester's baseline: System-Manual/10-Testing-and-Release ("Upkeep after a new database step"; Update-Baseline.ps1) |
| The tester (Tests/, .claude/agents/tester.md, .claude/hooks/tester-guard.ps1) | System-Manual/10-Testing-and-Release, System-Manual/02-Development-Environment ("The tester"); no user manual |
| The doc-auditor, its guard, Export-Catalog.ps1 or the documents standard | System-Manual/02-Development-Environment (the agents table), System-Manual/10-Testing-and-Release (the audit at a release candidate), Audit/README.md, this README |
| An audit run (doc-auditor) | Only its run folder `Documents/Audit/DA-yyyymmdd-<short SHA>/` and the run list in Audit/README.md; afterwards the doc-writer's stubs for the documents the standard requires that have no file (each a register or layout entry here) |
| Every step | Release-Notes/CHANGELOG.md |

A step with no document impact says "documents affected: none" in its plan, and only the
CHANGELOG gets its entry.

## Checks and export

Run from the repository root in PowerShell 7:

- `pwsh -File Documents/_build/Check-Documents.ps1` - header blocks, the register, ASCII, LF,
  placeholder format, no secret-like text; with pandoc: every image target is `images/<name>` next
  to the document and no raw block (openxml, html) is used; with mermaid-cli: every Mermaid block
  parses.
- `pwsh -File Documents/_build/Check-UserManuals.ps1` - the internal-material check of
  User-Manuals/, on the source and on pandoc's rendering of it; needs pandoc (or
  `-Pandoc <path to pandoc.exe>`); must end with "0 hit(s)." and exit code 0.
- `pwsh -File Documents/_build/Export-Documents.ps1 -Files <list>` - Word and PDF into
  `Documents/Export/<label>/`. Without -Files: the Overall manual (with the Glossary appended) and
  the four role manuals. The label is the release tag vX.Y.Z when HEAD carries one that
  matches AssemblyInformationalVersion, otherwise `Draft - <date>`; the latest step tag appears
  only in the folder name `Draft-<step tag>-<date>`, never in the document. Needs
  pandoc, mermaid-cli, Microsoft Edge and Word; makes no network calls; writes only under
  Documents/Export/.
- `pwsh -File Documents/_build/New-ReferenceDocx.ps1` - rebuilds the Gashpy Word template
  (only when the template is to change).
- `pwsh -NoProfile -File Documents/_build/Export-Catalog.ps1 -Server .\SQLEXPRESS -Database BMMS_Test -Replace` -
  the read-only catalog of BMMS_Test (-Server and -Database are mandatory)
  for an audit, into a folder outside the repository (see Audit/README.md).

Since step DA1: `Check-Documents.ps1` also checks the files under Audit/ and Standards/ (they
carry the header block), finds password hashes, salts and DPAPI-protected values as secret-like
text, and warns about an empty or missing `Commit` field. `Export-Documents.ps1` refuses every file
under Audit/, and for a release export any document whose `Commit` is empty or missing.
