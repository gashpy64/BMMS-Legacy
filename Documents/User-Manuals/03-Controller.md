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

Purpose: the first screen after you sign in. It shows every meeting with the state of its agenda items,
your alerts, your action items and the Approve and Reject buttons for the items that wait for you.

Fields and buttons, in the Meetings card:

- Committee drop-down: "All committees" first, then the committees. It narrows both lists. You have no
  Department drop-down.
- The card title is "Meetings".
- Scheduled: every meeting that has not been held yet, the earliest first, with no limit. A meeting dated
  today is still here until the end of the day.
- Completed (last 10): the ten latest meetings that have been held, the newest first.
- The columns are Meeting (the committee and, under it, "No" and the meeting number), Meeting date (with
  the time), Submit agenda by, Status, Items, Approved, Rejected and Pending. The counts cover every item
  of the meeting: Items (all of them), Approved (approved by a Controller), Rejected (rejected by the Manager
  or by a Controller) and Pending (still waiting for approval, with the Manager or with a Controller).
- The Status label is coloured: Open for submission (blue), Submission closed (orange), Agenda finalised
  (green), Minutes pending (red), Minutes finalised and Minutes confirmed (grey). The Overall manual
  explains each label.

Steps:

1. To look at one committee, choose it in the Committee drop-down. The lists change at once. Choose
   "All committees" to go back.
2. After you approve or reject an item in its panel, the counts in the Meetings card are read again.

Messages and what to do:

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

The Committee drop-down narrows the Meetings card only. The Alerts card and the Action Items card do not
follow it.

The Agenda Alert panel and the Action Item Details panel fit a narrow window: below about 720 pixels the
labels sit above the fields. On a window under about 1100 pixels the cards stack one under the other.

[Screenshot: Dashboard as the Controller - supplied by Gashpy Software]

[[CONFIRM: the other screens are not written yet]]

## Tasks by goal

[[CONFIRM: not written yet]]

## Alerts and mails you receive

[[CONFIRM: not written yet]]

## Common problems

[[CONFIRM: not written yet]]

## Quick reference

[[CONFIRM: not written yet]]
