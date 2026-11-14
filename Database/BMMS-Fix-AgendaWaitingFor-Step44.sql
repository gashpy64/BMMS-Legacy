/* ============================================================================
   BMMS - Dashboard "My approvals" and "Waiting for me": one rule for who may
   approve an agenda item (step 44, step UN6c2a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision UN6c2 (2026-11-13, plan approved, split into UN6c2a = this
   step and UN6c2b = step 45): the Dashboard shows a Controller and a Manager
   the agenda items that wait for their approval, in a panel and as a column
   of the meeting list. The panel, the column, the Approve and Reject buttons
   and the approval itself must always agree, so the rule is ONE function.

   Three new objects:

     fn_AgendaWaitingFor(@UserId INT, @Today DATE)   inline table function
         The items the user may decide, by the rules of step 20 (unchanged):
           Manager      an item at AC of which he is the creator's manager
                        (Users.ManagerId) or for whose alert he has a row in
                        Alert_User_Map (also a row he removed from his list);
                        he may approve and reject it. The department plays no
                        part (step UD1b will change this rule, here only).
           Controller   an item at AMA (approve or reject) or at AC (reject).
         Nothing for any other role, for an inactive user and for the
         protected system account. Columns: CanApprove, CanReject, AgendaOpen
         (the meeting's agenda is still Open), DateOpen (the meeting has no
         date, or its date is @Today or later) and IsWaiting = CanApprove and
         AgendaOpen and DateOpen: the items of the panel and the column.
         @Today is the DATABASE server's date in every caller.

     spr_GetAgendaApprovalState                    the Agenda Alert panel
         @ActingUserId, @AgendaId; OUTPUT @Result, @Reason, @CanApprove,
         @CanReject, @AgendaOpen, @DateOpen. The page shows Approve and
         Reject from this answer and no longer by a rule of its own.

     spr_GetDashboardApprovals                     the My approvals panel
         @ActingUserId, @CommitteeId, @DepartmentId, @PageNo; OUTPUT @Result,
         @Reason, @TotalRows, @PageShown. The IsWaiting items, newest meeting
         first, a page of 10 (ROW_NUMBER). @CommitteeId 0 = every committee,
         otherwise it must exist; @DepartmentId 0 = no department filter,
         otherwise a Manager's own department (fn_UserDepartmentScope).

     Reason 12  the acting user is the protected system account (checked as a
                system account, before the role)
     Reason 8   the acting user is missing, 0 or inactive
     Reason 4   a role without the panel (anyone but Controller and Manager);
                an unknown committee; a department that is not the Manager's
                (or any department for a Controller); a page number below 1;
                for the state: an unknown agenda item
     A refused call returns the same columns with no rows and changes nothing.

   Two procedures of earlier steps are REPLACED (their texts as installed,
   with the changes named below; BMMS-Rollback-AgendaWaitingFor-Step44.sql
   puts the earlier texts back, letter for letter):

     spr_UpdateAgendaByAgendaId    Approve and Reject (steps 16 to 35). The
         test "may this user act on this item" now reads fn_AgendaWaitingFor.
         The rules, the order of the refusals (12, 8, 4, 5, 14) and everything
         that is written are unchanged; the Test script runs the earlier text
         beside this one on the same cases and compares every result. The
         meeting date is NOT checked here, as before (the page checks it).
     spr_GetDashboardMeetings      the Dashboard's meeting list (step 42).
         One more column, WaitingForMe (last), and one more output,
         @WaitingShown (last, optional): the count of IsWaiting items of a
         scheduled meeting for a Controller and a Manager; NULL otherwise.

   The script stops when one of the two is neither the text this step was
   built from nor already the step 44 text (a later change would be lost).
   Both keep the markers of their earlier steps.

   EXECUTE permission: as steps 42 and 43, the script grants nothing. The
   application login holds EXECUTE on the schema dbo.

   Changes no data. Safe to re-run. Installed after step 43 (it stops
   otherwise). Install BEFORE the build of step UN6c2a: that build calls the
   new objects. The earlier build keeps working with step 44 installed.

   Marker AgendaWaitingFor-Step44 in each object (5 markers in
   BMMS-Check-InstalledSteps.sql).

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

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') NOT LIKE '%DashboardAlerts-Step43%'
         OR OBJECT_ID('dbo.fn_UserDepartmentScope', 'IF') IS NULL
         OR OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId', 'P') IS NULL OR OBJECT_ID('dbo.spr_GetDashboardMeetings', 'P') IS NULL)
BEGIN
    RAISERROR('Step 43 (BMMS-Fix-DashboardAlerts-Step43.sql) is not installed in "%s", or an earlier step is missing (spr_GetDashboardMeetings and fn_UserDepartmentScope of step 42, spr_UpdateAgendaByAgendaId). The steps are installed in order: run them first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF ((@AgendaHash <> '763564301F411D7CC3D94064BB115F4C23EC028A757040AD9F753B4E63B8652C378D7B74305741E8A4D1FE63C03B201B1FEDB06B4DA27D7EB55874F4'
          AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), '') NOT LIKE '%AgendaWaitingFor-Step44%')
         OR (@MeetHash <> 'A174C0B06EA28F9C2B914B6C581F74D2D1F4788A4BDBA6D90C4878E28B72831FFC6C1866F007CE47'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') NOT LIKE '%AgendaWaitingFor-Step44%'))
BEGIN
    RAISERROR('spr_UpdateAgendaByAgendaId or spr_GetDashboardMeetings in "%s" is not the text this step was built from (steps 35 and 42) and not the step 44 text either: a change made since would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Who may decide an agenda item (AgendaWaitingFor-Step44, step UN6c2a): the one rule for the approval itself
-- (spr_UpdateAgendaByAgendaId), the Dashboard's My approvals panel, its Waiting for me column and the Approve and
-- Reject buttons of the Agenda Alert panel. The rules of step 20, unchanged:
--   Manager      an item at AC of which he is the creator's manager (Users.ManagerId) or for whose alert he has a
--                row in Alert_User_Map (any row, also one he removed from his list): approve and reject;
--   Controller   an item at AMA: approve and reject; an item at AC: reject only.
-- No rows for another role, an inactive user or the protected system account. AgendaOpen: the meeting's agenda is
-- still Open. DateOpen: the meeting has no date or its date is @Today or later (the callers pass the database
-- server's date). IsWaiting: CanApprove and AgendaOpen and DateOpen - what the panel and the column show.
-- Step UD1b (every Manager of the item's department) changes the Manager rule here and nowhere else.
CREATE OR ALTER FUNCTION [dbo].[fn_AgendaWaitingFor]
(
@UserId INT,
@Today DATE
)
RETURNS TABLE
AS
RETURN
SELECT
x.AgendaId,
x.MeetingId,
x.CommitteeId,
x.DepartmentId,
x.AgendaStatusCode,
x.UserId,
x.CanApprove,
x.CanReject,
x.AgendaOpen,
x.DateOpen,
CAST(CASE WHEN x.CanApprove = 1 AND x.AgendaOpen = 1 AND x.DateOpen = 1 THEN 1 ELSE 0 END AS INT) AS IsWaiting
FROM (SELECT
      a.AgendaId,
      a.MeetingId,
      a.CommitteeId,
      a.DepartmentId,
      a.AgendaStatusCode,
      u.UserId,
      CAST(CASE WHEN r.RoleCode = 'manager' THEN 1
                WHEN r.RoleCode = 'controller' AND a.AgendaStatusCode = 'AMA' THEN 1
                ELSE 0 END AS INT) AS CanApprove,
      CAST(1 AS INT) AS CanReject,
      CAST(CASE WHEN m.MeetingId IS NOT NULL AND ISNULL(m.AgendaStatus, 'Open') = 'Open' THEN 1 ELSE 0 END AS INT) AS AgendaOpen,
      CAST(CASE WHEN m.MeetingId IS NOT NULL AND (m.MeetingDate IS NULL OR CAST(m.MeetingDate AS DATE) >= @Today) THEN 1 ELSE 0 END AS INT) AS DateOpen
      FROM Users u
      INNER JOIN Roles r ON r.RoleId = u.RoleId
      CROSS JOIN Agenda a
      LEFT JOIN Meeting m ON m.MeetingId = a.MeetingId
      LEFT JOIN Users c ON c.UserId = a.CreatedBy
      WHERE u.UserId = @UserId
      AND u.AccountStatus = 1
      AND u.IsSystem = 0
      AND ((r.RoleCode = 'manager'
            AND a.AgendaStatusCode = 'AC'
            AND (c.ManagerId = u.UserId
                 OR EXISTS (SELECT 1 FROM Alert_User_Map mp INNER JOIN Alert_Master am ON am.AlertId = mp.AlertId
                            WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId AND mp.UserId = u.UserId)))
           OR (r.RoleCode = 'controller'
               AND a.AgendaStatusCode IN ('AC', 'AMA')))) x;
GO

-- What the acting user may do with one agenda item (AgendaWaitingFor-Step44, step UN6c2a): the Agenda Alert panel
-- of the Dashboard shows Approve and Reject from this answer (fn_AgendaWaitingFor), so the buttons, the My approvals
-- panel and the approval itself agree. @AgendaOpen and @DateOpen describe the item's meeting for every caller.
-- Reason 12: the protected system account. Reason 8: acting user missing, 0 or inactive. Reason 4: the item does
-- not exist. Then every flag is 0.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaApprovalState]
@ActingUserId INT = NULL,
@AgendaId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@CanApprove INT = NULL OUTPUT,
@CanReject INT = NULL OUTPUT,
@AgendaOpen INT = NULL OUTPUT,
@DateOpen INT = NULL OUTPUT
AS
DECLARE @Today DATE;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @CanApprove = 0;
	SET @CanReject = 0;
	SET @AgendaOpen = 0;
	SET @DateOpen = 0;
	SET @Today = CAST(GETDATE() AS DATE);

	IF EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND IsSystem = 1)
		SET @Reason = 12;
	ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF NOT EXISTS (SELECT 1 FROM Agenda WHERE AgendaId = @AgendaId)
		SET @Reason = 4;
	ELSE
	BEGIN
		SELECT
		@AgendaOpen = CASE WHEN m.MeetingId IS NOT NULL AND ISNULL(m.AgendaStatus, 'Open') = 'Open' THEN 1 ELSE 0 END,
		@DateOpen = CASE WHEN m.MeetingId IS NOT NULL AND (m.MeetingDate IS NULL OR CAST(m.MeetingDate AS DATE) >= @Today) THEN 1 ELSE 0 END
		FROM Agenda a
		LEFT JOIN Meeting m ON m.MeetingId = a.MeetingId
		WHERE a.AgendaId = @AgendaId;

		SELECT @CanApprove = w.CanApprove, @CanReject = w.CanReject
		FROM dbo.fn_AgendaWaitingFor(@ActingUserId, @Today) w
		WHERE w.AgendaId = @AgendaId;

		SET @Result = 1;
	END
END
GO

-- Dashboard My approvals panel (AgendaWaitingFor-Step44, step UN6c2a): the items that wait for the acting user's
-- approval (fn_AgendaWaitingFor, IsWaiting: he may approve, the agenda is open, the meeting date has not passed),
-- newest meeting first, a page of 10. @CommitteeId 0: every committee; otherwise it must exist. @DepartmentId 0: no
-- department filter; otherwise one of a Manager's departments (fn_UserDepartmentScope). AlertId: the item's alert
-- (the page marks the acting user's own row of it read when the item is opened).
-- Reason 12: the protected system account. Reason 8: acting user missing, 0 or inactive. Reason 4: a role without
-- the panel (anyone but Controller and Manager), a filter that is not allowed, a page number below 1. A refused
-- call returns the same columns with no rows. A page number past the end gives the last page (@PageShown).
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardApprovals]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@DepartmentId INT = 0,
@PageNo INT = 1,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@TotalRows INT = NULL OUTPUT,
@PageShown INT = NULL OUTPUT
AS
DECLARE @Today DATE;
DECLARE @RoleCode VARCHAR(50);
DECLARE @PageSize INT;
DECLARE @Rows TABLE (RowNo INT PRIMARY KEY, AgendaId INT);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @TotalRows = 0;
	SET @PageShown = 1;
	SET @PageSize = 10;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	IF EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND IsSystem = 1)
		SET @Reason = 12;
	ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (ISNULL(@RoleCode, '') NOT IN ('controller', 'manager'))
		SET @Reason = 4;
	ELSE IF (@CommitteeId < 0
	         OR (@CommitteeId > 0 AND NOT EXISTS (SELECT 1 FROM Committee WHERE CommitteeId = @CommitteeId)))
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @RoleCode <> 'manager')
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE IF (@PageNo IS NULL OR @PageNo < 1)
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	IF (@Result = 1)
	BEGIN
		INSERT INTO @Rows (RowNo, AgendaId)
		SELECT ROW_NUMBER() OVER (ORDER BY m.MeetingDate DESC, m.MeetingId DESC, a.AgendaNo, a.AgendaId), a.AgendaId
		FROM dbo.fn_AgendaWaitingFor(@ActingUserId, @Today) w
		INNER JOIN Agenda a ON a.AgendaId = w.AgendaId
		INNER JOIN Meeting m ON m.MeetingId = a.MeetingId
		WHERE w.IsWaiting = 1
		AND (@CommitteeId = 0 OR a.CommitteeId = @CommitteeId)
		AND (@DepartmentId = 0 OR a.DepartmentId = @DepartmentId);

		SET @TotalRows = @@ROWCOUNT;
		SET @PageShown = CASE WHEN @TotalRows = 0 THEN 1
		                      WHEN @PageNo > (@TotalRows + @PageSize - 1) / @PageSize THEN (@TotalRows + @PageSize - 1) / @PageSize
		                      ELSE @PageNo END;
	END

	SELECT
	x.RowNo,
	a.AgendaId,
	a.AgendaNo,
	a.SubjectNo,
	a.ShortText,
	a.AgendaStatusCode,
	a.CommitteeId,
	c.CommitteeCode,
	c.CommitteeName,
	a.MeetingId,
	m.MeetingNo,
	m.MeetingDate,
	a.DepartmentId,
	d.DepartmentName,
	(SELECT TOP 1 am.AlertId FROM Alert_Master am
	 WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId ORDER BY am.AlertId) AS AlertId
	FROM @Rows x
	INNER JOIN Agenda a ON a.AgendaId = x.AgendaId
	INNER JOIN Meeting m ON m.MeetingId = a.MeetingId
	LEFT JOIN Committee c ON c.CommitteeId = a.CommitteeId
	LEFT JOIN Department d ON d.DepartmentId = a.DepartmentId
	WHERE @Result = 1
	AND x.RowNo > (@PageShown - 1) * @PageSize
	AND x.RowNo <= @PageShown * @PageSize
	ORDER BY x.RowNo;
END
GO

-- The two batches below are the texts of steps 35 and 42 with the changes of step 44 (marked AgendaWaitingFor-Step44).
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
-- AgendaWaitingFor-Step44 (step UN6c2a): who may act on the item is read from fn_AgendaWaitingFor, the one rule for
-- this check, the Dashboard's My approvals panel, its Waiting for me column and the Approve and Reject buttons. The
-- rules are those of step 20, unchanged; the order of the refusals and everything that is written are unchanged.
-- The meeting date is NOT checked here (the page checks it, step M6a), as before.
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
	DECLARE @Today DATE;
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

			-- Allowed only when the rule says so (AgendaWaitingFor-Step44: the rule is fn_AgendaWaitingFor; a Manager's
			-- row there may approve and reject; a Controller's row may approve at AMA and reject at AC or AMA)
			SET @Today = CAST(GETDATE() AS DATE);
			SET @Allowed = CASE
				WHEN @MgrAction = 1 AND @CtlAction = 0 AND ISNULL(@ActingRole, '') = 'manager'
				     AND EXISTS (SELECT 1 FROM dbo.fn_AgendaWaitingFor(@UpdatedBy, @Today) w
				                 WHERE w.AgendaId = @AgendaId AND w.CanApprove = 1)
				THEN 1
				WHEN @CtlAction = 1 AND @MgrAction = 0 AND ISNULL(@ActingRole, '') = 'controller'
				     AND EXISTS (SELECT 1 FROM dbo.fn_AgendaWaitingFor(@UpdatedBy, @Today) w
				                 WHERE w.AgendaId = @AgendaId
				                 AND ((@ControllerApprovedStatus = 'Approved' AND w.CanApprove = 1)
				                      OR (@ControllerApprovedStatus = 'Rejected' AND w.CanReject = 1)))
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
-- AgendaWaitingFor-Step44 (step UN6c2a): the column WaitingForMe (last) and the output @WaitingShown (last): for a
-- Controller and a Manager the number of items of a SCHEDULED meeting that wait for this person's approval
-- (fn_AgendaWaitingFor, IsWaiting; for a Manager within the chosen department); NULL on completed meetings and for
-- every other role (@WaitingShown 0). Everything else is unchanged.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardMeetings]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@DepartmentId INT = 0,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@StatisticsShown INT = NULL OUTPUT,
@ActingRoleCode VARCHAR(50) = NULL OUTPUT,
@WaitingShown INT = NULL OUTPUT
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
	SET @WaitingShown = 0;
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
		SET @WaitingShown = CASE WHEN @ActingRole IN ('controller', 'manager') THEN 1 ELSE 0 END;
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
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Pending, 0) END AS INT) AS Pending,
	CAST(CASE WHEN @WaitingShown = 1 AND l.ListCode = 'S' THEN ISNULL(w.Waiting, 0) END AS INT) AS WaitingForMe
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
	LEFT JOIN (SELECT wf.MeetingId, COUNT(*) AS Waiting
	           FROM dbo.fn_AgendaWaitingFor(@ActingUserId, @Today) wf
	           WHERE @WaitingShown = 1
	           AND wf.IsWaiting = 1
	           AND (@DepartmentId = 0 OR wf.DepartmentId = @DepartmentId)
	           GROUP BY wf.MeetingId) w ON w.MeetingId = m.MeetingId
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

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_AgendaWaitingFor')), '') LIKE '%AgendaWaitingFor-Step44%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaApprovalState')), '') LIKE '%AgendaWaitingFor-Step44%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), '') LIKE '%AgendaWaitingFor-Step44%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), '') LIKE '%AgendaWaitingFor-Step44%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') LIKE '%AgendaWaitingFor-Step44%')
    SET @Installed = @Installed + 1;

IF (@Installed = 5)
    PRINT 'Step 44 installed: fn_AgendaWaitingFor, spr_GetAgendaApprovalState and spr_GetDashboardApprovals are new; spr_UpdateAgendaByAgendaId reads its routing rule from the function and spr_GetDashboardMeetings has the column WaitingForMe (AgendaWaitingFor-Step44).';
ELSE
    RAISERROR('Step 44 is not complete: %d of 5 objects carry the marker AgendaWaitingFor-Step44. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
