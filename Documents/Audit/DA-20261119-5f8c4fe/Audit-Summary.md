# Audit Summary DA-20261119-5f8c4fe

- Title: Audit Summary DA-20261119-5f8c4fe
- Audience: Gashpy Software (internal)
- Shipped: No
- Applies to: DA-20261119-5f8c4fe
- Commit: 5f8c4fe
- Last updated by: DA DA-20261119-5f8c4fe
- Status: Draft
- Verified against: Documents/Standards/documents-spec.md, Documents/README.md, Documents/Audit/README.md, the Markdown files under Documents/, the catalog of BMMS_Test (catalog.txt, installed-steps.txt, columns.txt, foreign-keys.txt, indexes.txt, modules), BMMS/XML/PageAccess.xml, BMMS/UserControl/MenuUserControl.ascx, BMMS/UserControl/MeetingSummary.ascx(.cs), BMMS/DashBoard/DashBoard.aspx(.cs), BMMS/Master/Followup.aspx(.cs), BMMS/Report/*.aspx.cs, BMMS/PageAccessModule.cs, Default.aspx.cs, Global.asax.cs, MasterPage/Main.Master.cs, BMMS/FollowupStatusText.cs, BMMS/Web.config, BMMS/CSS/bmms-workbench.css, BMMS.sln, BMMS.csproj, BMMSBAL (UserMgr.cs, MeetingMgr.cs, ReportsMgr.cs, HTML_Report.cs, ActionItemMgr.cs, Common.cs), BMMSDAL, Tests/_runner, Tests/packs, Tests/package.json, .claude/agents and hooks, git for-each-ref, Database/ Fix scripts of steps 20, 42, 44, 45, 48, 49, 51 and 52 and the Database/ file list
- To confirm: the depth limits under "Not checked" (the part 1 and part 2 procedure tables of System-Manual/04-Database.md, lines 393 to 957 of System-Manual/05-Application-Code.md and the Test script counts of chapter 10 were checked by search of names, Reason codes and counts only, not line by line); every module of the catalog except eight against its newest Fix script

## Return record

```
Run: DA-20261119-5f8c4fe   Commit: 5f8c4fe   Catalog: 2026-11-19, highest installed step 52 (plus D1)
Files written: Audit-Summary.md, Coverage-Matrix.md, Gap-Register.md, Drift-Register.md
Coverage overall: Found+Verified 9.6%, Found 57.3%, Partial 16.8%
Gaps: 43 (Critical 5, High 12, Medium 19, Low 7); new 43, closed 0, still open 0
Drift items: 43 (Outdated 29, To confirm 14)
Documents done: 21 of 21 (20 drift-checked, the CHANGELOG is history with Existence only); finished: yes (to the depth under "Not checked")
Stubs needed (documents the standard requires with no file): None
Documents not done: None
Not checked: see "Not checked" below
```

## Traceability

| Item | Value |
|---|---|
| Repository | github.com/gashpy64/BMMS-Legacy |
| Branch | modernization |
| Commit SHA | 5f8c4fe |
| Audit date | 2026-11-19 |
| Agent | doc-auditor (sonnet) |
| Run id | DA-20261119-5f8c4fe |
| documents-spec date | 2026-11-19 (header of Documents/Standards/documents-spec.md: updated 2026-11-19 for DA1; the last change record line is 2026-11-19 18:55) |
| Catalog date | 2026-11-19 (export 18:59:02), SQL Server 17.0.1000.7 Express, compatibility level 100, database BMMS_Test (catalog server name: `<server>`) |
| Highest installed step | 52 (numbered steps 1 to 24, 29, 30, 31, 33 to 52, plus step D1 shown as 100); the Check script reports one note: the From Mail Id of SMTP Configuration is not the mail sender user's address (environment of BMMS_Test, not a document matter) |
| Previous run | none |

The audit ran in four sessions: the first stopped on a usage limit before writing any file; the second read the
standard and the documents and wrote the four files; the third ("continue DA-20261119-5f8c4fe") carried on the drift
check; this fourth session ("continue DA-20261119-5f8c4fe" again: the same commit 5f8c4fe, checked with git rev-parse
before starting, and the same catalog date 2026-11-19, 18:59:02, read from catalog.txt) finished the seven documents
not done and rewrote the four files whole. The working tree holds uncommitted changes to Documents/README.md,
CLAUDE.md and the build scripts (git status at HEAD 5f8c4fe); the audit compares the documents as they stand in the
working tree.

## Coverage figures

Rows are the 17 areas of the matrix, columns as defined by the task. n/a cells are left out. Formulas:
Found+Verified % = cells Found and Verified / applicable cells; Found % = cells Found or Partial / applicable
cells; Partial % = cells Partial / applicable cells. The CHANGELOG cells have no Verification, so they cannot be
Found and Verified: for the overall Found+Verified figure the denominator leaves them out (114 cells), for the
other two overall figures all 131 applicable cells count.

| Group | Applicable cells | Found and Verified | Found or Partial | Partial | Found+Verified % | Found % | Partial % |
|---|---|---|---|---|---|---|---|
| User manuals (00 to 04) | 55 | 6 | 20 | 14 | 6 / 55 = 10.9% | 20 / 55 = 36.4% | 14 / 55 = 25.5% |
| System manual (chapter and Database chapter) | 34 | 4 | 31 | 2 | 4 / 34 = 11.8% | 31 / 34 = 91.2% | 2 / 34 = 5.9% |
| Data flow (Program-to-Program and Workflow) | 25 | 1 | 7 | 6 | 1 / 25 = 4.0% | 7 / 25 = 28.0% | 6 / 25 = 24.0% |
| Release notes (CHANGELOG) | 17 | n/a | 17 | 0 | n/a | 17 / 17 = 100.0% | 0 / 17 = 0.0% |
| Overall | 131 (114 without CHANGELOG) | 11 | 75 | 22 | 11 / 114 = 9.6% | 75 / 131 = 57.3% | 22 / 131 = 16.8% |

Counts behind the groups: user manuals, 29 n/a cells (01: 11, 02: 9, 03: 4, 04: 5), Found 6, Partial 14, Missing 35;
system manual, Found 29, Partial 2, Missing 3; data flow, Found 1, Partial 6, Missing 18; CHANGELOG Found 17.
Found and Verified cells (11): the Dashboard and alerts cell of each of the five manuals (00 to 04), the Followup
cell of 03-Controller, SM/04-Database in Login and session, User Master, Followup, Dashboard and alerts, and (new in
this session) P2P/09 in Followup. (Partial and Verified, not counted as Found and Verified: UM/00, 01, 02, 03
Meetings and Agenda approval where the manual has them, UM/04 Page access and Meetings; P2P/01 Login and session;
WF/04 Agenda approval and Dashboard and alerts.) Cells that moved to Outdated: SM/01 in Login and session and in Page
access; P2P/10 Reports; WF/02 Meetings; and, in this session, P2P/09 Dashboard and alerts, SM/05 Reports and SM/05
Dashboard and alerts. The Outdated cells are still counted Found or Partial.

Reading: the structure is complete (every file the standard requires exists) but most Data-Flow files, three
System-Manual chapters and almost all of the five shipped user manuals are skeletons or partial. The Dashboard
screens of all five role manuals agree with the code and the catalog: the Verified share is still low mainly
because the written parts of the manuals are few and because six of the eight System-Manual chapters carry at least
one stale statement. The Outdated items (29) are listed in the Drift register.

## Documents and their status

Existence and the Verification reached in this run (Verified means: every claim checked in this run holds; the checks
are listed in the Drift register). The four infrastructure documents (Documents/README.md, Audit/README.md,
Standards/documents-spec.md, Export/README.md) are not part of the 21 counted below.

| Document | Existence | Verification | Claims checked in this run |
|---|---|---|---|
| User-Manuals/00-Overall.md | Partial | Verified for the written Dashboard, My approvals, Meeting status sections; the MD Secretariat and Management report text is Unverified in part | about 60 (status table, role table, cards, My approvals, alerts, action items, messages, MD Secretariat read-only Followup, Management menu) |
| User-Manuals/01-User.md | Partial | Verified (Dashboard section) | about 35 (messages, counts, completed list rule, Action Items scope, Reopened and Overdue chips, 1240 pixel rule) |
| User-Manuals/02-Manager.md | Partial | Verified (Dashboard section) | about 45 (My approvals rule, Waiting for me, messages, department drop-down, panel texts, CSS rules) |
| User-Manuals/03-Controller.md | Partial | Unverified: the claim that Export to Pdf cannot print Tamil or Hindi is not shown by the code; the rest holds | about 65 (Dashboard, Followup screen and its 25 messages, report messages, draft note, Followup by Department access) |
| User-Manuals/04-Admin.md | Partial | Verified | 27 (first run) |
| User-Manuals/Glossary.md | Found | Outdated (the routing term) | about 25 (roles, menus, terms) |
| System-Manual/01-Overview-and-Architecture.md | Found | Outdated | about 30 (three Outdated: page count, procedure count, request check; line numbers of the Interop note) |
| System-Manual/02-Development-Environment.md | Found | Outdated (the branch list and base commit, lines 102-107); also Unverified in part (the SQL Server edition, the build commands) | about 60 (tools and versions, BMMS.sln, csproj, #Requires lines, Tests/package.json, the tester tool lookups, memory reading, agents and guard options, the workflow list against CLAUDE.md, branches; no mention of doc-auditor: gap DA-G-034) |
| System-Manual/03-Deployment-and-Installation.md | Found | Outdated (run-order table ends at step 46, Check script rows stop at step 42, snapshot counts, "Rollback scripts for steps 33 to 42 only") | about 75 (script names of steps 33 to 52, marker counts of steps 39 to 52, Web.config lines, hidden segments, guards of the Fix scripts, the rollback table) |
| System-Manual/04-Database.md | Found | Outdated (the 2026-11-09 snapshot counts, Reason range "1 to 25", the Agenda index limitation, the THROW count) | about 110 (table and key sections, Reason codes 1 to 28 against the catalog modules, step 50 indexes, step 51 and 52 sections, settings rows, limitations rows; the procedure tables of parts 1 and 2 by name only) |
| System-Manual/05-Application-Code.md | Found | Outdated (five stale statements: roles of two report pages, summary cards "planned", RequireRole read, GoToErrPage count, Convert.ToInt16 in Session_End); step 52 not reflected: gap DA-G-038 | about 90 (page and folder counts, master pages, roles of the page tables, Dashboard method and control names, session keys, PageAccessModule bullets, error handling, limitations table; lines 393-957 by name search only) |
| System-Manual/06-Configuration-and-Settings.md | Missing | n/a | n/a |
| System-Manual/07-Mail.md | Partial | Unverified (one claim, the alert rows for Admins until step UD1b, not verified) | 12 (the two recipient procedures, callers, Reason 14, spr_GetAgendaApprovalState) |
| System-Manual/08-Security.md | Partial | Outdated (three: MD Secretariat counts, the approval procedure date rule, the THROW count) | about 110 (page protection layers, RequireRole pages, HasRole, session check, Dashboard procedure Reasons, the step 46 to 49 Followup paragraphs against the catalog procedures, the Triple DES and DPAPI routines) |
| System-Manual/09-Operations-and-Support.md | Missing | n/a | n/a |
| System-Manual/10-Testing-and-Release.md | Partial | Unverified (no stale statement found; the check counts of the Test scripts and the tester run records are as given for each step) | about 70 (the Test script files, the seven packs, the packs row, memory reading, results folder, expected.csv rows, marker counts, Update-Baseline guards, page-assets limit, the page history) |
| Data-Flow/00-Notation.md | Found | Outdated (source citation) | 12 |
| Data-Flow/01-Context.md | Missing | n/a | n/a |
| Data-Flow/02-Level1-Modules.md | Missing | n/a | n/a |
| P2P/01-Login-and-Session.md | Partial | Verified | 30 (first run) |
| P2P/02 to 08, 11 to 14 (11 files) | Missing | n/a | n/a |
| P2P/09-Dashboard-and-Alerts.md | Partial | Outdated (two: the Agenda index, the OUTPUT count) | about 120 (every procedure and function name, the Reason tables 4, 8, 12, 14, 26, 27, 28, the message texts, the method and control names, the step 52 rows, the status columns, the roles of the statistics) |
| P2P/10-Reports.md | Partial | Outdated | about 45 (names, messages, orders, access rules; one Outdated) |
| WF/01, 03, 05, 06 | Missing | n/a | n/a |
| WF/02-Meeting-Life-Cycle.md | Partial | Outdated | 20 |
| WF/04-Alerts.md | Partial | Verified | 35 (whole file) |
| Release-Notes/CHANGELOG.md | Found | n/a (history) | headings only |

The 21 documents with a drift check due are the Found or Partial files: 6 user manual files, 8 System-Manual chapters
(01 to 05, 07, 08, 10), Data-Flow/00-Notation, P2P/01, 09, 10, WF/02, WF/04 and the CHANGELOG (the CHANGELOG is
history: its claims are not compared).

## Top Critical and High gaps

| Id | Document | Gap | Priority |
|---|---|---|---|
| DA-G-028 | User-Manuals/00-Overall.md | five CONFIRM sections (purpose, roles matrix, life cycle, statuses, help) | Critical |
| DA-G-029 | User-Manuals/01-User.md | all sections but the Dashboard not written | Critical |
| DA-G-030 | User-Manuals/02-Manager.md | all sections but the Dashboard not written | Critical |
| DA-G-031 | User-Manuals/03-Controller.md | all screens but Dashboard and Followup not written | Critical |
| DA-G-032 | User-Manuals/04-Admin.md | all screens but the Dashboard not written (User Master, masters, settings, backup, reset, audit) | Critical |
| DA-G-004 | P2P/02-User-Master.md | skeleton | High |
| DA-G-006 to DA-G-010 | P2P/04 Agenda Entry and routing, 05 Approval, 06 Finalisation and mail, 07 Meeting, 08 Minutes | skeletons (the core business flows) | High |
| DA-G-016 | P2P/14-Mail-Sending.md | skeleton | High |
| DA-G-017, DA-G-019 | WF/01 Agenda life cycle, WF/03 Minutes life cycle | skeletons | High |
| DA-G-023 | System-Manual/06-Configuration-and-Settings.md | skeleton | High |
| DA-G-024, DA-G-025 | System-Manual/07-Mail.md, 08-Security.md | partial | High |

Gap totals: 43 (Critical 5, High 12, Medium 19, Low 7). The full list with evidence is in Gap-Register.md. New in this
session: DA-G-041 (chapter 03 rollback section), DA-G-042 (chapter 02 branches), DA-G-043 (five stale facts in chapter 05).

## Stubs needed

None. Every document the standard requires has a file (documents-spec.md section 2 layout, the 14 areas of 5.2, the 6
workflows of 6). The skeletons are counted Missing and are listed as gaps DA-G-001, 002, 004 to 010, 013 to 017, 019,
021 to 023, 026; no new file is needed, so the doc-writer makes no stub from this run.

## Drift

43 items in Drift-Register.md: Outdated 29, To confirm 14.

- Outdated (first session): System-Manual/01-Overview-and-Architecture.md:67 (47 pages, the site has 44);
  System-Manual/03-Deployment-and-Installation.md:325 (Check script row list stops at step 42, the catalog shows rows
  to step 52); System-Manual/03-Deployment-and-Installation.md:242 (the run-order table stops at step 46).
- Outdated (second and third sessions): Glossary.md:36-38 (routing term); 01-Overview:126 (157 spr_ procedures, catalog
  178), :171-173 (the request check before step 51), :204 (line numbers of the commented Word calls); 04-Database:111,
  122, 439 (module counts) and :112 (33 tables, catalog 34); 08-Security:157 (MD Secretariat counts not computed),
  :189-192 (the approval procedure does not look at the date), :26 and :144 (24 procedures use THROW, the catalog has
  23 procedures); WF/02:77-78 (counts not shown to MD Secretariat); P2P/10:250-251 (the module reads the user through
  GetUserDataTableByUserId); 00-Notation:9-12 and 113 (source of fn_ManagerReleaseRefusal and spr_AddEditUser).
- Outdated (this session, 14 items): 02-Development-Environment:102-107 (branches and base commit);
  03-Deployment:452 and 466-471 (Rollback scripts "for steps 33 to 42 only", the catalog of Database/ holds them for 33
  to 52) and :75-77 (snapshot counts); 04-Database:113, 115, 123-124 (foreign key, primary key, check and default
  counts), :1465 (Reason codes "1 to 25"), :1708 (Agenda index "open, planned"), :1706 (THROW count);
  05-Application-Code:135 and 140 (roles of Report/Followup and Report/Reports), :151 (summary cards "planned"),
  :1057-1059 (RequireRole reads GetUserDataTableByUserId), :1105 (164 GoToErrPage call sites, now 169 in 37 files),
  :1173 (Convert.ToInt16 in Session_End); P2P/09:169-170 (Agenda index) and :238 (six OUTPUT values, five).
- Modules against the Fix scripts: eight compared, all equal after normalising line endings and trailing spaces:
  fn_ManagerReleaseRefusal (Step 52), spr_GetUserAccessState (Step 51), fn_FollowupStatusLatest (Step 49),
  spr_GetDashboardApprovals (Step 45), fn_AgendaWaitingFor (Step 44), fn_AgendaRoute (Step 20),
  fn_MeetingDashboardState (Step 42), fn_DashboardActionItems (Step 48). Not compared: the rest of the 186
  procedures, 13 inline table functions, 3 scalar functions and 11 views, among them spr_AddEditUser,
  spr_SetUserStatusByUserId and spr_UpdateAgendaByAgendaId of step 52 (the auditor has no tool to diff two files).
  "Baseline, no script": not determined in this run (it needs the comparison of every module); the Reset Database
  procedure was not read or quoted.
- Observation, not drift: the catalog holds 24 THROW statements in 23 modules (spr_sys_ResetDatabase has two); the
  house rule says no THROW at compatibility level 100; chapter 08 lists the decision as an open point.
- Open finding of the documents, not drift: System-Manual/04-Database.md:1707 names seven procedures the data layer
  calls that are not in the catalog (confirmed absent); the document already lists them as open.

## Documents done

All documents with a drift check due (a continuation need not repeat any of them):

1. Documents/Data-Flow/03-Program-to-Program/01-Login-and-Session.md
2. Documents/User-Manuals/04-Admin.md
3. Documents/User-Manuals/00-Overall.md
4. Documents/User-Manuals/01-User.md
5. Documents/User-Manuals/02-Manager.md
6. Documents/User-Manuals/03-Controller.md
7. Documents/User-Manuals/Glossary.md
8. Documents/System-Manual/01-Overview-and-Architecture.md
9. Documents/System-Manual/07-Mail.md
10. Documents/Data-Flow/00-Notation.md
11. Documents/Data-Flow/03-Program-to-Program/10-Reports.md
12. Documents/Data-Flow/04-Workflows/02-Meeting-Life-Cycle.md
13. Documents/Data-Flow/04-Workflows/04-Alerts.md
14. Documents/System-Manual/02-Development-Environment.md (this session)
15. Documents/System-Manual/03-Deployment-and-Installation.md (this session)
16. Documents/System-Manual/04-Database.md (this session, to the depth under "Not checked")
17. Documents/System-Manual/05-Application-Code.md (this session, to the depth under "Not checked")
18. Documents/System-Manual/08-Security.md (this session)
19. Documents/System-Manual/10-Testing-and-Release.md (this session)
20. Documents/Data-Flow/03-Program-to-Program/09-Dashboard-and-Alerts.md (this session)

Release-Notes/CHANGELOG.md is history: Existence only, no comparison planned. That makes 21 of 21.

## Documents not done

None. The run is finished; there is nothing to continue. The depth limits that remain are listed under "Not checked".

## Claims checked per document

See the table "Documents and their status" (column "Claims checked in this run"). Total claims checked: about 1,000
(first session about 98, second session about 460, this session about 460).

## Assumptions

- "Existence" for a manual with real text for one section and CONFIRM lines for the rest is Partial; a file of only
  headings and CONFIRM lines (23 lines in Program-to-Program, 17 in Workflows, 19 in chapter 09, 45 in chapter 06;
  counted without blank lines) is Missing. A written Dashboard section alone is Partial for the areas it does not
  cover and Found only for the Dashboard row.
- "Verified" was given to a cell whose written claims were all compared in this run. Any other cell with text is
  Unverified, with the "To confirm" in the Drift register. A claim about a screen's colour or weight was compared
  with the CSS rule that sets it (bmms-workbench.css lines 1094, 1290, 1296, 1302), not with a browser.
- The role rules for the n/a cells come from BMMS/XML/PageAccess.xml and MenuUserControl.ascx at HEAD. Where the
  standard (section 4.2) differs from the code (User and Update Minutes, User and Reports), the code was followed and
  the difference is gap DA-G-036.
- The Program-to-Program Followup flow is cited in P2P/09 (the Followup page sections) because no file of its own
  exists for it in the standard.
- The CHANGELOG entry per area before RA1a is cited as "Baseline section"; only the headings from RA1a up were read.
- The catalog (BMMS_Test) was taken as the installed state; BMMS_Test holds step 52 and D1, the same as the code at HEAD.
- The compared modules differ from the scripts in the first keyword only (CREATE against CREATE OR ALTER): SQL Server
  stores CREATE; not counted as drift.
- A count in a chapter that names the export of 2026-11-09 is compared with the export of 2026-11-19 and recorded
  Outdated when it differs, because the chapter describes "the catalog export" as the source of the current state.
- The number of spr_ procedures in the catalog (178) is derived: 186 procedures less the 7 sp_ diagram procedures and
  the one procedure without a prefix (GetCommitteeMemberByMeetingId).
- Test results, tester run records and owner's test records quoted in chapter 10 and the per-step sections are history
  "as given for the step"; they are not current behaviour and were not recounted (the auditor does not read
  Tests/_results).
- Matching 55 addresses in Tests/packs/access-matrix/expected.csv was done by pattern: 54 .aspx rows plus the png row.

## Not checked

- Every module of the catalog against its newest Fix script, except eight; the "baseline, no script" modules.
- System-Manual/04-Database.md: the column lists of lines 130-300 against columns.txt; the procedure tables of part 1
  and part 2 (lines 565-1303: parameters, writes, step markers) except the rows named in the Drift register; the Fix
  script text of spr_AddEditUser, spr_SetUserStatusByUserId and spr_UpdateAgendaByAgendaId against the catalog.
- System-Manual/05-Application-Code.md lines 393-957 (Followup panel and page saves, the reports and ViewState
  sections, the stylesheet stamp, the pages in no menu, the BAL and DAL class lists, the messages): names only.
- System-Manual/10-Testing-and-Release.md: the check counts of each Test script and the counts of the tester runs.
- System-Manual/03-Deployment-and-Installation.md: the step sections (lines 476 to 1131) against the Fix, Rollback and
  Test scripts line by line (only names, marker counts and the guards of steps 39, 44 and 52).
- Data-Flow/03-Program-to-Program/09-Dashboard-and-Alerts.md: the sequence diagrams of steps 42, 44 and 45 and the
  "Tables read" lists against the Fix scripts.
- The CHANGELOG entries (history; only headings read), the Release notes cells therefore have Existence only.
- The register of Documents/README.md, the Audit/README.md, the Standards copy and Export/README.md (infrastructure, not
  counted).
- Browser behaviour, print and Export to Pdf, Word output and screenshots (the images folder is empty by design).
- The security review of this run folder (step 6 of Audit/README.md belongs to the main session).

## Comparison with the previous run

No previous run. Gaps: new 43 (DA-G-001 to DA-G-043), closed 0, still open 0. Next free id: DA-G-044.
