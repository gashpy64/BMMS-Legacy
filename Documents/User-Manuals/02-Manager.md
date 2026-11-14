# BMMS Manager Manual

- Audience: Manager role
- Version: filled in at export
- Date: filled in at export

## What you can and cannot do

[[CONFIRM: not written yet]]

## Signing in and your password

[[CONFIRM: not written yet]]

## Screens

### Dashboard

Purpose: the first screen after you sign in. It shows the items that wait for your approval, the meetings with the
state of the agenda items of your departments, your alerts, your action items and the Approve and Reject
buttons.

Fields and buttons, in the My approvals card (above the Meetings and Alerts cards, the full width of the page):

- The title is "My approvals (n)", where n is the number of items that wait for your approval.
- The list holds the items sent to you for approval, of meetings whose agenda is open and whose date has not
  passed: the items entered by the people who report to you, and the items about which BMMS sent you an alert (also
  when you removed the alert from your list). You see only the items you may approve: an item of your department
  that was sent to another Manager is not listed. The newest meeting is first; 10 items to a page, with page links
  under the list.
- The columns are Item (the agenda number as a link, with the short text under it), Committee, Meeting (the meeting
  number and under it its date) and Department.
- The card follows the Committee drop-down and the Department drop-down of the Meetings card.
- When nothing waits for you it says "Nothing is waiting for your approval."

Fields and buttons, in the Meetings card:

- Committee drop-down: "All committees" first, then the committees. It narrows both lists and the My approvals
  card.
- Department drop-down: shown only when you look after two or more departments. "All my departments" comes
  first, then your departments. With one department there is no drop-down. It narrows the My approvals card and
  the counts, including Waiting for me.
- The subtitle "Departments: [list of your departments]" (with one department, "Department: [name]").
- The card title: "Meetings, items of my departments", or "Meetings, [department] items" when you have
  chosen one department (or have only one).
- Scheduled: every meeting that has not been held yet, the earliest first. A meeting dated today is
  still here until the end of the day.
- Completed (last 10): the ten latest meetings that have been held, the newest first. A completed
  meeting is listed only when it has items of your department or departments.
- The columns are Meeting (the committee and, under it, "No" and the meeting number), Meeting date (with
  the time), Submit agenda by, Status, Items, Approved, Rejected and Pending, and, in the Scheduled list only,
  Waiting for me. The counts cover the items of the departments you have chosen: Items (all of them), Approved
  (approved by the Controller), Rejected (rejected by you or the Controller) and Pending (still waiting for
  approval, with you or with the Controller). Pending counts every such item of your departments, also an item that
  waits for another Manager or for the Controller, and the items of a meeting whose date has passed. Waiting for me
  is the number of items of that meeting that wait for your own approval now (in a meeting whose agenda is open and
  whose date has not passed); it is empty where nothing waits for you and it is shown in bold. So Pending can be
  larger than Waiting for me.
- The Meetings card takes three parts of four of the width of the page, with the Alerts card beside it. The
  Scheduled list has nine columns and fits its card on a window 1241 pixels wide or wider; if the card is
  narrower than the list, the list scrolls sideways inside the card.
- The Status label is coloured: Open for submission (blue), Submission closed (orange), Agenda finalised
  (green), Minutes pending (red), Minutes finalised and Minutes confirmed (grey). The Overall manual
  explains each label.

Steps:

1. To look at one committee, choose it in the Committee drop-down. The lists and My approvals change at once.
2. To look at one of your departments, choose it in the Department drop-down. Choose "All my
   departments" to go back.
3. To decide an item that waits for you, click its agenda number in My approvals. The Agenda Alert panel opens. If
   you have an alert about the item, it is marked read and the number in the header "Alerts (n)" goes down (only
   your own alert is marked). Read the item, add your comment if you wish, then press Approve or Reject. Approve and
   Reject are shown only when the item was sent to you for approval, the agenda is open and the meeting date has not
   passed. When you open an item that was sent to another Manager, it is shown read-only, without Approve and
   Reject.
4. After you approve or reject an item in its panel, My approvals, the Waiting for me counts, the Alerts card and
   the counts in the Meetings card are read again, and the item leaves My approvals.

Messages and what to do:

- "The meeting date has passed, so this item can no longer be approved or rejected. It will be rejected when the
  agenda is finalized.": you opened an item that was sent to you, but its meeting date has passed. The message is
  inside the panel, just above the buttons Close and "Remove from my list", and Approve and Reject are not shown.
  Such an item is not listed in My approvals and is not counted in Waiting for me; it still counts in Pending until
  the agenda is finalized.
- "Whether you may approve this item could not be checked, so it is shown read-only. Close it and open it again.":
  press Close and open the item again.
- "The item could not be checked, so nothing was changed. Try again.": you pressed Approve or Reject and nothing was
  saved; press the button again.
- "Nothing is waiting for your approval.": nothing was sent to you for approval for your choice of committee and
  department.
- "The approvals could not be loaded. Reload the page to try again." or "The server is busy and the approvals could
  not be loaded. Wait a moment, then reload the page.": reload the page. "The approvals are not available: your
  account is not active. Sign in again.": sign in again. "The approvals cannot be shown for this choice. Choose All
  committees or All my departments.": choose one of those two entries.
- "No scheduled meetings." or "No completed meetings.": there is nothing in that list for your choice.
- "The meeting list is not shown for this choice. Choose All committees or All my departments.": choose one
  of those two entries.
- "The meeting list could not be loaded. Reload the page to try again.": reload the page. Your alerts and
  action items are still shown, and the drop-downs are hidden until the list loads.
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
or go to another page. An item in bold is one you have not opened yet. You see the action items of your
departments whose minutes are finalised or confirmed; you no longer see items of another department or
items whose minutes are still open. You can change the action text of an item of your departments. If the
action items cannot be loaded the card says "The action items could not be loaded. Reload the page to try
again." (or "The server is busy and the action items could not be loaded. Wait a moment, then reload the
page.", or "The action items are not available: your account is not active. Sign in again.").

The Committee drop-down narrows the Meetings card and My approvals. Your Alerts and Action Items cards do not
follow it, and they do not follow the Department drop-down either.

The Agenda Alert panel and the Action Item Details panel fit a narrow window: below about 720 pixels the
labels sit above the fields. On a window 1240 pixels wide or narrower the cards stack one under the other; from
1241 pixels wide the Meetings card and the Alerts card stand side by side.

[Screenshot: Dashboard as a Manager with two departments - supplied by Gashpy Software]
[Screenshot: Dashboard as a Manager, My approvals card with items waiting and the Waiting for me column - supplied by Gashpy Software]
[Screenshot: Agenda Alert panel as a Manager, item of a meeting whose date has passed, message above the buttons - supplied by Gashpy Software]

[[CONFIRM: the other screens are not written yet]]

## Tasks by goal

[[CONFIRM: not written yet]]

## Alerts and mails you receive

[[CONFIRM: not written yet]]

## Common problems

[[CONFIRM: not written yet]]

## Quick reference

[[CONFIRM: not written yet]]
