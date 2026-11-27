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
The one screen you share with the Admin is the Governance Matrix (Reports menu). It only shows information; it saves
nothing.

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
and Followup Summary show no minutes status for you, but they show the followup status of each item:

- The Confirmed Status choice has three options: Both, Confirmed and Pending.
- In the list on screen (View) each item has a "Followup status" column. It shows "Pending" or "Confirmed",
  and under it a line that says who confirmed or reopened the item: "Confirmed by [name] ([login]) on
  [date and time]" (for example 17-Nov-2026 14:05) or "Reopened by [name] ([login]) on [date and time]:
  [reason]". These are the same texts as on the Followup screen. A followup that was confirmed before BMMS
  kept this history shows "Confirmed (before history)". The name of a user whose account is no longer active is
  marked, and a user who cannot be found shows as "an unknown user". A Pending item that was never reopened
  shows the word only.
- In Followup Summary the column shows the word only.
- The generated Followup report has a "FOLLOWUP STATUS" block under the action taken of each item: the word in
  bold and, under it, the line. The printed Followup Summary has a "Followup status" column with the word only.
- The rows, their filters and their order are as before; items that tie on every other key are listed by agenda
  number, then by action item.
- The Followup and Followup Summary pages open from the Reports menu. The breadcrumb reads "Reports / Followup" or
  "Reports / Followup Summary", the page title is the same, and the browser tab is named after the menu item. The filter is
  in a box headed "Filter", one row for each choice, with labels that have no colon. The red * marks the required
  fields inside the label: Meeting Date From (for the date range) and Committee Name. Under the rows are the buttons View
  (the main button), Generate and Cancel. They work as before.
- If you are not allowed to see a report you see "You are not allowed to see this report.", and if your session has
  ended "Your session is no longer valid. Please log in again."; no rows are shown, and the same applies to Export.

[Screenshot: Followup report as the Controller, the list with the Followup status column - supplied by Gashpy Software]
[Screenshot: Followup Summary as the Controller, the list with the Followup status column - supplied by Gashpy Software]
[Screenshot: Followup report, an item with the FOLLOWUP STATUS block, confirmed and reopened - supplied by Gashpy Software]

The Reports menu also has "Followup by Department", after Followup Summary. It is for you only: a
Manager who opens it gets "Access denied". It lists the subjects that have a follow-up item, for one
committee at a time. The breadcrumb reads "Reports / Followup by Department" and the page title is the same. The
filter is in a box headed "Filter", one row for each choice, with labels that have no colon. The red * inside the
labels Committee and Meeting No marks the two choices you must make:

1. Choose the Committee, and the Department (all departments, or one).
2. Choose the meeting: under "Meeting No. Search" pick Particular for one meeting, or Between for a
   range, and choose the meeting number in "Meeting No". You can limit the subjects the same way
   with "Subject No. Search" (All or Between) and "Subject No.".
3. Under "View Format" pick View to see the list on screen, or Print to make the report. Click
   Submit (the main button of the box).
4. With Print, a box headed "Print details" appears under the filter. Click Generate Report in it. The report opens in a
   new window, where you can Print it or use Export to Pdf or Export to Word.

The list and the report show only the meetings of the committee you chose. Each row has the meeting,
the agenda and subject numbers, the department and the agenda short text. In the list on screen (View) the last
column is "Followup status", with the word "Pending" or "Confirmed" and the line of who confirmed or reopened the
item, as in Followup. In the printed report the same word and line stand under the subject. The subject range
you choose is applied when the list is made, and the rows are listed by subject number, then by agenda number.
If you are not allowed to see the report you see "You are not allowed to see this report.", and if your session
has ended "Your session is no longer valid. Please log in again."; no rows are shown.

[Screenshot: Followup by Department, the list with the Followup status column - supplied by Gashpy Software]
[Screenshot: Followup by Department, the printed report with the status under the subject - supplied by Gashpy Software]

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

Summary cards (at the top of the page, above My approvals): three cards.

- "Items in progress": the items of the scheduled meetings that are not yet approved or rejected. The card carries
  the sentence "Items not yet approved or rejected. For a Manager this includes items waiting for someone else;
  'Waiting for me' is the part waiting for you."
- "Items rejected": the items of the scheduled meetings that have been rejected.
- "Unread alerts": the alerts you have not read, with the line "Your alerts, not filtered".

Under the first two a line says "Scheduled meetings, all committees", or the name of the committee you chose. The
two cards count the meetings in the Scheduled list only, and each equals the total of its column in the Scheduled
list for the same choice. A count that BMMS cannot read shows a dash, never 0 (a screen reader says "count not
available"), with the line "The counts could not be loaded. Reload the page to try again." or "The server is busy
and the counts could not be loaded. Wait a moment, then reload the page."

Fields and buttons, in the My approvals card (above the Meetings and Alerts cards, the full width of the page):

- The title is "My approvals (n)", where n is the number of items that wait for your approval.
- The list holds the items that wait for your approval: the items that a Manager has approved, and the items that
  went straight to the Controllers, of meetings whose agenda is open and whose date has not passed. The newest
  meeting is first; 10 items to a page, with page links under the list.
- The columns are Item (the agenda number as a link, with the short text under it), Committee, Meeting (the meeting
  number and under it its date) and Department.
- The card follows the Committee drop-down of the Meetings card.
- When nothing waits for you it says "Nothing is waiting for your approval."

Fields and buttons, in the Meetings card:

- Committee drop-down: "All committees" first, then the active committees. It narrows both lists, the first two
  summary cards, the My approvals card and the Action Items card. You have no Department drop-down.
- The card title is "Meetings".
- Scheduled: every meeting that has not been held yet, the earliest first, with no limit. A meeting dated
  today is still here until the end of the day.
- Completed (last 10): the ten latest meetings that have been held, the newest first.
- The columns are Meeting (the committee and, under it, "No" and the meeting number), Meeting date (with
  the time), Submit agenda by, Status, Items, Approved, Rejected and In progress, and, in the Scheduled list only,
  Waiting for me. The counts cover every item of the meeting: Items (all of them), Approved (approved by a
  Controller), Rejected (rejected by the Manager or by a Controller) and In progress (still waiting for approval, with
  the Manager or with a Controller). Rest the pointer on the heading to read: "Items not yet approved or rejected.
  For a Manager this includes items waiting for someone else; 'Waiting for me' is the part waiting for you." Waiting
  for me is the number of items of that meeting that wait for your own
  approval now (in a meeting whose agenda is open and whose date has not passed); it is empty where nothing waits
  for you and it is shown in bold. In progress is larger than Waiting for me when items still wait for the Manager,
  and it also counts the items of a meeting whose date has passed.
- The Meetings card takes three parts of four of the width of the page, with the Alerts card beside it. On a window
  1240 pixels wide or narrower the cards stack one under the other and the cells of the lists are tighter. On a
  window narrower than 960 pixels, a list wider than its card scrolls sideways inside the card with the Meeting
  column kept in view. The page itself never scrolls sideways.
- The Status label is coloured: Open for submission (blue), Submission closed (orange), Agenda finalised
  (green), Minutes pending (red), Minutes finalised and Minutes confirmed (grey). The Overall manual
  explains each label.

Steps:

1. To look at one committee, choose it in the Committee drop-down. The lists, the summary cards, My approvals and
   the Action Items card change at once.
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
  In progress until the agenda is finalized.
- You open an item that is still with the Manager (for example from an alert): you can read it, but Approve and
  Reject are not shown. BMMS shows them only for items that the Manager has approved and that wait for you.
- "Whether you may approve this item could not be checked, so it is shown read-only. Close it and open it again.":
  press Close and open the item again.
- "The item could not be checked, so nothing was changed. Try again.": you pressed Approve or Reject and nothing was
  saved; press the button again.
- "Nothing is waiting for your approval.": nothing waits for you for your choice of committee.
- "The approvals could not be loaded. Reload the page to try again." or "The server is busy and the approvals could
  not be loaded. Wait a moment, then reload the page.": reload the page. "The approvals are not available: your
  account is not active. Sign in again. "The approvals cannot be shown for this choice. Choose All committees.": the
  committee you chose can no longer be used, for example because it is no longer active; choose "All committees".
  The summary cards and the Action Items card say the same in their own words ("The counts cannot be shown for this
  choice. Choose All committees." and "The action items cannot be shown for this choice. Choose All committees.").
- When My approvals cannot be loaded, or cannot be shown for your choice, the title reads "My approvals (-)" with a
  dash in place of the number (a screen reader says "count not available"). The title keeps its number when you
  open or close an alert or an action item.
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

To change the action text, open the item: the Action Item Details panel shows Submit and Cancel (and no Close).
Press Submit to save. The panel closes, the list is read again (the link you chose, Show All, Read or Unread, and
your Committee choice stay) and BMMS says "The action text was saved." If the text could not be saved, the panel
stays open with your text and says so on a line above the buttons: "The action text could not be saved. Nothing was
saved. Try again." or "The server is busy and the action text could not be saved. Nothing was saved. Wait a
moment, then try again.", or "The text is too long. Shorten it or attach the document as a file." Press Submit
again. If your account is not active BMMS says "Your account is not active. Nothing was saved. Sign in again."

The card never lists a confirmed followup. A pending item that you reopened on the Followup screen has an orange
"Reopened" label in the Due date column, after "Overdue" when its date has also passed. Under the action text the
panel shows one grey line: "Reopened by [name (login)] on [date and time]: [reason]", "Confirmed by [name (login)] on
[date and time]" or "Confirmed (before history)", the same words as on the Followup screen; a long reason wraps. If
an item was confirmed after the card was read or after you opened the panel, the panel shows the text to read, the
line "This followup is confirmed and can no longer be changed." and Close only. If you press Submit on such an item,
BMMS says "This followup is confirmed and can no longer be changed. Nothing was saved." inside the panel, which stays
open to read with the saved text and the status line. To change a confirmed followup, reopen it on the Followup
screen first.

The Committee drop-down narrows the Meetings card, the first two summary cards, My approvals and the Action Items
card. The Alerts card is your own list for every committee; it says "Your own alerts, for every committee. The
filters at the top do not apply." The Unread alerts card follows no drop-down either.

The Agenda Alert panel and the Action Item Details panel fit a narrow window: below about 720 pixels the
labels sit above the fields. On a window 1240 pixels wide or narrower the cards stack one under the other; from
1241 pixels wide the Meetings card and the Alerts card stand side by side.

[Screenshot: Dashboard as the Controller - supplied by Gashpy Software]
[Screenshot: Dashboard as the Controller, the three summary cards and the Committee drop-down - supplied by Gashpy Software]
[Screenshot: Dashboard as the Controller, My approvals card with items waiting and the Waiting for me column - supplied by Gashpy Software]
[Screenshot: Agenda Alert panel as the Controller, item of a meeting whose date has passed, message above the buttons - supplied by Gashpy Software]

### Followup

Purpose: to read the follow-up decisions of the meetings, to change the action text of a decision, to mark
decisions as Confirmed and to reopen a confirmed decision. You are the only role that can save on this screen. (MD Secretariat
opens the same screen to read it.)

Open it from the Minutes menu, item Followup. The breadcrumb reads "Minutes / Followup", the page title is
"Followup", and the browser tab is named "Followup" too.

Fields and buttons:

- The filter at the top, in a box headed "Find followups", is one column of rows, in this order:
  Meeting Date From (a from date, "to" and a to date; the * mark stands in this label), Committee Name, Department,
  Meeting No. Search (Particular or Between), Meeting No., and Confirmed Status (Both, Confirmed or Pending).
  The labels have no colon. Under the rows are the buttons View (the main button) and Cancel.
- The list shows, for each decision, the Committee Name, Meeting No, Meeting Date, Agenda No., Subject No. and
  Decision. The column Actual Resolution has a View button that opens the actual resolution to read. The column
  Action Text has an Edit button on a Pending decision and a View button on a confirmed one. The column Status
  shows where the decision stands:
  - A Pending decision has a drop-down with Pending and Confirmed. Pending is chosen when the list appears.
  - A confirmed decision is final. It has no drop-down. The Status column reads "Confirmed" and a line "Confirmed by [name (login)] on [date and time]", with the date as day, month and year and the time as hours and minutes. A decision that was confirmed before BMMS kept this record reads "Confirmed (before history)". A confirmed decision has a Reopen button.
  - A decision that was reopened is Pending again. Under its drop-down a line reads "Reopened by [name (login)] on [date and time]: [reason]", the reason shown as plain text.
- The Submit button under the list confirms the decisions you changed to Confirmed. It is hidden while the list has no Pending decision.

Steps:

1. Choose the filter and press View. The list appears.
2. To change the action text of a Pending decision, press Edit on the row. The panel ":: Edit Action Text" opens.
   Change the text and press Save, or press Cancel to leave it unchanged. After Save the panel closes and BMMS says
   "The action text was saved."
3. To mark decisions as Confirmed, choose Confirmed in the Status drop-down of each of them and press Submit. Submit saves
   only the decisions you changed to Confirmed, in one step: either all of them are saved or none. BMMS says, for
   example, "3 followups were confirmed." or "1 followup was confirmed." If another Controller confirmed some of
   them in the meantime, BMMS leaves those as they are and adds "[m] had already been confirmed." If nothing was
   confirmed now, BMMS says "No followup was confirmed. [m] had already been confirmed." Once confirmed, a decision
   can no longer be changed, except by reopening it.
4. To read a confirmed decision's action text, press View on its row. The panel ":: View Action Text" opens with the
   line "This followup is confirmed and can no longer be changed. Reopen it to change the action text." Press Close.
5. To reopen a confirmed decision, press Reopen on its row. The panel ":: Reopen Followup" opens and names the
   decision (agenda number, subject number and meeting). Type the reason for reopening (it must be filled in, at most
   500 characters) and press Save, or press Cancel. After Save BMMS says "The followup was reopened." and the decision
   is Pending again, with the line that tells who reopened it, when and why. You can then change its action text or
   confirm it again. Each confirming and each reopening is recorded with the person, the date and time.

Messages and what to do:

- "No followup was changed to Confirmed. Nothing was saved.": you pressed Submit but no decision was changed to
  Confirmed; choose Confirmed on at least one row.
- "This followup is confirmed and can no longer be changed. Nothing was saved. Click View to read the list again.":
  somebody confirmed the decision while you had its action text open; your change was not saved; press View.
- "Enter the reason for reopening.": the reason is empty, or holds only blank characters (spaces, tabs, line breaks
  and other invisible spaces); type it and press Save.
- "The reason can be at most 500 characters.": shorten the reason; the panel stays open with your text.
- "Remove the "<" or "&#" from the reason, then save again.": the reason holds a "<" followed by a letter, "!", "/"
  or "?", or the characters "&#"; BMMS does not send it. Remove them and press Save. Only this message is shown.
- "This followup is no longer confirmed. Nothing was saved. Click View to read the list again.": someone else
  reopened the decision first; press View.
- "The followup could not be reopened. Nothing was saved. Try again." or "The server is busy and the followup could
  not be reopened. Nothing was saved. Wait a moment, then try again.": the panel stays open with your reason; press
  Save again.
- "You cannot read the followups: your role has no access to them.": the list is not shown to your account.

- "You cannot change the followups: your role can only read them, or an item on the list no longer exists. Nothing
  was saved. Click View to read the list again.": nothing was saved; press View to read the list again.
- "Your account is not active. Nothing was saved. Sign in again.": sign in again.
- "The action text could not be saved. Nothing was saved. Try again." or "The server is busy and the action text
  could not be saved. Nothing was saved. Wait a moment, then try again.": the panel stays open with your text, and
  the message stands on a line inside the panel; press Save again.
- "The text is too long. Shorten it or attach the document as a file.": shorten the text; the panel stays open.
- "The confirmations could not be saved. Nothing was saved. Try again." or "The server is busy and the
  confirmations could not be saved. Nothing was saved. Wait a moment, then try again.": press Submit again.

[Screenshot: Followup as the Controller, the filter box "Find followups" - supplied by Gashpy Software]
[Screenshot: Followup as the Controller, the list with the Status drop-downs, a confirmed row and Submit - supplied by Gashpy Software]
[Screenshot: Followup as the Controller, the panel ":: Edit Action Text" - supplied by Gashpy Software]
[Screenshot: Followup as the Controller, the panel ":: View Action Text" of a confirmed followup - supplied by Gashpy Software]
[Screenshot: Followup as the Controller, the panel ":: Reopen Followup" - supplied by Gashpy Software]
[Screenshot: Followup as the Controller, a reopened row with its Reopened by line - supplied by Gashpy Software]

### Governance Matrix

Purpose: shows, as on a date, who can enter and who approves each kind of transaction in each department, who the
Controllers are, and which settings applied. A second view, the Change log, lists the changes made to users,
departments and two settings. The screen only shows information: nothing on it can be changed or saved. Only you and the
Admin can open it. Open it from the Reports menu; the breadcrumb reads "Reports / Governance Matrix".

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
trail" for a change taken from older records when the log was started. A save that changes nothing leaves no row.

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
  Reload the page to try again.": reload the screen.
- "Your account is not active. Sign in again.": sign in again.
- "You are not allowed to see this page.": your role cannot open the matrix.
- In "Changed by", "(user no longer exists)" means the person who made the change has been removed.

Notes: for an earlier date the matrix applies the rules installed now, as the notes on the screen say; it shows who
held each role on that date. If you reload the screen after Show, the browser may ask whether to send the form again;
a fresh visit starts from the defaults.

[Screenshot: Governance Matrix as the Controller (Reports menu), the Matrix view for today - supplied by Gashpy Software]
[Screenshot: Governance Matrix, an earlier date with its notes - supplied by Gashpy Software]
[Screenshot: Governance Matrix, the Change log view - supplied by Gashpy Software]
[Screenshot: Governance Matrix, the print preview - supplied by Gashpy Software]

### Finalize Minutes

Purpose: to finalize the minutes of a meeting. Before you press Finalize you can read the items of the meeting in a list.

Open it from the Minutes menu, item Finalize Minutes. The breadcrumb reads "Minutes / Finalize Minutes".

Fields and buttons:

- The box "Meeting" has Committee Name and Meeting No (both required) and the buttons Finalize (the main button) and
  Cancel.
- When you have chosen a Committee Name and a Meeting No, a second box headed "Minutes Items" appears under the first.
  It is a list you can only read, with the columns Agenda No, Subject No, Short Text, Decision and Actual Resolution. The
  rows are in Agenda No order; you cannot sort them. Long texts wrap onto several lines. Actual Resolution is shown as
  plain text, without its formatting.
  - Subject No shows "-" when the item has no subject number.
  - Decision and Actual Resolution show "Not yet recorded" for an item whose minutes were not saved in Update Minutes yet.
  - For an item that was saved with nothing entered, they show "Not recorded".
  - A meeting without items shows "No items in this meeting."
- The list disappears when you set Committee Name or Meeting No back to -Select-, or choose another committee or
  meeting, and when you press Cancel (which takes you to the Dashboard). After Finalize the same meeting stays chosen, the list is read again and the
  message stays above it.

Steps:

1. Choose Committee Name, then Meeting No. The Minutes Items list appears.
2. Read the list. If an item shows "Not yet recorded", open Minutes, Update Minutes and save it first.
3. Press Finalize. BMMS asks whether you want to go on (see the texts below). Press OK to go on, or Cancel in the question to stay.
4. After OK, BMMS says "Minutes Finalized", or tells you why it cannot.

The question after Finalize shows the number of items ([n]) and the number not yet saved in Update Minutes ([m]):

- All items are saved: "Do you want to Finalize this Meeting Minutes? Items: [n]."
- Some items are not saved, on an older meeting: "Do you want to Finalize this Meeting Minutes? Items: [n]. Not yet saved
  in Update Minutes: [m]." If you press OK, BMMS finalizes the minutes unless something else stops it.
- Some items are not saved, on a newer meeting: "Items: [n]. Not yet saved in Update Minutes: [m]. These minutes cannot be
  finalized until every item is saved in Update Minutes. Nothing will be finalized." Press OK only if you want BMMS to show
  the reason; nothing is finalized.
- The meeting has no items: "This meeting has no minutes to finalize. Nothing will be finalized."

Finalize is never switched off: the question only tells you what is going to happen.

Messages and what to do:

- When you choose the meeting, BMMS can already show a warning above the boxes, in the warning colour, for a refusal it
  expects:
  - "[m] of the [n] minutes have not been updated yet. Update every item (Minutes, Update Minutes) before finalizing the
    minutes.": save the items that show "Not yet recorded" in Update Minutes, then come back.
  - "This meeting has no minutes to finalize (no agenda item was approved).": the meeting has no items to finalize.
  - "No Minutes For the selected Committee/Meeting": the meeting has no minutes.
  BMMS shows the first two only when the agenda of the meeting is finalized and its attendance is recorded. If one of
  them is missing, BMMS gives no warning in advance, and shows the reason after you press Finalize and OK. The warning
  goes away when you choose another committee or meeting, when you press Cancel and when you press Finalize (its message
  replaces it).
- "Minutes Finalized": done. The meeting stays chosen and the list shows the meeting again.

[Screenshot: Finalize Minutes as the Controller, a meeting chosen with the Minutes Items list - supplied by Gashpy Software]

### Minutes Confirmation

Purpose: the final step for the minutes of a meeting, with the Confirm button. Before you press Confirm you can read the items of the meeting in a list.

Open it from the Minutes menu, item Minutes Confirmation. The breadcrumb reads "Minutes / Minutes Confirmation".

Fields and buttons: the box "Meeting" has Committee Name and Meeting No (both required) and the buttons Confirm (the main
button) and Cancel. The box "Minutes Items" appears under it when both are chosen, with the same columns, wording and
behaviour as on Finalize Minutes (Agenda No, Subject No, Short Text, Decision, Actual Resolution; "-", "Not yet
recorded", "Not recorded", "No items in this meeting."; hidden again when you change or clear the choice, or press Cancel).

Steps:

1. Choose Committee Name, then Meeting No. The Minutes Items list appears.
2. Read the list.
3. Press Confirm. BMMS asks whether you want to go on and shows the number of items ([n]). Press OK to go on, or Cancel in the question to stay.
4. BMMS says "Minutes confirmed.", or tells you why it cannot. The meeting stays chosen and the list shows it again.

[Screenshot: Minutes Confirmation as the Controller, a meeting chosen with the Minutes Items list - supplied by Gashpy Software]

[[CONFIRM: the other screens are not written yet]]

## Tasks by goal

[[CONFIRM: not written yet]]

## Alerts and mails you receive

- When a User's new item goes straight to the Controllers (the person the User reports to is an active Controller, or the
  User's department has no active Manager and the Admin's System Settings send such items to the Controller), every
  active Controller gets an alert and the "has been Created" mail. When the reason is that the department had no active
  Manager, the mail says "Sent to the Controller: the department had no active Manager."
- When the department has no active Manager and the System Settings say such items are refused, the User's item is not
  saved and nobody receives an alert or a mail.
- When a Manager of the item's department approves or rejects an item, you receive the mail of the decision as before.
  The Managers of the department who did not decide have their alerts of the item handled, and get no later mail of it.
- When you edit an item that waits for the Manager and move it to another department, the Managers of the new
  department get an alert of it, and the alerts of the Managers of the old department show "Item moved to another
  department ([dd-MMM-yyyy])" under All. If you move the item back, those alerts become live again.
- The Admin gets no alert and no mail about agenda items, meetings or committees. Your own rules for approving are
  unchanged.
- When you save a meeting or a committee (Create or Update), BMMS sends a "has been Created" or "has been Updated" mail. It is
  sent to you, and to the same people who get the alert of that meeting or committee: every active user except you and the
  Admin role. A person without a mail address still gets the alert, and no mail. The Committee mail is sent too, as the
  Meeting mail always was.
- After you save a meeting or a committee, the screen can say:
  - "Successfully Saved": the item is saved and the mail was sent.
  - "The meeting was saved. No mail was sent because there were no recipients." (for a committee: "The committee was saved.
    No mail was sent because there were no recipients."): the item is saved, in green. Nobody had a mail address to send to,
    so no mail was sent at all.
  - "The meeting was saved, but the mail could not be sent. The error is in the error log." (for a committee: "The committee
    was saved, but the mail could not be sent. The error is in the error log."): the item is saved. The mail was not sent.
- When you finalise the minutes of a meeting, the action items are given to every active user except the Admin role. A user who
  is made active later does not get the action items of minutes finalised before. Action items already given to an Admin, or to
  a user who is now inactive, are kept and shown to nobody. You still see every action item that is not confirmed.

[[CONFIRM: the rest of this section (the other alerts and mails a Controller receives) is not written yet]]

## Common problems

[[CONFIRM: not written yet]]

## Quick reference

[[CONFIRM: not written yet]]
