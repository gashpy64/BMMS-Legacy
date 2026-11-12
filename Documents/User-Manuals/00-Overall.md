# BMMS Overall Manual

- Audience: Everyone who uses BMMS, and the people who decide on it
- Version: filled in at export
- Date: filled in at export

## Purpose of BMMS

[[CONFIRM: not written yet]]

## Roles and who does what

[[CONFIRM: not written yet]]

### The Dashboard meeting list, by role

The Dashboard is the first screen after you sign in. Its Meetings card lists the meetings of the
committees in two parts: Scheduled (every meeting that has not been held, the earliest first, with no
limit) and Completed (last 10) (the ten latest meetings that have been held, the newest first). A meeting
dated today is still Scheduled until the end of that day. Each row shows the Meeting (the committee name
and, under it, the meeting number, for example "No 00003"), the Meeting date (with the time, for example
"10:00 Hrs."), Submit agenda by, the Status and the four counts. Dates are shown as 12-Nov-2026.

What each role sees:

| Role | Committee drop-down | Department drop-down | Subtitle and card title | Counts | Last column |
|---|---|---|---|---|---|
| Controller | Yes | No | Title "Meetings" | Yes, every item | Pending |
| Management | Yes | No | Title "Meetings" | Yes, every item | Pending |
| MD Secretariat | Yes | No | Title "Meetings" | No | - |
| Admin | Yes | No | Title "Meetings" | No | - |
| Manager | Yes | Only when you look after two or more departments | Subtitle "Departments: [list of your departments]" (or "Department: [name]" with one); title "Meetings, items of my departments", or "Meetings, [department] items" when you choose one department | Yes, the items of your departments | Pending |
| User | No | No | Subtitle "Department: [name]"; title "Meetings, [department] items" | Yes, the items of your department | In progress |

The counts are Items (every agenda item of the meeting), Approved (items approved by the Controller),
Rejected (items rejected by the Manager or the Controller) and the last column: items still waiting for
approval, with the Manager or with the Controller. It is headed "In progress" for the User and "Pending"
for everyone else. An item in none of those states counts in Items only. MD Secretariat and Admin see the
meetings and their Status but no counts.

For the Manager and the User the Scheduled list shows every scheduled meeting, but a completed meeting is
listed only when it has items of your department (or one of your departments), and the counts cover only
those items. BMMS works out what you may see from your own sign-in; the drop-downs only narrow the list.
In the Committee drop-down, "All committees" comes first. In the Manager's Department drop-down, "All my
departments" comes first. After you approve or reject an item on the Dashboard, the counts are read again.

The Alerts card beside the Meetings card has two columns. "Alert" holds the link to the item, with the alert
type, the committee and the department on a smaller line under it, separated by " | ". "Created on" holds
the date and, under it, the time (for example 14:05). The Action Items card is below. On a narrow window
(under about 1100 pixels) the cards stack one under the other.

[Screenshot: Dashboard, Meetings card and Alerts card - supplied by Gashpy Software]

## MD Secretariat and Management

Management reads reports. You sign in to the dashboard, where you
view the agenda items and alerts that concern you but do not approve them. Your menu has a Reports
menu with three items:

- Minutes - the minutes report for every committee in the list, in every minutes status. Choose
  the committee and the meeting, then View or Generate. Each meeting shows "Minutes status: [status]"
  (Draft (not finalised), Finalised or Confirmed). A draft also carries a bordered note, "DRAFT -
  not finalised; this is not the approved text of the minutes.", at the start and at the end of the
  meeting. The list on screen has a last column "Minutes status". The status line and the note stay
  in Print, Export to Pdf and Export to Word.
- Followup - the follow-up decisions of the meetings, with the minutes status of each item (a draft
  item also carries the bordered note). The Cancel button returns you to the same report.
- Followup Summary - the same decisions as a table with a "Minutes status" column.

If the committee has no meeting with minutes, the Minutes report says "No meetings with minutes for
this committee." If your session has ended you see "Your session is no longer valid. Please log in
again."; if you are not allowed to see a report you see "You are not allowed to see this report."

You have no Minutes Extract, no agenda reports and no other report. If you open another report by
its address, BMMS shows "Access denied". The Manager and every other role see finalised and
confirmed minutes only.

MD Secretariat uses the Followup screen and views agenda items on the dashboard without approving
them.

On the Dashboard, the Meetings card of both roles has a Committee drop-down and the title "Meetings".
Management sees the counts (Items, Approved, Rejected, Pending) over every item. MD Secretariat sees the
meetings and their Status but no counts. See "The Dashboard meeting list, by role" for the columns.

[[CONFIRM: what MD Secretariat does beyond Followup and the dashboard]]

## From meeting to minutes

[[CONFIRM: not written yet]]

## Statuses

[[CONFIRM: not written yet]]

### Meeting status on the Dashboard

Each meeting in the Meetings card carries a coloured label. The colour is never the only sign: the label
always has its words. BMMS shows the first label that fits, in this order:

| Label | Colour | When it shows |
|---|---|---|
| Minutes finalised | Grey | The minutes of the meeting are finalised |
| Minutes confirmed | Grey | The minutes of the meeting are confirmed |
| Minutes pending | Red | The meeting date has passed and the minutes are not finalised or confirmed (also when the agenda was never finalised) |
| Agenda finalised | Green | The agenda is finalised and the meeting date has not passed |
| Submission closed | Orange | The date in "Submit agenda by" has passed and the agenda is not finalised. On the date itself the submission is still open |
| Open for submission | Blue | Anything else, also a meeting with no dates |

A meeting dated today is in the Scheduled list and is never "Minutes pending" that day.

## Getting help

[[CONFIRM: not written yet]]
