# Program to Program: Reports

- Title: Program to Program: Reports
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: RA1c1
- Last updated by: RA1c1, based on 4946500
- Status: Draft
- Verified against: for step RA1c1: BMMS/Report/ViewReport.aspx.cs (git diff against 4946500); and before:
  BMMS/Report/Reports.aspx.cs, Followup.aspx.cs, ViewReport.aspx.cs (diff of step RA1b),
  BMMS/PageAccessModule.cs (HasRole, RefuseRequest), BMMSBAL/ReportsMgr.cs, BMMSBAL/HTML_Report.cs,
  BMMSDAL/MinutesDB.cs and ActionItemDB.cs (the three calls), Database/BMMS-Fix-ReportAccess-Step41.sql,
  BMMS-Test-ReportAccess-Step41.sql (header), BMMS/XML/PageAccess.xml, Database/README.md (section RA1b)
- To confirm: the file covers only the flows changed in step RA1b (the Minutes report in every status and
  Management's Followup); the other reports (agenda reports, Minutes Extract, the Controller's Followup,
  notices, sitting fees and so on) are not written yet (WF2c3); the tables the three procedures read are
  from the views named in their header (View_Minute, View_Meeting, View_Action_Item), not from the view
  texts

## Scope

The report pages that read minutes and follow-up data: Reports.aspx (rc=minutes) for the Controller,
the Manager and Management, and Followup.aspx (fc=followup, fc=summary) for the Controller and Management,
with ViewReport.aspx that shows, prints and exports what they built. Written for step RA1b (step 41).
[[CONFIRM: the other report pages are not written yet (WF2c3)]]

## Programs involved

| Program | Role in this flow |
|---|---|
| Report/Reports.aspx(.cs) | Meeting list, filters, grid, builds the report HTML for rc=minutes |
| Report/Followup.aspx(.cs) | Same for fc=followup and fc=summary |
| Report/ViewReport.aspx(.cs) | Shows the stored report, Print, Export to Pdf, Export to Word |
| PageAccessModule | RequireRole, HasRole, RefuseRequest (role read from the database) |
| ReportsMgr, HTML_Report (BMMSBAL) | The three report calls, StatusMarkOf, refusal texts; MinutesStatusLine, DraftNote |
| MinutesDB, ActionItemDB (BMMSDAL) | The three procedure calls with the OUTPUT parameters |
| spr_GetMinutesReportMeetingsAllStatus, spr_GetMinutesReportAllStatus, spr_GetFollowupReportForManagement | Step 41, read only, check the acting user |

## Main flow

The Minutes report in every status (Controller and Management). A Manager or any other allowed role takes
the older path (spr_GetMinutesReportMeetings and spr_GetMinutesReport, finalised and confirmed only).

```mermaid
sequenceDiagram
    participant Br as Browser
    participant Pg as Reports.aspx
    participant PM as PageAccessModule
    participant BL as ReportsMgr
    participant DB as MinutesDB
    participant SQ as spr_GetMinutesReport..AllStatus
    participant VR as ViewReport.aspx
    Br->>Pg: Reports.aspx?rc=minutes
    Pg->>PM: RequireRole controller, manager, mgmt
    PM->>Pg: Allowed (role read from the database)
    Pg->>PM: HasRole controller, mgmt
    PM->>Pg: true, so the every-status path
    Pg->>BL: GetMinutesReportMeetingsAllStatus committee, UserId
    BL->>DB: Same call
    DB->>SQ: CommitteeId, ActingUserId
    SQ->>DB: Meetings with MinutesStatusMark, Result, Reason
    DB->>Pg: Meeting list
    Br->>Pg: Generate
    Pg->>BL: GetMinutesReportAllStatus filters, UserId
    BL->>DB: Same call
    DB->>SQ: Nine filters, ActingUserId
    SQ->>DB: Minutes rows with MinutesStatus and mark
    Pg->>Pg: Report HTML with the status line and the draft note
    Pg->>VR: Session holds the report and ViewReportKind minutes
    VR->>Br: Report, Print, Export to Pdf, Export to Word
```

| From | To | Data | Notes |
|---|---|---|---|
| Browser | Reports.aspx | rc=minutes | Any other rc than minutes, minutes_extract, agenda_summary and agenda_details is refused |
| Reports.aspx | PageAccessModule | RequireRole and HasRole | Decided on every request, never from the address or ViewState |
| Reports.aspx | ReportsMgr, MinutesDB | CommitteeId, ActingUserId (the session's UserId) | The meeting list |
| MinutesDB | spr_GetMinutesReportMeetingsAllStatus | @CommitteeId, @ActingUserId | OUTPUT @Result and @Reason |
| spr_GetMinutesReportMeetingsAllStatus | Reports.aspx | Meetings with at least one minutes row, any status, with MinutesStatusMark | By MeetingNo |
| Reports.aspx | spr_GetMinutesReportAllStatus | Nine filters of the Minutes report, ActingUserId | No finalised or confirmed filter |
| Reports.aspx | ViewReport.aspx | Report HTML in the session, Session["ViewReportKind"] | The kind is cleared first and set after the report is stored |

Management's Followup: Followup.aspx (fc=followup or summary) calls RequireRole("controller", "mgmt"); for
Management (HasRole("mgmt")) it calls ReportsMgr.GetFollowupReportForManagement, which calls
spr_GetFollowupReportForManagement with the committee, meeting, department and confirm filters and the acting
user; the rows carry MinutesStatus and MinutesStatusMark. The Controller keeps ReportsMgr.GetFollowupReport,
a query built in the code, with no mark. The mark is printed as "Minutes status: [mark]" under each item
(Followup) or in a "Minutes status" column (Followup Summary), and a draft item gets the bordered draft note.

Drawn from: BMMS/Report/Reports.aspx.cs (Page_Load, GetReportMeetings, GetReportDetails, the HTML of the
minutes), BMMS/Report/Followup.aspx.cs (Page_Load, GetReportDetails and the two HTML builders),
BMMSBAL/ReportsMgr.cs, BMMSBAL/HTML_Report.cs, BMMSDAL/MinutesDB.cs, BMMSDAL/ActionItemDB.cs,
Database/BMMS-Fix-ReportAccess-Step41.sql (header).

## Refusal paths

| Where | When | What happens |
|---|---|---|
| Reports.aspx Page_Load | rc missing or not one of the four codes | PageAccessModule.RefuseRequest("unknown report code"): DENIED-PAGE in the log, "Access denied" |
| Reports.aspx Page_Load | rc=minutes: role not controller, manager or mgmt; another rc: role not controller or manager | RequireRole refuses: "Access denied" |
| Followup.aspx Page_Load | fc not followup or summary; role not controller or mgmt | "Access denied" |
| Followup.aspx Page_Load | Session role mgmt but the database role could not be read | RefuseRequest("role could not be read for the Management path") |
| ViewReport.aspx Page_Load | Database or session role mgmt, and ViewReportKind missing, empty or not minutes, followup or summary, or ?pdf=1 | RefuseRequest("report kind not allowed for the role") |
| ViewReport.aspx Page_Load (after the check above) | No stored report: Session["ViewReport"] null or empty (opened by address, or the session ended), or the Export to Pdf or Export to Word postback with none | Not a refusal: HTTP 200, a page that says "The report is no longer available. Close this window and click Generate again.", no error-log entry, the request ends (step RA1c1). Page_Load answers first; the two export handlers check again |
| spr_GetMinutesReportMeetingsAllStatus, spr_GetMinutesReportAllStatus | Reason 8: acting user missing, 0 or inactive | No rows; the page shows "Your session is no longer valid. Please log in again." |
| The same procedures | Reason 4: role not controller or mgmt | No rows; "You are not allowed to see this report." |
| spr_GetFollowupReportForManagement | Reason 8 as above; Reason 4: role not mgmt | No rows; the same two messages |

Empty meeting list on the every-status path: "No meetings with minutes for this committee."

## Where each rule lives

| Rule | C# | Procedure |
|---|---|---|
| Who may open each report page | PageAccess.xml; RequireRole in Reports.aspx.cs and Followup.aspx.cs; ViewReport.aspx.cs for Management | none |
| Message when no report is stored | ViewReport.aspx.cs (NoStoredReport, SendNoReportMessage; also in the two export handlers) | none |
| Every-status path for the Controller and Management | Reports.aspx.cs (allStatus from HasRole) | spr_GetMinutesReportMeetingsAllStatus, spr_GetMinutesReportAllStatus |
| Acting user check, Reasons 8 and 4 | ReportsMgr.ReportRefusedMessage turns them into text | The three step 41 procedures |
| The mark (F Finalised, C Confirmed, anything else Draft (not finalised)) | ReportsMgr.StatusMarkOf reads it | The three step 41 procedures |
| Status line and draft note | HTML_Report.MinutesStatusLine, DraftNote, IsDraftMark (one-cell table with border 1, because the PDF export draws a table border but not a div border) | none |
| Manager and other roles: finalised and confirmed only | Reports.aspx.cs (older path) | spr_GetMinutesReport, spr_GetMinutesReportMeetings (step 22, unchanged) |

## Tables read and written

None written. The three procedures read the views View_Minute (minutes rows), View_Meeting (meetings) and
View_Action_Item (follow-up rows), and Users and Roles for the acting user's role. PageAccessModule reads
the user through UserMgr.GetUserDataTableByUserId (View_Users).

## Drawn from

BMMS/Report/Reports.aspx.cs, Followup.aspx.cs, ViewReport.aspx.cs, BMMS/PageAccessModule.cs,
BMMS/XML/PageAccess.xml, BMMSBAL/ReportsMgr.cs, BMMSBAL/HTML_Report.cs, BMMSDAL/MinutesDB.cs,
BMMSDAL/ActionItemDB.cs, Database/BMMS-Fix-ReportAccess-Step41.sql (header and first procedure),
Database/BMMS-Test-ReportAccess-Step41.sql (header), Database/README.md (section RA1b).
