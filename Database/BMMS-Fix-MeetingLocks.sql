/* ============================================================================
   BMMS - Meeting-state locks (step 15)
   ----------------------------------------------------------------------------
   Once the minutes of a meeting are finalized, its members, attendance and
   chairman can no longer be changed, and each finalize / confirm step can be
   done only once and only in order. The state is checked inside the
   procedure while the meeting row is locked (UPDLOCK, HOLDLOCK) in the same
   transaction as the change, so two browser tabs cannot both succeed.

   Meeting state (Meeting table; NULL is treated as 'Open'):
     AgendaStatus   'Open' -> 'Close'  (agenda finalized)
     MinutesStatus  'Open' -> 'F'      (minutes finalized)
                    'F'    -> 'C'      (minutes confirmed)

   Every procedure below except spr_UpdateAttendance returns ONE row:
     Result        1 = done, 0 = refused
     Reason        0 done
                   1 minutes finalized (MinutesStatus 'F' or 'C')
                   2 member has attendance recorded for the meeting
                   3 wrong state for this step (ReasonDetail = the status)
                   4 meeting, meeting member or chairman not found
     ReasonDetail  the current status for reason 3, otherwise ''
   spr_UpdateAttendance still returns only Result (0 = refused: meeting not
   held yet, step 12, or minutes finalized); the Attendance page tells the
   two apart with spr_GetMeetingStatusByMeetingId.

   Procedures
     spr_AddEditMeetingMember                 refuses add / edit when the
                                              minutes are finalized
     spr_DeleteMeetingMemberByMeetingMemberId refuses when the minutes are
                                              finalized, or the member has an
                                              Attendance row for the meeting
     spr_UpdateAttendance                     + refuses when the minutes are
                                              finalized (step 12 check kept)
     spr_UpdateMeetingChairman                refuses when the minutes are
                                              finalized
     spr_AgendaFinalizeByMeetingId            only from AgendaStatus 'Open'
     spr_MinutesFinalizeByMeetingId           only from MinutesStatus 'Open'
     spr_MinutesConfirmByMeetingId            only from MinutesStatus 'F'
     spr_GetMeetingStatusByMeetingId          NEW, AgendaStatus,
                                              MinutesStatus, IsHeld,
                                              IsMinutesFinalized (read only,
                                              for the pages)

   Replaces procedures of earlier steps: spr_UpdateMeetingChairman and
   spr_AgendaFinalizeByMeetingId (step 6), spr_MinutesFinalizeByMeetingId
   (step 8), spr_UpdateAttendance (step 12). If step 6, 8 or 12 is ever
   re-run, run this script again afterwards.

   Run it BEFORE deploying the build that reads Result / Reason from these
   procedures, and deploy that build straight after: an older build reads
   the new results wrongly (see Database/README.md, step 15).

   This script only replaces / adds procedures. It changes no data and adds
   no constraint. Safe to re-run. It needs step 12 (spr_CheckMeetingHeld-
   ByMeetingId) and stops otherwise.

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
ELSE IF (OBJECT_ID('dbo.spr_CheckMeetingHeldByMeetingId') IS NULL)
BEGIN
    RAISERROR('Step 12 (BMMS-Fix-Attendance-FutureMeeting.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Meeting - state for the pages (MeetingLocks-Step15)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMeetingStatusByMeetingId]
@MeetingId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	ISNULL(AgendaStatus, 'Open') AS AgendaStatus,
	ISNULL(MinutesStatus, 'Open') AS MinutesStatus,
	CASE WHEN MeetingDate IS NOT NULL AND CAST(MeetingDate AS date) <= CAST(GETDATE() AS date) THEN 1 ELSE 0 END AS IsHeld,
	CASE WHEN ISNULL(MinutesStatus, 'Open') IN ('F', 'C') THEN 1 ELSE 0 END AS IsMinutesFinalized
	FROM Meeting
	WHERE MeetingId = @MeetingId;
END
GO

-- Meeting_Member - add / edit, refused once the minutes are finalized (MeetingLocks-Step15)
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditMeetingMember]
@Code VARCHAR(50),
@MeetingMemberId INT,
@MeetingId INT,
@MemberId INT,
@MemberTypeId INT,
@StatusId INT,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @LockMeetingId INT;
DECLARE @MinutesStatus VARCHAR(50);
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
			SAVE TRANSACTION MeetingMemberSave;

		-- An edit stays on the meeting of the existing row
		IF (@Code = 'Update')
			SET @LockMeetingId = (SELECT MeetingId FROM Meeting_Member WITH (UPDLOCK, HOLDLOCK)
			                      WHERE MeetingMemberId = @MeetingMemberId);
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus IN ('F', 'C'))
			SET @Reason = 1;
		ELSE IF (@Code = 'Save')
		BEGIN
			INSERT INTO Meeting_Member
			(MeetingId, MemberId, MemberTypeId,  StatusId, CreatedOn, CreatedBy)
			VALUES
			(@MeetingId, @MemberId, @MemberTypeId, @StatusId, @CreatedOn, @CreatedBy);

			SET @Result = 1;
		END
		ELSE IF (@Code = 'Update')
		BEGIN
			UPDATE Meeting_Member SET
			MemberId = @MemberId,
			MemberTypeId = @MemberTypeId,
			StatusId = @StatusId,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy
			WHERE
			MeetingMemberId = @MeetingMemberId;

			SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;
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
			ROLLBACK TRANSACTION MeetingMemberSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Meeting_Member - delete, refused once the minutes are finalized or the member's attendance is recorded (MeetingLocks-Step15)
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteMeetingMemberByMeetingMemberId]
@MeetingMemberId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @MeetingId INT;
DECLARE @MemberId INT;
DECLARE @MinutesStatus VARCHAR(50);
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
			SAVE TRANSACTION MeetingMemberDelete;

		SELECT @MeetingId = MeetingId, @MemberId = MemberId
		FROM Meeting_Member WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingMemberId = @MeetingMemberId;

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @MeetingId;

		IF (@MeetingId IS NULL OR @MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus IN ('F', 'C'))
			SET @Reason = 1;
		ELSE IF EXISTS (SELECT 1 FROM Attendance WITH (UPDLOCK, HOLDLOCK)
		                WHERE MeetingId = @MeetingId AND MemberId = @MemberId)
			SET @Reason = 2;
		ELSE
		BEGIN
			DELETE FROM Meeting_Member WHERE MeetingMemberId = @MeetingMemberId;

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
			ROLLBACK TRANSACTION MeetingMemberDelete;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Attendance - refused for a meeting that has not yet taken place (Attendance-FutureMeeting)
-- or whose minutes are finalized (MeetingLocks-Step15). Returns only Result, as in step 12.
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
DECLARE @Result INT
DECLARE @OwnTransaction INT
DECLARE @MeetingDate DATETIME
DECLARE @MinutesStatus VARCHAR(50)
BEGIN
SET NOCOUNT ON;

SET @Result = 0;

IF (@@TRANCOUNT = 0)
	SET @OwnTransaction = 1;
ELSE
	SET @OwnTransaction = 0;

BEGIN TRY
	IF (@OwnTransaction = 1)
		BEGIN TRANSACTION;
	ELSE
		SAVE TRANSACTION AttendanceSave;

	SELECT @MeetingDate = MeetingDate, @MinutesStatus = ISNULL(MinutesStatus, 'Open')
	FROM Meeting WITH (UPDLOCK, HOLDLOCK)
	WHERE MeetingId = @MeetingId;

	-- Attendance-FutureMeeting: only a meeting dated today or earlier (database server date).
	-- MeetingLocks-Step15: not once the minutes are finalized.
	IF (@MinutesStatus IS NOT NULL
	    AND @MeetingDate IS NOT NULL
	    AND CAST(@MeetingDate AS date) <= CAST(GETDATE() AS date)
	    AND @MinutesStatus NOT IN ('F', 'C'))
	BEGIN
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
		ROLLBACK TRANSACTION AttendanceSave;

	THROW;
END CATCH

SELECT @Result AS Result;
END
GO

-- Meeting - ChairmanNameId: only a member that exists can be set (FK #5);
-- refused once the minutes are finalized (MeetingLocks-Step15)
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateMeetingChairman]
(
@MeetingId INT,
@CommitteeId INT,
@ChairmanNameId INT
)
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @MinutesStatus VARCHAR(50);
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
			SAVE TRANSACTION MeetingChairman;

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @MeetingId AND CommitteeId = @CommitteeId;

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus IN ('F', 'C'))
			SET @Reason = 1;
		ELSE IF NOT EXISTS (SELECT 1 FROM Member WHERE MemberId = @ChairmanNameId)
			SET @Reason = 4;
		ELSE
		BEGIN
			UPDATE Meeting SET
			ChairmanNameId = @ChairmanNameId
			WHERE
			MeetingId = @MeetingId AND
			CommitteeId = @CommitteeId;

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
			ROLLBACK TRANSACTION MeetingChairman;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Agenda finalize - only from AgendaStatus 'Open' (MeetingLocks-Step15). The minutes of
-- the meeting are deleted and re-created, so their action items go first (FK #5).
CREATE OR ALTER PROCEDURE [dbo].[spr_AgendaFinalizeByMeetingId]
@MeetingId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @AgendaStatus VARCHAR(50);
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
			SAVE TRANSACTION AgendaFinalize;

		SELECT @AgendaStatus = ISNULL(AgendaStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @MeetingId;

		IF (@AgendaStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@AgendaStatus <> 'Open')
		BEGIN
			SET @Reason = 3;
			SET @Detail = @AgendaStatus;
		END
		ELSE
		BEGIN
			-- FK #5
			DELETE FROM Action_Item WHERE
			MinutesId IN (SELECT MinutesId FROM Minutes WHERE
				AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId));

			DELETE FROM Minutes WHERE
			AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId);

			INSERT INTO Minutes
			(
			AgendaId, DecisionTypeId, Directions, ActualResolution,
			CreatedOn, CreatedBy, UpdatedOn, UpdatedBy
			)
			(
			SELECT
			AgendaId, 3, ' ', ProposedResolution,
			GETDATE(), 1, GETDATE(), 1
			FROM Agenda
			WHERE MeetingId = @MeetingId
			AND
			ControllerApprovedStatus = 'Approved'
			);

			UPDATE Meeting SET
			AgendaStatus = 'Close'
			WHERE MeetingId = @MeetingId;

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
			ROLLBACK TRANSACTION AgendaFinalize;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Minutes finalize - only from MinutesStatus 'Open' (MeetingLocks-Step15). Action items are
-- not duplicated and users are mapped only to this meeting's items (MinutesFinalize fix, step 8).
CREATE OR ALTER PROCEDURE [dbo].[spr_MinutesFinalizeByMeetingId]
@MeetingId INT,
@UserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @MinutesStatus VARCHAR(50);
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

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus <> 'Open')
		BEGIN
			SET @Reason = 3;
			SET @Detail = @MinutesStatus;
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
					WHERE b.MinutesId IN (SELECT MinutesId FROM Minutes WHERE
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

-- Minutes confirm - only from MinutesStatus 'F' (MeetingLocks-Step15)
CREATE OR ALTER PROCEDURE [dbo].[spr_MinutesConfirmByMeetingId]
@MeetingId INT,
@UserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @MinutesStatus VARCHAR(50);
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
			SAVE TRANSACTION MinutesConfirm;

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @MeetingId;

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus <> 'F')
		BEGIN
			SET @Reason = 3;
			SET @Detail = @MinutesStatus;
		END
		ELSE
		BEGIN
			UPDATE Meeting SET
			MinutesStatus = 'C',
			UpdatedOn = GETDATE(),
			UpdatedBy = @UserId
			WHERE MeetingId = @MeetingId;

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
			ROLLBACK TRANSACTION MinutesConfirm;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

IF (SELECT COUNT(*) FROM sys.sql_modules
    WHERE definition LIKE '%MeetingLocks-Step15%'
    AND object_id IN (OBJECT_ID('dbo.spr_GetMeetingStatusByMeetingId'), OBJECT_ID('dbo.spr_AddEditMeetingMember'),
                      OBJECT_ID('dbo.spr_DeleteMeetingMemberByMeetingMemberId'), OBJECT_ID('dbo.spr_UpdateAttendance'),
                      OBJECT_ID('dbo.spr_UpdateMeetingChairman'), OBJECT_ID('dbo.spr_AgendaFinalizeByMeetingId'),
                      OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId'), OBJECT_ID('dbo.spr_MinutesConfirmByMeetingId'))) = 8
    PRINT 'Meeting locks (step 15) installed: 8 procedures.';
GO

SET NOEXEC OFF;
GO
