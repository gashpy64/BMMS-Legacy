/* ============================================================================
   BMMS - User status, stage 2b (step 17)
   ----------------------------------------------------------------------------
   Inactive users (Users.AccountStatus 0, step 14) no longer receive new
   workflow alerts, action items or alert mail chosen inside the database:

     1. Every new Alert_User_Map row (committee, meeting and agenda alerts,
        approve / reject) and every new ActionItem_User_Map row goes to
        active users only.
     2. spr_GetAlertMailId (Bcc of the agenda approve / reject mails) returns
        active users only.
     3. A user's new agenda item waits for the user's manager. If ManagerId
        points at an INACTIVE user the item is refused (Reason 11,
        ReasonDetail = the manager's name) before anything is saved; nobody
        else can approve it on the Dashboard. A user with no manager (NULL)
        is unchanged. Editing an existing item is not affected.
     4. An action item created on the Minutes Update page whose agenda
        creator is inactive goes to the active Controllers instead. A creator
        who no longer exists is unchanged (no row, FK #5 of step 6).

   Rows already saved are left as they are: no alert or action-item row of an
   inactive user is deleted or changed. The approve / reject step renews the
   creator's row only while the creator is active. A user activated again
   gets new alerts from then on; nothing missed while inactive is added.
   The last active Admin and the last active Controller cannot be deactivated
   (steps 13 and 14), so the Admin and Controller recipients never run out.

   Reasons of the agenda procedures (step 16) plus:
     11  the creator's manager is inactive (spr_AddEditAgenda, Save only)

   Objects (each carries the text UserStatus2b-Step17)
     spr_AddEditCommittee                    1
     spr_AddEditMeeting                      1 (keeps MeetingLocks-Step16)
     spr_AddEditAgenda                       1 and 3 (keeps MeetingLocks-Step16)
     spr_AddEditAgendaByManager              1 (keeps MeetingLocks-Step16)
     spr_AddEditAgendaByController           1 (keeps MeetingLocks-Step16)
     spr_UpdateAgendaByAgendaId              1 (keeps MeetingLocks-Step16)
     spr_MinutesFinalizeByMeetingId          1 (keeps MeetingLocks-Step15 and the step 8 check)
     spr_UpdateMinutes                       1 and 4 (keeps MeetingLocks-Step16 and FK #5)
     spr_GetAlertMailId                      2

   Replaces procedures of earlier steps: spr_UpdateMinutes (steps 6 and 16),
   spr_MinutesFinalizeByMeetingId (steps 8 and 15), spr_AddEditMeeting,
   spr_AddEditAgenda, spr_AddEditAgendaByManager,
   spr_AddEditAgendaByController and spr_UpdateAgendaByAgendaId (step 16).
   If step 6, 8, 15 or 16 is ever re-run, run this script again afterwards.

   Run it BEFORE deploying the build that shows the Reason 11 message, and
   deploy that build straight after: the older build sends the "agenda
   created" mail first and then shows "Record Not Saved" for Reason 11.

   Changes no data. Safe to re-run. Needs steps 14, 15 and 16 and stops
   otherwise.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%UserStatus-Stage2a%')
BEGIN
    RAISERROR('Step 14 (BMMS-Fix-UserStatus-Stage2a.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeetingMember')), '') NOT LIKE '%MeetingLocks-Step15%')
BEGIN
    RAISERROR('Step 15 (BMMS-Fix-MeetingLocks.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaLockByMeetingId')), '') NOT LIKE '%MeetingLocks-Step16%'
         OR OBJECT_ID('dbo.fn_AgendaChangeRefusal') IS NULL)
BEGIN
    RAISERROR('Step 16 (BMMS-Fix-MeetingLocks-Step16.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Committee - add / edit; the alert goes to active users only (UserStatus2b-Step17)
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
		(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1)

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
		(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1)
	END

END
GO

-- Meeting - add / edit; date and committee locked by attendance, committee by agenda items (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
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
			SAVE TRANSACTION MeetingSave;

		SET @DepartmentId = (SELECT DepartmentId FROM Users WHERE UserId = @CreatedBy);

		IF (@Code = 'Save')
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
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1);

			SET @Result = 1;
		END

		IF (@Code = 'Update')
		BEGIN
			SELECT @Found = 1, @OldMeetingDate = MeetingDate, @OldCommitteeId = CommitteeId
			FROM Meeting WITH (UPDLOCK, HOLDLOCK)
			WHERE MeetingId = @MeetingId;

			-- Dates compared as dates: the page sends the date only
			SET @DateChanged = CASE WHEN @OldMeetingDate IS NULL AND @MeetingDate IS NULL THEN 0
			                        WHEN @OldMeetingDate IS NULL OR @MeetingDate IS NULL THEN 1
			                        WHEN CAST(@OldMeetingDate AS date) <> CAST(@MeetingDate AS date) THEN 1
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
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1);

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

-- Agenda - add / edit by a user, refused once the agenda is finalized (MeetingLocks-Step16).
-- A new item is refused when the creator's manager is set but inactive (Reason 11); no manager
-- (NULL) is unchanged. The alert goes to active users only (UserStatus2b-Step17)
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgenda]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText VARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText VARCHAR(MAX),
@AgendaTextPath VARCHAR(MAX),
@ProposedResolution VARCHAR(MAX),
@FilePath VARCHAR(255),
@MgrComments VARCHAR(MAX),
@ControllerComments VARCHAR(MAX),
@CurrentStatus VARCHAR(50),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@SubjectNo INT,
@ActingUserId INT)
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @agenda_id INT
	DECLARE @Mgr_Id INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @SubjectTypeName VARCHAR(50)
	DECLARE @SubjectTypeNameOld VARCHAR(50)
	DECLARE @SubjectTypeIdOld INT
	DECLARE @ShortTextOld VARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld VARCHAR(MAX)
	DECLARE @AgendaTextPathOld VARCHAR(MAX)
	DECLARE @ProposedResolutionOld VARCHAR(MAX)
	DECLARE @MinutesId INT
	DECLARE @NextAgendaNo AS VARCHAR(50);
	DECLARE @Prefix1 AS VARCHAR(50);
	DECLARE @Prefix2 AS VARCHAR(50);
	DECLARE @Prefix AS VARCHAR(50);
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @Locked INT;
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
			SAVE TRANSACTION AgendaSave;

		-- An edit stays on the meeting of the existing row
		IF (@Code = 'Update')
			SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 0);

		-- The new item waits for the creator's manager (AC): refused while that manager is inactive,
		-- since nobody else can approve it on the Dashboard. No manager (NULL) is unchanged (UserStatus2b-Step17)
		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SET @Mgr_Id = (SELECT ManagerId FROM Users WHERE UserId = @CreatedBy);

			IF (@Mgr_Id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @Mgr_Id AND AccountStatus = 1))
			BEGIN
				SET @Reason = 11;
				SET @Detail = ISNULL((SELECT UserName FROM Users WHERE UserId = @Mgr_Id), '');
			END
		END

		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SET @Prefix1 = (SELECT CommitteeCode FROM Committee WHERE CommitteeId = @CommitteeId)
			SET @Prefix2 = (SELECT MeetingNo FROM Meeting WHERE MeetingId = @MeetingId)
			SET @Prefix = @Prefix1 + '-' + @Prefix2 + '-';

			SET @NextAgendaNo = (SELECT MAX(AgendaNo) FROM Agenda
						WHERE MeetingId = @MeetingId);

			SET @AgendaNo = SUBSTRING(ISNULL(@NextAgendaNo,0),11,13);
			SET @AgendaNo = @AgendaNo + 1;

			IF (@AgendaNo <= 0)
			BEGIN
				SET @NextAgendaNo = @Prefix + '001';
			END
			IF (@AgendaNo >= 1 AND @AgendaNo <= 9)
			BEGIN
				SET @NextAgendaNo = @Prefix + '00' + CONVERT(VARCHAR(50),@AgendaNo);
			END
			IF (@AgendaNo >= 10 AND @AgendaNo <= 99)
			BEGIN
				SET @NextAgendaNo = @Prefix + '0' + CONVERT(VARCHAR(50),@AgendaNo);
			END

			SET @AgendaNo = @NextAgendaNo;

			INSERT INTO Agenda
			(AgendaNo, CommitteeId, MeetingId, DepartmentId,
			SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath,
			AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
			VALUES
			(@AgendaNo, @CommitteeId, @MeetingId, @DepartmentId,
			@SubjectTypeId, @ShortText, @AgendaType, @AgendaText, @AgendaTextPath, @ProposedResolution, @FilePath,
			'AC', @CurrentStatus, @CreatedOn, @CreatedBy);

			SET @agenda_id = @@identity

			SET @SourceType = 'Agenda'
			SET @DisplayText = 'Agenda (' + @AgendaNo + ')'

			INSERT INTO Alert_Master
			(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
			VALUES
			(@SourceType, @DepartmentId, @agenda_id, @DisplayText, 'AC', 3, @CommitteeId, @CreatedOn, @CreatedBy)

			SET @alert_id = @@identity

			SET @Mgr_Id = (SELECT ManagerId FROM Users WHERE UserId = @CreatedBy)

			INSERT INTO Alert_User_Map
			(AlertId, [UserId], ReadStatus, StatusId)
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE (RoleId = 1 OR UserId = @Mgr_Id) AND AccountStatus = 1);

			SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);

			INSERT INTO [Audit_Trail_Master]
	           ([Audit_Type], [Audit_Table], [Key_Field], [Key_Value], [Field_Name],
				[Old_Value], [New_Value], [Update_By], [Update_On])
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', '', @SubjectTypeName, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', '', @ShortText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', '', @AgendaType, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', '', @AgendaText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', '', @AgendaTextPath, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', '', @ProposedResolution, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'FilePath', '', @FilePath, @UpdatedBy, GETDATE();

			SET @Result = 1;
		END

		IF (@Reason = 0 AND @Code = 'Update')
		BEGIN
			SET @SubjectTypeIdOld = (SELECT SubjectTypeId FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTypeOld = (SELECT AgendaType FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextOld = (SELECT AgendaText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextPathOld = (SELECT AgendaTextPath FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ProposedResolutionOld = (SELECT ProposedResolution FROM Agenda WHERE AgendaId = @AgendaId);

			UPDATE Agenda SET
			SubjectTypeId = @SubjectTypeId,
			ShortText = @ShortText,
			AgendaType = @AgendaType,
			AgendaText = @AgendaText,
			AgendaTextPath = @AgendaTextPath,
			ProposedResolution = @ProposedResolution,
			FilePath = @FilePath,
			MgrComments = @MgrComments,
			ControllerComments = @ControllerComments,
			CurrentStatus = @CurrentStatus,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy,
			SubjectNo = @SubjectNo
			WHERE
			AgendaId = @AgendaId;

			SET @MinutesId = 0;
			SET @MinutesId = (SELECT MinutesId FROM View_Minute WHERE AgendaId = @AgendaId);

			UPDATE Minutes SET
			ActualResolution = @ProposedResolution
			WHERE MinutesId = @MinutesId;

			IF (@SubjectTypeIdOld != @SubjectTypeId)
			BEGIN
				SET @SubjectTypeNameOld = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeIdOld);
				SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', @SubjectTypeNameOld, @SubjectTypeName, @UpdatedBy, GETDATE());
			END
			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTypeOld != @AgendaType)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', @AgendaTypeOld, @AgendaType, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextOld != @AgendaText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', @AgendaTextOld, @AgendaText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextPathOld != @AgendaTextPath)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', @AgendaTextPathOld, @AgendaTextPath, @UpdatedBy, GETDATE());
			END
			IF (@ProposedResolutionOld != @ProposedResolution)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
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
			ROLLBACK TRANSACTION AgendaSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Agenda - add / edit by a manager, refused once the agenda is finalized (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgendaByManager]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText VARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText VARCHAR(MAX),
@AgendaTextPath VARCHAR(MAX),
@ProposedResolution VARCHAR(MAX),
@FilePath VARCHAR(255),
@MgrComments VARCHAR(MAX),
@ControllerComments VARCHAR(MAX),
@CurrentStatus VARCHAR(50),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@SubjectNo INT,
@ActingUserId INT)
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @agenda_id INT
	DECLARE @Mgr_Id INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @SubNo INT
	DECLARE @SubjectTypeName VARCHAR(50)
	DECLARE @SubjectTypeNameOld VARCHAR(50)
	DECLARE @SubjectTypeIdOld INT
	DECLARE @ShortTextOld VARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld VARCHAR(MAX)
	DECLARE @AgendaTextPathOld VARCHAR(MAX)
	DECLARE @ProposedResolutionOld VARCHAR(MAX)
	DECLARE @MinutesId INT
	DECLARE @NextAgendaNo AS VARCHAR(50);
	DECLARE @Prefix1 AS VARCHAR(50);
	DECLARE @Prefix2 AS VARCHAR(50);
	DECLARE @Prefix AS VARCHAR(50);
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @Locked INT;
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
			SAVE TRANSACTION AgendaSaveManager;

		IF (@Code = 'Update')
			SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 0);

		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SET @Prefix1 = (SELECT CommitteeCode FROM Committee WHERE CommitteeId = @CommitteeId)
			SET @Prefix2 = (SELECT MeetingNo FROM Meeting WHERE MeetingId = @MeetingId)
			SET @Prefix = @Prefix1 + '-' + @Prefix2 + '-';

			SET @NextAgendaNo = (SELECT MAX(AgendaNo) FROM Agenda
						WHERE MeetingId = @MeetingId);

			SET @AgendaNo = SUBSTRING(ISNULL(@NextAgendaNo,0),11,13);
			SET @AgendaNo = @AgendaNo + 1;

			IF (@AgendaNo <= 0)
			BEGIN
				SET @NextAgendaNo = @Prefix + '001';
			END
			IF (@AgendaNo >= 1 AND @AgendaNo <= 9)
			BEGIN
				SET @NextAgendaNo = @Prefix + '00' + CONVERT(VARCHAR(50),@AgendaNo);
			END
			IF (@AgendaNo >= 10 AND @AgendaNo <= 99)
			BEGIN
				SET @NextAgendaNo = @Prefix + '0' + CONVERT(VARCHAR(50),@AgendaNo);
			END

			SET @AgendaNo = @NextAgendaNo;

			INSERT INTO Agenda
			(AgendaNo, CommitteeId, MeetingId, DepartmentId,
			SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath,
			AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, MgrComments, MgrApprovedStatus)
			VALUES
			(@AgendaNo, @CommitteeId, @MeetingId, @DepartmentId,
			@SubjectTypeId, @ShortText, @AgendaType, @AgendaText, @AgendaTextPath, @ProposedResolution, @FilePath,
			'AMA', @CurrentStatus, @CreatedOn, @CreatedBy, @MgrComments, 'Approved');

			SET @agenda_id = @@identity

			SET @SourceType = 'Agenda'
			SET @DisplayText = 'Agenda (' + @AgendaNo + ')'

			INSERT INTO Alert_Master
			(SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
			VALUES
			(@SourceType, @agenda_id, @DepartmentId, @DisplayText, 'AMA', 3, @CommitteeId, @CreatedOn, @CreatedBy)

			SET @alert_id = @@identity

			INSERT INTO Alert_User_Map
			(AlertId, [UserId], ReadStatus, StatusId)
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE (RoleId = 1 OR RoleId = 2 OR
				UserId IN (SELECT Users.UserId FROM Users WHERE Users.DepartmentId = @DepartmentId))
				AND AccountStatus = 1);

			SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);

			INSERT INTO [Audit_Trail_Master]
	           ([Audit_Type], [Audit_Table], [Key_Field], [Key_Value], [Field_Name],
				[Old_Value], [New_Value], [Update_By], [Update_On])
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', '', @SubjectTypeName, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', '', @ShortText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', '', @AgendaType, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', '', @AgendaText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', '', @AgendaTextPath, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', '', @ProposedResolution, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'FilePath', '', @FilePath, @UpdatedBy, GETDATE();

			SET @Result = 1;
		END

		IF (@Reason = 0 AND @Code = 'Update')
		BEGIN
			SET @SubjectTypeIdOld = (SELECT SubjectTypeId FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTypeOld = (SELECT AgendaType FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextOld = (SELECT AgendaText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextPathOld = (SELECT AgendaTextPath FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ProposedResolutionOld = (SELECT ProposedResolution FROM Agenda WHERE AgendaId = @AgendaId);

			UPDATE Agenda SET
			SubjectTypeId = @SubjectTypeId,
			ShortText = @ShortText,
			AgendaType = @AgendaType,
			AgendaText = @AgendaText,
			AgendaTextPath = @AgendaTextPath,
			ProposedResolution = @ProposedResolution,
			FilePath = @FilePath,
			MgrComments = @MgrComments,
			ControllerComments = @ControllerComments,
			CurrentStatus = @CurrentStatus,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy,
			SubjectNo = @SubjectNo
			WHERE
			AgendaId = @AgendaId;

			SET @MinutesId = 0;
			SET @MinutesId = (SELECT MinutesId FROM View_Minute WHERE AgendaId = @AgendaId);

			UPDATE Minutes SET
			ActualResolution = @ProposedResolution
			WHERE MinutesId = @MinutesId;

			IF (@SubjectTypeIdOld != @SubjectTypeId)
			BEGIN
				SET @SubjectTypeNameOld = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeIdOld);
				SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', @SubjectTypeNameOld, @SubjectTypeName, @UpdatedBy, GETDATE());
			END
			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTypeOld != @AgendaType)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', @AgendaTypeOld, @AgendaType, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextOld != @AgendaText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', @AgendaTextOld, @AgendaText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextPathOld != @AgendaTextPath)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', @AgendaTextPathOld, @AgendaTextPath, @UpdatedBy, GETDATE());
			END
			IF (@ProposedResolutionOld != @ProposedResolution)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
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
			ROLLBACK TRANSACTION AgendaSaveManager;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Agenda - add / edit by the Controller; after the agenda is finalized only with the Admin option on (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgendaByController]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText VARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText VARCHAR(MAX),
@AgendaTextPath VARCHAR(MAX),
@ProposedResolution VARCHAR(MAX),
@FilePath VARCHAR(255),
@MgrComments VARCHAR(MAX),
@ControllerComments VARCHAR(MAX),
@CurrentStatus VARCHAR(50),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@SubjectNo INT,
@ActingUserId INT)
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @agenda_id INT
	DECLARE @Mgr_Id INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @SubNo INT
	DECLARE @SubjectTypeName VARCHAR(50)
	DECLARE @SubjectTypeNameOld VARCHAR(50)
	DECLARE @SubjectTypeIdOld INT
	DECLARE @ShortTextOld VARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld VARCHAR(MAX)
	DECLARE @AgendaTextPathOld VARCHAR(MAX)
	DECLARE @ProposedResolutionOld VARCHAR(MAX)
	DECLARE @AgendaStatus VARCHAR(50)
	DECLARE @MinutesId INT
	DECLARE @NextAgendaNo AS VARCHAR(50);
	DECLARE @Prefix1 AS VARCHAR(50);
	DECLARE @Prefix2 AS VARCHAR(50);
	DECLARE @Prefix AS VARCHAR(50);
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @Locked INT;
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
			SAVE TRANSACTION AgendaSaveController;

		IF (@Code = 'Update')
			SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 1);

		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SET @Prefix1 = (SELECT CommitteeCode FROM Committee WHERE CommitteeId = @CommitteeId)
			SET @Prefix2 = (SELECT MeetingNo FROM Meeting WHERE MeetingId = @MeetingId)
			SET @Prefix = @Prefix1 + '-' + @Prefix2 + '-';

			SET @NextAgendaNo = (SELECT MAX(AgendaNo) FROM Agenda
						WHERE MeetingId = @MeetingId);

			SET @AgendaNo = SUBSTRING(ISNULL(@NextAgendaNo,0),11,13);
			SET @AgendaNo = @AgendaNo + 1;

			IF (@AgendaNo <= 0)
			BEGIN
				SET @NextAgendaNo = @Prefix + '001';
			END
			IF (@AgendaNo >= 1 AND @AgendaNo <= 9)
			BEGIN
				SET @NextAgendaNo = @Prefix + '00' + CONVERT(VARCHAR(50),@AgendaNo);
			END
			IF (@AgendaNo >= 10 AND @AgendaNo <= 99)
			BEGIN
				SET @NextAgendaNo = @Prefix + '0' + CONVERT(VARCHAR(50),@AgendaNo);
			END

			SET @AgendaNo = @NextAgendaNo;

			INSERT INTO Agenda
			(AgendaNo, CommitteeId, MeetingId, DepartmentId,
			SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath,
			AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, ControllerComments, ControllerApprovedStatus)
			VALUES
			(@AgendaNo, @CommitteeId, @MeetingId, @DepartmentId,
			@SubjectTypeId, @ShortText, @AgendaType, @AgendaText, @AgendaTextPath, @ProposedResolution, @FilePath,
			'ACA', @CurrentStatus, @CreatedOn, @CreatedBy, @ControllerComments, 'Approved');

			SET @agenda_id = @@identity

			SET @SourceType = 'Agenda'
			SET @DisplayText = 'Agenda (' + @AgendaNo + ')'

			INSERT INTO Alert_Master
			(SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
			VALUES
			(@SourceType, @agenda_id, @DepartmentId, @DisplayText, 'ACA', 3, @CommitteeId, @CreatedOn, @CreatedBy)

			SET @alert_id = @@identity

			INSERT INTO Alert_User_Map
			(AlertId, [UserId], ReadStatus, StatusId)
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE (RoleId = 1 OR
				UserId IN (SELECT Users.UserId FROM Users WHERE Users.DepartmentId = @DepartmentId))
				AND AccountStatus = 1);

			SET @SubNo = (SELECT MAX(SubjectNo) FROM Agenda WHERE MeetingId = @MeetingId
								AND ControllerApprovedStatus = 'Approved');
			SET @SubNo = ISNULL(@SubNo,0);
			SET @SubNo = @SubNo + 1;

			UPDATE Agenda SET
			SubjectNo = @SubNo
			WHERE MeetingId = @MeetingId
			AND ControllerApprovedStatus = 'Approved'
			AND AgendaId = @agenda_id;

			-- An agenda added after the agenda was finalized gets its Minutes row here
			SET @AgendaStatus = (SELECT AgendaStatus FROM Meeting WHERE MeetingId = @MeetingId);

			IF (@AgendaStatus = 'Close')
			BEGIN
				INSERT INTO Minutes
				(
				AgendaId, DecisionTypeId, Directions, ActualResolution,
				CreatedOn, CreatedBy, UpdatedOn, UpdatedBy
				)
				VALUES
				(@agenda_id, 3, ' ', @ProposedResolution, GETDATE(), 1, GETDATE(), 1);
			END

			SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);

			INSERT INTO [Audit_Trail_Master]
	           ([Audit_Type], [Audit_Table], [Key_Field], [Key_Value], [Field_Name],
				[Old_Value], [New_Value], [Update_By], [Update_On])
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', '', @SubjectTypeName, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', '', @ShortText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', '', @AgendaType, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', '', @AgendaText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', '', @AgendaTextPath, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', '', @ProposedResolution, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'FilePath', '', @FilePath, @UpdatedBy, GETDATE();

			SET @Result = 1;
		END

		IF (@Reason = 0 AND @Code = 'Update')
		BEGIN
			SET @SubjectTypeIdOld = (SELECT SubjectTypeId FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTypeOld = (SELECT AgendaType FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextOld = (SELECT AgendaText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextPathOld = (SELECT AgendaTextPath FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ProposedResolutionOld = (SELECT ProposedResolution FROM Agenda WHERE AgendaId = @AgendaId);

			UPDATE Agenda SET
			DepartmentId = @DepartmentId,
			SubjectTypeId = @SubjectTypeId,
			ShortText = @ShortText,
			AgendaType = @AgendaType,
			AgendaText = @AgendaText,
			AgendaTextPath = @AgendaTextPath,
			ProposedResolution = @ProposedResolution,
			FilePath = @FilePath,
			MgrComments = @MgrComments,
			ControllerComments = @ControllerComments,
			CurrentStatus = @CurrentStatus,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy,
			SubjectNo = @SubjectNo
			WHERE
			AgendaId = @AgendaId;

			SET @MinutesId = 0;
			SET @MinutesId = (SELECT MinutesId FROM View_Minute WHERE AgendaId = @AgendaId);

			UPDATE Minutes SET
			ActualResolution = @ProposedResolution
			WHERE MinutesId = @MinutesId;

			IF (@SubjectTypeIdOld != @SubjectTypeId)
			BEGIN
				SET @SubjectTypeNameOld = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeIdOld);
				SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', @SubjectTypeNameOld, @SubjectTypeName, @UpdatedBy, GETDATE());
			END
			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTypeOld != @AgendaType)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', @AgendaTypeOld, @AgendaType, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextOld != @AgendaText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', @AgendaTextOld, @AgendaText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextPathOld != @AgendaTextPath)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', @AgendaTextPathOld, @AgendaTextPath, @UpdatedBy, GETDATE());
			END
			IF (@ProposedResolutionOld != @ProposedResolution)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
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
			ROLLBACK TRANSACTION AgendaSaveController;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Agenda - manager / controller approve or reject; refused once the agenda is finalized,
-- for every role: no Minutes row would be created for it (MeetingLocks-Step16). New alert rows go to
-- active users only; an inactive creator's saved row is left as it is (UserStatus2b-Step17)
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateAgendaByAgendaId]
@AgendaId INT,
@ShortText VARCHAR(MAX),
@ProposedResolution VARCHAR(MAX),
@MgrComments VARCHAR(MAX),
@ControllerComments VARCHAR(MAX),
@ControllerApprovedStatus varchar(50),
@MgrApprovedStatus varchar(50),
@UpdatedBy INT
AS
	DECLARE @AlertId INT
	DECLARE @User_Id INT
	DECLARE @MgrCommentsOld VARCHAR(MAX)
	DECLARE @ControllerCommentsOld VARCHAR(MAX)
	DECLARE @AgendaNo VARCHAR(50)
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
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
			SAVE TRANSACTION AgendaApprove;

		SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);

		SELECT @AgendaStatus = ISNULL(AgendaStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		IF (@AgendaStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@AgendaStatus <> 'Open')
		BEGIN
			SET @Reason = 5;
			SET @Detail = 'Finalized';
		END
		ELSE
		BEGIN
			SET @AgendaNo = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgendaId);

			IF @MgrApprovedStatus = 'Rejected'
			BEGIN
				UPDATE Agenda SET MgrComments = @MgrComments, MgrApprovedStatus = @MgrApprovedStatus,
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				UPDATE Alert_Master SET AlertTypeCode = 'AMR' WHERE AlertId = @AlertId;
				UPDATE Agenda SET AgendaStatusCode = 'AMR' WHERE AgendaId = @AgendaId;
				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;

				INSERT INTO Alert_User_Map
					(AlertId, [UserId], ReadStatus, StatusId)
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1);

				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'MgrComments', '', @MgrComments, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'MgrApprovedStatus', '', @MgrApprovedStatus, @UpdatedBy, GETDATE();
			END

			IF @MgrApprovedStatus = 'Approved'
			BEGIN
				UPDATE Agenda SET MgrComments = @MgrComments, MgrApprovedStatus = @MgrApprovedStatus,
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				UPDATE Alert_Master SET AlertTypeCode = 'AMA' WHERE AlertId = @AlertId;
				UPDATE Agenda SET AgendaStatusCode = 'AMA' WHERE AgendaId = @AgendaId;
				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;

				INSERT INTO Alert_User_Map
					(AlertId, [UserId], ReadStatus, StatusId)
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1);

				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'MgrComments', '', @MgrComments, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'MgrApprovedStatus', '', @MgrApprovedStatus, @UpdatedBy, GETDATE();
			END

			IF @ControllerApprovedStatus = 'Approved' OR @ControllerApprovedStatus = 'Rejected'
			BEGIN
				UPDATE Agenda SET
					ShortText = @ShortText, ProposedResolution = @ProposedResolution,
					ControllerComments = @ControllerComments, ControllerApprovedStatus = @ControllerApprovedStatus,
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				IF @ControllerApprovedStatus = 'Approved'
				BEGIN
					UPDATE Alert_Master SET AlertTypeCode = 'ACA' WHERE AlertId = @AlertId;
					UPDATE Agenda SET AgendaStatusCode = 'ACA' WHERE AgendaId = @AgendaId;
				END
				IF @ControllerApprovedStatus = 'Rejected'
				BEGIN
					UPDATE Alert_Master SET AlertTypeCode = 'ACR' WHERE AlertId = @AlertId;
					UPDATE Agenda SET AgendaStatusCode = 'ACR' WHERE AgendaId = @AgendaId;
				END

				-- The creator's row is renewed only while the creator is active (UserStatus2b-Step17)
				IF EXISTS (SELECT 1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1)
				BEGIN
					DELETE FROM Alert_User_Map WHERE UserId = @User_Id AND AlertId = @AlertId;

					INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
						VALUES (@AlertId, @User_Id, 0, 1);
				END

				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;
				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ControllerApprovedStatus', '', @ControllerApprovedStatus, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ControllerComments', '', @ControllerComments, @UpdatedBy, GETDATE();
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
			ROLLBACK TRANSACTION AgendaApprove;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO


-- Minutes finalize - only from MinutesStatus 'Open' (MeetingLocks-Step15). Action items are
-- not duplicated and users are mapped only to this meeting's items (MinutesFinalize fix, step 8).
-- Only active users are mapped; rows already saved are kept (UserStatus2b-Step17)
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
					WHERE a.AccountStatus = 1 AND
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

-- Minutes update - refused once the minutes are confirmed (MeetingLocks-Step16). The new action item is
-- mapped to the agenda creator only if that user still exists (FK #5, step 6). An inactive creator gets
-- no new row and the item goes to the active Controllers instead (UserStatus2b-Step17)
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

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus = 'C')
			SET @Reason = 7;
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
						WHERE UserId = @UserId AND AccountStatus = 1;

						-- Creator inactive: the active Controllers see the item (UserStatus2b-Step17).
						-- A creator who no longer exists is unchanged (no row, FK #5).
						IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UserId AND AccountStatus <> 1)
							INSERT INTO ActionItem_User_Map
								(ActionItemId, UserId, ReadStatus, StatusId)
							SELECT @ActionItemId, u.UserId, 0, 1
							FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
							WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1;
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

-- Agenda alert mail addresses (Bcc of the approve / reject mails): active users only (UserStatus2b-Step17)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAlertMailId]
@Code varchar(50),
@UserId INT,
@AgendaId INT
AS
	DECLARE @AlertId INT
	DECLARE @User_Id INT
BEGIN

IF @Code = 'AMR'
BEGIN
	
    SELECT EmailId FROM Users WHERE UserId IN (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId) AND AccountStatus = 1;

END

IF @Code = 'AMA'
BEGIN

	SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

	SELECT EmailId FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1;

END

IF @Code = 'ACA' OR @Code = 'ACR'
BEGIN

	SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
	SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

	SELECT EmailId FROM Users WHERE UserId IN
		(SELECT UserId FROM Alert_User_Map WHERE AlertId = @AlertId) AND AccountStatus = 1;

END

	
END
GO

DECLARE @Installed INT = (SELECT COUNT(*) FROM sys.sql_modules
    WHERE definition LIKE '%UserStatus2b-Step17%'
    AND object_id IN (OBJECT_ID('dbo.spr_AddEditCommittee'), OBJECT_ID('dbo.spr_AddEditMeeting'),
                      OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'),
                      OBJECT_ID('dbo.spr_AddEditAgendaByController'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'),
                      OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId'), OBJECT_ID('dbo.spr_UpdateMinutes'),
                      OBJECT_ID('dbo.spr_GetAlertMailId')));

IF (@Installed = 9)
    PRINT 'User status stage 2b (step 17) installed: 9 objects.';
ELSE
    PRINT 'User status stage 2b (step 17): only ' + CAST(@Installed AS VARCHAR(4)) + ' of 9 objects carry the marker. Check the messages above.';
GO

SET NOEXEC OFF;
GO
