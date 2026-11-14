/* ============================================================================
   BMMS - Browser test rows for step F3 (committee with NULL values)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY on the database BMMS_Test: every part stops with a message on any
   other database. It has no USE line: select BMMS_Test in SSMS first.

   The file has four parts. Select the lines of ONE part and press F5.

   PART 0  Read-only. Lists the type, nullability and default of every
           column of Committee, warns when IncorporationDate is not
           datetime, and lists the Status codes of SysCodeSetting
           (the Status list of Committee Master).
   PART 1  Inserts the committee "ZZ F3 test committee" (code ZF3, status
           1) with NULL in IncorporationDate, Board, MeetingStartNo,
           CommitteeColorCode, CessationDate and IsDelete (a column that
           does not allow NULL gets a normal value and a message), and one
           unread Committee alert for the test user pointing to it, with
           the display text "ZZ F3 test - committee with NULL values".
           Department and send option are copied from the newest alert the
           test user already has (as in the F1 test). Prints the new ids.
           Set @TestLogin (the only value to fill in) before running.
   PART 2  Read-only. Shows the test committee, every alert tied to its id
           (with ReadStatus) and its Committee Member rows.
   PART 3  Cleanup, by the committee id only: the Alert_User_Map rows and
           Alert_Master rows tied to the id (the test alert and the alerts
           Committee Master writes on Update), the Committee_Member rows of
           the id (browser test 8), then the committee. Prints the counts.
           It refuses when a meeting, agenda item or attendance row uses
           the id. If the committee was already deleted in the browser,
           set @TestCommitteeId to the id printed by part 1.

   No procedure is created or altered.
   ============================================================================ */


/* ============================================================================
   PART 0 - read-only: Committee columns and the Status list
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Committee'
ORDER BY ORDINAL_POSITION;

DECLARE @DateType NVARCHAR(128);
SELECT @DateType = DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Committee' AND COLUMN_NAME = 'IncorporationDate';

DECLARE @Line NVARCHAR(400);
IF (@DateType = N'datetime')
    PRINT N'IncorporationDate is datetime: the DateTime.MinValue rule of step F3 holds (datetime starts at 1753).';
ELSE
BEGIN
    SET @Line = N'WARNING: IncorporationDate is ' + ISNULL(@DateType, N'(not found)') + N', not datetime. Report this: the DateTime.MinValue rule of step F3 needs another look.';
    PRINT @Line;
END

SELECT SubCode, DisplayName, IsActive, DisplayOrder
FROM SysCodeSetting
WHERE MainCode = 'Status'
ORDER BY DisplayOrder;
GO


/* ============================================================================
   PART 1 - insert the test committee and its alert
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @TestLogin NVARCHAR(100) = N'Controller';    -- the login name of the test user

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @UserId INT;
SELECT @UserId = UserId FROM Users WHERE LoginName = @TestLogin AND AccountStatus = 1 AND IsSystem = 0;
IF (@UserId IS NULL)
BEGIN
    RAISERROR('No active user with the login "%s". Set @TestLogin at the top of part 1 and run again. Nothing was changed.', 16, 1, @TestLogin);
    RETURN;
END

DECLARE @Existing INT;
SELECT @Existing = COUNT(*) FROM Committee WHERE CommitteeName = 'ZZ F3 test committee' OR CommitteeCode = 'ZF3';
IF (@Existing > 0)
BEGIN
    RAISERROR('%d committee(s) named "ZZ F3 test committee" or with the code ZF3 are already there. Run part 3 first. Nothing was changed.', 16, 1, @Existing);
    RETURN;
END

DECLARE @AlertTypeCode VARCHAR(50) = 'AC';    -- as in the F1 test: 'AC' is shown to every role
DECLARE @DepartmentId INT, @AlertSendOption INT, @CopiedRows INT;
SELECT TOP 1 @DepartmentId = am.DepartmentId, @AlertSendOption = am.AlertSendOption
FROM Alert_Master am
JOIN Alert_User_Map m ON m.AlertId = am.AlertId
WHERE m.UserId = @UserId AND m.StatusId = 1
ORDER BY am.AlertId DESC;
SET @CopiedRows = @@ROWCOUNT;
IF (@CopiedRows = 0)
BEGIN
    RAISERROR('The user "%s" has no alert to copy from. Choose a test user who sees at least one alert on the Dashboard. Nothing was changed.', 16, 1, @TestLogin);
    RETURN;
END

-- NULL where the column allows it; otherwise the value Committee Master saves for a new committee
DECLARE @NullDate INT = ISNULL(COLUMNPROPERTY(OBJECT_ID('dbo.Committee'), 'IncorporationDate', 'AllowsNull'), 0);
DECLARE @NullBoard INT = ISNULL(COLUMNPROPERTY(OBJECT_ID('dbo.Committee'), 'Board', 'AllowsNull'), 0);
DECLARE @NullStartNo INT = ISNULL(COLUMNPROPERTY(OBJECT_ID('dbo.Committee'), 'MeetingStartNo', 'AllowsNull'), 0);
DECLARE @NullColor INT = ISNULL(COLUMNPROPERTY(OBJECT_ID('dbo.Committee'), 'CommitteeColorCode', 'AllowsNull'), 0);
DECLARE @NullCessation INT = ISNULL(COLUMNPROPERTY(OBJECT_ID('dbo.Committee'), 'CessationDate', 'AllowsNull'), 0);
DECLARE @NullIsDelete INT = ISNULL(COLUMNPROPERTY(OBJECT_ID('dbo.Committee'), 'IsDelete', 'AllowsNull'), 0);

DECLARE @CommitteeId INT, @AlertId INT, @MapId INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Committee (CommitteeCode, CommitteeName, Board, IncorporationDate, MeetingStartNo, CommitteeColorCode,
                           CessationDate, StatusId, IsDelete, CreatedOn, CreatedBy)
    VALUES ('ZF3', 'ZZ F3 test committee',
            CASE WHEN @NullBoard = 1 THEN NULL ELSE 0 END,
            CASE WHEN @NullDate = 1 THEN NULL ELSE CAST('2000-01-01' AS DATETIME) END,
            CASE WHEN @NullStartNo = 1 THEN NULL ELSE 1 END,
            CASE WHEN @NullColor = 1 THEN NULL ELSE '#FFFFFF' END,
            CASE WHEN @NullCessation = 1 THEN NULL ELSE '' END,
            1,
            CASE WHEN @NullIsDelete = 1 THEN NULL ELSE 0 END,
            GETDATE(), @UserId);
    SET @CommitteeId = SCOPE_IDENTITY();

    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Committee', @DepartmentId, @CommitteeId, 'ZZ F3 test - committee with NULL values', @AlertTypeCode, @AlertSendOption, @CommitteeId, GETDATE(), @UserId);
    SET @AlertId = SCOPE_IDENTITY();
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@AlertId, @UserId, 0, 1);
    SET @MapId = SCOPE_IDENTITY();

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    DECLARE @ErrorText NVARCHAR(2048) = ERROR_MESSAGE();
    RAISERROR('Part 1 failed and was rolled back, nothing was changed: %s', 16, 1, @ErrorText);
    RETURN;
END CATCH

DECLARE @Line NVARCHAR(400);
SET @Line = N'Test user ' + @TestLogin + N' (UserId ' + CAST(@UserId AS NVARCHAR(12)) + N')';
PRINT @Line;
SET @Line = N'Test committee ZF3 "ZZ F3 test committee": CommitteeId ' + CAST(@CommitteeId AS NVARCHAR(12)) + N'  (keep this id for part 3)';
PRINT @Line;
SET @Line = N'Committee alert: AlertId ' + CAST(@AlertId AS NVARCHAR(12)) + N', AlertUserId ' + CAST(@MapId AS NVARCHAR(12));
PRINT @Line;
IF (@NullDate = 0) PRINT N'IncorporationDate does not allow NULL: it was set to 01-Jan-2000.';
IF (@NullBoard = 0) PRINT N'Board does not allow NULL: it was set to 0.';
IF (@NullStartNo = 0) PRINT N'MeetingStartNo does not allow NULL: it was set to 1.';
IF (@NullColor = 0) PRINT N'CommitteeColorCode does not allow NULL: it was set to #FFFFFF.';
IF (@NullCessation = 0) PRINT N'CessationDate does not allow NULL: it was set to an empty text.';
IF (@NullIsDelete = 0) PRINT N'IsDelete does not allow NULL: it was set to 0.';
PRINT N'Sign in as the test user, open the Dashboard (Show All) and click the "ZZ F3 test -" alert. Then run part 2.';
GO


/* ============================================================================
   PART 2 - read-only: the test committee, its alerts and its members
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CommitteeId INT;
SELECT @CommitteeId = CommitteeId FROM Committee WHERE CommitteeName = 'ZZ F3 test committee' AND CommitteeCode = 'ZF3';

IF (@CommitteeId IS NULL)
    PRINT N'The test committee is not there (not inserted yet, or deleted in the browser or by part 3).';

SELECT CommitteeId, CommitteeCode, CommitteeName, Board, IncorporationDate, MeetingStartNo,
       CommitteeColorCode, CessationDate, StatusId, IsDelete
FROM Committee
WHERE CommitteeId = @CommitteeId;

SELECT am.AlertId, am.SourceType, am.SourceTypeId, am.CommitteeId, am.AlertTypeCode, am.DisplayText,
       m.AlertUserId, u.LoginName, m.ReadStatus
FROM Alert_Master am
JOIN Alert_User_Map m ON m.AlertId = am.AlertId
LEFT JOIN Users u ON u.UserId = m.UserId
WHERE am.CommitteeId = @CommitteeId OR (am.SourceType = 'Committee' AND am.SourceTypeId = @CommitteeId)
ORDER BY am.AlertId, m.AlertUserId;

SELECT CommitteeMemberId, CommitteeId, MemberId, MemberTypeId, AppointmentDate, CessationDate
FROM Committee_Member
WHERE CommitteeId = @CommitteeId;
GO


/* ============================================================================
   PART 3 - cleanup by the committee id
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @TestCommitteeId INT = NULL;    -- leave NULL; set to the id printed by part 1 only if the committee was deleted in the browser

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @Found INT;

IF (@TestCommitteeId IS NULL)
BEGIN
    SELECT @Found = COUNT(*) FROM Committee WHERE CommitteeName = 'ZZ F3 test committee' AND CommitteeCode = 'ZF3';
    IF (@Found <> 1)
    BEGIN
        RAISERROR('Found %d committee(s) named "ZZ F3 test committee" with the code ZF3 (expected 1). If it was deleted in the browser, set @TestCommitteeId to the id printed by part 1. Nothing was changed.', 16, 1, @Found);
        RETURN;
    END
    SELECT @TestCommitteeId = CommitteeId FROM Committee WHERE CommitteeName = 'ZZ F3 test committee' AND CommitteeCode = 'ZF3';
END
ELSE
BEGIN
    -- The id was typed in: it must be the test committee, or a committee that no longer exists
    SELECT @Found = COUNT(*) FROM Committee
    WHERE CommitteeId = @TestCommitteeId AND NOT (CommitteeName = 'ZZ F3 test committee' AND CommitteeCode = 'ZF3');
    IF (@Found > 0)
    BEGIN
        RAISERROR('CommitteeId %d is not the test committee "ZZ F3 test committee" (ZF3). Check @TestCommitteeId. Nothing was changed.', 16, 1, @TestCommitteeId);
        RETURN;
    END

    -- A committee that no longer exists: its id must still carry the alert written by part 1
    SELECT @Found = COUNT(*) FROM Committee WHERE CommitteeId = @TestCommitteeId;
    IF (@Found = 0)
    BEGIN
        SELECT @Found = COUNT(*) FROM Alert_Master
        WHERE SourceType = 'Committee' AND SourceTypeId = @TestCommitteeId AND DisplayText = 'ZZ F3 test - committee with NULL values';
        IF (@Found = 0)
        BEGIN
            RAISERROR('CommitteeId %d has no committee and no "ZZ F3 test -" alert, so it is not the id printed by part 1. Check @TestCommitteeId. Nothing was changed.', 16, 1, @TestCommitteeId);
            RETURN;
        END
    END
END

DECLARE @Used INT, @UsedMeeting INT, @UsedAgenda INT, @UsedAttendance INT;
SELECT @UsedMeeting = COUNT(*) FROM Meeting WHERE CommitteeId = @TestCommitteeId;
SELECT @UsedAgenda = COUNT(*) FROM Agenda WHERE CommitteeId = @TestCommitteeId;
SELECT @UsedAttendance = COUNT(*) FROM Attendance WHERE CommitteeId = @TestCommitteeId;
SET @Used = @UsedMeeting + @UsedAgenda + @UsedAttendance;
IF (@Used > 0)
BEGIN
    RAISERROR('The test committee (id %d) is used by %d meeting, %d agenda and %d attendance row(s), which this cleanup does not delete. Remove them first. Nothing was changed.', 16, 1,
              @TestCommitteeId, @UsedMeeting, @UsedAgenda, @UsedAttendance);
    RETURN;
END

DECLARE @MapRows INT, @AlertRows INT, @MemberRows INT, @CommitteeRows INT;

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE m
    FROM Alert_User_Map m
    JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.CommitteeId = @TestCommitteeId OR (am.SourceType = 'Committee' AND am.SourceTypeId = @TestCommitteeId);
    SET @MapRows = @@ROWCOUNT;

    DELETE FROM Alert_Master
    WHERE CommitteeId = @TestCommitteeId OR (SourceType = 'Committee' AND SourceTypeId = @TestCommitteeId);
    SET @AlertRows = @@ROWCOUNT;

    DELETE FROM Committee_Member WHERE CommitteeId = @TestCommitteeId;
    SET @MemberRows = @@ROWCOUNT;

    DELETE FROM Committee WHERE CommitteeId = @TestCommitteeId;
    SET @CommitteeRows = @@ROWCOUNT;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    DECLARE @ErrorText NVARCHAR(2048) = ERROR_MESSAGE();
    RAISERROR('Part 3 failed and was rolled back, nothing was deleted: %s', 16, 1, @ErrorText);
    RETURN;
END CATCH

DECLARE @Line NVARCHAR(400);
SET @Line = N'CommitteeId ' + CAST(@TestCommitteeId AS NVARCHAR(12)) + N': deleted ' + CAST(@MapRows AS NVARCHAR(12)) + N' Alert_User_Map row(s), '
          + CAST(@AlertRows AS NVARCHAR(12)) + N' Alert_Master row(s), ' + CAST(@MemberRows AS NVARCHAR(12)) + N' Committee_Member row(s) and '
          + CAST(@CommitteeRows AS NVARCHAR(12)) + N' Committee row(s).';
PRINT @Line;
PRINT N'Expected: at least 1 alert (the test alert, plus one per Update in Committee Master), the members added in browser test 8, and 1 committee (0 when deleted in the browser).';
GO
