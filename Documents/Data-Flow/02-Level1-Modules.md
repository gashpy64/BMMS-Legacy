# Data-Flow Level 1 Modules

- Title: Data-Flow Level 1 Modules
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: UD1c (step 54: the User_Department cell of the Manager's Agenda Entry row); UD1b (step 53: the rows of the matrix that the step changed); user-ud1a
- Commit: 42cb88c
- Last updated by: UD1c, based on 42cb88c
- Status: Draft
- Verified against: for UD1c: Database/BMMS-Fix-ManagerScope-Step54.sql (fn_ManagerDepartments and the comment and Reason 30 checks of spr_AddEditAgendaByManager); the other rows were not re-checked for step 54 (the new read procedures of step 54 are in Data-Flow/03-Program-to-Program/10-Reports.md, 04-Agenda-Entry-and-Routing.md and 02-User-Master.md); for UD1b: Database/BMMS-Fix-DepartmentApprovers-Step53.sql (the comment blocks and the alert and column statements of the 20 objects), System-Manual/04-Database (the Step 53 section), Database/README.md (section Step UD1b)
- To confirm: diagram and matrix not written yet (WF2e4), except the rows of the matrix that step UD1b changed; the other processes and every unchanged cell are not written yet

## Level 1 diagram

[[CONFIRM: not written yet (WF2e4)]]

## Flows

[[CONFIRM: not written yet (WF2e4)]]

## Process-by-table R/W matrix

Only the processes that step UD1b (database step 53) changed are listed, and only the tables of the alert, route and Manager
rules. R means the process reads the table, W that it writes it, RW both; a blank cell means nothing was read for this step. The
columns that are new in step 53 are Alert_User_Map.HandledReason, HandledBy and HandledOn and Agenda.RouteNote.

| Process (procedure) | Users | Roles | User_Department | Agenda | Meeting | Alert_Master | Alert_User_Map | App_Setting | Audit_Trail_Master |
|---|---|---|---|---|---|---|---|---|---|
| Agenda Entry by a User (spr_AddEditAgenda) | R | R | R | W (RouteNote) | R | W | W | R | W |
| Agenda Entry by a Manager (spr_AddEditAgendaByManager) | R | R | R (since step 54: fn_ManagerDepartments and fn_DepartmentManagers) | W | R | W | W (no Admin role) |  | W |
| Agenda Entry by the Controller (spr_AddEditAgendaByController) | R | R | R | W | R | W | RW (the 'M' marking and its reversal) |  | W |
| Approval (spr_UpdateAgendaByAgendaId) | R | R | R | W | R | W | RW (the 'H' marking) |  | W |
| User Master save and status (spr_AddEditUser, spr_SetUserStatusByUserId) | RW | R | RW | R | R | R | RW (the 'N' marking, new rows) |  |  |
| Meeting save (spr_AddEditMeeting) | R | R |  |  | W | W | W (no Admin role) |  |  |
| Committee save (spr_AddEditCommittee) | R | R |  |  |  | W | W (no Admin role) |  |  |
| Dashboard alerts (fn_DashboardAlerts, spr_GetDashboardAlerts, spr_GetAlertCount) | R | R |  | R |  | R | R (the three handled columns) |  |  |
| Mail recipients (spr_GetAlertMailId, spr_GetAgendaUpdateMailId, spr_GetAgendaCreationMailId) | R | R | R | R |  | R | R | R |  |
| Manager alert rows (spr_SetManagerAlertRows, internal) | R | R | R | R | R | R | RW |  |  |
| System Settings, Department without an active Manager (spr_SetDepartmentManagerRule) |  |  |  |  |  |  |  | W | W |

[[CONFIRM: the cells of this matrix were taken from the comment blocks and statements of the Fix script and the chapter 04 tables, not from a line-by-line read of the long save procedures; the owner or the WF2e4 pass confirms them]]

## Drawn from

Database/BMMS-Fix-DepartmentApprovers-Step53.sql, System-Manual/04-Database.md ("Step 53 (UD1b)", the routing, approval, meeting,
committee and alert tables), Database/README.md (section Step UD1b).
