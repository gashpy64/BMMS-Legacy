# Followup pack (steps UN6d and FU1)

The pack proves on every run that the Followup page (Master/Followup.aspx) lets the Controller save, confirm
and reopen, and lets the MD Secretariat read only (owner decisions UN6d, 2026-11-15, and FU1, 2026-11-16;
Database\README.md, sections "Step UN6d" and "Step FU1"). The saves are decided on the server
(BMMS-Fix-FollowupSave-Step46.sql, BMMS-Fix-FollowupFinal-Step47.sql); the pack checks what each role sees and
that the Controller's saves work.

## Files

| File | What | Who changes it |
|---|---|---|
| `expected.json` | The account that reads only (`readOnlyAccount`) and the one that saves (`saveAccount`), the rows of the list with the default filters (`rows`, by agenda number), the row the Controller confirms and reopens (`confirmRow`), the name the page shows for the Controller (`saveAccountName`), the reopen reason typed (`reopenReason`), and the texts of the lines and messages. | The owner, or Claude on the owner's instruction (the build report lists it under "expectations changed"). Never the tester. |
| `pack.js` | The checks. | Claude, in a reviewed step. |

## The data

The fixture (Tests\fixture). The list of the page is every row of View_Action_Item that the filters allow; with
the default filters (all committees, all departments, Confirmed status Both) that is every action item of the
fixture, five, none confirmed: QA1-00005-001, QA1-00005-002, QA1-00006-001, QA2-00002-1, QA2-00003-1. (The page's
meeting date boxes are not used by the list's query; see "Known items for later steps".)

## Checks

1. qa_ctrl (Controller), first:
   - View: the five rows, each Pending with the Status drop-down (Pending chosen), no Reopen, "Edit" on each
     row; Submit; no read-only line.
   - The action text of QA1-00005-001: ":: Edit Action Text", Save and Cancel; Save with the text unchanged
     closes the panel and shows "The action text was saved." as a success.
   - Submit with no row changed: "No followup was changed to Confirmed. Nothing was saved."; every row Pending.
   - Confirmed chosen on QA1-00005-001, Submit: "1 followup was confirmed." as a success; that row "Confirmed",
     "Confirmed by QA Controller (qa_ctrl) on [dd-MMM-yyyy HH:mm]", no drop-down, Reopen, "View"; the other
     four rows Pending.
   - Its action text: ":: View Action Text", no Save, Close, the line "This followup is confirmed and can no
     longer be changed. Reopen it to change the action text."
   - Filter Confirmed, View: that row only, and no Submit.
   - Reopen: ":: Reopen Followup" naming the item; Save with no reason: "Enter the reason for reopening." in
     the panel; a reason with "<b": `Remove the "<" or "&#" from the reason, then save again.` in the panel (the browser's check; nothing is sent); the reason `QA reopen & "check" 'quotes'` with spaces around it: "The followup was
     reopened." as a success; the row Pending with the drop-down, "Reopened by QA Controller (qa_ctrl) on
     [date]: QA reopen & "check" 'quotes'" (the text as typed, trimmed, shown as text), "Edit", no Reopen.
2. qa_mdsec (MD Secretariat), after the Controller: the five rows, the line "You can read the followups. Your
   role cannot change them." above the list, no Submit, no drop-down and no Reopen anywhere, "View" on each
   row, every row "Pending", the reopen line on QA1-00005-001. The action text of the first row: ":: View
   Action Text", no Save, Close, the read-only line inside the panel; Close closes the panel without a message.

Not in the pack:

- A Save, Submit or Reopen forged for the MD Secretariat: the page does not render the controls, and a post for
  a control the page did not render is refused by ASP.NET's event validation before the page runs (which writes
  the error log and fails a run). The server's refusal of every role but an active Controller, the system
  account, an inactive account, a refused Submit when one row is bad, Reason 26 (a confirmed item's action text)
  and Reason 27 (a reopen of an item no longer confirmed) are proven by BMMS-Test-FollowupFinal-Step47.sql.
- A second Controller confirming or reopening the same row in between (skipped rows, Reasons 26 and 27 from
  the page): an owner check with two browsers.
- "Confirmed (before history)": the fixture has no item confirmed before step 47. An owner check on BMMS_Test.
- The failure messages ("could not be saved", "could not be reopened", "The server is busy ..."): a pack has no
  database access to deny EXECUTE. An owner check.
- The text-too-long messages (Action Text editor; a reason over 500 characters, which the box does not let
  through): owner checks.

The Controller's Save writes the action text the fixture already has; the Confirm and the Reopen of
QA1-00005-001 leave it not confirmed, as in the fixture, with two history rows (the Dashboard pack runs before
this one). BMMS_Quality is restored and dated afresh before every run.
