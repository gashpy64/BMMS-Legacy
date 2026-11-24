# Program to Program: Agenda Entry and Routing

- Title: Program to Program: Agenda Entry and Routing
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: UD1c (step 54: the new section "A Manager's departments (step UD1c)": the list filter, Edit, Update and a Manager's new item, Reason 30, the alert to the other Managers); UD1b (step 53: the route of a new item, the Managers' alert rows and the Created mail); user-ud1a
- Commit: 42cb88c
- Last updated by: UD1c, based on 42cb88c
- Status: Draft
- Verified against: for UD1c: BMMS/Master/Agenda.aspx and Agenda.aspx.cs (diff: ManagerDepartments, LoadListDepartments, ListDepartmentId, the new-item department of a Manager, the Save branch, CheckItemAccess, the Created mail's department), BMMSBAL/AgendaMgr.cs, DepartmentMgr.cs and MeetingMgr.cs (diff), BMMSDAL/AgendaDB.cs and DepartmentDB.cs (diff stat), Database/BMMS-Fix-ManagerScope-Step54.sql (fn_ManagerDepartments, spr_GetManagerDepartments, spr_GetAgendaByMeetingIdDeptId read in full; spr_AddEditAgendaByManager read to the Save insert and its comment block; the alert insert to the other Managers is taken from that comment block and Database/README.md, not read line by line), Database/README.md (section Step UD1c); for UD1b: BMMS/Master/Agenda.aspx.cs (diff: CheckNewItemRoute, GenerateMail, the save message), BMMSBAL/AgendaMgr.cs, MeetingMgr.cs and BMMSDAL/AgendaDB.cs (diff), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_DepartmentManagers, fn_AgendaRoute, spr_SetManagerAlertRows, spr_GetAgendaCreationMailId read; the comment blocks and the Save branch of spr_AddEditAgenda read; the other save procedures: their alert inserts), Database/README.md (section Step UD1b)
- To confirm: the alert to the other active Managers of a Manager's new item (step 54) is taken from the comment block of spr_AddEditAgendaByManager and Database/README.md, not from the alert statement itself: read that statement to verify the recipients; feature area written only for the route of a new item and its alerts and mail (step UD1b); the numbering of items, the update, the delete, the meeting-date and lock checks and the attachment handling are not written yet (WF2c2)

## Scope

This file covers, since step UD1b (database step 53), what happens when a user saves a new agenda item: the route (to the
Managers of the item's department, straight to the Controllers, or refused), the alert rows and the Created mail. Items
entered by a Manager (they start at AMA) or by the Controller (they start at ACA) keep their route; only their alert
recipients lose the Admin role.

[[CONFIRM: the rest of the feature area (numbering, update, delete, lock and date checks, attachments) is not written yet (WF2c2)]]

## Programs involved

| Program | Kind | Part in the flow |
|---|---|---|
| Master/Agenda.aspx(.cs) | Page | `btnSave_Click`; `CheckNewItemMeetingDate`, `CheckNewItemRoute(DepartmentId)` before the save; `GenerateMail(DepartmentId, SentToControllerNote)` after it |
| AgendaMgr.GetAgendaCreationMailId, AgendaDB.GetAgendaCreationMailId | BAL, DAL | Call spr_GetAgendaCreationMailId with the user and the department; the BAL throws when the result has no Route or no RouteNote column |
| AgendaMgr.AddEditAgenda, AgendaDB.AddEditAgenda | BAL, DAL | Call spr_AddEditAgenda for a new item of a User; return Result, Reason, ReasonDetail |
| MeetingChangeResult, MeetingChangeReason (MeetingMgr.cs) | BAL | Turn Reason 29 into its message; hold the line "Sent to the Controller: the department had no active Manager." |
| Mail_Mgr.SendWebEmail | BAL | Sends the "has been Created" mail |
| spr_GetAgendaCreationMailId | Procedure | Reads fn_AgendaRoute for the department; returns Route, ManagerName, ActiveControllers, EmailId rows (the Bcc), DepartmentManagers, RouteNote, DepartmentName |
| spr_AddEditAgenda | Procedure | Reads the route again, refuses or saves the item, writes the alert and its rows |
| spr_SetManagerAlertRows | Internal procedure | Gives every active Manager of the department an unread row on the item's alert |
| fn_AgendaRoute, fn_DepartmentManagers | Inline table functions | The route, and the one definition of the active Managers of a department |

## Main flow

```mermaid
sequenceDiagram
    participant U as User
    participant P as Agenda.aspx.cs
    participant B as AgendaMgr
    participant SR as spr_GetAgendaCreationMailId
    participant SA as spr_AddEditAgenda
    participant SM as spr_SetManagerAlertRows
    participant T as Agenda, Alert_Master, Alert_User_Map
    participant X as Mail_Mgr

    U->>P: Save (department, meeting, text)
    P->>B: GetAgendaCreationMailId(user id, department id)
    B->>SR: UserId, DepartmentId
    SR-->>P: Route, ActiveControllers, DepartmentName
    alt Route R - no active Manager and the setting says Refused
        P-->>U: "Not saved: the department [department name] has no active Manager. Ask the Admin to nominate a Manager for the department."
    else Route M, or C with an active Controller
        P->>B: AddEditAgenda(item, acting user id)
        B->>SA: item fields, acting user
        SA->>SA: fn_AgendaRoute again (Reasons 11, 15, 29)
        SA->>T: the item (AC for M, AMA for C), RouteNote N when sent to the Controller, and the alert
        alt Route M
            SA->>SM: alert id, acting user
            SM->>T: one unread row for each active Manager of the department, the creator left out
        else Route C
            SA->>T: unread rows for the active Controllers
        end
        SA-->>P: Result 1, ReasonDetail SentToController when RouteNote is N
        P->>B: GetAgendaCreationMailId(user id, department id)
        B->>SR: UserId, DepartmentId
        SR-->>P: the Bcc addresses (the Managers, or the Controllers)
        P->>X: Created mail
        P-->>U: "Successfully Saved", or "Successfully Saved. Sent to the Controller: the department had no active Manager." when it applies
    end
```

| From | To | Data | Notes |
|---|---|---|---|
| User | Agenda.aspx | The new item and its department | Saved by Save; a Manager or the Controller does not take the route check |
| Agenda.aspx | AgendaMgr.GetAgendaCreationMailId | Acting user id, the item's department id | Called twice: before the save (the refusals) and after it (the Bcc) |
| spr_GetAgendaCreationMailId | Agenda.aspx | Route (I, C, M or R), ActiveControllers, DepartmentName, RouteNote | Route I is the step 20 refusal, C with no active Controller the step 20 refusal; R is new |
| Agenda.aspx | spr_AddEditAgenda | The item, the acting user | The procedure decides again; the page's check is a first look |
| spr_AddEditAgenda | Agenda | The item with AgendaStatusCode AC (route M) or AMA (route C), RouteNote 'N' when the setting sent it to the Controller | |
| spr_AddEditAgenda | Alert_Master | One alert of the type of the status | |
| spr_SetManagerAlertRows | Alert_User_Map | One unread row for each active Manager of the department, the creator left out | Never for the Admin role; refused unless called by another procedure |
| spr_AddEditAgenda | Agenda.aspx | Result 1 and ReasonDetail 'SentToController' when it applies | The page adds the Controller line to its message, also when the mail then fails |
| Agenda.aspx | Mail_Mgr.SendWebEmail | To the creator, Bcc the department's Managers or the Controllers; the body adds the Controller line when it applies | Sent only after the database accepted the item |

The route, in this order (fn_AgendaRoute): the creator's Reporting Person is set but inactive: refused (Reason 11,
unchanged); the Reporting Person is an active Controller: straight to the Controllers (AMA); the department has an active
Manager other than the creator: waits at AC; otherwise the setting DeptNoManagerAction: Refused (Reason 29), or Sent to the
Controller (AMA with RouteNote 'N'). Route C with no active Controller is refused (Reason 15, unchanged).

## Refusal paths

| Reason | Raised by | Meaning | Message the page shows |
|---|---|---|---|
| 29 | spr_AddEditAgenda (the page's own route check stops it first) | The department has no active Manager and the setting says Refused; nothing saved, no mail | "Not saved: the department [department name] has no active Manager. Ask the Admin to nominate a Manager for the department." |
| 11 | spr_AddEditAgenda | The creator's Reporting Person is inactive | "Your manager ([manager name]) is inactive, so this agenda item cannot be sent for approval. Ask the administrator to assign you an active manager." |
| 15 | spr_AddEditAgenda | The item would go to the Controllers and none is active | "No Controller is active, so this agenda item cannot be sent for approval. Ask the administrator to activate a Controller." |

## Where each rule lives

| Rule | C# | Procedure or function |
|---|---|---|
| The route of a new item of a User | `CheckNewItemRoute` (first look), `MeetingChangeReason.DepartmentHasNoManagerMessage` | fn_AgendaRoute, spr_AddEditAgenda (Reason 29, 11, 15) |
| Who the active Managers of a department are | none | fn_DepartmentManagers (role Manager, active, not the system account, an open department mapping; a user with no mapping rows counts by his home department) |
| One unread row for every Manager of the department; none for the Admin role | none | spr_SetManagerAlertRows (route M); the alert inserts of the save procedures |
| The Controller line in the message and the mail | `MeetingChangeReason.SentToControllerNoManagerNote`, `GenerateMail` | spr_AddEditAgenda (ReasonDetail 'SentToController') |
| The Bcc of the Created mail | `GenerateMail` | spr_GetAgendaCreationMailId; a Reporting Person of the Admin role is left out of the Bcc of a Manager's or the Controller's item in `GenerateMail` |
| Items entered by a Manager or the Controller | `btnSave_Click` | spr_AddEditAgendaByManager (AMA), spr_AddEditAgendaByController (ACA); alerts without the Admin role |

## Tables read and written

| Object | Reads | Writes |
|---|---|---|
| fn_AgendaRoute | Users, Roles, Department, App_Setting, and fn_DepartmentManagers | none |
| fn_DepartmentManagers | Users, Roles, User_Department | none |
| spr_GetAgendaCreationMailId | fn_AgendaRoute, Users, Roles | none |
| spr_AddEditAgenda | Users, Meeting, Committee, Subject_Type, and fn_AgendaRoute | Agenda (the new column RouteNote), Alert_Master, Alert_User_Map, Audit_Trail_Master |
| spr_SetManagerAlertRows | Users, Roles, User_Department, Agenda, Meeting, Alert_Master, Alert_User_Map | Alert_User_Map |

## A Manager's departments (step UD1c)

Since step 54 "a Manager's departments" are the departments of which he is an active Manager (fn_ManagerDepartments, one copy
of the rule: fn_DepartmentManagers of step 53). A User has his own department, the Controller every department. The page reads
them from the database each time it needs them (spr_GetManagerDepartments: home first; IsHome, IsActive), and the procedures
check them again; a posted department is never trusted.

```mermaid
sequenceDiagram
    participant M as Manager
    participant P as Agenda.aspx.cs
    participant SD as spr_GetManagerDepartments
    participant SL as spr_GetAgendaByMeetingIdDeptId
    participant SU as spr_AddEditAgendaByManager
    participant T as Agenda, Alert_Master, Alert_User_Map

    M->>P: open Agenda Entry
    P->>SD: ActingUserId
    SD-->>P: his departments (Reason 8 or 4: none)
    P-->>M: Department filter: All my departments, then his departments
    M->>P: choose a meeting or a department
    P->>SL: meeting, user, department (0 = all)
    SL-->>P: items of the scope and the items he entered, with Entered by
    M->>P: Edit (an item), Update
    P->>SD: read again (CheckItemAccess)
    alt the item is of none of his departments and he did not enter it
        P-->>M: "You can open only the agenda items of your departments and the items you entered."
    else allowed
        P->>SU: Update (the department, status and creator are never written)
        SU-->>P: Result, or Reason 30 when the item is of another department and he did not enter it
    end
    M->>P: Add, Save (department chosen, or fixed when he has one)
    P->>SD: read again, the department must be an active one of his
    alt not one of his active departments
        P-->>M: "Not saved: you are not a Manager of that department."
    else allowed
        P->>SU: Save (department)
        SU->>T: the item (AMA) and its alert (step 53 recipients, and the other active Managers of the department)
        SU-->>P: Result 1
    end
```

| From | To | Data | Notes |
|---|---|---|---|
| Agenda.aspx.cs (LoadListDepartments) | spr_GetManagerDepartments | ActingUserId | The filter holds "All my departments" (value 0), then every row, marked " (home)" and " (inactive)". Reason 8 or 4: the message "Your session is no longer valid. Please log in again." or "Your departments could not be read: you may no longer be a Manager. Reload the page." and Add disabled |
| Agenda.aspx.cs (LoadAgenda) | AgendaMgr.GetAgendaByMeetingIdDeptId | MeetingId, UserId, the chosen department (0 = all) | A Manager only; the Controller's list is unchanged |
| spr_GetAgendaByMeetingIdDeptId | Agenda.aspx.cs | The items of the meeting entered by the user, or of one of fn_ManagerDepartments(user); with a department chosen, only that department's items | EnteredByName; the step 33 text is replaced, its marker kept |
| Agenda.aspx.cs (CheckItemAccess) | spr_GetManagerDepartments | ActingUserId | On Edit and Update; an inactive department of his counts, as the list shows it |
| Agenda.aspx.cs (new item) | spr_GetManagerDepartments | ActingUserId | Several active departments: the Department drop-down, home first; one: fixed; reads again at Save; only an active department passes; Reason 8 or 4: the form is not opened |
| Agenda.aspx.cs | spr_AddEditAgendaByManager | The item, the acting user | Reason 30 (nothing saved) for a new item outside his active departments and for an Update of an item that is of none of his departments and that he did not enter |
| spr_AddEditAgendaByManager | Alert_Master, Alert_User_Map | The new item's alert | Also to the other active Managers of the item's department (fn_DepartmentManagers), whatever their home department |
| Agenda.aspx.cs (GenerateMail) | Mail_Mgr.SendWebEmail | The department name of the Manager's choice | In the Created mail |

| Reason | Raised by | Meaning | Message the page shows |
|---|---|---|---|
| 30 | spr_AddEditAgendaByManager (the page's own check stops it first) | A new item in a department of which he is not an active Manager, or an Update of an item of another department that he did not enter | "Not saved: you are not a Manager of that department." |

Where each rule lives:

| Rule | C# | Procedure or function |
|---|---|---|
| A Manager's departments | `Agenda.aspx.cs` ManagerDepartments, `DepartmentMgr.GetManagerDepartments` | fn_ManagerDepartments, spr_GetManagerDepartments |
| The list of a Manager and the filter | `LoadListDepartments`, `ListDepartmentId`, `LoadAgenda` | spr_GetAgendaByMeetingIdDeptId (optional @DepartmentId) |
| Edit and Update access | `CheckItemAccess`, `ItemNotInDepartmentMessage` | spr_AddEditAgendaByManager (Reason 30) |
| A Manager's new item department | btnAdd (the form), btnSave_Click (the Save branch), `MeetingChangeReason.NotManagerOfDepartmentMessage` | spr_AddEditAgendaByManager (Reason 30) |
| The alert to the other Managers | none | spr_AddEditAgendaByManager |

Tables read and written: fn_ManagerDepartments reads Department, Users, Roles, User_Department (through fn_DepartmentManagers);
spr_GetManagerDepartments reads Users, Roles, Department; spr_GetAgendaByMeetingIdDeptId reads View_Agenda and Users and writes
nothing; spr_AddEditAgendaByManager writes the same tables as before step 54 (Agenda, Alert_Master, Alert_User_Map; the step 54 text was
not compared table by table).

## Drawn from

BMMS/Master/Agenda.aspx.cs (btnSave_Click, CheckNewItemRoute, GenerateMail), BMMSBAL/AgendaMgr.cs and MeetingMgr.cs,
BMMSDAL/AgendaDB.cs, Database/BMMS-Fix-DepartmentApprovers-Step53.sql (fn_DepartmentManagers, fn_AgendaRoute,
spr_SetManagerAlertRows, spr_GetAgendaCreationMailId, spr_AddEditAgenda Save branch), Database/README.md (section Step UD1b),
Database/BMMS-Test-DepartmentApprovers-Step53.sql (as described in Database/README.md, not read line by line).
