# Access-matrix pack (step WF3a2)

The pack proves on every run that what each role can open matches the owner's access rules, and
that it fails when it does not.

## Files

| File | What | Who changes it |
|---|---|---|
| `expected.csv` | One row per address, one column per role, and the rule each row comes from. | The owner, or Claude on the owner's instruction (the build report lists it under "expectations changed"). Never the tester. |
| `not-in-menu.csv` | Pages a role can open but reaches without a menu link, each with its reason. | The owner (an approved list). |
| `home-link.csv` | Which roles have the Home link in the menu bar. | The owner. |
| `planted.json` | The one change to `PageAccess.xml` in the site copy that the standing proof makes. | Claude, in a reviewed step. |
| `pack.js` | The checks. | Claude, in a reviewed step. |

## Columns and cell words

Columns: `admin` (qa_admin), `controller` (qa_ctrl), `manager` (qa_manager), `user` (qa_user),
`mgmt` (qa_mgmt, Management), `mdsec` (qa_mdsec, MD Secretariat), `inactive` (qa_inactive), and
`visitor` (a browser that is not signed in).

| Cell | Meaning |
|---|---|
| opens | The page asked for comes back (HTTP 200). No DENIED line in the page access log. |
| Access denied | The "Access denied" page (HTTP 403), and exactly one DENIED or DENIED-PAGE line for that user and page in the page access log. |
| sign-in page | The browser ends on the sign-in page. |
| Page not found | HTTP 404 with a "not found" page. |
| owner to decide | No written rule decides the cell. The run shows what the site does, and the cell counts as failed until the owner decides it. (None left since 2026-11-11.) |
| to be removed (RA1c1) | The page goes in step RA1c1. The run does not open it (Event Calendar runs out of memory on a GET); a note in the results, never a failure. |
| to be decided (RA1c2) | The owner decides the cell in step RA1c2. The run opens the page and shows what it does; a note, never a failure. |

`page_rule`: `RA1b` marks the rows whose page narrows the roles of PageAccess.xml by its own
check (the report code `rc`, the followup code `fc`, the report kind of ViewReport); `missing on
purpose` marks the two addresses that do not exist (Q5).

## The rules (owner, plan WF3a2, 2026-11-11)

The `rule` column of every row names the rules below by their short names.

- **P (OWNER PRINCIPLE):** Admin is superior for the technical items (users, passwords, backup,
  audit trail, reset, system and mail settings). The Controller is superior for the functional
  items (committees, members, meetings, agenda, minutes, attendance, reports, follow-up) and has
  all functional rights.
- **R1 (Admin only, nine pages):** Department, Designation, MemberType, SubjectType,
  DecisionType, User, ResetPassword, BackupDatabase, Report/AuditTrail.
- **R2:** Admin also has SMTP Configuration, System Settings, Reset Database.
- **R3 (Controller):** Committee, Member, Meeting, Committee Member Tag/UnTag, Meeting-Member
  Tag/UnTag, Attendance, Reports (Minutes in all statuses, Minutes Extract, Agenda Summary,
  Agenda Details, Followup). **R3n:** the Controller does NOT have User Master, the five
  reference masters, Reset Password, Backup Database, Audit Trail.
- **R4 (Management):** Reports Minutes (rc=minutes only), Followup, Followup Summary, ViewReport;
  Minutes Extract, Agenda Summary and Agenda Details are refused. All signed-in roles reach the
  Dashboard. Home link: corrected by the owner on 2026-11-11 (the first text said Management has
  none, which was wrong): Management HAS the Home link (the owner's sheet and the code agree); only
  Admin and MD Secretariat have none.
- **R5 (Manager and User):** as in Database\README.md, sections RA1a and RA1b, and the existing
  PageAccess.xml; where a cell cannot be decided from a written rule it is marked "owner to
  decide" (listed below).
- **Q3:** ViewReport.aspx opened directly: the run shows what it does for each role (decided
  2026-11-11, see below). ReportPrint.aspx is marked "to be removed (RA1c1)" and is not a failure.
- **Q4:** Logout.aspx is opened last for each role.
- **Q5:** one missing .aspx and one missing file that is not a page; the cells come from what
  the run shows and are reviewed by the owner.
- **V/I:** a visitor who is not signed in is sent to the sign-in page for every page but the
  public ones; qa_inactive cannot sign in (its sign-in is refused with "Your account is
  inactive"), so its column is the visitor's (owner, answer 2; a user made inactive during a
  session comes later with RA1d).

Written rules the draft also cites (Database\README.md and the code comments of earlier steps):

- **W1:** the sign-in page, Logout and the error page are public (PageAccessModule, rule 1).
- **W2:** the error page sends a visitor who is not signed in to the sign-in page (step E2b).
- **W3:** every user changes the own password on Change Password (header link; RA1a "It changes
  only its own password").
- **W4:** after Reset Password, the first sign-in of any role asks for a new password
  (ChangePasswordFirst.aspx; RA1a test users).
- **W5:** Admin's Master menu shows all twelve items (RA1a browser check 1), so Admin opens the
  six committee and meeting masters too.
- **W6:** MD Secretariat works on Followup (Minutes menu; step A2 browser checks).
- **W7:** Error/TestPage.aspx is a leftover; nobody may open it; remove it with RA1c (step WF3a1).
- **W8:** Logout ends the session and shows the sign-in page.
- **RA1b:** the code rules of step RA1b: Reports.aspx refuses any rc other than minutes,
  minutes_extract, agenda_summary and agenda_details (and no rc); rc=minutes for Controller,
  Manager and Management, the other three for Controller and Manager; Followup.aspx refuses any fc
  other than followup and summary (and no fc), and is for Controller and Management.

Drafting rule (Claude's; confirmed by the owner on 2026-11-11):

- **D0:** a role has a page only when a written rule above gives it; otherwise "Access denied".
  It decides the Admin and MD Secretariat cells of the functional pages and reports that no rule
  above gives them, and the Management cells beyond R4's list.

## The cells the draft left to the owner, and the owner's decisions (2026-11-11)

| Address | Cells | Decision |
|---|---|---|
| Report/EventCalendar.aspx | every cell | "to be removed (RA1c1)": the page is removed in RA1c1; a note, not a failure. |
| Report/ReportPrint.aspx | every cell | "to be removed (RA1c1)", as above. |
| Report/FollowupActionTaken.aspx | controller, manager | "to be decided (RA1c2)": a note, not a failure. |
| Report/ViewReport.aspx | controller, manager | "opens": opened directly (no report kind) the page shows "The report is no longer available". Management "Access denied". Today the Controller and the Manager get HTTP 500: a real failure, a product defect fixed in RA1c1. |
| Report/ViewReport.aspx?pdf=1 | controller, manager | "opens" (the same decision; this address already shows "The report is no longer available"). |
| Master/NoSuchPage.aspx, Images/no-such-file.png | every cell | "Page not found" as the first run showed (HTTP 404 for every column, no DENIED line: a missing page never reaches the access check); the owner keeps them as observed. |

## What the pack checks

1. **The files:** every cell is one of the words above, every row has a rule, every row of
   `not-in-menu.csv` has a reason, no address twice.
2. **Pages on disk:** every .aspx page of the site is in `expected.csv` or in PageAccess.xml; a
   page in neither fails the run. A page in `expected.csv` but not in PageAccess.xml is reported
   (the module refuses it to every role).
3. **Agreement with PageAccess.xml:** each decided cell is compared with what the XML lets
   through. A difference is a failed check, for the owner to decide (the XML or the cell). On the
   `RA1b` rows only a cell that opens where the XML refuses counts, because those pages narrow
   the XML's roles themselves.
4. **The matrix:** each role opens each address (Logout last); what comes back and the page
   access log are compared with the cell.
5. **The menu:** each role's links (menu bar, its drop-down lists, the header) are read on the
   Dashboard. Every link must be an address in `expected.csv` that opens for that role; every page
   a role opens must have a link or a row in `not-in-menu.csv`; a row there that no longer applies
   fails too; the Home link must match `home-link.csv`.
6. **The standing proof (every run, before the matrix):** Run-Tests.ps1 adds `user` to the entry
   of Report/MeetingCalendar.aspx in `Tests\_site\XML\PageAccess.xml` only, runs the rows of
   `planted.json` for every column and puts the working tree's file back in a finally block.
   Exactly the cell qa_user / Meeting Calendar must fail ("Access denied" expected, "opens"
   seen). At the end of the run the hash of `Tests\_site\XML\PageAccess.xml` is compared with the
   working tree's file; a difference, or any other result of the proof, makes the run VOID.

Nothing in this pack changes a cell to make a run pass. A cell the site does not match is reported
to the owner as it is.
