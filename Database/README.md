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

Steps 1 to 13 are applied to the local `BMMS` (steps 10, 11 and 13 on 2026-10-15). Steps 1 to 12 are applied to `BMMS_bak1` (step 13 too, if it was run there as its section says). Steps 10 to 15 are on `BMMS_Test`. Steps 14 and 15 are NOT on `BMMS`.
Re-running the fix scripts is safe; re-running the key scripts reports that the constraint already exists.
If you install from the command line, use sqlcmd -I (quoted identifiers ON); installing from SSMS already does this.
If step 2, 6 or 10 is ever re-run, run step 13 again afterwards: each contains an older spr_DeleteUserByUserId (and step 10 needs steps 2 and 6 to be followed by it as before).
If step 13 is ever re-run, run step 14 again afterwards: step 13 contains the older fn_UserChangeRefusal and spr_GetUserListForUserPage.
If step 6, 8 or 12 is ever re-run, run step 15 again afterwards: each contains an older version of a procedure that step 15 replaces.
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
- BMMS-Check-InstalledSteps.sql           (read-only: which of steps 1 to 15 are installed in the selected database; allowed on `BMMS`)
- BMMS-Test-Delete-Procedures.sql         (delete-procedure tests for the master tables; deletes real unreferenced rows, inside a transaction that is rolled back)
- BMMS-Test-FK-Procedures.sql             (tests for steps 6 to 9; rolled back)
- BMMS-Test-UserDelete.sql                (tests for steps 10 and 11, with step 13 installed: user delete rules, one test per protected column, one per key; rolled back)
- BMMS-Test-UserKey-Workflows.sql         (committee, meeting, agenda, approvals, finalize, confirm, alerts, login / backup / mail audit, through the real procedures; rolled back)
- BMMS-Test-ResetDatabase.sql             (runs spr_sys_ResetDatabase with all keys in place; TEST COPY ONLY; rolled back, and the identity counters are put back)
- BMMS-Test-Attendance-FutureMeeting.sql  (tests for step 12: past / today / future / no-date meetings, new attendance and edits; 23 checks; run on the test copy; rolled back)
- BMMS-Test-UserProtection-Stage1.sql     (tests for step 13: every action by Admin / Controller / other roles, own account, last active Admin / Controller, acting user missing, reasons 5, 6 and 9, re-raised errors, list flags, locks; 142 checks; test copy only; rolled back. With step 14 installed, the three checks where an inactive Admin acts expect Reason 8 instead of 2, and their label says so)
- BMMS-Test-MeetingLocks.sql             (tests for step 15: meeting member add / edit / delete in each state, delete with attendance, attendance and chairman on finalized minutes, each finalize / confirm step in order and twice, NULL statuses, status lookup; 43 checks; test copy only; rolled back)
- BMMS-Test-UserStatus-Stage2a.sql        (tests for step 14: the AccountStatus column, inactive acting user, deactivate / activate by role, list Status / CanDeactivate / CanActivate / ManagedCount, active user list, Manager list, status lookup, retired lock; 50 checks; test copy only; rolled back)

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
- Not yet changed (stage 2b): alerts, action items and mail recipients chosen inside the database procedures still include inactive users.

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
- Not in this step: Meeting edit (date, committee), agenda add / edit / delete, Minutes update, committee members.
