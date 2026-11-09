# BMMS Change Log

- Title: BMMS Change Log
- Audience: Gashpy Software (internal)
- Shipped: No
- Applies to: user-ud1a
- Last updated by: WF2a, based on 021e946
- Status: Draft
- Verified against: git tags and commit subjects (git for-each-ref refs/tags), Database/README.md
- To confirm:

One entry per step, newest first. Each entry names the step, its tag and what changed for users,
for installers and in the database. Release entries (tags vX.Y.Z) collect the steps since the
previous release.

## WF2a - Documents baseline and the doc-writer agent

- Documents/ folder with its index, register, update matrix, header-block rules and skeletons of
  every manual, chapter and data-flow file; the diagram notation and a first glossary.
- The doc-writer agent and the documentation stage in the development workflow.
- Export and check scripts and the Gashpy Software Word template.
- For users: no change. For installers: no change. Database: no change.

## Baseline: state at 021e946

The documents start from commit 021e946 (tag user-ud1a, 2026-11-09). Everything before it is
listed in the appendix below, one line per tag, taken mechanically from git. The step sections
of Database/README.md describe each database step in full.

## Appendix: tags up to the documents baseline

Oldest first. Date is the tag date; subject is the subject of the tagged commit.

| Tag | Date | Subject |
|------------------------|------------|------------------------------------------------------------|
| BMMS-Recovered-Baseline | 2026-10-02 | Recovered BMMS legacy baseline |
| critical-1-7 | 2026-10-11 | Fix request validation and client IDs on .NET 4.8; fix user edit password handling |
| critical-5 | 2026-10-11 | Delete pages: read the procedure Result and show the reference message when a delete is blocked |
| critical-done | 2026-10-11 | Store 'no manager' as NULL; add FK_Users_ManagerId; NULL-safe ManagerId reads |
| ui-pilot | 2026-10-13 | UI pilot: Workbench theme for master page, Login, Department and Meeting |
| ui-batch-1 | 2026-10-14 | UI batch 1: Workbench theme for Designation, Member Type, Subject Type and Decision Type masters |
| db-user-delete | 2026-10-14 | User delete: refuse when the user has history; add 21 user-id foreign keys, tests and test-copy-first run order |
| ui-batch-2 | 2026-10-14 | UI batch 2: Workbench theme for Committee, Member, User and the two member tagging pages |
| user-protection-1 | 2026-10-15 | User protection stage 1: own-account, last Admin/Controller and role limits with reason codes |
| user-status-2a-meeting-locks-1 | 2026-10-16 | UI: inactive users (status column, deactivate/activate, login and per-request checks) and meeting locks (members, attendance, finalization pages) |
| meeting-locks-2 | 2026-10-16 | UI: meeting date/committee lock, agenda lock with Controller option, minutes confirm lock, appointment-date member filter, System Settings page |
| user-status-2b | 2026-10-17 | UI: inactive manager refusal (Reason 11), alert mail to every recipient, no reset mail to inactive users |
| user-system-admin-3 | 2026-10-18 | Stage 3 (step 18): system account in the application |
| member-types-21 | 2026-10-19 | Member type master and tagging pages use scope |
| organisation-settings-19 | 2026-10-19 | Member type master and tagging pages use scope |
| agenda-routing-20 | 2026-10-19 | UI step 20: agenda routing, Dashboard buttons by role, minutes attendance layout |
| minutes-gating-22 | 2026-10-19 | UI step 22: minutes and minutes extract lists only finalized or confirmed meetings |
| meeting-dates-24 | 2026-10-19 | UI step 24: meeting date validation and mail after save |
| report-print-25 | 2026-10-19 | UI step 25: working Print and PDF for the minutes, extract, followup and agenda reports |
| public-files-26 | 2026-10-19 | UI step 26: Notice, Agenda Approval and Sitting Fees PDFs no longer written to the public Files/PDF folder |
| notice-mail-28 | 2026-10-19 | Step 28: Notice Send Mail works; error log keeps the first error of each day |
| workflow-order-23 | 2026-10-20 | Step 23: workflow order messages and page checks |
| reset-safe-29 | 2026-10-21 | Step 29: Reset Database page, 300 s timeout, shared default password |
| smtp-default-30 | 2026-10-23 | Step 30 UI: SMTP page accepts empty login, From required, reset page and dialog mention mail settings, wider email check |
| branding-b2 | 2026-10-23 | Step B2: neutral product branding, remove previous organisation images and unused masters, one product name |
| error-handler-e1 | 2026-10-23 | Step E1: show and log errors on UpdatePanel pages (ScriptManager async error handler, message bar, log entry per error) |
| error-handler-e2 | 2026-10-24 | Step E2: global error handler, fixed error page text, redacted request-validation log |
| error-handler-e2b | 2026-10-24 | Step E2b: Exit returns to the failed page; signed-out visitors go to login |
| branding-b3 | 2026-10-24 | Step B3: product artwork and one colour scheme |
| unicode-text-31 | 2026-10-28 | Database step 31: Unicode text columns (varchar(max) to nvarchar(max)) |
| unicode-text-u1b | 2026-10-28 | U1b: UTF-8 mail and responses, Noto Serif PDF fonts, stop for Tamil/Hindi in PDF |
| dashboard-404-f1-e2c | 2026-10-29 | Step F1 and E2c: Dashboard alert link no longer crashes, fixed Page not found page, no version headers |
| dashboard-f2 | 2026-10-29 | Dashboard: guard hidden-field ids and bad alert data (F2) |
| committee-data-f3 | 2026-10-29 | Committee data layer: no crash on NULL values, date required on save (F3) |
| stored-html-a1a | 2026-10-30 | Step A1a: stored rich text cleaned on save and display, plain text encoded |
| file-names-n1 | 2026-10-30 | Step N1: safe names for uploaded files |
| meeting-gate-m1 | 2026-10-31 | Step M1: meeting Edit and Delete for the whole meeting date; sort header fix; saved but mail not sent message |
| sort-headers-a1b1 | 2026-10-31 | Step A1b-1: unique sort header IDs and sort handlers on seven more grids |
| master-html-a1b2 | 2026-10-31 | A1b-2 groups 1-2: encode master data shown on screen |
| state-master-s1 | 2026-10-31 | S1: complete the State_Master list |
| master-html-a1b3 | 2026-10-31 | A1b-2 group 3: encode grid labels on the backup page and seven reports |
| send-mail-sm1 | 2026-11-01 | SM1: Send Mail attachments as plain files, clearing after send, plain messages |
| agenda-date-m4 | 2026-11-01 | M4: no new agenda items after the meeting date; notice after the submission date |
| mail-after-save-m2-m3 | 2026-11-01 | M2 and M3: send mail only after a successful save; plain warning when the mail fails |
| agenda-edit-delete-m5-n4 | 2026-11-01 | M5 and N4: no edit or delete of agenda items after the meeting date; Finalisation keeps the item's text |
| agenda-dashboard-m6a | 2026-11-01 | M6a: Dashboard Approve and Reject refused after the meeting date |
| meeting-delete-d1 | 2026-11-01 | Step D1: deleting a meeting removes its alerts and refuses past or in-use meetings |
| subjectno-n5 | 2026-11-01 | Step N5: empty Subject No stays empty and an approved item's number cannot be changed |
| file-names-n2 | 2026-11-01 | Step N2: attachment and agenda text names come from the server and are checked where they are read |
| agenda-approval-print-ap1 | 2026-11-02 | AP1: restore Print option on Agenda Approval; PDF lists only Controller-approved items |
| editor-a2a | 2026-11-04 | Step A2a: own rich-text editor on Agenda Entry and Update Minutes |
| editor-a3 | 2026-11-04 | Step A3: own rich-text editor on Dashboard, Followup and Send Mail |
| editor-a4 | 2026-11-04 | Step A4: remove FreeTextBox from the project |
| layout-a2b | 2026-11-05 | A2b: card layout for Agenda Entry and Update Minutes; secondary button states fixed |
| comments-c1 | 2026-11-06 | C1: comment editors by role (Manager and Controller comments editable only by their role) |
| header-popups-h1 | 2026-11-06 | WIP H1: header visible in Dashboard popups (untested) |
| manager-department-c2 | 2026-11-07 | C2: Manager sees and edits department agenda items; Entered by column; server checks |
| names-un2 | 2026-11-07 | UN2: person's name with login tooltip in header; logged-in check by UserId; login ID in access log (step 34) |
| footer-f1 | 2026-11-07 | F1: footer version 1.1.0 from AssemblyInformationalVersion; database name for Admin and Controller |
| names-un3 | 2026-11-07 | UN3: Name (login) in user pickers, Audit Trail and backup list |
| grid-width-g1 | 2026-11-07 | G1: User Master grid fits inside its card; sort arrow stays with its heading |
| viewstate-pw1 | 2026-11-07 | PW1: password hash no longer kept in the User Master list |
| names-un4 | 2026-11-08 | UN4: who and when on Manager/Controller comments (step 35); M7: Add shows Meeting No, not MeetingId |
| alerts-al1 | 2026-11-08 | AL1: an edited agenda item re-alerts the next approver (step 36); header counts unread alerts only |
| mail-ml1 | 2026-11-08 | Step ML1 (step 37): mail when an agenda item is updated |
| mail-ml1b | 2026-11-08 | Step ML1b: an Entry item keeps no agenda text file name |
| mail-ml2a | 2026-11-08 | Step ML2a: keep the configured Bcc and send each address once |
| mail-ml2b | 2026-11-09 | Step ML2b: comment, Subject No and date format in the agenda mails |
| user-um2 | 2026-11-09 | UM1+UM2: User Master email accepts digits, capitals and hyphen (50 characters); user grid keeps Edit, Deactivate and Delete inside the card |
| user-un6a | 2026-11-09 | UN6a (step 38): due date for Followup decisions on Update Minutes |
| user-un6a1 | 2026-11-09 | UN6a1: due date not passed keeps the stored date; build works with or without step 38; clearer save message |
| user-ml2c | 2026-11-09 | ML2c: a bad To or Bcc address is skipped and logged, the mail fails only when nobody valid is left (Reset Password and Notice need a valid To); one shared helper for reading the item after save |
| workflow-wf1 | 2026-11-09 | WF1: reviewer subagents (security, UX, UI) and development workflow in CLAUDE.md |
| user-ud1a | 2026-11-09 | UD1a: user role and department history, multi-department Managers (step 39) |
