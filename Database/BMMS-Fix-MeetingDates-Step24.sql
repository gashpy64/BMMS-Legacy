/* ============================================================================
   BMMS - Meeting dates: agenda submission date and meeting date (step 24)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   The Meeting page accepted an Agenda Submission Date in the past (a meeting
   created today with the submission date yesterday: Users can never submit
   agenda items to it, spr_GetMeetingForUsers offers a meeting only while its
   submission date is today or later) and refused a submission date equal to
   the meeting date. Nothing in the database checked the dates.

   Rules (spr_AddEditMeeting), today = the database server date, dates
   compared as dates (the time of day is ignored):
     Create   Meeting Date and Agenda Submission Date both required;
              Meeting Date not before today;
              Agenda Submission Date not before today;
              Agenda Submission Date on or before the Meeting Date (equal is
              allowed). A meeting today with the submission date today is
              allowed.
     Edit     both required; the Agenda Submission Date on or before the
              Meeting Date, always; "not before today" only for a date that is
              being changed, so the venue or time of a meeting whose
              submission date has passed can still be changed. Checked after
              the existing refusals: unknown meeting (Reason 4), date or
              committee locked by attendance (6), committee locked by agenda
              items (10).
   Refused with Reason 16, ReasonDetail:
     Missing                 a date is missing
     MeetingBeforeToday      the meeting date is before today
     SubmissionBeforeToday   the agenda submission date is before today
     SubmissionAfterMeeting  the agenda submission date is after the meeting date
   A refused save changes nothing and creates no alert.

   Objects
     spr_AddEditMeeting  REPLACED. Generated from the installed text of step 18,
                         which keeps the texts of steps 16, 17 and 18
                         (MeetingLocks-Step16, UserStatus2b-Step17,
                         SystemAccount3-Step18); adds MeetingDates-Step24.

   Changes no data: meetings already saved keep their dates. Safe to re-run.
   Needs steps 16, 17 and 18 and stops otherwise. Steps 16, 17 and 18 each
   contain an older spr_AddEditMeeting: if one of them is re-run, run this
   script again afterwards. Run it BEFORE deploying the build that shows the
   Reason 16 messages; the older build shows "Record Not Saved" for a refusal.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".

   If you install from the command line, use sqlcmd -I (quoted identifiers ON);
   installing from SSMS already does this.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetAppSetting')), '') NOT LIKE '%MeetingLocks-Step16%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') NOT LIKE '%MeetingLocks-Step16%')
BEGIN
    RAISERROR('Step 16 (BMMS-Fix-MeetingLocks-Step16.sql) is not installed in "%s". Run it first (then steps 17 and 18), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') NOT LIKE '%UserStatus2b-Step17%')
BEGIN
    RAISERROR('Step 17 (BMMS-Fix-UserStatus-Stage2b.sql) is not installed in "%s". Run it first (then step 18), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%SystemAccount3-Step18%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') NOT LIKE '%SystemAccount3-Step18%')
BEGIN
    RAISERROR('Step 18 (BMMS-Fix-SystemAccount-Stage3.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Meeting - add / edit; date and committee locked by attendance, committee by agenda items (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- Dates (MeetingDates-Step24): both required; on create the meeting date and the agenda submission date not
-- before today; on edit a changed date not before today; the submission date always on or before the meeting
-- date. Today is the database server date; dates are compared as dates. Refused with Reason 16, ReasonDetail
-- Missing, MeetingBeforeToday, SubmissionBeforeToday or SubmissionAfterMeeting.
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditMeeting]
(@Code VARCHAR(50),
@MeetingId INT,
@MeetingNo VARCHAR(10),
@CommitteeId INT,
@Place VARCHAR(50),
@Venue VARCHAR(250),
@MeetingDate DATETIME,
@MeetingTime VARCHAR(10),
@AgendaSubmissionDate DATETIME,
@MeetingColorCode VARCHAR(10),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT)
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @meeting_id INT
	DECLARE @DepartmentId INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @Found INT;
	DECLARE @OldMeetingDate DATETIME;
	DECLARE @OldCommitteeId INT;
	DECLARE @DateChanged INT;
	DECLARE @CommitteeChanged INT;
	DECLARE @Today DATE;
	DECLARE @OldSubmissionDate DATETIME;
	DECLARE @SubmissionChanged INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';
	SET @Today = CAST(GETDATE() AS date);

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION MeetingSave;

		SET @DepartmentId = (SELECT DepartmentId FROM Users WHERE UserId = @CreatedBy);

		IF (@Code = 'Save')
		BEGIN
			-- MeetingDates-Step24
			IF (@MeetingDate IS NULL OR @AgendaSubmissionDate IS NULL)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'Missing';
			END
			ELSE IF (CAST(@MeetingDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'MeetingBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) > CAST(@MeetingDate AS date))
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionAfterMeeting';
			END
			ELSE
			BEGIN
				INSERT INTO Meeting
				(MeetingNo, CommitteeId, Place, Venue, MeetingDate,
				MeetingTime, AgendaSubmissionDate, MeetingColorCode, CreatedOn, CreatedBy)
				VALUES
				(@MeetingNo, @CommitteeId, @Place, @Venue,@MeetingDate,
				@MeetingTime, @AgendaSubmissionDate, @MeetingColorCode, @CreatedOn, @CreatedBy);

				SET @meeting_id = @@identity;

				SET @SourceType = 'Meeting'
				SET @DisplayText = 'Meeting (' + (SELECT CommitteeCode FROM Committee WHERE
					 CommitteeId = @CommitteeId) + '-' + @MeetingNo + ')';

				INSERT INTO Alert_Master
				(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
				VALUES
				(@SourceType, 0, @meeting_id, @DisplayText, 'MC', 3, @CommitteeId, @CreatedOn, @CreatedBy);

				SET @alert_id = @@identity;

				INSERT INTO Alert_User_Map
				(AlertId, [UserId], ReadStatus, StatusId)
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0);

				SET @Result = 1;
			END
		END

		IF (@Code = 'Update')
		BEGIN
			SELECT @Found = 1, @OldMeetingDate = MeetingDate, @OldCommitteeId = CommitteeId, @OldSubmissionDate = AgendaSubmissionDate
			FROM Meeting WITH (UPDLOCK, HOLDLOCK)
			WHERE MeetingId = @MeetingId;

			-- Dates compared as dates: the page sends the date only
			SET @DateChanged = CASE WHEN @OldMeetingDate IS NULL AND @MeetingDate IS NULL THEN 0
			                        WHEN @OldMeetingDate IS NULL OR @MeetingDate IS NULL THEN 1
			                        WHEN CAST(@OldMeetingDate AS date) <> CAST(@MeetingDate AS date) THEN 1
			                        ELSE 0 END;
			SET @SubmissionChanged = CASE WHEN @OldSubmissionDate IS NULL AND @AgendaSubmissionDate IS NULL THEN 0
			                             WHEN @OldSubmissionDate IS NULL OR @AgendaSubmissionDate IS NULL THEN 1
			                             WHEN CAST(@OldSubmissionDate AS date) <> CAST(@AgendaSubmissionDate AS date) THEN 1
			                             ELSE 0 END;
			SET @CommitteeChanged = CASE WHEN ISNULL(@OldCommitteeId, -1) <> ISNULL(@CommitteeId, -1) THEN 1 ELSE 0 END;

			IF (@Found IS NULL)
				SET @Reason = 4;
			ELSE IF ((@DateChanged = 1 OR @CommitteeChanged = 1)
			         AND EXISTS (SELECT 1 FROM Attendance WHERE MeetingId = @MeetingId))
			BEGIN
				SET @Reason = 6;
				SET @Detail = CASE WHEN @DateChanged = 1 AND @CommitteeChanged = 1 THEN 'MeetingDate,CommitteeId'
				                   WHEN @DateChanged = 1 THEN 'MeetingDate'
				                   ELSE 'CommitteeId' END;
			END
			ELSE IF (@CommitteeChanged = 1 AND EXISTS (SELECT 1 FROM Agenda WHERE MeetingId = @MeetingId))
			BEGIN
				SET @Reason = 10;
				SET @Detail = 'CommitteeId';
			END
			-- MeetingDates-Step24: after the locks; "not before today" only for a date that changes
			ELSE IF (@MeetingDate IS NULL OR @AgendaSubmissionDate IS NULL)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'Missing';
			END
			ELSE IF (@DateChanged = 1 AND CAST(@MeetingDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'MeetingBeforeToday';
			END
			ELSE IF (@SubmissionChanged = 1 AND CAST(@AgendaSubmissionDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) > CAST(@MeetingDate AS date))
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionAfterMeeting';
			END
			ELSE
			BEGIN
				UPDATE Meeting SET
				CommitteeId = @CommitteeId,
				Place = @Place,
				Venue = @Venue,
				MeetingDate = @MeetingDate,
				MeetingTime = @MeetingTime,
				AgendaSubmissionDate = @AgendaSubmissionDate,
				MeetingColorCode = @MeetingColorCode,
				UpdatedOn = @UpdatedOn,
				UpdatedBy = @UpdatedBy
				WHERE
				MeetingId = @MeetingId;

				SET @SourceType = 'Meeting'
				SET @DisplayText = 'Meeting (' + (SELECT CommitteeCode FROM Committee WHERE
					 CommitteeId = @CommitteeId) + '-' + @MeetingNo + ')';

				INSERT INTO Alert_Master
				(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
				VALUES
				(@SourceType, 0, @MeetingId, @DisplayText, 'MU', 3, @CommitteeId, @CreatedOn, @CreatedBy);

				SET @alert_id = @@identity;

				INSERT INTO Alert_User_Map
				(AlertId, [UserId], ReadStatus, StatusId)
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0);

				SET @Result = 1;
			END
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION MeetingSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END

GO

PRINT 'Step 24 installed: spr_AddEditMeeting checks the meeting and agenda submission dates (MeetingDates-Step24).';
GO

SET NOEXEC OFF;
GO
