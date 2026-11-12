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

Notes: in the Alerts card the "Alert" column holds the link, with the alert type, committee and
department on a smaller line under it, and "Created on" holds the date and, under it, the time. The
Agenda Alert panel and the Action Item Details panel fit a narrow window: below about 720 pixels the
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
