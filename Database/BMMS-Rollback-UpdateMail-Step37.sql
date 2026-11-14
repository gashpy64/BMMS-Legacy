/* ============================================================================
   BMMS - Rollback of step 37 (BMMS-Fix-UpdateMail-Step37.sql, step ML1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Restores spr_AddEditAgenda, spr_AddEditAgendaByManager and
   spr_AddEditAgendaByController with the text of step 36
   (BMMS-Fix-AlertRefresh-Step36.sql), as installed on BMMS_Test before
   step 37 (no @ChangedFields parameter), drops spr_GetAgendaUpdateMailId
   and deletes the App_Setting row MailSenderUserId. The alert refresh of
   step 36 stays.

   Roll back the build first (or at the same time): with step 37 rolled
   back, the step ML1 build saves an Update as before and shows "the mail
   could not be sent" (the error log names step 37).

   Changes no other data. Safe to re-run, also where step 37 was never
   installed. It needs step 36: run this rollback before any rollback of
   step 36.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') NOT LIKE '%AlertRefresh-Step36%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') NOT LIKE '%AlertRefresh-Step36%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') NOT LIKE '%AlertRefresh-Step36%')
BEGIN
    RAISERROR('Step 36 is not installed in "%s" (marker AlertRefresh-Step36 on the three agenda procedures). This rollback restores the step 36 texts over step 36 or step 37 only (BMMS-Check-InstalledSteps.sql shows which steps are installed). Nothing was changed.', 16, 1, @CurrentDatabase);
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
-- AlertRefresh-Step36: an Update that changes a saved field marks the item's alert unread again (ReadStatus 0)
-- and shown again (StatusId 1) for every recipient except the acting user; no alert row is added, and
-- Alert_Master (CreatedOn, AlertTypeCode) is not changed. Text is compared exactly (case and trailing spaces
-- count; NULL and empty text are the same); for a number a change from NULL or to NULL counts
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
	DECLARE @RfSubjectTypeId INT;   -- AlertRefresh-Step36: the saved values before an Update
	DECLARE @RfShortText NVARCHAR(MAX);
	DECLARE @RfAgendaType VARCHAR(50);
	DECLARE @RfAgendaText NVARCHAR(MAX);
	DECLARE @RfAgendaTextPath NVARCHAR(MAX);
	DECLARE @RfProposedResolution NVARCHAR(MAX);
	DECLARE @RfFilePath NVARCHAR(MAX);
	DECLARE @RfMgrComments NVARCHAR(MAX);
	DECLARE @RfControllerComments NVARCHAR(MAX);
	DECLARE @RfSubjectNo INT;
	DECLARE @RfChanged INT;
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
			-- AlertRefresh-Step36: the saved values, to see below whether this Update changes anything
			SELECT @RfSubjectTypeId = SubjectTypeId, @RfShortText = ShortText, @RfAgendaType = AgendaType,
			       @RfAgendaText = AgendaText, @RfAgendaTextPath = AgendaTextPath, @RfProposedResolution = ProposedResolution,
			       @RfFilePath = FilePath, @RfMgrComments = MgrComments, @RfControllerComments = ControllerComments,
			       @RfSubjectNo = SubjectNo
			FROM Agenda WHERE AgendaId = @AgendaId;

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

			-- AlertRefresh-Step36: a change marks the item's alert unread again, and shown again if it was removed, for
			-- every recipient except the acting user; an Update that changes nothing leaves the alert as it is
			SET @RfChanged = CASE
				WHEN @RfSubjectTypeId <> @SubjectTypeId OR (@RfSubjectTypeId IS NULL AND @SubjectTypeId IS NOT NULL) OR (@RfSubjectTypeId IS NOT NULL AND @SubjectTypeId IS NULL) THEN 1
				WHEN @RfSubjectNo <> @SubjectNo OR (@RfSubjectNo IS NULL AND @SubjectNo IS NOT NULL) OR (@RfSubjectNo IS NOT NULL AND @SubjectNo IS NULL) THEN 1
				WHEN ISNULL(@RfShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ShortText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfShortText, N'')) <> DATALENGTH(ISNULL(@ShortText, N'')) THEN 1
				WHEN ISNULL(@RfAgendaType, '') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaType, '') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaType, '')) <> DATALENGTH(ISNULL(@AgendaType, '')) THEN 1
				WHEN ISNULL(@RfAgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaText, N'')) <> DATALENGTH(ISNULL(@AgendaText, N'')) THEN 1
				WHEN ISNULL(@RfAgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaTextPath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) <> DATALENGTH(ISNULL(@AgendaTextPath, N'')) THEN 1
				WHEN ISNULL(@RfProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ProposedResolution, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfProposedResolution, N'')) <> DATALENGTH(ISNULL(@ProposedResolution, N'')) THEN 1
				WHEN ISNULL(@RfFilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@FilePath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfFilePath, N'')) <> DATALENGTH(ISNULL(@FilePath, N'')) THEN 1
				WHEN ISNULL(@RfMgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfMgrComments, N'')) <> DATALENGTH(ISNULL(@MgrComments, N'')) THEN 1
				WHEN ISNULL(@RfControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfControllerComments, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N'')) THEN 1
				ELSE 0 END;

			IF (@RfChanged = 1)
				UPDATE m SET ReadStatus = 0, StatusId = 1
				FROM Alert_User_Map m
				JOIN Alert_Master am ON am.AlertId = m.AlertId
				WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgendaId
				  AND m.UserId <> @ActingUserId;

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
-- AlertRefresh-Step36: an Update that changes a saved field marks the item's alert unread again (ReadStatus 0)
-- and shown again (StatusId 1) for every recipient except the acting user; no alert row is added, and
-- Alert_Master (CreatedOn, AlertTypeCode) is not changed. Text is compared exactly (case and trailing spaces
-- count; NULL and empty text are the same); for a number a change from NULL or to NULL counts
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
	DECLARE @RfSubjectTypeId INT;   -- AlertRefresh-Step36: the saved values before an Update
	DECLARE @RfShortText NVARCHAR(MAX);
	DECLARE @RfAgendaType VARCHAR(50);
	DECLARE @RfAgendaText NVARCHAR(MAX);
	DECLARE @RfAgendaTextPath NVARCHAR(MAX);
	DECLARE @RfProposedResolution NVARCHAR(MAX);
	DECLARE @RfFilePath NVARCHAR(MAX);
	DECLARE @RfMgrComments NVARCHAR(MAX);
	DECLARE @RfControllerComments NVARCHAR(MAX);
	DECLARE @RfSubjectNo INT;
	DECLARE @RfChanged INT;
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
			-- AlertRefresh-Step36: the saved values, to see below whether this Update changes anything
			SELECT @RfSubjectTypeId = SubjectTypeId, @RfShortText = ShortText, @RfAgendaType = AgendaType,
			       @RfAgendaText = AgendaText, @RfAgendaTextPath = AgendaTextPath, @RfProposedResolution = ProposedResolution,
			       @RfFilePath = FilePath, @RfMgrComments = MgrComments, @RfControllerComments = ControllerComments,
			       @RfSubjectNo = SubjectNo
			FROM Agenda WHERE AgendaId = @AgendaId;

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

			-- AlertRefresh-Step36: a change marks the item's alert unread again, and shown again if it was removed, for
			-- every recipient except the acting user; an Update that changes nothing leaves the alert as it is
			SET @RfChanged = CASE
				WHEN @RfSubjectTypeId <> @SubjectTypeId OR (@RfSubjectTypeId IS NULL AND @SubjectTypeId IS NOT NULL) OR (@RfSubjectTypeId IS NOT NULL AND @SubjectTypeId IS NULL) THEN 1
				WHEN @RfSubjectNo <> @SubjectNo OR (@RfSubjectNo IS NULL AND @SubjectNo IS NOT NULL) OR (@RfSubjectNo IS NOT NULL AND @SubjectNo IS NULL) THEN 1
				WHEN ISNULL(@RfShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ShortText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfShortText, N'')) <> DATALENGTH(ISNULL(@ShortText, N'')) THEN 1
				WHEN ISNULL(@RfAgendaType, '') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaType, '') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaType, '')) <> DATALENGTH(ISNULL(@AgendaType, '')) THEN 1
				WHEN ISNULL(@RfAgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaText, N'')) <> DATALENGTH(ISNULL(@AgendaText, N'')) THEN 1
				WHEN ISNULL(@RfAgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaTextPath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) <> DATALENGTH(ISNULL(@AgendaTextPath, N'')) THEN 1
				WHEN ISNULL(@RfProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ProposedResolution, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfProposedResolution, N'')) <> DATALENGTH(ISNULL(@ProposedResolution, N'')) THEN 1
				WHEN ISNULL(@RfFilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@FilePath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfFilePath, N'')) <> DATALENGTH(ISNULL(@FilePath, N'')) THEN 1
				WHEN ISNULL(@RfMgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfMgrComments, N'')) <> DATALENGTH(ISNULL(@MgrComments, N'')) THEN 1
				WHEN ISNULL(@RfControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfControllerComments, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N'')) THEN 1
				ELSE 0 END;

			IF (@RfChanged = 1)
				UPDATE m SET ReadStatus = 0, StatusId = 1
				FROM Alert_User_Map m
				JOIN Alert_Master am ON am.AlertId = m.AlertId
				WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgendaId
				  AND m.UserId <> @ActingUserId;

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
-- AlertRefresh-Step36: an Update that changes a saved field marks the item's alert unread again (ReadStatus 0)
-- and shown again (StatusId 1) for every recipient except the acting user; no alert row is added, and
-- Alert_Master (CreatedOn, AlertTypeCode) is not changed. Text is compared exactly (case and trailing spaces
-- count; NULL and empty text are the same); for a number a change from NULL or to NULL counts
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
	DECLARE @RfSubjectTypeId INT;   -- AlertRefresh-Step36: the saved values before an Update
	DECLARE @RfShortText NVARCHAR(MAX);
	DECLARE @RfAgendaType VARCHAR(50);
	DECLARE @RfAgendaText NVARCHAR(MAX);
	DECLARE @RfAgendaTextPath NVARCHAR(MAX);
	DECLARE @RfProposedResolution NVARCHAR(MAX);
	DECLARE @RfFilePath NVARCHAR(MAX);
	DECLARE @RfMgrComments NVARCHAR(MAX);
	DECLARE @RfControllerComments NVARCHAR(MAX);
	DECLARE @RfSubjectNo INT;
	DECLARE @RfDepartmentId INT;
	DECLARE @RfChanged INT;
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
			-- AlertRefresh-Step36: the saved values, to see below whether this Update changes anything
			SELECT @RfSubjectTypeId = SubjectTypeId, @RfShortText = ShortText, @RfAgendaType = AgendaType,
			       @RfAgendaText = AgendaText, @RfAgendaTextPath = AgendaTextPath, @RfProposedResolution = ProposedResolution,
			       @RfFilePath = FilePath, @RfMgrComments = MgrComments, @RfControllerComments = ControllerComments,
			       @RfSubjectNo = SubjectNo, @RfDepartmentId = DepartmentId
			FROM Agenda WHERE AgendaId = @AgendaId;

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

			-- AlertRefresh-Step36: a change marks the item's alert unread again, and shown again if it was removed, for
			-- every recipient except the acting user; an Update that changes nothing leaves the alert as it is
			SET @RfChanged = CASE
				WHEN @RfSubjectTypeId <> @SubjectTypeId OR (@RfSubjectTypeId IS NULL AND @SubjectTypeId IS NOT NULL) OR (@RfSubjectTypeId IS NOT NULL AND @SubjectTypeId IS NULL) THEN 1
				WHEN @RfSubjectNo <> @SubjectNo OR (@RfSubjectNo IS NULL AND @SubjectNo IS NOT NULL) OR (@RfSubjectNo IS NOT NULL AND @SubjectNo IS NULL) THEN 1
				WHEN @RfDepartmentId <> @DepartmentId OR (@RfDepartmentId IS NULL AND @DepartmentId IS NOT NULL) OR (@RfDepartmentId IS NOT NULL AND @DepartmentId IS NULL) THEN 1
				WHEN ISNULL(@RfShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ShortText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfShortText, N'')) <> DATALENGTH(ISNULL(@ShortText, N'')) THEN 1
				WHEN ISNULL(@RfAgendaType, '') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaType, '') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaType, '')) <> DATALENGTH(ISNULL(@AgendaType, '')) THEN 1
				WHEN ISNULL(@RfAgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaText, N'')) <> DATALENGTH(ISNULL(@AgendaText, N'')) THEN 1
				WHEN ISNULL(@RfAgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaTextPath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) <> DATALENGTH(ISNULL(@AgendaTextPath, N'')) THEN 1
				WHEN ISNULL(@RfProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ProposedResolution, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfProposedResolution, N'')) <> DATALENGTH(ISNULL(@ProposedResolution, N'')) THEN 1
				WHEN ISNULL(@RfFilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@FilePath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfFilePath, N'')) <> DATALENGTH(ISNULL(@FilePath, N'')) THEN 1
				WHEN ISNULL(@RfMgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfMgrComments, N'')) <> DATALENGTH(ISNULL(@MgrComments, N'')) THEN 1
				WHEN ISNULL(@RfControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfControllerComments, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N'')) THEN 1
				ELSE 0 END;

			IF (@RfChanged = 1)
				UPDATE m SET ReadStatus = 0, StatusId = 1
				FROM Alert_User_Map m
				JOIN Alert_Master am ON am.AlertId = m.AlertId
				WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgendaId
				  AND m.UserId <> @ActingUserId;

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
IF (OBJECT_ID('dbo.spr_GetAgendaUpdateMailId', 'P') IS NOT NULL)
    DROP PROCEDURE dbo.spr_GetAgendaUpdateMailId;
GO

DELETE FROM dbo.App_Setting WHERE SettingCode = 'MailSenderUserId';
IF (@@ROWCOUNT > 0)
    PRINT 'App_Setting MailSenderUserId deleted.';
GO

DECLARE @Left INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') LIKE '%UpdateMail-Step37%')
    SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') LIKE '%UpdateMail-Step37%')
    SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') LIKE '%UpdateMail-Step37%')
    SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetAgendaUpdateMailId', 'P') IS NOT NULL)
    SET @Left = @Left + 1;

IF (@Left = 0)
    PRINT 'Step 37 rolled back: the three agenda procedures have the text of step 36, spr_GetAgendaUpdateMailId and MailSenderUserId are removed.';
ELSE
    RAISERROR('Rollback of step 37 is not complete: %d of 4 objects still carry step 37. Read the messages above and run the script again.', 16, 1, @Left);
GO

SET NOEXEC OFF;
GO
