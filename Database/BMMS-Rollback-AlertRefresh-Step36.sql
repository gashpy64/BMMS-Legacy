/* ============================================================================
   BMMS - Rollback of step 36 (BMMS-Fix-AlertRefresh-Step36.sql, step AL1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Restores spr_AddEditAgenda with the text of step 31
   (BMMS-Fix-UnicodeText-Step31.sql) and spr_AddEditAgendaByManager and
   spr_AddEditAgendaByController with the text of step 35
   (BMMS-Fix-CommentAuthor-Step35.sql), as installed on BMMS_Test before
   step 36: an Update on Agenda Entry no longer refreshes the alert.
   The alerts already refreshed (ReadStatus 0, StatusId 1) are KEPT; they
   become read again when their recipients open them.

   Changes no data. Safe to re-run, also where step 36 was never installed.
   It needs step 35: run this rollback before any rollback of step 35.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') NOT LIKE '%CommentAuthor-Step35%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') NOT LIKE '%CommentAuthor-Step35%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') NOT LIKE '%UnicodeText-Step31%'
         OR OBJECT_ID('dbo.fn_AgendaChangeRefusal') IS NULL)
BEGIN
    RAISERROR('Step 35 is not installed in "%s" (marker CommentAuthor-Step35 on spr_AddEditAgendaByManager and spr_AddEditAgendaByController, UnicodeText-Step31 on spr_AddEditAgenda), or fn_AgendaChangeRefusal is missing. This rollback restores the texts of steps 31 and 35 over step 35 or step 36 only (BMMS-Check-InstalledSteps.sql shows which steps are installed). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO


-------------------------------------------------------------------------------
-- The two agenda procedures
-------------------------------------------------------------------------------

-- Agenda - add / edit by a user, refused once the agenda is finalized (MeetingLocks-Step16).
-- A new item is refused when the creator's manager is set but inactive (Reason 11); no manager
-- (NULL) was unchanged until step 20 (see below). The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- A new item waits for the manager (AC) only when the manager is active and a Manager; otherwise it goes
-- straight to the Controllers (AMA, manager fields empty) and the active Controllers get the alert;
-- refused when no Controller is active (Reason 15) (AgendaRouting-Step20)
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX); @FilePath
-- VARCHAR(255)); a change of the Proposed Resolution is audited as 'ProposedResolution' (was 'ShortText')
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgenda]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText NVARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText NVARCHAR(MAX),
@AgendaTextPath NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@FilePath NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
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
	DECLARE @ShortTextOld NVARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld NVARCHAR(MAX)
	DECLARE @AgendaTextPathOld NVARCHAR(MAX)
	DECLARE @ProposedResolutionOld NVARCHAR(MAX)
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
	DECLARE @Route CHAR(1);
	DECLARE @ManagerName NVARCHAR(200);
	DECLARE @ActiveControllers INT;
	DECLARE @StatusCode VARCHAR(10);
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
		-- since nobody else can approve it on the Dashboard (UserStatus2b-Step17).
		-- The creator's route (AgendaRouting-Step20): M the manager step (AC); C straight to the Controllers
		-- (AMA): no manager, or the manager is a Controller or has another role; I refused while the manager
		-- is inactive (Reason 11). C with no active Controller is refused (Reason 15): nobody could approve it.
		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SELECT @Route = Route, @ManagerName = ManagerName, @ActiveControllers = ActiveControllers
			FROM dbo.fn_AgendaRoute(@CreatedBy);

			IF (@Route = 'I')
			BEGIN
				SET @Reason = 11;
				SET @Detail = ISNULL(@ManagerName, '');
			END
			ELSE IF (@Route = 'C' AND @ActiveControllers = 0)
				SET @Reason = 15;

			SET @StatusCode = CASE WHEN @Route = 'C' THEN 'AMA' ELSE 'AC' END;
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
			@StatusCode, @CurrentStatus, @CreatedOn, @CreatedBy);

			SET @agenda_id = @@identity

			SET @SourceType = 'Agenda'
			SET @DisplayText = 'Agenda (' + @AgendaNo + ')'

			INSERT INTO Alert_Master
			(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
			VALUES
			(@SourceType, @DepartmentId, @agenda_id, @DisplayText, @StatusCode, 3, @CommitteeId, @CreatedOn, @CreatedBy)

			SET @alert_id = @@identity

			SET @Mgr_Id = (SELECT ManagerId FROM Users WHERE UserId = @CreatedBy)

			-- Route M: the Admins and the manager; route C: the Admins and the active Controllers (AgendaRouting-Step20)
			IF (@Route = 'C')
				INSERT INTO Alert_User_Map
				(AlertId, [UserId], ReadStatus, StatusId)
				(SELECT @alert_id, u.[UserId],0,1 FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
				 WHERE r.RoleCode IN ('admin', 'controller') AND u.AccountStatus = 1 AND u.IsSystem = 0);
			ELSE
				INSERT INTO Alert_User_Map
				(AlertId, [UserId], ReadStatus, StatusId)
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE (RoleId = 1 OR UserId = @Mgr_Id) AND AccountStatus = 1 AND IsSystem = 0);

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
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
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
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX); @FilePath
-- VARCHAR(255)); a change of the Proposed Resolution is audited as 'ProposedResolution' (was 'ShortText')
-- CommentAuthor-Step35: MgrApprovedBy and MgrApprovedDate are the acting user and GETDATE() when the Manager saves a new
-- item (it is saved as approved by the Manager) and, on an edit, only when the text of MgrComments changes
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgendaByManager]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText NVARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText NVARCHAR(MAX),
@AgendaTextPath NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@FilePath NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
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
	DECLARE @ShortTextOld NVARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld NVARCHAR(MAX)
	DECLARE @AgendaTextPathOld NVARCHAR(MAX)
	DECLARE @ProposedResolutionOld NVARCHAR(MAX)
	DECLARE @MgrCommentsOld NVARCHAR(MAX)
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

			-- CommentAuthor-Step35: the new item is saved as approved by the Manager: who and when
			UPDATE Agenda SET MgrApprovedBy = @ActingUserId, MgrApprovedDate = GETDATE() WHERE AgendaId = @agenda_id;

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
				AND AccountStatus = 1 AND IsSystem = 0);

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
			SET @MgrCommentsOld = (SELECT MgrComments FROM Agenda WHERE AgendaId = @AgendaId);   -- CommentAuthor-Step35

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

			-- CommentAuthor-Step35: who and when of the Manager's comment, only when its text changed (an exact comparison:
			-- case and trailing spaces count; NULL and empty text are the same)
			IF (ISNULL(@MgrCommentsOld, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
			    OR DATALENGTH(ISNULL(@MgrCommentsOld, N'')) <> DATALENGTH(ISNULL(@MgrComments, N'')))
				UPDATE Agenda SET MgrApprovedBy = @ActingUserId, MgrApprovedDate = GETDATE() WHERE AgendaId = @AgendaId;

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
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
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
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX); @FilePath
-- VARCHAR(255)); a change of the Proposed Resolution is audited as 'ProposedResolution' (was 'ShortText')
-- CommentAuthor-Step35: ControllerApprovedBy and ControllerApprovedDate are the acting user and GETDATE() when the Controller saves a new
-- item (it is saved as approved by the Controller) and, on an edit, only when the text of ControllerComments changes
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgendaByController]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText NVARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText NVARCHAR(MAX),
@AgendaTextPath NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@FilePath NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
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
	DECLARE @ShortTextOld NVARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld NVARCHAR(MAX)
	DECLARE @AgendaTextPathOld NVARCHAR(MAX)
	DECLARE @ProposedResolutionOld NVARCHAR(MAX)
	DECLARE @ControllerCommentsOld NVARCHAR(MAX)
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

			-- CommentAuthor-Step35: the new item is saved as approved by the Controller: who and when
			UPDATE Agenda SET ControllerApprovedBy = @ActingUserId, ControllerApprovedDate = GETDATE() WHERE AgendaId = @agenda_id;

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
				AND AccountStatus = 1 AND IsSystem = 0);

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
			SET @ControllerCommentsOld = (SELECT ControllerComments FROM Agenda WHERE AgendaId = @AgendaId);   -- CommentAuthor-Step35

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

			-- CommentAuthor-Step35: who and when of the Controller's comment, only when its text changed (an exact comparison:
			-- case and trailing spaces count; NULL and empty text are the same)
			IF (ISNULL(@ControllerCommentsOld, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
			    OR DATALENGTH(ISNULL(@ControllerCommentsOld, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N'')))
				UPDATE Agenda SET ControllerApprovedBy = @ActingUserId, ControllerApprovedDate = GETDATE() WHERE AgendaId = @AgendaId;

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
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
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

DECLARE @Left INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') LIKE '%AlertRefresh-Step36%')
    SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') LIKE '%AlertRefresh-Step36%')
    SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') LIKE '%AlertRefresh-Step36%')
    SET @Left = @Left + 1;

IF (@Left = 0)
    PRINT 'Step 36 rolled back: spr_AddEditAgenda has the text of step 31, spr_AddEditAgendaByManager and spr_AddEditAgendaByController the text of step 35. The alerts already refreshed are kept.';
ELSE
    RAISERROR('Rollback of step 36 is not complete: %d of 3 procedures still carry the marker AlertRefresh-Step36. Read the messages above and run the script again.', 16, 1, @Left);
GO

SET NOEXEC OFF;
GO
