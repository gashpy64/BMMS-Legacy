/* ============================================================================
   BMMS - Critical fix #5: tests for BMMS-Fix-FK-Procedures.sql,
   BMMS-Add-ForeignKeys-Step3.sql, BMMS-Fix-MinutesFinalize-Procedure.sql and
   BMMS-Add-ForeignKeys-Step4.sql
   ----------------------------------------------------------------------------
   Run AFTER all four of those scripts.

   Everything runs inside one transaction that is ROLLED BACK at the end, so
   no test data is kept and the agenda / minutes used by tests 12-18 are
   restored. The only lasting effect is that identity values (MemberId, UserId,
   ActionItemId, MinutesId) skip a few numbers.

   Result: one grid, one row per test. Status should be PASS for every row.
   SKIPPED means the data needed for that test does not exist (for example no
   Minutes rows yet); it is not a failure.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

DECLARE @T TABLE (TestNo INT, Test VARCHAR(100), Expected VARCHAR(50), Actual VARCHAR(200));
DECLARE @R TABLE (Result INT);
DECLARE @RU TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));   -- spr_DeleteUserByUserId returns Result, Reason, ReasonDetail

DECLARE @Now DATETIME = GETDATE();
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @DepartmentId INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @RoleId INT = (SELECT TOP 1 RoleId FROM Roles ORDER BY RoleId);
DECLARE @SexId INT = (SELECT TOP 1 SysCodeId FROM SysCodeSetting WHERE MainCode = 'Sex' ORDER BY SysCodeId);

DECLARE @MemberId INT;
DECLARE @MeetingId INT;
DECLARE @CommitteeId INT;
DECLARE @OldChairmanId INT;
DECLARE @UserId INT;
DECLARE @MinutesId INT;
DECLARE @AgendaId INT;
DECLARE @ActionItemId INT;
-- An existing user for the CreatedBy / UpdatedBy columns. Never a hard-coded id:
-- since BMMS-Add-ForeignKeys-Step5.sql those columns must hold a real user.
DECLARE @AnyUserId INT = (SELECT TOP 1 UserId FROM Users ORDER BY UserId);
DECLARE @AdminId INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                        WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 ORDER BY u.UserId);   -- acting user for the protected procedures

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Member.State_Id
    ---------------------------------------------------------------------------
    EXEC spr_AddEditMember @Code = 'Save', @MemberId = 0, @MemberCode = 'ZZFKTEST', @MemberName = 'FK test member',
         @SexId = @SexId, @DesignationId = @DesignationId, @DOB = '', @Address1 = '', @Address2 = '', @Address3 = '',
         @CityName = '', @State_Id = '0', @PinCode = '', @DOJ = '', @EmailId = '', @DinNo = '', @PhotoPath = '',
         @ResumePath = '', @RelievingDate = '', @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @AnyUserId,
         @UpdatedOn = @Now, @UpdatedBy = @AnyUserId;

    SET @MemberId = (SELECT MemberId FROM Member WHERE MemberCode = 'ZZFKTEST');

    INSERT INTO @T
    SELECT 1, 'Member saved with no state: State_Id stored as NULL', 'NULL', ISNULL(CAST(State_Id AS VARCHAR(12)), 'NULL')
    FROM Member WHERE MemberId = @MemberId;

    BEGIN TRY
        UPDATE Member SET State_Id = -1 WHERE MemberId = @MemberId;
        INSERT INTO @T VALUES (2, 'Key rejects a State_Id that is not in State_Master', 'Error 547', 'No error');
    END TRY
    BEGIN CATCH
        INSERT INTO @T VALUES (2, 'Key rejects a State_Id that is not in State_Master', 'Error 547', 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)));
    END CATCH

    ---------------------------------------------------------------------------
    -- Meeting.ChairmanNameId
    ---------------------------------------------------------------------------
    SELECT TOP 1 @MeetingId = MeetingId, @CommitteeId = CommitteeId, @OldChairmanId = ChairmanNameId
    FROM Meeting ORDER BY MeetingId;

    IF (@MeetingId IS NULL)
    BEGIN
        INSERT INTO @T VALUES (3, 'Chairman that does not exist is ignored', '', 'SKIPPED');
        INSERT INTO @T VALUES (4, 'Chairman that exists is saved', '', 'SKIPPED');
        INSERT INTO @T VALUES (5, 'Delete of a member who is a chairman: Result', '', 'SKIPPED');
        INSERT INTO @T VALUES (6, 'Member who is a chairman still exists', '', 'SKIPPED');
    END
    ELSE
    BEGIN
        -- Step 15: the chairman can only change while the minutes are not finalized
        UPDATE Meeting SET MinutesStatus = 'Open' WHERE MeetingId = @MeetingId;

        EXEC spr_UpdateMeetingChairman @MeetingId = @MeetingId, @CommitteeId = @CommitteeId, @ChairmanNameId = -1;

        INSERT INTO @T
        SELECT 3, 'Chairman that does not exist is ignored',
               ISNULL(CAST(@OldChairmanId AS VARCHAR(12)), 'NULL'), ISNULL(CAST(ChairmanNameId AS VARCHAR(12)), 'NULL')
        FROM Meeting WHERE MeetingId = @MeetingId;

        EXEC spr_UpdateMeetingChairman @MeetingId = @MeetingId, @CommitteeId = @CommitteeId, @ChairmanNameId = @MemberId;

        INSERT INTO @T
        SELECT 4, 'Chairman that exists is saved',
               CAST(@MemberId AS VARCHAR(12)), ISNULL(CAST(ChairmanNameId AS VARCHAR(12)), 'NULL')
        FROM Meeting WHERE MeetingId = @MeetingId;

        DELETE FROM @R;
        INSERT INTO @R EXEC spr_DeleteMemberByMemberId @MemberId = @MemberId;

        INSERT INTO @T
        SELECT 5, 'Delete of a member who is a chairman: Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

        INSERT INTO @T
        SELECT 6, 'Member who is a chairman still exists', '1', CAST(COUNT(*) AS VARCHAR(12))
        FROM Member WHERE MemberId = @MemberId;
    END

    ---------------------------------------------------------------------------
    -- Action_Item.MinutesId and ActionItem_User_Map.UserId
    ---------------------------------------------------------------------------
    BEGIN TRY
        INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy)
        VALUES (-1, '', '', '', @Now, @AnyUserId);
        INSERT INTO @T VALUES (7, 'Key rejects an Action_Item for minutes that do not exist', 'Error 547', 'No error');
    END TRY
    BEGIN CATCH
        INSERT INTO @T VALUES (7, 'Key rejects an Action_Item for minutes that do not exist', 'Error 547', 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)));
    END CATCH

    SET @MinutesId = (SELECT TOP 1 MinutesId FROM Minutes ORDER BY MinutesId);

    IF (@MinutesId IS NULL)
    BEGIN
        INSERT INTO @T VALUES (8, 'Key rejects a map row for a user that does not exist', '', 'SKIPPED');
        INSERT INTO @T VALUES (9, 'Delete of a user with action-item map rows: Result', '', 'SKIPPED');
        INSERT INTO @T VALUES (10, 'Map rows of the deleted user', '', 'SKIPPED');
        INSERT INTO @T VALUES (11, 'Deleted user is gone', '', 'SKIPPED');
        INSERT INTO @T VALUES (12, 'Agenda delete: agenda is gone', '', 'SKIPPED');
        INSERT INTO @T VALUES (13, 'Agenda delete: its action item is gone', '', 'SKIPPED');
    END
    ELSE
    BEGIN
        SET @AgendaId = (SELECT AgendaId FROM Minutes WHERE MinutesId = @MinutesId);

        INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy)
        VALUES (@MinutesId, 'FK test', '', 'Pending', @Now, @AnyUserId);

        SET @ActionItemId = SCOPE_IDENTITY();

        BEGIN TRY
            INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId)
            VALUES (@ActionItemId, -1, 0, 1);
            INSERT INTO @T VALUES (8, 'Key rejects a map row for a user that does not exist', 'Error 547', 'No error');
        END TRY
        BEGIN CATCH
            INSERT INTO @T VALUES (8, 'Key rejects a map row for a user that does not exist', 'Error 547', 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)));
        END CATCH

        INSERT INTO Users
        (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password],
         AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
        VALUES
        ('FK test user', @DepartmentId, @DesignationId, NULL, @RoleId, '', 'zzfktestuser', 'not-a-login',
         0, @Now, @AnyUserId, @Now, @AnyUserId);

        SET @UserId = SCOPE_IDENTITY();

        INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId)
        VALUES (@ActionItemId, @UserId, 0, 1);

        DELETE FROM @RU;
        INSERT INTO @RU EXEC spr_DeleteUserByUserId @UserId = @UserId, @ActingUserId = @AdminId;

        INSERT INTO @T
        SELECT 9, 'Delete of a user with action-item map rows: Result', '1', CAST(Result AS VARCHAR(12)) FROM @RU;

        INSERT INTO @T
        SELECT 10, 'Map rows of the deleted user', '0', CAST(COUNT(*) AS VARCHAR(12))
        FROM ActionItem_User_Map WHERE UserId = @UserId;

        INSERT INTO @T
        SELECT 11, 'Deleted user is gone', '0', CAST(COUNT(*) AS VARCHAR(12))
        FROM Users WHERE UserId = @UserId;

        -- The action item is still there, so the agenda delete has to remove it.
        EXEC spr_DeleteAgendaByAgendaId @AgendaId = @AgendaId;

        INSERT INTO @T
        SELECT 12, 'Agenda delete: agenda is gone', '0', CAST(COUNT(*) AS VARCHAR(12))
        FROM Agenda WHERE AgendaId = @AgendaId;

        INSERT INTO @T
        SELECT 13, 'Agenda delete: its action item is gone', '0', CAST(COUNT(*) AS VARCHAR(12))
        FROM Action_Item WHERE ActionItemId = @ActionItemId;
    END

    ---------------------------------------------------------------------------
    -- Agenda finalize (uses minutes of another agenda, if there are any left)
    ---------------------------------------------------------------------------
    SET @MinutesId = (SELECT TOP 1 MinutesId FROM Minutes ORDER BY MinutesId);

    IF (@MinutesId IS NULL)
    BEGIN
        INSERT INTO @T VALUES (14, 'Agenda finalize: old action item is gone', '', 'SKIPPED');
        INSERT INTO @T VALUES (15, 'Agenda finalize: no action item left without minutes', '', 'SKIPPED');
    END
    ELSE
    BEGIN
        SET @MeetingId = (SELECT a.MeetingId FROM Minutes m INNER JOIN Agenda a ON a.AgendaId = m.AgendaId
                          WHERE m.MinutesId = @MinutesId);

        INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy)
        VALUES (@MinutesId, 'FK test', '', 'Pending', @Now, @AnyUserId);

        SET @ActionItemId = SCOPE_IDENTITY();

        -- Step 15: the agenda can only be finalized from AgendaStatus 'Open'
        UPDATE Meeting SET AgendaStatus = 'Open' WHERE MeetingId = @MeetingId;

        EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @MeetingId;

        INSERT INTO @T
        SELECT 14, 'Agenda finalize: old action item is gone', '0', CAST(COUNT(*) AS VARCHAR(12))
        FROM Action_Item WHERE ActionItemId = @ActionItemId;

        INSERT INTO @T
        SELECT 15, 'Agenda finalize: no action item left without minutes', '0', CAST(COUNT(*) AS VARCHAR(12))
        FROM Action_Item ai WHERE NOT EXISTS (SELECT 1 FROM Minutes m WHERE m.MinutesId = ai.MinutesId);
    END

    ---------------------------------------------------------------------------
    -- Minutes finalize (BMMS-Fix-MinutesFinalize-Procedure.sql)
    ---------------------------------------------------------------------------
    SET @MinutesId = (SELECT TOP 1 MinutesId FROM Minutes ORDER BY MinutesId);

    -- The procedures treat DecisionTypeId = 1 as "Followup". If that row has
    -- been deleted, put it back for the test (rolled back with everything else).
    IF (@MinutesId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Decision_Type WHERE DecisionTypeId = 1))
    BEGIN
        SET IDENTITY_INSERT Decision_Type ON;

        INSERT INTO Decision_Type
        (DecisionTypeId, DecisionTypeCode, DecisionTypeName, StatusId, IsDelete, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
        VALUES
        (1, 'ZZFKTEST', 'FK test followup', 1, 1, @Now, 1, @Now, 1);

        SET IDENTITY_INSERT Decision_Type OFF;
    END

    IF (@MinutesId IS NULL)
    BEGIN
        INSERT INTO @T VALUES (16, 'Minutes finalize: one action item per follow-up minute', '', 'SKIPPED');
        INSERT INTO @T VALUES (17, 'Minutes finalize: every user mapped once to it', '', 'SKIPPED');
        INSERT INTO @T VALUES (18, 'Minutes finalize: no duplicate map rows', '', 'SKIPPED');
    END
    ELSE
    BEGIN
        SET @MeetingId = (SELECT a.MeetingId FROM Minutes m INNER JOIN Agenda a ON a.AgendaId = m.AgendaId
                          WHERE m.MinutesId = @MinutesId);
        SET @AnyUserId = (SELECT TOP 1 UserId FROM Users ORDER BY UserId);

        -- Same state spr_UpdateMinutes leaves behind: a follow-up minute that
        -- already has its action item, mapped to one user.
        UPDATE Minutes SET DecisionTypeId = 1 WHERE MinutesId = @MinutesId;

        INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy)
        VALUES (@MinutesId, 'FK test', '', '', @Now, @AnyUserId);

        SET @ActionItemId = SCOPE_IDENTITY();

        INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId)
        VALUES (@ActionItemId, @AnyUserId, 1, 1);

        -- Step 15: the minutes can only be finalized from MinutesStatus 'Open'
        UPDATE Meeting SET MinutesStatus = 'Open' WHERE MeetingId = @MeetingId;

        -- Twice on purpose: the second run must not add anything (from step 15 it is refused).
        EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MeetingId, @UserId = @AnyUserId;
        EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MeetingId, @UserId = @AnyUserId;

        INSERT INTO @T
        SELECT 16, 'Minutes finalize: one action item per follow-up minute', '1', CAST(COUNT(*) AS VARCHAR(12))
        FROM Action_Item WHERE MinutesId = @MinutesId;

        INSERT INTO @T
        SELECT 17, 'Minutes finalize: every user mapped once to it',
               CAST((SELECT COUNT(*) FROM Users) AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12))
        FROM ActionItem_User_Map WHERE ActionItemId = @ActionItemId;

        INSERT INTO @T
        SELECT 18, 'Minutes finalize: no duplicate map rows', '0', CAST(COUNT(*) AS VARCHAR(12))
        FROM (SELECT ActionItemId, UserId FROM ActionItem_User_Map
              GROUP BY ActionItemId, UserId HAVING COUNT(*) > 1) d;
    END

    ---------------------------------------------------------------------------
    -- Users.ManagerId (BMMS-Add-ForeignKeys-Step4.sql)
    ---------------------------------------------------------------------------
    -- UserDB.AddEditUser sends NULL (DBNull.Value) when no manager is selected.
    EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'FK test user 2', @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = NULL, @RoleId = @RoleId, @EmailId = '',
         @LoginName = 'zzfktestuser2', @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = @AdminId,
         @UpdatedOn = @Now, @UpdatedBy = @AdminId;

    INSERT INTO @T
    SELECT 19, 'User saved with no manager: ManagerId stored as NULL', 'NULL', ISNULL(CAST(ManagerId AS VARCHAR(12)), 'NULL')
    FROM Users WHERE LoginName = 'zzfktestuser2';

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES (99, 'Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 170));
END CATCH

IF (@@TRANCOUNT > 0)
BEGIN
    ROLLBACK TRANSACTION;
END

-- In case an error skipped the OFF above (harmless when it is already off).
SET IDENTITY_INSERT Decision_Type OFF;

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM @T
ORDER BY TestNo;

-- Confirm nothing was kept: all three counts should be 0.
SELECT (SELECT COUNT(*) FROM Member WHERE MemberCode = 'ZZFKTEST') AS TestMembersLeft,
       (SELECT COUNT(*) FROM Users WHERE LoginName IN ('zzfktestuser', 'zzfktestuser2')) AS TestUsersLeft,
       (SELECT COUNT(*) FROM Action_Item WHERE Directions = 'FK test') AS TestActionItemsLeft;
GO

SET NOEXEC OFF;
GO
