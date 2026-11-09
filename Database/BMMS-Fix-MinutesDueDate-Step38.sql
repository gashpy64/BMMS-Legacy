/* ============================================================================
   BMMS - An optional due date on a Followup decision (step 38, step UN6a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Minutes.DueDate (datetime, NULL) exists but nothing saved it: the box on
   Update Minutes was not connected and spr_UpdateMinutes had no parameter
   for it, so every row is NULL and "overdue" cannot be shown. Decisions
   (Consultant, 2026-11-09): the due date is optional and only for a
   Followup decision; not before the meeting date; editable until the
   minutes are confirmed, like the other fields; a change is audited.

   Objects
     spr_UpdateMinutes   REPLACED (text of step 31). New last parameter
                           @DueDate DATETIME = NULL
                         Code 'All' (Save minutes):
                           - a Followup (DecisionTypeId 1) stores @DueDate
                             without its time; any other decision stores
                             NULL;
                           - a Followup date before the meeting date is
                             refused: Result 0, Reason 22, ReasonDetail the
                             meeting date (dd-Mon-yyyy); nothing is saved.
                             A meeting without a date has no limit;
                           - a change of the stored due date writes one
                             Audit_Trail_Master row (Audit_Table 'Minutes',
                             Key_Field 'AgendaNo', Field_Name 'DueDate', old
                             and new as dd-Mon-yyyy, empty for none); no row
                             when it is unchanged. The Decision change is not
                             audited (as before).
                         Codes 'Directions' and 'ActualResolution' leave the
                         due date as it is. The locks are unchanged: refused
                         once the minutes are confirmed (Reason 7), and for a
                         meeting created after step 23 before the agenda is
                         finalized (17) and the attendance entered (18);
                         finalized minutes (F) can still be updated.
                         A caller that saves Code 'All' without @DueDate
                         clears the due date (only Update Minutes calls it;
                         see the README warning about the build).
   Marker MinutesDueDate-Step38. Only lines are added: the texts of steps 6
   (FK #5), 16, 17, 18, 23 and 31 are kept, so those steps still read
   Installed in BMMS-Check-InstalledSteps.sql.

   Order: step 31 must be installed before this step; the script stops if
   it is not. Re-running step 6, 16, 17, 18, 23 or 31 after this step
   brings back an older spr_UpdateMinutes and removes step 38: run step 38
   again.

   Changes no data. Safe to re-run.
   BMMS-Rollback-MinutesDueDate-Step38.sql restores the step 31 text and
   keeps the due dates already stored.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
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
ELSE IF (COL_LENGTH('dbo.Minutes', 'DueDate') IS NULL OR OBJECT_ID('dbo.Audit_Trail_Master', 'U') IS NULL
         OR OBJECT_ID('dbo.fn_WorkflowState') IS NULL)
BEGIN
    RAISERROR('Minutes.DueDate, Audit_Trail_Master or fn_WorkflowState is missing in "%s". This is not a BMMS database of the expected version (step 23 needed). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') NOT LIKE '%UnicodeText-Step31%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') NOT LIKE '%WorkflowOrder-Step23%')
BEGIN
    RAISERROR('Step 31 is not installed in "%s" (spr_UpdateMinutes needs the markers UnicodeText-Step31 and WorkflowOrder-Step23). The steps are installed in order: run BMMS-Fix-UnicodeText-Step31.sql first (BMMS-Check-InstalledSteps.sql shows which steps are installed), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
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
-- MinutesDueDate-Step38: @DueDate (optional, last). Code 'All': a Followup (DecisionTypeId 1) stores the date without its time,
-- any other decision stores NULL; a Followup date before the meeting date is refused (Reason 22, ReasonDetail the
-- meeting date dd-Mon-yyyy) and nothing is saved; a change of the stored due date writes one Audit_Trail_Master
-- row (Minutes, DueDate). Codes 'Directions' and 'ActualResolution' leave the due date as it is
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateMinutes]
@Code VARCHAR(50),
@MinutesId INT,
@DecisionTypeId INT,
@Directions NVARCHAR(MAX),
@ActualResolution NVARCHAR(MAX),
@ShortText NVARCHAR(MAX),
@CreatedBy INT,
@UpdatedBy INT,
@DueDate DATETIME = NULL   -- MinutesDueDate-Step38
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
	DECLARE @DdNew DATETIME;   -- MinutesDueDate-Step38: the due date to store
	DECLARE @DdOld DATETIME;
	DECLARE @DdMeetingDate DATETIME;
	DECLARE @DdAgendaNo VARCHAR(50);
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

		-- MinutesDueDate-Step38: the due date to store (Code 'All' only): a Followup keeps the date without its time
		SET @DdNew = CASE WHEN @Code = 'All' AND @DecisionTypeId = 1 AND @DueDate IS NOT NULL
		                  THEN DATEADD(DAY, DATEDIFF(DAY, 0, @DueDate), 0) ELSE NULL END;
		SET @DdMeetingDate = (SELECT DATEADD(DAY, DATEDIFF(DAY, 0, MeetingDate), 0) FROM Meeting WHERE MeetingId = @LockMeetingId);

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
		-- MinutesDueDate-Step38: a Followup due date before the meeting date (a meeting without a date has no limit)
		ELSE IF (@DdNew IS NOT NULL AND @DdMeetingDate IS NOT NULL AND @DdNew < @DdMeetingDate)
		BEGIN
			SET @Reason = 22;
			SET @Detail = REPLACE(CONVERT(VARCHAR(11), @DdMeetingDate, 106), ' ', '-');
		END
		ELSE
		BEGIN
			IF (@Code = 'All')
			BEGIN
				-- MinutesDueDate-Step38: the due date (NULL for a decision other than Followup); one audit row when it changes
				SET @DdOld = (SELECT DueDate FROM Minutes WHERE MinutesId = @MinutesId);
				UPDATE Minutes SET DueDate = @DdNew WHERE MinutesId = @MinutesId;
				IF (@DdOld <> @DdNew OR (@DdOld IS NULL AND @DdNew IS NOT NULL) OR (@DdOld IS NOT NULL AND @DdNew IS NULL))
				BEGIN
					SET @DdAgendaNo = (SELECT a.AgendaNo FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE mi.MinutesId = @MinutesId);
					INSERT INTO [Audit_Trail_Master]
					   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
					VALUES
						('UP', 'Minutes', 'AgendaNo', @DdAgendaNo, 'DueDate',
						 ISNULL(REPLACE(CONVERT(VARCHAR(11), @DdOld, 106), ' ', '-'), ''),
						 ISNULL(REPLACE(CONVERT(VARCHAR(11), @DdNew, 106), ' ', '-'), ''),
						 @UpdatedBy, GETDATE());
				END

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

IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') LIKE '%MinutesDueDate-Step38%')
    PRINT 'Step 38 installed: spr_UpdateMinutes (MinutesDueDate-Step38). No data was changed.';
ELSE
    RAISERROR('Step 38 is not complete: spr_UpdateMinutes does not carry the marker MinutesDueDate-Step38. Read the messages above and run the script again.', 16, 1);
GO

SET NOEXEC OFF;
GO
