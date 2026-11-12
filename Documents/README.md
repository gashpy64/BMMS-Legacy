# BMMS Documents

- Title: BMMS Documents - index, register and rules
- Audience: Gashpy Software (owner, developers, doc-writer)
- Shipped: No
- Applies to: RA1c2
- Last updated by: RA1c2, based on 1db6ac6 (register entry of 03-Controller only)
- Status: Draft
- Verified against: the register entry of 03-Controller: see there; CLAUDE.md, .claude/agents/doc-writer.md, Documents/_build/*.ps1, Tests/README.md
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
| _build/ | Export and check scripts, the Gashpy Word template | No |

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
- Last updated by: <step>, based on <commit the step started from>
- Status: Draft | Reviewed by owner | Current
- Verified against: <files or procedures read>
- To confirm: <open points; empty before an export>
```

### User manuals

A user manual carries only its title and three lines; its full header block is in the register
below.

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
- Applies to: RA1b (step 41)
- Last updated by: RA1b (step 41), based on 1d1bbbe
- Status: Draft
- Verified against: for the section "MD Secretariat and Management": BMMS/UserControl/MenuUserControl.ascx
  (Reports menu of Management), BMMS/Report/Reports.aspx(.cs), BMMS/Report/Followup.aspx(.cs),
  BMMS/Report/ViewReport.aspx.cs, BMMS/XML/PageAccess.xml, BMMSBAL/ReportsMgr.cs (message texts),
  BMMSBAL/HTML_Report.cs (status line, draft note), Database/BMMS-Fix-ReportAccess-Step41.sql
- To confirm: manual not written yet (WF2d1), except the section "MD Secretariat and Management";
  what MD Secretariat uses beyond Followup and the dashboard; whether the owner wants the Management
  reports described only here (the rules give Management no manual of its own) or also as a short
  manual; the button names "View" and "Generate" on the report pages are taken from the code
  comments and the step test table, not from the page markup

### User-Manuals/01-User.md

- Title: BMMS User Manual
- Audience: User role
- Shipped: Yes (PDF export)
- Applies to: user-ud1a
- Last updated by: WF2a, based on 021e946
- Status: Draft
- Verified against: none yet
- To confirm: manual not written yet (WF2d2)

### User-Manuals/02-Manager.md

- Title: BMMS Manager Manual
- Audience: Manager role
- Shipped: Yes (PDF export)
- Applies to: user-ud1a
- Last updated by: WF2a, based on 021e946
- Status: Draft
- Verified against: none yet
- To confirm: manual not written yet (WF2d2)

### User-Manuals/03-Controller.md

- Title: BMMS Controller Manual
- Audience: Controller role
- Shipped: Yes (PDF export)
- Applies to: RA1c2
- Last updated by: RA1c2, based on 1db6ac6
- Status: Draft
- Verified against: for "What you can and cannot do": BMMS/XML/PageAccess.xml, BMMS/UserControl/MenuUserControl.ascx,
  BMMS/Report/FollowupActionTaken.aspx(.cs) (Followup by Department, step RA1c2),
  BMMS/Report/Reports.aspx.cs, BMMSBAL/ReportsMgr.cs, BMMSBAL/HTML_Report.cs,
  Database/BMMS-Fix-ReportAccess-Step41.sql, the owner's principle of 2026-11-10 (Admin superior for the
  technical items, Controller superior for the functional items)
- To confirm: manual not written yet (WF2d3), except the first section in part; the wording of the
  owner's principle as the owner wants it in a shipped manual; the button names "View" and "Generate" as
  shown on the report page; the Followup by Department wording (the owner looks at the page's function in a
  later review), and that Export to Pdf cannot print Tamil or Hindi (taken from the step requirement)

### User-Manuals/04-Admin.md

- Title: BMMS Admin Manual
- Audience: Admin role
- Shipped: Yes (PDF export)
- Applies to: RA1b (step 41)
- Last updated by: RA1b (step 41), based on 1d1bbbe
- Status: Draft
- Verified against: for "What you can and cannot do": BMMS/XML/PageAccess.xml, BMMS/UserControl/MenuUserControl.ascx
  (Master, Admin and Reports menus by role), the owner's principle of 2026-11-10
- To confirm: manual not written yet (WF2d3), except the first section in part; the wording of the
  owner's principle as the owner wants it in a shipped manual; whether the Admin may also use the
  functional masters that PageAccess.xml opens to both Admin and Controller (Member, Committee,
  Committee Member, Meeting, Meeting Member, Attendance), which sits beside "Controller is superior for
  the functional items" and is not described in the manual yet

### User-Manuals/Glossary.md

- Title: BMMS Glossary
- Audience: Everyone who uses BMMS
- Shipped: Yes (appended to the Overall manual's export)
- Applies to: RA1b (step 41)
- Last updated by: RA1b (step 41), based on 1d1bbbe
- Status: Draft
- Verified against: for step RA1b (step 41): BMMS/XML/PageAccess.xml, BMMS/UserControl/MenuUserControl.ascx
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
  Secretariat uses beyond Followup and the dashboard

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
