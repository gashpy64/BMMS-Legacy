/* ============================================================================
   BMMS - Rollback of step 38 (BMMS-Fix-MinutesDueDate-Step38.sql, step UN6a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Restores spr_UpdateMinutes with the text of step 31
   (BMMS-Fix-UnicodeText-Step31.sql), as installed on BMMS_Test before step
   38: no @DueDate parameter. The due dates already stored and their audit
   rows are KEPT.

   Roll back the build first (or at the same time): the step UN6a build
   passes @DueDate and its saves fail with "too many arguments" against the
   step 31 procedure.

   Changes no data. Safe to re-run, also where step 38 was never installed.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') NOT LIKE '%UnicodeText-Step31%')
BEGIN
    RAISERROR('Step 31 is not installed in "%s" (marker UnicodeText-Step31 on spr_UpdateMinutes). This rollback restores the step 31 text over step 31 or step 38 only. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO


-- Minutes update - refused once the minutes are confirmed (MeetingLocks-Step16). The new action item is
-- mapped to the agenda creator only if that user still exists (FK #5, step 6). An inactive creator gets
-- no new row and the item goes to the active Controllers instead (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- WorkflowOrder-Step23: a meeting created after step 23 needs the agenda finalized (17) and attendance entered (18).
-- UnicodeText-Step31: @Directions, @ActualResolution and @ShortText are NVARCHAR(MAX) (were TEXT)
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateMinutes]
@Code VARCHAR(50),
@MinutesId INT,
@DecisionTypeId INT,
@Directions NVARCHAR(MAX),
@ActualResolution NVARCHAR(MAX),
@ShortText NVARCHAR(MAX),
@CreatedBy INT,
@UpdatedBy INT
AS
	DECLARE @ActionItemId INT;
	DECLARE @CountActionItemId INT;
	DECLARE @AgendaId INT;
	DECLARE @UserId INT;
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
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
			SAVE TRANSACTION MinutesUpdate;

		SET @LockMeetingId = (SELECT a.MeetingId FROM Minutes mi WITH (UPDLOCK, HOLDLOCK)
		                      JOIN Agenda a ON a.AgendaId = mi.AgendaId
		                      WHERE mi.MinutesId = @MinutesId);

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		-- Workflow order (WorkflowOrder-Step23): the meeting's state; the order applies only to a meeting
		-- created after step 23 was installed (fn_WorkflowState.IsNew)
		SELECT @WfNew = IsNew, @WfAgenda = AgendaFinalized, @WfAttendance = AttendanceRecorded,
		       @WfTotal = MinutesTotal, @WfUpdated = MinutesUpdated
		FROM dbo.fn_WorkflowState(@LockMeetingId);

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus = 'C')
			SET @Reason = 7;
		-- WorkflowOrder-Step23: a meeting created after step 23 updates its minutes only once the agenda
		-- is finalized and the attendance is entered (chairman and at least one member present)
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAgenda, 0) = 0)
			SET @Reason = 17;
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAttendance, 0) = 0)
			SET @Reason = 18;
		ELSE
		BEGIN
			IF (@Code = 'All')
			BEGIN
				UPDATE Minutes SET
				DecisionTypeId = @DecisionTypeId,
				StatusId = 1,
				UpdatedOn = GETDATE(),
				UpdatedBy = @UpdatedBy
				WHERE
				MinutesId = @MinutesId;

				SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);

				UPDATE Agenda SET ShortText = @ShortText WHERE AgendaId = @AgendaId;

				SET @Directions = (SELECT Directions FROM Minutes WHERE MinutesId = @MinutesId);

				IF (@DecisionTypeId != 1)
				BEGIN
					DELETE FROM Action_Item WHERE MinutesId = @MinutesId;
				END

				IF (@DecisionTypeId = 1)
				BEGIN
					SET @CountActionItemId = (SELECT COUNT(ActionItemId) FROM Action_Item WHERE MinutesId = @MinutesId);
					SET @ActionItemId = (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @MinutesId);

					IF (@CountActionItemId >= 1)
					BEGIN
						UPDATE [Action_Item] SET
						Directions = @Directions, UpdatedOn = GETDATE()
						WHERE ActionItemId = @ActionItemId;

						UPDATE ActionItem_User_Map SET
						ReadStatus = 1
						WHERE ActionItemId = @ActionItemId;
					END

					IF (@CountActionItemId <= 0)
					BEGIN
						INSERT INTO [Action_Item]
							([MinutesId],[Directions],[ActionText],[ActionStatus],[UpdatedOn],[UpdatedBy])
						VALUES
							(@MinutesId, @Directions, '','',GETDATE(),@UpdatedBy);

						SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);
						SET @UserId = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId);
						SET @ActionItemId = (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @MinutesId);

						-- FK #5: was INSERT ... VALUES (@ActionItemId, @UserId, 0, 1)
						INSERT INTO ActionItem_User_Map
							(ActionItemId, UserId, ReadStatus, StatusId)
						SELECT @ActionItemId, UserId, 0, 1
						FROM Users
						WHERE UserId = @UserId AND AccountStatus = 1 AND IsSystem = 0;

						-- Creator inactive: the active Controllers see the item (UserStatus2b-Step17).
						-- A creator who no longer exists is unchanged (no row, FK #5).
						IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UserId AND (AccountStatus <> 1 OR IsSystem = 1))
							INSERT INTO ActionItem_User_Map
								(ActionItemId, UserId, ReadStatus, StatusId)
							SELECT @ActionItemId, u.UserId, 0, 1
							FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
							WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0;
					END
				END
			END

			IF (@Code = 'Directions')
			BEGIN
				UPDATE Minutes SET
				Directions = @Directions, StatusId = 1, UpdatedOn = GETDATE(), UpdatedBy = @UpdatedBy
				WHERE MinutesId = @MinutesId;
			END

			IF (@Code = 'ActualResolution')
			BEGIN
				SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);

				UPDATE Minutes SET
				ActualResolution = @ActualResolution, StatusId = 1,	UpdatedOn = GETDATE(), 	UpdatedBy = @UpdatedBy
				WHERE MinutesId = @MinutesId;

				UPDATE Agenda SET ProposedResolution = @ActualResolution
				WHERE AgendaId = @AgendaId;
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
			ROLLBACK TRANSACTION MinutesUpdate;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') NOT LIKE '%MinutesDueDate-Step38%')
    PRINT 'Step 38 rolled back: spr_UpdateMinutes has the text of step 31. The due dates already stored are kept.';
ELSE
    RAISERROR('Rollback of step 38 is not complete: spr_UpdateMinutes still carries the marker MinutesDueDate-Step38. Read the messages above and run the script again.', 16, 1);
GO

SET NOEXEC OFF;
GO
