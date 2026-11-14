/* ============================================================================
   BMMS - Browser test rows for step M4 (Agenda Entry: no new item after the
   meeting date; notice after the Agenda Submission Date)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY on the database BMMS_Test: every part stops with a message on any
   other database. It has no USE line: select BMMS_Test in SSMS first.

   The file has four parts. Select the lines of ONE part and press F5.
   Rows are written with plain INSERTs and UPDATEs, as in the A1b test script;
   no procedure is created, altered or run. The file is plain ASCII.

   Step 24 refuses a meeting dated before today on Meeting Master, so the
   meetings of these tests are written here. Dates are the database server
   date; the page compares with the web server date (the same machine on
   BMMS_Test).

   Test committee: code A93, name "ZZ M4 agenda dates". One letter and digits,
   as in A1b (spr_GetNextCommitteeCode reads the characters after the first
   one as a number; A sorts below the C codes it generates). Parts 2, 3 and 4
   take the committee only when the name also starts with "ZZ M4".
   Three characters (step C1; it was A903): with a 4-character code every
   agenda item gets an Agenda No ending in -001 (step N3, parked). Remove the
   rows of an earlier run (part 4) before this version of the file is used:
   part 4 now looks for A93 only.

   PART 1  Inserts the committee and seven meetings (Agenda and Minutes
           status Open), numbered as Meeting Master numbers them:
             00901  meeting today,          submission today
             00902  meeting yesterday,      submission two days ago
             00903  no meeting date,        no submission date
             00904  meeting in 3 days,      submission yesterday
             00905  meeting in 5 days,      submission in 2 days
             00906  meeting in 3 days,      no submission date
             00907  meeting today,          submission today (part 2 moves it)
           A column that does not allow NULL: 00903 is not written when
           MeetingDate is NOT NULL; its submission date is today, and 00906
           is not written, when AgendaSubmissionDate is NOT NULL. Both are
           reported. Refuses when rows of an earlier run are still there, or
           when a committee A93 exists that is not a test row.
   PART 2  Moves meeting 00907 to yesterday (submission two days ago): the
           "page left open past the meeting date" check.
   PART 3  Read-only: the test meetings and the agenda items added to them.
   PART 4  Cleanup: the agenda items of the test meetings with their alerts,
           audit rows and Minutes rows, the meetings and the committee. Stops,
           changing nothing, when another meeting of the committee, a meeting
           member, attendance or an action item uses the test rows.
   ============================================================================ */


/* ============================================================================
   PART 1 - insert the test committee and meetings
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CodeTaken INT = (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'A93' AND CommitteeName NOT LIKE 'ZZ M4%');
IF (@CodeTaken > 0)
BEGIN
    RAISERROR('A committee with code A93 already exists and is not a test row. Change the test code in this file. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @Existing INT = (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'A93' OR CommitteeName LIKE 'ZZ M4%');
IF (@Existing > 0)
BEGIN
    RAISERROR('%d test committee(s) from an earlier run are still there. Run part 4 first. Nothing was changed.', 16, 1, @Existing);
    RETURN;
END

DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @ColorCode VARCHAR(50) = (SELECT TOP 1 CommitteeColorCode FROM Committee WHERE ISNULL(CommitteeColorCode, '') <> '' ORDER BY CommitteeId);
IF (@Sys IS NULL)
BEGIN
    RAISERROR('The system account was not found. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @MeetingDateNullable INT =
    (SELECT CASE WHEN IS_NULLABLE = 'YES' THEN 1 ELSE 0 END FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Meeting' AND COLUMN_NAME = 'MeetingDate');
DECLARE @SubmissionNullable INT =
    (SELECT CASE WHEN IS_NULLABLE = 'YES' THEN 1 ELSE 0 END FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Meeting' AND COLUMN_NAME = 'AgendaSubmissionDate');
IF (@MeetingDateNullable IS NULL OR @SubmissionNullable IS NULL)
BEGIN
    RAISERROR('Meeting.MeetingDate or Meeting.AgendaSubmissionDate was not found. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @Now DATETIME = GETDATE();
DECLARE @Today DATETIME = CAST(CAST(GETDATE() AS date) AS DATETIME);
DECLARE @Yesterday DATETIME = DATEADD(DAY, -1, @Today);
DECLARE @TwoDaysAgo DATETIME = DATEADD(DAY, -2, @Today);
DECLARE @InTwoDays DATETIME = DATEADD(DAY, 2, @Today);
DECLARE @InThreeDays DATETIME = DATEADD(DAY, 3, @Today);
DECLARE @InFiveDays DATETIME = DATEADD(DAY, 5, @Today);
DECLARE @NoSubmission DATETIME = CASE WHEN @SubmissionNullable = 1 THEN NULL ELSE @Today END;

DECLARE @CommitteeId INT, @MeetingRows INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Committee (CommitteeCode, CommitteeName, Board, IncorporationDate, MeetingStartNo, CommitteeColorCode, StatusId, IsDelete, CreatedOn, CreatedBy)
    VALUES ('A93', 'ZZ M4 agenda dates', 0, '2000-01-01', 901, @ColorCode, 1, 0, @Now, @Sys);
    SET @CommitteeId = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('00901', @CommitteeId, 'ZZ M4', 'ZZ M4 today', @Today, '10:00', @Today, 'Open', 'Open'),
           ('00902', @CommitteeId, 'ZZ M4', 'ZZ M4 yesterday', @Yesterday, '10:00', @TwoDaysAgo, 'Open', 'Open'),
           ('00904', @CommitteeId, 'ZZ M4', 'ZZ M4 after submission', @InThreeDays, '10:00', @Yesterday, 'Open', 'Open'),
           ('00905', @CommitteeId, 'ZZ M4', 'ZZ M4 before submission', @InFiveDays, '10:00', @InTwoDays, 'Open', 'Open'),
           ('00907', @CommitteeId, 'ZZ M4', 'ZZ M4 left open', @Today, '10:00', @Today, 'Open', 'Open');
    SET @MeetingRows = @@ROWCOUNT;

    IF (@MeetingDateNullable = 1)
    BEGIN
        INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
        VALUES ('00903', @CommitteeId, 'ZZ M4', 'ZZ M4 no date', NULL, '10:00', @NoSubmission, 'Open', 'Open');
        SET @MeetingRows = @MeetingRows + @@ROWCOUNT;
    END

    IF (@SubmissionNullable = 1)
    BEGIN
        INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
        VALUES ('00906', @CommitteeId, 'ZZ M4', 'ZZ M4 no submission date', @InThreeDays, '10:00', NULL, 'Open', 'Open');
        SET @MeetingRows = @MeetingRows + @@ROWCOUNT;
    END

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
SET @Line = N'CommitteeId ' + CAST(@CommitteeId AS NVARCHAR(12)) + N' (A93, ZZ M4 agenda dates), ' + CAST(@MeetingRows AS NVARCHAR(12)) + N' meeting(s).';
PRINT @Line;
IF (@MeetingDateNullable = 0)
    PRINT N'Meeting.MeetingDate does not allow NULL: meeting 00903 (no meeting date) was not written; skip that check.';
IF (@SubmissionNullable = 0)
    PRINT N'Meeting.AgendaSubmissionDate does not allow NULL: meeting 00906 was not written and 00903 has the submission date today; skip the no-submission-date check.';
PRINT N'Run the browser tests; part 2 during the page-left-open check; part 4 at the end.';
GO


/* ============================================================================
   PART 2 - move meeting 00907 to yesterday (page left open)
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CommitteeId INT = (SELECT TOP 1 CommitteeId FROM Committee WHERE CommitteeCode = 'A93' AND CommitteeName LIKE 'ZZ M4%' ORDER BY CommitteeId);
IF (@CommitteeId IS NULL)
BEGIN
    RAISERROR('The test committee A93 was not found. Run part 1 first. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @Today DATETIME = CAST(CAST(GETDATE() AS date) AS DATETIME);

UPDATE Meeting
SET MeetingDate = DATEADD(DAY, -1, @Today), AgendaSubmissionDate = DATEADD(DAY, -2, @Today)
WHERE CommitteeId = @CommitteeId AND MeetingNo = '00907';

DECLARE @Moved INT = @@ROWCOUNT;
DECLARE @Line NVARCHAR(400) = N'Meeting 00907 moved to yesterday: ' + CAST(@Moved AS NVARCHAR(12)) + N' row(s) (expected 1). Now press Save on the open form.';
PRINT @Line;
GO


/* ============================================================================
   PART 3 - read-only: the test meetings and their agenda items
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CommitteeId INT = (SELECT TOP 1 CommitteeId FROM Committee WHERE CommitteeCode = 'A93' AND CommitteeName LIKE 'ZZ M4%' ORDER BY CommitteeId);

SELECT mt.MeetingId, mt.MeetingNo, mt.Venue, mt.MeetingDate, mt.AgendaSubmissionDate, mt.AgendaStatus, mt.MinutesStatus,
       (SELECT COUNT(*) FROM Agenda a WHERE a.MeetingId = mt.MeetingId) AS AgendaItems
FROM Meeting mt
WHERE mt.CommitteeId = @CommitteeId
ORDER BY mt.MeetingNo;

SELECT a.AgendaId, a.AgendaNo, mt.MeetingNo, a.ShortText, a.CreatedOn, u.LoginName AS CreatedBy, r.RoleCode,
       a.MgrApprovedStatus, a.ControllerApprovedStatus
FROM Agenda a
JOIN Meeting mt ON mt.MeetingId = a.MeetingId
LEFT JOIN Users u ON u.UserId = a.CreatedBy
LEFT JOIN Roles r ON r.RoleId = u.RoleId
WHERE mt.CommitteeId = @CommitteeId
ORDER BY mt.MeetingNo, a.AgendaId;
GO


/* ============================================================================
   PART 4 - cleanup by the test code and name
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CommitteeId INT = (SELECT TOP 1 CommitteeId FROM Committee WHERE CommitteeCode = 'A93' AND CommitteeName LIKE 'ZZ M4%' ORDER BY CommitteeId);
IF (@CommitteeId IS NULL)
BEGIN
    PRINT N'The test committee A93 was not found: nothing to delete.';
    RETURN;
END

DECLARE @Meetings TABLE (MeetingId INT PRIMARY KEY);
INSERT INTO @Meetings (MeetingId)
SELECT MeetingId FROM Meeting
WHERE CommitteeId = @CommitteeId AND MeetingNo IN ('00901', '00902', '00903', '00904', '00905', '00906', '00907');

DECLARE @Agendas TABLE (AgendaId INT PRIMARY KEY, AgendaNo VARCHAR(50) NULL);
INSERT INTO @Agendas (AgendaId, AgendaNo)
SELECT AgendaId, AgendaNo FROM Agenda WHERE MeetingId IN (SELECT MeetingId FROM @Meetings) OR CommitteeId = @CommitteeId;

-- Anything else that uses the test rows stops the cleanup
DECLARE @OtherMeetings INT, @OtherAgendas INT, @MeetingMembers INT, @AttendanceRows INT, @ActionItems INT;
SELECT @OtherMeetings = COUNT(*) FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings);
SELECT @OtherAgendas = COUNT(*) FROM Agenda WHERE AgendaId IN (SELECT AgendaId FROM @Agendas)
                                              AND (CommitteeId <> @CommitteeId OR MeetingId NOT IN (SELECT MeetingId FROM @Meetings));
SELECT @MeetingMembers = COUNT(*) FROM Meeting_Member WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
SELECT @AttendanceRows = COUNT(*) FROM Attendance WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
SELECT @ActionItems = COUNT(*) FROM Action_Item ai JOIN Minutes mi ON mi.MinutesId = ai.MinutesId
                      WHERE mi.AgendaId IN (SELECT AgendaId FROM @Agendas);

IF (@OtherMeetings + @OtherAgendas + @MeetingMembers + @AttendanceRows + @ActionItems > 0)
BEGIN
    RAISERROR('Other rows use the test rows; this cleanup does not delete them. Other meetings of the committee %d, agenda items of another meeting %d, meeting members %d, attendance %d, action items %d. Remove them on screen first. Nothing was changed.', 16, 1,
              @OtherMeetings, @OtherAgendas, @MeetingMembers, @AttendanceRows, @ActionItems);
    RETURN;
END

DECLARE @MapRows INT, @AlertRows INT, @AuditRows INT, @MinutesRows INT, @AgendaRows INT, @MeetingRows INT, @CommitteeRows INT;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Alerts written by browser saves: the agenda items, the meetings and the committee
    DELETE m
    FROM Alert_User_Map m
    JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.CommitteeId = @CommitteeId
       OR (am.SourceType = 'Agenda' AND am.SourceTypeId IN (SELECT AgendaId FROM @Agendas))
       OR (am.SourceType = 'Meeting' AND am.SourceTypeId IN (SELECT MeetingId FROM @Meetings))
       OR (am.SourceType = 'Committee' AND am.SourceTypeId = @CommitteeId);
    SET @MapRows = @@ROWCOUNT;

    DELETE FROM Alert_Master
    WHERE CommitteeId = @CommitteeId
       OR (SourceType = 'Agenda' AND SourceTypeId IN (SELECT AgendaId FROM @Agendas))
       OR (SourceType = 'Meeting' AND SourceTypeId IN (SELECT MeetingId FROM @Meetings))
       OR (SourceType = 'Committee' AND SourceTypeId = @CommitteeId);
    SET @AlertRows = @@ROWCOUNT;

    -- Audit rows of the test agenda items (their numbers start with the test committee code)
    DELETE FROM Audit_Trail_Master
    WHERE Audit_Table = 'Agenda' AND Key_Field = 'AgendaNo' AND Key_Value LIKE 'A93-%'
      AND Key_Value IN (SELECT AgendaNo FROM @Agendas);
    SET @AuditRows = @@ROWCOUNT;

    DELETE FROM Minutes WHERE AgendaId IN (SELECT AgendaId FROM @Agendas);
    SET @MinutesRows = @@ROWCOUNT;

    DELETE FROM Agenda WHERE AgendaId IN (SELECT AgendaId FROM @Agendas);
    SET @AgendaRows = @@ROWCOUNT;

    DELETE FROM Meeting WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @MeetingRows = @@ROWCOUNT;

    DELETE FROM Committee WHERE CommitteeId = @CommitteeId;
    SET @CommitteeRows = @@ROWCOUNT;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    DECLARE @ErrorText NVARCHAR(2048) = ERROR_MESSAGE();
    RAISERROR('Part 4 failed and was rolled back, nothing was deleted: %s', 16, 1, @ErrorText);
    RETURN;
END CATCH

DECLARE @Line NVARCHAR(400);
SET @Line = N'Deleted ' + CAST(@MapRows AS NVARCHAR(12)) + N' Alert_User_Map, ' + CAST(@AlertRows AS NVARCHAR(12)) + N' Alert_Master, '
          + CAST(@AuditRows AS NVARCHAR(12)) + N' Audit_Trail_Master, ' + CAST(@MinutesRows AS NVARCHAR(12)) + N' Minutes, '
          + CAST(@AgendaRows AS NVARCHAR(12)) + N' Agenda, ' + CAST(@MeetingRows AS NVARCHAR(12)) + N' Meeting and '
          + CAST(@CommitteeRows AS NVARCHAR(12)) + N' Committee row(s).';
PRINT @Line;
PRINT N'Expected: the alerts and audit rows of the items saved in the tests, 0 Minutes, 7 Meeting (fewer when part 1 reported a skipped meeting), 1 Committee.';
GO
