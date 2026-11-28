/* ============================================================================
   BMMS - Browser test rows for step F1 (Dashboard alert whose item is gone)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY on the database BMMS_Test: every part stops with a message on any
   other database. It has no USE line: select BMMS_Test in SSMS first.

   The file has three parts. Select the lines of ONE part and press F5.

   PART 1  Inserts three unread alerts for one test user, each with the
           display text starting "ZZ F1 test -":
             (a) an Agenda alert with SourceTypeId NULL
             (b) a Meeting alert with a meeting id that does not exist
             (c) a Committee alert with a committee id that does not exist
           The rows use alert type 'AC' so every role sees them (a
           copied 'ACA' or 'ACR' would hide them from the Controller
           role). Department, committee and send option are copied
           from the newest alert the test user already has. Prints
           the new ids.
           Set @TestLogin (the only value to fill in) before running.
   PART 2  Shows ReadStatus of the test rows (0 = unread, 1 = read).
   PART 3  Cleanup: deletes the test rows (Alert_User_Map, then
           Alert_Master) and prints the counts.

   Nothing else is changed. No procedure is created or altered.
   ============================================================================ */


/* ============================================================================
   PART 1 - insert the test alerts
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
SELECT @Existing = COUNT(*) FROM Alert_Master WHERE DisplayText LIKE 'ZZ F1 test -%';
IF (@Existing > 0)
BEGIN
    RAISERROR('%d test alert(s) from an earlier run are still there. Run part 3 first. Nothing was changed.', 16, 1, @Existing);
    RETURN;
END

DECLARE @AlertTypeCode VARCHAR(50) = 'AC';    -- not copied: 'ACA' and 'ACR' are hidden from the Controller role
DECLARE @DepartmentId INT, @CommitteeId INT, @AlertSendOption INT, @CopiedRows INT;
SELECT TOP 1 @DepartmentId = am.DepartmentId, @CommitteeId = am.CommitteeId,
       @AlertSendOption = am.AlertSendOption
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

DECLARE @MissingMeetingId INT, @MissingCommitteeId INT;
SELECT @MissingMeetingId = ISNULL(MAX(MeetingId), 0) + 100000 FROM Meeting;
SELECT @MissingCommitteeId = ISNULL(MAX(CommitteeId), 0) + 100000 FROM Committee;

DECLARE @AlertA INT, @AlertB INT, @AlertC INT;
DECLARE @MapA INT, @MapB INT, @MapC INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Agenda', @DepartmentId, NULL, 'ZZ F1 test - agenda without id', @AlertTypeCode, @AlertSendOption, @CommitteeId, GETDATE(), @UserId);
    SET @AlertA = SCOPE_IDENTITY();
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@AlertA, @UserId, 0, 1);
    SET @MapA = SCOPE_IDENTITY();

    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Meeting', @DepartmentId, @MissingMeetingId, 'ZZ F1 test - meeting that does not exist', @AlertTypeCode, @AlertSendOption, @CommitteeId, GETDATE(), @UserId);
    SET @AlertB = SCOPE_IDENTITY();
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@AlertB, @UserId, 0, 1);
    SET @MapB = SCOPE_IDENTITY();

    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Committee', @DepartmentId, @MissingCommitteeId, 'ZZ F1 test - committee that does not exist', @AlertTypeCode, @AlertSendOption, @CommitteeId, GETDATE(), @UserId);
    SET @AlertC = SCOPE_IDENTITY();
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@AlertC, @UserId, 0, 1);
    SET @MapC = SCOPE_IDENTITY();

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
SET @Line = N'(a) Agenda, SourceTypeId NULL:      AlertId ' + CAST(@AlertA AS NVARCHAR(12)) + N', AlertUserId ' + CAST(@MapA AS NVARCHAR(12));
PRINT @Line;
SET @Line = N'(b) Meeting, SourceTypeId ' + CAST(@MissingMeetingId AS NVARCHAR(12)) + N':  AlertId ' + CAST(@AlertB AS NVARCHAR(12)) + N', AlertUserId ' + CAST(@MapB AS NVARCHAR(12));
PRINT @Line;
SET @Line = N'(c) Committee, SourceTypeId ' + CAST(@MissingCommitteeId AS NVARCHAR(12)) + N': AlertId ' + CAST(@AlertC AS NVARCHAR(12)) + N', AlertUserId ' + CAST(@MapC AS NVARCHAR(12));
PRINT @Line;
PRINT N'Sign in as the test user, open the Dashboard (Show All) and click each "ZZ F1 test -" alert. Then run part 2.';
GO


/* ============================================================================
   PART 2 - show ReadStatus of the test alerts (expected 1 after each click)
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

SELECT am.AlertId, am.SourceType, am.SourceTypeId, am.DisplayText,
       m.AlertUserId, u.LoginName, m.ReadStatus
FROM Alert_Master am
JOIN Alert_User_Map m ON m.AlertId = am.AlertId
LEFT JOIN Users u ON u.UserId = m.UserId
WHERE am.DisplayText LIKE 'ZZ F1 test -%'
ORDER BY am.AlertId;
GO


/* ============================================================================
   PART 3 - cleanup: delete the test alerts
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @MapRows INT, @AlertRows INT;

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE m
    FROM Alert_User_Map m
    JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.DisplayText LIKE 'ZZ F1 test -%';
    SET @MapRows = @@ROWCOUNT;

    DELETE FROM Alert_Master WHERE DisplayText LIKE 'ZZ F1 test -%';
    SET @AlertRows = @@ROWCOUNT;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    DECLARE @ErrorText NVARCHAR(2048) = ERROR_MESSAGE();
    RAISERROR('Part 3 failed and was rolled back, nothing was deleted: %s', 16, 1, @ErrorText);
    RETURN;
END CATCH

DECLARE @Line NVARCHAR(200);
SET @Line = N'Deleted ' + CAST(@MapRows AS NVARCHAR(12)) + N' Alert_User_Map row(s) and ' + CAST(@AlertRows AS NVARCHAR(12)) + N' Alert_Master row(s). Expected 3 and 3 (0 and 0 when already clean).';
PRINT @Line;
GO
