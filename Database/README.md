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
42. BMMS-Fix-DashboardMeetings-Step42.sql (Dashboard meeting list, step UN6b: five new read-only objects; nothing is replaced. fn_MeetingDashboardState (the status colour of every meeting on a given day), fn_UserDepartmentScope (a user's departments: open User_Department rows and the home department), fn_AgendaStatusGroup (approved ACA, rejected AMR and ACR, in progress AC and AMA, other), spr_GetDashboardMeetings (all six roles; @ActingUserId, @CommitteeId, @DepartmentId; OUTPUT @Result, @Reason (8 acting user missing or inactive, 4 role or filter not allowed; then no rows), @StatisticsShown, @ActingRoleCode; every scheduled meeting and the last 10 completed for every role) and spr_GetDashboardDepartments (Manager and User). Installed after step 41; install before the build of UN6b)
44. BMMS-Fix-AgendaWaitingFor-Step44.sql (Dashboard My approvals and Waiting for me, step UN6c2a: one rule for who may approve an agenda item. New: fn_AgendaWaitingFor, spr_GetAgendaApprovalState, spr_GetDashboardApprovals. Replaced: spr_UpdateAgendaByAgendaId (its routing test reads the function; nothing else changes) and spr_GetDashboardMeetings (the column WaitingForMe). Rollback: BMMS-Rollback-AgendaWaitingFor-Step44.sql, the two earlier texts letter for letter. Test: BMMS-Test-AgendaWaitingFor-Step44.sql, 120 numbered checks.)
46. BMMS-Fix-FollowupSave-Step46.sql (Followup page saves, step UN6d: two new procedures with @ActingUserId and OUTPUT @Result / @Reason (12 the system account, 8 acting user missing, 0 or inactive, 4 another role than Controller or an item that does not exist; then nothing saved): spr_SaveFollowupActionText (the Action Text, as spr_UpdateActionItem 'ActionText') and spr_SaveFollowupConfirmed (every row of the page in one call and one transaction, as spr_UpdateActionItem 'All'). Replaces nothing; spr_UpdateActionItem (step 31) is left as it is and without a caller. Installed after step 45; install before the build of UN6d. Rollback: BMMS-Rollback-FollowupSave-Step46.sql drops the two. Test: BMMS-Test-FollowupSave-Step46.sql, 56 numbered checks.)
47. BMMS-Fix-FollowupFinal-Step47.sql (Followup final, step FU1: a confirmed followup is final; Reopen with a reason. New table Action_Item_Status_History (one row per Confirm and per Reopen; FK to Action_Item ON DELETE CASCADE, FK to Users). New: spr_ReopenFollowup (@ActingUserId, @ActionItemId, @ReopenReason NVARCHAR(500); Reason 27 not confirmed) and spr_GetFollowupList (the page's list with the latest history row). Replaced: spr_SaveFollowupConfirmed (only the rows changed to Confirmed, `<i id=".."/>`; a row already confirmed is skipped; OUTPUT @Skipped) and spr_SaveFollowupActionText (Reason 26 on a confirmed item), both of step 46; spr_DeleteUserByUserId (step 39: history rows count as 'minutes', Reason 6). Installed after step 46; install it and deploy the build of FU1 together. Rollback: BMMS-Rollback-FollowupFinal-Step47.sql, the step 46 and 39 texts letter for letter; the table is kept. Test: BMMS-Test-FollowupFinal-Step47.sql, 95 numbered checks.)
48. BMMS-Fix-DashboardFollowupFinal-Step48.sql (Dashboard followup final, step FU2a: a confirmed followup is final on the Dashboard too. New: fn_DashboardActionItemScope (the scope rule of the Action Items card without the filter on confirmed items, with seven status columns from the latest Action_Item_Status_History row: IsReopened, StatusAction, StatusReason, StatusOn, StatusByName, StatusByLogin, StatusByActive). Replaced, each keeping the markers of steps 43 and 45: fn_DashboardActionItems (the same rows, 35 columns), spr_GetDashboardActionItems (the seven columns), spr_OpenDashboardActionItem (a confirmed item of the person's scope is returned and marked read; a read row it creates for a confirmed item gets StatusId 0) and spr_SaveDashboardActionText (Reason 26 for a confirmed item, after the role checks, under an update lock). Installed after steps 43, 45 and 47; install it and deploy the build of FU2a together. Rollback: BMMS-Rollback-DashboardFollowupFinal-Step48.sql, the step 43 and 45 texts letter for letter; run it before the Rollbacks of steps 45 and 43, which refuse while step 48 is installed. Test: BMMS-Test-DashboardFollowupFinal-Step48.sql, 43 numbered checks.)
49. BMMS-Fix-FollowupReports-Step49.sql (Followup reports, step FU2b: the reports show who confirmed or reopened each followup. New: fn_FollowupStatusLatest (the latest Action_Item_Status_History row of an item and the user who acted), spr_GetFollowupReport (Followup and Followup Summary, @ActingUserId; the Controller and Management; Reason 8 missing, inactive or the system account, 4 another role; the rows, filters and order of the query ReportsMgr.GetFollowupReport built before and of spr_GetFollowupReportForManagement, with AgendaNo, ActionItemId for equal rows, MinutesStatus and MinutesStatusMark for Management, and the six status columns) and spr_GetFollowupByDepartmentReport (Followup by Department, the Controller only; the committee and the subject range as whole numbers in the procedure; ORDER BY SubjectNo, AgendaNo, ActionItemId). Replaced, keeping FollowupFinal-Step47: spr_GetFollowupList (AgendaNo before ActionItemId) and spr_ReopenFollowup (one list of blank characters, the same as the page). spr_GetFollowupReportForManagement and spr_GetActionItemByMeetingIdDeptId are left without a caller (drop list). Installed after steps 41, 47 and 48; install it and deploy the build of FU2b together. Rollback: BMMS-Rollback-FollowupReports-Step49.sql, the step 47 texts letter for letter, after checking that the two procedures are still the step 49 texts; run it before the Rollback of step 47, which refuses while step 49 is installed. Test: BMMS-Test-FollowupReports-Step49.sql, 33 numbered checks.)
50. BMMS-Fix-Indexes-Step50.sql (Indexes for the Dashboard lists, step UN6e: three nonclustered indexes, kept because each at least halves the reads of its table in a path the Dashboard calls, measured on a copy of BMMS_Test filled to about one year of use: IX_Alert_User_Map_UserId_StatusId on Alert_User_Map (UserId, StatusId) INCLUDE (ReadStatus, AlertId); IX_Alert_Master_SourceType_SourceTypeId on Alert_Master (SourceType, SourceTypeId); IX_Agenda_MeetingId on Agenda (MeetingId) INCLUDE (DepartmentId, AgendaStatusCode). No primary key, table, procedure or function changes; no procedure text, so a re-run of an earlier step does not remove them. Re-runnable; stops, changing nothing, when an index of the same name has another definition or another index has the same first key column. Installed after step 49; the build of UN6e does not need it (deploy in either order). Rollback: BMMS-Rollback-Indexes-Step50.sql drops these three only, after checking their definitions. Test: BMMS-Test-Indexes-Step50.sql, 9 numbered checks.)
51. BMMS-Fix-SessionCheck-Step51.sql (Session check, step RA1d: one new read-only procedure, spr_GetUserAccessState (@UserId INT), read on every signed-in page request: no row when the user is not in View_Users; otherwise UserId, RoleCode, RoleName, AccountStatus, IsSystem and DepartmentSet (Users.DepartmentId, "|", the open User_Department rows of step 39 by DepartmentId, the home row marked "h", for example "4|4h,5"). No table, view or data change; nothing granted. Needs steps 18, 39 and 40; installed after step 50. INSTALL IT BEFORE THE BUILD OF RA1d: without it every signed-in request fails closed (the safe error page) and nobody can work. Rollback: BMMS-Rollback-SessionCheck-Step51.sql drops the procedure (roll back the build first). Test: BMMS-Test-SessionCheck-Step51.sql, 18 numbered checks.)
52. BMMS-Fix-ManagerRelease-Step52.sql (Manager release rule and the meeting-date rule, step MR1: replaces fn_ManagerReleaseRefusal, spr_AddEditUser and spr_SetUserStatusByUserId (step 39) and spr_UpdateAgendaByAgendaId (step 44), each keeping the markers of its earlier steps. Rule 12 reads the items routed to a Manager from fn_AgendaWaitingFor and counts them apart by the meeting date (still open / meeting date passed, agenda never finalised); the Reason 24 ReasonDetail is 'open:<n>|past:<n>|<department part>'; Deactivate of an active Manager follows rule 12 as a role change does; a Manager's approve or reject after the meeting date is refused (Reason 28), the Controller's reject stays possible. No table change; nothing granted. Needs steps 39, 44 and 51; installed after step 51. The Fix scripts of steps 39 and 44 stop while step 52 is installed. Rollback: BMMS-Rollback-ManagerRelease-Step52.sql, the four texts of steps 39 and 44 letter for letter (SHA-1 compared). Test: BMMS-Test-ManagerRelease-Step52.sql, 28 numbered checks.)
53. BMMS-Fix-DepartmentApprovers-Step53.sql (any Manager of the item's department approves, step UD1b: new fn_DepartmentManagers (the active Managers of a department; a user without history rows counts by Users.DepartmentId) and spr_SetManagerAlertRows (internal: refused unless called by another procedure); replaces 18 texts of steps 18, 20, 24, 37, 43, 44 and 52, each keeping the markers of its earlier steps; adds Alert_User_Map.HandledReason / HandledBy / HandledOn and Agenda.RouteNote with their checks and a key to Users. Who may decide an item at AC is every active Manager of its department but its creator; the route of a new item reads the department and the setting DeptNoManagerAction (Reason 29); the other Managers' rows are marked handled ('H') when one decides, and a Manager who leaves a department has his rows marked 'N'; no new Admin rows; a back-fill gives the Managers their rows of the items waiting at AC on a meeting to come. Needs steps 39, 44 and 52; installed after step 52. The Fix scripts of steps 20, 24, 36, 37, 43 and 52 and the Rollback scripts of steps 36, 37, 39, 43, 44 and 52 stop while step 53 is installed. Rollback: BMMS-Rollback-DepartmentApprovers-Step53.sql, the 18 texts letter for letter (SHA-1 compared); the columns and the rows stay. Test: BMMS-Test-DepartmentApprovers-Step53.sql, 66 numbered checks.)

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
Step 46 replaces no object of an earlier step, and no numbered script contains spr_SaveFollowupActionText or spr_SaveFollowupConfirmed, so no re-run of an earlier step needs step 46 again (a re-run of step 31 puts back the step 31 text of spr_UpdateActionItem, which step 46 never changed). Re-running step 46 is safe (it changes no data). Since step 47: a re-run of step 46 removes step 47 (see the next line).
If step 46, or step 2, 6, 10, 13 or 39, is ever re-run, run step 47 again afterwards, as the last step (after the chains above). Checked by searching every numbered script for the objects step 47 replaces: spr_SaveFollowupActionText and spr_SaveFollowupConfirmed are in step 46 only; spr_DeleteUserByUserId is in steps 2, 6, 10, 13 and 39. spr_ReopenFollowup, spr_GetFollowupList and the table are new. BMMS-Check-InstalledSteps.sql shows step 47 Partly: 4 of 6 after a re-run of step 46 (the Submit then writes by the step 46 rule, a confirmed item's action text can be edited again, and the FU1 build's Submit is refused), 5 of 6 after a re-run of one of the others (a user with history rows is then refused by the foreign key, an error, instead of the Reason 6 message). Step 47 keeps the markers of steps 46 and 39 (and the older ones of spr_DeleteUserByUserId), so those steps still read Installed after it. Re-running step 47 is safe: it keeps the table and its rows.
If step 43 or 45 is ever re-run, run step 48 again afterwards, as the last step (after the chains above). Checked by searching every numbered script for the objects step 48 replaces: fn_DashboardActionItems, spr_OpenDashboardActionItem and spr_SaveDashboardActionText are in step 43 only; spr_GetDashboardActionItems is in steps 43 and 45. fn_DashboardActionItemScope is new. A re-run of step 43 or 45 brings back their texts (28 columns; a confirmed item refused with Reason 4) and BMMS-Check-InstalledSteps.sql reads step 48 Partly; the FU2a build keeps working without the seven columns (no "Reopened", no status line). A re-run of step 43 also needs step 45 again first (see above), then step 48. Re-running step 48 is safe (it changes no data).
If step 47 is ever re-run, run step 49 again afterwards, as the last step (after the chains above). Checked by searching every numbered script for the objects step 49 replaces: spr_GetFollowupList and spr_ReopenFollowup are in step 47 only; fn_FollowupStatusLatest, spr_GetFollowupReport and spr_GetFollowupByDepartmentReport are new. A re-run of step 47 brings back its two texts (the order without AgendaNo; the shorter list of blank characters) and BMMS-Check-InstalledSteps.sql reads step 49 Partly, 3 of 5; the Followup reports keep working. A re-run of step 46 needs step 47 again first (see above), then step 49. Re-running step 49 is safe (it changes no data).
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
54. BMMS-Fix-ManagerScope-Step54.sql (lists for Managers with several departments, step UD1c: new fn_ManagerDepartments (the departments of which a user is an active Manager, read from fn_DepartmentManagers of step 53), fn_ReportingPersonAllowed (the active Controllers and the active Managers of a department, never the user himself), spr_GetManagerDepartments, spr_GetReportingPersonList, spr_GetAgendaReport, spr_GetMinutesReportByUser and spr_GetReportSubjectNos (read procedures with the acting user, Reason 8 / 4); replaces spr_GetAgendaByMeetingIdDeptId (step 33; R1 and an optional @DepartmentId), spr_AddEditAgendaByManager (step 53; Reason 30, the new item's alert to the other Managers of its department) and spr_AddEditUser (step 53; Reason 31). No table or data change. Needs steps 33, 39, 52 and 53. The Fix and Rollback scripts of steps 33 and 53 stop while step 54 is installed. Test script BMMS-Test-ManagerScope-Step54.sql; rollback BMMS-Rollback-ManagerScope-Step54.sql)
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

## Step WF3a2: access-matrix pack, tester stage in the workflow, the four security Lows of WF3a1 (no product change, no numbered database step)

Owner decision (2026-11-11, plan approved with four changes): the access matrix is drafted from the owner's access rules, not generated from PageAccess.xml; the differences between the draft and the XML are findings for the owner; the expected files are approved by the owner and never changed to make a run pass. The rules, their short names and the cells left to the owner: Tests/packs/access-matrix/README.md.

What is in the repository:

- Tests/packs/access-matrix/: expected.csv (60 addresses x 8 columns: qa_admin, qa_ctrl, qa_manager, qa_user, qa_mgmt, qa_mdsec, qa_inactive and a visitor; a rule per row), not-in-menu.csv (approved pages without a menu link, a reason per row), home-link.csv, planted.json, pack.js, README.md. The pack checks: the files are complete; every .aspx page on disk is in expected.csv or PageAccess.xml (a page in neither fails); the decided cells agree with PageAccess.xml (on the RA1b rows only a cell that opens where the XML refuses counts); each role opens each address (Logout last), what came back and the page access log (one DENIED line for that user and page for a refusal, none otherwise); each role's menu (the menu bar, the drop-down lists its items open, the header): every link opens for the role, every page the role opens has a link or an approved row, the Home link per home-link.csv. qa_inactive: its sign-in is refused with "Your account is inactive", then its column is the visitor's.
- Standing proof (every run with the pack): Run-Tests.ps1 adds user to Report/MeetingCalendar.aspx in Tests/_site/XML/PageAccess.xml only, runs the two rows of planted.json for every column, and copies the working tree's file back in a finally block; the planted cell must be caught and every other cell must come out as in the real matrix run that follows; at the end the SHA-256 of the site copy's PageAccess.xml must equal the working tree's. Otherwise VOID. -ProofFullMatrix (owner only) does the same over every row.
- Tests/lib/run.js: phases (main, planted, planted-full) with their own checks file; endSession after Logout; "Page not found" also for IIS's own 404 page of a missing static file.
- Tests/_runner/Run-Tests.ps1: the proof phase, the grid "Access matrix", "Cells for the owner to decide" and "Standing proof" in results.md (the cells are left out of "All checks"); a cell "owner to decide" counts as failed; the logins checked again after the restore; -LeaveSiteRunning refused on a firewall opening.
- Security Lows of WF3a1, closed: (1) Assert-QaLoginReach allow-list: in effect only CONNECT SQL and VIEW ANY DATABASE (fn_my_permissions), granted to the login only CONNECT SQL (sys.server_permissions), before every run, for bmms_tester and bmms_site; (2) the check again after the restore (Run-Tests.ps1) and after the Fix scripts, before the backup (Update-Baseline.ps1); (3) the permissions of Tests/_site/connectionStrings.config read back after icacls (protected, every entry the owner's account) before the password is written, the file removed otherwise; (4) the site copy runs from the runner's own IIS Express configuration (Tests/_build/iisexpress/applicationhost.config, made from IIS Express's template at every start): one site, Tests/_site on localhost:18573, the IP restriction module letting in 127.0.0.1 and ::1 only (IIS Express listens through http.sys on every address and, before this, served a caller sending "Host: localhost" through any of them: security review, 2026-11-11); Start-QaSite asks the site copy through every network address of the machine, with that address and with "Host: localhost" as host name, and stops unless both are refused (no connection, HTTP 400 or HTTP 403); every run reads the firewall through its COM interface (no administrator rights): an enabled inbound allow rule (TCP or any) for iisexpress.exe, System or any program (not an app container's own rule) that covers port 18573 (a number, a range or every port), or a profile that is off, is a warning in the console and in results.md ("Firewall"); -LeaveSiteRunning is refused only when a profile allows inbound traffic by default (owner decision 2026-11-11: the IP restriction is probed on every address with both host names on every run; no Windows rule is changed). On this laptop: one warning, the rule "WFD Driver-only (TCP-In)" (System, every port). The port check of Start-QaSite ignores a listening entry of process 0 (a socket of an ended process, seen after the address probes; it does not keep IIS Express from starting).
- CLAUDE.md: plans list browser checks as "tester" and "owner by eye"; new step 5 Tester (after the fixes, before the owner's tests; Update-Baseline.ps1 first for a new database script; failures to the owner as they are); the report has 6 parts, the tester record verbatim as part 6. .claude/agents/tester.md: the record has the matrix line, the proof and the cells to decide.

Checked in the code before the first matrix run (owner's condition): a plain GET does nothing by itself on Reset Database (Page_Init refuses anyone but Admin; Page_Load shows the database name and counts files; the reset runs only in btnResetDatabase_Click, which checks the role again and the typed name), Backup Database (RequireRole("admin"); Page_Load lists the backup audit rows; the backup runs only in btnBackupDatabase_Click, with RequireRole again) and Send Mail (Page_Load loads the committee list; mail, attachments and the temp-folder sweep run only in the button handlers). BMMS_Quality is restored at the start of every run anyway.

Found by the first runs (2026-11-11), for the owner; nothing changed in the product:

- Report/EventCalendar.aspx (High, baseline): a plain GET loops for ever and ends in System.OutOfMemoryException (BindEventCalendar: `for (DateTime date = startDate; date < endDate; date.AddDays(1))` throws away the new date). PageAccess.xml lets every signed-in role open it, so any user can make the site use up its memory; the user sees the error page. Owner decision: the page goes in RA1c1; until then every cell is "to be removed (RA1c1)" and the run does not open it.
- Report/ViewReport.aspx opened directly by the Controller or the Manager (no report kind): HTTP 500 (NullReferenceException, Session["ViewReport"] empty; an error-log entry). Owner decision: expected "opens" with "The report is no longer available" (as ?pdf=1 already shows), Management "Access denied"; the HTTP 500 stays a real failure of the pack, a product defect fixed in RA1c1.
- Report/FollowupActionTaken.aspx opens for the Controller and the Manager: owner decision "to be decided (RA1c2)", a note. ReportPrint.aspx: "to be removed (RA1c1)".
- A missing .aspx gives "Page not found" (HTTP 404) to every role, not "Access denied" (the plan's guess): the request ends before PageAccessModule's check. The owner keeps the two Q5 rows as observed. D0 (Tests/packs/access-matrix/README.md) is confirmed by the owner.
- Home link: the first rule text said Management has none; the owner corrected it (2026-11-11): Management has the Home link, only Admin and MD Secretariat have none. The product was right; no finding.
- The drop-down list of the Master menu (Member Master to Attendance) is in the page of every role; only Admin and the Controller have the menu bar item that opens it (reported by the pack as a note).
- Error/TestPage.aspx is the one page on disk that PageAccess.xml does not list (reported as a note; it is in expected.csv as refused to everyone).
- Agreement with PageAccess.xml: every decided cell agrees (the one difference, EventCalendar / mgmt, is gone with the owner's RA1c1 decision).

Test result of the build: see the build report (runs of 2026-11-11 in Tests/_results).

## Step RA1c1: Event Calendar and Report Print removed; ViewReport without a report shows a message (code only, no numbered database step)

Owner decision (2026-11-11, plan approved after WF3a2): remove the two unused pages; ViewReport.aspx with no stored report shows the same message as ?pdf=1; after RA1c1 the access matrix is expected to pass.

- Removed: BMMS/Report/EventCalendar.aspx, .aspx.cs, .aspx.designer.cs (a GET ran out of memory: BindEventCalendar looped for ever; every signed-in role could open it) and BMMS/Report/ReportPrint.aspx, .aspx.cs, .aspx.designer.cs (no page opened it); their six entries in BMMS/BMMS.csproj (four Compile, two Content); their two entries in BMMS/XML/PageAccess.xml, which now has 44 page entries (3 public). A request for either address now gets "Page not found" (HTTP 404).
- BMMS/Report/ViewReport.aspx.cs: the RA1b Management check stays first. Then, after ?pdf=1, when Session["ViewReport"] is missing or empty the page answers "The report is no longer available. Close this window and click Generate again." (HTTP 200) and ends the request (Response.End, so no event handler runs; no error-log entry). The text is one constant, NoReportHtml, used by ?pdf=1 too. The Export to Pdf and Export to Word handlers check the same before they read the report (a second check; Page_Load answers first on their postbacks). A stored report is shown as before.
- BMMS/PageAccessModule.cs: comment only (ReportPrint no longer named).
- Tests/packs/access-matrix: the EventCalendar and ReportPrint rows removed from expected.csv (56 addresses; not-in-menu.csv had none); README.md updated. .claude/agents/tester.md: the runner is called with the Bash tool's timeout at 10 minutes and not in the background (a matrix run takes about 4 minutes); the guard hook is unchanged.
- No other file names the two pages (searched BMMS, BMMSBAL, BMMSDAL: .cs, .aspx, .ascx, .Master, .xml, .config, .js, .csproj).

Browser checks: tester: access-matrix (expected PASSED, no error-log line). Owner by eye: a Minutes report generated and Print, Export to Pdf and Export to Word; Report/ViewReport.aspx opened directly as the Controller (the message) and as Management ("Access denied"); Report/EventCalendar.aspx and Report/ReportPrint.aspx give "Page not found".

## Step RA1c2: Followup by Department in the Controller's Reports menu; Error/TestPage.aspx removed (code only, no numbered database step)

Owner decisions (2026-11-11, plan approved): Report/FollowupActionTaken.aspx is restored to a menu as "Followup by Department", after Followup Summary in the Controller's Reports menu (now 17 items; 16 before), for the Controller only (option A: the Manager gets "Access denied"; Management and MD Secretariat do not get it); the functionality is looked at later. The page shows the subjects that have a follow-up item (meeting, subject number, department, agenda short text), not the action text.

- BMMS/Report/FollowupActionTaken.aspx.cs: PageAccessModule.RequireRole("controller") first in Page_Load and again first in Generate Report (role read from the database, as RA1a and RA1b). Generate clears Session["ViewReportKind"] before it stores the report (RA1b review). The committee filter: spr_GetActionItemByMeetingIdDeptId selects by meeting number and department only and does not use its @CommitteeId, and meeting numbers start again in every committee, so the page keeps only the rows of the chosen committee (a DataView filter on CommitteeId; no database step). One helper gives the rows of the chosen committee, meetings and department; the grid, the report (it used the unfiltered rows before) and the Subject No lists all use it, so the Subject No lists offer exactly the subjects the grid and the report show (before, they came from spr_GetActionItemByMeetingId, which got the department id as its @IsConfirmed). The check before View and Print counts the committee's items in all departments (before: one meeting counted only unconfirmed items, a range counted every committee's) and asks for a meeting when none is chosen. The Manager's fixed home department is gone with the Manager's access. Removed as dead code (the button was commented out): btnSendMail_Click, CreateBodyText, CreatePDF (it wrote Files/PDF/Followup.pdf) and the empty download panel pnlFollowupDownload (.aspx and designer). The page title and heading read "Followup by Department" (Title attribute, heading, a new PageSettings.xml entry for the browser title); the PDF file name of Export to Pdf is FollowupByDepartment.
- BMMS/UserControl/MenuUserControl.ascx: the item in the Controller's Reports menu. BMMS/XML/PageAccess.xml: Report/FollowupActionTaken.aspx roles="controller" (was controller,manager with a wrong CONFIRM comment: no Dashboard link to it existed); the TestPage comment line removed (43 page entries).
- Removed: BMMS/Error/TestPage.aspx, .aspx.cs, .aspx.designer.cs and their three csproj entries (a GET wrote Files/PDF/Test.pdf; it was not listed, so nobody could open it).
- Tests/packs/access-matrix: expected.csv FollowupActionTaken Controller "opens", Manager "Access denied"; the TestPage row removed (55 addresses); the cell words "to be removed (RA1c1)" and "to be decided (RA1c2)" retired (README and pack.js).

Browser checks: tester: access-matrix (expected PASSED, 0 notes). Owner by eye: as the Controller, Reports, Followup by Department: View (only the chosen committee's meetings), department All and one, Print, Generate Report, then Print, Export to Pdf and Export to Word in the window; a meeting range; for two committees with the same meeting number (for example NRC 1 and BM 1 on BMMS_Test) the report of one shows only its own subjects; as the Manager the address gives "Access denied"; Error/TestPage.aspx gives "Page not found"; no new error-log entry.

## Step UN6b: Dashboard in cards; meeting list with status colours and statistics by role (database script step 42 and code; test script for BMMS_Test)

Owner decisions UN6b (2026-11-12: the plan, addenda 1 and 2, the answers to the questions; the plan's recommendations hold where nothing else was said). The Alert and Action Item lists keep their behaviour and only move into cards. UN6c (summary cards, My approvals, alert rules, header count), UN6d (Submit on read-only action items) and UN6e (indexes) are later steps.

Rules:

- The Dashboard's "Scheduled Meetings" list is replaced by the Meetings card: every scheduled meeting (no cap), then the last 10 completed meetings (newest first) for EVERY role. A meeting dated today is scheduled until the end of that day ("today" is the database server's date; before, `MeetingDate >= GETDATE()` counted it as completed).
- Status, the first rule that fits, always a chip with its label (the colour is never the only sign): grey "Minutes finalised" / "Minutes confirmed" (Meeting.MinutesStatus F / C); red "Minutes pending" (the meeting date is before today and the minutes are not F or C, also when the agenda was never finalised); green "Agenda finalised" (Meeting.AgendaStatus not Open; NULL counts as Open); orange "Submission closed" (the agenda submission date is before today; the submission date itself is still open, as MeetingMgr.IsAfterAgendaSubmissionDate); blue "Open for submission" (anything else, also a meeting without dates).
- Statistics per meeting: Items (every agenda item), Approved (ACA), Rejected (AMR, ACR), and the last column, AC + AMA for every role: "In progress" for the User, "Pending" for the others. AF or any other code counts in Items only (none exists on BMMS_Test).
- Scope, decided by the procedures from the acting user id (role and departments read from the database; nothing from ViewState, the query string or the session role):
  - Controller and Management: every meeting, statistics over all items. MD Secretariat and Admin: every meeting with its colour, no statistics (the counts are not computed: NULL, @StatisticsShown 0).
  - Manager and User: every scheduled meeting; a completed meeting only when it has an item of their department(s); statistics over the items of their department(s) only. A Manager's departments are his open User_Department rows and his home department (a Manager can have several; no rule assumes one Manager per department).
- Filters: Committee ("All committees" first, then the list of CommitteeMgr.GetCommitteeList(1)) for the Controller, the Manager, Management, MD Secretariat and Admin; Department ("All my departments", then only his departments) for a Manager with two or more departments. The procedure checks both values: a committee that does not exist, a department that is not one of a Manager's or a User's, or any department for another role gives Reason 4 and no rows. The committee filter only narrows what the user may see, so the procedure accepts any existing committee for every role (giving the User a Committee drop-down later changes the page only).
- Titles: Controller, Management, MD Secretariat, Admin: "Meetings", no subtitle (the last three provisionally, until their mock-up screens are decided). Manager with two or more departments: subtitle "Departments: HRD, IT", title "Meetings, items of my departments", or "Meetings, [department] items" when one is chosen. Manager with one department and User: subtitle "Department: [name]", title "Meetings, [department] items". The role table is one place in UserControl/MeetingSummary.ascx.cs (RoleViews).
- Dates in the application's format dd-MMM-yyyy (as DashBoard.aspx.cs FormatDate); the meeting time under the date as "10:00 Hrs.".
- Messages in the Meetings card: Reason 8 "The meeting list is not available: your account is not active. Sign in again."; Reason 4 "The meeting list is not shown for this choice." followed by the filters that are shown ("Choose All committees or All my departments.", "Choose All committees.", "Choose All my departments.") or, with no filter shown, "The meeting list is not shown for your role."; a database error goes to the error log and the card says "The meeting list could not be loaded. Reload the page to try again." (the alerts still load); a timeout or a lack of memory (SqlException -2, 8645 or 701; no free connection in the pool in time; OutOfMemoryException on the web server) says "The server is busy and the meeting list could not be loaded. Wait a moment, then reload the page." After any failure no filter, no subtitle and the plain title "Meetings" are shown (the filters are hidden in the markup until a load succeeds). Empty lists: "No scheduled meetings.", "No completed meetings."
- After a successful Approve or Reject on the Dashboard the Meetings card is read again, so the counts follow.

Database, step 42 (BMMS-Fix-DashboardMeetings-Step42.sql, marker DashboardMeetings-Step42, 5 markers in BMMS-Check-InstalledSteps.sql): fn_MeetingDashboardState(@Today), fn_UserDepartmentScope(@UserId, @Today), fn_AgendaStatusGroup() (the one definition of the groups, for the later summary cards too), spr_GetDashboardMeetings and spr_GetDashboardDepartments; read only, nothing replaced. spr_GetScheduleMeet is unchanged; after this build nothing calls it (Known items). BMMS-Rollback-DashboardMeetings-Step42.sql drops the five objects. BMMS-Test-DashboardMeetings-Step42.sql checks the colour rules on fixed dates, the department scope, the four groups adding up, every role's rows, the cap of 10 completed meetings for every role, the statistics per role and department, the refused filters, Reasons 8 and 4 and the department list, inside a transaction that is rolled back.

Code:

- BMMS/UserControl/MeetingSummary.ascx, .ascx.cs, .designer.cs (rewritten): the heading "Dashboard" with the filters on its right and the subtitle, an empty container for the summary cards of UN6c, and the Meetings card (Scheduled, Completed (last 10); columns Meeting (committee name bold, "No 00003" under it), Meeting date, Submit agenda by, Status, Items, Approved, Rejected, last column). The control renders no wrapper: its blocks are cells of the Dashboard grid.
- BMMS/DashBoard/DashBoard.aspx: the two-column table with the 260 px left column is gone; .wb-page with the grid .wb-dash: Meetings about two thirds (7:3) beside Alerts, Action Items below; one column under 1100 px. The Alert and Action Item lists, their links and every control ID are unchanged. The Committee / Meeting Alert panel is at most 610 px wide (was 610 px); the Agenda Alert and Action Item Details panels have a 165 px label column and fields up to 550 px instead of fixed widths, labels above the fields at 720 px and below. DashBoard.aspx.cs: MeetingSummary1.Reload() after a successful Approve or Reject.
- BMMSDAL/MeetingDB.cs, BMMSBAL/MeetingMgr.cs (GetDashboardMeetings); BMMSDAL/DepartmentDB.cs, BMMSBAL/DepartmentMgr.cs (GetDashboardDepartments).
- BMMS/CSS/bmms-workbench.css: the Dashboard section (grid, heading and filters, chips with the palette's tints, number columns, the panel widths, the 1100 px and 720 px rules).
- Tester: the fixture gets committee QA2 (a meeting dated today without items, eleven completed meetings with Credit items, one of them with a Secretarial item only; Fixture, Fixture-Check and Fixture-Dates scripts; the summary line of Setup-Quality.ps1); the new pack Tests/packs/dashboard (expected.json, pack.js, README.md). All nine fixture accounts existed already (qa_user2 is an active HRD User). Saving QA2 writes its Committee alert, so every account but qa_ctrl has one alert more than before.

Follow-up after the owner's tests on BMMS_Test (2026-11-12, plan approved with option B for the Alerts card):

- Finding A (Manager and User Dashboards "could not be loaded") was memory starvation of the machine (RESOURCE_SEMAPHORE; SQL Server working set 82 MB, 711 MB available of 7.9 GB), not the query. Timing on BMMS_Test (17 meetings, 66 items; STATISTICS TIME, IO and the actual plans; warm runs): Controller 373 logical reads, Manager with one department 405, Manager with two 613, User 404; no physical reads; 0 to 31 ms CPU, 7 to 33 ms elapsed; every statement with a grant asked for 1024 KB (SQL Server's smallest grant), used 16 KB and waited 0 ms; the Manager and User branch has one such statement more (the department list). The query was not changed.
- Robustness: on any load failure the Meetings card shows no filter for any role (see the messages above).
- Finding B: the Alerts card has two columns, "Alert" (the Source link, with the alert type, committee and department in one muted line below it, separated by " | ") and "Created on" (dd-MMM-yyyy, HH:mm below it, neither wraps). Before, CreatedOn was shown as the raw date and time and broke over three lines. Read and unread rows, paging, the hidden values and every control ID that lnkSource_Click reads are unchanged; the unused hidden Read column is gone. DashBoard.aspx.cs: FormatDate is protected, FormatTimeOfDay and AlertDetails are new.
- Finding C (alert link): closed by the owner.
- Tester: the preflight reads the available memory (Task Manager's "Available") and warns below 1500 MB, never refuses; a VOID or RUNNER FAILED run reads it again and says in its summary when it was low; results.md has a "Memory at the start" line. The dashboard pack counts Alerts rows by the compact row and checks at 1366, 1024 and 800 px that the two Alerts headings are whole and every date takes at most two lines.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 41 Installed, step 42 Missing).
2. `BMMS_Test`: BMMS-Fix-DashboardMeetings-Step42.sql ("Step 42 installed: ...").
3. `BMMS_Test`: BMMS-Test-DashboardMeetings-Step42.sql (71 numbered checks, all must PASS; the owner's run of 2026-11-12: 71 passed, 0 failed, 0 skipped). Its first version stopped at test 7 (error 547, CK_User_Department_Closed): the Manager's closed department row had no ClosedOn, ClosedBy and CloseReason; fixed 2026-11-12 with CloseReason 'C' (changed).
4. BMMS-Check-InstalledSteps.sql again: step 42 Installed, 5 of 5.
5. Deploy the build (after step 42: the build calls the new procedures).
6. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build.
7. To undo: roll back the build, then BMMS-Rollback-DashboardMeetings-Step42.sql (step 42 Missing).

The tester's baseline: step 42 was installed in it with Update-Baseline.ps1, then BMMS_Quality was built afresh with the extended fixture (Setup-Quality.ps1, 2026-11-12).

Browser checks: tester: access-matrix and dashboard (expected PASSED). Owner by eye (Chrome and Edge at 100 percent, BMMS_Test): the look of the heading, filters, cards and chips, and whether the five colours are easy to tell apart; the 7:3 split at 1366 px with the compact Alerts rows (headings whole, dates on at most two lines); stacking at 1024 and 900 px; the Agenda Alert and Action Item Details panels at those widths (editors, read-only states, Approve, Reject, Submit); a Manager with two departments choosing one; a User; MD Secretariat and Admin without statistics; the counts after an Approve.

## Step UN6c1: Dashboard alert rules, "Remove from my list", overdue followups, header count; no functional alerts or mails for Admin (database script step 43 and code; test script for BMMS_Test)

Owner decisions UN6c (2026-11-09, 2026-11-10; plan and answers 2026-11-12 and 2026-11-13). UN6c is built in two steps: UN6c1 (this one, step 43) and UN6c2 (step 44: "Waiting for me" panel and column, summary cards), which starts after UN6c1 is committed. UN6d (Submit on read-only action items), UN6e (indexes) and UD1b stay later steps.

Rules:

- One listing rule on the server (fn_DashboardAlerts), from the acting user id alone; the role is read from the database, never from the page or the session role. It serves the Alerts card and the header count. A Controller does not see ACA and ACR and a Manager does not see AMA and AMR, as before.
- The Admin role gets no functional alerts. All eleven alert types of today are functional (CC, CU, MC, MU, AC, AMA, AMR, ACA, ACR, AF, MF), so an Admin's card reads "No alerts." and the header "Alerts (0)". The protected system account has the Admin role: it gets Reason 0 and an EMPTY list and count 0, like any Admin (its old read alerts were the "Alerts (0) with a full card" of the UN6b tests). The rows stay in the tables; nothing is deleted. The five procedures that write alerts are not changed and still add rows for Admins until UD1b (Known items).
- No functional mail for the Admin role: spr_GetAlertMailId leaves it out in every branch (AMR: the creator; AMA: the Controllers and the creator; ACA and ACR: the users of the item's alert), spr_GetAgendaUpdateMailId leaves it out too. Callers checked: spr_GetAlertMailId from DashBoard.aspx.cs (approve and reject mail) and AgendaFinalization.aspx.cs; spr_GetAgendaUpdateMailId from Agenda.aspx.cs (update mail); no procedure calls either. The Controller, the Manager and the creator get their mails as before.
- Alerts card: Recent | Unread | All. Recent is the default: every unread alert, and the read alerts whose event date is today or in the seven days before (database server date). All pages through everything that was not removed from the list; nothing is deleted. A page of 10 is read from the server (ROW_NUMBER; compatibility level 100); the alert list is no longer kept in ViewState.
- Event date and acting person of an alert (the card shows both: the muted line ends with "by [name]", the login ID as tooltip as in the header, and the date column, headed "Date", shows the event date):

  | Alert | Event date | Person |
  |---|---|---|
  | CC, CU, MC, MU (AF, MF if ever written; an agenda alert whose item is gone) | Alert_Master.CreatedOn | Alert_Master.CreatedBy |
  | AC | Agenda.UpdatedOn, else Agenda.CreatedOn | Agenda.UpdatedBy, else Agenda.CreatedBy |
  | AMA, AMR | Agenda.MgrApprovedDate | Agenda.MgrApprovedBy |
  | ACA, ACR | Agenda.ControllerApprovedDate | Agenda.ControllerApprovedBy |
  | AMA to ACR, edited after the decision | Agenda.UpdatedOn, when it is MORE THAN ONE MINUTE after the decision date | Agenda.UpdatedBy |
  | AMA to ACR without a recorded approver (before step 35) | Agenda.UpdatedOn, else Alert_Master.CreatedOn | a dash |

  The tolerance of one minute: a decision sets the decision date and UpdatedOn in one call with two clock reads, which can differ by milliseconds; without it an ordinary approval would name UpdatedBy. An agenda alert keeps one Alert_Master row for the item's life (its CreatedOn is the entry), so the date of an approval comes from the item.
- "Remove from my list" (the two Delete buttons renamed): spr_RemoveAlertForUser sets StatusId 0 on the row only when it is the acting user's own. The row id comes back from the page in a hidden field: another user's id or an unknown id gives Reason 4, nothing changes, and the page says "This alert is not in your list." Step 36 still shows a removed alert again, unread, on an edit.
- Opening an alert still marks it read with spr_UpdateAlertByUserId (not changed): it updates the row of that alert whose UserId is the session's user id, so it cannot mark another user's row; the alert id comes from the grid row (ViewState, not editable in the page).
- The link chosen stays chosen (found in the owner's test of UN6c1). Action Items card: with Unread chosen, opening an item reloaded the whole list while the mark stayed on Unread, and a second page of Read or Unread showed the whole list. The click handlers filtered a copy and set the mark themselves; lnkActionItem_Click and OnPagingAction did neither (so since the links exist; visible since the mark is bold). Now the mode (ActionMode: A, R, U) is kept in ViewState, LoadActionItemGRV sets the mark from it (MarkCurrent, class and aria-current) and BindActionItemGRV filters by it, for every load and every page. Alerts card: the mark was always set from the mode used to load (LoadAlertGRV), but opening an alert did not reload the list, so under Unread the opened alert stayed listed, as read, until the next action. lnkSource_Click now reloads the list in the mode chosen (in a finally block, so the header count follows also when the read mark could not be written). Effect on both cards: under Unread the item or alert just opened leaves the list while its panel is open; under Recent a read alert older than 7 days leaves the list when opened.
- Action Items card, scope (owner decision 2026-11-13, after the owner's test: item C05-00002-002 showed for the department's user and not for its Manager or the Controller). Before, the card listed the items MAPPED to the signed-in user (ActionItem_User_Map), and the mapping never followed the department: spr_UpdateMinutes maps the creator of the agenda item when a minute first becomes a Followup, spr_MinutesFinalizeByMeetingId maps every active user to the meeting's items; a minute that becomes a Followup after finalising is mapped to the creator alone. Old behaviour, not a regression. Now one rule on the server (fn_DashboardActionItems, from the acting user id; the role is read from the database): an item is an Action_Item with IsConfirmed 0, tied to a department by its agenda item; a Controller and Management get all of them whatever the minutes status; a Manager and a User those of their departments (fn_UserDepartmentScope of step 42, as of today) whose minutes are finalised (F) or confirmed (C); MD Secretariat and Admin have no card (Reason 4; the page hides the card on that answer, the Alerts card, the Meetings card and the header count are not touched). The list is ordered newest meeting first. The mapping rows hold each person's read state only: a person without a row sees the item unread (bold); opening it (spr_OpenDashboardActionItem, only an item in the person's scope) marks the person's own row read and creates it when missing, never a second row (check and insert in one statement under a held update lock; the table has no unique index); nothing of the item is touched, so Management opens read-only. The Submit of the details panel saves through spr_SaveDashboardActionText, which decides on the server whatever the page sends: only a Controller, a Manager or a User, only an item in the person's scope; Management, MD Secretariat, Admin and another department's item get "You cannot change this action item: your role can only read it, or it is not an item of your department. Nothing was saved." (an inactive account: "Your account is not active. Nothing was saved. Sign in again."; a failed save: "The action text could not be saved. Nothing was saved. Try again.", and the panel stays open with the text). The panel and its Submit button are not changed (hiding Submit for Management is step UN6d). A new column "Due date" (Minutes.DueDate, optional, step UN6a) with the word "Overdue" in a red chip when the due date's DATE is before the database server's date and the item is neither complied (Action_Item.IsComplied 0) nor confirmed (IsConfirmed 0); these are two flags, not status codes. No due date, no mark. The card's "Meeting Date" is shown as dd-MMM-yyyy as well (it was dd/MM/yyyy).
- Header "Alerts (n)": the unread alerts by the same rule (spr_GetAlertCount). In Main.Master the count sits in its own UpdatePanel (conditional, inline); the master's RefreshAlertCount reads it again and redraws it. The Dashboard calls it whenever it reloads the alert list on a postback (Approve, Reject, Remove from my list, the three links, paging) and after an alert was opened (marked read), so the header follows without a page reload and without script. Failure: logged; the header then shows "Alerts" without a number, on a full page load and on a refresh alike (before: a misleading 0; a number kept from before the action could be out of date); the action itself is not affected.
- Messages: Alerts card "The alerts could not be loaded. Reload the page to try again." / "The server is busy and the alerts could not be loaded. Wait a moment, then reload the page." (the busy rule of UN6b, now Common.IsServerBusy) / "The alerts are not available: your account is not active. Sign in again."; the grid and its pager are hidden then. The same three for the Action Items card ("The action items ..."). Remove: "This alert is not in your list." and, on an error, "The alert could not be removed from your list. Try again." Empty Alerts card: "No alerts."

Database, step 43 (BMMS-Fix-DashboardAlerts-Step43.sql, marker DashboardAlerts-Step43, 10 markers in BMMS-Check-InstalledSteps.sql). New: fn_DashboardAlerts(@UserId), spr_GetDashboardAlerts (@ActingUserId, @Mode R/U/A, @PageNo; OUTPUT @Result, @Reason, @TotalRows, @UnreadCount, @PageShown), spr_GetAlertCount, spr_RemoveAlertForUser, fn_DashboardActionItems(@UserId, @Today), spr_GetDashboardActionItems, spr_OpenDashboardActionItem (@ActingUserId, @ActionItemId), spr_SaveDashboardActionText (@ActingUserId, @ActionItemId, @ActionText). Replaced: spr_GetAlertMailId, spr_GetAgendaUpdateMailId; the Fix script was built from their definitions as installed (identical in BMMS_Test and BMMS_Quality) and stops when it finds another text. Reason 8: acting user missing or inactive; Reason 4: mode or page number not allowed, an alert row that is not the acting user's, a role without the Action Items card, an action item outside the acting user's scope, a Submit by Management; a refused call returns the same columns with no rows and changes nothing. The script grants nothing, as step 42: the application login holds EXECUTE on the schema dbo. BMMS-Rollback-DashboardAlerts-Step43.sql drops the eight new objects and puts the two mail procedures back letter for letter (it compares the SHA-1 of the restored texts with the texts the step was built from; checked on BMMS_Test: Fix, Rollback, Fix). BMMS-Test-DashboardAlerts-Step43.sql: 128 numbered checks (run it in a new query window): every alert type with an old and a young read alert and the edge of the seven days; the person and event date per type, with an ordinary approval (30 seconds between the two dates) and an edit after the decision; Recent, Unread, All, paging, the header count; the role filters; the Admin and the system account (empty list, count 0); the mail lists per branch; Remove (own row, another user's, unknown); spr_UpdateAlertByUserId marking one user's row only; the Action Items card on made-up rows per role (Controller, Management, a Manager with two departments, a Manager with one, a User, a User of a department without items, MD Secretariat, Admin and the system account refused with Reason 4, an inactive, a missing and an unknown acting user Reason 8; an item of a third department, an item with open minutes shown only to Controller and Management, a confirmed item gone, a stale mapping row that shows nothing), the read state per person and the four conditions of IsOverdue; opening (one row created, none at the second opening, two existing rows not a third, outside the scope Reason 4 and no row, Management's opening leaves the item unchanged); saving the action text (Controller, Manager and User inside their scope; Management, MD Secretariat, Admin, another department, open minutes for a User, a confirmed item refused; only the text is written); Reasons 8 and 4; that every database user who can run step 42's procedure can run the eight of step 43; and the Rollback's two texts installed inside the test's transaction and compared with the saved originals.

Code:

- BMMSDAL/AlertDB.cs, BMMSBAL/AlertMgr.cs (GetDashboardAlerts, GetAlertCount, RemoveAlertForUser); BMMSDAL/ActionItemDB.cs, BMMSBAL/ActionItemMgr.cs (GetDashboardActionItems, OpenDashboardActionItem, SaveDashboardActionText); BMMSBAL/Common.cs (IsServerBusy, moved from MeetingSummary.ascx.cs, which now calls it).
- BMMS/DashBoard/DashBoard.aspx, .aspx.cs, .aspx.designer.cs: the links Recent, Unread, All (lnkRecent, lnkUnread, lnkAll; lnkShowAll and lnkRead are gone); the Alerts grid with custom paging, the person on the muted line, the event date under the heading "Date" (was "Created on"), "No alerts."; the message paragraphs of the two cards; the buttons "Remove from my list"; the Action Items column "Due date" with "Overdue". Every control ID that lnkSource_Click and the panels read is unchanged.
- BMMS/MasterPage/Main.Master, .cs, .designer.cs: the count panel and RefreshAlertCount.
- BMMS/CSS/bmms-workbench.css: the cursor on a name with a tooltip, the space before "Overdue", and the link of the list that is shown in bold (Recent / Unread / All, and the three links of the Action Items card: since the card layout of UN6b the earlier rule td.showAll no longer reached them, so the current link was not marked; found by the UI review of UN6c1). The current Alerts link also carries aria-current.
- Tester: the fixture has three Followups (two on QA1 00005, one on 00006; before, one), three alerts read by qa_user and item QA1-00005-001 without a recorded approver; the dates script sets every alert date and the three due dates relative to the day of the run; for the scope of the Action Items card QA1-00006-001 keeps the mapping row of qa_user only and two Followups are added on QA2 (QA2-00003-1, Secretarial, minutes finalised, mapped to qa_ctrl only; QA2-00002-1, Credit, minutes in draft, mapped to qa_user only); Fixture-Check has 35 checks (was 32). The dashboard pack checks the header count per account, the Admin's empty card, the three links and paging, the person named, the due dates, opening and removing an alert with the header following, a row id of another user put into the page, that on both cards the link chosen stays chosen when an item or an alert is opened under Unread, the items of the Action Items card per account (no card for the Admin and MD Secretariat), an item without a mapping row unread and read after opening for that person only, Management's Submit refused, and a Submit with another department's item id refused.

Changed expected values of the dashboard pack (Tests/packs/dashboard/expected.json), each with its cause:

| Value | Before | Now | Cause |
|---|---|---|---|
| alertsFirstPage, admin | 10 | 0 | Rule: no functional alerts for the Admin role. qa_admin has 15 alert rows (every agenda, meeting and committee alert of the fixture); all are of functional types, so none is listed. |
| alertHeadings | Alert, Created on | Alert, Date | The column shows the event date (an approval's date), not the entry date. |
| actionItemsFirstPage, all eight accounts | 1 | 3 | Fixture: every minute of meetings 00005 and 00006 is a Followup now (three action items, mapped to every user as before), so the card can show an overdue, a not-overdue and an undated one. The scope rule is unchanged. |

Not changed although the rule is new: alertsFirstPage of the other seven accounts (controller 1, manager 10, manager2 3, user 10, user2 2, mgmt 2, mdsec 2). For qa_user the 10 is now the whole Recent list (12 alerts, two read ones older than seven days left out) where it was the first page of 12; for the others every alert is unread or dated today.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 42 Installed, step 43 Missing).
2. `BMMS_Test`: BMMS-Fix-DashboardAlerts-Step43.sql ("Step 43 installed: ...").
3. `BMMS_Test`: BMMS-Test-DashboardAlerts-Step43.sql, in a new query window (128 numbered checks, all must PASS).
4. BMMS-Check-InstalledSteps.sql again: step 43 Installed, 10 of 10.
5. Deploy the build (after step 43: the build calls the new procedures).
6. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build. Steps 37 to 42 come first there (the steps are installed in order).
7. To undo: roll back the build, then BMMS-Rollback-DashboardAlerts-Step43.sql (step 43 Missing; "letter for letter" in its last line).

The tester's baseline: step 43 was installed in it with Update-Baseline.ps1 -FixScript, then BMMS_Quality was built afresh with the extended fixture (Setup-Quality.ps1, 2026-11-12).

Browser checks: tester: access-matrix and dashboard (expected PASSED). Owner by eye (Chrome and Edge at 100 percent, BMMS_Test, smtp4dev running): the Alerts card with the three links, the person and the tooltip, at 1366, 1024 and 800 px; "Overdue" in the Action Items card; the header count after Approve and after Reject (the tester cannot drive them: they send mail); an approve, a reject and an item update with the mails read in smtp4dev: none to an Admin, the Controller's, the Manager's and the creator's as before; an Admin's Dashboard ("No alerts.", "Alerts (0)"); the load-failure messages with EXECUTE denied on spr_GetDashboardAlerts, spr_GetDashboardActionItems and spr_GetAlertCount (the statements are in the build report).

## Step UN6c2a: Dashboard "My approvals" panel and "Waiting for me" column; one rule for who may approve (database script step 44 and code; test script for BMMS_Test)

Owner decision 2026-11-13 (plan approved; UN6c2 split into UN6c2a = this step and UN6c2b = step 45: summary cards, Committee filter on the Action Items card and for the User).

What was found first:

- Who may approve or reject was decided in spr_UpdateAgendaByAgendaId alone (step 20): a Manager at AC when he is the creator's manager (Users.ManagerId) or has a row for the item's alert in Alert_User_Map (any row, also one he removed from his list); a Controller approves at AMA and rejects at AC or AMA. The department plays no part.
- The page had a rule of its own for the buttons: every Controller saw Approve and Reject on an item at AMA, every Manager on an item at AC, and the procedure refused what was not allowed (Reason 14).
- The meeting date (step M6a: no decision after the meeting date) was checked by the page only, against the WEB server's date, when the panel opened and again before Approve and Reject. The procedure does not look at the date.
- On BMMS_Test: Manager mgruser may approve 9 items by routing, 8 of them in meetings whose date has passed while the agenda is still open; Manager itmgruser has the same 9 items in his departments and none routed to him.

What changed:

- One rule, fn_AgendaWaitingFor(@UserId, @Today): the items the user may decide (the rules of step 20, unchanged), with CanApprove, CanReject, AgendaOpen, DateOpen and IsWaiting (may approve, agenda open, meeting date not passed). No rows for another role, an inactive user or the system account. Every caller passes the DATABASE server's date.
- spr_UpdateAgendaByAgendaId reads "may this user act" from the function. The order of its refusals (12, 8, 4, 5, 14), everything it writes and its eight parameters are unchanged, and it still does not look at the meeting date. Proof in the Test script: the earlier text is installed under a temporary name and both run on 1352 identical cases (13 kinds of acting user x 13 items x 8 action words); Result, Reason, ReasonDetail and every row written are the same in all of them.
- My approvals panel (spr_GetDashboardApprovals): for a Controller the items at AMA, for a Manager the items routed to him at AC, of meetings whose agenda is open and whose date has not passed (IsWaiting), newest meeting first, 10 per page from the server; title "My approvals (n)". Each row: the item (agenda number, short text), committee, meeting number and date, department; the link opens the Agenda Alert panel. Opening marks the person's own alert of the item read (spr_UpdateAlertByUserId, the acting user's row only) and the Alerts card and the header count follow. The panel follows the Committee drop-down and a Manager's Department drop-down. No panel for the User, Management, MD Secretariat, the Admin and the system account: the server answers Reason 4 (the system account: Reason 12, checked as a system account before the role) and the page hides the panel from that answer. Empty: "Nothing is waiting for your approval." Messages: "The approvals could not be loaded. Reload the page to try again." / "The server is busy and the approvals could not be loaded. Wait a moment, then reload the page." / "The approvals are not available: your account is not active. Sign in again." / a refused filter: "The approvals cannot be shown for this choice. Choose All committees or All my departments."
- "Waiting for me": the last column of the Scheduled list for a Controller and a Manager (spr_GetDashboardMeetings, column WaitingForMe, output @WaitingShown): the number of IsWaiting items of the meeting, within the chosen department for a Manager; empty where none waits; not in the Completed list; not shown to the other roles.
- Approve and Reject buttons of the Agenda Alert panel: from the server (spr_GetAgendaApprovalState, the same function), no longer from the role and the status. The buttons need "may approve" and an open agenda, as the panel and the column do. A Manager the item is not routed to sees the item read-only. The M6a message text is unchanged.
- One date source. Before: the page compared the meeting date with the web server's date (panel, Approve, Reject); the procedure compared nothing. Now: the panel, the column, the buttons and the check before Approve and Reject all use DateOpen of the function, by the database server's date; the procedure still compares nothing (see Known items).
- After Approve or Reject the My approvals panel, the meeting list and the Alerts card reload. When the state of the item cannot be read before a decision: "The item could not be checked, so nothing was changed. Try again." When it cannot be read as the panel opens, a Controller or a Manager sees the item read-only with "Whether you may approve this item could not be checked, so it is shown read-only. Close it and open it again."

Database, step 44 (BMMS-Fix-AgendaWaitingFor-Step44.sql, marker AgendaWaitingFor-Step44, 5 markers in BMMS-Check-InstalledSteps.sql). New: fn_AgendaWaitingFor, spr_GetAgendaApprovalState (@ActingUserId, @AgendaId; OUTPUT @Result, @Reason, @CanApprove, @CanReject, @AgendaOpen, @DateOpen), spr_GetDashboardApprovals (@ActingUserId, @CommitteeId, @DepartmentId, @PageNo; OUTPUT @Result, @Reason, @TotalRows, @PageShown). Replaced: spr_UpdateAgendaByAgendaId and spr_GetDashboardMeetings (both keep the markers of their earlier steps); the Fix script was built from their definitions as installed (identical in BMMS_Test and BMMS_Quality) and stops when it finds another text. The texts are longer than 4,000 characters, so the SHA-1 is taken in pieces of 4,000 characters. Reason 12: the system account; Reason 8: acting user missing or inactive; Reason 4: a role without the panel, an unknown committee, a department that is not the Manager's (any department for a Controller), a page below 1, an unknown item. The script grants nothing. BMMS-Rollback-AgendaWaitingFor-Step44.sql puts the two procedures back letter for letter (SHA-1 compared) and drops the three new objects (checked on BMMS_Test: Fix, Rollback, Fix). BMMS-Test-AgendaWaitingFor-Step44.sql: 120 numbered checks (run it in a new query window): markers, parameters and columns; on the data of the database the function against the step 20 rule for every active user and item; the 1352-case comparison of the earlier and the new approval procedure and 29 named cases (among them: a Manager whose alert row was removed from his list still approves; the system account Reason 12; the procedure approves an item of a past meeting, as before); the 9 items of the departments of itmgruser that are not routed to him, each refused with Reason 14; the function's flags; the approval state; the meeting list with the earlier text beside the new one (every column of before identical, for the made-up users and for every active user of the database) and WaitingForMe; My approvals by role, filter and page; the Rollback's two texts installed inside the transaction and compared with the saved originals.

The Test scripts of the earlier steps after step 44: BMMS-Test-DashboardAlerts-Step43.sql passes unchanged (128). BMMS-Test-DashboardMeetings-Step42.sql was adjusted in three places, each marked "Replaced by step 44": its checks of the parameter count and of the result columns of spr_GetDashboardMeetings, and its own table for the result, expect the step 44 shape when step 44 is installed and the step 42 shape otherwise (71 checks either way; run with step 44 installed and with step 44 rolled back).

Code:

- BMMSDAL/AgendaDB.cs, BMMSBAL/AgendaMgr.cs (GetAgendaApprovalState, GetDashboardApprovals); BMMSDAL/MeetingDB.cs, BMMSBAL/MeetingMgr.cs (GetDashboardMeetings: one more out value, WaitingShown).
- BMMS/UserControl/MeetingSummary.ascx, .ascx.cs: the column "Waiting for me"; the control tells the page which filters are chosen (CommitteeId, DepartmentId) and raises FiltersChanged.
- BMMS/DashBoard/DashBoard.aspx, .aspx.cs, .aspx.designer.cs: the panel (cardApprovals, grvApprovals), LoadApprovals, lnkApproval_Click, TryGetApprovalState; BindAgendaDetails, btnApprove_Click and btnReject_Click ask the server.
- BMMS/CSS/bmms-workbench.css: the panel's place in the Dashboard grid (full width, above the lists), the bold waiting count.
- Tester: the fixture has two more items on QA2 00001 (direct rows, no alerts): QA2-00001-1 (Credit, at AMA) and QA2-00001-2 (Secretarial, at AC, saved by qa_ctrl: not routed to anybody); Fixture-Check has 38 checks (was 35). The dashboard pack checks the panel per account, its filters, opening a row, the buttons, and the Waiting for me column.
- Tester, the follow-up of the owner's tests: fixture item QA2-00013-1 on the new meeting QA2 00013 (40 days ago, agenda still open; at AC, Credit, saved by qa_user, so routed to qa_manager; his alert of it read and 40 days old, so it is on the last page of All only and changes no count); one more Fixture-Check check for it (the 38th). Dashboard pack check 10: the Scheduled table fits its card (no sideways scroll, no gap) for qa_ctrl and qa_manager at 1366 and 1600 px and for qa_mgmt at 1366 px; check 4 also checks the layout at 1241 px (side by side) and 1240 px (stacked). Check 11: qa_manager opens the alert of QA2-00013-1: no Approve or Reject, the meeting-date message inside the panel next to the buttons; QA1-00001-001 opened from My approvals shows Approve and Reject and no message.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 43 Installed, step 44 Missing).
2. `BMMS_Test`: BMMS-Fix-AgendaWaitingFor-Step44.sql ("Step 44 installed: ...").
3. `BMMS_Test`: BMMS-Test-AgendaWaitingFor-Step44.sql, in a new query window (120 numbered checks, all must PASS), then BMMS-Test-DashboardMeetings-Step42.sql (71) and BMMS-Test-DashboardAlerts-Step43.sql (128).
4. BMMS-Check-InstalledSteps.sql again: step 44 Installed, 5 of 5.
5. Deploy the build (after step 44: the build calls the new objects). The earlier build keeps working with step 44 installed.
6. Browser checks (smtp4dev running): My approvals as a Controller and as a Manager; Approve and Reject from the panel (the row leaves the panel, the Waiting for me count and the alerts follow, the mails go out as before); a Manager with nothing routed to him sees "Nothing is waiting for your approval."; the layout at 1366, 1024 and 800 px; the load-failure messages with EXECUTE denied on spr_GetDashboardApprovals.

## Step UN6c2b: Dashboard summary cards; the Committee and Department filters on every card; statistics for the MD Secretariat; "In progress" for every role (database script step 45 and code; test script for BMMS_Test)

Owner decisions 2026-11-13 and 2026-11-14 (plan approved 2026-11-14 with six changes: the Department filter on the Action Items card too; a guard in the step 44 Rollback; pack check 14 shown failing on the build before the fix; the meaning of "In progress" on the card, in the Glossary and the manuals; the inactive committee in the fixture; the expected summary values by an independent count).

What was found first:

- spr_GetDashboardMeetings and spr_GetDashboardApprovals already took @CommitteeId, but accepted any committee that exists, also an inactive one (UN6b review Low). The Action Items card followed no filter.
- The User had no Committee drop-down; the page already lists the active committees for the other roles (spr_GetCommittee @StatusId 1), so no new list procedure was needed.
- The heading "My approvals (n)" lost its count on every postback that does not reload the panel (the Alerts and Action Items links, opening and closing an alert or an action item): its Literal had EnableViewState="false". The new pack check 14 failed 21 times on the build of step UN6c2a (tester run 2026-11-14_221927, all other 277 checks passed).
- The last statistics column said "Pending" for the Controller, Management and the Manager and "In progress" for the User; the MD Secretariat had no statistics.

What changed:

- Summary cards at the top of the Dashboard (spr_GetDashboardSummary): "[department] items in progress" and "[department] items rejected", the items of scheduled meetings (the rule of the Scheduled list: dated today or later, or without a date) by the one status definition fn_AgendaStatusGroup (in progress AC, AMA; rejected AMR, ACR), following the Committee filter and a Manager's Department filter; "Unread alerts", the person's own unread count by the rule of the Alerts card and the header (not filtered). Each card is the total of its column in the Scheduled list for the same filters. Labels: "Items ..." for the Controller and Management, "Credit items ..." for one department, "Items of my departments ..." for a Manager with several, "HRD items ..." with one chosen; the scope line "Scheduled meetings, all committees" or the committee's name; "Your alerts, not filtered" on Unread alerts. The In progress card shows the meaning of "In progress" (the same sentence as the column header's tooltip, which keyboard and touch users cannot reach). Cards for the Controller, Management, the Manager and the User; none for the MD Secretariat and the Admin (Reason 4). A count that cannot be read shows a dash (with "count not available" for a screen reader) and a message, never 0.
- One Committee filter rule (fn_DashboardCommitteeFilter): 0 (all committees) or an ACTIVE committee; an inactive, unknown or negative id is refused with Reason 4 by the meeting list, the summary, My approvals and the Action Items card. "All committees" still lists the meetings of inactive committees.
- The Action Items card follows the Committee filter and the Department filter (spr_GetDashboardActionItems, two optional parameters; the department rule of the meeting list). A refused choice shows "The action items cannot be shown for this choice. Choose All committees." in the card, and "... Choose All committees or All my departments." only where the Department drop-down is shown (a Manager with two or more departments; owner, 2026-11-15). The same rule for My approvals ("The approvals cannot be shown for this choice. ..."), the summary cards ("The counts cannot be shown for this choice. ...") and the meeting list. Called without the parameters it gives the rows of step 43.
- The User has the Committee drop-down (all active committees). The Manager's Department drop-down stays Manager-only (shown with two or more departments).
- The MD Secretariat sees the per-meeting statistics (Items, Approved, Rejected, In progress) for all departments and committees, read-only, as Management; still no Waiting for me, no My approvals, no Action Items. The Admin stays without statistics.
- "In progress" is the heading of the last statistics column for every role, with its meaning as the tooltip (owner, 2026-11-14): for the Controller and the Manager, the roles with "Waiting for me", "Items not yet approved or rejected. For a Manager this includes items waiting for someone else; 'Waiting for me' is the part waiting for you."; for every other role "Items not yet approved or rejected." The same sentence for the role is on the In progress card, and, where no card shows it (the MD Secretariat), in a visible line "In progress: ..." under the lists.
- The Alerts card says "Your own alerts, for every committee. The filters at the top do not apply."
- "My approvals (n)" keeps its count through every postback (the Literal keeps its text in ViewState). On a failed or refused load the heading reads "My approvals (-)" with the dash of the summary cards and "count not available" for a screen reader (owner, 2026-11-14), never an empty heading and never a number.

Database, step 45 (BMMS-Fix-DashboardSummary-Step45.sql, marker DashboardSummary-Step45, 5 markers in BMMS-Check-InstalledSteps.sql). New: fn_DashboardCommitteeFilter (@CommitteeId; column Allowed), spr_GetDashboardSummary (@ActingUserId, @CommitteeId, @DepartmentId; OUTPUT @Result, @Reason, @InProgress, @Rejected). Replaced: spr_GetDashboardMeetings (steps 42 and 44: the committee rule, StatisticsShown 1 for md_sect), spr_GetDashboardApprovals (step 44: the committee rule), spr_GetDashboardActionItems (step 43: @CommitteeId INT = 0 and @DepartmentId INT = 0, last); each keeps the markers of its earlier steps; parameters and columns of before unchanged. The Fix script was built from the definitions as installed (identical in BMMS_Test and BMMS_Quality; SHA-1 in pieces of 4,000 characters) and stops when it finds another text. Reason 12: the system account (summary, approvals); Reason 8: acting user missing, 0 or inactive; Reason 4: a role without the block, a committee that is not active, a department outside the scope (any department for a Controller or Management). The script grants nothing. BMMS-Rollback-DashboardSummary-Step45.sql puts the three procedures back letter for letter (SHA-1 compared) and drops the two new objects; checked on BMMS_Test: Fix, Rollback (letter for letter), Rollback again (refused: nothing to roll back), Fix, Fix again (safe to re-run).

BMMS-Rollback-AgendaWaitingFor-Step44.sql now refuses while step 45 is installed ("Step 45 is installed ... Run the step 45 Rollback (BMMS-Rollback-DashboardSummary-Step45.sql) first, then this script. Nothing was changed."): run on BMMS_Test with step 45 installed, it refused and the checksum of all 204 module definitions was the same before and after. Rollbacks run in the reverse order of the steps.

BMMS-Test-DashboardSummary-Step45.sql: 66 numbered checks, all PASS on BMMS_Test on 2026-11-14 (run it in a new query window): markers (new and kept), parameters and columns; fn_AgendaStatusGroup and fn_DashboardActionItems unchanged (SHA-1); no feature above compatibility level 100; EXECUTE for every database user who can run step 42's procedures; the condition of the step 44 Rollback's guard. Inside one rolled-back transaction with made-up data ZZ45 (three departments, the six roles, an inactive user, an active, a second active and an inactive committee, meetings today, later, without a date and past, 147 items in every status, 6 action items): the committee function; 26 fixed summary cases (counts, filters, Reasons 4, 8 and 12); for 320 cases (every active Controller, Management user, Manager and User x every committee value x every department of the scope) the summary equals an independent count and the totals of the Scheduled list; 60 calls with an inactive, unknown or negative committee refused with Reason 4 by all four procedures; the MD Secretariat's rows equal Management's, without Waiting for me, My approvals or Action Items; the earlier texts beside the new ones on 730 cases each (meeting list: no difference but the MD Secretariat's statistics; My approvals: none; Action Items: the earlier rows of the chosen committee and department); the Action Items called without the new parameters as in step 43; the Rollback's three texts installed inside the transaction and compared by SHA-1. Information line: the 320 summary cases took about 1.9 s in all (summary, independent count and meeting list each).

The Test scripts of the earlier steps after step 45 (each change marked "Replaced by step 45" and applied only when step 45 is installed; every script passes with step 45 installed and with it rolled back): BMMS-Test-DashboardMeetings-Step42.sql (71): the two MD Secretariat cases expect the statistics (Shown 1; all 15 rows with counts). BMMS-Test-DashboardAlerts-Step43.sql (128): the parameter count of spr_GetDashboardActionItems is 5 (2 OUTPUT). BMMS-Test-AgendaWaitingFor-Step44.sql (120): its two comparisons of the meeting list with the step 42 text (the eleven fixed calls, among them one of the MD Secretariat, and every active user) expect an MD Secretariat user to have StatisticsShown 1 and the counts of Management, and then compare as "no statistics".

Code:

- BMMSDAL/AgendaDB.cs, BMMSBAL/AgendaMgr.cs (GetDashboardSummary); BMMSDAL/ActionItemDB.cs, BMMSBAL/ActionItemMgr.cs (GetDashboardActionItems with CommitteeId and DepartmentId; the earlier signature sends 0 and 0).
- BMMS/UserControl/MeetingSummary.ascx, .ascx.cs, .ascx.designer.cs: the cards (LoadSummary with the filters of the meeting list, SetUnreadAlerts, dashes, labels), the role table ("In progress" for every role, the Committee drop-down for the User), the header tooltip.
- BMMS/DashBoard/DashBoard.aspx, .aspx.cs: the count of My approvals kept; the Unread alerts value from the Alerts card's load; the Action Items card with both filters, reloaded when a filter changes, and its message for a refused choice; the note of the Alerts card.
- BMMS/CSS/bmms-workbench.css: the cards (a wrapping row of three .wb-card tiles, at least 200 px each), the message under them, the note of the Alerts card. After the owner's test at 200 % zoom (the Meetings tables cut off at the right): at 1240 px and below the Meetings cells are tighter (6 px by 4 px) and the status chip may wrap, so the nine-column Scheduled list fits its card down to about 770 px (it needed 794 px before and scrolled inside the card below about 860 px); below 960 px a list still wider than its card scrolls inside it with the Meeting column kept in view (sticky). No column is hidden; the page never scrolls sideways. After the owner's second test (a thin inner scrollbar and "Waiting for me" cut off by a few pixels in Edge at 200 %, which has a classic vertical scrollbar of about 17 px; reproduced at 768 px, the window of a 1536 px desktop at 200 %: the list needed 707 px in a 685 px box), at 1240 px and below also: 3 px cell padding beside the text, 13 px headings, a committee minimum of 6em and a smaller chip; the list now needs 644 px (41 px to spare at 768 px with the scrollbar, 233 px at 960 px). Dashboard pack check 17: qa_manager and qa_ctrl with a 17 px scrollbar at 1280 (fits), 1097, 960 and 768 px (at least 24 px to spare), and at 800 px without it (fits).
- Tester: the fixture has committee QA9 "QA Inactive Committee" (inactive, a direct row without members, meetings or alert, so that no account's alerts change); Fixture-Check has 39 checks (was 38). The dashboard pack: check 1 also checks the In progress header and its tooltip, the MD Secretariat's statistics and the User's drop-down; new checks 12 (cards per account), 13 (both filters on every card), 14 (My approvals keeps its count), 15 (the inactive committee offered to nobody), 16 (the cards at 1366, 1280, 1097, 960 and 640 px); see Tests/packs/dashboard/README.md, with the values of the independent count.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 44 Installed, step 45 Missing).
2. `BMMS_Test`: BMMS-Fix-DashboardSummary-Step45.sql ("Step 45 installed: ...").
3. `BMMS_Test`: BMMS-Test-DashboardSummary-Step45.sql, in a new query window (66 numbered checks, all must PASS), then BMMS-Test-DashboardMeetings-Step42.sql (71), BMMS-Test-DashboardAlerts-Step43.sql (128) and BMMS-Test-AgendaWaitingFor-Step44.sql (120).
4. BMMS-Check-InstalledSteps.sql again: step 45 Installed, 5 of 5.
5. Deploy the build (after step 45: the build calls the new procedure and parameters). The earlier build keeps working with step 45 installed.
6. Browser checks: the cards per role, the filters on every card, the MD Secretariat's table, the User's Committee drop-down, the layout at 1366, 1280, 1097 and 960 px.

## Step UN6d: Submit on read-only action items; the Followup page saves decided on the server (database script step 46 and code; test script for BMMS_Test)

Owner decisions 2026-11-15 (plan approved with five changes: one refusal text on Followup for every role; the failure, busy and too-long messages of the Dashboard panel inside the panel; the too-long message inside the Followup panel too; the tester's baseline with step 46; the Test script also proves a refused Submit whose bad row is the last of several, and Reason 8 for an inactive Controller). The MD Secretariat reads the Followup page only (owner, 2026-11-15; before, rule W6 of the access matrix and the manuals said it "works on Followup").

What was found first:

- Dashboard, Action Item Details panel: a Controller saw Submit, Close and Cancel; a Manager and a User Submit and Cancel; every other role Submit, Close and Cancel. MD Secretariat and Admin have no Action Items card (step 43), so "every other role" is Management in practice. The server already refused Management's Submit (spr_SaveDashboardActionText, step 43).
- After a done or refused Submit the panel closed, the list was not read again and a save showed no message. A failed save wrote its message into the page's message box, which lies under the open panel (as step UN6c2a found for the Agenda Alert panel).
- The Followup page saved through spr_UpdateActionItem with no acting user: any session that reached the page could save, also the MD Secretariat. Every handler went to the error page on any failure. The item id of the Action Text save was read with Convert.ToInt16. The Action Text save showed no message; Submit showed "Successfully Saved".
- spr_UpdateActionItem as installed (identical in BMMS_Test and BMMS_Quality; SHA-1 7EC3DBDD2E40D966EDFA54EEBF52EF18797EF865 without carriage returns, letter for letter the step 31 text) writes for the code 'ActionText' Action_Item.ActionText only (no UpdatedOn, no UpdatedBy, no flag, a confirmed item too, an unknown id silently nothing); for the code 'All' Action_Item.IsComplied = @IsComplied and IsConfirmed = @IsConfirmed, and for a tick (IsConfirmed 1) StatusId 0 on every ActionItem_User_Map row of the item (an unticked item keeps its rows as they are). The page sent IsComplied 0 on every row (so every Submit set IsComplied 0) and empty texts, which the code 'All' ignores. Submit called it once per row with no transaction across rows. The code 'ActualResolution' has no caller.
- The page's list (ReportsMgr.GetFollowupReport, View_Action_Item) does not use the meeting date boxes (Known items).

What changed:

- Dashboard panel: Submit and Cancel only for the Controller, the Manager and the User (the Controller lost Close; the X in the header stays for everyone); every other role Close only, the Action Text read-only and the line "You can read this action item. Your role cannot change it." inside the panel. The buttons follow the session role; the server decides every save as before (spr_SaveDashboardActionText and the other objects of steps 43 and 45 are not changed).
- Dashboard Submit: saved, the panel closes, the Action Items list is read again with the link chosen (Show All / Read / Unread), the page and the Committee and Department filters kept (LoadActionItemGRV), and "The action text was saved." is shown as a success. Refused: the panel closes, the list is read again, the message of before ("You cannot change this action item: your role can only read it, or it is not an item of your department. Nothing was saved." / "Your account is not active. Nothing was saved. Sign in again."). Failed, server busy, or a text that is too long: the panel stays open with the text typed and the message ("The action text could not be saved. Nothing was saved. Try again." / "The server is busy and the action text could not be saved. Nothing was saved. Wait a moment, then try again." / "The text is too long. Shorten it or attach the document as a file.") is on the line inside the panel. The line is cleared when the panel opens and when it closes.
- Followup page: both saves go to the two procedures of step 46, which decide from the acting user id (the role read from the database): only an active Controller that is not the system account. What a save writes is unchanged.
  - Save of the Action Text: saved, the panel closes with "The action text was saved."; failed, busy or too long: the panel stays open with the text and the message on a line inside it ("The action text could not be saved. Nothing was saved. Try again." / "The server is busy and the action text could not be saved. Nothing was saved. Wait a moment, then try again." / the too-long text); the failure is written to the error log.
  - Submit: every row of the list in ONE call (spr_SaveFollowupConfirmed, one transaction): all rows are saved or none. Saved: "The confirmations were saved." (was "Successfully Saved"). Failed: "The confirmations could not be saved. Nothing was saved. Try again." or "The server is busy and the confirmations could not be saved. Nothing was saved. Wait a moment, then try again.", written to the error log, no error page.
  - Refused (Reason 4 or 12), for every role and for an item that no longer exists, one text: "You cannot change the followups: your role can only read them, or an item on the list no longer exists. Nothing was saved. Click View to read the list again." Reason 8: "Your account is not active. Nothing was saved. Sign in again."
  - The MD Secretariat (any role but the Controller, by the session role, for what the page shows): no Submit button, the Confirmed ticks disabled, "View" on the Action Text button of each row, the line "You can read the followups. Your role cannot change them." above the list; the Action Text panel titled ":: View Action Text", read-only, without Save, with Close (was Cancel) and the same line inside it. PageAccess.xml is not changed (the page still opens for controller and md_sect).
  - The item ids are read as full ints (int.TryParse); a row whose id cannot be read refuses the Submit before anything is sent.
- Code: ActionItemDB / ActionItemMgr SaveFollowupActionText and SaveFollowupConfirmed (the list built with XmlWriter; the business layer cleans the text with HtmlCleaner.Clean as before); the wrappers UpdateActionItem (DAL and BAL) removed, nothing calls them.

Layout faults found in the owner's browser test of the Followup page (2026-11-15, 1920 px), fixed in markup and CSS only (each measured on a copy of the page structure with the real stylesheets in the browser, before and after):

- A (caused by UN6d): the new message lines (above the list, and in the Action Text panel) were plain blocks after floated .divRow rows (CommonHTML.css, float: left; width: 100%), so a line's background started at the top of the floated row before it and ran under it (above the list: behind the filter rows, 220 px tall). Fix: each line's wrapper floats like the rows around it (.wb-followup-row, bmms-workbench.css, Followup only).
- B (old, in HEAD since step A2a): in both Followup panels (Actual Resolution, Action Text) the 600 px editor sat at the left of a panel about 1340 px wide (.MyPopupContentInner, 90 %) while the buttons were centred: the editor is a block (.rte, RichTextEditor.css), which text-align: center does not centre. Fix: .wb-followup-popup .rte with auto margins, and the panel line as wide as the editor and centred under it (.wb-followup-popup .wb-dash-message, 600 px, the same width as ftxtActionText; a comment at each names the other). The white area under an open panel is the step H1 design (the panel covers the content area) and is kept.
- C (old, in HEAD since commit ba361c3, step H1, 2026-11-06; not caused by UN6d): with a Followup panel open and a list taller than 70 % of the window, the page footer was drawn as a narrow column at the right edge of the window, level with the last rows of the list (measured at 1920 x 1080: the footer text at 1529 px from the left, 352 px wide, wrapped; the owner saw it before the A and B fix too). Cause: the step H1 rule body.wb div#contentArea:has(.MyPopupOuter) (CommonHTML.css) sets overflow: visible, which took away what made #contentArea contain floated content (overflow-x: auto, bmms-workbench.css); the Followup content is floated (.formContent), so it hung out below the content area (which ended at min-height 70vh) and the footer, a full-width block after it, wrapped beside the float. Fix: display: flow-root in that rule: the content area contains the floats again, without clipping or scrolling. Pages with MyPopupOuter: Followup (changed: the footer centred below the list; the open panel now covers the whole list, as H1 intends); the Dashboard (content in a grid) and Update Minutes (content in a form block, floats only inside its popups) were not affected and are unchanged (identical measurements before and after). The purpose of step H1 still holds on all three: with a panel open the panel starts at the header's lower edge and the header is the topmost element at its own centre.

Database, step 46 (BMMS-Fix-FollowupSave-Step46.sql, marker FollowupSave-Step46, 2 markers in BMMS-Check-InstalledSteps.sql). New: spr_SaveFollowupActionText (@ActingUserId, @ActionItemId, @ActionText; OUTPUT @Result, @Reason) and spr_SaveFollowupConfirmed (@ActingUserId, @Items XML `<items><i id=".." c="0|1"/>...</items>`; OUTPUT @Result, @Reason, @Saved). Reasons in the order of steps 44 and 45: 12 the system account; 8 acting user missing, 0, NULL or inactive; 4 another role, an item that does not exist, and for the Submit a list that cannot be read (another root, an element other than `<i>`, an id that is not a whole number of at most 10 digits that fits an INT, an id given twice, a tick other than 0 or 1, no list). A refused call writes nothing. The Submit opens its own transaction only when the caller has none, and never rolls back a transaction it did not begin. Replaced: nothing. spr_UpdateActionItem is left untouched and without a caller (Known items: drop list); a re-run of step 31 does not touch step 46. The script grants nothing. BMMS-Rollback-FollowupSave-Step46.sql drops the two procedures; it refuses when step 46 is not installed. Checked on BMMS_Test: Fix, Fix again (safe to re-run; the other 204 module texts unchanged), Rollback, Rollback again (refused), Fix.

BMMS-Test-FollowupSave-Step46.sql: 56 numbered checks, all PASS on BMMS_Test on 2026-11-15 (run it in a new query window): markers, parameters, no result set, no feature above compatibility level 100; spr_UpdateActionItem the step 31 text (SHA-1); the objects of steps 43 and 45 unchanged; EXECUTE for every database user who can run step 42's procedure. Inside one rolled-back transaction with made-up data ZZ46 (one department, a committee, a meeting with finalised minutes, the six roles, an inactive Controller, 17 action items with two mapping rows each): the Submit on six twin pairs against spr_UpdateActionItem row by row (both ticks from every start of IsComplied and IsConfirmed, a mapping row already at StatusId 0): every column of Action_Item and the mapping rows the same, and the values by name; the Action Text on a confirmed twin pair with a Unicode text, the same as spr_UpdateActionItem; each role refused for both procedures (Manager, User, Management, MD Secretariat, Admin: 4; the system account: 12; an inactive Controller, an unknown user, 0 and NULL: 8) with every ZZ46 row unchanged; the Submit by the Controller refused as a whole, every row as it was, when one row is bad: an unknown item LAST of four and FIRST of four, an id given twice, a tick of 2 or missing, an id that is not a whole number, with a space, negative, too large or of 11 digits, an element other than `<i>`, two roots, another root name, no list; the three good rows of those lists alone saved; an empty list (Result 1, nothing written); the test's own transaction still open after the refusals; the Action Text refused for an unknown and a NULL item; the Rollback's two DROPs inside the transaction. Afterwards the agenda, minutes, action item and mapping tables are unchanged and every identity counter is put back.

The Test scripts of the earlier steps after step 46, unchanged and passing on BMMS_Test (2026-11-15): BMMS-Test-UnicodeText-Step31.sql (41), BMMS-Test-DashboardAlerts-Step43.sql (128), BMMS-Test-DashboardSummary-Step45.sql (66).

Tester:

- The fixture is unchanged. The dashboard pack, check 8: qa_ctrl's panel has Submit and Cancel and no Close; qa_mgmt's has no Submit, no Cancel, Close and the read-only line (before: its Submit was clicked and refused; the server's refusal is still proven by the step 43 Test script); qa_manager2's refused Submit closes the panel and the list is read again; his Submit inside his scope under Read shows "The action text was saved." as a success, with Read still chosen and the item listed (before: no message).
- New followup pack (Tests\packs\followup): qa_mdsec reads only (the five rows, the line, no Submit, the ticks disabled, "View", the panel ":: View Action Text" without Save, with Close); qa_ctrl's Save and Submit with the values of the fixture, with their success messages.
- The access-matrix pack: expected.csv unchanged (the page still opens for md_sect); the text of rule W6 changed.

Changed expected values of the dashboard pack (Tests/packs/dashboard/expected.json and pack.js), each with its cause:

| Value | Before | Now | Cause |
|---|---|---|---|
| Check 8, qa_mgmt | Submit clicked, refused with the step 43 message, panel closed | no Submit, no Cancel, Close, the line "You can read this action item. Your role cannot change it."; Close closes without a message | UN6d A1, A2: Submit and Cancel only for the Controller, the Manager and the User |
| Check 8, qa_manager2's own Submit | no message, panel closed | "The action text was saved." (success), panel closed, list read again under Read | UN6d A3 |
| Check 8, qa_manager2's Submit with another department's id | the message | the message, the panel closed, the list read again | UN6d A4 |
| Check 8, qa_ctrl's panel | (not checked) | Submit and Cancel, no Close, no line | UN6d A1 |

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 45 Installed, step 46 Missing).
2. `BMMS_Test`: BMMS-Fix-FollowupSave-Step46.sql ("Step 46 installed: ...").
3. `BMMS_Test`: BMMS-Test-FollowupSave-Step46.sql, in a new query window (56 numbered checks, all must PASS), then BMMS-Test-UnicodeText-Step31.sql (41), BMMS-Test-DashboardAlerts-Step43.sql (128) and BMMS-Test-DashboardSummary-Step45.sql (66).
4. BMMS-Check-InstalledSteps.sql again: step 46 Installed, 2 of 2.
5. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-FollowupSave-Step46.sql`, then `pwsh -NoProfile -File Tests\_runner\Setup-Quality.ps1`.
6. Deploy the build (after step 46: the build calls the two new procedures). The earlier build keeps working with step 46 installed (it calls spr_UpdateActionItem, which is unchanged).
7. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build. Steps 42 to 45 come first there (the steps are installed in order).
8. To undo: roll back the build, then BMMS-Rollback-FollowupSave-Step46.sql (step 46 Missing).

Browser checks: tester: access-matrix, dashboard and followup. Owner by eye (Chrome and Edge at 100 percent, BMMS_Test, at 1366 and 1024 px): the Dashboard panel as Management (the read-only line, Close only) and as the Controller (Submit and Cancel), the green "saved" message after a Submit; the Followup page as the MD Secretariat (the disabled ticks, the line above the list, the View panel) and as the Controller (Save, Submit, the two success messages); the failure messages inside the two panels and the Submit failure with EXECUTE denied on the new procedures (statements in the build report); the too-long message inside both panels.

## Step FU1: a confirmed followup becomes final; Reopen with a reason; who confirmed and when (database script step 47 and code; test script for BMMS_Test)

Owner decisions 2026-11-16 (requirement R1 to R15, plan approved with four changes: the reopen text parameter is @ReopenReason; the skipped-rows message without "by another Controller"; this section says to install step 47 and deploy the build together; the Test script proves parity of the new list with the old query). D1: the history rows go with their item by a cascading foreign key; D2: the step 46 Test stops with a pointer while step 47 is installed; D3: a blank or too-long reason is Reason 4, at most 500 characters; D4: "Name (login)" and HH:mm; D5: a check in the browser for "<" in the reason.

What was found first:

- The page's list came from ReportsMgr.GetFollowupReport (`SELECT * FROM View_Action_Item ...` built in the code), which Report/Followup.aspx uses too; the reports are out of scope, so the page gets a procedure of its own and the report path is unchanged.
- ActionItem_User_Map already has a cascading key to Action_Item (FK_ActionItem_User_Map_Action_Item); Action_Item has no other child table and no trigger.
- ActionItem_User_Map.StatusId is written (1 when a mapping row is made, 0 by a confirm) and read by no procedure, view, function or page code; since step 43 it decides nothing. Reopen leaves it as it is (owner default).
- Reason codes 1 to 25 were taken (System-Manual/04-Database, "Reason codes"): step 47 adds 26 and 27.
- The procedures that delete Action_Item rows: spr_DeleteAgendaByAgendaId (step 16 text; also in step 6), spr_AgendaFinalizeByMeetingId (step 15; also step 6), spr_UpdateMinutes (step 38; also steps 6, 16, 17, 18, 23 and 31: a decision changed away from Followup), spr_sys_ResetDatabase (step 39; also steps 3, 18, 21, 29 and 30); BMMS-Test-MinutesEditor-A2.sql deletes its own rows directly. spr_DeleteMeetingByMeetingId (step D1) refuses a meeting with agenda items, and spr_DeleteUserByUserId (step 39) deletes only mapping rows. With the cascading key none of them is replaced.

What changed:

- Followup page (Master/Followup.aspx), Status column instead of the Is Confirmed tick (R1, R2): a Pending row of the Controller has a drop-down Pending / Confirmed (Pending chosen); a role that only reads sees "Pending". A Confirmed row is final (R6, R7): "Confirmed" and "Confirmed by [Name (login)] on [dd-MMM-yyyy HH:mm]", or "Confirmed (before history)" for an item confirmed before step 47 (R12; "Confirmed" alone when its latest history row is a Reopen, which only an older build after a rollback can leave); no drop-down; the Action Text button reads "View" for every role, the Controller too, and the panel opens read-only (for the Controller with the line "This followup is confirmed and can no longer be changed. Reopen it to change the action text."). A reopened row shows "Reopened by [Name (login)] on [date]: [reason]" under the drop-down (R9). The filter label "Not Confirmed" reads "Pending" (R15, this page only).
- Submit (R3 to R5): only the rows changed from Pending to Confirmed are sent, in one call; rows left Pending and rows already confirmed are not written. No row changed: nothing is sent, "No followup was changed to Confirmed. Nothing was saved.". Saved: "[n] followups were confirmed." / "1 followup was confirmed." (success), with "[m] had already been confirmed." when rows were skipped (confirmed in between, by another Controller or in another tab); none confirmed now: "No followup was confirmed. [m] had already been confirmed." (warning). The list is then read again with the filters of View. Submit is hidden while the list has no Pending row.
- Reopen (R8 to R10), Controller only, on a Confirmed row: the panel ":: Reopen Followup" names the item (agenda, subject and meeting number) and asks "Reason for reopening :" (mandatory, trimmed, at most 500 characters, a line break counted as one; "Enter the reason for reopening." / "The reason can be at most 500 characters." inside the panel, which stays open with the text). A "<" followed by a letter, "!", "/" or "?", or "&#", is stopped in the browser with `Remove the "<" or "&#" from the reason, then save again.` (D5; text by the owner, 2026-11-16, after the UX review found that "Do not use < in the reason." left out "&#"; the server's request validation would otherwise show the error page). Save reopens that one item at once: "The followup was reopened." (success), the list read again, with the Status choices not yet submitted on other rows kept; refused because the item is no longer confirmed: "This followup is no longer confirmed. Nothing was saved. Click View to read the list again."; a failure or a busy server keeps the panel open with its message and writes the error log.
- Save of the Action Text: refused for a confirmed item (Reason 26): "This followup is confirmed and can no longer be changed. Nothing was saved. Click View to read the list again."
- The list is read through spr_GetFollowupList; a role without access gets an empty list and "You cannot read the followups: your role has no access to them." (an inactive account: "Your account is not active. Sign in again."). The unused ViewState copy of the whole list (ViewState["GetFollowup"]) is gone; the filters of View are kept instead.
- Every text from the database in the Status cell (names, the reason, the date) is encoded with HttpUtility.HtmlEncode in grvFollowup_RowDataBound and written through a Literal; the message box (InnerHtml) only ever gets the page's fixed texts and numbers.
- Code: ActionItemDB / ActionItemMgr SaveFollowupConfirmed (the list of ids, out Saved and Skipped), ReopenFollowup (the BAL trims and never sends a blank reason or one over 500 characters), GetFollowupList; CSS .wb-followup-status*, .wb-followup-reopen* (bmms-workbench.css, Followup only).
- Not changed (R14): everything else that reads IsConfirmed counts a reopened item as not confirmed, because it reads the column: fn_DashboardActionItems (the Dashboard's Action Items card and its Overdue mark, through spr_GetDashboardActionItems and spr_OpenDashboardActionItem; spr_SaveDashboardActionText), View_Action_Item (the Controller's Followup and Followup Summary reports, ReportsMgr.GetFollowupReport), spr_GetFollowupReportForManagement (Management's Followup reports), spr_GetActionItemByMeetingId and spr_GetActionItemByUserId (no caller). The Test script proves the first three.

Database, step 47 (BMMS-Fix-FollowupFinal-Step47.sql, marker FollowupFinal-Step47; 5 markers and the table, 6 rows in BMMS-Check-InstalledSteps.sql). Installed after step 46 (it stops otherwise).

- New table Action_Item_Status_History: StatusHistoryId INT IDENTITY (PK), ActionItemId INT NOT NULL (FK to Action_Item ON DELETE CASCADE), [Action] VARCHAR(10) NOT NULL ('Confirm' or 'Reopen'), Reason NVARCHAR(500) NULL (NULL for Confirm, not blank for Reopen; two check constraints), ActedBy INT NOT NULL (FK to Users), ActedOn DATETIME NOT NULL DEFAULT GETDATE(); index IX_Action_Item_Status_History_ActionItemId (ActionItemId, StatusHistoryId). Only inserted into; no procedure updates or deletes it (the Test script checks the texts by name). It starts empty: items confirmed before step 47 have no row.
- Replaced: spr_SaveFollowupConfirmed (@ActingUserId, @Items XML `<items><i id=".."/>...</items>`; OUTPUT @Result, @Reason, @Saved, @Skipped (new)): the checks of step 46 (12, 8, 4; a list that cannot be read, an element other than `<i>`, an attribute other than id, such as the c of step 46, an id that is not a whole number of at most 10 digits that fits an INT, an id given twice, an item that does not exist: Reason 4, nothing written); then under UPDLOCK, HOLDLOCK, in one transaction, every row still not confirmed gets what a tick wrote before (IsConfirmed 1, IsComplied 0, every mapping row of the item StatusId 0) and one Confirm history row; a row already confirmed is skipped and counted in @Skipped. spr_SaveFollowupActionText: the same checks, then the item under UPDLOCK: Reason 26 when it is confirmed, Reason 4 when it does not exist.
- New: spr_ReopenFollowup (@ActingUserId, @ActionItemId, @ReopenReason NVARCHAR(500); OUTPUT @Result, @Reason): 12, 8, 4 as above, Reason 4 also for a NULL or blank reason (spaces, tabs, line breaks, no-break and zero-width spaces) and an item that does not exist, Reason 27 when the item is not confirmed; otherwise IsConfirmed 0 and one Reopen row with the reason trimmed of spaces, in one transaction under UPDLOCK; IsComplied and the mapping rows are left. A text longer than 500 characters is cut by the parameter type; the page and the business layer never send one. spr_GetFollowupList (@ActingUserId and the page's filters as INTs; OUTPUT @Result, @Reason): the View_Action_Item rows with the filters and the order of the old query (ActionItemId added for rows equal in CommitteeId, MeetingId, DepartmentId and IsConfirmed, which the old query left to the server), plus StatusAction, StatusReason, StatusOn, StatusByName, StatusByLogin, StatusByActive of the latest history row (OUTER APPLY TOP 1); only an active Controller or MD Secretariat that is not the system account gets rows (12, 8, 4 otherwise; one result set always).
- Replaced: spr_DeleteUserByUserId, the step 39 text with one line: rows the user wrote in the history table (ActedBy) add the group 'minutes' to Reason 6, as Action_Item.UpdatedBy does; the messages are unchanged.
- The step 47 texts keep the markers FollowupSave-Step46 and UserHistory-Step39 (and the older ones of spr_DeleteUserByUserId), so steps 46 and 39 read Installed after it. Re-run rule: a re-run of step 46 removes step 47 from the two Followup procedures (Partly, 4 of 6); a re-run of step 2, 6, 10, 13 or 39 from spr_DeleteUserByUserId (Partly, 5 of 6); run step 47 again. The re-run notes near the top of this file say so.
- Install step 47 and deploy the build of FU1 together. With step 47 and the build of UN6d, Submit is refused (Reason 4, nothing saved), because that page sends the attribute c; its Save of the Action Text still works for a Pending item and is refused (its generic refusal text) for a confirmed one. With the build of FU1 and without step 47, every View goes to the error page (spr_GetFollowupList is missing).
- Rollback (BMMS-Rollback-FollowupFinal-Step47.sql): puts back the step 46 texts of the two Followup procedures and the step 39 text of spr_DeleteUserByUserId letter for letter (compared by SHA-1 with BMMS_Quality on 2026-11-16), drops spr_ReopenFollowup and spr_GetFollowupList, and KEEPS the table with its rows, keys and index (as the step 39 Rollback keeps its tables); IsConfirmed values stay as they are. Afterwards deleting a user with history rows is refused by the foreign key (an error, nothing deleted); BMMS-Check-InstalledSteps.sql shows step 47 Partly, 1 of 6 (the table). Roll back the build first; roll back step 47 before step 46: BMMS-Rollback-FollowupSave-Step46.sql now refuses while step 47 is installed. A second run refuses and changes nothing.
- EXECUTE: as steps 42 to 46, nothing is granted; the application login holds EXECUTE on the schema dbo (the Test script checks it as each database user).

BMMS-Test-FollowupFinal-Step47.sql: 95 numbered checks, all PASS on BMMS_Test on 2026-11-16 (run it in a new query window). Part 1: the markers and the kept ones, parameters, result sets, no feature above compatibility level 100, the table (columns, identity, key, default, the two foreign keys with their delete rule, the checks, the index), no module updates or deletes it by name, spr_UpdateActionItem the step 31 text, the objects of steps 43 and 45 unchanged, EXECUTE for every database user who can run step 42's procedure. Part 2, in one rolled-back transaction with made-up data ZZ47 (two departments, a committee, three meetings, the six roles, a second and an inactive Controller, 22 action items): only the rows sent are written, with their history rows; a row already confirmed is skipped; the step 46 shape and 16 more bad lists refused as a whole; the Action Text saved on a Pending item and refused (26) on a confirmed one, before history too; Reopen with the reason trimmed and letter for letter, refused (27) when not confirmed, refused (4) for a NULL, empty, spaces-only or tabs-and-line-breaks reason and an unknown item, 500 characters kept whole, 501 cut to 500 by the parameter type; a reopened item editable and confirmed again; an item confirmed before step 47 reopened; every role and the system, inactive, missing, 0 and NULL user refused for the three saves and the list (the MD Secretariat reads the list); the latest history row and who acted per item; parity with the old query for 24 filter combinations (Both / Confirmed / Pending; every committee, Particular with one and with all meetings, Between; with and without a department; 334 rows compared on BMMS_Test); a reopened item listed and Overdue in fn_DashboardActionItems, with IsConfirmed 0 in View_Action_Item, under Not Confirmed in spr_GetFollowupReportForManagement; the history rows gone with their item through spr_UpdateMinutes, spr_DeleteAgendaByAgendaId, spr_AgendaFinalizeByMeetingId and a direct DELETE; spr_DeleteUserByUserId refuses a user with history rows (Reason 6, 'minutes') and deletes one without. Afterwards every table and identity counter as before.

The Test scripts of the earlier steps after step 47 (BMMS_Test, 2026-11-16): BMMS-Test-FollowupSave-Step46.sql ("Replaced by step 47": while step 47 is installed it runs no check and names the step 47 test; with step 47 rolled back, 56 of 56 PASS, run so on 2026-11-16). BMMS-Test-ResetDatabase.sql: its count of the keys to Users is 30 when the table exists ("[step 47: +1]"); 40 PASS. Unchanged and passing: BMMS-Test-UnicodeText-Step31.sql (41), BMMS-Test-DashboardAlerts-Step43.sql (128), BMMS-Test-DashboardSummary-Step45.sql (66), BMMS-Test-UserDelete.sql (75), BMMS-Test-UserHistory-Step39.sql (58), BMMS-Test-UserProtection-Stage1.sql (142), BMMS-Test-FK-Procedures.sql (19), BMMS-Test-ReportAccess-Step41.sql (44). BMMS-Test-MinutesEditor-A2.sql is a manual test in four parts (it needs a Controller login set at its top) and was not run; its clean-up deletes action items directly, which the cascade covers (checked by the step 47 test).

Tester:

- The fixture is unchanged. The followup pack (Tests\packs\followup) is rewritten for FU1: the Controller's View (the drop-downs), the unchanged Save of the action text, a Submit with no row changed, the Confirm of QA1-00005-001 (the message, who and when, no drop-down, Reopen, "View"), its action text read-only, the filter Confirmed without Submit, the Reopen panel (no reason, "<b" stopped in the browser, a reason with & and quotes shown exactly), then the MD Secretariat's read-only view with the reopen line. The row ends not confirmed, as in the fixture.
- The access-matrix pack: expected.csv unchanged. The dashboard pack: unchanged.
- Run 2026-11-16_133023 (access-matrix, dashboard, followup; baseline with step 47): PASSED, 878 checks (selftest 8, access-matrix 472, dashboard 385, followup 16), 3 planted failures caught, the standing proof held, 0 error-log lines, 0 outside requests, 288 s. The expected values of the followup pack were approved by the owner (2026-11-16).
- Before that run the baseline update refused twice: the owner's copy BMMS_NQuality (a restore of BMMS_Quality on the default instance) let bmms_tester in as its dbo and kept a bmms_site user. On the owner's word its owner was set to the owner's login (dbo follows) and the bmms_site user dropped; the copy stays. Tests/README.md ("One-time setup and upkeep") says what to do with such a copy.

Changed expected values of the followup pack (Tests/packs/followup/expected.json and pack.js), each with its cause:

| Value | Before | Now | Cause |
|---|---|---|---|
| The Controller's rows after View | every tick enabled | every row Pending with the Status drop-down, no Reopen | FU1 R1, R2 |
| The Controller's Submit with nothing changed | "The confirmations were saved." (success) | "No followup was changed to Confirmed. Nothing was saved." (warning) | FU1 R5 |
| `confirmedSaved` | "The confirmations were saved." | removed; `confirmedOne` "1 followup was confirmed." | FU1 R4 |
| The MD Secretariat's rows | every tick disabled | no drop-down, no Reopen, "Pending", the reopen line | FU1 R1, R9 |
| New: Confirm, Reopen, the filter Confirmed, the reopen messages and line | (not checked) | as in the pack's README | FU1 R3 to R10 |
| Order of the two roles | MD Secretariat, then Controller | Controller, then MD Secretariat (who then sees the reopen) | FU1 R9 |

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 46 Installed, step 47 Missing).
2. `BMMS_Test`: BMMS-Fix-FollowupFinal-Step47.sql ("Step 47 installed: ...").
3. `BMMS_Test`: BMMS-Test-FollowupFinal-Step47.sql, in a new query window (95 numbered checks, all must PASS), then BMMS-Test-ResetDatabase.sql (40), BMMS-Test-UnicodeText-Step31.sql (41), BMMS-Test-DashboardAlerts-Step43.sql (128), BMMS-Test-DashboardSummary-Step45.sql (66), BMMS-Test-UserDelete.sql (75) and BMMS-Test-UserHistory-Step39.sql (58).
4. BMMS-Check-InstalledSteps.sql again: step 47 Installed, 6 of 6; step 46 Installed, 2 of 2.
5. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-FollowupFinal-Step47.sql`, then `pwsh -NoProfile -File Tests\_runner\Setup-Quality.ps1`.
6. Deploy the build together with step 47 (see above: the build of UN6d cannot Submit with step 47, the build of FU1 cannot list without it).
7. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build. Steps 42 to 46 come first there (the steps are installed in order).
8. To undo: roll back the build, then BMMS-Rollback-FollowupFinal-Step47.sql (step 47 Partly, 1 of 6: the table stays; step 46 Installed).

Browser checks: tester: access-matrix, dashboard and followup. Owner by eye (Chrome and Edge at 100 percent, BMMS_Test, at 1366 and 1024 px): the Status column (the drop-down, the two lines, a long reopen reason wrapping inside the cell), the Reopen panel and its messages, the success and warning messages of Submit; "Confirmed (before history)" on the items BMMS_Test confirmed before step 47; two browsers as two Controllers (or two tabs): a row confirmed in one and submitted in the other ("[m] had already been confirmed."), an Action Text saved on an item confirmed meanwhile (Reason 26), a Reopen of an item reopened meanwhile (Reason 27); a reason of exactly 500 characters; "<b" in the reason; the MD Secretariat's view; the failure messages with EXECUTE denied on the new procedures (statements in the build report).

## Step FU2a: a confirmed followup is final on the Dashboard too; who confirmed or reopened it; "Reopened" in the Action Items card (database script step 48 and code; test script for BMMS_Test)

Owner decisions 2026-11-16 (requirement R16 to R21, plan approved with four answers): after a refusal the panel shows the saved text (the item is read again), and when that read fails it stays open read-only with the message and no status line; a read row made by opening a confirmed item gets StatusId 0, as a Confirm writes; the changed expected values of the Test scripts of steps 43 and 45 follow the step 48 marker; the name DashboardFollowupFinal. Reports (Report/Followup.aspx, Report/FollowupActionTaken.aspx, ReportsMgr.GetFollowupReport) are FU2b and not touched.

What was found first:

- The Action Items card and the panel read fn_DashboardActionItems, which leaves out confirmed items: a confirmed item reached from a stale row or a panel opened before the confirm was "This item no longer exists." (Open, Reason 4), and its Submit was refused with Reason 4 ("You cannot change this action item ..."), the panel closing.
- The Test scripts of steps 43 and 45 read the result sets of spr_GetDashboardActionItems and spr_OpenDashboardActionItem with INSERT ... EXEC into tables of 28 columns: they stop with an error, not a failed check, when the columns change, so their table #AI gets the seven columns when step 48 is installed. Test 45 also compares fn_DashboardActionItems with the step 43 text (SHA-1).
- The Dashboard has no count of action items (the summary cards count agenda items; the header counts alerts): "every count agrees" (R20) means fn_DashboardActionItems gives the same rows as before.

What changed:

- Database step 48 (BMMS-Fix-DashboardFollowupFinal-Step48.sql, marker DashboardFollowupFinal-Step48, 5 markers in BMMS-Check-InstalledSteps.sql). New fn_DashboardActionItemScope(@UserId, @Today): the scope rule of step 43 (Controller and Management every item; a Manager and a User the items of their departments with finalised or confirmed minutes; every other role none) without the filter on confirmed items, with the seven status columns of the latest history row (OUTER APPLY TOP 1 by StatusHistoryId): IsReopened (1: that row is a Reopen and the item is not confirmed), StatusAction, StatusReason, StatusOn, StatusByName, StatusByLogin, StatusByActive. fn_DashboardActionItems is now that function without the confirmed items: the same rows (R20), 35 columns. spr_GetDashboardActionItems returns the seven columns (parameters, order and Reasons unchanged). spr_OpenDashboardActionItem allows every item of the person's scope: a confirmed one is returned with IsConfirmed 1 and marked read (R21); a read row it creates gets StatusId 1, or 0 for a confirmed item. spr_SaveDashboardActionText: the role checks of before first (Reason 8; Reason 4 for Management, MD Secretariat, Admin), then in one transaction (its own only when the caller has none) the item read under UPDLOCK, HOLDLOCK together with the scope rule: outside the scope or unknown, Reason 4; confirmed, Reason 26; else the action text is written (R16). XACT_ABORT ON.
- The script stops unless steps 43, 45 and 47 are installed, and when one of the four replaced texts is neither the text it was built from (SHA-1) nor the step 48 text. BMMS-Rollback-DashboardFollowupFinal-Step48.sql puts the step 43 and 45 texts back letter for letter (SHA-1 checked) and drops the new function. The Rollbacks of steps 43 and 45 now refuse while step 48 is installed. The step 48 texts carry no marker of steps 46 and 47, and only spr_GetDashboardActionItems keeps the marker of step 45: the Test scripts of those steps count the objects with their markers.
- Shared class BMMS/FollowupStatusText.cs (in BMMS.csproj): the texts "Confirmed by [Name (login)] on [dd-MMM-yyyy HH:mm]", "Reopened by [Name (login)] on [dd-MMM-yyyy HH:mm]: [reason]", "Confirmed (before history)", "Confirmed", " (inactive)", "an unknown user", "an unknown date". Master/Followup.aspx.cs uses it; its output is character for character that of step 47 (864 combinations of status, action, person, date and reason compared, before and after).
- Dashboard, Action Item Details panel: the status line under the action text, full width of the value column, in the caption style of step UN4 (bmms-comment-by), plain text (InnerText), a 500-character reason wrapping (R17). A confirmed item opens read-only for every role: the editor read-only, no Submit, no Cancel, Close, and the line "This followup is confirmed and can no longer be changed." (for Management in place of the read-only line) (R18). A Submit refused with Reason 26: the item is read again, the panel stays open read-only with the saved text, the status line and "This followup is confirmed and can no longer be changed. Nothing was saved."; the list is read again (R16). Management's panel never has Submit, so it cannot reach that message; its save is refused by the role check (Reason 4) in any case.
- Dashboard, Action Items card, Due date column: "Reopened" in an orange chip (wb-chip-orange, #8A5300 on #FDF3E1, 5.75:1) for a Pending item whose latest history row is a Reopen, after "Overdue" when both apply (R19). No "Confirmed" chip (the card lists no confirmed item). The page reads the seven columns only when they are there.

Test script BMMS-Test-DashboardFollowupFinal-Step48.sql (BMMS_Test only; 43 numbered checks; one transaction, rolled back, made-up data ZZ48): markers, parameters, the 35 columns of the four objects, no feature above level 100, no marker of steps 46 and 47, the Rollback guards; the card per role (Controller, Management, Manager, User: no confirmed item, the reopened item with IsReopened 1 and its status columns; MD Secretariat, Admin, the system account, an inactive and no user refused); fn_DashboardActionItems against the step 43 text installed under another name, every user of the database, 28 columns both ways; Open of a confirmed item per role (returned, marked read, StatusId 0), outside the scope, the other roles; Save: Reason 26 in the scope, Reason 4 first for Management and the roles without the card, outside the scope and unknown, Reason 8; a Pending, a reopened and an item whose latest row is a Confirm still save; the caller's transaction left open; afterwards Action_Item, ActionItem_User_Map, Action_Item_Status_History and every identity counter unchanged.

Changed expected values of older Test scripts (approved by the owner 2026-11-16), each by the step 48 marker:

| Script | Check | Without step 48 | With step 48 |
|---|---|---|---|
| BMMS-Test-DashboardAlerts-Step43.sql | table #AI | 28 columns | 35 columns (seven added) |
| BMMS-Test-DashboardAlerts-Step43.sql | spr_GetDashboardActionItems, spr_OpenDashboardActionItem, fn_DashboardActionItems columns | 28 | 35 |
| BMMS-Test-DashboardAlerts-Step43.sql | The Controller opens the confirmed item 6 | Result 0, Reason 4, returned 0 (read 0), own rows 0 (read 0) | Result 1, Reason 0, returned 1 (read 1), own rows 1 (read 1) |
| BMMS-Test-DashboardAlerts-Step43.sql | Save by the Controller, the confirmed item | Result 0, Reason 4 | Result 0, Reason 26 |
| BMMS-Test-DashboardSummary-Step45.sql | table #AI (#AIO unchanged) | 28 columns | 35 columns |
| BMMS-Test-DashboardSummary-Step45.sql | spr_GetDashboardActionItems columns | 28 | 35 |
| BMMS-Test-DashboardSummary-Step45.sql | fn_DashboardActionItems SHA-1 | the step 43 text | the step 48 text |

Not changed: BMMS-Test-FollowupFinal-Step47.sql (it reads the markers of steps 43 and 45, kept, and the rows of fn_DashboardActionItems, the same) and BMMS-Test-AgendaWaitingFor-Step44.sql. Results on BMMS_Test with step 48: Test 48 43 of 43, Test 43 128 of 128, Test 44 120 of 120, Test 45 66 of 66, Test 47 95 of 95 (Test 46 stands down while step 47 is installed, as before). Checked on BMMS_Test: Fix, Fix again, the Rollbacks of steps 43 and 45 (refused), Rollback 48 (texts SHA-1 checked), Rollback 48 again (refused), Fix.

Tester:

- The fixture is unchanged. The dashboard pack gets check 18 (`followupFinal`, last of the pack): QA Test Committee, meeting 00005, agenda 001 confirmed by qa_ctrl on the Followup page; the card lists it for nobody; a stale row of qa_user opens it read-only with the line and who confirmed it; Submit in a stale panel of qa_manager gets the Reason 26 message, nothing saved, the panel stays open; qa_ctrl reopens it; "Overdue" and "Reopened" in the row, who reopened it in the panel. The item is left Pending. The followup pack, run after it, sees the "Reopened by" line under that row; its expected values are unchanged (owner's condition: same check count, all pass).
- The access-matrix pack: unchanged. Baseline: Update-Baseline.ps1 with step 48.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (steps 43, 45 and 47 Installed, step 48 Missing).
2. `BMMS_Test`: BMMS-Fix-DashboardFollowupFinal-Step48.sql ("Step 48 installed: ...").
3. `BMMS_Test`: BMMS-Test-DashboardFollowupFinal-Step48.sql in a new query window (43 numbered checks, all must PASS), then BMMS-Test-DashboardAlerts-Step43.sql (128), BMMS-Test-AgendaWaitingFor-Step44.sql (120), BMMS-Test-DashboardSummary-Step45.sql (66) and BMMS-Test-FollowupFinal-Step47.sql (95).
4. BMMS-Check-InstalledSteps.sql again: step 48 Installed, 5 of 5; steps 43 and 45 Installed.
5. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-DashboardFollowupFinal-Step48.sql`.
6. Deploy the build together with step 48.
7. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build. Steps 42 to 47 come first there.
8. To undo: roll back the build, then BMMS-Rollback-DashboardFollowupFinal-Step48.sql (step 48 Missing; steps 43 and 45 Installed).

Browser checks: tester: access-matrix, dashboard and followup. Owner by eye (Chrome and Edge at 100 percent, BMMS_Test, at 1366 and 1024 px): the Due date cell with "Overdue" and "Reopened"; the panel's status line with a long reason, "Confirmed by ...", "Confirmed (before history)" and an "(inactive)" name; Management's read-only panel of a confirmed item; two browsers for R16 (a Manager's panel open, the Controller confirms, the Manager's Submit); the Followup page's Status cell as in step 47.

## Step FU2b: the Followup reports show who confirmed or reopened each followup; the reports read procedures with the acting user; one list of blank characters for a reopen reason (database script step 49 and code; test script for BMMS_Test)

Owner decisions 2026-11-17 (requirement R22 to R27 and RA-1 to RA-3, plan approved with seven answers and seven additions): the texts of BMMS/FollowupStatusText.cs as they are (Q1); tie-break AgendaNo, ActionItemId in both report procedures and AgendaNo before ActionItemId in spr_GetFollowupList (Q2, RA-1); Followup by Department for the Controller only (Q3); a Status column in the View grids, the word and the line, the word only for the Summary (Q4); a new tester pack followup-reports (Q5); Reason 8 for the system account (Q6); one union list of blank characters with a build check that compares the C# and the SQL lists (Q7, RA-3). Additions: the subject range of Followup by Department as integer parameters of the procedure; the Minutes status column by the role read from the database; Reason 4 and 8 with ReportsMgr.ReportRefusedMessage on Followup by Department; no string-built SQL left for these reports; the count of Action_Item rows whose IsConfirmed is NULL (0 of 5 on BMMS_Test, 0 of 5 on BMMS_Quality, 2026-11-17; both filters leave such rows out, as before); step 47 still Installed 6 of 6 with the step 49 texts; a Word overflow of a 500-character reason without spaces to be reported before the layout is changed. Not touched: spr_SaveDashboardActionText (the FU2a analyser Low stays in Known items).

What was found first:

- Followup and Followup Summary: the Controller's rows came from SQL built in BMMSBAL/ReportsMgr.cs (GetFollowupReport, through ActionItemDB.GetFollowup, which ran any text it was given), Management's from spr_GetFollowupReportForManagement (step 41, the same filters and order, with the minutes status). Their ORDER BY (CommitteeId, MeetingId, DepartmentId, IsConfirmed) left rows equal in those four to the server.
- Followup by Department: spr_GetActionItemByMeetingIdDeptId (in no numbered script; no acting user; it does not use @CommitteeId, so the page filtered the committee with a RowFilter, and the subject range with another; ORDER BY SubjectNo only).
- Print, Export to Pdf and Export to Word are built from one report text in Session["ViewReport"] (ViewReport.aspx).
- The blank reopen reason: the page and BMMSBAL trimmed with .NET String.Trim() (U+0009 to U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000 to U+200A, U+2028, U+2029, U+202F, U+205F, U+3000; not U+200B, U+FEFF), spr_ReopenFollowup took out U+0009, U+000A, U+000D, U+00A0, U+200B and spaces: a reason of zero-width spaces only passed the page and was refused by the procedure with Reason 4 ("You cannot change the followups ..."), one of U+3000 only was stopped by the page.
- "Not Confirmed" was the word of the Confirmed Status choice of Report/Followup.aspx only.

What changed:

- Database step 49 (BMMS-Fix-FollowupReports-Step49.sql, marker FollowupReports-Step49, 5 markers in BMMS-Check-InstalledSteps.sql): fn_FollowupStatusLatest; spr_GetFollowupReport; spr_GetFollowupByDepartmentReport; spr_GetFollowupList and spr_ReopenFollowup replaced (see the install list). The script stops unless steps 41, 47 and 48 are installed and when one of the two replaced procedures is neither the step 47 text (SHA-1) nor the step 49 text. BMMS-Rollback-FollowupReports-Step49.sql first checks that the two procedures are the step 49 (or step 47) texts, then puts the step 47 texts back letter for letter (SHA-1 checked) and drops the three new objects. The Rollback of step 47 refuses while step 49 is installed.
- BMMSBAL/ReportsMgr.cs GetFollowupReport: one call of spr_GetFollowupReport with the acting user, for both roles; GetFollowupReportForManagement removed. BMMSDAL/ActionItemDB.cs: GetFollowup(string) (the string-SQL path), GetFollowupReportForManagement and GetActionItemByMeetingIdDeptId removed; GetFollowupReport and GetFollowupByDepartmentReport added (stored procedures, parameters only). BMMSBAL/ActionItemMgr.cs: GetFollowupByDepartmentReport; ReopenBlankCharacters (the one list, written as code points) and IsBlankReopenReason, used by the Reopen Save of Master/Followup.aspx.cs and by ReopenFollowup.
- BMMS/FollowupStatusText.cs: PendingWord, Word (the word; "Pending" or "Confirmed" only for the Summary) and Line (the Confirm or Reopen line) beside the existing texts; Master/Followup.aspx.cs keeps its own calls, its Status cell is unchanged.
- Report/Followup.aspx(.cs), Followup and Followup Summary: "Not Confirmed" is "Pending"; the View grid has a "Followup status" column (the word and the line; the word only for the Summary), encoded (headed as the printed Summary's column after the UX review, owner 2026-11-17); the Followup report has a FOLLOWUP STATUS block after ACTION TAKEN (the word in bold, the line under it, wrapping); the Summary a "Followup status" column (Pending or Confirmed); the minutes status (column, lines, Summary column) follows the role read from the database (PageAccessModule.HasRole), not whether the column is in the rows; a refusal (Reason 8 or 4) shows ReportsMgr.ReportRefusedMessage for both roles. The From and To dates are still not used (Known items).
- Report/FollowupActionTaken.aspx(.cs), Followup by Department: the rows from spr_GetFollowupByDepartmentReport with the acting user; the committee and the subject range (both values parsed as whole numbers by int.TryParse) go to the procedure, the two RowFilters are gone (the one left filters the rows of a meeting by its integer MeetingId); a "Followup status" column in the View grid; the word and the line under the subject in the report's Subject cell (the column widths unchanged); Reason 8 or 4 shows ReportsMgr.ReportRefusedMessage (grid, subject lists, Generate Report, the check of Submit).
- Master/Followup.aspx: when the browser check of the reason fires ("<" or "&#"), the server's line of an earlier Save ("Enter the reason for reopening.") is cleared, so the panel shows one message (RA-2).

Test script BMMS-Test-FollowupReports-Step49.sql (BMMS_Test only; 33 numbered checks; one transaction, rolled back, made-up data ZZ49): markers, parameters, columns, level 100, no marker of steps 46 to 48 in the new objects, the Rollback 47 guard; who may call both procedures (every role, the system account, inactive, none); the status columns of Pending, Confirmed, before history, Reopened, re-confirmed, confirmed with a Reopen as latest row, an inactive and a nameless actor; the tie-break in the two reports and the Followup list; parity: the Controller against a copy of the query built before (24 filter combinations, 0 differ), Management against spr_GetFollowupReportForManagement with the minutes status (24, 0; its order kept its four keys), Followup by Department against spr_GetActionItemByMeetingIdDeptId with the committee and subject range the page applied (12, 0); the 27 blank characters each alone and all together refused, U+200C alone and a reason with a zero-width space inside saved, stored trimmed as before; afterwards the three tables and every identity counter unchanged.

Changed expected value of an older Test script (approved by the owner 2026-11-17), by the step 49 marker:

| Script | Check | Without step 49 | With step 49 |
|---|---|---|---|
| BMMS-Test-FollowupFinal-Step47.sql | Parity with the old query (#ZZ47Old order) | ROW_NUMBER over ..., IsConfirmed, ActionItemId | ..., IsConfirmed, AgendaNo, ActionItemId (the expected "24, 0" unchanged) |

Results on BMMS_Test with step 49: Test 49 33 of 33, Test 41 44 of 44, Test 43 128 of 128, Test 44 120 of 120, Test 45 66 of 66, Test 47 95 of 95, Test 48 43 of 43. Checked on BMMS_Test: Fix, Fix again, the Rollback of step 47 (refused), Rollback 49 (texts SHA-1 checked), Rollback 49 again (refused), Fix; BMMS-Check-InstalledSteps.sql: step 47 Installed, 6 of 6; step 49 Installed, 5 of 5.

Build checks of the step: the list of BMMSBAL (27 code points) against the lists of the Fix and Test scripts (the same), and IsBlankReopenReason for every character of the Basic Multilingual Plane against the list (0 differ).

Tester:

- The fixture is unchanged. New pack followup-reports (Tests\packs\followup-reports): qa_ctrl confirms QA Test Committee meeting 00005 agenda 002 and meeting 00006 agenda 001 and reopens the second; the Followup and Followup Summary reports of qa_ctrl and qa_mgmt and Followup by Department of qa_ctrl, View and Generate (the report read in ViewReport.aspx). The followup pack is unchanged (the RA-2 line is not one of its checks; RA-1 orders only rows that tie). The access-matrix and dashboard packs are unchanged. Baseline: Update-Baseline.ps1 with step 49.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (steps 41, 47 and 48 Installed, step 49 Missing).
2. `BMMS_Test`: BMMS-Fix-FollowupReports-Step49.sql ("Step 49 installed: ...").
3. `BMMS_Test`: BMMS-Test-FollowupReports-Step49.sql in a new query window (33 numbered checks, all must PASS), then BMMS-Test-ReportAccess-Step41.sql (44), BMMS-Test-DashboardAlerts-Step43.sql (128), BMMS-Test-AgendaWaitingFor-Step44.sql (120), BMMS-Test-DashboardSummary-Step45.sql (66), BMMS-Test-FollowupFinal-Step47.sql (95) and BMMS-Test-DashboardFollowupFinal-Step48.sql (43).
4. BMMS-Check-InstalledSteps.sql again: step 49 Installed, 5 of 5; step 47 Installed, 6 of 6.
5. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-FollowupReports-Step49.sql`.
6. Deploy the build together with step 49.
7. `BMMS`, after the backup: steps 1, 2 and 4 (no test script on `BMMS`), then deploy the build. Steps 42 to 48 come first there.
8. To undo: roll back the build, then BMMS-Rollback-FollowupReports-Step49.sql (step 49 Missing; step 47 Installed).

Browser checks: tester: access-matrix, dashboard, followup and followup-reports. Owner by eye (Chrome and Edge at 100 percent, BMMS_Test, at 1366 and 1024 px): each report's View, Print, Export to Pdf and Export to Word as the Controller and as Management; a 500-character reason with and without spaces (Word: an overflow is reported before the layout changes); the "Followup status" column at 1024 px; RA-2 ("<b" after a blank Save shows one message); RA-3 (a reason of only U+3000 or only U+200B gives "Enter the reason for reopening.").

## Step UN6e: indexes for the Dashboard lists; the Action Items list out of ViewState; a version stamp on the stylesheet links; the tester names its results folder (database script step 50 and code; test script for BMMS_Test)

Owner decisions 2026-11-18 (requirement R28 to R31, plan approved with six answers and five changes): stage A of the ViewState rule always, stage B only where the measured size is over the limit and only after the owner has seen the numbers (answer 1); a new tester pack page-assets (2); the two-instance text of Tests\README.md as given (3); known test passwords on three accounts of the throwaway copy only (4); IX_Action_Item_MinutesId measured with the same rule (5); stage B on Followup accepted, a row confirmed meanwhile then shows its new status line (6). Changes: MeetingNo of the filled copy digits only (step 49 compares MeetingNo with integers); the measuring site against the copy with the repository's connectionStrings.config unchanged (hash before and after); the cause of WF3a3 shown from the tester runs; one table of reads per candidate and the kept list before the Fix script; a failure of Tests 42 to 49 on the filled copy said with its cause.

What was found first:

- Only clustered primary keys on Alert_User_Map, Alert_Master, ActionItem_User_Map, Agenda, Minutes, Meeting, Users and Action_Item. Action_Item_Status_History already has IX_Action_Item_Status_History_ActionItemId (ActionItemId, StatusHistoryId) of step 47, which serves the latest-row reads of fn_FollowupStatusLatest, fn_DashboardActionItemScope and spr_GetFollowupList; User_Department has IX_User_Department_UserId (UserId, EffectiveFrom) of step 39, which serves fn_UserDepartmentScope. Neither got a new index. The manager column of Users is ManagerId.
- The Dashboard kept the whole Action Items list in ViewState (ViewState["dtActionItem"], every row with Directions, Action Text and the reopen reasons), so its paging could bind from it. The Alerts and My approvals lists already read only the page shown. The Followup page keeps every row of its grid (no paging).

How the indexes were measured: a copy of BMMS_Test on .\SQLEXPRESS (BMMS_Volume, COPY_ONLY backup, dropped afterwards) filled to about one year of use: 317 meetings (300 new, MeetingNo 09001 to 09300), 1,570 agenda items, 1,380 minutes, 455 action items, 1,371 ActionItem_User_Map rows, 229 status history rows (reopen reasons of 465 characters), 1,914 alerts and 10,634 Alert_User_Map rows. SET STATISTICS IO on spr_GetDashboardAlerts, spr_GetDashboardActionItems, spr_GetDashboardMeetings, spr_GetDashboardApprovals, spr_GetDashboardSummary and spr_GetFollowupList as a Controller, a Manager and a User (and spr_GetMeetingByFromToDate and the UserId predicate of the action item writing procedures), after a warm-up, one candidate at a time. Rule: kept when it at least halves the reads of its table in a path the Dashboard or the Followup page calls.

| Candidate | Serves | Reads of its table, before and after (worst role) | Kept |
|---|---|---|---|
| IX_Alert_User_Map_UserId_StatusId (UserId, StatusId) INCLUDE (ReadStatus, AlertId) | fn_DashboardAlerts (step 43); fn_AgendaWaitingFor (step 44) | Alerts 102 to 30 (every role); My approvals and Meetings, Manager, 553 to 73 | yes |
| IX_Alert_Master_SourceType_SourceTypeId (SourceType, SourceTypeId) | spr_GetDashboardApprovals; fn_AgendaWaitingFor (step 44) | My approvals, Manager, 414 to 42; Meetings, Manager, 352 to 32 | yes |
| IX_Agenda_MeetingId (MeetingId) INCLUDE (DepartmentId, AgendaStatusCode) | spr_GetDashboardMeetings, spr_GetDashboardSummary (steps 42, 45) | Meetings, Manager, 6,229 to 315, User 6,136 to 222; Summary 93 to 7 | yes |
| IX_Agenda_AgendaStatusCode INCLUDE (MeetingId, DepartmentId) | fn_AgendaWaitingFor, fn_AgendaStatusGroup | alone 6,229 to 576; with the three kept: no change | no |
| IX_ActionItem_User_Map_UserId (UserId) | spr_UpdateActionItemByUserId, spr_DeleteUserByUserId (not a Dashboard path) | 7 to 2 (7 pages) | no |
| IX_ActionItem_User_Map_ActionItemId_UserId INCLUDE (ReadStatus) | fn_DashboardActionItemScope | Controller 7 to 681 (worse) | no |
| IX_Minutes_AgendaId (AgendaId) | View_Action_Item (Followup list) | 26 to 749 (worse) | no |
| IX_Meeting_MeetingDate (MeetingDate) | spr_GetDashboardMeetings (fn_MeetingDashboardState reads every meeting) | 242 to 237 | no |
| IX_Users_ManagerId (ManagerId) | fn_AgendaRoute, fn_AgendaWaitingFor | no change | no |
| IX_Action_Item_MinutesId (MinutesId) | fn_DashboardActionItemScope, View_Action_Item | 67 to 3,897 (worse) | no |

With the three kept, total reads: Meetings Manager 7,577 to 863, User 6,536 to 622; My approvals Manager 1,171 to 319; Alerts 381 to 309; Summary 177 to 91; the other calls unchanged.

What changed:

- Database step 50 (BMMS-Fix-Indexes-Step50.sql; one marker per index in BMMS-Check-InstalledSteps.sql: the name, the table and the key and included columns in order, present only when the index has exactly that definition): the three indexes above. The script first checks every index of the step and stops, creating nothing, when an index of the same name on that table has another definition (it is never dropped by the script) or another index there has the same first key column; the creates run only when those checks ran to their end (a second gate, a temporary table, for an error that stops the check batch in SSMS; a gate table left in the window by a cancelled run is dropped first, so only the checks of this run open it; UX review Low, fixed on the owner's word 2026-11-18). BMMS-Rollback-Indexes-Step50.sql drops the three, and only when each has the step 50 definition (it refuses otherwise, dropping nothing). Re-run rule: step 50 has no procedure text; re-running an earlier step's Fix script leaves it Installed.
- BMMS/DashBoard/DashBoard.aspx.cs (stage A of R29): the Action Items list is no longer kept in ViewState. Paging reads it again through spr_GetDashboardActionItems with the acting user and the Committee and Department filters (as the Show All, Read and Unread links and every save already did); a page that no longer exists after the list changed shows the last page there is, as before. ViewState keeps the mode, the page number, the filters and the panel flags. No message between pages. Rows, order, paging, bold unread, the due date and status lines are as before.
- BMMS/AssetVersion.cs (new, R30) with BMMS/MasterPage/Main.Master.cs, MainNoMenu.Master.cs and Default.aspx.cs: every local stylesheet link of the header and of the page content gets ?v= and the first 8 hex characters of the SHA-256 of the file, computed once per file and kept for the life of the application (a deployment restarts it). A missing or unreadable file keeps its link without ?v=, with no error and no log line. The page links of Master/Agenda.aspx and Master/MinutesUpdate.aspx (bmms-forms.css) and Master/Committee.aspx and Master/Meeting.aspx (ColorPicker/js_color_picker_v2.css) became runat="server" for it. Pages with their own links: Default.aspx and these four; the two master pages carry the rest. The local .js links (BrowserSecurity.js on both master pages, Default.aspx and Report/ViewReport.aspx; ColorPicker/color_functions.js and js_color_picker_v2.js on Committee and Meeting) are not stamped (option only).
- Tests/_runner/Run-Tests.ps1 (WF3a3): "Results folder: Tests\_results\<run>" at the start and at the end, and Tests\_results\latest.txt (the run folder name only) at the start.

ViewState measured (characters of the __VIEWSTATE field; the measuring site was a copy of the build in the scratch folder, on localhost, against the two throwaway copies; per-control sizes from the ASP.NET trace of that copy only):

| Page, role | Copy of BMMS_Test, before | after stage A | Filled copy, before | after stage A |
|---|---|---|---|---|
| Dashboard, Controller | 23,316 (the page's own state, the list: 15,632) | 7,788 | 899,196 (the list: 877,388) | 21,908 |
| Dashboard, Manager | 14,096 | 8,160 | 61,496 | 22,992 |
| Dashboard, User | 13,560 | 7,624 | 59,680 | 21,176 |
| Followup, Controller, committee C05 viewed | 4,844 | 4,844 | 85,016 | 85,016 |

On the filled copy the Dashboard after stage A is over the proposed limit (20 KB, 20,480): what is left is the grids' own row state (the Meetings card's two lists, the Alerts and Action Items pages, My approvals). Stage B (display-only controls of the rows without ViewState, every list read again before the page is drawn) is not built; it waits for the owner's decision on these numbers. Followup is not changed in this step.

Test script BMMS-Test-Indexes-Step50.sql (BMMS_Test only; read only; 9 numbered checks): each index with exactly its definition; no other index on its table with the same first key column; the clustered primary keys of the three tables unchanged.

Results on the filled copy (BMMS_Volume) with step 50: Test 50 9 of 9; Test 42 71 of 71; Test 43 128 of 128; Test 45 66 of 66; Test 47 95 of 95; Test 48 43 of 43; Test 49 33 of 33; Test 46 runs no check once step 47 is installed (its own note); Test 44 119 of 120: check 15 (itmgruser: the items at AC of his departments not routed to him appear in none of his function rows) sees 55 rows, with and without step 50: the fill data, which maps alerts of copied agenda items to every user, not the indexes. Checked on the filled copy: Check (50 Missing), Fix, Fix again (each "already present"), Test, Check (Installed, 3 of 3), Rollback (three dropped), Rollback again (skipped), an index of the same name with another definition (Fix and Rollback refuse, nothing changed, also run as SSMS does, without stopping at the first error), a second index with the same first key column (Fix refuses), Fix.

Tester:

- New pack page-assets (Tests\packs\page-assets): ten pages (sign-in; Dashboard of qa_ctrl, qa_manager, qa_user; Followup, Agenda, Update Minutes, Committee, Meeting and ChangePasswordFirst of qa_ctrl), each with its local stylesheet links in order, each with the stamp of its file in Tests\_site; the Controller's Dashboard at most 12,900 characters of ViewState (owner decision 2026-11-18: the fixture value 10,312 plus about 25 percent; the code before UN6e gives 24,288 for the same page, measured on a scratch build against a copy of the tester's baseline; the first limit, 9,800 from a copy of BMMS_Test, failed in the first tester run). The other packs are unchanged. Baseline: Update-Baseline.ps1 with step 50.
- WF3a3, the cause, from the tester runs of FU1 (2026-11-16 13:30), FU2a (2026-11-16 18:10) and FU2b (2026-11-17 13:35): each call of the runner had the 600 s timeout, and each still moved to the background after about three minutes; the runner's last lines (the result word and the folder) went to the task output file under the user's temporary folder, which the guard does not let the agent read (by design), and Read of the folder Tests\_results (a listing) is refused too, so the agent could not learn the folder name and guessed it (2026-11-16_13-30-23 for 2026-11-16_133023). The short FU2b run of followup-reports alone (44 s) stayed in the foreground and the agent read results.md itself. The first lines of the runner do reach the agent in every case, and latest.txt is a file under Tests\_results that the guard allows: either names the folder. The guard and the agent instructions are unchanged.

What to run where (the Consultant runs the scripts on BMMS):

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 49 Installed, step 50 Missing).
2. `BMMS_Test`: BMMS-Fix-Indexes-Step50.sql ("Created ..." three times), then again ("already present" three times).
3. `BMMS_Test`: BMMS-Test-Indexes-Step50.sql (9 numbered checks, all PASS), then the Test scripts of steps 42, 43, 44, 45, 47, 48 and 49 (71, 128, 120, 66, 95, 43, 33).
4. BMMS-Check-InstalledSteps.sql again: step 50 Installed, 3 of 3.
5. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-Indexes-Step50.sql`.
6. Deploy the build (it does not need step 50; either order).
7. `BMMS`, after the backup: step 50, then deploy the build. Steps 42 to 49 come first there.
8. To undo: BMMS-Rollback-Indexes-Step50.sql (step 50 Missing); the build can be rolled back on its own.

Browser checks: tester: access-matrix, dashboard, followup, followup-reports and page-assets. Owner by eye (Chrome and Edge at 100 percent, BMMS_Test): the Dashboard of the Controller, a Manager and a User: the lists, their paging, bold unread, the chips and status lines as before; the page source: each stylesheet link with ?v=; a stylesheet changed and the site restarted: its stamp changes and the change shows without clearing the cache.

## Step RA1d: the role, status and departments read from the database on every request; a change ends the session (database script step 51 and code; test script for BMMS_Test)

Owner decisions 2026-11-18 (requirement RA1d, plan approved with five answers): Q1 on a change the session ends and the user signs in again (no silent refresh); Q2 a change is any of role, active status and department set (the open User_Department rows of step 39); Q3 a new small read-only procedure, step 51. Answers: A the home department is part of the stamp, and Users.DepartmentId too (added to the stamp rather than proved equal to the IsHome row); B a database error during the check ends nothing (see below); C the session cookie is expired on every ended session; D a tester pack session-check; E Session_End's audit call in a try/catch.

Why: until this step only the nine Admin pages of RA1a (PageAccessModule.RequireRole) read the role from the database; the menu and every other page used Session["RoleCode"] until sign-out (owner test 2026-11-10: a Controller made a Manager while signed in still opened Update Minutes).

**Install step 51 BEFORE this build.** The build reads spr_GetUserAccessState on every signed-in request; without the procedure every signed-in request fails closed and shows the safe error page. The real BMMS database on the Work Laptop is at step 37: this build is not to be run against it.

What the session holds (Default.aspx, at sign-in, from spr_GetUserByLoginName / View_Users): UserId, UserName, LoginName, DesignName, RoleCode, RoleName, NoRecord, IsSystem; since this step also DepartmentSet. RoleCode and RoleName now come from spr_GetUserAccessState, the read the module compares with, made before the login is recorded (a database error there is "Database not connected", as before; a user that is missing or inactive at that moment gets the inactive text). The session never held departments, DepartmentId, ManagerId or RoleId.

Which requests are checked (PageAccessModule, PostAcquireRequestState: the first event after the session is loaded, before any page, master page or menu code): every .aspx request that PageAccess.xml does not open to visitors, with its postbacks and UpdatePanel postbacks: ChangePasswordFirst.aspx, DashBoard/DashBoard.aspx, the 24 pages of Master/ and the 15 of Report/ (Report/ViewReport.aspx with its pop-up, the PDF stream and the Word export among them). Not checked: Default.aspx, Logout.aspx and Error/ErrorPage.aspx (public in PageAccess.xml), WebResource.axd, ScriptResource.axd, *_AppService.axd, static files. The project has no .ashx or .asmx.

What the check does, once per request, in place of the status read of step 14 (spr_GetUserStatusByUserId, which ResetPassword.aspx still uses):

- No row (user missing) or AccountStatus not 1: SESSION-ENDED, reason "missing" or "inactive"; the sign-in page shows the text it already had, "Your account is inactive. Contact the administrator."
- RoleCode not the session's (trimmed, case ignored), or DepartmentSet not the session's (or none in the session): SESSION-ENDED, reason "role X to Y", "departments changed" or both; the sign-in page shows "Your access has changed. Please sign in again."
- Then: the line in App_Data/PageAccessLog.txt (action SESSION-ENDED; the user column "Name (login)"; the role; the page without its query string; "UserId [n]; [reason]"), Session.Abandon without Clear (so Global.Session_End still finds the UserId and closes the open login rows, as at sign-out; the inactive path of step 14 cleared the session first, so its audit call never ran), the redirect, and the session cookie (the cookieName of sessionState, ASP.NET_SessionId) expired so the sign-in page starts a new session id. Authentication is Windows: there is no forms cookie. An UpdatePanel postback gets the redirect in the ASP.NET AJAX pageRedirect form (no script error); the report pop-up and the exports get the redirect before any byte of the page or file.
- The message reaches the sign-in page as ?status=inactive or ?status=changed; Default.aspx compares the value with these two fixed codes and shows fixed text; any other value shows nothing and is never written to the page.
- Database error during the check (owner answer B): the session is kept; the page does not run; Global's safe error page (HTTP 500; for an UpdatePanel postback the AsyncPostBackErrorMessage text, shown by AsyncPostBackError.js) with the error log line and one PageAccessLog line SESSION-CHECK-ERROR ("UserId [n]; database error; the session is kept"). The next click checks again. Before this step a database error let the request through.
- Every logged value is cleaned of control characters (tab, line breaks), so a line always has six columns; a value without one is written as before.
- The protected system account follows the same rule (IsSystem is read but not compared: only the step 18 script changes it).

Unchanged: who can open which page (PageAccess.xml, MenuUserControl.ascx, the nine RequireRole checks and their log lines). RequireRole, HasRole and RefuseRequest reuse the module's read of the same request (the same view, View_Users, and columns), so the nine Admin pages make no second call; one database call per checked request, as before. One visible difference: an Admin made a User while signed in now gets SESSION-ENDED and the sign-in page before a page's RequireRole runs, where before the page logged DENIED-PAGE.

Writers of Users.DepartmentId (answer A): Users.DepartmentId is part of the stamp itself, so a writer that changes it without the IsHome row (a script by hand) is covered too; no proof of equality is relied on.

What changed:

- Database step 51 (BMMS-Fix-SessionCheck-Step51.sql; marker SessionCheck-Step51; one row in BMMS-Check-InstalledSteps.sql): spr_GetUserAccessState as above. Guards: the name like BMMS%, steps 18 (View_Users.IsSystem), 39 (User_Department.IsHome, marker UserHistory-Step39) and 40 (marker RoleAccess-Step40). No table change; nothing granted (the application login holds EXECUTE on the schema dbo). Re-run rule: safe to re-run; no earlier script contains the procedure, so a re-run of an earlier step leaves step 51 Installed; a re-run of step 18 creates View_Users again with the same columns. BMMS-Rollback-SessionCheck-Step51.sql drops the procedure only and refuses when it is not installed; roll back the build first.
- BMMSDAL/UserDB.cs, BMMSBAL/UserMgr.cs: GetUserAccessState and the class UserAccessState.
- BMMS/PageAccessModule.cs: the check above in place of IsActiveUser; RequireRole and HasRole reuse the read; the cleaning of logged values.
- BMMS/Default.aspx.cs: the read at sign-in, Session["DepartmentSet"], the message "Your access has changed. Please sign in again."
- BMMS/Global.asax.cs: WriteSafeAnswer is internal (the module uses it); Session_End's audit call in a try/catch that writes the error log (answer E); Session_End reads the UserId with int.TryParse instead of Convert.ToInt16 (security review Low, owner's word 2026-11-19): a UserId that does not parse, or is not above 0, skips the audit call.

Test script BMMS-Test-SessionCheck-Step51.sql (BMMS_Test only; 18 numbered checks): the marker and the one parameter; the result columns (no Password, no EmailId); no feature above compatibility level 100; EXECUTE for every database user who can run spr_GetUserStatusByUserId; in one transaction rolled back, a made-up Manager written through the real spr_AddEditUser and spr_SetUserStatusByUserId: unchanged (the same text twice), a department added, a department removed, the home department moved in the same set, Users.DepartmentId changed alone, the role changed (Manager to User), deactivated, a missing UserId and UserId 0 (no row), the system account (IsSystem 1); afterwards Users, User_Role and User_Department as before, no ZZ51 row left.

Results on BMMS_Test (.\SQLEXPRESS): Test 51 18 of 18; Fix, Fix again, Rollback, Rollback again (refused, nothing to roll back), Fix; Check: step 51 Installed, 1 of 1. Older tests with step 51: Test 39 58 of 58; UserProtection-Stage1 142 of 142; UserStatus-Stage2a 50 of 50; UserStatus-Stage2b 63 of 63; Test 40 43 of 43; SystemAccount-Stage3 51 of 51. Its check 44 (Mail ACA) expected the ordinary Admin to be mailed ("0 1") and saw "0 0", the same with step 51 rolled back: step 43 (UN6c1, owner-tested 2026-11-13) leaves the Admin role out of functional mails by design. In this step (owner's word 2026-11-19, test only) the expected value became "0 0", with a comment naming step 43; BMMS-Test-SystemAccount-Stage3.sql is otherwise unchanged.

Tester: new pack session-check (Tests\packs\session-check): while qa_mdsec, qa_manager2 and qa_user2 are signed in, qa_admin changes qa_mdsec to Management, adds Credit to qa_manager2 (owner's word 2026-11-19: removing Secretarial is refused in the fixture by step 39 rule 12, Reason 24, as qa_manager2 is its last active Manager with an item waiting) and deactivates qa_user2 in User Master; each next click (for qa_manager2 a Dashboard filter, an UpdatePanel postback) lands on the sign-in page with its text, one SESSION-ENDED line each, and the browser then holds another ASP.NET_SessionId cookie (answer C, after a fresh sign-in; on the sign-in page for qa_user2); qa_ctrl, unchanged, is not interrupted; the three are put back in a finally block and a user left changed fails a check (as does one found changed at the start: the runner restores BMMS_Quality before every run, so only an earlier pack of the same run can leave one). Run it as the last pack. Baseline: Update-Baseline.ps1 with step 51.

What to run where:

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 50 Installed, step 51 Missing).
2. `BMMS_Test`: BMMS-Fix-SessionCheck-Step51.sql ("Step 51 installed"), BEFORE the build is deployed to the site that uses BMMS_Test.
3. `BMMS_Test`: BMMS-Test-SessionCheck-Step51.sql (18 checks, all PASS).
4. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-SessionCheck-Step51.sql`.
5. Deploy the build.
6. `BMMS`: only after steps 38 to 50 are installed there, after the backup: step 51, then the build. Not on the Work Laptop's BMMS (step 37).
7. To undo: roll back the build first, then BMMS-Rollback-SessionCheck-Step51.sql.

Browser checks: tester: access-matrix, page-assets and session-check (last). Owner by eye: see the step's report.

Owner's tests: passed on BMMS_Test on 2026-11-19 (the Check script, step 51 Installed 1 of 1; Test 51 18 of 18; SystemAccount-Stage3 51 of 51; the browser tests: role, department, inactive, an Admin made a User while on Department Master giving SESSION-ENDED and not DENIED-PAGE, the Dashboard filter redirect, two tabs, the report window and the Word export refused, the database offline with the safe error page, the session kept and three SESSION-CHECK-ERROR lines, back online without a new sign-in; the error log held only the lines of the offline test).

Test data on BMMS_Test (owner, 2026-11-19): ra1admin is an active user with the Admin role there (the account of the RA1a role-change test, step 40, kept). It is a second ordinary Admin of BMMS_Test, not of BMMS; a Test script that counts the active Admins of BMMS_Test sees it.

## Step MR1: a Manager stays needed while items routed to him wait, also on Deactivate; the meeting-date rule in the database (database script step 52 and code; test script for BMMS_Test)

Owner decisions 2026-11-19 (requirement MR1, plan approved with seven answers): (1) keep blocking a role change away from Manager, a department removal and (new) a Deactivate while such items exist, the message telling apart (a) the items still open for approval, (b) the items of meetings whose date has passed and whose agenda was never finalised and (c) the department part, unchanged; the personal part never suggests another department Manager; (2) the same date rule in the database: a Manager's approve and reject follow fn_AgendaWaitingFor (refused once the meeting date has passed, Reason 28); the Controller's reject of a past-meeting item stays possible; M6a is kept (no page change: the Controller closes such items with Agenda Finalization, which rejects every item not yet approved); (3) Reason 24 with the coded detail, Reason 28 for a Manager's decision after the meeting date; (4) Tests 20 and 35: the open meetings dated ahead; Tests 44 and 39: the expected values of step 52; (5) the THROW of spr_UpdateAgendaByAgendaId kept unchanged; (6) a guard in the step 39 Fix; (7) a session-check addition.

Why (read-only report of 2026-11-19): on BMMS_Test, mgruser's change to User was refused for "8 items waiting for their own approval" while his Dashboard showed none: the 8 are AC items of committee C06 meetings 00001 to 00003 (29 to 31 October 2026, agendas never finalised), routed to him; fn_AgendaWaitingFor (step 44) gives CanApprove 1 and DateOpen 0, so My approvals hides them, while rule 12 counted them by its own copy of the routing condition; the message also advised "give the department another active Manager", which cannot clear a personal refusal.

What changed:

- Database step 52 (BMMS-Fix-ManagerRelease-Step52.sql; marker ManagerRelease-Step52; 4 markers in BMMS-Check-InstalledSteps.sql):
  - fn_ManagerReleaseRefusal: the personal part reads fn_AgendaWaitingFor(@UserId, server date), items at AC that he may approve on a meeting whose agenda is still open: Kind 'P' when the meeting date has not passed (also a meeting without a date), Kind 'Q' when it has. Kind 'D' (the department part) and the parameters are unchanged.
  - spr_AddEditUser: the Reason 24 ReasonDetail is 'open:<P>|past:<Q>|<department part>', the department part as step 39 wrote it ('last active Manager of <names with counts>' or nothing).
  - spr_SetUserStatusByUserId: Deactivate of an active Manager runs rule 12 (both parts, as for a role change, under the same lock); refused with the same Reason 24 and ReasonDetail. UD1a had no check here (owner, 2026-11-19).
  - spr_UpdateAgendaByAgendaId: a Manager's approve or reject is refused with Reason 28 when fn_AgendaWaitingFor gives DateOpen 0 for the item; checked after Reason 14, so a Manager who is not routed still gets 14. Nothing is saved and no alert row is written; the page sends no mail on a refusal. The Controller branch is unchanged (a Controller may reject at AC and AMA after the meeting date: Agenda Finalization does so). The THROW of its CATCH block is kept as it was (owner answer 5).
  - The script was built from the four texts as installed (identical in BMMS_Test and BMMS_Quality; SHA-1 without carriage returns in pieces of 4,000 characters) and stops, changing nothing, when one is neither that text nor already the step 52 text. Guards: the name like BMMS%, steps 39, 44 and 51. Nothing granted.
  - Re-run rule: the Fix scripts of steps 39 and 44 now stop while step 52 is installed (guards added in this step) and name BMMS-Rollback-ManagerRelease-Step52.sql. Found while building: before the guard, a re-run of step 44 did NOT stop (its text check accepts any text with its own marker, which step 52 keeps): on BMMS_Test it put the step 44 texts of spr_UpdateAgendaByAgendaId, spr_GetDashboardMeetings and spr_GetDashboardApprovals back (steps 45 and 52 read Partly); BMMS_Test was put right by running the Fix scripts of steps 45, 48 and 52 again, and every module text of BMMS_Test was then compared with BMMS_Quality (213 modules; only the four of step 52 differ). A re-run of another step that holds one of the four (2, 3, 6, 10, 13, 14, 16, 17, 18, 20, 21, 29, 30, 31, 35, 42) still brings back an older text: step 52 reads Partly; run step 52 again.
  - BMMS-Rollback-ManagerRelease-Step52.sql puts the four texts of steps 39 and 44 back letter for letter (SHA-1 compared at its end); it refuses when step 52 is not installed. Roll back the build first.
- BMMSBAL/UserMgr.cs: the Reason 24 message is built from the parts, one line each (the message box shows them with line breaks; names HTML-encoded, no ids): "Not saved: this Manager is still needed."; (a) "[n] item(s) routed to them is/are still open for approval: approve or reject it/them first."; (b) "[n] item(s) routed to them belongs/belong to meetings whose date has passed and whose agenda was never finalized: the Controller should finalize the agenda of those meetings first (finalizing rejects the items not yet approved)."; (c) "Last active Manager of [department] ([n] item(s) of the department waiting): give the department another active Manager first." (owner 2026-11-19: the spelling finalize as in the menu and the Reason 28 text; the department's count said as such); "Nothing was changed.". A ReasonDetail in the step 39 form (a database without step 52) gets the step 39 message.
- BMMSBAL/MeetingMgr.cs: Reason 28 (DecisionAfterMeetingDate) with the Dashboard's own meeting-date text, "The meeting date has passed, so this item can no longer be approved or rejected. It will be rejected when the agenda is finalized." The Dashboard's step M6a check normally stops the request first.
- No page changed. Callers: User Master Save (role change, department removal) and the grid's Deactivate show the Reason 24 message in the message box; the Dashboard's Approve and Reject show Reason 28 in the Agenda Alert panel's alert (after the page's own M6a check); Agenda Finalization rejects as the Controller, unchanged.

Older tests (owner answer 4):

- BMMS-Test-AgendaRouting-Step20.sql: meetings 99920 and 99922 (agenda open; items decided by a Manager) dated 10 days ahead instead of 7 days back (variable @Future, comment naming step 52); 99921 (finalised) unchanged. No expected value changed. Without the move, against step 52: checks 35, 36, 37, 38, 41, 43 and 44 fail (Reason 28 instead of the decision, and the Controller checks that follow it). With it: 56 of 56.
- BMMS-Test-CommentAuthor-Step35.sql: meeting 99935 dated 10 days ahead (its agenda submission date stays in the past). No expected value changed. Without the move: checks 9, 10, 11, 12, 13 and 15 fail. With it: 28 of 28.
- BMMS-Test-UserHistory-Step39.sql, expected values (each with a comment naming step 52): check 24 'Result 0, Reason 24, last active Manager of ZZ step 39 department A (1 item waiting) | ...' to 'Result 0, Reason 24, open:0|past:0|last active Manager of ZZ step 39 department A (1 item waiting) | ...'; check 25 '... (1 item waiting); 1 item waiting for their own approval | ...' to '... open:1|past:0|last active Manager of ZZ step 39 department A (1 item waiting) | ...'; check 26 'Result 0, Reason 24, 1 item waiting for their own approval' to 'Result 0, Reason 24, open:1|past:0|'; check 29 'Result 0, Reason 24, last active Manager of ZZ step 39 department A (1 item waiting)' to 'Result 0, Reason 24, open:0|past:0|last active Manager of ZZ step 39 department A (1 item waiting)'. The Deactivate of M2 (old check 31) is now refused by rule 12 (he is the last Manager of A, where ZZ39-001 waits, routed to him): a NEW check 31 says so ('Result 0, Reason 24, open:1|past:0|last active Manager of ZZ step 39 department A (1 item waiting) | role manager; open ZZ39A*,ZZ39B; closed 1/0/0'); the item is then marked AMA for the Deactivate and Activate checks of step 39 (now 32 to 35, expected values unchanged) and put back at AC after them. Without that, the old checks 31 to 34 and 46 (Activate, NotRestored, HomeDepartmentInactive; the setting refused for an inactive Manager) would test nothing. 58 checks became 59; 59 of 59.
- BMMS-Test-AgendaWaitingFor-Step44.sql: check 56 (named case 27) 'AS BEFORE, the procedure does not look at the meeting date ...' expected 'Result 1, Reason 0', now 'SINCE STEP 52, ... is refused (Reason 28 ...)' expected 'Result 0, Reason 28'; check 29 'allowed 32; Reason 12: 104, Reason 14: 688, Reason 4: 72, Reason 5: 144, Reason 8: 312' to 'allowed 26; Reason 12: 104, Reason 14: 688, Reason 28: 6, Reason 4: 72, Reason 5: 144, Reason 8: 312'; check 28 '1352 cases, 0 differ' to '1352 cases, 6 differ (6 of them a manager's decision on pAC, now Reason 28), 0 other': the 6 intended differences (the three routed managers' approve and reject of the past item pAC) are counted apart and any other difference is still named (a change of the check's text, not only its expected value: the first difference it showed carries row ids). 120 of 120.
- Unchanged and passing with step 52: UserStatus-Stage2a 50 of 50 (no case deactivates a Manager with routed items: no case changed), UserStatus-Stage2b 63 of 63, SystemAccount-Stage3 51 of 51, UserProtection-Stage1 142 of 142, Step 23 53 of 53, Step 24 36 of 36, Step 51 18 of 18. Before step 52 each of the ten older tests passed in full on BMMS_Test (20: 56, 35: 28, 39: 58, 44: 120, the others as above).

Test script BMMS-Test-ManagerRelease-Step52.sql (BMMS_Test only; 28 numbered checks): the markers (the new one and those of steps 13, 35, 39 and 44), the parameter counts, no feature above compatibility level 100 added; in one transaction rolled back, made-up data ZZ52 (two departments, four meetings: to come, date passed, no date, agenda finalised; five Managers saved through spr_AddEditUser): the open and past counts (a finalised agenda and an item at AMA not counted), the department part alone, the mgruser-like Manager (past items only, other Managers in the department), the Reason 24 detail of a role change, a department removal and a Deactivate, the Deactivate of a User and of a Manager with nothing routed, a Manager's approve and reject after the meeting date (Reason 28, the item, its alert rows and audit rows unchanged), a Manager who is not routed (Reason 14 first), approve of an item to come and of one without a date, the Controller's reject after the meeting date at AC and at AMA; afterwards Users, User_Role, User_Department, Agenda and Alert_User_Map as before, no ZZ52 row left, every identity counter put back.

Results on BMMS_Test (.\SQLEXPRESS): Test 52 28 of 28; Fix, Rollback (SHA-1 compared: letter for letter), Rollback again (refused, nothing to roll back), Fix, Fix again; Check: step 52 Installed, 4 of 4, every other step Installed. The step 39 and 44 Fix scripts stop while step 52 is installed (checked).

Repair of BMMS_Test during the build (2026-11-19): a check that the step 44 Fix script stops while step 52 is installed ran it before its guard existed; it did not stop (its text check accepts any text that carries its own marker) and put back the step 44 texts of spr_UpdateAgendaByAgendaId, spr_GetDashboardMeetings and spr_GetDashboardApprovals, so steps 45 and 52 read Partly. Put right by running the Fix scripts of steps 45, 48 (the step 45 re-run replaces spr_GetDashboardActionItems, which step 48 had replaced) and 52 again, in that order; BMMS-Check-InstalledSteps.sql then read Installed for every step. Every module text of BMMS_Test (213 procedures, functions and views; SHA-1 of the text without carriage returns) was then compared with BMMS_Quality, which this build had not touched: only the four objects of step 52 differ. BMMS and BMMS_Quality were not affected.

Owner's tests: passed on BMMS_Test on 2026-11-19 (the Check script, step 52 Installed 4 of 4; Test 52 28 of 28; Step 39 59 of 59; Step 44 120 of 120; the browser steps: mgruser's role change and Deactivate refused with (b) 8 items; two parts (1 open, 8 past) and three parts (HRD 9 items of the department) with the data below; the message boxes fine in Chrome and Edge; My approvals and the meeting-date message; a Manager's approval of an item to come; the Controller's Agenda Finalization of 00004 and 00001 rejecting their items, mails sent; the refusal then counting 6; the error log clean).

Test data on BMMS_Test after the owner's test (2026-11-19): committee C06 (Test Committee for Board validation) has a new meeting 00004 with item C06-00004-001 (entered by depuser, approved by mgruser, rejected when the agenda was finalized); the agendas of meetings 00004 and 00001 are finalized (the two AC items of 00001 rejected); itmgruser has HRD again. mgruser's refusal now counts 6 past items (00002 and 00003).

Tester: pack session-check, new check 4b: qa_admin's change of qa_manager to User is refused with the lines "2 items routed to them are still open for approval ..." (QA1-00001-001, QA1-00002-001) and "1 item routed to them belongs to meetings whose date has passed ..." (QA2-00013-1), no department line (credmanager is another Manager of Credit); qa_manager stays a Manager (put back in the finally block only if the refusal did not hold). Baseline: Update-Baseline.ps1 with step 52.

What to run where:

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 51 Installed, step 52 Missing).
2. `BMMS_Test`: BMMS-Fix-ManagerRelease-Step52.sql ("Step 52 installed"), then the build.
3. `BMMS_Test`: BMMS-Test-ManagerRelease-Step52.sql (28 checks), then the Test scripts of steps 20, 35, 39 and 44 (56, 28, 59, 120).
4. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-ManagerRelease-Step52.sql`.
5. `BMMS`: only after steps 38 to 51 are installed there, after the backup: step 52, then the build. Not on the Work Laptop's BMMS (step 37).
6. To undo: roll back the build, then BMMS-Rollback-ManagerRelease-Step52.sql.

Browser checks: tester: access-matrix, dashboard and session-check (last). Owner by eye: see the step's report; the User Master message box with two and with three parts at laptop width.

## Step UD1b: any Manager of the item's department approves (database script step 53 and code; test script for BMMS_Test)

Owner decisions 2026-11-23 (requirement UD1b; the plan of 2026-11-23 and its 17 open questions answered as recommended).

- R1 Who may decide: an item at AC may be approved or rejected by every active Manager of its department (fn_DepartmentManagers: the current role in Users is Manager, active, not the system account, an open User_Department row for the department; a user without any history row counts as mapped to Users.DepartmentId, the rule of step 39), but not by its creator. The creator's Reporting Person and the alert rows no longer decide. fn_AgendaWaitingFor carries the rule, so the approval itself, My approvals, Waiting for me and the Approve / Reject buttons follow it. Users.ManagerId still names the Reporting Person where a page or mail shows it.
- R2 Route of a new item of a User (fn_AgendaRoute, now with the department): Reporting Person set but inactive - Reason 11 (unchanged); Reporting Person an active Controller - AMA; the department has an active Manager other than the creator - AC; otherwise the setting DeptNoManagerAction: refuse - Reason 29 ("Not saved: the department <name> has no active Manager. Ask the Admin to nominate a Manager for the department."), controller - AMA with Agenda.RouteNote 'N' (the save message and the Created mail add "Sent to the Controller: the department had no active Manager."). Reason 15 is unchanged. Items entered by a Manager or the Controller keep their route.
- R3, R8 Rows: route M gives one unread row to each active Manager of the department; no procedure adds a row for the Admin role any more (Agenda Entry, approve / reject, Meeting MC / MU, Committee CC / CU). Existing Admin rows are left as they are.
- R4, R5 When one Manager approves or rejects, the rows of the other Managers on the item's alert are marked handled in the same transaction (HandledReason 'H', HandledBy, HandledOn, read; the check allows 'H', 'N' and 'M'). The checks and their order are unchanged; the item is locked first, so the first decision wins and a second Manager gets Reason 14. A marked row is never made unread again (the decision procedure, the refresh of steps 36 / 37); the refresh also leaves the rows of inactive users as they are.
- R6 Mails: the Created mail of route M goes to every active Manager of the department (spr_GetAgendaCreationMailId, @DepartmentId added, optional); the approve and reject mails (AMA, AMR) also to the other Managers of the department; the ACA / ACR and the update mails leave out marked rows; the Admin is never in them. A Reporting Person of the Admin role is left out of the Bcc of a Manager's new item.
- R7 Back-fill (in the Fix): items at AC on a meeting whose agenda is open and whose date is today or later (or not set), with an alert: each Manager of the department without a row gets one unread row; it prints the counts and the number of such items without an alert (reported, nothing created). A second run adds nothing. On BMMS_Test 2026-11-23: 0 rows (its six items at AC belong to meetings that have passed); on BMMS_Quality the data check predicts 2 (credmanager on QA1-00001-001 and QA1-00002-001).
- R9 Rule 12 (fn_ManagerReleaseRefusal, same parameters): a Manager is stopped only by the items no other Manager of the department could decide; 'P' / 'Q' count them by the meeting date, 'D' names their departments with the department's count; the Reason 24 detail and message are unchanged. When the change is allowed (a role change, a Deactivate, a removed department), his rows of the items at AC of the departments he leaves are marked 'N' and the success detail ends with '|Released:<n>:<departments>'; User Master says "Saved. <n> waiting approval alert(s) of <departments> were closed; the other Managers of the department still have them." (Deactivate: "User deactivated. ...").
- R10 A new Manager, a department added, a role changed to Manager and Activate give him his rows of the items waiting at AC (by the R7 scope); his own 'N' (or 'M') row is opened again, an 'H' row never.
- spr_SetManagerAlertRows is internal: it refuses a direct call (@@NESTLEVEL 1) and an acting user who is unknown or inactive (owner decisions 2026-11-23: gate B, then the protected system account allowed, since as an Admin it may change users in User Master). The Fix's back-fill runs it as the first active Admin; when there is none it does not run, and the Fix's closing line says "Step 53 installed, BUT the back-fill did NOT run ..." (activate an Admin and run the Fix again).
- Lists: fn_DashboardAlerts lists a marked row whatever the alert type is now, with its marking time and person; spr_GetDashboardAlerts shows it under All only, never as unread; the header count leaves it out; Remove from my list works on it. The Dashboard shows it greyed with the line "Handled by <name (login)> on dd-MMM-yyyy" or "No longer Manager of the department (dd-MMM-yyyy)", and the same line in the Agenda Alert panel opened from it. The System Settings card now reads "Used when a new agenda item's department has no active Manager."
- A Controller's edit that moves an item at AC to another department gives that department's Managers their rows and marks the other Managers' rows 'M' (HandledBy the Controller); the Dashboard line reads "Item moved to another department (dd-MMM-yyyy)". A move back opens those 'M' rows again. Owner decision 2026-11-23 (gate B).

- Database step 53 (BMMS-Fix-DepartmentApprovers-Step53.sql; marker DepartmentApprovers-Step53; 21 markers in BMMS-Check-InstalledSteps.sql: the 20 objects and one for the columns):
  - The Fix was built from the 18 texts as installed (identical in BMMS_Test and BMMS_Quality on 2026-11-23; SHA-1 without carriage returns, in pieces of 4,000 characters) and stops, changing nothing, when one is neither that text nor already the step 53 text. Safe to re-run.
  - Re-run rule: the Fix scripts of steps 20, 24, 36, 37, 43 and 52 and the Rollback scripts of steps 36, 37, 39, 43, 44 and 52 now stop while step 53 is installed (guards added in this step; checked on BMMS_Test, each refused and changed nothing). A re-run of another step that holds one of the 18 (13, 16, 17, 18, 31, 35) brings back an older text: step 53 reads Partly; run step 53 again.
  - BMMS-Rollback-DepartmentApprovers-Step53.sql puts the 18 texts back letter for letter (SHA-1 compared at its end) and drops fn_DepartmentManagers and spr_SetManagerAlertRows; it keeps the columns, their checks and key, and the rows step 53 marked or added. The older texts read a marked row as an ordinary row: it stays read until the next decision or edit of its item makes every row of the alert unread again, and under the step 20 rule an alert row lets a Manager decide the item. So the Rollback ends with two counts: the alert rows of items at AC held by active Managers who are not Managers of the item's department (those marked 'N' and 'M' by step 53 apart; each lets that Manager decide the item again: tell the Consultant), and the items at AC that no active Manager could decide (only the Controller can reject them; the step 20 re-route or an active Reporting Person sends them on). On BMMS_Test 2026-11-23 both read 0. BMMS-Check-InstalledSteps.sql then shows step 53 at 1 of 21 (the columns). Roll back the build first.
- Keys to Users: 31 with step 53 (FK_Alert_User_Map_HandledBy; 30 before). A user who handled a row cannot be deleted (the delete procedure's safe refusal, as for the other keys).

Found while building: with step 52's Reason 28 the Test scripts of steps 16, 31, 36 and 37 failed on BMMS_Test because the meeting whose items a Manager decides was dated in the past (the same on a copy taken before step 53). As step MR1 did for Tests 20 and 35, that one meeting is now dated 10 days ahead (its agenda submission date stays in the past); nothing else in what they check changed. Without step 53 they pass again (100, 41, 37 and 42 checks).

Test script BMMS-Test-DepartmentApprovers-Step53.sql (BMMS_Test only; 70 numbered checks): the marker in the 20 objects, the markers of the earlier steps in the 18 replaced texts, the parameter counts, no feature above compatibility level 100, the columns, checks and key, the internal procedure refusing a direct call; in one transaction rolled back, made-up data ZZ53 (department A with two active Managers, an inactive Manager, a Manager without history rows and a fourth Manager; B without a Manager; C with one Manager; Users of A whose Reporting Person is a Manager of A, a Manager of C, a Controller, nobody, an inactive Manager; a User of B and of C; an Admin and two Controllers; a meeting to come and one passed): R1 to R10 as above, the mail lists of every branch, the lists Recent / Unread / All, the header count and Remove on a marked row, the back-fill run twice, a Controller's move to another department and back ('M'), the internal procedure refusing the system account and an inactive acting user; afterwards Users, User_Role, User_Department, Agenda, Alert_User_Map and the setting as before, no ZZ53 row left, every identity counter put back.

What to run where:

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 52 Installed, step 53 Missing).
2. `BMMS_Test`: BMMS-Fix-DepartmentApprovers-Step53.sql ("Step 53 installed", the back-fill counts), again (0 added), then the build.
3. `BMMS_Test`: BMMS-Test-DepartmentApprovers-Step53.sql (70 checks), then the older Test scripts (their step 53 expectations: see the step's report).
4. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-DepartmentApprovers-Step53.sql`.
5. `BMMS`: only after steps 38 to 52 are installed there, after the backup: step 53, then the build. Not on the Work Laptop's BMMS (step 37).
6. To undo: roll back the build, then BMMS-Rollback-DepartmentApprovers-Step53.sql, then BMMS-Check-InstalledSteps.sql.

Browser checks: tester: access-matrix, dashboard and session-check (last), after their step 53 expectations are approved. Owner by eye: see the step's report; the greyed handled row and its line, the Reason 29 and Released messages at 1366, 1024 and 800 px.

## Step UD1c: lists for Managers with several departments (database script step 54 and code; test script for BMMS_Test)

Owner decisions 2026-11-24 (requirement UD1c; the plan of 2026-11-24 and its 12 open questions answered as recommended): (1) a new fixture account qa_manager4 (Credit home, HRD) for the tester, the existing packs unchanged; (2) inactive departments are listed "(inactive)" in the filters, only active ones for a new item; (3) Reason 30 also on Update, in the procedure; (4) the Edit message "You can open only the agenda items of your departments and the items you entered."; (5) the Department column for every role (it was already there); (6) a Manager's new item also alerts the other Managers of its department; (7) the Dashboard is not changed, the Test script proves its departments equal R1; (8) R4 strict on the server (an unchanged Reporting Person that is not allowed is refused too); (9) a Manager is never his own Reporting Person; (10) the Controller's Agenda Summary, Agenda Details, Minutes and Minutes Extract also read the new procedures, the Test script proving the same rows; (11) Reasons 30 and 31; (12) spr_GetMgrControllerByDeptId kept, not called (backlog). Also: step 33 check 3 to follow fn_ManagerDepartments (its new expected text to be approved before it is written).

- R1 "A Manager's departments" are those of fn_ManagerDepartments: every department D of which he is an active Manager by fn_DepartmentManagers(D) of step 53 (one copy of the rule). A User: his own department; the Controller: every department.
- R2 Agenda Entry, a Manager: a Department filter in the list strip ("All my departments", then his departments, the home department marked "(home)", an inactive one "(inactive)"); the list shows the items of the chosen scope and the items he entered (spr_GetAgendaByMeetingIdDeptId, optional @DepartmentId); the card note reads "Items of your departments and the items you entered.". Edit and Update of a colleague's item of any of his departments; the page checks again on Edit and Update (fn_ManagerDepartments read at that moment) and spr_AddEditAgendaByManager refuses an Update of an item of another department that he did not enter (Reason 30). An Update still never writes the department, the status or the creator.
- R3 A Manager's new item: with several active departments the form offers them (home first and chosen), with one it is fixed; the page and spr_AddEditAgendaByManager check that the department is one of his active departments (Reason 30, "Not saved: you are not a Manager of that department.", nothing saved). The Created mail names the chosen department. Users are unchanged.
- R4 The Reporting Person (User Master): the list is the active Controllers and the active Managers of the chosen department, never the user himself (spr_GetReportingPersonList, fn_ReportingPersonAllowed); a current Reporting Person outside it is listed "(not allowed now)" and Save is refused while it is chosen ("Not saved: the Reporting Person must be a Manager of the user's department or a Controller. Choose another, or - Select -."; the form stays open); the drop-down is then enabled for every role. A Department change sets the Reporting Person to "- Select -". spr_AddEditUser refuses the same on Create and on every Update (Reason 31); "- Select -" (NULL) stays allowed.
- R5 The reports read procedures with the acting user; ReportsMgr builds no SQL text any more: spr_GetAgendaReport (Agenda Summary, Agenda Details), spr_GetMinutesReportByUser (Minutes for the Manager, Minutes Extract), spr_GetReportSubjectNos (the From / To subject numbers). A Manager's Department drop-down lists "All my departments" and his departments; a department outside them is refused (Reason 4, "You are not allowed to see this report."). Print, PDF and Word are built from the rows of Generate. The Controller's and Management's every-status Minutes report (step 41) is unchanged.
- R6 The Dashboard reads fn_UserDepartmentScope (step 42); for every active Manager it gives the departments of fn_ManagerDepartments (the home department always has an open row since step 39; no row is dated ahead). Not changed; checked by the Test script (check 6) on the whole database.
- Owner answer 6: the alert of a Manager's new item also goes to the other active Managers of its department (fn_DepartmentManagers), not only to the users whose home department it is.

- Database step 54 (BMMS-Fix-ManagerScope-Step54.sql; marker ManagerScope-Step54; 10 markers in BMMS-Check-InstalledSteps.sql):
  - New: fn_ManagerDepartments, fn_ReportingPersonAllowed, spr_GetManagerDepartments, spr_GetReportingPersonList, spr_GetAgendaReport, spr_GetMinutesReportByUser, spr_GetReportSubjectNos (each read procedure: Reason 8 for an acting user missing, inactive or the protected system account (spr_GetReportingPersonList: missing or inactive; the system account is an Admin), Reason 4 for another role; then no rows).
  - Replaced: spr_GetAgendaByMeetingIdDeptId (step 33, keeps ManagerDepartment-Step33), spr_AddEditAgendaByManager and spr_AddEditUser (step 53, keep their earlier markers).
  - Kept unchanged: spr_GetMgrControllerByDeptId (no longer called), spr_GetMinutesReport, spr_GetMinutesByMeetingId, fn_UserDepartmentScope.
  - The Fix was built from the three texts as installed (identical in BMMS_Test and BMMS_Quality on 2026-11-24; SHA-1 without carriage returns, in pieces of 4,000 characters) and stops, changing nothing, when one is neither that text nor already the step 54 text. Safe to re-run. Guards: the name like BMMS%, steps 33, 39, 52 and 53.
  - Re-run rule (guards from a text search of every Fix and Rollback script that creates one of the three texts): the Fix and Rollback scripts of steps 33 and 53 now stop while step 54 is installed (guards added in this step). The Fix scripts of steps 36, 37 and 52 and the Rollback scripts of steps 36, 37, 39 and 52 already stop while step 53 is installed (their guard reads fn_DepartmentManagers, which step 54 keeps); the Fix script of step 39 stops while step 52 is installed. Checked on BMMS_Test: the twelve scripts each refused and no module text changed (222 modules compared). A re-run of step 13, 16, 17, 18, 31 or 35 (not guarded, as in step 53) brings back an older text of spr_AddEditAgendaByManager or spr_AddEditUser: steps 53 and 54 read Partly; tell the Consultant (Rollback 54, then the step 53 notes, then step 54 again).
  - BMMS-Rollback-ManagerScope-Step54.sql puts the three texts back letter for letter (SHA-1 compared at its end) and drops the seven new objects; it refuses when step 54 is not installed. No data to undo. Roll back the build first.
- Keys to Users: unchanged (31).
- Reasons: 30 (MeetingChangeReason.NotManagerOfDepartment) and 31 (UserChangeReason.ReportingPersonNotAllowed).

Code:

- BMMS/Master/Agenda.aspx(.cs, .designer.cs): the Department filter (pnlListDepartment, ddlListDepartment), the new-item department of a Manager, CheckItemAccess by fn_ManagerDepartments, the Created mail's department, the card note, the Edit message (answer 4).
- BMMS/Master/User.aspx.cs: the Reporting Person list from spr_GetReportingPersonList, "(not allowed now)", the page check before Save, the drop-down cleared on a Department change.
- BMMS/Report/Reports.aspx.cs: the Manager's Department drop-down, every report and the subject number lists by the acting user, the refusal message for every report.
- BMMSBAL: ReportsMgr.cs (no SQL text left), AgendaMgr.cs, DepartmentMgr.cs, UserMgr.cs (Reason 31, the list; the GetMgrControllerByDeptId wrappers removed), MeetingMgr.cs (Reason 30). BMMSDAL: AgendaDB.cs, DepartmentDB.cs, UserDB.cs, MinutesDB.cs (spr_GetMinutesReport no longer called).

Found while building: a whole-file run of the six browser-test setup scripts (AgendaDates-M4, CommitteeData-F3, DashboardAlert-F1, MasterHtml-A1b, MinutesEditor-A2, StoredHtml-A1: "select ONE part and press F5") added their own ZZ rows and deleted them again on BMMS_Test (nothing left; identity counters moved). They are not check scripts; the older-test runs below leave them out. The first Rollback built by the step's generator added an empty line before each text it put back (SHA-1 compare refused; the Fix then refused as well); BMMS_Test was put right by running the three exact texts again, then every module text of BMMS_Test was compared with BMMS_Quality (215, all equal), and the cycle was run again clean.

Older tests (BMMS_Test, before and after step 54):

- BMMS-Test-ManagerDepartment-Step33.sql: check 3 fails with step 54 (55 rows "listed but not allowed": itmgruser, Manager of Finance and HRD, now sees the HRD items); its rule (Users.DepartmentId) is to follow fn_ManagerDepartments (owner, 2026-11-24). The new expected text is shown to the owner before it is written.
- BMMS-Test-AgendaWaitingFor-Step44.sql: check 15 ("Login itmgruser ... 6 function rows", seen 8) already fails before step 54 on the data of BMMS_Test today; unchanged by step 54.
- Every other Test script: the same PASS and SKIPPED counts before and after (steps 20, 35, 36, 39, 51, 52, 53, the user-protection stages and the others).

Test script BMMS-Test-ManagerScope-Step54.sql (BMMS_Test only; 42 checks): part 1 the markers, parameters, compatibility level, the objects kept, R6 for every active Manager of the database; part 1b the Controller's reports against the queries they replace over every committee, department and meeting of the database (in the report's order); part 2 in one transaction rolled back, made-up data ZZ54 (departments A, B, C and I (inactive after mapping); Managers M2 (A home, B, I), MA, MB, MC; Users UA, UB; a Controller, an inactive Controller, Management, an Admin; a meeting to come and a meeting with finalised minutes): R1 to R5 and answers 6 and 9 as above; afterwards Users, User_Role, User_Department, Agenda, Alert_User_Map and Minutes as before, no ZZ54 row left, every identity counter put back.

Results on BMMS_Test (.\SQLEXPRESS): Test 54 42 of 42; Fix, Fix again; Rollback (SHA-1 compared: letter for letter; every module equal to BMMS_Quality), Rollback again (refused), Fix, Fix again; Check: step 54 Installed, 10 of 10, every other step Installed.

What to run where:

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 53 Installed, step 54 Missing).
2. `BMMS_Test`: BMMS-Fix-ManagerScope-Step54.sql ("Step 54 installed"), then the build.
3. `BMMS_Test`: BMMS-Test-ManagerScope-Step54.sql (42 checks), then BMMS-Test-ManagerDepartment-Step33.sql (with its approved check 3).
4. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-ManagerScope-Step54.sql`.
5. `BMMS`: only after steps 38 to 53 are installed there, after the backup: step 54, then the build. Not on the Work Laptop's BMMS (step 37).
6. To undo: roll back the build, then BMMS-Rollback-ManagerScope-Step54.sql, then BMMS-Check-InstalledSteps.sql.

Browser checks: tester: access-matrix, dashboard, two-approvers, manager-scope (new, after its fixture and expectations are approved) and session-check (last). Owner by eye: see the step's report; the Department filter in the Agenda Entry strip and the new-item drop-down at 1366, 1024 and 800 px; "(not allowed now)" in User Master; the reports' Print, PDF and Word.

## Step IU1: inactive users and the Admin role in mails, action items and Reset Password (database script step 55 and code; test script for BMMS_Test)

Owner decisions 2026-11-25 (requirement IU1; the plan of 2026-11-25 approved with Q1 to Q7 as recommended, Q1 changed to "switch the Committee mail on", and the G3 fix taken into IU1).

- R1 The Meeting and Committee Created / Updated mails (MC, MU, CC, CU) go to exactly the users who get the alert row of the same event: active, not the protected system account, not the Admin role, not the person who saved. One rule for both: fn_FunctionalUsers, read by spr_AddEditMeeting and spr_AddEditCommittee (the alert rows, the same users as the step 53 filter) and by spr_GetMeetingCommitteeMailId (the Bcc). The To stays the person who saved (Q3); a user without an address keeps the alert and gets no mail (Q4). With nobody to mail, no mail is sent at all and the page says "The meeting was saved. No mail was sent because there were no recipients." (Committee: "The committee was saved. ..."), in green (Q2). The ML2c address checks and "The meeting was saved, but the mail could not be sent. The error is in the error log." are unchanged.
- Q1 The Committee Created / Updated mail is sent again (it was commented out in Committee.aspx.cs since the baseline, so Audit_Trail_SendMail held no Committee mail): after a successful save, by the Meeting page's path (the same rule, the ML2c checks, "The committee was saved, but the mail could not be sent. The error is in the error log.", the error logged once); a mail failure never undoes the save. The old commented-out call is removed.
- R2 The action item rows of a minutes finalisation (spr_MinutesFinalizeByMeetingId) go to fn_FunctionalUsers only: no row for the Admin role any more. No back-fill for a user made active later. The late action item of spr_UpdateMinutes (inactive creator: the active Controllers) and the Dashboard's scope (UD1 rule 10) are unchanged.
- R3 Existing action item rows of the Admin role and of users now inactive are kept. No page or count shows them: the Action Items card reads fn_DashboardActionItemScope (the mapping gives only the read state; the Admin role and inactive users get no rows); View_Action_Item_Users is read only by spr_GetActionItemByUserId and spr_GetActionItemByActionItemIdUserId, whose BAL / DAL wrappers no page calls.
- R4 Reset Password: the list (spr_GetUser without the system account; "(inactive)" by the UN3 display name) is unchanged. The reset of an inactive user sends no mail and says "The password was reset to the default password. No mail was sent because the user is inactive." (green, Q6). The acting-user check is in the database: spr_ResetPasswordByUserId reads fn_UserChangeRefusal 'ResetPassword' (Reason 8: acting user missing or inactive; 4: a role other than Admin for another user's account; 7: the protected system account as the target). The protected system account has the Admin role and may reset other users (Q5: kept, reported only).
- G3 (fixed in IU1): the mail address and the active status of the chosen user come from the database, under the same acting-user check as the reset (spr_GetResetPasswordMail: @ActingUserId, @UserId, @Reason OUTPUT; no address parameter), never from the page. The hidden field hdnEmailId is removed (nothing else read it: ResetPassword.aspx, .aspx.cs and .designer.cs only).

- Database step 55 (BMMS-Fix-InactiveUsers-Step55.sql; marker InactiveUsers-Step55; 6 markers in BMMS-Check-InstalledSteps.sql):
  - New: fn_FunctionalUsers (inline function, no parameters: UserId, EmailId), spr_GetMeetingCommitteeMailId (Reason 8 for an acting user missing, 0 or inactive, Reason 4 for a role other than Admin and Controller; then no rows), spr_GetResetPasswordMail (the refusals of the reset rule, Reason 4 for a user that does not exist; then no row).
  - Replaced: spr_AddEditMeeting and spr_AddEditCommittee (step 53 texts; they keep the markers of steps 16, 17, 18, 24 and 53), spr_MinutesFinalizeByMeetingId (step 23 text; it keeps the markers of steps 15, 17, 18 and 23 and the step 8 text that the older tests read).
  - The Fix was built from the three texts as installed (identical in BMMS_Test and BMMS_Quality on 2026-11-25; SHA-1 without carriage returns, in pieces of 4,000 characters) and stops, changing nothing, when one is neither that text nor already the step 55 text. Safe to re-run. Guards: the name like BMMS%, steps 23, 53 and 54.
  - Re-run rule (guards from a text search of every Fix and Rollback script that creates one of the three texts): the Fix scripts of steps 23 and 53 and the Rollback script of step 53 now stop while step 55 is installed (guards added in this step). The Fix script of step 24 already stops while step 53 is installed. A re-run of step 8, 15, 16, 17, 18 or 21 (not guarded, as in steps 53 and 54) brings back an older text: step 55 reads Partly; tell the Consultant.
  - BMMS-Rollback-InactiveUsers-Step55.sql puts the three texts back letter for letter (SHA-1 compared at its end) and drops the three new objects; it refuses when step 55 is not installed. No data to undo. Run it only AFTER the build of IU1 is rolled back: the new Meeting, Committee and Reset Password code calls spr_GetMeetingCommitteeMailId and spr_GetResetPasswordMail.
- Keys to Users: unchanged (31). Reasons: no new code.

Code:

- BMMS/Master/Meeting.aspx.cs: the Bcc from spr_GetMeetingCommitteeMailId (AlertMgr.GetMeetingCommitteeMailId); the To as before; "no recipients" (no mail, green).
- BMMS/Master/Committee.aspx.cs: the mail switched on after the save, by the Meeting path; the commented-out call removed.
- BMMS/Master/ResetPassword.aspx(.cs, .designer.cs): the address and status from spr_GetResetPasswordMail (UserMgr.GetResetPasswordMail); hdnEmailId removed; the inactive message.
- BMMSBAL: AlertMgr.cs, UserMgr.cs. BMMSDAL: AlertDB.cs, UserDB.cs.

Known items of IU1 (owner, 2026-11-25: no change in IU1):

- G1: the Created mail of a Manager's or the Controller's new item goes only to the Reporting Person (Agenda.aspx.cs), while the alert goes to the Controllers, the other Managers of the department and the department's users (a Manager's item) or to the department's users (the Controller's item).
- G2: the To of the Meeting and Committee mails is the person who saved, which can be an Admin (both pages are open to Admin and Controller); the Admin then receives his own functional mail.
- G4: the late action item row of spr_UpdateMinutes for the item's creator has no Admin-role check; an Admin cannot enter agenda items, so it matters only after a role change.
- G5: ActionItemMgr.GetActionItemByUserId and GetActionItemByActionItemIdUserId (BAL and DAL), their procedures and View_Action_Item_Users are not used by any page; remove them in a clean-up step.
- G6: spr_AddEditCommittee has no transaction and returns no result row (a refusal cannot be reported); the page reports a database error through the error page, as before.

Test script BMMS-Test-InactiveUsers-Step55.sql (BMMS_Test only; 48 checks): part 1 the marker in the six objects, the markers of the earlier steps in the three replaced texts, the parameters (no address parameter in spr_GetResetPasswordMail, G3), no feature above compatibility level 100 in the new objects, fn_FunctionalUsers over the whole database equal to the step 53 filter; part 2 in one transaction rolled back, made-up data ZZ55 (a Controller who saves, a second Controller, an Admin, an inactive Admin, MD Secretariat, a User, a User without an address, an inactive User, an inactive Manager, the system account): R1 for CC, CU, MC and MU (the alert rows equal the step 53 filter on the same data, both directions; the mail list equals the addresses of the alert users that have one, minus the saver, both directions; the refusals 8 and 4), R2 (the rows of a finalisation equal fn_FunctionalUsers; a user made active later gets no row; the late action item of an inactive creator still goes to the active Controllers), R3 (rows saved before are kept), R4 and G3 (an inactive user is reset; the reset mail reads the stored address, also after it is changed; refusals 8, 4, 7 and 4 for a user that does not exist); afterwards Users, Alert_User_Map, ActionItem_User_Map and the counts of the item tables as before, no ZZ55 row left, every identity counter put back.

Results on BMMS_Test (.\SQLEXPRESS, 2026-11-25): Test 55 48 of 48; Fix, Fix again; Rollback (SHA-1 compared: letter for letter; all 222 module texts equal to BMMS_Quality), Rollback again (refused), Fix, Fix again; Check: step 55 Installed, 6 of 6, every other step Installed. The Fix scripts of steps 23, 24 and 53 and the Rollback script of step 53 each refused while step 55 is installed and no module text changed (225 modules compared). NOEXEC: the new and changed scripts parse; BMMS-Rollback-DepartmentApprovers-Step53.sql reports Msg 313 for fn_AgendaRoute under NOEXEC, exactly as its committed text does (NOEXEC compiles against today's two-parameter function, which the real run replaces first).

Older tests (BMMS_Test; the six browser-test setup scripts left out): with the first build of step 55 three checks failed, each because the Admin role no longer gets an action item row at a finalisation (R2). Their new expected texts were approved by the owner (2026-11-25) and written; each reads the step 55 value only while step 55 is installed ([step 55: ...]):

- BMMS-Test-SystemAccount-Stage3.sql check 45 "Minutes finalize, new item: ordinary Admin / system account mapped [step 55: no Admin row]": "Result 1, Reason 0; 0 0" with step 55, "Result 1, Reason 0; 1 0" without.
- BMMS-Test-FK-Procedures.sql check 17 "Minutes finalize: every user mapped once (17/18: active, not system; 55: not Admin; + saved row)": with step 55 the active users other than the system account and the Admin role, plus the saved row.
- BMMS-Test-UserStatus-Stage2b.sql check 51 "... all active users mapped [step 55: not the Admin role]": with step 55 the active users other than the system account and the Admin role.

Run with step 55 installed, then after BMMS-Rollback-InactiveUsers-Step55.sql (then the Fix again): every script passes in both states with the same counts (PASS / SKIPPED): AgendaRouting-Step20 56/0, AgendaWaitingFor-Step44 121/0, AlertRefresh-Step36 37/0, Attendance-FutureMeeting 23/0, CommentAuthor-Step35 28/0, DashboardAlerts-Step43 128/0, DashboardFollowupFinal-Step48 43/0, DashboardMeetings-Step42 71/0, DashboardSummary-Step45 66/0, DepartmentApprovers-Step53 70/0, FK-Procedures 19/0, FollowupFinal-Step47 95/0, FollowupReports-Step49 33/0, Indexes-Step50 9/0, LoginName-Step34 7/0, ManagerDepartment-Step33 7/1, ManagerRelease-Step52 28/0, ManagerScope-Step54 42/0, MeetingDates-Step24 36/0, MeetingDelete-D1 9/0, MeetingLocks-Step16 100/0, MeetingLocks 43/0, MemberTypes-Step21 100/0, MinutesDueDate-Step38 22/0, MinutesGating-Step22 36/0, OrganisationSettings-Step19 52/0, ReportAccess-Step41 44/0, ResetDatabase 40/0, RoleAccess-Step40 43/0, SessionCheck-Step51 18/0, SystemAccount-Stage3 51/0, UnicodeText-Step31 41/0, UpdateMail-Step37 42/0, UserDelete 75/0, UserHistory-Step39 59/0, UserKey-Workflows 23/0, UserProtection-Stage1 142/0, UserStatus-Stage2a 50/0, UserStatus-Stage2b 63/0, WorkflowOrder-Step23 53/0. Delete-Procedures and FollowupSave-Step46 run no check by design (messages only). Afterwards step 55 installed again: Check 6 of 6, every step Installed; Test 55 48 of 48.

What to run where:

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 54 Installed, step 55 Missing).
2. `BMMS_Test`: BMMS-Fix-InactiveUsers-Step55.sql ("Step 55 installed"), then the build.
3. `BMMS_Test`: BMMS-Test-InactiveUsers-Step55.sql (48 checks), then the older Test scripts (with the three approved expected texts).
4. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-InactiveUsers-Step55.sql`.
5. `BMMS`: only after steps 38 to 54 are installed there, after the backup: step 55, then the build. Not on the Work Laptop's BMMS (step 37).
6. To undo: roll back the build FIRST, then BMMS-Rollback-InactiveUsers-Step55.sql, then BMMS-Check-InstalledSteps.sql.

Tester (2026-11-25, Tests\_results\2026-11-25_105953): access-matrix and session-check PASSED, 497 of 497 checks (440 access cells ok), error log 0 new lines.

Owner tests (BMMS_Test, 2026-11-25 13:50): PASSED.

- First a unique e-mail address was set for every BMMS_Test user (User Master).
- Meeting 00001 (Risk Management) Created and Updated: To the Controller; Bcc 14 addresses (sect, credmanager, inactiveuser, itmgruser, mgruser, secuser, mduser, ra1mdsec, muser, ra1mgmt, creduser, depuser, ituser, s20user); no mail to admin, ra1admin, s20admin or zztest (inactive).
- Committee C08 (Risk Management Committee) Created and Updated: the mail sent by the same rule (the first Committee mail of BMMS_Test).
- NRC meeting 00004: minutes finalised by the Controller; action item C04-00004-001 has 15 rows (the Controller's creator row kept, 14 added); none for the Admins, the system account or zztest.
- Reset Password: zztest (inactive) marked "(inactive)" in the list; the green "The password was reset to the default password. No mail was sent because the user is inactive."; no mail. depuser: the mail received, with the existing message.
- The messages fine at 1366, 1024 and 800 px; the error log 0 new lines; zztest activated again afterwards (now on the default password).

Browser checks: tester: access-matrix and session-check (last). Owner by eye: Meeting Create and Update, Committee Create and Update in the mail catcher (To the saver; no Admin, no inactive user, not the system account in the Bcc); minutes finalisation (no new row for the Admin); Reset Password of an inactive user (the new message, no mail) and of an active user (the mail as before); the error log.

## Step GM1a: the Governance Matrix and the governance change log (database script step 56 and code; test script for BMMS_Test)

Owner decisions 2026-11-25 (requirement GM1, section 5, M1 to M11; the plan of 2026-11-25 approved with its 12 answers as recommended and the changes C1 to C7; test change approved: BMMS-Test-ResetDatabase.sql keys to Users 31 -> 32; access-matrix cells approved).

- M1 to M7 A read-only page Report/GovernanceMatrix.aspx for the Admin and the Controller (PageAccess.xml, RequireRole; the Admin menu and the Controller's Reports menu). One row per transaction and department ("All departments" where the rule is not per department): Transaction, Department, Who enters, Who approves ("Any one of: " for the Managers), Controller(s), Rule note; people as "Name (login)". An As-on date (default today; validated on the server: before the history start Reason 32 "History starts on <date>. Choose that date or a later one.", after today Reason 33), a Department and a Transaction filter, Print, Export to Excel (CSV) and Export to PDF. A Settings block (DeptNoManagerAction, AgendaControllerBypass as on the date) and a Read-only access block (Management, MD Secretariat).
- M4 Today's matrix reads the functions the software uses (fn_DepartmentManagers, fn_AgendaRoute, fn_FunctionalUsers, fn_UserDepartmentScope, Users); an earlier day reads their dated versions over User_Role and User_Department (step 39) and the change log. One function gives both (fn_GovernanceMatrixPeople(@AsOn, @Live)); Test 56 proves that both give the same rows today, over the whole database and on made-up data after every change. The rules whose only check is a page rule (Agenda finalisation, Minutes update, Minutes finalisation, Minutes confirmation, Followup, Meeting, Committee, Attendance, User Master, Department Master, System Settings) are read from PageAccess.xml itself (PageAccessModule.RolesForPage); MD Secretariat is shown "can open the page to read only" on Followup, where the procedures accept the Controller only.
- C2 The Read-only access block is built from PageAccess.xml and the menu (MenuUserControl.ascx, read by GovernanceMgr.ReadMenu): Management "Dashboard (read only), Minutes report, Followup report, Followup Summary report"; MD Secretariat "Dashboard, Followup page (read only)" (what PageAccess.xml and the menu give today: the Minutes and Followup reports of step RA1b for Management). Each entry is named by its page (gate B, 2026-11-25; GovernanceMgr.ReadOnlyEntryName): a page under Report/ "<menu title> report", another page "<menu title> page", "(read only)" where the role only reads there (the Followup transaction's read-only role; the Dashboard for Management, which sees the action items and cannot save them).
- C6 Two rows "Action items: who receives them" (fn_FunctionalUsers) and "Action items: who can open them (Dashboard)" (the rule of fn_DashboardActionItemScope by department).
- M8, M11 Governance_Change_Log: ChangedOn, EffectiveOn, ChangedBy (key to Users), ChangeType (UA user added, RC role changed, HC home department changed, DA / DR Manager department added / removed, RP Reporting Person changed, UV activated, UD deactivated, UX deleted, KA / KD department activated / deactivated, ST setting changed), UserId with the login and name as they were (no key: the rows about a deleted user stay), DepartmentId and name, SettingCode, OldId / NewId, OldValue / NewValue, Source (the procedure, 'History' or 'AuditTrail'). Written by the procedures in the same transaction, only when something changed: spr_AddEditUser, spr_SetUserStatusByUserId, spr_DeleteUserByUserId, spr_AddEditDepartment, spr_SetDepartmentManagerRule, spr_SetAppSetting (through the internal spr_WriteGovernanceUserChanges and spr_WriteGovernanceChange). Audit_Trail_Master is written as before. The Reporting Person and the department status of an earlier day are read back from the log (from the install, App_Setting GovernanceLogFrom, or the last Reset Database, whichever is later); for an earlier day the page says "Reporting Person not recorded before <date>: the route to the Controller is not shown for earlier dates." and "Department status not recorded before <date>: today's status is shown."
- M9 Back-fill at the first install (only while the log is empty): the calls of the step 39 history after its first migration (grouped by user and time stamp; Source 'History') and the Audit_Trail_Master rows of the two settings (Source 'AuditTrail'). On BMMS_Test 2026-11-25: 79 rows from the history (DA 11, DR 12, HC 12, RC 22, UA 5, UD 8, UV 9), 6 from the audit trail.
- M10 A second view, Change log: From and To dates (Reason 34 when From is after To or To after today), user (deleted users listed "(deleted)"), department, change type; Print, CSV, PDF.
- C1 spr_AddEditDepartment takes @ActingUserId (optional for the call shape) and refuses a missing, 0 or inactive acting user (Reason 8) and any role other than Admin (Reason 4) before any change; Department Master passes the signed-in user: "Not saved: your account is not active. Sign in again. Nothing was changed." / "Not saved: only an Admin can change departments. Nothing was changed.". It now runs in one transaction.
- C3 A delete writes UX with OldValue the role, the home department and the Manager's departments held at the delete; a past-day matrix says "Deleted users are not shown; see the change log." (their history rows go with them, step 39).
- C4 The CSV puts a ' before a cell that begins with = + - @, a tab or a carriage return.
- C5 Grant model: the application's database users (bmms_app; bmms_site on BMMS_Quality) have db_datareader, db_datawriter and EXECUTE on schema dbo. The Fix denies INSERT, UPDATE and DELETE on Governance_Change_Log and EXECUTE on the two internal procedures to public; the procedures that change users, departments and settings write the log through ownership chaining (all dbo). The internal procedures also refuse a call at nesting level 1. Test 56 runs both as bmms_app (error 229) and directly (refused).
- Delete and Reset: a user who is ChangedBy of a log row cannot be deleted (Reason 6, group "user changes"). Reset Database clears the log before Users and starts its counter again; it does not touch App_Setting (step 19): the log's start after a reset is the time of its audit row. Keys to Users: 32 (FK_Governance_Change_Log_ChangedBy).

- Database step 56 (BMMS-Fix-GovernanceLog-Step56.sql; marker GovernanceLog-Step56; 27 markers in BMMS-Check-InstalledSteps.sql: 26 objects and one for the table, its key and the setting):
  - New: the table, the setting row GovernanceLogFrom, fn_GovernanceHistoryStart, fn_UserRoleOn, fn_UserDepartmentsOn, fn_DepartmentManagersOn, fn_ReportingPersonOn, fn_SettingOn, fn_DepartmentActiveOn, fn_GovernanceRoleHolders, fn_GovernanceMatrixPeople, fn_GovernanceRefusal, fn_GovernanceDeptList, fn_GovernanceUserSummary, spr_WriteGovernanceChange, spr_WriteGovernanceUserChanges, spr_GetGovernanceMatrix, spr_GetGovernanceSettings, spr_GetGovernanceDepartments, spr_GetGovernanceChangeLog, spr_GetGovernanceLogUsers (each read procedure: Reason 8 / 4, then the date rules).
  - Replaced: spr_AddEditUser (step 54), spr_SetUserStatusByUserId (step 53), spr_DeleteUserByUserId (step 47), spr_AddEditDepartment (baseline), spr_SetDepartmentManagerRule (step 39), spr_SetAppSetting (step 16), spr_sys_ResetDatabase (step 39); they keep the markers of their earlier steps.
  - The Fix was built from the seven texts as installed (identical in BMMS_Test and BMMS_Quality on 2026-11-25; SHA-1 without carriage returns, in pieces of 4,000 characters) and stops, changing nothing, when one is neither that text nor already the step 56 text. Guards: the name like BMMS%, steps 39, 53, 54 and 55. Safe to re-run (the back-fill runs only while the log is empty).
  - Re-run rule (guards from a text search of every Fix and Rollback script that creates one of the seven texts): the Fix and Rollback scripts of steps 47 and 54 now stop while step 56 is installed (guards added in this step). The Fix and Rollback scripts of steps 39, 52 and 53 already stop while step 52, 53 or 55 is installed (checked: each refused, nothing changed). A re-run of step 2, 3, 6, 10, 13, 16, 18, 21, 29 or 30 (not guarded) brings back an older text: step 56 reads Partly; tell the Consultant.
  - BMMS-Rollback-GovernanceLog-Step56.sql puts the seven texts back letter for letter (SHA-1 compared at its end) and drops the 19 new functions and procedures; it keeps the table, its rows, its key, the DENY and the setting row (Check: step 56 Partly, 1 of 27). While rolled back with rows in the log a user who changed something recorded there cannot be deleted (Reason 9) and Reset Database fails and changes nothing (the older text does not clear the log): install step 56 again first. Changes made while rolled back are not recorded, and the back-fill does not run again (the log is not empty). Roll back the build first.

Code:

- BMMS/Report/GovernanceMatrix.aspx(.cs, .designer.cs): the two views, the filters, the exports (CSV and PDF built by the page from the same reads; the PDF through PDFUtilities.HtmlReportToPdf with the report banner), the messages. BMMSBAL/GovernanceMgr.cs (the transactions, the rows, the notes, the menu reading, the CSV and PDF text), BMMSDAL/GovernanceDB.cs.
- BMMS/PageAccessModule.cs: RolesForPage (read only, from the cached policy). BMMS/XML/PageAccess.xml: the page for admin and controller. BMMS/UserControl/MenuUserControl.ascx: the two menu entries. BMMS/CSS/bmms-workbench.css: .wb-gov-* and a print rule.
- BMMS/Master/Department.aspx.cs, BMMSBAL/DepartmentMgr.cs, BMMSDAL/DepartmentDB.cs: the acting user and the two refusal messages (C1).

Test script BMMS-Test-GovernanceLog-Step56.sql (BMMS_Test only; 49 numbered checks): part 1 the markers, the earlier markers in the replaced texts, the parameters, no feature above compatibility level 100 in the new texts, the table, its key, the 32 keys to Users, the DENY to public, Reset Database's text, LogFrom, M4 over the whole database (the matrix, the Managers of every department, the people by role, the settings, the departments' status, the Reporting Person), the back-fill rows against the history; part 2 in one transaction rolled back, made-up data ZZ56 (three departments, two Admins, a Controller, an inactive Controller, Management, MD Secretariat; a Manager, a User and a user to delete added through spr_AddEditUser): each change type written once, nothing written on a save that changes nothing, the UX row (C3), the delete of a user who wrote a log row (Reason 6), the department refusals (C1), the internal procedures refused directly and as bmms_app (C5), who may read (eight users, Reasons 0, 4, 8), the dates (32, 33), M4 after the changes, past days (the history moved back: a Manager who was a User 5 days ago; the settings, the department status and the Reporting Person of yesterday), the matrix and change log procedures and the Reason 34 refusals; afterwards Users, the history tables, the log and App_Setting as before, no ZZ56 row left, every identity counter put back.

Results on BMMS_Test (.\SQLEXPRESS, 2026-11-25): Test 56 49 of 49; Fix, Fix again (back-fill skipped), Rollback (SHA-1 compared: letter for letter), Rollback again (refused), Fix, Fix again; Check: step 56 Installed, 27 of 27, every other step Installed. Every module text of BMMS_Test compared with BMMS_Quality: only the 26 objects of step 56 differ. The Fix and Rollback scripts of steps 39, 47, 52, 53 and 54 each refused while step 56 is installed.

Older tests (BMMS_Test; the six browser-test setup scripts left out): with step 56 installed every script passes (AgendaRouting-Step20 56, AgendaWaitingFor-Step44 121, AlertRefresh-Step36 37, Attendance-FutureMeeting 23, CommentAuthor-Step35 28, DashboardAlerts-Step43 128, DashboardFollowupFinal-Step48 43, DashboardMeetings-Step42 71, DashboardSummary-Step45 66, DepartmentApprovers-Step53 70, FK-Procedures 19, FollowupFinal-Step47 95, FollowupReports-Step49 33, InactiveUsers-Step55 48, Indexes-Step50 9, LoginName-Step34 7, ManagerDepartment-Step33 7/1 skipped, ManagerRelease-Step52 28, ManagerScope-Step54 42, MeetingDates-Step24 36, MeetingDelete-D1 9, MeetingLocks-Step16 100, MeetingLocks 43, MemberTypes-Step21 100, MinutesDueDate-Step38 22, MinutesGating-Step22 36, OrganisationSettings-Step19 52, ReportAccess-Step41 44, ResetDatabase 40 (with the approved key count 32), RoleAccess-Step40 43, SessionCheck-Step51 18, SystemAccount-Stage3 51, UnicodeText-Step31 41, UpdateMail-Step37 42, UserDelete 75, UserHistory-Step39 59, UserKey-Workflows 23, UserProtection-Stage1 142, UserStatus-Stage2a 50, UserStatus-Stage2b 63, WorkflowOrder-Step23 53). After the Rollback the same counts, except ResetDatabase (18 of 20 run) and UserHistory-Step39 (55 of 56 run), whose Reset Database check fails on the kept log rows (error 547, the documented rolled-back state); with the log emptied in the rolled-back state both pass (40, 59). Delete-Procedures and FollowupSave-Step46 run no check by design.

What to run where:

1. `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 55 Installed, step 56 Missing).
2. `BMMS_Test`: BMMS-Fix-GovernanceLog-Step56.sql ("Step 56 installed", the back-fill counts), then the build.
3. `BMMS_Test`: BMMS-Test-GovernanceLog-Step56.sql (49 checks), then BMMS-Test-ResetDatabase.sql (with the approved key count).
4. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-GovernanceLog-Step56.sql`.
5. `BMMS`: only after steps 38 to 55 are installed there, after the backup: step 56, then the build. Not on the Work Laptop's BMMS (step 37).
6. To undo: roll back the build FIRST, then BMMS-Rollback-GovernanceLog-Step56.sql, then BMMS-Check-InstalledSteps.sql.

Browser checks: tester: access-matrix (the new page for six roles) and session-check (last). Owner by eye: see the step's report; the matrix and the change log at 1366, 1024 and 800 px, Print, the PDF and the CSV in Excel.

Tester (2026-11-25, Tests\_results\2026-11-25_154316; baseline updated with step 56, back-fill on BMMS_Quality DR 1, UA 11, UD 1): access-matrix and session-check PASSED, 505 of 505 checks (448 access cells ok, Report/GovernanceMatrix.aspx ok in all 8 columns; session-check 20 of 20), error log 0 new lines. Again on the final build after the owner-test fixes (Tests\_results\2026-11-25_170101): PASSED, 505 of 505, error log 0 new lines.

Owner tests (BMMS_Test, 2026-11-25): PASSED (filters, breadcrumb, defaults on a fresh visit, print preview of both views in Chrome and Edge, the Controller's view, past dates, the change log: 10 recorded rows for DA, DR, RP twice, UD, UV, KD, KA and ST twice, no row for a save that changed nothing, 93 rows in all; the exports; the error log clean).

## Step AZ1: Release build from a fresh clone, third-party DLLs from Lib, the https menu 404 and the .woff2 fonts (code and project files only, no database step)

Found on the first Azure publish (requirement az1-requirements; plan approved 2026-11-26 with the tester's ReferencePath line removed, C1 and C2).

- P1 The Release build failed (CS0246 in BMMSBAL): BMMSBAL.csproj pointed itextsharp and Microsoft.Office.Interop.Word at `..\BMMS\dll\`, a folder git does not track; Debug worked only through the copies tracked in BMMSBAL\bin\Debug. BMMS.csproj had no HintPath for itextsharp and AjaxControlToolkit (found in BMMS\bin).
- P2 Over https every page showed a 404 text above the header: JScript/ddlevelsmenu.js had `enableshim: true`, which adds an IFRAME with `httpsiframesrc` "blank.htm" (no such page) on an https page.
- P3 The Public Sans .woff2 fonts answered 404 on Azure App Service (IIS there has no MIME type for .woff2).

Changes:

- Lib\iTextSharp\itextsharp.dll (4.0.2.0, moved with git mv from BMMS\bin) and Lib\AjaxControlToolkit\AjaxControlToolkit.dll (1.0.20229.20821, moved from BMMS\bin), each with a README.txt (version, size, SHA-256, where it is used). No licence text came with either copy; each README names the licence as published (iTextSharp 4.x MPL 1.1 / LGPL; the toolkit Ms-PL) as to be confirmed, for the owner to add the text.
- BMMSBAL.csproj: itextsharp from `..\Lib\iTextSharp\itextsharp.dll` (Private True); the Microsoft.Office.Interop.Word reference, the COM reference VBIDE (which brought Microsoft.Vbe.Interop, office.dll and stdole.dll into the build) and `DocToString.cs` removed. BMMS.csproj: itextsharp and AjaxControlToolkit with a HintPath into Lib (Private True). Every third-party reference now has a HintPath into Lib; none relies on a bin folder.
- Office was not used at run time: `DocToString.ConvertDocToString` was called only in a commented line (Master/Agenda.aspx.cs) and `WordUtilities.CreateWord` had no caller; both are removed (the rest of WordUtilities.cs is unchanged). Export to Word (Report/ViewReport.aspx.cs) sends the report HTML as a .doc download and starts no Word. Word is not needed on the server, before or after this step.
- Removed from git (git rm): BMMSBAL\bin\Debug\ itextsharp.dll (identical to the moved copy), Microsoft.Office.Interop.Word.dll and .xml, office.dll and office.xml, Microsoft.Vbe.Interop.dll, Microsoft.SqlServer.BatchParser.dll, Microsoft.SqlServer.Replication.dll; BMMS\bin\backupdlls\ (the same two SQL Server DLLs) and BMMS\bin\stdole.dll. No code uses Microsoft.SqlServer: Backup Database is a plain `BACKUP DATABASE` through System.Data.SqlClient (BMMSBAL/Sql_Backup_Mgr.cs). git now tracks no file under any bin or obj folder.
- stdole: the tracked BMMS\bin\stdole.dll (22,344 bytes) was overwritten by every build with the 16,384-byte copy the VBIDE/Office references brought in, hence the permanent ` M BMMS/bin/stdole.dll`. With those references gone the build copies no stdole.dll, and the file is no longer tracked.
- JScript/ddlevelsmenu.js: `enableshim: false` (the shim is for old Internet Explorer; Chrome and Edge draw the menu, z-index 100, over a drop-down list without it). No IFRAME is added, so blank.htm is never asked for.
- Web.config, system.webServer: `<staticContent><remove fileExtension=".woff2"/><mimeMap fileExtension=".woff2" mimeType="font/woff2"/></staticContent>` (the remove avoids the duplicate error where IIS already knows .woff2).
- Tests/_runner/Tester.Common.ps1: the tester's build no longer passes `/p:ReferencePath` (BMMSBAL\bin\Debug and BMMS\bin), so the tester's build proves the references resolve from Lib.
- .gitignore: the comment on the build folders.

After a pull: Build (or Rebuild) Solution before opening the site. The pull deletes itextsharp.dll and AjaxControlToolkit.dll from BMMS\bin, and only the build copies them back from Lib. Opened before the build, even the sign-in page (Default.aspx) and every page that registers the toolkit (32 of the 45 pages) answer HTTP 500 with the site's error page "BMMS - Error" ("This action could not be completed because of an error on the server. The error is in the error log."), and the error log has "System.Web.HttpParseException: Could not load file or assembly 'AjaxControlToolkit' or one of its dependencies" (checked 2026-11-26 on a copy of the fresh-clone site with the two DLLs deleted from bin). After the build the pages open again; nothing in the database is touched.

Not in this step: UTC dates, hiding Backup on Azure, the machine key, a Release Web.config transform, mail STARTTLS, Azure exact-text checks; the x86 configurations of the solution.

Build checks (2026-11-26): the working tree built into the scratchpad (Debug, 0 errors, bin and obj untouched); a fresh clone (git clone of HEAD 00838ed plus the step's diff; no bin, obj or dll folder, only the three DLLs in Lib) Rebuilt Debug and Release (Any CPU), 0 errors, the detailed log resolves itextsharp, AjaxControlToolkit and HtmlAgilityPack from the clone's Lib in both, and no stdole, office, Vbe or SqlServer DLL is produced; the site precompiled with aspnet_compiler (0 errors). No SQL script. The .woff2 MIME entry checked on IIS Express: with an IIS configuration without .woff2 the fonts answer 404 without the block and 200 font/woff2 with it; with the default configuration (which knows .woff2) 200 font/woff2, no duplicate error.

Reviewers (2026-11-26): security Pass, no finding; ux and ui Pass with Low notes only (in Known items for later steps). No High or Medium finding.

Tester (2026-11-26, Tests\_results\2026-11-26_224034; no baseline update, no database step): access-matrix, page-assets, dashboard, followup, followup-reports, manager-scope PASSED, 940 of 940 checks (448 access cells ok), error log 0 new lines. Again after Tests\_build\out and Tests\_site\bin were emptied (the runner's build without ReferencePath into empty folders; Tests\_results\2026-11-26_225141): access-matrix and page-assets PASSED, 496 of 496, error log 0 new lines; the two folders then held only the six DLLs of the site (no Office, Vbe or stdole DLL).

Owner tests (Work Laptop, BMMS_Test, 2026-11-26): PASSED (Rebuild first; the menus open over the drop-down lists on Agenda Finalize, Followup and Committee Master in Chrome and Edge; both .woff2 fonts 200; View Report Export to Pdf and Export to Word open; the calendar and the User Master Email filter work; no " M BMMS/bin/stdole.dll" in git status after the build; error log 0 new lines). The check on Azure is deferred until after step AZ2 (the Azure database is at step 51).

## Step AZ2: no reference to another database in two procedures, so the database deploys to Azure SQL Database (database script step 57; test script for BMMS_Test)

Why: the SSMS "Deploy Database to Microsoft Azure SQL Database" of BMMS_Test failed with SQL71562: spr_AddEditMemberType and spr_SetOrganisationSettings reference [master].[dbo].[spt_values]. Both filled their list of control characters (NCHAR 0 to 31 and 127) from master.dbo.spt_values (type 'P') before the role check; the list refuses a control character with Reason 3 and the setting code, MemberTypeCode or MemberTypeName. An Azure SQL database cannot name another database.

The Azure copy of BMMS_Test (at step 51) has an undocumented hand change of 2026-11-18: a view dbo.vw_spt_values_P and both procedures reading it, with their markers kept. It is not in git. The redeploy from the local BMMS_Test replaces it; step 57 does not create or use such a view.

Owner decisions 2026-11-26 (requirement AZ2; the plan approved with the answers A, B and C as recommended):

- Marker DatabaseLocal-Step57. A numbers list (common table expression) inside each procedure; no new object, no catalog view.
- Fix 19, Fix 21, Fix 40 and Rollback 40 are not changed (they still contain the spt_values text; see "Re-run" below).
- spr_SetOrganisationSettings keeps its THROW in the CATCH block (identical behaviour); spr_AddEditMemberType keeps RAISERROR (Test 40 checks that it has no THROW).
- A: the closing count of the Fix and the Check row leave out exactly one row of sys.sql_expression_dependencies: spr_SaveFollowupConfirmed with referenced database x, schema n and entity value. That row is the XML method call x.n.value(...) in its text, which SQL Server lists as a three-part name; it names no database. Every other reference to another database or server counts, so a correct install prints 0.
- C: Test 57 has 30 rows; the 33 characters are checked inside 3 rows, which list the code points that did not give the expected answer.

What changes: both procedures get the step 19 and step 40 texts word for word, except the fill of the list and one comment line naming DatabaseLocal-Step57:

    ;WITH d (n) AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),
                    (13),(14),(15)) v (n)),
          num (number) AS (SELECT a.n * 16 + b.n FROM d a CROSS JOIN d b)
    INSERT INTO @Ctrl (Ch)
    SELECT NCHAR(number) FROM num WHERE number BETWEEN 0 AND 31 OR number = 127;

The same 33 characters. Parameters, result sets, Reasons, ReasonDetail and messages are unchanged; no data change; no C# change. The markers OrganisationSettings-Step19, MemberTypes-Step21 and RoleAccess-Step40 stay in the texts (the Check rows of steps 19, 21 and 40, Test 19 line 106, Test 21 line 131, Test 40 and the guards of Fix 20, 21, 29, 30, 39 and 40 read them). The new comment line contains neither "THROW" nor "master.". Checked on BMMS_Test: the installed texts differ from the step 19 and step 40 texts only in these lines.

- Database step 57 (BMMS-Fix-DatabaseLocal-Step57.sql; marker DatabaseLocal-Step57; 3 markers in BMMS-Check-InstalledSteps.sql: the two procedures and "no procedure, function, view or trigger names another database or server"). Guards: the name like BMMS%; step 56 (spr_sys_ResetDatabase carries GovernanceLog-Step56); spr_SetOrganisationSettings with OrganisationSettings-Step19 and spr_AddEditMemberType with RoleAccess-Step40 (both keep them after step 57, so a re-run is safe). It ends with "Step 57 installed ..." and the count of references to another database or server (0 expected).
- BMMS-Rollback-DatabaseLocal-Step57.sql puts the step 19 and step 40 texts back unchanged and prints the SHA-256 of both definitions. It stops when step 57 is not installed and on Azure SQL Database (SERVERPROPERTY('EngineEdition') = 5), where the restored texts cannot run. On BMMS_Test the restored definitions have the same SHA-256 (HASHBYTES('SHA2_256') of OBJECT_DEFINITION) as before step 57: spr_SetOrganisationSettings 0x228A8FBBCC0DF254230625A9085F09E1A1A73A1273BB379F6859DB2F3E334CAE, spr_AddEditMemberType 0xAE706ABF18BC2865142CFFB27D66ECB1648CB5722E772B4BC58174B5F606EB75. (SQL Server stores CREATE OR ALTER as "CREATE   PROCEDURE"; the hashes compare the stored texts.)
- Re-run: BMMS-Fix-OrganisationSettings-Step19.sql, BMMS-Fix-MemberTypes-Step21.sql, BMMS-Fix-RoleAccess-Step40.sql and BMMS-Rollback-RoleAccess-Step40.sql still contain master.dbo.spt_values. Run after step 57, they bring the reference back: step 57 reads Partly; run step 57 again (after step 56). Not guarded (owner decision); see Known items.

Test script BMMS-Test-DatabaseLocal-Step57.sql (TEST DATABASE ONLY: it refuses a database named BMMS; it names no other database, so it also runs on Azure; 30 checks): part 1 read only (the new and the older markers, neither text with spt_values or "master.", no reference to another database or server for either procedure, the parameters unchanged, no THROW in spr_AddEditMemberType, THROW still in spr_SetOrganisationSettings); part 2 in one transaction rolled back, with made-up ZZ57 users (an Admin, an inactive Admin, a Controller): each of the 33 characters inside an organisation value (the seven free-text settings in turn), a member type code and a member type name (Result 0, Reason 3 and that setting code, MemberTypeCode or MemberTypeName; nothing written); space (32), ~ (126) and NCHAR(160) accepted in each (each member type save with its own code and name); NCHAR(129) accepted in each, as before step 57; Controller Reason 4, unknown, NULL and inactive acting user Reason 8 for both; afterwards Users, App_Setting, Member_Type and Audit_Trail_Master as before, no ZZ57 row left, every identity counter put back.

Results on BMMS_Test (.\SQLEXPRESS, 2026-11-27): all four scripts parse under NOEXEC. Check before: step 57 Missing (0 of 3). Fix: "Step 57 installed ... References to another database or server: 0 (0 expected)". Test 57: 27 of 30 (before the owner decision of 2026-11-27; now 30 of 30, see below); the 3 rows of NCHAR(129) FAIL (Result 1, Reason 0: accepted), see below. Fix again: the same message. Check: step 57 Installed 3 of 3, every step Installed. Rollback: the two hashes above, equal to the values before step 57; Rollback again: refused ("nothing to roll back"); Test 57 refused (step 57 not installed); Check: step 57 Missing, steps 19, 21 and 40 Installed. Fix again, then Test 19 52 of 52, Test 21 100 of 100, Test 40 43 of 43, Test 57 27 of 30 (before the owner decision of 2026-11-27; now 30 of 30, see below) (the same three rows), Check: every step Installed.

Found (pre-existing, not changed): NCHAR(129) is accepted by both procedures, before and after step 57. On BMMS_Test (collation SQL_Latin1_General_CP1_CI_AS, code page 1252) U+0081 converts to VARCHAR and back unchanged, so the code-page rule does not refuse it, and it is not one of the 33 control characters. A call inside a rolled-back transaction with the step 19 and step 40 texts (after the Rollback, both reading spt_values) gave Result 1, Reason 0 in the organisation name, the member type code and the member type name. All 33 control characters gave Reason 3 in all three places.

Owner decision 2026-11-27 (NCHAR(129)): the requirement line "NCHAR(129) still refused (code-page rule, unchanged)" was wrong: NCHAR(129) was never refused. The expected result of the three NCHAR(129) rows of Test 57 is changed to "accepted: Result 1, Reason 0", as before step 57 (code page 1252 keeps 129, 141, 143, 144 and 157 unchanged; each row carries a comment saying so); the procedures are not changed and the row count stays 30. These rows check the unchanged behaviour; whether to refuse these characters is step CC1 (Known items). Re-run on BMMS_Test after the change: Test 57 30 of 30, Check: every step Installed.

What to run where:

1. Work Laptop `BMMS_Test`: BMMS-Check-InstalledSteps.sql (step 56 Installed, step 57 Missing), BMMS-Fix-DatabaseLocal-Step57.sql, BMMS-Test-DatabaseLocal-Step57.sql, then BMMS-Test-OrganisationSettings-Step19.sql, BMMS-Test-MemberTypes-Step21.sql and BMMS-Test-RoleAccess-Step40.sql.
2. The tester's baseline: `pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-DatabaseLocal-Step57.sql`.
3. Base Laptop: its local `BMMS_Test`, the same as 1.
4. Azure: redeploy BMMS_Test from the local copy (SSMS "Deploy Database to Microsoft Azure SQL Database"); this replaces the hand change of 2026-11-18. Test 57 may then run there.
5. `BMMS`: only after steps 38 to 56 are installed there, after the backup. Not on the Work Laptop's BMMS (step 37).
6. To undo (not on Azure): BMMS-Rollback-DatabaseLocal-Step57.sql, then BMMS-Check-InstalledSteps.sql. No build to roll back.

Reviewers (2026-11-27): security and ux Pass with notes, ui Not applicable (no markup, CSS or script). No High. Medium (both, the same point): the three NCHAR(129) rows of Test 57 fail against the requirement; pre-existing behaviour, settled by the owner decision above (expected result changed). Lows in Known items.
Re-review after the decision (security-reviewer, ux-reviewer, Test script and README): Pass, no High or Medium.

Tester (2026-11-27; baseline updated with step 57 by Update-Baseline.ps1: 53 step rows, all Installed, fixture check PASS; Tests\_results\2026-11-27_000952): access-matrix PASSED, 485 of 485 checks (448 access cells ok), error log 0 new lines.

Browser checks: tester: access-matrix. Owner by eye: Member Type add and edit with a normal value and with a pasted tab; System Settings organisation save with a normal value and with a line break in an address line; the messages as before.

Owner tests (Work Laptop, BMMS_Test, 2026-11-27): PASSED (Member Type add and edit saved; a pasted tab in the code and in the name refused with the same message as before; System Settings organisation save saved and kept after a reload; a line break in Registered Office Line 1 refused with the same message as before; error log no new lines).

## Step MF1: the minutes items on Finalize Minutes and Minutes Confirmation (code only, no database step)

Requirement: the owner's MF1 brief (D1 to D3, R1 to R10); plan approved 2026-11-27 with Q1 to Q5 as recommended and C1 to C7; the Finalize Minutes confirm texts T1 to T4 approved the same day.

- After Committee Name and Meeting No are chosen, both pages show a second card "Minutes Items": a read-only list (wb-table-scroll / wb-table, as the pending list of Agenda Finalize) with Agenda No, Subject No, Short Text, Decision and Actual Resolution, in Agenda No order, no sorting. A meeting without minute rows shows "No items in this meeting." The list is hidden when the committee or the meeting goes back to -Select- or changes, and on Cancel (C4; Cancel then goes to the Dashboard, as before).
- Data: the existing spr_GetMinutesByMeetingId(@MeetingId, -1, -1) (View_Minute, all departments, as Update Minutes reads it; no procedure changed). One shared method builds the list and its counts: MinutesMgr.GetMinutesItemList (BMMSBAL/MinutesMgr.cs, class MinutesItemList).
- A minute counts as saved when View_Minute.StatusId is 1 (Q1: the rule of fn_WorkflowState.MinutesUpdated; Agenda Finalize creates every minute with decision 3 Sanctioned and the proposed resolution, StatusId not 1). Cells (C1): a minute not saved shows "Not yet recorded" for Decision and Actual Resolution; a saved minute with nothing left after the conversion shows "Not recorded"; Subject No empty or 0 shows "-".
- Actual Resolution is shown as plain text: HtmlCleaner.ToPlainText (new, BMMSBAL/HtmlCleaner.cs; null or empty gives ""; the existing TagPattern; a block end or br becomes a space, an inline tag nothing; then HtmlDecode and one space for each run of white space; existing methods unchanged, C5). Every cell is encoded once, by HttpUtility.HtmlEncode in the ItemTemplate (C3). Short Text and Actual Resolution wrap between words (new shared rule `.wb-table > tbody > tr > td.wb-col-text` in bmms-workbench.css, overflow-wrap: break-word, Q3).
- Meeting No now has the handler ddlMeeting_SelectedIndexChanged on both pages (owner-approved exception to R9, Q2; AutoPostBack was already set). After Finalize or Confirm (success or refusal) the meeting stays selected, as before, and the list is read again; the page's message stays.
- Confirm texts, built on the server from the same rows (D3), fixed text and counts only (Q5), passed through HttpUtility.JavaScriptStringEncode. With no list shown, the markup's text stays.
  - Finalize Minutes. T1 (n > 0, all saved): "Do you want to Finalize this Meeting Minutes? Items: n." T2 (some not saved, a meeting created before step 23, which is finalized anyway): "Do you want to Finalize this Meeting Minutes? Items: n. Not yet saved in Update Minutes: m." T3 (some not saved, a meeting created after step 23, refused with Reason 19): "Items: n. Not yet saved in Update Minutes: m. These minutes cannot be finalized until every item is saved in Update Minutes. Nothing will be finalized." T4 (no minutes, refused): "This meeting has no minutes to finalize. Nothing will be finalized." Finalize stays clickable; OK posts back and the refusal shows as before.
  - Minutes Confirmation: "Do you want to Confirm this Meeting Minutes? Items: n."
  - C7: for T3 and T4 the message block shows the refusal in advance, with the warning look, when the meeting is chosen: for a meeting created after step 23 MeetingChangeReason.MinutesNotUpdatedMessage with the list's counts ("not saved/total"), only when its agenda is finalized and its attendance recorded (C8, approved 2026-11-27: otherwise the procedure refuses first with Reason 17 or 18, which is not forecast, so no warning; the three values from the same GetMeetingWorkflowState call); for an older meeting the page's own "No Minutes For the selected Committee/Meeting" (one constant, also used by btnFinalize_Click). Cleared when the committee or meeting changes, on Cancel, and by the message of Finalize. Which case applies comes from the existing MeetingMgr.GetMeetingWorkflowState (IsNew). No other refusal is forecast.
- C2, found before the build: spr_MinutesFinalizeByMeetingId refuses a meeting created after step 23 (fn_WorkflowState.IsNew) with no minutes or a minute not saved (Reason 19); an older meeting is finalized with minutes not saved; an older meeting without minutes is refused by the page. Unchanged.
- Not changed: the Finalize and Confirm behaviour, procedures, mails, alerts, audit rows, control ids, validators, UpdatePanels, the other onclick attribute (MinutesFinalizeValidation, see the UI2a item in Known items), PageAccess.xml, PageSettings.xml; no acting-user check added (D2).

Build checks (2026-11-27): the working tree built into the scratchpad (Debug, 0 errors, bin and obj untouched); the site precompiled with aspnet_compiler (0 errors); both again after the ux fixes. No SQL script, so no SQL parse and no Test script. C3 check (a scratch harness through HtmlCleaner.Clean, ToPlainText and HtmlEncode as the cell does, with the BMMSBAL.dll of the build): "&amp;" typed as text, "<b>x</b>" typed as text and "<script>alert(1)</script>" typed as text show literally, a real script tag is removed, nothing is encoded twice, Tamil unchanged, null and empty give "": 12 of 12 passed. Read-only checks on BMMS_Test: for all 21 meetings the View_Minute counts equal fn_WorkflowState MinutesTotal / MinutesUpdated and the rows of spr_CheckMinutesByMeetingId.

C8 found by a read-only query of BMMS_Test after the first owner report: every meeting without minutes there, and NRC 00003, would be refused for the agenda or the attendance first. Build and precompile again after C8: 0 errors, bin and obj untouched.

Reviewers (2026-11-27): security Pass, no finding; ux Pass with notes, two Medium (the advance warning of an older meeting without minutes used the Reason 19 text, and its counts came from fn_WorkflowState instead of the list) fixed and re-reviewed (Pass with notes, Low only; the stale comment it named fixed); ui Pass with notes, Low only. Low notes in Known items for later steps.

Tester (2026-11-27, Tests\_results\2026-11-27_115855; no baseline update, no database step): access-matrix, page-assets, dashboard, followup, followup-reports, manager-scope in that order PASSED, 940 of 940 checks (448 access cells ok, standing proof holds; the self-test's 3 planted checks caught and not counted in the 940), error log 0 new lines, no request outside localhost. No pack opens the Minutes Items list (access-matrix only opens the two pages); its looks are the owner's tests.

After C8 (2026-11-27): ux-reviewer on the MinutesFinalization.aspx.cs diff Pass (one Low, in Known items); tester access-matrix (Tests\_results\2026-11-27_121332) PASSED, 485 of 485 checks (448 cells ok, standing proof holds), error log 0 new lines.

Owner tests (Work Laptop, BMMS_Test, 2026-11-27, Chrome and Edge at 1366 and 1024 px): PASSED. T1 NRC 00002: no warning, confirm "Items: 1.", Cancel. T2 Secretarial Standards 00001: no warning, the T2 confirm, OK finalized. T3 Women Harassment 00004: the Reason 19 warning on choosing the meeting, the T3 confirm, OK gave the same refusal, the list stayed. T3 without attendance NRC 00003: no warning, the T3 confirm, OK gave the attendance message. T4 Test Committee for Board validation 00004: "No items in this meeting.", no warning, the T4 confirm, Cancel. Minutes Confirmation Audit Committee 00003: 12 items in Agenda No order, "Items: 12.", the confirm worked, the list stayed. The list hides on Meeting -Select- and on a Committee change; Cancel goes to the Dashboard; layout and card alignment fine; Actual Resolution as plain text; error log 0 new lines.

## Step SF1: Meeting No. column in the Sitting Fees report (code only, no database step)

Requirement: the owner's SF1 brief (R1 to R8: only a Meeting No column, no new filter); plan approved 2026-11-27 with D1 Designation option A (no Meeting No), header "Meeting No.", the Individual committee table 43/12/15/15/15, the Board table unchanged; D3 (owner, 2026-11-27, after the first proofs) replaces the approved Consolidated widths 12/6/9/8 by 12/7/9/10 with the member columns at 62.

- Every procedure the report reads already returns the meeting number: spr_GetAttendanceByMemberId (Individual) and spr_GetMeetingByFromToDate (Consolidated) select * from View_Attendance and View_Meeting, which have MeetingNo. No procedure, view or table changed, so no database step 58. The value is printed as stored (varchar(10), for example 00002), as the Meeting No pickers show it.
- Individual (BMMSBAL/PDF_Reports.cs, BindSitFeeTable): the committee table gets "Meeting No." after "Name of the Committee" (widths 43/12/15/15/15, the table still 80 percent of the page; one more empty cell in the TOTAL row). The Board table already shows the meeting number as "Board No." and is unchanged.
- Consolidated (GenerateSittingFeeConsolidated): "Meeting No." after "Name of the Committee"; the fixed columns 12/7/9/10 (they were 15/10/10), the member columns share 62 (they shared 65). One row is one meeting, so there is nothing to aggregate. A4 landscape as before.
- Designation: unchanged (one row per member with the total of many meetings; D1 option A).
- BMMS/Report/SittingFees.aspx.cs: the Tamil/Hindi check of Consolidated also reads MeetingNo, now printed (Individual already read it).
- Not changed: the amounts, totals, headers, signatory blocks, page size and orientation, the filter card, the role checks, the procedures.

Build checks (2026-11-27): HEAD (9f67b3c) and the working tree built into the scratchpad with MSBuild (Debug, OutDir and IntermediateOutputPath in the scratchpad; 0 errors; bin and obj untouched); both site copies precompiled with aspnet_compiler (0 errors). No SQL script, so no SQL parse and no Test script.

Proofs (2026-11-27, BMMS_Test, 01-Oct-2026 to 31-Dec-2026): the PDFs were made in two scratch site copies (HEAD and the working tree, IIS Express, Windows authentication to .\SQLEXPRESS BMMS_Test) by a scratch handler that calls the same BMMSBAL methods with the same inputs as SittingFees.aspx.cs (never in the repository); text by pdftotext -layout, page images by the Windows PDF renderer (Windows.Data.Pdf). Cases: Individual Ganesh Shankar (Board table), Individual Radha Ganesh (committee table), Individual All, Designation Director, Consolidated all committees.

- Amounts: every table row (its date and its amount cells, read in content order with pdftotext -raw) and every total (TOTAL, Board, Committee, Total Sitting Fees paid, the certificate's Rs. amount, the Designation TOTAL 23,000) equal before and after: Individual Ganesh Shankar 11 rows, Radha Ganesh 9, All 27, Consolidated 21; the Designation text is identical. Page counts unchanged (2, 2, 8, 1, 2).
- The new column is in the Individual committee tables and on every Consolidated row, the value as stored (00001 to 00004); the Board table unchanged.
- Words: with the approved 12/6/9/8 the Consolidated header broke as "Meetin" / "g No." and Place broke "Coimbatore" (it did not at 10 percent); D3 (12/7/9/10, members 62) was chosen from page images of both. With D3 no word of the Consolidated table is broken (every word checked against the committee names, places and member names of BMMS_Test and the header words), on both pages; 10000.00 and every member name (the longest, 14 characters) on one line; still 2 pages, header repeated on page 2 (the thin double line under the repeated header is there before SF1 too). Individual: "Meeting No." wraps at its space; the Place column breaks "Coimbatore" before and after (Known items).

Reviewers (2026-11-27, on the diff with the brief and the proof files; told that D3 changed the approved widths): security Pass, no finding; ux Pass, Low only; ui Pass with notes, Low only. No High or Medium. Low notes in Known items for later steps.

Tester (2026-11-27, Tests\_results\2026-11-27_171334; no baseline update, no database step): access-matrix, page-assets, dashboard, followup, followup-reports, manager-scope in that order PASSED, 940 of 940 checks (448 access cells ok, standing proof holds; the self-test's 3 planted checks caught), error log 0 new lines, no request outside localhost. No pack opens the Sitting Fees PDF (access-matrix opens the page only); its layout is the owner's test.

Browser checks: tester: the six packs above. Owner by eye: the three report types on BMMS_Test, 01-Oct-2026 to 31-Dec-2026 (Individual Ganesh Shankar and Radha Ganesh, Individual All, Designation Director, Consolidated all committees), on screen and printed.

## Known items for later steps

- Step SF1 (found on the way; list only, not changed): spr_UpdateAttendance ignores the "fee applicable" choice of Committee Member Tagging (Committee_Member.IsFeeApplicable): it copies ApplicableFee into the attendance row of a member marked present anyway.
- Step SF1 (list only): spr_AddEditCommitteeMember declares @ApplicableFee DECIMAL (that is DECIMAL(18,0)), so the fee is saved as a whole number and paise are dropped.
- Step SF1 (list only): spr_UpdateAttendance reads the fee with a subquery on Committee_Member by CommitteeId and MemberId; two tagging rows for one member on one committee would make the attendance save fail ("Subquery returned more than 1 value").
- Step SF1 (list only): the fee is copied into Attendance.SittingFees when attendance is saved (spr_UpdateAttendance), not read live; a later change of the tagging fee does not reach meetings already saved (until their attendance is saved again, which the meeting locks may refuse).
- Step SF1 (old, not changed): the Individual report's Place column (15 percent) breaks "Coimbatore" mid-word ("Coimbator" / "e"), before and after SF1. ui-reviewer (Low): a later step can give Place more than 15 percent and take it from the 43 percent of Name of the Committee (the longest name on BMMS_Test, "Women Harassment", fits with room to spare).
- Step SF1 ui-reviewer and ux-reviewer (Low): Consolidated shares 62 percent among every member column (65 before SF1, owner decision D3); proved with the 5 members of BMMS_Test only. With many members a long member name or an amount such as 10000.00 could wrap or break; check with a larger member count when one is available.
- Step SF1 ux-reviewer (Low, no change): a NULL MeetingNo would print an empty cell; Meeting.MeetingNo is varchar(10) NOT NULL on BMMS_Test (checked 2026-11-27), so it cannot happen there.
- Step SF1 (old, not changed): the Individual report's Board table shows the meeting number only; on BMMS_Test it lists two meetings numbered 00001 (Board Meeting and Test Committee for Board validation, both committees count as Board), which cannot be told apart in the table.
- Step SF1 (plan item 8; list only): Individual calls spr_GetTotAmtByMemberId up to three times per member and reads Rows[0] unguarded (safe today: a SUM without GROUP BY always returns one row); attendance of a hard-deleted member drops out of all three reports (View_Attendance inner-joins Member); a member deleted while the PDF is built would stop it at dtMember.Rows[0]; an empty or bad From or To date in the report type change (LoadMember) is outside any try; a damaged logo file makes the builder call GoToErrPage and still return a broken PDF to the pop-up.
- Step SF1 (list only): the Individual certificate amount (spr_GetTotAmtByMemberId, every MemberOf) and its tables (spr_GetAttendanceByMemberId, MemberOf 'C' only) can differ if a non-'C' attendance row ever has a fee (none on BMMS_Test today). Consolidated prints the amounts raw (1000.00, not 1,000) and gives every member of every committee a column, whatever the committee filter; with many members the columns get narrow.

- Step UI2b (Workbench form look for the 13 report filter pages; code only, no database step, so its entries are here only; owner's condition C8): on the report pages whose grid is not inside a panel (Committee Master, Meeting Master, Committee Member, Meeting Calendar and Sitting Fees Applicable) the grid's old frame (formContent / formPanel, kept outside .wb-page by R12) shows as an empty strip 14 px high (the 2 px border and the 10 px bottom padding of its .divRow) while the code-behind hides the grid: on Committee Master and Sitting Fees Applicable after a filter change until Submit, and on Sitting Fees Applicable from the start. Measured at 1366 and 1024 px, Chrome and Edge. Not fixed in UI2b (owner's decision); a later step can put the frame inside a panel or hide an empty frame.
- Step UI2b (found while measuring; fixed in the same step after the owner's test G1): .wb-page has min-height: 420px (room for the calendar pop-ups below short forms), so on the report pages with a short filter card the grid, below .wb-page, started 78 to 180 px below the card. The shared modifier .wb-page.wb-page-fit (min-height: 0, bmms-workbench.css) is on Committee Master, Meeting Master, Committee Member, Meeting Calendar, Sitting Fees Applicable and Attendance Details: the gap is 34 px (the card's 24 px margin and the frame's 10 px padding) at 1366 and 1024 px, Chrome and Edge. On Meeting Calendar the From and To pop-ups open whole, in front of the card, and end 9 px above the grid. Other pages that put a grid after .wb-page can take the same modifier.
- Step UI2b round 1 ui-reviewer (Low): on Meeting Calendar the To pop-up ends 9 px above the grid (1366 and 1024 px) and covers the Sort Option radio while open. It depends on the filter card's height and its bottom padding and margin; check the pop-ups again if that card or .wb-card spacing changes.
- Step UI2b (owner's test G2): the meeting number pickers are .wb-filter-meetno, 112 px, on Report/Reports.aspx, Report/Followup.aspx, Report/FollowupActionTaken.aspx (the menu's Followup by Department) and Master/Followup.aspx (the widest entry "- Select -" needs 106 px, a five-digit number 90 px, "- All -" 82 px; measured the same in Chrome and Edge). A six-digit meeting number (about 106 px) would still fit; a seven-digit one would not. The Subject No pickers of Reports and Followup by Department keep .wb-filter-short, 80 px: they hold subject numbers only (no "- All -" or "- Select -"); a one- or two-digit number needs 55 to 64 px and a three-digit one 73 px, but a four-digit subject number (81 px) would be cut. Give them the meeting pickers' treatment if a meeting can have 1000 subjects.
- SF1 (owner, a later step; noted in UI2b round 1): a Meeting No column in the Sitting Fees report and its view (no new filter).
- AD1 (owner, a later step; noted in UI2b round 1): a View button on Attendance Details (today the list shows when a meeting is chosen).
- Step UI2b (pre-existing, found in the inventory): Report/Followup.aspx.cs adds onclick="return MinutesFinalizeValidation()" to View, a function defined nowhere, so every View click throws a ReferenceError in the browser and posts anyway (as the UI2a item for Master/Followup); and View does not check an empty committee (btnViewFollowup_Click calls no CheckValidataion), only Generate does (Followup.aspx.cs CheckValidataion, "Select committee name."). The Committee Name * of UI2b stands for Generate's refusal. UI2b keeps the behaviour.
- Step UI2b (pre-existing): Report/CommitteeMember.aspx.cs calls Common.InitSetup("CommitteeMember"), the entry of Master/CommitteeMember.aspx in PageSettings.xml, so the session's PageURL is ~/Master/CommitteeMember.aspx on the report page (the tab title "Committee Member" is right; PageURL is no longer read, see ErrorPage.aspx.cs and Utilities.cs). Give the report page an entry of its own when it is next touched.
- Step UI2b (pre-existing): the Title= attributes of the @ Page directives are stale ("Untitled Page" on Reports, Followup, SendMail, Committee Master, Meeting Master and Notice; "Sitting Fees Applicable" on Sitting Fees). Main.Master sets Page.Title from the session's PageTitle on every page, so nobody sees them; tidy them in a later step.
- Step UI2b (pre-existing): Report/SittingFees.aspx had width="100%;" on its first table (an invalid attribute value); the table is gone in UI2b, the item stays for the other old-look pages that copy the pattern.
- Step UI2b (pre-existing): Report/FollowupActionTaken.aspx: ddlSubjectNoFrom and ddlSubjectNoTo have AutoPostBack="true" and no OnSelectedIndexChanged handler, so each change posts the page back for nothing. UI2b keeps them (R1).
- Step UI2b (inventory; list only, none changed): pages still in the old look (no .wb-page): ChangePasswordFirst.aspx, Master/Attendance.aspx, Master/BackupDatabase.aspx, Master/ChangePassword.aspx, Master/ResetPassword.aspx, Master/SMTPServerConfig.aspx, Report/AuditTrail.aspx, Report/ViewReport.aspx, Error/ErrorPage.aspx.
- Step UI2b ui-reviewer (Low): on the rows with a radio list (Meeting No., Subject No., Meeting No. Search, Subject No. Search, Confirmed Status, View Format, Report Type, Sort Option) the radio text sits about 8 px above its label's text (1024 px, Chrome: radios at y=348, label at y=356 on Reports): .wb-label keeps its padding-top for a 40 px field and .wb-radio-list has no matching offset. Same on Minutes > Followup since UI2a. Align them in one shared rule in a later CSS step.
- Step UI2b ui-reviewer and ux-reviewer (Low, as the UI2a item for Followup): the radio rows have a div.wb-label, not a label element, so a screen reader has no group name for the radio lists; and the picker rows that follow a radio row on Reports (Meeting No. and Subject No. pickers) and the Meeting No. row of Report/Followup have no label for the drop-downs (an empty label column or a div). Option: role="group" with aria-labelledby for the radio lists and a label for the pickers.
- Step UI2b ux-reviewer (Low): the line "The notice opened in a new window; allow pop-ups if it did not." (Notice, pnlNoticeDownload) and "The agenda details opened in a new window; ..." (Agenda Approval, pnlAgendaDetailsDownload) is plain text under the buttons in the card, without message styling, so it is easy to miss. Option: the page's message block (Notice has one; Agenda Approval has none, decision Q5) or a shared muted-note class.
- Step UI2b ux-reviewer (Low, pre-existing): Sitting Fees has no message block (decision Q5); its refusals stay alert() pop-ups (SittingFees.aspx.cs), while From Date and To Date now carry the Masters' * marker. The dates are filled when the page opens and cannot be cleared.
- Step UI2b ux-reviewer (Low): on Report/Followup the * of the date range is in "Meeting Date From" only (D4: the marker moved from after the To date into the label), as on Minutes > Followup (UI2a item). Both dates are filled when the page opens and cannot be cleared.
- Step UI2b ux-reviewer (Low, pre-existing): Send Mail keeps Style="visibility: hidden" on the Add Attachment button (the upload script clicks it), an inline style kept under R1; it still takes its width in the Attachment row. A later step can hide it with a shared class.
- Step UI2b ui-reviewer (Low, pre-existing): the disabled Subject No. radios and pickers on Reports and Followup by Department are shown only as grey (the browser's disabled look); unchanged by UI2b.
- Step MF1 (owner decision Q3): the Minutes Items list wraps Short Text and Actual Resolution with overflow-wrap: break-word; in the grid's auto layout one unbroken string longer than the column (a long URL) widens it, and the list then scrolls sideways inside .wb-table-scroll. Normal sentences and Tamil wrap.
- Step MF1: the list is sorted by Agenda No as text (View_Minute.AgendaNo is varchar(50)); right for the zero-padded codes (C01-00001-001), but an all-digit Agenda No of older data would sort 10 before 2 (none on BMMS_Test, checked 2026-11-27).
- Step MF1: the counts of the list and the confirm come from View_Minute, the server's refusal from fn_WorkflowState (Reason 19) or spr_CheckMinutesByMeetingId (older meetings). Equal for all 21 meetings of BMMS_Test (2026-11-27); they would differ only for a minute whose decision type, committee, meeting or department row is missing (View_Minute joins them).
- Step MF1 ux-reviewer (Low): on Minutes Confirmation a meeting with 0 items gives "Do you want to Confirm this Meeting Minutes? Items: 0." and no hint; the page then refuses as before (minutes not finalized). Option: a sentence for n = 0.
- Step MF1 ux-reviewer (Low): the Minutes Items list has no caption or read-only note (as the Agenda Finalize list).
- Step MF1 ux-reviewer (Low, after C8): a meeting created after step 23 whose agenda is not finalized or whose attendance is not recorded still gets the T3 or T4 confirm ("Nothing will be finalized", true: Reason 17 or 18 refuses) but no advance warning; the reason shows only after OK. As C8 decided. Option: a neutral confirm text for these cases.
- Step MF1 ui-reviewer (Low): the default confirm text is now in two places, the markup's OnClientClick and DefaultConfirmText in the code-behind of each page; keep them equal if one is edited (or set it in one place).
- Step MF1 ui-reviewer (Low, optional): the new td.wb-col-text rule also sets word-wrap: break-word, the legacy alias of overflow-wrap (as several other rules of the file).
- Step CC1 (later, before the fresh install): spr_SetOrganisationSettings and spr_AddEditMemberType accept the C1 characters 129, 141, 143, 144 and 157; decide whether to refuse 128-159 or these five. (Found in step AZ2: of 128 to 159 exactly these five survive the code page 1252 round trip on BMMS_Test, checked 2026-11-27; the three NCHAR(129) rows of BMMS-Test-DatabaseLocal-Step57.sql expect them accepted, and change with step CC1.)
- Step AZ2: the Azure copy of BMMS_Test (step 51) has an undocumented hand change of 2026-11-18 (view dbo.vw_spt_values_P, both procedures reading it, markers kept), not in git. The redeploy from the local BMMS_Test after step 57 replaces it; check afterwards that dbo.vw_spt_values_P is gone.
- Step AZ2 (pre-install guard audit): BMMS-Fix-OrganisationSettings-Step19.sql, BMMS-Fix-MemberTypes-Step21.sql, BMMS-Fix-RoleAccess-Step40.sql and BMMS-Rollback-RoleAccess-Step40.sql still contain master.dbo.spt_values and do not stop while step 57 is installed; a re-run brings the reference back (step 57 Partly). Add guards in the guard audit before the fresh install.
- Step AZ2 (house rule): spr_SetOrganisationSettings keeps THROW in its CATCH block, against the house rule "no THROW" (compatibility level 100 lists THROW as not allowed); kept by owner decision for identical behaviour. Replace it with RAISERROR in a later step (Test 19 and Test 57 then change).
- Step AZ2 security-reviewer (Low): BMMS-Fix-DatabaseLocal-Step57.sql prints "Step 57 installed" also when the count of references to another database or server is above 0 (it shows the count with "(0 expected)"; BMMS-Check-InstalledSteps.sql then reads step 57 Partly). Raise a message naming the count when it is not 0.
- Step AZ2 ux-reviewer (Low): the third guard message of BMMS-Fix-DatabaseLocal-Step57.sql names both procedures and both markers in one line; one message per procedure (or the missing marker printed) would say which one failed.
- Step AZ2 ux-reviewer (Low): a re-run of Fix 19, 21 or 40 after step 57 shows nothing on screen about step 57 (only the Check reads Partly); covered by the guard audit item above.
- Step AZ1 (open): the Backup Database page on Azure (BACKUP DATABASE TO DISK does not run on Azure SQL Database): hide it or explain it there.
- Found 2026-11-26 during AZ1 owner tests (pre-existing; small later step): Agenda Details "Generate" fails for the whole report when one attachment file is missing on disk (System.IO.IOException in Report/Reports.aspx.cs, CreateAgendaDetailsPDF; seen for Attach-C01-00001-001-...pdf, not present in BMMS\Files\AgendaAttach on the Work Laptop). Skip the missing file with a note in the report instead of failing.
- Step AZ1 ui-reviewer (Low, optional cleanup): JScript/ddlevelsmenu.js keeps httpsiframesrc "blank.htm" and the shim code (addshimmy, positionshim, hideshim), dead with enableshim false; a later cleanup may remove them.
- Step AZ1 ux-reviewer (Low): after a pull the site shows only the generic "BMMS - Error" page until the solution is built (the DLLs leave BMMS\bin); the build-first line is in this README, the step's owner report and the CHANGELOG entry, nothing in the site.
- Step AZ1 ux-reviewer (Low; before the fresh install): the full licence texts beside the DLLs: MPL 1.1 and LGPL for iTextSharp 4.0.2 (Lib\iTextSharp) and Ms-PL for AjaxControlToolkit (Lib\AjaxControlToolkit). Today each README.txt names the licence as "to be confirmed": no licence text came with either copy.
- Step AZ1 security-reviewer (note, no finding; for the pre-install security pass): iTextSharp 4.0.2 and AjaxControlToolkit 1.0.20229 stay at their old versions; review them (known vulnerabilities, upgrade path) in the security pass before the fresh install.

- Step UI2a (Workbench form look for Agenda Finalize, Finalize Minutes, Minutes Confirmation and Minutes > Followup; code only, no database step, so its entries are here only; pre-existing, found in the inventory): the code-behind adds onclick="return AgendaFinalizeValidation()" (Master/AgendaFinalization.aspx.cs) and "return MinutesFinalizeValidation()" (Master/MinutesFinalization.aspx.cs, and Master/Followup.aspx.cs for View), but neither function is defined anywhere. On Finalize the confirm's own "return" runs first, so the missing function is never reached; on Followup, View throws a ReferenceError in the browser and the page posts anyway. Remove the two Attributes.Add lines or define the functions (Committee Name and Meeting No required) in a later step; UI2a keeps the behaviour.
- Step UI2a (pre-existing): the browser tab title is the PageTitle setting followed by the page title with no separator ("BMMS - Board Minutes and Meeting SoftwareFollowup"): Common.InitSetup joins AppSettings.xml PageTitle and PageSettings.xml pageTitle as they are. A page with no PageSettings.xml entry kept the previous page's title (fixed for Minutes Confirmation and Followup in UI2a; check the other pages when they are next touched). Add a separator (" - ") once for every page.
- Step UI2a (candidate UI3): the Followup list to the Workbench look as one piece: the grid (contentTable1, its old frame formContent / formPanel, which starts 10 px inside and ends 16 to 21 px inside the filter card at 1366 and 1024 px), Submit (primary look from .wb-actions, but outside .wb-page so its font is the frame's Verdana, 98 px wide against the Masters' 96 px, and it starts about 216 px in from the .wb-actions padding), the three panels (Actual Resolution, Action Text, Reopen) and the Status column items (no sort link; 220 px, about 216 px at 1024 px). Kept outside .wb-page in UI2a so its rules do not reach them (decision D6).
- Step UI2a ux-reviewer (Low): on Followup the * of the date range sits in the label "Meeting Date From" (D4: the marker moved from after the To date into the label), so it can read as if only From is required. Both dates are filled when the page opens and cannot be cleared. Option: the label "Meeting Date From / To" if the owner sees it.
- Step UI2a ux-reviewer (Low, pre-existing): the Followup date boxes keep onfocus="this.blur()" and TabIndex="-1" and the calendar opens from an image button, so a keyboard user can neither type a date nor tab to the picker; the label's for= points at a box that cannot take focus. As on the Masters' date fields (Committee Master). For UI3 or a keyboard step.
- Step UI2a ux-reviewer (Low): Meeting No. Search, Meeting No. and Confirmed Status on Followup are div.wb-label (as the Masters' date labels), not label elements, so a screen reader has no group name for the radio lists and the meeting number pickers. Option: role="group" with aria-labelledby, or label for the single-control case.
- Step UI2a ux-reviewer (Low, pre-existing): on Followup the message box is above the filter card, so after a long list the message of Submit or Reopen shows far from the button; the page has no scroll or focus to the message. For UI3.
- Step UI2a (tester): the dashboard pack expects the fixture as restored, and the followup pack writes (an action text Save, a Confirm and a Reopen). With followup listed before dashboard in one run (2026-11-26_174407), 19 dashboard checks missed the action item QA1-00005-002 and a dashboard step then timed out, so the run was VOID; in the order access-matrix, page-assets, dashboard, followup, followup-reports, manager-scope (as in UI1) the packs run as designed. The order is now named in Tests/README.md (UI2a); a runner that puts dashboard before the packs that write would remove the trap.
- CAL1 (owner's UI2a tests, pre-existing, seen before UI1): on the Masters with date fields the calendar pop-up opens behind the next field (Committee Master, Cessation Date). The Followup calendars open in front. For a later step.
- MF1 (done in step MF1, see its section): Finalize Minutes and Minutes Confirmation show the minutes items of the chosen meeting before Finalize or Confirm.
- MD Secretariat and the action item rows (found 2026-11-26, read-only check after UI2a; pre-existing since step 43): spr_MinutesFinalizeByMeetingId writes an ActionItem_User_Map row for every user of fn_FunctionalUsers (step 55: active, not the system account, not the Admin role), MD Secretariat included, but MD Secretariat can never open an action item from the Dashboard (fn_DashboardActionItemScope gives no rows; spr_GetDashboardActionItems answers Reason 4 and the card is hidden). The rows hold only a read state and are never shown (BMMS_Test: mduser 4 rows, ra1mdsec 3). The Governance Matrix shows the mismatch: AIR (who receives them) lists MD Secretariat, AIS (who can open them) does not. Decide with GM1b / RS1: drop md_sect from the finalisation rows, or accept and document it.
- Step UI1 (pre-existing, found while measuring): Committee Master, Add fails with "Conversion failed when converting the varchar value 'A9' to data type int" when a committee code is not a number after its first letter (BMMS_Quality has QA1, QA2, QA9): CommitteeDB.GetNextCommitteeCode / its procedure converts the code to int. The page shows the server-error message; nothing is saved. Not seen on BMMS_Test (its codes have numeric suffixes; the owner's Add test passed there on 2026-11-26). Fix the next-code rule for non-numeric codes.
- Step UI1 owner tests (Low): the label inset differs by page type: 16 px on the Masters (.wb-card-body padding) and the .divRowLeft pages (F1), 12 px on the table filter pages (td.Lable, from the tables' cellspacing="12"). Option: a 4 px left padding on td.Lable.wb-label, or cellspacing 16, checked page by page.
- Step UI1 owner tests (Low, pre-existing): the wide tables (Governance Matrix, Committee Master list) scroll sideways inside their card at zoomed or narrow widths; not part of UI1 (W1 to W3 only).
- Step UI1 ui-reviewer (Low): on Agenda Finalize, Finalize Minutes, Minutes Confirmation and Attendance Details the drop-down (wb-filter-select, width 100% up to 300 px) and its * share the 50 % .divRowRight; below a content area of about 600 px the * wraps under the drop-down. Option: width auto for a wb-filter-select inside .divRowRight.
- Step UI1 ui-reviewer (Low): the label and field cell proportions of the table filter pages (Followup, Reports, SittingFees, SendMail, FollowupActionTaken) follow the 200 px label column now that the old percentage widths are gone; measured at 1366 and 1024 px only for Followup (both), Reports and FollowupActionTaken.
- Step UI1 ux-reviewer (Low): on the .divRowLeft pages the label line height is 1.45 (as the Masters) and the field's is 18 px (CommonHTML.css), so a label may sit 1 to 2 px off the control's baseline; option: 18 px for div.divRowLeft.wb-label if the owner sees it.
- Step UI1 F1 ui-reviewer (Low): the 16 px left margin of div.divRowLeft.wb-label is a second rule block after the companion label rule (same elements); merge the two when the rule is next touched.
- Step UI1 ux-reviewer (Low): wb-filter-select has min-width 12em, so below about 800 px a filter row of the table pages may still pass its card (the step covers 1366 and 1024 px).

- Step GM1a (C7, pre-install security pass): Agenda finalisation, Minutes update, Minutes finalisation and Minutes confirmation are guarded only by PageAccess.xml (and the menu): spr_AgendaFinalizeByMeetingId, spr_UpdateMinutes, spr_MinutesFinalizeByMeetingId and spr_MinutesConfirmByMeetingId take no acting user (or do not check its role), so nothing in the database refuses another role. Add the acting-user and Controller checks in the procedures.
- Step GM1a gate B (pre-install security pass): spr_sys_ResetDatabase fails as bmms_app at its first DBCC CHECKIDENT (error 2557, "User 'bmms_app' does not have permission to run DBCC CHECKIDENT for object 'ActionItem_User_Map'"; existed before step 56: DBCC CHECKIDENT needs table ownership or db_owner / db_ddladmin, which bmms_app has for no table). Proven on BMMS_Test 2026-11-25 with EXECUTE AS USER = 'bmms_app' in a transaction rolled back (data and identity counters unchanged). Fix to decide: module signing (certificate) or run the reset only from the install script as dbo. Do not grant db_ddladmin or db_owner to bmms_app.
- Step GM1a gate B (Low): the Management "Dashboard (read only)" mark in the Read-only access block comes from a one-line list in GovernanceMgr.cs (DashboardReadOnlyRoles), not from the rule itself (fn_DashboardActionItemScope, spr_SaveDashboardActionText).
- Step GM1a owner test 2 (Low): in the PDF export the headings ("Settings", "Who enters and who approves", "Read-only access") touch the top border of their tables (iTextSharp HTMLWorker ignores the paragraph spacing); the PDF of the full matrix is long (13 pages on BMMS_Test). Options: a spacer paragraph or the PdfPTable builder; a filtered export, or landscape pages in the PDF.
- Step GM1a owner test 2 (pre-existing, every page): the browser title is the PageTitle setting followed by the page's title from XML/PageSettings.xml with no separator ("BMMS - Board Minutes and Meeting SoftwareGovernance Matrix"; the Dashboard "...SoftwareDashBoard"); a page without an entry there (Audit Trail, System Settings, for example) keeps the title of the page opened before. Option: a " - " in Common.InitSetup and an entry for every page.
- Step GM1a owner print test (Low): the page prints landscape through a print-only style the page adds to its own head (@page { size: landscape }); the print dialog's Layout setting can override it. The first named-page version left the first sheet blank in Chrome and Edge and was replaced. The tables use fixed column widths in print (matrix 14/12/15/19/15/25 percent, change log 12/13/12/13/12/14/14/10); a very long login can still break inside. The table header fill is not printed while "Background graphics" is off (bold text and the border line remain).
- Step GM1a owner tests (Low): on a past date the heading "As on <date>, end of the day" is repeated as the first note line ("As on <date>, end of the day. The rules are those installed now."); the note line could read only "The rules are those installed now."
- Step GM1a print fix review (UI Low): in print the header row of the matrix and change log does not repeat on the following sheets (a GridView renders it in tbody, no thead) and a row can split across two sheets (no break-inside: avoid); the Settings table keeps the automatic layout (two short columns); print keeps the 14px screen font. Options: break-inside: avoid on the rows; UseAccessibleHeader with TableSection = TableHeader and thead rules (the screen selectors .wb-table > tbody > tr > th need thead equivalents first); 12px in print.
- Step GM1a owner-test fixes review (UX Low): a reload (F5) after a Show or a view change re-sends the form ("Resend?") and keeps the choices, as for every postback; a fresh visit, a reload of a fresh visit and Back start from the defaults.
- Step GM1a: the matrix for an earlier day applies the rules installed now (the page says so); on BMMS_Test the Manager rule changed on 23-Nov-2026 (step 53), after the history start of 09-Nov-2026. On BMMS the steps go in together before the history starts.
- Step GM1a review (security Low): spr_SetAppSetting (step 16 text) and spr_sys_ResetDatabase (step 39 text) keep their THROW lines (compatibility level 110); step 56 kept them unchanged. Replace with RAISERROR when those texts are next replaced.
- Step GM1a review (security Low): spr_DeleteDepartmentByDeptId still takes no acting user (Department Master is an Admin page; C1 covered the save only) and writes no log row; a deleted department drops out of past-day matrices (only a department never mapped can be deleted). Add @ActingUserId (Reasons 8, 4) and decide on a log row in a later step.
- Step GM1a review (security and UX Low): the change log range has no upper limit and no paging; a range of years returns and exports every row in one request (Admin and Controller only). Option: a cap on the range or the rows, or paging.
- Step GM1a review (security Low): BMMS-Rollback-GovernanceLog-Step56.sql (like the Rollbacks of steps 54 and 55) checks only that step 56 is installed and compares the seven texts at its end; a later change to one of them would be overwritten. A pre-check per text could refuse instead.
- Step GM1a review (security Low): the page's default As-on date is the web server's date and the "today" of the procedures the database server's; on two machines with clocks across midnight the default could be refused as after today (Reason 33) for a moment.
- Step GM1a review (UX Low): "Enter a valid date (dd-MMM-yyyy)." and "Enter valid From and To dates (dd-MMM-yyyy)." do not name the field that is wrong.
- Step GM1a re-review (UX Low): after a refused or failed read of the change log filters the filter row stays visible with empty lists, and Show then reads the log without a user or department filter (the message above says the filters did not load; the next click on Change log loads them again). Option: hide the filter row until they are loaded.
- Step GM1a review (UI Low): the active view button differs by the primary / secondary button style and aria-pressed only; the date boxes open the calendar on click without a calendar icon (the Matrix help line says so; the change log view has no such line).
- Step GM1a: the Followup row lists MD Secretariat as "can open the page to read only" from a list kept in GovernanceMgr (ReadOnlyRoles), because PageAccess.xml lets MD Secretariat open the page and only the procedures refuse its saves.

- Step IU1 owner tests (2026-11-25): an Admin who shares an e-mail address with other users receives their mails (the data of BMMS_Test showed this before the addresses were made unique). Before the fresh install, check that every user has an address of his own (with gap D).
- Step IU1 review (UX Medium, accepted by the owner for IU1, 2026-11-25): a Meeting or Committee mail that reaches only some of the alert users (the others have no address) still says "Successfully Saved"; only when nobody has an address does the page say "No mail was sent because there were no recipients." Later step ML2d: a "sent to N of M" message for all mails (the procedures that build the lists to return the counts).
- Step IU1 review (UX Low): when the person who saved has no address (or is the system account) but there are Bcc recipients, the Committee and Meeting pages show the general "the mail could not be sent" warning (the ML2c rule, unchanged); the cause is only in the error log of Mail_Mgr.
- Step IU1 review (UX Low): Reset Password: when spr_GetResetPasswordMail refuses after the reset (a race: the user deleted, the acting user made inactive), the page says "The password was reset to the default password, but the mail could not be sent. ..." even for an inactive user; the Reason is in the error log.
- Step IU1 review (UX Low, pre-existing; backlog by the owner, 2026-11-25): the Reset Password success text reads "New passward was sent through mail." (typo for "password"); unchanged in IU1 because the other messages were to stay as they are.
- Step IU1 review (security Low): spr_GetResetPasswordMail follows the reset rule (fn_UserChangeRefusal 'ResetPassword'), which lets any active role read its own address and status (acting user = target); the page is for the Admin only. Add an active-Admin check if the procedure should refuse it.
- Step IU1 review (security Low): BMMS-Rollback-InactiveUsers-Step55.sql (like the Rollback of step 54) writes the three texts back without first checking what is installed, and compares them only at its end; a later change to one of them would be overwritten. A pre-check (each text carries InactiveUsers-Step55 or has the hash it restores) could refuse instead.
- Step IU1 review (security Low): the Meeting and Committee Bcc is read again after the save (spr_GetMeetingCommitteeMailId), not from the alert rows of the event; a status or role change in the same moment could make the two differ by that user. The save procedures could return their AlertId and the mail read Alert_User_Map.
- Step IU1 review (security Low, pre-existing): spr_AddEditCommittee does no acting-user check and returns no Result / Reason (G6).

- Step UD1c owner tests (pre-existing since step 25, possible enhancement): Agenda Summary and Agenda Details open as a PDF only (Generate stores the PDF and opens ViewReport.aspx?pdf=1, which streams it), so they have no Export to Word and no Export to Pdf / Print buttons of their own; the browser's PDF viewer prints them. Minutes and Minutes Extract open the HTML view with Print, Export to Word and Export to Pdf.
- Step UD1c review of the manager-scope pack changes (UX Low): the HRD row check says "(compared as a set)" without "sorted" (the other two say both); the full-postback wait is chosen by matching the page pattern's text (an explicit flag would not depend on how the pattern is written); a full postback that does not load a new page would show only a 60 s timeout. Optional.
- Step UD1c review of the manager-scope pack (UX Low): several checks record expected and seen as JSON objects ({"shown":true,...}); the owner has to read keys to find the one wrong value. Option: a short sentence per value.
- Step UD1c review (UX Low, wording): Test 44 check 15 now reads "rows not by the rule / rule items without a row" with "0 / 0"; spelling out "function rows the rule does not give him / items the rule gives him without a function row" would read more easily. Test 33 check 3 names fn_ManagerDepartments in its title; "[since step 54: every department he is a Manager of]" would say it in words.
- Step UD1c re-review (UX Low): after the Agenda Entry or Reports page has shown that the Manager's departments could not be read, a change of Committee or Meeting hides the message (MsgHide) while Add (or View, Generate and the Department choice) stays disabled. Option: show the message again, or give the disabled button a tooltip.
- Step UD1c review (security Low): spr_GetAgendaByMeetingIdDeptId does not check that @UserId is an active account other than the system account (the step 33 text did not either); the other new read procedures do (Reason 8 / 4). Not exploitable (the page passes the session user, read from the database on every request since step 51; fn_ManagerDepartments gives no rows for an inactive Manager). Add the acting-user check when the procedure is next changed.
- Step UD1c review (UX Low): the Agenda Entry card note "Items of your departments and the items you entered." stays the same when one department is chosen in the filter (the list then holds that department's items and the items he entered in it). Option: let the note follow the filter.
- Step UD1c review (UX Low): a Department change in User Master sets the Reporting Person to "- Select -" without a line saying so. Option: a short note.
- Step UD1c review (UX Low): a report refused for a department that is not the Manager's (only a stale or posted value) says "You are not allowed to see this report." without naming the Department choice.
- Step UD1c review (UX Low): a Manager without an active department sees his home department fixed on Add and is refused only at Save (Reason 30). Option: say so at Add.
- Step UD1c review (UI Low, by eye): a Manager's Agenda Entry strip has four cells (Committee, Meeting, Department, Add) and wraps at 800 px; long department names may be cut. The Reports Department drop-down keeps its inline width of 300 px, and "(home)" / "(inactive)" make the entries longer (to UI1).
- Step UD1c (owner answer 12): spr_GetMgrControllerByDeptId (step 14) stays in the database but is no longer called (User Master reads spr_GetReportingPersonList); BMMS-Test-UserStatus-Stage2a.sql still tests it. Remove it with its test in a later clean-up step.
- Step UD1b review (security Low, race): spr_AddEditAgenda reads the department's Managers without a lock; a deactivation of the last Manager at the same moment can leave a new item at AC with nobody to approve it (the Controller can still reject it), as for the Reason 11 check of step 20. Option: read the department's open User_Department rows WITH (UPDLOCK, HOLDLOCK) in the Save branch.
- Step UD1b review (UX Low): the Released part of a successful User Master detail is added before the 2,000-character cut; with very long department lists it can be cut and the page then says only "Successfully Saved".
- Step UD1b review (UX Low, by eye): the handled line is added to any other line of the Agenda Alert panel (for example the meeting-date line), joined by a space.
- Step UD1b review (UI Low): the greyed handled row also greys its Source link to the muted colour, so it looks less like a link (it still works).
- Step UD1b re-review (UX Low): the Rollback's count of items nobody could decide is a PRINT just before its closing line; it is easy to miss when the output scrolls. Option: put the count in the closing line.
- Step UD1b review (UI Low): a handled row is never bold; it differs from an ordinary read row only by its italic line and muted text (the words carry the state).
- Step UD1b review of the System Settings Save messages (UX Low, wording, optional): "will be refused" does not say that the User's new item is not saved ("will not be saved" would), and "the Controller" is singular while the item goes to every active Controller. The generic failure message "Not saved: the value is not valid." also shows for an unexpected failure (unchanged since step 39).
- Step UD1b owner tests (pre-existing, AMA label): an item that goes straight to the Controller (route C, or route M changed to the Controller by the setting "Department without an active Manager") shows the status "Manager Approved" at AMA although no Manager approved it. The label belongs to the AMA status, not to step 53.
- Step UD1b owner tests: when the Controller moves an item to another department, the greyed alert line of the old department's Managers ("Item moved to another department ...") still shows the old department in the row.
- Step UD1b owner tests (to UI1): the Dashboard Meetings card at narrow widths scrolls its table inside the card, so the "Waiting for me" column is off-screen until the card is scrolled sideways.
- Step UD1b documentation stage (document tools): since Microsoft Edge 158 (November 2026) the Mermaid check of Documents/_build/Check-Documents.ps1 fails on the development laptop (Edge exits at once with code 0 and keeps running, so every block fails and the work folder Documents/Export/_check stays locked). Workaround: -Edge "C:\Users\HP\.cache\puppeteer\chrome\win64-157.0.8103.50\chrome-win64\chrome.exe" (puppeteer's Chrome for Testing); System-Manual/02-Development-Environment.md, "Document tools". Export-Documents.ps1 uses the same browser search and needs the same -Edge. Option: let DocTools.ps1 fall back to that browser, or stop the browser it started before deleting the work folder.

- Step DA1 (documentation audit tooling; no database step, so this is its only entry here): (1) the doc-auditor guard (.claude/hooks/doc-auditor-guard.ps1) does not compare the date of the run folder DA-<yyyymmdd>-<short SHA> with today, so that a continuation on a later day writes the same folder; any 8-digit date with the current HEAD SHA is accepted (owner, DA1 gate B: accepted). (2) The doc-writer guard (.claude/hooks/doc-writer-guard.ps1, unchanged in DA1 by the owner's decision) has no read rule for protected files: unlike the doc-auditor's, it does not refuse reads of connectionStrings.config or of files under Log\ and App_Data\, nor git options that read a working-tree file (blame --contents); a later step.
- Step MR1: the meeting-date rule (fn_AgendaWaitingFor DateOpen, rule 12 Kinds 'P' and 'Q', Reason 28) uses the database server's date (CAST(GETDATE() AS DATE)); on Azure SQL Database that is UTC, so near midnight India time an item can turn "past" up to 5 hours 30 minutes early or late. Part of the Azure hosting item (no item of that name was found in this repository; the owner's backlog).
- Step MR1 review (UX Low, text change): for the last Manager of several departments each count reads "(n items of the department waiting)" and the line ends "give the department another active Manager first" (singular); "of HRD" per count would be tighter. Optional.
- Step MR1 review (UX Low): a Manager of very many departments: the department part is cut at 2,000 characters in the database, with no sign that it was cut.
- Step MR1 review (UI Low): the message box is bold throughout; with three parts the long "past meetings" line makes a dense block, and the header is set apart from the parts by a line break only. For the owner's by-eye test.
- Pre-install install-all script (backlog, found in step MR1): audit every Fix script's re-run guard. The step 44 Fix script accepted any text carrying its own marker and so silently replaced texts of later steps that kept that marker (steps 45 and 52 on BMMS_Test, repaired; see the step MR1 section). Steps 39 and 44 are now guarded against step 52 only; other Fix scripts whose text check accepts "already this step's text" by marker (for example 42, 43, 45, 47, 48) can do the same to a later step that replaced one of their objects. Before an install-all script runs every Fix in order, each needs a guard naming the later steps that hold its objects, or a check of its own exact text (SHA-1) instead of the marker.
- Step MR1: the Controller can close a past-meeting item only by finalising the meeting's agenda (Agenda Finalization rejects every item not yet approved); a single Reject on the Dashboard stays refused after the meeting date for every role (step M6a, owner answer 2).

- Step RA1d: the Audit Trail shows a session ended by the check as a normal sign-out (Audit_Trial_Login Login_Status 'C' and the logout time) with no reason; the reason is only in PageAccessLog.txt.
- Step RA1d: Session_End (spr_AddEditAuditTrialLogin) closes every open login row of the user, also those of another browser in which the user is still signed in (as Logout does).
- Step RA1d: when the report pop-up (Report/ViewReport.aspx) is the next request after a change, the sign-in page opens inside the pop-up window.
- Step RA1d, for the pre-install security pass (security Low): PageAccessModule checks only paths ending in .aspx. The project has no .ashx, .asmx or .svc today; a future handler type (.ashx, .asmx, .svc or other) must be added to the check (login, role and session checks; a handler without session counts as not signed in) in the same step that adds it.
- Step RA1d, for the pre-install security pass (older code): the session id is not renewed at sign-in (Default.aspx keeps the session id the browser had before signing in).
- Step RA1d review (security, older code): the expired cookie of an ended session is HttpOnly but not Secure, as the session cookie itself (no requireSSL on this site).
- Step RA1d review (security Low, check 44): with "0 0" expected, BMMS-Test-SystemAccount-Stage3.sql check 44 also passes when spr_GetAlertMailId returns an empty ACA list for any reason; a third count for a recipient who must get the mail (the Controller or a mapped ordinary user) would show the list is built. Changes the check beyond RA1d: owner's word needed.
- Step RA1d (backlog, Low): Convert.ToInt16(Session["UserId"]) remains on ChangePasswordFirst, Logout, AgendaFinalization, BackupDatabase, ChangePassword, MinutesUpdate, ResetPassword and Report/Followup; it fails for a UserId above 32767. Use int.TryParse as Session_End does since RA1d.
- Step RA1d review (UX Low): during a database outage the safe error page does not say that the session is still valid and that trying again is safe.
- Step UN6e (R29, stage B, owner to decide): the Dashboard after stage A is 21,908 characters of ViewState for the Controller on the filled copy (over 20 KB); the Followup page with a committee of about 110 followups 85,016. Stage B (display-only row controls without ViewState and the lists read again before the page is drawn; on Followup the chosen statuses put back by ActionItemId, and a row confirmed meanwhile shows its new status line) waits for the owner's decision on these numbers.
- Step UN6e (R30): the local .js links (BrowserSecurity.js, ColorPicker color_functions.js and js_color_picker_v2.js) have no version stamp (option only).
- Step UN6e: Main.Master and MainNoMenu.Master link MainMaster.css twice (the second link does nothing).
- Step UN6e (tester): the agent instructions (.claude/agents/tester.md) could name Tests\_results\latest.txt for a run that moved to the background; a change there needs a new Claude Code session before the next tester run.
- Step UN6e review (UX Low): Action Items paging now reads the list again; when that read fails the card shows "The action items could not be loaded. Reload the page to try again." (before, paging could not fail), and a list that changed between pages can shift rows or land on the last page, without a message (as decided).
- Step UN6e review (UX Low): BMMS-Fix-Indexes-Step50.sql refuses any other index with the same first key column (stricter than a duplicate check); its message could add what to send the Consultant (the sp_helpindex output of the table).
- Step UN6e review (UI Low): the stamp is kept for the life of the application, a missing file as "no stamp" too; a stylesheet changed or added without a restart keeps the old stamp until the application recycles (a deployment restarts it).
- Step UN6c1: an Update of an agenda item that changes nothing still sets Agenda.UpdatedOn and UpdatedBy (spr_AddEditAgenda), while step 36 leaves the alert as it is. For an item at AC, or one edited more than a minute after its decision, the alert's event date and person then follow that Update: a read alert can come back into Recent, as read, with the newer date. Fix in the writing procedure (set the two columns only when something changed) when it is next touched.
- Step UN6c1: spr_GetAlertByUserId and spr_UpdateAlertByAlertUserId have no caller since UN6c1 (the Dashboard reads spr_GetDashboardAlerts and removes with spr_RemoveAlertForUser; the header reads spr_GetAlertCount); spr_GetActionItemByUserId has none either (spr_GetDashboardActionItems). spr_UpdateAlertByAlertUserId has no owner check. Drop the three in a later database step, with spr_GetScheduleMeet.
- Step UN6c1: the five procedures that write alerts (spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController, spr_AddEditMeeting, spr_AddEditCommittee) still add Alert_User_Map rows for users with the Admin role; the listing rule and the two mail procedures leave them out. Change the creation with UD1b, which rewrites the recipients. Closed by step UD1b (database step 53): no procedure adds Admin rows any more; the existing rows stay.
- Step UN6c1: fn_DashboardAlerts joins Committee as View_Alert does (inner join), so an alert without a committee is still not listed (2 on BMMS_Test); such rows count nowhere, not in the header either.
- Step UN6c1: the tester cannot drive Approve and Reject (they send mail; there is no mail server on the tester and a failed mail writes to the error log) nor deny EXECUTE to see the load-failure messages (a pack has no database access). Both are owner checks; a mail catcher for the tester and a failure switch could come with WF3a3.
- Step UN6c1 review (security Low): the four new procedures accept every active account as acting user and do not look at IsSystem; the protected system account gets its empty list and count 0 because it has the Admin role (the Test script checks that role). If it ever had another role its own alerts would be listed. Exclude IsSystem in fn_DashboardAlerts or refuse it in the procedures when step 43 is next touched.
- Step UN6c1 (Action Items scope): spr_UpdateMinutes and spr_MinutesFinalizeByMeetingId are unchanged and keep writing mapping rows that have nothing to do with the scope (the creator; every active user at finalising, also MD Secretariat, Admin and users of other departments). The rows are harmless now (they hold a read state nobody is shown), but they grow with users times items. Change the creation with UD1b.
- Step UN6c1 (Action Items scope, for UN6e or UN6d): a Controller's and Management's card holds every action item that is not confirmed, the whole list travels in ViewState (the filters and paging work on it in the page) and fn_DashboardActionItems reads Action_Item without an index on IsConfirmed. Fine for a few hundred items; server-side paging and an index when the list grows.
- Step UN6c1 (Action Items scope, install effect): on the day of the install every person sees the items he had no mapping row for in bold (unread) once, a Controller every open item; and three kinds of rows leave a card: items of another department, items whose minutes are still open (for a Manager or User), and the whole card for MD Secretariat and Admin.
- Step UN6c1 (Action Items scope, not reproduced): on BMMS_Test the items C05-00001-002 and C05-00002-002 have one mapping row (the creator) although their minutes are finalised and confirmed; by the text of spr_MinutesFinalizeByMeetingId this happens when the minute became a Followup AFTER finalising (minutes can be edited until they are confirmed), but no audit row shows the order. It decides nothing any more, since visibility no longer follows the mapping.
- Step UN6c1 (Action Items scope, rollback): BMMS-Rollback-DashboardAlerts-Step43.sql leaves the read rows that opening an item created in ActionItem_User_Map. The earlier build lists an item for everyone who has a row, so after a rollback a Controller or Management user keeps the items he opened in his old list (also one with draft minutes). Small: the old finalise path maps every active user anyway.
- Step UN6c1 review (security Low): spr_OpenDashboardActionItem checks the scope and then writes the person's own read row in a second statement; an item that leaves the scope in between still gets that read row (nothing else is written). The save has the scope inside its UPDATE.
- Step UN6c1 review (security Low): the three action item procedures, like the alert procedures, do not look at IsSystem; the system account is refused by its Admin role (Reason 4), not as a system account.
- Step UN6c1 review (UX Low): after a Submit of the Action Item Details panel the list is not reloaded and no "saved" message is shown (as before); the two texts for an inactive account differ slightly (list, save); the panel does not say why its texts are read-only for Management. Done in UN6d (list read again, "The action text was saved.", the read-only line), except the two inactive-account texts, which stay as they are (owner, 2026-11-15).
- Step UN6c1 review (UI Low): when a Dashboard card shows its "could not be loaded" message the hidden grid's wrapper still draws its thin top border under the message.
- Step UN6c1 (for UN6d): spr_UpdateActionItem (the Followup page; the Dashboard no longer calls it) has no acting-user check of its own; the Dashboard's Submit button is still shown to Management (the server refuses the save); after a refused or done Submit the panel closes without a success message; spr_UpdateActionItemByUserId, spr_GetActionItemByActionItemIdUserId, spr_GetActionItemByUserId and their wrappers have no caller in the Dashboard any more. Done in UN6d (step 46) for the first three; the procedures and wrappers named last stay for a later drop step.
- Step UN6d (drop list): spr_UpdateActionItem has no caller since UN6d (the Followup page saves through spr_SaveFollowupActionText and spr_SaveFollowupConfirmed of step 46; its DAL and BAL wrappers were removed). It is left as step 31 installed it, because a re-run of step 31 would bring it back. Drop it in a later database step with spr_UpdateActionItemByUserId, spr_GetActionItemByActionItemIdUserId, spr_GetActionItemByUserId and the three of step UN6c1; BMMS-Check-InstalledSteps.sql and BMMS-Test-UnicodeText-Step31.sql read its marker and must be adjusted in that step.
- Step UN6d (Followup, lost update): Submit writes every row of the list with the ticks the page shows, also rows whose tick did not change, with the values the page read at View. A tick changed by another Controller in between is overwritten. Kept, because what a save writes must not change; a row version or "only the changed ticks" is a later decision. Done in FU1 (step 47): Submit sends only the rows changed to Confirmed, the server writes only those still not confirmed and skips the others; a confirmed item can no longer be unticked (only reopened, one at a time, with a reason).
- Step UN6d (Followup, audit): the Action Text save and the Submit set no UpdatedOn or UpdatedBy on Action_Item and write no audit row, as before, although the acting user is now known to the procedures.
- Step UN6d (Followup, error page): opening a panel (grvFollowup_RowCommand: View of the Actual Resolution, Edit or View of the Action Text) for an item that no longer exists still goes to the error page (Rows[0] of an empty table), as do View, the Committee drop-down and the other handlers on any failure; only the two saves show messages since UN6d.
- Step UN6d (Followup, IsComplied): nothing in the application ever sets Action_Item.IsComplied to 1 (the Followup page always wrote 0, and still does by step 46), so the "not complied" part of the Overdue rule (fn_DashboardActionItems, step 43) is always true and Overdue depends on IsConfirmed and the due date alone.
- Step UN6d (role display): the Dashboard's Action Item Details panel (buttons, read-only line, read-only editor) and the Followup page (Save, Submit, ticks, read-only line) choose what they show by the session role; the server decides every save from the acting user id with the role read from the database. A role changed while the person is signed in shows the old buttons until the next sign-in, and a save is then refused or allowed by the new role.
- Step UN6d review (UX Low): on the Followup page a Controller with an empty list still sees Submit; it sends an empty list, the procedure answers Result 1 and the page says "The confirmations were saved." although nothing was written (as before with "Successfully Saved"). Hide Submit when the list has no rows, or show nothing. Done in FU1: Submit is hidden while the list has no Pending row, and a Submit with no row changed sends nothing and says so.
- Step UN6d review (UX Low): after a done Submit of the Dashboard panel, if reading the list again fails, the card shows its "could not be loaded" message and the page also shows "The action text was saved." (both true; the list is then not current). An owner check by eye.
- Step UN6d review (UX Low): on Followup a refused save for an inactive account (Reason 8) shows "Your account is not active. Nothing was saved. Sign in again." and not the one refusal text of Reasons 4 and 12, as in the approved plan. Decided by the owner (2026-11-15): kept, it tells the person the right next action.
- Step UN6d review (UI Low): for the MD Secretariat each Followup row has two buttons reading "View" side by side (Actual Resolution and Action Text); the column headings tell them apart. A tooltip such as "View action text" could be added. FU1: the Action Text button has the tooltip "View the action text" / "Edit the action text"; the Actual Resolution button has none yet.
- Step UN6d panel-fix review (UI Low): the new lines of the Followup page (above the list and in the Action Text panel) sit in an aria-live wrapper inside UpdatePanel1, which a partial postback replaces whole, so a screen reader may not announce them (the same as the UN6c1 UI Low for the Dashboard cards); role="status" on the paragraph itself could help. Also noted: the 600 px of the Action Text editor is kept in two places (its Width and .wb-followup-popup .wb-dash-message), each with a comment naming the other.
- Candidate step (found in the owner's test of UN6d, 2026-11-15; not in UN6d): stylesheets are cached by the browser after a release. The stylesheet links of MasterPage/Main.Master (10), MasterPage/MainNoMenu.Master (9) and Default.aspx (3) carry no version, and the site sends no Cache-Control header for them, so a browser keeps a stylesheet that was old when it fetched it and does not ask again until Ctrl+F5 (seen: the UN6d footer fix in CommonHTML.css, last changed nine days before, did not show while the newer bmms-workbench.css did; Ctrl+F5 showed it). After a release users can see an old look for hours or days. Candidate fix: a version query on each stylesheet link (for example ?v= the footer version, from the one place step F1 set up: AssemblyInformationalVersion in BMMS/Properties/AssemblyInfo.cs, read by Common.ProductFooter), and a note in the release steps to raise the version when a stylesheet changes.
- Step UN6d review (security Low): the lost update of the Followup Submit (the item above "Step UN6d (Followup, lost update)"): send only the changed rows, or the tick each row had when read and refuse when the stored value differs. Done in FU1 (step 47).
- Step FU1 (Reset Database, Low): spr_sys_ResetDatabase (step 39 text, not replaced in step 47) clears Action_Item_Status_History through the cascading key, but does not restart its identity counter (it restarts a fixed list of tables): after a reset the first history row does not have id 1. Harmless; add the table to the list when spr_sys_ResetDatabase is next replaced.
- Step FU1 (reopen reason length, Low): spr_ReopenFollowup's @ReopenReason is NVARCHAR(500) as decided, so a longer text sent by another caller is cut to 500 characters without a refusal (the Test script shows it); the page and ActionItemMgr.ReopenFollowup refuse it before the call. A wider parameter with a length check in the procedure would make the server refuse it too.
- Step FU1 (audit): the Confirm and Reopen rows of Action_Item_Status_History are the record of who did it; no Audit_Trail_Master row is written and the Audit Trail report does not show them (out of scope in FU1).
- Step FU1 (out of scope): who and when are not shown in Report/Followup.aspx, Report/FollowupActionTaken.aspx or the Dashboard's Action Item panel.
- Step FU1 review (UX Low): after a refused Submit (Reason 4 or 8) or a refused Action Text save the list is not read again, so the rows shown may be out of date; the Reason 26 text says "Click View to read the list again", the Submit refusal text of UN6d does too. A read of the list after every refusal could follow.
- Step FU1 review (UX Low): when the list read after a done Submit or Reopen is itself refused (a role changed in between), the save's message replaces the refusal text of the list. Edge case.
- Step FU1 review (UI Low): the Status column is 220 px (was 100 px); whether the grid fits its card at 1024 px is an owner check by eye; narrow it to about 180 px if it does not. The who-and-when line uses --wb-text-muted at the grid's small font; its contrast (4.5:1) is not measured.
- Step FU1 review (security Low): spr_ReopenFollowup's blank check covers spaces, tabs, line breaks, no-break (U+00A0) and zero-width (U+200B) spaces; other Unicode spaces sent by a caller other than the page (which trims all white space) would pass. Accepted. Re-review: the page and the procedure do not use one list: a reason of only U+200B passes the page's Trim and is then refused by the procedure (Reason 4), so the page closes the panel with the generic refusal text instead of "Enter the reason for reopening."; U+FEFF, U+2000 to U+200A and U+3000 alone pass a direct call of the procedure. One rule in both places (remove U+200B and U+FEFF in C# after Trim; add those code points to the procedure's list) when the page is next touched.
- Step FU1 (owner tests): spr_GetFollowupList orders by ... IsConfirmed, ActionItemId; AgendaNo should be added as a tie-breaker before ActionItemId, so rows of one meeting and status come in agenda order.
- Step FU1 (owner tests, UX): when the browser's "<" check fires in the Reopen panel, the line "Enter the reason for reopening." of an earlier empty Save stays shown above the new line; the check should clear it.
- Step FU1 (tester): the tester's runner call needs a foreground timeout of about 600 s (the FU1 run took 288 s); with the default the run moves to the background and the tester agent cannot read its result (see the WF3a3 item above).
- Step FU2 (planned, from the withdrawn FU1 fix round 1): on the Dashboard, a "Reopened" badge in the Action Items card's Due date column (with Overdue where both apply); the Followup status caption in the Action Item Details panel (Reopened by / Confirmed by / Confirmed (before history)); a read-only panel when a stale card row of an item confirmed meanwhile is opened; an explicit Reason 26 on the Dashboard save (spr_SaveDashboardActionText) with its own text; in the reports (Report/Followup.aspx, Report/FollowupActionTaken.aspx) who confirmed and when. Today the Dashboard already never lists, opens or saves a confirmed item (fn_DashboardActionItems, step 43).
- Step UN6d (Followup, old faults found): the View button calls a script function MinutesFinalizeValidation() that exists nowhere in the site (a script error in the browser; the page posts anyway; already logged below as a baseline item from the RA1b tests, for four pages, and seen again in UN6d); the meeting date boxes ("Meeting Date From ... to") are not used by the list's query (ReportsMgr.GetFollowupReport reads View_Action_Item without a date filter), so the list ignores them.
- Step UN6c1 review (security Low): the wrappers AlertDB / AlertMgr.UpdateAlertByAlertUserId and GetAlertByUserId, and ActionItemDB / ActionItemMgr.GetActionItemByUserId, are still in the code without a caller; UpdateAlertByAlertUserId has no owner check. Remove them with the three procedures.
- Step UN6c1 review (UX Low): "Remove from my list" acts at once, without a confirmation and without a message that it was done (an edit of the item brings the alert back). Decide whether a short confirmation or a success message is wanted.
- Step UN6c1 review (UX Low): the empty text "No alerts." is the same under Recent, Unread and All; under Recent it does not say that older read alerts may be under All.
- Step UN6c1 review (UX Low): on a full (not UpdatePanel) postback of the Dashboard the header count is read twice.
- Step UN6c1 review (UI Low): the message paragraphs of the Dashboard cards sit in an aria-live region inside UpdatePanel1, which is replaced whole on a postback, so a screen reader may not announce them (the same in the Meetings card); role="status" on the paragraph itself could help.
- Step UN6c1 review (UI Low): the login ID of the person on an alert is a title tooltip only (as in the header, step UN2): not reachable by keyboard or on a touch screen.
- Step UN6c1 review (UI Low): when the Due date cell of the Action Items card is narrower than the date and the chip together, "Overdue" drops to a second line with its left margin.
- Step UN6c1 review (UI Low): the rule td.showAll a.bmms-filter-current in MainMaster.css reaches nothing on the Dashboard since UN6b; remove it when no other page uses td.showAll.
- Step UN6c1 review (UX Low): a change of the header count is not announced to a screen reader.
- Step UN6c1 review (UX Low): the Action Items card pages through the list kept in ViewState, so a page change shows the read state of the last load, not of the database (as before); a click on a link or opening an item reads it again.
- Step UN6c1 (tester run 2026-11-13 03:59, VOID; the repeat at 04:04 PASSED): once, in the standing proof of the access matrix, Report/MeetingCalendar.aspx answered HTTP 500 to the User ("Value cannot be null or empty. Parameter name: handler", thrown by an AjaxControlToolkit CalendarExtender of that page while it rendered) on the first requests after the site copy started; the Controller opened the same page without error later in the same run, and the page is not in the step. Not reproduced. If it comes back: suspect the toolkit under several first requests at once, and look at the calendar extenders of that page.
- Step UN6c2b (tester): the pack cannot put an inactive committee id into the Committee drop-down: ASP.NET's event validation rejects a value the drop-down did not offer before the page runs, which writes the error log and fails the run. The pack checks that the inactive committee is offered to nobody (check 15); the server's refusal (Reason 4 in all four procedures) is proven by BMMS-Test-DashboardSummary-Step45.sql (60 calls). A committee made inactive while a Dashboard is open (the drop-down keeps it) gives the refusal messages; that path is an owner check.
- Step UN6c2b: the summary cards and the meeting list count the items of scheduled meetings of every committee, also of an inactive committee, when "All committees" is chosen (the rule applies to a chosen committee only, as decided).
- Step UN6c2b review (security Low): spr_GetDashboardMeetings and spr_GetDashboardActionItems have no Reason 12 of their own (as in steps 42 and 43); the system account has the Admin role and gets the meeting list without statistics and Reason 4 for the Action Items, nothing beyond what an Admin sees. Add the system-account check before Reason 8 when the two are next replaced (the step 45 Rollback texts stay as they are).
- Step UN6c2b review (security note): the page sends the department chosen last even when the Department drop-down is not shown (a User, a Manager with one department); the server checks it against the person's departments, so a forged value only gives Reason 4 with dashes and a message.
- Step UN6c2b review (UI Low): the last statistics header is "In progress" (11 characters, was "Pending"); whether it wraps cleanly in the nine-column Scheduled list at 1097 and 960 px is an owner check by eye. The Alerts note: decided by the owner (2026-11-14), "The filters at the top do not apply".
- Step UN6c2b review (UX Low): the meaning of "In progress" named "Waiting for me" also for roles without that column. Decided by the owner (2026-11-14) and done: the second half only for the Controller and the Manager.
- Step UN6c2b review (UX Low): the heading "My approvals" on a failed or refused load. Decided by the owner (2026-11-14) and done: "My approvals (-)" with "count not available" for a screen reader. The tester cannot reach that state (an inactive committee cannot be chosen, and a pack has no database access): an owner check.
- Step UN6c2b re-review (UX Low, optional): the visible line with the meaning of "In progress" (MD Secretariat) sits under both lists; directly under the Scheduled list would be nearer the column when the Completed list is long.
- Step UN6c2b review (UX Low): pSummaryMessage got role="status" in the fix round; the other card messages (Meetings, Alerts, Action Items, My approvals) still sit in aria-live regions inside UpdatePanel1 (see the UN6c1 UI Low).
- Step UN6c2b narrow-width fix review (UI and UX Low, owner checks by eye): at 1240 px and below the Meetings cells are tighter (6 px by 4 px) and a wrapped status chip ("Open for / submission") looks like a rounded box and makes the row taller; the sticky Meeting column (959 px and below) may lose its divider line while the table scrolls sideways in a table with collapsed borders, and on a phone-width window leaves few columns beside it (drop the sticky rule below about 600 px if that is found cramped); the .wb-table-scroll wrapper has no tabindex or role="region" (recent Edge and Chrome make a scroll box focusable anyway).
- Step UN6c2b second narrow-width fix review (UI Low, owner checks by eye): at 1240 px and below the Meetings cells have 3 px side padding (neighbouring texts about 6 px apart; if too tight, give 1 px back on the Status and Meeting columns first) and 13 px headings (a size step at 1241 px); the smaller chip may still look odd on two lines, and in "Submission closed" its dot sits on a line of its own.
- Step UN6c2a (a small decision of its own, after UN6c2): the meeting date rule of step M6a is checked by the page only. spr_UpdateAgendaByAgendaId does not look at the meeting date, so a tampered post could approve or reject an item of a meeting whose date has passed while its agenda is still Open (the Test script of step 44 shows it: check "AS BEFORE, the procedure does not look at the meeting date"). The function has the flag (DateOpen); refusing in the procedure is one line and a behaviour change.
- Step UN6c2a (data, for the owner): items at AC or AMA of a meeting whose date has passed while the agenda was never finalised cannot be approved by anybody from the Dashboard (the page refuses, step M6a) and are not listed in My approvals or counted in Waiting for me; they still count as "in progress" in the meeting statistics. On BMMS_Test: 8 items at AC routed to mgruser. Finalising the agenda rejects them; decide whether old meetings are to be cleaned up.
- Step UN6c2a (until UD1b; closed by step UD1b, database step 53): a Manager's statistics ("Pending", and the summary cards of step 45) count the items of his departments; My approvals and Waiting for me count the items routed to him (the creator's manager or an alert row). So his cards can show more items in progress than wait for him (on BMMS_Test itmgruser: 9 in his departments, none routed to him). UD1b (every Manager of the item's department) changes the Manager rule in fn_AgendaWaitingFor and nowhere else; with it come the alert rows "handled by another approver" and the case of the last Manager of a department being deactivated.
- Step UN6c2a (for UN6e, indexes): fn_AgendaWaitingFor reads Agenda by AgendaStatusCode and MeetingId (only the primary key exists), Alert_Master by SourceType and SourceTypeId, Users by ManagerId, Alert_User_Map by AlertId and UserId. It runs for the panel, once per Dashboard load for the meeting list, once per opened item and once per decision. Candidates: Agenda (MeetingId, AgendaStatusCode) including DepartmentId, CommitteeId and CreatedBy; Alert_Master (SourceType, SourceTypeId); Users (ManagerId); Alert_User_Map (AlertId, UserId).
- Step UN6c2a: a Controller may reject an item at AC (step 20), but the Agenda Alert panel shows him Approve and Reject only at AMA, as before (the buttons are shown together, from "may approve").
- Step UN6c2a review (security Low): the function compares the creator's manager with `c.ManagerId = u.UserId`, the earlier text with `@UpdatedBy = ISNULL(@CreatorManagerId, 0)`; they differ only for an active Manager whose UserId is 0 and an item whose creator has no manager. UserId is an identity column that starts at 1, so no such user exists; the new form is the stricter one.
- Step UN6c2a review (security Low): spr_GetAgendaApprovalState tells any active user, for any agenda item id, whether the meeting's agenda is open and whether its date has passed (two yes/no flags, no content, no authority).
- Step UN6c2a review (security Low): the Agenda Alert panel still chooses its editable fields, and Approve and Reject choose the Manager's or the Controller's action word, from the role in the session; a role changed in the database during a session gives a refusal (Reason 14), not a bypass. Return the role from spr_GetAgendaApprovalState and branch on it in a later step. The same for the My approvals panel: a Manager whose role changes during a session sees the "choose All committees" message instead of the panel disappearing, until he opens the Dashboard afresh.
- Step UN6c2a review (UX Low): an item opened from a stale My approvals row or from an alert that the person may not decide is shown read-only without a line that says why; a blank agenda number would give a row without link text; a long short text makes a tall row; opening a row does not say that the alert was marked read (the header count follows).
- Step UN6c2a review (UI Low): the explanation of "Waiting for me" is a title tooltip on the heading (mouse only); whether the ninth column of the Scheduled list fits at 1366 px without scrolling inside the card is an owner check.
- Step UN6c2a: the tester still cannot drive Approve and Reject (no mail server); the pack checks the panel, the column and the buttons, the effect of a decision is an owner check.
- Step UN6c1 (for UN6e, indexes): fn_DashboardAlerts reads Alert_User_Map by UserId and StatusId (no index: a scan per Dashboard load and per header count on every page), Alert_Master by AlertId, and Agenda by AgendaId. Candidates: Alert_User_Map (UserId, StatusId) including AlertId and ReadStatus; Alert_Master (SourceType, SourceTypeId) for the writing procedures. The header count now runs on every full page load of every page (as the earlier list read did).
- Step UN6e (indexes): Agenda has only its primary key (AgendaId). spr_GetDashboardMeetings scans it once per listed meeting for the counts (13 scans of 10 pages for the Controller on BMMS_Test) and once for the completed meetings of a Manager or a User, so the reads grow with the number of agenda items. An index on Agenda (MeetingId) with DepartmentId and AgendaStatusCode included, in a numbered database step (timing of 2026-11-12 in the UN6b section).
- Step UN6b follow-up review (UI and UX Low): in the compact Alerts grid the "Alert" heading is still centred by the grid's HeaderStyle HorizontalAlign="Center", over left-aligned rows ("Created on" is left-aligned by CSS). Cosmetic; align both left when the grid moves to the Workbench table style.
- Step UN6b follow-up review (UX Low): since the hidden Read column went, an unread alert is marked by bold type and the row tint only; a visually hidden "Unread" word in the row would tell a screen reader user.
- Step UN6b: spr_GetScheduleMeet has no caller since UN6b (the Dashboard reads spr_GetDashboardMeetings); drop it in a later database step.
- Step UN6b: a Manager's Dashboard counts follow the department (Agenda.DepartmentId), while approval still follows the creator's manager (step 20) until UD1b; a Manager may have an alert for an item outside his counts. Closed by step UD1b (database step 53): approval follows the department too.
- Step UN6b: meetings of the same day are ordered by Meeting.MeetingTime as text ('HH:MM' sorts correctly; another form would not).
- Step UN6b review (UX Low): MD Secretariat and Admin see no statistics columns and no note why ("Statistics are not shown for your role" could be added); decide with their mock-up screens.
- Step UN6b review (UX Low): the Scheduled list has no cap (as decided), so with many scheduled meetings the Meetings card grows without limit; a maximum height with its own scroll, or a pager, is a later choice.
- Step UN6b review (UX Low): the two filter drop-downs post back on every change, also when a keyboard user steps through the list with the arrow keys; a filter button could follow later.
- Step UN6b review (UX Low): the card is titled "Action Items" (the old heading was "Action Item"); confirm the term with the mock-up.
- Step UN6b review (security Low): spr_GetDashboardMeetings accepts any existing committee id, also an inactive one (the drop-down lists active committees only) and also from a User (who has no Committee drop-down). Nothing is disclosed: every role may see every scheduled meeting, and the department scope still limits the completed list and the counts. Decide whether the server should mirror the page (refuse inactive committees, refuse a committee for the User). Closed in step UN6c2b (step 45): an inactive or unknown committee is refused (Reason 4) by all four Dashboard procedures; the User has the Committee drop-down.
- Step UN6b review (UI Low): in the Agenda Alert panel the inline widths style="width: 140px" on the right-hand labels and Width="200px" on the text boxes still apply below 720 px (the boxes are capped at their column); the Committee and Meeting Alert panels keep the old percentage rows. Cosmetic.
- Step UN6b review (UI Low): the Alert and Action Item grids keep the old contentTable1 classes (behaviour unchanged, as required), so their headings differ from the Meetings grid; move them to the Workbench table style in a later step.
- Step RA1c2 (PDF diagnosis, 2026-11-12): the PDF converter of the report window (BMMSBAL/PDFUtilities.cs, HtmlReportToPdf and AddHtmlPart) swallows the exception of iTextSharp's HTMLWorker without writing it to the error log, and HTMLWorker rejects a unit in a numeric attribute (border='1px' threw System.FormatException in IncCell, so the whole Followup by Department report became "[This part of the report could not be converted to PDF. Use Print instead.]"; fixed in that page in RA1c2 with border='1'). Make the converter tolerant (strip units from numeric table attributes before parsing) and write the exception to the error log, as its own step, with the PDF of every report that uses it tested (Minutes, Minutes Extract, Followup, Followup Summary, Followup by Department).
- Step RA1c2: a "reports" tester pack: as the Controller (and Management for its reports), fill in each report page from the fixture, click Generate, catch the report window, check its headings, press Export to Pdf and Export to Word, and check the files (type, size) and that the PDF text holds the table and is not the fallback sentence. The access matrix only checks who may open which address and cannot see report contents.
- Step RA1c2: spr_GetActionItemByMeetingIdDeptId ignores its @CommitteeId (it selects by meeting number and department only); Followup by Department filters by committee in the page. Fix the procedure in a numbered step when it is next needed by another caller.
- Step RA1c2 review (Low, UX and UI, for the functional review of Followup by Department): changing View/Print or a Subject No list does not hide a grid of earlier choices (no handler; Committee, Meeting No and Department changes do); the Meeting No lists still carry a leftover DataTextField="SubjectNo" (harmless, loaded with explicit fields); the Print panel keeps an empty spacing row; the page's markup differs from Report/Followup.aspx (heading as plain text, inline widths), all baseline. When CheckValidataion itself fails with an exception it writes the error log and shows no message, so Submit and Generate do nothing visible (baseline; since RA1c2 Generate calls it too): show a short message there.
- Step RA1c2 (owner test, 2026-11-12): the Followup by Department report does not print the committee name (page, PDF and Word); the Followup report (Report/Reports.aspx) probably has the same gap. Plan one step that adds the report title, the committee name and the chosen filters (department, meeting and Subject No range) under the banner, for every report built from the same helper (OrganisationDetails.ReportBannerHtml: Report/FollowupActionTaken.aspx.cs and Report/Reports.aspx.cs). In the same step remove the lone "." after the report table (`<spana style='color:white'>.</spana>`, FollowupActionTaken.aspx.cs), which prints black in the PDF.
- Step RA1c2: Followup by Department for the Manager (option B: home and managed departments, finalised and confirmed minutes only, enforced on the server) is for the functional review of the page; the page shows draft-minutes follow-up items without a mark (as the Controller's Followup does).
- Step WF3a1 security pass (owner, 2026-11-11): the sign-in page limits the password to 12 characters (PasswordMaxLength in BMMS/XML/AppSettings.xml, as the User ID by LoginIdMaxLength; ChangePassword and ChangePasswordFirst ask for more than PasswordMinLength 6). Twelve is short for today's guidance; raising it touches the sign-in page, the two change-password pages, Reset Password and the User Master. Take it up in a security step.
- Step WF3a1: Error/TestPage.aspx was a leftover of the baseline that wrote a trial PDF in Page_Load. Closed in step RA1c2 (removed).
- Step WF3a1 security review (Low): Update-Baseline.ps1's scan of a Fix script does not see USE inside dynamic SQL or a three-part name; the wall is that bmms_tester can open no other database (asked of the server before every run). sqlcmd runs without -X.
- Step WF3a1, the four security Lows (allow-list, role check timing, icacls read-back, reachability): closed in step WF3a2 (see its section). Left: the test from the other laptop (owner's test steps of WF3a2).
- Step WF3a2 (High, product, baseline): Report/EventCalendar.aspx ran out of memory on every GET. Closed in step RA1c1 (the page and Report/ReportPrint.aspx removed).
- Step RA1c1 review (Low, UI and UX): the "no longer available" page of ViewReport.aspx (one constant, NoReportHtml, for ?pdf=1 and a missing report) is a bare HTML fragment: no doctype, charset or stylesheet (quirks mode, default font), no Close link, and after an Export click it does not say that nothing was exported. Polish both paths together: a doctype and the page style, a Close link.
- Step RA1c1: the tester agent's runner command moves to the background after 180 s (a limit of the agent's command tool; the 10-minute timeout in .claude/agents/tester.md does not change it), so the agent does not see the runner's last lines or the name of the results folder, and the main session has to give it the name (seen in WF3a2 and RA1c1). Fix in a later step: the runner writes the results folder name to Tests/_results/latest.txt, which the agent may read.
- Step RA1c1 review (Low): the pack README listed the unused cell words of RA1c1 and RA1c2. Closed in step RA1c2 (the words removed from the README and from pack.js).
- Step WF3a2 (product defect): Report/ViewReport.aspx opened directly with no report gave the Controller and the Manager HTTP 500. Closed in step RA1c1 ("The report is no longer available", HTTP 200, no error-log entry).
- Step WF3a2: Report/FollowupActionTaken.aspx for the Controller and the Manager: to be decided by the owner in RA1c2.
- Step WF3a2 UX review (Low): "Other notes for the owner" names the Master menu's drop-down list by its internal id (ddsubmenu1) and does not say that only Admin and the Controller can open it.
- Step WF3a2 UX review (Low): results.md does not mark a failed check the owner has already seen (the two ViewReport cells, kept as a real failure until RA1c1) as known.
- Step WF3a2 UX review (Low): the run's check count (for example "2 of 501") counts the menu and file checks and leaves out the planted ones, next to "464 cells" in the grid; the report does not explain the difference, and "All checks" jumps over the cell numbers (the line above it says why).
- Step WF3a2: the drop-down list of the Master menu is rendered for every role; only Admin and the Controller can open it. Render it for those two only (RA1c or a menu step).
- Step WF3a2: the access matrix run takes about 3 minutes, over the "about two minutes" of the plan; most of it is the site's first requests (page compilation). Precompiling the site copy is the first lever, if the time matters.
- Step WF3a2: the reachability guards test the binding and the IP restriction from this machine and read the firewall rules (a rule that lets inbound traffic in is a warning, owner decision 2026-11-11); they are not a test from another machine.
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
- Step RA1b review (Low): the other pages that open ViewReport.aspx (FollowupActionTaken, Agenda Approval, Notice, Sitting Fees) neither set nor clear Session["ViewReportKind"]; after a role change to Management during a session (RA1d), a kind left by an earlier Minutes or Followup report could let ViewReport show such a report. ?pdf=1 is refused to Management anyway. Clear the kind wherever Session["ViewReport"] or Session["ReportPdf"] is set. Step RA1c2: FollowupActionTaken now clears the kind before it stores its report; Agenda Approval, Notice and Sitting Fees remain.
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
- Step UD1a: approval still follows the creator's manager (step 20); a Manager's second department gives him no approval until UD1b. The department check of rule 12 prepares for UD1b. Closed by step UD1b (database step 53).
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
- Dashboard alert panel of an item of a past meeting opens as a normal panel (buttons visible, boxes editable); only pressing Approve or Reject is refused (to be taken up later; the branch in BindAgendaDetails that should make it read-only does not take effect on this path). Fixed in step UN6c2a (step 44): the panel of such an item opens read-only without Approve and Reject for the person who could decide it, with the meeting-date message inside the panel above the buttons (dashboard pack check 11).
- Cause of the item above (found in step C1): the M6a check in BindAgendaDetails is `if (btnApprove.Visible && ...)`, and btnApprove.Visible reads false during the bind because its parent pnlAgenda is still hidden (lnkSource_Click shows it after BindAgendaDetails returns), so the branch never runs. To be fixed in a separate step M6c by showing pnlAgenda before the bind (and hiding it again when the item is not found); C1 test 6 then changes. Fixed in step UN6c2a instead of M6c: the branch now tests the server's answer (spr_GetAgendaApprovalState: may decide, DateOpen), not btnApprove.Visible; C1 test 6 changes accordingly (the panel opens read-only with the message).
- Agenda Entry Update (step C1): the other role's comment is read at save time, just before the save procedure takes its lock; a Dashboard Approve or Reject by that role in the same moment (milliseconds) can be overwritten by the older value. Closing it fully needs the save procedures to keep the column themselves (a database step).
- Agenda Entry Edit of an item deleted meanwhile (baseline): the Edit branch reads the first row of an empty table and the safe error page shows (only through a list older than the delete).
- Agenda Finalisation Reject (step C1 left it): every item not yet approved gets Controller Comments "Agenda rejected by Controller on agenda finalized.", which replaces a comment the Controller wrote earlier; Manager Comments is not touched.
- Report/Followup and Report/FollowupActionTaken have Send Mail code (btnSendMail_Click) that no button reaches: Followup.aspx has no Send Mail button and the one in FollowupActionTaken.aspx is commented out. If a button is restored: the Followup report attaches `~/Files/PDF/Followup.pdf`, which that page never writes (another meeting's file written by Followup Action Taken, or none), both pages always say "Mail was sent to all members." whatever the mail result, and the file name is shared by every user (steps M2 and M3 left them unchanged).
- The Followup and Followup Action Taken mail handlers (btnSendMail_Click) are dead code, because no Send Mail button is rendered on either page (commented out in FollowupActionTaken.aspx:115-116, absent from Followup.aspx), so the mail inventory should not list those two as live (step ML2a).
- Sitting Fees can still crash on a missing GetTotAmtByMemberId row, a deleted member, an empty From/To date, and a damaged logo file.
- A damaged logo file makes the Notice, Agenda Approval and Sitting Fees PDFs throw (PDFUtilities.AddCompanyLogo).
- Notice page shows no confirmation (fixed in step 28).
- Owner's test 7 (step UN6c2a): mgruser opened the alert of C06-00001-003 (AC, agenda Open, meeting 29-Oct-2026; spr_GetAgendaApprovalState: Result 1, Reason 0, CanApprove 1, CanReject 1, AgendaOpen 1, DateOpen 0). The panel opened read-only without Approve and Reject, but the meeting-date message was written to the page's message box, which lies under the popup, so no message could be seen. Fixed in step UN6c2a (the same commit as step 44): the message, and the could-not-be-checked message, now show inside the panel above the buttons (dashboard pack check 11).
- Dashboard (step UN6c2a, ui-reviewer): the 4 px padding of the Status cell is set by column position (`.wb-dash-table` th/td:nth-child(4)); a column added or moved in MeetingSummary.ascx moves it to another column. Give the Status cell its own class when the control is next changed.
- Dashboard Agenda Alert panel (step UN6c2a, ux-reviewer): in the read-only state of an item of a passed meeting the Short Text box looks white like an editable box while the other read-only boxes are grey (it is set ReadOnly; styling only, not verified in the page).
- Dashboard Agenda Alert panel (step UN6c2a, ux-reviewer): the meeting-date message is in the button row at the bottom of a tall panel; at 1366 px it is seen after scrolling down to the buttons. A short note near the top, or scrolling to it, could follow.
- Dashboard layout (step UN6c2a, ux-reviewer): windows of 1101 to 1240 px now get the one-column layout (Alerts below Meetings); an owner check by eye at about 1200 px is suggested.
- Tests/_runner/Setup-Quality.ps1: its closing summary still says "committee QA2 with twelve meetings and twelve agenda items"; since step UN6c2a it has thirteen meetings and fifteen items (wording only; the fixture check counts them).
- DocTools does not find a global npm mermaid-cli (Low; Work-Laptop setup, 2026-11-15). Find-DocMmdc falls back to mmdc on PATH, which for `npm install -g` is the shim in %APPDATA%\npm, and Invoke-DocMmdc then looks for `..\@mermaid-js\mermaid-cli\src\cli.js` next to it (%APPDATA%\@mermaid-js\..., which does not exist): Check-Documents and Export-Documents stop with "mermaid-cli script not found". No value of BMMS_DOC_TOOLS helps, because a global install has no node_modules\.bin\mmdc.cmd. Today: pass `-Mmdc "%APPDATA%\npm\node_modules\@mermaid-js\mermaid-cli"`, or install mermaid-cli locally in C:\Tools\bmms-doc-tools. Fix in a later step: look for cli.js under `node_modules\@mermaid-js\mermaid-cli` beside the shim as well.

- Step FU2a review (security Low): BMMS-Rollback-DashboardFollowupFinal-Step48.sql checks only that step 48 is installed (its marker or the new function), not that the four objects are still the step 48 texts before it puts back the texts of steps 43 and 45. A later step that replaces one of them and keeps the step 48 marker would be overwritten without a warning (the SHA-1 check at the end only proves the restore). Fix in a later step: compare each object with the SHA-1 of its step 48 text (or look for a later marker) and refuse when it differs, as the Fix scripts do.
- Step FU2a review (UX Low): after a Submit refused with Reason 26 the editor shows the saved text (owner decision, R16), so a long edit typed in the panel is gone without a way to copy it; the message says "Nothing was saved." but not that the typed text was not kept. Possible later change: add "Your changes were not kept." or keep the typed text in view when it differs from the saved text.
- Step FU2a review (UX Low): the status line under the action text (pActionItemStatus) is not a live region; the panel's message line above the buttons is (aria-live="polite"), so the Reason 26 message is announced, the changed status line is not. Polish only.
- Step FU2a review (UI Low): in the Due date column the date, "Overdue" and "Reopened" can wrap onto a second line at 1024 px; a wrapped chip keeps its left margin (wb-dash-overdue, wb-dash-reopened) and sits about 4 px off centre. Cosmetic; nothing is cut. Owner's check at 1024 px decides.
- Step FU2a review (UI Low, note): the status line is as wide as the value column (wb-dash-pfield, at most 550 px), no wider than the editor above it. As intended; for the owner's check by eye.
- Step FU2a (ViewState): the card's rows travel in ViewState (dtActionItem, for the paging and the links) with the seven status columns of step 48, the reason of a reopened item included (at most 500 characters per reopened item). See the UN6c1 item above on the size of the list.
- Step FU2b (drop list): spr_GetFollowupReportForManagement (step 41) and spr_GetActionItemByMeetingIdDeptId (in no numbered script) have no caller since FU2b (the Followup reports read spr_GetFollowupReport and spr_GetFollowupByDepartmentReport, step 49). Drop them in a later step, with BMMS-Test-ReportAccess-Step41.sql (it reads spr_GetFollowupReportForManagement) and the parity checks of BMMS-Test-FollowupReports-Step49.sql changed to saved copies.
- Step FU2b: Report/Followup.aspx.cs still has btnSendMail_Click and CreateBodyText, whose button is not in the page (the mail attaches ~/Files/PDF/Followup.pdf, which nothing writes since step 25). The handler cannot be reached; remove it in a later step, as RA1c2 did on Followup by Department.
- Step FU2b review (UX Low, fixed in FU2b on the owner's word, 2026-11-17): the grid column of Followup, Followup Summary and Followup by Department was headed "Status"; it is headed "Followup status" now, as the printed Summary's column, so it is not taken for "Minutes status" (the followup-reports pack reads the header from expected.json, statusHeader).
- Step FU2b review (UX Low): a Pending item that was never reopened shows the word "Pending" alone, as on the Followup page (R22); an explicit "No history" line would be a later owner decision.
- Step FU2b review (UX Low): "Confirmed (before history)", an "(inactive)" name and "an unknown user" are proven in the reports only by BMMS-Test-FollowupReports-Step49.sql (the status columns) and the owner's check on BMMS_Test (the texts); the fixture has none of them, so the followup-reports pack does not show them.
- Step FU2b review (UI Medium, checked, no change): the report HTML's word-wrap is ignored by iTextSharp HTMLWorker (Export to Pdf), but HTMLWorker breaks a word longer than the line by character: checked 2026-11-17 with PDFUtilities.HtmlReportToPdf on the report HTML of both pages with a 500-character reason without spaces (Followup: 11 lines inside the margins; Followup by Department: the Subject cell grows, the table stays on the page). Export to Word stays an owner check.
- Step FU2b review (UI Low): the "Followup status" column has Width 220px in the auto-width grids; for Management's Followup the fixed widths add up to about 890 px, so at 1024 px the Agenda Short Text column is narrow (the status text wraps, nothing is expected to overflow). Owner's check at 1024 px; 180 px or a percentage if it is tight. The new column has no sort link (its neighbours have one).
- Step FU2b review (UI Low): the status line under the subject in Followup by Department is 10pt inline; the report cell's text has no set size (the browser's default, about 12pt), so it shows smaller. In the PDF HTMLWorker draws all four columns of that table at equal width (it ignores the 10/10/10/70 % widths), as before FU2b.
- Step FU2b review (security, robustness note, pre-existing): spr_GetFollowupByDepartmentReport compares Meeting.MeetingNo (VARCHAR) with the integer meeting numbers, as spr_GetActionItemByMeetingIdDeptId did ("compared as before", parity proven): a meeting number that is not a number would stop the report with a conversion error, as it would have before. A later step could compare TRY-free with ISNUMERIC guards or store MeetingNo as a number.
- Step FU2b re-review (UX Low): code comments of Report/Followup.aspx and Report/FollowupActionTaken.aspx still call the grid cell "the Status cell" (StatusCellHtml); wording inside the code only, not seen by users. Change to "Followup status cell" when the files are next touched.
- Step FU2b (addition 7, closed by the owner 2026-11-17, no code change): Export to Word opens the file in Web Layout, where a long word without spaces runs past the window edge; in Print Layout the 500-character reason wraps inside the margins (owner checked). This holds for every field of every report exported to Word (baseline, not from FU2b). Fix it once in the report export: open the file in Print Layout, or add break points in long words.
- Step FU2b (baseline, seen in the owner's tests): in the Followup report (Report/Followup.aspx.cs) the whole action text under ACTION TAKEN prints bold (font-weight:bold on its div).
- Step FU2b (baseline, seen in the owner's tests): the Followup report HTML (Report/Followup.aspx.cs) has the style typo text-aligh:justify (for text-align:justify), so that text is not justified.
- Step FU2b (seen in the owner's tests): on the Followup page, after an Action Text save, a Submit with no row changed says "No followup was changed to Confirmed. Nothing was saved.", which can read as if the Action Text was lost (it was saved). Reword later, for example to say that no confirmation was changed.
- Step FU2b (documents): Documents/System-Manual/05-Application-Code.md, line 790, gives the ActionItemDB method count as 12; it was wrong before FU2b and is 15 now (public static methods of BMMSDAL/ActionItemDB.cs). Correct it in the next documents stage.