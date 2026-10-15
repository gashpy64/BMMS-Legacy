/* ============================================================================
   BMMS - Critical fix #5: tests for BMMS-Fix-UserDelete-Procedure.sql and
   BMMS-Add-ForeignKeys-Step5.sql
   ----------------------------------------------------------------------------
   Run AFTER both of those scripts.

   Everything runs inside one transaction that is ROLLED BACK at the end, so
   no test data is kept. The only lasting effect is that identity values
   (UserId, ActionItemId, ...) skip a few numbers.

   What is tested:
     * a user with no history is deleted
     * a user who only has alerts received / action-item read flags is deleted
       and those rows go with them
     * a user who approved an agenda, finalized minutes or confirmed minutes
       (through the real procedures) is NOT deleted
     * one test per protected column (40): put the test user's id in that
       column of an existing row, try to delete, expect Result = 0
     * one test per foreign key to Users (23): the key rejects an id that is
       not a user
     * a mail or login audit row dated before the user was created (an id
       reused from a user deleted long ago) does not block the delete

   Result: one grid, one row per test. Status should be PASS for every row.
   SKIPPED means the table has no row to test with; it is not a failure.
   A key test that says "No error" means BMMS-Add-ForeignKeys-Step5.sql has
   not been run, or refused that key.

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

-- Blocks = 1: the delete must be refused while the column holds the user.
-- HasKey = 1: the column has a foreign key to Users.
DECLARE @Cols TABLE (ColNo INT IDENTITY(1,1), TableName SYSNAME, ColumnName SYSNAME, Blocks INT, HasKey INT);

INSERT INTO @Cols (TableName, ColumnName, Blocks, HasKey) VALUES
('Users', 'ManagerId', 1, 1), ('Users', 'CreatedBy', 1, 0), ('Users', 'UpdatedBy', 1, 1),
('Agenda', 'CreatedBy', 1, 1), ('Agenda', 'UpdatedBy', 1, 1),
('Agenda', 'MgrApprovedBy', 1, 1), ('Agenda', 'ControllerApprovedBy', 1, 1),
('Meeting', 'CreatedBy', 1, 1), ('Meeting', 'UpdatedBy', 1, 1),
('Minutes', 'CreatedBy', 1, 0), ('Minutes', 'UpdatedBy', 1, 0),
('Committee', 'CreatedBy', 1, 1), ('Committee', 'UpdatedBy', 1, 1),
('Committee_Member', 'CreatedBy', 1, 1), ('Committee_Member', 'UpdatedBy', 1, 1),
('Meeting_Member', 'CreatedBy', 1, 1), ('Meeting_Member', 'UpdatedBy', 1, 1),
('Member', 'CreatedBy', 1, 1), ('Member', 'UpdatedBy', 1, 1),
('Attendance', 'UpdatedBy', 1, 1),
('Action_Item', 'UpdatedBy', 1, 1),
('Alert_Master', 'CreatedBy', 1, 1),
('Audit_Trail_Master', 'Update_By', 1, 1),
('Audit_Trail_SendMail', 'Mail_Send_By', 1, 0),
('Audit_Trail_SqlBackup', 'User_Id', 1, 1),
('Audit_Trial_Login', 'User_Id', 1, 0),
('Department', 'CreatedBy', 1, 0), ('Department', 'UpdatedBy', 1, 0),
('Designation', 'CreatedBy', 1, 0), ('Designation', 'UpdatedBy', 1, 0),
('Roles', 'CreatedBy', 1, 0), ('Roles', 'UpdatedBy', 1, 0),
('Alert_Type', 'CreatedBy', 1, 0), ('Alert_Type', 'UpdatedBy', 1, 0),
('Decision_Type', 'CreatedBy', 1, 0), ('Decision_Type', 'UpdatedBy', 1, 0),
('Member_Type', 'CreatedBy', 1, 0), ('Member_Type', 'UpdatedBy', 1, 0),
('Subject_Type', 'CreatedBy', 1, 0), ('Subject_Type', 'UpdatedBy', 1, 0),
('Alert_User_Map', 'UserId', 0, 1),
('ActionItem_User_Map', 'UserId', 0, 1);

DECLARE @Now DATETIME = GETDATE();
DECLARE @AdminId INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                        WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 ORDER BY u.UserId);   -- acting user for the protected procedures
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @DepartmentId INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @RoleId INT = (SELECT TOP 1 RoleId FROM Roles ORDER BY RoleId);

DECLARE @UserA INT;      -- no history
DECLARE @UserB INT;      -- only alerts received / read flags
DECLARE @UserC INT;      -- approves, finalizes, confirms
DECLARE @UserD INT;      -- per-column tests
DECLARE @UserE INT;      -- id with older audit rows
DECLARE @AlertId INT;
DECLARE @MinutesId INT;
DECLARE @ActionItemId INT;
DECLARE @AgendaId INT;
DECLARE @MeetingId INT;
DECLARE @ShortText VARCHAR(MAX);
DECLARE @ProposedResolution VARCHAR(MAX);
DECLARE @ColNo INT;
DECLARE @ColCount INT;
DECLARE @TableName SYSNAME;
DECLARE @ColumnName SYSNAME;
DECLARE @Blocks INT;
DECLARE @HasKey INT;
DECLARE @Sql NVARCHAR(MAX);
DECLARE @Rows INT;
DECLARE @Label VARCHAR(120);

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Four test users (inserted directly; no login is possible with them)
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
                       AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ delete test A', @DepartmentId, @DesignationId, NULL, @RoleId, '', 'zzdeltesta', 'not-a-login', 0, @Now, NULL, NULL, NULL);
    SET @UserA = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
                       AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ delete test B', @DepartmentId, @DesignationId, NULL, @RoleId, '', 'zzdeltestb', 'not-a-login', 0, @Now, NULL, NULL, NULL);
    SET @UserB = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
                       AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ delete test C', @DepartmentId, @DesignationId, NULL, @RoleId, '', 'zzdeltestc', 'not-a-login', 0, @Now, NULL, NULL, NULL);
    SET @UserC = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
                       AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ delete test D', @DepartmentId, @DesignationId, NULL, @RoleId, '', 'zzdeltestd', 'not-a-login', 0, @Now, NULL, NULL, NULL);
    SET @UserD = SCOPE_IDENTITY();

    -- The per-column test for Action_Item needs a row; make one if minutes exist.
    SET @MinutesId = (SELECT TOP 1 MinutesId FROM Minutes ORDER BY MinutesId);

    IF (@MinutesId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Action_Item))
        INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy)
        VALUES (@MinutesId, 'ZZ delete test', '', 'Pending', @Now, NULL);

    SET @ActionItemId = (SELECT TOP 1 ActionItemId FROM Action_Item ORDER BY ActionItemId);

    -- Same for the two tables that are often empty: give the key tests a row.
    IF (@ActionItemId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ActionItem_User_Map))
        INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId) VALUES (@ActionItemId, @UserD, 0, 1);

    IF (NOT EXISTS (SELECT 1 FROM Meeting_Member)
        AND EXISTS (SELECT 1 FROM Meeting) AND EXISTS (SELECT 1 FROM Member) AND EXISTS (SELECT 1 FROM Member_Type))
        INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy)
        SELECT (SELECT TOP 1 MeetingId FROM Meeting ORDER BY MeetingId), (SELECT TOP 1 MemberId FROM Member ORDER BY MemberId),
               (SELECT TOP 1 MemberTypeId FROM Member_Type ORDER BY MemberTypeId), 1, @Now, NULL;
    SET @AlertId = (SELECT TOP 1 AlertId FROM Alert_Master ORDER BY AlertId);

    ---------------------------------------------------------------------------
    -- A user with no history is deleted
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @UserA, @ActingUserId = @AdminId;

    INSERT INTO @T SELECT 'User with no history: Result', '1', CAST(Result AS VARCHAR(12)) FROM @R;
    INSERT INTO @T SELECT 'User with no history is gone', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM Users WHERE UserId = @UserA;

    ---------------------------------------------------------------------------
    -- Reused id: audit rows older than the user do not block
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
                       AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ delete test E', @DepartmentId, @DesignationId, NULL, @RoleId, '', 'zzdelteste', 'not-a-login', 0, @Now, NULL, NULL, NULL);
    SET @UserE = SCOPE_IDENTITY();

    INSERT INTO Audit_Trail_SendMail (Mail_To, Mail_Subject, Mail_Body_Text, Mail_Attachment_Path, Mail_Send_On, Mail_Send_By)
    VALUES ('', 'ZZ delete test', '', '', DATEADD(YEAR, -5, @Now), @UserE);

    INSERT INTO Audit_Trial_Login ([User_Id], Login_DateTime, Login_Status, User_IP_Address, Server_Url)
    VALUES (@UserE, DATEADD(YEAR, -5, @Now), 'C', '', '');

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @UserE, @ActingUserId = @AdminId;

    INSERT INTO @T SELECT 'User whose id has only OLDER mail / login rows: Result', '1', CAST(Result AS VARCHAR(12)) FROM @R;
    INSERT INTO @T SELECT 'That user is gone', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM Users WHERE UserId = @UserE;

    ---------------------------------------------------------------------------
    -- Alerts received and action-item read flags do not block; they go with the user
    ---------------------------------------------------------------------------
    IF (@AlertId IS NULL AND @ActionItemId IS NULL)
    BEGIN
        INSERT INTO @T VALUES ('User with only alerts received / read flags: Result', '', 'SKIPPED');
        INSERT INTO @T VALUES ('Their Alert_User_Map and ActionItem_User_Map rows', '', 'SKIPPED');
        INSERT INTO @T VALUES ('That user is gone', '', 'SKIPPED');
    END
    ELSE
    BEGIN
        IF (@AlertId IS NOT NULL)
            INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@AlertId, @UserB, 0, 1);

        IF (@ActionItemId IS NOT NULL)
            INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId) VALUES (@ActionItemId, @UserB, 0, 1);

        DELETE FROM @R;
        INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @UserB, @ActingUserId = @AdminId;

        INSERT INTO @T SELECT 'User with only alerts received / read flags: Result', '1', CAST(Result AS VARCHAR(12)) FROM @R;

        INSERT INTO @T
        SELECT 'Their Alert_User_Map and ActionItem_User_Map rows', '0',
               CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE UserId = @UserB)
                  + (SELECT COUNT(*) FROM ActionItem_User_Map WHERE UserId = @UserB) AS VARCHAR(12));

        INSERT INTO @T SELECT 'That user is gone', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM Users WHERE UserId = @UserB;
    END

    ---------------------------------------------------------------------------
    -- Approval, finalize and confirm history (through the real procedures)
    ---------------------------------------------------------------------------
    SELECT TOP 1 @AgendaId = AgendaId, @MeetingId = MeetingId,
                 @ShortText = ShortText, @ProposedResolution = ProposedResolution
    FROM Agenda ORDER BY AgendaId;

    IF (@AgendaId IS NULL)
    BEGIN
        INSERT INTO @T VALUES ('Delete of a user who approved an agenda: Result', '', 'SKIPPED');
        INSERT INTO @T VALUES ('Delete of a user who finalized minutes: Result', '', 'SKIPPED');
        INSERT INTO @T VALUES ('Delete of a user who confirmed minutes: Result', '', 'SKIPPED');
        INSERT INTO @T VALUES ('Delete of a user who approved and finalized: Result', '', 'SKIPPED');
        INSERT INTO @T VALUES ('That user still exists', '', 'SKIPPED');
    END
    ELSE
    BEGIN
        SAVE TRANSACTION HistoryTest;

        EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgendaId, @ShortText = @ShortText,
             @ProposedResolution = @ProposedResolution, @MgrComments = '', @ControllerComments = 'ZZ delete test',
             @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @UserC;

        DELETE FROM @R;
        INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @UserC, @ActingUserId = @AdminId;
        INSERT INTO @T SELECT 'Delete of a user who approved an agenda: Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

        ROLLBACK TRANSACTION HistoryTest;
        SAVE TRANSACTION HistoryTest;

        EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MeetingId, @UserId = @UserC;

        DELETE FROM @R;
        INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @UserC, @ActingUserId = @AdminId;
        INSERT INTO @T SELECT 'Delete of a user who finalized minutes: Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

        ROLLBACK TRANSACTION HistoryTest;
        SAVE TRANSACTION HistoryTest;

        EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MeetingId, @UserId = @UserC;

        DELETE FROM @R;
        INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @UserC, @ActingUserId = @AdminId;
        INSERT INTO @T SELECT 'Delete of a user who confirmed minutes: Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

        ROLLBACK TRANSACTION HistoryTest;
        SAVE TRANSACTION HistoryTest;

        -- The case that went wrong: approvals and finalized minutes together.
        EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgendaId, @ShortText = @ShortText,
             @ProposedResolution = @ProposedResolution, @MgrComments = '', @ControllerComments = 'ZZ delete test',
             @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @UserC;

        EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MeetingId, @UserId = @UserC;

        DELETE FROM @R;
        INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @UserC, @ActingUserId = @AdminId;
        INSERT INTO @T SELECT 'Delete of a user who approved and finalized: Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;
        INSERT INTO @T SELECT 'That user still exists', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Users WHERE UserId = @UserC;

        ROLLBACK TRANSACTION HistoryTest;
    END

    ---------------------------------------------------------------------------
    -- One test per protected column
    ---------------------------------------------------------------------------
    SET @ColNo = 1;
    SET @ColCount = (SELECT COUNT(*) FROM @Cols);

    WHILE (@ColNo <= @ColCount)
    BEGIN
        SELECT @TableName = TableName, @ColumnName = ColumnName, @Blocks = Blocks
        FROM @Cols WHERE ColNo = @ColNo;

        IF (@Blocks = 1)
        BEGIN
            SET @Label = 'Delete refused: user in ' + @TableName + '.' + @ColumnName;

            SAVE TRANSACTION ColumnTest;

            -- The two audit tables only count rows dated after the user was created.
            SET @Sql = N'UPDATE TOP (1) dbo.' + QUOTENAME(@TableName) + N' SET ' + QUOTENAME(@ColumnName) + N' = @u'
                     + CASE WHEN @TableName = 'Audit_Trail_SendMail' THEN N', Mail_Send_On = DATEADD(MINUTE, 1, GETDATE())'
                            WHEN @TableName = 'Audit_Trial_Login' THEN N', Login_DateTime = DATEADD(MINUTE, 1, GETDATE())'
                            ELSE N'' END
                     + CASE WHEN @TableName = 'Users' THEN N' WHERE UserId <> @u' ELSE N'' END
                     + N'; SET @n = @@ROWCOUNT;';

            EXEC sp_executesql @Sql, N'@u INT, @n INT OUTPUT', @u = @UserD, @n = @Rows OUTPUT;

            IF (@Rows = 0)
                INSERT INTO @T VALUES (@Label, '', 'SKIPPED');
            ELSE
            BEGIN
                DELETE FROM @R;
                INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @UserD, @ActingUserId = @AdminId;

                INSERT INTO @T
                SELECT @Label, 'Result 0, user kept',
                       'Result ' + CAST(Result AS VARCHAR(12)) + ', user '
                       + CASE WHEN EXISTS (SELECT 1 FROM Users WHERE UserId = @UserD) THEN 'kept' ELSE 'DELETED' END
                FROM @R;
            END

            ROLLBACK TRANSACTION ColumnTest;
        END

        SET @ColNo = @ColNo + 1;
    END

    ---------------------------------------------------------------------------
    -- One test per foreign key to Users
    ---------------------------------------------------------------------------
    SET @ColNo = 1;

    WHILE (@ColNo <= @ColCount)
    BEGIN
        SELECT @TableName = TableName, @ColumnName = ColumnName, @HasKey = HasKey
        FROM @Cols WHERE ColNo = @ColNo;

        IF (@HasKey = 1)
        BEGIN
            SET @Label = 'Key rejects an unknown user in ' + @TableName + '.' + @ColumnName;

            SAVE TRANSACTION KeyTest;

            SET @Sql = N'UPDATE TOP (1) dbo.' + QUOTENAME(@TableName) + N' SET ' + QUOTENAME(@ColumnName) + N' = -1; SET @n = @@ROWCOUNT;';

            BEGIN TRY
                EXEC sp_executesql @Sql, N'@n INT OUTPUT', @n = @Rows OUTPUT;

                IF (@Rows = 0)
                    INSERT INTO @T VALUES (@Label, '', 'SKIPPED');
                ELSE
                    INSERT INTO @T VALUES (@Label, 'Error 547', 'No error');
            END TRY
            BEGIN CATCH
                INSERT INTO @T VALUES (@Label, 'Error 547', 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)));
            END CATCH

            IF (XACT_STATE() = 1)
                ROLLBACK TRANSACTION KeyTest;
        END

        SET @ColNo = @ColNo + 1;
    END

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
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
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zzdeltest%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Action_Item WHERE CAST(Directions AS VARCHAR(50)) = 'ZZ delete test') AS TestActionItemsLeft;
GO

SET NOEXEC OFF;
GO
