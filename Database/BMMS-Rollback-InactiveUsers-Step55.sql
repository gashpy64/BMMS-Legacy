/* ============================================================================
   BMMS - Rollback of step 55 (step IU1, inactive users and the Admin role in
   mails, action items and Reset Password)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Puts back, letter for letter, the texts that BMMS-Fix-InactiveUsers-
   Step55.sql replaced:
     spr_AddEditMeeting               the step 53 text
     spr_AddEditCommittee             the step 53 text
     spr_MinutesFinalizeByMeetingId   the step 23 text
   and drops the three objects step 55 added: fn_FunctionalUsers,
   spr_GetMeetingCommitteeMailId and spr_GetResetPasswordMail. No data
   changes: step 55 changed none (the action item rows written by a
   finalisation while step 55 was installed stay; the step 23 text would also
   have given the Admin role a row). At its end the three texts are compared
   with the texts step 55 was built from (SHA-1 without carriage returns).

   Roll back the build of step IU1 FIRST: the Meeting, Committee and Reset
   Password pages of IU1 call spr_GetMeetingCommitteeMailId and
   spr_GetResetPasswordMail, which this script drops. It refuses when step
   55 is not installed (none of its objects carries InactiveUsers-Step55).

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS". Written for
   compatibility level 100. The file is plain ASCII.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF NOT EXISTS (SELECT 1 FROM (VALUES ('fn_FunctionalUsers'), ('spr_GetMeetingCommitteeMailId'), ('spr_GetResetPasswordMail'),
                                          ('spr_AddEditMeeting'), ('spr_AddEditCommittee'), ('spr_MinutesFinalizeByMeetingId')) o(Name)
                    WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%InactiveUsers-Step55%')
BEGIN
    RAISERROR('Step 55 is not installed in "%s" (none of its objects carries InactiveUsers-Step55): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- spr_AddEditMeeting: the step 53 text
-------------------------------------------------------------------------------
GO

-- Meeting - add / edit; date and committee locked by attendance, committee by agenda items (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- Dates (MeetingDates-Step24): both required; on create the meeting date and the agenda submission date not
-- before today; on edit a changed date not before today; the submission date always on or before the meeting
-- date. Today is the database server date; dates are compared as dates. Refused with Reason 16, ReasonDetail
-- Missing, MeetingBeforeToday, SubmissionBeforeToday or SubmissionAfterMeeting.
-- DepartmentApprovers-Step53 (step UD1b): the MC and MU alerts no longer go to the Admin role.
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
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0
				 AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = Users.RoleId AND ar.RoleCode = 'admin'));   -- DepartmentApprovers-Step53

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
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0
				 AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = Users.RoleId AND ar.RoleCode = 'admin'));   -- DepartmentApprovers-Step53

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
-------------------------------------------------------------------------------
-- spr_AddEditCommittee: the step 53 text
-------------------------------------------------------------------------------
GO

-- Committee - add / edit; the alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- DepartmentApprovers-Step53 (step UD1b): the CC and CU alerts no longer go to the Admin role.
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditCommittee]
@Code VARCHAR(50),
@CommitteeId INT,
@CommitteeCode VARCHAR(10),
@CommitteeName VARCHAR(50), 
@Board INT,
@IncorporationDate DATETIME,
@MeetingStartNo INT,
@CommitteeColorCode VARCHAR(50), 
@CessationDate VARCHAR(50), 
@StatusId INT,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT
AS
	DECLARE @alert_id INT 
	DECLARE @alert_type_id INT
	DECLARE @committee_id INT
	DECLARE @DepartmentId INT 
	DECLARE @SourceType VARCHAR(150)	
	DECLARE @DisplayText VARCHAR(150)	
BEGIN

SET @DepartmentId = (SELECT DepartmentId FROM Users WHERE UserId = @CreatedBy);

	IF (@Code = 'Save') 
	BEGIN
		INSERT INTO Committee
		(CommitteeCode, CommitteeName, Board, IncorporationDate, MeetingStartNo, CommitteeColorCode, 
			CessationDate, StatusId, CreatedOn, CreatedBy)
		VALUES
		(@CommitteeCode, @CommitteeName, @Board, @IncorporationDate, @MeetingStartNo, @CommitteeColorCode, 
			@CessationDate, @StatusId, @CreatedOn, @CreatedBy);

		SET @committee_id = @@identity

		SET @SourceType = 'Committee'
		SET @DisplayText = 'Committee (' + @CommitteeCode + ')'		

		INSERT INTO Alert_Master
		(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
		VALUES
		(@SourceType, 0, @committee_id, @DisplayText, 'CC', 3, @committee_id, @CreatedOn, @CreatedBy)
		
		SET @alert_id = @@identity

		INSERT INTO Alert_User_Map
		(AlertId, [UserId], ReadStatus, StatusId)
		(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0
		 AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = Users.RoleId AND ar.RoleCode = 'admin'))   -- DepartmentApprovers-Step53

	END
	IF (@Code = 'Update') 
	BEGIN
		UPDATE Committee SET
		CommitteeCode = @CommitteeCode,
		CommitteeName = @CommitteeName, 
		Board = @Board,
		IncorporationDate = @IncorporationDate,
		MeetingStartNo = @MeetingStartNo,
		CommitteeColorCode = @CommitteeColorCode, 
		CessationDate = @CessationDate,
		StatusId = @StatusId,
		UpdatedOn = @UpdatedOn, 
		UpdatedBy = @UpdatedBy
		WHERE
		CommitteeId = @CommitteeId;

		SET @SourceType = 'Committee'
		SET @DisplayText = 'Committee (' + @CommitteeCode + ')'		

		INSERT INTO Alert_Master
		(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
		VALUES
		(@SourceType, 0, @CommitteeId, @DisplayText, 'CU', 3, @CommitteeId, @CreatedOn, @CreatedBy)
		
		SET @alert_id = @@identity

		INSERT INTO Alert_User_Map
		(AlertId, [UserId], ReadStatus, StatusId)
		(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0
		 AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = Users.RoleId AND ar.RoleCode = 'admin'))   -- DepartmentApprovers-Step53
	END

END
GO
-------------------------------------------------------------------------------
-- spr_MinutesFinalizeByMeetingId: the step 23 text
-------------------------------------------------------------------------------
GO

-- Minutes finalize - only from MinutesStatus 'Open' (MeetingLocks-Step15). Action items are
-- not duplicated and users are mapped only to this meeting's items (MinutesFinalize fix, step 8).
-- Only active users are mapped; rows already saved are kept (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- WorkflowOrder-Step23: a meeting created after step 23 needs the agenda finalized (17), attendance entered (18)
-- and every minute updated (19, ReasonDetail 'not updated/total'; '0/0' when it has no minutes).
CREATE OR ALTER PROCEDURE [dbo].[spr_MinutesFinalizeByMeetingId]
@MeetingId INT,
@UserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @MinutesStatus VARCHAR(50);
DECLARE @WfNew INT;
DECLARE @WfAgenda INT;
DECLARE @WfAttendance INT;
DECLARE @WfTotal INT;
DECLARE @WfUpdated INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION MinutesFinalize;

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @MeetingId;

		-- Workflow order (WorkflowOrder-Step23): the meeting's state; the order applies only to a meeting
		-- created after step 23 was installed (fn_WorkflowState.IsNew)
		SELECT @WfNew = IsNew, @WfAgenda = AgendaFinalized, @WfAttendance = AttendanceRecorded,
		       @WfTotal = MinutesTotal, @WfUpdated = MinutesUpdated
		FROM dbo.fn_WorkflowState(@MeetingId);

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus <> 'Open')
		BEGIN
			SET @Reason = 3;
			SET @Detail = @MinutesStatus;
		END
		-- WorkflowOrder-Step23
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAgenda, 0) = 0)
			SET @Reason = 17;
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAttendance, 0) = 0)
			SET @Reason = 18;
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND (ISNULL(@WfTotal, 0) = 0 OR ISNULL(@WfUpdated, 0) < ISNULL(@WfTotal, 0)))
		BEGIN
			SET @Reason = 19;
			SET @Detail = CAST(ISNULL(@WfTotal, 0) - ISNULL(@WfUpdated, 0) AS VARCHAR(12)) + '/' + CAST(ISNULL(@WfTotal, 0) AS VARCHAR(12));
		END
		ELSE
		BEGIN
			UPDATE Meeting SET
			MinutesStatus = 'F',
			UpdatedOn = GETDATE(),
			UpdatedBy = @UserId
			WHERE MeetingId = @MeetingId;

			INSERT INTO Action_Item
				([MinutesId], Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy)
				(SELECT m.[MinutesId], ' ', ' ', 'Pending', GETDATE(), @UserId
					FROM Minutes m WHERE
						m.AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId) AND
						m.DecisionTypeId = 1 AND
						NOT EXISTS (SELECT 1 FROM Action_Item x WHERE x.MinutesId = m.MinutesId))

			INSERT INTO ActionItem_User_Map
				(ActionItemId, [UserId], ReadStatus, StatusId)
				(SELECT b.ActionItemId, a.UserId,0,1 FROM Users a, Action_Item b
					WHERE a.AccountStatus = 1 AND a.IsSystem = 0 AND
						b.MinutesId IN (SELECT MinutesId FROM Minutes WHERE
							AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId)) AND
						NOT EXISTS (SELECT 1 FROM ActionItem_User_Map x
							WHERE x.ActionItemId = b.ActionItemId AND x.UserId = a.UserId))

			SET @Result = 1;
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
			ROLLBACK TRANSACTION MinutesFinalize;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- The three new objects (the procedures first: nothing reads fn_FunctionalUsers once the old texts are back)
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.spr_GetResetPasswordMail', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_GetResetPasswordMail;
IF OBJECT_ID('dbo.spr_GetMeetingCommitteeMailId', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_GetMeetingCommitteeMailId;
IF OBJECT_ID('dbo.fn_FunctionalUsers', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_FunctionalUsers;
GO

-------------------------------------------------------------------------------
-- Result: the three texts letter for letter, the new objects gone
-------------------------------------------------------------------------------
DECLARE @D NVARCHAR(MAX), @I INT;
DECLARE @H1 VARCHAR(400), @H2 VARCHAR(400), @H3 VARCHAR(400);
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), CHAR(13), ''); SET @H1 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H1 = @H1 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditCommittee')), CHAR(13), ''); SET @H2 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H2 = @H2 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')), CHAR(13), ''); SET @H3 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H3 = @H3 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END

IF (ISNULL(@H1, '') <> 'A058BEE902EF43E0DFF8F2C7367E585C7E2EECFC6E5328D4EBE58FF6EDBAFBE9698513834C64682A' OR ISNULL(@H2, '') <> '817EA0F49B8526EF915C83EB02DA9F7CAA07E073' OR ISNULL(@H3, '') <> 'FB127BB7509FE9C35B7BD3AB4C0848ACAC641E7F')
    RAISERROR('Rollback of step 55 is NOT complete: a text is not the one step 55 replaced. Tell the Consultant.', 16, 1);
ELSE IF EXISTS (SELECT 1 FROM (VALUES ('fn_FunctionalUsers'), ('spr_GetMeetingCommitteeMailId'), ('spr_GetResetPasswordMail')) o(Name)
                WHERE OBJECT_ID('dbo.' + o.Name) IS NOT NULL)
    RAISERROR('Rollback of step 55 is NOT complete: a new object of step 55 is still there. Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 55 rolled back: the three texts are back letter for letter (SHA-1 compared); the three new objects are dropped.';
GO

SET NOEXEC OFF;
GO
