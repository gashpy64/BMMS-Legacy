# BMMS Glossary

- Audience: Everyone who uses BMMS
- Version: filled in at export
- Date: filled in at export

This glossary explains the words BMMS uses on its screens and in its mails. Screen names are
written as the menu shows them. More terms are added as the manuals are written.

## Roles

Every person who signs in to BMMS has one role. The role decides which menus you see and what
you may do on each screen.

The two top roles share the work by one rule. The Admin is superior for the technical items (user
accounts, the code masters, Reset Password, Backup Database, SMTP Configuration, System Settings,
Audit Trail and Reset Database). The Controller is superior for the functional items (the agenda,
the meetings, the minutes, the follow-up and the reports) and has all of the functional rights.

| Role | In short |
|---|---|
| User | Enters agenda items on Agenda Entry. |
| Manager | Enters agenda items, approves or rejects the agenda items sent to them, and uses the Reports menu. |
| Controller | Approves or rejects agenda items after the Manager, or items sent straight to the Controllers. Uses Agenda Entry, Agenda Finalize, Update Minutes, Finalize Minutes, Minutes Confirmation, Followup and the reports. The Minutes report shows the Controller every meeting that has minutes, in every minutes status, each marked Draft (not finalised), Finalised or Confirmed. The Master menu shows Member Master, Committee Master, Committee Member Tag / UnTag, Meeting Master, Meeting - Member Tag / UnTag and Attendance. A Controller has no Admin menu, cannot open User Master, the code masters, Reset Password, Backup Database or Audit Trail, and changes only their own password. |
| Admin | Is the only role that uses User Master, Department, Designation, Member Type, Subject Type and Decision Type (Master menu), and the Admin menu (Reset Password, Backup Database, SMTP Configuration, System Settings, Audit Trail, Reset Database). Views agenda items on the dashboard but does not approve them. The menu has no Home link for Admin; the dashboard opens after sign-in. |
| MD Secretariat | Uses the Followup screen. Views agenda items on the dashboard but does not approve them. The menu has no Home link for MD Secretariat; the dashboard opens after sign-in. |
| Management | Views agenda items on the dashboard but does not approve them. Has a Reports menu with Minutes, Followup and Followup Summary only: the Minutes report in every minutes status and the follow-up reports for all committees in the list, each marked with its minutes status. Has no Minutes Extract. |

## Terms

**Agenda item** - A subject proposed for a meeting. It is entered on the Agenda Entry screen and is
then approved or rejected.

**Proposed Resolution** - The resolution suggested with an agenda item when it is entered.

**Approve, reject** - The decision on an agenda item. An item entered by a User whose own Manager
is active waits for that Manager first; otherwise it goes straight to the Controllers. After the
Manager has approved it, a Controller decides. The Approve and Reject buttons appear on the
dashboard only for the person who decides the item at that moment. Each decision sends a mail;
if the mail cannot be sent, the decision is still saved and the screen says so.

**Meeting date passed** - Once the date of the meeting has passed, its agenda items can no longer
be approved or rejected. The dashboard shows them read-only with the message "The meeting date
has passed, so this item can no longer be approved or rejected. It will be rejected when the
agenda is finalized."

**Committee** - A group of members that holds meetings, for example a board or one of its
committees.

**Committee member** - A member who belongs to a committee.

**Meeting** - One sitting of a committee, with a date, its agenda items and its minutes.

**In Attendance** - A person tagged on a meeting as attending without being a committee member.
The first person tagged In Attendance signs the meeting notice and the follow-up mails.

**Special Invitee, Invitee** - People invited to a meeting. The minutes list them under
"On invitation".

**Agenda Finalize** - The screen where the Controller finalizes the agenda of a meeting. After
that, its agenda items can no longer be approved or rejected; items that were still undecided
are rejected.

**Minutes** - The record of what was decided at a meeting.

**Minutes status** - Where the minutes of a meeting stand: Draft (not finalised), Finalised or
Confirmed. The Controller and Management see the Minutes report in every status; the line
"Minutes status: [status]" is printed under each meeting, and a draft also carries a bordered note
"DRAFT - not finalised; this is not the approved text of the minutes." The Manager and the other
roles see finalised and confirmed minutes only.

**Update Minutes** - The screen where the Controller records the minutes after the meeting,
including the Actual Resolution of each item.

**Actual Resolution** - The resolution as recorded in the minutes.

**Finalize Minutes, Minutes Confirmation** - The screens where the Controller finalizes the
minutes and then confirms them.

**Followup** - A decision in the minutes that someone must act on, with a due date, and the
screen where its progress is recorded. Followup Summary is a report on them.

**Dashboard** - The screen you see after you sign in. It lists the agenda items and alerts that
concern you. The first time you sign in, BMMS asks you to change your password before it shows
the dashboard.

**Alert** - A notice on your dashboard, for example that an agenda item is waiting for your
decision. You can remove an alert from your own list; this does not change the agenda item.

**Department** - The part of the organisation a person works in. Every user has one home
department. A Manager can also look after further departments.

**Home department** - The department shown with your user details. For a Manager it is always
one of their departments.
