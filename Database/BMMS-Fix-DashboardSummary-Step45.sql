/* ============================================================================
   BMMS - Dashboard summary cards, the Committee and Department filters on
   every Dashboard card, statistics for the MD Secretariat (step 45, step
   UN6c2b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decisions UN6c2b (2026-11-13 and 2026-11-14, plan approved
   2026-11-14 with changes):
     - Summary cards at the top of the Dashboard: "items in progress" and
       "items rejected" of SCHEDULED meetings (the rule of the meeting list,
       fn_MeetingDashboardState.IsScheduled), by the one status definition
       fn_AgendaStatusGroup, following the Committee filter and, for a
       Manager, the Department filter. For the Controller, Management, the
       Manager and the User; none for the MD Secretariat and the Admin.
       (The third card, "Unread alerts", is the count the Alerts card already
       reads; it follows no filter and is not part of this step.)
     - The Committee filter takes only an ACTIVE committee (before: any
       committee that exists). An unknown, inactive or negative committee id
       is refused with Reason 4 by every Dashboard procedure that takes it.
     - The Action Items card follows the Committee filter and the Department
       filter (the department rule of the meeting list: a Manager's or a
       User's own department, Reason 4 otherwise).
     - The MD Secretariat sees the per-meeting statistics (Items, Approved,
       Rejected, In progress) for all departments and committees, read-only,
       as Management. No "Waiting for me", no My approvals, no Action Items.

   Two new objects:

     fn_DashboardCommitteeFilter(@CommitteeId INT)   inline table function
         One row, Allowed: 1 for 0 (every committee) and for the id of an
         active committee (Committee.StatusId 1); 0 for anything else. The
         one rule of the Committee filter of the four procedures below.

     spr_GetDashboardSummary                         the two summary cards
         @ActingUserId, @CommitteeId, @DepartmentId; OUTPUT @Result, @Reason,
         @InProgress, @Rejected (NULL when refused). The counts are exactly
         the totals of the columns In progress and Rejected of the Scheduled
         list of spr_GetDashboardMeetings for the same filters.

     Reason 12  the acting user is the protected system account
     Reason 8   the acting user is missing, 0 or inactive
     Reason 4   a role without the cards (MD Secretariat, Admin, any other);
                a committee that is not active or unknown; a department
                outside the person's scope (or any department for a
                Controller or Management)

   Three procedures of earlier steps are REPLACED (their texts as installed,
   with the changes named below; BMMS-Rollback-DashboardSummary-Step45.sql
   puts the earlier texts back, letter for letter):

     spr_GetDashboardMeetings      (steps 42 and 44) the Committee filter by
         fn_DashboardCommitteeFilter; StatisticsShown 1 for the MD
         Secretariat. Parameters, columns, WaitingForMe and everything else
         are unchanged.
     spr_GetDashboardApprovals     (step 44) the Committee filter by
         fn_DashboardCommitteeFilter. Nothing else changes.
     spr_GetDashboardActionItems   (step 43) two more parameters, last and
         optional: @CommitteeId INT = 0 and @DepartmentId INT = 0, checked
         as in spr_GetDashboardMeetings and applied to the rows of
         fn_DashboardActionItems (which is not changed). With both 0 the rows
         are those of step 43.

   The script stops when one of the three is neither the text this step was
   built from nor already the step 45 text (a later change would be lost).
   Each keeps the markers of its earlier steps.

   EXECUTE permission: as steps 42 to 44, the script grants nothing. The
   application login holds EXECUTE on the schema dbo.

   Changes no data. Safe to re-run. Installed after step 44 (it stops
   otherwise). Install BEFORE the build of step UN6c2b: that build calls the
   new objects and the new parameters. The earlier build keeps working with
   step 45 installed (the new parameters are optional).

   Rolling back: BMMS-Rollback-DashboardSummary-Step45.sql. It must run
   before any rollback of steps 44 and 43 (the step 44 Rollback refuses while
   step 45 is installed).

   Marker DashboardSummary-Step45 in each object (5 markers in
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
DECLARE @MeetHash VARCHAR(400), @ApprHash VARCHAR(400), @ActHash VARCHAR(400);

-- The three procedures as they are now: SHA-1 of the text without carriage returns, in pieces of 4,000 characters
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), CHAR(13), ''); SET @MeetHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @MeetHash = @MeetHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), CHAR(13), ''); SET @ApprHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @ApprHash = @ApprHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), CHAR(13), ''); SET @ActHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @ActHash = @ActHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_AgendaWaitingFor', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), '') NOT LIKE '%AgendaWaitingFor-Step44%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') NOT LIKE '%AgendaWaitingFor-Step44%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') NOT LIKE '%DashboardAlerts-Step43%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') NOT LIKE '%DashboardAlerts-Step43%'
         OR OBJECT_ID('dbo.fn_AgendaStatusGroup', 'IF') IS NULL
         OR OBJECT_ID('dbo.fn_MeetingDashboardState', 'IF') IS NULL
         OR OBJECT_ID('dbo.fn_UserDepartmentScope', 'IF') IS NULL)
BEGIN
    RAISERROR('Step 44 (BMMS-Fix-AgendaWaitingFor-Step44.sql) is not installed in "%s", or an earlier step is missing (the Dashboard objects of steps 42 and 43). The steps are installed in order: run them first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF ((@MeetHash <> '018126C666059C775382F2D990FD0E6894CB1960A0DBD4D95E46DC9E033221FEA12D64364BED4928'
          AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') NOT LIKE '%DashboardSummary-Step45%')
         OR (@ApprHash <> 'B39CC2B64BCF0068CA13908C21302FC1212452A7'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), '') NOT LIKE '%DashboardSummary-Step45%')
         OR (@ActHash <> 'A3117268FEA43FAB4F7FA858DAD14CA978FB0D02'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') NOT LIKE '%DashboardSummary-Step45%'))
BEGIN
    RAISERROR('spr_GetDashboardMeetings, spr_GetDashboardApprovals or spr_GetDashboardActionItems in "%s" is not the text this step was built from (steps 44 and 43) and not the step 45 text either: a change made since would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- The Committee filter of the Dashboard (DashboardSummary-Step45, step UN6c2b): the one rule of spr_GetDashboardMeetings,
-- spr_GetDashboardSummary, spr_GetDashboardApprovals and spr_GetDashboardActionItems. Allowed 1: @CommitteeId 0 (every
-- committee) or the id of an active committee (Committee.StatusId 1). Allowed 0: an inactive, unknown, negative or NULL
-- id. "Every committee" (0) lists the meetings of inactive committees as well; only a CHOSEN committee must be active.
CREATE OR ALTER FUNCTION [dbo].[fn_DashboardCommitteeFilter]
(
@CommitteeId INT
)
RETURNS TABLE
AS
RETURN
SELECT
CAST(CASE WHEN @CommitteeId = 0 THEN 1
          WHEN EXISTS (SELECT 1 FROM Committee c WHERE c.CommitteeId = @CommitteeId AND c.StatusId = 1) THEN 1
          ELSE 0 END AS INT) AS Allowed;
GO

-- Dashboard summary cards (DashboardSummary-Step45, step UN6c2b): the items of SCHEDULED meetings (the rule of the
-- meeting list: fn_MeetingDashboardState.IsScheduled, a meeting dated today or later or without a date) that are in
-- progress (AC, AMA) and rejected (AMR, ACR), by the one definition fn_AgendaStatusGroup. The role and the departments
-- come from the database (the acting user id); the two filters are checked as in spr_GetDashboardMeetings:
--   @CommitteeId   0: every committee; otherwise an active committee (fn_DashboardCommitteeFilter), else Reason 4
--   @DepartmentId  0: all of a Manager's or a User's departments; otherwise one of them (Manager and User only),
--                  else Reason 4
-- Controller and Management: every department. Manager and User: the chosen department(s) (fn_UserDepartmentScope).
-- @InProgress and @Rejected are the totals of the columns In progress (Pending) and Rejected of the Scheduled list of
-- spr_GetDashboardMeetings for the same filters. Reason 12: the protected system account; Reason 8: acting user
-- missing, 0 or inactive; Reason 4: a role without the cards (MD Secretariat, Admin), a filter outside the scope. A
-- refused call leaves both counts NULL.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardSummary]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@DepartmentId INT = 0,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@InProgress INT = NULL OUTPUT,
@Rejected INT = NULL OUTPUT
AS
DECLARE @Today DATE;
DECLARE @RoleCode VARCHAR(50);
DECLARE @DeptScoped INT;
DECLARE @Dept TABLE (DepartmentId INT PRIMARY KEY);
BEGIN
	SET NOCOUNT ON;
	SET @Result = 0;
	SET @Reason = 0;
	SET @InProgress = NULL;
	SET @Rejected = NULL;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	SET @DeptScoped = CASE WHEN @RoleCode IN ('manager', 'user') THEN 1 ELSE 0 END;

	IF EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND IsSystem = 1)
		SET @Reason = 12;
	ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (ISNULL(@RoleCode, '') NOT IN ('controller', 'mgmt', 'manager', 'user'))
		SET @Reason = 4;
	ELSE IF NOT EXISTS (SELECT 1 FROM dbo.fn_DashboardCommitteeFilter(@CommitteeId) cf WHERE cf.Allowed = 1)
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @DeptScoped = 0)
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	IF (@Result = 1)
	BEGIN
		IF (@DeptScoped = 1)
			INSERT INTO @Dept (DepartmentId)
			SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
			WHERE @DepartmentId = 0 OR s.DepartmentId = @DepartmentId;

		SELECT
		@InProgress = ISNULL(SUM(CASE WHEN ag.StatusGroup = 'in progress' THEN 1 ELSE 0 END), 0),
		@Rejected = ISNULL(SUM(CASE WHEN ag.StatusGroup = 'rejected' THEN 1 ELSE 0 END), 0)
		FROM dbo.fn_AgendaStatusGroup() ag
		INNER JOIN Meeting m ON m.MeetingId = ag.MeetingId
		INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
		INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
		WHERE st.IsScheduled = 1
		AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId)
		AND (@DeptScoped = 0 OR ag.DepartmentId IN (SELECT DepartmentId FROM @Dept));
	END
END
GO

-- The three batches below are the texts of steps 44 and 43 with the changes of step 45 (marked DashboardSummary-Step45).
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
-- DashboardSummary-Step45 (step UN6c2b): @CommitteeId must be 0 or an ACTIVE committee (fn_DashboardCommitteeFilter;
-- an inactive or unknown one: Reason 4), and the MD Secretariat gets the statistics as well (StatisticsShown 1,
-- read-only, as Management; still no WaitingForMe). Only the Admin has no statistics now. Everything else is unchanged.
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
	ELSE IF NOT EXISTS (SELECT 1 FROM dbo.fn_DashboardCommitteeFilter(@CommitteeId) cf WHERE cf.Allowed = 1)
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @DeptScoped = 0)
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE
	BEGIN
		SET @Result = 1;
		SET @StatisticsShown = CASE WHEN @ActingRole IN ('controller', 'mgmt', 'md_sect', 'manager', 'user') THEN 1 ELSE 0 END;
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

-- Dashboard My approvals panel (AgendaWaitingFor-Step44, step UN6c2a): the items that wait for the acting user's
-- approval (fn_AgendaWaitingFor, IsWaiting: he may approve, the agenda is open, the meeting date has not passed),
-- newest meeting first, a page of 10. @CommitteeId 0: every committee; otherwise it must exist. @DepartmentId 0: no
-- department filter; otherwise one of a Manager's departments (fn_UserDepartmentScope). AlertId: the item's alert
-- (the page marks the acting user's own row of it read when the item is opened).
-- Reason 12: the protected system account. Reason 8: acting user missing, 0 or inactive. Reason 4: a role without
-- the panel (anyone but Controller and Manager), a filter that is not allowed, a page number below 1. A refused
-- call returns the same columns with no rows. A page number past the end gives the last page (@PageShown).
-- DashboardSummary-Step45 (step UN6c2b): @CommitteeId must be 0 or an ACTIVE committee (fn_DashboardCommitteeFilter;
-- an inactive or unknown one: Reason 4). Everything else is unchanged.
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
	ELSE IF NOT EXISTS (SELECT 1 FROM dbo.fn_DashboardCommitteeFilter(@CommitteeId) cf WHERE cf.Allowed = 1)
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

-- Dashboard Action Items card (DashboardAlerts-Step43, step UN6c1): the rows of fn_DashboardActionItems for the
-- acting user, newest meeting first. Reason 8: acting user missing, 0 or inactive. Reason 4: a role without an
-- Action Items card (MD Secretariat, Admin; the page hides the card on this answer). A refused call returns the
-- same columns with no rows.
-- DashboardSummary-Step45 (step UN6c2b): two more parameters, last and optional, the filters at the top of the
-- Dashboard, checked as in spr_GetDashboardMeetings (Reason 4 after the role check):
--   @CommitteeId   0: every committee; otherwise an active committee (fn_DashboardCommitteeFilter)
--   @DepartmentId  0: no department filter; otherwise one of a Manager's or a User's departments
--                  (fn_UserDepartmentScope); any department for the Controller or Management is refused
-- The rows are those of fn_DashboardActionItems (unchanged) of the committee and the department chosen; with both 0
-- they are the rows of step 43.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardActionItems]
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@CommitteeId INT = 0,
@DepartmentId INT = 0
AS
DECLARE @Today DATE;
DECLARE @RoleCode VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (ISNULL(@RoleCode, '') NOT IN ('controller', 'mgmt', 'manager', 'user'))
		SET @Reason = 4;
	ELSE IF NOT EXISTS (SELECT 1 FROM dbo.fn_DashboardCommitteeFilter(@CommitteeId) cf WHERE cf.Allowed = 1)
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @RoleCode NOT IN ('manager', 'user'))
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	f.ActionItemId,
	f.MinutesId,
	f.ActionText,
	f.ActionStatus,
	f.AgendaId,
	f.DecisionTypeId,
	f.DueDate,
	f.AgendaNo,
	f.CommitteeId,
	f.MeetingId,
	f.DecisionTypeCode,
	f.DecisionTypeName,
	f.SubjectNo,
	f.DepartmentCode,
	f.DepartmentName,
	f.ActualResolution,
	f.CommitteeName,
	f.CommitteeCode,
	f.MeetingDate,
	f.MeetingTime,
	f.Venue,
	f.UserId,
	f.ReadStatus,
	f.DepartmentId,
	f.Directions,
	f.IsComplied,
	f.IsConfirmed,
	f.IsOverdue
	FROM dbo.fn_DashboardActionItems(@ActingUserId, @Today) f
	WHERE @Result = 1
	AND (@CommitteeId = 0 OR f.CommitteeId = @CommitteeId)
	AND (@DepartmentId = 0 OR f.DepartmentId = @DepartmentId)
	ORDER BY f.MeetingDate DESC, f.AgendaNo, f.ActionItemId;
END
GO

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardCommitteeFilter')), '') LIKE '%DashboardSummary-Step45%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardSummary')), '') LIKE '%DashboardSummary-Step45%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') LIKE '%DashboardSummary-Step45%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), '') LIKE '%DashboardSummary-Step45%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardSummary-Step45%')
    SET @Installed = @Installed + 1;

IF (@Installed = 5)
    PRINT 'Step 45 installed: fn_DashboardCommitteeFilter and spr_GetDashboardSummary are new; spr_GetDashboardMeetings, spr_GetDashboardApprovals and spr_GetDashboardActionItems take only an active committee, the meeting list has statistics for the MD Secretariat and the Action Items card follows both filters (DashboardSummary-Step45).';
ELSE
    RAISERROR('Step 45 is not complete: %d of 5 objects carry the marker DashboardSummary-Step45. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
