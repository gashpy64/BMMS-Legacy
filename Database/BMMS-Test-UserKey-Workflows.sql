/* ============================================================================
   BMMS - Critical fix #5: the main workflows still work with the 21 user keys
   (BMMS-Add-ForeignKeys-Step5.sql) and the new spr_DeleteUserByUserId
   ----------------------------------------------------------------------------
   Run AFTER BMMS-Fix-UserDelete-Procedure.sql and BMMS-Add-ForeignKeys-Step5.sql.

   Calls the same stored procedures the pages call, as three test users
   (a user, their manager and a controller):
     committee created -> meeting created -> agenda added -> manager approves
     -> controller approves -> agenda finalized -> minutes finalized
     -> minutes confirmed -> login recorded -> backup recorded -> mail recorded
   and checks after each step that the rows and the alerts were written with
   the right user id. At the end all three users have history, so deleting
   any of them must be refused.

   Everything runs inside one transaction that is ROLLED BACK at the end, so
   no test data is kept. The only lasting effect is that identity values skip
   a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for that step does not exist.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(120), Expected VARCHAR(50), Actual VARCHAR(250));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));   -- spr_DeleteUserByUserId returns Result, Reason, ReasonDetail

DECLARE @Now DATETIME = GETDATE();
DECLARE @AdminId INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                        WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 ORDER BY u.UserId);   -- acting user for the protected procedures
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @DepartmentId INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @RoleUser INT = ISNULL((SELECT RoleId FROM Roles WHERE RoleCode = 'user'), (SELECT TOP 1 RoleId FROM Roles ORDER BY RoleId));
DECLARE @RoleManager INT = ISNULL((SELECT RoleId FROM Roles WHERE RoleCode = 'manager'), @RoleUser);
DECLARE @RoleController INT = ISNULL((SELECT RoleId FROM Roles WHERE RoleCode = 'controller'), @RoleUser);

DECLARE @Usr INT;
DECLARE @Mgr INT;
DECLARE @Ctl INT;
DECLARE @CommitteeId INT;
DECLARE @MeetingId INT;
DECLARE @AgendaId INT;
DECLARE @MinutesId INT;
DECLARE @AlertId INT;
DECLARE @OtherUsers INT;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Three test users (inserted directly; no login is possible with them)
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
                       AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ workflow controller', @DepartmentId, @DesignationId, NULL, @RoleController, '', 'zzwftestctl', 'not-a-login', 0, @Now, NULL, NULL, NULL);
    SET @Ctl = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
                       AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ workflow manager', @DepartmentId, @DesignationId, NULL, @RoleManager, '', 'zzwftestmgr', 'not-a-login', 0, @Now, NULL, NULL, NULL);
    SET @Mgr = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
                       AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ workflow user', @DepartmentId, @DesignationId, @Mgr, @RoleUser, '', 'zzwftestusr', 'not-a-login', 0, @Now, NULL, NULL, NULL);
    SET @Usr = SCOPE_IDENTITY();

    -- Step 17: alerts, action items and alert mail go to active users only, and a user's agenda is
    -- refused while their manager is inactive. The three test users are switched on (rolled back)
    -- and "every other user" counts active users only.
    IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), '') LIKE '%UserStatus2b-Step17%')
    BEGIN
        UPDATE Users SET AccountStatus = 1 WHERE UserId IN (@Usr, @Mgr, @Ctl);
        SET @OtherUsers = (SELECT COUNT(*) FROM Users WHERE AccountStatus = 1) - 1;
    END
    ELSE
        SET @OtherUsers = (SELECT COUNT(*) FROM Users) - 1;

    ---------------------------------------------------------------------------
    -- Committee created (alert sent to every other user)
    ---------------------------------------------------------------------------
    EXEC spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'ZT1', @CommitteeName = 'ZZ workflow test committee',
         @Board = 0, @IncorporationDate = @Now, @MeetingStartNo = 1, @CommitteeColorCode = '#FFFFFF', @CessationDate = '',
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;

    SET @CommitteeId = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'ZT1');

    INSERT INTO @T
    SELECT 'Committee created by the controller', CAST(@Ctl AS VARCHAR(12)), ISNULL(CAST(CreatedBy AS VARCHAR(12)), 'NULL')
    FROM Committee WHERE CommitteeId = @CommitteeId;

    SET @AlertId = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Committee' AND SourceTypeId = @CommitteeId ORDER BY AlertId DESC);

    INSERT INTO @T
    SELECT 'Committee alert: sender', CAST(@Ctl AS VARCHAR(12)), ISNULL(CAST(CreatedBy AS VARCHAR(12)), 'NULL')
    FROM Alert_Master WHERE AlertId = @AlertId;

    INSERT INTO @T
    SELECT 'Committee alert: sent to every other user', CAST(@OtherUsers AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12))
    FROM Alert_User_Map WHERE AlertId = @AlertId;

    ---------------------------------------------------------------------------
    -- Meeting created
    ---------------------------------------------------------------------------
    DELETE FROM @R;   -- since step 16 the meeting procedure returns Result, Reason, ReasonDetail
    INSERT INTO @R EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '00001', @CommitteeId = @CommitteeId, @Place = 'ZZ test',
         @Venue = 'ZZ test', @MeetingDate = @Now, @MeetingTime = '10:00', @AgendaSubmissionDate = @Now, @MeetingColorCode = '#FFFFFF',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;

    SET @MeetingId = (SELECT MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId);

    INSERT INTO @T
    SELECT 'Meeting created by the controller', CAST(@Ctl AS VARCHAR(12)), ISNULL(CAST(CreatedBy AS VARCHAR(12)), 'NULL')
    FROM Meeting WHERE MeetingId = @MeetingId;

    INSERT INTO @T
    SELECT 'Meeting alert: sent to every other user', CAST(@OtherUsers AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12))
    FROM Alert_User_Map WHERE AlertId = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @MeetingId ORDER BY AlertId DESC);

    ---------------------------------------------------------------------------
    -- Agenda added by the user
    ---------------------------------------------------------------------------
    -- Step 16: the agenda procedures take the acting user, who must be active
    -- (the test users are inserted inactive; this one is switched on, rolled back)
    DELETE FROM @R;
    IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') LIKE '%MeetingLocks-Step16%')
    BEGIN
        UPDATE Users SET AccountStatus = 1 WHERE UserId = @Usr;

        INSERT INTO @R EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @CommitteeId, @MeetingId = @MeetingId,
             @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ workflow test agenda', @AgendaType = 'Text',
             @AgendaText = 'ZZ test', @AgendaTextPath = '', @ProposedResolution = 'ZZ test resolution', @FilePath = '',
             @MgrComments = '', @ControllerComments = '', @CurrentStatus = '', @CreatedOn = @Now, @CreatedBy = @Usr,
             @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = 0, @ActingUserId = @Usr;
    END
    ELSE
        EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @CommitteeId, @MeetingId = @MeetingId,
             @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ workflow test agenda', @AgendaType = 'Text',
             @AgendaText = 'ZZ test', @AgendaTextPath = '', @ProposedResolution = 'ZZ test resolution', @FilePath = '',
             @MgrComments = '', @ControllerComments = '', @CurrentStatus = '', @CreatedOn = @Now, @CreatedBy = @Usr,
             @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = 0;

    SET @AgendaId = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @MeetingId ORDER BY AgendaId DESC);

    INSERT INTO @T
    SELECT 'Agenda added: created by the user', CAST(@Usr AS VARCHAR(12)), ISNULL(CAST(CreatedBy AS VARCHAR(12)), 'NULL')
    FROM Agenda WHERE AgendaId = @AgendaId;

    SET @AlertId = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId ORDER BY AlertId DESC);

    INSERT INTO @T
    SELECT 'Agenda alert: sender', CAST(@Usr AS VARCHAR(12)), ISNULL(CAST(CreatedBy AS VARCHAR(12)), 'NULL')
    FROM Alert_Master WHERE AlertId = @AlertId;

    INSERT INTO @T
    SELECT 'Agenda alert: sent to the user''s manager', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Alert_User_Map WHERE AlertId = @AlertId AND UserId = @Mgr;

    INSERT INTO @T
    SELECT 'Agenda added: audit trail rows by the user', 'Yes', CASE WHEN COUNT(*) > 0 THEN 'Yes' ELSE 'No' END
    FROM Audit_Trail_Master WHERE Update_By = @Usr;

    ---------------------------------------------------------------------------
    -- Manager approves, then controller approves
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgendaId, @ShortText = 'ZZ workflow test agenda',
         @ProposedResolution = 'ZZ test resolution', @MgrComments = 'ZZ ok', @ControllerComments = '',
         @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;

    INSERT INTO @T
    SELECT 'Manager approval: status / recorded user', 'Approved / ' + CAST(@Mgr AS VARCHAR(12)),
           ISNULL(MgrApprovedStatus, 'NULL') + ' / ' + ISNULL(CAST(UpdatedBy AS VARCHAR(12)), 'NULL')
    FROM Agenda WHERE AgendaId = @AgendaId;

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgendaId, @ShortText = 'ZZ workflow test agenda',
         @ProposedResolution = 'ZZ test resolution', @MgrComments = 'ZZ ok', @ControllerComments = 'ZZ ok',
         @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;

    INSERT INTO @T
    SELECT 'Controller approval: status / recorded user', 'Approved / ' + CAST(@Ctl AS VARCHAR(12)),
           ISNULL(ControllerApprovedStatus, 'NULL') + ' / ' + ISNULL(CAST(UpdatedBy AS VARCHAR(12)), 'NULL')
    FROM Agenda WHERE AgendaId = @AgendaId;

    INSERT INTO @T
    SELECT 'Approvals: audit trail rows by manager and controller', 'Yes',
           CASE WHEN EXISTS (SELECT 1 FROM Audit_Trail_Master WHERE Update_By = @Mgr)
                 AND EXISTS (SELECT 1 FROM Audit_Trail_Master WHERE Update_By = @Ctl) THEN 'Yes' ELSE 'No' END;

    ---------------------------------------------------------------------------
    -- Agenda finalized (creates the minutes)
    ---------------------------------------------------------------------------
    EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @MeetingId;

    SET @MinutesId = (SELECT TOP 1 MinutesId FROM Minutes WHERE AgendaId = @AgendaId ORDER BY MinutesId);

    INSERT INTO @T
    SELECT 'Agenda finalized: minutes created for the agenda', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Minutes WHERE AgendaId = @AgendaId;

    ---------------------------------------------------------------------------
    -- Minutes finalized, then confirmed
    ---------------------------------------------------------------------------
    -- A follow-up decision makes the finalize create an action item.
    IF EXISTS (SELECT 1 FROM Decision_Type WHERE DecisionTypeId = 1)
        UPDATE Minutes SET DecisionTypeId = 1 WHERE MinutesId = @MinutesId;

    EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MeetingId, @UserId = @Ctl;

    INSERT INTO @T
    SELECT 'Minutes finalized: status / recorded user', 'F / ' + CAST(@Ctl AS VARCHAR(12)),
           ISNULL(MinutesStatus, 'NULL') + ' / ' + ISNULL(CAST(UpdatedBy AS VARCHAR(12)), 'NULL')
    FROM Meeting WHERE MeetingId = @MeetingId;

    IF EXISTS (SELECT 1 FROM Decision_Type WHERE DecisionTypeId = 1)
        INSERT INTO @T
        SELECT 'Minutes finalized: action item created by the controller', '1', CAST(COUNT(*) AS VARCHAR(12))
        FROM Action_Item WHERE MinutesId = @MinutesId AND UpdatedBy = @Ctl;
    ELSE
        INSERT INTO @T VALUES ('Minutes finalized: action item created by the controller', '', 'SKIPPED');

    EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MeetingId, @UserId = @Ctl;

    INSERT INTO @T
    SELECT 'Minutes confirmed: status / recorded user', 'C / ' + CAST(@Ctl AS VARCHAR(12)),
           ISNULL(MinutesStatus, 'NULL') + ' / ' + ISNULL(CAST(UpdatedBy AS VARCHAR(12)), 'NULL')
    FROM Meeting WHERE MeetingId = @MeetingId;

    ---------------------------------------------------------------------------
    -- Login audit, backup audit, send-mail audit
    ---------------------------------------------------------------------------
    EXEC spr_RecordLoginByUserId @UserId = @Usr, @User_IP_Address = '127.0.0.1', @Server_Url = 'zz-test';

    INSERT INTO @T
    SELECT 'Login audit row written for the user', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Audit_Trial_Login WHERE [User_Id] = @Usr AND Login_DateTime >= @Now;

    EXEC spr_AddEditAuditTrailSqlBackup @Backup_File_Name = 'zz-test.bak', @User_Id = @Ctl, @User_IP_Address = '127.0.0.1', @Server_Url = 'zz-test';

    INSERT INTO @T
    SELECT 'Backup audit row written for the controller', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Audit_Trail_SqlBackup WHERE [User_Id] = @Ctl;

    EXEC spr_SaveSendMail @Mail_To = 'zz@test', @Mail_Subject = 'ZZ workflow test', @Mail_Body_Text = '', @Mail_Attachment_Path = '', @Mail_Send_By = @Mgr;

    INSERT INTO @T
    SELECT 'Send-mail audit row written for the manager', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Audit_Trail_SendMail WHERE Mail_Send_By = @Mgr AND Mail_Send_On >= @Now;

    ---------------------------------------------------------------------------
    -- All three now have history: none of them can be deleted
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Usr, @ActingUserId = @AdminId;
    INSERT INTO @T SELECT 'Delete of the user (added an agenda, logged in): Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Mgr, @ActingUserId = @AdminId;
    INSERT INTO @T SELECT 'Delete of the manager (approved, sent mail): Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Ctl, @ActingUserId = @AdminId;
    INSERT INTO @T SELECT 'Delete of the controller (approved, finalized, confirmed): Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    INSERT INTO @T
    SELECT 'All three users still exist', '3', CAST(COUNT(*) AS VARCHAR(12))
    FROM Users WHERE UserId IN (@Usr, @Mgr, @Ctl);

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - checks after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 220));
END CATCH

IF (@@TRANCOUNT > 0)
BEGIN
    ROLLBACK TRANSACTION;
END

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM @T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual <> Expected THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM @T;

-- Confirm nothing was kept: both counts should be 0.
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zzwftest%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'ZT1') AS TestCommitteesLeft;
GO

SET NOEXEC OFF;
GO
