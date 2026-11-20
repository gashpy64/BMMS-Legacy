/* ============================================================================
   BMMS - Meeting workflow order (step 23, installed after step 28)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   The order of a meeting: 1 Agenda Finalisation, 2 Attendance, 3 Update
   Minutes, 4 Minutes Finalisation, 5 Minutes Generation (Reports, step 22),
   6 Minutes Confirmation. Until now most of it was checked only by the pages
   (and partly through stand-ins: the chairman for "attendance entered").
   From this step the database refuses a step taken too early:

     Attendance and chairman   before the agenda is finalized   Reason 17
     Update Minutes (all kinds) and the agenda short text on the minutes page
                               before the agenda is finalized   Reason 17
                               before attendance is entered     Reason 18
     Minutes Finalisation      before the agenda is finalized   Reason 17
                               before attendance is entered     Reason 18
                               while a minute was never updated, or the
                               meeting has no minutes           Reason 19,
                               ReasonDetail 'not updated/total' ('0/0')
     Minutes Confirmation      before Minutes Finalisation: unchanged (step
                               15, Reason 3 with ReasonDetail 'Open')

   "Agenda finalized"   Meeting.AgendaStatus is not 'Open' (NULL = 'Open').
   "Attendance entered" the chairman is set AND at least one member is marked
                        present ('P') in Attendance.
   "Minute updated"     Minutes.StatusId = 1 (set when the minute is saved on
                        Update Minutes); every minute of the meeting.
   The existing refusals keep their place and come first (4, 1, 3, 7, 9).

   Grandfathering: the order applies only to a meeting created after this
   step was installed: Meeting.CreatedOn on or after the App_Setting value
   WorkflowOrderFrom, written once by this script (a re-run keeps it). A
   meeting without CreatedOn counts as older. Older meetings behave exactly
   as before, so no existing meeting is changed or blocked.

   Objects (each carries the text WorkflowOrder-Step23)
     fn_WorkflowState               NEW, one row per meeting: IsNew,
                                    AgendaFinalized, AttendanceRecorded,
                                    MinutesTotal, MinutesUpdated
     spr_GetMeetingWorkflowState    NEW, the same row for the pages
     spr_UpdateAttendance           REPLACED (from step 16; keeps
                                    Attendance-FutureMeeting,
                                    MeetingLocks-Step15, MeetingLocks-Step16)
     spr_UpdateMeetingChairman      REPLACED (from step 16; keeps
                                    MeetingLocks-Step15, MeetingLocks-Step16)
     spr_UpdateAgendaShortText      REPLACED (from step 16; keeps
                                    MeetingLocks-Step16)
     spr_UpdateMinutes              REPLACED (from step 18; keeps FK #5,
                                    MeetingLocks-Step16, UserStatus2b-Step17,
                                    SystemAccount3-Step18)
     spr_MinutesFinalizeByMeetingId REPLACED (from step 18; keeps the step 8
                                    duplicate check, MeetingLocks-Step15,
                                    UserStatus2b-Step17, SystemAccount3-Step18)
     App_Setting row WorkflowOrderFrom (added only if missing)

   Changes no meeting, attendance or minutes data. Safe to re-run. Needs
   steps 12, 15, 16, 17 and 18 (checked through their texts in the five
   procedures) and stops otherwise. Steps 6, 8, 12, 15, 16, 17 and 18 each
   contain an older version of one of these procedures: if one of them is
   re-run, run this script again afterwards. Run it BEFORE deploying the
   build that shows the Reason 17 to 19 messages.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".

   If you install from the command line, use sqlcmd -I (quoted identifiers ON);
   installing from SSMS already does this.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
DECLARE @Missing TABLE (Seq INT IDENTITY(1,1), ObjectName SYSNAME, Marker VARCHAR(100), Step VARCHAR(10));
DECLARE @MissingObject SYSNAME;
DECLARE @MissingStep VARCHAR(10);

-- The older texts each replaced procedure must carry: whatever this script finds missing was replaced by
-- a later re-run of an older step, which has to be run again first
INSERT INTO @Missing (ObjectName, Marker, Step)
SELECT r.ObjectName, r.Marker, r.Step
FROM (VALUES
    ('spr_UpdateAttendance', '%Attendance-FutureMeeting%', '12'),
    ('spr_UpdateAttendance', '%MeetingLocks-Step15%', '15'),
    ('spr_UpdateAttendance', '%MeetingLocks-Step16%', '16'),
    ('spr_UpdateMeetingChairman', '%MeetingLocks-Step15%', '15'),
    ('spr_UpdateMeetingChairman', '%MeetingLocks-Step16%', '16'),
    ('spr_UpdateAgendaShortText', '%MeetingLocks-Step16%', '16'),
    ('spr_UpdateMinutes', '%FK #5%', '6'),
    ('spr_UpdateMinutes', '%MeetingLocks-Step16%', '16'),
    ('spr_UpdateMinutes', '%UserStatus2b-Step17%', '17'),
    ('spr_UpdateMinutes', '%SystemAccount3-Step18%', '18'),
    ('spr_MinutesFinalizeByMeetingId', '%NOT EXISTS (SELECT 1 FROM ActionItem[_]User[_]Map x%', '8'),
    ('spr_MinutesFinalizeByMeetingId', '%MeetingLocks-Step15%', '15'),
    ('spr_MinutesFinalizeByMeetingId', '%UserStatus2b-Step17%', '17'),
    ('spr_MinutesFinalizeByMeetingId', '%SystemAccount3-Step18%', '18')
) r (ObjectName, Marker, Step)
WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + r.ObjectName)), '') NOT LIKE r.Marker;

SELECT TOP 1 @MissingObject = ObjectName, @MissingStep = Step FROM @Missing ORDER BY Seq;

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.App_Setting', 'U') IS NULL)
BEGIN
    RAISERROR('Step 16 (BMMS-Fix-MeetingLocks-Step16.sql) is not installed in "%s": table App_Setting is missing. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@MissingObject IS NOT NULL)
BEGIN
    RAISERROR('In "%s", %s does not carry the text of step %s: that step (or a later one in the README re-run order) was replaced by a re-run. Run steps %s to 18 again as the README says, then this script. Nothing was changed.', 16, 1, @CurrentDatabase, @MissingObject, @MissingStep, @MissingStep);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- The time from which meetings follow the workflow order (WorkflowOrder-Step23).
-- Written once: a re-run keeps the first value.
-------------------------------------------------------------------------------
DECLARE @WorkflowOrderFrom VARCHAR(23);

IF NOT EXISTS (SELECT 1 FROM App_Setting WHERE SettingCode = 'WorkflowOrderFrom')
    INSERT INTO App_Setting (SettingCode, SettingValue, Description)
    VALUES ('WorkflowOrderFrom', CONVERT(VARCHAR(23), GETDATE(), 126),
            'Meetings created from this time follow the workflow order of step 23 (WorkflowOrder-Step23); older meetings keep the earlier behaviour');

SET @WorkflowOrderFrom = (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'WorkflowOrderFrom');
PRINT 'Workflow order applies to meetings created from ' + @WorkflowOrderFrom + ' (App_Setting WorkflowOrderFrom).';
GO

-- Workflow state of one meeting (WorkflowOrder-Step23). IsNew: created on or after WorkflowOrderFrom (no
-- CreatedOn, or no setting: 0). AgendaFinalized: AgendaStatus not 'Open' (NULL = 'Open'). AttendanceRecorded:
-- chairman set and at least one member present ('P'). MinutesTotal / MinutesUpdated: minutes of the meeting /
-- those saved on Update Minutes (StatusId 1). No row when the meeting does not exist.
CREATE OR ALTER FUNCTION [dbo].[fn_WorkflowState]
(
@MeetingId INT
)
RETURNS TABLE
AS
RETURN
SELECT
m.MeetingId,
CASE WHEN m.CreatedOn IS NOT NULL AND f.WorkflowOrderFrom IS NOT NULL AND m.CreatedOn >= f.WorkflowOrderFrom
     THEN 1 ELSE 0 END AS IsNew,
CASE WHEN ISNULL(m.AgendaStatus, 'Open') = 'Open' THEN 0 ELSE 1 END AS AgendaFinalized,
CASE WHEN m.ChairmanNameId IS NOT NULL
      AND EXISTS (SELECT 1 FROM Attendance a WHERE a.MeetingId = m.MeetingId AND a.Attendance = 'P')
     THEN 1 ELSE 0 END AS AttendanceRecorded,
(SELECT COUNT(*) FROM Minutes mi JOIN Agenda ag ON ag.AgendaId = mi.AgendaId
 WHERE ag.MeetingId = m.MeetingId) AS MinutesTotal,
(SELECT COUNT(*) FROM Minutes mi JOIN Agenda ag ON ag.AgendaId = mi.AgendaId
 WHERE ag.MeetingId = m.MeetingId AND mi.StatusId = 1) AS MinutesUpdated
FROM Meeting m
CROSS JOIN (SELECT CASE WHEN ISDATE(s.SettingValue) = 1 THEN CONVERT(DATETIME, s.SettingValue, 126) END AS WorkflowOrderFrom
            FROM (SELECT 1 AS One) d
            LEFT JOIN App_Setting s ON s.SettingCode = 'WorkflowOrderFrom') f
WHERE m.MeetingId = @MeetingId;
GO

-- Workflow state for the pages (WorkflowOrder-Step23); no row when the meeting does not exist
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMeetingWorkflowState]
@MeetingId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT IsNew, AgendaFinalized, AttendanceRecorded, MinutesTotal, MinutesUpdated
	FROM dbo.fn_WorkflowState(@MeetingId);
END
GO

-- Attendance - save one member (MeetingLocks-Step16): a NEW committee-member row only for a member on the
-- committee on the meeting date. Kept from step 15 (MeetingLocks-Step15) and step 12 (Attendance-FutureMeeting).
-- WorkflowOrder-Step23: a meeting created after step 23 takes attendance only once its agenda is finalized
-- (Result 0; the chairman is saved first and refused with Reason 17).
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
DECLARE @WfNew INT;
DECLARE @WfAgenda INT;
DECLARE @WfAttendance INT;
DECLARE @WfTotal INT;
DECLARE @WfUpdated INT;
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

	-- Workflow order (WorkflowOrder-Step23): the meeting's state; the order applies only to a meeting
	-- created after step 23 was installed (fn_WorkflowState.IsNew)
	SELECT @WfNew = IsNew, @WfAgenda = AgendaFinalized, @WfAttendance = AttendanceRecorded,
	       @WfTotal = MinutesTotal, @WfUpdated = MinutesUpdated
	FROM dbo.fn_WorkflowState(@MeetingId);

	-- Attendance-FutureMeeting: only a meeting dated today or earlier (database server date).
	-- MeetingLocks-Step15: not once the minutes are finalized.
	IF (@MinutesStatus IS NOT NULL
	    AND @MeetingDate IS NOT NULL
	    AND CAST(@MeetingDate AS date) <= CAST(GETDATE() AS date)
	    AND @MinutesStatus NOT IN ('F', 'C')
	    -- WorkflowOrder-Step23: not before the agenda is finalized (a meeting created after step 23)
	    AND NOT (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAgenda, 0) = 0))
	BEGIN
		SET @Cnt = (SELECT COUNT(*) FROM Attendance WHERE
			CommitteeId = @CommitteeId AND
			MeetingId = @MeetingId AND
			MemberId = @MemberId);

		SET @Cnt = ISNULL(@Cnt,0);

		-- MeetingLocks-Step16: a new committee-member row only for a member on the committee on the
		-- meeting date. Rows saved earlier can still be edited.
		IF (@Cnt > 0
		    OR @MemberOf <> 'C'
		    OR EXISTS (SELECT 1 FROM Committee_Member cm
		               WHERE cm.CommitteeId = @CommitteeId AND cm.MemberId = @MemberId
		               AND dbo.fn_CommitteeMemberDateCheck(cm.AppointmentDate, cm.CessationDate, @MeetingDate, 'B') = 1))
		BEGIN
			SET @SittingFees = 0;

			IF (@Attendance = 'P')
			BEGIN
				SET @SittingFees = (SELECT ApplicableFee FROM Committee_Member WHERE
					CommitteeId = @CommitteeId AND
					MemberId = @MemberId);
			END

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

-- Meeting chairman (MeetingLocks-Step16): a changed chairman must be on the committee on the meeting date.
-- Kept from step 15 (MeetingLocks-Step15): refused once the minutes are finalized.
-- WorkflowOrder-Step23: a meeting created after step 23 takes a chairman only once its agenda is finalized (Reason 17).
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
DECLARE @MeetingDate DATETIME;
DECLARE @CurrentChairmanId INT;
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
			SAVE TRANSACTION MeetingChairman;

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open'), @MeetingDate = MeetingDate, @CurrentChairmanId = ChairmanNameId
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @MeetingId AND CommitteeId = @CommitteeId;

		-- Workflow order (WorkflowOrder-Step23): the meeting's state; the order applies only to a meeting
		-- created after step 23 was installed (fn_WorkflowState.IsNew)
		SELECT @WfNew = IsNew, @WfAgenda = AgendaFinalized, @WfAttendance = AttendanceRecorded,
		       @WfTotal = MinutesTotal, @WfUpdated = MinutesUpdated
		FROM dbo.fn_WorkflowState(@MeetingId);

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus IN ('F', 'C'))
			SET @Reason = 1;
		-- WorkflowOrder-Step23
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAgenda, 0) = 0)
			SET @Reason = 17;
		ELSE IF NOT EXISTS (SELECT 1 FROM Member WHERE MemberId = @ChairmanNameId)
			SET @Reason = 4;
		ELSE IF (@ChairmanNameId <> ISNULL(@CurrentChairmanId, -1)
		         AND NOT EXISTS (SELECT 1 FROM Committee_Member cm
		                         WHERE cm.CommitteeId = @CommitteeId AND cm.MemberId = @ChairmanNameId
		                         AND dbo.fn_CommitteeMemberDateCheck(cm.AppointmentDate, cm.CessationDate, @MeetingDate, 'B') = 1))
		BEGIN
			SET @Reason = 9;
			SET @Detail = ISNULL((SELECT MemberName FROM Member WHERE MemberId = @ChairmanNameId), '');
		END
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

-- Agenda short text (edited on the minutes page) - refused once the minutes are confirmed (MeetingLocks-Step16)
-- WorkflowOrder-Step23: a meeting created after step 23 needs the agenda finalized (17) and attendance entered (18).
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateAgendaShortText]
@AgendaId INT,
@ShortText VARCHAR(MAX),
@UpdatedBy INT
AS
	DECLARE @ShortTextOld VARCHAR(MAX)
	DECLARE @AgendaNo VARCHAR(50)
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
			SAVE TRANSACTION AgendaShortText;

		SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);

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
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaNo = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgendaId);

			UPDATE Agenda SET
			ShortText = @ShortText
			WHERE
			AgendaId = @AgendaId;

			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
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
			ROLLBACK TRANSACTION AgendaShortText;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Minutes update - refused once the minutes are confirmed (MeetingLocks-Step16). The new action item is
-- mapped to the agenda creator only if that user still exists (FK #5, step 6). An inactive creator gets
-- no new row and the item goes to the active Controllers instead (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- WorkflowOrder-Step23: a meeting created after step 23 needs the agenda finalized (17) and attendance entered (18).
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateMinutes]
@Code VARCHAR(50),
@MinutesId INT,
@DecisionTypeId INT,
@Directions TEXT,
@ActualResolution TEXT,
@ShortText TEXT,
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

PRINT 'Step 23 installed: workflow order (WorkflowOrder-Step23).';
GO

SET NOEXEC OFF;
GO
