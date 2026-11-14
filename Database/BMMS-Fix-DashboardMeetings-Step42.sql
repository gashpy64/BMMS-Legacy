/* ============================================================================
   BMMS - Dashboard meeting list with status colours and statistics
   (step 42, step UN6b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision UN6b (2026-11-12, plan approved): the Dashboard's
   "Scheduled Meetings" list is replaced by a meeting list with a status
   colour and per-meeting statistics, scoped by role and department on the
   server. The acting user's role and departments are read from the
   database; nothing comes from the page.

   Five new read-only objects. Nothing is replaced; spr_GetScheduleMeet is
   unchanged (after the build of UN6b nothing calls it).

     fn_MeetingDashboardState(@Today DATE)        inline table function
         one row per meeting: MeetingId, IsScheduled, StateCode, StateLabel.
         IsScheduled: the meeting date is @Today or later (a meeting dated
         today is scheduled until the end of that day), or it has no date.
         The state is the first rule that fits, in this order:
           grey    MinutesStatus F or C       "Minutes finalised" / "Minutes confirmed"
           red     the meeting date is before @Today      "Minutes pending"
           green   AgendaStatus not Open (NULL = Open)    "Agenda finalised"
           orange  the agenda submission date is before @Today  "Submission closed"
           blue    anything else                          "Open for submission"
     fn_UserDepartmentScope(@UserId INT, @Today DATE)   inline table function
         the user's departments: the User_Department rows open on @Today
         (EffectiveFrom on or before it, EffectiveTo empty or after it),
         together with the home department Users.DepartmentId (a user
         without history rows counts as mapped to it, step 39).
     fn_AgendaStatusGroup()                        inline table function
         every agenda item with its group, the one definition for the
         Dashboard and the later summary cards (UN6c):
           approved     ACA
           rejected     AMR, ACR
           in progress  AC, AMA
           other        AF and any other code
     spr_GetDashboardMeetings                      all six roles
         @ActingUserId, @CommitteeId (0 = all committees), @DepartmentId
         (0 = all the user's departments), @Result, @Reason,
         @StatisticsShown and @ActingRoleCode as OUTPUT.
         Reason 8  the acting user is missing, 0 or inactive
         Reason 4  a role outside the six; a committee that does not exist;
                   a department that is not one of a Manager's or a User's
                   departments; any department for the other roles
         A refused call returns the same columns with no rows.
         Rows: every scheduled meeting (no cap), then the last 10 completed
         meetings (newest first) - the cap of 10 holds for EVERY role. For a
         Manager and a User a completed meeting is listed only when it has
         at least one item of the chosen department(s). The committee filter
         narrows both lists. Items, Approved, Rejected, Pending are counted
         by fn_AgendaStatusGroup (Pending = in progress = AC + AMA), for a
         Manager and a User over the chosen department(s) only. For MD
         Secretariat and Admin they are NULL and @StatisticsShown is 0 (not
         computed); for the Controller, Management, the Manager and the User
         @StatisticsShown is 1.
     spr_GetDashboardDepartments                   Manager and User
         @ActingUserId, @Result, @Reason as OUTPUT (Reasons 8 and 4 as
         above): DepartmentId, DepartmentName, IsHome of the user's
         departments, the home department first, then by name.

   "Today" is the database server's date.

   Changes no data. Safe to re-run. Installed after step 41 (it stops
   otherwise). Install BEFORE the build of step UN6b: that build calls these
   procedures. BMMS-Rollback-DashboardMeetings-Step42.sql drops them (then
   roll back the build too).

   Marker DashboardMeetings-Step42 in each object (5 markers in
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

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupReportForManagement')), '') NOT LIKE '%ReportAccess-Step41%'
         OR OBJECT_ID('dbo.User_Department', 'U') IS NULL OR OBJECT_ID('dbo.Agenda_Status', 'U') IS NULL)
BEGIN
    RAISERROR('Step 41 (BMMS-Fix-ReportAccess-Step41.sql) is not installed in "%s", or the table User_Department (step 39) is missing. The steps are installed in order: run step 41 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Dashboard meeting state (DashboardMeetings-Step42, step UN6b): one row per meeting. IsScheduled: the meeting
-- date is @Today or later, or there is no date. The state is the first rule that fits: grey (minutes F or C),
-- red (the meeting date is before @Today), green (agenda finalised), orange (the agenda submission date is before
-- @Today), blue (open for submission). NULL AgendaStatus and MinutesStatus count as 'Open'.
CREATE OR ALTER FUNCTION [dbo].[fn_MeetingDashboardState]
(
@Today DATE
)
RETURNS TABLE
AS
RETURN
SELECT
m.MeetingId,
CAST(CASE WHEN m.MeetingDate IS NULL OR CAST(m.MeetingDate AS DATE) >= @Today THEN 1 ELSE 0 END AS INT) AS IsScheduled,
CAST(CASE WHEN ISNULL(m.MinutesStatus, 'Open') IN ('F', 'C') THEN 'grey'
          WHEN CAST(m.MeetingDate AS DATE) < @Today THEN 'red'
          WHEN ISNULL(m.AgendaStatus, 'Open') <> 'Open' THEN 'green'
          WHEN CAST(m.AgendaSubmissionDate AS DATE) < @Today THEN 'orange'
          ELSE 'blue' END AS VARCHAR(10)) AS StateCode,
CAST(CASE WHEN ISNULL(m.MinutesStatus, 'Open') = 'F' THEN 'Minutes finalised'
          WHEN ISNULL(m.MinutesStatus, 'Open') = 'C' THEN 'Minutes confirmed'
          WHEN CAST(m.MeetingDate AS DATE) < @Today THEN 'Minutes pending'
          WHEN ISNULL(m.AgendaStatus, 'Open') <> 'Open' THEN 'Agenda finalised'
          WHEN CAST(m.AgendaSubmissionDate AS DATE) < @Today THEN 'Submission closed'
          ELSE 'Open for submission' END AS VARCHAR(30)) AS StateLabel
FROM Meeting m;
GO

-- A user's departments (DashboardMeetings-Step42, step UN6b): the User_Department rows open on @Today (a row covers
-- EffectiveFrom up to, not including, EffectiveTo; empty EffectiveTo = current) and the home department
-- Users.DepartmentId (a user without history rows counts as mapped to it, step 39). A Manager can have several.
CREATE OR ALTER FUNCTION [dbo].[fn_UserDepartmentScope]
(
@UserId INT,
@Today DATE
)
RETURNS TABLE
AS
RETURN
SELECT ud.DepartmentId
FROM User_Department ud
WHERE ud.UserId = @UserId
AND ud.EffectiveFrom <= @Today
AND (ud.EffectiveTo IS NULL OR ud.EffectiveTo > @Today)
UNION
SELECT u.DepartmentId
FROM Users u
WHERE u.UserId = @UserId
AND u.DepartmentId IS NOT NULL;
GO

-- Agenda item groups (DashboardMeetings-Step42, step UN6b): the one definition used by the Dashboard statistics and
-- the later summary cards. approved: ACA; rejected: AMR, ACR; in progress (Pending): AC, AMA; other: AF and any
-- other or empty code (counted in Items only).
CREATE OR ALTER FUNCTION [dbo].[fn_AgendaStatusGroup]
(
)
RETURNS TABLE
AS
RETURN
SELECT
a.AgendaId,
a.MeetingId,
a.CommitteeId,
a.DepartmentId,
a.AgendaStatusCode,
CAST(CASE WHEN a.AgendaStatusCode = 'ACA' THEN 'approved'
          WHEN a.AgendaStatusCode IN ('AMR', 'ACR') THEN 'rejected'
          WHEN a.AgendaStatusCode IN ('AC', 'AMA') THEN 'in progress'
          ELSE 'other' END AS VARCHAR(20)) AS StatusGroup
FROM Agenda a;
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

-- Dashboard department list (DashboardMeetings-Step42, step UN6b): the departments of a Manager or a User
-- (fn_UserDepartmentScope), the home department first, then by name. Reason 8: acting user missing or inactive;
-- Reason 4: another role; then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardDepartments]
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
DECLARE @HomeDepartmentId INT;
DECLARE @Today DATE;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Today = CAST(GETDATE() AS DATE);
	SELECT @ActingRole = r.RoleCode, @HomeDepartmentId = u.DepartmentId
	FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN ('manager', 'user'))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	d.DepartmentId,
	d.DepartmentName,
	CAST(CASE WHEN d.DepartmentId = @HomeDepartmentId THEN 1 ELSE 0 END AS BIT) AS IsHome
	FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	INNER JOIN Department d ON d.DepartmentId = s.DepartmentId
	WHERE @Result = 1
	ORDER BY CASE WHEN d.DepartmentId = @HomeDepartmentId THEN 0 ELSE 1 END, d.DepartmentName, d.DepartmentId;
END
GO

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_MeetingDashboardState')), '') LIKE '%DashboardMeetings-Step42%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserDepartmentScope')), '') LIKE '%DashboardMeetings-Step42%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_AgendaStatusGroup')), '') LIKE '%DashboardMeetings-Step42%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') LIKE '%DashboardMeetings-Step42%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardDepartments')), '') LIKE '%DashboardMeetings-Step42%')
    SET @Installed = @Installed + 1;

IF (@Installed = 5)
    PRINT 'Step 42 installed: fn_MeetingDashboardState, fn_UserDepartmentScope, fn_AgendaStatusGroup, spr_GetDashboardMeetings and spr_GetDashboardDepartments (DashboardMeetings-Step42); spr_GetScheduleMeet unchanged.';
ELSE
    RAISERROR('Step 42 is not complete: %d of 5 objects carry the marker DashboardMeetings-Step42. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
