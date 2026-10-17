/* ============================================================================
   BMMS - Which numbered steps (README run order 1 to 17) are installed
   ----------------------------------------------------------------------------
   READ ONLY. It reads object definitions and constraint names; it creates,
   changes and deletes nothing, and it can run on BMMS as well as on a copy.

   One row per step:
     Installed       every marker of the step is present
     Partly          some are present: usually a later re-run of an older
                     script replaced one of its procedures (see Detail and
                     the re-run notes in Database/README.md)
     Missing         none is present
     Not detectable  the step leaves nothing that can be checked (none of
                     steps 1 to 17 today; kept for future steps)

   A step that is replaced by a later one is checked by what survives: for
   example step 10 by the "FK#5-UserDelete-AllColumns" text that step 13 kept
   in spr_DeleteUserByUserId, step 8 by the duplicate check that step 15 kept
   in spr_MinutesFinalizeByMeetingId. Step 16 keeps the texts of steps 6, 12
   and 15 in the procedures it replaces, so those steps still read Installed;
   if step 6, 12 or 15 is re-run afterwards, step 16 reads Partly. Step 17
   keeps the texts of steps 6, 8, 15 and 16 in the procedures it replaces; if
   step 6, 8, 15 or 16 is re-run afterwards, step 17 reads Partly.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was read.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

-- One row per marker: Step, what is checked, present (1) or not (0)
DECLARE @M TABLE (Step INT, Marker VARCHAR(200), Present INT);

-- 1. BMMS-Fix-Login-Procedures.sql
INSERT INTO @M VALUES
(1, 'spr_RecordLoginByUserId exists', CASE WHEN OBJECT_ID('dbo.spr_RecordLoginByUserId', 'P') IS NOT NULL THEN 1 ELSE 0 END),
(1, 'spr_GetUserByLoginName ignores @Password', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUserByLoginName')), '') LIKE '%retained for compatibility%' THEN 1 ELSE 0 END);

-- 2. BMMS-Fix-Delete-Procedures.sql
INSERT INTO @M VALUES
(2, 'spr_DeleteCommitteeMemberByCommitteeMemberId checks Attendance', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteCommitteeMemberByCommitteeMemberId')), '') LIKE '%Committee+Member combination%' THEN 1 ELSE 0 END);

-- 3. BMMS-Fix-ResetDatabase-Seeds.sql
INSERT INTO @M VALUES
(3, 'spr_sys_ResetDatabase seeds ManagerId NULL', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '') LIKE '%FK#5-ManagerId-NULL%' THEN 1 ELSE 0 END);

-- 4. BMMS-Add-PrimaryKeys.sql
INSERT INTO @M VALUES
(4, 'PK_Source_Type', CASE WHEN OBJECT_ID('dbo.PK_Source_Type', 'PK') IS NOT NULL THEN 1 ELSE 0 END),
(4, 'PK_Audit_Trail_SendMail', CASE WHEN OBJECT_ID('dbo.PK_Audit_Trail_SendMail', 'PK') IS NOT NULL THEN 1 ELSE 0 END);

-- 5. BMMS-Add-ForeignKeys-Safe.sql
INSERT INTO @M VALUES
(5, 'FK_Agenda_Committee', CASE WHEN OBJECT_ID('dbo.FK_Agenda_Committee', 'F') IS NOT NULL THEN 1 ELSE 0 END),
(5, 'FK_Attendance_Committee', CASE WHEN OBJECT_ID('dbo.FK_Attendance_Committee', 'F') IS NOT NULL THEN 1 ELSE 0 END);

-- 6. BMMS-Fix-FK-Procedures.sql (its chairman, agenda finalize and user delete procedures were replaced by steps 10, 13 and 15;
--    step 16 replaced spr_UpdateMinutes and spr_DeleteAgendaByAgendaId and kept the "FK #5" text)
INSERT INTO @M VALUES
(6, 'spr_AddEditMember stores no state as NULL', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMember')), '') LIKE '%FK #5%' THEN 1 ELSE 0 END),
(6, 'spr_UpdateMinutes maps only an existing user', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') LIKE '%FK #5%' THEN 1 ELSE 0 END),
(6, 'spr_DeleteAgendaByAgendaId removes action items first', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteAgendaByAgendaId')), '') LIKE '%FK #5%' THEN 1 ELSE 0 END);

-- 7. BMMS-Add-ForeignKeys-Step3.sql
INSERT INTO @M VALUES
(7, 'FK_Action_Item_Minutes', CASE WHEN OBJECT_ID('dbo.FK_Action_Item_Minutes', 'F') IS NOT NULL THEN 1 ELSE 0 END),
(7, 'FK_ActionItem_User_Map_Users', CASE WHEN OBJECT_ID('dbo.FK_ActionItem_User_Map_Users', 'F') IS NOT NULL THEN 1 ELSE 0 END),
(7, 'FK_Meeting_Chairman', CASE WHEN OBJECT_ID('dbo.FK_Meeting_Chairman', 'F') IS NOT NULL THEN 1 ELSE 0 END),
(7, 'FK_Member_State_Master', CASE WHEN OBJECT_ID('dbo.FK_Member_State_Master', 'F') IS NOT NULL THEN 1 ELSE 0 END);

-- 8. BMMS-Fix-MinutesFinalize-Procedure.sql (kept by step 15)
INSERT INTO @M VALUES
(8, 'spr_MinutesFinalizeByMeetingId does not duplicate map rows', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')), '') LIKE '%NOT EXISTS (SELECT 1 FROM ActionItem_User_Map x%' THEN 1 ELSE 0 END);

-- 9. BMMS-Add-ForeignKeys-Step4.sql
INSERT INTO @M VALUES
(9, 'FK_Users_ManagerId', CASE WHEN OBJECT_ID('dbo.FK_Users_ManagerId', 'F') IS NOT NULL THEN 1 ELSE 0 END);

-- 10. BMMS-Fix-UserDelete-Procedure.sql (kept by step 13)
INSERT INTO @M VALUES
(10, 'spr_DeleteUserByUserId checks every user-id column', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') LIKE '%FK#5-UserDelete-AllColumns%' THEN 1 ELSE 0 END);

-- 11. BMMS-Add-ForeignKeys-Step5.sql (21 keys)
INSERT INTO @M
SELECT 11, k.Name, CASE WHEN OBJECT_ID('dbo.' + k.Name, 'F') IS NOT NULL THEN 1 ELSE 0 END
FROM (VALUES ('FK_Action_Item_UpdatedBy'), ('FK_Agenda_ControllerApprovedBy'), ('FK_Agenda_CreatedBy'), ('FK_Agenda_MgrApprovedBy'),
             ('FK_Agenda_UpdatedBy'), ('FK_Alert_Master_CreatedBy'), ('FK_Alert_User_Map_Users'), ('FK_Attendance_UpdatedBy'),
             ('FK_Audit_Trail_Master_Update_By'), ('FK_Audit_Trail_SqlBackup_User_Id'), ('FK_Committee_CreatedBy'),
             ('FK_Committee_Member_CreatedBy'), ('FK_Committee_Member_UpdatedBy'), ('FK_Committee_UpdatedBy'), ('FK_Meeting_CreatedBy'),
             ('FK_Meeting_Member_CreatedBy'), ('FK_Meeting_Member_UpdatedBy'), ('FK_Meeting_UpdatedBy'), ('FK_Member_CreatedBy'),
             ('FK_Member_UpdatedBy'), ('FK_Users_UpdatedBy')) k(Name);

-- 12. BMMS-Fix-Attendance-FutureMeeting.sql (spr_UpdateAttendance kept the text in step 15)
INSERT INTO @M VALUES
(12, 'spr_CheckMeetingHeldByMeetingId exists', CASE WHEN OBJECT_ID('dbo.spr_CheckMeetingHeldByMeetingId', 'P') IS NOT NULL THEN 1 ELSE 0 END),
(12, 'spr_UpdateAttendance refuses a future meeting', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAttendance')), '') LIKE '%Attendance-FutureMeeting%' THEN 1 ELSE 0 END);

-- 13. BMMS-Fix-UserProtection-Stage1.sql
INSERT INTO @M
SELECT 13, o.Name + ' (UserProtection-Stage1)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UserProtection-Stage1%' THEN 1 ELSE 0 END
FROM (VALUES ('fn_UserChangeRefusal'), ('spr_CheckUserChange'), ('spr_DeleteUserByUserId'), ('spr_AddEditUser'),
             ('spr_ResetPasswordByUserId'), ('spr_SetUserStatusByUserId'), ('spr_GetUserListForUserPage')) o(Name);
INSERT INTO @M VALUES
(13, 'spr_DeleteUserByUserId has 5 parameters', CASE WHEN (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_DeleteUserByUserId')) = 5 THEN 1 ELSE 0 END);

-- 14. BMMS-Fix-UserStatus-Stage2a.sql
INSERT INTO @M
SELECT 14, o.Name + ' (UserStatus-Stage2a)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UserStatus-Stage2a%' THEN 1 ELSE 0 END
FROM (VALUES ('fn_UserChangeRefusal'), ('spr_GetUserStatusByUserId'), ('spr_GetActiveUserList'), ('spr_GetMgrControllerByDeptId'),
             ('spr_GetUserListForUserPage'), ('spr_LockUserByUserId')) o(Name);
INSERT INTO @M VALUES
(14, 'Users.AccountStatus NOT NULL', CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'AccountStatus' AND is_nullable = 0) THEN 1 ELSE 0 END),
(14, 'CK_Users_AccountStatus', CASE WHEN EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.Users') AND name = 'CK_Users_AccountStatus') THEN 1 ELSE 0 END);

-- 15. BMMS-Fix-MeetingLocks.sql
INSERT INTO @M
SELECT 15, o.Name + ' (MeetingLocks-Step15)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%MeetingLocks-Step15%' THEN 1 ELSE 0 END
FROM (VALUES ('spr_GetMeetingStatusByMeetingId'), ('spr_AddEditMeetingMember'), ('spr_DeleteMeetingMemberByMeetingMemberId'),
             ('spr_UpdateAttendance'), ('spr_UpdateMeetingChairman'), ('spr_AgendaFinalizeByMeetingId'),
             ('spr_MinutesFinalizeByMeetingId'), ('spr_MinutesConfirmByMeetingId')) o(Name);

-- 16. BMMS-Fix-MeetingLocks-Step16.sql (re-running step 6, 12 or 15 replaces some of these)
INSERT INTO @M
SELECT 16, o.Name + ' (MeetingLocks-Step16)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%MeetingLocks-Step16%' THEN 1 ELSE 0 END
FROM (VALUES ('fn_AgendaChangeRefusal'), ('fn_CommitteeMemberDateCheck'), ('spr_GetAppSetting'), ('spr_SetAppSetting'),
             ('spr_AddEditMeeting'), ('spr_GetMeetingEditLockByMeetingId'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'),
             ('spr_AddEditAgendaByController'), ('spr_DeleteAgendaByAgendaId'), ('spr_UpdateSubjectNoByAgendaId'),
             ('spr_UpdateAgendaByAgendaId'), ('spr_GetAgendaLockByMeetingId'), ('spr_UpdateMinutes'), ('spr_UpdateAgendaShortText'),
             ('spr_GetCommitteeMemberByCommitteeId'), ('spr_GetCommitteeMemberByMeetingId'), ('spr_UpdateAttendance'),
             ('spr_UpdateMeetingChairman')) o(Name);
INSERT INTO @M VALUES
(16, 'App_Setting table', CASE WHEN OBJECT_ID('dbo.App_Setting', 'U') IS NOT NULL THEN 1 ELSE 0 END);

-- 17. BMMS-Fix-UserStatus-Stage2b.sql (re-running step 6, 8, 15 or 16 replaces some of these)
INSERT INTO @M
SELECT 17, o.Name + ' (UserStatus2b-Step17)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UserStatus2b-Step17%' THEN 1 ELSE 0 END
FROM (VALUES ('spr_AddEditCommittee'), ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'),
             ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaByAgendaId'), ('spr_MinutesFinalizeByMeetingId'),
             ('spr_UpdateMinutes'), ('spr_GetAlertMailId')) o(Name);

DECLARE @Steps TABLE (Step INT, Script VARCHAR(60), IfPartly VARCHAR(200));
INSERT INTO @Steps VALUES
(1, 'BMMS-Fix-Login-Procedures.sql', ''),
(2, 'BMMS-Fix-Delete-Procedures.sql', ''),
(3, 'BMMS-Fix-ResetDatabase-Seeds.sql', ''),
(4, 'BMMS-Add-PrimaryKeys.sql', ''),
(5, 'BMMS-Add-ForeignKeys-Safe.sql', ''),
(6, 'BMMS-Fix-FK-Procedures.sql', ''),
(7, 'BMMS-Add-ForeignKeys-Step3.sql', ''),
(8, 'BMMS-Fix-MinutesFinalize-Procedure.sql', ''),
(9, 'BMMS-Add-ForeignKeys-Step4.sql', ''),
(10, 'BMMS-Fix-UserDelete-Procedure.sql', 'step 10 or 13 replaced: run step 13 again, then 14'),
(11, 'BMMS-Add-ForeignKeys-Step5.sql', 'some keys refused: run BMMS-Check-Orphans.sql, then step 11 again'),
(12, 'BMMS-Fix-Attendance-FutureMeeting.sql', 'run step 12 again, then steps 15, 16 and 17'),
(13, 'BMMS-Fix-UserProtection-Stage1.sql', 'step 2, 6 or 10 was re-run: run step 13 again, then 14'),
(14, 'BMMS-Fix-UserStatus-Stage2a.sql', 'step 13 was re-run: run step 14 again'),
(15, 'BMMS-Fix-MeetingLocks.sql', 'step 6, 8 or 12 was re-run: run step 15 again, then steps 16 and 17'),
(16, 'BMMS-Fix-MeetingLocks-Step16.sql', 'step 6, 12 or 15 was re-run: run step 16 again, then step 17'),
(17, 'BMMS-Fix-UserStatus-Stage2b.sql', 'step 6, 8, 15 or 16 was re-run: run step 17 again');

SELECT s.Step, s.Script,
       CASE WHEN COUNT(m.Step) = 0 THEN 'Not detectable'
            WHEN SUM(m.Present) = COUNT(*) THEN 'Installed'
            WHEN SUM(m.Present) = 0 THEN 'Missing'
            ELSE 'Partly' END AS Status,
       CAST(ISNULL(SUM(m.Present), 0) AS VARCHAR(4)) + ' of ' + CAST(COUNT(m.Step) AS VARCHAR(4)) + ' markers'
       + CASE WHEN COUNT(m.Step) > 0 AND SUM(m.Present) > 0 AND SUM(m.Present) < COUNT(*) AND s.IfPartly <> '' THEN '; ' + s.IfPartly ELSE '' END AS Detail
FROM @Steps s
LEFT JOIN @M m ON m.Step = s.Step
GROUP BY s.Step, s.Script, s.IfPartly
ORDER BY s.Step;

-- Every marker that is missing, for a step that is not fully installed
SELECT m.Step, m.Marker AS MissingMarker
FROM @M m
WHERE m.Present = 0
ORDER BY m.Step, m.Marker;

SELECT DB_NAME() AS CurrentDatabase;
GO

SET NOEXEC OFF;
GO
