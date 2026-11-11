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

Steps 25, 26 and 28 have no database script (code only); step 27 is not built yet (see Known items for later steps). Steps 29, 30 and 31 are installed last, after step 23, in that order:

29. BMMS-Fix-ResetDatabase-Step29.sql       (Reset Database made safe: only an active Admin who types the name of the current database (Reasons 8, 4, 3), checked before anything is cleared; one transaction with XACT_ABORT ON, so an error or a timeout changes nothing, and the procedure puts the identity counters back after a rollback; the five TRUNCATEs become DELETE with the same next ids; Audit_Trail_SendMail is cleared too; one Audit_Trail_Master row "Reset by <login>" survives the reset; the four seeded users get the hashes of the new default password (Common.DefaultPassword); otherwise the re-created data is unchanged; needs steps 18 and 21; replaces spr_sys_ResetDatabase of step 21 (earlier 3 and 18) and keeps their texts; SQL BEFORE deploying the build: see its section)
30. BMMS-Fix-SmtpDefault-Step30.sql         (safe SMTP default: Reset Database replaces the mail settings (SMTP_Master) by one row that cannot send real mail: localhost, port 25, no login, From noreply@example.invalid, no Bcc; new spr_sys_SetSmtpDefault writes the same row on a new database (run by hand, never on BMMS); spr_UpdateSMTPMaster inserts the row when the table is empty; installing changes no data; needs steps 18 and 21; replaces spr_sys_ResetDatabase of step 29 (earlier 3, 18 and 21) and keeps their texts, and the legacy spr_UpdateSMTPMaster; SQL before deploying the build: see its section)
31. BMMS-Fix-UnicodeText-Step31.sql        (Unicode agenda and minutes text: the 13 text columns of Agenda (ShortText, AgendaText, AgendaTextPath, ProposedResolution, FilePath, MgrComments, ControllerComments), Minutes (Directions, ActualResolution), Action_Item (Directions, ActionText) and Audit_Trail_Master (Old_Value, New_Value) become NVARCHAR(MAX), so the rupee sign and Tamil and Hindi letters are kept; existing values unchanged, proved inside the script by a hash of every value before and after (any difference rolls back); the views on these tables refreshed; the 31 text parameters of seven procedures NVARCHAR(MAX), names and order unchanged; a Proposed Resolution change is audited as 'ProposedResolution' (was 'ShortText'); needs steps 18, 20 and 23; replaces spr_AddEditAgenda and spr_UpdateAgendaByAgendaId of step 20, spr_AddEditAgendaByManager and spr_AddEditAgendaByController of step 18, spr_UpdateAgendaShortText and spr_UpdateMinutes of step 23 and the original spr_UpdateActionItem, keeping their texts; SQL BEFORE deploying the build of step U1b: see its section)

Step D1 has a database script and is installed after step 31 (it is lettered, not numbered, like the code steps around it):

D1. BMMS-Fix-MeetingDelete-D1.sql         (meeting delete: refused after the meeting date (Reason 20, database server date, a meeting with no date is open) and while the meeting has members, agenda items or attendance (Reason 21, ReasonDetail names them; members and agenda items as the baseline, attendance new); when allowed, the meeting's own alerts (SourceType 'Meeting': MC and MU) and their Alert_User_Map rows are removed with the meeting in one transaction; Result kept, Reason and ReasonDetail added; replaces the baseline spr_DeleteMeetingByMeetingId (in no numbered script); changes no data, reports the orphan Meeting alerts left by earlier deletes and does not remove them; SQL before deploying the build of step D1: see its section)

Step 33 is installed after step D1 (step 32 is reserved for RolePermissions-Step32 and not built yet):

33. BMMS-Fix-ManagerDepartment-Step33.sql   (Agenda Entry list, step C2: a Manager sees the items of their department (Agenda.DepartmentId) and the items they entered, a User only the items they entered; both list procedures add EnteredByName (" (inactive)" for an inactive creator); replaces the baseline spr_GetAgendaByMeetingIdDeptId and spr_GetAgendaByMeetingId (in no numbered script); changes no data; BMMS-Rollback-ManagerDepartment-Step33.sql restores both baseline texts; run BEFORE deploying the build of step C2: see its section)

Step 34 is installed after step 33:

34. BMMS-Fix-LoginName-Step34.sql          (access log, step UN2 (names): adds Audit_Trial_Login.Login_Name, VARCHAR(50) NULL; spr_RecordLoginByUserId of step 1 also writes the login ID (Users.LoginName, read by @UserId) into the new row of a successful login, parameters unchanged; the existing rows stay NULL; BMMS-Rollback-LoginName-Step34.sql restores the step 1 procedure and keeps the column; either order with the build of step UN2 (names): see its section)

Step 35 is installed after step 34:

35. BMMS-Fix-CommentAuthor-Step35.sql      (agenda comments, step UN4: spr_UpdateAgendaByAgendaId (Approve / Reject), spr_AddEditAgendaByManager and spr_AddEditAgendaByController (Agenda Entry) write MgrApprovedBy / MgrApprovedDate and ControllerApprovedBy / ControllerApprovedDate: who last saved the comment or recorded the decision, and when; on an Agenda Entry edit only when that role's comment text changes; parameters unchanged; the existing rows stay NULL; BMMS-Rollback-CommentAuthor-Step35.sql restores the step 31 text and keeps the values written; re-run step 35 after re-running step 16, 17, 18, 20 or 31)

Step 36 is installed after step 35 (the steps are installed in order; the step 36 script stops when step 35 is not installed):

36. BMMS-Fix-AlertRefresh-Step36.sql       (agenda alerts, step AL1: spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController (Agenda Entry, Update): when the Update changes a saved field, the item's alert is unread again (ReadStatus 0) and shown again (StatusId 1) for every recipient except the acting user; an Update without a change leaves it; no alert row is added, Alert_Master and the e-mails unchanged; parameters unchanged; BMMS-Rollback-AlertRefresh-Step36.sql restores the texts of steps 31 and 35 and keeps the alerts already refreshed; re-running step 31 or 35 (or 16, 17, 18, 20) after step 36 removes step 36: run step 36 again)
37. BMMS-Fix-UpdateMail-Step37.sql         (mail on Update, step ML1: spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController get the optional OUTPUT parameter @ChangedFields, the fields an Update changed by the comparison of step 36, empty when nothing changed; new spr_GetAgendaUpdateMailId, the addresses of the users the refreshed alert is shown to; new App_Setting row MailSenderUserId (the Controller login account); result rows and the other parameters unchanged; needs step 36; BMMS-Rollback-UpdateMail-Step37.sql restores the step 36 texts and removes the procedure and the row; re-running step 16, 17, 18, 20, 31, 35 or 36 after step 37 removes step 37: run step 37 again)
38. BMMS-Fix-MinutesDueDate-Step38.sql     (optional due date on a Followup decision, step UN6a: spr_UpdateMinutes gets the optional last parameter @DueDate (default 9999-12-31 = not passed, step UN6a1); Code 'All' stores it without its time for a Followup (NULL clears it, not passed keeps it) and NULL for any other decision, refuses a date before the meeting date (Reason 22) and audits a change of the due date (Audit_Trail_Master, Minutes, DueDate); the locks are unchanged (refused once the minutes are confirmed); needs step 31; BMMS-Rollback-MinutesDueDate-Step38.sql restores the step 31 text and keeps the dates; re-running step 6, 16, 17, 18, 23 or 31 after step 38 removes step 38: run step 38 again)
39. BMMS-Fix-UserHistory-Step39.sql      (role and department history, step UD1a: new tables User_Role and User_Department with EffectiveFrom / EffectiveTo, one open row per user and value; only a Manager has several departments, the home department (Users.DepartmentId) among them and primary; Add, Edit, Deactivate, Activate, Delete and Reset Database write the history; a role change away from Manager is refused while he is the last active Manager of a department with items waiting at AC or items are routed to him (Reason 24); a mapped department cannot be deleted (Reason 25); new setting DeptNoManagerAction (refuse / controller), stored only; migrates every user with rows dated the install date; needs steps 13, 14, 18 and 30; replaces spr_AddEditUser, spr_SetUserStatusByUserId and spr_DeleteUserByUserId of step 13, spr_DeleteDepartmentByDeptId of step 2 and spr_sys_ResetDatabase of step 30, keeping their texts; BMMS-Rollback-UserHistory-Step39.sql keeps the tables and the setting; re-running step 2, 3, 6, 10, 13, 18, 21, 29 or 30 after step 39 removes it: run step 39 again, then step 40, which is the last step)
40. BMMS-Fix-RoleAccess-Step40.sql         (role access, step RA1a: user accounts and member types are Admin tasks; fn_UserChangeRefusal gives the Controller the rule of every role other than Admin (only its own Edit and ResetPassword; everything else on another account Reason 4), so spr_AddEditUser, spr_CheckUserChange, spr_DeleteUserByUserId, spr_GetUserListForUserPage, spr_ResetPasswordByUserId and spr_SetUserStatusByUserId refuse the Controller; spr_AddEditMemberType and spr_DeleteMemberTypeByMemberTypeId refuse a Controller (Reason 4) and re-raise an error with RAISERROR instead of THROW; parameters unchanged; replaces fn_UserChangeRefusal of step 18 and the two procedures of step 21, keeping the markers of steps 13, 14, 18 and 21; changes no data; installed after step 39 (the script stops otherwise); BMMS-Rollback-RoleAccess-Step40.sql restores the texts of steps 18 and 21; re-running step 13, 14, 18 or 21 after step 40 removes it: run step 40 again; either order with the build of step RA1a: see its section)
41. BMMS-Fix-ReportAccess-Step41.sql       (report access, step RA1b: three new read-only procedures with @ActingUserId and OUTPUT @Result / @Reason (8 acting user missing or inactive, 4 another role; then no rows): spr_GetMinutesReportMeetingsAllStatus and spr_GetMinutesReportAllStatus for the Controller and Management (every minutes status; only meetings with at least one minutes row; MinutesStatusMark Draft (not finalised) / Finalised / Confirmed), spr_GetFollowupReportForManagement for Management (the filters of the Controller's Followup query, with the mark); replaces nothing (spr_GetMinutesReport and spr_GetMinutesReportMeetings of step 22 unchanged); changes no data; installed after step 22 and step 40 (the script stops otherwise); SQL BEFORE deploying the build of step RA1b (that build calls the procedures); BMMS-Rollback-ReportAccess-Step41.sql drops the three procedures: see its section)

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
If step 6, 15, 16, 17, 18, 20 or 23 is ever re-run, run step 31 again afterwards, as the last step (after the chains above). Checked by searching every numbered script for the procedures step 31 replaces: spr_AddEditAgenda and spr_UpdateAgendaByAgendaId are in steps 16, 17, 18 and 20; spr_AddEditAgendaByManager and spr_AddEditAgendaByController in steps 16, 17 and 18; spr_UpdateAgendaShortText in steps 16 and 23; spr_UpdateMinutes in steps 6, 16, 17, 18 and 23; spr_UpdateActionItem is in no numbered script (only a restore of the original database brings its old text back, which also needs step 31 again). Step 15 contains none of them, but its chain goes through steps 16 to 18 and so ends in step 31 too. The columns stay NVARCHAR after such a re-run, but an older procedure turns new text into ? while it is saved: BMMS-Check-InstalledSteps.sql shows step 31 Partly until step 31 is run again. Step 31 refuses to run once step 32 (role permissions, marker RolePermissions-Step32) has replaced one of its procedures; step 32 will contain the step 31 texts, so run step 32 again instead. Re-running step 31 is safe: columns that are already NVARCHAR are left alone, and the procedures are replaced with the same text.
If step 2, 3, 6, 10, 13, 18, 21, 29 or 30 is ever re-run, run step 39 again afterwards, as the last step (after the chains above). Checked by searching every numbered script for the objects step 39 replaces: spr_DeleteUserByUserId is in steps 2, 6, 10 and 13; spr_AddEditUser and spr_SetUserStatusByUserId in step 13; spr_DeleteDepartmentByDeptId in step 2; spr_sys_ResetDatabase in steps 3, 18, 21, 29 and 30. fn_ManagerReleaseRefusal, spr_GetUserDepartmentMap, spr_SetDepartmentManagerRule and the two tables are new. Steps 14, 16, 17, 20, 31, 33 and 35 to 38 contain none of them. Re-running step 39 is safe: it keeps the tables, the rows and the setting value, and re-syncs the rows with Users.
Step D1 replaces spr_DeleteMeetingByMeetingId, which no numbered script contains, so no re-run of a numbered step needs step D1 again; only a restore of a database from before step D1 does. Re-running step D1 is safe (it changes no data and only reports the orphan alerts).
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
- BMMS-Check-InstalledSteps.sql           (read-only: which of steps 1 to 24, 29, 30, 31, 33, 34, 35, 36, 37 and 38 and step D1 (shown as step 100) are installed in the selected database, for step 18 whether exactly one user is the system account, for step 19 whether the 12 setting rows exist, for step 21 whether types 2, 3 and 6 are reserved, and for step 37 whether MailSenderUserId names an active Controller-role user whose address is the From Mail Id of SMTP Configuration (no address shown); allowed on `BMMS`)
- BMMS-Check-UserNames.sql                (read-only, step UN-data: every user with LoginName, UserName, role, department, active flag and the problems of the name: blank name, name equals login, name is a role word (every RoleName and RoleCode in Roles; the words are listed), duplicate name, duplicate login; then the counts per problem; allowed on `BMMS`)
- BMMS-Test-LoginName-Step34.sql          (tests for step 34: the column, the marker, the unchanged parameters, a login of mgruser writes its login ID and closes the earlier rows, an id with no user row writes NULL, and nothing is left; 7 checks; BMMS_Test only; inside a transaction that is rolled back, only the identity counter moves on)
- BMMS-Test-CommentAuthor-Step35.sql     (tests for step 35: the marker on the 3 procedures and the texts of steps 16, 17, 18, 20 and 31 kept, the parameters unchanged; a User's save writes no who and when; Approve and Reject of the Manager and the Controller (also with an empty comment, and the reject of Agenda Finalization) write the acting user and the time of their own role only; a refused call writes nothing; a new item of a Manager / the Controller writes that role's who and when; an edit only when that role's comment changes (case and a trailing space count, NULL and empty are the same), never for the other role's comment; View_Agenda returns them; rows outside the test unchanged; 28 checks; BMMS_Test only; inside a transaction that is rolled back, only the identity counters move on)
- BMMS-Test-AlertRefresh-Step36.sql      (tests for step 36: the marker on the 3 procedures, the texts of steps 16, 17, 18, 20, 31 and 35 kept, the parameters unchanged (since step 37 the list ends with @ChangedFields); an Update on Agenda Entry by a User (at AC, and on an item sent straight to the Controllers), a Manager (at AMA, the reported case, and at AMR) and the Controller (at AMA, ACA and ACR) marks the alert unread for every other recipient; no change refreshes nothing; NULL to a value and back, a trailing space, a change of case, of Subject No and of department count; NULL and empty are the same; the acting user's own row unchanged; a removed alert comes back; spr_GetAlertByUserId lists it unread; Alert_Master unchanged; a refused Update refreshes nothing; rows outside the test unchanged; 37 checks; BMMS_Test only; inside a transaction that is rolled back, only the identity counters move on)
- BMMS-Test-UpdateMail-Step37.sql        (tests for step 37: the marker on the 4 procedures, the texts of steps 16, 17, 18, 20, 31, 35 and 36 kept, @ChangedFields the one new parameter (last, OUTPUT, VARCHAR(400)), the MailSenderUserId row; @ChangedFields empty on Save, on an Update without a change and on a refused Update; one code per changed field in the fixed order (Subject Type, Short Text, Agenda Type, Agenda Text, the agenda text file attached / replaced / removed, Proposed Resolution, Attachments, both comments, Department for the Controller only, Subject No); a trailing space, a change of case and NULL to a value and back count; NULL and empty are the same; a caller without the parameter saves and refreshes as in step 36; spr_GetAgendaUpdateMailId: the users the alert is shown to (no Manager for AMA / AMR, no Controller for ACA / ACR), never the acting user, an inactive user, a user without an address or the system account; rows outside the test unchanged; 42 checks; BMMS_Test only; inside a transaction that is rolled back, only the identity counters move on)
- BMMS-Test-MinutesDueDate-Step38.sql    (tests for step 38: the marker, the texts of steps 6, 16, 17, 18, 23 and 31 kept, @DueDate the one new parameter (last, datetime, default 9999-12-31 = not passed); the markers MinutesDueDate-Step38 and DueDateKeep-Step38; Code 'All': a Followup stores the date without its time, the same date again writes no audit row, another date and NULL are stored and audited; another decision stores NULL; the meeting date itself is accepted, the day before is refused (Reason 22, the meeting date) and nothing is saved; a meeting without a date has no limit; Directions and Actual Resolution leave the date; a Followup saved without @DueDate keeps it, and an older caller that changes the decision without it stores NULL; finalized minutes can still be changed, confirmed minutes are refused (Reason 7); the audit row; Minutes and Audit_Trail_Master unchanged after the rollback; 22 checks; BMMS_Test only; inside a transaction that is rolled back, only the identity counters move on)
- BMMS-Test-Delete-Procedures.sql         (delete-procedure tests for the master tables; deletes real unreferenced rows, inside a transaction that is rolled back. With step 21 installed the member type part passes an active Admin, also tries a reserved type (expect Reason 7) and deletes a free type, adding one inside the transaction when none is unreferenced)
- BMMS-Test-FK-Procedures.sql             (tests for steps 6 to 9; rolled back)
- BMMS-Test-UserDelete.sql                (tests for steps 10 and 11, with step 13 installed: user delete rules, one test per protected column, one per key; rolled back)
- BMMS-Test-DashboardAlert-F1.sql         (step F1 browser check: three test alerts whose item does not exist for one test user, their ReadStatus, and the cleanup; three parts, run one at a time; BMMS_Test only; not rolled back, part 3 removes the rows)
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
- BMMS-Test-MeetingDelete-D1.sql        (tests for step D1: committee A94 "ZZ D1 meeting delete" with seven meetings and their Meeting alerts; a meeting today deleted with its alert and map rows while an Agenda alert carrying the same id and a Committee alert stay; a past meeting refused (Reason 20) with nothing removed; a meeting with no date deleted; agenda item, attendance without a meeting member, and meeting member refused (Reason 21 'Agenda items', 'Attendance', 'Members') with nothing removed; unknown id (Reason 4); a forced failure through a temporary trigger on Meeting (dbo.trg_ZZ_D1_MeetingDeleteFails, created and dropped by part 2, dropped by part 4 if left) after the alert deletes: the error reaches the caller, no transaction open, meeting and alerts all still there; 9 checks; four parts, run one at a time; BMMS_Test only; not rolled back, part 4 removes the rows)
- BMMS-Test-UnicodeText-Step31.sql      (tests for step 31: marker on the 7 procedures and the older texts of steps 6, 16, 17, 18, 20 and 23 kept; the 13 columns NVARCHAR(MAX) with collation and NULL unchanged, no VARCHAR text column left in the four views; the 31 text parameters NVARCHAR(MAX), parameter names, order and counts unchanged (since step 37: plus @ChangedFields on the three agenda procedures, 23 parameters and 3 outputs; since step 38: plus @DueDate on spr_UpdateMinutes, 9 parameters); the rupee sign, a Tamil word and a Hindi word (built with NCHAR, so the file is plain ASCII) through every save procedure: agenda save and edit by a user, a Manager and the Controller, Manager and Controller approval comments, the short text of the minutes page, Update Minutes Directions / Actual Resolution / All, the action text and actual resolution of an action item, read back from the tables, the four views and the minutes report procedure; text of about 50,000 characters kept whole, in the audit trail too; a Proposed Resolution change audited as ProposedResolution, a Short Text change still as ShortText; the Audit Trail report procedure names neither label; no procedure returns one of the texts as VARCHAR; made-up sample values only; 41 checks; test copy only; rolled back)

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

## Step 31: Unicode agenda and minutes text (what to run where)

Until step 31 the agenda and minutes text was stored as VARCHAR, code page 1252 (collation SQL_Latin1_General_CP1_CI_AS): the rupee sign and Tamil or Hindi letters typed on Agenda Entry, Update Minutes, the Dashboard or Followup became `?` when they were saved. The pages, the DAL (untyped parameters, sent as NVARCHAR) and the Word export were already Unicode; the database was the only place the letters were lost.

From step 31:

- Columns, VARCHAR(MAX) to NVARCHAR(MAX), collation and NULL / NOT NULL unchanged: Agenda ShortText, AgendaText, AgendaTextPath, ProposedResolution, FilePath, MgrComments, ControllerComments; Minutes Directions, ActualResolution; Action_Item Directions, ActionText; Audit_Trail_Master Old_Value, New_Value (the audit trail holds the old and new agenda text). AgendaTextPath and FilePath hold the names of uploaded files, which keep the name the user gave them, so a file with a Tamil or Hindi name is found again.
- The views on these tables are refreshed (View_Agenda, View_Minute, View_Action_Item, View_Action_Item_Users and any other view on them), so they return NVARCHAR too.
- Procedures, each with the marker UnicodeText-Step31 and otherwise the text of the step that last set it: spr_AddEditAgenda and spr_UpdateAgendaByAgendaId (step 20), spr_AddEditAgendaByManager and spr_AddEditAgendaByController (step 18), spr_UpdateAgendaShortText and spr_UpdateMinutes (step 23), spr_UpdateActionItem (the original database; no numbered script had it). Each text parameter and old-value variable is NVARCHAR(MAX): 31 parameters (TEXT in spr_UpdateMinutes and spr_UpdateActionItem; `@FilePath` was VARCHAR(255), which cut a long attachment list without a message, and now takes the whole list). Parameter names, order and count are unchanged, so the current build works with or without the step.
- A change of the Proposed Resolution in the three agenda add / edit procedures is written to the audit trail as `ProposedResolution` (it was `ShortText`, so the Audit Trail report showed it as a Short Text change). A new item was already audited as `ProposedResolution`. Rows written before step 31 keep the old label; they are not rewritten. Checked before the change: the Audit Trail page only shows Field_Name as text, and no page, report or numbered script selects on the label; the test checks that the Audit Trail report procedure names neither label.
- Existing data is unchanged. Every code page 1252 character has exactly one Unicode character, so the change is lossless. The script proves it in one transaction: it locks the four tables, keeps a SHA-256 hash of every value (as NVARCHAR) and its length, changes the columns, hashes the stored values again and compares the two sets row by row; any difference, or a different number of rows, rolls everything back and stops the script with "Step 31 stopped and changed nothing". Statistics that SQL Server created by itself on a changed column are dropped first (it makes them again when it needs them).
- Text that was already saved as `?` stays `?`: the letters were lost when it was saved and cannot be recovered.
- The text columns take about twice the space (2 bytes per character), and the change rewrites the rows of the four tables: take a backup first.

Step 31 needs steps 18, 20 and 23 (checked through their texts in the procedures) and stops otherwise, changing nothing. It also stops if the database name does not start with "BMMS" (so BMMS, BMMS_Test and BMMS_Quality are accepted, as in steps 29 and 30), if the compatibility level is below 100, if a column is missing or not VARCHAR(MAX) / NVARCHAR(MAX), if a schema-bound object, a statistic created by hand or a full-text index uses one of the columns, if spr_UpdateActionItem is not the original version (TEXT parameters, @Code All / ActualResolution / ActionText), or if step 32 has already replaced one of its procedures. Re-run rules: see "If step 6, 15, 16, 17, 18, 20 or 23 is ever re-run" under Run order.

The before and after check (read only; run it before step 31 and again after it, and compare the two grids: every line must be the same). The values are read as NVARCHAR in both runs, so the hash of a VARCHAR value before is the hash of the same text after:

```sql
SELECT 'Agenda' AS TableName, 'ShortText' AS ColumnName, COUNT(*) AS RowsInTable, COUNT(ShortText) AS NotNull,
       SUM(CAST(LEN(CAST(ShortText AS NVARCHAR(MAX))) AS BIGINT)) AS Chars,
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(ShortText AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) AS HashSum FROM dbo.Agenda
UNION ALL SELECT 'Agenda', 'AgendaText', COUNT(*), COUNT(AgendaText), SUM(CAST(LEN(CAST(AgendaText AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(AgendaText AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Agenda
UNION ALL SELECT 'Agenda', 'AgendaTextPath', COUNT(*), COUNT(AgendaTextPath), SUM(CAST(LEN(CAST(AgendaTextPath AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(AgendaTextPath AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Agenda
UNION ALL SELECT 'Agenda', 'ProposedResolution', COUNT(*), COUNT(ProposedResolution), SUM(CAST(LEN(CAST(ProposedResolution AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(ProposedResolution AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Agenda
UNION ALL SELECT 'Agenda', 'FilePath', COUNT(*), COUNT(FilePath), SUM(CAST(LEN(CAST(FilePath AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(FilePath AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Agenda
UNION ALL SELECT 'Agenda', 'MgrComments', COUNT(*), COUNT(MgrComments), SUM(CAST(LEN(CAST(MgrComments AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(MgrComments AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Agenda
UNION ALL SELECT 'Agenda', 'ControllerComments', COUNT(*), COUNT(ControllerComments), SUM(CAST(LEN(CAST(ControllerComments AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(ControllerComments AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Agenda
UNION ALL SELECT 'Minutes', 'Directions', COUNT(*), COUNT(Directions), SUM(CAST(LEN(CAST(Directions AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(Directions AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Minutes
UNION ALL SELECT 'Minutes', 'ActualResolution', COUNT(*), COUNT(ActualResolution), SUM(CAST(LEN(CAST(ActualResolution AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(ActualResolution AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Minutes
UNION ALL SELECT 'Action_Item', 'Directions', COUNT(*), COUNT(Directions), SUM(CAST(LEN(CAST(Directions AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(Directions AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Action_Item
UNION ALL SELECT 'Action_Item', 'ActionText', COUNT(*), COUNT(ActionText), SUM(CAST(LEN(CAST(ActionText AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(ActionText AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Action_Item
UNION ALL SELECT 'Audit_Trail_Master', 'Old_Value', COUNT(*), COUNT(Old_Value), SUM(CAST(LEN(CAST(Old_Value AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(Old_Value AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Audit_Trail_Master
UNION ALL SELECT 'Audit_Trail_Master', 'New_Value', COUNT(*), COUNT(New_Value), SUM(CAST(LEN(CAST(New_Value AS NVARCHAR(MAX))) AS BIGINT)),
       SUM(CAST(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', CAST(New_Value AS NVARCHAR(MAX))), 1, 7)) AS DECIMAL(38, 0))) FROM dbo.Audit_Trail_Master;
```

Run it with nobody using the application, so no row is added between the two runs (an agenda saved in between changes the Agenda and Audit_Trail_Master lines; the script's own check inside its transaction is not affected by that).

On the test copy (`BMMS_Test`), after a backup:

1. BMMS-Check-InstalledSteps.sql          (steps 1 to 24, 29 and 30 as before; step 31 Missing, 0 of 8 markers)
2. The before and after check above       (keep the grid: 13 lines)
3. BMMS-Fix-UnicodeText-Step31.sql        (prints the rows of the four tables and "Columns still VARCHAR: 13 of 13", then "Columns changed to NVARCHAR(MAX): 13 (UnicodeText-Step31). Values checked: <n>, all unchanged. ... Views refreshed: <v>." and "Step 31 installed: 13 columns NVARCHAR(MAX), 31 procedure parameters NVARCHAR(MAX), the views refreshed, marker on the 7 procedures (UnicodeText-Step31).")
4. The before and after check again       (the 13 lines exactly the same as in 2)
5. BMMS-Test-UnicodeText-Step31.sql       (41 checks; test copy ONLY)
6. The older tests of these procedures, unchanged: BMMS-Test-AgendaRouting-Step20.sql (56), BMMS-Test-WorkflowOrder-Step23.sql (53), BMMS-Test-MinutesGating-Step22.sql (36), BMMS-Test-MeetingLocks-Step16.sql (100), BMMS-Test-UserStatus-Stage2b.sql (63), BMMS-Test-SystemAccount-Stage3.sql (51), BMMS-Test-UserKey-Workflows.sql (23)
7. BMMS-Check-InstalledSteps.sql          (step 31 Installed, 8 of 8; steps 18, 20 and 23 still Installed)

A second run of step 31 prints "Columns still VARCHAR: 0 of 13" and "Columns changed to NVARCHAR(MAX): 0" and installs the same procedures again.

On `BMMS_Quality`: the same seven. On `BMMS`, after the backup: 1, 2, 3, 4 and 7 only (no tests).

The SQL works with the current build. Code step U1b (mail encoding, the request and response encoding in Web.config, the login page charset, PDF fonts and the stop for Tamil and Devanagari text in PDF exports) follows; its browser checks are in the section "Step U1b".

## Step E1: errors in UpdatePanel postbacks (code only, no database script)

An unhandled error during an UpdatePanel (partial) postback was neither shown nor written to the error log: the progress indicator stopped, nothing changed on the page, and the exception text went to the browser console only.

From step E1:

- The ScriptManager of Main.Master, MainNoMenu.Master and the login page (Default.aspx) handles OnAsyncPostBackError: Utilities.LogAsyncPostBackError writes one entry to the error log (class: the page's code-behind, method: "AsyncPostBack <control that posted>", the exception with its stack, the page path without query string, the user id). Form values, passwords and the mail password are never written. The browser gets only the fixed text "The action could not be completed. The error is in the error log." (AsyncPostBackErrorMessage), never the exception text.
- JScript/AsyncPostBackError.js shows a message bar at the top of the page content (div#wbAsyncError, style wb-async-error), never alert or confirm: "This action could not be completed because of an error on the server. The error is in the error log. Reload the page and check what was saved before you try again." When the browser gives up waiting: "The server did not answer in time. Reload the page and check what was saved before you try again." The next request hides the bar. The script registers its handlers once per page (Sys.Application load fires again after every partial postback), so a second postback never adds a second handler or a second message.
- Errors the pages already handle are unchanged: the 162 catch blocks that log and open the error page (GoToErrPage), the pages' own messages, mail failures (caught in Mail_Mgr), and Reset Database (its own server message, and its own client message when the page gets no answer; its handler runs first and marks the error handled, so the bar does not appear there). No catch block logs and then rethrows, so nothing is logged twice.
- Only pages with an UpdatePanel are covered; the pages that post back in full and errors before the page starts are covered by step E2.
- The error log (BMMS\Log\yyyy_MM_dd_ErrorLog.txt) keeps every error; step 28 only fixed the day's first entry, which used to be lost.

Browser checks on `BMMS_Test` after deploying the build (no test code in the product):

1. Database timeout. In SSMS on `BMMS_Test`: `BEGIN TRANSACTION; SELECT COUNT(*) FROM dbo.Alert_User_Map WITH (TABLOCKX, HOLDLOCK);` (if `SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = 'BMMS_Test';` gives 1, reads are not blocked: tell the Consultant). In the browser, Dashboard, click Read: after the 30-second command timeout the bar shows the server-error text; no alert; the console shows only "Partial postback failed: Sys.WebForms.PageRequestManagerServerErrorException". Today's error log has one new entry for the Dashboard class, "AsyncPostBack" and the Read link, with the SqlException (Execution Timeout Expired), the page path and the user id. Then `ROLLBACK TRANSACTION;`.
2. In the developer tools (Network), the response of check 1 contains only "The action could not be completed. The error is in the error log.": no stack, no SQL text.
3. Second postback. Click Unread (works now): the bar disappears. Hold the lock again and click Read again: one bar, one message (not two), and exactly one more log entry. Then `ROLLBACK TRANSACTION;`.
4. Request validation. Committee, type `<x` in the name and Save: the bar shows. Note whether the error log has an entry (expected: none, because the error comes before the page starts; since step E2, Application_Error writes one entry, with the value replaced).
5. Reset Database on `BMMS_Quality`: the wrong-name message, the slow-reset "no answer" message (step 29 check 14) and a normal reset behave as before; the bar never appears there.
6. Mail and handled errors: with smtp4dev stopped, Notice Send Mail still reports the mails that could not be sent; a save that fails in a guarded handler still opens the error page.
7. Login page: a normal sign-in and a wrong password show no bar.

## Step E2: errors on full-postback pages and before the page starts (code only, no database script)

Until step E2 there was no Application_Error: an unhandled error on a page without an UpdatePanel (Agenda, Attendance, User, Member, the small Master lists, SMTP Configuration, System Settings, Send Mail, Change Password and others) showed the ASP.NET error page (with the stack when browsing on the server) and was not logged; request validation ("A potentially dangerous Request.Form value", for example `<x` in a field) was not logged on any page. The error page of the guarded pages (GoToErrPage) showed the exception message (from the session) and a text taken from the address (`?Error=`).

From step E2:

- Global.asax.cs, Application_Error: every unhandled error that reaches the application is written once to the error log (class Global, method "Application_Error GET" or "POST", the exception, the page path without query string, the user id when there is a session) and answered with a short fixed page, status 500 (400 for a dangerous URL path): "This action could not be completed because of an error on the server. The error is in the error log. Open the page again and check what was saved before you try again." with an "Open the page again" link (the same path, normal GET, no query string; none for status 400) and a "Back to home" link (wording and link since step E2b). No exception text, no stack, no redirect, and the page needs no master, session or database, so it cannot loop. Requests from the server itself get the same page (the log has the stack). If even that page cannot be written, the answer is status 500 with no body.
- An UpdatePanel postback that fails before the page starts (request validation) gets status 500 with the fixed text, and the E1 message bar shows; it is logged once by Application_Error. An error the E1 handler already logged is not logged again (HttpContext.Items flag BMMS.ErrorLogged).
- Request validation: the log keeps the field name and replaces the value: `... from the client (ctl00$ContentPlaceHolder1$txtUserName="(value not logged)").` Only types, messages and stack traces are written for such an error, from Application_Error, from the E1 handler and from GoToErrPage. Other exception messages are written as they are (a SQL conversion message can quote a value); they go to the log only.
- Untouched: HTTP 404 (missing page; not logged, the usual answer), 404.8 for the hidden folders PDF, SqlBackup and Log (IIS answers before the application), and the 403 "Access denied" page of PageAccessModule (written by the module, logged in App_Data/PageAccessLog.txt only). An expired session still goes to the login page first, without an error.
- GoToErrPage (the 162 guarded catch blocks) logs as before and opens Error/ErrorPage.aspx without `?Error=` and without putting the exception message in the session. The error page shows only a fixed text (since step E2b: "This action could not be completed because of an error on the server. The error is in the error log. Use Exit to return to the page, and check what was saved before you try again.") with the Exit button; it reads nothing from the address and no error text from the session (Exit: see step E2b). The setting CommonErrMsg (XML/AppSettings.xml) is no longer used.

Browser checks on `BMMS_Test` after deploying the build (no test code in the product; keep the error log of the day open: BMMS\Log\yyyy_MM_dd_ErrorLog.txt):

1. Full postback, request validation: User Master, Add, type `<x` in User Name, Save. The safe page appears (Network: status 500); the page source contains no exception text and no `<x`. The log has one new entry: Global, "Application_Error POST", System.Web.HttpRequestValidationException with the field name and `(value not logged)`, the path /Master/User.aspx and the user id.
2. UpdatePanel, request validation: Committee, type `<x` in the name, Save. The E1 message bar shows; the log has one new entry, as in check 1, for /Master/Committee.aspx.
3. The value never appears: search the day's error log for `<x` (no match), and the page source of checks 1, 2 and 5 (no match).
4. E1 unchanged: Dashboard, Read while `SELECT COUNT(*) FROM dbo.Alert_User_Map WITH (TABLOCKX, HOLDLOCK);` holds the lock in an open transaction (as in E1): the bar shows, and the log has exactly one new entry (from the E1 handler, not a second one from Application_Error). Then `ROLLBACK TRANSACTION;`.
5. Guarded error (GoToErrPage): in SSMS `BEGIN TRANSACTION; SELECT COUNT(*) FROM dbo.Department WITH (TABLOCKX, HOLDLOCK);`, then open Department Master. After about 30 seconds the error page shows the fixed text; the address is /Error/ErrorPage.aspx without `?Error=`; the page source contains no "Timeout" and no exception text; the log has one entry for the Department page. Run `ROLLBACK TRANSACTION;`, then press Exit: Department Master opens (since step E2b; before, Exit went to /Master/.aspx and gave a 404). If Exit is pressed while the lock is still held, the page fails again after the timeout and the error page shows again, as expected.
6. The address cannot set the text: open /Error/ErrorPage.aspx?Error=hello: only the fixed text, no "hello".
7. 404: /Master/NoSuchPage.aspx gives the usual 404; /Log/x.txt, /Files/SqlBackup/x.bak and /Files/PDF/x.pdf give 404.8 as before. No new log entries.
8. 403: signed in as a user who is not an Admin, open /Master/ResetDatabase.aspx: "Access denied" (403) as before; no new error log entry.
9. 400: open /Master/a%3Cb.aspx (a `<` in the path): the safe page with status 400 and one log entry (the path is in the entry, it is the address, not a form value).
10. Expired session: delete the ASP.NET_SessionId cookie in the developer tools, then Save on User Master: the login page opens as before; no new error log entry.
11. Unchanged: a normal sign-in, Reset Database (step 29 checks 7 to 9) and the mail failure messages.

## Step E2b: Exit on the error page returns to the page that failed (code only, no database script)

Found in the E2 browser test: after an error on Department Master, Exit on Error/ErrorPage.aspx went to /Master/.aspx (ASP.NET 404). Exit used Session["PageURL"], which Common.InitSetup copies from XML/PageSettings.xml at the start of each page; the Department entry had no page name (`~/Master/.aspx`, since the recovered baseline). PageURL is also stale for every page without an entry or without InitSetup (ChangePassword, Master Followup, MinutesConfirmation, ResetDatabase, most reports, BackupDatabase, ResetPassword, SMTP Configuration, System Settings, ViewReport, ReportPrint): Exit went to the last page with an entry, or to the login page.

From step E2b:

- Utilities.GoToErrPage stores the page that failed in Session["ErrorReturnPage"]: its app-relative path and its original query string (`~/Report/Reports.aspx?rc=minutes`); no error text. It is stored only for a normal .aspx page; otherwise the value is cleared.
- Exit (ErrorPage.aspx.cs) returns there only if the value starts with `~/`, has a non-empty file name ending in .aspx, contains nothing that could point to another site (`//`, `\`, `:`), is not the error page itself and the file exists; otherwise it goes to the Dashboard. It removes the value after use and never uses Session["PageURL"] again.
- XML/PageSettings.xml: the Department entry is `~/Master/Department.aspx`; the two entries no page uses (SubjectNoAllocation, whose page does not exist, and "-") are removed (searched first: nothing refers to them; the report codes in the menu are agenda_summary, agenda_details, minutes and minutes_extract).
- The safe page of Application_Error (step E2) now says "... Open the page again and check what was saved before you try again." and has an "Open the page again" link: the same path with a normal GET, HTML-encoded, no query string; no link for status 400, for the error page itself (the link would point at itself) or for a path that could point to another site. "Back to home" stays.
- The error page (Error/ErrorPage.aspx) says "This action could not be completed because of an error on the server. The error is in the error log. Use Exit to return to the page, and check what was saved before you try again." (the first two sentences as on the safe page); the separate line "Use Exit to return to the previous page." is gone.
- The error page with no signed-in user (the session expired or its cookie was removed): it is public in PageAccess.xml, so PageAccessModule let it through, and the menu of Main.Master failed to render without Session["RoleCode"] (NullReferenceException in the menu, logged by Application_Error, safe page). Now the page itself sends the visitor to the login page first, on GET and on POST, with no log entry: in OnPreInit, before the master page and its menu are created and before the Exit event, with Response.Redirect(url, true) as Common.InitSetup does on the other pages. The test is the one PageAccessModule uses (Session["UserName"] empty). A signed-in user sees the page as before.

Browser checks on `BMMS_Test` after deploying the build:

1. Department: `BEGIN TRANSACTION; SELECT COUNT(*) FROM dbo.Department WITH (TABLOCKX, HOLDLOCK);`, open Department Master, wait for the error page, `ROLLBACK TRANSACTION;`, press Exit: Department Master opens (Network: ErrorPage.aspx 302, then Department.aspx 200).
2. A report with ?rc= (the Generate button is guarded): open Reports, Minutes (Reports.aspx?rc=minutes), choose a committee and a finalized meeting; then `BEGIN TRANSACTION; SELECT COUNT(*) FROM dbo.Meeting WITH (TABLOCKX, HOLDLOCK);` and press Generate. After the timeout the error page shows; `ROLLBACK TRANSACTION;`, press Exit: Reports.aspx?rc=minutes opens (the Minutes report). Note: a lock taken before the report page is opened makes its unguarded loading fail instead, and the safe page's "Open the page again" link has no query string, so Reports opens without ?rc= and fails again; use the menu there.
3. Pages that never call InitSetup. (a) System Settings (its loading is guarded): `BEGIN TRANSACTION; SELECT COUNT(*) FROM dbo.App_Setting WITH (TABLOCKX, HOLDLOCK);`, open System Settings as an Admin; when the error page shows, `ROLLBACK TRANSACTION;`, press Exit: System Settings opens. (b) SMTP Configuration (its loading is not guarded, so the error reaches Application_Error): `BEGIN TRANSACTION; SELECT COUNT(*) FROM dbo.SMTP_Master WITH (TABLOCKX, HOLDLOCK);`, open SMTP Configuration; the safe page of step E2 shows; `ROLLBACK TRANSACTION;`, use "Open the page again": SMTP Configuration opens.
4. /Error/ErrorPage.aspx opened directly (after a fresh sign-in, no error before): Exit opens the Dashboard.
5. Expired session on the error page, POST: get the error page as in check 1, `ROLLBACK TRANSACTION;`, delete the ASP.NET_SessionId cookie (developer tools, Application, Cookies), press Exit: the login page opens (Network: POST ErrorPage.aspx 302, then Default.aspx 200); no new error log entry and no safe page.
5b. Expired session on the error page, GET: delete the ASP.NET_SessionId cookie, open /Error/ErrorPage.aspx: the login page opens (GET ErrorPage.aspx 302, then Default.aspx 200); no new error log entry. Signed in, the same address shows the error page with the new text and Exit (Exit then goes to the Dashboard, as in check 4).
6. The safe page link: User Master, Add, `<x` in User Name, Save: the safe page shows the new text with "Open the page again" (to /Master/User.aspx, no query string) and "Back to home"; the link opens User Master with a normal GET. /Master/a%3Cb.aspx: status 400, the safe page without "Open the page again".
7. A failing page from the Network tab never leads to an address with an empty page name (no request to /Master/.aspx).

## Step B3: product artwork and one colour scheme (code and files only, no database script)

The artwork and the palette were made in Claude Design; the source is `Design/bmms-brand/` (outside the web project; its SVG files carry no provenance metadata in the repository copy). Owner Gashpy Software, product "Board Minutes and Meeting Software" (BMMS).

From step B3:

- Palette: `BMMS/CSS/bmms-colours.css`, an exact copy of `Design/bmms-brand/bmms-colours.css` (48 `--bmms-*` values, including `--bmms-focus-on-dark` and `--bmms-menu-selected-indicator`), loaded before `bmms-workbench.css` on both master pages and the sign-in page. The `--wb-*` names of the workbench are now aliases of the palette (the green accent became the product blue). The older stylesheets MainMaster.css and CommonHTML.css use the palette for every colour (layout unchanged); rules nothing uses were removed (listed at the top of MainMaster.css).
- Header: the logo `Images/Brand/bmms-logo-horizontal-white.png` (2x through srcset), 36 px high in a 48 px bar, no link, tooltip and alt text "Board Minutes and Meeting Software". The current page's menu item: blue with a 3 px white bar along its bottom; keyboard focus on the bar: a light blue outline.
- Sign-in page: the banner (up to 560 px wide (source file 1000 x 240 px, with a 2000 x 480 px version for sharp screens), scales down to the window) above the Log in box; the heading "BMMS" and the product name stay for screen readers (visually hidden); the footer line of the other pages; the Log in button is blue.
- Favicon: `BMMS/favicon.ico` (so `/favicon.ico` no longer gives 404) and `Images/Brand/bmms-favicon-192.png`, linked from the master pages, the sign-in page, Logout, ReportPrint and ViewReport.
- Messages: each page's MsgDisplay has an optional kind (Common.MessageKind): Warning (the default: refusals, "please select", the browser checks of Validation.js), Success (saved, deleted, finalized, confirmed, mail sent, ...), Error (failed on the server). The message shows the matching icon (`Images/Brand/message-*.png`), tint and left border; the text is unchanged. The E1 message bar has the error look (CSS only).
- Tables: the light palette header (`--bmms-table-head-bg`, `--bmms-table-head-text`), striped rows and a hover tint. The sort links of the older grids carry an inline white colour; one rule (`.contentTableHeader a[style]`, with !important) gives them the header text colour, and they are underlined.
- Dashboard: read and unread alerts and action items keep their difference (unread rows bold, as before) on two palette tints; the current filter (Show All / Read / Unread) is blue and not underlined, the others underlined.
- Menu arrows: the menu script no longer adds arrow images (`showarrow` off in MenuUserControl.ascx), so `/DashBoard/Images/arrow-down.gif` and `/Report/Images/arrow-down.gif` are no longer requested; the arrow is drawn in CSS.
- The inline error page (Application_Error) and the "Access denied" page use hex copies of the palette (marked in the code); text and behaviour unchanged.
- Deleted (unused after B3): Images/bg.jpg, tableft.gif, tabright.gif, Common/Error-Info.gif and the tab_*.gif copies in Images (the colour picker keeps its own in JScript/ColorPicker/Images).
- Printed reports, PDFs and mail are unchanged. The Committee colour field keeps the colour the user chose.

Browser checks on `BMMS_Test` after deploying the build (Ctrl+F5 on each page; developer tools, Network, Disable cache):

1. Sign-in page: the banner above the Log in box, sharp on a high-density screen; at 320 px window width no horizontal scroll bar; a screen reader reads the heading "BMMS"; the footer line; the blue Log in button; no 404 in the Network list (favicon.ico, arrow-down.gif, bg.jpg).
2. Signed out: `/favicon.ico`, `/CSS/bmms-colours.css` and `/Images/Brand/bmms-logo-horizontal-white.png` each give 200.
3. First-login page (admin with the default password after a reset on `BMMS_Quality`): the logo bar is 48 px high; no orange anywhere.
4. Dashboard: blue and grey only; unread rows bold on the stronger tint, read rows normal on the lighter one; the current filter blue and not underlined; no request for `/DashBoard/Images/arrow-down.gif`.
5. A master list and form (Department): Save gives a green success message with its icon; a delete of a department in use gives the warning look; field borders grey, the focus ring blue.
6. A report page (Reports, Minutes; then Meeting Master): the table header light blue with dark, underlined sort links; no request for `/Report/Images/arrow-down.gif`.
7. Reset Database: a wrong name gives the warning look; otherwise unchanged.
8. An error page (the Department lock of step E2b): the error page in the new look, text unchanged; Exit as before.
9. The safe page after `<x` on User Master: the palette colours, the same text and links, status 500.
10. Keyboard on the menu bar: Tab through the menu items, Change Password and Logout: each shows a light blue outline; the current page's menu item shows the white bottom bar.
11. A failed partial postback (the E1 lock on the Dashboard): the E1 bar has the red error icon and tint.

## Step U1b: Unicode in mail, pages and PDF exports (code, Web.config and font files, no database script)

Install step 31 first (see its section): before it, Tamil and Hindi agenda and minutes text is stored as `?`, and the checks below cannot show anything. U1b works with or without step 31.

From step U1b:

- Mail (Mail_Mgr.SendWebEmail, used by every alert mail, Notice, Send Mail and Reset Password): subject, body and headers are sent as UTF-8 (SubjectEncoding, BodyEncoding, HeadersEncoding), and an attached file keeps a Tamil or Hindi file name (NameEncoding UTF-8).
- Web.config, in `<system.web>`, after `<httpRuntime requestValidationMode="2.0"/>`: `<globalization requestEncoding="utf-8" responseEncoding="utf-8"/>`. The runtime web.config of each server needs the same line by hand (Web.config is not deployed over it).
- The sign-in page (Default.aspx) declared `charset=iso-8859-1`; it now declares `charset=utf-8`, as the server sends. The other pages had no charset of their own.
- PDF font: the PDF exports use Noto Serif, embedded (only the letters used), in place of the built-in Times Roman and Helvetica, which have only the 1252 code page: the rupee sign was left out of every PDF. Files in `BMMS/Fonts/Pdf` (static TrueType, unhinted; hinting does nothing in a PDF), SIL Open Font License 1.1 (`OFL.txt` beside them, from the Noto project):

  | File | Bytes |
  |---|---|
  | NotoSerif-Regular.ttf | 482,540 |
  | NotoSerif-Bold.ttf | 481,892 |
  | NotoSerif-Italic.ttf | 513,428 |
  | NotoSerif-BoldItalic.ttf | 513,280 |
  | OFL.txt | 4,396 |

  1,995,536 bytes in all. A PDF grows only by the letters it uses (a one-page test with all four faces: 41 KB). The files are Content in BMMS.csproj, so Publish copies them; the site reads them from `<site>\Fonts\Pdf` and a missing file stops the export with "The PDF font file is missing: <path>" in the error log.
- BMMSBAL/PdfFonts.cs: the font (size and style; bold and italic are the real faces, underline stays a style), the text helpers, and the font for HTML converted by iTextSharp's HTMLWorker: every font the HTML names (`font-family: Times`, Arial or none) becomes Noto Serif in the size and style asked for. Noto Serif has Latin, Greek, Cyrillic and the rupee sign; a character it does not have prints as `?` (iTextSharp left it out without a sign), also when written in the HTML as `&#nnnn;`.
- Tamil and Hindi (Devanagari) text: Noto Serif has no Tamil or Devanagari letters, and iTextSharp 4 cannot join them (no text shaping) even with a font that has them. A PDF export whose printed text contains a Tamil or Devanagari letter (also written as `&#nnnn;` in rich text) is therefore not made: the page shows "Tamil or Hindi text cannot be printed correctly in a PDF; " and what to use instead, in its own message display, and opens no PDF window. Only the text the PDF prints is checked (for example a Hindi Proposed Resolution does not stop the Agenda Summary, which does not print it). An agenda text or attachment uploaded as a PDF file is copied into Agenda Details page by page and is not checked.

  | PDF export | Message display | Instead (in the message) |
  |---|---|---|
  | ViewReport, Export to Pdf (Minutes, Minutes Extract, Followup Action Taken reports) | new line under the buttons (not printed) | "use Export to Word or Print" (same window) |
  | Reports, Agenda Summary, Generate (one meeting, all meetings, a range) | the page's message box | "use View on this page" (the grid) |
  | Reports, Agenda Details, Generate | the page's message box | "use View on this page" |
  | Agenda Approval, Create PDF | alert, as "No Agenda Available" | "choose View on this page" (View Format: View) |
  | Notice, Create PDF | the page's message box | "use Send Mail" (the same notice as mail) |
  | Sitting Fees, Generate Report (Individual, Designation, Consolidated) | alert, as "No such record found" | none: "Sitting Fees has no Word export, so this report cannot be made" |

  Agenda Summary, Agenda Details, Agenda Approval and Sitting Fees have no Word export or Print view; their alternatives are the screen grid (only part of the text) or nothing.
- Not changed: code no page reaches (Followup Action Taken and Followup Send Mail, whose buttons are not on the pages; PayRollStatement in PDFUtilities and PDF_Reports; GenerateHTMLPdf of Error/TestPage); empty spacer lines in the PDFs still name Helvetica (they print no letter).
- Still VARCHAR in the database (not part of step 31): member names and addresses, committee, department, meeting place and venue, and the organisation details of System Settings (App_Setting). The rupee sign and Tamil or Hindi letters typed there become `?` when saved, so they cannot reach a PDF, a mail or a report. In particular the Notice PDF prints only such texts, so its stop cannot be seen in the browser yet.

Before the checks (on `BMMS_Test`, step 31 installed): deploy the build, add the globalization line to the runtime web.config, recycle the application pool, start smtp4dev (step 30) and point SMTP Configuration at it. Sample texts (made up): `₹ 1,500`, Tamil `தமிழ் சோதனை`, Hindi `हिन्दी परीक्षण`, and `中` (a character no font has).

1. Sign-in page: developer tools, Network, Default.aspx: the response header `Content-Type: text/html; charset=utf-8`; View Source shows `charset=utf-8`. Sign in.
2. Every agenda and minutes box, each with the rupee sign, the Tamil and the Hindi text: Agenda Entry (Short Text, Agenda Text, Proposed Resolution); Manager and Controller approval comments (Dashboard); Minutes short text; Update Minutes (Directions, Actual Resolution); Followup / Action Taken (action text, actual resolution). Save, open again: the text is as typed. In SSMS the four tables show the letters (no `?`).
3. A file with a Tamil name: on Agenda Entry attach a PDF named `தமிழ்-மாதிரி.pdf` and save: it is listed with its name and opens; Agenda Details (step 7) includes its pages. On Send Mail attach the same file: the mail in smtp4dev has the attachment with its Tamil name.
4. Screen reports: Reports, Minutes and Minutes Extract, Generate; Followup Action Taken, Generate Report: the report window shows the rupee sign, Tamil and Hindi correctly.
5. Word: Export to Word from each report of check 4: Word shows the same letters.
6. Print: Print from each report of check 4, Save as PDF in the browser: the rupee sign, Tamil and Hindi are printed correctly (the browser joins the letters).
7. Each PDF with the rupee sign and Latin text only (an agenda without Tamil or Hindi; Sitting Fees with `₹` in Authorised Person Name): Export to Pdf of the three reports of check 4; Agenda Summary (one meeting, and a range); Agenda Details; Agenda Approval, Create PDF; Notice, Create PDF; Sitting Fees Individual, Designation and Consolidated. Each opens; the rupee sign shows; the PDF reader's document properties list only NotoSerif fonts (with Helvetica at most for empty lines), embedded subset; bold and italic text is in the Bold and Italic faces.
8. `中` in an agenda Short Text, Agenda Summary and Export to Pdf of the Minutes report: it prints as `?`; the rest of the line is complete.
9. Each PDF with Tamil, then with Hindi text in what it prints: Export to Pdf of the three reports (the message under the buttons; Export to Word and Print still work in the same window); Agenda Summary and Agenda Details (message box, no window opens); Agenda Approval (alert); Sitting Fees with Tamil in Authorised Person Name, each of the three types (alert). The texts as in the table above. Then the same with Tamil only in the Proposed Resolution: Agenda Summary is made (it does not print it); Agenda Approval stops.
10. Alert mails in smtp4dev, with the rupee sign, Tamil and Hindi in the agenda Short Text (the alert mails print it): an agenda created on Agenda Entry, approved or returned on the Dashboard, finalized on Agenda Finalization: the Short Text line shows the letters as typed. Send Mail with the sample texts in Subject and Body: subject and body as typed. The message source has `charset=utf-8` in the body's Content-Type and the subject as `=?utf-8?B?...?=`. (The meeting and committee alert mails print only master data, see above.)
11. Notice, Send Mail: arrives as before (its texts are VARCHAR master data, see above).

## Step F1 and E2c: Dashboard alert whose item is gone; Page not found (code and Web.config, no database script)

Found on `BMMS_Test`: one alert row with SourceTypeId NULL made DashBoard.aspx.cs, lnkSource_Click, throw a FormatException (`int.Parse` of the hidden SourceTypeId), and the user saw the error page. A page that does not exist got the default ASP.NET 404 page (with the .NET and ASP.NET versions), and every answer carried the X-AspNet-Version and X-Powered-By headers.

From step F1:

- Dashboard, lnkSource_Click: the session user id, the item id (SourceTypeId) and the alert id are read with `int.TryParse`. A session without a usable user id is treated as expired: the login page opens (`Response.Redirect("~/", true)`, as Common.InitSetup does). When the item id is unusable or the Meeting, Committee or Agenda is not found, no panel or popup opens and the page shows the warning "This item no longer exists." in its message box (new on the Dashboard, the same box and MsgDisplay as the other pages); the alert is still marked as read when the alert id itself is valid. A committee that is not found is detected by catching the IndexOutOfRangeException of that one lookup (CommitteeDB reads `Rows[0]` without a check; BAL and DAL unchanged).
- Unchanged: the normal path, an unknown source type (no panel, marked as read), alert creation and every procedure. An item that is found but the user should not see: no change, the Dashboard lists only the alerts mapped to the user (Alert_User_Map) and has no per-item check; Approve and Reject are shown by role and refused by the procedure for the wrong role (step 20).

From step E2c:

- Global.asax.cs, Application_Error: HTTP 404 raised in ASP.NET (a missing .aspx, ScriptResource.axd or WebResource.axd with a bad `d=`) gets status 404 and a short fixed page: title "BMMS - Page not found", heading "Page not found", the text "Page not found." and the link "Back to home" (the Dashboard; a signed-out visitor goes on to the login page). Same inline style and palette as the safe error page, no master, session or database; no path, no version, no log entry. An UpdatePanel postback that gets a 404 receives status 404 with the fixed text of step E1, and the E1 message bar shows.
- A missing static file (.css, .js, images) or folder is answered by IIS itself, not by the application; that answer is unchanged. Also unchanged: 404.8 for the hidden folders PDF, SqlBackup and Log, and the 403 "Access denied" page of PageAccessModule.
- The safe page without the "Open the page again" link (status 400, the error page itself, a path starting with `//` or containing `\`) now says "This action could not be completed because of an error on the server. The error is in the error log. Check what was saved before you try again." The other safe pages keep "... Open the page again and check what was saved before you try again." with the link.
- Web.config, `<system.web>`: `<httpRuntime requestValidationMode="2.0" enableVersionHeader="false"/>` (no X-AspNet-Version header). `<system.webServer>`: `<httpProtocol><customHeaders><remove name="X-Powered-By"/></customHeaders></httpProtocol>` after `<security>`. The Server header is left as it is. Apply the same lines by hand to the runtime Web.config.
- No database object is changed. BMMS-Test-DashboardAlert-F1.sql only adds test rows for the browser check and removes them again.

Preparation: deploy the build, apply the Web.config lines to the runtime Web.config, recycle the application pool. Keep the error log of the day open (BMMS\Log\yyyy_MM_dd_ErrorLog.txt). Addresses below are relative to the application root (`http://localhost:<port>`).

Browser checks on `BMMS_Test`:

1. F1, bad alert rows: open BMMS-Test-DashboardAlert-F1.sql in SSMS on `BMMS_Test`, set `@TestLogin` in part 1 to a test user who already has at least one alert, select part 1 and run it (it prints three AlertIds). Sign in as that user, Dashboard, Show All, click each of the three "ZZ F1 test -" alerts (agenda without id, meeting and committee that do not exist): each time the warning "This item no longer exists." shows above the Alert list, no panel or popup opens, no error page, no new error log entry. Run part 2: ReadStatus is 1 for all three. Run part 3 (cleanup): "Deleted 3 ... and 3 ...".
2. F1, normal path: a real Meeting alert and a Committee alert open their popup, and an Agenda alert opens the agenda panel, as before; the warning is gone after the next click.
3. F1, Approve and Reject still work for a normal agenda alert: as Manager (agenda status AC) and as Controller (status AMA), Approve one agenda and Reject another from the Dashboard: the status changes, the alert mail arrives (smtp4dev), no message box warning.
4. Page not found: `/NoSuchPage.aspx`, `/x/y.aspx` and `/ScriptResource.axd?d=bad`: status 404 (Network tab) and the short page with only "Page not found." and "Back to home"; the page source has no path, no version and no ".NET"; no new error log entry. "Back to home" opens the Dashboard (or the login page when signed out). For comparison, `/NoSuch.css` gets the IIS answer as before.
5. Unchanged: `/Log/`, `/Files/SqlBackup/` and `/Files/PDF/` (and a file name under each, such as `/Log/x.txt`) give 404.8 as before; signed in as a user who is not an Admin, `/Master/ResetDatabase.aspx` gives 403 "Access denied" as before. No new error log entries.
6. Headers: any page (Network tab, response headers): no `X-AspNet-Version` and no `X-Powered-By`; `Server` is still there.
7. Wording: `/Master/a%3Cb.aspx` (a `<` in the path): status 400, the safe page with "... Check what was saved before you try again.", no "Open the page again" text and no such link, one log entry. User Master, Add, `<x` in User Name, Save: status 500, the safe page still has "Open the page again" in the text and as a link.

Later: step F2 (found while planning F1, not changed in this step; all in DashBoard.aspx.cs):

- LoadAlertGRV and LoadActionItemGRV: `int.Parse(Session["UserId"])`.
- lnkActionItem_Click: `int.Parse` of the hidden ActionItemId (twice); BindActionItemDetails reads `Rows[0]` without checking that a row came back.
- btnApprove_Click and btnReject_Click: `int.Parse` of hdnAgendaMeeting and hdnAgendaId, and `Convert.ToInt16(Session["UserId"])`.
- GenerateMail: `int.Parse` of hdnAgendaId and of the session user id.
- btnActionItemApprove_Click: `int.Parse` of hdnActionItemId.
- btnDeleteAlert_Click: `Convert.ToInt16(hdnAlertUserId)` overflows once AlertUserId is above 32,767 (an overflow, not only bad input).
- BindAgendaDetails: `Convert.ToInt16` of the MeetingId (the same overflow above 32,767).
- BindMeetingDetails and BindAgendaDetails: an item that is found but has a NULL MeetingDate (or AgendaSubmissionDate) still fails in `Convert.ToDateTime`.

## Step N1: safe names for uploaded files (code only, no database script)

Found during browser testing: an attachment whose name contains & % or + could not be opened by its link (ASP.NET refuses & in a URL path with 400, IIS refuses an escaped + or %), and a comma in an agenda attachment name broke the comma-separated list in Agenda.FilePath.

- BMMSBAL/SafeFileName.cs (new), Clean: only the name is kept (no folder); letters of any script with their combining marks (Tamil and Hindi vowel signs and virama), decimal digits, the zero-width joiner and non-joiner, space, dot, hyphen, underscore and round brackets are kept; any other white space becomes one space; every other character becomes _ (a run of them one _). Composed form (NFC); repeated dots become one; spaces and dots trimmed at both ends; at most 100 characters with the extension (up to 10 characters) kept, never cut between a letter and its marks; an empty name or one of only _ becomes "file"; a Windows reserved name (CON, PRN, AUX, NUL, COM1 to COM9, LPT1 to LPT9, also with an extension) gets _ in front. Never throws, never empty; cleaning again gives the same name.
- SafeFileName.MakeUnique: when a file of that name is already in the folder, " (2)", " (3)" ... is added before the extension (never longer than the name or 100 characters, whichever is more), so two uploads that clean to the same name no longer overwrite each other.
- Agenda Entry: attachment `Attach-<agenda no>-<clean name>` and agenda text `<agenda no>-<clean name>`, both made unique in their folder; the agenda number prefix is generated and kept as it is. The attachment grid shows the saved name, so it shows the cleaned name; no extra message.
- Send Mail: the clean name in Files/Temp (not made unique: the folder is emptied on every upload). The mail attachment carries the clean name.
- Unchanged: files already on disk and names already stored in the database (a stored name with & % + or a comma still cannot be opened); member photo and CV (named from the member code) and the organisation logo (fixed name); the readers in DashBoard, Reports and Agenda Approval; every procedure.
- Tamil and Hindi names are stored correctly only on a database with step 31 (NVARCHAR(MAX) FilePath and AgendaTextPath).

Browser checks on `BMMS_Test` (deploy the build first; keep the error log of the day open):

1. Agenda Entry, new agenda: attach `a&b #1.pdf`, `a+b.pdf`, `50% off.pdf`, `a,b.pdf`, a Tamil name, a Hindi name, a name of about 150 characters and a Tamil name of 100 characters. The grid shows the cleaned names (for example `Attach-<agenda no>-a_b _1.pdf`, `...-a_b.pdf`, `...-50_ off.pdf`, `...-a_b (2).pdf` for `a,b.pdf`), every link opens the right PDF. Save.
2. Edit the same agenda: every attachment link and the agenda text View open.
3. Agenda text: upload `a&b #1.pdf`, View opens; save, reopen, View opens.
4. Dashboard popup for that agenda: every attachment link and View open.
5. The agenda booklet PDF (Reports) and Agenda Approval include the attachments and agenda text, no error.
6. Send Mail: upload `a&b #1.pdf`, View opens; send: the mail attachment is named `a_b _1.pdf` and opens; a Tamil name arrives in Tamil; `.pdf` gives `file.pdf`.
7. Same name twice: attach `x&y.pdf` and then `x+y.pdf` to one agenda: two rows, `... x_y.pdf` and `... x_y (2).pdf`, each opens its own file.
8. No new error log entries.

## Step M1: Meeting Master Edit and Delete for the whole meeting date; "saved, but the mail could not be sent" (code only, no database script)

Found during browser testing: Meeting Master compared the meeting date (stored at 00:00) with the current date and time, so a meeting dated today was "closed" from midnight, although step 24 allows saving a meeting dated today. A new meeting saved while the mail server was stopped showed only "Error: Failure sending mail.", although the meeting, its alert and the alert rows were saved.

- MeetingMgr.IsMeetingOpenForChange (new): a meeting is open for Edit and Delete for the whole of its date and closed from the next day (web server date; MeetingTime is not looked at); a meeting with no date stays open so that it can be corrected.
- Meeting Master, grid: only Edit and Delete are handled in RowCommand (a sort header click no longer reaches the id conversion); a meeting that no longer exists gives "The meeting or member no longer exists. Reload the page." and the grid is reloaded; a closed meeting gives the warning "The meeting date has passed, so this meeting can no longer be edited or deleted." (was "This meeting was closed."); a meeting with no date opens with empty date boxes.
- Meeting Master, Update: the same rule is checked again against the saved meeting date before anything is saved (a form opened before midnight, or a changed hidden meeting id).
- Meeting Master, Save and Update: when the mail fails after the save, the warning "The meeting was saved, but the mail could not be sent. The error is in the error log." (the mail error text is no longer shown); the grid is reloaded as before. A failure while the mail is prepared (for example reading the user list) is logged once as Meeting / GenerateMail; a failure while sending is logged once by Mail_Mgr as before.
- Reset Password: "The password was reset to the default password, but the mail could not be sent. The error is in the error log." (the mail error text is no longer shown).
- Meeting.aspx: the Venue sort header had the same ID as the Place header (`lnk3`, since the baseline), so every sort header click failed with "Multiple controls with the same ID 'lnk3' were found"; the Venue header is now `lnk7` and the headers sort.
- Unchanged: the step 24 save rules and every procedure. spr_AddEditMeeting and spr_DeleteMeetingByMeetingId have no date rule of their own (the delete is refused only when the meeting has members or agenda items, and it leaves the meeting's alerts behind); the page is now the only way to them and applies the rule on Edit, Update and Delete. (Since step D1 the delete procedure has the date rule too and removes the meeting's alerts.)

Browser checks on `BMMS_Test` (deploy the build first; smtp4dev running unless stated; keep the error log of the day open):

1. A meeting dated tomorrow: Edit opens, Update gives "Successfully Saved" and the mail arrives; Delete deletes it when it has no members or agenda items, and is refused with the usual message when it has.
2. A meeting dated today (before and after its meeting time): Edit and Delete as in 1, until midnight.
3. A meeting dated yesterday: Edit and Delete both give "The meeting date has passed, so this meeting can no longer be edited or deleted."; the grid is unchanged.
4. Open Edit on tomorrow's meeting, change the hidden meeting id in the browser to yesterday's meeting, Update: the same warning, nothing saved.
5. Every sort header of the meeting grid sorts the grid, no error page, no log entry.
6. Stop smtp4dev. Add a meeting dated tomorrow: the warning "The meeting was saved, but the mail could not be sent. The error is in the error log." and the new row in the grid. Edit it and Update: the same warning. Start smtp4dev, Update again: "Successfully Saved" and the mail arrives.
7. Stop smtp4dev. Reset Password for an active user: "The password was reset to the default password, but the mail could not be sent. The error is in the error log.", no error text on the page.
8. Error log: one Mail_Mgr / SendWebEmail entry for each failed mail in checks 6 and 7, nothing else.

## Step A1b-1: sort headers on seven more grids (markup and code only, no database script)

Found in step M1: two or more sort header links of one grid had the same ID, so every header click of that grid failed with "Multiple controls with the same ID ... were found" (since the baseline). Two of these grids also had no sort handler at all.

- New header IDs, nothing else in the markup changed: Backup Database `lnk2` (Backup Date Time) to `lnk3`; Committee Member `lnk2` (Member Type) to `lnk6`; Department `lnk2` (Display Order) to `lnk3`; Member `lnk3` (Email Id) to `lnk4` and `lnk3` (Date of Join) to `lnk6`; Attendance Details report `LinkButton1` (Meeting No) to `LinkButton2`, `LinkButton1` (Meeting Date) to `LinkButton5` and `LinkButton4` (Attendance) to `LinkButton6`; Committee Master report `lnk2` (Incorporation Date) to `lnk3`; Followup report `LinkButton1` (Meeting No) to `LinkButton7`. No code, script or style refers to these IDs. A scan of all 38 grids finds no duplicate ID left.
- Backup Database and the Committee Master report: the grid gets `OnSorting="grvRecord_Sorting"`; the bound table is kept in `ViewState["DataTable"]` and sorted by Utilities.GridViewDataTableSorting, as on Department and Member. Before this, a header click there would have failed with "The GridView ... fired event Sorting which wasn't handled" once the IDs were unique.
- Unchanged: the columns, the data, the filters and every procedure.

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; keep the error log of the day open):

1. Each of the seven pages opens with no error: Master/BackupDatabase, Master/CommitteeMember, Master/Department, Master/Member, Report/AttendanceDetails, Report/CommitteeMaster, Report/Followup (after its filter has listed rows).
2. Every header of each grid sorts ascending on the first click and descending on the second; the arrow style of the header follows.
3. Committee Member, Department and Member: after a sort, Edit opens the row that was clicked, Cancel returns to the grid, and Delete of a row that may be deleted deletes that row (the delete confirm still shows).
4. Backup Database: after a sort, Backup Database adds a backup row and the grid shows it.
5. Committee Master report: after a sort, changing the Committee or Status filter and Submit lists the right rows; sorting again works.
6. Attendance Details and Followup reports: after a sort, changing the filters lists the right rows; sorting again works.
7. A grid with no rows (for example Committee Member for a committee without members) shows its no-record text and no error.
8. No new error log entries.

## Step A1b-2: plain text encoded on the master, meeting and report grids (markup and code only; test script for BMMS_Test)

Found in the A1b review: the grid Labels of the master, meeting and report pages show `Eval(...)` without encoding (a Label does not encode), so a name holding `<`, `>` or `&` was read as HTML by the browser (since the baseline). A name with an apostrophe (O'Brien) could not be saved on six master pages: the duplicate-name check pastes the typed name between quotes in a DataView RowFilter, the filter is then invalid, and the save went to the error page.

Built and tested in three groups. Test rows: `Database/BMMS-Test-MasterHtml-A1b.sql` (BMMS_Test only; part 1 inserts, part 2 shows, part 3 deletes; see its header). The texts are A `ZZ A1b O'Brien & Sons <b>x</b>`, B `ZZ A1b <script>alert(1)</script>`, C `ZZ A1b <img src=x onerror=alert(2)>` and D `<i>T'&</i>`; each must appear exactly as typed, as text.

Group 1, masters:

- Grid Labels now `HttpUtility.HtmlEncode(Eval(...))`, as in A1a: Department (code, name, status), Decision Type (code, name, status), Designation (code, name, status), Subject Type (code, name, status), Member Type (code, name, scope, status), User (name, department, designation, email, role, login, status). The order and display-order numbers are unchanged. The User status label of the system account is still written by the code (already encoded), so it is not encoded twice.
- Duplicate-name check: the typed text has each `'` doubled in the RowFilter (Department, Decision Type, Designation and Subject Type name; User login), on Save and on Update. The check itself is unchanged (case-insensitive, same messages).
- Unchanged: Member Type has no duplicate check on the page; the edit boxes and dropdowns (encoded by the controls); every procedure.

Browser checks for group 1 on `BMMS_Test`, in Chrome and in Edge (deploy the build first; part 1 of the test script run; keep the error log of the day open):

1. Department, Decision Type, Designation, Subject Type, Member Type and User: the ZZ A1b row shows its text exactly as stored (`<b>x</b>` with its tags and not bold, `<script>...</script>` as text, the img text as text); no alert box, no broken image, no bold.
2. Edit on each ZZ A1b row opens the same text in the boxes. These rows cannot be saved again from the screen: their text holds `<`, so request validation stops the postback (the error page, and one error log entry with the field name and without the value, step E2); this is expected. The apostrophe Update is tested on the `ZZ O'Brien` rows of check 3: Edit, Update without changes gives the usual saved message (before this step that save went to the error page).
3. Department, Decision Type, Designation and Subject Type: Save a new row named `ZZ O'Brien` (any free code): saved. Save a second one named `zz o'brien`: refused with "Duplicate ... not allowed". User: Save a new user with login `zz o'brien` (role User, any department): saved; a second one with the same login is refused with "Duplicate Login User Id not allowed".
4. Delete the `ZZ O'Brien` rows of check 3: the delete confirm shows its fixed text, and the row is deleted.
5. User: Delete on `zza1b` gives "This user cannot be deleted because they have history: audit trail, backups." and the row stays.
6. Dropdowns show the names as text: User page Department (A) and Designation (B); Member page Designation (B); Agenda Entry Subject Type (A); Committee Member Member Type (B); Update Minutes Decision Type (C), when a meeting with minutes is at hand.
7. Every header of the six grids sorts ascending on the first click and descending on the second; the ZZ A1b rows keep their text after a sort.
8. Normal names (the seeded departments, designations and types, and a name with `&`) look as before.
9. No new error log entries, apart from one redacted request validation entry for each save of a ZZ A1b row tried in check 2.

Decision Type Master open to Controllers (decision of the Consultant, 2026-10-31): since the baseline the page hid the Add button and disabled Edit and Delete on every row for every role except Admin (an inline role check in DecisionType.aspx and `Enabled = false` in grvDecisionType_RowDataBound), although PageAccess.xml and the Master menu give the page to Admin and Controller. Both checks are removed, so the page behaves for Admin and Controller exactly like Department. Nothing else restricts it by role: spr_AddEditDecisionType receives no role (only the acting user id), spr_DeleteDecisionTypeByDecisionTypeId refuses only a decision type used by minutes, and other roles still get Access denied from PageAccess.xml.

Browser checks for Decision Type Master:

1. Signed in as a Controller: the Add button shows, and Edit and Delete are enabled (not grey) on every row.
2. As the Controller: Add `ZZ O'Brien` (any free code) saves; Edit it, Update without changes saves; Add a second `zz o'brien`: refused with "Duplicate Decision Type not allowed"; Delete `ZZ O'Brien`: the confirm shows, the row is deleted.
3. Signed in as Admin: the same as before (Add, Edit, Update, Delete).
4. Signed in as a Manager and as a User: opening `Master/DecisionType.aspx` by its address gives Access denied.

Group 2, committee, member and meeting:

- Grid Labels now `HttpUtility.HtmlEncode(Eval(...))`: Committee (code, name, status), Committee Member (committee, member, designation, member type), Member (code, name, designation, email, date of joining text), Meeting (meeting no, committee, place, venue, time), Meeting Member (meeting no, member, designation, member type), and the Dashboard meeting summary UserControl/MeetingSummary.ascx (committee, meeting no and time, in the scheduled and the completed list). Dates in `{0:dd-MMM-yyyy}`, the Yes/No and Active/InActive texts, the hidden MeetingId and the member photo address are unchanged.
- Committee: the duplicate-name check doubles each `'` of the typed name in the RowFilter, on Save and on Update, as in group 1.
- Unchanged: the edit forms, the dropdowns (encoded by the controls), the meeting mails (encoded since A1a), every procedure.

Browser checks for group 2 on `BMMS_Test`, in Chrome and in Edge (deploy the build first; smtp4dev running; keep the error log of the day open). Rows whose text holds `<` cannot be saved again from the screen (request validation, as in group 1 check 2); that is the expected result and is not repeated below.

1. Committee: the A901 row shows name A as text; Edit opens it with the same text. Add a committee named `ZZ O'Brien` (any free code): saved; Edit it, Update without changes: saved; Add a second `zz o'brien`: refused with "Duplicate Committee Name not allowed"; Delete `ZZ O'Brien`: the confirm shows, the row is deleted.
2. Committee Member: choose committee A901 (A in the dropdown, as text): the row shows member C, designation B and member type B as text; Edit opens the right member; Cancel.
3. Member: the A902 row shows name C and DOJ B as text, designation B as text; Edit opens with name C, Address1 A and DOJ B in the boxes; Cancel.
4. Dashboard, before check 5: the meeting summary lists the A901 meetings with committee A as text, meeting 2 (dated tomorrow, 10:00) under scheduled and meeting 1 (dated yesterday, time `<i>T'&</i>` as text) under completed, when the summary includes them (part 2 of the test script shows the rows).
5. Meeting Master: the A901 rows show committee A, place and venue (A, B, C) and the time of meeting 1 as text. Sort by a header, then on meeting 2 (522, tomorrow): Edit opens; change Place and Venue to `ZZ O'Brien & Sons`, Update: "Successfully Saved", the grid shows the new text, the mail arrives with the text as typed; sort again, Delete meeting 2: deleted (no members, no agenda items).
6. Meeting Master, meeting 1 (521, yesterday): Edit and Delete each give "The meeting date has passed, so this meeting can no longer be edited or deleted."; the grid is unchanged.
7. Meeting Member: choose committee A901 and meeting 1: the row shows meeting no, member C and designation B as text; Edit opens the right member; Cancel. Keep the row (the group 3 reports use it).
8. Dropdowns show committee A and member C as text on Committee Member, Meeting, Meeting Member, Attendance and Agenda Entry (committee), and on the report filters.
9. Every header of the five grids sorts ascending then descending; the ZZ A1b rows keep their text after a sort.
10. Normal names (the seeded committees and members, a name with `&`) look as before.
11. Error log: one Mail_Mgr entry only if a mail failed; one redacted request validation entry for each save of a ZZ A1b row tried; nothing else.

Test codes of the member and the committee (changed with group 3): part 1 first used ZZB1M and ZZB1C, and while those rows existed the Add pages of Member Master and Committee Master failed. spr_GetNextMemberCode and spr_GetNextCommitteeCode (baseline) take the highest code as text and convert the characters after the first one to a number (`SUBSTRING(MAX(MemberCode), 2, 4)`, `SUBSTRING(MAX(CommitteeCode), 2, 3)`); ZZB1M and ZZB1C sort above every M and C code, so they became the highest and the conversion failed. Part 1 now writes member A902 and committee A901 (one letter and digits; A sorts below M and C, so they never become the highest). Parts 2 and 3 take these two rows only when the name also starts with "ZZ A1b", and also find the rows of an earlier run under ZZB1M and ZZB1C. Part 1 stops when a real member A902 or committee A901 exists. The checks above now name A901 and A902. The two procedures are unchanged: any other code whose second character onward is not a number has the same effect (a later step).

Part 3 (and part 2) finds the test committee through its test code (A901 or ZZB1C) and either its test name or the tagged test member, because the committee name can be edited on screen (the name is the only text field of the Committee form, so it can be saved under a new name). Part 3 stops with "The test member is tagged to committee(s) ... that part 3 does not recognise as test committees" when the test member is tagged to a committee it does not recognise; its other refusals are unchanged.

Group 3, backup and reports:

- Grid Labels now `HttpUtility.HtmlEncode(Eval(...))`: Backup Database (file name, user name, IP address), Attendance Details (committee, meeting no, member, designation, attendance), Audit Trail (table, key field, key value, field name, updated by, updated on), Committee Master report (code, name, status), Meeting Calendar (committee name and code, meeting no, time, venue), Meeting Master report (committee, meeting no, time, venue), Sitting Fees Applicable (committee, meeting no, time, member type, member, designation, attendance, sitting fees) and Followup report (committee, meeting no, agenda no, subject no, department). Dates in `{0:dd-MMM-yyyy}` and the hidden ids are unchanged; the meeting time inside the server comment of the Followup report is not rendered and is left as it is; the Followup short text was encoded in A1a.
- bmms-workbench.css: the comment of the rule for grid buttons disabled by code now names the pages that still use it (Member Type, Meeting Member, User); Decision Type no longer does. The rule is unchanged.
- Unchanged: the filters, the PDF and Excel exports (encoded since A1a and U1b), every procedure.

Browser checks for group 3 on `BMMS_Test`, in Chrome and in Edge (deploy the build first; keep the error log of the day open). Rows from the first part 1 run use the old codes: run part 3 of the test script (it finds them), then part 1 again (new codes A902 and A901; new meeting ids, printed by part 1).

1. Member Master and Committee Master, Add: the form opens with the next code (M... and C...), no error page. Cancel.
2. Backup Database: the test row shows file name C, user name A and IP address B as text; sorting by every header keeps them as text.
3. Attendance Details: committee A901 (A in the dropdown), meeting 1: committee A, member C, designation B and the attendance as text.
4. Audit Trail: user "- All -" (or zza1b), today's date range: table ZZA1b, key value D (`<i>T'&</i>`), field name B and updated by A as text.
5. Committee Master report: committee A901 shows code A901, name A and the status as text; filter and sort keep it as text.
6. Meeting Calendar, a range covering yesterday and tomorrow: committee A (A901), meeting 1 with time D and venue C, meeting 2 with venue B, as text.
7. Meeting Master report, committee A901: meeting no, time and venue as text.
8. Sitting Fees Applicable, committee A901 and a range covering yesterday: committee A, meeting 1, time D, member type B, member C, designation B, attendance and 1000 as text.
9. Followup report: the test rows have no agenda item, so no ZZ row is listed; normal rows (committee, meeting no, agenda no, subject no, department) look as before. With the A1 test rows (BMMS-Test-StoredHtml-A1.sql) present, their short text still shows as text.
10. Every sort header of the eight grids sorts ascending then descending; the ZZ A1b rows keep their text.
11. Member Type, Meeting Member and User rows that may not be changed still show grey Edit or Delete buttons (CSS comment change only).
12. Normal names look as before. No new error log entries.

## Step S1: complete State_Master (what to run where)

dbo.State_Master held three rows: 1 TN Tamil Nadu, 2 AP "Andhra Pradash", 3 KE Kerala. The Member page State dropdown reads it through spr_GetStateMaster (Member.State_Id, used by View_Member and View_Meeting_Member, and by the Notice mail and PDF). No page maintains the table; it is filled only by script. State is optional on the Member page ("- Select -" is stored as NULL, step 5). Reset Database does not touch State_Master, so the rows below survive a reset.

Decision (Consultant, 2026-10-31): State_Id 1, 2 and 3 are kept; id 2 is named "Andhra Pradesh" and the code of id 3 becomes KL; the remaining 25 states and 8 union territories are added (AR Arunachal Pradesh, AS Assam, BR Bihar, CG Chhattisgarh, GA Goa, GJ Gujarat, HR Haryana, HP Himachal Pradesh, JH Jharkhand, KA Karnataka, MP Madhya Pradesh, MH Maharashtra, MN Manipur, ML Meghalaya, MZ Mizoram, NL Nagaland, OD Odisha, PB Punjab, RJ Rajasthan, SK Sikkim, TG Telangana, TR Tripura, UP Uttar Pradesh, UK Uttarakhand, WB West Bengal; AN Andaman and Nicobar Islands, CH Chandigarh, DD Dadra and Nagar Haveli and Daman and Diu, DL Delhi, JK Jammu and Kashmir, LA Ladakh, LD Lakshadweep, PY Puducherry); the dropdown lists the states by name.

`BMMS-Fix-StateMaster-S1.sql` (no USE line; runs on a database whose name starts with BMMS):

- Checks first and stops with nothing changed when one fails: the three columns exist, State_Code holds 2 and State_Name 40 characters, no other column needs a value, id 2 is "Andhra Pradash" or "Andhra Pradesh", id 3 is Kerala with code KE or KL, no other row has KL, no code or name is there twice, and spr_GetStateMaster can be handled (below).
- Then, in one transaction (SET XACT_ABORT ON, TRY/CATCH; any error rolls everything back with the message "The script failed and was rolled back completely, nothing was changed"): fixes id 2 and id 3 when not yet done; inserts each new row only when neither its code nor its name is there yet (ignoring case and spaces), with ids MAX(State_Id) + 1, + 2 ... in the order above (4 to 36 on a table holding ids 1 to 3; with IDENTITY_INSERT when State_Id is an identity column); a row whose code or name is already there is skipped and listed. On a database that holds other extra rows the new ids start after its own highest id, so ids can differ between databases; nothing in the code refers to an id above 3, and a restored database brings its own State_Master.
- spr_GetStateMaster: left alone when it already sorts by State_Name. Otherwise replaced (marker StateMaster-S1) by the same columns, in the same order and under the same names as SQL Server describes its result today, from dbo.State_Master ORDER BY State_Name; it is replaced automatically only when it has no parameter, no WHERE and no JOIN and every column comes from State_Master, else the script stops and shows its text. The old text is shown in the results and printed before the change.
- Prints what it fixed, inserted (id, code, name) and skipped (with the reason), whether the procedure was replaced, and the check below. Nothing is deleted. Safe to run twice: the second run reports 0 fixed, 0 inserted and the procedure left unchanged.

Step 0 on `BMMS_Test` (2026-10-31): State_Id INT identity, primary key PK_State (no unique key on code or name); State_Code and State_Name VARCHAR(50), NULL allowed; rows 1 TN Tamil Nadu, 2 AP Andhra Pradash, 3 KE Kerala; members: 7 with State_Id 1, 1 with no state, none with 2 or 3. spr_GetStateMaster already sorts by name, so the script leaves it unchanged. Its text, for reference:

```sql
CREATE PROCEDURE [dbo].[spr_GetStateMaster]
AS
BEGIN
    SELECT * FROM State_Master ORDER BY State_Name;
END
```

On the test copy (`BMMS_Test`), after a backup of it, in this order:

1. The step 0 query of the S1 plan (read-only): columns, keys, rows, the text of spr_GetStateMaster, and the members per State_Id. Keep the procedure text.
2. BMMS-Fix-StateMaster-S1.sql   (prints: id 2 fixed, id 3 fixed, 33 inserted with IDENTITY_INSERT as ids 4 to 36, 0 skipped, "spr_GetStateMaster already sorts by State_Name: left unchanged", "Check: 36 row(s)")
3. BMMS-Fix-StateMaster-S1.sql again   (prints: already fixed, 0 inserted, 0 skipped, procedure left unchanged, 36 rows)
4. The check query below, then the browser checks.

Then the same on `BMMS` (backup, step 0, the script once, the check query). No build or deploy is needed: no code changes.

Check (read-only):

```sql
SELECT COUNT(*) AS StateRows FROM dbo.State_Master;                                         -- 36
SELECT State_Code, COUNT(*) FROM dbo.State_Master GROUP BY State_Code HAVING COUNT(*) > 1;  -- no rows
SELECT State_Name, COUNT(*) FROM dbo.State_Master GROUP BY State_Name HAVING COUNT(*) > 1;  -- no rows
SELECT State_Id, State_Code, State_Name FROM dbo.State_Master WHERE State_Id IN (1, 2, 3); -- TN Tamil Nadu, AP Andhra Pradesh, KL Kerala
EXEC dbo.spr_GetStateMaster;                                                                 -- 36 rows in name order
```

Browser checks on `BMMS_Test` (keep the error log of the day open):

1. Member Master, Add: the State dropdown shows "- Select -" and then 36 entries in name order, from Andaman and Nicobar Islands to West Bengal; "Andhra Pradash" appears nowhere.
2. Add a test member with state Karnataka: saved; Edit shows Karnataka. Change to Andhra Pradesh, Update: Edit shows "Andhra Pradesh". Change to Kerala, then to Puducherry: each Update keeps the state chosen.
3. A member saved earlier with Tamil Nadu (7 on BMMS_Test): Edit shows Tamil Nadu; Update without changes saves and keeps it.
4. The member with no state: Edit shows "- Select -"; Update saves it still without a state.
5. Optional, Notice: tag the test member of check 2 to a committee with state Andhra Pradesh; Create PDF or Send Mail for one of its meetings shows "Andhra Pradesh". Untag the member afterwards.
6. Delete the test member of check 2 (or keep it for later tests). No new error log entries.

Rollback (nothing was deleted, so the rollback is small; or restore the backup taken before the script):

```sql
-- Members using a new state must be moved first (the key FK_Member_State_Master refuses the delete):
--   SELECT MemberId, MemberName, State_Id FROM dbo.Member WHERE State_Id > 3;
UPDATE dbo.State_Master SET State_Name = 'Andhra Pradash' WHERE State_Id = 2;
UPDATE dbo.State_Master SET State_Code = 'KE' WHERE State_Id = 3;
DELETE FROM dbo.State_Master WHERE State_Id > 3 AND State_Code IN ('AR','AS','BR','CG','GA','GJ','HR','HP','JH','KA','MP','MH','MN','ML','MZ','NL','OD','PB','RJ','SK','TG','TR','UP','UK','WB','AN','CH','DD','DL','JK','LA','LD','PY');
-- spr_GetStateMaster: nothing to roll back on BMMS_Test (left unchanged). Only on a database where the script printed
-- "spr_GetStateMaster replaced": run the old text it printed, with CREATE changed to CREATE OR ALTER.
-- The identity continues after 36; DBCC CHECKIDENT ('dbo.State_Master', RESEED, 3) after the delete makes the next id 4 again.
```

## Step SM1: Send Mail attachments, clearing and messages (code only, no database script)

Left over from step N1: every attachment upload on Send Mail deleted every file in `~/Files/Temp` (also `.gitkeep` and the attachment of another user's mail being written; a failed delete was ignored), and nothing was deleted after a send, so files stayed until the next upload. After a send every field and the attachment stayed, so Send sent the same mail again. The attachment's name was not shown. A failed send showed "Error: " and the exception text (a server path, SMTP or SQL text).

- Attachment file per mail: an upload is saved as one plain file `~/Files/Temp/<id>_<clean name>` (a new Guid per upload, 32 hexadecimal characters; the clean name of step N1). Send Mail creates and deletes no folder. The id and the name are kept in ViewState, not in a posted box (the hidden `txtAttachmentPath` is removed); before use the id is parsed as a Guid and the name reduced to a file name again, and the path is built from these two. A new file for the same mail deletes the file of the earlier one. After a successful send the file is deleted; after a failed send the attachment is kept so that Send can be pressed again.
- Clean-up: each upload first removes the files at the top of Temp whose creation and last write are both more than 24 hours old. `.gitkeep`, folders and anything younger are never touched. Every delete is a file delete; one that fails is written to the error log (SendMail / DeleteAttachment) and never stops the mail.
- Deleting a directory inside the application folder restarts the application and loses the in-process sessions; code must delete files, never directories, there. The Temp folder outside the application folder is part of step 27. (Found in the browser test of the first SM1 build, which kept each attachment in a folder of its own: after a Send with an attachment the next click went to the login page.)
- After a successful send: Committee back to "- Select -", Meeting No emptied (the meetings are not loaded again), To, Subject and the body emptied, the attachment removed. After a failed send everything stays.
- The attachment's clean name is shown, HTML-encoded, next to View once the file is attached. Mail_Mgr.SendWebEmail has a second form with the name the attachment shows; Send Mail passes the clean name, so the mail attachment carries it (not the stored `<id>_<name>`). The first form calls the second with no name, so the other mail pages are unchanged. The View link opens the stored file, so a browser download shows the `<id>_` in front.
- Mail_Mgr.FindInvalidMailAddress (new): checks the addresses by the rule of AddMailAddresses (comma or semicolon, blanks skipped) and returns the first one that is not valid. Used by Send Mail only; how mails are sent, and every other mail page, are unchanged.
- Messages: "The mail was sent." (was "Mail was sent to all members."); "The mail could not be sent. The error is in the error log." (the error text is no longer shown; Mail_Mgr logs it once as before); "Enter at least one mail address in To."; "This mail address is not valid: <address>. Correct it and send again." (the address encoded); "The attachment is no longer on the server. Attach the file again."; "The file could not be attached. The error is in the error log." (logged as SendMail / btnAttachment_Click; the earlier attachment of the mail stays); "The file is empty or was not received. Choose the file again.".
- Unchanged: the Committee and Meeting No loading (the slow Meeting No dropdown is a separate item), the recipient list from the meeting, the body cleaning of A1a, every procedure.

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; delete by hand, once, the 32-character folders the first SM1 build left in `Files\Temp`; smtp4dev running unless stated; keep the error log of the day and the folder `Files\Temp` of the site open):

1. Attach `a&b #1.pdf`: "View" and `a_b _1.pdf` appear; View opens the file. Temp holds one new file `<32 hexadecimal characters>_a_b _1.pdf` and no new folder; `.gitkeep` is still there.
2. Click View, then attach another file to the same mail: the name changes; the first file is gone, one file is left. Choose a Committee: you stay signed in.
3. Send with the attachment: "The mail was sent."; the mail's attachment is named `a_b _1.pdf` (no id in front). Committee shows "- Select -", Meeting No is empty, To, Subject, body, View and the name are gone; the file is deleted, `.gitkeep` stays. Choose a Committee and a Meeting: you stay signed in and To fills.
4. Send without an attachment: "The mail was sent."; the page is cleared; choosing a Committee keeps the session.
5. Two browsers, each signed in as a different Controller: each attaches its own file (one after the other, within a minute); both files stay; each View opens its own file; each sends its own mail with its own attachment; neither upload deleted the other's file.
6. Stop smtp4dev, send with an attachment: "The mail could not be sent. The error is in the error log."; To, Subject, body, View, the name and the file stay. One Mail_Mgr / SendWebEmail log entry; no server path or SMTP text on the page. Start smtp4dev, Send again: "The mail was sent.", the mail arrives with the attachment, the file is deleted, and the session is kept.
7. To empty (or only commas and spaces): "Enter at least one mail address in To."; nothing is sent, nothing is logged.
8. To holding a typed address that is not valid, for example `abc` or `x@` or `a@b.com, <b>bad</b>`: "This mail address is not valid: abc. Correct it and send again." (the address shown as text, `<b>bad</b>` with its tags); nothing is sent, nothing is logged. Correct it, Send: sent.
9. Attach a file, delete it in Explorer, Send: "The attachment is no longer on the server. Attach the file again."; View and the name are gone; nothing is sent.
10. Sweep: attach a file and leave the page; in PowerShell set that file's creation and last write time 25 hours back (`$f = Get-Item <file>; $f.CreationTime = $f.LastWriteTime = (Get-Date).AddHours(-25)`); also put a file `old.txt` at the top of Temp and set its times back the same way. Attach a file in a new Send Mail page: the old file and `old.txt` are gone; `.gitkeep` and the new file stay; a file younger than 24 hours is never removed (check 5). Choose a Committee: you stay signed in.
11. A file of 0 bytes: "The file is empty or was not received. Choose the file again."; an earlier attachment of the mail stays.
12. A Tamil or a Hindi file name: shown next to View, and the mail's attachment carries that name.
13. Committee and Meeting No fill To as before, and the page is not slower than before.
14. The other mail pages (Meeting Master save, Reset Password, Notice): their mails arrive as before.
15. Error log: only the entries named above; no check goes to the login page.

## Step M4: Agenda Entry, no new item after the meeting date; notice after the Agenda Submission Date (code only; test script for BMMS_Test)

Decision (Consultant, 2026-11-01): Agenda Entry refuses a new agenda item after the meeting date. The Agenda Submission Date is a provisional deadline and blocks nothing: an urgent item can be added at any time up to the meeting date. Before this step nothing checked a date when an item was added: the Controller's Meeting No list (spr_GetMeetingForController) offers every meeting of the committee whose minutes are open, past meetings included, and only the Users' and Managers' list (spr_GetMeetingForUsers) stops at the Agenda Submission Date.

- The rule of step M1 (MeetingMgr.IsMeetingOpenForChange): the whole meeting date counts, closed from the next day (web server date; the meeting time is not looked at); a meeting with no date is open.
- Add: after the agenda lock check, a meeting whose date has passed gives the warning "The meeting date has passed, so agenda items can no longer be added to this meeting." and the form does not open. A meeting with no date opens with an empty Date of Meeting (it failed in Convert.ToDateTime before).
- Save of a new item: the meeting is read again by its id, after the agenda lock check and before the mail, so a form left open past the meeting date cannot add; the same warning, no mail, nothing saved; the form closes as with every refusal. Update is not checked (steps M2 and M3).
- Notice: MeetingMgr.IsAfterAgendaSubmissionDate (new) is true from the day after the Agenda Submission Date. A new item saved then shows "Successfully Saved. This item was added after the Agenda Submission Date (dd-MMM-yyyy)." (shown as saved, never blocks). No notice on the submission date itself, before it, or for a meeting with no submission date. It is decided at Save, so a form left open over the deadline also gets it.
- The rule and the notice apply to every role that saves on Agenda Entry. PageAccess.xml lets Controller, Manager and User reach Agenda Entry and each has an add path; roles and PageAccess are unchanged. A User or Manager meets the notice only with a form left open, because their list hides a meeting after its submission date.
- Unchanged: the meeting lists (the Controller still sees past meetings with open minutes, to view and edit their items), Edit and Delete of an item, the agenda lock, the add procedures, the mail before the save (M2).
- The three add procedures (spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController) have no date rule of their own; the page is the only way to them (see Known items).

Test rows: `Database/BMMS-Test-AgendaDates-M4.sql` (BMMS_Test only; part 1 inserts committee A93 "ZZ M4 agenda dates" and meetings 00901 to 00907, part 2 moves 00907 to yesterday, part 3 shows, part 4 deletes; see its header). Part 1 reports a meeting it could not write when a date column does not allow NULL; skip that check.

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; run part 1; smtp4dev running; keep the error log of the day open; signed in as a Controller unless stated; committee "ZZ M4 agenda dates"):

1. Meeting 00901 (today, submission today): Add opens; Save gives "Successfully Saved" with no notice; the "Agenda Created" mail arrives.
2. Meeting 00902 (yesterday): still listed; Add gives "The meeting date has passed, so agenda items can no longer be added to this meeting."; the form does not open; no mail.
3. Meeting 00903 (no meeting date): Add opens with an empty Date of Meeting; Save gives "Successfully Saved", no notice.
4. Page left open: choose 00907 (today), press Add and fill the form; run part 2; press Save: the same warning, no mail, no new item in the grid (part 3 shows none for 00907).
5. Meeting 00904 (in 3 days, submission yesterday): Save gives "Successfully Saved. This item was added after the Agenda Submission Date (<yesterday>)." in green.
6. Meeting 00905 (in 5 days, submission in 2 days): saved, no notice. Check 1 covers the submission date itself.
7. Meeting 00906 (no submission date): saved, no notice.
8. Meeting 00902 stays in the Controller's Meeting No list and its grid opens (no items); the grid's sort headers work.
9. Signed in as a User and as a Manager: the Meeting No list of the test committee shows 00901 and 00905 only (00907 is gone after part 2; 00903 is listed only when part 1 gave it the submission date today); an item added to 00905 is saved as before ("Successfully Saved", the routing mail).
10. Run part 3: the items of checks 1, 3, 5, 6, 7 and 9, none on 00902 or 00907. Error log: no entry from these checks. Then run part 4.

## Steps M2 and M3: mail after the save on Agenda Entry, Dashboard Approve and Reject, and Agenda Finalisation (code only, no database script)

Found in the mail review after step M1: Agenda Entry sent the "Agenda Created" mail before saving, so a failed mail lost the new item and showed the mail error text, and a save the procedure refused still left a sent mail. Dashboard Approve and Reject ignored the mail result, and a failure while the mail was prepared ended on the error page after the change was saved (for the Controller's approval, before the subject number was given). Agenda Finalisation sent each "rejected" mail before the rejection was saved and ignored both results.

- Agenda Entry (M2), new item: the agenda lock, the meeting date (M4) and the route of step 20 (inactive Manager, no active Controller) are checked first; then the item is saved; the mail goes out only when the save succeeded. A refused save or a refused route sends no mail. When the mail fails, the warning "The agenda item was saved, but the mail could not be sent. The error is in the error log." and the grid shows the item; the M4 notice is added to either message when it applies. Update sends no mail, as before.
- Dashboard Approve and Reject (M3): the change is saved first, as before; for an approval the subject number is now given before the mail. When the mail fails, the warning "The item was approved, but the mail could not be sent. The error is in the error log." or "The item was rejected, but the mail could not be sent. The error is in the error log."; nothing is shown on success, as before.
- Agenda Finalisation (M3): each item not yet approved is rejected first; its mail goes out only when the rejection was saved. The message adds " n item(s) could not be rejected." and " n rejection mail(s) could not be sent. The error is in the error log." when they apply (for example "Agenda Finalized. 1 item(s) could not be rejected. 2 rejection mail(s) could not be sent. The error is in the error log.", a warning); "Agenda Finalized" when all went well. Finalisation goes on as before.
- Logging: a failed send is written once by Mail_Mgr (Mail_Mgr / SendWebEmail), as before. Each GenerateMail of the three pages now has the try/catch of Meeting Master: a failure while the mail is prepared is written once as Agenda / GenerateMail, DashBoard / GenerateMail or AgendaFinalization / GenerateMail, and the page shows its warning instead of the error page.
- Unchanged: the mail texts, recipients and Bcc, Mail_Mgr, every procedure and the database; Meeting Master, Reset Password, Notice and Send Mail (already handled in steps 24, M1, 28 and SM1).
- Not changed: Report/Followup and Report/FollowupActionTaken have Send Mail code that no button reaches (see Known items).

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; keep the error log of the day open; test rows as in the step report; first with smtp4dev stopped, then checks 1, 5, 6, 7 and 8 again with smtp4dev started):

1. Agenda Entry as a Controller, a new item: "The agenda item was saved, but the mail could not be sent. The error is in the error log."; the item is in the grid; one Mail_Mgr / SendWebEmail log entry; no SMTP text or path on screen.
2. The same as a User whose Manager is active and as a Manager: the same warning, the item saved. As a User whose Manager is inactive: the inactive-manager refusal, no item, no mail, no log entry.
3. Agenda Entry, a new item after the Agenda Submission Date (M4 meeting 00904): the warning followed by "This item was added after the Agenda Submission Date (...)."
4. Agenda Entry, Update of an item: "Successfully Saved", no log entry.
5. Dashboard, a Manager approves an item waiting for the Manager: "The item was approved, but the mail could not be sent. ..."; the alert of the item moves on to the Controllers; one log entry.
6. Dashboard, a Controller approves an item waiting for the Controller: the same warning; the item has its subject number in the Agenda Entry grid; one log entry.
7. Dashboard, a Manager rejects and a Controller rejects an item: "The item was rejected, but the mail could not be sent. ..." each time; the item shows Rejected; one log entry each.
8. Agenda Finalisation of a meeting with two items not yet approved: "Agenda Finalized. 2 rejection mail(s) could not be sent. The error is in the error log."; both items Rejected, the agenda finalized; two log entries.
9. With smtp4dev started: check 1 gives "Successfully Saved" and the mail arrives; checks 5 to 7 show nothing new and the mails arrive; check 8 gives "Agenda Finalized" and two mails. No log entries.
10. No check reaches the error page.

## Steps M5 and N4: no Edit or Delete of an agenda item after the meeting date; Finalisation keeps the text of a rejected item (code only, no database script)

Decisions (Consultant, 2026-11-01). M5: after the meeting date an agenda item can no longer be edited or deleted in Agenda Entry, for every role including the Controller; what is decided afterwards is recorded in the minutes. N4: Agenda Finalisation keeps the text of the items it rejects. Before these steps the Controller's Meeting No list (all meetings with open minutes) let the Controller edit and delete the items of a past meeting until the minutes were finalized, and Finalisation sent an empty Short Text and an empty Proposed Resolution with each rejection, which spr_UpdateAgendaByAgendaId wrote over the stored text (baseline behaviour).

- M5, the rule of steps M1 and M4 (MeetingMgr.IsMeetingOpenForChange): the whole meeting date counts, closed from the next day (web server date; the meeting time is not looked at); a meeting with no date is open.
- M5, Agenda Entry: the Edit (pencil) and Delete (trash) icons stay; on a click for an item of a past meeting the warning "The meeting date has passed, so agenda items can no longer be edited or deleted." and nothing opens or is deleted. Update checks again against the meeting date of the item as saved, read by the item's id (not the Meeting No list or the form), so a form opened before midnight cannot save; nothing is saved and no mail goes out. The meeting stays in the Controller's list and its grid still shows the items; the full text is in Agenda Details, Agenda Summary and the Agenda Approval PDF. Edit of an item of a meeting with no date opens with an empty Date of Meeting (it failed in Convert.ToDateTime before).
- M5, unchanged: Add (step M4, its message and behaviour), the agenda lock, the approval-status rules of Users and Managers, every procedure. Not changed, to be decided separately (M6): Dashboard Approve and Reject, Agenda Finalisation and Minutes Update still change items after the meeting date (see Known items); Minutes Update stays allowed, the decisions after the meeting are recorded there.
- N4, Agenda Finalisation: each item is read again by its id just before it is rejected, and its stored Short Text and Proposed Resolution are sent instead of empty values, so an edit made in another tab after the page was loaded is kept too. An item that no longer exists counts as "could not be rejected" (step M3). Unchanged: Controller Comments "Agenda rejected by Controller on agenda finalized.", the Rejected status, the Manager comments (not written by the Controller branch of the procedure), the mail and its data, the M3 order.

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; on the test day run part 4 and then part 1 of `Database/BMMS-Test-AgendaDates-M4.sql`; smtp4dev running; keep the error log of the day open; signed in as a Controller unless stated; committee "ZZ M4 agenda dates"). Before part 2: add one item as the Controller and one as a User whose Manager is active to 00907 (today; a User sees it because its submission date is today), one item as the Controller to 00901 and to 00903, and two items as that User to 00905.

1. 00901 (today): Edit opens; Update gives "Successfully Saved"; Delete of the item gives "Record Deleted Successfully".
2. 00903 (no meeting date): Edit opens with an empty Date of Meeting (no error page); Update and Delete work.
3. Page left open, Update: open Edit on the Controller's 00907 item, run part 2, press Update: "The meeting date has passed, so agenda items can no longer be edited or deleted."; the item is unchanged (part 3).
4. Page left open, Delete: show the 00907 grid, run part 2, press the trash icon and confirm: the same warning; the item is still there.
5. After part 2: 00907 is still in the Controller's list and its grid shows both items; the pencil and the trash give the warning on each item.
6. As the User, page left open: before part 2 choose 00907 and open Edit on the User's own item; after part 2 press Update: the same warning, nothing saved. (Checks 3, 4 and 6 need part 2 to run while their pages are open: open the three pages first, then run part 2 once.)
7. Add on 00907 after part 2: "The meeting date has passed, so agenda items can no longer be added to this meeting." (step M4, unchanged).
8. N4: Agenda Finalisation of 00905 with the User's two items not yet approved: "Agenda Finalized"; both items Rejected; in Agenda Entry both keep their Short Text and, in Edit as the Controller, their Proposed Resolution; Controller Comments "Agenda rejected by Controller on agenda finalized."; two rejection mails arrive.
9. N4, edit in another tab: in a fresh run (part 4, part 1, two User items in 00905), choose 00905 in Agenda Finalisation, then in another tab change an item's Short Text in Agenda Entry and save, then press Finalize: the changed Short Text is kept.
10. Error log: no entry from these checks; no check reaches the error page.

## Step M6a: Dashboard Approve and Reject closed after the meeting date (code only, no database script)

Decision (Consultant, 2026-11-01): after the meeting date the agenda area closes; what is decided afterwards is recorded in the minutes. Agenda Entry closed in steps M4 and M5; this step closes Dashboard Approve and Reject. Agenda Finalisation stays allowed after the meeting date while the minutes are open (late finalisation, no code change): it rejects the items still waiting, keeping their text (step N4), sends their mails (step M3) and creates the minutes rows of the approved items, after which Attendance and the minutes follow in the step 23 order.

- The rule of steps M1, M4 and M5 (MeetingMgr.IsMeetingOpenForChange): the whole meeting date counts, closed from the next day (web server date; the meeting time is not looked at); a meeting with no date is open.
- Dashboard, Approve and Reject: refused after the meeting date, checked against the item's own saved meeting date, after the finalized-agenda check and before anything is saved, with the message "The meeting date has passed, so this item can no longer be approved or rejected. It will be rejected when the agenda is finalized." Nothing changes, no subject number is given, no mail goes out. Past items stay in the alert list (not hidden).
- Not working as intended: the alert panel of an item of a past meeting opens as a normal panel (Approve, Reject and Close visible, the boxes editable, no message above it, no remove button); only pressing Approve or Reject is refused (see Known items).
- Unchanged: the alert lists, every procedure, Agenda Finalisation, Attendance, Minutes Update, Minutes Finalisation, Minutes Confirmation, Followup, Followup Action Taken and the reports.

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; on the test day run part 4 and then part 1 of `Database/BMMS-Test-AgendaDates-M4.sql`; before part 2 add, as a User whose Manager is active, two items to 00907 and have the Manager approve one of them, and add one User item to 00905; then run part 2; smtp4dev running; keep the error log of the day open):

1. As the Manager, open the alert of the User's pending 00907 item, then press Approve (and Reject): opens normally; refusal on press (the message; nothing saved).
2. As a Controller, open the alert of the Manager-approved 00907 item, then press Approve (and Reject): opens normally; refusal on press (the message; nothing saved).
3. Panel left open: as the Manager (or the Controller), open a 00907 item before part 2 is run, run part 2, then press Approve (and, on the other item, Reject): the message; the item's status and subject number are unchanged (part 3); no mail. Tested.
4. The User's 00905 item (a future meeting): the Manager approves and the Controller approves as before; the subject number is given and the mails arrive. Tested.
5. Late finalisation: Agenda Finalisation of 00907 after part 2: "Agenda Finalized"; both 00907 items Rejected with their Short Text and Proposed Resolution kept; the rejection mails arrive; their alerts leave the Controller's list (type ACR); Attendance of 00907 now opens. Tested.
6. Error log: no entry from these checks; no check reaches the error page. Tested.

## Step D1: meeting delete closed after the meeting date, the meeting's alerts removed (database script and code; test script for BMMS_Test)

Parked since step M1: spr_DeleteMeetingByMeetingId had no date rule of its own and left the meeting's alerts behind, so the Dashboard kept an alert of a meeting that no longer exists (shown since step F1 as "item gone").

- spr_DeleteMeetingByMeetingId (BMMS-Fix-MeetingDelete-D1.sql, marker MeetingDelete-D1), checked in this order under an update lock on the meeting row (UPDLOCK, HOLDLOCK):
  - Reason 4: the meeting does not exist.
  - Reason 20: the meeting date is before today, the database server date; dates compared as dates (the meeting time is not looked at), so it is open for the whole of its date; a meeting with no date is open. The same rule as Meeting Master (step M1), which uses the web server date.
  - Reason 21: the meeting has meeting members or agenda items (the two checks of the baseline, kept) or attendance (new). Attendance can exist without Meeting_Member rows: Attendance saves committee members (MemberOf 'C') of a meeting dated today or earlier, so a meeting dated today could have attendance and no members, and the baseline delete then failed on the Attendance foreign key. ReasonDetail names what was found, for example 'Members, Agenda items'. No minutes check: Minutes rows hang off Agenda rows, which are already refused.
  - Allowed: in one transaction (SET XACT_ABORT ON, TRY/CATCH) the Alert_User_Map rows of the meeting's alerts, then those Alert_Master rows (SourceType 'Meeting', SourceTypeId = the MeetingId: the "Meeting Created" (MC) and "Meeting Updated" (MU) alerts that spr_AddEditMeeting writes; no other code writes SourceType 'Meeting'), then the meeting. An error rolls everything back and is raised again (RAISERROR; no THROW at compatibility level 100).
  - Returns Result (1 deleted, 0 refused: the baseline column), Reason and ReasonDetail.
- Not touched: Agenda and Committee alerts (an Agenda alert's SourceTypeId is an AgendaId, and a meeting with agenda items cannot be deleted), Audit_Trail_Master, spr_UpdateAlertByMeetingId (Agenda alerts only), and the orphan Meeting alerts of meetings deleted before step D1: the script lists them and prints their count at the end, without removing them (5 on BMMS_Test and 1 on BMMS at step 0; see Known items).
- Meeting Master, Delete: shows the procedure's refusal: Reason 20 "The meeting date has passed, so this meeting can no longer be edited or deleted." (the M1 text, now MeetingChangeReason.MeetingDatePassedMessage), Reason 21 the existing "in use" message (delete_reference), Reason 4 "The meeting or member no longer exists. Reload the page.". An error is written to the error log (Meeting / Delete) and the page shows "The meeting could not be deleted. The error is in the error log." (it showed the "in use" message and logged nothing). The page check of step M1 is unchanged and still runs first.
- Day boundary: the page uses the web server date and the procedure the database server date (the same machine on BMMS_Test). If they differ, around midnight either the page refuses first, or the page lets the delete through and the procedure refuses with Reason 20, which shows the same message. Nothing that either side counts as past can be deleted. Reason 20 is therefore hard to reach from the browser: the page re-reads the meeting date before every delete.

What to run where (the Consultant runs the scripts):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (D1, shown as step 100, reads Missing).
2. `BMMS_Test`: BMMS-Fix-MeetingDelete-D1.sql. It prints "Step D1 installed" and the orphan Meeting alerts (count and list).
3. `BMMS_Test`: BMMS-Test-MeetingDelete-D1.sql part 1, part 2 (9 checks, all PASS; check 3 SKIPPED only when Meeting.MeetingDate does not allow NULL), part 3 (optional), part 4.
4. BMMS-Check-InstalledSteps.sql again: D1 reads Installed.
5. Deploy the build of step D1 (either order is safe: an older build reads only Result and shows the "in use" message for every refusal; the D1 build on the old procedure logs the missing Reason and shows "The meeting could not be deleted").
6. The browser checks below.
7. `BMMS`, after the backup: steps 2 and 4 (no test script on `BMMS`).

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; run part 4 if part 2 was run, then part 1 of `Database/BMMS-Test-MeetingDelete-D1.sql`; keep the error log of the day open):

1. As a Controller, the Dashboard lists "Meeting (A94-00901)". On Meeting Master, committee A94, Delete 00901 (today): "Record Deleted Successfully"; back on the Dashboard the alert is gone (no "item gone" warning).
2. Delete 00902 (yesterday): the M1 message; the meeting stays, its alert stays.
3. Delete 00903 (no date; not there when part 1 reported it skipped): deleted; its alert is gone.
4. Delete 00904 (agenda item), 00906 (attendance, dated today) and 00907 (meeting member): the "in use" message each time; nothing removed.
5. Error log: no entry from these checks; no check reaches the error page.
6. Part 3 shows the remaining meetings and alerts; then part 4.

## Step N5: Subject No 0 after Update in Agenda Entry (code only, no database script)

Fault (baseline): in Agenda Entry an Update of an item without a subject number stored 0 instead of leaving it empty, for every role. The Subject No box was empty, the page sent an empty string, and the INT parameter @SubjectNo of spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController turned it into 0, which their Update branch writes. The grid then showed 0, and for the Controller the box became editable on that item (it is editable whenever the saved value is not empty). A Controller who cleared the box on an approved item and pressed Update also replaced its number by 0. A stored 0 does not stop the number on approval: spr_GenerateSubjectNoByMeetingId takes MAX(SubjectNo) of the meeting's Controller-approved items plus 1 and never reads the item's own value.

- AgendaDB.cs (AddEditAgenda, AddEditAgendaByManager, AddEditAgendaByController): an empty Subject No is sent as NULL.
- Rule (Consultant, 2026-11-01): once the Controller's approval gives an item its Subject No, no role can change it from any route. The Subject No box is read-only in Agenda Entry for every Controller-approved item, for every role (the box of the User and the Manager was already read-only for every item). On Update the item is read again just before the save; when it is Controller-approved, its saved Subject No is used and the posted box text is ignored, whatever it contains, for every role (also when the item was approved on the Dashboard after the form was opened; the Update branches of the three procedures do not check the approval status themselves).
- Agenda Entry, Update of an item that is not Controller-approved: when the Subject No box is empty, the saved Subject No is used: NULL stays NULL, an old 0 stays 0 until the data step below. A number typed in the box (the Controller's box is editable only for such an item with a saved value, that is an old 0 row) is used.
- Unchanged: every procedure, Save of a new item (the Controller's Save gives MAX + 1 in the procedure; the box on Add stays editable, but the Save branches ignore its value), the Dashboard approval and the rule that gives the number on approval (spr_GenerateSubjectNoByMeetingId writes SubjectNo only for a Controller-approved item; a second Approve of an approved item is refused with Reason 14, so the number is not given again), which roles may open which item, and Delete.
- Routes that write SubjectNo: the Update branches of spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController (Agenda Entry, all covered above); the Save branch of spr_AddEditAgendaByController (the new item only); spr_GenerateSubjectNoByMeetingId (Dashboard Approve only); spr_UpdateSubjectNoByAgendaId (no page calls it). The Consultant checks the databases with `SELECT OBJECT_NAME(object_id) FROM sys.sql_modules WHERE definition LIKE '%SubjectNo%'`.
- Open question for the Consultant: whether a Controller-approved item may be deleted, and what happens to the gap in the numbering. Today the Controller can delete it (Delete is shown to the Controller only; spr_DeleteAgendaByAgendaId has no status check) and its number goes with it. Step N5 does not change Delete.
- A short timing gap remains; see Known items.

Browser checks on `BMMS_Test`, first round (passed before the rule above; check 5 is replaced by checks A to G) (deploy the build first; run part 1 only of `Database/BMMS-Test-AgendaDates-M4.sql`; all items in meeting 00905 of committee A93, meeting in 5 days, submission in 2 days; a User whose Manager is active, that Manager, and a Controller; after each step `SELECT AgendaId, SubjectNo, MgrApprovedStatus, ControllerApprovedStatus FROM Agenda WHERE MeetingId = <00905>`; keep the error log of the day open):

1. Item waiting: the User adds item 1 and presses Update without changes: Subject No empty in the grid, NULL in the table. The Manager opens it and presses Update: the same. The Controller opens it: the box is empty and read-only; Update: the same.
2. Approval: the Manager approves item 1 on the Dashboard, then the Controller: item 1 gets the next number (MAX + 1 of the approved items), shown in the grid.
3. Approved item, box cleared: the Controller opens item 1, clears the Subject No box, presses Update: the number is unchanged.
4. Approved item, other changes: the Controller changes only the Short Text of item 1 and presses Update: the number is unchanged.
5. Replaced by checks A to G below (with the rule above, check 3 now finds the box read-only).
6. Controller item: the Controller adds item 2: it gets MAX + 1 at once, as before.
7. Form left open: the User adds item 3. As the Controller, open item 3 in Agenda Entry (box empty) and leave the form open; in a second tab the Manager and then the Controller approve item 3 on the Dashboard; back in the first tab press Update: item 3 keeps the number it got on approval (before N5 it became 0).
8. The three old rows on BMMS_Test with Subject No 0 (AgendaId 384 and 685 rejected by the Controller, 683 waiting): they still show 0 in the grid. After the optional data step below they show an empty Subject No.
9. Error log: no entry from these checks.

Checks A to G, the rule above (same setup: meeting 00905 of committee A93, the same User, Manager and Controller, new items):

- A. Approved item: the User adds item "N5b one"; the Manager and then the Controller approve it on the Dashboard; it gets MAX + 1. The Controller opens it in Agenda Entry: the box shows the number and is read-only; Update without changes: the number is unchanged.
- B. Retest of check 3: the Controller opens "N5b one" and tries to clear the box: it cannot be cleared; Update: the number is unchanged.
- C. Retest of check 4: the Controller changes only the Short Text of "N5b one" and presses Update: the number is unchanged.
- D. Retest of check 7: the User adds item "N5b two". As the Controller, open it in Agenda Entry (box empty and read-only) and leave the form open; in a second tab the Manager and then the Controller approve it on the Dashboard; back in the first tab press Update: it keeps the number it got on approval.
- E. Forged value: the Controller opens "N5b one", removes the `readonly` attribute of the Subject No box with the browser's developer tools, types 99 and presses Update: the number is unchanged (the server does not take posted text for a read-only box, and the saved number is used for an approved item).
- F. Old zero rows, after the optional data step: AgendaId 384, 685 (rejected by the Controller) and 683 (waiting) show an empty Subject No in their meetings' grids. If one of them is opened, Update is refused when its meeting date has passed (step M5).
- G. Error log: no entry from these checks.

Optional extra test of the saved-number rule alone, `BMMS_Test` only (the box of an approved item is read-only, so check E cannot reach this rule by itself): the User adds item "N5b three". Before the Manager approves it, the Consultant sets its Subject No to 0 with one statement given inline (`UPDATE Agenda SET SubjectNo = 0 WHERE AgendaId = <AgendaId of N5b three>`, 1 row). As the Controller, open "N5b three" in Agenda Entry: the box shows 0 and is editable (not approved, saved value not empty); leave the form open. In a second tab the Manager and then the Controller approve it on the Dashboard (it gets MAX + 1; the stored 0 does not stop it). Back in the first tab type 99 and press Update: the number from the approval is kept, not 99.

Optional data step, `BMMS_Test` only (BMMS has no rows with 0), after the browser checks and only on the Consultant's go-ahead; the Consultant gives the statements inline (no script file): a read-only count of the rows with SubjectNo = 0 (expected 3: AgendaId 384, 683, 685, none approved by the Controller), then, in a transaction, SubjectNo = NULL for those rows (expected 3 rows), then check 8 again.

## Step N2: file names in Agenda Entry taken from the server, checked where they are read (code only, no database script)

Fault (baseline): Agenda Entry stored two file names exactly as the browser posted them: the hidden field hdnFilePath of each attachment row (joined with commas into Agenda.FilePath) and the hidden text box txtAgendaTextPath (Agenda.AgendaTextPath), through spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController. Any User, Manager or Controller who could update an item could change them with the browser's developer tools. Two readers then opened the stored value as a path: Agenda Approval (`MapPath("..\\Files\\AgendaText\\" + name)`, read as text into the PDF) could read any file inside the application folder, for example Web.config or a log; the Agenda Details report (`MapPath(folder) + name`, opened with PdfReader) could copy any PDF on the same drive into the report. A drive letter, a UNC path, a very long value or characters not allowed in file names made the PDF fail for everyone until the row was corrected. The uploads themselves were already safe (server-built path, cleaned name, step N1), and the links only go to the browser.

- SafeFileName.IsPlainName (BMMSBAL): true only for a bare file name: not empty, at most 255 characters, no character Windows does not allow in a file name (so no \ / : * ? " < > |, no drive letter, no UNC path), not `.` or `..`. Every name SafeFileName.Clean returns passes, Tamil and Hindi names included, and Clean never leaves a comma (it becomes _), so the comma list stays intact. A comma is allowed by IsPlainName, so agenda text names stored before step N1 keep working.
- Agenda Entry, Save and Update, every role: the attachment names come from the server's own list (ViewState, filled on Edit from the database and on each upload; the grid is bound from it row for row) for the ticked rows, and the agenda text name from the value the server set on Edit or upload. The posted hdnFilePath and txtAgendaTextPath are ignored. Add starts with an empty agenda text name (before, the name of an item opened earlier in the same page stayed in the hidden box and was stored with the new item). A saved name that is not a plain file name (old data) refuses the save: "An attached file name is not valid. Remove the file and attach it again."
- Agenda Details report (Reports.aspx.cs) and Agenda Approval (AgendaApproval.aspx.cs): a stored name that is not a plain file name is left out, one line goes to the error log (`Agenda <AgendaNo or AgendaId>: file name refused (FilePath or AgendaTextPath), left out of the PDF: <name>`, cut at 300 characters), and the rest of the PDF is built. Agenda Approval now passes `~/Files/AgendaText/<name>`. An Upload item with an empty agenda text name is also left out and logged (before, the PDF failed).
- Unchanged: every procedure, the uploads, the links on Agenda Entry and the Dashboard, Delete, and the other risks listed under Known items.

Stored names with path characters (read-only, run by the Consultant on each database; each row must be corrected or the file removed and attached again in Agenda Entry, which the refusal message says):

```sql
SELECT AgendaId, AgendaNo, MeetingId, AgendaType, AgendaTextPath, FilePath
FROM Agenda
WHERE CAST(AgendaTextPath AS NVARCHAR(MAX)) LIKE N'%[\/:*?"<>|]%'
   OR CAST(AgendaTextPath AS NVARCHAR(MAX)) IN (N'.', N'..')
   OR LEN(CAST(AgendaTextPath AS NVARCHAR(MAX))) > 255
   OR CAST(FilePath AS NVARCHAR(MAX)) LIKE N'%[\/:*?"<>|]%'
   OR N',' + CAST(FilePath AS NVARCHAR(MAX)) + N',' LIKE N'%,.,%'
   OR N',' + CAST(FilePath AS NVARCHAR(MAX)) + N',' LIKE N'%,..,%';
```

Browser checks on `BMMS_Test` (deploy the build first; run part 1 only of `Database/BMMS-Test-AgendaDates-M4.sql`; all items in meeting 00905 of committee A93; a User whose Manager is active, that Manager, and a Controller; small test PDF files a.pdf, b.pdf, c.pdf, t1.pdf, t2.pdf; after each step `SELECT AgendaId, ShortText, AgendaType, AgendaTextPath, FilePath FROM Agenda WHERE MeetingId = <00905>`; keep the error log of the day open; when this step was tested the committee was A903, so every item had an Agenda No ending in -001 (step N3, parked) and a second file of the same name got " (2)"; since step C1 the code is A93 and each item gets its own Agenda No):

Normal use (nothing may be lost):

1. Upload then Save: the User adds item "N2 one" (Entry), attaches a.pdf and b.pdf, presses Save: FilePath = `Attach-<AgendaNo>-a.pdf,Attach-<AgendaNo>-b.pdf,`.
2. Edit then Update without touching files: the User opens "N2 one", changes only the Short Text, presses Update: FilePath unchanged.
3. Upload then Update: the User opens "N2 one", attaches c.pdf, presses Update: the three names.
4. Untick one: the User opens "N2 one", unticks b.pdf, presses Update: a.pdf and c.pdf only (b.pdf stays in Files/AgendaAttach, see Known items).
5. Agenda text, then replace it: the User adds item "N2 two" (Upload), uploads t1.pdf, presses Save: AgendaTextPath = `<AgendaNo>-t1.pdf`. The User opens it again, uploads t2.pdf, presses Update: `<AgendaNo>-t2.pdf`. The View link opens the new file.
6. Manager and Controller Update: the Manager opens "N2 one" and presses Update; then the Controller opens it and presses Update: FilePath and AgendaTextPath unchanged each time.
7. Add after Edit: the User opens "N2 two" (Upload, t2.pdf), presses Cancel, then Add, and saves item "N2 four" (Entry, no file): AgendaTextPath and FilePath empty (before step N2 it got the agenda text name of "N2 two").

Forged and stored values:

- T1. Forged attachment name (User, "N2 one"): open it; in the developer tools set the value of the hidden input whose name ends in `hdnFilePath` (first attachment row) to each value in turn and press Update each time: `..\..\Web.config`, `C:\Windows\win.ini`, `\\server\share\x.pdf`, a value of 300 characters, `a<b>.pdf`, `x.pdf,..\y.pdf`. Expected: FilePath unchanged after each Update; no entry in the error log.
- T2. Forged agenda text name (User, "N2 two"): set the value of the hidden text box whose name ends in `txtAgendaTextPath` to the first five values above and press Update each time. Expected: AgendaTextPath unchanged; no entry in the error log.
- T3. Normal use: checks 1 to 7 above.
- T4. Bad stored value, readers (the Consultant runs each statement inline on `BMMS_Test` only):
  - Agenda Details report: the Controller adds item "N2 three" with attachment c.pdf (a Controller's item is approved at once; the report lists approved items only). Then `UPDATE Agenda SET FilePath = '..\AgendaText\<AgendaTextPath of N2 two>,' WHERE AgendaId = <AgendaId of N2 three>` (1 row). The Controller opens Reports, Agenda Details, committee A93, meeting 00905, PDF: the PDF opens without the pages of that file; one error-log line `... file name refused (FilePath) ...`.
  - Agenda Approval: code review only. The Create PDF button is never shown (the Print option is commented out in AgendaApproval.aspx and was in the baseline), so this reader cannot be reached from the screen; the check was verified by reading the code (AgendaApproval.aspx.cs, CreatePDF: IsPlainName, then one error-log line `... file name refused (AgendaTextPath) ...`).
  - Agenda text through Agenda Details (replacement test, done and passed): a Controller-approved Upload item in meeting 00905; its stored AgendaTextPath changed by inline SQL to `..\..\Web.config`; Reports, Agenda Details PDF generated again: the item's agenda text pages are left out, no Web.config text appears, one error-log line `... file name refused (AgendaTextPath) ...` is written.
- T5. Bad stored value, Agenda Entry (done and passed):
  - Controller: the Controller-approved item "N2 Three", whose stored FilePath is a bad name (`..\AgendaText\<a file name>`, from the Agenda Details test in T4). The Controller opens it and presses Update with no change: "An attached file name is not valid. Remove the file and attach it again." and no change in the table. Unticking the bad row and pressing Update gives "Successfully Saved" and FilePath is empty.
  - User: inline SQL `UPDATE Agenda SET FilePath = '..\x.pdf,' WHERE AgendaId = <AgendaId of N2 One changed>` (1 row) on the User's waiting item "N2 One changed"; this UPDATE replaces the whole stored list of attachments. The User opens it and presses Update with no change: the same message and no change in the table. Unticking the bad row and pressing Update gives "Successfully Saved" and FilePath is empty.

Part 4 of the M4 script removes the A93 items, meetings and committee; the uploaded files stay in Files/AgendaAttach and Files/AgendaText.

## Step AP1: Print option on Reports, Agenda Approval (code only, no database script)

Before: the page (Controller only, heading "Agenda Approval / Reject Report") showed only the list. The Print option was commented out in AgendaApproval.aspx since the baseline, so the Create PDF button was never shown. Its PDF would have printed every item of the meeting whatever its status (spr_GetAgendaByMeetingId is `SELECT * FROM View_Agenda WHERE MeetingId = @MeetingId ORDER BY AgendaStatusCode, SubjectNo`), and it read an uploaded agenda text (always a PDF file) as plain text.

- AgendaApproval.aspx: the Print option is back; View stays the default. Print shows the meeting venue, date and time and the Create PDF button once a committee and a meeting are chosen (the existing handlers).
- Create PDF prints only the items the Controller has approved (AgendaStatusCode ACA), filtered in the page; the list on View keeps every item. No approved item: "No approved agenda items for this meeting". The Tamil/Hindi refusal is unchanged and looks at the approved items only.
- An Upload item's agenda text file is added page by page (PDFUtilities.AddAgendaText, as in the Agenda Details report), after the step N2 name check; a refused name is still left out with one error-log line `file name refused (AgendaTextPath)`.
- The line "The agenda details opened in a new window ..." is hidden when the view format changes.
- Unchanged: the procedures, the layout of the PDF (no Subject No, no title, no attachments, no meeting date), every other page.

Browser checks on `BMMS_Test` (deploy the build first; run part 1 only of `Database/BMMS-Test-AgendaDates-M4.sql`; all items in meeting 00905 of committee A93; a User whose Manager is active, that Manager, and a Controller; small test PDF files a.pdf and t1.pdf; keep the error log of the day open; after each step `SELECT AgendaId, ShortText, AgendaType, AgendaStatusCode, AgendaTextPath, FilePath FROM Agenda WHERE MeetingId = <00905>`):

Items, part one (before test 4): the User adds "AP1 waiting" (Entry): AC. The User adds "AP1 manager" (Entry) and the Manager approves it on the Dashboard: AMA. The User adds "AP1 rejected" (Entry), the Manager approves it, the Controller rejects it on the Dashboard: ACR.

Items, part two (after test 4): the Controller adds "AP1 entry" (Entry, some rich text, a proposed resolution, attachment a.pdf) and "AP1 upload" (Upload, agenda text t1.pdf, a proposed resolution); a Controller's item is approved at once: ACA. Note the AgendaTextPath of "AP1 upload" for tests 6 and 7.

1. Page states (Controller, Reports, Agenda Approval): the page opens with View chosen. Choosing Print before a committee and a meeting are chosen shows nothing more. Committee A93, meeting 00905, View: the list shows every item with its status. Print: venue, date, time and Create PDF; the list is hidden.
2. Create PDF (after part two): the pop-up opens the PDF with "AP1 entry" and "AP1 upload" only. Each item starts on a new page with the logo (or organisation name), "Note to the <committee>", Agenda No, Meeting No, Department, the Short Text, the agenda text and "Proposed Resolution :". "AP1 entry": its rich text; no pages of a.pdf. "AP1 upload": the pages of t1.pdf, then the proposed resolution on the next page. No "AP1 waiting", "AP1 manager" or "AP1 rejected"; no Subject No. Error log: nothing.
3. The list still shows all five items: Print, then View again.
4. No approved item (after part one, before part two): Print, Create PDF: the message "No approved agenda items for this meeting"; no pop-up.
5. Tamil or Hindi: the User puts a Tamil word in the Short Text of "AP1 waiting" (Update): Create PDF makes the PDF. The Controller puts a Tamil word in the Short Text of "AP1 entry" (Update): Create PDF shows "Tamil or Hindi text cannot be printed correctly in a PDF; choose View on this page." and no PDF. Remove both words afterwards.
6. Bad stored name (the Consultant runs inline, `BMMS_Test` only): `UPDATE Agenda SET AgendaTextPath = '..\..\Web.config' WHERE AgendaId = <AgendaId of AP1 upload>` (1 row). Create PDF: the PDF opens; "AP1 upload" has no agenda text pages and no Web.config text; "AP1 entry" is complete; one error-log line `Agenda <AgendaNo>: file name refused (AgendaTextPath), left out of the PDF: ..\..\Web.config`. Then put the name back: `UPDATE Agenda SET AgendaTextPath = '<AgendaTextPath of AP1 upload noted before>' WHERE AgendaId = <AgendaId of AP1 upload>` (1 row).
7. Missing file (inline, `BMMS_Test` only): `UPDATE Agenda SET AgendaTextPath = 'AP1-missing.pdf' WHERE AgendaId = <AgendaId of AP1 upload>` (1 row). Create PDF: the standard error message bar, no pop-up, one entry in the error log (file not found). Then put the name back as in test 6.
8. Switch back: after a Create PDF, View: the list, without the line "The agenda details opened in a new window ..."; Print again: the panel without that line.
9. Other roles: the Manager and the User have no Agenda Approval entry under Reports; opening `Report/AgendaApproval.aspx` directly gives the access-denied page (PageAccess.xml).

Part 4 of the M4 script removes the A93 items, meetings and committee; the uploaded files stay in Files/AgendaAttach and Files/AgendaText.

## Step A2a: new rich-text editor on Agenda Entry and Update Minutes (code only, no database script)

FreeTextBox 3.2.2 is replaced in stages (A2a Agenda Entry and Update Minutes; A3 Dashboard, Followup and Send Mail; A4 FreeTextBox removed from the project). A2a keeps the layout and labels; the new layout is step A2b.

- New server control `BMMS.Controls.RichTextEditor` (`BMMS/RichTextEditor.cs`, tag `<bmms:RichTextEditor>`, registered in Web.config) with the members the pages already use (`Text`, `ReadOnly`, `Visible`, `Width`, `Height`) and `Label` (the name a screen reader reads). Script `JScript/RichTextEditor.js` and stylesheet `CSS/RichTextEditor.css`, loaded by Main.Master on every page. Our own editor on contenteditable: no third-party code, works offline.
- Toolbar: Bold, Italic, Underline, Bulleted list, Numbered list, Align left, centre, right, Justify, Undo, Redo. No Indent or Outdent buttons: Tab and Shift+Tab nest a list item or move it back out, inside a list only. Ctrl+B, I, U, Z and Y work as usual. No HTML view. The toolbar is a keyboard toolbar (Tab to reach it, arrow keys, Home and End to move, Enter or Space to apply); every button has a name and shows whether it is on.
- Paste: the pasted HTML is reduced in the browser to the allow-list of HtmlCleaner (paragraphs, line breaks, bold, italic, underline, lists, tables with colspan and rowspan, alignment). Word list paragraphs (the dot and number bullets) become real lists, with their levels; Excel ranges and Word tables stay tables. Pictures and files are not taken. The server cleans every value again, so the browser clean-up is a convenience, not the check.
- How the text travels: one hidden field per editor holds the HTML as Base64 of its UTF-8 bytes (`BMMSBAL/RichTextPost.cs`), so the post holds no markup and **request validation is on again** on Agenda.aspx and MinutesUpdate.aspx (`ValidateRequest="false"` removed). The server renders the cleaned text into the box and the same text into the field; the script replaces the field only after a real edit (typing, paste, drop or a toolbar action) and never serialises an untouched box. On the server every posted value is cleaned with `HtmlCleaner.Clean`; text that shows nothing (`HtmlCleaner.IsBlank`: an emptied box, `<p>&nbsp;</p>`, `<p><br /></p>`, a table of empty cells) is stored as empty text. The business layer cleans again before the procedures, as since step A1a. A value that is not Base64 of UTF-8 is refused like any other bad request (the safe error page and one error-log entry).
- Audit trail: an untouched Update posts back exactly the cleaned text, so a row saved after step A1a writes no audit row for an editor nobody changed. A row saved before step A1a (not yet in cleaned form) can write one audit row on its first save, the known step A1a behaviour.
- Read-only and hidden editors: shown without toolbar, nothing posted, any posted value ignored; their text is kept in view state, as FreeTextBox did. An editable, visible editor keeps its text only in the hidden field, so it is not sent twice. The Update Minutes "View Proposed Resolution" editor is now read-only (it was editable but never saved) (the panel cannot be opened from the screen; see Known items).
- Limits: `RichTextMaxChars` (one editor, default 200000) and `RichTextMaxTotalChars` (all editors of one page, default 600000) in Web.config `<appSettings>`, read by `BMMSBAL/RichTextLimits.cs`; a missing key or one that is not a positive whole number gives the default. They count characters of the editor's HTML (formatting tags included). The control writes them into the page; the script shows "The text is too long. Shorten it or attach the document as a file." under the editor and stops a post started by a button. The server checks again: Save or Update and the Attach and Upload agenda text handlers on Agenda Entry, and the Directions and Actual Resolution Save on Update Minutes, call `RichTextEditor.IsTooLong(this)` first and refuse the whole post with the same message (nothing saved, no file kept). The editor keeps the text that was typed.
- Unchanged: the code of steps N5, N2, M2, M4 and M5; AgendaValidation (it checks Subject Type and Short Text only; no rule reads an editor); Update Minutes accepts an empty Directions or Actual Resolution as before (no rule on the page or in spr_UpdateMinutes); every procedure; the display of stored text on every page (it was already shown through HtmlCleaner.Clean); the PDF, Word and Excel exports; the mails. FreeTextBox stays on the Dashboard, Followup and Send Mail until step A3 and in the project until step A4 (both done; see steps A3 and A4).

Settings to raise together with the limits. In the worst case (all Tamil or Hindi text) each character of an editor posts about 4.3 bytes (3 bytes of UTF-8, as Base64 and form-encoded). With the defaults the editors of one page post at most about 2.6 MB, inside the 4 MB request limit. If `RichTextMaxTotalChars` is raised, raise these together:

1. `<httpRuntime maxRequestLength="...">` in `system.web`, in KB (default 4096; not set in Web.config today). At least 4.3 x RichTextMaxTotalChars / 1024, plus 1024 KB for the rest of the page, plus the largest attachment allowed on Agenda Entry (the Attach and Upload agenda text buttons post the editor text in the same request as the file).
2. `<requestLimits maxAllowedContentLength="...">` under `system.webServer/security/requestFiltering`, in bytes (IIS default 30000000; not set today). At least maxRequestLength x 1024.
3. The UpdatePanel timeout: `AsyncPostBackTimeout` on the ScriptManager in `MasterPage/Main.Master`, in seconds (default 90; only Reset Database sets it today). It applies to Update Minutes (and to the Dashboard and Followup from step A3), where a large post on a slow link can run out of time.
4. `executionTimeout` on `<httpRuntime>`, in seconds (default 110; not applied while `compilation debug="true"`).

`RichTextMaxChars` above `RichTextMaxTotalChars` has no effect beyond the total: the total limit applies. The runtime copy has its own Web.config: add the two `<appSettings>` keys there when this step is deployed (without them the defaults apply).

Browser checks on `BMMS_Test`, each in Chrome and again in Edge (deploy the build first; run part 1 only of `Database/BMMS-Test-AgendaDates-M4.sql`; Agenda Entry items in meeting 00905 of committee A93; a User whose Manager is active, that Manager, and a Controller; keep the error log of the day open; after each Agenda Entry step `SELECT AgendaId, AgendaNo, ShortText, AgendaText, ProposedResolution, MgrComments, ControllerComments FROM Agenda WHERE MeetingId = <00905>`):

Test material: a Word document "A2 paste.docx" with the line "Paste test" in bold, a dot-bullet list of three items (One, Two, Three; Three indented one level with Tab in Word) and a 2 x 2 table (A1, B1 / A2, B2); an Excel sheet with the range A1:B2 filled with 1, 2 / 3, 4; the texts `கூட்டம் நிகழ்ச்சி நிரல்` (Tamil), `बैठक की कार्यसूची` (Hindi) and `₹ 1,250.00` (rupee sign); a.pdf for attaching.

1. Type and format (User, Agenda Entry, Add, 00905, Entry, Short Text "A2 typed"): in Agenda Text type "Bold Italic Underline" and make each word that style with the toolbar; Enter; a bulleted list "b1", "b2" (Tab on "b2" nests it, Shift+Tab moves it back); a numbered list "n1", "n2"; a line "Centred" aligned centre, a line "Right" aligned right, a line "Justified" justified; Undo and Redo once each. Proposed Resolution "Resolved." Save: "Successfully Saved". Reopen (Edit): the same formatting. AgendaText holds only p, b or strong, i or em, u, ul, ol, li, br, align. Error log: nothing.
2. Paste from Word (User, "A2 typed", Edit): copy all of "A2 paste.docx" and paste at the end of Agenda Text. The bold line stays bold; the three bullets show as a real bulleted list with Three one level in (if they stay paragraphs with dot characters, note it: Word list conversion is best effort); the table shows 2 x 2 with borders. Update. AgendaText holds `<ul><li>` items and `<table border="1" cellpadding="4" cellspacing="0">` with the four cells.
3. Paste from Excel (same item): paste A1:B2 into Proposed Resolution: a 2 x 2 table with 1, 2 / 3, 4. Update: saved as a table.
4. Tamil, Hindi and rupee sign (User, Add "A2 unicode"): type or paste each of the three texts on its own line in Agenda Text and in Proposed Resolution. Save; reopen: the same text, letters joined correctly. The Dashboard (Manager) and Reports, Agenda Details, View show the same text.
5. Script and markup (User, Add "A2 script"): in Agenda Text type `<script>alert(1)</script>` and `<b>x</b>`: they show and are stored as text (`&lt;script&gt;`), no alert. Copy from any web page a part with a picture and a link, paste: no picture, the link text without the link. Save: no alert at any time; AgendaText has no script, img or a. Then, in the developer tools, set the value of the hidden input whose name ends in `ftxtAgendaText` to `@@@` and press Update: the safe error page, one error-log entry ("could not be read"), nothing saved.
6. Plain-text box (User, Add "A2 lt"): Short Text `a<b`, Save: the safe error page (request validation, as decided); one redacted request validation entry in the error log; nothing saved. Short Text `5 < 6` saves normally.
7. Empty editor (User, "A2 typed", Edit): select all in Proposed Resolution and delete; Update: ProposedResolution is empty text (not `<p>&nbsp;</p>`). Type a space only and Update: still empty.
8. Untouched Update (User, "A2 typed", Edit, then Update with no change): no new audit row. Before and after: `SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = '<AgendaNo of A2 typed>'`; the count is the same. Then change one word in Agenda Text and Update: one new row (Field_Name AgendaText).
9. Text kept through an attachment and the Agenda Type switch (User, Add "A2 upload"):
    - 9a. Type "Kept text" in Agenda Text and Proposed Resolution, then attach a.pdf (the file is added at once): both editors still show "Kept text".
    - 9b. Choose Agenda Type Upload (Agenda Text is hidden, Proposed Resolution still shows "Kept text"), then Entry again: "Kept text" still in Agenda Text.
    - 9c. Choose Upload, upload a file that is not a PDF (for example a.txt) as agenda text: the message "Agenda text upload suppport pdf files only."; choose Entry again: "Kept text" still in Agenda Text.
    - 9d. With Entry chosen, Save; reopen "A2 upload": Agenda Text and Proposed Resolution both show "Kept text" and a.pdf is attached.
10. Hidden and read-only editors: the Manager opens "A2 typed", writes "Manager note" in Manager Comments, Update; the Controller opens it, writes "Controller note" in Controller Comments, Update; the Manager opens it again and presses Update: ControllerComments is still "Controller note" (the Manager does not see that editor). Update Minutes (test 12 meeting), View Proposed Resolution: shown without toolbar and not editable, no hidden field. (That a read-only editor ignores a posted value is checked by the scratch test.)
11. Agenda Entry rules unchanged: N5 checks 1 to 3, N2 checks 1 and 5 (step N2 section), an Edit of an item of meeting 00902 (yesterday) refused (M5), and a User's new item with its "Agenda Created" mail sent only after the save (M2). Results as in those steps.
12. Update Minutes, on the setup of `Database/BMMS-Test-MinutesEditor-A2.sql` part 1 (committee A92, meeting 00951; see below), as the Controller. For every decision type each row shows the Decision drop-down, the Agenda Short Text box and the Actual Resolution Edit button; there is no Directions editor and no Proposed Resolution view on this screen (see Known items).
    - 12a. Edit Actual Resolution of "ZZ A2 rich text" (it opens with the Proposed Resolution the agenda save copied into it): bold a word, add a bulleted list, paste the Word table, Save: saved (this also writes the item's Proposed Resolution, as before).
    - 12b. Stored text: `SELECT a.ShortText, mi.ActualResolution, a.ProposedResolution FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.ShortText LIKE N'ZZ A2 %' ORDER BY a.AgendaId;` "ZZ A2 rich text" has the cleaned HTML with the bold word, the list and the table, and ProposedResolution equal to ActualResolution.
    - 12c. Edit Actual Resolution of "ZZ A2 unicode": the Tamil, Hindi and rupee text, letters joined correctly; Cancel: nothing saved.
    - 12d. After partial postbacks (change one Decision drop-down, open and cancel Actual Resolution twice), Edit Actual Resolution again: the editor still formats, pastes and saves.
    - 12e. Read-only display: no read-only editor can be opened on Update Minutes; it is checked on Agenda Entry in test 10.
13. A form left open (User, Edit "A2 typed", change Agenda Text, wait 11 minutes: the session ends after 10), Update: the login page; nothing saved; no error-log entry.
14. Limits (the length is the editor's HTML; fill a box from the developer tools Console with `var b = document.querySelectorAll('.rte-box')[N]; b.focus(); document.execCommand('selectAll'); document.execCommand('insertText', false, 'x'.repeat(L));` (it replaces the box's text) where N is 0 for Agenda Text, 1 Proposed Resolution, 2 Manager Comments, 3 Controller Comments):
    - 14a. One editor over its limit (User, Add "A2 long"): N = 0, L = 200001. The message "The text is too long. Shorten it or attach the document as a file." shows under Agenda Text; Save does nothing (no post); choosing a file to attach does nothing either. Delete one character (200000): the message goes; Save: saved.
    - 14b. Page total over its limit (Controller, Edit "A2 long" (Entry), all four editors shown): fill each of the four with L = 160000 (each under 200000, 640000 together). The message shows under the editors; Update does nothing. Shorten one to 100000 (580000 together): the message goes; Update: saved.
    - 14c. Setting from Web.config: on BMMS_Test set `RichTextMaxChars` to `1000` (the application restarts), open Agenda Entry, N = 0, L = 1001: the message; L = 1000: none. Put back `200000`.
    - 14d. Setting not valid: set `RichTextMaxChars` to `abc`: behaves as 200000 (14a gives the message at 200001, not at 1001). Put back `200000`.
    - 14e. Server check: with 14a's 200001 characters, turn the browser check off in the Console with `var s = document.querySelectorAll('.rte')[0].rteState; s.max = 999999; s.maxTotal = 9999999;`, then Save: the page comes back with the same message at the top and under the editor, the text still there, nothing saved, no error-log entry. Choose a file to attach: the same message, no file added.
15. Keyboard and screen reader (User, Add): Tab from Agenda Type reaches the first toolbar button; arrow keys move along the toolbar, Enter applies; Tab moves into the box; Ctrl+B, Ctrl+I, Ctrl+U, Ctrl+Z, Ctrl+Y work. With Narrator: the toolbar is read as "Agenda Text formatting, toolbar", each button by its name and "pressed" when on, the box as "Agenda Text, edit".

Part 4 of the M4 script removes the A93 items with their alerts, audit rows and Minutes rows, the meetings and the committee; the uploaded files stay in Files/AgendaAttach and Files/AgendaText.

Test setup for Update Minutes (and, from step A3, Followup and the Dashboard action items): `Database/BMMS-Test-MinutesEditor-A2.sql`, `BMMS_Test` only, no USE line, one part at a time (select the part, F5). Every row goes through the procedures the pages use; nothing is written to a table directly. Set `@ControllerLogin` at the top of part 1 to the login of an active Controller with a department first.

- Part 1 creates committee A92 "ZZ A2 minutes editor" (3 characters: a 4-character code gives every item -001, step N3), members A921 (chairman), A922 (committee members) and A923 (meeting member), and two meetings dated today. 00951: three Controller-approved items with Subject Nos 1 to 3 (rich text with a list and a 2 x 2 table; Tamil, Hindi and rupee text; plain text), agenda finalised, chairman and attendance entered, minutes open and not yet updated. 00952: two items, both minutes updated (item 1 decision Followup), minutes finalised, one Pending action item mapped to every active user. One transaction; a refusal of any procedure rolls back everything and names the step and Reason. It refuses while rows of an earlier run exist (run part 3 first) and when a test code belongs to a row that is not a test row. It prints the ids, the Agenda Nos, the Subject Nos and the workflow state (expected 00951 `1,1,1,0/3`, 00952 `1,1,1,2/2` with minutes status F).
- Part 1b (optional) confirms the minutes of 00952 (spr_MinutesConfirmByMeetingId), for a page that lists confirmed minutes only.
- Part 2 (read-only) lists the committee, members, meetings with their workflow state, agenda items with their minutes, the action item with its mapped users, the alert and audit counts, and the Controller's Dashboard action list.
- Part 3 deletes, by id, every row of the test committee, its two meetings and the three members, including rows added in the browser tests on those meetings, and prints one count per table and "Rows of the test left anywhere: 0". Expected after part 1 then part 3 with no browser changes: ActionItem_User_Map = the number of active users, Action_Item 1, Attendance 6, Alert_User_Map as many as the alerts reached, Alert_Master 8 (committee 1, meetings 2, items 5), Audit_Trail_Master 35 (7 per item: the procedures in this repository write audit rows for agenda items only, Audit_Table Agenda, Key_Field AgendaNo; the committee, member, committee-member, meeting and meeting-member procedures write none, and part 3 also removes any row under those tables for the test codes and ids), Minutes 5, Agenda 5, Meeting_Member 2, Meeting 2, Committee_Member 2, Member 3, Committee 1. It refuses, deleting nothing, when a test code or name was changed on screen, or when another meeting of A92, a tag, chairmanship or attendance of a test member elsewhere uses the test rows.
- Seen by the other users of `BMMS_Test` until part 3 (accepted): the committee, meeting and agenda alerts, and the 00952 action item on every Dashboard.
- Run twice: part 1 refuses while the earlier rows exist; part 3 with nothing left says so. The meetings carry the date part 1 ran; for a fresh setup run part 3, then part 1.

## Step A3: rich-text editor on Dashboard, Followup and Send Mail (code only, no database script)

The nine FreeTextBox editors of these three pages become `BMMS.Controls.RichTextEditor` (step A2a): the same toolbar, paste, Base64 post, cleaning, read-only and view-state rules, and the same limits (`RichTextMaxChars`, `RichTextMaxTotalChars`). FreeTextBox stays referenced by the project and `bin/FreeTextBox.dll` stays until step A4 (removed in step A4).

- Dashboard (`DashBoard/DashBoard.aspx`), agenda panel: Agenda Text (always read-only), Proposed Resolution, Manager Comments, Controller Comments. Who may edit which editor is unchanged (the Controller: Proposed Resolution and Controller Comments; the Manager on an item waiting for the Manager: Manager Comments; read-only after the meeting date, step M6a). Approve and Reject save through spr_UpdateAgendaByAgendaId as before: the Manager's approval writes only MgrComments, the Controller's ShortText, ProposedResolution and ControllerComments.
- Dashboard, action item panel: Actual Resolution (read-only) and Action Text (editable for controller, manager and user; read-only for the other roles). Submit saves Action Text through spr_UpdateActionItem (code `ActionText`).
- Followup (`Master/Followup.aspx`): Action Text (Edit, Save) as before; Actual Resolution is now read-only (it was editable but never saved) and its popup header reads "View Minute Actual Resolution" (was "Edit Minute Actual Resolution").
- Send Mail (`Report/SendMail.aspx`): Body Text. The mail body is the editor's cleaned HTML (HtmlCleaner.Clean, the rich-text allow-list), sent as HTML in UTF-8 as before. The Page_Load line that copied the posted body back into the editor on every postback is gone (the control keeps its posted value). An empty body is still sent (no rule, as before).
- Request validation is on again on the three pages (`ValidateRequest="false"` removed), as on Agenda Entry and Update Minutes since step A2a.
- Too long: Approve, Reject and the action item Submit (Dashboard), Save of Action Text (Followup), Send Mail and choosing an attachment (Send Mail) check `RichTextEditor.IsTooLong` first. Over the limit nothing is saved or sent, no mail goes out and no file is stored; the panel stays open with the typed text, and the message shows at the top and under the editor. At most two editors are editable at once on these pages (2 x 200000 is below 600000), so only the limit of one editor can be reached.
- Closed panels keep no text: the Dashboard agenda panel clears its four editors after Approve or Reject is done, after Close (and its X) and after Delete; the action item panel clears its two editors after Submit, Close (and its X) and Cancel; Followup clears Actual Resolution on Cancel and Action Text on Cancel and after Save; an Upload item on the Dashboard clears the hidden Agenda Text. Nothing is cleared on an error, refusal or too-long path.
- Unchanged: every procedure; the mails of Approve and Reject (they carry no editor text); the Followup Submit (IsConfirmed only); the pages that show these texts (Agenda Entry, Agenda Approval PDF, Report/Followup) read them through HtmlCleaner.Clean as before.

Browser checks on `BMMS_Test`, each in Chrome and again in Edge (deploy the build first; smtp4dev running; keep the error log of the day open). Agenda alerts: run part 1 of `Database/BMMS-Test-AgendaDates-M4.sql` (meeting 00905 of committee A93, in 5 days); as a User whose Manager is active add "A3 approve" and "A3 reject" to 00905 on Agenda Entry, each with a formatted Agenda Text, a Word paste and Tamil, Hindi and rupee text in Proposed Resolution, and one Upload item "A3 upload". Action items and Followup: part 1 of `Database/BMMS-Test-MinutesEditor-A2.sql` (the Pending action item of 00952, committee A92, mapped to every active user). After each Dashboard agenda step `SELECT AgendaId, ShortText, ProposedResolution, MgrComments, ControllerComments, AgendaStatusCode FROM Agenda WHERE ShortText LIKE N'A3 %';`.

Limit tests fill an editor by its label (read-only editors come first on the Dashboard, so the index of A2a test 14 does not fit): `var b = document.querySelector('.rte-box[aria-label="<label>"]'); b.focus(); document.execCommand('selectAll'); document.execCommand('insertText', false, 'x'.repeat(L));` with the label Proposed Resolution, Action Text or Body Text. The browser check is turned off for the server check with `var s = b.closest('.rte').rteState; s.max = 999999; s.maxTotal = 9999999;`.

Dashboard, agenda alerts:

1. Manager approval (the Manager opens the alert of "A3 approve"): Agenda Text, Proposed Resolution and Controller Comments show their formatting, read-only, without toolbar. In Manager Comments make a word bold, add a bulleted list, paste from Word and type Tamil text; Approve: MgrComments is the cleaned HTML; ProposedResolution and ControllerComments unchanged; status AMA; the approval mail arrives.
2. Controller approval (the Controller opens the same alert): Proposed Resolution and Controller Comments editable, Manager Comments read-only. Change both, Approve: saved, status ACA, Subject No given, the mail arrives.
3. Blank save: the Manager approves "A3 reject"; the Controller opens it, selects all in Controller Comments and deletes, Reject: ControllerComments is empty text (not `<p>&nbsp;</p>`), status ACR.
4. Read-only cases: the User opens the alert of an own item: every editor read-only, no Approve or Reject. "A3 upload": Agenda Text hidden, the View link shown; open an Entry item next: its Agenda Text shows. After part 2 of the M4 script (00907 yesterday), an item of 00907 waiting for the Manager: read-only with the meeting-date message (step M6a).
5. Limits (run between tests 1 and 2: the Controller opens "A3 approve", waiting for the Controller; Proposed Resolution with L = 200001): the message shows under the editor; Approve, Reject, Close and X do nothing. Delete one character (200000): the message goes. Server check (L = 200001 again, the browser check off, then Approve): the message at the top and under the editor, the panel open with the text still there; status still AMA, nothing saved, no mail, no error-log entry. Reload the Dashboard and go on with test 2.
6. Partial postbacks: open an agenda alert and Close; open the action item and Close; change the page of a grid; open the agenda alert again: the editors still format, paste and save, and no text of the earlier item shows.

Dashboard, action items (the 00952 action item):

7. Controller: Actual Resolution read-only. In Action Text make a word bold, paste a Word table and type Tamil text; Submit. Open it again: the same text; Followup and Report/Followup show it too. `SELECT ActionItemId, ActionText FROM Action_Item WHERE ActionItemId = <id>;` gives the cleaned HTML.
8. Manager and User: Action Text editable; Submit saves.
9. Admin, mgmt or md_sect: Action Text read-only; Submit saves the shown text again (see Known items).
10. Limit: Action Text with L = 200001: the message; Submit, Close, X and Cancel do nothing; shorten and Submit: saved.

Followup (the Controller, then md_sect; committee "ZZ A2 minutes editor"):

11. Actual Resolution, View: the header "View Minute Actual Resolution"; the formatting shows, read-only, without toolbar; Cancel.
12. Action Text, Edit: make a word bold, paste from Word, paste Excel A1:B2, type Tamil, Hindi and rupee text; Save. Edit again: the same text; the query of test 7 gives the cleaned HTML.
13. Blank save: select all in Action Text and delete, Save: ActionText is empty text.
14. Limit: Action Text with L = 200001: the message; Save and Cancel do nothing; shorten and Save: saved.
15. Partial postbacks: after Cancel of Actual Resolution open Action Text, and after Save of Action Text open Actual Resolution and then Action Text again: the editors still format, paste and save, and each shows the text of the item it was opened for.

Send Mail (the Controller; To = an address smtp4dev receives):

16. Formatting and Unicode: in Body Text bold, italic and underline a word each, add a bulleted and a numbered list, paste a Word list and an Excel range, type Tamil, Hindi and rupee text. Attach a file: the body is kept after the attach postback. Send Mail: "The mail was sent."; the page is cleared. In smtp4dev the mail shows the formatting, the lists and the table, the Tamil and Hindi letters joined correctly; its HTML source has only the allow-list tags (p, br, b, strong, i, em, u, ul, ol, li, table parts) with align, colspan and rowspan: no `<script>`, `<style>`, `<img>`, `<a>`, no `on...=` or `class=` attribute.
17. Script and markup: type `<script>alert(1)</script>` and `<b>x</b>` in Body Text, send: the mail shows them as text (`&lt;script&gt;` in the source).
18. Empty body: the mail is sent with an empty body, as before.
19. Failed send (stop smtp4dev): "The mail could not be sent. The error is in the error log."; Body Text and the attachment kept.
20. Limit: Body Text with L = 200001: the message; Send Mail and choosing a file do nothing. Server check (the browser check off): Send Mail and choosing a file each show the message at the top and under the editor; nothing sent, no file stored, the text still there.
21. Request validation: Subject `a<b`, Send Mail: the safe error page and one redacted request validation entry in the error log; nothing sent. Subject `5 < 6` sends normally.

22. Keyboard (each page once): Tab reaches the first toolbar button of an editable editor; arrow keys move along it, Enter applies; Tab moves into the box; Ctrl+B and Ctrl+Z work. A read-only editor has no toolbar and is reached with Tab.

Results on `BMMS_Test`, 2026-11-04 (Chrome; the core tests repeated in Edge), all passed:

- Dashboard, agenda alerts (tests 1 to 6): Manager approve, Controller approve and reject, blank Controller Comments stored as empty text, the read-only cases, the limits in the browser and on the server, partial postbacks.
- Dashboard, action items (tests 7 to 10): Action Text editable and saved; read-only for mgmt.
- Followup (tests 11 to 15): passed.
- Send Mail (tests 16 to 21): the mail received in smtp4dev; `a<b` gives the safe error page and one redacted error-log line; `5 < 6` sends normally.

Part 4 of the M4 script and part 3 of the A2 script remove the test rows (the agenda items, their alerts and audit rows, the action item); smtp4dev keeps the test mails.

## Step A4: FreeTextBox removed from the project (code only, no database script)

Since steps A2a and A3 every editor is `BMMS.Controls.RichTextEditor`; FreeTextBox 3.2.2 is no longer used anywhere.

- The `<%@ Register Assembly="FreeTextBox" ... TagPrefix="FTB" %>` line is removed from the seven pages that still carried it: Master/Agenda.aspx, Master/MinutesUpdate.aspx, Master/AgendaFinalization.aspx, Master/Attendance.aspx, Master/MinutesConfirmation.aspx, Master/MinutesFinalization.aspx and Report/AttendanceDetails.aspx. The commented-out FreeTextBox tag of the Short Text popup on Update Minutes is removed too.
- BMMS.csproj: the FreeTextBox reference and the `Properties\licenses.licx` resource are removed. `BMMS/bin/FreeTextBox.dll` and `BMMS/Properties/licenses.licx` (it listed FreeTextBox only) are deleted from the repository.
- The comment of BMMSBAL/HtmlCleaner.cs and the list of third-party libraries in Documentation/Architecture/BMMS-Architecture.md name the own editor instead of FreeTextBox.
- Unchanged: every page's behaviour and every procedure; the other third-party DLLs under BMMS/bin and BMMSBAL/bin/Debug.

Deployment note: when a release is deployed later, the new BMMS.dll and all pages go together; the old FreeTextBox.dll in the target bin can then be deleted (leaving it does no harm). Check the target's own Web.config for a FreeTextBox entry.

Browser checks, from Visual Studio on the repository (FreeTextBox.dll is already gone there; if the Solution Explorer still shows the FreeTextBox reference, restart Visual Studio or reload the project first; keep the error log of the day open):

1. Pages that had the Register line open without an error page and without a new error-log entry: Agenda Entry (Controller, Manager, User), Update Minutes, Agenda Finalisation, Attendance (Admin or Controller), Minutes Confirmation, Minutes Finalisation and Report / Attendance Details (Controller).
2. One quick check on each page with an editor (bold a word, add a bulleted list, save, open again): Agenda Entry (Agenda Text and Proposed Resolution), Update Minutes (Actual Resolution), Dashboard (Manager Comments on an approval), Followup (Action Text), Send Mail (Body Text; the mail in smtp4dev shows the formatting).
3. Reports, Agenda Approval: the PDF of a meeting with an item that has formatted Agenda Text and Proposed Resolution opens and shows the formatting.

## Step A2b: card layout of Agenda Entry and Update Minutes (layout and CSS only, no database script)

The two pages take the Workbench look of the restyled master pages (`.wb-page`, cards, 40px fields, 44px buttons, the blue focus ring) plus one new stylesheet, `BMMS/CSS/bmms-forms.css`, loaded by these two pages only and scoped by `.bmms-form`. Colours are the `--bmms-*` properties of bmms-colours.css. No behaviour changes: every server control ID, handler, UpdatePanel, visibility and read-only rule, the editor limits and the code-behind are as before (the code-behind and designer files are not changed).

- Agenda Entry keeps its two screens. The list: title row (breadcrumb Agenda / Agenda Entry), a tinted meeting strip with Committee Name, Meeting No and Add, and the card "Agenda items in this meeting" (for a Manager or User with the line "Items of your department."; corrected in step C1: the list of a Manager or User shows only the items they entered, so a User now sees "Items you entered." and a Manager no line until step C2). The form: a tinted strip with Committee Name, Meeting No, Meeting Date, Agenda No and Subject No (read-only boxes; Subject No editable for the Controller as before), the cards "Item details" (Department, Subject Type; Short Text with its hint), "Agenda content" (Agenda Type, the upload of an agenda text file, Agenda Text, Proposed Resolution), "Files to be attached" (the list, Choose a PDF to attach, the hint on the 4 MB limit), "Comments" (Manager and Controller Comments side by side where both show; hidden when neither shows), and an action bar with Save and Cancel that stays at the bottom of the window.
- Agenda No of a new item shows "Assigned on Save". The hidden box keeps the value the code puts there (display: none, so it is no Tab stop and is still posted): the "Agenda Created" mail and the attachment file names read it; the stored number is worked out by the save procedure as before.
- Update Minutes: title row (Minutes / Update Minutes), a tinted strip with Committee Name, Meeting No and Update Minutes, the card "Decisions" (the same grid and columns, in the same order), and an action bar with Save minutes (was Submit) and Cancel, shown with the grid (Cancel was beside Update Minutes before). The Actual Resolution editor opens as before (Edit), now as a centred card over the dimmed page, with Save resolution (was Save), Close (was Cancel) and the hint "Saving the Actual Resolution also replaces the Proposed Resolution of this item." The three panels that cannot be opened (Directions, Short Text, Proposed Resolution) are unchanged.
- Grids: dark header row, light separators, scrolling inside their box on a narrow window. The Edit and Delete icons of the agenda list are 40px targets with the names Edit and Delete for screen readers; Delete still shows for the Controller only.
- Accessibility: a label (for=) on every field, Agenda Type as a fieldset, per-row names for the Decision list, the Short Text box and Edit on Update Minutes. Tab follows the new reading order (strip left to right, then the cards top to bottom); the set of fields is the same.
- Not shown on Update Minutes: the meeting date and an item count (they would need code or a new database call).

Browser checks on `BMMS_Test`, in Chrome and again in Edge (deploy the build; keep the error log of the day open). Agenda Entry: part 1 of `Database/BMMS-Test-AgendaDates-M4.sql` (meeting 00905 of committee A93), a User whose Manager is active, that Manager and a Controller. Update Minutes: part 1 of `Database/BMMS-Test-MinutesEditor-A2.sql` (committee A92, meeting 00951), as the Controller. Each visual check at about 1366 px wide, at 390 px (developer tools, device toolbar) and at 200% zoom.

1. Repeat of step A2a tests 1, 2, 7, 8, 9a to 9d, 10, 12, 14a, 14e and 15 on the new layout: the same results.
2. Role views of the form: the Controller (Department list, Subject No editable, Controller Comments on a new item, both comment editors on Edit, Delete in the list); the Manager (Department as text, Manager Comments only, no Delete); the User (no Comments card, no Delete).
3. Agenda No: a new item shows "Assigned on Save"; after Save the list shows the stored number; Edit shows the number; the "Agenda Created" mail still names an Agenda No.
4. Layout: cards stack on a narrow window; no sideways scroll of the page; the grids scroll inside their box; the action bar stays at the bottom of the window while the form scrolls and does not cover the last field; the message at the top is seen after a refused Save.
5. Accessibility: a click on each label puts the focus in its field; Tab follows the reading order; the blue focus ring shows on every field, radio, file box, button, icon and editor box; Edit, Delete and the radios are at least 40 px; a screen reader names the Agenda Type group, the Edit and Delete icons and each row's Decision list and Short Text box.
6. Update Minutes: the strip, the Decisions card and the action bar; Edit opens the centred card over the dimmed page with Save resolution, Close and the hint; Save resolution saves (step A2a test 12b); Close keeps nothing; a Decision change and Save minutes as before.
7. Other pages unchanged: Meeting, Committee and the Dashboard look as before.

## Step C1: comment editors by role on Agenda Entry and the Dashboard (code only, no database script)

Decision (Consultant, 2026-11-05): each comment editor is editable only by the role that writes it. Manager Comments: editable by the Manager only. Controller Comments: editable by the Controller only. Every other role that can see one (User, Admin, mgmt, md_sect) sees it read-only.

Found while planning (data loss before this step): Agenda Entry Update wrote both comment columns from the form, and spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController (step 31) write both columns as passed. A comment hidden from the role saving was posted empty, so a Manager's Update blanked the Controller comment (one the Controller had written on Agenda Entry before approving) and a User's Update blanked both. The Controller could also rewrite the Manager comment on Edit. A hidden editor that was not read-only also accepted a posted value (it is registered for post data even when hidden).

- Agenda Entry (Master/Agenda.aspx.cs): ApplyCommentRoles on New and on Edit makes Manager Comments read-only for every role but the Manager and Controller Comments read-only for every role but the Controller. Which panels show is unchanged (the Controller sees Manager Comments, read-only, on Edit; the User sees neither).
- Agenda Entry Save: only the acting role's comment comes from its editor; the other column is the saved value, read at save time (empty on a new item); the User keeps both saved values. The saved value passes through HtmlCleaner.Clean as every save does since step A1a; cleaning a clean text gives the same text, so a comment saved since A1a is written back unchanged.
- Dashboard (DashBoard/DashBoard.aspx.cs): a comment is editable only for its own role and only while Approve / Reject is shown (the only way to save it). Before, the Controller's comment was editable on every item, with nothing to save it. spr_UpdateAgendaByAgendaId already writes only the acting role's column (role read from Users), so Approve and Reject never touched the other comment.
- Dashboard, found in the C1 tests: the first version of this rule read `btnApprove.Visible`, and the Manager saw Manager Comments read-only on an AC item with Approve, Reject and Close shown (the Controller's comment on an AMA item likewise). Cause: the Visible getter of a WebForms control returns false while a parent is hidden, and lnkSource_Click hides pnlAgenda, calls BindAgendaDetails and shows pnlAgenda only after it returns (btnApprove sits in pnlAgendaControls inside pnlAgenda), so during the bind btnApprove.Visible always reads false although the button itself is set visible. Fix: BindAgendaDetails keeps a local `canDecide`, set true on the two lines that show Approve / Reject and false on every line that hides them, and the rule uses it. The M6a check and lnkSource_Click are unchanged, so test 6 stays as written. No other line in BindAgendaDetails or in what it calls reads Visible during the bind (the M6a check aside, see Known items; the editor reads its own Visible only when the view state is saved, after the panel is shown).
- Audit trail: the three agenda add / edit procedures write no comment audit rows; Approve and Reject write one for the acting role's comment only. A read-only comment gets no audit row.
- Unchanged: the markup, every procedure, Agenda Finalisation (its Reject text, see Known items), the visibility of the panels and the other fields of the Dashboard panel.
- Agenda Entry list (Master/Agenda.aspx, markup text only): the line under "Agenda items in this meeting" said "Items of your department.", but spr_GetAgendaByMeetingIdDeptId lists only the items the user entered (CreatedBy = @UserId). The User now sees "Items you entered."; the Manager sees no line until step C2 makes the Manager's list show the department's items. The Controller, as before, no line.
- Test committee of `Database/BMMS-Test-AgendaDates-M4.sql` renamed A903 to A93 (3 characters: a 4-character code gives every item -001, step N3). Run part 4 of the old file before the new one is used, or delete the A903 rows by hand: the new part 4 looks for A93 only.

Browser checks on `BMMS_Test`, in Chrome and again in Edge (deploy the build first; run part 4 and then part 1 of `Database/BMMS-Test-AgendaDates-M4.sql`, committee A93; a User whose Manager is active, that Manager and a Controller; keep the error log of the day open). After each step:

```sql
SELECT AgendaId, AgendaNo, ShortText, MgrComments, ControllerComments, MgrApprovedStatus, ControllerApprovedStatus, AgendaStatusCode
FROM Agenda WHERE ShortText LIKE N'C1 %' ORDER BY AgendaId;

SELECT Key_Value, Field_Name, New_Value, Update_By, Update_On FROM Audit_Trail_Master
WHERE Field_Name IN ('MgrComments', 'ControllerComments')
  AND Key_Value IN (SELECT AgendaNo FROM Agenda WHERE ShortText LIKE N'C1 %')
ORDER BY Update_On;
```

1. User: on Agenda Entry add "C1 entry" (Entry) and "C1 upload" (Upload, with an agenda text file) to 00905 and "C1 past" to 00907. No comment editor shows, on New or on Edit. Both comments of the three rows are empty.
2. Controller, then Manager, then User, on "C1 upload" before the Manager has acted: the Controller opens Edit (Manager Comments read-only, no toolbar; Controller Comments editable), types "C1 controller note" and presses Update: ControllerComments holds it, MgrComments unchanged, no new comment audit row. The Manager opens Edit (Manager Comments editable, Controller Comments not shown), types "C1 manager note" and presses Update: MgrComments holds it and ControllerComments is still "C1 controller note" (before this step it was blanked).
3. User Update: the User opens "C1 entry" after the Controller has written a Controller comment on it (as in 2) and presses Update with a changed Short Text: both comments unchanged (before this step both were blanked).
4. Dashboard: the Manager opens the alert of "C1 entry" (Manager Comments editable, Controller Comments read-only), approves with a Manager comment: one MgrComments audit row, ControllerComments unchanged. The Controller opens it (Manager Comments read-only, Controller Comments editable), approves: one ControllerComments audit row, MgrComments unchanged. On Agenda Entry the Controller's Edit of the approved item shows Manager Comments read-only; Update leaves MgrComments byte-identical and writes no comment audit row.
5. Forged post: as the Controller on Agenda Entry Edit, in the developer tools copy the hidden field of the Controller Comments editor, rename the copy to the name of the Manager Comments editor (`ctl00$ContentPlaceHolder1$ftxtManagerComments`, the UniqueID; check it in the page) and press Update: MgrComments unchanged. The same as the Manager against the Controller editor, and on the Dashboard with Approve (Manager against Controller Comments, Controller against Manager Comments): the other comment unchanged each time, no error page.
6. Past meeting: bring "C1 past" to AC (User item, Manager not yet acted), run part 2. As the Manager open its alert: Controller Comments read-only. The panel itself still opens with Approve / Reject shown (Known items, step M6a), so Manager Comments stays editable while they show; pressing Approve or Reject is refused with the meeting-date message and nothing is saved (both comments unchanged). As the Controller, open the alert: Manager Comments read-only; Controller Comments read-only too (no Approve / Reject on an item that is not AMA).
7. Upload postback: as the Manager on Edit of "C1 upload", attach a PDF (and replace the agenda text file) before Update: the typed Manager comment survives the postbacks and is saved; ControllerComments unchanged.

## Step H1: header stays visible above the popup panels (CSS and markup only, no database script)

Found in the C1 tests: when an Agenda Alert was opened on the Dashboard, only the "Agenda Alert" panel showed; the logo, the menu and the user name were gone. Nothing hid them: the popup panels use `.MyPopupOuter` (CommonHTML.css: `position: fixed; top: 0`, the whole window, z-index 10000) with `.MyPopupContent` filling it, and the Workbench header has no position or z-index, so the panel was drawn over it. The header wraps to more rows on a narrow window, so moving the panel down by a fixed height would not work.

- BMMS/CSS/CommonHTML.css: on the Workbench pages (`body.wb`) a popup covers the content area only: `#contentArea` is positioned while it holds a `.MyPopupOuter` (`:has()`, Chrome and Edge 105 and later, as in step A2b), at least 70% of the window high, and the popup is absolute inside it with the panel background (`--bmms-panel-bg`, was the grey #414141 of the old rule, which stays for pages outside `body.wb`). The header, and the footer below, stay visible; the panel keeps scrolling inside its own box; `box-sizing: border-box` keeps its 5px padding inside the width, so there is no sideways page scroll. The four popups that can be opened change this way: Dashboard Agenda Alert (pnlAgenda) and Action Item Details (pnlActionItemDetails), Followup Actual Resolution (pnlActualResolution) and Action Text (pnlActionText). The three old panels of Update Minutes use the same classes but cannot be opened (Visible = false on the server); the Actual Resolution card of Update Minutes (step A2b, `.bmms-modal`) and the Committee / Meeting alert of the Dashboard (an AJAX modal over `.modalBackground`) are unchanged.
- BMMS/DashBoard/DashBoard.aspx: the divs of pnlAgenda did not balance (the outer popup div was never closed, and an empty second `MyPopupOuter` div was nested inside it), so the browser placed pnlActionItemDetails inside pnlAgenda when both were rendered. The empty div is replaced by the missing closing div; all four popup panels now balance.
- Unchanged: every code-behind file (Approve / Reject, canDecide and the C1 comment editors included), the panels' content, the AJAX modal.

Browser checks on `BMMS_Test`, in Chrome and again in Edge, each at about 1366 px wide, at 390 px (developer tools, device toolbar) and at 200% zoom (deploy the build first, Ctrl+F5 so the new stylesheet is loaded; keep the error log of the day open). Setup: part 1 of `Database/BMMS-Test-AgendaDates-M4.sql` with the C1 items (an AC item for the Manager, an AMA item for the Controller, "C1 past" after part 2) and part 1 of `Database/BMMS-Test-MinutesEditor-A2.sql` (the Pending action item of 00952, mapped to every active user; Followup of committee A92).

1. Dashboard, Agenda Alert, as the Manager (AC item) and as the Controller (AMA item): the header shows the logo, the menu (it opens) and the user name with the role; the panel fills the content area below it, at the width of the other screens; a long panel scrolls inside its box; no sideways scroll of the page at 390 px; X and Close close it and the Dashboard lists show again. The C1 editor states are as in step C1 test 4.
2. Approve and Reject unchanged: the Manager approves the AC item and the Controller approves the AMA item (on another item, Reject): the panel closes, the status, the comments, the audit rows and the mails as in step C1 test 4.
3. M6a past-meeting alert ("C1 past"): the header stays visible; the panel opens as before (Known items, step M6a), pressing Approve or Reject is refused with the meeting-date message.
4. Dashboard, Action Item Details (the Pending action item of 00952): header visible; the panel scrolls inside; X closes it. Open an Agenda Alert and then the action item (and the reverse): each shows on its own, never one inside the other.
5. Followup (committee A92, the Pending action item): open Actual Resolution and then Action Text: header visible above each; the panel scrolls inside; Cancel closes it; Save of Action Text saves as before (Actual Resolution has Cancel only).
6. Unchanged: the Committee and Meeting alerts of the Dashboard (the centred box over the dimmed page); Agenda Entry and Update Minutes, including the Actual Resolution card and the action bar at the bottom of the window (step A2b); a Dashboard with no popup open (no extra height under the lists).
7. Error log: no entry from these checks.

## Step C2: a Manager sees the department's items on Agenda Entry; "Entered by" (database script step 33 and code; test script for BMMS_Test)

Decision (Consultant, 2026-11-06): on Agenda Entry a Manager sees, opens and updates the items of their department and the items they entered; a User only the items they entered; the Controller every item. Delete is for the Controller only. The list of every role shows who entered each item.

- spr_GetAgendaByMeetingIdDeptId (BMMS-Fix-ManagerDepartment-Step33.sql, marker ManagerDepartment-Step33), the list of every role but the Controller: an item of the meeting is listed when the user entered it (CreatedBy = @UserId, as before) or when the user's role is Manager (Roles.RoleCode 'manager') and the item's department is the user's department (Agenda.DepartmentId = Users.DepartmentId of @UserId). The department is the item's own: an item the Controller entered for the department is listed for its Manager. An item with no department is listed only for its creator. Every other role that reaches the page (the User; PageAccess.xml allows only Controller, Manager and User) keeps only its own items.
- spr_GetAgendaByMeetingId (same script and marker), the Controller's list and the list of Reports, Agenda Approval: the same rows as before.
- Both return every column of View_Agenda as before, in the same order, and EnteredByName at the end: the creator's User Name, "<name> (inactive)" for an inactive account, "(unknown user)" when no user row exists (FK_Agenda_CreatedBy of step 11 keeps a creator from being deleted). View_Agenda is not changed: six procedures select every column from it. Agenda Approval ignores the new column.
- The name is Users.UserName. On BMMS_Test 12 of 14 users have a User Name equal to their login, so the column shows the login until the names are entered on User Master (step N-names, planned).
- BMMS-Rollback-ManagerDepartment-Step33.sql restores both baseline texts (read from BMMS_Test before step 33). With the C2 build on the baseline procedures the "Entered by" column is empty (the page checks for the column) and the Manager's list holds only the Manager's own items; the page checks stay.
- Agenda Entry (Master/Agenda.aspx.cs), server checks by the rule of the list (CheckItemAccess): the Controller may open every item; a Manager the items whose Agenda.DepartmentId is the Manager's department, read from Users at the time of the check (not from the session or the form), and the items the Manager entered; every other role only the items it entered.
  - Edit: checked first, before the meeting-date and approval-status rules; refused with "You can open only the agenda items you entered." (User) or "You can open only the agenda items of your department and the items you entered." (Manager); the form is not opened. The id of Edit is the grid's command argument (server state), so this is a second line of defence.
  - Update: the id comes from the hidden field hdnAgendaId, which the browser can change. The saved item of that id is checked again (after the file-name and agenda-lock checks, before the meeting-date check); a refusal shows the same message and nothing is saved. An id that no longer exists is left to the procedure, as before.
  - Delete: refused for every role but the Controller with "Only the Controller can delete agenda items. Nothing was deleted.", before the meeting-date check. The button is shown to the Controller only (unchanged), so ASP.NET event validation normally refuses a forged Delete first (see test 6).
  - The Manager's Update (spr_AddEditAgendaByManager) keeps CreatedBy, DepartmentId and the statuses, so a Manager who updates a User's item does not become its creator.
  - Save of a new item by a User or a Manager: the department is the user's department in the user master (Users.DepartmentId), read at the time of the save, as the Edit check reads it; the posted hidden field hdnDepartmentId (filled by Add from the same value) is not used. When the posted value differs from it, or is not a number, the save is refused with "The department does not match your department. Nothing was saved." (after the file-name and agenda-lock checks, before the meeting-date and route checks): no row, no alert, no mail. Before, the posted value was saved as it came, so a forged value put the item into another department's list. This also refuses a save when an Admin changed the user's department between Add and Save; Cancel and Add again. The Controller keeps choosing the department from the drop-down. An Update by a User or a Manager never changes the department (spr_AddEditAgenda and spr_AddEditAgendaByManager do not write DepartmentId, as before; the posted value is still passed to them but is no longer an error page when it is not a number).
- Agenda Entry (Master/Agenda.aspx): the line under "Agenda items in this meeting" is "Items of your department." for the Manager, "Items you entered." for the User (unchanged), none for the Controller. New sortable column "Entered by" after Subject Type, the same position for every role, HTML-encoded. The table keeps its sideways scroll (minimum width 900 px); the name wraps between words and keeps at least 9em (BMMS/CSS/bmms-forms.css, `.bmms-col-person`).
- BMMS-Check-InstalledSteps.sql: step 33 (2 markers). The C1 Known item about the Manager's list is removed.
- Unchanged: the save procedures, the Dashboard, Agenda Finalisation, the approval-status rules on Edit, the meeting-date rules (M4, M5), the agenda lock, Add (it still fills the department box and hdnDepartmentId from the user master).

What to run where (the Consultant runs the scripts):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 33 reads Missing).
2. `BMMS_Test`: BMMS-Fix-ManagerDepartment-Step33.sql. It prints "Step 33 installed".
3. `BMMS_Test`: BMMS-Test-ManagerDepartment-Step33.sql (read-only, 8 checks; PASS, or SKIPPED where the data has no case: run it again after the browser setup below, when checks 5 and 7 have items).
4. BMMS-Check-InstalledSteps.sql again: step 33 reads Installed.
5. Deploy the build of step C2 (after step 2: on the old procedures the column is empty and the Manager still sees only their own items).
6. The browser checks below, then step 3 again.
7. `BMMS`, after the backup: steps 2 and 4 (no test script on `BMMS`), then deploy the build.
8. If step 33 must be undone: BMMS-Rollback-ManagerDepartment-Step33.sql, then BMMS-Check-InstalledSteps.sql (step 33 reads Missing).

Browser checks on `BMMS_Test`, in Chrome and again in Edge, at about 1366 px and at 390 px (developer tools, device toolbar). Deploy the build first; run part 4 and then part 1 of `Database/BMMS-Test-AgendaDates-M4.sql` (committee A93; meeting 00905 is in 5 days). Logins: Controller (Controller), mgruser (Manager, department 5), depuser (User, department 5, manager mgruser), creduser (User, department 4, manager credmanager), credmanager (Manager, department 4, User Name "Manager"), secuser (Manager, department 2). Keep the error log of the day open. After each step:

```sql
SELECT a.AgendaId, a.AgendaNo, a.ShortText, a.DepartmentId, u.LoginName AS EnteredBy, a.AgendaStatusCode, a.UpdatedOn, a.UpdatedBy
FROM Agenda a LEFT JOIN Users u ON u.UserId = a.CreatedBy
WHERE a.ShortText LIKE N'C2 %' ORDER BY a.AgendaId;
```

1. Setup on Agenda Entry, A93 / 00905: depuser adds "C2 dep", mgruser adds "C2 mgr", creduser adds "C2 cred", the Controller adds "C2 ctl" with Department the department of mgruser. The query shows four rows with those creators and departments 5, 5, 4, 5.
2. Lists: the Controller sees all four, no line under the title, a Delete button on each row. mgruser sees "C2 dep", "C2 mgr" and "C2 ctl" with the line "Items of your department."; not "C2 cred". depuser sees only "C2 dep" with "Items you entered.". credmanager sees only "C2 cred". secuser sees none of them. No Delete button for any of the Managers or Users.
3. "Entered by": after Subject Type for every role, showing the User Name of the creator (depuser, mgruser, User, Controller on BMMS_Test). Sort by it (ascending, then descending). At 390 px the table scrolls sideways inside its box, the page itself does not; the column is readable (a name is not squeezed to one word a line).
4. Edit and Update by the Manager: mgruser opens "C2 dep" (form opens, as for a Manager before C2 on their own item), changes the Short Text to "C2 dep by mgr" and presses Update: saved; the query shows EnteredBy still depuser, DepartmentId 5, UpdatedBy the id of mgruser. mgruser opens "C2 ctl": the existing message "This Agenda was Approved by Controller" (the Controller's own item is Controller-approved), the form does not open.
5. Forged Update: depuser opens "C2 dep" (Edit). In the developer tools find the hidden field `ctl00$ContentPlaceHolder1$hdnAgendaId` (the one outside the grid, next to the form; check the name in the page) and set its value to the AgendaId of "C2 mgr" from the query; press Update: "You can open only the agenda items you entered."; the query shows "C2 mgr" and "C2 dep" unchanged (UpdatedOn as before). The same as mgruser with the AgendaId of "C2 cred": "You can open only the agenda items of your department and the items you entered."; nothing changed. The same as credmanager with the AgendaId of "C2 dep": refused, nothing changed. (Not tested on purpose: the Controller may update every item, so a forged id would overwrite that item with the open form.)
6. Forged Delete: as mgruser, on the list, in the developer tools change the name of the Edit button of the "C2 dep" row from `...$grvAgenda$ctlNN$btnEdit` to `...$grvAgenda$ctlNN$btnDelete` (the same ctlNN) and click it. Expected: either the safe error page with one "Invalid postback or callback argument" entry in the error log (ASP.NET event validation: the Delete button was never rendered for mgruser), or the message "Only the Controller can delete agenda items. Nothing was deleted." (only if event validation is ever turned off). Pass in both cases when "C2 dep" is still there:
   `SELECT AgendaId FROM Agenda WHERE AgendaId = <id of C2 dep>;` (one row).
7. Forged department on a new item: depuser presses Add on A93 / 00905, enters Short Text "C2 forged dept", and before Save, in the developer tools, sets the hidden field `ctl00$ContentPlaceHolder1$hdnDepartmentId` (check the name in the page) to another department's id (4, Credit); press Save: "The department does not match your department. Nothing was saved."; the query shows no "C2 forged dept" row, credmanager's list does not show it, no "Agenda Created" mail goes out and no new alert:
   `SELECT COUNT(*) FROM Agenda WHERE ShortText = N'C2 forged dept';` (0).
   The same as mgruser (set 4): refused, no row. Then depuser presses Add again and saves "C2 dep 2" without touching anything: saved with DepartmentId 5 (the regular save still works). As the Controller, Add with the Department drop-down set to Credit: saved with DepartmentId 4 (the Controller keeps choosing).
8. Controller Delete unchanged: the Controller deletes "C2 cred" (confirm): "Record Deleted Successfully"; it is gone from the query and from credmanager's list.
9. Inactive creator (optional): as Admin, Deactivate depuser on User Master: mgruser's and the Controller's lists show "depuser (inactive)" for "C2 dep". Activate depuser again at once on User Master.
10. Reports, Agenda Approval, committee A93 / 00905: the list as before (no new column, no error).
11. Error log: no entry from these checks except the one of test 6 (when event validation refused it).
12. Run BMMS-Test-ManagerDepartment-Step33.sql again: checks 5 and 7 now PASS (they have items), the others PASS.

## Step UN-data: which users still have no real name (read-only check script, no change)

Decision (Consultant, 2026-11-06): Users.LoginName is the login ID (for example mgruser), Users.UserName is the person's actual name, and wherever a person or a role is shown the actual name appears. Most of the work is data: the Consultant enters the real names on User Master. On BMMS_Test (2026-11-07) 11 of the 14 users still have a User Name equal to their login (Controller's is also a role word), creduser has the role word "User" as its name, and credmanager already has a real name.

- BMMS-Check-UserNames.sql (read-only; on `BMMS_Test` and on `BMMS`). Result 1: the role words it compares against, every RoleName and RoleCode in Roles once each (also printed in the Messages tab). Result 2: one row per user (inactive users and the system account included) with UserId, LoginName, UserName, RoleName, DepartmentName, Active and Problem. Result 3: the number of users per problem, zero included, the users with at least one problem, and all users.
- The problems, separated by "; " when a user has more than one; every comparison ignores case and leading and trailing spaces:
  - blank name: the User Name is empty or spaces only (not compared further);
  - name equals login: the User Name is the login ID;
  - name is a role word: the User Name is a RoleName or a RoleCode of Roles (as Result 1 lists them; on BMMS_Test Admin, Controller, Management, Manager, MD Secretariat, User and the codes md_sect and mgmt);
  - duplicate name: another user has the same User Name;
  - duplicate login: another user has the same login ID (Users has no unique index on LoginName; User Master refuses a duplicate on save).
- Run it before and after entering the names; the aim is a blank Problem column for every user who uses the system.

## Step UN2 (names): header "Name | Role" with the login ID as tooltip; logged-in check by UserId; login ID in the access log (database script step 34 and code; test script for BMMS_Test)

The names series has the prefix UN (Consultant, 2026-11-07), so it does not clash with steps N2 (file names in Agenda Entry), N3 (agenda numbering), N4 and N5. Step UN-data comes first; the later name steps are separate: UN3 (Manager drop-down, Audit Trail, backup grid), UN4 (approver names on the comment captions), UN5 (mails) and UN6.

- Login (Default.aspx.cs): the session keeps UserId, UserName (the person's name, as before) and RoleName, and now also LoginName (Users.LoginName, the login ID).
- Header (MasterPage/Main.Master and MainNoMenu.Master): "Name | Role" as before (UserName | RoleName), with the login ID as the tooltip (title) of the name; both HTML-encoded. No "(inactive)" in the header: an inactive user cannot log in (Default.aspx.cs), and one deactivated while logged in is sent to the login page at the next request (PageAccessModule). The tooltip cannot be opened on a touch screen (see Known items).
- Logged-in check by UserId (Common.IsLoggedIn: the session holds a UserId above 0): PageAccessModule (every page), Common.InitSetup, Error/ErrorPage.aspx and Master/ResetDatabase.aspx. Before, these tested Session["UserName"], the name; a user with an empty name was then sent back to the login page on every page. The active-user check (by UserId) and the role check (by RoleCode) are unchanged.
- App_Data/PageAccessLog.txt: the user column is "Name (login)" (only the name for a session without a login ID).
- Access log, Audit_Trial_Login (BMMS-Fix-LoginName-Step34.sql, marker LoginName-Step34): new column Login_Name, VARCHAR(50) NULL. spr_RecordLoginByUserId, called after a successful login, closes the user's earlier rows and writes the new open row as before, and now writes the login ID into it, read from Users by @UserId inside the procedure. Its parameters are unchanged, so no C# change is needed for it and the build before step UN2 (names) keeps working. The rows from before step 34 (411 on BMMS_Test) stay NULL. The table has no name column, so none is kept or added.
- BMMS-Rollback-LoginName-Step34.sql restores the step 1 procedure and keeps the column with the login IDs already written; BMMS-Check-InstalledSteps.sql then reads step 34 Partly.
- BMMS-Check-InstalledSteps.sql: step 34 (the column and the procedure marker). Re-running step 1 (BMMS-Fix-Login-Procedures.sql) afterwards brings back the old procedure: step 34 reads Partly; run step 34 again.
- Header CSS (BMMS/CSS/bmms-workbench.css, `.wb-user-name`): `overflow-wrap: anywhere`, so a long name without a space breaks inside the word instead of pushing the page wider than the window (40 times W at 390 px measured in Edge: 517 px wide before, no sideways scroll after).
- Unchanged: a wrong password or an unknown login writes no row; logout and the end of a session (spr_AddEditAuditTrialLogin) close the user's open rows by User_Id; a second login of the same user works next to the first; no stored procedure other than spr_RecordLoginByUserId.

What to run where (the Consultant runs the scripts):

1. `BMMS_Test`: BMMS-Check-UserNames.sql (the problems as listed above).
2. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 34 reads Missing).
3. `BMMS_Test`: BMMS-Fix-LoginName-Step34.sql. It prints "Audit_Trial_Login.Login_Name added" and "Step 34 installed".
4. `BMMS_Test`: BMMS-Test-LoginName-Step34.sql (7 checks, all PASS; nobody logging in meanwhile).
5. BMMS-Check-InstalledSteps.sql again: step 34 reads Installed.
6. Deploy the build of step UN2 (names) (either order with step 3 is safe).
7. The browser checks below.
8. `BMMS`, after the backup: BMMS-Check-UserNames.sql, steps 3 and 5 (no test script on `BMMS`), then deploy the build.
9. If step 34 must be undone: BMMS-Rollback-LoginName-Step34.sql, then BMMS-Check-InstalledSteps.sql (step 34 reads Partly; the column stays).

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; keep the error log of the day and App_Data/PageAccessLog.txt open). After the login checks:

```sql
SELECT TOP 10 l.Audit_Trial_Login_Id, l.User_Id, l.Login_Name, u.UserName, l.Login_DateTime, l.Logout_DateTime, l.Login_Status, l.User_IP_Address
FROM Audit_Trial_Login l LEFT JOIN Users u ON u.UserId = l.User_Id
ORDER BY l.Audit_Trial_Login_Id DESC;
```

1. Names: as Admin on User Master, enter real names for mgruser and depuser. Run BMMS-Check-UserNames.sql: neither shows "name equals login" any more.
2. Header: log in as each of the 14 test users in turn (inactiveuser is refused with "Your account is inactive"). Each shows "<User Name> | <Role Name>"; mgruser and depuser show the new names; the tooltip of the name (hover) shows the login ID exactly as stored (for example `Controller` with a capital C). Alerts, Change Password and Logout work as before. The same on a page with MainNoMenu.Master (ChangePasswordFirst.aspx after a login with the default password, if one is at hand).
3. A name equal to the login (ituser): "ituser | User", tooltip "ituser".
4. Encoding: User Master refuses `<` (request validation), so set it by SQL: `UPDATE Users SET UserName = 'A&B <i>x</i> O''Neil "Q"' WHERE LoginName = 'ituser';` and log in as ituser: the header shows the text exactly, nothing in italics; View Source shows `A&amp;B &lt;i&gt;x&lt;/i&gt; O&#39;Neil &quot;Q&quot;` in the span. Then `UPDATE Users SET UserName = 'ituser' WHERE LoginName = 'ituser';`.
5. Layout at 390 px (device toolbar), 1105 px and 1366 px: the header as before. With long names: as Admin set the name of ituser on User Master to 40 letters with no space (for example `Venkataramanasubramaniancharlesvijayaram`), then to 40 times W, then to 50 characters with spaces; log in as ituser each time: at 390 px the name may take its own line (40 times W breaks inside the word) and the page does not scroll sideways; at 1105 and 1366 px one line. Restore the name.
6. Two users at once: Chrome as mgruser, Edge as depuser, an InPrivate window as Controller: each keeps its own name, role and lists after several clicks.
7. The same user twice (Chrome and InPrivate as mgruser): both work. The query shows two rows of mgruser with Login_Name `mgruser`: the first closed ('C', no logout time), the second open ('O'), as before.
8. Logout in one of the two windows: both rows of mgruser are closed ('C'; the open one gets a logout time), as before; the other window still works until its session ends.
9. A wrong password for mgruser, and an unknown login: "Invalid User Id / Password", no new row in the query (as before).
10. Session end: log in as depuser and leave the window for 10 minutes (the session timeout): the open row of depuser gets a logout time; Login_Name is `depuser`. The next click goes to the login page.
11. Deactivate while logged in: depuser logged in in Edge; as Admin deactivate depuser; in Edge click a menu item: the login page with "Your account is inactive. Contact the administrator."; activate depuser again.
12. Logged out: in a new InPrivate window open DashBoard/DashBoard.aspx, Error/ErrorPage.aspx and Master/ResetDatabase.aspx directly: the login page each time.
13. PageAccessLog.txt: as depuser type the address of a page the role may not open (for example Master/User.aspx): the new line carries "<name> (depuser)" as the user.
14. Error log: no entry from these checks.

## Step F1: footer version 1.1.0 from one place; database name for Admin and Controller (code only, no database script)

- Version: the footer line "BMMS 1.1.0, Board Minutes and Meeting Software. Copyright © 2026 Gashpy Software. All Rights Reserved." is built by Common.ProductFooter (BMMSBAL/Common.cs) from three attributes of the web assembly, BMMS/Properties/AssemblyInfo.cs: AssemblyInformationalVersion (the version, "1.1.0"; the one place to change it), AssemblyProduct and AssemblyCopyright. The text is the same as before apart from the number. Without AssemblyInformationalVersion the footer falls back to AssemblyVersion, three parts. The login page (Default.aspx), Main.Master and MainNoMenu.Master use it; no other page, report, PDF or mail carries a version.
- AssemblyVersion and AssemblyFileVersion of BMMS, BMMSBAL and BMMSDAL: 1.1.0.0.
- Database name: under the footer line, on its own line, "Database: <name>" for a logged-in user with RoleCode admin or controller only (Main.Master and MainNoMenu.Master, label lblFooterDatabase). For the other roles the label is not rendered at all. The login page, the safe error page, "Page not found" and "Access denied" have no database line; Error/ErrorPage.aspx sends a logged-out visitor to the login page first. No server name.
- The name is the database the server opened for the application's connection (ConnectDB.GetConnectedDatabaseName: SqlConnection.Database after Open), not the text of connectionStrings.config; HTML-encoded; read once and kept for the application's lifetime (Common.FooterDatabaseName). A change to connectionStrings.config restarts the application, so the new name shows after the switch.
- When the connection cannot be opened: one entry in the error log (class Common, method FooterDatabaseName), the footer shows the version line only, the page goes on; the next try waits 60 seconds.
- CSS (bmms-workbench.css, `body.wb div#footer`): `overflow-wrap: anywhere`, so a long name without a space breaks inside the word; `.wb-footer-db` on its own line.

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; keep the error log of the day open):

1. Logged out, login page: the footer line with 1.1.0; View Source has no "Database:".
2. Controller: Dashboard, Agenda Entry and a Dashboard popup: the footer line, then "Database: BMMS_Test". View Source: no server name.
3. Admin: Dashboard, User Master, Reset Database: the same as check 2.
4. Manager, then User: the footer line only; View Source has neither "Database:" nor `lblFooterDatabase`.
5. ChangePasswordFirst.aspx (MainNoMenu.Master), if a login with the default password is at hand: a User sees no database line, an Admin sees it.
6. Logged out, in a new InPrivate window: Error/ErrorPage.aspx (login page), /NoSuchPage.aspx ("Page not found"): no database line anywhere.
7. Admin, Error/ErrorPage.aspx opened directly: "Database: BMMS_Test" (logged-in user).
8. Switch: set `database=BMMS` in connectionStrings.config and log in as Controller: "Database: BMMS"; set `database=BMMS_Test` again: the login page footer shows no database line, and after login "Database: BMMS_Test".
9. Layout: as Admin, in DevTools replace the text of the `wb-footer-db` span with `Database: BMMS_Test_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_XYZ` (a 50-character name); at 390 px (device toolbar), 1105 px and 1366 px the footer wraps and the page does not scroll sideways (in the Console, `document.documentElement.scrollWidth <= window.innerWidth` is true).
10. BMMS/bin/BMMS.dll, Properties, Details: File version 1.1.0.0, Product version 1.1.0.
11. Error log: no entry from these checks.

## Step UN3: "Name (login)" where a specific account is chosen or recorded (code only, no database script)

Where a user is picked from a list or an action is recorded for audit, the account is shown as "Name (login)", for example "MohanKumar (mgruser)", with " (inactive)" added for an inactive account. Names are not unique; the login is. Everywhere else the name alone stays (grids, captions, mails: steps UN4 to UN6).

- One format (BMMSBAL/Common.cs, `Common.UserDisplayName(name, login, isActive)`): "Name (login)"; a name equal to the login in full ("admin (admin)"); a blank name gives the login alone, a blank login the name alone; " (inactive)" added. Plain text: a grid label encodes it with HttpUtility.HtmlEncode; a drop-down list encodes its item texts itself (encoding them again would show `&amp;amp;`).
- Pick lists (BMMSBAL/UserMgr.cs, `UserMgr.WithUserDisplayName`): the column UserDisplayName, sorted by name, then login (case ignored; a blank name sorts by its login). Two users with the same name stand next to each other, told apart by the login. The value of every list stays UserId, and no page logic reads the text: User.aspx.cs saves `ddlManager.SelectedValue` and reloads with `ddlManager.Text = ManagerId`; ResetPassword.aspx.cs reads `ddlLoginUser.SelectedValue` (and `.Text == "0"`, the selected value); AuditTrail.aspx.cs passes `ddlUsers.SelectedValue` to spr_GetAuditTrailMasterByUserId, which filters `WHERE Update_By = @UserId`.
- User Master, Reporting Person: the active Managers and Controllers of the department, plus the edited user's current manager even if inactive, as "Name (login)". The procedure's ManagerText column (login only) is no longer shown; the procedure is unchanged.
- Reset Password: label "User :" (was "Login Name :"); every user except the protected system account, inactive ones marked.
- Audit Trail: label "User :" (was "User Name :"); "- All -" first, then every user (inactive ones and the system account included). The column "Update By" shows "Name (login)" by Update_By, and "(unknown user)" when the user no longer exists (the same text as the Entered by column). The procedure's Update_By_Name (login only) is no longer shown.
- Audit Trail, header sort (finding F-2): a click on a column header sorted the rows and then read them again from the database, so the order was lost; the rows are now read only on opening the page and on Submit, and a header click sorts the rows already shown.
- Audit Trail (finding F-1): the list of users is no longer kept in ViewState. It was never read back, and View_Users carries the password hash, so every user's hash was written into the page's ViewState (encrypted and signed by ASP.NET, because the grid has DataKeyNames, so not readable in the browser; see step PW1). User Master kept its user list (spr_GetUserListForUserPage, with the hash) in ViewState the same way; removed in step PW1.
- Backup Database list: the column "Backup By" (was "User Name", the name alone) shows "Name (login)" by User_Id, inactive ones marked. A backup by a user that no longer exists is still not listed (the procedure joins Users).
- App_Data/PageAccessLog.txt: the user column uses the same format (`PageAccessModule.LogUser`); no visible change, except that a blank name gives "mgruser" and not " (mgruser)".
- Layout (BMMS/CSS/bmms-workbench.css): the user lists of Reset Password and Audit Trail (`select.wb-user-select`, was 150 px wide) take their column up to 360 px; the Reporting Person list already does (`.wb-page select`). A long text is cut in the closed list and never widens the page; the open list shows it whole. The grid cells (`td.wb-user-cell`) break a long name without a space inside the word.
- No stored procedure, table or view is changed: every list and grid already returns the user's id, and the names come from spr_GetUser. The build before step UN3 keeps working.

Who opens what: User Master, Reset Password and Backup Database: Admin and Controller. Audit Trail: Controller. Manager and User: "Access denied" on all four (unchanged).

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the build first; keep the error log of the day and App_Data/PageAccessLog.txt open). Test data, set by SQL before the checks and restored after them:

```sql
-- before: note the values
SELECT UserId, LoginName, UserName, ManagerId, AccountStatus FROM Users WHERE LoginName IN ('inactiveuser','depuser','ituser','mgruser');
UPDATE Users SET UserName = 'MohanKumar' WHERE LoginName = 'inactiveuser';             -- the same name as mgruser
UPDATE Users SET ManagerId = 105 WHERE LoginName = 'depuser';                          -- an inactive current manager
UPDATE Users SET UserName = 'A&B <i>x</i> O''Neil "Q"' WHERE LoginName = 'ituser';    -- special characters
-- after the checks
UPDATE Users SET UserName = 'Shravankumar' WHERE LoginName = 'inactiveuser';
UPDATE Users SET ManagerId = 12 WHERE LoginName = 'depuser';
UPDATE Users SET UserName = 'Gopinath' WHERE LoginName = 'ituser';
```

1. Admin, User Master, edit depuser, open Reporting Person: "- Select -", "MohanKumar (inactiveuser) (inactive)" (selected), "MohanKumar (mgruser)".
2. The same user: choose "MohanKumar (mgruser)", Save, edit depuser again: "MohanKumar (mgruser)" is selected; `SELECT ManagerId FROM Users WHERE LoginName = 'depuser'` gives 12.
3. Edit s20user (department 2): "RameshKumar (secuser)" and the other Managers and Controllers of department 2, sorted by name.
4. Controller: checks 1 and 2 again (set ManagerId = 105 again first): the same.
5. Reset Password (Admin, then Controller): label "User :"; sorted by name, then login; "MohanKumar (inactiveuser) (inactive)" before "MohanKumar (mgruser)"; "admin (admin)" and "sect (sect)" in full; the system account not listed; ituser reads `A&B <i>x</i> O'Neil "Q" (ituser)` as text, nothing in italics; View Source shows `A&amp;B &lt;i&gt;x&lt;/i&gt; O&#39;Neil &quot;Q&quot; (ituser)` in the option (encoded once). Choosing ituser fills the details box; a password reset of ituser works.
6. Audit Trail (Controller): label "User :"; "- All -" first, then the same sorted list with inactive users and the system account.
7. As Admin edit any department (save without change is enough if it writes a row; otherwise change and restore a name); as Controller, Audit Trail, today, user "admin (admin)", Submit: only Admin's rows; `SELECT COUNT(*) FROM Audit_Trail_Master WHERE Update_By = 5 AND Update_On >= CAST(GETDATE() AS DATE)` equals the number of rows; "Update By" reads "admin (admin)".
8. "- All -", a wider date range: each row shows its user as "Name (login)". Click "Update By" twice: ascending, then descending, and the rows stay the same rows (finding F-2); the other headers sort as well.
9. The same name: "MohanKumar (mgruser)", Submit: only rows with `Update_By = 12`; none of inactiveuser.
10. Unknown user, if the database has such rows: `SELECT TOP 5 a.Update_By, a.Update_On FROM Audit_Trail_Master a LEFT JOIN Users u ON u.UserId = a.Update_By WHERE u.UserId IS NULL ORDER BY a.Update_On DESC`; a row of that date reads "(unknown user)".
11. View Source of Audit Trail: the __VIEWSTATE is shorter than before (no user list in it).
12. Backup Database: Controller makes a backup: the new top row shows "Venkat (Controller)" under "Backup By"; a click on the header sorts by it.
13. Layout: set ituser's name to 50 characters without a space by SQL (for example `UPDATE Users SET UserName = REPLICATE('W', 50) WHERE LoginName = 'ituser';`, then restore 'Gopinath'). Reset Password and Audit Trail (and an Audit Trail row of ituser) at 390 px (device toolbar), 1105 px and 1366 px: the closed list may cut the text at 390 px, the open list shows it whole; the grid cell breaks inside the word; the page never scrolls sideways (Console: `document.documentElement.scrollWidth <= window.innerWidth` is true).
14. Manager (mgruser) and User (depuser): User Master, Reset Password, Backup Database and Audit Trail opened directly: "Access denied" each time.
15. PageAccessLog.txt: the line of check 14 reads "MohanKumar (mgruser)" as before.
16. Error log: no entry from these checks.

## Step G1: the User Master grid stays inside its card (CSS only, no database script)

The User Master grid was about 26 px wider than its card at every window width from about 1232 px up, so the Delete column was cut off and the grid scrolled sideways. The window width does not matter: `#contentArea` is at most 1200 px wide (`--wb-content-width`), so the grid box is 1166 px at 1366 px and at 1900 px alike. With one-line headings (`white-space: nowrap` on every grid heading) the 11 columns need at least 1191 px.

- BMMS/CSS/bmms-workbench.css, after `.wb-page table.wb-table-wide`: the headings of the User Master grid only (`#ctl00_ContentPlaceHolder1_grvUser > tbody > tr > th { white-space: normal; }`) may take two lines. Measured at 1366 px and 1900 px with the BMMS_Test rows: 26 px over before, fits after (Edit 55, Deactivate 99, Delete 72 px wide, all inside the card); the heading row grows from 41 to 61 px; Department Name, Designation Name and Login / User ID take two lines; the data rows are unchanged (49 to 62 px, as before).
- Why only User Master: the other grids with `wb-table-wide` (Agenda Entry, Committee Member, Meeting, Member, Update Minutes) fit today. With the rule on all of them, their headings would wrap as well, because many date and number columns are as narrow as their data (`wb-col-action`, width 1%) and a heading that may wrap no longer holds them wider: Meeting's "Agenda Submission Date" would take three lines and its heading row 81 px; Committee Member and Update Minutes would get a heading row 20 px taller for no gain. Measured on the same copies, these five grids are unchanged by step G1.
- The selector is the grid's rendered client ID (`clientIDMode="AutoID"` in Web.config: the master page `ctl00`, `ContentPlaceHolder1`, `grvUser`). If grvUser, the content placeholder or the master page is renamed, check the ID in View Source and change the selector.
- Sort arrows (all grids): the arrow after a sorted heading is now added after a no-break space (`"\00A0\25B2"`, `"\00A0\25BC"`; was a normal space), so on a heading that wraps it stays on the line of the last word and never stands alone on a line. On one-line headings nothing changes (the same width).
- How it was measured: copies of the six grids with the real stylesheets, the Public Sans font and the BMMS_Test rows of their procedures (View_Users; spr_GetAgendaByMeetingId meeting 516; spr_GetCommitteeMemberByCommitteeId committee 97; spr_GetMeetingByCommitteeId committee 116; spr_GetMember; spr_GetMinutesByMeetingId meeting 514), in headless Edge at 1366 px and 1900 px. Copies, not the live pages, and few rows: longer data can change the widths.
- No .aspx, .cs or database change.

Browser checks on `BMMS_Test`, in Chrome and in Edge (deploy the CSS first and reload with Ctrl+F5):

1. User Master at 1366 px: the Delete column is wholly inside the card and there is no sideways scroll bar under the grid; Department Name, Designation Name and Login / User ID take two lines.
2. User Master at 1900 px: the same as check 1 (the card is 1200 px wide at both widths).
3. A wrapped heading sorts: on User Master click "Designation Name": the rows sort A to Z and ▲ stands after "Name" on the second line, not alone; click again: Z to A and ▼ in the same place.
4. One-line headings: click "Status", then "Email Id": the arrow stays on the heading's line, as before.
5. The other five grids look exactly as before, at 1366 px and at 1900 px: Agenda Entry (a meeting with items), Committee Member (a committee with members), Meeting (a committee with meetings), Member, and Update Minutes (a meeting with minutes). Each heading on one line, the heading row as high as before, no new sideways scroll bar; click a heading to sort and the arrow shows after it as before; Edit and Delete work.
6. A narrower window (about 1100 px): every grid still scrolls inside its own card, as before step G1.

## Step PW1: no password hashes in the User Master ViewState (code only, no database script)

Finding F-1 of step UN3. User Master keeps its user list in ViewState (`ViewState["dtUser"]`, BMMS/Master/User.aspx.cs) for the header sort and the "Duplicate Login User Id not allowed" check. The list comes from spr_GetUserListForUserPage, which returns `v.*` of View_Users, the Password column included, so every user's password hash was written into the page's ViewState.

How far that went: the User Master ViewState is encrypted by ASP.NET. A GridView with DataKeyNames and AutoGenerateColumns="false" registers ViewState encryption in its OnInit (read in the IL of System.Web.dll 4.8.10002), and with the default `viewStateEncryptionMode` ("Auto"; not set in Web.config, machine.config or the framework web.config) the page then encrypts its whole ViewState and writes the field `__VIEWSTATEENCRYPTED`. grvUser has `DataKeyNames="UserId"` and `AutoGenerateColumns="false"`. The ViewState is also signed (enableViewStateMac, always on since .NET 4.5.2) with the machine key that ASP.NET generates for this machine and application (no `<machineKey>` is set). So the old exposure was limited: the hashes reached the browser encrypted and signed, readable only with the server's machine key, that is by someone who already has the server. Proven on a test site in IIS Express with the same settings: without DataKeyNames the ViewState was readable (it starts with the bytes FF 01; a login and a sample hash were found in it), with DataKeyNames it was encrypted and neither was found. Audit Trail's grid (`DataKeyNames="Audit_Trail_Maser_Id"`) is encrypted the same way, so the user list removed there in step UN3 was encrypted too.

Step PW1 is defence in depth: the hash never reaches the browser at all, even if the grid loses its DataKeyNames (the page's ViewState would then be readable after base64 decoding) or the encryption is switched off.

- BMMSBAL/UserMgr.cs, `GetUserListForUserPage`: the Password column is removed from the list before the page gets it. No part of the page used it: the grid, the row buttons (CanEdit, CanDelete, CanDeactivate, CanActivate, ManagedCount, IsSystem), the sort and the duplicate check (LoginName, UserId) use other columns. Edit reads its user separately (spr_GetUserByUserId) and keeps nothing.
- The procedure is unchanged (it keeps `v.*`), so the test scripts of steps 13, 14 and 18, which fill a table from it with `INSERT INTO ... EXEC`, and BMMS-Check-InstalledSteps.sql are unchanged. No .aspx change, no database change; the build before step PW1 keeps working.
- What the column holds: on BMMS_Test all 14 users have PBKDF2 hashes (`100000.<salt>.<hash>`, 100,000 iterations, a random 16-byte salt per user), not readable passwords. Still, with a hash and its salt anyone can try the default password of the source code on every user in seconds and find who still has it, and weak passwords can be guessed offline. A value in the older ("legacy") format would be worse: it is TripleDES with an empty key and an IV that are in the source code (Common.DecryptVal), so it can be turned back into the password. Such a user cannot log in (VerifyPassword refuses the format).
- The rest of the solution, checked: SQL Server reports seven procedures whose rows carry a Password column (spr_GetUserListForUserPage, spr_GetUser, spr_GetActiveUserList, spr_GetMgrControllerByDeptId, spr_GetUserByUserId, spr_GetUserByLoginName and spr_GetSMTPMaster, the mail password). Only the User Master list was kept in ViewState. The others stay on the server: the pick lists keep only their item texts and values, Session keeps the user's id, names and role, Reset Password's hidden field keeps the e-mail address, and the SMTP page shows only stars (the mail password is stored DPAPI-protected).
- No browser check can prove step PW1 on User Master: its ViewState is encrypted, so neither the hash nor any login can be found in it, before or after the step. The proof is the server-side check below: the built UserMgr.GetUserListForUserPage returns the rows with no Password column.

Server-side check (repeatable; there is no test script for the C# layer). It reads BMMS_Test only (spr_GetUserListForUserPage is read-only) and uses the DLLs of the build under test. In PowerShell, in a new empty folder (for example `C:\Temp\pw1check`):

1. Copy `BMMSBAL.dll` and `BMMSDAL.dll` from `C:\Repositories\BMMS-Legacy\BMMS\bin` into the folder.
2. Save this as `PW1Check.cs`:

```csharp
// Step PW1: the list User Master keeps in ViewState must have no Password column (reads BMMS_Test only)
using System;
using System.Data;
using BMMSBAL;

class PW1Check
{
    static void Main()
    {
        DataTable dt = UserMgr.GetUserListForUserPage(6);   // acting user 6 = Controller
        string[] used = { "UserId", "UserName", "LoginName", "Status", "AccountStatus", "IsSystem",
                          "CanEdit", "CanDelete", "CanDeactivate", "CanActivate", "ManagedCount" };
        bool allUsed = true;
        foreach (string c in used)
            if (!dt.Columns.Contains(c)) { allUsed = false; Console.WriteLine("missing column: " + c); }

        Console.WriteLine("rows=" + dt.Rows.Count + "  Password column=" + dt.Columns.Contains("Password")
                          + "  page columns present=" + allUsed);
        Console.WriteLine(!dt.Columns.Contains("Password") && allUsed && dt.Rows.Count > 0 ? "PASS" : "FAIL");
    }
}
```

3. Save this as `PW1Check.exe.config` (the data layer reads the connection string "ConnectionString"; Windows login to the local server):

```xml
<?xml version="1.0"?>
<configuration>
  <connectionStrings>
    <add name="ConnectionString" connectionString="Server=.;Database=BMMS_Test;Integrated Security=SSPI"/>
  </connectionStrings>
</configuration>
```

4. Compile and run:

```powershell
& "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /r:BMMSBAL.dll /r:System.Data.dll /r:System.Web.dll /out:PW1Check.exe PW1Check.cs
.\PW1Check.exe
```

Expected: `rows=14  Password column=False  page columns present=True` and `PASS` (the row count is that of BMMS_Test). On the build before step PW1 the same check gives `Password column=True` and `FAIL`.

Optional check on the real `BMMS` (counts only, no values): which format the stored passwords have.

```sql
SELECT CASE WHEN Password IS NULL OR Password = '' THEN 'empty'
            WHEN Password LIKE '[0-9]%.%.%' AND LEN(Password) - LEN(REPLACE(Password, '.', '')) = 2 THEN 'PBKDF2 hash'
            ELSE 'legacy (reversible)' END AS format,
       COUNT(*) AS users
FROM Users
GROUP BY CASE WHEN Password IS NULL OR Password = '' THEN 'empty'
              WHEN Password LIKE '[0-9]%.%.%' AND LEN(Password) - LEN(REPLACE(Password, '.', '')) = 2 THEN 'PBKDF2 hash'
              ELSE 'legacy (reversible)' END;
```

Browser check of the ViewState on `BMMS_Test`, in Chrome or Edge (deploy the build first). Open DevTools (F12), tab Console, paste this and press Enter. It joins the ViewState fields if the page splits them, says whether the ViewState is readable or encrypted, and searches for hashes and a login only when it is readable:

```js
(function () {
  var c = document.getElementById('__VIEWSTATEFIELDCOUNT');
  var n = c ? parseInt(c.value, 10) : 1, v = '';
  for (var i = 0; i < n; i++) v += document.getElementById(i === 0 ? '__VIEWSTATE' : '__VIEWSTATE' + i).value;
  var b = atob(v);
  var plain = b.charCodeAt(0) === 0xFF && b.charCodeAt(1) === 0x01;
  var r = {
    fields: n,
    bytes: b.length,
    encryptedField: !!document.getElementById('__VIEWSTATEENCRYPTED'),
    format: plain ? 'plain (readable)' : 'encrypted (not readable in the browser)'
  };
  if (plain) {
    r.hashes = (b.match(/\d{4,7}\.[A-Za-z0-9+\/=]{20,}\.[A-Za-z0-9+\/=]{20,}/g) || []).length;
    r.loginFound = b.indexOf('credmanager') >= 0;
  }
  return r;
})()
```

Expected on User Master: `fields: 1`, `encryptedField: true`, `format: 'encrypted (not readable in the browser)'`. There is no `hashes` or `loginFound` in the result: they are only searched in a readable ViewState. `bytes` is the size of the encrypted ViewState.

Regression checks on `BMMS_Test` (the page must behave as before):

1. Controller, User Master: the console check above gives the expected result.
2. Sort every column twice (User Name, Department Name, Designation Name, Email Id, Role Name, Login / User ID, Status): A to Z, then Z to A.
3. Edit s20user, Cancel; Edit again and Update without a change: saved.
4. Duplicate check: Add a user with the login `mgruser`: "Duplicate Login User Id not allowed". Edit depuser (the User ID is read-only on Edit) and Update without a change: saved, with no "Duplicate" message.
5. Deactivate s20user: the confirmation names s20user; the row turns inactive (greyed). Activate it again.
6. Delete: a user with history (mgruser) is refused with the reason; a new test user you add is deleted.
7. The system account row (admin): greyed, "(System account)", the three buttons disabled with the tooltip "Protected system account".
8. Admin: checks 1 and 2 again; rows the Admin may not change show disabled buttons with their tooltips, as before.
9. Manager (mgruser) and User (depuser): `Master/User.aspx` opened directly gives "Access denied", as before.
10. Unchanged: login, Change Password (the old password is checked) and Reset Password (the details box) work as before.
11. Error log: no entry from these checks.

## Step UN4: comment captions show who wrote the comment and when (database script step 35 and code; test script for BMMS_Test)

The only comments in the application are the Manager's comment and the Controller's comment of an agenda item (Agenda.MgrComments, Agenda.ControllerComments). They are shown on Agenda Entry (an item opened for editing) and on the Dashboard (the agenda panel of an alert). No other page, print or PDF shows them: Minutes Update, Confirmation and Finalization have the Proposed and Actual Resolution, which are not comments, and the approval print and PDF (AP1) print the Short Text and the Proposed Resolution only. Mails (step UN5) and the alerts and Pending lists (step UN6) are not changed in step UN4.

- Caption, Agenda Entry (one line): `Manager's comment: MohanKumar, 11-Oct-2026 16:49` and `Controller's comment: Venkat, 11-Oct-2026 16:49`. The label stays bold; the name and the time follow it, muted and not bold.
- Caption, Dashboard: the label `Manager's comment :` / `Controller's comment :` in the label column as before, and the name and the time on their own line under it, smaller and muted (12 px). A long name without a space breaks inside the word, so the label column keeps its width.
- The name alone (Common.UserCaptionName): the person's name (Users.UserName), the login ID only when the name is blank, " (inactive)" added for an inactive account: `Shravankumar (inactive), 02-Nov-2026 10:15`. A user id with no user row shows `(unknown user)` (UserMgr.UnknownUserText); spr_DeleteUserByUserId already refuses to delete a user named in these columns, so this needs a change by hand in the database.
- The date and time: `dd-MMM-yyyy HH:mm`, as System Settings shows "Last changed by ... on ...", in English month names whatever the server culture. The time is the database server's clock (GETDATE()).
- A comment saved before step 35 has no who and when: the caption is the label alone (`Controller's comment`, and on the Dashboard nothing under the label). They are not filled in from the Audit Trail: comments saved on Agenda Entry and the comments of a Manager's or the Controller's own new item were never audited, and a match by agenda number and text would be partial (on 2026-11-07, BMMS_Test: 9 of 11 Manager and 12 of 16 Controller comments; BMMS: 2 of 2 and 2 of 7).
- The name is HTML-encoded by the page (HttpUtility.HtmlEncode in Agenda.aspx.cs and DashBoard.aspx.cs, ShowCommentCaptions), so a name such as `A&B <i>x</i> O'Neil "Q"` shows as plain text. The editor's accessible name (its aria-label) is the whole caption on one line.
- An approval or a rejection with an empty comment still shows the name and the time: they record the decision.

Database, step 35 (BMMS-Fix-CommentAuthor-Step35.sql, marker CommentAuthor-Step35). The columns MgrApprovedBy, MgrApprovedDate, ControllerApprovedBy and ControllerApprovedDate exist in Agenda and View_Agenda (so spr_GetAgendaByAgendaId returns them), but no procedure wrote them: on 2026-11-07 they were NULL in every row of BMMS_Test (38 items) and BMMS (9). From step 35 they hold whoever last saved the comment or recorded the decision, not only an approver (the column names stay):

- spr_UpdateAgendaByAgendaId (Dashboard Approve / Reject, and the reject of Agenda Finalization): the Manager's decision sets MgrApprovedBy = @UpdatedBy and MgrApprovedDate = GETDATE() (the same time as UpdatedOn); the Controller's decision sets the Controller's two columns. Always, also with an empty comment.
- spr_AddEditAgendaByManager / spr_AddEditAgendaByController, Save (a new item of a Manager, of the Controller): the item is saved as approved by that role, so that role's two columns are set (@ActingUserId, GETDATE()), also with an empty comment.
- The same two procedures, Update (Agenda Entry): only when the text of that role's own comment changes. The comparison is exact (case and trailing spaces count; NULL and empty text are the same). The other role's comment, which the page writes back unchanged (step C1), never sets anything. A save without a change keeps the who and when.
- spr_AddEditAgenda (a User, the Admin and the other roles on Agenda Entry): unchanged; it writes both comments back as saved.
- Parameters and result sets are unchanged, so the build before step UN4 works with step 35, and the build of step UN4 works without it (the captions then show the label alone).
- Only lines are added to the three procedures: the texts of steps 16, 17, 18, 20 and 31 are kept, and BMMS-Check-InstalledSteps.sql still reads those steps Installed. Re-running step 16, 17, 18, 20 or 31 afterwards brings back an older text: step 35 then reads Partly or Missing; run step 35 again (the step 31 row now says so).
- An untouched comment is saved back exactly: an editor that was not changed posts the text it was given (HtmlCleaner output), and every stored comment on BMMS_Test (27) and BMMS (9) is already unchanged by HtmlCleaner, so a save without a change does not count as a change.
- Consequence: spr_DeleteUserByUserId refuses to delete a user named in MgrApprovedBy or ControllerApprovedBy (as before step 35, when nobody was). From step 35 every Manager and Controller who decides or comments is named there, so they can be deactivated but not deleted.
- BMMS-Rollback-CommentAuthor-Step35.sql restores the step 31 text of the three procedures (the definitions installed on BMMS_Test and BMMS before step 35 are the step 31 text exactly) and keeps the who and when already written; later saves leave them as they are, so a caption may then show an older name and time than the last change of a comment. To clear them too (they were NULL in every row before step 35): `UPDATE Agenda SET MgrApprovedBy = NULL, MgrApprovedDate = NULL, ControllerApprovedBy = NULL, ControllerApprovedDate = NULL;`
- BMMS-Test-CommentAuthor-Step35.sql: 28 checks, in a transaction that is rolled back. On a restored copy of BMMS_Test (2026-11-07): Fix twice, Test 28 PASS; the tests of steps 31 (41), 20 (56) and 16 (100) PASS with step 35 installed; Rollback twice gives the live definitions exactly; Fix again, Test 28 PASS. The message "Null value is eliminated by an aggregate" comes from the procedures (the step 31 test prints it too) and is harmless.

Code: BMMSBAL/Common.cs (UserCaptionName), BMMSBAL/AgendaMgr.cs (CommentAuthor, CommentCaption and the two labels), BMMS/Master/Agenda.aspx (.cs, .designer.cs), BMMS/DashBoard/DashBoard.aspx (.cs, .designer.cs), BMMS/CSS/bmms-workbench.css (.bmms-comment-by, .bmms-comment-by-line).

What to run where (the Consultant runs the scripts):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 35 reads Missing).
2. `BMMS_Test`: BMMS-Fix-CommentAuthor-Step35.sql. It prints "Step 35 installed: ..." (a second run prints the same).
3. `BMMS_Test`: BMMS-Test-CommentAuthor-Step35.sql (28 checks, all PASS; the last grid 0, 0, 0, 0).
4. BMMS-Check-InstalledSteps.sql again: step 35 reads Installed; steps 16, 17, 18, 20 and 31 still Installed.
5. Rebuild and deploy the build of step UN4.
6. The browser checks below.
7. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build.
8. If step 35 must be undone: BMMS-Rollback-CommentAuthor-Step35.sql (it prints "Step 35 rolled back"), then BMMS-Check-InstalledSteps.sql (step 35 reads Missing).

Browser checks on `BMMS_Test`, in Chrome and in Edge (keep the error log of the day open). Setup: on 2026-11-07 no open meeting of BMMS_Test had a date from today on. As Controller, on Meeting, add one for the checks (date about a week ahead, agenda submission date after today). Then:

1. depuser, Agenda Entry: a new item on that meeting, Save. The Comments card is not shown (as before). Find the item:

```sql
SELECT TOP 1 AgendaId, AgendaNo, AgendaStatusCode, MgrApprovedBy, MgrApprovedDate, ControllerApprovedBy, ControllerApprovedDate
FROM Agenda WHERE CreatedBy = (SELECT UserId FROM Users WHERE LoginName = 'depuser') ORDER BY AgendaId DESC;
```

2. mgruser, Dashboard: open the alert of the item. "Manager's comment :" and "Controller's comment :" with nothing under them. Leave the Manager's comment EMPTY and Approve.
3. mgruser, Agenda Entry, open the item: `Manager's comment: MohanKumar, <today> <the time of step 2>`; the name and time muted, not bold. The query of step 1: MgrApprovedBy 12, MgrApprovedDate the same time.
4. Controller (Venkat), Dashboard, the same item: under "Manager's comment :" the line `MohanKumar, <time of step 2>`, small and grey; nothing under "Controller's comment :". Type a comment and Approve.
5. Controller, Agenda Entry, the same item: `Manager's comment: MohanKumar, ...` and `Controller's comment: Venkat, <time of step 4>`.
6. Controller, Agenda Entry, the same item: Update without changing anything; open it again: both times unchanged. Change the Controller's comment, Update, open again: the Controller's time is now; the Manager's line unchanged.
7. depuser, Dashboard: open the alert of the item (Controller approved): both lines under the labels, read-only editors, as in step 4.
8. A comment from before step 35: list them, then open one as Controller on Agenda Entry: `Controller's comment` alone (no colon, no name).

```sql
SELECT a.AgendaNo, m.MeetingNo, c.CommitteeName, a.AgendaStatusCode,
       CASE WHEN CAST(a.MgrComments AS NVARCHAR(10)) <> N'' AND a.MgrApprovedBy IS NULL THEN 'Manager' ELSE '' END AS OldMgrComment,
       CASE WHEN CAST(a.ControllerComments AS NVARCHAR(10)) <> N'' AND a.ControllerApprovedBy IS NULL THEN 'Controller' ELSE '' END AS OldControllerComment
FROM Agenda a JOIN Meeting m ON m.MeetingId = a.MeetingId JOIN Committee c ON c.CommitteeId = a.CommitteeId
WHERE (CAST(a.MgrComments AS NVARCHAR(10)) <> N'' AND a.MgrApprovedBy IS NULL)
   OR (CAST(a.ControllerComments AS NVARCHAR(10)) <> N'' AND a.ControllerApprovedBy IS NULL)
ORDER BY a.AgendaId DESC;
```

9. Inactive, unknown, special characters and long names: set by SQL on the test item (put its AgendaNo in the first line of each block), open it as Controller on Agenda Entry and as depuser on the Dashboard after each block:

```sql
-- a) inactive: "Manager's comment: Shravankumar (inactive), <time of step 2>"
DECLARE @AgendaNo VARCHAR(50) = '<AgendaNo of the test item>';
UPDATE Agenda SET MgrApprovedBy = 105 WHERE AgendaNo = @AgendaNo;
```

```sql
-- b) a user id with no user row: "Manager's comment: (unknown user), <time of step 2>"
DECLARE @AgendaNo VARCHAR(50) = '<AgendaNo of the test item>';
UPDATE Agenda SET MgrApprovedBy = 999999 WHERE AgendaNo = @AgendaNo;
```

```sql
-- c) special characters: the caption shows A&B <i>x</i> O'Neil "Q" as plain text, nothing in italics;
--    View Source shows A&amp;B &lt;i&gt;x&lt;/i&gt; O&#39;Neil &quot;Q&quot; in the span and in the aria-label
DECLARE @AgendaNo VARCHAR(50) = '<AgendaNo of the test item>';
UPDATE Users SET UserName = 'A&B <i>x</i> O''Neil "Q"' WHERE LoginName = 'ituser';
UPDATE Agenda SET MgrApprovedBy = (SELECT UserId FROM Users WHERE LoginName = 'ituser') WHERE AgendaNo = @AgendaNo;
```

```sql
-- d) long names (Users.UserName is VARCHAR(50)): 50 letters without a space, then 50 characters with spaces.
--    Dashboard: the line breaks inside the label column (165 px), the editor stays beside it; Agenda Entry: the
--    caption wraps inside the card. No sideways scroll at 1366 px and at 1105 px.
UPDATE Users SET UserName = REPLICATE('W', 50) WHERE LoginName = 'ituser';
-- then:
UPDATE Users SET UserName = 'Venkataramana Subramanian Charles Vijayaraghavan K' WHERE LoginName = 'ituser';
```

```sql
-- after the checks of step 9
DECLARE @AgendaNo VARCHAR(50) = '<AgendaNo of the test item>';
UPDATE Agenda SET MgrApprovedBy = 12 WHERE AgendaNo = @AgendaNo;
UPDATE Users SET UserName = 'Gopinath' WHERE LoginName = 'ituser';
```

10. Manager reject: depuser adds a second item on the test meeting; mgruser rejects it on the Dashboard with a comment: as depuser on the Dashboard (the rejection alert) `MohanKumar, <now>` under "Manager's comment :".
11. Admin, User Master: deleting mgruser is refused with the reason, as before.
12. Last, optional (it finalizes the agenda of the test meeting and sends the rejection mails): depuser adds a third item, mgruser approves it; Controller, Agenda Finalization, the test meeting, Finalize. The third item is rejected with "Agenda rejected by Controller on agenda finalized."; on Agenda Entry: `Controller's comment: Venkat, <now>`.
13. Error log: no entry from these checks.

## Step AL1: a changed agenda item alerts the next approver again; "Alerts (n)" counts unread alerts (database script step 36 and code; test script for BMMS_Test)

Before step 36 an Update on Agenda Entry never touched the alerts. A Manager who changed the comment of an item they had already approved (AMA) left the Controller's alert as read: on 2026-11-08 on BMMS_Test, item C02-00003-003 had MgrApprovedDate 18:24:58 (the comment change) while the Controller who had opened the alert still had it read. A User's edit of an item waiting for the Manager (AC) left the Manager's alert as read too. Approve and Reject on the Dashboard (spr_UpdateAgendaByAgendaId) already mark the alert unread for everyone except the person who acted.

How the alerts work (unchanged): every agenda item has one Alert_Master row (SourceType 'Agenda', SourceTypeId the AgendaId) whose AlertTypeCode follows the item (AC, AMA, AMR, ACA, ACR), and one Alert_User_Map row per recipient with ReadStatus (0 unread, 1 read) and StatusId (1 shown, 0 removed with the Dashboard's delete button). Opening an alert on the Dashboard sets ReadStatus 1 (spr_UpdateAlertByUserId). spr_GetAlertByUserId lists a user's rows with StatusId 1; the Controller does not see ACA and ACR alerts, a Manager not AMA and AMR.

Database, step 36 (BMMS-Fix-AlertRefresh-Step36.sql, marker AlertRefresh-Step36), the Update of the three Agenda Entry procedures:

- Compared: the saved values before the Update with the values of the Update: SubjectTypeId, SubjectNo, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath, MgrComments, ControllerComments, and DepartmentId for the Controller (spr_AddEditAgendaByController is the only one that writes it). CurrentStatus is not compared (Agenda Entry always sends 'New'). Text is compared exactly, as in step 35: case and trailing spaces count; NULL and empty text are the same. For a number, NULL to a value and a value to NULL count as a change.
- Something changed: every Alert_User_Map row of the item's alert except the acting user's own row gets ReadStatus 0 and StatusId 1, so it is unread again and shown again also for someone who had removed it. The acting user's row is not touched.
- Nothing changed: the alert is left as it is.
- Not changed: no alert row is added, so somebody who never had a row for the item (for example a Controller made active after the item reached AMA) still gets none; Alert_Master (CreatedOn, AlertTypeCode) is not changed, so the alert keeps its place in the list (sorted by CreatedOn); no e-mail is sent on Update (since step ML1, step 37, a mail goes out: see that section); Save, Approve, Reject and a refused call behave as before. Parameters and result sets are unchanged.

Who gets the refreshed alert (the role filters of spr_GetAlertByUserId decide who sees it):

| Update by | Status | Unread again for |
|---|---|---|
| User | AC (waiting for the Manager) | the Manager, Admin |
| User | AMA, sent straight to the Controllers (no manager, step 20) | the Controllers |
| Manager, comment or text changed | AMA | the Controllers, the creator, Admin (the reported case) |
| Manager | AMR | the creator, Admin |
| Controller | ACA or ACR | the creator, the Manager, the other Controllers, Admin |
| Controller | AC or AMA (comment without deciding) | the other Controllers, the Manager, Admin |

A User cannot edit an item once the Manager has approved or rejected it, and a User or a Manager cannot once the Controller has decided (Agenda.aspx.cs, unchanged): a rejected item is not resubmitted from Agenda Entry, so step 36 has no rule for it.

- Only lines are added to the three procedures: spr_AddEditAgenda keeps the text of step 31 (with steps 16, 17, 18 and 20), spr_AddEditAgendaByManager and spr_AddEditAgendaByController the text of step 35 (with steps 16, 17, 18 and 31); BMMS-Check-InstalledSteps.sql still reads those steps Installed. The step 36 procedures were built from the definitions installed on BMMS_Test on 2026-11-08, which are the step 31 and step 35 script texts exactly.
- The steps are installed in order: step 35 before step 36; the step 36 script stops, changing nothing, when step 35 is not installed. Re-running step 31 or step 35 after step 36 removes step 36 (step 31 replaces all three procedures: step 36 reads Missing; step 35 replaces two: Partly, 1 of 3), and so does a re-run of step 16, 17, 18 or 20: run step 36 again. The rows of steps 31 and 35 in BMMS-Check-InstalledSteps.sql say so.
- BMMS-Rollback-AlertRefresh-Step36.sql restores the step 31 text of spr_AddEditAgenda and the step 35 text of the other two, and keeps the alerts already refreshed (they become read when opened). Roll back step 36 before step 35.
- BMMS-Test-AlertRefresh-Step36.sql: 37 checks, in a transaction that is rolled back (see the test list above). Desk-checked (batches, compatibility level 100); not yet run: record the results here after step 3 below.

Rich text and "no change": an untouched editor posts back exactly the text it was given (RichTextEditor: HtmlCleaner output), and ReplaceRichTextFont, applied to the Proposed Resolution on every save, only renames style words (font-family:, color: ...) that HtmlCleaner has already removed, so it changes nothing in cleaned text. Checked on 2026-11-08 by running the page's save path (HtmlCleaner.Clean on load, on render and on post, Trim, ReplaceRichTextFont) over every stored row, read-only: a second untouched Update of any row changes nothing, every comment is already stable, and text with bold, italic, a bulleted and a numbered list and an alignment comes back the same. Only rows saved before step A1a would change once, on their first Update: on BMMS_Test 5 Agenda Text and 2 Proposed Resolution of 44 (items 2, 3, 384, 460 and 674), on BMMS 3 and 1 of 9 (items 2, 3 and 4). All of them are on a finalized agenda (AgendaStatus Close), where an Update is refused, so none can refresh an alert without a change.

Code: BMMS/MasterPage/Main.Master.cs (AlertCount). "Alerts (n)" in the header now counts the unread alerts (ReadStatus 0) of the list the Dashboard shows (StatusId 1); before it counted read and unread. The label is unchanged ("Alerts (n)"), and the Dashboard list still shows read and unread alerts (bold is unread), so a user whose alerts are all read sees "Alerts (0)" above a list. Main.Master is not changed.

What to run where (the Consultant runs the scripts):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 35 Installed, step 36 Missing).
2. `BMMS_Test`: BMMS-Fix-AlertRefresh-Step36.sql. It prints "Step 36 installed: ..." (a second run prints the same).
3. `BMMS_Test`: BMMS-Test-AlertRefresh-Step36.sql (37 checks, all PASS; the last grid 0, 0, 0, 0). Then the tests of steps 35, 31 and 20 with step 36 installed (they still pass: step 36 only adds lines).
4. BMMS-Check-InstalledSteps.sql again: step 36 reads Installed; steps 16, 17, 18, 20, 31 and 35 still Installed.
5. Rebuild and deploy the build of step AL1 (Main.Master.cs).
6. The browser checks below.
7. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build.
8. If step 36 must be undone: BMMS-Rollback-AlertRefresh-Step36.sql (it prints "Step 36 rolled back"), then BMMS-Check-InstalledSteps.sql (step 36 reads Missing, step 35 Installed).

Browser checks on `BMMS_Test`, in Chrome and in Edge (keep the error log of the day open), with depuser (a User of mgruser), mgruser (Manager) and the Controller, on an open meeting dated from today on (add one as Controller if there is none, as in step UN4). Before each Update, open the alert as the person who will get it, so it is read (not bold); note the "Alerts (n)" number. Find the rows of the item with:

```sql
DECLARE @AgendaNo VARCHAR(50) = '<AgendaNo of the test item>';
SELECT u.LoginName, r.RoleCode, m.ReadStatus, m.StatusId, am.AlertTypeCode, am.CreatedOn
FROM Agenda a
JOIN Alert_Master am ON am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId
JOIN Alert_User_Map m ON m.AlertId = am.AlertId
JOIN Users u ON u.UserId = m.UserId JOIN Roles r ON r.RoleId = u.RoleId
WHERE a.AgendaNo = @AgendaNo
ORDER BY r.RoleCode, u.LoginName;
```

1. depuser, Agenda Entry: a new item with a Proposed Resolution that has formatting: a bold word, a bulleted list of two lines and a numbered list of two lines. Save.
2. mgruser opens the alert on the Dashboard (read). depuser, Agenda Entry, opens the item and clicks Update without changing anything: mgruser's alert stays read (not bold), "Alerts (n)" of mgruser unchanged; the query shows mgruser ReadStatus 1.
3. depuser changes the Short Text and clicks Update: mgruser's alert is bold again and "Alerts (n)" one higher; the query shows ReadStatus 0 for mgruser (and Admin), AlertTypeCode and CreatedOn unchanged.
4. mgruser approves on the Dashboard (AMA). The Controller opens the alert (read).
5. mgruser, Agenda Entry, opens the item and clicks Update without changing anything (the formatted Proposed Resolution is in the box): the Controller's alert stays read. Then mgruser changes only the Manager's comment and clicks Update: the Controller's alert is bold again, "Alerts (n)" of the Controller one higher; mgruser's own row unchanged.
6. The Controller opens the alert (read), approves on the Dashboard (ACA). depuser and mgruser open their alerts (read).
7. The Controller, Agenda Entry, opens the item and clicks Update without changing anything: nobody's alert changes. Then the Controller changes only the Controller's comment and clicks Update: depuser's and mgruser's alerts are bold again; the Controller's own row unchanged.
8. Removed alert: depuser removes the alert from the Dashboard (delete button); the Controller changes the comment again and clicks Update: the alert is back in depuser's list, bold.
9. Header count: for a user with only read alerts the header shows "Alerts (0)" while the Dashboard still lists them; opening a bold alert lowers the number by one on the next page.
10. Error log: no entry from these checks.

If an Update without a change refreshes an alert (steps 2, 5 or 7): stop, do not install step 36 on `BMMS`, and find the field that changed. In SSMS, in one query window, before the Update:

```sql
DECLARE @AgendaNo VARCHAR(50) = '<AgendaNo of the test item>';
IF OBJECT_ID('tempdb..#Before') IS NOT NULL DROP TABLE #Before;
SELECT AgendaId, SubjectTypeId, SubjectNo, DepartmentId, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath, MgrComments, ControllerComments
INTO #Before FROM Agenda WHERE AgendaNo = @AgendaNo;
```

then click Update without a change, and in the same window:

```sql
SELECT CASE WHEN ISNULL(b.ShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(a.ShortText, N'') COLLATE Latin1_General_BIN2 OR DATALENGTH(ISNULL(b.ShortText, N'')) <> DATALENGTH(ISNULL(a.ShortText, N'')) THEN 'changed' ELSE '' END AS ShortText,
       CASE WHEN ISNULL(b.AgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(a.AgendaText, N'') COLLATE Latin1_General_BIN2 OR DATALENGTH(ISNULL(b.AgendaText, N'')) <> DATALENGTH(ISNULL(a.AgendaText, N'')) THEN 'changed' ELSE '' END AS AgendaText,
       CASE WHEN ISNULL(b.ProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(a.ProposedResolution, N'') COLLATE Latin1_General_BIN2 OR DATALENGTH(ISNULL(b.ProposedResolution, N'')) <> DATALENGTH(ISNULL(a.ProposedResolution, N'')) THEN 'changed' ELSE '' END AS ProposedResolution,
       CASE WHEN ISNULL(b.MgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(a.MgrComments, N'') COLLATE Latin1_General_BIN2 OR DATALENGTH(ISNULL(b.MgrComments, N'')) <> DATALENGTH(ISNULL(a.MgrComments, N'')) THEN 'changed' ELSE '' END AS MgrComments,
       CASE WHEN ISNULL(b.ControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(a.ControllerComments, N'') COLLATE Latin1_General_BIN2 OR DATALENGTH(ISNULL(b.ControllerComments, N'')) <> DATALENGTH(ISNULL(a.ControllerComments, N'')) THEN 'changed' ELSE '' END AS ControllerComments,
       CASE WHEN ISNULL(b.FilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(a.FilePath, N'') COLLATE Latin1_General_BIN2 OR ISNULL(b.AgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(a.AgendaTextPath, N'') COLLATE Latin1_General_BIN2 THEN 'changed' ELSE '' END AS Files,
       CASE WHEN ISNULL(b.SubjectNo, -1) <> ISNULL(a.SubjectNo, -1) OR ISNULL(b.SubjectTypeId, -1) <> ISNULL(a.SubjectTypeId, -1) OR ISNULL(b.DepartmentId, -1) <> ISNULL(a.DepartmentId, -1) OR ISNULL(b.AgendaType, '') <> ISNULL(a.AgendaType, '') THEN 'changed' ELSE '' END AS Numbers,
       b.ProposedResolution AS ProposedBefore, a.ProposedResolution AS ProposedAfter
FROM #Before b JOIN Agenda a ON a.AgendaId = b.AgendaId;
DROP TABLE #Before;
```

Send the result (and, for a text column, the two values) to the Consultant. The page is then fixed so that an untouched value is written back exactly; step 36 itself stays as it is. Until then the step can be rolled back on `BMMS_Test` (step 8 above) if the extra alerts disturb other tests.

## Step ML1: a mail when an agenda item is updated (database script step 37 and code; test script for BMMS_Test)

Since step 36 an Update on Agenda Entry that changes something marks the item's alert unread again, but no mail went out. Decisions (Consultant, 2026-11-08): a mail on Update goes to the same people as the refreshed alert, only when something really changed (any compared field, Agenda Text and Proposed Resolution included); the subject says "has been Updated"; the body has the details of the "has been Created" mail and one line per changed field, never the text of a field; one fixed sender, the Controller's login account; a failed send is shown to the user after the save.

Database, step 37 (BMMS-Fix-UpdateMail-Step37.sql, marker UpdateMail-Step37):

- spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController: new last parameter `@ChangedFields VARCHAR(400) = NULL OUTPUT`. It is set from the comparisons of step 36, one per field, so it is empty exactly when step 36 leaves the alert as it is: empty for a new item (Save), a refusal and an Update without a change. The codes, in this order: SubjectType, ShortText, AgendaType, AgendaText, AgendaTextFile:Attached / AgendaTextFile:Removed / AgendaTextFile:Replaced, ProposedResolution, Attachments, MgrComments, ControllerComments, Department (the Controller only), SubjectNo. The result row (Result, Reason, ReasonDetail) and the other parameters are unchanged, so every caller that does not pass the parameter (the older test scripts, other pages) works as before. A 4th result column was not used: nine test scripts read the result row into a three-column table.
- spr_GetAgendaUpdateMailId (new, reads only): @AgendaId, @ActingUserId. The addresses of the Alert_User_Map rows of the item's alert except the acting user, with the role filter of spr_GetAlertByUserId (the Controller does not see ACA / ACR alerts, a Manager not AMA / AMR, so they get no mail for those), active users only, not the system account, address not empty.
- App_Setting row MailSenderUserId (added only when missing): the user ID of the account that sends the BMMS mail, pre-set to the active Controller-role user with Login ID `Controller` (UserId 6 on `BMMS_Test` and `BMMS` on 2026-11-08), else empty. The Fix and BMMS-Check-InstalledSteps.sql say whether the From Mail Id of SMTP Configuration is that user's address; they never show the address.
- Only lines are added to the three procedures (the texts of steps 16, 17, 18, 20, 31, 35 and 36 are kept; built from the step 36 definitions installed on `BMMS_Test` on 2026-11-08). The steps are installed in order: step 36 before step 37; the script stops, changing nothing, otherwise. Re-running step 16, 17, 18, 20, 31, 35 or 36 after step 37 removes step 37 from one or more of the three procedures: run step 37 again. BMMS-Rollback-UpdateMail-Step37.sql restores the step 36 texts, drops spr_GetAgendaUpdateMailId and deletes the MailSenderUserId row; roll back step 37 before step 36. The tests of steps 31 and 36 accept the new parameter when step 37 is installed.

Who gets the mail (the same as who sees the refreshed alert; Admin and the other roles that have the alert get it too):

| Update by | Status | Mail to |
|---|---|---|
| User | AC (waiting for the Manager) | the Manager |
| User | AMA, sent straight to the Controllers (no manager) | the Controllers |
| Manager | AMA | the Controllers, the creator |
| Manager | AMR | the creator |
| Controller | AMA (comment without deciding) | the other Controllers, the creator (not the Manager: AMA alerts are hidden from Managers) |
| Controller | ACA or ACR | the Manager, the creator (not the other Controllers: ACA / ACR alerts are hidden from the Controller) |

Nobody in Bcc with an address: no mail and no message. The person who saved is never in Bcc; they get the mail as To.

The mail (Agenda.aspx.cs, GenerateUpdateMail; read from the item as saved now):

- Subject: `Agenda (<Agenda No>) has been Updated`.
- To: the person who saved, as in the "has been Created" and the approve / reject mails; the recipients above in Bcc; the Bcc of SMTP Configuration is added as for every mail. From is unchanged (the From Mail Id of SMTP Configuration).
- Body: Agenda No, Committee Name, Meeting No, Meeting Date, Department, Subject Type and Short Text (the current values), then "Changes", one line per code: Subject Type - Updated; Short Text - Updated; Agenda Type - Updated; Agenda Text - Updated; Agenda Text file - Attached / Replaced / Removed (no file name); Proposed Resolution - Updated; Attachments - Updated (N files now), or Attachments - Removed (no file names); Manager's Comments - Updated (Name, dd-MMM-yyyy hh:mm), or - Removed (...), with who and when of step 35, never the comment; the same for Controller's Comments; Department - Updated; Subject No - 5, or Subject No - Removed. Fields that did not change are not listed.
- No mail from this code on Save (the "has been Created" mail is unchanged), on a refusal or on an Update without a change.
- A failed send: the Update is saved, and the page shows "The agenda item was updated, but the mail could not be sent. The error is in the error log." as a warning. The same message when step 37 is not installed (the error log then names step 37): before each Update BMMSDAL asks the database whether the procedure has @ChangedFields, so the build works with or without step 37.

The sender (decision 3). How mail is sent today: every BMMS mail goes out through the one row of SMTP_Master (Admin, SMTP Configuration): From = From Mail Id; login = User Name / Password when a User Name is set; no TLS. `BMMS_Test` has the step 30 default (localhost, 25, no login, noreply@example.invalid); `BMMS` has localhost, 25, a login, and a From Mail Id that is not the Controller account's address (2026-11-08). The users with the Controller role, in both databases: UserId 6, Login ID `Controller` (the login account), and UserId 9, Login ID `sect` (a recipient only). A From address that does not belong to the SMTP login is a risk: Office 365 refuses it, Gmail replaces it by the login's address, and a relay that passes the mail on to the internet fails SPF / DMARC for the sender's domain, so the mail lands in spam or is rejected. So the code does NOT put the Controller's address in From: set the From Mail Id of SMTP Configuration (and the SMTP login) to the mailbox of the account in MailSenderUserId. The Check script shows whether they agree. This applies to every BMMS mail, not only the update mail.

What to run where (the Consultant runs the scripts):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 36 Installed, step 37 Missing).
2. `BMMS_Test`: BMMS-Fix-UpdateMail-Step37.sql. It prints the MailSenderUserId row, the sender line and "Step 37 installed: ...". A second run keeps the row.
3. `BMMS_Test`: BMMS-Test-UpdateMail-Step37.sql (42 checks, all PASS; the last grid 0, 0, 0, 0, 0). Then the tests of steps 36, 35, 31 and 20 with step 37 installed (they still pass).
4. BMMS-Check-InstalledSteps.sql again: step 37 Installed, 5 of 5; steps 16, 17, 18, 20, 31, 35 and 36 still Installed; the MailSender grid.
5. Rebuild and deploy the build of step ML1 (BMMSDAL/AgendaDB.cs, BMMSBAL/MeetingMgr.cs, BMMSBAL/AgendaMgr.cs, BMMS/Master/Agenda.aspx.cs).
6. The browser checks below, with smtp4dev on port 25 of the web server.
7. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), set SMTP Configuration as described under "The sender", then deploy the build.
8. If step 37 must be undone: BMMS-Rollback-UpdateMail-Step37.sql (it prints "Step 37 rolled back"), then BMMS-Check-InstalledSteps.sql (step 37 Missing, step 36 Installed). Until the build without ML1 is deployed, every saved Update shows "the mail could not be sent".

Browser checks on `BMMS_Test` (smtp4dev running; keep the error log of the day open), with depuser (a User of mgruser), mgruser (Manager) and the Controller, on an open meeting:

1. depuser: a new item, Save: the "has been Created" mail as before.
2. depuser opens it and clicks Update without a change: no new mail in smtp4dev; "Successfully Saved".
3. depuser changes the Short Text and the Proposed Resolution (a bold word and a list), Update: one mail "Agenda (...) has been Updated", To depuser, mgruser in Bcc; the body shows the new Short Text and the lines "Short Text - Updated" and "Proposed Resolution - Updated", and no text of the Proposed Resolution.
4. mgruser approves (AMA), then changes only the Manager's comment, Update: one mail to the Controllers and depuser with "Manager's Comments - Updated (name, date and time)"; no comment text; To mgruser, who is not in Bcc.
5. The Controller approves (ACA), then sets Subject No 5 and removes an attachment, Update: one mail to mgruser and depuser (not to `sect`) with "Subject No - 5" and "Attachments - ..."; no file names.
6. Stop smtp4dev; the Controller changes the comment, Update: the page shows "The agenda item was updated, but the mail could not be sent. ..." as a warning, the item shows the new comment (saved), and the error log has the entry. Start smtp4dev again.
7. Error log: no other entry from these checks.

## Step ML1b: an Entry item keeps no agenda text file name (code only, no database script)

Before, Agenda Entry saved the stored agenda text file name (AgendaTextPath) whatever the Agenda Type: an item saved as Upload with a PDF, then switched to Entry and updated, kept the old file name, so the Updated mail (step ML1) said only "Agenda Type - Updated". The same happened on a new item when a PDF was uploaded and the type switched to Entry before Save.

Code: BMMS/Master/Agenda.aspx.cs, btnSave_Click. Save and Update send an empty AgendaTextPath when the Agenda Type is Entry, for the User, the Manager and the Controller alike; Upload sends the file name as before. It is decided at Save, not when the type is switched, so switching to Entry and back to Upload before saving keeps the uploaded file. No procedure changes: steps 36 and 37 already treat a file name changed to empty as a change, so the alert is refreshed and the mail lists "Agenda Text file - Removed"; the old audit code writes one Audit Trail row AgendaTextPath (old name to empty). The PDF stays in Files/AgendaText/, as for a replaced file or an unticked attachment (Agenda Entry deletes no files). Every page that reads AgendaTextPath (Dashboard, Agenda Approval print, the Agenda Details report, Agenda Entry Edit) looks at the Agenda Type first, so nothing else changes for an Entry item. The typed Agenda Text of an Upload item is still kept, as before.

Browser checks on `BMMS_Test` (smtp4dev running):

1. An Upload item with a PDF: switch to Entry, type text, Update: the mail lists Agenda Type - Updated, Agenda Text - Updated and Agenda Text file - Removed; in SSMS AgendaTextPath is empty; the PDF is still in Files/AgendaText/; the Audit Trail has one AgendaTextPath row.
2. The same item back to Upload, attach a PDF, Update: Agenda Type - Updated and Agenda Text file - Attached; the View link opens the new PDF.
3. Update without a change (an Entry and an Upload item): no mail.
4. A plain Entry item, Short Text changed: no file line in the mail.
5. New item: upload a PDF, switch to Entry, Save: AgendaTextPath is empty; the Created mail as before.
6. Check 1 as mgruser at AMA (To mgruser; Bcc the Controllers and the creator) and as the Controller at ACA (To the Controller; Bcc the Manager and the creator).
7. Error log: no entry from these checks.

## Step ML2a: the configured Bcc on every mail, no address twice (code only, no database script)

Code:

- BMMSBAL/Mail_Mgr.cs, SendWebEmail. The Bcc of SMTP Configuration is now added to every mail. Before, a caller that passed no Bcc (Reset Password, Notice, Send Mail) lost the configured copy, because the code then set the Bcc list to nothing. The Bcc list then drops an address that is already in it and an address that is also a To address, comparing without case (AddMailAddresses with the To list; a new ContainsAddress). The To list itself is unchanged. From, the login and the SMTP settings are unchanged.

What each mail gets now:

| Mail | To | Bcc |
|---|---|---|
| Agenda Created, Updated; Dashboard approve / reject; Agenda Finalisation reject | the person who acted | the configured Bcc and the recipients, each address once, none equal to the To |
| Meeting Created / Updated | the person who saved | the configured Bcc and the other active users, each address once (accounts that share a mailbox get one copy) |
| Reset Password | the user | the configured Bcc (new) |
| Notice | each member, one mail each | the configured Bcc (new): the Bcc address gets one copy per member mail |
| Send Mail | the typed addresses | the configured Bcc (new) |

Browser checks on `BMMS_Test` (smtp4dev on port 25 of the web server; on SMTP Configuration set Bcc `copy@example.invalid`, and set it back afterwards):

1. Reset Password for a user: the mail arrives, and copy@example.invalid is in its Bcc. Send Mail to test1@example.invalid: copy@example.invalid in the Bcc. Notice to a meeting with two members who have an address: two mails, each with copy@example.invalid in the Bcc.
2. Addresses once: save a Meeting (all active users in the Bcc; several share gashpysoft@gmail.com): smtp4dev shows each address once in the Bcc, and the To address of the saver not again in the Bcc. A Controller approve (ACA), where the list includes the Controller who acted: the Controller's address is the To only. Set the configured Bcc to an address that is also a recipient: it appears once.
3. Error log: no other entry from these checks.

## Step ML2b: the comment in the approve and reject mails; Subject No and one date format in every agenda mail (code only, no database script)

Code:

- BMMSBAL/AgendaMail.cs (new; BMMSBAL.csproj): the parts every agenda mail shares, instead of a copy on each page. DetailRows builds the detail rows (Agenda No, Subject No only when it has a value, Committee Name, Meeting No, Meeting Date as dd-MMM-yyyy, Department, Subject Type, Short Text; every value HTML-encoded) in the layout the pages built before. CommentRow builds one comment row in the layout of the detail rows: the label "Manager's comment" or "Controller's comment" in bold in the label cell (aligned to the top); in the value cell, after ": ", a smaller grey line with who and when, "Name, dd-MMM-yyyy HH:mm" (AgendaMgr.CommentAuthor, names by Common.UserCaptionName, HTML-encoded; no line when there is no who and when), then the comment cleaned by HtmlCleaner.Clean, the cleaning of Send Mail (allow-listed tags only: no script, no event handlers, no style), with leading and trailing spaces and &nbsp; removed, so a long comment uses the full width of the value cell; a comment with no text (HtmlCleaner.IsBlank) adds no row. DecisionCommentRow picks the comment of the role that acted: a comment the decision changed, or a new one, shows who decided and when (step 35 writes them with the decision); a comment the decision did not change shows the who and when it had before the save, or the label alone when it had none. Compared exactly, as in steps 35 and 36 (case and trailing spaces count; NULL and empty are the same).
- BMMS/DashBoard/DashBoard.aspx.cs (Approve and Reject by the Manager and the Controller): TryGetAgenda keeps the item it reads before the save; after the saved decision GenerateMail reads the item again for the Subject No (given on approval) and the comment row. The other details come from the page, as before.
- BMMS/Master/AgendaFinalization.aspx.cs (Reject on agenda finalized): the details and the comment row come from the item read again after the rejection, so the Meeting Date is dd-MMM-yyyy (before, it showed the date with a time). The comment is the fixed text "Agenda rejected by Controller on agenda finalized.".
- BMMS/Master/Agenda.aspx.cs (Created and Updated mails): the detail block through DetailRows. The layout is unchanged except Subject No (only when it has a value; Created: the Subject No saved with the item). The Changes block of the Updated mail is unchanged.
- If the item cannot be read again after the save, the mail still goes out without the comment row (Dashboard: the Subject No as shown on the page; Finalisation: the details from the page's list), and the error log has the entry. A failed read or a failed mail never changes the saved decision. No procedure, view or setting changes.

Browser checks on `BMMS_Test` (smtp4dev on port 25 of the web server; keep the error log of the day open), with depuser (a User of mgruser), mgruser (Manager) and the Controller, on an open meeting:

1. mgruser approves an item with the comment "ok" (AMA): the mail "approved by Manager" has the detail block with Meeting Date dd-MMM-yyyy, Subject No (the number given on approval), and the row "Manager's comment" (label cell) with, in the value cell, the grey line "<name>, <date> <time>" and below it "ok"; the name and time are those of the caption on Agenda Entry.
2. mgruser rejects another item with an empty comment (AMR): no comment row.
3. The Controller approves (ACA) with a comment with a bold word and a bulleted list: the mail shows them as bold and a list, with no style attributes.
4. The Controller writes a comment on Agenda Entry (Update, at AMA), then later approves on the Dashboard without changing it: the comment row shows the time of the Agenda Entry save, not of the approval. On an item whose stored comment has no who and when (saved before step 35), the row has no grey line, only the label and the text. A comment typed with a leading space (" Controller note unchanged") arrives without it.
5. The Controller rejects (ACR) with the comment `<script>alert(1)</script> text` typed in: in smtp4dev the comment shows "text", the source has no script element, and nothing runs.
6. Agenda Finalisation with an item not yet approved: the "rejected by Controller on agenda finalized" mail has Meeting Date dd-MMM-yyyy (no time), Subject No if the item has one, and the row "Controller's comment" with the grey line "<name>, <date> <time>" and the fixed text below it.
7. Created and Updated mails (the ML1 checks): the same layout as before; a Subject No line only for an item that has one.
8. Error log: no entry from these checks.

## Step UM1: User Master, Email Id accepts digits and capitals; at most 50 characters (markup only, no database script)

Before, the Email Id box of User Master (Master/User.aspx) had a character filter (AjaxControlToolkit FilteredTextBoxExtender) that let only lowercase letters, `.`, `@` and `_` in: a digit, a capital or `-` was dropped while typing and removed from pasted text, so `user1@example.com` could not be entered. The filter now lets in a-z, A-Z, 0-9, `.`, `@`, `_` and `-`. `+` is not supported: it is still dropped, and the shared check emailValidation (JScript/Validation.js, unchanged) would refuse it. The browser check on Save is unchanged ("Invalid E-Mail Id", "EmailId is required field").

The box now stops at 50 characters (MaxLength 50), the size of Users.EmailId and of the @EmailId parameter of spr_AddEditUser (varchar(50)); before, a longer address was cut to 50 by the database without a message. No address stored today is longer than 22 characters.

Not changed: Member Master and SMTP Configuration (no character filter; the same emailValidation), System Settings (Organisation e-mail, step 19). There is no duplicate check on the e-mail (users may share a mailbox), and the duplicate Login ID check on Save is not case-sensitive, as before.

Browser checks on `BMMS_Test` (Chrome and Edge):

1. Add a user with `user1@example.com`: the 1 stays; Save; then edit and change it to `user22@test-mail.com`: saved as typed.
2. Paste `First.Last99@Example.com`: nothing is removed; it saves.
3. Paste an address of 51 characters: the box keeps 50.
4. Type `+tag@example.com`: the + is dropped.
5. `user1example.com` and `user1@@example.com`: "Invalid E-Mail Id"; an empty box: "EmailId is required field"; nothing is saved.
6. Edit an existing user and Save: the address is unchanged.
7. Error log: no entry from these checks.

## Step UM2: User Master, Edit / Deactivate / Delete stay inside the card (CSS only, no database script)

Cause: the User Master grid (11 columns) sits in a box that scrolls sideways (.wb-table-scroll) inside its card, which is at most 1166 px wide (#contentArea is at most 1200 px). Step G1 let its headings wrap, but an Email Id or Login ID has no space to wrap at, so with the BMMS_Test users the grid needs at least 1102 px. When the browser shows fewer than about 1140 px (a window that is not maximised, browser zoom, or Windows display scaling above 100%), the grid is wider than its card and the Delete column is cut off at the right edge until the box is scrolled.

Change: BMMS/CSS/bmms-workbench.css, one rule after the G1 heading rule, for this grid only (#ctl00_ContentPlaceHolder1_grvUser): 8 px instead of 12 px left and right padding in the headings and cells. The grid then needs at least 1014 px, and no word is broken. Other grids and pages are unchanged.

Why this option (measured with headless Edge on a copy of the grid with the live CSS, the 14 BMMS_Test users, at windows of 1366 and 1280 px and narrower): letting the cells break inside a word (overflow-wrap: anywhere), alone or together with the smaller padding, also fits, but it splits ordinary addresses such as gashpysoft@gmail.com and names in the middle even when the grid would fit, so it was not used. With the smaller padding the grid fits down to a content width of about 1060 px (also a 1366 px screen at 125% scaling), and nothing is split.

Known limit: with a 35-character address without spaces (for example firstname.lastname.dept@example.com) the grid needs about 1107 px; under about 1150 px of content width the Delete column is cut off again until the box is scrolled. Every column can still be reached by scrolling.

After deploying, reload User Master with Ctrl+F5 so the browser does not keep the old bmms-workbench.css.

Browser checks on `BMMS_Test` (Chrome and Edge, 100% zoom, window 1366 px and 1280 px wide):

1. User Master: Edit, Deactivate / Activate and Delete are fully visible on every row, with no sideways scroll bar; no address or name is broken inside a word.
2. Add a test user with the address firstname.lastname.dept@example.com and the designation Assistant Manager: at 1366 and 1280 px the three links stay visible, the address is on one line.
3. Edit, Deactivate / Activate (with its question) and Delete (on a test user) work; sorting by Email Id still shows the arrow next to its heading.
4. A narrower window (about 1000 px): the grid scrolls sideways inside the card and every column can be reached.
5. Member Master, Agenda Entry and Meeting Master look as before.
6. Error log: no entry from these checks.

## Step UN6a: an optional due date on a Followup decision (database script step 38 and code; test script for BMMS_Test)

Minutes.DueDate (datetime, NULL) existed, but nothing saved it: the Due Date column of Update Minutes was commented out, spr_UpdateMinutes had no parameter for it and the BAL / DAL defaulted it to today. Every row is NULL (29 on BMMS_Test, 9 on BMMS), so "overdue" cannot be shown. Decisions (Consultant, 2026-11-09): optional, only for a Followup decision; not before the meeting date; editable until the minutes are confirmed, like the other fields; a change of the due date is audited (the Decision change is not).

Database, step 38 (BMMS-Fix-MinutesDueDate-Step38.sql, marker MinutesDueDate-Step38), spr_UpdateMinutes:

- New last parameter `@DueDate DATETIME = '99991231'` (since step UN6a1 the default means "not passed"). Code 'All' (Save minutes): any decision other than Followup (DecisionTypeId 1) stores NULL. A Followup stores a passed date without its time, clears the date for an explicit NULL (the Clear button), and keeps the stored date when @DueDate is not passed, so a caller that does not know the parameter (an older build, the older tests) never clears it; an explicit 9999-12-31 counts as not passed. A Followup date passed before the meeting date is refused, Result 0, Reason 22, ReasonDetail the meeting date (dd-Mon-yyyy), and that row is not saved; a meeting without a date has no limit, and a kept date is not checked.
- A change of the stored due date writes one Audit_Trail_Master row: Audit_Type UP, Audit_Table Minutes, Key_Field AgendaNo, Field_Name DueDate, old and new as dd-Mon-yyyy (empty for none). No row when it is unchanged. The Audit Trail page shows these rows like the others.
- Codes 'Directions' and 'ActualResolution' leave the due date as it is. The locks are unchanged: refused once the minutes are confirmed (Reason 7) and, for a meeting created after step 23, before the agenda is finalized and the attendance entered (Reasons 17 and 18); finalized minutes (F) can still be changed, as the other fields.
- Only lines are added to the step 31 text, which carries steps 6 (FK #5), 16, 17, 18 and 23 as well; those steps still read Installed. The procedure was built from the definition installed on BMMS_Test on 2026-11-09, which is the step 31 script text exactly. Existing rows are not changed: they stay NULL.
- Re-run rule: the steps are installed in order, step 31 before step 38 (the step 38 script stops otherwise). Steps 6, 16, 17, 18, 23 and 31 each contain spr_UpdateMinutes: re-running any of them after step 38 brings back an older text and removes step 38 (BMMS-Check-InstalledSteps.sql: step 38 Missing). Run step 38 again afterwards, as the last of them.
- BMMS-Rollback-MinutesDueDate-Step38.sql restores the step 31 text and keeps the dates already stored and their audit rows. The build may stay: since step UN6a1 it sends @DueDate only when the procedure has it (see below).
- Step UN6a1 edited the step 38 scripts in place and added the marker DueDateKeep-Step38. A database with the first step 38 text (a missing @DueDate cleared the date) reads Partly, 1 of 2, in BMMS-Check-InstalledSteps.sql: run BMMS-Fix-MinutesDueDate-Step38.sql again (it is re-runnable over the first text); the test script stops until then.
- The step 31 test accepts the new parameter when step 38 is installed (9 parameters, the list ending with @DueDate).

**Build and database in any order (step UN6a1).** The first step 38 text cleared the due date whenever a caller saved Code 'All' without @DueDate, so an older build wiped the due dates of a meeting on every "Save minutes". Since step UN6a1 a missing @DueDate keeps the stored date, and the build sends @DueDate only when spr_UpdateMinutes has it (a check of sys.parameters once per Save, as for step 37's @ChangedFields). So an older build against a database with step 38 keeps the due dates (it cannot set them), and the new build against a database without step 38 saves the minutes as before, with the due date boxes disabled (tooltip "Due dates need database step 38 ..."). A database that still has the first step 38 text: run step 38 again before anyone edits minutes with an older build.

Code: BMMS/Master/MinutesUpdate.aspx and .aspx.cs, BMMSBAL/MinutesMgr.cs, BMMSDAL/MinutesDB.cs, BMMSBAL/MeetingMgr.cs (Reason 22 and its message).

- The Due Date column after Decision: the date box (not typed into; the calendar, dd-MMM-yyyy, as on Meeting Master), the calendar button and a Clear button (empties the box in the browser; the date is optional). Enabled only when the row's Decision is Followup (matched by its id, 1); choosing another decision empties and disables them. The stored date is shown when the minutes are opened again.
- Save minutes checks every row first (only when step 38 is installed), and saves nothing when one is wrong: "Agenda <No>: the due date is not a valid date (dd-MMM-yyyy). Nothing was saved." or "Agenda <No>: the due date cannot be before the meeting date (<dd-MMM-yyyy>). Nothing was saved." Each row is then saved on its own; a refusal from the procedure on a row (Reason 22 "The due date cannot be before the meeting date (...).", Reason 7 "The minutes of this meeting are confirmed ..." or any other) stops the loop and the message says what happened: "Nothing was saved." on the first row, otherwise "Saved: agenda <No>, <No>. Not saved: agenda <No> and the rows after it." (step UN6a1).
- MinutesBAL and MinutesDAL DueDate are DateTime? (null = none; before, a non-null DateTime defaulting to today), with SendDueDate (step UN6a1): the DAL adds @DueDate (SqlDbType.DateTime, DBNull for none) only when it is set; Save minutes sets it when MinutesMgr.HasDueDateParameter() is true; Directions and Actual Resolution never send it.
- Not changed in this step: the Dashboard action item grid and popup (step UN6b), the Followup page grid (its Due Date column is still commented out), the Followup, Followup Action Taken, Minutes and Minutes Extract reports. View_Minute, View_Action_Item and View_Action_Item_Users already return DueDate.

What to run where (the Consultant runs the scripts):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 31 Installed, step 38 Missing).
2. `BMMS_Test`: BMMS-Fix-MinutesDueDate-Step38.sql. It prints "Step 38 installed: ..." (a second run prints the same).
3. `BMMS_Test`: BMMS-Test-MinutesDueDate-Step38.sql (22 checks, all PASS; the last grid 0, 0, 0). Then the tests of steps 31, 23 and 16 with step 38 installed (they still pass).
4. BMMS-Check-InstalledSteps.sql again: step 38 Installed, 2 of 2; steps 6, 16, 17, 18, 23 and 31 still Installed.
5. Rebuild and deploy the build of step UN6a1 (in either order with the SQL, see above), then the browser checks below.
6. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build.
7. If step 38 must be undone: BMMS-Rollback-MinutesDueDate-Step38.sql (it prints "Step 38 rolled back"), then BMMS-Check-InstalledSteps.sql (step 38 Missing). The UN6a1 build may stay: the due date boxes are then disabled and the minutes are saved without them.

Browser checks on `BMMS_Test` (Chrome and Edge; keep the error log of the day open), on a meeting whose agenda is finalized and attendance entered, with minutes not confirmed:

1. Minutes, Update Minutes, choose the committee and meeting, Update Minutes: the Due Date column shows after Decision; for every row that is not Followup the box, the calendar and Clear are disabled and empty.
2. Set one item to Followup: the box, calendar and Clear become enabled. Pick a date after the meeting date with the calendar, Save minutes: "Successfully Saved". Open the meeting again: the date shows as dd-MMM-yyyy. In SSMS: `SELECT m.DueDate FROM Minutes m JOIN Agenda a ON a.AgendaId = m.AgendaId WHERE a.AgendaNo = '<AgendaNo>'` shows that date at 00:00:00.
3. Save minutes again without a change: no new Audit Trail row (`SELECT * FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' ORDER BY Audit_Trail_Maser_Id DESC`). Change the date, Save: one new row, old and new as dd-Mon-yyyy; Report, Audit Trail lists it.
4. Pick the meeting date itself: saved. Pick the day before the meeting date: the message "Agenda <No>: the due date cannot be before the meeting date (...). Nothing was saved." and no row of the meeting is saved (a Short Text change on another row is not saved either).
5. Clear, Save: the date is gone (NULL in SSMS) and one audit row (old date, new empty).
6. Set a date, then change the Decision to Sanctioned: the box empties and is disabled; Save: NULL in SSMS.
7. With a due date set: Edit the Actual Resolution of that item and save it, and (Followup) Add Directions and save: the due date is unchanged.
8. Minutes Finalization of the meeting, then Update Minutes again: the date can still be changed. After Minutes Confirmation: Save minutes is refused as before and the date is unchanged.
9. The other rows of the meeting and the minutes of other meetings stay NULL: `SELECT COUNT(*) FROM Minutes WHERE DueDate IS NOT NULL` counts only the rows set in these checks.
10. Step UN6a1, a refusal from the procedure: open Update Minutes for the meeting in two tabs; in the second, finish Minutes Finalization and Minutes Confirmation; in the first, change a Decision and Save minutes: "The minutes of this meeting are confirmed and can no longer be changed. Nothing was saved." (the first row is refused, so nothing is saved). A refusal on a later row ("Saved: agenda <No>. Not saved: agenda <No> and the rows after it.") needs the procedure to refuse a row the page check passed, for example the minutes confirmed between two rows of one save; it cannot be produced by hand reliably, and is covered by reading the code.
11. Step UN6a1, without step 38: BMMS-Rollback-MinutesDueDate-Step38.sql; reload Update Minutes: the due date boxes, calendar and Clear are disabled (tooltip "Due dates need database step 38 ..."), a stored date is still shown; Save minutes, Directions and Actual Resolution save without an error (no "too many arguments"); the stored dates are unchanged in SSMS. Run BMMS-Fix-MinutesDueDate-Step38.sql again: the boxes are enabled again.
12. Error log: no entry from these checks.

## Step ML2c: a bad Bcc address no longer stops a mail; one helper for the mail's item read (code only, no database script)

Found by the review of steps ML1 to UN6a. Since step ML2a the Bcc of SMTP Configuration goes on every mail, and the update mail (step ML1) puts every recipient's stored e-mail in one Bcc. Neither the SMTP Configuration Bcc nor Users.EmailId is checked on the server, and one address that could not be read (for example `john@`, or two addresses separated only by a space) threw an error and stopped the whole mail: no Reset Password mail, no Notice to any member, no approve / reject or update mail.

Code:

- BMMSBAL/Mail_Mgr.cs, AddRecipients and AddMailAddresses: an address in To or Bcc that is not valid is skipped, and the error log gets one entry per mail and address: "To address skipped, not a valid address: <address>" or "Bcc address skipped, not a valid address: <address>" (Mail_Mgr, AddMailAddresses). The To of the agenda, approve / reject, update and meeting mails is the stored address of the person who saved or decided, so a bad address there stopped the mail for every recipient before. The mail now fails (the error of the first bad To address, as before) only when no valid address is left in To and Bcc together. The page message is unchanged: the mail went out, the log names the skipped address, and that person gets no copy.
- SendWebEmail has a new optional ToRequired (default false). Reset Password and Notice set it: their mail is for the one user or member in To, so without a valid To address it fails as before, also when a Bcc is configured (no Bcc-only copy), and the page reports the failure as before (Reset Password: "... but the mail could not be sent ..."; Notice: counted in "sent N of M"). Send Mail keeps its own check of the typed addresses, so a bad To is refused before sending.
- BMMSBAL/AgendaMail.cs, new ReadItemAfterSave: the item read again after a saved decision, or null after the error log entry "Agenda <id> could not be read after the decision (the rejection); the mail is sent without the comment row." It replaces the same block in BMMS/DashBoard/DashBoard.aspx.cs and BMMS/Master/AgendaFinalization.aspx.cs; the log text, the page names in the log and the mails are unchanged.
- Not changed: no server check is added on SMTP Configuration Bcc or User Master Email Id (a later step may add one); no SQL.

Browser checks on `BMMS_Test` (smtp4dev on port 25 of the web server; keep the error log of the day open; made-up addresses only; note every value before changing it):

1. Bad SMTP Bcc: in SSMS `UPDATE SMTP_Master SET Bcc = 'copy@example.invalid, bad address'`. Report, Send Mail to `test1@example.invalid`: the mail arrives, copy@example.invalid in its Bcc; the error log has one line "Bcc address skipped, not a valid address: bad address". Notice to a meeting with two members: two mails, each with copy@example.invalid; two "skipped" lines. Set the Bcc back.
2. depuser with a bad address: `UPDATE Users SET EmailId = 'john@' WHERE LoginName = 'depuser'`.
   a. depuser saves a new agenda item: "Successfully Saved"; smtp4dev has the "has been Created" mail with mgruser in Bcc and no To; the log has "To address skipped, not a valid address: john@".
   b. depuser changes the Short Text and clicks Update: the "has been Updated" mail reaches mgruser; the log names john@ (To).
   c. mgruser approves the item (AMA): the mail is To mgruser with the Controllers in Bcc; the log has "Bcc address skipped, not a valid address: john@" (depuser is the creator).
   d. Reset Password for depuser, SMTP Configuration Bcc empty: the page says "The password was reset to the default password, but the mail could not be sent. ..."; nothing in smtp4dev; the log has the To skip line and the error.
   e. The same with SMTP Configuration Bcc `copy@example.invalid`: the same page message, nothing in smtp4dev (no Bcc-only copy, ToRequired); set the Bcc back.
   Set depuser's address back.
3. Bad To on Send Mail: to `john@`: refused by the page ("This mail address is not valid: john@ ..."), as before; nothing is sent.
4. Approve and reject mails: Dashboard, Manager approves (AMA) and rejects (AMR), Controller approves (ACA) and rejects (ACR); Agenda Finalisation with an item not yet approved (the "rejected by Controller on agenda finalized" mail). Each mail as in step ML2b: the detail block, Subject No when there is one, Meeting Date dd-MMM-yyyy, the comment row with its grey name and time line.
5. Error log: only the expected "skipped" lines and the two Reset Password errors (2d, 2e); no "could not be read after" line.

## Step UD1a: role and department history; several departments for a Manager (database script step 39 and code; test script for BMMS_Test)

Data only (requirement UD1, split UD1a / UD1b / UD1c; Consultant, 2026-11-09). Approval, alerts, mails, lists, reports and the Dashboard behave exactly as before: UD1b (approval and alerts) and UD1c (lists and reports) will read the new tables. Users keeps the current RoleId and DepartmentId, so nothing that reads Users changes.

Rules (UD1 rules 1, 9, 11, 12 and 6; the Consultant's answers to the plan, Q2 to Q10):

- Only a Manager can have several departments; Users, Controllers, Admins and the other roles keep one. The home department (Users.DepartmentId) is one of the Manager's departments and is the primary one.
- Two history tables for every user, `User_Role` (UserId, RoleId) and `User_Department` (UserId, DepartmentId, IsHome), each with EffectiveFrom (required), EffectiveTo (empty = current), CreatedOn / CreatedBy, ClosedOn / ClosedBy and CloseReason (C changed, D deactivated, R role changed away from Manager). A row covers EffectiveFrom up to, not including, EffectiveTo. Filtered unique indexes: one open role row per user, one open row per user and department, one open home department per user.
- Add opens the rows. Edit closes the old row (end date today) and opens a new one when the role or a department changes; a change of the home department closes and reopens the rows whose IsHome changes. Deactivate closes every open row. Activate opens the role row and the departments closed by the last deactivation; a department that is inactive now is skipped and named; an inactive home department refuses the activation ("Not activated: HRD is inactive. Reactivate it or change the user's department first."; before step 39 Activate did not look at the department).
- Delete: as before only when nothing refers to the user. The user's own history rows go with an otherwise unused user; rows the user wrote in another user's history (CreatedBy / ClosedBy) are history: Reason 6, group "user changes".
- Role change away from Manager: his other departments are closed (end date today, R); the home department stays. Refused (Reason 24) when he is the last active Manager of one of his departments that has open items waiting for a Manager, or when items waiting at AC are routed to him personally; ReasonDetail names both kinds. An Edit that removes a department checks that department only (not the items routed to him). No check on Deactivate in UD1a.
- "Open items waiting for a Manager": Agenda.AgendaStatusCode 'AC' on a meeting whose agenda is open (Meeting.AgendaStatus 'Open' or NULL), for the department Agenda.DepartmentId. "Routed to him": he has the item's alert, or he is the creator's manager (Users.ManagerId), as step 20 lets a Manager approve.
- Department delete: refused while a user has an open mapping to it (Reason 25, the users named), and also when only closed mappings exist ("used in history; make it inactive instead"). A home department is refused as before (Users.DepartmentId).
- Rule 6, setting `DeptNoManagerAction` (App_Setting): what a later step does when a department has no active Manager, `refuse` (default) or `controller`. Stored only in UD1a. Only an active Admin changes it, on System Settings; a change is written to Audit_Trail_Master (Audit_Table 'App_Setting'), as every setting. No separate change-log table (GM1 will read Audit_Trail_Master or create its own).
- The protected system account: its edit, delete, deactivate and role change are refused with Reason 7 before any history is written (fn_UserChangeRefusal is unchanged), so its rows never change after the seed or the migration.

Database, step 39 (BMMS-Fix-UserHistory-Step39.sql, marker UserHistory-Step39, 11 markers in BMMS-Check-InstalledSteps.sql):

- New tables User_Role and User_Department (keys to Users, Roles and Department), the setting row DeptNoManagerAction 'refuse' (only when missing), fn_ManagerReleaseRefusal (the rule 12 check), spr_GetUserDepartmentMap (the open mappings, for User Master) and spr_SetDepartmentManagerRule (the setting; Reasons 8, 4, 3 as spr_SetAppSetting).
- spr_AddEditUser (text of step 13): new optional last parameter `@DepartmentIds VARCHAR(MAX)`, the comma list of the user's department ids. It is read as numbers in a loop (digits and commas only, at most 2000 characters, each id at most 9 digits, no dynamic SQL); every id must be a department; a department added by the list must be active; only a Manager may have several; the home department must be in the list. Reason 23, ReasonDetail ListNotValid, DepartmentNotFound, DepartmentInactive, OneDepartmentOnly or HomeNotTicked; nothing is saved. NULL = not passed (an older build, the older tests): a new user gets the home department; an edit keeps the Manager's mappings and adds the home department. An inactive user's rows stay closed: only Users changes, Activate opens the rows. A user without any history row (inserted directly, as the older test scripts do) counts as mapped to the department in Users: a row is written only when something changes. On a role change away from Manager the result row carries ReasonDetail 'MappingsClosed:<names>' (Result 1).
- spr_SetUserStatusByUserId (text of step 13): Deactivate closes, Activate reopens (ReasonDetail 'NotRestored:<names>' for a department skipped because it is inactive; Reason 23 'HomeDepartmentInactive:<name>'). An active user's Activate opens nothing.
- spr_DeleteUserByUserId (text of step 13, five parameters as before): the group "user changes"; the user's own rows are deleted with the user.
- spr_DeleteDepartmentByDeptId (text of step 2): Reason 25 ('Mapped:<names>' or 'History'); Result as before, Reason and ReasonDetail added after it (Reason 5 for agenda items or users).
- spr_sys_ResetDatabase (text of step 30, which carries steps 3, 18, 21 and 29): clears the two tables before Users, starts their counters again at the seed and seeds one open role row and one open home department row per seed user, dated the reset day, created by user 1. App_Setting is not cleared, so the setting survives a reset.
- BMMS-Test-ResetDatabase.sql (Consultant's approval, 2026-11-09): its check "Keys to Users still present and trusted" expects 29 keys when step 39 is installed (the 6 keys of User_Role and User_Department to Users) and 23 without it.
- The three procedures of step 13 used THROW to pass an error on; the new texts use RAISERROR with the same message (compatibility level 100), so a caller sees the same text (error number 50000). The Reset Database text keeps the THROW lines of step 30 unchanged.
- Migration and re-sync (every run): an active user without an open row gets one role row and one home department row dated the install date, written by the system account; an inactive user without rows gets one closed row in each table (From = To = the install date, D), so Activate works. An open row that no longer agrees with Users is closed (C), an inactive user's open rows are closed (D). The script prints the counts. On BMMS_Test at the plan: 13 users, 4 Managers (3 active, 1 inactive).
- BMMS-Rollback-UserHistory-Step39.sql restores the step 13, step 2 and step 30 texts and drops the three new objects; it keeps both tables, their rows and the setting row (no history is lost; the Check script shows step 39 Partly, 3 of 11). While rolled back with rows in the tables, a user with history rows cannot be deleted (the keys of the tables: Reason 9, "other data still refers to them") and Reset Database fails and changes nothing: install step 39 again first. Running the Fix script again re-syncs and prints the counts.

**Build and database in any order.** The build sends @DepartmentIds only when spr_AddEditUser has it and spr_GetUserDepartmentMap exists (UserMgr.HasUserHistory, read once per page visit); without step 39 User Master works as before (no Departments managed list) and the System Settings card is hidden. An older build against step 39 calls spr_AddEditUser without @DepartmentIds: a new user gets the home department, an edit keeps a Manager's mappings, and the history is written.

Code:

- BMMS/Master/User.aspx and .aspx.cs, User.aspx.designer.cs: for the Manager role the Department row is labelled "Home department" and a "Departments managed" check list follows (the active departments; a mapped department that is inactive now is shown ticked with "(inactive)"). The home department is ticked and disabled (tooltip "Home department: change it above to untick"); choosing another home department keeps the previous one ticked. An inactive Manager's list is shown but disabled ("This user is inactive: the departments managed can be changed after Activate."). The list sent is built on the server from the items: the home department first, then the ticked ones; for any other role only the home department. The grid's Department column shows "HRD (primary), Credit, Admin" for a user with several departments, wrapped inside the column (CSS .wb-dept-list, max 10em).
- Messages: "Saved. Their department mappings were closed today: Credit, Admin." (role change away from Manager); "Activated. Not restored (department inactive): Credit"; Reason 23 "Not saved: ... Nothing was changed." per ReasonDetail, and "Not activated: <department> is inactive. Reactivate it or change the user's department first."; Reason 24 "Not saved: this Manager is still needed: last active Manager of HRD (2 items waiting); 1 item waiting for their own approval. Approve or reject those items first, or give the department another active Manager. Nothing was changed."
- BMMS/Master/Department.aspx.cs, BMMSBAL/DepartmentMgr.cs, BMMSDAL/DepartmentDB.cs: Reason 25 "This department cannot be deleted: it is mapped to <names>. Remove it from them in User Master first, or make it inactive." or "... it is used in the department history of users. Make it inactive instead."; other refusals keep the general message.
- BMMS/Master/SystemSettings.aspx, .aspx.cs and .designer.cs, BMMSBAL/Utilities.cs, BMMSDAL/UtilitiesDB.cs: card "Department without an active Manager", radio pair "Refused (default)" / "Sent to the Controller", Save, "Stored now, used from a later step", last changed by / on.
- BMMSBAL/UserMgr.cs, BMMSDAL/UserDB.cs: DepartmentIds, Reasons 23 and 24 and their messages, HasUserHistory, GetUserDepartmentMap. BMMS/CSS/bmms-workbench.css: .wb-dept-list.
- Not changed in UD1a: approval and routing (fn_AgendaRoute, spr_UpdateAgendaByAgendaId), alerts and mails; Agenda Entry still lists the items of the Manager's home department only (step 33); the Reporting Person list still offers the Managers and Controllers of the home department only (spr_GetMgrControllerByDeptId); reports and the Dashboard.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 38 Installed, step 39 Missing).
2. `BMMS_Test`: BMMS-Fix-UserHistory-Step39.sql. It prints the migration counts and "Step 39 installed: ...". A second run prints 0 opened and 0 closed.
3. `BMMS_Test`: BMMS-Test-UserHistory-Step39.sql (all PASS). Then the older tests that use the changed procedures, unchanged: steps 13, 14, 17, 18, 20, 21, the user delete tests (steps 10 and 11), the FK test (step 6), Reset Database (step 29 / 30) and steps 35, 36 and 37 (all PASS).
4. BMMS-Check-InstalledSteps.sql again: step 39 Installed, 11 of 11; steps 2, 3, 10, 13, 18, 21, 29 and 30 still Installed; the last grid "history rows agree with Users".
5. Deploy the build (in either order with the SQL), then the browser checks below.
6. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build.
7. To undo: BMMS-Rollback-UserHistory-Step39.sql, then the Check script (step 39 Partly, 3 of 11). Install step 39 again before deleting users or resetting the database.

Browser checks on `BMMS_Test` (Chrome and Edge at 100 percent; keep the error log of the day open):

1. User Master, Add, role Manager: "Home department" and the "Departments managed" list appear; the chosen home department is ticked and greyed (tooltip). Tick a second department, Save: "Successfully Saved"; the grid shows "<home> (primary), <other>" wrapped inside the Department column, with Edit, Deactivate and Delete still inside the card.
2. Change the role to User in the form: the list disappears and the label reads "Department". Back to Manager: it returns.
3. Edit the Manager: the ticks are shown; untick the second department, Save; tick it again, Save. Change the home department to the second one: the old home stays ticked; Save; the grid shows the new primary first.
4. Agenda Entry as a User whose reporting person is that Manager, in the Manager's home department: save an item (it waits at AC). Back in User Master as Admin, change the Manager's role to User: "Not saved: this Manager is still needed: ...". Approve or reject the item on the Dashboard as that Manager, then change the role again: "Saved. Their department mappings were closed today: ...".
5. Deactivate a Manager with two departments, make one of them inactive on Department Master, Activate: "Activated. Not restored (department inactive): ...". Deactivate again, make the home department inactive, Activate: "Not activated: ... is inactive. ..."; make both active again.
6. Delete a new user who did nothing: deleted. Delete a user with history: refused as before.
7. Department Master: delete a department that is only a Manager's second department: "it is mapped to <name> ..."; untick it in User Master and delete again: "it is used in the department history of users. Make it inactive instead."
8. System Settings: the card "Department without an active Manager" shows "Refused (default)" selected; choose "Sent to the Controller", Save: the message and "Last changed by <you> on ..."; Report, Audit Trail lists App_Setting DeptNoManagerAction refuse -> controller. Set it back.
9. As a Controller: User Master shows the same list for a Manager; System Settings is not reachable (Admin only).
10. Reset Database (only if you want to; on BMMS_Test): the four seed users open and edit normally; a Manager seed user shows one ticked home department.
11. Error log: no entry from these checks.

## Step RA1a: role access, user accounts and code masters for Admin only (database script step 40 and code; test script for BMMS_Test)

Owner decision RA1 (2026-11-10; split RA1a access, RA1b Management reports, RA1c unused pages). RA1a changes who may open and use the pages; no data changes.

Rules:

- Admin only: User Master, Department, Designation, Member Type, Subject Type and Decision Type (Master menu); Reset Password, Backup Database and, new in the Admin menu after System Settings, Audit Trail (Reset Database stays last). SMTP Configuration, System Settings and Reset Database stay Admin only.
- The Controller keeps Member Master, Committee Master, Committee Member Tag / UnTag, Meeting Master, Meeting - Member Tag / UnTag and Attendance, and loses the whole Admin menu and the Audit Trail report (its Reports menu now has 16 items). It changes only its own password (Change Password).
- No Home link for Admin and MD Secretariat (unchanged; the header link "Alerts (n)" opens the Dashboard).
- A hidden page is refused by address (PageAccess.xml in Enforce mode) and, as a second check, by the page itself, which reads the role from the database (an old session, LogOnly mode or a role changed during the session).

Database, step 40 (BMMS-Fix-RoleAccess-Step40.sql, marker RoleAccess-Step40, 3 markers in BMMS-Check-InstalledSteps.sql):

- fn_UserChangeRefusal (text of step 18): the Controller branch is removed, so the Controller has the rule of every role other than Admin: only its own Edit and ResetPassword; Create, and Edit, RoleChange, Deactivate, Activate, Delete and ResetPassword of another account give Reason 4. Rules 7 (system account), 1 (own account) and 2 and 3 (last active Admin / Controller) unchanged. Every caller follows: spr_AddEditUser, spr_CheckUserChange, spr_DeleteUserByUserId, spr_GetUserListForUserPage (the Can... flags), spr_ResetPasswordByUserId and spr_SetUserStatusByUserId.
- spr_AddEditMemberType and spr_DeleteMemberTypeByMemberTypeId (texts of step 21): an active Admin only (Reason 4 for a Controller, as for a Manager; Reason 8 for a missing or inactive acting user, unchanged). A database error is re-raised with RAISERROR('%s') instead of THROW (compatibility level 100), so a caller sees the same text as error 50000.
- Parameters and result sets unchanged; the markers of steps 13, 14, 18 and 21 are kept, so those steps still read Installed. Changes no data; safe to re-run.
- BMMS-Rollback-RoleAccess-Step40.sql restores the step 18 and step 21 texts unchanged (copied from BMMS-Fix-SystemAccount-Stage3.sql and BMMS-Fix-MemberTypes-Step21.sql; on BMMS_Test the restored definitions have the same SHA-256 as before step 40). It refuses when step 40 is not installed.
- BMMS-Test-RoleAccess-Step40.sql: 43 checks (markers, parameters, no THROW; the Controller refused, its own account allowed, Admin and Manager unchanged; the user procedures and the member type procedures end to end; the User Master list flags a Controller sees on the Manager, User and Management rows (all 0) and on its own row (edit only), and an Admin on a User row; nothing left after the rollback, identity counters put back).

Older Test scripts changed for step 40 (Consultant, RA1 Q4: only the Controller expectations the decision changes; the case numbers and names are unchanged; each changed line carries a "Step 40 (RA1a)" comment). After step 40 they pass; on a database without step 40 these cases fail:

- BMMS-Test-UserProtection-Stage1.sql: cases 38 to 69 (Controller on a Manager, User, Management and MD Secretariat user: the eight actions), 75 to 78 (Controller creates a Manager, User, Management, MD Secretariat user), 107 (spr_CheckUserChange, Controller resets a User's password) and 113 (list flags of the MD Secretariat row): from allowed to Result 0, Reason 4 (the list: 0 0 0).
- BMMS-Test-UserStatus-Stage2a.sql: cases 18 and 19 (Controller deactivates / activates a User) Result 0, Reason 4; case 31 (list, CanDeactivate of a User row for a Controller) 0.
- BMMS-Test-MemberTypes-Step21.sql: cases 15 (Controller saves a meeting type), 44 (Controller edits a free type) and 99 (Controller deletes an unused free type) Result 0, Reason 4. Case 51 (display order change of reserved type 3) now acts as the Admin and keeps its expected result, Result 0, Reason 7 (an Admin gets Reason 7 there with and without step 40; the Controller's refusal is covered by the step 40 Test); its name says "by an Admin". Two setup lines added, without a check row: the Admin saves the meeting type of case 15 and makes the edit of case 44, so the later cases start from the same types as before.
- Not changed (all PASS with step 40, as before it): the tests of steps 2 (delete procedures), 10 and 11 (user delete), 17, 18, 29 / 30 (Reset Database), 39 and the user-key workflows.

Code:

- BMMS/UserControl/MenuUserControl.ascx: the six code and user master items for Admin only; the Admin menu heading for Admin only; the Controller block of the Admin menu (Reset Password, Backup Database) removed; Audit Trail moved from the Controller's Reports menu to the Admin menu, after System Settings.
- BMMS/XML/PageAccess.xml: Department, Designation, MemberType, SubjectType, DecisionType, User, ResetPassword, BackupDatabase and Report/AuditTrail.aspx: admin only.
- BMMS/PageAccessModule.cs: new `PageAccessModule.RequireRole(params string[] roles)`: reads the role and status of the session's user from the database (View_Users through spr_GetUserByUserId), and for anyone else writes a line of type DENIED-PAGE with the reason "role not allowed by the page (allowed: [roles])" to App_Data/PageAccessLog.txt, answers the same "Access denied" page (HTTP 403) and ends the request with Response.End, so no event handler runs; a database error denies access (and is written to the error log). Called first in Page_Load of the nine Admin-only pages (Master/User, Department, Designation, MemberType, SubjectType, DecisionType, ResetPassword, BackupDatabase, Report/AuditTrail) and again first in the Reset Password and Backup Database buttons.
- Messages: BMMSBAL/MemberTypeMgr.cs Reason 4 "Only an Admin can change member types." (before RA1a: "Only an Admin or a Controller can change member types."); BMMSBAL/UserMgr.cs Reason 4 "You are not allowed to [action]. Only an Admin can change other users' accounts." (before RA1a: "You are not allowed to [action]. A Controller cannot change Admin or Controller accounts, or give anyone the Admin or Controller role."). No other text tells a Controller to use User Master, Reset Password or Backup Database (searched: pages, BAL, XML).
- Not changed in RA1a: the Management reports (RA1b), EventCalendar, FollowupActionTaken and ReportPrint (RA1c); the Department, Designation, Subject Type and Decision Type procedures (no acting user; see Known items).

**Build and database in either order.** The build alone keeps the Controller out of the pages; step 40 alone makes the database refuse the same changes (the build before RA1a then shows the Controller the Reason 4 message). Install both.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 39 Installed, step 40 Missing).
2. `BMMS_Test`: BMMS-Fix-RoleAccess-Step40.sql: "Step 40 installed: fn_UserChangeRefusal, spr_AddEditMemberType and spr_DeleteMemberTypeByMemberTypeId (RoleAccess-Step40); the markers of steps 13, 14, 18 and 21 kept." A second run prints the same.
3. `BMMS_Test`: BMMS-Test-RoleAccess-Step40.sql (43 PASS). Then BMMS-Test-UserProtection-Stage1.sql (142), BMMS-Test-UserStatus-Stage2a.sql (50) and BMMS-Test-MemberTypes-Step21.sql (100), and unchanged BMMS-Test-SystemAccount-Stage3.sql, BMMS-Test-UserStatus-Stage2b.sql, BMMS-Test-UserDelete.sql, BMMS-Test-UserHistory-Step39.sql, BMMS-Test-ResetDatabase.sql and BMMS-Test-UserKey-Workflows.sql (all PASS).
4. BMMS-Check-InstalledSteps.sql again: step 40 Installed, 3 of 3; steps 13, 14, 18, 21 and 39 still Installed.
5. Deploy the build, then the browser checks below.
6. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build.
7. To undo: BMMS-Rollback-RoleAccess-Step40.sql and the previous build, then the Check script (step 40 Missing).

Browser checks on `BMMS_Test` (Chrome and Edge at 100 percent; keep the error log and App_Data/PageAccessLog.txt of the day open). Test users for Management and MD Secretariat (Reset Database does not seed them): as Admin, User Master, Add, Role "Management" (then "MD Secretariat"), a department, Save; Reset Password gives the default password; the first sign-in asks for a new one. Remove them afterwards: Delete (a user who did nothing is deleted; otherwise Deactivate).

1. Admin: no Home; Master shows all twelve items; Admin shows Reset Password, Backup Database, SMTP Configuration, System Settings, Audit Trail, Reset Database in that order. Audit Trail opens and lists rows.
2. Controller: Home; Master shows only Member Master, Committee Master, Committee Member Tag / UnTag, Meeting Master, Meeting - Member Tag / UnTag, Attendance; no Admin menu; Reports has 16 items, no Audit Trail. Type Master/User.aspx, Master/Department.aspx, Master/Designation.aspx, Master/MemberType.aspx, Master/SubjectType.aspx, Master/DecisionType.aspx, Master/ResetPassword.aspx, Master/BackupDatabase.aspx and Report/AuditTrail.aspx: "Access denied" each time; PageAccessLog.txt shows DENIED. Change Password works.
3. User, Manager, Management, MD Secretariat: the menus as before; each of the nine addresses: "Access denied".
4. Role changed during a session (the RA1a build only): as Admin, create a test user ra1admin with the Admin role in User Master. Sign in as ra1admin in Chrome and open Reset Password. In Edge, as the normal Admin, change ra1admin's role to Controller. In Chrome, choose a user and press Reset Password: "Access denied", the password is not changed, no mail is sent. Then delete ra1admin (or deactivate it if it has history).
5. Error log: no entry from these checks.

## Step RA1b: Minutes report in every status for Controller and Management; Reports for Management (database script step 41 and code; test script for BMMS_Test)

Owner decision RA1, part RA1b (2026-11-10, with the correction of Q2 and the answers to the plan). Nothing else changes; RA1c (unused pages) and RA1d (the role read from the database on every request) are later steps.

Rules:

- The Controller and Management (role code mgmt) see the Minutes report (Reports.aspx?rc=minutes) for every committee in the list (active committees, as before) and every minutes status, drafts included. Every meeting carries its mark: Meeting.MinutesStatus 'F' = "Finalised", 'C' = "Confirmed", anything else (NULL, 'Open' or any other value) = "Draft (not finalised)". The meeting list shows only meetings that have at least one minutes row (View_Minute, what the report prints): a Minutes row is written only by Agenda Finalisation (spr_AgendaFinalizeByMeetingId) and for an item the Controller adds afterwards (spr_AddEditAgendaByController); spr_UpdateMinutes only updates rows, so a new meeting is not listed. Empty list: "No meetings with minutes for this committee."
- The Manager, the User and every other role keep the Minutes report of step 22: finalised and confirmed minutes only, no marks. Minutes Extract is unchanged for the Controller and the Manager (finalised and confirmed only); Management does not get it.
- Management gets a Reports menu with Minutes, Followup and Followup Summary (Followup.aspx?fc=followup and fc=summary): the same rows as the Controller's Followup (all committees in the list; the From and To dates are not used, as in the Controller's query), each item with its mark. The Controller's Followup is unchanged (no mark).
- The mark is in the report HTML: a line "Minutes status: [mark]" under each meeting heading (Followup: under each item; Followup Summary: a "Minutes status" column), and for a draft a bordered note "DRAFT - not finalised; this is not the approved text of the minutes." at the start and at the end of the meeting (Followup: under the item). The note is plain bold text in a one-cell table with border='1' (black), because the PDF export (iTextSharp HTMLWorker) draws a table border but not a div border; Print, Export to Pdf and Export to Word all use the same HTML. The grid of View shows a "Minutes status" column for the Controller and Management (Minutes) and for Management (Followup).

Database, step 41 (BMMS-Fix-ReportAccess-Step41.sql, marker ReportAccess-Step41, 3 markers in BMMS-Check-InstalledSteps.sql):

- spr_GetMinutesReportMeetingsAllStatus (@CommitteeId): the View_Meeting columns of spr_GetMinutesReportMeetings plus MinutesStatusMark, the meetings of the committee with at least one View_Minute row, by MeetingNo. Controller and Management.
- spr_GetMinutesReportAllStatus: the nine parameters of spr_GetMinutesReport, the same View_Minute columns, filters and order without the finalised / confirmed filter, plus MinutesStatus and MinutesStatusMark. Controller and Management.
- spr_GetFollowupReportForManagement (@CommitteeId, @MeetingNoSearch, @MeetingId, @FromMeetingId, @ToMeetingId, @DepartmentId, @ConfirmStatus): the View_Action_Item rows with the filters and order of the query ReportsMgr.GetFollowupReport builds for the Controller, plus MinutesStatus and MinutesStatusMark. Management only.
- Each takes @ActingUserId and gives @Result (1 / 0) and @Reason as OUTPUT parameters: Reason 8 acting user missing, 0 or inactive; Reason 4 any other role (checked in the database, not only in the page); a refused call returns no rows. Pages: "Your session is no longer valid. Please log in again." (8) and "You are not allowed to see this report." (4).
- Replaces nothing; spr_GetMinutesReport, spr_GetMinutesReportMeetings, View_Minute, View_Meeting and View_Action_Item unchanged. Changes no data; safe to re-run. BMMS-Rollback-ReportAccess-Step41.sql drops the three procedures (refuses when none exists).
- Prerequisites: step 22 and step 40. The Fix stops, with nothing changed, unless step 22 is installed (spr_GetMinutesReport and spr_GetMinutesReportMeetings carry the marker MinutesGating-Step22) and View_Minute, View_Meeting and View_Action_Item exist, and unless step 40 is installed.
- BMMS-Test-ReportAccess-Step41.sql: 44 checks: markers, parameters, result columns (the old columns in the same order plus the new ones), step 22 unchanged; who may call each procedure (Controller and Management; Management only for Followup; Manager, User, Admin and MD Secretariat Reason 4; inactive, 0 or no acting user Reason 8; no rows when refused); the meeting list in every status with the marks, a meeting without minutes rows and another committee left out; the minutes rows (every meeting, one meeting, a range, a department, subject numbers); the step 22 procedures still F and C only; spr_GetFollowupReportForManagement against a copy of the Controller's code-built query for nine filter combinations (no filter; committee; one meeting; meeting range; department; confirmed; not confirmed; committee, department and not confirmed; meeting range without a committee): the same rows by count and ActionItemId; nothing left after the rollback, identity counters put back.
- Existing Test scripts unchanged: the tests of steps 22, 23, 31 and 40 give the same results with step 41 as before it (no changed case).

Code:

- BMMS/PageAccessModule.cs: RequireRole unchanged in behaviour and log text (DENIED-PAGE, "role not allowed by the page (allowed: [roles])"); it now reads the role through a shared private ReadDatabaseRole. New HasRole(params string[] roles) (true for an active user with one of the roles, read from the database; refuses nothing) and RefuseRequest(reason) (DENIED-PAGE with that reason, "Access denied", Response.End).
- BMMS/Report/Reports.aspx.cs: Page_Load first refuses any rc other than minutes, minutes_extract, agenda_summary and agenda_details ("unknown report code"), then RequireRole("controller", "manager", "mgmt") for rc=minutes and RequireRole("controller", "manager") for the other three, so Management with another rc is refused on the server. The every-status path is `rc == "minutes" && PageAccessModule.HasRole("controller", "mgmt")`, decided from the database role on every request (not from the address or ViewState); it uses the two new procedures with the session's UserId, skips the "minutes not finalised" checks and shows the refusal message when the procedure refuses. On Generate, Session["ViewReportKind"] is cleared first and set only after the report is stored in the session, so a failed build leaves no kind (a database error that hides the role gives the finalised-only report: less, never more). Reports.aspx: the grid's "Minutes status" column (shown only on that path).
- BMMS/Report/Followup.aspx.cs: Page_Load refuses any fc other than followup and summary, then RequireRole("controller", "mgmt"); Management (HasRole("mgmt")) reads spr_GetFollowupReportForManagement, the Controller keeps ReportsMgr.GetFollowupReport; a session whose role is mgmt but whose database role could not be read is refused ("role could not be read for the Management path"), never given the Controller's path without the marks. The marks in both reports and the grid column for Management; Session["ViewReportKind"] cleared and set after the report is stored, as in Reports.aspx. Cancel now returns to the same report (Followup.aspx?fc=...; before, it went to Followup.aspx without fc, which gave the error page). Followup.aspx: the grid column.
- BMMS/Report/ViewReport.aspx.cs: for a user whose database role is mgmt (or whose session role is mgmt, so a database error does not skip the check: fail closed), Page_Load (every entry point: the report, ?pdf=1, the Export to Word and Export to Pdf postbacks; Print is the browser printing the page) refuses a missing, empty or unknown Session["ViewReportKind"] and ?pdf=1; only minutes, followup and summary pass. Controller and Manager unchanged.
- BMMSBAL/HTML_Report.cs: MinutesStatusLine, DraftNote, IsDraftMark. BMMSBAL/ReportsMgr.cs: the three calls, StatusMarkOf, the two messages. BMMSDAL/MinutesDB.cs and BMMSDAL/ActionItemDB.cs: the three procedure calls with the OUTPUT parameters.
- BMMS/UserControl/MenuUserControl.ascx: Management's Reports block (Minutes, Followup, Followup Summary). BMMS/XML/PageAccess.xml: mgmt added to Report/Reports.aspx, Report/ViewReport.aspx and Report/Followup.aspx.

**SQL first, then the build** (Consultant, Q5): the build calls the step 41 procedures; without them the Controller's and Management's Minutes report and Management's Followup show the error page. No fallback.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 40 Installed, step 41 Missing).
2. `BMMS_Test`: BMMS-Fix-ReportAccess-Step41.sql: "Step 41 installed: spr_GetMinutesReportMeetingsAllStatus, spr_GetMinutesReportAllStatus and spr_GetFollowupReportForManagement (ReportAccess-Step41); spr_GetMinutesReport and spr_GetMinutesReportMeetings of step 22 unchanged." A second run prints the same.
3. `BMMS_Test`: BMMS-Test-ReportAccess-Step41.sql (44 PASS). Then, unchanged, BMMS-Test-MinutesGating-Step22.sql (36), BMMS-Test-UnicodeText-Step31.sql (41), BMMS-Test-WorkflowOrder-Step23.sql (53) and BMMS-Test-RoleAccess-Step40.sql (43), all PASS.
4. BMMS-Check-InstalledSteps.sql again: step 41 Installed, 3 of 3.
5. Deploy the build, then the browser checks below.
6. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build.
7. To undo: the previous build first, then BMMS-Rollback-ReportAccess-Step41.sql and the Check script (step 41 Missing).

Browser checks on `BMMS_Test` (Chrome and Edge at 100 percent; keep the error log and App_Data/PageAccessLog.txt of the day open). Test users for Management and MD Secretariat as in the step RA1a section. A draft meeting: a meeting whose agenda is finalised (Agenda Finalisation writes the minutes rows) and whose minutes are not finalised.

1. Controller, menu Reports, Minutes: the meeting list includes the draft meeting and the finalised and confirmed ones, not a meeting whose agenda is not finalised. View: the grid's last column "Minutes status". Generate for the draft meeting: "Minutes status: Draft (not finalised)" under the heading and the bordered DRAFT note at the start and the end; Print, Export to Pdf and Export to Word of that report each show the line and the bordered note. A finalised meeting shows "Minutes status: Finalised" and no note. Minutes Extract: finalised and confirmed only, as before. Followup: as before (no mark).
2. Management, menu Reports: Minutes, Followup, Followup Summary only. Minutes as for the Controller. Followup: each item "Minutes status: ...", a draft item with the bordered note; Followup Summary: a "Minutes status" column; View: the grid column. Typed addresses: Report/Reports.aspx?rc=minutes_extract, ?rc=agenda_summary, ?rc=agenda_details, ?rc=xyz and Report/Reports.aspx without rc: "Access denied" each time; Report/ViewReport.aspx?pdf=1: "Access denied"; in a new browser session (sign in again), Report/ViewReport.aspx before any Generate: "Access denied".
3. Manager, menu Reports (4 items, unchanged): Minutes lists finalised and confirmed meetings only, no "Minutes status" column, no marks; a typed Report/Reports.aspx?rc=minutes shows the same. Report/Followup.aspx?fc=followup: "Access denied".
4. User, Admin and MD Secretariat: Report/Reports.aspx?rc=minutes, Report/Followup.aspx?fc=followup and Report/ViewReport.aspx: "Access denied".
5. Step RA1a regression: as the Controller and as the Manager, type the nine Admin-only addresses (Master/User.aspx, Department.aspx, Designation.aspx, MemberType.aspx, SubjectType.aspx, DecisionType.aspx, ResetPassword.aspx, BackupDatabase.aspx, Report/AuditTrail.aspx): "Access denied" each time, as after RA1a; PageAccessLog.txt shows the same lines as after RA1a (DENIED from the module, since PageAccess.xml refuses them first).
6. Followup, Cancel: returns to the same report (Followup or Followup Summary), not to the error page.
7. At 1366 px wide (laptop), as the Controller and as Management: View on Minutes and on Followup; the grid with the "Minutes status" column stays inside its card.
8. Error log: no entry from these checks.

## Step WF3a1: tester infrastructure; database BMMS_Quality with a fixture and a baseline (no product change, no numbered database step)

Owner decisions (2026-11-10): the tester uses BMMS_Quality, a restore of BMMS_Test made for it; BMMS_Test stays the owner's manual test database and the tester never touches it; the baseline is built as clear, then fixture, then baseline backup. WF3a1 is the infrastructure; the access-matrix pack and its proof are step WF3a2. How to run and how to read the results: Tests/README.md.

What is in the repository:

- Tests/_runner/Tester.Common.ps1: the fixed names (database BMMS_Quality, logins bmms_tester and bmms_site, port 18573, site copy Tests/_site) and the shared functions. Before every run each of the two logins is asked, as itself, what it can reach: refused when it can open any database besides BMMS_Quality and the system databases, can open BMMS or BMMS_Test (asked by name), is in a server role, holds CONTROL SERVER, IMPERSONATE ANY LOGIN or any IMPERSONATE grant, or (bmms_site) is in BMMS_Quality anything but a member of exactly db_backupoperator, db_datareader and db_datawriter. Every sqlcmd call goes through one function that accepts BMMS_Quality only (and master for the one RESTORE statement, which names [BMMS_Quality] in fixed text).
- Tests/_runner/Setup-Quality.ps1 (one time, the owner's Windows login, -ConfirmDatabase BMMS_Quality): checks that every row of BMMS-Check-InstalledSteps.sql reads Installed and that bmms_app is linked with db_backupoperator, db_datareader, db_datawriter (read only); clears BMMS_Quality with spr_sys_ResetDatabase; creates the SQL login bmms_tester (no server role) and makes it the owner of BMMS_Quality; creates the SQL login bmms_site (no server role) and its user in BMMS_Quality with db_datareader, db_datawriter, db_backupoperator and EXECUTE on the dbo schema (what bmms_app has there), before the baseline is taken so the baseline holds the user; generates the test passwords, hashes them with Common.HashPassword of the built BMMSBAL.dll and runs the fixture with the hashes; writes Tests/local/credentials.json (readable by the owner's Windows account only); takes the baseline BMMS_Quality_baseline.bak in the server's backup folder; restores it once as bmms_tester as the proof. It ends with the list of what it changed on the server.
- Tests/_runner/Update-Baseline.ps1 (after a new database step): everything as bmms_tester, never the sysadmin login. Restores the baseline, runs the Fix script(s) named (only BMMS-Fix-[name].sql from Database/; a script with USE or a sqlcmd command such as :connect, :r or !! is refused before anything runs, and the connection must still be on BMMS_Quality after each script), runs the fixture check and the Check script, takes the baseline again. If a part fails the old baseline stays.
- Tests/_runner/Run-Tests.ps1 (every run): preflight; builds the working tree into Tests/_build with MSBuild (OutDir and IntermediateOutputPath there, so bin and obj are untouched) and mirrors BMMS/ to Tests/_site; proves the copy is current (nothing left to copy, no code file newer than the build, the DLLs are the built ones); writes the copy's connection string from fixed parts (the local server, BMMS_Quality, the login bmms_site; BMMS/connectionStrings.config and bmms_app are not used) and proves it; restores the baseline as bmms_tester; sets the fixture dates; refuses unless every Check row reads Installed ("out of date") and the fixture check passes; starts IIS Express on http://localhost:18573; signs in as qa_admin and reads "Database: BMMS_Quality" in the footer (step F1); runs the self-test and the packs; writes Tests/_results/[date_time]/results.md and results.json. Exit codes 0 passed, 1 failed, 2 refused, 3 void, 4 runner failed. For the owner: -LeaveSiteRunning leaves the site copy on port 18573 after the run (to look at the fixture by hand; the report says how to stop it) and -StopSite stops it; the tester agent's guard allows neither.
- Tests/fixture/BMMS-Quality-Fixture.sql: stops unless the database is exactly BMMS_Quality and in the cleared state. Nine accounts through spr_AddEditUser as the seeded Admin (so the step 39 history rows are written): qa_admin, qa_ctrl (Controller), qa_manager (Credit), qa_manager2 (HRD home and Secretarial), qa_user (manager qa_manager), qa_user2 (HRD, manager qa_manager2), qa_mgmt, qa_mdsec, qa_inactive (made inactive with spr_SetUserStatusByUserId). Committee QA1 with a Chairman and a Member (spr_AddEditCommittee, spr_AddEditMember, spr_AddEditCommitteeMember). Six meetings 00001 to 00006: agenda open (items at AC, AMA, ACA, AMR, ACR and an HRD item at AC); submission date passed; agenda finalised; minutes in Draft; minutes Finalised (one Followup with its action item); minutes Confirmed. The items and the workflow go through the application's procedures in the application's order (spr_AddEditAgenda, spr_UpdateAgendaByAgendaId, spr_GenerateSubjectNoByMeetingId, spr_AgendaFinalizeByMeetingId, spr_UpdateMeetingChairman, spr_UpdateAttendance, spr_UpdateMinutes, spr_MinutesFinalizeByMeetingId, spr_MinutesConfirmByMeetingId). The six Meeting rows are inserted directly, as the Test scripts do, because spr_AddEditMeeting refuses a date before today. One transaction; a failure rolls everything back and names the step.
- Tests/fixture/BMMS-Quality-Fixture-Dates.sql: after every restore, sets the two date columns of the six fixture meetings relative to today (a direct UPDATE of those six rows, nothing else).
- Tests/fixture/BMMS-Quality-Fixture-Check.sql: read only, 29 checks (accounts with role, status and history rows, the form of the password hash only, the committee, each meeting's state and where its dates lie, the items by status, the workflow state, the action item, the mail settings localhost:25); ends with "FIXTURE CHECK: PASS (n checks)" or an error.
- Tests/lib/run.js (Node, playwright-core, the installed Chrome): the database proof, then the packs; requests to any host other than localhost are aborted and listed. Tests/packs/selftest: three true controls, one log control, one sign-in control and three deliberately wrong expectations that must fail.
- .claude/agents/tester.md and .claude/hooks/tester-guard.ps1: the tester agent runs Run-Tests.ps1 (-CheckOnly or -Pack) and git status --short, and nothing else (no sqlcmd: the runner runs the Check script and the fixture check as bmms_tester and saves their output in the results folder); it has no Write, Edit, Grep or Glob tool and reads only files inside Tests/_results/ (an allowed list, so Tests/local/ and every connectionStrings.config are out of reach whatever way a path is written).
- .gitignore: Tests/_results/, Tests/_site/, Tests/_build/, Tests/local/, Tests/node_modules/.

The fixture is not a numbered step: it has no row in BMMS-Check-InstalledSteps.sql and must never run on BMMS or BMMS_Test (its guard refuses any database not named exactly BMMS_Quality).

Found while building (facts about the product, nothing changed):

- The sign-in page takes at most 12 characters in User ID and in Password (LoginIdMaxLength and PasswordMaxLength in BMMS/XML/AppSettings.xml), so the test login names and passwords have at most 12.
- Port 49673 of the plan lies in the Windows range for outgoing connections (49152 and up) and was taken by another program at the first start; the site copy uses 18573.
- BMMS/XML/PageAccess.xml has 46 page entries (3 public); BMMS/ has 47 .aspx pages. The one page not listed is Error/TestPage.aspx (a signed-in user gets "Access denied" for it, as for every unlisted page). WF3a2's agreement check names it.

Test result of the build (2026-11-11, this laptop): Setup-Quality.ps1 ran to the end (fixture check 29 of 29; restore as bmms_tester worked); Run-Tests.ps1 -Pack selftest: PASSED, 5 checks, 3 of 3 planted failures caught, 23 seconds; -CheckOnly: READY; refusals seen for an unknown pack, a changed fixture script, a wrong -ConfirmDatabase, a file that is not a Fix script and a Fix script with USE [BMMS] (BMMS-Fix-Login-Procedures.sql); the guard hook (after the security review) blocked 20 of 20 commands, tools and path forms that are not allowed (among them the \\?\ and UNC forms, ::$DATA, an 8.3 short name, sqlcmd, Grep and Glob) and let 5 of 5 allowed ones through; bmms_tester has no server role, only CONNECT SQL, owns BMMS_Quality and cannot open any other BMMS database; Tests/local and Tests/_site/connectionStrings.config are readable by the owner's Windows account only. Update-Baseline.ps1 was run for real with the re-runnable BMMS-Fix-ReportAccess-Step41.sql (as bmms_tester; "STILL ON BMMS_Quality"; fixture check and steps passed; baseline taken again; the next run PASSED) and refused the four old Fix scripts that contain USE [BMMS]. Every run asks the server, as bmms_tester, which databases that login can open and refuses unless it is BMMS_Quality only. The tester agent itself ran the self-test pack and returned its record (PASSED, 18 seconds). Not exercised: the "out of date" refusal (it needs a step 42).

Closed after the security review (owner decision 2026-11-11): the site copy no longer signs in as bmms_app. It uses its own login bmms_site, mapped to BMMS_Quality only, so a server permission, not only the connection string, keeps the copy off BMMS and BMMS_Test. Seen on the server while the copy ran: its one connection to BMMS_Quality is login bmms_site; bmms_site can open master, tempdb, msdb and BMMS_Quality and nothing else. The user stays linked through every restore because the baseline holds it with the login's identity (SID) and setup never drops the login (a second run only changes the password).

Owner's tests of step WF3a1 passed on 2026-11-11 (the owner reports steps 1 to 10; the build report listed: the self-test run and its report, the fixture looked at by hand with -LeaveSiteRunning and stopped with -StopSite, the owner's own site untouched, a refusal, the logins in Management Studio, the permissions of Tests/local and of the site copy's connection file, Tests/README.md).

Error/TestPage.aspx (answer to the owner's question): a leftover of the recovered baseline (990b26d), referenced by nothing. Its Page_Load writes a trial PDF (Files/PDF/Test.pdf from Files/PDF/pdf.css, PDFUtilities.GenerateHTMLPdf) and shows an empty page. Nobody can open it today: it is not in PageAccess.xml, and PageAccessModule in Enforce mode treats a page that is not listed as not allowed, so a signed-in user of any role, Admin included, gets "Access denied" (HTTP 403, logged as DENIED with "page is not in PageAccess.xml") and a visitor who is not signed in is sent to the sign-in page; Page_Load never runs. It does not belong in the product: remove it with the unused pages (RA1c).

## Known items for later steps

- Step WF3a1 security pass (owner, 2026-11-11): the sign-in page limits the password to 12 characters (PasswordMaxLength in BMMS/XML/AppSettings.xml, as the User ID by LoginIdMaxLength; ChangePassword and ChangePasswordFirst ask for more than PasswordMinLength 6). Twelve is short for today's guidance; raising it touches the sign-in page, the two change-password pages, Reset Password and the User Master. Take it up in a security step.
- Step WF3a1: Error/TestPage.aspx is a leftover of the baseline that writes a trial PDF in Page_Load; it is not in PageAccess.xml, so nobody can open it ("Access denied" for every role). Remove it with the unused pages (RA1c); WF3a2's agreement check names it as the one page on disk that is not listed.
- Step WF3a1 security review (Low): Update-Baseline.ps1's scan of a Fix script does not see USE inside dynamic SQL or a three-part name; the wall is that bmms_tester can open no other database (asked of the server before every run). sqlcmd runs without -X.
- Step WF3a2, first task (the four open security Lows of step WF3a1, before the access-matrix pack is built):
  1. Pre-run check allow-list: Assert-QaLoginReach refuses CONTROL SERVER and the IMPERSONATE rights, not every other server right a sysadmin might grant later (ALTER ANY LOGIN, for example); Setup-Quality.ps1 does refuse anything but CONNECT SQL. Use the same allow-list before every run, for bmms_tester and bmms_site.
  2. Role check timing: the check of bmms_site's database roles runs before the restore (on the database as the last run left it), and Update-Baseline.ps1 takes the new backup without checking again after the Fix scripts. Check once more after the restore in Run-Tests.ps1 and before the backup in Update-Baseline.ps1.
  3. icacls read-back: after icacls on Tests/_site/connectionStrings.config the runner does not read the permissions back before it writes the password (an explicit entry of another account already on the file would stay). Read them back as Test-QaLocalDirAcl does and refuse otherwise.
  4. Reachability check for -LeaveSiteRunning: IIS Express started with /path and /port should answer only to the host name localhost. Seen by the owner on 2026-11-11 while the site copy ran: port 18573 listens on ::1 and on ::; the Windows Firewall is on (all three profiles) and has no allow rule for IIS Express or for port 18573. Whether another machine can reach the port has not been tested. Assert the listener and firewall state in Start-QaSite (or refuse -LeaveSiteRunning otherwise) and test once from the other laptop.
- Step WF3a1 security review (Low): linked servers are not checked (a linked server with a default login mapping would give bmms_tester a way out); Setup-Quality.ps1 should refuse when sys.linked_logins has such a row.
- Step WF3a1 security review (Low): new error-log lines of the site copy are copied to Tests/_results, which the tester agent can read; confirm that the application's error log never carries connection details.
- Step WF3a1 security review (Low): the restore sets SINGLE_USER from a connection on master, so another connection can take the single slot before RESTORE (three tries, then the runner fails and BMMS_Quality may be left in SINGLE_USER; nothing outside BMMS_Quality is affected).
- Step WF3a1 security review (Low): a pack (Tests/packs/[name]/pack.js) is Node code with the owner's rights; the localhost-only rule covers the browser's requests only. Packs are written in a step's build and must be reviewed as code by security-reviewer (WF3a2 and every later pack).
- Step WF3a1 UX review (Low): several rare refusals give the cause but no remedy (no bmms_tester entry in credentials.json, MSBuild not found, an unexpected backup file name); the README row "Anything else" covers them for now.
- Step WF3a1: IIS Express of the site copy is started without a log file (so that a copy left running holds none of the runner's pipes); when it does not start, the runner says so but cannot show IIS Express's own message.
- Step WF3a1: the tester has no retry yet ("passed on retry" of the plan); a check that fails once is reported as failed. Add it only if a pack turns out to be unsteady.
- Step WF3a1: App_Setting MailSenderUserId keeps its value through Reset Database (6 in BMMS_Quality, which after the clearing is the user id of qa_ctrl); a pack that tests mail must look at it.

- Step RA1a security lead (not fixed): only the nine Admin-only pages check the role in the database (PageAccessModule.RequireRole); the menu and every other page follow the role stored in the session (Session["RoleCode"]) until sign-out, so a role changed during a session counts on those pages only at the next sign-in. A later step (RA1d) closes this.
- Step RA1a (Low, Consultant RA1 Q3): the Department, Designation, Subject Type and Decision Type procedures take no acting user and check no role; only PageAccess.xml and the page check keep the Controller out. Add acting-user checks to them (and @ActingUserId to their data-layer calls) in a later step.
- Step RA1a: the older Test scripts of steps 13, 14 and 21 carry the Controller expectations of step 40 (see the step RA1a section); on a database without step 40 those cases fail.
- Step RA1a review (Low): BMMS-Rollback-RoleAccess-Step40.sql restores the step 21 member type texts exactly, THROW included (the Fix replaced it by RAISERROR); after a rollback, part 1 of the step 40 Test ("No THROW left") would fail, as it does without step 40.
- Step RA1a review (Low): Reset Password sends its notice to the address in the hidden field hdnEmailId, which a tampered postback can change (the user reset comes from the list); the mail carries no password. Read EmailId again by UserId on the server in btnResetPassword_Click.
- Step RA1a review (Low): a refused UpdatePanel postback gets the plain 403 page of PageAccessModule (as the module did before step RA1a), which the browser shows as a script error, not the "Access denied" page.
- Step RA1a review (Low): the menu is built from Session["RoleCode"] while the page check reads the role from the database; after a role change during a session the old menu stays until the next sign-in and its links end on "Access denied". A refused Reset Password or Backup Database click shows "Access denied", not a message that nothing was done (nothing runs).
- Step RA1b (Consultant): the Controller's Followup and Followup Summary reports read a query built in the code (ReportsMgr.GetFollowupReport: `SELECT * FROM View_Action_Item WHERE ...` with the filters appended); RA1b adds a procedure for Management only and leaves this path unchanged. Move it to a procedure in a later step.
- Step RA1b (Consultant Q1): the Controller's Followup and Followup Summary show no minutes status mark (its code path is unchanged); Management's do. Mark the Controller's too when its query moves to a procedure.
- Step RA1b (Consultant Q2): Followup and Followup Summary ignore the page's From and To meeting dates (the Controller's query never used them; spr_GetFollowupReportForManagement does the same, for the same data scope).
- Step RA1b (Consultant Q6): the Minutes and Followup reports list active committees only (CommitteeMgr.GetCommitteeList(1)), for every role; the minutes of an inactive committee cannot be reported.
- Step RA1b review (Low): the other pages that open ViewReport.aspx (FollowupActionTaken, Agenda Approval, Notice, Sitting Fees) neither set nor clear Session["ViewReportKind"]; after a role change to Management during a session (RA1d), a kind left by an earlier Minutes or Followup report could let ViewReport show such a report. ?pdf=1 is refused to Management anyway. Clear the kind wherever Session["ViewReport"] or Session["ReportPdf"] is set.
- Step RA1b review (Low): Reports.aspx and Followup.aspx read the role from the database twice per request (RequireRole, then HasRole); read it once and use the value for both.
- Step RA1b review (Low): on a database error in the HasRole call of Reports.aspx the Controller and Management get the finalised-only Minutes report (fails safe: less data).
- Step RA1b review (Low): the step 41 procedures, like step 40, test AccountStatus = 1 but not IsSystem = 0; the protected system account has the Admin role and gets Reason 4.
- Step RA1b review (Low): Reason 8 ("Your session is no longer valid. Please log in again.") is a message only, with no link or redirect to the sign-in page.
- Step RA1b review (Low): Management's Followup repeats the bordered draft note for every draft item (not once per meeting); a long list of drafts is noisy.
- Step RA1b review (Low): the Followup page shows From and To date boxes that the Followup query does not use (Q2), for the Controller and for Management, with no hint.
- Step RA1b review (Low): the new "Minutes status" grid columns are 150px wide next to the fixed widths of the existing columns; whether the grids still fit inside the card at 1366 px is a browser check (browser check 1 and 2). DraftNote keeps both border='1' (the PDF export needs it) and the CSS border (Word, browser): do not remove the attribute.
- Step RA1b test (Low): in the PDF of a draft the top border of the DRAFT note touches the "Minutes status" line.
- Baseline (Low, seen in the RA1b tests): the View button's onclick on Report/Followup, Master/Followup, MinutesFinalization and MinutesUpdate calls MinutesFinalizeValidation, which no page defines (console: Uncaught ReferenceError); the pages still work. It comes from the recovered baseline 990b26d.

- Step UD1a: Agenda Entry lists a Manager's home department only (step 33), and the Reporting Person list offers the Managers of the home department only; UD1c (lists and reports) will use User_Department.
- Step UD1a: approval still follows the creator's manager (step 20); a Manager's second department gives him no approval until UD1b. The department check of rule 12 prepares for UD1b.
- Step UD1a: after BMMS-Rollback-UserHistory-Step39.sql, while the history rows exist, a user with rows cannot be deleted and Reset Database fails (the keys of the two tables); install step 39 again first.
- Step UD1a: a new agenda item saved at the same moment as the role change of its department's last Manager is not locked out by the rule 12 check (accepted: approval is unchanged in UD1a).
- Step UD1a review (Low): on Update, a department already mapped but inactive now can be made the home department through a direct call of spr_AddEditUser (Save and Activate refuse an inactive home department); User Master lists active departments only.
- Step UD1a review (Low): two Managers of one department leaving it at the same moment can deadlock in spr_AddEditUser (each holds his own User_Department rows, then asks for the other's); one save is rolled back and shows the error page. No rule is bypassed.
- Step UD1a review (Low): UserDB.HasUserHistory reads sys.parameters with a constant inline query (no input), once per page visit, not through a procedure.
- Step UD1a review (Low): spr_DeleteDepartmentByDeptId has no acting-user check and runs its checks and the delete without a transaction (as before step 39); a mapping added at the same moment gives error 547 and the error page.
- Step UD1a review (Low): while step 39 is rolled back, the restored step 2 department delete hits error 547 for a department with history rows only, and the Department page shows the error page.
- Step UD1a review (Low): the 'Saved. Their department mappings were closed today' message is green (Success) and is recognised by its text prefix.
- Step UD1a review (Low): Reason 24 with only items routed to him personally still advises 'give the department another active Manager', which does not help there; no hint to use the Dashboard.
- Step UD1a review (Low): for an inactive Manager the list shows only the home department (the others are closed) and does not name the departments Activate will restore.
- Step UD1a review (Low): the department delete refusal names every mapped user; with many it is a long banner (shorten to a few names and 'and N more').
- Step UD1a review (Low): the tooltip of the disabled home check box is on the wrapping span; whether Chrome and Edge show it over a disabled box is not verified (else put the text in the note).
- Step UD1a review (Low): after a change of home department the old one stays ticked on purpose; no note says so.
- Step UD1a review (Low): the vertical Departments managed list (.wb-radio-list) has no row spacing; small click targets with many departments.
- Step UD1a review (Low): the .wb-dept-list rule is tied to the client ID of grvUser (as the G1 and UM2 rules); a department name with spaces now wraps at 10em, so rows grow; the action buttons' vertical alignment in a 3-line row is not verified.
- Step WF2a review (Low, unverified): an entity code without its closing semicolon inside a Mermaid label of a user manual is not caught by Check-UserManuals.ps1 (Mermaid runs with strict security and no HTML labels, so it is expected to show the text as typed).
- Step WF2a review (Low): the Glossary does not say that the Management role's Reports menu is empty; it is listed under To confirm in the Glossary's register entry (Documents/README.md) for WF2d1.
- Since step ML1 an Update on Agenda Entry that changes something sends a mail (step 37).
- The mail goes out From the From Mail Id of SMTP Configuration; MailSenderUserId only records which account that should be (step ML1). Mail_Mgr does not use TLS (EnableSsl is not set), so only a server that accepts plain SMTP works (a local relay); Office 365 or Gmail on port 587 would need a code change.

- Agenda Entry comment changes are not in the Audit Trail (spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController audit no MgrComments or ControllerComments change; Approve and Reject do). On the backlog (Consultant, step UN4); step 35 records only who last saved the comment and when, not the old text.
- Agenda.MgrApprovedBy / MgrApprovedDate and ControllerApprovedBy / ControllerApprovedDate keep their names but, from step 35, hold whoever last saved the comment or recorded the decision (step UN4). A rename would touch View_Agenda and every reader; not planned.
- The four user-list procedures (spr_GetUser, spr_GetActiveUserList, spr_GetMgrControllerByDeptId, spr_GetUserListForUserPage) still return the Password column (`v.*` of View_Users), though no caller of theirs needs it; the hashes stay on the server (step PW1). Leaving it out of them is a database step of its own, and the test scripts of steps 13, 14 and 18 that fill a table from spr_GetUserListForUserPage would need the same column change. View_Users itself keeps Password: the login and the password change read it through spr_GetUserByLoginName and spr_GetUserByUserId.
- Optional: ViewState encryption on the six pages whose ViewState is still readable. A page's ViewState is encrypted only when a control on it asks for it (a GridView, DetailsView, FormView or DataList with data keys; `viewStateEncryptionMode` is the default "Auto"), and by their markup six pages that keep tables in ViewState have none: DashBoard, Attendance, Minutes Confirmation, Minutes Finalization, Attendance Details and Notice. Their ViewState is signed but can be read after base64 decoding. None of them carries a password (step PW1 checked every procedure that returns a Password column). `viewStateEncryptionMode="Always"` on `<pages>` in Web.config would encrypt the ViewState of every page; a step of its own, to test on every page.
- Agenda Entry, sorted by "Subject Type Name": the sort arrow makes the grid about 3 px wider than its card, so it scrolls sideways a little (measured with the BMMS_Test rows of meeting 516; the same before and after step G1, so not caused by it). Not changed in step G1.
- The login ID in the header is a tooltip only, which a touch screen cannot open (accepted for phones, step UN2 (names)).
- Access log, as before step UN2 (names): a second login of the same user closes the first row without a logout time, and a logout or session end in one window closes the user's open rows of every window (spr_AddEditAuditTrialLogin closes by User_Id); a wrong password or an unknown login writes nothing.

- The colour picker on Committee and Meeting (third-party JScript/ColorPicker/js_color_picker_v2.js) asks for its tab and slider images relative to the page (`/Master/images/tab_right_active.gif`, `slider_handle.gif`), which gives 404; its own copies are in JScript/ColorPicker/Images. Seen in step B3, not changed.
- Mail has no TLS or STARTTLS: Mail_Mgr never sets EnableSsl, so a mail provider that requires an encrypted connection (usually port 587) refuses every mail (step 30).
- The Bcc of SMTP Configuration is ignored when the caller passes no Bcc of its own (Reset Password, Notice, Send Mail): Mail_Mgr.SendWebEmail replaces it by null (step 30).
- From Mail Id and Bcc are cut at 50 characters without an error: the parameters of spr_UpdateSMTPMaster are VARCHAR(50) (step 30 kept the sizes).
- The SMTP password is encrypted with Windows DPAPI for the machine (Common.ProtectSecret): after the database moves to another server it cannot be read there and every mail with a login fails until the password is entered again on SMTP Configuration. The safe default has no password, so it works anywhere (step 30).

- Files left by a Reset Database: the upload folders (Files/AgendaAttach, AgendaText, MemberPhoto, MemberResume) and the backups in Files/SqlBackup are not removed; the page shows their counts (step 29). Deleting them is a later step.
- Step 27: a login-checked download page for agenda attachments and agenda text, member photos and CVs, and Send Mail attachments (move `~/Files/Temp` to App_Data); then add Temp to the hidden segments in Web.config. Until then these files can be fetched by URL without logging in.
- Fixed in step SM1: Send Mail deleted every file in `~/Files/Temp` when anyone attached a new file, so two Controllers composing at once lost each other's attachment.
- Deleting a directory inside the application folder restarts the application and loses the in-process sessions; code must delete files, never directories, there. The Temp folder outside the application folder is part of step 27.
- The Send Mail audit row stores the full server path of the attachment: Mail_Mgr.SendWebEmail passes the path it was given to Common.SaveSendMail (Audit_Trail_SendMail). Store the file name only in a later step (Mail_Mgr is shared by every mail page).
- A mail that was sent but whose audit row could not be saved (Common.SaveSendMail after smtp.Send) is reported by Mail_Mgr.SendWebEmail as a failure, so Send Mail says "The mail could not be sent" although the mail went out.
- Uploads larger than the ASP.NET default of 4 MB (no maxRequestLength in Web.config) are refused before the page runs and show the safe error page; Send Mail and Agenda Entry give no message of their own.
- Agenda Approval, an agenda whose text was uploaded as a file: it is read with WordUtilities.ReadWordDocument on a relative path through Word, while uploaded agenda texts are PDF files, so that text is probably missing from the PDF (AgendaApproval.aspx.cs).
- Database backups should later be written outside the web root (Backup Database writes to `~/Files/SqlBackup`, now hidden but still inside the site folder).
- Other exception text still shown on purpose (kept by E1 and E2): the Notice page's "The notice could not be sent: <message>" (HTML-encoded). Replace it with a fixed text in a later step. The mail error text of Mail_Mgr ("Error: <message>") is no longer shown by any page (steps M1, SM1, M2).
- Notice Send Mail: no rule yet about meetings in the past.
- Agenda Entry, step M4: spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController do not refuse a new item after the meeting date; only the page checks. A database step can add the rule there.
- Agenda Entry: Add puts the meeting id into Meeting No and the meeting number into the hidden meeting id (btnAdd_Click), so the "Agenda Created" mail shows the id as the Meeting No. (Edit of an item of a meeting with no date opens since step M5.)
- Agenda Entry is reachable by Controller, Manager and User (PageAccess.xml); step M4 kept it so.
- Agenda Entry, Subject No (step N5): the page reads the item just before the save, so a Dashboard approval that lands between that read and the procedure's UPDATE can still be overwritten by the posted value (NULL, or an old 0). The gap is accepted for now. Future fix, in the install-all script: `SubjectNo = CASE WHEN ControllerApprovedStatus = 'Approved' THEN SubjectNo ELSE @SubjectNo END` in the Update branches of spr_AddEditAgenda, spr_AddEditAgendaByManager and spr_AddEditAgendaByController.
- Agenda uploads, orphan files (step N2 left it): a file is saved when it is chosen, before Save and without the meeting-date, lock or role checks; files of items never saved, files unticked later and replaced agenda texts stay in Files/AgendaAttach and Files/AgendaText. Nothing removes agenda files.
- Agenda uploads, content not checked: only the extension .pdf is checked on the server; any content with that name is stored and served from the Files folders (without login until step 27).
- Agenda Details report: one attachment or agenda text that is missing or not a PDF makes the whole PDF fail (PdfReader throws), for every user of that meeting.
- Agenda uploads: the Agenda No goes into the saved file name without cleaning (Agenda.aspx.cs, btnAddFile_Click and btnAddAgentaText_Click). It comes from the committee code and the meeting number; a committee code with \, / or .. would change the folder, and one with another character not allowed in file names would make the save refuse the name (step N2).
- Member: the photo and resume paths (hidden text boxes) are stored as posted; nothing opens a file from them today. The photo and resume uploads have no type check.
- Request validation (step A2a): on again on Agenda.aspx and MinutesUpdate.aspx. Text such as `a<b` in a plain text box of those pages (Short Text, the Subject No box) gives the safe error page and one redacted error-log entry, as on the master pages since step A1b (accepted). The Dashboard, Followup and Send Mail have it on again since step A3 (see the step A3 item); eleven other pages keep it for other reasons (ChangePasswordFirst, Logout, AgendaFinalization, Attendance, BackupDatabase, ChangePassword, MinutesConfirmation, MinutesFinalization, ResetPassword, SMTPServerConfig, Report/AttendanceDetails).
- Rich-text editor (step A2a): it uses document.execCommand, deprecated but supported by Chrome and Edge; if a browser version drops it, the fallback is the Squire library (MIT) under the same control. Word list conversion is best effort: a list Word does not mark with mso-list stays paragraphs.
- Rich-text limits (step A2a) count characters of HTML, so formatting counts too; a post that the script cannot stop (a drop-down that posts back on change) still goes, and the server refuses the next save while the text is over the limit.
- Agenda Entry, Agenda Type Upload (step A2a): text typed into Agenda Text before choosing Upload stays in the hidden editor and is saved as AgendaText of the Upload item; it is never shown for an Upload item.
- Fixed in step A2a: choosing Agenda Type Entry again after Upload blanked Agenda Text (baseline, rdoAgendaType_SelectedIndexChanged); the text typed before the switch now stays.
- Update Minutes (baseline, kept in step A2a): the Directions column (Add button, Directions editor) and the Proposed Resolution column (View button, read-only Proposed Resolution editor) are in the page and its code but both grid columns are Visible="false" (MinutesUpdate.aspx), so neither editor can be opened for any decision type; for Followup the code still shows the Directions button inside the hidden column. Both editors were moved to the new control and are otherwise unchanged; the Agenda Short Text View button is hidden too, so its popup cannot be opened either. The grid has AllowSorting="true" but no column has a SortExpression, so sorting does nothing (baseline).
- Request validation (step A3): on again on the Dashboard, Followup and Send Mail. A `<` followed by a letter, such as `a<b`, typed into Dashboard Short Text (editable for the Controller) or into Send Mail To or Subject gives the safe error page and one redacted error-log entry, as on Agenda Entry since step A2a (accepted). Followup has no plain text box that takes free text.
- Rich-text limits (steps A2a and A3): while an editor is over its limit every button post of the page is held back, Close, Cancel and X too (Dashboard panels, Followup popups, Update Minutes panels); shorten the text or reload the page.
- Dashboard, action item (baseline, kept in step A3): for admin, mgmt and md_sect Action Text is read-only but Submit is shown; it saves the shown text again (spr_UpdateActionItem, code ActionText), so a change made meanwhile in Followup is overwritten.
- Dashboard, Approve and Reject (baseline): spr_UpdateAgendaByAgendaId writes the audit rows of MgrComments or ControllerComments on every approval or rejection, changed or not (Old_Value empty).
- Followup, Save of Action Text (baseline, kept in step A3): the action item id is read with Convert.ToInt16 (Followup.aspx.cs, btnActionTextSave_Click), so an ActionItemId above 32767 gives the error page.
- Followup, Save of Action Text (baseline, kept in step A3): no check of the session, the role or that the action item still exists, and no message on success (the popup closes).
- Send Mail (baseline, kept in step A3): a mail with an empty Body Text is sent without a warning.
- Rich-text limits (step A3 test): the limits count characters of HTML, not typed characters. The browser stores a trailing space as `&nbsp;` (6 characters), so `abcd ` repeated 40000 times (200000 typed characters) gave about 200005 characters of HTML and was refused, while 39990 repeats were accepted.
- Send Mail (step A3): the editor has no fixed width, so one unbroken string of about 200000 characters (for example a very long URL) widens the editor and the page scrolls sideways; text with spaces wraps normally. Cosmetic; a CSS line that wraps such strings inside the editor is a later item.
- Dashboard (step A3): when the server refuses a too-long text (browser check switched off), the page comes back and shows the message under the editor; the message at the top of the page is not seen because the alert panel is long. Nothing is saved and no mail goes out (tested on Approve).
- Fixed in step A4: seven pages carried only the FreeTextBox Register line and no FreeTextBox editor (Master/Agenda.aspx, Master/MinutesUpdate.aspx, Master/AgendaFinalization.aspx, Master/Attendance.aspx, Master/MinutesConfirmation.aspx, Master/MinutesFinalization.aspx and Report/AttendanceDetails.aspx); the lines, the FreeTextBox reference and licenses.licx in BMMS.csproj and bin/FreeTextBox.dll are removed.
- Agenda Entry and Update Minutes layout (step A2b): the action bar sticks to the bottom of the window because bmms-forms.css turns off the sideways scrolling of the content area while one of these pages is shown (`:has()`, Chrome and Edge 105 and later); in an older browser the bar stays at the end of the form. The Comments card is hidden the same way when no comment editor shows.
- Agenda Entry (step A2b): the Agenda No of a new item is shown as "Assigned on Save", but the "Agenda Created" mail and the attachment file names still use the number predicted when the form opened, which can differ from the stored one (step N3, parked).
- Update Minutes (step A2b): Cancel is shown only once the grid is open (it was beside Update Minutes before); it reloads the page as before.
- Update Minutes, Followup, Minutes Finalisation and Report/Followup call `MinutesFinalizeValidation()`, which no script defines (baseline): the browser logs a script error and the post goes on.
- Agenda Entry: HTML_Report.ReplaceRichTextFont changes typed text such as "color:" or "font-size:" in Proposed Resolution (baseline).
- Agenda uploads: between SafeFileName.MakeUnique and SaveAs two uploads of the same name at the same moment can overwrite each other (SaveAs overwrites).
- Reports, Agenda Approval (step AP1 left it): CreatePDF rethrows with `throw ex`, which loses the original stack, and `pdfDocument.Close()` in `finally` can raise its own error and hide the first one.
- WordUtilities.ReadWordDocument is no longer called (step AP1); it does not close the file if reading fails (no `using`).
- Reports, Agenda Approval: no rule on the meeting date or on finalisation; the PDF can be made for any meeting.
- Reports, Agenda Approval: the meeting venue, date and time boxes shown with Create PDF can be edited but are not used in the PDF.
- Reports, Agenda Approval: SetMargins is called after the document is opened, so the first page has other margins than the rest.
- PDFUtilities.AddHTMLText drops without a sign any HTML element iTextSharp cannot place.
- Reports, Agenda Approval: the Agenda No is printed as the third part of AgendaNo split on - (step N3, parked); an Agenda No with fewer parts makes the whole PDF fail.
- Reports, Agenda Approval: the Tamil/Hindi message says "choose View on this page", but View shows only the list, without the agenda text.
- Reports, Agenda Approval: the Company Secretary signature lines are commented out.
- Reports, Agenda Approval: ViewState["dtAgenda"] carries all the rich text of the meeting, so the page is heavy.
- PDFUtilities.AddAgendaText leaves the page size of the last page of the uploaded file for the pages that follow (Agenda Approval and Agenda Details reports).
- Orphan Meeting alerts: meetings deleted before step D1 left their alerts behind (5 on BMMS_Test and 1 on BMMS at step 0). Step D1 lists and counts them and does not remove them; the Consultant decides after seeing them. New deletes since step D1 leave none.
- Meeting delete (step D1): the meeting's Agenda alerts are not looked at (a meeting with agenda items cannot be deleted). Alerts of agenda items deleted earlier (spr_DeleteAgendaByAgendaId) refer to an AgendaId that no longer exists and are a separate question.
- M6: Dashboard Approve and Reject are closed after the meeting date since step M6a (the procedures themselves, spr_UpdateAgendaByAgendaId and spr_GenerateSubjectNoByMeetingId, still have no date rule). Still allowed after the meeting date, as decided: Agenda Finalisation (rejects every item not yet approved and finalizes; refused only when already finalized) and Minutes Update (spr_UpdateMinutes and spr_UpdateAgendaShortText write Agenda.ShortText; refused once the minutes are confirmed and by the step 23 order). The Agenda Finalisation alert (M6b) is not built yet.
- Dashboard alert panel of an item of a past meeting opens as a normal panel (buttons visible, boxes editable); only pressing Approve or Reject is refused (to be taken up later; the branch in BindAgendaDetails that should make it read-only does not take effect on this path).
- Cause of the item above (found in step C1): the M6a check in BindAgendaDetails is `if (btnApprove.Visible && ...)`, and btnApprove.Visible reads false during the bind because its parent pnlAgenda is still hidden (lnkSource_Click shows it after BindAgendaDetails returns), so the branch never runs. To be fixed in a separate step M6c by showing pnlAgenda before the bind (and hiding it again when the item is not found); C1 test 6 then changes.
- Agenda Entry Update (step C1): the other role's comment is read at save time, just before the save procedure takes its lock; a Dashboard Approve or Reject by that role in the same moment (milliseconds) can be overwritten by the older value. Closing it fully needs the save procedures to keep the column themselves (a database step).
- Agenda Entry Edit of an item deleted meanwhile (baseline): the Edit branch reads the first row of an empty table and the safe error page shows (only through a list older than the delete).
- Agenda Finalisation Reject (step C1 left it): every item not yet approved gets Controller Comments "Agenda rejected by Controller on agenda finalized.", which replaces a comment the Controller wrote earlier; Manager Comments is not touched.
- Report/Followup and Report/FollowupActionTaken have Send Mail code (btnSendMail_Click) that no button reaches: Followup.aspx has no Send Mail button and the one in FollowupActionTaken.aspx is commented out. If a button is restored: the Followup report attaches `~/Files/PDF/Followup.pdf`, which that page never writes (another meeting's file written by Followup Action Taken, or none), both pages always say "Mail was sent to all members." whatever the mail result, and the file name is shared by every user (steps M2 and M3 left them unchanged).
- The Followup and Followup Action Taken mail handlers (btnSendMail_Click) are dead code, because no Send Mail button is rendered on either page (commented out in FollowupActionTaken.aspx:115-116, absent from Followup.aspx), so the mail inventory should not list those two as live (step ML2a).
- Sitting Fees can still crash on a missing GetTotAmtByMemberId row, a deleted member, an empty From/To date, and a damaged logo file.
- A damaged logo file makes the Notice, Agenda Approval and Sitting Fees PDFs throw (PDFUtilities.AddCompanyLogo).
- Notice page shows no confirmation (fixed in step 28).
