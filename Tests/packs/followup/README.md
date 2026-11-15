# Followup pack (step UN6d)

The pack proves on every run that the Followup page (Master/Followup.aspx) lets the Controller save and lets the
MD Secretariat read only (owner decision UN6d, 2026-11-15; Database\README.md, section "Step UN6d"). The two
saves are decided on the server (BMMS-Fix-FollowupSave-Step46.sql); the pack checks what each role sees and that
the Controller's saves still work.

## Files

| File | What | Who changes it |
|---|---|---|
| `expected.json` | The account that reads only (`readOnlyAccount`) and the one that saves (`saveAccount`), the rows of the list with the default filters (`rows`, by agenda number), the read-only line (`readOnlyLine`), the two success messages (`actionTextSaved`, `confirmedSaved`). | The owner, or Claude on the owner's instruction (the build report lists it under "expectations changed"). Never the tester. |
| `pack.js` | The checks. | Claude, in a reviewed step. |

## The data

The fixture (Tests\fixture). The list of the page is every row of View_Action_Item that the filters allow; with
the default filters (all committees, all departments, Confirmed status Both) that is every action item of the
fixture, five, none confirmed: QA1-00005-001, QA1-00005-002, QA1-00006-001, QA2-00002-1, QA2-00003-1. (The page's
meeting date boxes are not used by the list's query; see "Known items for later steps".)

## Checks

1. qa_mdsec (MD Secretariat): the page opens; after View the five rows, the line "You can read the followups.
   Your role cannot change them." above the list, no Submit button, every Confirmed tick disabled, "View" on the
   Action Text button of every row. The action text of the first row: the panel title ":: View Action Text", no
   Save button, a Close button, the read-only line inside the panel; Close closes the panel without a message.
2. qa_ctrl (Controller): the page opens; after View the five rows, no read-only line, the Submit button, every tick
   enabled, "Edit" on every Action Text button. The action text of the first row: ":: Edit Action Text", Save and
   Cancel, no line in the panel; Save with the text unchanged closes the panel and shows "The action text was
   saved." as a success. Submit with the ticks unchanged shows "The confirmations were saved." as a success and
   every row keeps its tick.

Not in the pack:

- A Save or Submit forged for the MD Secretariat: the page does not render the buttons, and a post for a control
  the page did not render is refused by ASP.NET's event validation before the page runs (which writes the error
  log and fails a run). The server's refusal of every role but an active Controller, the system account, an
  inactive account and a refused Submit when one row is bad are proven by BMMS-Test-FollowupSave-Step46.sql.
- The failure messages ("could not be saved", "The server is busy ..."): a pack has no database access to deny
  EXECUTE. An owner check.
- The text-too-long message inside the panel: an owner check.

The Controller's Save and Submit write the values the fixture already has; BMMS_Quality is restored and dated
afresh before every run.
