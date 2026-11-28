# Workflow: Meeting Life Cycle

- Title: Workflow: Meeting Life Cycle
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: FU2a (step 48): two decision points on the Action Items card and panel; UN6c2b (step 45): the decision points for the statistics, the summary cards and the Committee filter; UN6b (step 42): the meeting status on the Dashboard; the rest not written yet
- Last updated by: FU2a, based on 9336d29
- Status: Draft
- Verified against: for step FU2a: Database/BMMS-Fix-DashboardFollowupFinal-Step48.sql (the Reason lines), BMMS/DashBoard/DashBoard.aspx.cs (diff), Database/README.md (section Step FU2a);
  for step UN6c2b: Database/BMMS-Fix-DashboardSummary-Step45.sql (fn_DashboardCommitteeFilter, spr_GetDashboardSummary, spr_GetDashboardMeetings header), Database/README.md (section Step UN6c2b);
  for the Dashboard status (step UN6b): Database/BMMS-Fix-DashboardMeetings-Step42.sql
  (fn_MeetingDashboardState, spr_GetDashboardMeetings), BMMS/UserControl/MeetingSummary.ascx.cs,
  BMMS/DashBoard/DashBoard.aspx.cs (diff: Reload after Approve and Reject), Database/README.md (section Step UN6b),
  Documents/User-Manuals/Glossary.md (the screens of each role)
- To confirm: workflow only partly written (WF2e2): the lanes below show the meeting status the Dashboard gives at
  each stage; the agenda routing, the approval stages, the minutes steps, the follow-up and the mails are not drawn
  yet

## Lanes

The meeting status the Dashboard shows (step UN6b) follows the stages of the life cycle below. Three lanes: the
Controller (who saves the meeting, finalises the agenda and takes the minutes through their steps), the Manager and
the User (who enter and decide agenda items) and the Dashboard (what every role sees in the Meetings card).

[[CONFIRM: the lanes for the Admin, MD Secretariat and Management, the agenda routing and the mails are not written yet (WF2e2)]]

## Workflow diagram

```mermaid
flowchart LR
    subgraph Controller["Controller"]
        c1["Saves the meeting with its meeting date and Submit agenda by date"]
        c2["Agenda Finalize"]
        c3["Update Minutes, then Finalize Minutes"]
        c4["Minutes Confirmation"]
    end
    subgraph ManagerUser["Manager and User"]
        m1["Enter agenda items on Agenda Entry"]
        m2["Items are approved or rejected"]
    end
    subgraph Dash["Dashboard, Meetings card (every role)"]
        s1["Scheduled, Open for submission (blue)"]
        d1{"Submit agenda by date passed?"}
        s2["Scheduled, Submission closed (orange)"]
        s3["Scheduled, Agenda finalised (green)"]
        d2{"Meeting date passed?"}
        s4["Completed, Minutes pending (red)"]
        s5["Completed, Minutes finalised (grey)"]
        s6["Completed, Minutes confirmed (grey)"]
    end

    c1 --> s1
    s1 --> m1
    m1 --> m2
    m2 --> d1
    d1 -->|"no"| s1
    d1 -->|"yes"| s2
    s2 --> c2
    s1 --> c2
    c2 --> s3
    s3 --> d2
    d2 -->|"no"| s3
    d2 -->|"yes"| s4
    s4 --> c3
    c3 --> s5
    s5 --> c4
    c4 --> s6
    m2 -.->|"after Approve or Reject the counts are read again"| s1
```

What the diagram shows. A meeting is Scheduled until the end of its meeting date and Completed after it. The
status label is the first rule that fits: grey when the minutes are finalised or confirmed, red when the meeting
date has passed and the minutes are not finalised or confirmed (also if the agenda was never finalised), green when
the agenda is finalised, orange when the Submit agenda by date has passed, blue otherwise. The arrows between the
Controller and Manager lanes show who does the work, the arrows into the Dashboard lane show which label follows.
The last arrow is dashed: the Meetings card is read again after a successful Approve or Reject, so the four counts
follow the decision (counts are shown to the Controller, Management, the Manager and the User; not to MD
Secretariat and Admin).

| From | To | Data | Notes |
|---|---|---|---|
| Controller | Dashboard | A saved meeting | Blue "Open for submission", also for a meeting with no dates |
| Dashboard | Manager and User | The open meeting | Agenda items are entered on Agenda Entry |
| Manager and User | Dashboard | Items approved or rejected | The counts of Items, Approved, Rejected and In progress (headed Pending for some roles before step 45) change; since step 45 the summary cards Items in progress and Items rejected change too |
| Controller | Dashboard | Agenda finalised | Green "Agenda finalised" until the meeting date passes |
| Dashboard | Controller | Meeting date passed, minutes still open | Red "Minutes pending" |
| Controller | Dashboard | Minutes finalised | Grey "Minutes finalised" |
| Controller | Dashboard | Minutes confirmed | Grey "Minutes confirmed" |

## Decision points

| Decision | Who | Rule | Where it lives |
|---|---|---|---|
| Is the meeting in the Scheduled or the Completed list? | The database, for every role | The meeting date is today or later (or there is no date): Scheduled; before today: Completed. Today is the database server's date, so a meeting dated today is Scheduled until the end of that day | fn_MeetingDashboardState (IsScheduled) |
| Which label does the meeting carry? | The database, for every role | The first rule that fits: grey (minutes F or C), red (date before today), green (agenda not Open), orange (submission date before today; the submission date itself is still open), blue | fn_MeetingDashboardState (StateCode, StateLabel); MeetingSummary.StateCssClass for the chip |
| How many completed meetings are listed? | The database | The last 10, newest first, for every role | spr_GetDashboardMeetings (TOP 10) |
| Does a Manager or a User see a completed meeting? | The database, from the acting user id | Only when the meeting has at least one item of one of their departments | spr_GetDashboardMeetings with fn_UserDepartmentScope |
| Are the counts shown? | The database | Controller, Management, Manager, User: yes; MD Secretariat: yes since step 45, read-only; Admin: no | spr_GetDashboardMeetings (@StatisticsShown) |
| Which items does a count cover? | The database | Controller, Management and MD Secretariat: every item; Manager and User: the items of their department(s). Approved is ACA, Rejected is AMR and ACR, In progress (column Pending) is AC and AMA | fn_AgendaStatusGroup; spr_GetDashboardMeetings |
| Who has the summary cards, and what do they count? (step 45) | The database | Controller, Management, Manager, User: the items of Scheduled meetings in progress (AC, AMA) and rejected (AMR, ACR), for the committee and department chosen; MD Secretariat and Admin: no cards. Each equals the total of its column in the Scheduled list | spr_GetDashboardSummary; fn_AgendaStatusGroup |
| Which committee may be chosen? (step 45) | The database | All committees (0), or an active committee; an inactive or unknown one is refused (Reason 4) by the meeting list, the summary, My approvals and the Action Items card | fn_DashboardCommitteeFilter |
| When are the counts read again? | The Dashboard | After a successful Approve or Reject on the Dashboard | DashBoard.aspx.cs (MeetingSummary1.Reload) |
| May the action text of a followup be changed on the Dashboard? (step FU2a) | The database, for every role | Not when the followup is confirmed: Reason 26, nothing saved; the role checks (Reason 8, 4) and the scope (Reason 4) come first. A confirmed followup is final until the Controller reopens it on the Followup page | spr_SaveDashboardActionText |
| Does the Action Items card list a confirmed followup? (step FU2a) | The database | No, for every role; a confirmed item of the person's scope can still be opened (a stale row, or a panel opened before the confirm), read-only. A Pending item whose latest history row is a Reopen carries the chip "Reopened" | fn_DashboardActionItems, spr_OpenDashboardActionItem, fn_DashboardActionItemScope (IsReopened) |

## Drawn from

Database/BMMS-Fix-DashboardMeetings-Step42.sql (fn_MeetingDashboardState, fn_AgendaStatusGroup,
fn_UserDepartmentScope, spr_GetDashboardMeetings); BMMS/UserControl/MeetingSummary.ascx.cs (StateCssClass, RoleViews);
BMMS/DashBoard/DashBoard.aspx.cs (Reload calls); Documents/User-Manuals/Glossary.md (which role uses Agenda Entry,
Agenda Finalize, Update Minutes, Finalize Minutes and Minutes Confirmation); Database/README.md (section Step UN6b).
