/* ============================================================================
   BMMS - Meeting locks, part 2 (step 16)
   ----------------------------------------------------------------------------
   Adds the locks step 15 left out, inside the procedures so that no caller
   can get round them:

     1. Meeting edit: once attendance is recorded for a meeting, its date and
        committee cannot change. Once agenda items exist, its committee cannot
        change (the agenda numbers carry the committee code). Venue, time and
        the other details stay editable.
     2. Agenda add / edit / delete / approve once the agenda is finalized
        (AgendaStatus 'Close'): refused, except that an active Controller may
        still add, edit and delete agenda items while the minutes are not
        finalized, if the Admin option "AgendaControllerBypass" (table
        App_Setting, default '1' = on) is switched on. The procedure reads the
        acting user's role and status from the database itself.
     3. Minutes update (and the agenda short text edited on the minutes page):
        refused once the minutes are confirmed (MinutesStatus 'C'). 'F' stays
        editable, as before.
     4. Committee members: a member counts for a meeting only if appointed on
        or before the meeting date (AppointmentDate NULL counts as appointed),
        as well as not ceased before it. A CessationDate that is not a date
        counts as not ceased. Members that already have an Attendance row for
        the meeting are still listed, so nothing saved is hidden. New
        attendance for a member not on the committee on that date is refused,
        and so is a new chairman who is not.

   Meeting state (Meeting table; NULL is treated as 'Open'):
     AgendaStatus   'Open' -> 'Close'  (agenda finalized)
     MinutesStatus  'Open' -> 'F'      (minutes finalized)
                    'F'    -> 'C'      (minutes confirmed)

   Every changed procedure except spr_UpdateAttendance returns ONE row:
     Result        1 = done, 0 = refused
     Reason        0  done
                   1  minutes finalized (MinutesStatus 'F' or 'C')       (step 15)
                   3  value not valid (setting); ReasonDetail = the value
                   4  not found, or (setting) not allowed for your role
                   5  agenda finalized; ReasonDetail 'Finalized', or
                      'BypassOff' when a Controller is refused because the
                      Admin option is switched off
                   6  attendance recorded: date / committee cannot change;
                      ReasonDetail 'MeetingDate', 'CommitteeId' or both
                   7  minutes confirmed
                   8  acting user missing or inactive
                   9  member not on the committee on the meeting date;
                      ReasonDetail = the member name
                   10 agenda items exist: committee cannot change
   spr_UpdateAttendance still returns only Result (0 = refused).

   Objects (each carries the text MeetingLocks-Step16)
     App_Setting (table)                     NEW, one row per option
     fn_AgendaChangeRefusal                  NEW, the agenda rule (2)
     fn_CommitteeMemberDateCheck             NEW, the member date rule (4)
     spr_GetAppSetting / spr_SetAppSetting   NEW, System Settings page;
                                             only an active Admin may set
     spr_AddEditMeeting                      + rule 1
     spr_GetMeetingEditLockByMeetingId       NEW, HasAttendance / HasAgenda
     spr_AddEditAgenda                       + @ActingUserId, rule 2, no bypass
     spr_AddEditAgendaByManager              + @ActingUserId, rule 2, no bypass
     spr_AddEditAgendaByController           + @ActingUserId, rule 2 with bypass
     spr_DeleteAgendaByAgendaId              + @ActingUserId, rule 2 with bypass
     spr_UpdateSubjectNoByAgendaId           + @ActingUserId, rule 2 with bypass
     spr_UpdateAgendaByAgendaId              approve / reject: refused once
                                             the agenda is finalized (no bypass)
     spr_GetAgendaLockByMeetingId            NEW, the agenda rule for the pages
     spr_UpdateMinutes, spr_UpdateAgendaShortText   rule 3
     spr_GetCommitteeMemberByCommitteeId     rule 4 (only @MeetingId > 0)
     spr_GetCommitteeMemberByMeetingId       rule 4
     spr_UpdateAttendance                    + rule 4 for new 'C' rows
     spr_UpdateMeetingChairman               + rule 4 for a changed chairman

   Replaces procedures of earlier steps: spr_UpdateMinutes and
   spr_DeleteAgendaByAgendaId (step 6), spr_UpdateMeetingChairman (steps 6
   and 15), spr_UpdateAttendance (steps 12 and 15). They keep the texts the
   installed-steps check looks for ("FK #5", "Attendance-FutureMeeting",
   "MeetingLocks-Step15"). If step 6, 12 or 15 is ever re-run, run this
   script again afterwards.

   Run it BEFORE deploying the build that passes @ActingUserId and reads
   Result / Reason from these procedures, and deploy that build straight
   after: the older build cannot save or delete agenda items against this
   script (missing @ActingUserId), and it reports a refused meeting or
   minutes change as saved.

   Changes no existing data. Creates App_Setting and adds its one row only if
   they are missing, so a re-run keeps the Admin's choice. Safe to re-run.
   Needs steps 14 and 15 and stops otherwise.

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
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- Settings table (MeetingLocks-Step16). No user-id column: each change is
-- written to Audit_Trail_Master, which already counts as user history.
-------------------------------------------------------------------------------
IF (OBJECT_ID('dbo.App_Setting', 'U') IS NULL)
BEGIN
	CREATE TABLE [dbo].[App_Setting]
	(
	SettingCode VARCHAR(50) NOT NULL CONSTRAINT PK_App_Setting PRIMARY KEY,
	SettingValue VARCHAR(250) NOT NULL,
	Description VARCHAR(250) NULL
	);
	PRINT 'Table App_Setting created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass')
BEGIN
	INSERT INTO App_Setting (SettingCode, SettingValue, Description)
	VALUES ('AgendaControllerBypass', '1', 'Controller can add, edit and delete agenda items after the agenda is finalized (until the minutes are finalized)');
	PRINT 'Setting AgendaControllerBypass added (on).';
END
GO

-- Agenda rule (MeetingLocks-Step16). One row: Reason, ReasonDetail.
-- @BypassAllowed = 1 only for the procedures the Controller may use after
-- the agenda is finalized (the Controller add / edit, delete, subject no).
-- The caller locks the meeting row first (UPDLOCK, HOLDLOCK).
CREATE OR ALTER FUNCTION [dbo].[fn_AgendaChangeRefusal]
(
@MeetingId INT,
@ActingUserId INT,
@BypassAllowed INT
)
RETURNS TABLE
AS
RETURN
SELECT
x.Reason,
CAST(CASE WHEN x.Reason = 5 AND x.IsBypassRole = 1 THEN 'BypassOff'
          WHEN x.Reason = 5 THEN 'Finalized'
          ELSE '' END AS NVARCHAR(2000)) AS ReasonDetail
FROM
(
	SELECT
	CASE WHEN a.RoleCode IS NULL THEN 8
	     WHEN m.MeetingId IS NULL THEN 4
	     WHEN m.MinutesStatus IN ('F', 'C') THEN 1
	     WHEN m.AgendaStatus = 'Open' THEN 0
	     WHEN @BypassAllowed = 1 AND a.RoleCode = 'controller' AND s.Bypass = '1' THEN 0
	     ELSE 5 END AS Reason,
	CASE WHEN @BypassAllowed = 1 AND a.RoleCode = 'controller' THEN 1 ELSE 0 END AS IsBypassRole
	FROM (SELECT 1 AS One) d
	LEFT JOIN (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	           WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1) a ON 1 = 1
	LEFT JOIN (SELECT MeetingId, ISNULL(AgendaStatus, 'Open') AS AgendaStatus, ISNULL(MinutesStatus, 'Open') AS MinutesStatus
	           FROM Meeting WHERE MeetingId = @MeetingId) m ON 1 = 1
	CROSS JOIN (SELECT ISNULL((SELECT SettingValue FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass'), '1') AS Bypass) s
) x;
GO

-- Committee member dates against a meeting date (MeetingLocks-Step16).
-- @Check 'A' appointed on or before the meeting date (NULL appointment
-- counts as appointed), 'C' not ceased before it (empty or not-a-date
-- cessation counts as not ceased), 'B' both. Compared as dates; equal is
-- allowed. A meeting with no date: appointment passes, only an empty or
-- not-a-date cessation passes (as before).
CREATE OR ALTER FUNCTION [dbo].[fn_CommitteeMemberDateCheck]
(
@AppointmentDate DATETIME,
@CessationDate VARCHAR(50),
@MeetingDate DATETIME,
@Check CHAR(1)
)
RETURNS INT
AS
BEGIN
	DECLARE @Appointed INT;
	DECLARE @NotCeased INT;

	IF (@AppointmentDate IS NULL OR @MeetingDate IS NULL OR CAST(@AppointmentDate AS date) <= CAST(@MeetingDate AS date))
		SET @Appointed = 1;
	ELSE
		SET @Appointed = 0;

	IF (ISNULL(@CessationDate, '') = '' OR ISDATE(@CessationDate) = 0)
		SET @NotCeased = 1;
	ELSE IF (@MeetingDate IS NOT NULL
	         AND CAST(CONVERT(DATETIME, CASE WHEN ISDATE(@CessationDate) = 1 THEN @CessationDate END) AS date) >= CAST(@MeetingDate AS date))
		SET @NotCeased = 1;
	ELSE
		SET @NotCeased = 0;

	RETURN CASE @Check WHEN 'A' THEN @Appointed
	                   WHEN 'C' THEN @NotCeased
	                   ELSE @Appointed * @NotCeased END;
END
GO

-- Settings - read one, with the last change from the audit trail (MeetingLocks-Step16)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAppSetting]
@SettingCode VARCHAR(50)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	s.SettingCode,
	s.SettingValue,
	s.Description,
	l.Update_On AS LastChangedOn,
	ISNULL(u.UserName, '') AS LastChangedBy
	FROM App_Setting s
	OUTER APPLY (SELECT TOP 1 t.Update_On, t.Update_By FROM Audit_Trail_Master t
	             WHERE t.Audit_Table = 'App_Setting' AND t.Key_Value = s.SettingCode
	             ORDER BY t.Update_On DESC, t.Audit_Trail_Maser_Id DESC) l
	LEFT JOIN Users u ON u.UserId = l.Update_By
	WHERE s.SettingCode = @SettingCode;
END
GO

-- Settings - change one; only an active Admin (MeetingLocks-Step16)
CREATE OR ALTER PROCEDURE [dbo].[spr_SetAppSetting]
@SettingCode VARCHAR(50),
@SettingValue VARCHAR(250),
@ActingUserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @OldValue VARCHAR(250);
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
			SAVE TRANSACTION AppSettingSave;

		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

		IF (@ActingRole IS NULL)
			SET @Reason = 8;
		ELSE IF (@ActingRole <> 'admin')
			SET @Reason = 4;
		ELSE IF (ISNULL(@SettingCode, '') <> 'AgendaControllerBypass' OR ISNULL(@SettingValue, '') NOT IN ('0', '1'))
		BEGIN
			SET @Reason = 3;
			SET @Detail = ISNULL(@SettingValue, 'NULL');
		END
		ELSE
		BEGIN
			SET @OldValue = (SELECT SettingValue FROM App_Setting WITH (UPDLOCK, HOLDLOCK) WHERE SettingCode = @SettingCode);

			IF (@OldValue IS NULL)
				INSERT INTO App_Setting (SettingCode, SettingValue, Description)
				VALUES (@SettingCode, @SettingValue, 'Controller can add, edit and delete agenda items after the agenda is finalized (until the minutes are finalized)');
			ELSE
				UPDATE App_Setting SET SettingValue = @SettingValue WHERE SettingCode = @SettingCode;

			IF (ISNULL(@OldValue, '') <> @SettingValue)
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'App_Setting', 'SettingCode', @SettingCode, 'SettingValue', ISNULL(@OldValue, ''), @SettingValue, @ActingUserId, GETDATE());

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
			ROLLBACK TRANSACTION AppSettingSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Meeting - add / edit; date and committee locked by attendance, committee by agenda items (MeetingLocks-Step16)
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
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy);

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
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy);

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

-- Meeting - what the edit page may change (MeetingLocks-Step16). No row if the meeting does not exist.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMeetingEditLockByMeetingId]
@MeetingId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	CASE WHEN EXISTS (SELECT 1 FROM Attendance a WHERE a.MeetingId = m.MeetingId) THEN 1 ELSE 0 END AS HasAttendance,
	CASE WHEN EXISTS (SELECT 1 FROM Agenda g WHERE g.MeetingId = m.MeetingId) THEN 1 ELSE 0 END AS HasAgenda
	FROM Meeting m
	WHERE m.MeetingId = @MeetingId;
END
GO

-- Agenda - add / edit by a user, refused once the agenda is finalized (MeetingLocks-Step16)
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
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE RoleId = 1 OR UserId = @Mgr_Id);

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

-- Agenda - add / edit by a manager, refused once the agenda is finalized (MeetingLocks-Step16)
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
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE RoleId = 1 OR RoleId = 2 OR
				UserId IN (SELECT Users.UserId FROM Users WHERE Users.DepartmentId = @DepartmentId));

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

-- Agenda - add / edit by the Controller; after the agenda is finalized only with the Admin option on (MeetingLocks-Step16)
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
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE RoleId = 1 OR
				UserId IN (SELECT Users.UserId FROM Users WHERE Users.DepartmentId = @DepartmentId));

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

-- Agenda - delete; after the agenda is finalized only the Controller with the Admin option on,
-- never once the minutes are finalized (MeetingLocks-Step16). Action items go first (FK #5, step 6).
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteAgendaByAgendaId]
@AgendaId INT,
@ActingUserId INT
AS
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
			SAVE TRANSACTION AgendaDelete;

		SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 1);

		IF (@Reason = 0)
		BEGIN
			DELETE FROM Alert_Master
				WHERE SourceType = 'Agenda'
				AND SourceTypeId = @AgendaId;

			-- FK #5
			DELETE FROM Action_Item WHERE
			MinutesId IN (SELECT MinutesId FROM Minutes WHERE AgendaId = @AgendaId);

			DELETE FROM Minutes WHERE AgendaId = @AgendaId;

			DELETE FROM Agenda WHERE AgendaId = @AgendaId;

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
			ROLLBACK TRANSACTION AgendaDelete;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Agenda - subject number (no page calls it today); same rule as the Controller edit (MeetingLocks-Step16)
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateSubjectNoByAgendaId]
@AgendaId INT,
@SubjectNo INT,
@ActingUserId INT
AS
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
			SAVE TRANSACTION AgendaSubjectNo;

		SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 1);

		IF (@Reason = 0)
		BEGIN
			UPDATE Agenda SET
			SubjectNo = @SubjectNo
			WHERE AgendaId = @AgendaId;

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
			ROLLBACK TRANSACTION AgendaSubjectNo;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Agenda - manager / controller approve or reject; refused once the agenda is finalized,
-- for every role: no Minutes row would be created for it (MeetingLocks-Step16)
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
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE UserId = @User_Id);

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
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE RoleId = 2 OR UserId = @User_Id);

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

				DELETE FROM Alert_User_Map WHERE UserId = @User_Id AND AlertId = @AlertId;

				INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
					VALUES (@AlertId, @User_Id, 0, 1);

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

-- Agenda - may the acting user add / edit / delete agenda items of this meeting? For the pages (MeetingLocks-Step16)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaLockByMeetingId]
@MeetingId INT,
@ActingUserId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	CASE WHEN Reason = 0 THEN 1 ELSE 0 END AS AllowChange,
	Reason,
	ReasonDetail
	FROM dbo.fn_AgendaChangeRefusal(@MeetingId, @ActingUserId, 1);
END
GO

-- Minutes update - refused once the minutes are confirmed (MeetingLocks-Step16). The new action item is
-- mapped to the agenda creator only if that user still exists (FK #5, step 6).
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
						WHERE UserId = @UserId;
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

-- Agenda short text (edited on the minutes page) - refused once the minutes are confirmed (MeetingLocks-Step16)
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

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus = 'C')
			SET @Reason = 7;
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

-- Committee members of a committee (MeetingLocks-Step16). @MeetingId > 0: only members appointed on or
-- before the meeting date and not ceased before it; members with an Attendance row for the meeting stay
-- listed whatever their appointment date. -1 (all) and 0 (not ceased today) are unchanged.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetCommitteeMemberByCommitteeId]
@CommitteeId INT,
@MeetingId INT
AS
DECLARE @MeetingDate DATETIME;
BEGIN
	IF (@MeetingId = -1)
	BEGIN
		SELECT
		*
		FROM View_Committee_Member
		WHERE CommitteeId = @CommitteeId;
	END

	IF (@MeetingId = 0)
	BEGIN
		SELECT
		*
		FROM View_Committee_Member
		WHERE CommitteeId = @CommitteeId
		AND
		(CessationDate >= GETDATE()
		OR CessationDate = '');
	END

	IF (@MeetingId > 0)
	BEGIN
		SET @MeetingDate = (SELECT MeetingDate FROM Meeting WHERE MeetingId = @MeetingId);

		SELECT
		v.*
		FROM View_Committee_Member v
		WHERE v.CommitteeId = @CommitteeId
		AND dbo.fn_CommitteeMemberDateCheck(v.AppointmentDate, v.CessationDate, @MeetingDate, 'C') = 1
		AND (dbo.fn_CommitteeMemberDateCheck(v.AppointmentDate, v.CessationDate, @MeetingDate, 'A') = 1
		     OR EXISTS (SELECT 1 FROM Attendance a WHERE a.MeetingId = @MeetingId AND a.MemberId = v.MemberId));
	END
END
GO

-- Committee members of a meeting, for the notice and minutes prints (MeetingLocks-Step16): members on the
-- committee on the meeting date, plus anyone with an Attendance row for the meeting.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetCommitteeMemberByMeetingId]
@MeetingId INT
AS
BEGIN
	SELECT
	*,
	(SELECT MemberTypeName FROM View_Committee_Member WHERE
		View_Committee_Member.MemberId = View_Member.MemberId AND
			View_Committee_Member.CommitteeId IN
			(SELECT Meeting.CommitteeId  FROM Meeting WHERE Meeting.MeetingId = @MeetingId)) AS MemberTypeName
	FROM  View_Member
	WHERE MemberId IN
	(SELECT cm.MemberId
	 FROM View_Committee_Member cm
	 JOIN Meeting mt ON mt.CommitteeId = cm.CommitteeId
	 WHERE mt.MeetingId = @MeetingId
	 AND (dbo.fn_CommitteeMemberDateCheck(cm.AppointmentDate, cm.CessationDate, mt.MeetingDate, 'B') = 1
	      OR EXISTS (SELECT 1 FROM Attendance a WHERE a.MeetingId = @MeetingId AND a.MemberId = cm.MemberId)));
END
GO

-- Attendance - save one member (MeetingLocks-Step16): a NEW committee-member row only for a member on the
-- committee on the meeting date. Kept from step 15 (MeetingLocks-Step15) and step 12 (Attendance-FutureMeeting).
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

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus IN ('F', 'C'))
			SET @Reason = 1;
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

DECLARE @Installed INT = (SELECT COUNT(*) FROM sys.sql_modules
    WHERE definition LIKE '%MeetingLocks-Step16%'
    AND object_id IN (OBJECT_ID('dbo.fn_AgendaChangeRefusal'), OBJECT_ID('dbo.fn_CommitteeMemberDateCheck'),
                      OBJECT_ID('dbo.spr_GetAppSetting'), OBJECT_ID('dbo.spr_SetAppSetting'),
                      OBJECT_ID('dbo.spr_AddEditMeeting'), OBJECT_ID('dbo.spr_GetMeetingEditLockByMeetingId'),
                      OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'),
                      OBJECT_ID('dbo.spr_AddEditAgendaByController'), OBJECT_ID('dbo.spr_DeleteAgendaByAgendaId'),
                      OBJECT_ID('dbo.spr_UpdateSubjectNoByAgendaId'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'),
                      OBJECT_ID('dbo.spr_GetAgendaLockByMeetingId'), OBJECT_ID('dbo.spr_UpdateMinutes'),
                      OBJECT_ID('dbo.spr_UpdateAgendaShortText'), OBJECT_ID('dbo.spr_GetCommitteeMemberByCommitteeId'),
                      OBJECT_ID('dbo.spr_GetCommitteeMemberByMeetingId'), OBJECT_ID('dbo.spr_UpdateAttendance'),
                      OBJECT_ID('dbo.spr_UpdateMeetingChairman')));

IF (@Installed = 19 AND OBJECT_ID('dbo.App_Setting', 'U') IS NOT NULL)
    PRINT 'Meeting locks part 2 (step 16) installed: App_Setting and 19 objects.';
ELSE
    PRINT 'Meeting locks part 2 (step 16): only ' + CAST(@Installed AS VARCHAR(4)) + ' of 19 objects carry the marker. Check the messages above.';
GO

SET NOEXEC OFF;
GO
