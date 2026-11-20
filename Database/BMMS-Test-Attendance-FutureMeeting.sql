/* ============================================================================
   BMMS - Tests for BMMS-Fix-Attendance-FutureMeeting.sql
   ----------------------------------------------------------------------------
   Run AFTER BMMS-Fix-Attendance-FutureMeeting.sql, on the TEST COPY only.

   Creates test meetings dated relative to the database server date
   (yesterday, today at 00:00, today at 23:59, tomorrow, no date) for an
   existing committee member, then calls spr_UpdateAttendance and
   spr_CheckMeetingHeldByMeetingId the way the Attendance page does:
     * future meeting: new attendance refused, nothing written
     * meeting today (any time of day): allowed
     * past meeting: allowed
     * edit of existing attendance on a past meeting: allowed
     * edit of existing attendance on a future meeting: refused, row unchanged
     * meeting with no date: refused

   Everything runs inside one transaction that is ROLLED BACK at the end, so
   no test data is kept. The only lasting effect is that identity values skip
   a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means there is no committee member to test with.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS".
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
DECLARE @R TABLE (Result INT);

DECLARE @Today DATETIME = CAST(CAST(GETDATE() AS date) AS DATETIME);
DECLARE @UserId INT = (SELECT TOP 1 UserId FROM Users ORDER BY UserId);
DECLARE @CommitteeId INT;
DECLARE @MemberId INT;

SELECT TOP 1 @CommitteeId = CommitteeId, @MemberId = MemberId
FROM Committee_Member
WHERE CommitteeId IS NOT NULL AND MemberId IS NOT NULL
ORDER BY CommitteeId, MemberId;

DECLARE @MeetingsBefore INT = (SELECT COUNT(*) FROM Meeting);
DECLARE @AttendanceBefore INT = (SELECT COUNT(*) FROM Attendance);
DECLARE @AttendanceChecksumBefore INT = (SELECT CHECKSUM_AGG(CHECKSUM(*)) FROM Attendance);

DECLARE @Past INT;
DECLARE @TodayMidnight INT;
DECLARE @TodayLate INT;
DECLARE @Future INT;
DECLARE @NoDate INT;

IF (@CommitteeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('No committee member to test with', 'PASS', 'SKIPPED');
END
ELSE
BEGIN
BEGIN TRANSACTION;

BEGIN TRY

    -- Step 16: new attendance only for a member on the committee on the meeting date.
    -- Make the chosen member valid for every test date (rolled back).
    UPDATE Committee_Member SET AppointmentDate = '2000-01-01', CessationDate = ''
    WHERE CommitteeId = @CommitteeId AND MemberId = @MemberId;

    ---------------------------------------------------------------------------
    -- Test meetings, dated relative to the server date
    ---------------------------------------------------------------------------
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime)
    VALUES ('ZZ-PAST', @CommitteeId, 'ZZ test', 'ZZ test', DATEADD(DAY, -1, @Today), '10:00');
    SET @Past = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime)
    VALUES ('ZZ-TODAY0', @CommitteeId, 'ZZ test', 'ZZ test', @Today, '00:00');
    SET @TodayMidnight = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime)
    VALUES ('ZZ-TODAY23', @CommitteeId, 'ZZ test', 'ZZ test', DATEADD(MINUTE, 23 * 60 + 59, @Today), '23:59');
    SET @TodayLate = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime)
    VALUES ('ZZ-FUTURE', @CommitteeId, 'ZZ test', 'ZZ test', DATEADD(DAY, 1, @Today), '10:00');
    SET @Future = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime)
    VALUES ('ZZ-NODATE', @CommitteeId, 'ZZ test', 'ZZ test', NULL, NULL);
    SET @NoDate = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- spr_CheckMeetingHeldByMeetingId (the page's check before saving)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckMeetingHeldByMeetingId @MeetingId = @Past;
    INSERT INTO @T SELECT 'Check: past meeting', '1', CAST(Result AS VARCHAR(12)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckMeetingHeldByMeetingId @MeetingId = @TodayMidnight;
    INSERT INTO @T SELECT 'Check: meeting today 00:00', '1', CAST(Result AS VARCHAR(12)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckMeetingHeldByMeetingId @MeetingId = @TodayLate;
    INSERT INTO @T SELECT 'Check: meeting today 23:59', '1', CAST(Result AS VARCHAR(12)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckMeetingHeldByMeetingId @MeetingId = @Future;
    INSERT INTO @T SELECT 'Check: meeting tomorrow', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckMeetingHeldByMeetingId @MeetingId = @NoDate;
    INSERT INTO @T SELECT 'Check: meeting with no date', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckMeetingHeldByMeetingId @MeetingId = -1;
    INSERT INTO @T SELECT 'Check: meeting that does not exist', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    ---------------------------------------------------------------------------
    -- Future meeting: new attendance refused, nothing written
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Future, @MemberOf = 'C',
         @MemberId = @MemberId, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Future meeting, new attendance: Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    INSERT INTO @T
    SELECT 'Future meeting, new attendance: rows written', '0', CAST(COUNT(*) AS VARCHAR(12))
    FROM Attendance WHERE MeetingId = @Future;

    ---------------------------------------------------------------------------
    -- Meeting today (00:00 and 23:59): allowed
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @TodayMidnight, @MemberOf = 'C',
         @MemberId = @MemberId, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Meeting today 00:00, new attendance: Result', '1', CAST(Result AS VARCHAR(12)) FROM @R;

    INSERT INTO @T
    SELECT 'Meeting today 00:00, new attendance: row saved as P', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Attendance WHERE MeetingId = @TodayMidnight AND MemberId = @MemberId AND Attendance = 'P';

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @TodayLate, @MemberOf = 'C',
         @MemberId = @MemberId, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Meeting today 23:59 (later than now), new attendance: Result', '1', CAST(Result AS VARCHAR(12)) FROM @R;

    INSERT INTO @T
    SELECT 'Meeting today 23:59, new attendance: row saved', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Attendance WHERE MeetingId = @TodayLate AND MemberId = @MemberId;

    ---------------------------------------------------------------------------
    -- Past meeting: new attendance allowed, then an edit allowed
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Past, @MemberOf = 'C',
         @MemberId = @MemberId, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Past meeting, new attendance: Result', '1', CAST(Result AS VARCHAR(12)) FROM @R;

    INSERT INTO @T
    SELECT 'Past meeting, new attendance: row saved as P', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Attendance WHERE MeetingId = @Past AND MemberId = @MemberId AND Attendance = 'P';

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Past, @MemberOf = 'C',
         @MemberId = @MemberId, @Attendance = 'A', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Past meeting, edit P -> A: Result', '1', CAST(Result AS VARCHAR(12)) FROM @R;

    INSERT INTO @T
    SELECT 'Past meeting, edit P -> A: still one row, now A', '1 A', CAST(COUNT(*) AS VARCHAR(12)) + ' ' + ISNULL(MAX(Attendance), 'NULL')
    FROM Attendance WHERE MeetingId = @Past AND MemberId = @MemberId;

    ---------------------------------------------------------------------------
    -- Future meeting with attendance saved before this fix: edit refused
    ---------------------------------------------------------------------------
    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@CommitteeId, @Future, 'C', @MemberId, 'P', 0, GETDATE(), @UserId);

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Future, @MemberOf = 'C',
         @MemberId = @MemberId, @Attendance = 'A', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Future meeting, edit of existing attendance: Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    INSERT INTO @T
    SELECT 'Future meeting, edit of existing attendance: row unchanged (P)', '1 P', CAST(COUNT(*) AS VARCHAR(12)) + ' ' + ISNULL(MAX(Attendance), 'NULL')
    FROM Attendance WHERE MeetingId = @Future AND MemberId = @MemberId;

    ---------------------------------------------------------------------------
    -- Meeting with no date: refused
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @NoDate, @MemberOf = 'C',
         @MemberId = @MemberId, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Meeting with no date, new attendance: Result', '0', CAST(Result AS VARCHAR(12)) FROM @R;

    INSERT INTO @T
    SELECT 'Meeting with no date, new attendance: rows written', '0', CAST(COUNT(*) AS VARCHAR(12))
    FROM Attendance WHERE MeetingId = @NoDate;

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - checks after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 220));
END CATCH

IF (@@TRANCOUNT > 0)
BEGIN
    ROLLBACK TRANSACTION;
END

---------------------------------------------------------------------------
-- After the rollback: data unchanged
---------------------------------------------------------------------------
INSERT INTO @T
SELECT 'After rollback: Meeting row count unchanged', CAST(@MeetingsBefore AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12))
FROM Meeting;

INSERT INTO @T
SELECT 'After rollback: Attendance row count unchanged', CAST(@AttendanceBefore AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12))
FROM Attendance;

INSERT INTO @T
SELECT 'After rollback: Attendance contents unchanged (checksum)', ISNULL(CAST(@AttendanceChecksumBefore AS VARCHAR(12)), 'NULL'),
       ISNULL(CAST(CHECKSUM_AGG(CHECKSUM(*)) AS VARCHAR(12)), 'NULL')
FROM Attendance;
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

-- Confirm nothing was kept: should be 0.
SELECT COUNT(*) AS TestMeetingsLeft FROM Meeting WHERE MeetingNo LIKE 'ZZ-%';
GO

SET NOEXEC OFF;
GO
