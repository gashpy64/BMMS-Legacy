/* ============================================================================
   BMMS - Agenda routing and the meeting signer (step 20)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   1. Agenda routing. A user's new agenda item waits for the user's manager
      only when that manager is active and has the Manager role (status AC).
      Otherwise it goes straight to the Controllers (status AMA, "Manager
      Approved"; the manager fields stay empty): when the user has no manager,
      or the manager is a Controller or has another role. A manager who is set
      but inactive still refuses the item (Reason 11, step 17). When it would go
      to the Controllers and no Controller is active, it is refused (Reason 15).
      The Admins keep their informational alert.

   2. Who may approve or reject (spr_UpdateAgendaByAgendaId), checked in this
      order: the system account (Reason 12, step 18), acting user missing or
      inactive (Reason 8), unknown agenda (4), agenda finalized (5), then:
        a Manager: approve or reject at AC, if the item was routed to them (they
                   have its alert) or they are the creator's current manager
        a Controller: approve at AMA; reject at AC or AMA (Agenda Finalization
                   rejects the items still waiting)
        anyone else, any other stage, or a call that approves nothing: Reason
                   14, ReasonDetail = the item's status name.
      A Controller may approve an item they created.

   3. One-time re-route: an item still waiting at AC on a meeting whose agenda
      is open, whose creator now goes straight to the Controllers, moves to AMA
      and the active Controllers get the alert. No mail. Safe to re-run.

   4. The signer: spr_GetCompanySecretary lists the In Attendance members
      (type 3) of the meeting, the first tagged first (lowest MeetingMemberId);
      callers take the first row. Every row is listed whatever its status, as
      the other member lists of the same reports do. The Invitee / Special
      Invitee list is in the same order.

   Objects (each carries the text AgendaRouting-Step20)
     fn_AgendaRoute                      NEW, the creator's route: M, C or I
     spr_GetAgendaCreationMailId         NEW, the route and the Bcc of the
                                         "agenda created" mail
     spr_AddEditAgenda                   REPLACED (steps 16, 17, 18; keeps
                                         their texts)
     spr_UpdateAgendaByAgendaId          REPLACED (steps 16, 17, 18; keeps
                                         their texts)
     spr_RerouteWaitingAgendas           NEW, the one-time re-route (run by
                                         this script)
     spr_GetCompanySecretary             REPLACED (in no numbered script)
     spr_GetMeetingMemberByMeetingIdMemberTypeId  REPLACED (in no numbered
                                         script), ordered

   The two agenda procedures return ONE row Result, Reason, ReasonDetail, as
   before. New reasons: 14 not allowed for you at this stage, 15 no active
   Controller.

   Needs steps 18, 19 and 21 and stops otherwise. Replaces nothing of step 21.
   Changes no data except the re-route (it prints the number of items moved).
   Safe to re-run. Run it BEFORE deploying the build that reads Reasons 14 and
   15 and calls spr_GetAgendaCreationMailId, and the build straight after.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%SystemAccount3-Step18%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), '') NOT LIKE '%SystemAccount3-Step18%')
BEGIN
    RAISERROR('Step 18 (BMMS-Fix-SystemAccount-Stage3.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '') NOT LIKE '%OrganisationSettings-Step19%')
BEGIN
    RAISERROR('Step 19 (BMMS-Fix-OrganisationSettings-Step19.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') NOT LIKE '%MemberTypes-Step21%')
BEGIN
    RAISERROR('Step 21 (BMMS-Fix-MemberTypes-Step21.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- Routing
-------------------------------------------------------------------------------

-- Agenda routing: one row for the creator @UserId (AgendaRouting-Step20)
--   Route M  the manager step (AC): the manager is active and has the Manager role
--         C  straight to the Controllers (AMA): no manager, or the manager is a
--            Controller or has another role
--         I  refused (Reason 11): the manager is set but inactive, whatever the role
--   ActiveControllers: active Controllers other than the protected system account
CREATE OR ALTER FUNCTION [dbo].[fn_AgendaRoute]
(
@UserId INT
)
RETURNS TABLE
AS
RETURN
SELECT
CAST(CASE WHEN m.UserId IS NULL THEN 'C'
          WHEN m.AccountStatus <> 1 THEN 'I'
          WHEN mr.RoleCode = 'manager' THEN 'M'
          ELSE 'C' END AS CHAR(1)) AS Route,
m.UserId AS ManagerId,
CAST(ISNULL(m.UserName, '') AS NVARCHAR(200)) AS ManagerName,
(SELECT COUNT(*) FROM Users c JOIN Roles cr ON cr.RoleId = c.RoleId
 WHERE cr.RoleCode = 'controller' AND c.AccountStatus = 1 AND c.IsSystem = 0) AS ActiveControllers
FROM (SELECT 1 AS One) d
LEFT JOIN Users u ON u.UserId = @UserId
LEFT JOIN Users m ON m.UserId = u.ManagerId
LEFT JOIN Roles mr ON mr.RoleId = m.RoleId;
GO

-- "Agenda created" mail of a user (AgendaRouting-Step20): the route and the Bcc addresses -
-- the manager for route M, the active Controllers for route C, none for route I. Always at least
-- one row (EmailId NULL when there is no address). Active users other than the system account only.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaCreationMailId]
@UserId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT r.Route, r.ManagerName, r.ActiveControllers, u.EmailId
	FROM dbo.fn_AgendaRoute(@UserId) r
	LEFT JOIN Users u ON u.AccountStatus = 1 AND u.IsSystem = 0 AND ISNULL(u.EmailId, '') <> ''
		AND ((r.Route = 'M' AND u.UserId = r.ManagerId)
		  OR (r.Route = 'C' AND u.UserId <> ISNULL(@UserId, 0)
		      AND u.RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode = 'controller')))
	ORDER BY u.UserId;
END
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

-- Agenda - manager / controller approve or reject; refused once the agenda is finalized,
-- for every role: no Minutes row would be created for it (MeetingLocks-Step16). New alert rows go to
-- active users only; an inactive creator's saved row is left as it is (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account; the system account cannot
-- approve or reject (Reason 12) (SystemAccount3-Step18)
-- Who may act at which stage (AgendaRouting-Step20): a Manager approves or rejects at AC an item routed
-- to them (or of whom they are the creator's manager); a Controller approves at AMA and rejects at AC or
-- AMA; anything else is refused (Reason 14, ReasonDetail the status name). An inactive or unknown acting
-- user is refused (Reason 8). A Controller may approve an item they created.
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
	DECLARE @ActingRole VARCHAR(50);
	DECLARE @StatusCode VARCHAR(50);
	DECLARE @StatusName VARCHAR(100);
	DECLARE @CreatorManagerId INT;
	DECLARE @MgrAction INT;
	DECLARE @CtlAction INT;
	DECLARE @Allowed INT;
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

		-- The protected system account takes no part in the workflow (SystemAccount3-Step18)
		IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UpdatedBy AND IsSystem = 1)
			SET @Reason = 12;
		-- Acting user missing or inactive (AgendaRouting-Step20)
		ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @UpdatedBy AND AccountStatus = 1)
			SET @Reason = 8;
		ELSE IF (@AgendaStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@AgendaStatus <> 'Open')
		BEGIN
			SET @Reason = 5;
			SET @Detail = 'Finalized';
		END
		ELSE
		BEGIN
			-- Who may act at which stage (AgendaRouting-Step20)
			SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @UpdatedBy);

			SELECT @StatusCode = a.AgendaStatusCode, @CreatorManagerId = c.ManagerId,
			       @StatusName = ISNULL(st.AgendaStatusName, ISNULL(a.AgendaStatusCode, ''))
			FROM Agenda a
			LEFT JOIN Users c ON c.UserId = a.CreatedBy
			LEFT JOIN Agenda_Status st ON st.AgendaStatusCode = a.AgendaStatusCode
			WHERE a.AgendaId = @AgendaId;

			SET @MgrAction = CASE WHEN ISNULL(@MgrApprovedStatus, '') IN ('Approved', 'Rejected') THEN 1 ELSE 0 END;
			SET @CtlAction = CASE WHEN ISNULL(@ControllerApprovedStatus, '') IN ('Approved', 'Rejected') THEN 1 ELSE 0 END;

			-- Allowed only when a rule says so: a NULL anywhere counts as not allowed
			SET @Allowed = CASE
				WHEN @MgrAction = 1 AND @CtlAction = 0 AND ISNULL(@ActingRole, '') = 'manager' AND ISNULL(@StatusCode, '') = 'AC'
				     AND (@UpdatedBy = ISNULL(@CreatorManagerId, 0)
				          OR EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
				                     WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgendaId AND m.UserId = @UpdatedBy))
				THEN 1
				WHEN @CtlAction = 1 AND @MgrAction = 0 AND ISNULL(@ActingRole, '') = 'controller'
				     AND (ISNULL(@StatusCode, '') = 'AMA'
				          OR (ISNULL(@StatusCode, '') = 'AC' AND @ControllerApprovedStatus = 'Rejected'))
				THEN 1
				ELSE 0 END;

			IF (@Allowed = 0)
			BEGIN
				SET @Reason = 14;
				SET @Detail = ISNULL(@StatusName, '');
			END
		END

		IF (@Reason = 0)
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
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1 AND IsSystem = 0);

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
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1 AND IsSystem = 0);

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
				IF EXISTS (SELECT 1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1 AND IsSystem = 0)
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

-------------------------------------------------------------------------------
-- One-time re-route of items still waiting at AC
-------------------------------------------------------------------------------

-- Re-route (AgendaRouting-Step20): an agenda item still waiting at AC on a meeting whose agenda is
-- open, whose creator now goes straight to the Controllers (route C) while a Controller is active,
-- moves to AMA (manager fields left empty); the active Controllers get the alert (unread), one
-- Audit_Trail_Master row per item by the system account. No mail. Safe to re-run: a moved item is no
-- longer AC. Returns one row: Rerouted.
CREATE OR ALTER PROCEDURE [dbo].[spr_RerouteWaitingAgendas]
AS
DECLARE @OwnTransaction INT;
DECLARE @SystemUser INT;
DECLARE @Moved TABLE (AgendaId INT PRIMARY KEY, AgendaNo VARCHAR(50), AlertId INT);
BEGIN
	SET NOCOUNT ON;

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaReroute;

		SET @SystemUser = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);

		INSERT INTO @Moved (AgendaId, AgendaNo)
		SELECT a.AgendaId, a.AgendaNo
		FROM Agenda a WITH (UPDLOCK, HOLDLOCK)
		JOIN Meeting mt WITH (UPDLOCK, HOLDLOCK) ON mt.MeetingId = a.MeetingId
		CROSS APPLY dbo.fn_AgendaRoute(a.CreatedBy) r
		WHERE a.AgendaStatusCode = 'AC'
		  AND ISNULL(mt.AgendaStatus, 'Open') = 'Open'
		  AND r.Route = 'C'
		  AND r.ActiveControllers > 0;

		UPDATE x SET AlertId = (SELECT TOP 1 am.AlertId FROM Alert_Master am
		                        WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = x.AgendaId ORDER BY am.AlertId DESC)
		FROM @Moved x;

		UPDATE a SET AgendaStatusCode = 'AMA'
		FROM Agenda a JOIN @Moved x ON x.AgendaId = a.AgendaId;

		UPDATE am SET AlertTypeCode = 'AMA'
		FROM Alert_Master am JOIN @Moved x ON x.AlertId = am.AlertId;

		INSERT INTO Alert_User_Map (AlertId, [UserId], ReadStatus, StatusId)
		SELECT x.AlertId, u.UserId, 0, 1
		FROM @Moved x
		CROSS JOIN Users u
		JOIN Roles r ON r.RoleId = u.RoleId
		WHERE x.AlertId IS NOT NULL
		  AND r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0
		  AND NOT EXISTS (SELECT 1 FROM Alert_User_Map m WHERE m.AlertId = x.AlertId AND m.UserId = u.UserId);

		INSERT INTO [Audit_Trail_Master]
		   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
		SELECT 'UP', 'Agenda', 'AgendaNo', x.AgendaNo, 'AgendaStatusCode', 'AC', 'AMA', @SystemUser, GETDATE()
		FROM @Moved x;

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
			ROLLBACK TRANSACTION AgendaReroute;

		THROW;
	END CATCH

	SELECT COUNT(*) AS Rerouted FROM @Moved;
END
GO

DECLARE @Rerouted TABLE (Rerouted INT);
DECLARE @ReroutedCount INT;
INSERT INTO @Rerouted EXEC dbo.spr_RerouteWaitingAgendas;
-- PRINT takes no subquery: read the count into a variable first
SET @ReroutedCount = ISNULL((SELECT TOP 1 Rerouted FROM @Rerouted), 0);
PRINT CAST(@ReroutedCount AS VARCHAR(12))
    + ' agenda item(s) waiting at AC moved to AMA (creator has no manager, or a manager who is not a Manager).';
GO

-------------------------------------------------------------------------------
-- The signer and the invitee lists
-------------------------------------------------------------------------------

-- The signer of notices, minutes and follow-up letters: the In Attendance members (type 3) of the meeting,
-- the first tagged first. "First tagged" is the lowest MeetingMemberId: an identity, given in insert order,
-- never reused, not changed by an edit (CreatedOn comes from the page and can repeat). Callers take the
-- first row as the signer; the minutes list every row. Every row is listed whatever its status, as the
-- other member lists of the same reports do (AgendaRouting-Step20)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetCompanySecretary]
@MeetingId INT
AS
BEGIN
	SELECT MemberName AS
	CompanySecretary,
	DesignationName,
	MeetingMemberId
	FROM View_Meeting_Member
	WHERE
	MemberTypeId = 3
	AND
	MeetingId = @MeetingId
	ORDER BY MeetingMemberId;
END
GO

-- Meeting members of one type (the minutes: Invitee 2, Special Invitee 6), in the order they were
-- tagged (AgendaRouting-Step20)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMeetingMemberByMeetingIdMemberTypeId]
@MeetingId INT,
@MemberTypeId INT
AS
BEGIN
	SELECT
	*
	FROM View_Meeting_Member
	WHERE
	MeetingId = @MeetingId
	AND
	MemberTypeId = @MemberTypeId
	ORDER BY MeetingMemberId;
END
GO

DECLARE @Installed INT = (SELECT COUNT(*) FROM sys.sql_modules
    WHERE definition LIKE '%AgendaRouting-Step20%'
    AND object_id IN (OBJECT_ID('dbo.fn_AgendaRoute'), OBJECT_ID('dbo.spr_GetAgendaCreationMailId'),
                      OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'),
                      OBJECT_ID('dbo.spr_RerouteWaitingAgendas'), OBJECT_ID('dbo.spr_GetCompanySecretary'),
                      OBJECT_ID('dbo.spr_GetMeetingMemberByMeetingIdMemberTypeId')));
DECLARE @Kept INT = (SELECT COUNT(*) FROM sys.sql_modules
    WHERE definition LIKE '%MeetingLocks-Step16%' AND definition LIKE '%UserStatus2b-Step17%' AND definition LIKE '%SystemAccount3-Step18%'
    AND object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')));

IF (@Installed = 7 AND @Kept = 2)
    PRINT 'Agenda routing (step 20) installed: 7 objects; steps 16, 17 and 18 texts kept in the 2 agenda procedures.';
ELSE
    PRINT 'Agenda routing (step 20): ' + CAST(@Installed AS VARCHAR(4)) + ' of 7 objects carry the marker, '
        + CAST(@Kept AS VARCHAR(4)) + ' of 2 agenda procedures keep the older texts. Check the messages above.';
GO

SET NOEXEC OFF;
GO
