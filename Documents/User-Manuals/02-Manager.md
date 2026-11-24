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

Summary cards (at the top of the page, above My approvals): three cards.

- "Items of my departments in progress": the items of your departments in the scheduled meetings that are not yet
  approved or rejected. With one department, or when you choose one in the Department drop-down, the name of the
  department takes the place of "Items of my departments", for example "HRD items in progress". The card carries
  the same sentence as the In progress heading (see below).
- "Items of my departments rejected": the same, for the items that have been rejected.
- "Unread alerts": the alerts you have not read, with the line "Your alerts, not filtered".

Under the first two a line says "Scheduled meetings, all committees", or the name of the committee you chose. The
two cards count the meetings in the Scheduled list only, and each equals the total of its column in the Scheduled
list for the same choice. They follow the Committee drop-down and the Department drop-down. Because they count
every item of your departments, "Items in progress" can be larger than the number of items that wait for you. A
count that BMMS cannot read shows a dash, never 0 (a screen reader says "count not available"), with the line "The
counts could not be loaded. Reload the page to try again." or "The server is busy and the counts could not be
loaded. Wait a moment, then reload the page."

Fields and buttons, in the My approvals card (above the Meetings and Alerts cards, the full width of the page):

- The title is "My approvals (n)", where n is the number of items that wait for your approval.
- The list holds the items that wait for your approval, of meetings whose agenda is open and whose date has not
  passed: the items of your departments that wait for a Manager, except the items you entered yourself. Every active
  Manager of the department sees the same items, and any one of them may approve or reject; whoever decides first
  decides (see "Alerts and mails you receive"). It does not matter who entered the item or who that person reports to.
  You see only the items you may approve. The newest meeting is first; 10 items to a page, with page links under
  the list.
- The columns are Item (the agenda number as a link, with the short text under it), Committee, Meeting (the meeting
  number and under it its date) and Department.
- The card follows the Committee drop-down and the Department drop-down of the Meetings card.
- When nothing waits for you it says "Nothing is waiting for your approval."

Fields and buttons, in the Meetings card:

- Committee drop-down: "All committees" first, then the active committees. It narrows both lists, the first two
  summary cards, the My approvals card and the Action Items card.
- Department drop-down: shown only when you look after two or more departments. "All my departments" comes
  first, then your departments. With one department there is no drop-down. It narrows the My approvals card, the
  Action Items card, the summary cards and the counts, including Waiting for me.
- The subtitle "Departments: [list of your departments]" (with one department, "Department: [name]").
- The card title: "Meetings, items of my departments", or "Meetings, [department] items" when you have
  chosen one department (or have only one).
- Scheduled: every meeting that has not been held yet, the earliest first. A meeting dated today is
  still here until the end of the day.
- Completed (last 10): the ten latest meetings that have been held, the newest first. A completed
  meeting is listed only when it has items of your department or departments.
- The columns are Meeting (the committee and, under it, "No" and the meeting number), Meeting date (with
  the time), Submit agenda by, Status, Items, Approved, Rejected and In progress, and, in the Scheduled list only,
  Waiting for me. The counts cover the items of the departments you have chosen: Items (all of them), Approved
  (approved by the Controller), Rejected (rejected by you or the Controller) and In progress (still waiting for
  approval, with you or with the Controller). In progress counts every such item of your departments, also an item
  that waits for another Manager or for the Controller, and the items of a meeting whose date has passed. Rest the
  pointer on the heading to read: "Items not yet approved or rejected. For a Manager this includes items waiting for
  someone else; 'Waiting for me' is the part waiting for you." Waiting for me
  is the number of items of that meeting that wait for your own approval now (in a meeting whose agenda is open and
  whose date has not passed); it is empty where nothing waits for you and it is shown in bold. So In progress can be
  larger than Waiting for me.
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
2. To look at one of your departments, choose it in the Department drop-down. Choose "All my
   departments" to go back.
3. To decide an item that waits for you, click its agenda number in My approvals. The Agenda Alert panel opens. If
   you have an alert about the item, it is marked read and the number in the header "Alerts (n)" goes down (only
   your own alert is marked). Read the item, add your comment if you wish, then press Approve or Reject. Approve and
   Reject are shown only when the item waits for your approval, the agenda is open and the meeting date has not
   passed. When you open an item you may not decide (for example an item you entered yourself, or one that another
   Manager of your department has already approved or rejected), it is shown read-only, without Approve and
   Reject. If another Manager decides the item while your panel is open, pressing Approve or Reject says "You cannot
   approve or reject this agenda item at its current stage ([status name]). Reload the Dashboard to see its current
   state." and nothing is saved; reload the Dashboard.
4. After you approve or reject an item in its panel, My approvals, the Waiting for me counts, the Alerts card and
   the counts in the Meetings card are read again, and the item leaves My approvals.

Messages and what to do:

- "The meeting date has passed, so this item can no longer be approved or rejected. It will be rejected when the
  agenda is finalized.": you opened an item that was sent to you, but its meeting date has passed. The message is
  inside the panel, just above the buttons Close and "Remove from my list", and Approve and Reject are not shown.
  Such an item is not listed in My approvals and is not counted in Waiting for me; it still counts in In progress until
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
  committees." (with two or more departments: "... Choose All committees or All my departments."): the committee
  you chose can no longer be used, for example because it is no longer active; choose "All committees" (or "All my
  departments"). The summary cards, the Action Items card and the Meetings card say the same in their own words, for
  example "The counts cannot be shown for this choice. Choose All committees." and "The action items cannot be shown
  for this choice. Choose All committees."
- When My approvals cannot be loaded, or cannot be shown for your choice, the title reads "My approvals (-)" with a
  dash in place of the number (a screen reader says "count not available"). The title keeps its number when you
  open or close an alert or an action item.
- "No scheduled meetings." or "No completed meetings.": there is nothing in that list for your choice.
- "The meeting list is not shown for this choice. Choose All committees or All my departments.": choose one
  of those two entries. With one department, the text ends "Choose All committees."
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

Handled alerts: when another Manager of your department approves or rejects an item that was waiting for you too,
your alert of that item is handled. It is listed under All only (not under Recent or Unread), in grey, and under
the alert type line it says "Handled by [Name (login)] on [dd-MMM-yyyy]", with the name and login of the Manager who
decided and the day. Two other lines can stand there: "No longer Manager of the department ([dd-MMM-yyyy])", when you
stopped being a Manager of that department while the item was waiting, and "Item moved to another department
([dd-MMM-yyyy])", when the Controller moved the item to another department. The date in the Date column is the day
it was handled. A handled alert is never counted in the header "Alerts (n)" or in the Unread alerts card, and it
never becomes unread again. You can still open it: the Agenda Alert panel shows the same line and no Approve or
Reject. "Remove from my list" works on it as on any alert. If the Controller moves the item back to your department,
the alert becomes live again, unread.

Action Items card: the newest meeting is first. It has a "Due date" column; when the date is before today
and the item is not complied with or confirmed, a red "Overdue" label stands beside it. The links Show All |
Read | Unread narrow the list; the one you are looking at is in bold and stays chosen when you open an item
or go to another page. An item in bold is one you have not opened yet. You see the action items of your
departments whose minutes are finalised or confirmed; you no longer see items of another department or
items whose minutes are still open. You can change the action text of an item of your departments. If the
action items cannot be loaded the card says "The action items could not be loaded. Reload the page to try
again." (or "The server is busy and the action items could not be loaded. Wait a moment, then reload the
page.", or "The action items are not available: your account is not active. Sign in again.").

To change the action text, open the item: the Action Item Details panel shows Submit and Cancel. Press Submit to
save. The panel closes, the list is read again (the link you chose, Show All, Read or Unread, and your Committee
and Department choices stay) and BMMS says "The action text was saved." If the item is not one of your
departments, BMMS says "You cannot change this action item: your role can only read it, or it is not an item of
your department. Nothing was saved." If the text could not be saved, the panel stays open with your text and says
so on a line above the buttons: "The action text could not be saved. Nothing was saved. Try again." or "The server
is busy and the action text could not be saved. Nothing was saved. Wait a moment, then try again.", or "The text
is too long. Shorten it or attach the document as a file." Press Submit again. If your account is not active BMMS
says "Your account is not active. Nothing was saved. Sign in again."

The card never lists a confirmed followup. A pending item that the Controller reopened has an orange "Reopened"
label in the Due date column, after "Overdue" when its date has also passed. Under the action text the panel shows
one grey line: "Reopened by [name (login)] on [date and time]: [reason]", "Confirmed by [name (login)] on [date and
time]" or "Confirmed (before history)"; a long reason wraps. If an item was confirmed after the card was read or
after you opened the panel, the panel shows the text to read, the line "This followup is confirmed and can no longer
be changed." and Close only. If you press Submit on such an item, BMMS says "This followup is confirmed and can no
longer be changed. Nothing was saved." inside the panel, which stays open to read with the saved text and the status
line.

The Committee drop-down narrows the Meetings card, the first two summary cards, My approvals and the Action Items
card. The Department drop-down (if you have it) narrows the same four. Your Alerts card is your own list for every
committee; it says "Your own alerts, for every committee. The filters at the top do not apply." The Unread alerts
card follows no drop-down either.

The Agenda Alert panel and the Action Item Details panel fit a narrow window: below about 720 pixels the
labels sit above the fields. On a window 1240 pixels wide or narrower the cards stack one under the other; from
1241 pixels wide the Meetings card and the Alerts card stand side by side.

[Screenshot: Dashboard as a Manager with two departments - supplied by Gashpy Software]
[Screenshot: Dashboard as a Manager, the three summary cards and the Committee and Department drop-downs - supplied by Gashpy Software]
[Screenshot: Dashboard as a Manager, My approvals card with items waiting and the Waiting for me column - supplied by Gashpy Software]
[Screenshot: Agenda Alert panel as a Manager, item of a meeting whose date has passed, message above the buttons - supplied by Gashpy Software]
[Screenshot: Dashboard as a Manager, Alerts card under All with greyed handled alerts and their lines - supplied by Gashpy Software]
[Screenshot: Agenda Alert panel as a Manager, opened from a handled alert, the line "Handled by" and no Approve or Reject - supplied by Gashpy Software]

[[CONFIRM: the other screens are not written yet]]

## Tasks by goal

[[CONFIRM: not written yet]]

## Alerts and mails you receive

Approval of items is shared by all the active Managers of a department. The Reporting Person of the person who entered
the item does not decide, and the Admin does not approve items.

Alerts:

- When a User enters a new item for your department and it waits for a Manager, every active Manager of the
  department gets an unread alert. You do not get an alert for an item you entered yourself.
- When you are made a Manager, a department is added to you, or your account is activated again, you get the
  alerts of the items of your departments that are waiting for a Manager (only items of meetings whose agenda is
  open and whose date is today or later).
- When one Manager decides an item, the alerts of the other Managers of the department are handled (see "Handled
  alerts" above): they stay in the All list, in grey, with "Handled by [Name (login)] on [dd-MMM-yyyy]".
- When you stop being a Manager of a department (the Admin changes your role, takes the department away or deactivates
  you), your waiting alerts of that department show "No longer Manager of the department ([dd-MMM-yyyy])". The Admin is
  told how many were closed and that the other Managers of the department still have them.
- When the Controller moves an item that waits at the Manager step to another department, the alerts of the old
  department's Managers show "Item moved to another department ([dd-MMM-yyyy])".

Mails:

- When a User enters a new item that waits for a Manager, the "has been Created" mail goes to every active Manager of the
  department. If the department had no active Manager and the Admin has set System Settings to send such items to the
  Controller, the mail goes to the Controllers instead and says "Sent to the Controller: the department had no active
  Manager."
- When another Manager of your department approves or rejects an item, you also get the mail of that decision.
- After one Manager has decided, the Managers whose alerts were handled get no later mail about that item.

[[CONFIRM: the rest of this section (the other alerts and mails a Manager receives) is not written yet]]

## Common problems

[[CONFIRM: not written yet]]

## Quick reference

[[CONFIRM: not written yet]]
