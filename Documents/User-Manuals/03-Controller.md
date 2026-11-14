# BMMS Controller Manual

- Audience: Controller role
- Version: filled in at export
- Date: filled in at export

## What you can and cannot do

BMMS follows one rule for the two top roles. The Admin is superior for the technical items:
user accounts, the code masters, Reset Password, Backup Database, SMTP Configuration, System
Settings, Audit Trail and Reset Database. You, the Controller, are superior for the functional
items: the agenda, the meetings, the minutes, the follow-up and the reports. You get all of the
functional rights, and you do not use the technical items. You have no Admin menu, you cannot open
User Master, the code masters, Reset Password, Backup Database or Audit Trail, and you change
only your own password. If you open one of those screens by its address, BMMS shows "Access denied".

The Minutes report shows you every meeting that has minutes, in every status, drafts included.
Each meeting carries its minutes status, in the report and in the list you choose from:

- Draft (not finalised) - the minutes are still being updated. A draft also carries a bordered
  note, "DRAFT - not finalised; this is not the approved text of the minutes.", at the start and at
  the end of the meeting, so nobody takes a draft for the approved text.
- Finalised - you have finalised the minutes.
- Confirmed - the minutes are confirmed.

The status line "Minutes status: [status]" and the draft note stay in Print, Export to Pdf and
Export to Word. In the list on screen (View), the last column is "Minutes status". A meeting
whose agenda is not finalised yet has no minutes and is not listed; if the committee has no such
meeting you see "No meetings with minutes for this committee."

Minutes Extract is different: it shows finalised and confirmed minutes only, as before. Followup
and Followup Summary are unchanged for you and show no minutes status.

The Reports menu also has "Followup by Department", after Followup Summary. It is for you only: a
Manager who opens it gets "Access denied". It lists the subjects that have a follow-up item, for one
committee at a time:

1. Choose the Committee, and the Department (all departments, or one).
2. Choose the meeting: under "Meeting No. Search" pick Particular for one meeting, or Between for a
   range, and choose the meeting number in "Meeting No". You can limit the subjects the same way
   with "Subject No. Search" (All or Between) and "Subject No.".
3. Under "View Format" pick View to see the list on screen, or Print to make the report. Click
   Submit.
4. With Print, click Generate Report. The report opens in a new window, where you can Print it or
   use Export to Pdf or Export to Word.

The list and the report show only the meetings of the committee you chose. Each row has the meeting,
the agenda and subject numbers, the department and the agenda short text.

Export to Pdf cannot print Tamil or Hindi text. If the report holds such text, use Export to Word or
Print instead.

[[CONFIRM: the rest of this section is not written yet]]

## Signing in and your password

[[CONFIRM: not written yet]]

## Screens

### Dashboard

Purpose: the first screen after you sign in. It shows the items that wait for your approval, every meeting with the
state of its agenda items, your alerts, your action items and the Approve and Reject buttons for the items that
wait for you.

Fields and buttons, in the My approvals card (above the Meetings and Alerts cards, the full width of the page):

- The title is "My approvals (n)", where n is the number of items that wait for your approval.
- The list holds the items that the Manager has approved and that wait for you, of meetings whose agenda is open
  and whose date has not passed. The newest meeting is first; 10 items to a page, with page links under the list.
- The columns are Item (the agenda number as a link, with the short text under it), Committee, Meeting (the meeting
  number and under it its date) and Department.
- The card follows the Committee drop-down of the Meetings card.
- When nothing waits for you it says "Nothing is waiting for your approval."

Fields and buttons, in the Meetings card:

- Committee drop-down: "All committees" first, then the committees. It narrows both lists and the My approvals
  card. You have no Department drop-down.
- The card title is "Meetings".
- Scheduled: every meeting that has not been held yet, the earliest first, with no limit. A meeting dated
  today is still here until the end of the day.
- Completed (last 10): the ten latest meetings that have been held, the newest first.
- The columns are Meeting (the committee and, under it, "No" and the meeting number), Meeting date (with
  the time), Submit agenda by, Status, Items, Approved, Rejected and Pending, and, in the Scheduled list only,
  Waiting for me. The counts cover every item of the meeting: Items (all of them), Approved (approved by a
  Controller), Rejected (rejected by the Manager or by a Controller) and Pending (still waiting for approval, with
  the Manager or with a Controller). Waiting for me is the number of items of that meeting that wait for your own
  approval now (in a meeting whose agenda is open and whose date has not passed); it is empty where nothing waits
  for you and it is shown in bold. Pending is larger than Waiting for me when items still wait for the Manager, and
  it also counts the items of a meeting whose date has passed.
- The Meetings card takes three parts of four of the width of the page, with the Alerts card beside it. The
  Scheduled list has nine columns and fits its card on a window 1241 pixels wide or wider; if the card is
  narrower than the list, the list scrolls sideways inside the card.
- The Status label is coloured: Open for submission (blue), Submission closed (orange), Agenda finalised
  (green), Minutes pending (red), Minutes finalised and Minutes confirmed (grey). The Overall manual
  explains each label.

Steps:

1. To look at one committee, choose it in the Committee drop-down. The lists and My approvals change at once.
   Choose "All committees" to go back.
2. To decide an item that waits for you, click its agenda number in My approvals. The Agenda Alert panel opens. If
   you have an alert about the item, it is marked read and the number in the header "Alerts (n)" goes down (only
   your own alert is marked). Read the item, then press Approve or Reject. Approve and Reject are shown when the
   item waits for your approval, the agenda is open and the meeting date has not passed.
3. After you approve or reject an item in its panel, My approvals, the Waiting for me counts, the Alerts card and
   the counts in the Meetings card are read again, and the item leaves My approvals.

Messages and what to do:

- "The meeting date has passed, so this item can no longer be approved or rejected. It will be rejected when the
  agenda is finalized.": you opened an item that you could have decided, but its meeting date has passed. The
  message is inside the panel, just above the buttons Close and "Remove from my list", and Approve and Reject are
  not shown. Such an item is not listed in My approvals and is not counted in Waiting for me; it still counts in
  Pending until the agenda is finalized.
- You open an item that is still with the Manager (for example from an alert): you can read it, but Approve and
  Reject are not shown. BMMS shows them only for items that the Manager has approved and that wait for you.
- "Whether you may approve this item could not be checked, so it is shown read-only. Close it and open it again.":
  press Close and open the item again.
- "The item could not be checked, so nothing was changed. Try again.": you pressed Approve or Reject and nothing was
  saved; press the button again.
- "Nothing is waiting for your approval.": nothing waits for you for your choice of committee.
- "The approvals could not be loaded. Reload the page to try again." or "The server is busy and the approvals could
  not be loaded. Wait a moment, then reload the page.": reload the page. "The approvals are not available: your
  account is not active. Sign in again.": sign in again.
- "No scheduled meetings." or "No completed meetings.": there is nothing in that list for your choice.
- "The meeting list is not shown for this choice. Choose All committees.": choose "All committees".
- "The meeting list could not be loaded. Reload the page to try again.": reload the page. Your alerts and
  action items are still shown, and the Committee drop-down is hidden until the list loads.
- "The server is busy and the meeting list could not be loaded. Wait a moment, then reload the page."
- "The meeting list is not available: your account is not active. Sign in again."

Alerts card: the links Recent | Unread | All choose what is listed; the one you are looking at is in bold.
Recent (shown first) lists every alert you have not read and the alerts you have read in the last 7 days.
Unread lists only the alerts you have not read. All lists every alert that is not removed from your list.
The card shows 10 alerts to a page. The "Alert" column holds the link, with the alert type, committee,
department and the person ("by [Name]") on a smaller line under it; rest the pointer on the name to see
the login ID. Where the person is not known the line ends with "by -". The "Date" column holds the date
of the event (the day of a decision, or of an edit) and, under it, the time. You do not see the alerts of
your own decisions. The card says "No alerts." when there is nothing to list. The header shows "Alerts (n)",
the alerts you have not read; it changes after you press Approve, Reject or "Remove from my list", open an
alert or click one of the three links. If BMMS cannot read the number, the header shows "Alerts" without a
number. "Remove from my list" in an alert's panel removes the alert from your list only; if the item is
edited later, the alert comes back, unread. If the alerts cannot be loaded the card says "The alerts could
not be loaded. Reload the page to try again." (or "The server is busy and the alerts could not be loaded.
Wait a moment, then reload the page.", or "The alerts are not available: your account is not active. Sign
in again.").

Action Items card: the newest meeting is first. It has a "Due date" column; when the date is before today
and the item is not complied with or confirmed, a red "Overdue" label stands beside it. The links Show All |
Read | Unread narrow the list; the one you are looking at is in bold and stays chosen when you open an item
or go to another page. An item in bold is one you have not opened yet. You see every action item that is
not confirmed, whatever the status of its minutes, and you can change the action text of any of them. On
the day this release is installed, each open item shows in bold once, because you have not opened it yet.
If the action items cannot be loaded the card says "The action items could not be loaded. Reload the page
to try again." (or "The server is busy and the action items could not be loaded. Wait a moment, then reload
the page.", or "The action items are not available: your account is not active. Sign in again.").

The Committee drop-down narrows the Meetings card and My approvals. The Alerts card and the Action Items card do
not follow it.

The Agenda Alert panel and the Action Item Details panel fit a narrow window: below about 720 pixels the
labels sit above the fields. On a window 1240 pixels wide or narrower the cards stack one under the other; from
1241 pixels wide the Meetings card and the Alerts card stand side by side.

[Screenshot: Dashboard as the Controller - supplied by Gashpy Software]
[Screenshot: Dashboard as the Controller, My approvals card with items waiting and the Waiting for me column - supplied by Gashpy Software]
[Screenshot: Agenda Alert panel as the Controller, item of a meeting whose date has passed, message above the buttons - supplied by Gashpy Software]

[[CONFIRM: the other screens are not written yet]]

## Tasks by goal

[[CONFIRM: not written yet]]

## Alerts and mails you receive

[[CONFIRM: not written yet]]

## Common problems

[[CONFIRM: not written yet]]

## Quick reference

[[CONFIRM: not written yet]]
