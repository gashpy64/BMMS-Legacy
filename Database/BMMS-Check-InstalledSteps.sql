/* ============================================================================
   BMMS - Which numbered steps (README run order 1 to 22 and 24) are installed
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
                     the steps checked today; kept for future steps)

   A step that is replaced by a later one is checked by what survives: for
   example step 10 by the "FK#5-UserDelete-AllColumns" text that step 13 kept
   in spr_DeleteUserByUserId, step 8 by the duplicate check that step 15 kept
   in spr_MinutesFinalizeByMeetingId. Step 16 keeps the texts of steps 6, 12
   and 15 in the procedures it replaces, so those steps still read Installed;
   if step 6, 12 or 15 is re-run afterwards, step 16 reads Partly. Step 17
   keeps the texts of steps 6, 8, 15 and 16 in the procedures it replaces; if
   step 6, 8, 15 or 16 is re-run afterwards, step 17 reads Partly. Step 18
   keeps the texts of steps 3, 6, 8, 13 to 17 in the objects it replaces; if
   step 3, 6, 8, 13, 14, 15, 16 or 17 is re-run afterwards, step 18 reads
   Partly. Step 18 also checks that exactly one user is the system account.
   Step 19 replaces nothing and no earlier script contains its procedures, so
   no re-run of an earlier step changes it; it also checks that its 12
   setting rows exist. Step 20 keeps the texts of steps 16, 17 and 18 in the
   two agenda procedures it replaces; if step 16, 17 or 18 is re-run
   afterwards, step 20 reads Partly. Step 21
   keeps the texts of steps 3, 15 and 18 in the procedures it replaces; if
   step 2, 3, 15 or 18 is re-run afterwards, step 21 reads Partly. Step 21
   also checks that every existing type 2, 3 and 6 is reserved, a meeting
   type and active. Step 22 replaces nothing and no earlier script contains
   its two procedures, so no re-run of an earlier step changes it. Step 23
   is reserved and not listed. Step 24 keeps the texts of steps 16, 17 and
   18 in spr_AddEditMeeting; if step 16, 17 or 18 is re-run afterwards, its
   marker is gone and step 24 reads Missing: run step 24 again.

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

-- 18. BMMS-Fix-SystemAccount-Stage3.sql (re-running step 3, 6, 8, 13, 14, 15, 16 or 17 replaces some of these)
INSERT INTO @M
SELECT 18, o.Name + ' (SystemAccount3-Step18)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%SystemAccount3-Step18%' THEN 1 ELSE 0 END
FROM (VALUES ('View_Users'), ('fn_UserChangeRefusal'), ('spr_GetUserListForUserPage'), ('spr_GetUser'), ('spr_GetActiveUserList'),
             ('spr_AddEditCommittee'), ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'),
             ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaByAgendaId'), ('spr_MinutesFinalizeByMeetingId'),
             ('spr_UpdateMinutes'), ('spr_GetAlertMailId'), ('spr_sys_ResetDatabase')) o(Name);
DECLARE @SystemAccounts INT = 0;
IF (COL_LENGTH('dbo.Users', 'IsSystem') IS NOT NULL)
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.Users WHERE IsSystem = 1', N'@n INT OUTPUT', @n = @SystemAccounts OUTPUT;
INSERT INTO @M VALUES
(18, 'Users.IsSystem NOT NULL', CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'IsSystem' AND is_nullable = 0) THEN 1 ELSE 0 END),
(18, 'CK_Users_IsSystem', CASE WHEN EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.Users') AND name = 'CK_Users_IsSystem') THEN 1 ELSE 0 END),
(18, 'Exactly one system account (found ' + CAST(@SystemAccounts AS VARCHAR(12)) + ')', CASE WHEN @SystemAccounts = 1 THEN 1 ELSE 0 END);

-- 19. BMMS-Fix-OrganisationSettings-Step19.sql (replaces nothing; no earlier script contains these)
DECLARE @OrgRows INT = 0;
IF (OBJECT_ID('dbo.App_Setting', 'U') IS NOT NULL)
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.App_Setting WHERE SettingCode IN (''OrganisationName'', ''OrganisationShortName'', ''OrganisationTerm'',
        ''CertificateSignOff'', ''RegisteredOfficeLabel'', ''RegisteredOfficeLine1'', ''RegisteredOfficeLine2'', ''RegisteredOfficeCity'',
        ''RegisteredOfficePinCode'', ''OrganisationPhone'', ''OrganisationFax'', ''OrganisationEmail'')', N'@n INT OUTPUT', @n = @OrgRows OUTPUT;
INSERT INTO @M VALUES
(19, 'spr_GetOrganisationSettings', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetOrganisationSettings')), '') LIKE '%OrganisationSettings-Step19%' THEN 1 ELSE 0 END),
(19, 'spr_SetOrganisationSettings', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '') LIKE '%OrganisationSettings-Step19%' THEN 1 ELSE 0 END),
(19, 'spr_RecordOrganisationLogo', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_RecordOrganisationLogo')), '') LIKE '%OrganisationSettings-Step19%' THEN 1 ELSE 0 END),
(19, 'The 12 organisation setting rows (found ' + CAST(@OrgRows AS VARCHAR(12)) + ')', CASE WHEN @OrgRows = 12 THEN 1 ELSE 0 END);

-- 20. BMMS-Fix-AgendaRouting-Step20.sql (re-running step 16, 17 or 18 replaces the two agenda procedures)
INSERT INTO @M
SELECT 20, o.Name + ' (AgendaRouting-Step20)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%AgendaRouting-Step20%' THEN 1 ELSE 0 END
FROM (VALUES ('fn_AgendaRoute'), ('spr_GetAgendaCreationMailId'), ('spr_AddEditAgenda'), ('spr_UpdateAgendaByAgendaId'),
             ('spr_RerouteWaitingAgendas'), ('spr_GetCompanySecretary'), ('spr_GetMeetingMemberByMeetingIdMemberTypeId')) o(Name);

-- 21. BMMS-Fix-MemberTypes-Step21.sql (re-running step 2, 3, 15 or 18 replaces some of these)
INSERT INTO @M
SELECT 21, o.Name + ' (MemberTypes-Step21)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%MemberTypes-Step21%' THEN 1 ELSE 0 END
FROM (VALUES ('spr_GetMemberType'), ('spr_GetMemberTypeByMemberTypeId'), ('spr_GetMemberTypeForTagging'), ('spr_AddEditMemberType'),
             ('spr_DeleteMemberTypeByMemberTypeId'), ('spr_AddEditCommitteeMember'), ('spr_AddEditMeetingMember'),
             ('spr_sys_ResetDatabase')) o(Name);
DECLARE @ReservedWrong INT = -1;
IF (COL_LENGTH('dbo.Member_Type', 'IsReserved') IS NOT NULL AND COL_LENGTH('dbo.Member_Type', 'MemberScope') IS NOT NULL)
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.Member_Type WHERE MemberTypeId IN (2, 3, 6) AND (IsReserved <> 1 OR MemberScope <> ''M'' OR StatusId <> 1)',
         N'@n INT OUTPUT', @n = @ReservedWrong OUTPUT;
INSERT INTO @M VALUES
(21, 'Member_Type.IsReserved NOT NULL', CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Member_Type') AND name = 'IsReserved' AND is_nullable = 0) THEN 1 ELSE 0 END),
(21, 'Member_Type.MemberScope NOT NULL', CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Member_Type') AND name = 'MemberScope' AND is_nullable = 0) THEN 1 ELSE 0 END),
(21, 'CK_Member_Type_MemberScope', CASE WHEN EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.Member_Type') AND name = 'CK_Member_Type_MemberScope') THEN 1 ELSE 0 END),
(21, 'CK_Member_Type_Reserved', CASE WHEN EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.Member_Type') AND name = 'CK_Member_Type_Reserved') THEN 1 ELSE 0 END),
(21, 'UX_Member_Type_Code', CASE WHEN EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Member_Type') AND name = 'UX_Member_Type_Code' AND is_unique = 1) THEN 1 ELSE 0 END),
(21, 'UX_Member_Type_Name', CASE WHEN EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Member_Type') AND name = 'UX_Member_Type_Name' AND is_unique = 1) THEN 1 ELSE 0 END),
(21, 'Types 2, 3, 6 (where present) reserved, meeting, active'
     + CASE WHEN @ReservedWrong > 0 THEN ' (' + CAST(@ReservedWrong AS VARCHAR(12)) + ' not)' ELSE '' END, CASE WHEN @ReservedWrong = 0 THEN 1 ELSE 0 END);

-- 22. BMMS-Fix-MinutesGating-Step22.sql (replaces nothing)
INSERT INTO @M
SELECT 22, o.Name + ' (MinutesGating-Step22)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%MinutesGating-Step22%' THEN 1 ELSE 0 END
FROM (VALUES ('spr_GetMinutesReportMeetings'), ('spr_GetMinutesReport')) o(Name);

-- 24. BMMS-Fix-MeetingDates-Step24.sql (re-running step 16, 17 or 18 replaces spr_AddEditMeeting)
INSERT INTO @M VALUES
(24, 'spr_AddEditMeeting (MeetingDates-Step24)', CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') LIKE '%MeetingDates-Step24%' THEN 1 ELSE 0 END);

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
(12, 'BMMS-Fix-Attendance-FutureMeeting.sql', 'run step 12 again, then steps 15, 16, 17, 18, 20, 21 and 24'),
(13, 'BMMS-Fix-UserProtection-Stage1.sql', 'step 2, 6 or 10 was re-run: run step 13 again, then 14, 18, 20, 21 and 24'),
(14, 'BMMS-Fix-UserStatus-Stage2a.sql', 'step 13 was re-run: run step 14 again, then 18 and 24'),
(15, 'BMMS-Fix-MeetingLocks.sql', 'step 6, 8 or 12 was re-run: run step 15 again, then steps 16, 17, 18, 20, 21 and 24'),
(16, 'BMMS-Fix-MeetingLocks-Step16.sql', 'step 6, 12 or 15 was re-run: run step 16 again, then steps 17, 18, 20 and 24'),
(17, 'BMMS-Fix-UserStatus-Stage2b.sql', 'step 6, 8, 15 or 16 was re-run: run step 17 again, then steps 18, 20 and 24'),
(18, 'BMMS-Fix-SystemAccount-Stage3.sql', 'step 3, 6, 8, 13, 14, 15, 16 or 17 was re-run, or the system account count is not 1: see README step 18 (then steps 20, 21 and 24)'),
(19, 'BMMS-Fix-OrganisationSettings-Step19.sql', 'a procedure or setting row is missing: run step 19 again (the values already set are kept)'),
(20, 'BMMS-Fix-AgendaRouting-Step20.sql', 'step 16, 17 or 18 was re-run: run step 20 again (the re-route moves nothing a second time)'),
(21, 'BMMS-Fix-MemberTypes-Step21.sql', 'step 2, 3, 15 or 18 was re-run, or a reserved type was changed by hand: run step 21 again'),
(22, 'BMMS-Fix-MinutesGating-Step22.sql', 'a procedure is missing: run step 22 again'),
(24, 'BMMS-Fix-MeetingDates-Step24.sql', 'Missing after a re-run of step 16, 17 or 18: run step 24 again');

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
