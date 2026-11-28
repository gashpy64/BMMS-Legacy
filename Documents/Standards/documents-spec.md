# BMMS Documents Standard

- Title: BMMS Documents Standard
- Audience: Gashpy Software (owner, developers, doc-writer, doc-auditor)
- Shipped: No
- Applies to: DA1 (copy of the owner's project document claude/documents-spec.md)
- Commit: 5f8c4fe
- Last updated by: DA1, based on 5f8c4fe
- Status: Draft
- Verified against: the owner's text of claude/documents-spec.md (updated 2026-11-19 for DA1), copied below unchanged (DA1 gate B, 2026-11-20)
- To confirm:

This file is the standard an audit checks the documents against (Documents/Audit/README.md). It
is a copy of the owner's project document and changes only on the owner's word; the doc-auditor
reads it and cannot write it.

# BMMS Documents: specification and templates (approved by the owner 2026-11-09, decisions in section 10; updated 2026-11-19 for DA1)

Applies to the Documents/ folder (in git, same commit as the code; see claude/wf2-documentation-agent.md). Written by the doc-writer agent, checked by Claude against the code, reviewed by the owner. Audited by the doc-auditor agent (claude/da1-requirements.md).
Shipped with the installation: the User manuals only (Documents/User-Manuals/). Everything else in Documents/ is internal.
A copy of this specification is kept in the repository as Documents/Standards/documents-spec.md; the project document claude/documents-spec.md is the master, and the copy is refreshed in the step that changes it.

## 1. Principles
1. Every statement is traceable to the code, a stored procedure, a setting or a Test script. What cannot be verified is marked `To confirm: <what>` and listed in the document's record; never guessed.
2. Plain text: Markdown and Mermaid. Word or PDF are exports (section 11).
3. No secrets anywhere in Documents/: no connection strings, passwords, password hashes or salts, real addresses, real names of people or clients. Use placeholders (`<server>`, `<user>`).
4. Owner's terms: Followup, Proposed Resolution, Actual Resolution, Reporting Person, Agenda, Minutes, Controller, Manager. One glossary; the same word everywhere.
5. Each document has a header block (below) and a change record at the end.
6. A step that changes behaviour must update the documents it touches (section 8). A step with no document impact says so in the plan ("documents affected: none") and the gate checks that claim.
7. Two audiences:
   - Shipped (User-Manuals/): written for clients. Contains no internal material: no technical internals (tables, procedures, step numbers, file paths), no unfixed weaknesses or security backlog, no reviewer findings, no internal decisions, no owner or machine names, no work-in-progress notes, no reference to the internal documents. "To confirm" lines are resolved or removed before an export.
   - Internal (System-Manual/, Data-Flow/, Release-Notes/, Audit/, Standards/): for Gashpy Software developers and installers. May describe the full design, limits and known gaps, but never secrets. The security backlog and reviewer findings still live in the project docs and Database/README.md; the System manual states how security works and its known limits in factual terms.
8. Plain English, second person for user manuals ("you can..."), short sentences, no jargon without a glossary entry.
9. A file being present does not make a document complete: status is recorded on two separate scales (section 12).

## 2. Folder layout
```
Documents/
  README.md                      internal index, how to update
  User-Manuals/                  SHIPPED
    00-Overall.md                what BMMS is, roles (including MD Secretariat and Management), login, common screens, who does what, every workflow in plain words
    01-User.md
    02-Manager.md
    03-Controller.md
    04-Admin.md
    Glossary.md                  client-facing glossary
    images/                      screenshots (owner takes them), named <manual>-<screen>-<nn>.png
  System-Manual/                 internal
    01-Overview-and-Architecture.md
    02-Development-Environment.md
    03-Deployment-and-Installation.md
    04-Database.md
    05-Application-Code.md
    06-Configuration-and-Settings.md
    07-Mail.md
    08-Security.md
    09-Operations-and-Support.md
    10-Testing-and-Release.md
  Data-Flow/                     internal
    00-Notation.md
    01-Context.md
    02-Level1-Modules.md
    03-Program-to-Program/        one file per feature area (see section 5)
    04-Workflows/                 one file per workflow (see section 6)
  Release-Notes/
    CHANGELOG.md                 internal: one entry per step tag
  Audit/                         internal: documentation audits (doc-auditor), one folder per run DA-yyyymmdd-<short SHA>/
    README.md                    what the folder is, run list, how to run an audit
  Standards/                     internal
    documents-spec.md            repository copy of this specification
  Export/                        generated Word and PDF (section 11)
```
The workflow diagrams in Data-Flow/04 stay internal; the Overall user manual carries simplified, plain-language versions of the user-facing ones (agenda, meeting, minutes, alerts), drawn for the client reader.

## 3. Header block for every document
```
---
Title:
Audience:            (User / Manager / Controller / Admin / Developer / Installer / All)
Shipped:             Yes (user manuals) | No (internal)
Applies to:          git tag or step (for example user-ml2c / step 38)
Commit:              short SHA the document was last verified against (empty gives a check warning; a release export refuses it)
Last updated by:     step id and commit
Status:              Draft | Reviewed by owner | Current
Verified against:    list of files or procedures read to write it (in shipped manuals this line is removed at export)
To confirm:          open points (empty when none; empty before an export)
---
```
For user manuals the full header block, including Commit, lives in the register in Documents/README.md (WF2a decision Q2).

## 4. User manuals (role-wise and Overall) - SHIPPED
Written for a business reader. No code, no table names. Short steps, one task per section, screen names exactly as on screen.

### 4.1 Common template for each role manual (01 to 04)
1. Who this is for and what this role can do (and cannot do): one table, taken from PageAccess.xml and the procedures' role rules.
2. Signing in, first login, changing and resetting the password, signing out, session timeout.
3. The screens you will use: one section per menu item. Each section has: purpose; who sees it; fields and buttons (name and meaning); step-by-step tasks; messages you may see and what to do (taken from the code's message texts); notes and limits.
4. Tasks by goal (the "how do I" list for the role), each as numbered steps.
5. Alerts and mails you receive: when, what they say, what to do.
6. Common problems: message, cause, action.
7. Quick reference: one page, keys, statuses, colours.
Screenshots: the doc-writer lists the screens needed (a shot list with the page, the state to show, and the file name) and puts a placeholder `[Screenshot: <screen> - supplied by Gashpy Software]` in the text; the owner takes the pictures and drops them into images/. The doc-writer never invents a picture.

### 4.2 Content that differs by role (scope of each manual)
- User (01): create and edit own agenda items, see own items and status, agenda printout and mail, Update Minutes view as allowed, own alerts, Dashboard (own department), Reports allowed, change own password.
- Manager (02): everything a User sees plus approve or reject items of the department (and, from UD1b, any Manager of the department can act; first decision wins), alerts and "handled by another approver", Agenda Entry for the department (later: all managed departments), Reports.
- Controller (03): agenda approval at the Controller stage, reject rules, meetings (create, update, finalise, notice, send mail), minutes (update, confirm), Dashboard, Reports, User Master and Department/Member/Committee masters as allowed, Governance Matrix (from GM1).
- Admin (04): masters, User Master (roles, departments, multi-department Managers from UD1a), System Settings (mail, organisation, no-active-Manager rule), Reset Database (where allowed), Audit Trail, SMTP configuration, user protection rules.
- Overall (00): purpose and scope of BMMS; the roles and a one-page "who does what" matrix; the meeting-to-minutes life cycle in plain words with simplified workflow diagrams; statuses and what they mean; glossary; where to get help. MD Secretariat and Management have a short section each here, because their roles are not yet defined in detail (the doc-writer takes what they can open from PageAccess.xml and marks the rest "To confirm" until the owner settles them). Own manuals for them are a later decision.
- A user manual may describe what a screen does and refuses ("The item cannot be changed after the minutes are confirmed") but never says how (no procedure names, Reason codes or table names).

## 5. Data flow diagrams - INTERNAL
Definition used: the flow of data from one program (page, class, procedure, table, mail server, file) to another.

### 5.1 Notation (00-Notation.md)
Mermaid flowchart. Shapes: rounded = page (.aspx); rectangle = BAL/DAL class or C# method; cylinder = table; hexagon = stored procedure; parallelogram = file or mail; stadium = external actor (User, Manager, Controller, Admin, SMTP server). Arrows labelled with the data (for example "AgendaId, DecisionCode"). Colours only as a secondary signal (each shape also has a text label). Each diagram is followed by a table "From, To, Data, Notes" so the picture is also readable as text, and by the list of files and procedures it was drawn from.

### 5.2 Levels
- 01-Context: BMMS as one box; actors; SMTP server; file store (agenda text files); database; what goes in and out.
- 02-Level1-Modules: modules (Login and users, Masters, Agenda, Approval, Meetings, Minutes, Notices and mail, Dashboard and alerts, Reports, Audit, Settings) and the data stores between them.
- 03-Program-to-Program (one file per feature area): page to BAL to DAL to procedure to tables, and back, including mail and file outputs. Areas: Login and session; User Master (with history tables); Department and other masters; Agenda Entry and routing (fn_AgendaRoute); Agenda approval (Manager, Controller); Agenda Finalisation and mail; Meeting create/update/notice; Minutes update and confirmation (spr_UpdateMinutes, due date); Dashboard and alerts; Reports; Audit trail; System settings; Reset Database; Mail sending (Mail_Mgr, SMTP).
  Each file: overview diagram; one sequence diagram for the main flow (Mermaid sequenceDiagram: page, BAL, DAL, procedure, table); inputs and outputs; error and refusal paths with their Reason codes; where the rule lives (C# and procedure).
- Table list: for each flow, the tables read and written (a matrix: process by table, R/W).

## 6. Workflow diagrams (Data-Flow/04-Workflows) - INTERNAL
Process flow from the business view, with roles as swim lanes (Mermaid flowchart with subgraphs per role). One file per workflow, each with statuses and the rule that moves the item:
1. Agenda life cycle: create, edit, route (M, I, C), Manager approve or reject, Controller approve or reject, finalise, with the status codes and who is alerted and mailed.
2. Meeting life cycle: create, notice, agenda attach, locks, finalise, minutes.
3. Minutes life cycle: update (decisions, due date, Actual Resolution), finalised, confirmed (locks), audit rows.
4. Alerts: creation, refresh (step 36/37), read, remove, nullified when another approver acts (from UD1b).
5. User life cycle: add, role or department change (history rows), deactivate, activate, delete, Reset Password.
6. Release and install: pull, database steps order, Check script, Test on BMMS_Test, browser check, rollback.
Each workflow file ends with a "decision points" table: condition, outcome, message shown.

## 7. System manual templates (Technical) - INTERNAL
Developer and installer audience. Each chapter lists "Verified against" files.
- 01 Overview and architecture: purpose; layers (Web Forms pages, BAL, DAL, Entities, SQL Server); projects and folders in the solution; request flow; session and role model; page access (PageAccess.xml); text storage (agenda text files); key design decisions.
- 02 Development environment: tools and versions (Visual Studio 2026, .NET Framework 4.8, SQL Server version and compatibility level 100, IIS Express), repository, how to clone, build and run, solution settings, how to run the Check and Test scripts (BMMS_Test only for Test), the two-database convention (BMMS and BMMS_Test), the development workflow in short (plan, build, review, test, approve), house rules, the repository agents (reviewers, doc-writer, doc-auditor, tester) and their guards.
- 03 Deployment and installation: server prerequisites; IIS site setup (application pool, .NET version, bindings); folders and permissions (Log, Files); configuration files (web.config, connectionStrings.config, mail settings; placeholders only); database creation and the numbered steps with run order and the re-run rule; Check script use; first login and default password handling; mail and TLS notes; upgrade procedure step by step; rollback; backup and restore; Windows Code Integrity / Smart App Control note (signed DLLs); fresh install checklist; smoke test.
- 04 Database: tables (columns, keys, indexes, purpose), history tables, stored procedures and functions (purpose, parameters, result columns, Reason codes, step number, marker), triggers if any, the numbered step list with what each step changes, compatibility rules (no THROW, TRY_CONVERT, IIF, CONCAT), Reset Database behaviour, audit trail table and what is audited, row locks and transaction notes.
- 05 Application code: project structure, naming, page-to-class map, Mgr/DB/Entity pattern, shared helpers (Mail_Mgr, AgendaMail, MinutesDB, Utilities.WriteErrorLog, text cleaner), validation and messages, how to add a page, a procedure and a step.
- 06 Configuration and settings: every App_Setting and System Settings item (name, values, default, effect, who can change, where it is logged).
- 07 Mail: flows, recipient rules (To and Bcc per mail type), ToRequired, skipped addresses and logging, SMTP configuration, testing with a local SMTP catcher.
- 08 Security: how security works (roles and page access, procedure-level checks of acting user, status and locks, user protection, password handling, input and output handling, file handling, error handling and logging), recommended hardening for an installation, and known limits stated factually. Review findings and the working security backlog stay in the project docs and Database/README.md; the chapter points to the README for the open list.
- 09 Operations and support: logs (`Log\yyyy_MM_dd_ErrorLog.txt`), common errors and fixes, checks to run, regular tasks, support contact placeholder.
- 10 Testing and release: Test scripts per step, how to run them, expected counts, browser test method, release checklist (including a documentation audit at each release candidate), tagging, version numbers.

## 8. What changes which document (update matrix)
| Change in a step | Update |
|---|---|
| New or changed page or button, message text | the role manuals (screen section, messages, shot list), Overall if a rule changes, Level-1 and program-to-program flow |
| New or changed stored procedure, table, column, Reason code | 04 Database, program-to-program flow, 08 Security if rules change |
| New or changed setting | 06 Configuration, role manuals (Admin), 04 Database |
| Approval, routing, alert or status rule | workflows 1 and 4, Overall, Manager and Controller manuals, program-to-program flow |
| Mail recipients or text | 07 Mail, role manuals (alerts and mails), workflow diagrams |
| Install or step order | 03 Deployment, 10 Testing and release, README run order |
| Documentation audit run | a new Audit/ run folder; the Commit field of documents verified in the run; the WF2 order from the gap register |
| Any step | Release-Notes/CHANGELOG.md (tag, what changed for users, what changed for installers) |

## 9. Quality rules (checked by Claude at the gate)
- Every procedure, setting and Reason code named in an internal document exists in the code (spot check by grep).
- Diagram tables match the diagrams; arrows name the data.
- Message texts in manuals match the code.
- Header block filled; "Verified against" lists real files; "To confirm" holds every unverified claim; Commit filled when the document is verified (warning when empty).
- git status shows only Documents/ changed by the doc-writer, and only the current Audit/ run folder by the doc-auditor.
- No secrets, no real personal data. User manuals contain no internal material (principle 7): a grep of User-Manuals/ for procedure names (spr_, fn_), step numbers, Reason, table names and file paths must find nothing.

## 10. Decisions (owner, 2026-11-09)
1. MD Secretariat and Management: kept in the Overall manual for now; own manuals later.
2. Plain English, second person.
3. Screenshots: the owner takes them (starting now); the doc-writer supplies the shot list and leaves placeholders.
4. Exports: Word and PDF with the "Gashpy Software" label. A client label is decided later.
5. Only the User manuals are shipped with the installation (correction 2026-11-09 16:05); the System manual, Data-Flow and Release-Notes are internal.
6. (2026-11-19, DA1) Documentation audits by the doc-auditor; audit files internal and never exported; empty Commit field is a warning, refused only at a release export.

## 11. Export and branding
- Exports (Word and PDF) are generated from the Markdown sources into Documents/Export/ with the "Gashpy Software" label on the cover and in the header or footer, the document title, version (git tag) and date. Diagrams are rendered as images. The shipped set is the User manuals (each role manual and the Overall manual, with the glossary). Internal documents may be exported for Gashpy Software's own use with the same label, marked Internal; Audit/ files are never exported.
- The export method (tool, template, how Mermaid is rendered) is chosen in the WF2 plan. Exports are generated at release, not at every step; whether Export/ is committed or ignored is decided in WF2 (recommended: ignored in git, produced for each release; only the user manuals go into the installation package).
- Before an export of the user manuals: all "To confirm" lines resolved or removed, status Reviewed by owner, the principle 7 grep clean; for a release export, every exported document has its Commit field filled.

## 12. Document status (two scales, from DA1)
- Existence: Found (written, not a skeleton) / Partial (some required sections written) / Missing (no file, skeleton or stub only).
- Verification: Verified (claims checked against the code at the recorded Commit) / Unverified / Outdated (a claim contradicted by the code).
- Coverage figures: Found and Verified; Found (any); Partial; cells that do not apply are excluded.

## Change record
- 2026-11-09: approved by the owner.
- 2026-11-19: DA1 additions: Commit header field, Audit/ and Standards/ folders, two status scales (section 12), doc-auditor in chapter 02 and the release checklist, hashes and salts in principle 3, update-matrix row for an audit run, decision 6.
- 2026-11-19 18:55: four fragments put in backticks (formatting only) so Check-Documents passes on the repository copy.
