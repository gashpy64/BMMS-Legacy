/* ============================================================================
   BMMS - Roll back step 45 (Dashboard summary cards, the filters on every
   Dashboard card, statistics for the MD Secretariat; step UN6c2b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Puts back the three procedures step 45 replaced, letter for letter as
   steps 44 and 43 installed them:
     spr_GetDashboardMeetings      (any existing committee; no statistics for
                                    the MD Secretariat)
     spr_GetDashboardApprovals     (any existing committee)
     spr_GetDashboardActionItems   (without @CommitteeId and @DepartmentId)
   and drops the two new objects of step 45:
     spr_GetDashboardSummary, fn_DashboardCommitteeFilter
   At its end the script compares the restored texts with the texts step 45
   was built from (SHA-1, carriage returns left out, in pieces of 4,000
   characters) and says so.

   Roll back the application build of step UN6c2b first or at the same time:
   that build calls spr_GetDashboardSummary for the summary cards and sends
   the two filters to spr_GetDashboardActionItems; without step 45 the cards
   show a dash and the Action Items card its "could not be loaded" message.

   Order of rollbacks: this script comes FIRST. The step 44 Rollback refuses
   to run while step 45 is installed (it would put back the step 42 meeting
   list and drop spr_GetDashboardApprovals under step 45). Only the Rollback
   of step 48 comes before it: this script refuses while step 48 is
   installed (step FU2a).

   Changes no data. Safe to re-run. BMMS-Check-InstalledSteps.sql then shows
   step 45 Missing; steps 16 to 44 stay Installed.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS", and when step 45 is not
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
ELSE IF (OBJECT_ID('dbo.fn_DashboardCommitteeFilter', 'IF') IS NULL
         AND OBJECT_ID('dbo.spr_GetDashboardSummary', 'P') IS NULL
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') NOT LIKE '%DashboardSummary-Step45%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), '') NOT LIKE '%DashboardSummary-Step45%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') NOT LIKE '%DashboardSummary-Step45%')
BEGIN
    RAISERROR('Step 45 is not installed in "%s" (none of its two new objects exists and the three replaced procedures do not carry its marker): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.spr_GetDashboardMeetings', 'P') IS NULL OR OBJECT_ID('dbo.spr_GetDashboardApprovals', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetDashboardActionItems', 'P') IS NULL OR OBJECT_ID('dbo.fn_AgendaWaitingFor', 'IF') IS NULL
         OR OBJECT_ID('dbo.fn_DashboardActionItems', 'IF') IS NULL)
BEGIN
    RAISERROR('A procedure or function of steps 43 and 44 is missing in "%s" (spr_GetDashboardMeetings, spr_GetDashboardApprovals, spr_GetDashboardActionItems, fn_AgendaWaitingFor, fn_DashboardActionItems): this is not a database step 45 was installed in. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
-- Step 48 (step FU2a) replaced spr_GetDashboardActionItems after step 45: roll it back first
-- (BMMS-Rollback-DashboardFollowupFinal-Step48.sql)
ELSE IF (OBJECT_ID('dbo.fn_DashboardActionItemScope', 'IF') IS NOT NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') LIKE '%DashboardFollowupFinal-Step48%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') LIKE '%DashboardFollowupFinal-Step48%')
BEGIN
    RAISERROR('Step 48 (BMMS-Fix-DashboardFollowupFinal-Step48.sql) is installed in "%s" and replaced spr_GetDashboardActionItems after step 45. Roll back step 48 first (BMMS-Rollback-DashboardFollowupFinal-Step48.sql), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- The three batches below are the texts of steps 44 and 43, unchanged. Do not tidy them: the comparison at the end
-- is letter for letter. They come first: while they run, the function they no longer read is still there.
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

-- Dashboard Action Items card (DashboardAlerts-Step43, step UN6c1): the rows of fn_DashboardActionItems for the
-- acting user, newest meeting first. Reason 8: acting user missing, 0 or inactive. Reason 4: a role without an
-- Action Items card (MD Secretariat, Admin; the page hides the card on this answer). A refused call returns the
-- same columns with no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardActionItems]
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @Today DATE;
DECLARE @RoleCode VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Today = CAST(GETDATE() AS DATE);

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (ISNULL(@RoleCode, '') NOT IN ('controller', 'mgmt', 'manager', 'user'))
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
	ORDER BY f.MeetingDate DESC, f.AgendaNo, f.ActionItemId;
END
GO

-- The new procedure first, the function it reads last (the three texts above no longer read it)
IF OBJECT_ID('dbo.spr_GetDashboardSummary', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetDashboardSummary;
IF OBJECT_ID('dbo.fn_DashboardCommitteeFilter', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_DashboardCommitteeFilter;
GO

DECLARE @Left INT = 0;
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

IF (OBJECT_ID('dbo.spr_GetDashboardSummary', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.fn_DashboardCommitteeFilter', 'IF') IS NOT NULL) SET @Left = @Left + 1;

IF (@Left > 0)
    RAISERROR('Step 45 is not fully rolled back: %d of its two new objects are still there. Read the messages above and run the script again.', 16, 1, @Left);
ELSE IF (ISNULL(@MeetHash, '') <> '018126C666059C775382F2D990FD0E6894CB1960A0DBD4D95E46DC9E033221FEA12D64364BED4928'
         OR ISNULL(@ApprHash, '') <> 'B39CC2B64BCF0068CA13908C21302FC1212452A7'
         OR ISNULL(@ActHash, '') <> 'A3117268FEA43FAB4F7FA858DAD14CA978FB0D02')
    RAISERROR('Step 45: the two new objects are dropped, but spr_GetDashboardMeetings, spr_GetDashboardApprovals or spr_GetDashboardActionItems is NOT letter for letter the text of steps 44 and 43 (SHA-1 differs). Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 45 rolled back: the two new objects are dropped; spr_GetDashboardMeetings, spr_GetDashboardApprovals and spr_GetDashboardActionItems are again the texts of steps 44 and 43, letter for letter (SHA-1 compared).';
GO

SET NOEXEC OFF;
GO
