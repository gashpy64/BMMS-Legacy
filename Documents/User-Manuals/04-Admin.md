# BMMS Admin Manual

- Audience: Admin role
- Version: filled in at export
- Date: filled in at export

## What you can and cannot do

BMMS follows one rule for the two top roles. You, the Admin, are superior for the technical
items: User Master, Department, Designation, Member Type, Subject Type and Decision Type (Master
menu), and Reset Password, Backup Database, SMTP Configuration, System Settings, Audit Trail and
Reset Database (Admin menu). Only you use these screens; the Controller does not. The Controller
is superior for the functional items: the agenda, the meetings, the minutes, the follow-up and
the reports, and has all of the functional rights. You view agenda items on the dashboard but do
not approve them, and you have no Reports menu.

[[CONFIRM: the rest of this section is not written yet]]

## Signing in and your password

[[CONFIRM: not written yet]]

## Screens

### Dashboard

Purpose: the first screen after you sign in. You view the meetings. You have no functional alerts and no
action items on it, and you do not approve agenda items.

Fields and buttons, in the Meetings card:

- Committee drop-down: "All committees" first, then the committees. It narrows both lists. You have no
  Department drop-down.
- The card title is "Meetings".
- Scheduled: every meeting that has not been held yet, the earliest first, with no limit. A meeting dated
  today is still here until the end of the day.
- Completed (last 10): the ten latest meetings that have been held, the newest first.
- The columns are Meeting (the committee and, under it, "No" and the meeting number), Meeting date (with
  the time), Submit agenda by and Status. You see no counts: BMMS does not show the Items, Approved,
  Rejected and In progress columns to your role. You have no summary cards (Items in progress, Items rejected,
  Unread alerts) either.
- The Status label is coloured: Open for submission (blue), Submission closed (orange), Agenda finalised
  (green), Minutes pending (red), Minutes finalised and Minutes confirmed (grey). The Overall manual
  explains each label.

Steps: to look at one committee, choose it in the Committee drop-down. Choose "All committees" to go back.

Messages and what to do:

- "No scheduled meetings." or "No completed meetings.": there is nothing in that list for your choice.
- "The meeting list is not shown for this choice. Choose All committees.": choose "All committees".
- "The meeting list could not be loaded. Reload the page to try again.": reload the page. Your alerts and
  action items are still shown, and the Committee drop-down is hidden until the list loads.
- "The server is busy and the meeting list could not be loaded. Wait a moment, then reload the page."
- "The meeting list is not available: your account is not active. Sign in again."

Alerts and action items: as the Admin you have no functional alerts. The Alerts card says "No alerts.", the
header reads "Alerts (0)" and BMMS sends you no mail about agenda items, meetings or committees. You have
no Action Items card. The Committee drop-down narrows the Meetings card only. The Alerts card says "Your own
alerts, for every committee. The filters at the top do not apply."

You have no "My approvals" card and no "Waiting for me" column: you do not approve agenda items.

The Meetings card takes three parts of four of the width of the page, with the Alerts card beside it. On a window
1240 pixels wide or narrower the cards stack one under the other and the cells of the lists are tighter; from 1241
pixels wide they stand side by side. On a window narrower than 960 pixels a list wider than its card scrolls
sideways inside the card with the Meeting column kept in view; the page itself never scrolls sideways.

[Screenshot: Dashboard as the Admin - supplied by Gashpy Software]

### User Master (Managers and their departments)

Only the part about Managers is written here. The rest of User Master is not described yet.

Purpose: you nominate the Managers of each department. Any active Manager of an agenda item's department may approve or
reject the item while it waits for a Manager (never the person who entered it). The Reporting Person of the person who
entered the item no longer decides; the Reporting Person still shows where a page or a mail names him. A department with
no active Manager cannot send a new item of a User to a Manager: see System Settings below.

Steps:

1. To make a person a Manager, or to give a Manager another department, open the person in User Master and save the
   role and the departments. The new Manager gets an unread alert for every item of those departments that is waiting for
   a Manager, on a meeting whose agenda is still open and whose date is today or later. Activating a Manager again does
   the same.
2. To change a Manager's role, to remove a department from a Manager, or to deactivate a Manager, use the same screen.
   BMMS stops you only when no other Manager of the department could decide an item that is waiting for him.

Messages and what to do:

- "Not saved: this Manager is still needed.": the change was refused and nothing was changed. One line says why: items
  still open for approval ("[n] item(s) routed to them is/are still open for approval: approve or reject it/them first."),
  items of meetings whose date has passed and whose agenda was never finalized ("the Controller should finalize the
  agenda of those meetings first (finalizing rejects the items not yet approved)."), or the department ("Last active
  Manager of [department] ([n] item(s) of the department waiting): give the department another active Manager first.").
  The last line is "Nothing was changed." Give the department another active Manager, or ask the Controller to finalize
  the agenda, then try again.
- "Saved. [n] waiting approval alert(s) of [departments] were closed; the other Managers of the department still have
  them.": the change was saved. The Manager's own waiting alerts of the department he left were closed (they stay in his
  All list as "No longer Manager of the department ([dd-MMM-yyyy])"); the other Managers of the department still have
  theirs and can decide the items. After a Deactivate the message starts "User deactivated." instead of "Saved.". When
  department mappings were closed too, the message reads "Saved. Their department mappings were closed today:
  [departments]." and then the same sentence.

[Screenshot: User Master, the message after a Manager's department was removed, alerts closed - supplied by Gashpy Software]

### System Settings (Department without an active Manager)

Purpose: tells BMMS what to do with a new agenda item entered by a User when the item's department has no active Manager.
It applies only to the items of a User whose Reporting Person is not an active Controller; items entered by a Manager or the
Controller are not affected.

Fields and buttons: the card "Department without an active Manager" has the choice "A new agenda item is": "Refused
(default)" or "Sent to the Controller", and a Save button for the card. The card says "Used when a new agenda item's
department has no active Manager. A change is written to the audit trail." and, once the choice has been changed, "Last
changed by [name] on [dd-MMM-yyyy HH:mm]."

Steps: choose "Refused (default)" or "Sent to the Controller" and press Save.

Messages and what to do:

- "Saved: when a department has no active Manager, a new agenda item will be sent to the Controller. The setting is now in
  use." and "Saved: when a department has no active Manager, a new agenda item will be refused. The setting is now in use.":
  the choice was saved.
- "Not saved: only an Admin can change system settings." and "Not saved: the value is not valid.": the choice was not saved.
- What the User sees: with "Refused (default)" the User is told "Not saved: the department [department name] has no active
  Manager. Ask the Admin to nominate a Manager for the department." and nothing is saved. With "Sent to the Controller" the
  item is saved, goes to the Controllers, and the User's message and the "has been Created" mail add "Sent to the
  Controller: the department had no active Manager."

[Screenshot: System Settings, the card Department without an active Manager - supplied by Gashpy Software]

[[CONFIRM: the other screens are not written yet]]

## Tasks by goal

[[CONFIRM: not written yet]]

## Alerts and mails you receive

You receive no alert and no mail about agenda items, meetings or committees. BMMS no longer even writes these alerts
for the Admin role. If you are the Reporting Person of a Manager or of the Controller, you get no copy of the "has been
Created" mail of their items.

[[CONFIRM: the rest of this section is not written yet]]

## Common problems

[[CONFIRM: not written yet]]

## Quick reference

[[CONFIRM: not written yet]]
