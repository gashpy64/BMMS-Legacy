/* ============================================================================
   BMMS - Business rule: attendance only for a meeting that has taken place
   ----------------------------------------------------------------------------
   Replaces spr_UpdateAttendance and adds spr_CheckMeetingHeldByMeetingId.

   Before this change the Attendance page could save (and edit) attendance for
   a meeting dated in the future.

   Rule: attendance can be saved only when the meeting date is today or
   earlier, judged by the DATABASE SERVER date:
       CAST(Meeting.MeetingDate AS date) <= CAST(GETDATE() AS date)
   A meeting dated today is allowed at any time of day (MeetingTime is not
   looked at). A meeting with no date (NULL) is refused.

   spr_UpdateAttendance
     * returns Result = 0 and writes nothing when the meeting has not yet
       taken place (new attendance and edits of existing attendance alike);
     * otherwise inserts or updates exactly as before and returns Result = 1.
     Existing attendance rows are not changed or removed by this script.

   spr_CheckMeetingHeldByMeetingId
     * returns Result = 1 when the meeting has taken place, 0 otherwise.
       The Attendance page calls it before saving anything (chairman included).

   Deploy order: run this script BEFORE deploying the build that reads Result
   from spr_UpdateAttendance. The new build stops with an error if this script
   has not been run.

   This script only replaces / adds procedures. It changes no data and adds no
   constraint. Safe to re-run.

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

PRINT 'Database: ' + DB_NAME();
GO

-- Meeting - has the meeting taken place? (server date, date part only)
CREATE OR ALTER PROCEDURE [dbo].[spr_CheckMeetingHeldByMeetingId]
@MeetingId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CASE WHEN EXISTS (SELECT 1 FROM Meeting
                             WHERE MeetingId = @MeetingId
                             AND MeetingDate IS NOT NULL
                             AND CAST(MeetingDate AS date) <= CAST(GETDATE() AS date))
                THEN 1 ELSE 0 END AS Result;
END
GO

-- Attendance - refused for a meeting that has not yet taken place
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateAttendance]
@CommitteeId INT,
@MeetingId INT,
@MemberOf varchar(50),
@MemberId INT,
@Attendance varchar(50),
@UpdatedBy INT
AS
DECLARE @Cnt INT
DECLARE @SittingFees DECIMAL(18,2)
BEGIN
SET NOCOUNT ON;

-- Attendance-FutureMeeting
IF NOT EXISTS (SELECT 1 FROM Meeting
               WHERE MeetingId = @MeetingId
               AND MeetingDate IS NOT NULL
               AND CAST(MeetingDate AS date) <= CAST(GETDATE() AS date))
BEGIN
	SELECT 0 AS Result;
	RETURN;
END

SET @Cnt = (SELECT COUNT(*) FROM Attendance WHERE
	CommitteeId = @CommitteeId AND
	MeetingId = @MeetingId AND
	MemberId = @MemberId);

SET @SittingFees = 0;

IF (@Attendance = 'P')
BEGIN
	SET @SittingFees = (SELECT ApplicableFee FROM Committee_Member WHERE
		CommitteeId = @CommitteeId AND
		MemberId = @MemberId);
END

SET @Cnt = ISNULL(@Cnt,0);

	IF (@Cnt <= 0)
	BEGIN
		INSERT INTO Attendance
		(CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
		VALUES
		(@CommitteeId, @MeetingId, @MemberOf, @MemberId, @Attendance, @SittingFees, GETDATE(), @UpdatedBy);
	END

	IF (@Cnt > 0)
	BEGIN
		UPDATE Attendance SET
		Attendance = @Attendance,
		SittingFees = @SittingFees
		WHERE
		CommitteeId = @CommitteeId AND
		MeetingId = @MeetingId AND
		MemberId = @MemberId;
	END

	SELECT 1 AS Result;
END
GO

PRINT 'spr_CheckMeetingHeldByMeetingId and spr_UpdateAttendance installed.';
GO

SET NOEXEC OFF;
GO
