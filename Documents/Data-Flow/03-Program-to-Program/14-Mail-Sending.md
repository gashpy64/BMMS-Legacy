# Program to Program: Mail Sending

- Title: Program to Program: Mail Sending
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: IU1 (step 55: the section "Meeting, Committee and Reset Password mails"); UD1b (step 53: the recipients of the agenda mails); user-ud1a
- Commit: 79f50ea
- Last updated by: IU1, based on 79f50ea
- Status: Draft
- Verified against: for IU1: the step's diff (BMMS/Master/Meeting.aspx.cs, Committee.aspx.cs, ResetPassword.aspx.cs, BMMSBAL/AlertMgr.cs, UserMgr.cs), Database/BMMS-Fix-InactiveUsers-Step55.sql, Database/README.md (section Step IU1); for UD1b: BMMS/Master/Agenda.aspx.cs (GenerateMail, GenerateUpdateMail), BMMS/DashBoard/DashBoard.aspx.cs (the mail after Result 1), BMMS/Master/AgendaFinalization.aspx.cs (the call of AlertMgr.GetAlertMailId), Database/BMMS-Fix-DepartmentApprovers-Step53.sql (spr_GetAlertMailId, spr_GetAgendaUpdateMailId, spr_GetAgendaCreationMailId read in full), Database/README.md (section Step UD1b)
- To confirm: feature area written only for the recipients of the agenda mails since step UD1b (WF2c3); the mail server settings, the Mail_Mgr send, the mail log and the other mails are not written yet

## Scope

This file covers who gets which agenda mail since step UD1b (database step 53). The mail texts do not change, except that the
"has been Created" mail of a User's item sent to the Controller adds the line "Sent to the Controller: the department had no
active Manager." The Admin role is in no recipient list.

[[CONFIRM: the sending itself (Mail_Mgr, the SMTP settings, the log) and the other mails are not written yet (WF2c3)]]

## Programs involved

| Program | Kind | Part in the flow |
|---|---|---|
| Master/Agenda.aspx(.cs) | Page | The Created mail (`GenerateMail`) and the update mail (`GenerateUpdateMail`) |
| DashBoard/DashBoard.aspx(.cs) | Page | The mail of an approval or rejection by a Manager or the Controller, after Result 1 |
| Master/AgendaFinalization.aspx(.cs) | Page | The mail of a rejection at finalisation |
| AgendaMgr.GetAgendaCreationMailId, AgendaMgr.GetAgendaUpdateMailId, AlertMgr.GetAlertMailId | BAL | Read the recipients |
| spr_GetAgendaCreationMailId, spr_GetAgendaUpdateMailId, spr_GetAlertMailId | Procedures | The recipient lists |
| Mail_Mgr.SendWebEmail | BAL | Sends the mail |

## Main flow

```mermaid
flowchart TD
    pAgenda("Agenda Entry - Agenda.aspx")
    pDash("Dashboard - DashBoard.aspx")
    pFin("Agenda Finalization")
    sCreate{{"spr_GetAgendaCreationMailId"}}
    sUpdate{{"spr_GetAgendaUpdateMailId"}}
    sAlert{{"spr_GetAlertMailId"}}
    tMap[("Alert_User_Map")]
    tUsers[("Users")]
    fMail[/"Agenda mail"/]

    pAgenda -->|"user, department"| sCreate
    sCreate -->|"Managers of the department, or the Controllers"| pAgenda
    pAgenda -->|"agenda, acting user"| sUpdate
    tMap -->|"rows not marked as handled"| sUpdate
    sUpdate -->|"addresses"| pAgenda
    pDash -->|"AMA or AMR, item, acting user"| sAlert
    pFin -->|"ACR, item"| sAlert
    tMap -->|"rows not marked (ACA, ACR)"| sAlert
    tUsers -->|"Managers of the item's department (AMA, AMR)"| sAlert
    sAlert -->|"addresses"| pDash
    pAgenda -->|"Created or updated"| fMail
    pDash -->|"Approved or rejected"| fMail
```

| From | To | Data | Notes |
|---|---|---|---|
| Agenda.aspx | spr_GetAgendaCreationMailId | User id, department id | Route M: Bcc every active Manager of the department other than the creator; route C: the active Controllers; routes I and R: none (the item is refused) |
| Agenda.aspx | Agenda.aspx (GenerateMail) | The Bcc of a Manager's or the Controller's own item | The Reporting Person gets a Bcc, but not one of the Admin role |
| Alert_User_Map | spr_GetAgendaUpdateMailId | The rows of the item's alert except the acting user | Rows marked as handled are left out; Admin, system account, empty addresses and the types a role does not see are left out as before |
| DashBoard.aspx | spr_GetAlertMailId | Code AMA or AMR | AMA: the Controllers and the creator; AMR: the creator; both also every other active Manager of the item's department (the one who decided is left out) |
| AgendaFinalization.aspx, DashBoard.aspx | spr_GetAlertMailId | Code ACA or ACR | The users of the item's alert whose row is not marked as handled |
| the pages | Agenda mail | Subject, body, addresses | The body of the Created mail adds "Sent to the Controller: the department had no active Manager." when the item went to the Controller for that reason |

## Refusal paths

[[CONFIRM: not written yet (WF2c3)]]

## Where each rule lives

| Rule | C# | Procedure or function |
|---|---|---|
| Recipients of the Created mail | `GenerateMail` | spr_GetAgendaCreationMailId, fn_AgendaRoute, fn_DepartmentManagers |
| Recipients of the approval and rejection mails | `btnApprove_Click`, `btnReject_Click`, AgendaFinalization.aspx.cs `GenerateMail` | spr_GetAlertMailId |
| Recipients of the update mail | `GenerateUpdateMail` | spr_GetAgendaUpdateMailId |
| No mail for the Admin role; none for a handled Manager | none | the three procedures |

## Tables read and written

| Object | Reads | Writes |
|---|---|---|
| spr_GetAgendaCreationMailId | Users, Roles, Department, App_Setting, User_Department (through fn_AgendaRoute, fn_DepartmentManagers) | none |
| spr_GetAgendaUpdateMailId | Alert_Master, Alert_User_Map, Users, Roles | none |
| spr_GetAlertMailId | Users, Roles, Agenda, Alert_Master, Alert_User_Map, User_Department (through fn_DepartmentManagers) | none |

## Meeting, Committee and Reset Password mails (step IU1)

Since step IU1 (database step 55) the Meeting and Committee "Created" and "Updated" mails (MC, MU, CC, CU) go to the users who
get the alert row of the same event, by one rule (fn_FunctionalUsers: active, not the protected system account, not the Admin
role, not the person who saved). The To stays the person who saved. The Committee mail, switched off in Committee.aspx.cs since
the baseline, is sent again after a successful save. The Reset Password mail reads the address and the active status from the
database. The flows are drawn in 07-Meeting and 03-Masters; this section gives the mail side.

```mermaid
flowchart TD
    pMeeting("Meeting - Meeting.aspx")
    pCommittee("Committee - Committee.aspx")
    pReset("Reset Password - ResetPassword.aspx")
    sMailId{{"spr_GetMeetingCommitteeMailId"}}
    sResetMail{{"spr_GetResetPasswordMail"}}
    fFunc{{"fn_FunctionalUsers"}}
    tUsers[("Users")]
    fMail[/"Meeting, Committee or Reset Password mail"/]

    pMeeting -->|"acting user"| sMailId
    pCommittee -->|"acting user"| sMailId
    sMailId --> fFunc
    tUsers -->|"active, not system, not Admin role"| fFunc
    sMailId -->|"Bcc addresses, Reason"| pMeeting
    sMailId -->|"Bcc addresses, Reason"| pCommittee
    pReset -->|"acting user, chosen user"| sResetMail
    tUsers -->|"address, active status"| sResetMail
    sResetMail -->|"address, IsActive, Reason"| pReset
    pMeeting -->|"saved"| fMail
    pCommittee -->|"saved"| fMail
    pReset -->|"active user only"| fMail
```

| From | To | Data | Notes |
|---|---|---|---|
| Meeting.aspx, Committee.aspx | spr_GetMeetingCommitteeMailId | Acting user | Read after the save. Reason 8: acting user missing, 0 or inactive; Reason 4: a role other than Admin and Controller; then no rows |
| spr_GetMeetingCommitteeMailId | Meeting.aspx, Committee.aspx | The addresses of the users of fn_FunctionalUsers, except the person who saved | A user without an address keeps the alert and gets no mail |
| Meeting.aspx, Committee.aspx | Mail_Mgr | To: the person who saved; Bcc: the list | The ML2c address checks are unchanged. No address in the list: no mail at all, green "The meeting was saved. No mail was sent because there were no recipients." (Committee: "The committee was saved. ...") |
| Meeting.aspx, Committee.aspx | The person who saved | "The meeting was saved, but the mail could not be sent. The error is in the error log." (Committee: "The committee was saved, but ...") | A mail failure or a refusal of the Bcc procedure never undoes the save |
| ResetPassword.aspx | spr_GetResetPasswordMail | Acting user, chosen user | Called after the reset, under the acting-user check of the reset (fn_UserChangeRefusal 'ResetPassword'). The page holds no address: the hidden field hdnEmailId is removed (G3) |
| spr_GetResetPasswordMail | ResetPassword.aspx | The address, IsActive, Reason | Reason 4 for a user that does not exist; the refusals of the reset rule |
| ResetPassword.aspx | The Admin | Active user: the mail, "New passward was sent through mail."; inactive user: no mail, green "The password was reset to the default password. No mail was sent because the user is inactive." | If the procedure refuses after the reset: "The password was reset to the default password, but the mail could not be sent. The error is in the error log." |

Where the rules live: the recipient rule in fn_FunctionalUsers (also read by spr_AddEditMeeting, spr_AddEditCommittee and
spr_MinutesFinalizeByMeetingId for their rows); the To, the "no recipients" result and the messages in Meeting.aspx.cs and
Committee.aspx.cs (GenerateMail, MailToActingUser); the inactive-user branch in ResetPassword.aspx.cs
(btnResetPassword_Click). Tables read: Users, Roles. Nothing is written by the three mail procedures.

## Drawn from

Database/BMMS-Fix-InactiveUsers-Step55.sql (fn_FunctionalUsers, spr_GetMeetingCommitteeMailId, spr_GetResetPasswordMail),
BMMS/Master/Meeting.aspx.cs, Committee.aspx.cs and ResetPassword.aspx.cs (the messages), Database/README.md (section Step IU1).
Agenda mails: BMMS/Master/Agenda.aspx.cs (GenerateMail, GenerateUpdateMail), BMMS/DashBoard/DashBoard.aspx.cs, BMMS/Master/AgendaFinalization.aspx.cs,
Database/BMMS-Fix-DepartmentApprovers-Step53.sql (spr_GetAgendaCreationMailId, spr_GetAgendaUpdateMailId, spr_GetAlertMailId), System-Manual/07-Mail,
Database/README.md (section Step UD1b).
