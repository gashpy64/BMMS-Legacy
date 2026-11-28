# Followup reports pack (step FU2b)

The pack proves on every run that the Followup reports show who confirmed or reopened each followup, with the
texts of the Followup page (owner decision FU2b, 2026-11-17; Database\README.md, section "Step FU2b"): Followup
and Followup Summary (Report/Followup.aspx, fc=followup and fc=summary) for the Controller and Management, and
Followup by Department (Report/FollowupActionTaken.aspx) for the Controller. The rows come from
BMMS-Fix-FollowupReports-Step49.sql (spr_GetFollowupReport, spr_GetFollowupByDepartmentReport); that the rows,
their order and the filters are those of before is proven by BMMS-Test-FollowupReports-Step49.sql (parity).

## Files

| File | What | Who changes it |
|---|---|---|
| `expected.json` | The accounts (`controller`, `management`), the name the pages show for the Controller (`controllerName`), the committee chosen (`committee`), the row confirmed (`confirmRow`) and the row confirmed and reopened (`reopenRow`, its meeting number `reopenMeetingNo`, the reason typed `reopenReason`), the labels of Confirmed Status (`confirmLabels`), the header of the grids' status column (`statusHeader`, "Followup status"), the messages of the Followup page (`confirmedTwo`, `reopened`). | The owner, or Claude on the owner's instruction (the build report lists it under "expectations changed"). Never the tester. |
| `pack.js` | The checks. | Claude, in a reviewed step. |

## The data

The fixture (Tests\fixture): QA Test Committee, meeting 00005, agenda 002 (QA1-00005-002) and meeting 00006,
agenda 001 (QA1-00006-001), both Pending. The pack confirms both in one Submit on the Followup page and reopens
QA1-00006-001 with the reason `QA FU2b reopen & "check" 'q' <5` (the page lets "<" followed by a digit through).
QA1-00005-001 is the row of the dashboard and followup packs; this pack reads only its own two rows. Run it after
the followup pack.

## Checks

1. Set-up, qa_ctrl, Followup page: "2 followups were confirmed.", then "The followup was reopened.".
2. Followup, qa_ctrl: the Confirmed Status choices Both, Confirmed, Pending. View: a "Followup status" column and no
   Minutes status column; QA1-00005-002 "Confirmed" and "Confirmed by QA Controller (qa_ctrl) on [dd-MMM-yyyy HH:mm]";
   QA1-00006-001 "Pending" and "Reopened by QA Controller (qa_ctrl) on [date]: [reason]" (the reason as typed,
   shown as text). Pending chosen: QA1-00006-001 listed, QA1-00005-002 not, every row "Pending". Generate (the
   report in ViewReport.aspx, read in a second window of the same session): one FOLLOWUP STATUS block per row of
   View, with the Confirm line and the reopen line.
3. Followup Summary, qa_ctrl: View shows the word only, no line. Generate: the "Followup status" column holds only
   "Pending" and "Confirmed" (one cell per row of View), no "Reopened by" and no FOLLOWUP STATUS block.
4. Followup, qa_mgmt: View has the "Followup status" and the Minutes status columns, the same rows, and QA1-00006-001's reopen
   line. Generate: one FOLLOWUP STATUS block and one "Minutes status:" line per row, and the reopen line.
5. Followup by Department, qa_ctrl, meeting 00006, every department: View has a "Followup status" column with QA1-00006-001's
   word and reopen line and no message; Print, Generate Report: the report has "Pending" and the reopen line.

Not in the pack:

- Export to Pdf and Export to Word: the pack reads the report as the browser shows it (Print); the downloads are
  owner checks (a reason of 500 characters without spaces in Word, too).
- The refusals of the two procedures (Reason 8 and 4 for every role) and the parity of the rows, their order and
  every filter combination: BMMS-Test-FollowupReports-Step49.sql. Who may open the pages: the access-matrix pack.
- "Confirmed (before history)", an inactive name and "an unknown user": the fixture has none; the Test script
  proves the status columns of those cases, an owner check on BMMS_Test shows the texts.
