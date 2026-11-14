# Dashboard pack (steps UN6b, UN6c1 and UN6c2a)

The pack proves on every run that the Dashboard's Meetings card shows each role the meetings, colours and
statistics of the owner's rules (Database\README.md, section "Step UN6b"), that the Alert and Action Item lists
still show what they showed, and that the page fits the window.

## Files

| File | What | Who changes it |
|---|---|---|
| `expected.json` | The cases (account, filter chosen, drop-downs, subtitle, card title, last column header, statistics shown, the Scheduled and Completed rows), the first-page row counts of the Alert and Action Item lists, the two headings of the Alerts card, the window widths. Step UN6c1: the header count per account (`alertHeader`), the three links for one account (`alertModes`), the person named on some alerts (`alertActors`), the due dates of the action items (`actionItemsDue`), the accounts of the action checks (`alertActions`). Step UN6c2a: `meetingsFit` (account, window width and number of columns of the fit check of the Scheduled list) and `pastItem` (the account, the alert and item of the passed meeting, the meeting-date message as the page shows it, and an item the account can decide). | The owner, or Claude on the owner's instruction (the build report lists it under "expectations changed"). Never the tester. |
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
- Step UN6c1: three Followups (QA1-00005-001 due three days ago, QA1-00005-002 due in five days, QA1-00006-001
  without a due date); qa_user has read three alerts (QA1-00004-001, 12 days old; QA1-00004-002, 2 days old;
  Committee (QA2), 10 days old); item QA1-00005-001 has no recorded approver. The dates script sets every alert
  date relative to the day of the run.
- Step UN6c1, scope of the Action Items card: QA1-00006-001 keeps the mapping row of qa_user only; two Followups
  on QA2 (direct rows): QA2-00003-1 (Secretarial, minutes finalised, mapped to qa_ctrl only) and QA2-00002-1
  (Credit, minutes in draft, mapped to qa_user only).
- Step UN6c2a: two items on QA2 00001 (direct rows, no alerts): QA2-00001-1 (Credit, approved by the Manager) and
  QA2-00001-2 (Secretarial, waiting for the Manager, saved by qa_ctrl). The statistics of QA2 00001 follow: 2 0 0 2
  for all departments, 1 0 0 1 for Credit and for Secretarial, 0 0 0 0 for HRD.
- QA2 "QA Dashboard Committee" (added in step UN6b): 00001 dated today (scheduled, not Minutes pending), no items;
  00002 to 00012 completed (days -1 to -9, -11, -12), Credit items, 00003 with a Secretarial item only. With QA2
  every role whose scope allows it has more than ten completed meetings, so the cap of ten shows. 00013 (step
  UN6c2a) lies 40 days back with its agenda still open and one Credit item at AC (QA2-00013-1, saved by qa_user,
  so routed to qa_manager) and its alert, read by qa_manager only: older than every other meeting, so it is below
  the ten Completed rows of every list and changes no row of check 1.

## Checks

1. Each case: no message, the card title, the subtitle, the drop-downs, the column headers, the Scheduled and
   Completed rows in order, the empty texts, the dates in dd-MMM-yyyy.
2. The Alert and Action Item lists: the number of rows on their first page per account (an Alerts row is a
   compact row: the Source link with the alert type, committee and department below it).
3. The inactive account is refused at sign-in; a visitor who opens the Dashboard ends on the sign-in page.
4. At 1366, 1241, 1240, 1024 and 800 px (qa_manager): the page is no wider than the window and the content area
   does not scroll sideways; the Meetings and Alerts cards side by side at 1366 and 1241 px and stacked at 1240 px
   and below (the breakpoint, step UN6c2a; 1100 px before); the same
   width check with the Agenda Alert panel open (qa_manager) and the Action Item Details panel open (qa_user).
   At each width the Alerts card (qa_manager): the headings "Alert" and "Date", none cut and the grid no
   wider than its card; every date dd-MMM-yyyy with HH:mm below it, on at most two lines.

5. Alerts card rules (step UN6c1, qa_user): Recent (the default: 10 rows, the read alert of 2 days ago among them,
   the read alerts of 10 and 12 days ago not), Unread (9), All (10 and a second page with the two older ones);
   the person named on an alert with the login ID as tooltip, a dash without tooltip where no approver is
   recorded (item QA1-00005-001); the header count unchanged by the links and no page reload. Action Items card:
   the due date and the word "Overdue" on QA1-00005-001 only; a date on QA1-00005-002; nothing on QA1-00006-001.
6. Alerts card actions (step UN6c1; last, they change data, and BMMS_Quality is restored before every run): as
   qa_user2, opening an alert lowers the header count by one without a page reload; "Remove from my list" takes
   the row out of this list (also under All); with the row id of qa_mgmt's alert put into the page, Remove is
   refused with "This alert is not in your list." and both lists keep their rows.
7. The link chosen stays chosen (step UN6c1, from the owner's test; `filterKept`: qa_manager with three unread
   action items, qa_manager2 with three unread alerts): with Unread chosen in the Action Items card, opening an item leaves
   the mark on Unread and the list holds the two unread rows; Read then shows the one opened, Show All the three.
   The same in the Alerts card: with Unread chosen, opening an alert leaves the mark on Unread, the list holds
   the two unread rows and the header reads "Alerts (2)"; Recent shows the three, one read.
8. The scope of the Action Items card (step UN6c1, `actionScope`; which items each account sees is in check 2,
   `actionItemsList`): qa_ctrl has no mapping row for QA1-00006-001, sees it unread, opens it and sees it read,
   also on a fresh Dashboard; for qa_mgmt it is still unread; qa_mgmt opens it and its Submit is refused with
   "You cannot change this action item: your role can only read it, or it is not an item of your department. Nothing was saved."; with the id of QA1-00005-002 (Credit) put into the
   page of qa_manager2 (HRD and Secretarial), Submit is refused with the same message; his Submit for his own
   QA2-00003-1 saves (no message).
9. My approvals (step UN6c2a; `approvals`, `approvalFilters`, `approvalOpen`): the panel per account and its rows,
   newest meeting first; no panel for qa_user, qa_user2, qa_mgmt, qa_mdsec and qa_admin. With committee QA Dashboard
   Committee chosen qa_ctrl sees QA2-00001-1 only; qa_manager2 with HRD chosen sees his item, with Secretarial
   chosen "Nothing is waiting for your approval." (QA2-00001-2 is Secretarial and at AC, but not routed to him).
   qa_ctrl opens QA1-00001-002 from the panel: the Agenda Alert panel with Approve and Reject, his alert of that
   item read (header from 1 to 0) without a page reload, the row still in the panel. qa_user opens his alert of
   QA1-00001-003: no Approve, no Reject. In check 1 the cases of qa_ctrl, qa_manager and qa_manager2 also check
   the "Waiting for me" column (`waiting` of the case: the meetings with items waiting for him; the other cases
   check that the column is not there).
10. The Scheduled list fits its card (step UN6c2a, `meetingsFit`): qa_ctrl and qa_manager (nine columns) at 1366
   and 1600 px, qa_mgmt (eight columns) at 1366 px: the cards side by side, the number of columns, the table no
   wider than its scroll box (scrollWidth not above clientWidth), no empty gap at its right (1 px allowed for
   rounding), and the heading "Waiting for me" on at most two lines (the nine-column lists only).
11. The meeting-date message (step UN6c2a, step M6a, `pastItem`; last, because opening an item from My approvals
   marks qa_manager's alert of it read): qa_manager opens the alert of QA2-00013-1 on the last page of All: the
   Agenda Alert panel without Approve and Reject, the message "The meeting date has passed, so this item can no
   longer be approved or rejected. It will be rejected when the agenda is finalized." inside the panel, at most
   40 px above the buttons and not covered by anything; then QA1-00001-001 from My approvals: Approve and Reject
   and no message in the panel.

My approvals per account, by the rule "Controller: items approved by the Manager; Manager: items waiting for the
Manager that are routed to him; meetings with an open agenda whose date has not passed":

| Account | Panel |
|---|---|
| qa_ctrl | QA1-00001-002 (meeting QA1 00001), QA2-00001-1 (QA2 00001, dated today) |
| qa_manager | QA1-00001-001 (QA1 00001), QA1-00002-001 (QA1 00002): both saved by qa_user, whose manager he is |
| qa_manager2 | QA1-00001-006 (the HRD item saved by qa_user2, whose manager he is) |
| qa_user, qa_user2, qa_mgmt, qa_mdsec, qa_admin | no panel |

The Action Items card per account (check 2), by the rule "Controller and Management: every item that is not
confirmed; Manager and User: the items of their departments with finalised or confirmed minutes; MD Secretariat and
Admin: no card", newest meeting first:

| Account | Card |
|---|---|
| qa_ctrl, qa_mgmt | QA2-00002-1 (Credit, minutes in draft), QA2-00003-1 (Secretarial), QA1-00005-001, QA1-00005-002, QA1-00006-001 (Credit) |
| qa_manager, qa_user (Credit) | QA1-00005-001, QA1-00005-002, QA1-00006-001 |
| qa_manager2 (HRD, Secretarial) | QA2-00003-1 |
| qa_user2 (HRD) | the card, no rows |
| qa_admin, qa_mdsec | no card |

In check 2 the Alerts card is on Recent, the header reads "Alerts (n)" with the unread alerts of the account, and
the Admin has no rows, the text "No alerts." and "Alerts (0)" (the Admin role gets no functional alerts; its rows
stay in the table).

Not in the pack: Approve and Reject (they send mail; the tester has no mail server and a failed mail writes to the
error log, which fails a run), so the header count after them and the mails themselves are the owner's checks;
the "could not be loaded" messages (a pack has no access to the database to deny EXECUTE).

What the pack cannot see is in the owner's checks by eye (looks, colours, print).
