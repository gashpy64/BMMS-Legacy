# Dashboard pack (step UN6b)

The pack proves on every run that the Dashboard's Meetings card shows each role the meetings, colours and
statistics of the owner's rules (Database\README.md, section "Step UN6b"), that the Alert and Action Item lists
still show what they showed, and that the page fits the window.

## Files

| File | What | Who changes it |
|---|---|---|
| `expected.json` | The cases (account, filter chosen, drop-downs, subtitle, card title, last column header, statistics shown, the Scheduled and Completed rows), the first-page row counts of the Alert and Action Item lists, the two headings of the Alerts card, the window widths. | The owner, or Claude on the owner's instruction (the build report lists it under "expectations changed"). Never the tester. |
| `pack.js` | The checks. | Claude, in a reviewed step. |

## A row

`committee | No meeting number | colour | label | Items Approved Rejected Pending`

- colour: grey, red, green, orange or blue (the class of the status chip); label: the chip's text.
- The four counts only where statistics are shown. For MD Secretariat and Admin the shared lists
  (`rowsScheduledAll`, `rowsCompletedAll`) are compared without them, and the pack also checks that no
  statistics word (Items, Approved, Rejected, Pending, In progress) is anywhere in the Meetings card.
- Scheduled rows by meeting date, oldest first; Completed rows newest first, at most 10 for every role.

## The data

The fixture (Tests\fixture), restored and dated afresh before every run (the dates are relative to the day of
the run):

- QA1 "QA Test Committee": 00001 Open for submission, 00002 Submission closed, 00003 Agenda finalised (scheduled);
  00004 Minutes pending, 00005 Minutes finalised, 00006 Minutes confirmed (completed).
- QA2 "QA Dashboard Committee" (added in step UN6b): 00001 dated today (scheduled, not Minutes pending), no items;
  00002 to 00012 completed (days -1 to -9, -11, -12), Credit items, 00003 with a Secretarial item only. With QA2
  every role whose scope allows it has more than ten completed meetings, so the cap of ten shows.

## Checks

1. Each case: no message, the card title, the subtitle, the drop-downs, the column headers, the Scheduled and
   Completed rows in order, the empty texts, the dates in dd-MMM-yyyy.
2. The Alert and Action Item lists: the number of rows on their first page per account (an Alerts row is a
   compact row: the Source link with the alert type, committee and department below it).
3. The inactive account is refused at sign-in; a visitor who opens the Dashboard ends on the sign-in page.
4. At 1366, 1024 and 800 px (qa_manager): the page is no wider than the window and the content area does not
   scroll sideways; the Meetings and Alerts cards side by side at 1366 px and stacked below 1100 px; the same
   width check with the Agenda Alert panel open (qa_manager) and the Action Item Details panel open (qa_user).
   At each width the Alerts card (qa_manager): the headings "Alert" and "Created on", none cut and the grid no
   wider than its card; every date dd-MMM-yyyy with HH:mm below it, on at most two lines.

What the pack cannot see is in the owner's checks by eye (looks, colours, print).
