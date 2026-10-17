# BMMS database scripts

## Always test on a copy first

Every change goes to a test copy before it goes to `BMMS`:

1. Restore the latest `BMMS` backup as a second database named `BMMS_bak1` (SSMS: Restore Database, change the database name and the two file names). Never restore over `BMMS` for a test.
2. Run the scripts and the tests on `BMMS_bak1`. Every test must show PASS (or SKIPPED) before going on.
3. Back up `BMMS`:
   `BACKUP DATABASE BMMS TO DISK = N'C:\Backups\BMMS_before_change.bak' WITH COPY_ONLY;`
4. Run the same scripts on `BMMS`, in the same order, then the tests that are allowed on `BMMS`.

Scripts 1 to 9 start with `USE [BMMS]`. To run one of them on the test copy, change that first line to `USE [BMMS_bak1]` in the SSMS window before running it, and do not save the change.

Scripts 10 onwards and every test script have **no `USE` line**. They run in the database selected in the SSMS toolbar, print its name, and stop without changing anything if the name does not start with `BMMS`.

## Run order

On a database that does not have the changes yet:

1. BMMS-Fix-Login-Procedures.sql          (login lookup split; needed by the new password hashing)
2. BMMS-Fix-Delete-Procedures.sql         (delete procedures with reference checks)
3. BMMS-Fix-ResetDatabase-Seeds.sql       (Reset Database seeds the 4 default users with hashed passwords and ManagerId NULL for "no manager"; installs the procedure only, does not reset)
4. BMMS-Add-PrimaryKeys.sql
5. BMMS-Add-ForeignKeys-Safe.sql          (FK_Agenda_Committee, FK_Attendance_Committee)
6. BMMS-Fix-FK-Procedures.sql             (7 procedures changed so the next 4 keys can be added; needs the MemberDB.cs NULL-state fix deployed)
7. BMMS-Add-ForeignKeys-Step3.sql         (FK_Action_Item_Minutes, FK_ActionItem_User_Map_Users, FK_Meeting_Chairman, FK_Member_State_Master)
8. BMMS-Fix-MinutesFinalize-Procedure.sql (minutes finalization no longer duplicates action items or maps users to other meetings' items)
9. BMMS-Add-ForeignKeys-Step4.sql         (FK_Users_ManagerId; run after the build that stores "no manager" as NULL is deployed, and after re-running step 3 if it was applied before this change - the script refuses otherwise)
10. BMMS-Fix-UserDelete-Procedure.sql     (a user with history cannot be deleted; replaces the version of spr_DeleteUserByUserId installed by steps 2 and 6, so always run it after them)
11. BMMS-Add-ForeignKeys-Step5.sql        (21 keys from the user-id columns to Users; refuses until step 10 is installed, and refuses any key whose column holds an unknown user)
12. BMMS-Fix-Attendance-FutureMeeting.sql (attendance only for a meeting dated today or earlier, by the database server date; run BEFORE deploying the build that reads its Result)
13. BMMS-Fix-UserProtection-Stage1.sql    (who may change which user account; replaces spr_DeleteUserByUserId of step 10, spr_AddEditUser and spr_ResetPasswordByUserId; run after step 10 and BEFORE deploying the build that reads Reason)
14. BMMS-Fix-UserStatus-Stage2a.sql       (inactive users: AccountStatus NOT NULL / DEFAULT 1 / CHECK 0 or 1, an inactive acting user is refused, active-only pick lists, spr_LockUserByUserId retired; replaces fn_UserChangeRefusal and spr_GetUserListForUserPage of step 13; SQL BEFORE deploying the build that calls spr_GetUserStatusByUserId)
15. BMMS-Fix-MeetingLocks.sql             (meeting-state locks: members, attendance and chairman refused once the minutes are finalized; agenda finalize only from Open, minutes finalize only from Open, confirm only from F, checked under a lock; replaces spr_UpdateMeetingChairman and spr_AgendaFinalizeByMeetingId of step 6, spr_MinutesFinalizeByMeetingId of step 8 and spr_UpdateAttendance of step 12; SQL BEFORE deploying the build, and the build straight after: see its section)
16. BMMS-Fix-MeetingLocks-Step16.sql      (meeting locks part 2: meeting date / committee locked by attendance, committee by agenda items; agenda add / edit / delete / approve locked once the agenda is finalized, with an Admin option for the Controller; minutes locked once confirmed; committee members counted for a meeting only from their appointment date; new table App_Setting; replaces spr_UpdateMinutes and spr_DeleteAgendaByAgendaId of step 6, spr_UpdateMeetingChairman of steps 6 and 15, spr_UpdateAttendance of steps 12 and 15; SQL BEFORE deploying the build, and the build straight after: see its section)
17. BMMS-Fix-UserStatus-Stage2b.sql        (inactive users get no new alerts, action items or alert mail; a user's new agenda item is refused while their manager is inactive (Reason 11); late action items of an inactive creator go to the active Controllers; replaces spr_UpdateMinutes of steps 6 and 16, spr_MinutesFinalizeByMeetingId of steps 8 and 15, spr_AddEditMeeting, spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController and spr_UpdateAgendaByAgendaId of step 16; SQL BEFORE deploying the build, and the build straight after: see its section)

Steps 1 to 16 are installed and verified on the local `BMMS` (steps 10, 11 and 13 on 2026-10-15). Steps 1 to 12 are applied to `BMMS_bak1` (step 13 too, if it was run there as its section says). Steps 10 to 17 are on `BMMS_Test`. Step 17 is NOT on `BMMS` yet: the live release is step 17 plus the new build.
Re-running the fix scripts is safe; re-running the key scripts reports that the constraint already exists.
If you install from the command line, use sqlcmd -I (quoted identifiers ON); installing from SSMS already does this.
If step 2, 6 or 10 is ever re-run, run step 13 again afterwards: each contains an older spr_DeleteUserByUserId (and step 10 needs steps 2 and 6 to be followed by it as before).
If step 13 is ever re-run, run step 14 again afterwards: step 13 contains the older fn_UserChangeRefusal and spr_GetUserListForUserPage.
If step 6, 8 or 12 is ever re-run, run step 15 again afterwards: each contains an older version of a procedure that step 15 replaces.
If step 6, 12 or 15 is ever re-run, run step 16 again afterwards. Checked by searching every numbered script for each procedure step 16 replaces: step 6 contains spr_UpdateMinutes, spr_DeleteAgendaByAgendaId and spr_UpdateMeetingChairman; step 12 contains spr_UpdateAttendance; step 15 contains spr_UpdateAttendance and spr_UpdateMeetingChairman. Steps 2, 8 and 10 contain none of them, and no other numbered script does either. So a re-run of step 6 or 12 needs step 15 and then step 16 again.
If step 6, 8, 15 or 16 is ever re-run, run step 17 again afterwards. Checked by searching every numbered script for each procedure step 17 replaces: step 6 contains spr_UpdateMinutes; step 8 contains spr_MinutesFinalizeByMeetingId; step 15 contains spr_MinutesFinalizeByMeetingId; step 16 contains spr_AddEditMeeting, spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController, spr_UpdateAgendaByAgendaId and spr_UpdateMinutes. spr_AddEditCommittee and spr_GetAlertMailId are in no numbered script. Steps 1 to 5, 7 and 9 to 14 contain none of them (13 and 14 checked as well). So a re-run of step 6 needs steps 15, 16 and 17 again; of step 8, steps 15 and 17; of step 12, steps 15, 16 and 17; of step 15, steps 16 and 17; of step 16, step 17.
To see which steps a database has, run BMMS-Check-InstalledSteps.sql (read only; one row per step: Installed, Partly, Missing or Not detectable, with the missing markers listed). "Partly" usually means one of the re-runs above happened; its Detail says which step to run again.

## Steps 10 and 11: what to run where

On `BMMS_bak1` (test copy):

1. BMMS-Fix-UserDelete-Procedure.sql
2. BMMS-Add-ForeignKeys-Step5.sql         (expect "Added now: 21   Refused: 0", or "already exists" on a re-run)
3. BMMS-Fix-UserProtection-Stage1.sql     (step 13; the tests below call its signature. Run it again whenever step 10 is re-run)
4. BMMS-Test-UserDelete.sql               (75 checks)
5. BMMS-Test-UserKey-Workflows.sql        (23 checks)
6. BMMS-Test-FK-Procedures.sql            (19 checks)
7. BMMS-Test-ResetDatabase.sql            (14 checks; test copy ONLY)
8. The manual checklist below, with the application pointed at the test copy (optional but recommended)

Then on `BMMS`, after the backup:

1. BMMS-Fix-UserDelete-Procedure.sql
2. BMMS-Add-ForeignKeys-Step5.sql
3. BMMS-Fix-UserProtection-Stage1.sql     (step 13; see its section below for when, relative to the build)
4. BMMS-Test-UserDelete.sql
5. BMMS-Test-UserKey-Workflows.sql
6. BMMS-Test-FK-Procedures.sql

The tests need step 13 on that database. Between step 10 and step 13 they cannot run: BMMS-Test-UserDelete.sql stops with a message naming step 13 (earlier it failed with error 8144, "too many arguments").

Do NOT run BMMS-Test-ResetDatabase.sql on `BMMS`. It refuses to, by name.

## Test and check scripts

- BMMS-Check-Orphans.sql                  (read-only check of candidate foreign keys, and of every user-id column)
- BMMS-Check-InstalledSteps.sql           (read-only: which of steps 1 to 17 are installed in the selected database; allowed on `BMMS`)
- BMMS-Test-Delete-Procedures.sql         (delete-procedure tests for the master tables; deletes real unreferenced rows, inside a transaction that is rolled back)
- BMMS-Test-FK-Procedures.sql             (tests for steps 6 to 9; rolled back)
- BMMS-Test-UserDelete.sql                (tests for steps 10 and 11, with step 13 installed: user delete rules, one test per protected column, one per key; rolled back)
- BMMS-Test-UserKey-Workflows.sql         (committee, meeting, agenda, approvals, finalize, confirm, alerts, login / backup / mail audit, through the real procedures; rolled back)
- BMMS-Test-ResetDatabase.sql             (runs spr_sys_ResetDatabase with all keys in place; TEST COPY ONLY; rolled back, and the identity counters are put back)
- BMMS-Test-Attendance-FutureMeeting.sql  (tests for step 12: past / today / future / no-date meetings, new attendance and edits; 23 checks; run on the test copy; rolled back)
- BMMS-Test-UserProtection-Stage1.sql     (tests for step 13: every action by Admin / Controller / other roles, own account, last active Admin / Controller, acting user missing, reasons 5, 6 and 9, re-raised errors, list flags, locks; 142 checks; test copy only; rolled back. With step 14 installed, the three checks where an inactive Admin acts expect Reason 8 instead of 2, and their label says so)
- BMMS-Test-MeetingLocks.sql             (tests for step 15: meeting member add / edit / delete in each state, delete with attendance, attendance and chairman on finalized minutes, each finalize / confirm step in order and twice, NULL statuses, status lookup; 43 checks; test copy only; rolled back)
- BMMS-Test-MeetingLocks-Step16.sql       (tests for step 16: meeting date / committee / venue edits with and without attendance or agenda items, agenda add / edit / delete / approve / subject no by every role with the Controller option on and off, minutes finalized, inactive or missing acting user, System Settings, minutes and short text at Open / F / C, committee members before / on / after the appointment date, ceased, bad cessation, saved attendance, attendance and chairman saves; 100 checks; test copy only; rolled back)
- BMMS-Test-UserStatus-Stage2a.sql        (tests for step 14: the AccountStatus column, inactive acting user, deactivate / activate by role, list Status / CanDeactivate / CanActivate / ManagedCount, active user list, Manager list, status lookup, retired lock; 50 checks; test copy only; rolled back)
- BMMS-Test-UserStatus-Stage2b.sql        (tests for step 17: markers kept, committee / meeting / agenda alerts by every route with active and inactive recipients, manager active / inactive (Reason 11) / none, Reason 8 before 11, approve / reject with an active and an inactive creator, saved rows kept, minutes finalize, late action items (Controller fallback), alert mail addresses, last active Controller / Admin, re-activation without back-fill; 63 checks; test copy only; rolled back)

Since step 17 BMMS-Test-UserKey-Workflows.sql switches its three test users on (they are inserted inactive) and counts "every other user" among active users only, and BMMS-Test-FK-Procedures.sql expects minutes finalize to map every active user plus the row it saved before; BMMS-Test-MeetingLocks-Step16.sql picks as agenda creator a User whose manager is active or not set. Each checks whether step 17 is installed, so they pass before and after it.

Since step 16 BMMS-Test-FK-Procedures.sql, BMMS-Test-UserDelete.sql and BMMS-Test-UserKey-Workflows.sql open the agenda (AgendaStatus 'Open') before they approve or delete an agenda item, pass the acting user when step 16 is installed, and make the chairman they set a committee member; BMMS-Test-MeetingLocks.sql and BMMS-Test-Attendance-FutureMeeting.sql make the member they mark present a committee member since 2000. All inside their rolled-back transaction, so they pass before and after step 16.

Since step 15 BMMS-Test-FK-Procedures.sql and BMMS-Test-UserDelete.sql put the meeting they use into the state each procedure needs (Open before a finalize, F before a confirm) inside their rolled-back transaction, so they pass before and after step 15.

Since step 13 the four older user tests (UserDelete, UserKey-Workflows, FK-Procedures, ResetDatabase) pass an acting Admin to the user procedures and read the extra Reason / ReasonDetail columns. Run them only after step 13.

The rolled-back tests keep no data, but identity values (UserId and so on) skip a few numbers each time they run.

## User delete rule (step 10)

A user cannot be deleted (the page shows the existing "in use" message) if their id is in any of these:

- other users: ManagerId, CreatedBy, UpdatedBy
- Agenda, Meeting, Minutes, Committee, Committee_Member, Meeting_Member, Member: CreatedBy, UpdatedBy (Agenda also MgrApprovedBy, ControllerApprovedBy)
- Attendance.UpdatedBy, Action_Item.UpdatedBy
- Alert_Master.CreatedBy (alerts the user raised)
- Audit_Trail_Master, Audit_Trail_SendMail, Audit_Trail_SqlBackup, Audit_Trial_Login (the user has logged in)
- Department, Designation, Roles, Alert_Type, Decision_Type, Member_Type, Subject_Type: CreatedBy, UpdatedBy

Removed together with the user, without blocking: alerts received (Alert_User_Map) and action-item read flags (ActionItem_User_Map).

Mail and login audit rows dated before the user was created do not block: they belong to an earlier user who had the same id.

## Step 12: attendance for a future meeting (what to run where)

On `BMMS_bak1`: BMMS-Fix-Attendance-FutureMeeting.sql, then BMMS-Test-Attendance-FutureMeeting.sql (23 checks, all PASS).
On `BMMS`, after the backup: BMMS-Fix-Attendance-FutureMeeting.sql only.

Rule: attendance (new or edited, chairman included) is saved only when `CAST(MeetingDate AS date) <= CAST(GETDATE() AS date)` on the database server. A meeting today is allowed at any time of day; a meeting with no date is refused. The page shows "Attendance cannot be marked for a meeting that has not yet taken place." Existing attendance rows are not changed.

Any database the application points at must have step 12 before the new build runs there, otherwise saving attendance stops with an error that names this script.

## Step 13: user account protection, stage 1 (what to run where)

On the test copies (`BMMS_bak1`, `BMMS_Test`): BMMS-Fix-UserProtection-Stage1.sql, then BMMS-Test-UserProtection-Stage1.sql (142 checks), then the four older user tests.
Applied to `BMMS` on 2026-10-15, after steps 10 and 11.

Rules (dbo.fn_UserChangeRefusal):

- Nobody can delete, deactivate or change the role of their own account. Editing your own details and password is allowed.
- The last ACTIVE Admin and the last ACTIVE Controller cannot be deleted, deactivated or given another role.
- Admin: any user. Controller: any user except Admin and Controller users, for every action (edit details, role, reset password, delete, deactivate); cannot create or promote to Admin / Controller. Other roles: only their own details and password.
- The acting user must be given: NULL, 0 or an unknown id is refused (Reason 8). From step 14 on, an inactive acting user is refused too (Reason 8); the pages show "Your session is no longer valid. Please log in again."

## Step 14: user status, stage 2a (what to run where)

On the test copy (`BMMS_Test`, or `BMMS_bak1`), in this order:

1. BMMS-Fix-UserStatus-Stage2a.sql        (stops, changing nothing, if step 13 is missing or any Users.AccountStatus is NULL or not 0 / 1)
2. BMMS-Test-UserStatus-Stage2a.sql       (50 checks)
3. BMMS-Test-UserProtection-Stage1.sql    (142 checks)
4. BMMS-Test-UserDelete.sql               (75 checks)
5. BMMS-Test-UserKey-Workflows.sql        (23 checks)
6. BMMS-Test-FK-Procedures.sql            (19 checks)
7. BMMS-Test-ResetDatabase.sql            (14 checks; test copy ONLY)

On `BMMS`, after the backup: BMMS-Fix-UserStatus-Stage2a.sql, then deploy the build. SQL before deploying the build: the new build reads spr_GetUserStatusByUserId on every page request and ManagerText from spr_GetMgrControllerByDeptId.

What it does:

- Users.AccountStatus is NOT NULL, defaults to 1 and only accepts 0 (inactive) or 1 (active).
- Login refuses any status other than 1, after the password check: "Your account is inactive. Contact the administrator."
- Every page request re-reads the status (BMMS/PageAccessModule.cs). An inactive user is logged out and sent to the login page with the same message. A database error lets the request through and is written to the error log.
- User Master shows a Status column (inactive rows greyed) and a Deactivate / Activate button per row, greyed when the rules do not allow it. Deactivating a Manager is allowed; the confirmation says how many active users have them as manager, and those users keep them.
- The Manager drop-down offers active Managers / Controllers only, plus the edited user's current manager marked "(inactive)".
- Committee and Meeting mail Bcc and the Agenda manager mail use active users only (spr_GetActiveUserList). Audit Trail and Reset Password still list every user (spr_GetUser, unchanged).
- spr_LockUserByUserId is retired (error 50002); use spr_SetUserStatusByUserId.
- Alerts, action items and mail recipients chosen inside the database procedures: see step 17 (stage 2b).

Every protected procedure returns one row `Result, Reason, ReasonDetail`. Result 1 = done, 0 = refused. Reason: 0 done, 1 own account, 2 last active Admin, 3 last active Controller, 4 not allowed for your role, 5 other users point at the user (names), 6 history (groups), 7 reserved (stage 3), 8 acting user missing, 9 a database reference the checks do not know. For Reason 9 the page shows a plain sentence and writes the SQL Server message to the application error log (`BMMS\Log\yyyy_MM_dd_ErrorLog.txt`). Any other database error is re-raised and reaches the error page; it is never reported as "in use".

Rule 2 is checked inside the same transaction as the change, with UPDLOCK, HOLDLOCK on the active Admin / Controller rows, so two simultaneous changes run one after the other and the second sees the first.

spr_SetUserStatusByUserId (deactivate / activate) exists and is tested, but no page calls it until stage 2.

## Manual checklist (application pointed at the test copy)

Do these after steps 10 and 11, logged in as the role shown. Each should work exactly as before.

1. Admin: add a user, then delete it straight away. Expected: deleted.
2. Admin: delete a user who has logged in or created anything. Expected: the "in use" message, user still listed.
3. Controller: add a committee, add a meeting, tag a committee member and a meeting member.
4. User: add an agenda for that meeting. Manager: the alert appears on the dashboard; approve it. Controller: approve it.
5. Controller: finalize the agenda, update the minutes (one item as Followup), finalize the minutes, confirm the minutes.
6. Controller: mark attendance for the meeting.
7. Any user: open the dashboard alerts and mark one as read; open an action item.
8. Any user: change password; log out and log in again.
9. Admin: Reset Password for another user.
10. Admin: Backup Database (a row appears in the backup audit report).
11. Controller: send a notice or agenda mail (needs SMTP; otherwise skip).
12. Admin: edit a department, designation, member type, subject type and decision type.

## Known defects (logged, not fixed)

- spr_AgendaFinalizeByMeetingId and spr_AddEditAgendaByController insert Minutes rows with CreatedBy = 1 and UpdatedBy = 1 hard-coded. User 1 does not exist in the live data. Because of this Minutes.CreatedBy and Minutes.UpdatedBy have no key.
- Audit_Trail_SendMail and Audit_Trial_Login hold ids of users deleted long ago, and the Users identity counter is now handing some of those ids to new users. Reports that show "sent by" or "logged in" by user id can show the wrong name for those old rows.
- Dashboard: an Admin sees Approve / Reject on a new agenda item (AC), but the Admin's Approve sets neither the Manager nor the Controller status; nothing changes.
- A user whose manager is a Controller (the Manager drop-down offers Managers and Controllers) cannot get a new agenda item approved: the AC alert goes to that Controller, whose Dashboard offers Approve only at AMA.
- A user with no manager (ManagerId NULL) who adds an agenda item: the AC alert goes to the Admins only, and nobody can give the Manager approval. Step 17 leaves this unchanged; Q6 in the step 17 section lists those users.

## Step 15: meeting-state locks (what to run where)

Before installing, check that no meeting has a NULL status (the procedures treat NULL as 'Open', but the result should be 0 / 0):

```sql
SELECT SUM(CASE WHEN AgendaStatus IS NULL THEN 1 ELSE 0 END) AS AgendaStatusNull,
       SUM(CASE WHEN MinutesStatus IS NULL THEN 1 ELSE 0 END) AS MinutesStatusNull
FROM Meeting;
```

On the test copy (`BMMS_Test`, or `BMMS_bak1`), in this order:

1. BMMS-Fix-MeetingLocks.sql              (stops, changing nothing, if step 12 is missing)
2. BMMS-Test-MeetingLocks.sql             (43 checks)
3. BMMS-Test-FK-Procedures.sql            (19 checks)
4. BMMS-Test-UserDelete.sql               (75 checks)
5. BMMS-Test-UserKey-Workflows.sql        (23 checks)
6. BMMS-Test-Attendance-FutureMeeting.sql (23 checks)
7. BMMS-Check-InstalledSteps.sql          (step 15 Installed)

On `BMMS`, after the backup, in a quiet period (nobody working on meetings): BMMS-Fix-MeetingLocks.sql, then deploy the new build straight away. SQL before deploying the build, and no gap between the two: the old build reads the new results of the meeting member, chairman and finalize procedures wrongly (for example it reports a refused save as "Record Not Saved" and a refused finalize as done), and the new build needs spr_GetMeetingStatusByMeetingId.

Rules:

- Meeting members (Meeting Member page): add and edit are refused once the minutes are finalized (MinutesStatus F or C). Delete is refused then too, and also when the member's attendance is recorded for the meeting. The page greys Add, Edit and Delete for a finalized meeting and shows the reason.
- Attendance and chairman (Attendance page): refused once the minutes are finalized; the page greys the chairman, the check boxes and Update. A meeting that has not yet taken place is still refused as in step 12.
- Agenda finalize only from AgendaStatus 'Open'; minutes finalize only from MinutesStatus 'Open'; minutes confirm only from 'F'. A second tab gets "This step has already been done for this meeting" and nothing is changed.
- NULL AgendaStatus / MinutesStatus count as 'Open'.
- No data is changed by the script. A member added to a finalized meeting before step 15 stays until it is removed by hand.
- Not in this step: Meeting edit (date, committee), agenda add / edit / delete, Minutes update, committee members. Those are step 16.

## Step 16: meeting locks part 2 (what to run where)

Before installing, run the read-only data checks below on `BMMS` and keep the counts. Step 16 changes no existing rows; the counts show what the new rules would have refused in the past.

On the test copy (`BMMS_Test`, or `BMMS_bak1`), in this order:

1. BMMS-Fix-MeetingLocks-Step16.sql       (stops, changing nothing, if step 14 or 15 is missing)
2. BMMS-Test-MeetingLocks-Step16.sql      (100 checks)
3. BMMS-Test-MeetingLocks.sql             (43 checks)
4. BMMS-Test-FK-Procedures.sql            (19 checks)
5. BMMS-Test-UserDelete.sql               (75 checks)
6. BMMS-Test-UserKey-Workflows.sql        (23 checks)
7. BMMS-Test-Attendance-FutureMeeting.sql (23 checks)
8. BMMS-Test-UserProtection-Stage1.sql    (142 checks)
9. BMMS-Test-UserStatus-Stage2a.sql       (50 checks)
10. BMMS-Test-ResetDatabase.sql           (14 checks; test copy ONLY)
11. BMMS-Check-InstalledSteps.sql         (step 16 Installed, 20 of 20 markers)

On `BMMS`, after the backup, in a quiet period: BMMS-Fix-MeetingLocks-Step16.sql (steps 14 and 15 must be there first), then deploy the new build straight away. SQL before deploying the build, and no gap between the two: the old build calls the agenda procedures without @ActingUserId, so saving or deleting an agenda item fails with an error page until the new build is in, and it reports a refused meeting or minutes change as saved. The new build calls spr_GetAgendaLockByMeetingId, spr_GetMeetingEditLockByMeetingId and spr_GetAppSetting, which exist only after the script.

Rules:

- Meeting edit (Meeting Master): once attendance is recorded for the meeting, its date and committee cannot change (Reason 6); venue, place, time and agenda submission date still can. Once agenda items exist, its committee cannot change (Reason 10): the agenda numbers start with the committee code and the meeting number belongs to the committee, so the items are not carried over. Dates are compared as dates. The page greys the date when attendance exists and checks before it sends the "Meeting updated" mail.
- Agenda add / edit / delete once the agenda is finalized (AgendaStatus not 'Open'): refused for every role (Reason 5), except an active Controller while the minutes are not finalized and the Admin option is on. Once the minutes are finalized (F or C) nobody can change agenda items, the Controller included (Reason 1). The Controller exception covers the Controller add / edit procedure, delete and subject number only; spr_AddEditAgenda and spr_AddEditAgendaByManager never allow it (they would not create the Minutes row).
- Approve / reject (Dashboard, agenda finalization) once the agenda is finalized: refused for every role (Reason 5), as the Dashboard already showed.
- The acting user is the logged-in user (Session["UserId"]), passed as @ActingUserId; the procedures read the role and status from Users / Roles. A missing or inactive acting user is refused (Reason 8).
- Minutes update and the agenda short text on the Minutes Update page: refused once the minutes are confirmed (MinutesStatus 'C', Reason 7). 'F' is still editable, as before.
- Committee members for a meeting (Attendance grid and chairman list, Send Mail recipients, Notice / Followup / Followup Action Taken reports, Notice print and minutes report): only members appointed on or before the meeting date (no appointment date counts as appointed) and not ceased before it. A cessation date that is not a date counts as not ceased. Members that already have attendance saved for the meeting stay listed. New attendance for a committee member outside those dates is refused, and so is a new chairman (Reason 9); saved attendance can still be edited and a saved chairman saved again. Nothing saved on past meetings is removed.
- Not changed: the invitee list on Meeting - Member Tag (committee members are never offered as invitees), the Committee Member page, the "members tagged" check when adding a meeting.

System Settings (Utilities menu, Admin only): one option, "Controller can add, edit and delete agenda items after the agenda is finalized", default on. Stored in App_Setting (AgendaControllerBypass = '1' or '0'); each change is written to Audit_Trail_Master. If the row is missing the procedures treat the option as on. Re-running the script keeps the stored value.

Reasons returned (Result, Reason, ReasonDetail): 0 done, 1 minutes finalized, 3 setting value not valid, 4 not found / not allowed for your role (setting), 5 agenda finalized (ReasonDetail Finalized or BypassOff), 6 attendance recorded (ReasonDetail MeetingDate, CommitteeId or both), 7 minutes confirmed, 8 acting user missing or inactive, 9 member not on the committee on the meeting date (ReasonDetail the name), 10 agenda items exist. spr_UpdateAttendance still returns Result only.

Read-only data checks for `BMMS` (they only read):

```sql
SET NOCOUNT ON;
-- Q1 attendance whose committee differs from the meeting's committee
SELECT 'Q1' AS Q, COUNT(*) AS Cnt FROM Attendance a JOIN Meeting m ON m.MeetingId = a.MeetingId WHERE ISNULL(a.CommitteeId,-1) <> ISNULL(m.CommitteeId,-1);
-- Q2 agenda whose committee differs from the meeting's committee
SELECT 'Q2' AS Q, COUNT(*) AS Cnt FROM Agenda g JOIN Meeting m ON m.MeetingId = g.MeetingId WHERE ISNULL(g.CommitteeId,-1) <> ISNULL(m.CommitteeId,-1);
-- Q3 meetings with attendance edited after the first attendance row
SELECT 'Q3' AS Q, COUNT(*) AS Cnt FROM Meeting m JOIN (SELECT MeetingId, MIN(UpdatedOn) AS FirstAtt FROM Attendance GROUP BY MeetingId) a ON a.MeetingId = m.MeetingId WHERE m.UpdatedOn > a.FirstAtt;
-- Q4 attendance recorded on a day before the meeting's (current) date
SELECT 'Q4' AS Q, COUNT(*) AS Cnt FROM Meeting m WHERE EXISTS (SELECT 1 FROM Attendance a WHERE a.MeetingId = m.MeetingId AND CAST(a.UpdatedOn AS date) < CAST(m.MeetingDate AS date));
-- Q5 committee members on attendance appointed after the meeting date
SELECT 'Q5' AS Q, COUNT(*) AS Cnt FROM Attendance a JOIN Meeting m ON m.MeetingId = a.MeetingId JOIN Committee_Member cm ON cm.CommitteeId = m.CommitteeId AND cm.MemberId = a.MemberId WHERE a.MemberOf = 'C' AND CAST(cm.AppointmentDate AS date) > CAST(m.MeetingDate AS date);
-- Q6 chairman appointed after the meeting date
SELECT 'Q6' AS Q, COUNT(*) AS Cnt FROM Meeting m JOIN Committee_Member cm ON cm.CommitteeId = m.CommitteeId AND cm.MemberId = m.ChairmanNameId WHERE CAST(cm.AppointmentDate AS date) > CAST(m.MeetingDate AS date);
-- Q7 committee members with no AppointmentDate / CessationDate not a date
SELECT 'Q7' AS Q, SUM(CASE WHEN AppointmentDate IS NULL THEN 1 ELSE 0 END) AS NoAppointment, SUM(CASE WHEN CessationDate <> '' AND ISDATE(CessationDate) = 0 THEN 1 ELSE 0 END) AS BadCessation, SUM(CASE WHEN CessationDate <> '' AND ISDATE(CessationDate) = 1 THEN CASE WHEN CONVERT(datetime, CASE WHEN ISDATE(CessationDate) = 1 THEN CessationDate END) < AppointmentDate THEN 1 ELSE 0 END ELSE 0 END) AS CessBeforeAppt FROM Committee_Member;
-- Q8 same member twice on one committee
SELECT 'Q8' AS Q, COUNT(*) AS Cnt FROM (SELECT CommitteeId, MemberId FROM Committee_Member GROUP BY CommitteeId, MemberId HAVING COUNT(*) > 1) d;
-- Q9 agenda rows created / changed after the agenda was finalized (finalize time = first Minutes row of the meeting)
SELECT 'Q9' AS Q, SUM(CASE WHEN g.CreatedOn > f.Fin THEN 1 ELSE 0 END) AS CreatedAfter, SUM(CASE WHEN g.UpdatedOn > f.Fin THEN 1 ELSE 0 END) AS UpdatedAfter FROM Agenda g JOIN (SELECT a.MeetingId, MIN(mi.CreatedOn) AS Fin FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId GROUP BY a.MeetingId) f ON f.MeetingId = g.MeetingId JOIN Meeting m ON m.MeetingId = g.MeetingId WHERE m.AgendaStatus = 'Close';
-- Q10 approved agenda in a finalized meeting with no Minutes row
SELECT 'Q10' AS Q, COUNT(*) AS Cnt FROM Agenda g JOIN Meeting m ON m.MeetingId = g.MeetingId WHERE m.AgendaStatus = 'Close' AND g.ControllerApprovedStatus = 'Approved' AND NOT EXISTS (SELECT 1 FROM Minutes mi WHERE mi.AgendaId = g.AgendaId);
-- Q11 agenda / minutes in a meeting whose minutes are finalized or confirmed, changed after the last minutes update
SELECT 'Q11' AS Q, COUNT(*) AS Cnt FROM Meeting m WHERE m.MinutesStatus IN ('F','C') AND EXISTS (SELECT 1 FROM Agenda g WHERE g.MeetingId = m.MeetingId AND g.UpdatedOn > (SELECT MAX(mi.UpdatedOn) FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.MeetingId = m.MeetingId));
-- Q12 status values
SELECT 'Q12' AS Q, ISNULL(AgendaStatus,'NULL') AS AgendaStatus, ISNULL(MinutesStatus,'NULL') AS MinutesStatus, COUNT(*) AS Meetings FROM Meeting GROUP BY AgendaStatus, MinutesStatus;
```

Q3, Q4, Q9 and Q11 are estimates: the database keeps no history of meeting dates or of when an agenda was finalized or minutes confirmed.

## Step 17: user status, stage 2b (what to run where)

Steps 14, 15 and 16 are already installed and verified on `BMMS`, so the live release is only BMMS-Fix-UserStatus-Stage2b.sql plus the new build.

Before installing, run the read-only exposure queries below on `BMMS` and keep the counts. Step 17 changes no existing rows; the counts show what inactive users hold today and where a workflow has no active recipient.

On the test copy (`BMMS_Test`, or `BMMS_bak1`), in this order:

1. BMMS-Fix-UserStatus-Stage2b.sql        (stops, changing nothing, if step 14, 15 or 16 is missing)
2. BMMS-Test-UserStatus-Stage2b.sql       (63 checks)
3. BMMS-Test-UserStatus-Stage2a.sql       (50 checks)
4. BMMS-Test-UserProtection-Stage1.sql    (142 checks)
5. BMMS-Test-UserDelete.sql               (75 checks)
6. BMMS-Test-UserKey-Workflows.sql        (23 checks)
7. BMMS-Test-FK-Procedures.sql            (19 checks)
8. BMMS-Test-MeetingLocks.sql             (43 checks)
9. BMMS-Test-MeetingLocks-Step16.sql      (100 checks)
10. BMMS-Test-Attendance-FutureMeeting.sql (23 checks)
11. BMMS-Test-ResetDatabase.sql           (14 checks; test copy ONLY)
12. BMMS-Check-InstalledSteps.sql         (step 17 Installed, 9 of 9 markers)

On `BMMS`, after the backup, in a quiet period: BMMS-Fix-UserStatus-Stage2b.sql, then deploy the new build straight away. SQL before deploying the build, and no gap between the two. During a gap the old build, for a User whose manager is inactive, sends the "Agenda created" mail first and then shows "Record Not Saved" (the procedure refuses with Reason 11, which the old build does not know). Everything else works with the old build; the procedure signatures do not change.

Rules:

- New alert rows (committee CC / CU, meeting MC / MU, agenda AC / AMA / ACA, approve / reject AMA / AMR / ACA / ACR) go to active users only (AccountStatus 1).
- Minutes finalize maps the new action items to active users only. An action item added on the Minutes Update page goes to the agenda creator if active; if the creator is inactive, to the active Controllers instead. A creator who no longer exists gets no row, as before (FK #5).
- The Bcc of the agenda approve / reject mails (spr_GetAlertMailId) holds active users only. The page now sends to every address it returns (before, it repeated the first address: BMMSDAL/AlertDB.cs).
- A User (any role other than Manager and Controller) whose ManagerId points at an inactive user cannot add an agenda item: Reason 11, ReasonDetail the manager's name. The Agenda page checks before the "Agenda created" mail and shows "Your manager (name) is inactive, so this agenda item cannot be sent for approval. Ask the administrator to assign you an active manager." A user with no manager is unchanged. Editing an existing item is not affected. Reasons 8, 5 and 1 of step 16 come first.
- Reset Password for an inactive user resets the password but sends no mail: "Password reset; no mail sent because the account is inactive."
- The User Master deactivate confirmation for a manager now also says that new agenda items from their users (other than Managers and Controllers) will be refused until they get an active manager.
- Nothing saved is changed: alert and action-item rows of inactive users stay (the dashboard of an inactive user is never shown, since they cannot log in). The Controller approve / reject renews the creator's row only while the creator is active. A user activated again gets new alerts from then on; nothing missed while inactive is added.
- The last active Admin and the last active Controller cannot be deactivated (steps 13 and 14), so the Admin and Controller recipients never run out. A direct SQL change to Users.AccountStatus can get round that; Q8 below shows it.
- Not changed: Committee / Meeting / Agenda page mail (active users since step 14), Notice / Followup / Followup Action Taken mail (they go to committee members, not users), Send Mail (addresses typed by hand), the SMTP Bcc setting, dashboards and reports (action items belong to a department; the user rows only decide who sees them).

Reasons returned by the agenda procedures: as step 16, plus 11 the creator's manager is inactive (spr_AddEditAgenda, Save only).

Read-only exposure queries for `BMMS` (they only read; anything other than AccountStatus 1 counts as inactive):

```sql
SET NOCOUNT ON;
-- Q1 alert rows held by inactive users, by alert type
SELECT 'Q1' Q, am.AlertTypeCode, COUNT(*) MapRows, SUM(CASE WHEN ISNULL(aum.ReadStatus,0)=0 THEN 1 ELSE 0 END) Unread, COUNT(DISTINCT aum.UserId) Users
FROM Alert_User_Map aum JOIN Users u ON u.UserId=aum.UserId JOIN Alert_Master am ON am.AlertId=aum.AlertId
WHERE ISNULL(u.AccountStatus,-1)<>1 AND aum.StatusId=1 GROUP BY am.AlertTypeCode;
-- Q2 open action items mapped to inactive users
SELECT 'Q2' Q, u.UserId, u.LoginName, COUNT(*) OpenItems
FROM ActionItem_User_Map m JOIN Users u ON u.UserId=m.UserId JOIN Action_Item ai ON ai.ActionItemId=m.ActionItemId
WHERE ISNULL(u.AccountStatus,-1)<>1 AND ISNULL(ai.IsConfirmed,0)=0 GROUP BY u.UserId, u.LoginName;
-- Q3 open action items no active user can see
SELECT 'Q3' Q, ai.ActionItemId, g.AgendaNo, g.DepartmentId
FROM Action_Item ai JOIN Minutes mi ON mi.MinutesId=ai.MinutesId JOIN Agenda g ON g.AgendaId=mi.AgendaId
WHERE ISNULL(ai.IsConfirmed,0)=0 AND NOT EXISTS (SELECT 1 FROM ActionItem_User_Map m JOIN Users u ON u.UserId=m.UserId
      WHERE m.ActionItemId=ai.ActionItemId AND u.AccountStatus=1);
-- Q4 agenda waiting for the manager (AC, agenda open), no active manager on its alert
SELECT 'Q4' Q, g.AgendaId, g.AgendaNo, c.LoginName Creator, mg.LoginName Manager, mg.AccountStatus MgrStatus
FROM Agenda g JOIN Meeting mt ON mt.MeetingId=g.MeetingId JOIN Users c ON c.UserId=g.CreatedBy LEFT JOIN Users mg ON mg.UserId=c.ManagerId
WHERE g.AgendaStatusCode='AC' AND ISNULL(mt.AgendaStatus,'Open')='Open'
AND NOT EXISTS (SELECT 1 FROM Alert_Master am JOIN Alert_User_Map aum ON aum.AlertId=am.AlertId JOIN Users u ON u.UserId=aum.UserId
      JOIN Roles r ON r.RoleId=u.RoleId WHERE am.SourceType='Agenda' AND am.SourceTypeId=g.AgendaId AND u.AccountStatus=1 AND r.RoleCode='manager');
-- Q5 agenda waiting for the controller (AMA, agenda open), no active controller on its alert
SELECT 'Q5' Q, g.AgendaId, g.AgendaNo
FROM Agenda g JOIN Meeting mt ON mt.MeetingId=g.MeetingId
WHERE g.AgendaStatusCode='AMA' AND ISNULL(mt.AgendaStatus,'Open')='Open'
AND NOT EXISTS (SELECT 1 FROM Alert_Master am JOIN Alert_User_Map aum ON aum.AlertId=am.AlertId JOIN Users u ON u.UserId=aum.UserId
      JOIN Roles r ON r.RoleId=u.RoleId WHERE am.SourceType='Agenda' AND am.SourceTypeId=g.AgendaId AND u.AccountStatus=1 AND r.RoleCode='controller');
-- Q6 active users adding agenda items through spr_AddEditAgenda whose manager is missing, inactive or not a Manager
SELECT 'Q6' Q, u.UserId, u.LoginName, r.RoleCode, mg.LoginName Manager, mg.AccountStatus MgrStatus, mr.RoleCode MgrRole,
  CASE WHEN u.ManagerId IS NULL THEN 'NoManager' WHEN ISNULL(mg.AccountStatus,-1)<>1 THEN 'ManagerInactive' ELSE 'ManagerNotManagerRole' END Issue
FROM Users u JOIN Roles r ON r.RoleId=u.RoleId LEFT JOIN Users mg ON mg.UserId=u.ManagerId LEFT JOIN Roles mr ON mr.RoleId=mg.RoleId
WHERE u.AccountStatus=1 AND r.RoleCode NOT IN ('controller','manager')
AND (u.ManagerId IS NULL OR ISNULL(mg.AccountStatus,-1)<>1 OR mr.RoleCode<>'manager');
-- Q7 departments with active users but no active Manager
SELECT 'Q7' Q, d.DepartmentId, d.DepartmentName,
  SUM(CASE WHEN u.AccountStatus=1 THEN 1 ELSE 0 END) ActiveUsers,
  SUM(CASE WHEN u.AccountStatus=1 AND r.RoleCode='manager' THEN 1 ELSE 0 END) ActiveMgrs,
  SUM(CASE WHEN ISNULL(u.AccountStatus,-1)<>1 AND r.RoleCode='manager' THEN 1 ELSE 0 END) InactiveMgrs
FROM Department d LEFT JOIN Users u ON u.DepartmentId=d.DepartmentId LEFT JOIN Roles r ON r.RoleId=u.RoleId
GROUP BY d.DepartmentId, d.DepartmentName
HAVING SUM(CASE WHEN u.AccountStatus=1 AND r.RoleCode='manager' THEN 1 ELSE 0 END)=0 AND SUM(CASE WHEN u.AccountStatus=1 THEN 1 ELSE 0 END)>0;
-- Q8 active / inactive count per role (Admin and Controller must be >= 1 active)
SELECT 'Q8' Q, r.RoleCode, SUM(CASE WHEN u.AccountStatus=1 THEN 1 ELSE 0 END) Active, SUM(CASE WHEN ISNULL(u.AccountStatus,-1)<>1 THEN 1 ELSE 0 END) Inactive
FROM Roles r LEFT JOIN Users u ON u.RoleId=r.RoleId GROUP BY r.RoleCode;
```

Q6 rows with Issue 'ManagerInactive' are the users whose new agenda items step 17 refuses: give them an active manager before or straight after the release. Committees and departments have no manager or controller column; the Controller role is global (Q8).
