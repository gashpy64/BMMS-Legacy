/* ============================================================================
   BMMS - Roll back step 44 (Dashboard My approvals and Waiting for me,
   step UN6c2a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Puts back the two procedures step 44 replaced, letter for letter as steps
   35 and 42 installed them:
     spr_UpdateAgendaByAgendaId   (its own routing test again)
     spr_GetDashboardMeetings     (without the column WaitingForMe)
   and drops the three new objects of step 44:
     spr_GetDashboardApprovals, spr_GetAgendaApprovalState, fn_AgendaWaitingFor
   At its end the script compares the restored texts with the texts step 44
   was built from (SHA-1, carriage returns left out, in pieces of 4,000
   characters) and says so.

   Roll back the application build of step UN6c2a first or at the same time:
   that build calls the new objects for the My approvals panel, the Waiting
   for me column and the Approve and Reject buttons; without them the panel
   shows its "could not be loaded" message, the meeting list fails to load
   and no item can be approved from the Dashboard.

   Changes no data. Safe to re-run. BMMS-Check-InstalledSteps.sql then shows
   step 44 Missing; steps 16 to 43 stay Installed.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS", and when step 44 is not
   installed (nothing to roll back). Plain ASCII. From the command line use
   sqlcmd -I.
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
ELSE IF (OBJECT_ID('dbo.fn_AgendaWaitingFor', 'IF') IS NULL
         AND OBJECT_ID('dbo.spr_GetAgendaApprovalState', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_GetDashboardApprovals', 'P') IS NULL
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), '') NOT LIKE '%AgendaWaitingFor-Step44%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') NOT LIKE '%AgendaWaitingFor-Step44%')
BEGIN
    RAISERROR('Step 44 is not installed in "%s" (none of its three new objects exists and the two replaced procedures do not carry its marker): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId', 'P') IS NULL OR OBJECT_ID('dbo.spr_GetDashboardMeetings', 'P') IS NULL)
BEGIN
    RAISERROR('spr_UpdateAgendaByAgendaId or spr_GetDashboardMeetings is missing in "%s": this is not a database step 44 was installed in. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- The two batches below are the texts of steps 35 and 42, unchanged. Do not tidy them: the comparison at the end
-- is letter for letter. They come first: while they run, the function they no longer read is still there.
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
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX))
-- CommentAuthor-Step35: Approve and Reject record who decided and when, also with an empty comment: MgrApprovedBy and
-- MgrApprovedDate (Manager), ControllerApprovedBy and ControllerApprovedDate (Controller) are @UpdatedBy and GETDATE()
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateAgendaByAgendaId]
@AgendaId INT,
@ShortText NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
@ControllerApprovedStatus varchar(50),
@MgrApprovedStatus varchar(50),
@UpdatedBy INT
AS
	DECLARE @AlertId INT
	DECLARE @User_Id INT
	DECLARE @MgrCommentsOld NVARCHAR(MAX)
	DECLARE @ControllerCommentsOld NVARCHAR(MAX)
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
					MgrApprovedBy = @UpdatedBy, MgrApprovedDate = GETDATE(),   -- CommentAuthor-Step35
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
					MgrApprovedBy = @UpdatedBy, MgrApprovedDate = GETDATE(),   -- CommentAuthor-Step35
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
					ControllerApprovedBy = @UpdatedBy, ControllerApprovedDate = GETDATE(),   -- CommentAuthor-Step35
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

-- Dashboard meeting list (DashboardMeetings-Step42, step UN6b), for all six roles. The role and the departments come
-- from the database (the acting user id); the two filters are checked against them:
--   @CommitteeId   0: every committee; otherwise it must exist (any role), else Reason 4
--   @DepartmentId  0: all of a Manager's or a User's departments; otherwise it must be one of them (Manager and User
--                  only), else Reason 4
-- Reason 8: acting user missing or inactive; Reason 4: a role outside the six or a filter outside the scope; then
-- no rows. Rows: every scheduled meeting (no cap), then the last 10 completed meetings for EVERY role (for a Manager
-- and a User only completed meetings with an item of the chosen department(s)). Statistics (fn_AgendaStatusGroup,
-- Pending = AC + AMA) for the Controller, Management, the Manager and the User (for the last two over the chosen
-- department(s) only); NULL and @StatisticsShown 0 for MD Secretariat and Admin.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardMeetings]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@DepartmentId INT = 0,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@StatisticsShown INT = NULL OUTPUT,
@ActingRoleCode VARCHAR(50) = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
DECLARE @Today DATE;
DECLARE @DeptScoped INT;
DECLARE @Dept TABLE (DepartmentId INT PRIMARY KEY);
DECLARE @List TABLE (MeetingId INT PRIMARY KEY, ListCode CHAR(1));
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @StatisticsShown = 0;
	SET @ActingRoleCode = NULL;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);

	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);
	SET @DeptScoped = CASE WHEN @ActingRole IN ('manager', 'user') THEN 1 ELSE 0 END;

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN ('admin', 'controller', 'manager', 'user', 'mgmt', 'md_sect'))
		SET @Reason = 4;
	ELSE IF (@CommitteeId < 0
	         OR (@CommitteeId > 0 AND NOT EXISTS (SELECT 1 FROM Committee WHERE CommitteeId = @CommitteeId)))
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @DeptScoped = 0)
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE
	BEGIN
		SET @Result = 1;
		SET @StatisticsShown = CASE WHEN @ActingRole IN ('controller', 'mgmt', 'manager', 'user') THEN 1 ELSE 0 END;
	END

	-- The role of an active user is returned even when a filter is refused (the page words its message by it)
	IF (@ActingRole IN ('admin', 'controller', 'manager', 'user', 'mgmt', 'md_sect'))
		SET @ActingRoleCode = @ActingRole;

	IF (@Result = 1 AND @DeptScoped = 1)
		INSERT INTO @Dept (DepartmentId)
		SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
		WHERE @DepartmentId = 0 OR s.DepartmentId = @DepartmentId;

	-- Scheduled: every one (no cap)
	INSERT INTO @List (MeetingId, ListCode)
	SELECT m.MeetingId, 'S'
	FROM Meeting m
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	WHERE @Result = 1
	AND st.IsScheduled = 1
	AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId);

	-- Completed: the last 10, for every role
	INSERT INTO @List (MeetingId, ListCode)
	SELECT TOP (10) m.MeetingId, 'C'
	FROM Meeting m
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	WHERE @Result = 1
	AND st.IsScheduled = 0
	AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId)
	AND (@DeptScoped = 0
	     OR EXISTS (SELECT 1 FROM Agenda a INNER JOIN @Dept d ON d.DepartmentId = a.DepartmentId
	                WHERE a.MeetingId = m.MeetingId))
	ORDER BY m.MeetingDate DESC, m.MeetingTime DESC, m.MeetingId DESC;

	SELECT
	m.MeetingId,
	m.CommitteeId,
	c.CommitteeCode,
	c.CommitteeName,
	m.MeetingNo,
	m.MeetingDate,
	m.MeetingTime,
	m.AgendaSubmissionDate,
	l.ListCode,
	st.StateCode,
	st.StateLabel,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Items, 0) END AS INT) AS Items,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Approved, 0) END AS INT) AS Approved,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Rejected, 0) END AS INT) AS Rejected,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Pending, 0) END AS INT) AS Pending
	FROM @List l
	INNER JOIN Meeting m ON m.MeetingId = l.MeetingId
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	LEFT JOIN (SELECT ag.MeetingId,
	                  COUNT(*) AS Items,
	                  SUM(CASE WHEN ag.StatusGroup = 'approved' THEN 1 ELSE 0 END) AS Approved,
	                  SUM(CASE WHEN ag.StatusGroup = 'rejected' THEN 1 ELSE 0 END) AS Rejected,
	                  SUM(CASE WHEN ag.StatusGroup = 'in progress' THEN 1 ELSE 0 END) AS Pending
	           FROM dbo.fn_AgendaStatusGroup() ag
	           INNER JOIN @List gl ON gl.MeetingId = ag.MeetingId
	           WHERE @StatisticsShown = 1
	           AND (@DeptScoped = 0 OR ag.DepartmentId IN (SELECT DepartmentId FROM @Dept))
	           GROUP BY ag.MeetingId) g ON g.MeetingId = m.MeetingId
	ORDER BY
	CASE l.ListCode WHEN 'S' THEN 0 ELSE 1 END,
	CASE WHEN l.ListCode = 'S' THEN m.MeetingDate END ASC,
	CASE WHEN l.ListCode = 'S' THEN m.MeetingTime END ASC,
	CASE WHEN l.ListCode = 'S' THEN m.MeetingId END ASC,
	CASE WHEN l.ListCode = 'C' THEN m.MeetingDate END DESC,
	CASE WHEN l.ListCode = 'C' THEN m.MeetingTime END DESC,
	CASE WHEN l.ListCode = 'C' THEN m.MeetingId END DESC;
END
GO

-- The procedures first, the function they read last
IF OBJECT_ID('dbo.spr_GetDashboardApprovals', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetDashboardApprovals;
IF OBJECT_ID('dbo.spr_GetAgendaApprovalState', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetAgendaApprovalState;
IF OBJECT_ID('dbo.fn_AgendaWaitingFor', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_AgendaWaitingFor;
GO

DECLARE @Left INT = 0;
DECLARE @D NVARCHAR(MAX), @I INT;
DECLARE @AgendaHash VARCHAR(400), @MeetHash VARCHAR(400);

-- The two procedures as they are now: SHA-1 of the text without carriage returns, in pieces of 4,000 characters
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), CHAR(13), ''); SET @AgendaHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @AgendaHash = @AgendaHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), CHAR(13), ''); SET @MeetHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @MeetHash = @MeetHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END

IF (OBJECT_ID('dbo.spr_GetDashboardApprovals', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetAgendaApprovalState', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.fn_AgendaWaitingFor', 'IF') IS NOT NULL) SET @Left = @Left + 1;

IF (@Left > 0)
    RAISERROR('Step 44 is not fully rolled back: %d of its three new objects are still there. Read the messages above and run the script again.', 16, 1, @Left);
ELSE IF (ISNULL(@AgendaHash, '') <> '763564301F411D7CC3D94064BB115F4C23EC028A757040AD9F753B4E63B8652C378D7B74305741E8A4D1FE63C03B201B1FEDB06B4DA27D7EB55874F4'
         OR ISNULL(@MeetHash, '') <> 'A174C0B06EA28F9C2B914B6C581F74D2D1F4788A4BDBA6D90C4878E28B72831FFC6C1866F007CE47')
    RAISERROR('Step 44: the three new objects are dropped, but spr_UpdateAgendaByAgendaId or spr_GetDashboardMeetings is NOT letter for letter the text of steps 35 and 42 (SHA-1 differs). Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 44 rolled back: the three new objects are dropped; spr_UpdateAgendaByAgendaId and spr_GetDashboardMeetings are again the texts of steps 35 and 42, letter for letter (SHA-1 compared).';
GO

SET NOEXEC OFF;
GO
