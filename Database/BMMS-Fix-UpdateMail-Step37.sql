/* ============================================================================
   BMMS - A mail when an agenda item is updated (step 37, step ML1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Since step 36 an Update on Agenda Entry that changes a saved field marks
   the item's alert unread again for the other recipients, but no mail goes
   out. Decision (Consultant, 2026-11-08): a mail on Update goes to the same
   people as the refreshed alert, only when something really changed, and
   names the changed fields without their text.

   Objects
     spr_AddEditAgenda              REPLACED (text of step 36)
     spr_AddEditAgendaByManager     REPLACED (text of step 36)
     spr_AddEditAgendaByController  REPLACED (text of step 36)
                                    New last parameter
                                      @ChangedFields VARCHAR(400) = NULL OUTPUT
                                    The fields the Update changed, by the
                                    comparison of step 36, as a comma list in
                                    this order:
                                      SubjectType, ShortText, AgendaType,
                                      AgendaText, AgendaTextFile:Attached |
                                      AgendaTextFile:Removed |
                                      AgendaTextFile:Replaced,
                                      ProposedResolution, Attachments,
                                      MgrComments, ControllerComments,
                                      Department (Controller only), SubjectNo
                                    Empty for a new item (Save), a refusal and
                                    an Update that changes nothing; it is
                                    empty exactly when step 36 leaves the
                                    alert as it is. Callers that do not pass
                                    it are not affected: the result row
                                    (Result, Reason, ReasonDetail) and every
                                    other parameter are unchanged.
     spr_GetAgendaUpdateMailId      NEW. @AgendaId, @ActingUserId. The e-mail
                                    addresses of the users the refreshed
                                    alert is shown to: the Alert_User_Map
                                    rows of the item's alert except the
                                    acting user, with the role filter of
                                    spr_GetAlertByUserId (no Controller for an
                                    ACA / ACR alert, no Manager for AMA / AMR),
                                    active users only, not the system
                                    account, address not empty. One column
                                    EmailId, ordered by UserId. Reads only.
     App_Setting MailSenderUserId   NEW ROW (only when missing). The user ID
                                    of the account that sends the BMMS mail
                                    (the Controller login account). Pre-set
                                    to the active Controller-role user with
                                    Login ID "Controller", else empty. The
                                    mail is still sent From the From Mail Id
                                    of SMTP Configuration: set that address
                                    (and the SMTP login) to this user's
                                    mailbox. BMMS-Check-InstalledSteps.sql
                                    shows whether the two agree.
   Marker UpdateMail-Step37 in the four procedures. Only lines are added to
   the three agenda procedures: the texts of steps 16, 17, 18, 20, 31, 35
   and 36 are kept, so those steps still read Installed.

   Order: install the steps in order. Step 36 must be installed before this
   step; the script stops if it is not. Re-running step 16, 17, 18, 20, 31,
   35 or 36 after this step brings back an older text and removes step 37
   (no mail on Update, and Agenda Entry says so as a mail error): run step 37
   again.

   Data: adds the one App_Setting row when it is missing, nothing else.
   Safe to re-run (an existing MailSenderUserId row is kept as it is).
   BMMS-Rollback-UpdateMail-Step37.sql restores the step 36 texts, drops
   spr_GetAgendaUpdateMailId and deletes the MailSenderUserId row.

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
ELSE IF (OBJECT_ID('dbo.App_Setting', 'U') IS NULL OR COL_LENGTH('dbo.Users', 'IsSystem') IS NULL
         OR COL_LENGTH('dbo.Users', 'AccountStatus') IS NULL OR OBJECT_ID('dbo.Roles', 'U') IS NULL)
BEGIN
    RAISERROR('App_Setting, Roles, Users.IsSystem or Users.AccountStatus is missing in "%s". This is not a BMMS database of the expected version. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') NOT LIKE '%AlertRefresh-Step36%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') NOT LIKE '%AlertRefresh-Step36%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') NOT LIKE '%AlertRefresh-Step36%')
BEGIN
    RAISERROR('Step 36 is not installed in "%s" (the three agenda procedures need the marker AlertRefresh-Step36). The steps are installed in order: run BMMS-Fix-AlertRefresh-Step36.sql first (BMMS-Check-InstalledSteps.sql shows which steps are installed), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
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
-- UpdateMail-Step37: @ChangedFields (OUTPUT, optional) returns the fields an Update changed, by the comparison of
-- AlertRefresh-Step36, as a comma list of codes in a fixed order; empty for a new item, a refusal or an Update
-- that changes nothing. Agenda Entry sends the update mail from it; nothing else changes
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
@ActingUserId INT,
@ChangedFields VARCHAR(400) = NULL OUTPUT)   -- UpdateMail-Step37
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
	SET @ChangedFields = '';   -- UpdateMail-Step37

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

			-- UpdateMail-Step37: the changed fields for the update mail (the comparisons above, one per field: the list is
			-- empty exactly when @RfChanged is 0)
			SET @ChangedFields =
				CASE WHEN @RfSubjectTypeId <> @SubjectTypeId OR (@RfSubjectTypeId IS NULL AND @SubjectTypeId IS NOT NULL) OR (@RfSubjectTypeId IS NOT NULL AND @SubjectTypeId IS NULL)
				       THEN ',SubjectType' ELSE '' END
				+ CASE WHEN ISNULL(@RfShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ShortText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfShortText, N'')) <> DATALENGTH(ISNULL(@ShortText, N''))
				       THEN ',ShortText' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaType, '') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaType, '') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaType, '')) <> DATALENGTH(ISNULL(@AgendaType, ''))
				       THEN ',AgendaType' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaText, N'')) <> DATALENGTH(ISNULL(@AgendaText, N''))
				       THEN ',AgendaText' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaTextPath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) <> DATALENGTH(ISNULL(@AgendaTextPath, N''))
				       THEN CASE WHEN DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) = 0 THEN ',AgendaTextFile:Attached'
				                 WHEN DATALENGTH(ISNULL(@AgendaTextPath, N'')) = 0 THEN ',AgendaTextFile:Removed'
				                 ELSE ',AgendaTextFile:Replaced' END
				       ELSE '' END
				+ CASE WHEN ISNULL(@RfProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ProposedResolution, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfProposedResolution, N'')) <> DATALENGTH(ISNULL(@ProposedResolution, N''))
				       THEN ',ProposedResolution' ELSE '' END
				+ CASE WHEN ISNULL(@RfFilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@FilePath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfFilePath, N'')) <> DATALENGTH(ISNULL(@FilePath, N''))
				       THEN ',Attachments' ELSE '' END
				+ CASE WHEN ISNULL(@RfMgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfMgrComments, N'')) <> DATALENGTH(ISNULL(@MgrComments, N''))
				       THEN ',MgrComments' ELSE '' END
				+ CASE WHEN ISNULL(@RfControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfControllerComments, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N''))
				       THEN ',ControllerComments' ELSE '' END
				+ CASE WHEN @RfSubjectNo <> @SubjectNo OR (@RfSubjectNo IS NULL AND @SubjectNo IS NOT NULL) OR (@RfSubjectNo IS NOT NULL AND @SubjectNo IS NULL)
				       THEN ',SubjectNo' ELSE '' END
				+ '';
			IF (LEN(@ChangedFields) > 0)
				SET @ChangedFields = STUFF(@ChangedFields, 1, 1, '');

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
-- UpdateMail-Step37: @ChangedFields (OUTPUT, optional) returns the fields an Update changed, by the comparison of
-- AlertRefresh-Step36, as a comma list of codes in a fixed order; empty for a new item, a refusal or an Update
-- that changes nothing. Agenda Entry sends the update mail from it; nothing else changes
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
@ActingUserId INT,
@ChangedFields VARCHAR(400) = NULL OUTPUT)   -- UpdateMail-Step37
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
	SET @ChangedFields = '';   -- UpdateMail-Step37

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

			-- UpdateMail-Step37: the changed fields for the update mail (the comparisons above, one per field: the list is
			-- empty exactly when @RfChanged is 0)
			SET @ChangedFields =
				CASE WHEN @RfSubjectTypeId <> @SubjectTypeId OR (@RfSubjectTypeId IS NULL AND @SubjectTypeId IS NOT NULL) OR (@RfSubjectTypeId IS NOT NULL AND @SubjectTypeId IS NULL)
				       THEN ',SubjectType' ELSE '' END
				+ CASE WHEN ISNULL(@RfShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ShortText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfShortText, N'')) <> DATALENGTH(ISNULL(@ShortText, N''))
				       THEN ',ShortText' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaType, '') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaType, '') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaType, '')) <> DATALENGTH(ISNULL(@AgendaType, ''))
				       THEN ',AgendaType' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaText, N'')) <> DATALENGTH(ISNULL(@AgendaText, N''))
				       THEN ',AgendaText' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaTextPath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) <> DATALENGTH(ISNULL(@AgendaTextPath, N''))
				       THEN CASE WHEN DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) = 0 THEN ',AgendaTextFile:Attached'
				                 WHEN DATALENGTH(ISNULL(@AgendaTextPath, N'')) = 0 THEN ',AgendaTextFile:Removed'
				                 ELSE ',AgendaTextFile:Replaced' END
				       ELSE '' END
				+ CASE WHEN ISNULL(@RfProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ProposedResolution, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfProposedResolution, N'')) <> DATALENGTH(ISNULL(@ProposedResolution, N''))
				       THEN ',ProposedResolution' ELSE '' END
				+ CASE WHEN ISNULL(@RfFilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@FilePath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfFilePath, N'')) <> DATALENGTH(ISNULL(@FilePath, N''))
				       THEN ',Attachments' ELSE '' END
				+ CASE WHEN ISNULL(@RfMgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfMgrComments, N'')) <> DATALENGTH(ISNULL(@MgrComments, N''))
				       THEN ',MgrComments' ELSE '' END
				+ CASE WHEN ISNULL(@RfControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfControllerComments, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N''))
				       THEN ',ControllerComments' ELSE '' END
				+ CASE WHEN @RfSubjectNo <> @SubjectNo OR (@RfSubjectNo IS NULL AND @SubjectNo IS NOT NULL) OR (@RfSubjectNo IS NOT NULL AND @SubjectNo IS NULL)
				       THEN ',SubjectNo' ELSE '' END
				+ '';
			IF (LEN(@ChangedFields) > 0)
				SET @ChangedFields = STUFF(@ChangedFields, 1, 1, '');

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
-- UpdateMail-Step37: @ChangedFields (OUTPUT, optional) returns the fields an Update changed, by the comparison of
-- AlertRefresh-Step36, as a comma list of codes in a fixed order; empty for a new item, a refusal or an Update
-- that changes nothing. Agenda Entry sends the update mail from it; nothing else changes
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
@ActingUserId INT,
@ChangedFields VARCHAR(400) = NULL OUTPUT)   -- UpdateMail-Step37
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
	SET @ChangedFields = '';   -- UpdateMail-Step37

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

			-- UpdateMail-Step37: the changed fields for the update mail (the comparisons above, one per field: the list is
			-- empty exactly when @RfChanged is 0)
			SET @ChangedFields =
				CASE WHEN @RfSubjectTypeId <> @SubjectTypeId OR (@RfSubjectTypeId IS NULL AND @SubjectTypeId IS NOT NULL) OR (@RfSubjectTypeId IS NOT NULL AND @SubjectTypeId IS NULL)
				       THEN ',SubjectType' ELSE '' END
				+ CASE WHEN ISNULL(@RfShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ShortText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfShortText, N'')) <> DATALENGTH(ISNULL(@ShortText, N''))
				       THEN ',ShortText' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaType, '') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaType, '') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaType, '')) <> DATALENGTH(ISNULL(@AgendaType, ''))
				       THEN ',AgendaType' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaText, N'')) <> DATALENGTH(ISNULL(@AgendaText, N''))
				       THEN ',AgendaText' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaTextPath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) <> DATALENGTH(ISNULL(@AgendaTextPath, N''))
				       THEN CASE WHEN DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) = 0 THEN ',AgendaTextFile:Attached'
				                 WHEN DATALENGTH(ISNULL(@AgendaTextPath, N'')) = 0 THEN ',AgendaTextFile:Removed'
				                 ELSE ',AgendaTextFile:Replaced' END
				       ELSE '' END
				+ CASE WHEN ISNULL(@RfProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ProposedResolution, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfProposedResolution, N'')) <> DATALENGTH(ISNULL(@ProposedResolution, N''))
				       THEN ',ProposedResolution' ELSE '' END
				+ CASE WHEN ISNULL(@RfFilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@FilePath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfFilePath, N'')) <> DATALENGTH(ISNULL(@FilePath, N''))
				       THEN ',Attachments' ELSE '' END
				+ CASE WHEN ISNULL(@RfMgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfMgrComments, N'')) <> DATALENGTH(ISNULL(@MgrComments, N''))
				       THEN ',MgrComments' ELSE '' END
				+ CASE WHEN ISNULL(@RfControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfControllerComments, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N''))
				       THEN ',ControllerComments' ELSE '' END
				+ CASE WHEN @RfDepartmentId <> @DepartmentId OR (@RfDepartmentId IS NULL AND @DepartmentId IS NOT NULL) OR (@RfDepartmentId IS NOT NULL AND @DepartmentId IS NULL)
				       THEN ',Department' ELSE '' END
				+ CASE WHEN @RfSubjectNo <> @SubjectNo OR (@RfSubjectNo IS NULL AND @SubjectNo IS NOT NULL) OR (@RfSubjectNo IS NOT NULL AND @SubjectNo IS NULL)
				       THEN ',SubjectNo' ELSE '' END
				+ '';
			IF (LEN(@ChangedFields) > 0)
				SET @ChangedFields = STUFF(@ChangedFields, 1, 1, '');

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

-- UpdateMail-Step37: who gets the mail when an agenda item is updated: the users the refreshed alert is shown to
-- (Alert_User_Map rows of the item's alert except the acting user, with the role filter of spr_GetAlertByUserId),
-- active, not the system account, with an address. Reads only.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaUpdateMailId]
@AgendaId INT,
@ActingUserId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT u.EmailId
	FROM Alert_Master am
	JOIN Alert_User_Map m ON m.AlertId = am.AlertId
	JOIN Users u ON u.UserId = m.UserId
	LEFT JOIN Roles r ON r.RoleId = u.RoleId
	WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgendaId
	  AND m.UserId <> @ActingUserId
	  AND u.AccountStatus = 1 AND u.IsSystem = 0
	  AND LTRIM(RTRIM(ISNULL(u.EmailId, ''))) <> ''
	  AND NOT (ISNULL(r.RoleCode, '') = 'controller' AND am.AlertTypeCode IN ('ACA', 'ACR'))
	  AND NOT (ISNULL(r.RoleCode, '') = 'manager' AND am.AlertTypeCode IN ('AMA', 'AMR'))
	GROUP BY u.UserId, u.EmailId
	ORDER BY u.UserId;
END
GO

-- UpdateMail-Step37: the account that sends the BMMS mail (only when the row is missing)
DECLARE @Sender VARCHAR(250);
IF NOT EXISTS (SELECT 1 FROM dbo.App_Setting WHERE SettingCode = 'MailSenderUserId')
BEGIN
    SET @Sender = ISNULL((SELECT CAST(MIN(u.UserId) AS VARCHAR(250)) FROM dbo.Users u JOIN dbo.Roles r ON r.RoleId = u.RoleId
                          WHERE u.LoginName = 'Controller' AND r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0), '');
    INSERT INTO dbo.App_Setting (SettingCode, SettingValue, Description)
    VALUES ('MailSenderUserId', @Sender, 'User ID of the account that sends the BMMS mail (the Controller login account, step 37)');
    PRINT 'App_Setting MailSenderUserId added: "' + @Sender + '".';
END
ELSE
BEGIN
    SET @Sender = (SELECT SettingValue FROM dbo.App_Setting WHERE SettingCode = 'MailSenderUserId');
    PRINT 'App_Setting MailSenderUserId kept: "' + @Sender + '".';
END
GO

-- The sender against SMTP Configuration (read only; the addresses are not shown)
DECLARE @SenderValue VARCHAR(250) = (SELECT SettingValue FROM dbo.App_Setting WHERE SettingCode = 'MailSenderUserId');
DECLARE @SenderMail VARCHAR(250);
DECLARE @FromMail VARCHAR(250) = (SELECT MIN(FromMailId) FROM dbo.SMTP_Master);
IF (@SenderValue NOT LIKE '%[^0-9]%' AND LEN(@SenderValue) BETWEEN 1 AND 9)
    SET @SenderMail = (SELECT u.EmailId FROM dbo.Users u JOIN dbo.Roles r ON r.RoleId = u.RoleId
                       WHERE u.UserId = CAST(@SenderValue AS INT) AND r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0);
IF (@SenderMail IS NULL)
    PRINT 'Sender: MailSenderUserId does not name an active Controller-role user. Set it (see Database/README.md, step ML1).';
ELSE IF (LTRIM(RTRIM(ISNULL(@FromMail, ''))) = LTRIM(RTRIM(@SenderMail)))
    PRINT 'Sender: the From Mail Id of SMTP Configuration is the e-mail of user ' + @SenderValue + '.';
ELSE
    PRINT 'Sender: the From Mail Id of SMTP Configuration is NOT the e-mail of user ' + @SenderValue + '. The mail still goes out From the SMTP Configuration address (see Database/README.md, step ML1).';
GO

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') LIKE '%UpdateMail-Step37%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') LIKE '%UpdateMail-Step37%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') LIKE '%UpdateMail-Step37%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), '') LIKE '%UpdateMail-Step37%')
    SET @Installed = @Installed + 1;

IF (@Installed = 4)
    PRINT 'Step 37 installed: spr_AddEditAgenda, spr_AddEditAgendaByManager, spr_AddEditAgendaByController and spr_GetAgendaUpdateMailId (UpdateMail-Step37).';
ELSE
    RAISERROR('Step 37 is not complete: %d of 4 procedures carry the marker UpdateMail-Step37. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
