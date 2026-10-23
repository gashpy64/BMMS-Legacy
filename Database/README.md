# BMMS database scripts

BMMS (Board Minutes and Meeting Software) is a board-meeting product for any company. Owner: Gashpy Software. Consultant: Ganesh Shankar C S.

## Always test on a copy first

Every change goes to a test copy before it goes to `BMMS`:

1. Restore the latest `BMMS` backup as a second database named `BMMS_bak1` (SSMS: Restore Database, change the database name and the two file names). Never restore over `BMMS` for a test.
2. Run the scripts and the tests on `BMMS_bak1`. Every test must show PASS (or SKIPPED) before going on.
3. Back up `BMMS`:
   `BACKUP DATABASE BMMS TO DISK = N'C:\Backups\BMMS_before_change.bak' WITH COPY_ONLY;`
4. Run the same scripts on `BMMS`, in the same order, then the tests that are allowed on `BMMS`.

Scripts 1, 2 and 4 to 9 start with `USE [BMMS]` (step 3 lost its `USE` line in step 29). To run one of them on the test copy, change that first line to `USE [BMMS_bak1]` in the SSMS window before running it, and do not save the change.

Script 3, scripts 10 onwards and every test script have **no `USE` line**. They run in the database selected in the SSMS toolbar, print its name, and stop without changing anything if the name does not start with `BMMS`.

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
9. BMMS-Add-ForeignKeys-Step4.sql         (FK_Users_ManagerId; run after the build that stores "no manager" as NULL is deployed, and after re-running step 3 if it was applied before this change - the script refuses otherwise. On a freshly restored baseline it refuses because the old seeds stored "no manager" as 0: in that database run `UPDATE dbo.Users SET ManagerId = NULL WHERE ManagerId = 0;`, then run step 9 again)
10. BMMS-Fix-UserDelete-Procedure.sql     (a user with history cannot be deleted; replaces the version of spr_DeleteUserByUserId installed by steps 2 and 6, so always run it after them)
11. BMMS-Add-ForeignKeys-Step5.sql        (21 keys from the user-id columns to Users; refuses until step 10 is installed, and refuses any key whose column holds an unknown user)
12. BMMS-Fix-Attendance-FutureMeeting.sql (attendance only for a meeting dated today or earlier, by the database server date; run BEFORE deploying the build that reads its Result)
13. BMMS-Fix-UserProtection-Stage1.sql    (who may change which user account; replaces spr_DeleteUserByUserId of step 10, spr_AddEditUser and spr_ResetPasswordByUserId; run after step 10 and BEFORE deploying the build that reads Reason)
14. BMMS-Fix-UserStatus-Stage2a.sql       (inactive users: AccountStatus NOT NULL / DEFAULT 1 / CHECK 0 or 1, an inactive acting user is refused, active-only pick lists, spr_LockUserByUserId retired; replaces fn_UserChangeRefusal and spr_GetUserListForUserPage of step 13; SQL BEFORE deploying the build that calls spr_GetUserStatusByUserId)
15. BMMS-Fix-MeetingLocks.sql             (meeting-state locks: members, attendance and chairman refused once the minutes are finalized; agenda finalize only from Open, minutes finalize only from Open, confirm only from F, checked under a lock; replaces spr_UpdateMeetingChairman and spr_AgendaFinalizeByMeetingId of step 6, spr_MinutesFinalizeByMeetingId of step 8 and spr_UpdateAttendance of step 12; SQL BEFORE deploying the build, and the build straight after: see its section)
16. BMMS-Fix-MeetingLocks-Step16.sql      (meeting locks part 2: meeting date / committee locked by attendance, committee by agenda items; agenda add / edit / delete / approve locked once the agenda is finalized, with an Admin option for the Controller; minutes locked once confirmed; committee members counted for a meeting only from their appointment date; new table App_Setting; replaces spr_UpdateMinutes and spr_DeleteAgendaByAgendaId of step 6, spr_UpdateMeetingChairman of steps 6 and 15, spr_UpdateAttendance of steps 12 and 15; SQL BEFORE deploying the build, and the build straight after: see its section)
17. BMMS-Fix-UserStatus-Stage2b.sql        (inactive users get no new alerts, action items or alert mail; a user's new agenda item is refused while their manager is inactive (Reason 11); late action items of an inactive creator go to the active Controllers; replaces spr_UpdateMinutes of steps 6 and 16, spr_MinutesFinalizeByMeetingId of steps 8 and 15, spr_AddEditMeeting, spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController and spr_UpdateAgendaByAgendaId of step 16; SQL BEFORE deploying the build, and the build straight after: see its section)
18. BMMS-Fix-SystemAccount-Stage3.sql      (the protected System Administrator account: Users.IsSystem; the "admin" account is visible but cannot be edited, deleted, deactivated or given another role (Reason 7), only it may change its password, it gets no workflow alerts and cannot approve or reject (Reason 12); Reason 2 counts ordinary Admins only; replaces spr_sys_ResetDatabase of step 3, fn_UserChangeRefusal and spr_GetUserListForUserPage of steps 13 and 14, spr_GetActiveUserList of step 14 and the nine procedures of step 17; SQL BEFORE deploying the build, and the build straight after: see its section)
19. BMMS-Fix-OrganisationSettings-Step19.sql (organisation name, office address and contact details as settings on System Settings, printed on notices, minutes, reports and certificates; the logo upload audit; replaces nothing; SQL BEFORE deploying the build: see its section)
20. BMMS-Fix-AgendaRouting-Step20.sql     (agenda routing: a user's item waits for the manager only when the manager is an active Manager, otherwise it goes straight to the Controllers (AMA, manager fields empty), refused while the manager is inactive (Reason 11) or when no Controller is active (Reason 15); approve / reject only by the routed Manager at AC and a Controller at AMA (reject also at AC), anyone else refused (Reason 14); one-time re-route of items stuck at AC; the signer is the first In Attendance member tagged; needs steps 18, 19 and 21; replaces spr_AddEditAgenda and spr_UpdateAgendaByAgendaId of steps 16, 17 and 18; SQL BEFORE deploying the build, and the build straight after: see its section)
21. BMMS-Fix-MemberTypes-Step21.sql        (Member Type Master for Admin and Controller: each type is a committee or a meeting type with a display order; types 2, 3 and 6 are reserved and cannot be edited, deactivated or deleted (Reason 7); a type in use cannot change scope or be deleted (Reason 5); committee and meeting members accept only an active type of their own scope (Reason 13); needs steps 18 and 19, not step 20; replaces spr_DeleteMemberTypeByMemberTypeId of step 2, spr_sys_ResetDatabase of steps 3 and 18 and spr_AddEditMeetingMember of step 15; SQL BEFORE deploying the build, and the build straight after: see its section)
22. BMMS-Fix-MinutesGating-Step22.sql      (minutes reports only after Minutes Finalisation: Reports, Minutes and Reports, Minutes Extract list, view and generate only meetings whose minutes are finalized or confirmed (MinutesStatus F or C), through two new read-only procedures instead of a query in the code; needs step 15, not steps 16 to 21; replaces nothing; SQL BEFORE deploying the build: see its section)

Step 21 is installed before step 20 (step 20 needs it). The list stays in number order; the install order is 19, 21, 20, 22.

Step 23 is installed after step 28 (it was numbered before steps 24 to 28 were built). The list stays in number order:

23. BMMS-Fix-WorkflowOrder-Step23.sql      (workflow order: attendance and chairman only after Agenda Finalisation (Reason 17); Update Minutes only after attendance is entered, chairman and at least one member present (18); Finalise Minutes only when every minute was updated (19, '0/0' when the meeting has no minutes); only for meetings created after the step is installed (setting WorkflowOrderFrom), older meetings unchanged; replaces spr_UpdateAttendance, spr_UpdateMeetingChairman and spr_UpdateAgendaShortText of step 16 and spr_UpdateMinutes and spr_MinutesFinalizeByMeetingId of step 18; needs steps 12 and 15 to 18; SQL BEFORE deploying the build: see its section)

24. BMMS-Fix-MeetingDates-Step24.sql        (meeting dates: on create the meeting date and the agenda submission date not before today and the submission date on or before the meeting date (equal allowed), both required; on edit "not before today" only for a date that is changed; refused with Reason 16; today is the database server date; needs steps 16, 17 and 18; replaces spr_AddEditMeeting of steps 16, 17 and 18; SQL BEFORE deploying the build: see its section)

Steps 25, 26 and 28 have no database script (code only); step 27 is not built yet (see Known items for later steps). Steps 29 and 30 are installed last, after step 23, in that order:

29. BMMS-Fix-ResetDatabase-Step29.sql       (Reset Database made safe: only an active Admin who types the name of the current database (Reasons 8, 4, 3), checked before anything is cleared; one transaction with XACT_ABORT ON, so an error or a timeout changes nothing, and the procedure puts the identity counters back after a rollback; the five TRUNCATEs become DELETE with the same next ids; Audit_Trail_SendMail is cleared too; one Audit_Trail_Master row "Reset by <login>" survives the reset; the four seeded users get the hashes of the new default password (Common.DefaultPassword); otherwise the re-created data is unchanged; needs steps 18 and 21; replaces spr_sys_ResetDatabase of step 21 (earlier 3 and 18) and keeps their texts; SQL BEFORE deploying the build: see its section)
30. BMMS-Fix-SmtpDefault-Step30.sql         (safe SMTP default: Reset Database replaces the mail settings (SMTP_Master) by one row that cannot send real mail: localhost, port 25, no login, From noreply@example.invalid, no Bcc; new spr_sys_SetSmtpDefault writes the same row on a new database (run by hand, never on BMMS); spr_UpdateSMTPMaster inserts the row when the table is empty; installing changes no data; needs steps 18 and 21; replaces spr_sys_ResetDatabase of step 29 (earlier 3, 18 and 21) and keeps their texts, and the legacy spr_UpdateSMTPMaster; SQL before deploying the build: see its section)

On a new database (restored from the baseline, not `BMMS`), after step 30: `EXEC dbo.spr_sys_SetSmtpDefault @ConfirmDatabaseName = N'<the database name>';` (Result 1). The restored row would otherwise keep mailing through whatever server it names. Never on `BMMS`: it keeps its real settings.

Steps 1 to 18 are installed and verified on the local `BMMS` (steps 10, 11 and 13 on 2026-10-15). Steps 1 to 12 are applied to `BMMS_bak1` (step 13 too, if it was run there as its section says). Steps 1 to 22 are installed on `BMMS_Test` and `BMMS` (tags organisation-settings-19, member-types-21, agenda-routing-20, minutes-gating-22). Step 24 is tagged meeting-dates-24; steps 25, 26 and 28 are code only (step 28 also fixed the error log). Step 23 is written and not yet installed anywhere: install it after step 28, on `BMMS_Test` first (see its section). Step 29 is installed on `BMMS_Test`, `BMMS_Quality` and `BMMS` (Consultant, 2026-10-22). Step 30 is written and not yet installed anywhere: install it after step 29 (see its section). BMMS-Check-InstalledSteps.sql shows the real state of any database.
Re-running the fix scripts is safe; re-running the key scripts reports that the constraint already exists.
If you install from the command line, use sqlcmd -I (quoted identifiers ON); installing from SSMS already does this.
If step 2, 6 or 10 is ever re-run, run step 13 again afterwards: each contains an older spr_DeleteUserByUserId (and step 10 needs steps 2 and 6 to be followed by it as before).
If step 13 is ever re-run, run step 14 again afterwards: step 13 contains the older fn_UserChangeRefusal and spr_GetUserListForUserPage.
If step 6, 8 or 12 is ever re-run, run step 15 again afterwards: each contains an older version of a procedure that step 15 replaces.
If step 6, 12 or 15 is ever re-run, run step 16 again afterwards. Checked by searching every numbered script for each procedure step 16 replaces: step 6 contains spr_UpdateMinutes, spr_DeleteAgendaByAgendaId and spr_UpdateMeetingChairman; step 12 contains spr_UpdateAttendance; step 15 contains spr_UpdateAttendance and spr_UpdateMeetingChairman. Steps 2, 8 and 10 contain none of them, and no other numbered script does either. So a re-run of step 6 or 12 needs step 15 and then step 16 again.
If step 6, 8, 15 or 16 is ever re-run, run step 17 again afterwards. Checked by searching every numbered script for each procedure step 17 replaces: step 6 contains spr_UpdateMinutes; step 8 contains spr_MinutesFinalizeByMeetingId; step 15 contains spr_MinutesFinalizeByMeetingId; step 16 contains spr_AddEditMeeting, spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController, spr_UpdateAgendaByAgendaId and spr_UpdateMinutes. spr_AddEditCommittee and spr_GetAlertMailId are in no numbered script. Steps 1 to 5, 7 and 9 to 14 contain none of them (13 and 14 checked as well). So a re-run of step 6 needs steps 15, 16 and 17 again; of step 8, steps 15 and 17; of step 12, steps 15, 16 and 17; of step 15, steps 16 and 17; of step 16, step 17.
If step 3, 6, 8, 13, 14, 15, 16 or 17 is ever re-run, run step 18 again afterwards. Checked by searching every numbered script for each object step 18 replaces: step 3 contains spr_sys_ResetDatabase; step 6 contains spr_UpdateMinutes; step 8 contains spr_MinutesFinalizeByMeetingId; step 13 contains fn_UserChangeRefusal and spr_GetUserListForUserPage; step 14 contains fn_UserChangeRefusal, spr_GetUserListForUserPage and spr_GetActiveUserList; step 15 contains spr_MinutesFinalizeByMeetingId; step 16 contains spr_AddEditMeeting, spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController, spr_UpdateAgendaByAgendaId and spr_UpdateMinutes; step 17 contains all nine of its procedures. spr_GetUser and View_Users are in no numbered script. Steps 1, 2, 4, 5, 7 and 9 to 12 contain none of them. So a re-run of step 6 needs steps 15, 16, 17 and 18 again; of step 8, steps 15, 17 and 18; of step 12, steps 15, 16, 17 and 18; of step 13, steps 14 and 18; of step 14, 15 or 16, the later steps up to 18; of step 17, step 18; of step 3, step 18.
Step 19 replaces no object of an earlier step, and no numbered script contains spr_GetOrganisationSettings, spr_SetOrganisationSettings or spr_RecordOrganisationLogo, so no re-run of an earlier step needs step 19 again. Re-running step 16 keeps App_Setting and its rows. Re-running step 19 keeps the values already set.
If step 2, 3, 15 or 18 is ever re-run, run step 21 again afterwards. Checked by searching every numbered script for each object step 21 replaces: step 2 contains spr_DeleteMemberTypeByMemberTypeId; steps 3 and 18 contain spr_sys_ResetDatabase; step 15 contains spr_AddEditMeetingMember. spr_GetMemberType, spr_GetMemberTypeByMemberTypeId, spr_AddEditMemberType and spr_AddEditCommitteeMember are in no numbered script, and spr_GetMemberTypeForTagging is new. Steps 1, 4 to 14, 16, 17 and 19 contain none of them. So a re-run of step 2 needs steps 13, 14, 18 and 21 again; of step 3, steps 18 and 21; of step 6, 8 or 12, the later steps up to 18 as above and then 21; of step 15, steps 16, 17, 18 and 21; of step 18, step 21. Re-running step 21 keeps the scope, order and status the Admin has set (it repairs only the reserved rows and the scope of a type in use).
Step 20 replaces none of the objects of step 21 (spr_sys_ResetDatabase and spr_AddEditMeetingMember are untouched), so step 21 still reads Installed after step 20. A later step that replaces either of them must keep the MemberTypes-Step21 text and the older markers.
If step 16, 17 or 18 is ever re-run, run step 20 again afterwards. Checked by searching every numbered script for each object step 20 replaces: steps 16, 17 and 18 each contain spr_AddEditAgenda and spr_UpdateAgendaByAgendaId. spr_GetCompanySecretary and spr_GetMeetingMemberByMeetingIdMemberTypeId are in no numbered script, and fn_AgendaRoute, spr_GetAgendaCreationMailId and spr_RerouteWaitingAgendas are new. Steps 1 to 15, 19 and 21 contain none of them. So, with the chains above: a re-run of step 6, 8, 12, 13, 14 or 15 needs the later steps up to 18 and then 20 (and 21 where listed); of step 16 or 17, the later steps up to 18 and then 20; of step 18, steps 20 and 21; of step 3, steps 18, 20 and 21; of step 2, steps 13, 14, 18, 20 and 21. Re-running step 20 is safe: the re-route moves nothing a second time.
Step 22 replaces no object of an earlier step, and no numbered script contains spr_GetMinutesReportMeetings or spr_GetMinutesReport, so no re-run of an earlier step needs step 22 again. Re-running step 22 is safe (it only replaces its two read-only procedures).
If step 16, 17 or 18 is ever re-run, run step 24 again afterwards. Checked by searching every numbered script for spr_AddEditMeeting, the only object step 24 replaces: steps 16, 17 and 18 each contain it; no other numbered script does. So, with the chains above, a re-run of step 6, 8, 12, 13, 14 or 15 needs the later steps up to 18 and then 24 as well (with 20 and 21 where listed). Re-running step 24 is safe (it changes no data).
If step 6, 8, 12, 15, 16, 17 or 18 is ever re-run, run step 23 again afterwards (after the chains above, as the last step). Checked by searching every numbered script for each procedure step 23 replaces: spr_UpdateAttendance is in steps 12, 15 and 16; spr_UpdateMeetingChairman in steps 6, 15 and 16; spr_UpdateAgendaShortText in step 16; spr_UpdateMinutes in steps 6, 16, 17 and 18; spr_MinutesFinalizeByMeetingId in steps 8, 15, 17 and 18. fn_WorkflowState and spr_GetMeetingWorkflowState are new. If one of those steps was re-run, step 23 stops and names the step whose text is missing until the chain has been run again. Re-running step 23 is safe: it keeps the WorkflowOrderFrom value of its first run.
If step 3, 18 or 21 is ever re-run, run step 29 again afterwards, as the last step (after the chains above, after step 23). Checked by searching every numbered script for spr_sys_ResetDatabase, the only object step 29 replaces: steps 3, 18 and 21 contain it; step 14 names it only in a comment; no other numbered script contains it. So any chain above that ends in step 18 or 21 ends in step 29. Step 29 keeps the texts of steps 3, 18 and 21 (FK#5-ManagerId-NULL, SystemAccount3-Step18, MemberTypes-Step21) and the seeded rows of step 21, so those steps still read Installed after it. Re-running step 29 is safe (it changes no data).
If step 3, 18, 21 or 29 is ever re-run, run step 30 again afterwards, as the last step (after the chains above). Checked by searching every numbered script for the objects step 30 replaces: spr_sys_ResetDatabase is in steps 3, 18, 21 and 29; spr_UpdateSMTPMaster and SMTP_Master are in no numbered script, and spr_sys_SetSmtpDefault is new. Step 30 contains the whole step 29 text, so after a re-run of step 3, 18 or 21 only step 30 is needed (not 29 and then 30), and every chain above that ends in step 29 now ends in step 30. Step 30 keeps the texts of steps 3, 18, 21 and 29, so those steps still read Installed after it. A re-run of step 29 alone makes the reset keep the mail settings again: step 30 then reads Partly, 2 of 3. Re-running step 30 is safe (it changes no data).
To see which steps a database has, run BMMS-Check-InstalledSteps.sql (read only; one row per step: Installed, Partly, Missing or Not detectable, with the missing markers listed). "Partly" usually means one of the re-runs above happened; its Detail says which step to run again.

## Steps 10 and 11: what to run where

On `BMMS_bak1` (test copy):

1. BMMS-Fix-UserDelete-Procedure.sql
2. BMMS-Add-ForeignKeys-Step5.sql         (expect "Added now: 21   Refused: 0", or "already exists" on a re-run)
3. BMMS-Fix-UserProtection-Stage1.sql     (step 13; the tests below call its signature. Run it again whenever step 10 is re-run)
4. BMMS-Test-UserDelete.sql               (75 checks)
5. BMMS-Test-UserKey-Workflows.sql        (23 checks)
6. BMMS-Test-FK-Procedures.sql            (19 checks)
7. BMMS-Test-ResetDatabase.sql            (test copy ONLY; since step 29 it needs step 29 and has 32 checks, 40 with step 30: see the step 29 and step 30 sections)
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
- BMMS-Check-InstalledSteps.sql           (read-only: which of steps 1 to 24 and 29 are installed in the selected database, for step 18 whether exactly one user is the system account, for step 19 whether the 12 setting rows exist, and for step 21 whether types 2, 3 and 6 are reserved; allowed on `BMMS`)
- BMMS-Test-Delete-Procedures.sql         (delete-procedure tests for the master tables; deletes real unreferenced rows, inside a transaction that is rolled back. With step 21 installed the member type part passes an active Admin, also tries a reserved type (expect Reason 7) and deletes a free type, adding one inside the transaction when none is unreferenced)
- BMMS-Test-FK-Procedures.sql             (tests for steps 6 to 9; rolled back)
- BMMS-Test-UserDelete.sql                (tests for steps 10 and 11, with step 13 installed: user delete rules, one test per protected column, one per key; rolled back)
- BMMS-Test-UserKey-Workflows.sql         (committee, meeting, agenda, approvals, finalize, confirm, alerts, login / backup / mail audit, through the real procedures; rolled back)
- BMMS-Test-ResetDatabase.sql             (runs spr_sys_ResetDatabase with all keys in place; since step 29 also its refusals and a forced failure that must roll back; since step 30 the safe mail settings, spr_sys_SetSmtpDefault and the SMTP save on an empty table; needs step 29; 32 checks, 40 with step 30; TEST COPY ONLY; rolled back, and the identity counters are put back)
- BMMS-Test-Attendance-FutureMeeting.sql  (tests for step 12: past / today / future / no-date meetings, new attendance and edits; 23 checks; run on the test copy; rolled back)
- BMMS-Test-UserProtection-Stage1.sql     (tests for step 13: every action by Admin / Controller / other roles, own account, last active Admin / Controller, acting user missing, reasons 5, 6 and 9, re-raised errors, list flags, locks; 142 checks; test copy only; rolled back. With step 14 installed, the three checks where an inactive Admin acts expect Reason 8 instead of 2, and their label says so)
- BMMS-Test-MeetingLocks.sql             (tests for step 15: meeting member add / edit / delete in each state, delete with attendance, attendance and chairman on finalized minutes, each finalize / confirm step in order and twice, NULL statuses, status lookup; 43 checks; test copy only; rolled back)
- BMMS-Test-MeetingLocks-Step16.sql       (tests for step 16: meeting date / committee / venue edits with and without attendance or agenda items, agenda add / edit / delete / approve / subject no by every role with the Controller option on and off, minutes finalized, inactive or missing acting user, System Settings, minutes and short text at Open / F / C, committee members before / on / after the appointment date, ceased, bad cessation, saved attendance, attendance and chairman saves; 100 checks; test copy only; rolled back)
- BMMS-Test-UserStatus-Stage2a.sql        (tests for step 14: the AccountStatus column, inactive acting user, deactivate / activate by role, list Status / CanDeactivate / CanActivate / ManagedCount, active user list, Manager list, status lookup, retired lock; 50 checks; test copy only; rolled back)
- BMMS-Test-UserStatus-Stage2b.sql        (tests for step 17: markers kept, committee / meeting / agenda alerts by every route with active and inactive recipients, manager active / inactive (Reason 11) / none, Reason 8 before 11, approve / reject with an active and an inactive creator, saved rows kept, minutes finalize, late action items (Controller fallback), alert mail addresses, last active Controller / Admin, re-activation without back-fill; 63 checks; test copy only; rolled back)
- BMMS-Test-SystemAccount-Stage3.sql      (tests for step 18: column, check, view, exactly one system account, markers kept; Reason 7 for edit, Login ID change, delete, deactivate and role change by another Admin, by the Controller and by itself, password reset by others; own password change; Activate; Reason 2 with ordinary Admins only; User Master, spr_GetUser and active list; no alerts, action items or alert mail for the system account; Reason 12 on approve / reject; saved rows kept; the Reset Database seed; 51 checks; test copy only; rolled back)
- BMMS-Test-OrganisationSettings-Step19.sql (tests for step 19: markers, the 12 rows in order, a missing row read as empty and re-created on save; save by an Admin (trimmed), one audit row per changed value, none when nothing changed, clearing and NULL; Windows-1252 characters kept; the system account may save; Controller (4), inactive Admin and unknown user (8) refused; Reason 3 naming the setting for each bad value (length, term, PIN, phone, fax, e-mail, line break, tab, characters outside Windows-1252); nothing changed after a refusal; logo upload / removal audit and its refusals; step 16 setting untouched; Reset Database leaves App_Setting alone; made-up sample values only; 52 checks; test copy only; rolled back)
- BMMS-Test-AgendaRouting-Step20.sql     (tests for step 20: markers, the steps 16 to 18 texts kept, step 21 untouched; the route of each kind of creator; saving with an active Manager (AC), no manager, a Controller manager and a manager with another role (AMA, manager fields empty), alert recipients, inactive manager (11), inactive Controller manager (11), inactive creator (8), no active Controller (15) while the manager route still saves; edits keep AC, AMA, AMR and ACA; the creation mail list per route; approve / reject refused for another Manager, a Controller approving at AC, Admin (also the empty call of the old button), mgmt, md_sect, the system account (12), inactive or unknown acting user (8), both decisions at once, unknown item (4), finalized agenda (5), decided items; allowed for the routed Manager, a Controller at AMA, a Controller rejecting at AC, the old and the new manager after a manager change, a Controller approving their own item; the re-route and its re-run; the signer and Special Invitee order (not by CreatedOn), inactive rows still listed; made-up sample values only; 56 checks; test copy only; rolled back; sends no mail)
- BMMS-Test-MemberTypes-Step21.sql       (tests for step 21: markers and the older markers kept, columns, constraints, reserved rows, scope against use; direct SQL refused by the constraints; save by an Admin, a Controller and the system account (trimmed), Manager (4), inactive / unknown / no acting user (8), Reason 3 naming the field for each bad value and duplicate; edit of a free type, every change of a reserved type refused (7), scope change of a type in use refused (5), deactivation allowed; the two drop-down lists and the marked current type; committee and meeting member save / edit by scope, status and existence (13), the step 15 lock first; delete in use (5), reserved (7), by role, not found; the master list columns; the Reset Database seed; made-up sample values only; 100 checks; test copy only; rolled back)
- BMMS-Test-MinutesGating-Step22.sql     (tests for step 22: markers, the step 15 procedure and the shared views and procedures untouched, the result columns equal those of View_Meeting and View_Minute; the meeting list (F and C only, by MeetingNo, own committee); the minutes rows for one meeting in each state (Open, NULL, Close/Open, F, C, another committee), All, ranges, department, subject numbers, committee 0; the old query of the code against the new procedure; a meeting finalized and confirmed through the real procedures is listed from then on; made-up sample values only; 36 checks; test copy only; rolled back; can be run twice in one window)
- BMMS-Test-MeetingDates-Step24.sql      (tests for step 24: marker, the texts of steps 16, 17 and 18 kept, parameters unchanged; create with the submission date yesterday, the meeting yesterday, a past meeting, the submission after the meeting date, a date missing (Reason 16 with its detail), refused creates leave no meeting and no alert; create today / today, today / later, between, equal to the meeting date, a time of day (saved, with their alerts); edit of an old meeting and of a meeting whose submission date has passed without changing the dates (saved), the same date at another time of day, a changed date before today, after the meeting date or missing (refused), refused edits change nothing and write no alert; Reasons 4, 6 and 10 before the date rules; made-up sample values only; 36 checks; test copy only; rolled back; no temporary tables)
- BMMS-Test-WorkflowOrder-Step23.sql     (tests for step 23: markers on the 7 objects, the older texts of steps 6, 8, 12, 15, 16, 17 and 18 kept, confirmation unchanged, the WorkflowOrderFrom setting; a new meeting through the whole order with each early step refused (17, 18, 19 'n/m'), a chairman without anyone present, the short text not counting as an update; Reasons 4, 1, 3 and 7 before the new ones, 17 before 9; a meeting without agenda items (attendance allowed, Finalise 19 '0/0'); an agenda item added after finalization; older meetings (no CreatedOn, or created in 2000) unchanged; the read procedure; made-up sample values only; 53 checks; test copy only; rolled back)

Since step 17 BMMS-Test-UserKey-Workflows.sql switches its three test users on (they are inserted inactive) and counts "every other user" among active users only, and BMMS-Test-FK-Procedures.sql expects minutes finalize to map every active user plus the row it saved before; BMMS-Test-MeetingLocks-Step16.sql picks as agenda creator a User whose manager is active or not set. Each checks whether step 17 is installed, so they pass before and after it.

Since step 18 the older tests find the protected system account (Users.IsSystem, through sp_executesql, so they still run before step 18) and adjust where it changes a result; each adjusted check says "[step 18: ...]" in its name when step 18 is installed:
- BMMS-Test-UserProtection-Stage1.sql: the list capture table is built from View_Users (it follows the new IsSystem column); the lock check acts with the first active Admin, which is the system account on a copy without another Admin, and then expects Reason 7 instead of 1.
- BMMS-Test-UserStatus-Stage2a.sql: the three capture tables are built from View_Users; "keeps the admin-name filter" becomes "leaves out the system account"; "Active list = spr_GetUser rows that are active" leaves the system account out (spr_GetUser now lists it).
- BMMS-Test-UserStatus-Stage2b.sql: the Admin recipient counts (checks 17 and 23) and the "all active users mapped" count (check 51) leave out the system account; the two last-active-Admin checks (60 and 61) expect Reason 7 when that Admin is the system account.
- BMMS-Test-UserKey-Workflows.sql and BMMS-Test-FK-Procedures.sql: "every other user" and "every user mapped" leave out the system account.
- BMMS-Test-ResetDatabase.sql: after the reset, exactly one system account, the admin seed (UserId 1); "admin cannot delete itself" expects Reason 7. 15 checks with step 18 installed, 14 without.

Since step 19 BMMS-Test-ResetDatabase.sql sets two sample organisation values inside its rolled-back transaction and checks that the reset leaves the 12 setting rows and their values unchanged ("[step 19]"): 16 checks with steps 18 and 19 installed.

Since step 20 four older tests follow the new routing, each adjusted check saying "[step 20: ...]" when step 20 is installed (counts unchanged): BMMS-Test-UserStatus-Stage2b.sql (the no-manager item is AMA with the Admins and Controllers alerted; the two items inserted for an inactive creator are routed to the Manager who approves them), BMMS-Test-SystemAccount-Stage3.sql (an ordinary Admin's approve is refused, Reason 14), BMMS-Test-UserDelete.sql (the approver acts as an active Controller at AMA for that call), BMMS-Test-MeetingLocks-Step16.sql (the item a Manager approves is at AC and routed to them). BMMS-Test-UserKey-Workflows.sql needs no change: its user has an active Manager, who approves at AC, then its Controller at AMA.

Since step 21 BMMS-Test-ResetDatabase.sql checks the six member types the reset seeds, with their scope, display order, reserved flag and status ("[step 21]"): 17 checks with steps 18, 19 and 21 installed. BMMS-Test-MeetingLocks.sql saves its meeting members with a meeting type (2, 3 or 6 first), so it passes on a freshly reset copy too, where the lowest id is the committee type "Member".

Since step 29 BMMS-Test-ResetDatabase.sql needs step 29 (it stops, changing nothing, without it) and calls the procedure as the page does, with an active Admin and the database name typed in lower case. Part 1 keeps the 17 checks and adds 4 ("[step 29]": Result 1, one audit row naming the acting user, Audit_Trail_SendMail empty, and the four seeded users stored with the hashes of the new default password, compared exactly as strings; that each hash belongs to the password is checked in C#, with the application's own Common.VerifyPassword). Part 2 adds 11: the procedure text (texts of steps 3, 18, 21 and 29, XACT_ABORT, no App_Setting); refusals for a wrong and an empty database name (Reason 3), a user who is not an Admin (4) and an unknown user (8), and that they changed nothing; a forced failure through a test trigger on Committee (dbo.trg_ZZ_Step29Test_Fail, created inside the transaction, so the procedure's rollback removes it): the error reaches the caller, no transaction is left open, every table has its rows and every identity counter its value again, put back by the procedure itself before the test reseeds, and the trigger is gone. The two "Test copy restored" checks now come last and cover both parts. 32 checks with steps 18, 19, 21 and 29 installed. The procedure's own Result row of part 1 appears as a small grid above the result grid.

Since step 30 BMMS-Test-ResetDatabase.sql adds 8 checks ("[step 30]") when step 30 is installed (it still runs, with 32 checks, without it). Part 1: the mail settings are set to sample values in two rows inside the rolled-back transaction; after the reset SMTP_Master has exactly one row, the safe default. Part 2: the SmtpDefault-Step30 marker in the reset, spr_sys_SetSmtpDefault and spr_UpdateSMTPMaster, and the reset asks the helper for no result row (the page reads the reset's own row); after the forced failure SMTP_Master is as before the test; spr_sys_SetSmtpDefault on an empty table writes the one default row, and with a wrong database name is refused (Result 0, Reason 3, DatabaseName) and changes nothing; spr_UpdateSMTPMaster on an empty table inserts the row and a second save updates it (each rolled back). Last: "Test copy restored: SMTP_Master rows and values unchanged". The test copy's mail settings are compared, never shown. 40 checks with steps 18, 19, 21, 29 and 30 installed.

Since step 24 three older tests save the meetings they create through spr_AddEditMeeting dated today instead of 10 days ago, because a create with a past date is refused from step 24; each change says "[step 24]" in a comment. Checks and counts are unchanged, and they pass before and after step 24: BMMS-Test-MeetingLocks-Step16.sql (the new meeting 99910), BMMS-Test-SystemAccount-Stage3.sql (meeting 99981), BMMS-Test-UserStatus-Stage2b.sql (meeting 99971 and its two edits, which keep the saved dates). Meetings the tests insert directly keep their past dates; their edits that keep a date, or move it to today, still pass.

Since step 23 BMMS-Test-UserKey-Workflows.sql gives its meeting (saved through spr_AddEditMeeting, so it counts as created after step 23) a chairman, one member present and an updated minute before it finalizes the minutes; the lines say "[step 23]" in a comment, no check reads them, and the count stays 23. The other older tests create their meetings with a direct insert (no CreatedOn) or use the lowest existing MeetingId, so they count as older meetings and are unchanged. After a Reset Database every meeting is new: BMMS-Test-FK-Procedures and BMMS-Test-UserDelete, which pick the lowest existing MeetingId, would then follow the order too.

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
- Committee and Meeting mail Bcc and the Agenda manager mail use active users only (spr_GetActiveUserList). Audit Trail and Reset Password list users through spr_GetUser, which until step 18 also left out the user named "admin" (see step 18).
- spr_LockUserByUserId is retired (error 50002); use spr_SetUserStatusByUserId.
- Alerts, action items and mail recipients chosen inside the database procedures: see step 17 (stage 2b).

Every protected procedure returns one row `Result, Reason, ReasonDetail`. Result 1 = done, 0 = refused. Reason: 0 done, 1 own account, 2 last active Admin, 3 last active Controller, 4 not allowed for your role, 5 other users point at the user (names), 6 history (groups), 7 the protected system account (step 18), 8 acting user missing, 9 a database reference the checks do not know. For Reason 9 the page shows a plain sentence and writes the SQL Server message to the application error log (`BMMS\Log\yyyy_MM_dd_ErrorLog.txt`). Any other database error is re-raised and reaches the error page; it is never reported as "in use".

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

## Step 18: the protected System Administrator account (what to run where)

Before installing, run the read-only queries below on `BMMS` and keep the results. Q1 must show exactly one active Admin with the LoginName "admin" and a department and designation that exist; otherwise the script stops, changing nothing.

On the test copy (`BMMS_Test`, or `BMMS_bak1`), in this order:

1. BMMS-Fix-SystemAccount-Stage3.sql      (stops, changing nothing, if step 14, 15, 16 or 17 is missing, if no single active "admin" Admin can be chosen, or if more than one user is already flagged)
2. BMMS-Test-SystemAccount-Stage3.sql     (51 checks)
3. BMMS-Test-UserStatus-Stage2b.sql       (63 checks)
4. BMMS-Test-UserStatus-Stage2a.sql       (50 checks)
5. BMMS-Test-UserProtection-Stage1.sql    (142 checks)
6. BMMS-Test-UserDelete.sql               (75 checks)
7. BMMS-Test-UserKey-Workflows.sql        (23 checks)
8. BMMS-Test-FK-Procedures.sql            (19 checks)
9. BMMS-Test-MeetingLocks.sql             (43 checks)
10. BMMS-Test-MeetingLocks-Step16.sql     (100 checks)
11. BMMS-Test-Attendance-FutureMeeting.sql (23 checks)
12. BMMS-Test-ResetDatabase.sql           (15 checks; test copy ONLY)
13. BMMS-Check-InstalledSteps.sql         (step 18 Installed, 18 of 18 markers, one of them "Exactly one system account")

On `BMMS`, after the backup, in a quiet period, and only after step 17 is there: BMMS-Fix-SystemAccount-Stage3.sql, then deploy the new build straight away. SQL before deploying the build, and no gap between the two. During a gap the old build already shows the system account in User Master with Edit, Delete and Deactivate greyed (the flags come from the database), but without the "(System account)" label; Reset Password still offers it and a reset is refused with the old generic message; an approve or reject it attempts on the Dashboard is refused with "Record Not Saved" instead of the Reason 12 message. Nothing is changed wrongly in the gap.

Rules:

- One user is the protected system account: Users.IsSystem = 1 (BIT NOT NULL, default 0, CK_Users_IsSystem). The script flags the active Admin whose LoginName is "admin" on its first run and keeps the flag on re-runs. Nothing in the application writes IsSystem. "Exactly one" is checked by the script, BMMS-Check-InstalledSteps.sql and the test (there is no unique index).
- Nobody can edit the system account (details or Login ID), delete it, deactivate it or change its role, the account itself included: Reason 7. User Master shows it greyed, labelled "(System account)", with those buttons disabled.
- Its password: only the account itself, on Change Password. Reset Password does not offer it, and a reset by anyone else is refused (Reason 7). A lost password is recovered by the DBA (below).
- Activate stays allowed for an active Admin, so the account can be switched on again if it is ever found inactive (the Controller gets Reason 4: the target is an Admin account).
- The last-active-Admin rule (Reason 2) counts ordinary Admins only: the last ordinary active Admin cannot be deleted, deactivated or given another role, even while the system account is active. Create a named ordinary Admin for day-to-day work if the system account is the only Admin today (Q2).
- It takes no part in the workflow: no new committee, meeting or agenda alerts, no action items from minutes finalize, no alert mail (spr_GetAlertMailId, spr_GetActiveUserList), and it cannot approve or reject agenda items (Reason 12; the Dashboard hides Approve and Reject for it). An action item added on Minutes Update for an agenda item it created goes to the active Controllers. Other Admins keep their current behaviour.
- Rows already saved for it (alerts, action items) are left as they are.
- The old filter `UserName NOT LIKE 'admin'` is gone from spr_GetUser, spr_GetUserListForUserPage and spr_GetActiveUserList: User Master and the Audit Trail user list now show the account; the active list (workflow mail) leaves it out by IsSystem. Any other user whose UserName is "admin" is now listed like everyone else (Q7).
- Reset Database seeds the "admin" user with IsSystem = 1 and the three other default users with IsSystem = 0. The three seed e-mail addresses are now placeholders (con@, mgr@, usr@ example.invalid); they matter only after a reset.
- No new role: the Admin role and the flag are enough. PageAccess.xml and the menu are unchanged.

Reasons and messages:

- User procedures, Reason 7: "This is the protected system account. It cannot be edited, deactivated, deleted, or have its role or Login ID changed, and only the account itself can change its password (Change Password)."
- spr_UpdateAgendaByAgendaId, Reason 12 (checked first): "The system account takes no part in the agenda workflow and cannot approve or reject agenda items."
- spr_GetUserListForUserPage: CanEdit, CanChangeRole, CanDelete and CanDeactivate are 0 for the system account for every acting user.

Recovering a lost password of the system account (DBA only):

1. Confirm with the application owner that the password is really lost and that no ordinary Admin can do the work instead.
2. Back up the database: `BACKUP DATABASE BMMS TO DISK = N'C:\Backups\BMMS_before_system_password.bak' WITH COPY_ONLY;`
3. In SSMS, on that database, set the password to the application's default password. The value below is the stored hash of that default password, the same one Reset Database seeds for "admin":

```sql
UPDATE Users
SET [Password] = '100000.gURba0Xwa3iXhBwkFEi/hA==.yxFedi3Cfs3FLcDlU7oWXp94eY15AGoU4AN+c3tf8j0=',
    AccountStatus = 1,
    UpdatedOn = GETDATE()
WHERE IsSystem = 1;
SELECT @@ROWCOUNT AS UsersChanged;   -- must be 1
```

4. Log in as "admin" with the application's default password (the application owner has it). The application sends the account straight to the first-login password change; choose the new password there. Since step 29 the hash above is that of the new default password (Common.DefaultPassword in BMMSBAL/Common.cs): use it only with the step 29 build or later; the old default is not a default any more.
5. Record the recovery (date, who asked, who ran it) in the change log. The UPDATE above is not written to the Audit Trail.

Read-only queries for `BMMS` (they only read; the account is UserId 5 there today):

```sql
SET NOCOUNT ON;
-- Q1 the account step 18 will flag, and whether View_Users can show it
SELECT 'Q1' Q, u.UserId, u.UserName, u.LoginName, r.RoleCode, u.AccountStatus, u.DepartmentId, u.DesignationId, u.ManagerId, u.EmailId,
       u.CreatedOn, u.CreatedBy, u.UpdatedOn, u.UpdatedBy,
       CASE WHEN d.DepartmentId IS NULL THEN 'missing' ELSE 'ok' END Dept, CASE WHEN g.DesignationId IS NULL THEN 'missing' ELSE 'ok' END Desig
FROM Users u LEFT JOIN Roles r ON r.RoleId=u.RoleId LEFT JOIN Department d ON d.DepartmentId=u.DepartmentId LEFT JOIN Designation g ON g.DesignationId=u.DesignationId
WHERE u.UserId=5 OR u.LoginName='admin' OR u.UserName='admin';
-- Q2 every Admin (after step 18, Reason 2 counts the ordinary ones only)
SELECT 'Q2' Q, u.UserId, u.UserName, u.LoginName, u.AccountStatus FROM Users u JOIN Roles r ON r.RoleId=u.RoleId WHERE r.RoleCode='admin';
-- Q3 every keyed column that points at UserId 5 (builds one SELECT per key; reads only)
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql = @sql + N'SELECT ''' + OBJECT_NAME(fk.parent_object_id) + N'.' + c.name + N''' RefColumn, COUNT(*) Cnt FROM dbo.'
     + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + N' WHERE ' + QUOTENAME(c.name) + N' = 5 UNION ALL '
FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=fk.object_id
JOIN sys.columns c ON c.object_id=fc.parent_object_id AND c.column_id=fc.parent_column_id
WHERE fk.referenced_object_id=OBJECT_ID('dbo.Users');
SET @sql = LEFT(@sql, LEN(@sql) - 10);
EXEC (@sql);
-- Q4 user-id columns without a key
SELECT 'Q4' Q, (SELECT COUNT(*) FROM Minutes WHERE CreatedBy=5) MinutesCreated, (SELECT COUNT(*) FROM Minutes WHERE UpdatedBy=5) MinutesUpdated,
       (SELECT COUNT(*) FROM Audit_Trial_Login WHERE User_Id=5) Logins, (SELECT COUNT(*) FROM Audit_Trail_SendMail WHERE Mail_Send_By=5) MailsSent,
       (SELECT COUNT(*) FROM Audit_Trail_SqlBackup WHERE User_Id=5) Backups;
-- Q5 open workflow rows held by UserId 5 (kept by step 18)
SELECT 'Q5' Q, am.AlertTypeCode, COUNT(*) Rows, SUM(CASE WHEN ISNULL(m.ReadStatus,0)=0 THEN 1 ELSE 0 END) Unread
FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId=m.AlertId WHERE m.UserId=5 AND m.StatusId=1 GROUP BY am.AlertTypeCode;
SELECT 'Q5b' Q, COUNT(*) OpenActionItems FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId=m.ActionItemId
WHERE m.UserId=5 AND ISNULL(a.IsConfirmed,0)=0;
-- Q6 agenda rows created or approved by 5, and users who have 5 as manager
SELECT 'Q6' Q, (SELECT COUNT(*) FROM Agenda WHERE CreatedBy=5) AgendaCreated, (SELECT COUNT(*) FROM Agenda WHERE MgrApprovedBy=5) MgrApproved,
       (SELECT COUNT(*) FROM Agenda WHERE ControllerApprovedBy=5) CtrlApproved, (SELECT COUNT(*) FROM Users WHERE ManagerId=5) ManagedUsers;
-- Q7 users hidden until now by the name filter
SELECT 'Q7' Q, UserId, UserName, LoginName FROM Users WHERE UserName LIKE 'admin';
```

## Step 19: organisation details as settings (what to run where)

BMMS ships neutral: the organisation name, office address and contact details that notices, minutes, reports and sitting-fee certificates print are settings, set by an Admin on System Settings (Utilities menu). Nothing organisation-specific is in the code or in this repository.

On the test copy (`BMMS_Test`, or `BMMS_bak1`), in this order:

1. BMMS-Fix-OrganisationSettings-Step19.sql (stops, changing nothing, if step 16 or 18 is missing)
2. BMMS-Test-OrganisationSettings-Step19.sql (52 checks)
3. BMMS-Test-ResetDatabase.sql            (16 checks; test copy ONLY)
4. BMMS-Check-InstalledSteps.sql          (step 19 Installed, 4 of 4 markers)

On `BMMS`, after the backup: BMMS-Fix-OrganisationSettings-Step19.sql, then deploy the new build. SQL before the build: the new build reads spr_GetOrganisationSettings for every printed output and the System Settings page. A gap is harmless: the old build never calls the new procedures.

**Straight after the release, an Admin fills in the organisation details on System Settings.** Until then every printed and mailed output leaves the organisation name, address and contact lines out (it never prints a placeholder), and System Settings shows a warning. Upload the organisation logo there too: until a logo is uploaded, PDFs print no logo and the organisation name takes its place.

**Back up the folder `BMMS\Files\Branding` together with the database.** The uploaded logo is kept there (`report-logo.png`), not in the database and not in this repository; a database backup alone does not include it. Deploying a new build does not touch the folder, unless the deployment is set to delete files on the server that are not in the build.

The settings (table App_Setting; default '' = not set; values are trimmed; line breaks, control characters and characters outside Windows-1252 are refused):

| Setting | Meaning | Limit | When empty |
|---|---|---|---|
| OrganisationName | legal name | 150 | name lines left out |
| OrganisationShortName | short name for mail headers | 100 | the legal name |
| OrganisationTerm | the word in "the ___'s Board" / "of our ___" | 30, letters and spaces | "Company" |
| CertificateSignOff | text after "For" in letters and certificates | 150 | the legal name; "For" line left out if both are empty |
| RegisteredOfficeLabel | e.g. "Regd. & Admin. Office" | 60 | left out |
| RegisteredOfficeLine1 / Line2 | street / locality | 100 each | left out |
| RegisteredOfficeCity | city (also the "Place" line of the Agenda Summary) | 60 | left out |
| RegisteredOfficePinCode | PIN / postcode | 12, digits, space, hyphen | left out |
| OrganisationPhone / OrganisationFax | certificate footer | 60 each, digits, space, + - ( ) / , | left out; the whole contact line if all three are empty |
| OrganisationEmail | certificate footer | 100, one address | left out |

Procedures (each carries the text OrganisationSettings-Step19), one row `Result, Reason, ReasonDetail` as step 16:

- spr_GetOrganisationSettings: the 12 settings in a fixed order ('' for a missing row) with the last change.
- spr_SetOrganisationSettings: all 12 in one transaction or none; only an active Admin (the system account included); one Audit_Trail_Master row per changed value. Reason 3 names the first setting that is not valid, 4 not an Admin, 8 acting user missing or inactive.
- spr_RecordOrganisationLogo: the audit row for a logo upload or removal; only an active Admin. The page writes or deletes the file only after Result = 1.

Reset Database (step 18) does not touch App_Setting: the organisation details survive a reset (BMMS-Test-ResetDatabase.sql checks it). Their change history in Audit_Trail_Master is cleared with the rest of the audit trail.

The logo (System Settings, Admin only): PNG, JPEG or GIF, at most 500 KB and 1000 x 300 pixels. The file must decode as an image and pass a structure check of its format (PNG: every chunk and its CRC, IHDR first, IEND last; JPEG: the markers up to the scan and the end marker; GIF: every block up to the trailer), so a cut or damaged file is refused; it is re-drawn and saved as PNG under the fixed name `Files\Branding\report-logo.png`. Known limit: a JPEG whose markers are intact but whose compressed image data is damaged is accepted and saved as drawn. Nothing of the uploaded file's name or path is used. "Remove logo" deletes it. Each upload and removal writes an audit row.

Manual checks for the logo, on the test copy, logged in as an Admin:

1. Upload a small PNG: accepted, the preview shows it, Audit_Trail_Master has "Uploaded: PNG w x h, n KB" for OrganisationLogo.
2. Rename any .exe to logo.png and upload it: refused ("not a valid image"), the previous logo is unchanged, no audit row.
3. Take a real .png, cut it to its first 200 bytes (or overwrite the middle with zeros) and upload it: refused, no change, no audit row.
4. Upload an image larger than 500 KB, and one wider than 1000 or taller than 300 pixels: refused.
5. Remove logo: the file is gone, the PDFs print the organisation name instead, an audit row "Removed".
6. Log in as a Controller and open System Settings: access denied (PageAccess.xml).

## Step 21: member types (what to run where)

Each company keeps its own member types (for example Director, Member, Independent Director) on the Member Type Master (Master menu, Admin and Controller). A type is a **committee** type (Committee Member Tag / UnTag) or a **meeting** type (Meeting - Member Tag / UnTag); each tagging page lists only the active types of its own scope, in display order.

On the test copy (`BMMS_Test`, or `BMMS_bak1`), in this order:

1. BMMS-Fix-MemberTypes-Step21.sql       (stops, changing nothing, if step 15, 18 or 19 is missing, if two types have the same code or name, or if a meeting type is used on Committee Member)
2. BMMS-Test-MemberTypes-Step21.sql      (100 checks)
3. BMMS-Test-MeetingLocks.sql            (43 checks)
4. BMMS-Test-Delete-Procedures.sql       (read the Member_Type part of the Messages tab: Result 0 / Reason 5, 0 / 7, 1)
5. BMMS-Test-ResetDatabase.sql           (17 checks; test copy ONLY)
6. BMMS-Check-InstalledSteps.sql         (step 21 Installed, 15 of 15 markers)

On `BMMS`, after the backup: BMMS-Fix-MemberTypes-Step21.sql, then deploy the new build straight away. SQL before the build: the new build calls the new parameters and spr_GetMemberTypeForTagging. In the gap the older Member Type page cannot save or delete (Reason 8; it shows "Record Not Saved" or the "in use" message); the older tagging pages keep working (a committee member save still reports its row count).

What the script changes in the data (it prints the number of rows):

- Member_Type gets IsReserved (0 / 1) and MemberScope (C committee, M meeting). Types 2, 3 and 6, where they exist, become reserved meeting types and are kept active. A type used only on Meeting Member becomes a meeting type; every other type stays a committee type. Type 2 is not re-created where it is missing.
- On the first run DisplayOrder 0 becomes the id, so the lists keep the order they had.
- Check constraints: MemberScope is C or M; a reserved type is active. Unique indexes on MemberTypeCode and MemberTypeName (case is ignored).

Reserved types and where the application uses them by id:

| Id | Type | Used by |
|---|---|---|
| 2 | Invitee | the minutes "ON INVITATION" block (Report/Reports.aspx.cs) |
| 3 | In Attendance | spr_GetCompanySecretary: the signer of notices, minutes and follow-up letters, and the minutes "IN ATTENDANCE" block |
| 6 | Special Invitee | the minutes (Report/Reports.aspx.cs) |

Rules (one row `Result, Reason, ReasonDetail`):

- Save, edit and delete: an active Admin or Controller (Reason 4 for any other role, 8 when the acting user is missing or inactive).
- Code and name: trimmed, 1 to 50 characters, no control characters or characters outside Windows-1252, unique ignoring case (Reason 3; ReasonDetail names the field, DuplicateCode or DuplicateName). Scope C or M, display order 0 to 9999, status 0 or 1.
- A reserved type cannot be edited, deactivated or deleted (Reason 7). New types are never reserved.
- A type in use keeps its scope (Reason 5, "<n> committee, <m> meeting"); it can be renamed or deactivated. Deactivated, it leaves the drop-downs, and the rows that have it keep it.
- Delete: only an unused, free type (Reason 5 when in use).
- Committee member and meeting member save: the type must be an active type of the page's scope (Reason 13, ReasonDetail the type name). An edit that keeps the row's current type is allowed even when that type is now inactive; the drop-down shows it as "(inactive)". The meeting member locks of step 15 come first.

Reset Database seeds the six types with their scope, display order (the id) and the reserved flag (2, 3 and 6).

Manual checks after deploying the build, on the test copy:

1. Controller: the Master menu shows Member Type; the page opens (Admin as well). A Manager opening `Master/MemberType.aspx` directly gets "Access denied".
2. In Attendance and Special Invitee (and Invitee, where it exists) show "(reserved)"; their Edit and Delete are greyed. A type in use has Delete greyed, with the counts in its tooltip.
3. Add "Director" (Used On: Committee, Display Order 10) and "Observer" (Used On: Meeting). Committee Member Tag offers Director with Chairman and Managing Director, not Observer, In Attendance or Special Invitee; Meeting - Member Tag offers Observer, In Attendance and Special Invitee, not Director.
4. Add a second type named "director": refused, "Another member type already has this name."
5. Tag a committee member as Director, then edit Director: "Used On" is greyed with the in-use note. Make Director inactive: it leaves the Committee Member drop-down; editing the tagged member shows "Director (inactive)" selected and saves.
6. Delete an unused type: deleted. Delete Director while in use: Delete is greyed.
7. Print the minutes of a meeting with an In Attendance member: the signer and the "IN ATTENDANCE" block are unchanged.

## Step 20: agenda routing and the meeting signer (what to run where)

On the test copy (`BMMS_Test`), after a backup of it, in this order:

1. BMMS-Check-InstalledSteps.sql          (steps 1 to 19 and 21 Installed, step 20 Missing)
2. BMMS-Fix-AgendaRouting-Step20.sql      (stops, changing nothing, if step 18, 19 or 21 is missing; prints the number of items re-routed - 1 on the current `BMMS_Test`, agenda 138)
3. BMMS-Test-AgendaRouting-Step20.sql     (56 checks)
4. BMMS-Test-UserStatus-Stage2b.sql       (63 checks)
5. BMMS-Test-SystemAccount-Stage3.sql     (51 checks)
6. BMMS-Test-UserDelete.sql               (75 checks)
7. BMMS-Test-MeetingLocks-Step16.sql      (100 checks)
8. BMMS-Test-UserKey-Workflows.sql        (23 checks)
9. The other tests, unchanged: BMMS-Test-MemberTypes-Step21.sql (100), BMMS-Test-OrganisationSettings-Step19.sql (52), BMMS-Test-MeetingLocks.sql (43), BMMS-Test-UserProtection-Stage1.sql (142), BMMS-Test-UserStatus-Stage2a.sql (50), BMMS-Test-FK-Procedures.sql (19), BMMS-Test-Attendance-FutureMeeting.sql (23), BMMS-Test-ResetDatabase.sql (17; test copy ONLY)
10. BMMS-Check-InstalledSteps.sql         (step 20 Installed, 7 of 7 markers; steps 16, 17, 18 and 21 still Installed)

On `BMMS`, after the backup: BMMS-Fix-AgendaRouting-Step20.sql, then deploy the build straight away. Do not run the tests on `BMMS`. In the gap the older Dashboard still shows Approve / Reject to Admin, mgmt and md_sect; the database refuses them (Reason 14), which the older build shows as "Record Not Saved" after it has already sent the mail.

Routing of a new agenda item saved by a User (Agenda Entry):

| The creator's manager | Saved as | Alerted | "Agenda created" mail Bcc | Who acts next |
|---|---|---|---|---|
| an active Manager | AC (unchanged) | the Admins and that Manager | that Manager | that Manager approves (AMA) or rejects (AMR) |
| none | AMA, manager fields empty | the Admins and the active Controllers | the active Controllers | a Controller approves (ACA) or rejects (ACR) |
| an active Controller | AMA, manager fields empty | the Admins and the active Controllers | the active Controllers | a Controller |
| a user with another role (admin, mgmt, md_sect, user) | AMA, manager fields empty | the Admins and the active Controllers | the active Controllers | a Controller |
| set but inactive (any role) | refused, Reason 11 (unchanged) | - | - | - |
| none / a Controller / another role, and no Controller is active | refused, Reason 15 | - | - | - |

A Manager's own item is saved as AMA and a Controller's own item as ACA, as before. "Manager Approved" is the status name of AMA, also for an item that skipped the manager step. A User may edit the item until the Controller decides (as before for an item at AC); approved and rejected items keep their status and their edit locks.

Approve / reject (Dashboard; spr_UpdateAgendaByAgendaId), checked in this order: the system account (Reason 12), acting user missing or inactive (8), unknown item (4), agenda finalized (5), then:

- a Manager approves or rejects at AC an item routed to them (they have its alert) or of which they are the creator's current manager;
- a Controller approves at AMA, and rejects at AC or AMA (Agenda Finalization rejects the items still waiting; that page is open to Controllers only, PageAccess.xml);
- anything else is refused: Reason 14, "You cannot approve or reject this agenda item at its current stage (status)". That includes Admin, mgmt and md_sect, whose Dashboard shows no Approve / Reject any more, and an item already decided.
- A Controller may approve an item they created.
- The Dashboard sends the approve / reject mail only after the database has accepted the action.

The script re-routes once: an item still at AC on a meeting whose agenda is open, whose creator now goes straight to the Controllers, moves to AMA; the active Controllers get the alert (unread), Audit_Trail_Master gets one row per item by the system account; no mail. Items waiting for an active Manager, or for an inactive one, stay at AC.

The signer (Notice, Followup and Action Taken mails, minutes): the first In Attendance member (type 3) tagged on the meeting, by the lowest MeetingMemberId (an identity, given in insert order and not changed by an edit; CreatedOn comes from the page and can repeat). Meeting_Member.StatusId (1 Active, 0 InActive, set on the Meeting Member page) is not used by any member list of these reports, so the signer does not use it either: an inactive row is listed as before. With no In Attendance member the Notice, Followup and Action Taken print "Authorized Signatory" (unchanged) and the minutes leave the IN ATTENDANCE block out and the signer's place empty (unchanged).

The minutes (Reports, Minutes, Generate: the pop-up shows the layout): PRESENT lists the committee members only (Special Invitees no longer); ON INVITATION lists the Invitees (type 2, where it exists) and then the Special Invitees (type 6), each in the order tagged; IN ATTENDANCE lists every In Attendance member; the first one signs.

Mail during testing: the application mails on every agenda save, approve and reject. The SMTP settings are not in a file: they are the row of table SMTP_Master (SMTPServer, SMTPServerPort, UserName, Password (protected), FromMailId, Bcc), read by spr_GetSMTPMaster and set on Admin, SMTP Configuration (Master/SMTPServerConfig.aspx). A failed send is caught and written to the error log (Mail_Mgr.SendWebEmail returns "Error: ..."). The Dashboard approve / reject and Agenda Finalization complete whatever the mail result; a new agenda item is NOT saved when its "agenda created" mail fails (Agenda Entry shows the mail error), as before. To smoke-test without real mail, point the test application's SMTP settings at a local mail catcher (it accepts and keeps the mail), not at an address nobody receives, or the agenda saves fail. Since step 30 a new or reset database has the safe default localhost, port 25, no login, From noreply@example.invalid: a mail catcher such as smtp4dev on port 25 of the web server receives the mail without any change; with nothing listening there every mail fails and a new agenda item is not saved (see step 30).

Manual checks after deploying the build, on the test copy (made-up data only):

1. User `creduser` (manager `credmanager`) adds an agenda item: status Agenda Creation; `credmanager` sees it on the Dashboard with Approve / Reject; the Admins see it without the buttons.
2. User `ituser` (no manager) adds an item: status Manager Approved; `Controller` and `sect` see it with Approve / Reject; `credmanager` does not see it.
3. A made-up user in Secretarial whose manager is `sect` (a Controller) adds an item: Manager Approved; both Controllers have the alert.
4. `ituser` edits that item before the Controller decides: saved, still Manager Approved.
5. `credmanager` approves the `creduser` item: Manager Approved; the Controllers get the alert. Approve again from an old Dashboard tab: refused with the "current stage" message, no mail.
6. `Controller` approves one item (Controller Approved) and rejects another (Controller Rejected); Agenda Finalize on a meeting with an item still at Agenda Creation rejects it.
7. A made-up ordinary Admin opens an agenda alert: no Approve / Reject. (`admin` is the system account and had no buttons already.)
8. A made-up user whose manager is then made inactive tries to add an item: "Your manager ... is inactive" (unchanged).
9. Agenda 138 of `BMMS_Test` (by `ituser`): Manager Approved after the script; the Controllers have the alert.
10. On a made-up meeting tag two In Attendance members, one Special Invitee and, where type 2 exists, one Invitee. After Finalize Minutes (step 22), Reports, Minutes, Generate: ON INVITATION lists the Invitee then the Special Invitee; PRESENT does not; IN ATTENDANCE lists both members; the first tagged signs. The Notice and the Minutes show the same signer.
11. A meeting without an In Attendance member: the Notice prints "Authorized Signatory".

Smoke list per role (BMMS_Test users; mail to a catcher only, see above):

- user: `creduser` add (AC), `ituser` add (AMA), edit an own AMA item, try to edit an approved item (locked, unchanged).
- manager: `credmanager` approve and reject at AC; no buttons on an AMA item.
- Controller: `Controller` or `sect` approve and reject at AMA, reject at AC through Agenda Finalize, Reports, Minutes, Generate after Finalize Minutes.
- Admin: a made-up ordinary Admin, Dashboard view only; `admin` unchanged.

## Step 22: minutes reports only after Minutes Finalisation (what to run where)

The intended order of a meeting is 1 Agenda Finalisation, 2 Attendance, 3 Update Minutes, 4 Minutes Finalisation, 5 Minutes Generation, 6 Minutes Confirmation. Until now Reports, Minutes and Reports, Minutes Extract listed every meeting and printed the minutes as soon as Agenda Finalisation had created the Minutes rows (before attendance, before Update Minutes, before Finalize Minutes, even for a meeting dated in the future). From step 22 both reports list, view and generate only meetings whose minutes are finalized or confirmed (Meeting.MinutesStatus F or C); confirmation is not needed first.

- spr_GetMinutesReportMeetings fills the meeting lists of both reports (the View_Meeting columns, by MeetingNo). The other pages keep spr_GetMeetingByCommitteeId and still list every meeting.
- spr_GetMinutesReport returns the minutes rows for both reports (the View_Minute columns). It replaces the two queries the code built (GetMinutesReport and GetMinutesExtractReport were the same query), with the same filters and order, and leaves out every meeting whose minutes are not finalized: with - All - or a range those meetings are simply left out.
- The page shows "The minutes of this meeting are not finalized yet. ..." when a meeting is chosen whose minutes are not finalized, and "No meeting of this committee has finalized minutes yet, ..." when the committee has none. No Reason code: the procedures only read.
- Unchanged: the agenda reports, Update Minutes (still allowed at F, the step 16 rule), Finalize Minutes, Minutes Confirmation, Attendance, the Followup reports. Generation leaves no trace in the database, so minutes printed earlier cannot be told apart; the rule follows the current state only.

On the test copy (`BMMS_Test`), after a backup of it, in this order:

1. BMMS-Check-InstalledSteps.sql          (steps 1 to 21 Installed, step 22 Missing)
2. BMMS-Fix-MinutesGating-Step22.sql      (stops, changing nothing, if step 15 is missing)
3. BMMS-Test-MinutesGating-Step22.sql     (36 checks)
4. The other tests, unchanged: BMMS-Test-AgendaRouting-Step20.sql (56), BMMS-Test-MemberTypes-Step21.sql (100), BMMS-Test-OrganisationSettings-Step19.sql (52), BMMS-Test-SystemAccount-Stage3.sql (51), BMMS-Test-UserStatus-Stage2b.sql (63), BMMS-Test-MeetingLocks-Step16.sql (100), BMMS-Test-MeetingLocks.sql (43), BMMS-Test-UserProtection-Stage1.sql (142), BMMS-Test-UserStatus-Stage2a.sql (50), BMMS-Test-UserDelete.sql (75), BMMS-Test-UserKey-Workflows.sql (23), BMMS-Test-FK-Procedures.sql (19), BMMS-Test-Attendance-FutureMeeting.sql (23), BMMS-Test-ResetDatabase.sql (17; test copy ONLY)
5. BMMS-Check-InstalledSteps.sql          (step 22 Installed, 2 of 2 markers; steps 1 to 21 unchanged)

On `BMMS`, after the backup: BMMS-Fix-MinutesGating-Step22.sql, then deploy the build. Do not run the tests on `BMMS`. The older build never calls the new procedures, so the order is free; until the build is deployed the gap stays open.

Meetings on the dev databases today: on `BMMS_Test` meetings 3 and 343 (agenda finalized, minutes Open) are listed now and are no longer listed after the build; meeting 1 (C) stays. On `BMMS` meetings 1 and 4 (both C) stay listed.

Manual checks after deploying the build, on the test copy (made-up data only):

1. Reports, Minutes: choose a committee. The meeting list shows only meetings whose minutes are finalized or confirmed. A committee with none shows the "No meeting of this committee has finalized minutes yet" message and an empty list.
2. On a made-up meeting with the agenda finalized and the minutes not finalized (Open): it is not in the list. Choosing it from an old page or tab, View and Generate show "The minutes of this meeting are not finalized yet".
3. Finalize Minutes on that meeting: it appears in the list; View shows its rows; Generate opens the minutes.
4. Minutes Confirmation on it: still listed; Generate still works.
5. - All - and Between (range): only finalized and confirmed meetings are printed; Department and Subject No narrow them as before.
6. Reports, Minutes Extract: checks 1 to 5 again.
7. Agenda Summary and Agenda Details: unchanged, every meeting listed.
8. Manager (`credmanager`): Minutes and Minutes Extract show only the own department, finalized meetings only.

## Step 24: meeting dates (what to run where)

The Meeting page accepted an Agenda Submission Date in the past (a meeting created today with the submission date yesterday; Users can then never submit agenda items to it, because Agenda Entry offers a meeting only while its submission date is today or later) and refused a submission date equal to the meeting date. The database checked no dates.

Rules (spr_AddEditMeeting is the authority; Meeting.aspx.cs shows the same message before saving). Today is the database server date; dates are compared as dates, the time of day is ignored.

| | Meeting Date | Agenda Submission Date |
|---|---|---|
| Create | required; not before today | required; not before today; on or before the Meeting Date (equal allowed) |
| Edit | required; not before today only if it is changed | required; not before today only if it is changed; always on or before the Meeting Date |

A meeting today with the submission date today can be created. There is no exception for past meetings. On edit the existing refusals come first: unknown meeting (Reason 4), date or committee locked by attendance (6), committee locked by agenda items (10), then the date rules. Refused with Reason 16 and these messages:

- Missing: "Meeting Date and Agenda Submission Date are required."
- MeetingBeforeToday: "The Meeting Date cannot be before today."
- SubmissionBeforeToday: "The Agenda Submission Date cannot be before today."
- SubmissionAfterMeeting: "The Agenda Submission Date must be on or before the Meeting Date."

The page now saves first and sends the "Meeting Created" / "Meeting Updated" mail only when the save is accepted (Result 1); the mail text and the handling of a failed mail are unchanged. Meetings already saved keep their dates (no data fix). Unchanged: the previous-meeting rule, the "This meeting was closed." gate, the markup and the calendars.

On the test copy (`BMMS_Test`), after a backup of it, in this order:

1. BMMS-Check-InstalledSteps.sql          (steps 1 to 22 Installed, step 24 Missing)
2. BMMS-Fix-MeetingDates-Step24.sql       (stops, changing nothing, if step 16, 17 or 18 is missing)
3. BMMS-Test-MeetingDates-Step24.sql      (36 checks)
4. The three adjusted tests: BMMS-Test-MeetingLocks-Step16.sql (100 checks), BMMS-Test-SystemAccount-Stage3.sql (51), BMMS-Test-UserStatus-Stage2b.sql (63)
5. The other tests, unchanged: BMMS-Test-MinutesGating-Step22.sql (36), BMMS-Test-AgendaRouting-Step20.sql (56), BMMS-Test-MemberTypes-Step21.sql (100), BMMS-Test-OrganisationSettings-Step19.sql (52), BMMS-Test-MeetingLocks.sql (43), BMMS-Test-UserProtection-Stage1.sql (142), BMMS-Test-UserStatus-Stage2a.sql (50), BMMS-Test-UserDelete.sql (75), BMMS-Test-UserKey-Workflows.sql (23), BMMS-Test-FK-Procedures.sql (19), BMMS-Test-Attendance-FutureMeeting.sql (23), BMMS-Test-ResetDatabase.sql (17; test copy ONLY)
6. BMMS-Check-InstalledSteps.sql          (step 24 Installed, 1 of 1 marker; steps 16, 17 and 18 still Installed)

On `BMMS`, after the backup: BMMS-Fix-MeetingDates-Step24.sql, then deploy the build. Do not run the tests on `BMMS`. Until the build is deployed the older page shows "Record Not Saved" for a refused save, after it has already sent the mail.

Manual checks after deploying the build, on the test copy (made-up data only; SMTP pointed at a mail catcher, see step 20):

1. Create a meeting dated in a few days with the Agenda Submission Date yesterday: "The Agenda Submission Date cannot be before today."; no meeting, no mail.
2. Create a meeting with the Agenda Submission Date equal to the Meeting Date: saved, "Meeting Created" mail.
3. Create a meeting today with the Agenda Submission Date today: saved.
4. Create a meeting with the Agenda Submission Date the day after the Meeting Date: "The Agenda Submission Date must be on or before the Meeting Date."; no meeting, no mail.
5. Edit the venue of a future meeting whose Agenda Submission Date has passed (a made-up meeting saved earlier with a near deadline, or dated so on the test copy): saved, "Meeting Updated" mail.
6. Edit that meeting and move the Agenda Submission Date to yesterday: the message, the meeting unchanged, no "Meeting Updated" mail in the catcher.

## Step 26: generated PDFs no longer public (code and Web.config only, no database script)

Notice (Create PDF), Agenda Approval (Create PDF) and Sitting Fees (Individual, Designation, Consolidated) used to write fixed-name files into `~/Files/PDF` (Notice.pdf, AgendaDetails.pdf, SFR_*.pdf) and open them by URL. Files there could be fetched by anyone who knew the URL, without logging in (the page-access check covers .aspx pages only), and two users overwrote each other's file. Agenda Approval also wrote AgendaDetails.pdf behind a link to AgendaApproval.pdf, so its link never worked.

From step 26 these PDFs are built in memory and open in a pop-up through ViewReport.aspx?pdf=1, as Agenda Summary and Agenda Details since step 25; nothing is written to `~/Files/PDF`. Notice Send Mail is unchanged (it never attached a file). If the same user opens two of these pop-ups at once, the last one built is shown in both.

Web.config hides every URL with a path segment PDF, SqlBackup or Log (request filtering, hidden segments; 404): the old generated PDFs, the database backups under `~/Files/SqlBackup` and the error logs under `~/Log` are no longer served. The files themselves stay on disk.

After deploying, on every server (the test copy and BMMS), delete the old generated PDFs by hand: everything in `~/Files/PDF` (Notice.pdf, AgendaDetails.pdf, AgendaSummary.pdf, SFR_Individual.pdf, SFR_Designation.pdf, SFR_Consolidated.pdf, Followup.pdf, whichever exist). Nothing writes there any more. Keep the backups in `~/Files/SqlBackup` and the logs in `~/Log` as they are (now hidden).

Manual checks on the test copy (http://localhost:49573, Chrome or Edge):

1. Notice, Create PDF: the notice opens in the pop-up; Print and Download work; no new file appears in `~/Files/PDF`.
2. Notice, Send Mail (smtp4dev): every member gets the mail as before, with no attachment.
3. Agenda Approval, Create PDF: the PDF opens in the pop-up; no AgendaDetails.pdf appears; Reports, Agenda Details still works.
4. Sitting Fees: Individual, Designation and Consolidated each open in the pop-up.
5. Blocked: /Files/PDF/Notice.pdf, a file under /Files/SqlBackup and today's /Log/<yyyy_MM_dd>_ErrorLog.txt each give 404. Still served: /Files/Branding/report-logo.png and an agenda attachment opened from the Dashboard.
6. Two Controllers in two browsers, Notice for two meetings at the same time: each sees their own PDF.

## Step 28: Notice, Send Mail (code only, no database script)

Reports, Notice, Send Mail did nothing on screen and sent no mail. It read the members from spr_GetCommitteeMemberByCommitteeId (View_Committee_Member), which has no CityName and no State_Name, so the mail body failed on the first member; the click is an UpdatePanel postback, so the error was neither shown nor logged. This existed before the modernization (the recovered baseline has the same code and procedure).

From step 28 Send Mail uses the same members as Create PDF (spr_GetCommitteeMemberByMeetingId, View_Member: address, city and state; the step 16 rule on the meeting date), mails every member with an e-mail address and shows "Notice sent to N of M members." (M = members with an e-mail address), the names of members without one, and how many mails could not be sent (see the error log). A meeting without members shows only the existing alert. Any other error is written to the error log and shown as "The notice could not be sent: ...". No rule about meetings in the past.

Also in step 28: the first error of each day was not written to the error log (fixed). WriteErrorLog (BMMSBAL/Utilities.cs) left the stream of a newly created log file open, so the entry that created the file was lost; it now appends in one step, lets one request write at a time and never throws to the caller. The log file name, folder and format are unchanged.

Manual checks on the test copy (smtp4dev running):

1. Notice, Board Meeting 00001, Send Mail: one mail per member with an address in smtp4dev, the address in the mail includes city and state, and the page shows "Notice sent to N of M members."
2. A meeting where one member has no e-mail address: that member is named on the page.
3. With smtp4dev stopped: the page reports the mails that could not be sent, and the error log has an entry.

## Step 23: meeting workflow order (installed after step 28)

The order of a meeting is 1 Agenda Finalisation, 2 Attendance, 3 Update Minutes, 4 Minutes Finalisation, 5 Minutes Generation (Reports, gated since step 22), 6 Minutes Confirmation. Before this step most of it was checked only by the pages, partly through stand-ins (the chairman for "attendance entered"). The database now refuses a step taken too early:

| Step | Refused when | Reason | Message |
|---|---|---|---|
| Attendance, chairman | the agenda is not finalized | 17 | "The agenda of this meeting is not finalized yet. Finalize the agenda (Agenda, Agenda Finalize) first." |
| Update Minutes (all kinds), short text on the minutes page | the agenda is not finalized | 17 | as above |
| | attendance not entered | 18 | "Attendance has not been entered for this meeting. Enter the attendance and the chairman (Master, Attendance) first." |
| Finalize Minutes | the agenda is not finalized / attendance not entered | 17 / 18 | as above |
| | a minute never updated | 19, "n/m" | "n of the m minutes have not been updated yet. Update every item (Minutes, Update Minutes) before finalizing the minutes." |
| | no minutes at all | 19, "0/0" | "This meeting has no minutes to finalize (no agenda item was approved)." |
| Minutes Confirmation | not finalized (unchanged procedure, Reason 3 'Open') | 3 | "The minutes of this meeting are not finalized yet. Finalize them (Minutes, Finalize Minutes) first." |

Attendance entered = the chairman is set and at least one member is marked present. A minute is updated once it was saved on Update Minutes (Minutes.StatusId 1); Submit saves every row. The existing refusals keep their place and come first (unknown 4, finalized 1, already done 3, confirmed 7; a chairman not on the committee, 9, after 17). Agenda Finalize now also finalizes a meeting without agenda items ("Agenda Finalized (no agenda items)."); its attendance can be entered, its minutes cannot be finalized (19, "0/0"). An agenda item the Controller adds after finalization (step 16 option) brings a new minute that must be updated before Finalize. Update Minutes at F stays allowed (step 16).

The order applies only to meetings created after step 23 was installed: Meeting.CreatedOn on or after the setting WorkflowOrderFrom (App_Setting), written by the first run and kept by later runs; a meeting without CreatedOn counts as older. Older meetings keep the earlier behaviour on every page and in every procedure, so nothing existing is changed or blocked. The pages ask spr_GetMeetingWorkflowState: for a new meeting Attendance is read-only until the agenda is finalized, Update Minutes and Finalize Minutes show the database's messages; for an older meeting they keep their earlier checks.

To see which existing meetings are already out of order (they stay as they are), run these read-only queries:

```sql
-- Attendance or chairman recorded while the agenda is not finalised
SELECT m.MeetingId, m.MeetingNo, m.CommitteeId, ISNULL(m.AgendaStatus,'Open') AS AgendaStatus, ISNULL(m.MinutesStatus,'Open') AS MinutesStatus,
       m.ChairmanNameId, (SELECT COUNT(*) FROM Attendance a WHERE a.MeetingId = m.MeetingId) AS AttendanceRows, m.CreatedOn
FROM Meeting m
WHERE ISNULL(m.AgendaStatus,'Open') = 'Open'
  AND (m.ChairmanNameId IS NOT NULL OR EXISTS (SELECT 1 FROM Attendance a WHERE a.MeetingId = m.MeetingId));

-- Minutes updated or finalised without attendance (no chairman, or nobody present)
SELECT m.MeetingId, m.MeetingNo, m.CommitteeId, ISNULL(m.MinutesStatus,'Open') AS MinutesStatus, m.ChairmanNameId, m.CreatedOn
FROM Meeting m
WHERE (ISNULL(m.MinutesStatus,'Open') IN ('F','C')
       OR EXISTS (SELECT 1 FROM Minutes mi JOIN Agenda ag ON ag.AgendaId = mi.AgendaId WHERE ag.MeetingId = m.MeetingId AND mi.StatusId = 1))
  AND (m.ChairmanNameId IS NULL OR NOT EXISTS (SELECT 1 FROM Attendance a WHERE a.MeetingId = m.MeetingId AND a.Attendance = 'P'));

-- Minutes finalised or confirmed with minutes never updated
SELECT m.MeetingId, m.MeetingNo, m.CommitteeId, m.MinutesStatus,
       SUM(CASE WHEN mi.StatusId = 1 THEN 1 ELSE 0 END) AS Updated, COUNT(*) AS Total
FROM Meeting m JOIN Agenda ag ON ag.MeetingId = m.MeetingId JOIN Minutes mi ON mi.AgendaId = ag.AgendaId
WHERE ISNULL(m.MinutesStatus,'Open') IN ('F','C')
GROUP BY m.MeetingId, m.MeetingNo, m.CommitteeId, m.MinutesStatus
HAVING SUM(CASE WHEN mi.StatusId = 1 THEN 1 ELSE 0 END) < COUNT(*);
```

On the test copy (`BMMS_Test`), after a backup of it and after step 28, in this order:

1. BMMS-Check-InstalledSteps.sql          (steps 1 to 22 and 24 Installed, step 23 Missing)
2. BMMS-Fix-WorkflowOrder-Step23.sql      (stops, changing nothing, if a procedure lacks the text of step 6, 8, 12, 15, 16, 17 or 18; prints the WorkflowOrderFrom time)
3. BMMS-Test-WorkflowOrder-Step23.sql     (53 checks)
4. BMMS-Test-UserKey-Workflows.sql        (23 checks; adjusted "[step 23]")
5. The other tests, unchanged: BMMS-Test-MeetingDates-Step24.sql (36), BMMS-Test-MinutesGating-Step22.sql (36), BMMS-Test-AgendaRouting-Step20.sql (56), BMMS-Test-MemberTypes-Step21.sql (100), BMMS-Test-OrganisationSettings-Step19.sql (52), BMMS-Test-SystemAccount-Stage3.sql (51), BMMS-Test-UserStatus-Stage2b.sql (63), BMMS-Test-MeetingLocks-Step16.sql (100), BMMS-Test-MeetingLocks.sql (43), BMMS-Test-UserProtection-Stage1.sql (142), BMMS-Test-UserStatus-Stage2a.sql (50), BMMS-Test-UserDelete.sql (75), BMMS-Test-FK-Procedures.sql (19), BMMS-Test-Attendance-FutureMeeting.sql (23), BMMS-Test-ResetDatabase.sql (17; test copy ONLY)
6. BMMS-Check-InstalledSteps.sql          (step 23 Installed, 8 of 8 markers; steps 6 to 18 still Installed)

On `BMMS`, after the backup: BMMS-Fix-WorkflowOrder-Step23.sql, then deploy the build. Do not run the tests on `BMMS`.

Manual checks on the test copy, on new made-up meetings created after the install (made-up data only):

1. Master, Attendance on a new meeting whose agenda is not finalized: the page is read-only with the "agenda ... not finalized" message.
2. Agenda, Agenda Finalize, then Attendance with a chairman and one member present: saved.
3. Minutes, Update Minutes on a second new meeting whose agenda is finalized but without attendance: the "Attendance has not been entered" message. On the first meeting: the minutes open; Submit saves them.
4. Minutes, Finalize Minutes on a meeting where one minute was never saved: "1 of the 2 minutes have not been updated yet ..."; after saving it: Minutes Finalized.
5. Reports, Minutes: the meeting is listed; Generate works.
6. Minutes, Minutes Confirmation: confirmed. Confirmation on a meeting whose minutes are not finalized: "The minutes of this meeting are not finalized yet ...".
7. Agenda Finalize on a new meeting without agenda items: "Agenda Finalized (no agenda items)."; Finalize Minutes on it: "This meeting has no minutes to finalize ...".
8. An older meeting (for example BMMS_Test meeting 3 or 343): Attendance, Update Minutes and Finalize Minutes behave as before.
9. With the Controller option on, add an agenda item to a new meeting after its agenda is finalized: Finalize Minutes is refused until that item's minute is updated.

## Step 29: Reset Database made safe (what to run where)

Reset Database (Utilities, Admin only) ran spr_sys_ResetDatabase with no transaction: an error, or the 30-second command timeout, left the database half cleared. The confirm text said sign-in would not work afterwards (it does: admin with the default password). The session stayed open after the reset, still pointing at a user id that no longer existed or now belonged to another seeded user.

From step 29:

- The page shows the name of the connected database and asks the Admin to type it (capital letters do not matter). The browser compares first (trimmed, ignoring case): a wrong name shows "The name you typed is not the name of this database. Nothing was changed.", the dialog does not open and nothing is sent to the server. A correct name opens the confirm dialog with the correct text. After OK the page compares again on the server, and the procedure a third time.
- The procedure first checks, changing nothing: the acting user exists and is active (Reason 8), is an Admin (4), and the typed name is the current database (3, ReasonDetail DatabaseName). Any active Admin may reset, as before.
- Then everything runs in one transaction with XACT_ABORT ON: an error or a timeout rolls back every row. Identity counters are not covered by a rollback, so the procedure saves them first and puts them back after a rollback. All clearing comes first and every reseed only after it, just before COMMIT. The five tables TRUNCATE used to clear are cleared with DELETE; a used counter of theirs starts again at its seed, as with TRUNCATE. RESEED 0 elsewhere is unchanged.
- Audit_Trail_SendMail is cleared too (DELETE, RESEED 0): its Mail_Send_By ids would otherwise point at the re-seeded users, and the user delete rule would treat them as history.
- One Audit_Trail_Master row is written inside the transaction, after the seeds: Audit_Table "Database", Key_Value the database name, Field_Name "Reset", New_Value "Reset by <login>", Update_By 1 (the acting user no longer exists). It is the only row in that table after a reset.
- The re-created rows are those of step 21, except the password hashes: the four seeded users get the hashes of the new default password. Organisation settings and the other settings are not touched. The mail settings (SMTP_Master) were kept as well in step 29; since step 30 the reset replaces them by a safe default (localhost, port 25, no login, noreply@example.invalid): see the step 30 section.
- The default password is new and kept in one place, `Common.DefaultPassword` (BMMSBAL/Common.cs). Reset Password gives it, Reset Database seeds its hashes, and signing in with it opens the change-password page (ChangePasswordFirst). The old default is not accepted as a default anywhere: there is no transition period. The seed hashes in steps 3, 18 and 21 were replaced too, so a re-run of any of them can no longer bring back the old default. Nobody needs to re-run step 18 or 21 because of this: step 29 owns the reset procedure and is the only script to run again. The re-run rules above are unchanged (step 21 after a re-run of 2, 3, 15 or 18; step 29 last). The procedure text carries a third marker, DefaultPassword-Step29.
- A user whose password is still the old default can still sign in with it (the stored hash is checked, not the text), but is no longer sent to the change-password page. These users are reset by hand: an Admin uses Reset Password for each one (the user gets the new default and must change it at the next sign-in); the system account `admin` cannot be reset by another Admin (step 18) and changes its own password with Change Password. Users still holding one of the four old seeds can be found with this read-only query:

```sql
-- Read only: users whose stored password is still one of the four old seed hashes
SELECT UserId, LoginName, AccountStatus
FROM dbo.Users
WHERE CAST([Password] AS VARCHAR(200)) COLLATE Latin1_General_BIN2 IN (
    '100000.WADOkeW3PD8T+KGnhd13NA==.ykPBZLhjry5KbA3hGEQsf8hdO3yY8C23RTHKeAOfXWU=',
    '100000.M/UxC7LnMnNnEZFfpnw6mg==.BjFpjTZvVXXXGN0NOfAyBgtqgpaTbE4rH41LJyBONSc=',
    '100000.PsM4vZJAAQ9wtc5TyVtBcg==.g2/yOexqH1W/RQ33t0LmQ0eZYFQl6gPN7buM+M1bbqY=',
    '100000.VqhtwYgekpXELBK53d/DLg==.haI/Qxp3EbSWTlfeUjLiqWbR30WATDUW5pazcR8k7tA=')
ORDER BY UserId;
```

  A password you changed yourself (or one set through Reset Password) has its own random salt and cannot be found this way, even if it is the old default: reset each user by hand, or ask them to change their password.
- The page calls the procedure with a 300-second command timeout (its own DAL method). On success it ends the session and opens the sign-in page. A refusal is shown on the page. An error is written to the error log (`~/Log`) and shown as "The reset did not run; nothing was changed. The error is in the error log."
- The page waits as long as the procedure may run: on this page only, the browser waits 330 seconds for the answer (ScriptManager AsyncPostBackTimeout; the default is 90) and the server lets the request run 330 seconds (Server.ScriptTimeout; the default is 110). Before this, a reset that took longer than 90 seconds finished in the database while the page showed nothing and stayed signed in. While the reset runs, a "Reset in progress, please wait" message covers the page (bmms-workbench.css, wb-progress-overlay). If the request still fails or gets no answer, the page says "The page got no answer from the server. The reset may have finished: sign in again as admin to check." After a successful reset the page is not drawn again; the browser goes straight to the sign-in page.
- The page lists how many files each upload folder holds (Files/AgendaAttach, AgendaText, MemberPhoto, MemberResume, SqlBackup): a reset does not remove them, and after a reset agenda numbers and member codes start again, so a new upload with the same number or code and file name replaces an old file. Deleting them is a later step.
- BMMS-Fix-ResetDatabase-Seeds.sql (step 3) no longer has a `USE` line (it has the usual name check instead), and its header and seed e-mail addresses no longer carry the old organisation's name. Re-running it still installs the older procedure: run steps 18, 21 and 29 again afterwards.

Permissions are unchanged: DELETE needs the delete permission and DBCC CHECKIDENT needs ALTER on the tables (or db_owner) for the application login. Without them the reset stops at the first reseed, rolls back and logs the error; nothing is changed.

On the test copy (`BMMS_Test`): install the procedure and run the rolled-back tests only. Do NOT restore over `BMMS_Test` and do NOT run a real Reset there.

1. BMMS-Check-InstalledSteps.sql          (steps 1 to 24 as before; step 29 Missing, 0 of 3 markers; on a database that has the first text of step 29: Partly, 2 of 3, DefaultPassword-Step29 missing)
2. BMMS-Fix-ResetDatabase-Step29.sql      (stops, changing nothing, if step 18 or 21 is missing; prints "Reset Database (step 29) installed: ... (ResetSafe-Step29, DefaultPassword-Step29)")
3. BMMS-Test-ResetDatabase.sql            (32 checks; test copy ONLY)
4. The four tests that read the procedure's text, unchanged: BMMS-Test-SystemAccount-Stage3.sql (51), BMMS-Test-MemberTypes-Step21.sql (100), BMMS-Test-OrganisationSettings-Step19.sql (52), BMMS-Test-AgendaRouting-Step20.sql (56)
5. BMMS-Check-InstalledSteps.sql          (step 29 Installed, 3 of 3 markers; steps 3, 18 and 21 still Installed)

The real Reset through the page is tried on a separate database, `BMMS_Quality`, never on `BMMS_Test` or `BMMS`:

1. SSMS: Restore Database from the baseline backup (the recovered legacy database, before any numbered step) as a new database named `BMMS_Quality`; change the database name and the two file names. Never restore over an existing database. If the application login cannot open it, map its user in `BMMS_Quality`: `ALTER USER bmms_app WITH LOGIN = bmms_app;`
2. In `BMMS_Quality`, run the numbered scripts in README order, each as its section says. Scripts 1, 2 and 4 to 9: change the first line to `USE [BMMS_Quality]` in the SSMS window and do not save the change. Script 3 and scripts 10 onwards: select `BMMS_Quality` in the toolbar. The order: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 20, 22, 24, then 23 (installed after step 28; steps 25, 26 and 28 have no script, step 27 is not built yet), then 29 last (since step 30: then 30 and spr_sys_SetSmtpDefault, see the step 30 section). Step 21 comes before step 20 (step 20 needs it). Step 9 refuses on the baseline because the old seeds stored "no manager" as 0: run `UPDATE dbo.Users SET ManagerId = NULL WHERE ManagerId = 0;` in `BMMS_Quality`, then run step 9 again. Step 11 refuses a key whose column holds an unknown user: run BMMS-Check-Orphans.sql if it reports a refusal.
3. BMMS-Check-InstalledSteps.sql on `BMMS_Quality`: steps 1 to 24 and 29 Installed (step 29: 3 of 3 markers). A `BMMS_Quality` that already has the first text of step 29 shows step 29 Partly, 2 of 3: run BMMS-Fix-ResetDatabase-Step29.sql there again, then the checker (Installed, 3 of 3).
4. Point the application at it: in `BMMS/connectionStrings.config` (not tracked by git) change `database=BMMS` to `database=BMMS_Quality`; restart the site.
5. Sign in as a user who is not an Admin and open /Master/ResetDatabase.aspx: "Access denied." (unchanged).
6. Sign in as an Admin and open Utilities, Reset Database: the page shows `BMMS_Quality`, the three cards and the file counts per folder.
7. Type `BMMS_Test` and press Reset Database: "The name you typed is not the name of this database. Nothing was changed." appears at once; no dialog opens and the page is not sent (the browser's network tab shows no request). The same with an empty box. The data is still there.
8. Type `bmms_quality`, press Reset Database and Cancel in the dialog: nothing happens.
9. Type `bmms_quality`, press Reset Database and OK: the "Reset in progress, please wait" message covers the page, then the sign-in page opens. Your old password no longer works.
10. Sign in as `admin` (small letters; the login name is case sensitive) with the default password, typed (the password box does not accept paste): the change-password page opens at once; choose a new password.
11. Check: the dashboard is empty; the Master lists show the default departments, designations, member types and the two committees; System Settings shows the organisation settings and logo unchanged; the four default users exist.
12. In SSMS on `BMMS_Quality`: `SELECT * FROM Audit_Trail_Master;` gives one row "Reset by <your login>", by user 1; `SELECT COUNT(*) FROM Audit_Trail_SendMail;` gives 0. Today's error log (`~/Log/<yyyy_MM_dd>_ErrorLog.txt`) has no new ResetDatabase entry.
13. If step 9 shows "The reset did not run; nothing was changed." instead: the error log names the cause (for example the permission for DBCC CHECKIDENT), and the data must be unchanged.
14. A slow reset (longer than the old 90-second limit). Sign in as `admin` with the new password. Open a second SSMS query window on `BMMS_Quality` (window B) and run only:
    `BEGIN TRANSACTION; SELECT COUNT(*) FROM dbo.Department WITH (TABLOCKX, HOLDLOCK);`
    This holds a lock on Department until window B ends the transaction; the reset waits for it inside its own transaction. Leave window B open. In the browser, open Reset Database, type `bmms_quality`, press Reset Database and OK: the "Reset in progress, please wait" message stays. Optional, in a third window: `SELECT session_id, blocking_session_id, wait_time / 1000 AS wait_seconds FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;` shows the reset waiting for window B. After about 120 seconds, release the lock in window B: `ROLLBACK TRANSACTION;` then `SELECT @@TRANCOUNT;` gives 0. Within a few seconds the sign-in page opens; sign in as `admin` with the default password (the change-password page opens). `SELECT * FROM Audit_Trail_Master;` gives one row "Reset by admin". If window B is closed or disconnected instead, SQL Server rolls its transaction back and the lock is released as well.
15. Optional, a reset past the 300-second limit: as step 14, but release the lock only after about 320 seconds. At 300 seconds the page shows "The reset did not run; nothing was changed. The error is in the error log."; you are still signed in, the data is unchanged (Audit_Trail_Master still has the row of step 14), and the error log has a btnResetDatabase_Click timeout entry (the log keeps every error; step 28 only fixed the day's first entry, which used to be lost). Then run `ROLLBACK TRANSACTION;` in window B.
16. Switch back: in `BMMS/connectionStrings.config` change `database=BMMS_Quality` back to `database=BMMS`; restart the site. `BMMS_Quality` can be dropped or kept for the next step.

On `BMMS`, after the backup: BMMS-Fix-ResetDatabase-Step29.sql, then deploy the build. Do not run the tests on `BMMS`, and do not reset it. Until the build is deployed, the older page's Reset fails with "expects parameter" and nothing is cleared.

## Step 30: safe SMTP default (what to run where)

The mail settings are the one row of table SMTP_Master (SMTPServer, SMTPServerPort, UserName, Password, FromMailId, Bcc; no key), read by spr_GetSMTPMaster and saved by spr_UpdateSMTPMaster from Admin, SMTP Configuration. Until step 30 no script owned the table: Reset Database kept the row, so a reset or newly restored database went on mailing through whatever server the old row named.

Decision (Consultant, 2026-10-22): a new or reset database gets a safe default that cannot send real mail: server `localhost`, port `25`, no user name, no password, From Mail Id `noreply@example.invalid`, no Bcc.

From step 30:

- Reset Database replaces every SMTP_Master row by the one default row, inside its transaction, before the default rows (a failure rolls it back with everything else). The page text and the confirm dialog say so ("Replaced: the mail settings ..."). Organisation and other settings are still kept.
- New procedure spr_sys_SetSmtpDefault writes the same row on its own: `EXEC dbo.spr_sys_SetSmtpDefault @ConfirmDatabaseName = N'<the database name>';` returns Result 1 (Result 0, Reason 3, DatabaseName for another name; nothing changed). Run it by hand on a new database and on the test copies, never on `BMMS`. Installing step 30 changes no data.
- spr_UpdateSMTPMaster inserts the row when the table is empty (before, Update saved nothing and still said "Successfully updated."). Parameter sizes unchanged.
- SMTP Configuration: User Name and Password are no longer required. Both empty means a server without login (the mail is sent without credentials, as Mail_Mgr already did for an empty user name); both filled means a login; one without the other is refused, in the browser and on the server ("User Name and Password go together ..."). An empty password is saved as empty (before, an empty password would have been stored encrypted, readable on this machine only). From Mail Id stays required, with the e-mail check in the browser and a MailAddress check on the server. An empty password shows as an empty box instead of stars. The page explains the default. If the table has no row, the page shows empty fields instead of an error page.
- The shared e-mail check (Validation.js emailValidation; used by SMTP Configuration, Member Master and User Master) accepts 2 or more letters after the last dot: `.invalid`, `.company` and `.photography` were refused before, so the default From address and the seeded user addresses could not be saved. Spaces, a second @, no dot or no domain are still refused, and so is a last part of digits (the old check accepted `name@example.123`). The old check could also hang the browser for seconds on a long wrong address; the new one cannot.
- With nothing listening on port 25 of the web server, every mail fails (written to the error log) and a new agenda item is NOT saved, because its "agenda created" mail fails. That is accepted: enter real settings on SMTP Configuration, or run a mail catcher (smtp4dev) for testing.

Step 30 needs steps 18 and 21 (as step 29) and stops otherwise; it also stops if SMTP_Master or one of its six columns is missing, if another column needs a value, or if SMTPServer or FromMailId is too short for the default. It prints the SMTP_Master columns and today's row count (read only). Re-run rules: see "If step 3, 18, 21 or 29 is ever re-run" under Run order.

On the test copy (`BMMS_Test`):

1. BMMS-Check-InstalledSteps.sql          (step 29 Installed, 3 of 3; step 30 Missing, 0 of 3)
2. BMMS-Fix-SmtpDefault-Step30.sql        (prints the columns, the rows today and "Safe SMTP default (step 30) installed: ... No data was changed.")
3. BMMS-Test-ResetDatabase.sql            (40 checks; test copy ONLY)
4. The four tests that read the reset procedure's text, unchanged: BMMS-Test-SystemAccount-Stage3.sql (51), BMMS-Test-MemberTypes-Step21.sql (100), BMMS-Test-OrganisationSettings-Step19.sql (52), BMMS-Test-AgendaRouting-Step20.sql (56)
5. `EXEC dbo.spr_sys_SetSmtpDefault @ConfirmDatabaseName = N'BMMS_Test';` (Result 1, Reason 0)
6. BMMS-Check-InstalledSteps.sql          (step 30 Installed, 3 of 3; steps 3, 18, 21 and 29 still Installed)

The test (3) runs before the default (5), so its forced-failure check compares against settings that differ from the default.

On `BMMS_Quality`: the same six, with `N'BMMS_Quality'` in 5. Then deploy the build and run the browser checks below.

On `BMMS`, after the backup: BMMS-Check-InstalledSteps.sql, BMMS-Fix-SmtpDefault-Step30.sql, BMMS-Check-InstalledSteps.sql (step 30 Installed, 3 of 3), then deploy the build. No tests, no spr_sys_SetSmtpDefault, no reset: `BMMS` keeps its mail settings.

The build (SMTPServerConfig.aspx and .cs, ResetDatabase.aspx and .cs, JScript/Validation.js) works with or without the SQL; deploy it after the SQL. After deploying, reload the pages with Ctrl+F5 so the browser does not keep the old Validation.js.

Browser checks on `BMMS_Quality` (smtp4dev listening on port 25 of the web server; made-up addresses only):

1. Admin, SMTP Configuration: localhost, 25, empty User Name, empty Password box (no stars), noreply@example.invalid, empty Bcc; no * after User Name and Password. Edit, change nothing, Update: "Successfully updated." In SSMS: `SELECT COUNT(*) FROM dbo.SMTP_Master;` gives 1 and `SELECT CASE WHEN [Password] = '' THEN 'empty' ELSE 'set' END FROM dbo.SMTP_Master;` gives empty.
2. Refusals (Edit, then Update), each leaving the row unchanged: User Name `sampleuser` with no password, and a password with no User Name: "User Name and Password go together ..."; From Mail Id empty: "From Mail Id is required field"; `abc` and `name@example`: "Invalid E-Mail Id". `office@acme.company` is accepted (set noreply@example.invalid back afterwards). User Master: open the seeded user Controller (con@example.invalid) and press Save without changes: the page no longer stops at "Invalid E-Mail Id" (as it did before step 30); a later check of the page may still ask for something else, and nothing needs to be saved.
3. The server check: Edit, then in the browser's developer console run `SMTPServerConfigValidation = function () { return true; };`, enter User Name `sampleuser` with no password and press Update: the page shows "User Name and Password go together ..." from the server and nothing is saved. Reload the page.
4. Report, Send Mail to `test1@example.invalid`: the mail arrives in smtp4dev from noreply@example.invalid; the smtp4dev session log shows no AUTH command; `SELECT COUNT(*) FROM dbo.Audit_Trail_SendMail;` went up by 1.
5. SMTP Configuration: save sample settings (smtp.sample.invalid, 2525, sampleuser with a password, sample@example.invalid, Bcc copy@example.invalid). Utilities, Reset Database: the page says "Replaced: the mail settings ..."; type `bmms_quality`, press Reset Database: the dialog names the safe default; OK. Sign in as `admin` with the default password and choose a new one. SMTP Configuration shows the default again; in SSMS SMTP_Master has 1 row: localhost, 25, empty, empty, noreply@example.invalid, empty.
6. After the reset, with smtp4dev running: Reset Password for `secuser`: the mail to con@example.invalid arrives in smtp4dev. Stop smtp4dev and Send Mail again: the page reports the error, nothing leaves the machine, and the error log has the entry (the log keeps every error). Start smtp4dev again.

Switch the connection string back to `BMMS` afterwards (as in step 29).

## Step E1: errors in UpdatePanel postbacks (code only, no database script)

An unhandled error during an UpdatePanel (partial) postback was neither shown nor written to the error log: the progress indicator stopped, nothing changed on the page, and the exception text went to the browser console only.

From step E1:

- The ScriptManager of Main.Master, MainNoMenu.Master and the login page (Default.aspx) handles OnAsyncPostBackError: Utilities.LogAsyncPostBackError writes one entry to the error log (class: the page's code-behind, method: "AsyncPostBack <control that posted>", the exception with its stack, the page path without query string, the user id). Form values, passwords and the mail password are never written. The browser gets only the fixed text "The action could not be completed. The error is in the error log." (AsyncPostBackErrorMessage), never the exception text.
- JScript/AsyncPostBackError.js shows a message bar at the top of the page content (div#wbAsyncError, style wb-async-error), never alert or confirm: "This action could not be completed because of an error on the server. The error is in the error log. Reload the page and check what was saved before you try again." When the browser gives up waiting: "The server did not answer in time. Reload the page and check what was saved before you try again." The next request hides the bar. The script registers its handlers once per page (Sys.Application load fires again after every partial postback), so a second postback never adds a second handler or a second message.
- Errors the pages already handle are unchanged: the 162 catch blocks that log and open the error page (GoToErrPage), the pages' own messages, mail failures (caught in Mail_Mgr), and Reset Database (its own server message, and its own client message when the page gets no answer; its handler runs first and marks the error handled, so the bar does not appear there). No catch block logs and then rethrows, so nothing is logged twice.
- Only pages with an UpdatePanel are covered; the pages that post back in full and errors before the page starts are step E2 (see Known items).
- The error log (BMMS\Log\yyyy_MM_dd_ErrorLog.txt) keeps every error; step 28 only fixed the day's first entry, which used to be lost.

Browser checks on `BMMS_Test` after deploying the build (no test code in the product):

1. Database timeout. In SSMS on `BMMS_Test`: `BEGIN TRANSACTION; SELECT COUNT(*) FROM dbo.Alert_User_Map WITH (TABLOCKX, HOLDLOCK);` (if `SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = 'BMMS_Test';` gives 1, reads are not blocked: tell the Consultant). In the browser, Dashboard, click Read: after the 30-second command timeout the bar shows the server-error text; no alert; the console shows only "Partial postback failed: Sys.WebForms.PageRequestManagerServerErrorException". Today's error log has one new entry for the Dashboard class, "AsyncPostBack" and the Read link, with the SqlException (Execution Timeout Expired), the page path and the user id. Then `ROLLBACK TRANSACTION;`.
2. In the developer tools (Network), the response of check 1 contains only "The action could not be completed. The error is in the error log.": no stack, no SQL text.
3. Second postback. Click Unread (works now): the bar disappears. Hold the lock again and click Read again: one bar, one message (not two), and exactly one more log entry. Then `ROLLBACK TRANSACTION;`.
4. Request validation. Committee, type `<x` in the name and Save: the bar shows. Note whether the error log has an entry (expected: none, because the error comes before the page starts; that is step E2).
5. Reset Database on `BMMS_Quality`: the wrong-name message, the slow-reset "no answer" message (step 29 check 14) and a normal reset behave as before; the bar never appears there.
6. Mail and handled errors: with smtp4dev stopped, Notice Send Mail still reports the mails that could not be sent; a save that fails in a guarded handler still opens the error page.
7. Login page: a normal sign-in and a wrong password show no bar.

## Known items for later steps

- Mail has no TLS or STARTTLS: Mail_Mgr never sets EnableSsl, so a mail provider that requires an encrypted connection (usually port 587) refuses every mail (step 30).
- The Bcc of SMTP Configuration is ignored when the caller passes no Bcc of its own (Reset Password, Notice, Send Mail): Mail_Mgr.SendWebEmail replaces it by null (step 30).
- From Mail Id and Bcc are cut at 50 characters without an error: the parameters of spr_UpdateSMTPMaster are VARCHAR(50) (step 30 kept the sizes).
- The SMTP password is encrypted with Windows DPAPI for the machine (Common.ProtectSecret): after the database moves to another server it cannot be read there and every mail with a login fails until the password is entered again on SMTP Configuration. The safe default has no password, so it works anywhere (step 30).

- Files left by a Reset Database: the upload folders (Files/AgendaAttach, AgendaText, MemberPhoto, MemberResume) and the backups in Files/SqlBackup are not removed; the page shows their counts (step 29). Deleting them is a later step.
- Step 27: a login-checked download page for agenda attachments and agenda text, member photos and CVs, and Send Mail attachments (move `~/Files/Temp` to App_Data); then add Temp to the hidden segments in Web.config. Until then these files can be fetched by URL without logging in.
- Send Mail deletes every file in `~/Files/Temp` when anyone attaches a new file, so two Controllers composing at once lose each other's attachment (SendMail.aspx.cs).
- Agenda Approval, an agenda whose text was uploaded as a file: it is read with WordUtilities.ReadWordDocument on a relative path through Word, while uploaded agenda texts are PDF files, so that text is probably missing from the PDF (AgendaApproval.aspx.cs).
- Database backups should later be written outside the web root (Backup Database writes to `~/Files/SqlBackup`, now hidden but still inside the site folder).
- Step E2: unhandled errors on the pages that post back in full (no UpdatePanel: Agenda, Attendance, ChangePassword, ChangePasswordFirst, the Master lists without an UpdatePanel, SMTP Configuration, System Settings, Send Mail and others) and errors raised before the page starts (request validation) are still neither logged nor shown in a friendly way: add Application_Error in Global.asax (log, then the error page). The error page shows the exception message (Session ErrMsg set by GoToErrPage); E2 should show a fixed text instead.
- Notice Send Mail: no rule yet about meetings in the past.
- Sitting Fees can still crash on a missing GetTotAmtByMemberId row, a deleted member, an empty From/To date, and a damaged logo file.
- A damaged logo file makes the Notice, Agenda Approval and Sitting Fees PDFs throw (PDFUtilities.AddCompanyLogo).
- Notice page shows no confirmation (fixed in step 28).
