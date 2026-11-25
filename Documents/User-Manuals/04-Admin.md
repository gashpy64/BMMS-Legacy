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
not approve them, and you have no Reports menu. The one screen you share with the Controller is the
Governance Matrix (Admin menu). It only shows information; it saves nothing.

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

3. To choose the Reporting Person of a person, set the Department first. The Reporting Person list then holds the active
   Controllers and the active Managers of that department, never the person himself; "- Select -" is always allowed. When
   you change the Department, the Reporting Person is set to "- Select -" and you choose again. A Reporting Person who is
   saved already but is no longer one of the list (for example a Manager who left the department) is shown with
   " (not allowed now)" after the name; the Reporting Person drop-down can be changed for every role then. You cannot save
   while that person is chosen. This is checked when you create a person and on every save, also when you did not change
   the Reporting Person.

Messages and what to do:

- "Not saved: the Reporting Person must be a Manager of the user's department or a Controller. Choose another, or - Select -.":
  the chosen Reporting Person is not allowed (a person shown "(not allowed now)", or one who stopped being allowed since the
  page was opened). Nothing was saved and the form stays open. Choose another Reporting Person, or "- Select -", and save
  again.
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
[Screenshot: User Master, the Reporting Person list with an entry marked (not allowed now) and the refusal message - supplied by Gashpy Software]

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

### Reset Password

Purpose: sets the password of a user back to the default password and tells the user by mail. Only you use this screen.

Fields and buttons: the heading ":: Reset Password"; the drop-down "User :" and the button "Reset Password". The drop-down
lists the active and the inactive users by name and login; an inactive user is marked "(inactive)". When you choose a user, his details are shown under the drop-down and the button appears.

Steps:

1. Choose the user in the "User :" drop-down.
2. Press "Reset Password" and answer "OK" to "Are you sure to reset password?".

Messages and what to do:

- "New passward was sent through mail.": the password was reset to the default password and the user was sent a mail (the
  screen shows this text with that spelling).
- "The password was reset to the default password. No mail was sent because the user is inactive.": the user is inactive. The
  password was reset, in green, and no mail was sent.
- "The password was reset to the default password, but the mail could not be sent. The error is in the error log.": the password
  was reset, but the mail did not go out.
- "The password was not reset. Please try again.": nothing was changed; try again.

The mail goes to the address stored for the user. You cannot change it on this screen.

[Screenshot: Reset Password, an inactive user chosen and the message after Reset Password - supplied by Gashpy Software]

### Department Master (saving a department)

Only the part that changed is described here. When you save a department BMMS now checks your account first. If your
account is not active, or you are not an Admin, nothing is saved.

Messages and what to do:

- "Successfully Saved": the department was saved.
- "Not saved: your account is not active. Sign in again. Nothing was changed.": sign in again.
- "Not saved: only an Admin can change departments. Nothing was changed.": only an Admin can save a department.
- "Record Not Saved": the department was not saved; try again.

Making a department active or inactive is recorded in the change log of the Governance Matrix (below).

### Governance Matrix

Purpose: shows, as on a date, who can enter and who approves each kind of transaction in each department, who the
Controllers are, and which settings applied. A second view, the Change log, lists the changes made to users,
departments and two settings. The screen only shows information: nothing on it can be changed or saved. Only you and the
Controller can open it. Open it from the Admin menu; the breadcrumb reads "Admin / Governance Matrix".

Fields and buttons: two buttons at the top switch the view, "Matrix" and "Change log". Every time you open the screen
afresh it starts from the defaults below; your choices are kept while you stay on the screen.

In the Matrix view:

- "As on": the date, written dd-MMM-yyyy, for example 25-Nov-2026; click the box to pick a date. The default is today.
  The matrix shows the state at the end of that day.
- "Department": "All departments" (the default) or one department. A department that is not active on that date is
  marked "(inactive)".
- "Transaction": "All transactions" (the default) or one transaction.
- "Show": reads the matrix for your choices.

After Show the screen says "As on [date] (today)" or "As on [date], end of the day", and shows three blocks, with the
buttons "Print", "Export to Excel (CSV)" and "Export to PDF" above them:

- "Settings": the setting "Department without an active Manager" ("Sent to the Controller" or "Refused") and the setting
  "Controller changes the agenda after finalisation" ("Allowed" or "Not allowed"), as they were on the date. Where a
  setting was never changed the block says so, for example "Refused (not set: the default)".
- "Who enters and who approves": one row for each transaction and department; where a rule is not per department the
  department is "All departments". The columns are "Transaction", "Department", "Who enters", "Who approves",
  "Controller(s)" and "Rule note". Managers who approve are listed as "Any one of: [names]", because any one of them
  can decide.
- "Read-only access": the roles that only read, with the people who hold each role and what each can read. Management
  reads "Dashboard (read only), Minutes report, Followup report, Followup Summary report". MD Secretariat reads
  "Dashboard, Followup page (read only)". These roles approve nothing.

How to read the rows:

- People are shown as "Name (login)". A person who is inactive is never shown as able to act. On an earlier date, a
  person who was active then but is inactive now is marked "(inactive now)". The protected system account appears in
  the Admin rows only, marked "(system account)".
- The transactions are: agenda entry by a User, by a Manager and by the Controller; Manager approval or rejection;
  Controller approval or rejection; agenda finalisation; minutes update, finalisation and confirmation; Followup save,
  confirm and reopen; action items (who receives them, and who can open them on the Dashboard); meeting and committee
  create and update; attendance; User Master; Department Master; System Settings.
- The "Rule note" explains the route. For agenda entry by a User it says whether a Manager approves first and then a
  Controller, which Users go straight to the Controller (their Reporting Person is a Controller), which Users cannot
  enter new items (their Reporting Person is inactive), and, where the department has no active Manager, what the
  setting "Department without an active Manager" does. An inactive department says "Department inactive: no new agenda
  items." For the transactions that follow the rules of a page, the note names the roles of that page.

Steps for a date in the past: type the date in "As on" and press Show. Under the heading the screen adds notes:

- "As on [date], end of the day. The rules are those installed now."
- "Deleted users are not shown; see the change log."
- Where BMMS has no record for that date: "Reporting Person not recorded before [date]: the route to the Controller is
  not shown for earlier dates." and "Department status not recorded before [date]: today's status is shown."

In the Change log view you choose:

- "From" and "To": the dates. The default is the last 30 days, ending today.
- "User": "- All -" or one user. A deleted user is marked "(deleted)" and an inactive user "(inactive)".
- "Department": "All departments" or one department.
- "Change type": "All change types" or one of: User added, Role changed, Home department changed, Manager department
  added, Manager department removed, Reporting Person changed, Activated, Deactivated, Deleted, Department activated,
  Department deactivated, Setting changed.
- "Show": lists the changes. The heading reads "Changes from [date] to [date]: [number] changes", and the buttons
  "Print", "Export to Excel (CSV)" and "Export to PDF" appear.

The columns are "Changed on", "Changed by", "Change", "User", "Department or setting", "Old value", "New value" and
"Source". "Source" is "Recorded" for a change saved after the log was started, and "From history" or "From audit
trail" for a change taken from older records when the log was started. A save that changes nothing leaves no row. A
change of the setting "Department without an active Manager" or "Controller changes the agenda after finalisation" is
listed as "Setting changed".

Print, Export to Excel (CSV) and Export to PDF work for the view you are in, with the rows you chose. Print uses a
landscape page without the header, the menu, the filters and the buttons. In the Excel (CSV) file a cell that starts
with = + - @ or a tab gets a ' in front, so that Excel does not read it as a formula.

Messages and what to do:

- "History starts on [date]. Choose that date or a later one.": the matrix is not available for dates before the
  history starts; no rows are shown. Choose the date shown or a later one.
- "The As-on date cannot be after today. Choose today or an earlier date.": change the "As on" date.
- "Enter a valid date (dd-MMM-yyyy).": write the "As on" date, for example 25-Nov-2026.
- "Enter valid From and To dates (dd-MMM-yyyy).": write both dates in that form.
- "Choose a From date that is not after the To date, and a To date that is not after today.": change the dates.
- "No rows for the chosen filters." and "No changes for the chosen filters.": nothing matches; change the filters.
- "The governance matrix could not be loaded. Reload the page to try again." and "The change log could not be loaded.
  Reload the page to try again.": reload the screen. If it happens again, look at the error log.
- "Your account is not active. Sign in again.": sign in again.
- "You are not allowed to see this page.": your role cannot open the matrix.
- In "Changed by", "(user no longer exists)" means the person who made the change has been removed.

Notes: a user who made a recorded change cannot be deleted afterwards. For an earlier date the matrix applies the rules
installed now, as the notes on the screen say; it shows who held each role on that date. If you reload the screen after
Show, the browser may ask whether to send the form again; a fresh visit starts from the defaults.

[Screenshot: Governance Matrix as the Admin (Admin menu), the Matrix view for today - supplied by Gashpy Software]
[Screenshot: Governance Matrix, an earlier date with its notes - supplied by Gashpy Software]
[Screenshot: Governance Matrix, the Change log view - supplied by Gashpy Software]
[Screenshot: Governance Matrix, the print preview - supplied by Gashpy Software]

[[CONFIRM: the other screens are not written yet]]

## Tasks by goal

[[CONFIRM: not written yet]]

## Alerts and mails you receive

You receive no alert and no mail about agenda items, meetings or committees. BMMS no longer even writes these alerts
for the Admin role. If you are the Reporting Person of a Manager or of the Controller, you get no copy of the "has been
Created" mail of their items.

The Admin role is not in the list of those who get the mail of a meeting or a committee another person saved, and BMMS does not
give you the action items of finalised minutes. If you save a meeting or a committee yourself (the Meeting and Committee screens
are open to you and to the Controller), the "has been Created" or "has been Updated" mail is sent to you as the person who saved,
and to the other active users. Action items given to the Admin role before are kept and shown to nobody.

[[CONFIRM: the rest of this section is not written yet]]

## Common problems

[[CONFIRM: not written yet]]

## Quick reference

[[CONFIRM: not written yet]]
