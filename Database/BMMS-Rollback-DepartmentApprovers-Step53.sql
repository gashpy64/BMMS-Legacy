/* ============================================================================
   BMMS - Roll back step 53 (any Manager of the item's department approves,
   step UD1b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Puts back the 18 texts step 53 replaced, letter for letter as steps 18,
   20, 24, 37, 43, 44 and 52 left them, and drops the two objects step 53
   added (fn_DepartmentManagers, spr_SetManagerAlertRows). At its end the
   script compares the restored texts with the texts step 53 was built from
   (SHA-1, carriage returns left out, in pieces of 4,000 characters) and says
   so.

   Kept, as step 39's rollback kept its tables: the columns
   Alert_User_Map.HandledReason, HandledBy, HandledOn and Agenda.RouteNote,
   their checks and the key to Users, the rows step 53 marked as handled and
   the rows its back-fill or its procedures added. The older texts do not
   read the new columns: a marked row is an ordinary row for them (shown in
   the Alerts card by its type as before, and made unread again by the next
   decision or Update of the item, as before step 53). Under the restored rule
   a Manager decides an item at AC when he is the creator's Reporting Person
   or has a row on its alert; the script ends by counting the items at AC
   that no active Manager could then decide (they need the Controller, the
   one-time re-route of step 20, or an active Reporting Person), and the
   alert rows of items at AC held by active Managers outside the item's
   department (the rows marked 'N' and 'M' by step 53 apart): under the restored
   rule each lets that Manager decide the item.

   Roll back the application build of step UD1b first or at the same time:
   that build passes the department to spr_GetAgendaCreationMailId (the older
   text has one parameter) and reads the handled columns of the Alerts card.

   A second run refuses (step 53 is not installed: nothing to roll back).
   BMMS-Check-InstalledSteps.sql then shows step 53 Missing.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS". Plain ASCII. From the
   command line use sqlcmd -I.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
-- Step 55 (step IU1) replaced spr_AddEditMeeting and spr_AddEditCommittee of step 53 again, keeping its markers, so a run now
-- would put an older text back without a word (InactiveUsers-Step55)
ELSE IF (OBJECT_ID('dbo.fn_FunctionalUsers', 'IF') IS NOT NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') LIKE '%InactiveUsers-Step55%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditCommittee')), '') LIKE '%InactiveUsers-Step55%')
BEGIN
    RAISERROR('Step 55 is installed in "%s": it replaced spr_AddEditMeeting and spr_AddEditCommittee of step 53 again. Roll back the build of step IU1, run BMMS-Rollback-InactiveUsers-Step55.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
-- Step 54 (step UD1c) replaced spr_AddEditAgendaByManager and spr_AddEditUser of step 53 again and needs step 53, keeping its markers, so a run now
-- would put an older text back without a word (ManagerScope-Step54)
ELSE IF (OBJECT_ID('dbo.fn_ManagerDepartments', 'IF') IS NOT NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingIdDeptId')), '') LIKE '%ManagerScope-Step54%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') LIKE '%ManagerScope-Step54%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') LIKE '%ManagerScope-Step54%')
BEGIN
    RAISERROR('Step 54 is installed in "%s": it replaced spr_AddEditAgendaByManager and spr_AddEditUser of step 53 again and needs step 53. Run BMMS-Rollback-ManagerScope-Step54.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (NOT EXISTS (SELECT 1 FROM (VALUES ('fn_AgendaRoute'), ('fn_AgendaWaitingFor'), ('fn_ManagerReleaseRefusal'), ('fn_DashboardAlerts'), ('spr_GetDashboardAlerts'), ('spr_GetAlertCount'),
                                           ('spr_GetAlertMailId'), ('spr_GetAgendaUpdateMailId'), ('spr_GetAgendaCreationMailId'), ('spr_RerouteWaitingAgendas'), ('spr_AddEditCommittee'), ('spr_AddEditMeeting'),
                                           ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId')) o(Name)
                     WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%DepartmentApprovers-Step53%')
         AND OBJECT_ID('dbo.fn_DepartmentManagers', 'IF') IS NULL AND OBJECT_ID('dbo.spr_SetManagerAlertRows', 'P') IS NULL)
BEGIN
    RAISERROR('Step 53 is not installed in "%s" (none of its objects carries DepartmentApprovers-Step53): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
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

-------------------------------------------------------------------------------
-- Rule 12 (UserHistory-Step39): what stops a Manager from leaving a department
-------------------------------------------------------------------------------
-- One row per finding, none when nothing stops it. Kind 'D': @UserId is the last active Manager
-- (open User_Department row, active, Manager role, not the system account) of a department with
-- open items waiting for a Manager (AC on a meeting whose agenda is open); Items = their count.
-- @DepartmentId NULL = every department of @UserId, otherwise that one. Kind 'P' (only when
-- @Personal = 1): items waiting at AC routed to @UserId himself (he has the item's alert, or he is
-- the creator's manager), as step 20 lets a Manager approve them. The caller locks first.
-- ManagerRelease-Step52 (step MR1): the personal part is read from fn_AgendaWaitingFor (step 44), the one rule
-- of who may decide an item: items at AC that @UserId may approve on a meeting whose agenda is still open.
-- Kind 'P': the meeting date has not passed (DateOpen 1, also a meeting without a date); Kind 'Q': the meeting
-- date has passed (DateOpen 0) and the agenda was never finalised. Both use the database server's date.
-- Kind 'D' is unchanged.
CREATE OR ALTER FUNCTION [dbo].[fn_ManagerReleaseRefusal]
(
@UserId INT,
@DepartmentId INT,
@Personal BIT
)
RETURNS TABLE
AS
RETURN
SELECT CAST('D' AS CHAR(1)) AS Kind, d.DepartmentId, CAST(d.DepartmentName AS NVARCHAR(200)) AS DepartmentName, COUNT(*) AS Items
FROM dbo.User_Department ud
JOIN dbo.Department d ON d.DepartmentId = ud.DepartmentId
JOIN dbo.Agenda a ON a.DepartmentId = ud.DepartmentId
JOIN dbo.Meeting mt ON mt.MeetingId = a.MeetingId
WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL
  AND (@DepartmentId IS NULL OR ud.DepartmentId = @DepartmentId)
  AND a.AgendaStatusCode = 'AC' AND ISNULL(mt.AgendaStatus, 'Open') = 'Open'
  AND NOT EXISTS (SELECT 1 FROM dbo.User_Department o
                  JOIN dbo.Users ou ON ou.UserId = o.UserId
                  JOIN dbo.Roles orl ON orl.RoleId = ou.RoleId
                  WHERE o.DepartmentId = ud.DepartmentId AND o.EffectiveTo IS NULL AND o.UserId <> @UserId
                    AND ou.AccountStatus = 1 AND ou.IsSystem = 0 AND orl.RoleCode = 'manager')
GROUP BY d.DepartmentId, d.DepartmentName
UNION ALL
SELECT CAST(CASE WHEN w.DateOpen = 1 THEN 'P' ELSE 'Q' END AS CHAR(1)), CAST(NULL AS INT), CAST(N'' AS NVARCHAR(200)), COUNT(*)
FROM dbo.fn_AgendaWaitingFor(@UserId, CAST(GETDATE() AS DATE)) w
WHERE @Personal = 1
  AND w.AgendaStatusCode = 'AC' AND w.CanApprove = 1 AND w.AgendaOpen = 1
GROUP BY w.DateOpen;
GO

-- Dashboard alert list (DashboardAlerts-Step43, step UN6c1): the one listing rule, for the Alerts card and the header
-- count. The rows of @UserId that are not removed (StatusId 1), with the role read from Users: a Controller does not
-- see ACA and ACR, a Manager does not see AMA and AMR (as spr_GetAlertByUserId), and the Admin role sees none of the
-- eleven functional types (so nothing today; the protected system account has the Admin role). EventOn and the acting
-- person: an agenda item at AC by its UpdatedOn / UpdatedBy (else CreatedOn / CreatedBy); a decision (AMA, AMR by
-- MgrApprovedDate / MgrApprovedBy; ACA, ACR by ControllerApprovedDate / ControllerApprovedBy), unless the item was
-- edited more than one minute after it (then UpdatedOn / UpdatedBy); a decision without a recorded approver has no
-- acting person; every other alert by Alert_Master.CreatedOn / CreatedBy.
CREATE OR ALTER FUNCTION [dbo].[fn_DashboardAlerts]
(
@UserId INT
)
RETURNS TABLE
AS
RETURN
SELECT
m.AlertUserId,
m.AlertId,
m.UserId,
CAST(ISNULL(m.ReadStatus, 0) AS INT) AS ReadStatus,
am.SourceType,
am.SourceTypeId,
am.DepartmentId,
d.DepartmentName,
am.AlertTypeCode,
t.AlertTypeName,
am.CommitteeId,
c.CommitteeCode,
c.CommitteeName,
am.DisplayText,
am.CreatedOn,
ev.EventOn,
ev.ActorUserId,
au.UserName AS ActorName,
au.LoginName AS ActorLogin
FROM Alert_User_Map m
INNER JOIN Alert_Master am ON am.AlertId = m.AlertId
INNER JOIN Users u ON u.UserId = m.UserId
LEFT JOIN Roles r ON r.RoleId = u.RoleId
INNER JOIN Alert_Type t ON t.AlertTypeCode = am.AlertTypeCode
INNER JOIN Committee c ON c.CommitteeId = am.CommitteeId
LEFT JOIN Department d ON d.DepartmentId = am.DepartmentId
LEFT JOIN Agenda a ON am.SourceType = 'Agenda' AND a.AgendaId = am.SourceTypeId
CROSS APPLY (SELECT
             CASE WHEN a.AgendaId IS NOT NULL AND am.AlertTypeCode = 'AC' THEN 1 ELSE 0 END AS IsEntry,
             CASE WHEN a.AgendaId IS NOT NULL AND am.AlertTypeCode IN ('AMA', 'AMR', 'ACA', 'ACR') THEN 1 ELSE 0 END AS IsDecision,
             CASE WHEN am.AlertTypeCode IN ('AMA', 'AMR') THEN a.MgrApprovedDate
                  WHEN am.AlertTypeCode IN ('ACA', 'ACR') THEN a.ControllerApprovedDate END AS DecisionOn,
             CASE WHEN am.AlertTypeCode IN ('AMA', 'AMR') THEN a.MgrApprovedBy
                  WHEN am.AlertTypeCode IN ('ACA', 'ACR') THEN a.ControllerApprovedBy END AS DecisionBy) k
CROSS APPLY (SELECT
             CASE WHEN k.IsDecision = 1 AND k.DecisionOn IS NOT NULL AND k.DecisionBy IS NOT NULL THEN 1 ELSE 0 END AS HasApprover,
             CASE WHEN k.IsDecision = 1 AND k.DecisionOn IS NOT NULL AND k.DecisionBy IS NOT NULL
                       AND a.UpdatedBy IS NOT NULL AND a.UpdatedOn > DATEADD(MINUTE, 1, k.DecisionOn) THEN 1 ELSE 0 END AS EditedAfter) k2
CROSS APPLY (SELECT
             CASE WHEN k.IsEntry = 1 THEN ISNULL(a.UpdatedOn, ISNULL(a.CreatedOn, am.CreatedOn))
                  WHEN k2.EditedAfter = 1 THEN a.UpdatedOn
                  WHEN k2.HasApprover = 1 THEN k.DecisionOn
                  WHEN k.IsDecision = 1 THEN ISNULL(a.UpdatedOn, am.CreatedOn)
                  ELSE am.CreatedOn END AS EventOn,
             CASE WHEN k.IsEntry = 1 THEN ISNULL(a.UpdatedBy, a.CreatedBy)
                  WHEN k2.EditedAfter = 1 THEN a.UpdatedBy
                  WHEN k2.HasApprover = 1 THEN k.DecisionBy
                  WHEN k.IsDecision = 1 THEN NULL
                  ELSE am.CreatedBy END AS ActorUserId) ev
LEFT JOIN Users au ON au.UserId = ev.ActorUserId
WHERE m.UserId = @UserId
AND m.StatusId = 1
AND NOT (ISNULL(r.RoleCode, '') = 'admin'
         AND am.AlertTypeCode IN ('CC', 'CU', 'MC', 'MU', 'AC', 'AMA', 'AMR', 'ACA', 'ACR', 'AF', 'MF'))
AND NOT (ISNULL(r.RoleCode, '') = 'controller' AND am.AlertTypeCode IN ('ACA', 'ACR'))
AND NOT (ISNULL(r.RoleCode, '') = 'manager' AND am.AlertTypeCode IN ('AMA', 'AMR'));
GO

-- Dashboard Alerts card (DashboardAlerts-Step43, step UN6c1): the acting user's alerts by fn_DashboardAlerts, a page
-- of 10, newest EventOn first.
--   @Mode  'R' recent: every unread alert and the read alerts whose EventOn is today or in the seven days before
--          'U' unread only; 'A' all (nothing is ever deleted)
--   @PageNo  from 1; a page after the last gives the last (@PageShown)
-- Reason 8: acting user missing or inactive; Reason 4: another mode or a page number below 1; then no rows.
-- @TotalRows counts the rows of the mode, @UnreadCount the unread rows of the whole list.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardAlerts]
@ActingUserId INT = NULL,
@Mode CHAR(1) = 'R',
@PageNo INT = 1,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@TotalRows INT = NULL OUTPUT,
@UnreadCount INT = NULL OUTPUT,
@PageShown INT = NULL OUTPUT
AS
DECLARE @PageSize INT;
DECLARE @From DATETIME;
DECLARE @Pages INT;
DECLARE @L TABLE (RowNo INT PRIMARY KEY, AlertUserId INT);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @TotalRows = 0;
	SET @UnreadCount = 0;
	SET @PageShown = 1;
	SET @PageSize = 10;
	SET @From = DATEADD(DAY, -7, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0));
	SET @Mode = UPPER(ISNULL(@Mode, 'R'));
	SET @PageNo = ISNULL(@PageNo, 1);

	IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (@Mode NOT IN ('R', 'U', 'A') OR @PageNo < 1)
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	IF (@Result = 1)
	BEGIN
		SET @UnreadCount = (SELECT COUNT(*) FROM dbo.fn_DashboardAlerts(@ActingUserId) f WHERE f.ReadStatus = 0);

		INSERT INTO @L (RowNo, AlertUserId)
		SELECT ROW_NUMBER() OVER (ORDER BY f.EventOn DESC, f.AlertUserId DESC), f.AlertUserId
		FROM dbo.fn_DashboardAlerts(@ActingUserId) f
		WHERE @Mode = 'A'
		OR f.ReadStatus = 0
		OR (@Mode = 'R' AND f.EventOn >= @From);

		SET @TotalRows = @@ROWCOUNT;
		SET @Pages = (@TotalRows + @PageSize - 1) / @PageSize;
		SET @PageShown = CASE WHEN @Pages < 1 THEN 1 WHEN @PageNo > @Pages THEN @Pages ELSE @PageNo END;
	END

	SELECT
	l.RowNo,
	f.AlertUserId,
	f.AlertId,
	f.UserId,
	f.ReadStatus,
	f.SourceType,
	f.SourceTypeId,
	f.DepartmentId,
	f.DepartmentName,
	f.AlertTypeCode,
	f.AlertTypeName,
	f.CommitteeId,
	f.CommitteeCode,
	f.CommitteeName,
	f.DisplayText,
	f.CreatedOn,
	f.EventOn,
	f.ActorUserId,
	f.ActorName,
	f.ActorLogin
	FROM @L l
	INNER JOIN dbo.fn_DashboardAlerts(@ActingUserId) f ON f.AlertUserId = l.AlertUserId
	WHERE @Result = 1
	AND l.RowNo > (@PageShown - 1) * @PageSize
	AND l.RowNo <= @PageShown * @PageSize
	ORDER BY l.RowNo;
END
GO

-- Header count "Alerts (n)" (DashboardAlerts-Step43, step UN6c1): the unread alerts of the acting user by
-- fn_DashboardAlerts, the rule of the Alerts card. Reason 8: acting user missing or inactive (count 0).
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAlertCount]
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@UnreadCount INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @UnreadCount = 0;

	IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE
	BEGIN
		SET @UnreadCount = (SELECT COUNT(*) FROM dbo.fn_DashboardAlerts(@ActingUserId) f WHERE f.ReadStatus = 0);
		SET @Result = 1;
	END
END
GO

-- Agenda alert mail addresses (Bcc of the approve / reject mails): active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- DashboardAlerts-Step43 (step UN6c1): the Admin role is left out in every branch (AMR, AMA, ACA / ACR); the
-- Controller is the superior for functional items
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAlertMailId]
@Code varchar(50),
@UserId INT,
@AgendaId INT
AS
	DECLARE @AlertId INT
	DECLARE @User_Id INT
BEGIN

IF @Code = 'AMR'
BEGIN
	
    SELECT EmailId FROM Users WHERE UserId IN (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId) AND AccountStatus = 1 AND IsSystem = 0
		AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = Users.RoleId AND ar.RoleCode = 'admin');   -- DashboardAlerts-Step43

END

IF @Code = 'AMA'
BEGIN

	SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

	SELECT EmailId FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1 AND IsSystem = 0
		AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = Users.RoleId AND ar.RoleCode = 'admin');   -- DashboardAlerts-Step43

END

IF @Code = 'ACA' OR @Code = 'ACR'
BEGIN

	SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
	SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

	SELECT EmailId FROM Users WHERE UserId IN
		(SELECT UserId FROM Alert_User_Map WHERE AlertId = @AlertId) AND AccountStatus = 1 AND IsSystem = 0
		AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = Users.RoleId AND ar.RoleCode = 'admin');   -- DashboardAlerts-Step43

END

	
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
	  AND ISNULL(r.RoleCode, '') <> 'admin'   -- DashboardAlerts-Step43 (step UN6c1): no functional mail for the Admin role
	  AND NOT (ISNULL(r.RoleCode, '') = 'controller' AND am.AlertTypeCode IN ('ACA', 'ACR'))
	  AND NOT (ISNULL(r.RoleCode, '') = 'manager' AND am.AlertTypeCode IN ('AMA', 'AMR'))
	GROUP BY u.UserId, u.EmailId
	ORDER BY u.UserId;
END
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

-- Committee - add / edit; the alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditCommittee]
@Code VARCHAR(50),
@CommitteeId INT,
@CommitteeCode VARCHAR(10),
@CommitteeName VARCHAR(50), 
@Board INT,
@IncorporationDate DATETIME,
@MeetingStartNo INT,
@CommitteeColorCode VARCHAR(50), 
@CessationDate VARCHAR(50), 
@StatusId INT,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT
AS
	DECLARE @alert_id INT 
	DECLARE @alert_type_id INT
	DECLARE @committee_id INT
	DECLARE @DepartmentId INT 
	DECLARE @SourceType VARCHAR(150)	
	DECLARE @DisplayText VARCHAR(150)	
BEGIN

SET @DepartmentId = (SELECT DepartmentId FROM Users WHERE UserId = @CreatedBy);

	IF (@Code = 'Save') 
	BEGIN
		INSERT INTO Committee
		(CommitteeCode, CommitteeName, Board, IncorporationDate, MeetingStartNo, CommitteeColorCode, 
			CessationDate, StatusId, CreatedOn, CreatedBy)
		VALUES
		(@CommitteeCode, @CommitteeName, @Board, @IncorporationDate, @MeetingStartNo, @CommitteeColorCode, 
			@CessationDate, @StatusId, @CreatedOn, @CreatedBy);

		SET @committee_id = @@identity

		SET @SourceType = 'Committee'
		SET @DisplayText = 'Committee (' + @CommitteeCode + ')'		

		INSERT INTO Alert_Master
		(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
		VALUES
		(@SourceType, 0, @committee_id, @DisplayText, 'CC', 3, @committee_id, @CreatedOn, @CreatedBy)
		
		SET @alert_id = @@identity

		INSERT INTO Alert_User_Map
		(AlertId, [UserId], ReadStatus, StatusId)
		(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0)

	END
	IF (@Code = 'Update') 
	BEGIN
		UPDATE Committee SET
		CommitteeCode = @CommitteeCode,
		CommitteeName = @CommitteeName, 
		Board = @Board,
		IncorporationDate = @IncorporationDate,
		MeetingStartNo = @MeetingStartNo,
		CommitteeColorCode = @CommitteeColorCode, 
		CessationDate = @CessationDate,
		StatusId = @StatusId,
		UpdatedOn = @UpdatedOn, 
		UpdatedBy = @UpdatedBy
		WHERE
		CommitteeId = @CommitteeId;

		SET @SourceType = 'Committee'
		SET @DisplayText = 'Committee (' + @CommitteeCode + ')'		

		INSERT INTO Alert_Master
		(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
		VALUES
		(@SourceType, 0, @CommitteeId, @DisplayText, 'CU', 3, @CommitteeId, @CreatedOn, @CreatedBy)
		
		SET @alert_id = @@identity

		INSERT INTO Alert_User_Map
		(AlertId, [UserId], ReadStatus, StatusId)
		(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0)
	END

END
GO

-- Meeting - add / edit; date and committee locked by attendance, committee by agenda items (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- Dates (MeetingDates-Step24): both required; on create the meeting date and the agenda submission date not
-- before today; on edit a changed date not before today; the submission date always on or before the meeting
-- date. Today is the database server date; dates are compared as dates. Refused with Reason 16, ReasonDetail
-- Missing, MeetingBeforeToday, SubmissionBeforeToday or SubmissionAfterMeeting.
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
	DECLARE @Today DATE;
	DECLARE @OldSubmissionDate DATETIME;
	DECLARE @SubmissionChanged INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';
	SET @Today = CAST(GETDATE() AS date);

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
			-- MeetingDates-Step24
			IF (@MeetingDate IS NULL OR @AgendaSubmissionDate IS NULL)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'Missing';
			END
			ELSE IF (CAST(@MeetingDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'MeetingBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) > CAST(@MeetingDate AS date))
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionAfterMeeting';
			END
			ELSE
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
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0);

				SET @Result = 1;
			END
		END

		IF (@Code = 'Update')
		BEGIN
			SELECT @Found = 1, @OldMeetingDate = MeetingDate, @OldCommitteeId = CommitteeId, @OldSubmissionDate = AgendaSubmissionDate
			FROM Meeting WITH (UPDLOCK, HOLDLOCK)
			WHERE MeetingId = @MeetingId;

			-- Dates compared as dates: the page sends the date only
			SET @DateChanged = CASE WHEN @OldMeetingDate IS NULL AND @MeetingDate IS NULL THEN 0
			                        WHEN @OldMeetingDate IS NULL OR @MeetingDate IS NULL THEN 1
			                        WHEN CAST(@OldMeetingDate AS date) <> CAST(@MeetingDate AS date) THEN 1
			                        ELSE 0 END;
			SET @SubmissionChanged = CASE WHEN @OldSubmissionDate IS NULL AND @AgendaSubmissionDate IS NULL THEN 0
			                             WHEN @OldSubmissionDate IS NULL OR @AgendaSubmissionDate IS NULL THEN 1
			                             WHEN CAST(@OldSubmissionDate AS date) <> CAST(@AgendaSubmissionDate AS date) THEN 1
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
			-- MeetingDates-Step24: after the locks; "not before today" only for a date that changes
			ELSE IF (@MeetingDate IS NULL OR @AgendaSubmissionDate IS NULL)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'Missing';
			END
			ELSE IF (@DateChanged = 1 AND CAST(@MeetingDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'MeetingBeforeToday';
			END
			ELSE IF (@SubmissionChanged = 1 AND CAST(@AgendaSubmissionDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) > CAST(@MeetingDate AS date))
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionAfterMeeting';
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
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE UserId <> @CreatedBy AND AccountStatus = 1 AND IsSystem = 0);

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
-- ManagerRelease-Step52 (step MR1): a Manager's approve or reject is refused once the meeting date has passed, as
-- fn_AgendaWaitingFor says (DateOpen 0, the database server's date): Reason 28, after Reason 14, nothing saved and
-- no alert row written (the page sends no mail on a refusal). The Controller is not checked for the date: the
-- Controller's reject at AC or AMA (Agenda Finalization rejects every item not yet approved) stays possible.
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
			-- ManagerRelease-Step52: a Manager's decision after the meeting date
			ELSE IF (@MgrAction = 1
			         AND NOT EXISTS (SELECT 1 FROM dbo.fn_AgendaWaitingFor(@UpdatedBy, @Today) w
			                         WHERE w.AgendaId = @AgendaId AND w.CanApprove = 1 AND w.DateOpen = 1))
				SET @Reason = 28;
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

-------------------------------------------------------------------------------
-- Users - add / edit (UserProtection-Stage1; UserHistory-Step39)
-------------------------------------------------------------------------------
-- Save checks Create (acting user = @CreatedBy); Update checks Edit and, when the role really
-- changes, RoleChange (acting user = @UpdatedBy) (UserProtection-Stage1).
-- UserHistory-Step39: @DepartmentIds (optional, last) is the comma list of the user's departments:
-- digits and commas only, at most 2000 characters, each id at most 9 digits and a department that
-- exists; a department added by the list must be active. Only a Manager may have several; the home
-- department (@DepartmentId) must be in the list (Reason 23). NULL = not passed: a new user gets the
-- home department; an edit keeps the Manager's mappings and adds the home department. Every change is
-- written to User_Role / User_Department in the same transaction (rows dated today, by the acting
-- user). An inactive user's rows are left closed: only Users changes, Activate opens the rows.
-- A role change away from Manager closes his other departments (R) and is refused (Reason 24) when he
-- is the last active Manager of one of his departments with items waiting for a Manager, or when items
-- waiting at AC are routed to him; an edit that removes a department of a Manager checks that
-- department only. On success ReasonDetail is 'MappingsClosed:<names>' when departments were closed
-- by a role change away from Manager, otherwise ''.
-- ManagerRelease-Step52 (step MR1): the items routed to him are those fn_AgendaWaitingFor lets him approve, counted
-- apart by the meeting date (fn_ManagerReleaseRefusal Kinds 'P' and 'Q'). The Reason 24 ReasonDetail is
-- 'open:<n>|past:<n>|<department part>', the department part as before ('last active Manager of ...' or nothing).
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditUser]
@Code VARCHAR(50),
@UserId INT,
@UserName VARCHAR(50),
@DepartmentId INT,
@DesignationId INT,
@ManagerId INT,
@RoleId INT,
@EmailId VARCHAR(50),
@LoginName VARCHAR(50),
@Password VARCHAR(MAX),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT,
@DepartmentIds VARCHAR(MAX) = NULL
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @ActingUserId INT;
DECLARE @OldRoleId INT;
DECLARE @OldActive INT;
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @NewUserId INT;
DECLARE @IsManager INT;
DECLARE @WasManager INT;
DECLARE @Today DATE;
DECLARE @Now DATETIME;
DECLARE @Rest VARCHAR(MAX);
DECLARE @Pos INT;
DECLARE @Token VARCHAR(20);
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @Posted TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @Wanted TABLE (DepartmentId INT NOT NULL PRIMARY KEY, IsHome BIT NOT NULL);
DECLARE @OpenNow TABLE (DepartmentId INT NOT NULL PRIMARY KEY, IsHome BIT NOT NULL, IsVirtual BIT NOT NULL);
DECLARE @OldDepartmentId INT;
DECLARE @Lost TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @Refusal TABLE (Kind CHAR(1), DepartmentId INT NULL, DepartmentName NVARCHAR(200), Items INT);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
	SET @ActingUserId = CASE WHEN @Code = 'Save' THEN @CreatedBy ELSE @UpdatedBy END;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @Now = GETDATE();
	SET @IsManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleId AND RoleCode = 'manager') THEN 1 ELSE 0 END;

	-- The posted list, read as numbers only (UserHistory-Step39)
	IF (@DepartmentIds IS NOT NULL)
	BEGIN
		IF (LEN(@DepartmentIds) = 0 OR LEN(@DepartmentIds) > 2000 OR @DepartmentIds LIKE '%[^0-9,]%')
			SET @Detail = N'ListNotValid';
		ELSE
		BEGIN
			SET @Rest = @DepartmentIds + ',';
			WHILE (LEN(@Rest) > 0 AND @Detail = N'')
			BEGIN
				SET @Pos = CHARINDEX(',', @Rest);
				IF (@Pos <= 1 OR @Pos > 10)
					SET @Detail = N'ListNotValid';
				ELSE
				BEGIN
					SET @Token = LEFT(@Rest, @Pos - 1);
					SET @Rest = SUBSTRING(@Rest, @Pos + 1, LEN(@Rest));
					IF NOT EXISTS (SELECT 1 FROM @Posted WHERE DepartmentId = CAST(@Token AS INT))
						INSERT INTO @Posted (DepartmentId) VALUES (CAST(@Token AS INT));
				END
			END
		END

		IF (@Detail = N'' AND EXISTS (SELECT 1 FROM @Posted p WHERE NOT EXISTS (SELECT 1 FROM Department d WHERE d.DepartmentId = p.DepartmentId)))
			SET @Detail = N'DepartmentNotFound';
		ELSE IF (@Detail = N'' AND @IsManager = 0 AND (SELECT COUNT(*) FROM @Posted) > 1)
			SET @Detail = N'OneDepartmentOnly';
		ELSE IF (@Detail = N'' AND NOT EXISTS (SELECT 1 FROM @Posted WHERE DepartmentId = @DepartmentId))
			SET @Detail = N'HomeNotTicked';
	END

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
		SET @Detail = N'';
	END
	ELSE IF (@Code = 'Save')
	BEGIN
		SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, NULL, 'Create', @RoleId);

		IF (@Reason <> 0)
			SET @Detail = N'';
		ELSE IF (@Detail <> N'')
			SET @Reason = 23;
		ELSE IF (EXISTS (SELECT 1 FROM @Posted p JOIN Department d ON d.DepartmentId = p.DepartmentId WHERE ISNULL(d.StatusId, 0) <> 1))
		BEGIN
			SET @Reason = 23;
			SET @Detail = N'DepartmentInactive';
		END

		IF (@Reason = 0)
		BEGIN
			IF (@@TRANCOUNT = 0)
				SET @OwnTransaction = 1;
			ELSE
				SET @OwnTransaction = 0;

			BEGIN TRY
				IF (@OwnTransaction = 1)
					BEGIN TRANSACTION;
				ELSE
					SAVE TRANSACTION AddUser;

				INSERT INTO Users
				(UserName, DepartmentId, DesignationId, ManagerId,
					RoleId, EmailId, LoginName, Password, AccountStatus, CreatedOn, CreatedBy)
				VALUES
				(@UserName, @DepartmentId, @DesignationId, @ManagerId,
					@RoleId, @EmailId, @LoginName, @Password, 1, @CreatedOn, @CreatedBy);

				SET @NewUserId = SCOPE_IDENTITY();

				INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
				VALUES (@NewUserId, @RoleId, @Today, @Now, @ActingUserId);

				INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
				VALUES (@NewUserId, @DepartmentId, 1, @Today, @Now, @ActingUserId);

				INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
				SELECT @NewUserId, p.DepartmentId, 0, @Today, @Now, @ActingUserId
				FROM @Posted p
				WHERE p.DepartmentId <> @DepartmentId;

				SET @Result = 1;

				IF (@OwnTransaction = 1)
					COMMIT TRANSACTION;
			END TRY
			BEGIN CATCH
				SET @ErrMsg = ERROR_MESSAGE();

				IF (@OwnTransaction = 1)
				BEGIN
					IF (@@TRANCOUNT > 0)
						ROLLBACK TRANSACTION;
				END
				ELSE IF (XACT_STATE() = 1)
					ROLLBACK TRANSACTION AddUser;

				RAISERROR('%s', 16, 1, @ErrMsg);
				RETURN;
			END CATCH
		END
	END
	ELSE IF (@Code = 'Update')
	BEGIN
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION EditUser;

			SELECT @OldRoleId = RoleId, @OldDepartmentId = DepartmentId, @OldActive = ISNULL(AccountStatus, 0)
			FROM Users WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId;

			SET @WasManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @OldRoleId AND RoleCode = 'manager') THEN 1 ELSE 0 END;

			-- Rule 2 under concurrency (only a role change can break it here)
			IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
				WHERE AccountStatus = 1
				AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'Edit', NULL);

			IF (@Reason = 0 AND ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'RoleChange', @RoleId);

			IF (@Reason <> 0)
				SET @Detail = N'';
			ELSE IF (@Detail <> N'' AND @OldActive = 1)
				SET @Reason = 23;
			ELSE IF (@OldActive <> 1)
				-- An inactive user keeps closed rows: the list is not used (Activate opens the rows)
				SET @Detail = N'';

			IF (@Reason = 0 AND @OldActive = 1)
			BEGIN
				-- The open rows today, and the rows wanted after the save
				INSERT INTO @OpenNow (DepartmentId, IsHome, IsVirtual)
				SELECT DepartmentId, MAX(CAST(IsHome AS INT)), 0 FROM User_Department WITH (UPDLOCK, HOLDLOCK)
				WHERE UserId = @UserId AND EffectiveTo IS NULL
				GROUP BY DepartmentId;

				-- A user without an open department row (inserted directly, as the older test scripts do) counts
				-- as mapped to the department in Users: a row is written only when it changes
				IF NOT EXISTS (SELECT 1 FROM @OpenNow) AND @OldDepartmentId IS NOT NULL
					INSERT INTO @OpenNow (DepartmentId, IsHome, IsVirtual) VALUES (@OldDepartmentId, 1, 1);

				IF (@DepartmentIds IS NOT NULL)
					INSERT INTO @Wanted (DepartmentId, IsHome)
					SELECT DepartmentId, CASE WHEN DepartmentId = @DepartmentId THEN 1 ELSE 0 END FROM @Posted;
				ELSE IF (@IsManager = 1)
					INSERT INTO @Wanted (DepartmentId, IsHome)
					SELECT DepartmentId, CASE WHEN DepartmentId = @DepartmentId THEN 1 ELSE 0 END FROM @OpenNow
					UNION
					SELECT @DepartmentId, 1 WHERE NOT EXISTS (SELECT 1 FROM @OpenNow WHERE DepartmentId = @DepartmentId);
				ELSE
					INSERT INTO @Wanted (DepartmentId, IsHome) VALUES (@DepartmentId, 1);

				-- A department added by the list must be active
				IF EXISTS (SELECT 1 FROM @Posted p JOIN Department d ON d.DepartmentId = p.DepartmentId
				           WHERE ISNULL(d.StatusId, 0) <> 1
				             AND NOT EXISTS (SELECT 1 FROM @OpenNow o WHERE o.DepartmentId = p.DepartmentId))
				BEGIN
					SET @Reason = 23;
					SET @Detail = N'DepartmentInactive';
				END
			END

			-- Rule 12: a Manager who leaves departments
			IF (@Reason = 0 AND @OldActive = 1 AND @WasManager = 1)
			BEGIN
				IF (@IsManager = 0)
					INSERT INTO @Lost (DepartmentId) SELECT DepartmentId FROM @OpenNow;
				ELSE
					INSERT INTO @Lost (DepartmentId)
					SELECT o.DepartmentId FROM @OpenNow o WHERE NOT EXISTS (SELECT 1 FROM @Wanted w WHERE w.DepartmentId = o.DepartmentId);

				IF (EXISTS (SELECT 1 FROM @Lost) OR @IsManager = 0)
				BEGIN
					-- Two Managers of one department changing at the same time are serialised here
					SELECT @Locked = COUNT(*) FROM User_Department WITH (UPDLOCK, HOLDLOCK)
					WHERE EffectiveTo IS NULL AND DepartmentId IN (SELECT DepartmentId FROM @Lost);

					IF (@IsManager = 0)
						INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
						SELECT Kind, DepartmentId, DepartmentName, Items FROM dbo.fn_ManagerReleaseRefusal(@UserId, NULL, 1);
					ELSE
						INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
						SELECT f.Kind, f.DepartmentId, f.DepartmentName, f.Items
						FROM @Lost l
						CROSS APPLY dbo.fn_ManagerReleaseRefusal(@UserId, l.DepartmentId, 0) f;

					IF EXISTS (SELECT 1 FROM @Refusal)
					BEGIN
						SET @Reason = 24;
						-- ManagerRelease-Step52: 'open:<n>|past:<n>|' and then the department part as before ('last active
						-- Manager of <names with counts>', or nothing). open: Kind 'P', past: Kind 'Q'. The page builds the message.
						SET @Detail = N'open:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'P'), 0) AS NVARCHAR(12))
						            + N'|past:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'Q'), 0) AS NVARCHAR(12))
						            + N'|'
						            + ISNULL(N'last active Manager of '
						              + STUFF((SELECT N', ' + r.DepartmentName + N' (' + CAST(r.Items AS NVARCHAR(12))
						                              + CASE WHEN r.Items = 1 THEN N' item waiting)' ELSE N' items waiting)' END
						                       FROM @Refusal r WHERE r.Kind = 'D' ORDER BY r.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');
						SET @Detail = LEFT(@Detail, 2000);
					END
				END
			END

			IF (@Reason = 0)
			BEGIN
				UPDATE Users SET
				UserName = @UserName,
				DepartmentId = @DepartmentId,
				DesignationId = @DesignationId,
				ManagerId = @ManagerId,
				RoleId = @RoleId,
				EmailId = @EmailId,
				LoginName = @LoginName,
				UpdatedOn = @UpdatedOn,
				UpdatedBy = @UpdatedBy
				WHERE
				UserId = @UserId;

				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;

				-- History (UserHistory-Step39): active users only
				IF (@Result = 1 AND @OldActive = 1)
				BEGIN
					IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
					BEGIN
						UPDATE User_Role SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'C'
						WHERE UserId = @UserId AND EffectiveTo IS NULL;

						INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @RoleId, @Today, @Now, @ActingUserId);
					END

					IF (@WasManager = 1 AND @IsManager = 0)
						SET @Detail = ISNULL(N'MappingsClosed:'
						              + STUFF((SELECT N', ' + d.DepartmentName FROM @OpenNow o JOIN Department d ON d.DepartmentId = o.DepartmentId
						                       WHERE o.IsVirtual = 0
						                         AND NOT EXISTS (SELECT 1 FROM @Wanted w WHERE w.DepartmentId = o.DepartmentId)
						                       ORDER BY d.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');

					-- Close the rows that go away or whose home flag changes
					UPDATE ud SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId,
					       CloseReason = CASE WHEN @WasManager = 1 AND @IsManager = 0 AND w.DepartmentId IS NULL THEN 'R' ELSE 'C' END
					FROM User_Department ud
					LEFT JOIN @Wanted w ON w.DepartmentId = ud.DepartmentId
					WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL
					  AND (w.DepartmentId IS NULL OR w.IsHome <> ud.IsHome);

					-- Open the rows that are wanted and not open (nor unchanged in Users, for a user without rows)
					INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
					SELECT @UserId, w.DepartmentId, w.IsHome, @Today, @Now, @ActingUserId
					FROM @Wanted w
					WHERE NOT EXISTS (SELECT 1 FROM User_Department ud
					                  WHERE ud.UserId = @UserId AND ud.DepartmentId = w.DepartmentId AND ud.EffectiveTo IS NULL)
					  AND NOT EXISTS (SELECT 1 FROM @OpenNow o
					                  WHERE o.IsVirtual = 1 AND o.DepartmentId = w.DepartmentId AND o.IsHome = w.IsHome);
				END
			END

			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION EditUser;

			RAISERROR('%s', 16, 1, @ErrMsg);
			RETURN;
		END CATCH
	END

	IF (@Result <> 1 AND @Reason = 0)
		SET @Detail = N'';

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- Users - deactivate / activate (UserProtection-Stage1; UserHistory-Step39)
-------------------------------------------------------------------------------
-- UserHistory-Step39: Deactivate closes every open role and department row (D). Activate of an
-- inactive user is refused while the home department is inactive (Reason 23,
-- 'HomeDepartmentInactive:<name>'); otherwise it opens the role row (Users.RoleId) and the home
-- department, and for a Manager the other departments closed by the last deactivation; one that is
-- inactive now is skipped and named in ReasonDetail ('NotRestored:<names>'). Rows that are already
-- open are kept (an active user's Activate opens nothing).
-- ManagerRelease-Step52 (step MR1, owner 2026-11-19; UD1a had no check here): Deactivate of an active Manager is
-- refused by rule 12 as a role change away from Manager is (fn_ManagerReleaseRefusal, the department part and the
-- personal part): Reason 24, ReasonDetail 'open:<n>|past:<n>|<department part>', the same as spr_AddEditUser.
CREATE OR ALTER PROCEDURE [dbo].[spr_SetUserStatusByUserId]
@UserId INT,
@AccountStatus INT,
@ActingUserId INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @OldActive INT;
DECLARE @HomeId INT;
DECLARE @RoleIdNow INT;
DECLARE @IsManager INT;
DECLARE @LastClosed DATETIME;
DECLARE @Today DATE;
DECLARE @Now DATETIME;
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @Restore TABLE (DepartmentId INT NOT NULL PRIMARY KEY, Active INT NOT NULL, DepartmentName NVARCHAR(200));
DECLARE @Refusal TABLE (Kind CHAR(1), DepartmentId INT NULL, DepartmentName NVARCHAR(200), Items INT);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
	SET @Today = CAST(GETDATE() AS DATE);
	SET @Now = GETDATE();

	IF (@AccountStatus IS NULL OR @AccountStatus NOT IN (0, 1))
	BEGIN
		RAISERROR('spr_SetUserStatusByUserId: @AccountStatus must be 0 (inactive) or 1 (active).', 16, 1);
		RETURN;
	END

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
	END
	ELSE
	BEGIN
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION SetUserStatus;

			-- Rule 2 under concurrency: hold the active Admin / Controller rows
			-- until this transaction ends.
			SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
			WHERE AccountStatus = 1
			AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId,
			                  CASE WHEN @AccountStatus = 0 THEN 'Deactivate' ELSE 'Activate' END, NULL);

			SELECT @OldActive = ISNULL(AccountStatus, 0), @HomeId = DepartmentId, @RoleIdNow = RoleId
			FROM Users WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId;

			-- ManagerRelease-Step52: rule 12 on Deactivate of an active Manager, under the same lock as a role change
			IF (@Reason = 0 AND @AccountStatus = 0 AND @OldActive = 1
			    AND EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager'))
			BEGIN
				SELECT @Locked = COUNT(*) FROM User_Department WITH (UPDLOCK, HOLDLOCK)
				WHERE EffectiveTo IS NULL
				AND DepartmentId IN (SELECT DepartmentId FROM User_Department WHERE UserId = @UserId AND EffectiveTo IS NULL);

				INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
				SELECT Kind, DepartmentId, DepartmentName, Items FROM dbo.fn_ManagerReleaseRefusal(@UserId, NULL, 1);

				IF EXISTS (SELECT 1 FROM @Refusal)
				BEGIN
					SET @Reason = 24;
					-- ManagerRelease-Step52: 'open:<n>|past:<n>|' and then the department part as before ('last active
					-- Manager of <names with counts>', or nothing). open: Kind 'P', past: Kind 'Q'. The page builds the message.
					SET @Detail = N'open:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'P'), 0) AS NVARCHAR(12))
					            + N'|past:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'Q'), 0) AS NVARCHAR(12))
					            + N'|'
					            + ISNULL(N'last active Manager of '
					              + STUFF((SELECT N', ' + r.DepartmentName + N' (' + CAST(r.Items AS NVARCHAR(12))
					                              + CASE WHEN r.Items = 1 THEN N' item waiting)' ELSE N' items waiting)' END
					                       FROM @Refusal r WHERE r.Kind = 'D' ORDER BY r.DepartmentName
					                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');
					SET @Detail = LEFT(@Detail, 2000);
				END
			END

			-- UserHistory-Step39: no activation into an inactive home department
			IF (@Reason = 0 AND @AccountStatus = 1 AND @OldActive = 0
			    AND EXISTS (SELECT 1 FROM Department WHERE DepartmentId = @HomeId AND ISNULL(StatusId, 0) <> 1))
			BEGIN
				SET @Reason = 23;
				SET @Detail = LEFT(N'HomeDepartmentInactive:' + ISNULL((SELECT CAST(DepartmentName AS NVARCHAR(200)) FROM Department WHERE DepartmentId = @HomeId), N''), 2000);
			END

			IF (@Reason = 0)
			BEGIN
				UPDATE Users SET
				AccountStatus = @AccountStatus,
				UpdatedOn = GETDATE(),
				UpdatedBy = @ActingUserId
				WHERE
				UserId = @UserId;

				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;

				-- History (UserHistory-Step39)
				IF (@Result = 1 AND @AccountStatus = 0)
				BEGIN
					UPDATE User_Role SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'D'
					WHERE UserId = @UserId AND EffectiveTo IS NULL;

					UPDATE User_Department SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'D'
					WHERE UserId = @UserId AND EffectiveTo IS NULL;
				END

				IF (@Result = 1 AND @AccountStatus = 1)
				BEGIN
					IF NOT EXISTS (SELECT 1 FROM User_Role WHERE UserId = @UserId AND EffectiveTo IS NULL)
					   AND EXISTS (SELECT 1 FROM User_Role WHERE UserId = @UserId)
						INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @RoleIdNow, @Today, @Now, @ActingUserId);

					IF NOT EXISTS (SELECT 1 FROM User_Department WHERE UserId = @UserId AND EffectiveTo IS NULL)
					   AND EXISTS (SELECT 1 FROM User_Department WHERE UserId = @UserId)
					BEGIN
						INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @HomeId, 1, @Today, @Now, @ActingUserId);

						SET @IsManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager') THEN 1 ELSE 0 END;

						IF (@IsManager = 1)
						BEGIN
							SET @LastClosed = (SELECT MAX(ClosedOn) FROM User_Department WHERE UserId = @UserId AND CloseReason = 'D');

							INSERT INTO @Restore (DepartmentId, Active, DepartmentName)
							SELECT DISTINCT ud.DepartmentId, CASE WHEN ISNULL(d.StatusId, 0) = 1 THEN 1 ELSE 0 END, CAST(d.DepartmentName AS NVARCHAR(200))
							FROM User_Department ud
							JOIN Department d ON d.DepartmentId = ud.DepartmentId
							WHERE ud.UserId = @UserId AND ud.CloseReason = 'D' AND ud.ClosedOn = @LastClosed
							  AND ud.DepartmentId <> @HomeId;

							INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
							SELECT @UserId, r.DepartmentId, 0, @Today, @Now, @ActingUserId
							FROM @Restore r WHERE r.Active = 1;

							IF EXISTS (SELECT 1 FROM @Restore WHERE Active = 0)
								SET @Detail = LEFT(N'NotRestored:'
								              + STUFF((SELECT N', ' + r.DepartmentName FROM @Restore r WHERE r.Active = 0 ORDER BY r.DepartmentName
								                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), 2000);
						END
					END
				END
			END

			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION SetUserStatus;

			RAISERROR('%s', 16, 1, @ErrMsg);
			RETURN;
		END CATCH
	END

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO


-- The two objects of step 53 (nothing else uses them now)
IF OBJECT_ID('dbo.spr_SetManagerAlertRows', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_SetManagerAlertRows;
IF OBJECT_ID('dbo.fn_DepartmentManagers', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_DepartmentManagers;
GO

DECLARE @D NVARCHAR(MAX), @I INT, @Bad SYSNAME;
DECLARE @H00 VARCHAR(400), @H01 VARCHAR(400), @H02 VARCHAR(400), @H03 VARCHAR(400), @H04 VARCHAR(400), @H05 VARCHAR(400), @H06 VARCHAR(400), @H07 VARCHAR(400), @H08 VARCHAR(400), @H09 VARCHAR(400), @H10 VARCHAR(400), @H11 VARCHAR(400), @H12 VARCHAR(400), @H13 VARCHAR(400), @H14 VARCHAR(400), @H15 VARCHAR(400), @H16 VARCHAR(400), @H17 VARCHAR(400);
DECLARE @Texts TABLE (Name SYSNAME PRIMARY KEY, Hash VARCHAR(400), BuiltFrom VARCHAR(400));
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_AgendaRoute')), CHAR(13), ''); SET @H00 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H00 = @H00 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_AgendaWaitingFor')), CHAR(13), ''); SET @H01 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H01 = @H01 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_ManagerReleaseRefusal')), CHAR(13), ''); SET @H02 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H02 = @H02 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardAlerts')), CHAR(13), ''); SET @H03 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H03 = @H03 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardAlerts')), CHAR(13), ''); SET @H04 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H04 = @H04 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertCount')), CHAR(13), ''); SET @H05 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H05 = @H05 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), CHAR(13), ''); SET @H06 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H06 = @H06 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), CHAR(13), ''); SET @H07 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H07 = @H07 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaCreationMailId')), CHAR(13), ''); SET @H08 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H08 = @H08 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_RerouteWaitingAgendas')), CHAR(13), ''); SET @H09 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H09 = @H09 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditCommittee')), CHAR(13), ''); SET @H10 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H10 = @H10 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), CHAR(13), ''); SET @H11 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H11 = @H11 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), CHAR(13), ''); SET @H12 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H12 = @H12 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), CHAR(13), ''); SET @H13 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H13 = @H13 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), CHAR(13), ''); SET @H14 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H14 = @H14 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), CHAR(13), ''); SET @H15 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H15 = @H15 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), CHAR(13), ''); SET @H16 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H16 = @H16 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetUserStatusByUserId')), CHAR(13), ''); SET @H17 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H17 = @H17 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
INSERT INTO @Texts (Name, Hash, BuiltFrom) VALUES
('fn_AgendaRoute', @H00, '00FEB2D05A96D4D50CE621FDB00AC88D10F1E336'),
('fn_AgendaWaitingFor', @H01, '4DB279D9C242C8F61AD81F270F9E0EDC2F12054E'),
('fn_ManagerReleaseRefusal', @H02, 'EBE4B95581F5FA948200D28DF47E38836E06A21A'),
('fn_DashboardAlerts', @H03, '65D104646DDF69FDBDEF264CD7F3272B325D5886'),
('spr_GetDashboardAlerts', @H04, '88A60ACC0F7FE2CCB339FE18CE9E52F6F4FF3142'),
('spr_GetAlertCount', @H05, 'E28542502ECA2B103E7050E0B44FD6D11EA1E62D'),
('spr_GetAlertMailId', @H06, 'B42747DAF00CFD72B91856B04E1F9D3E16DA12ED'),
('spr_GetAgendaUpdateMailId', @H07, '767F0743C2D2BCA555DAFA1272948BA07772594E'),
('spr_GetAgendaCreationMailId', @H08, 'B790FC2AD9C2B61AE7269C7BE879838E2311A100'),
('spr_RerouteWaitingAgendas', @H09, 'A63918E22D8D3806512BCEF20793FE8A0C35CF9E'),
('spr_AddEditCommittee', @H10, 'BEF007B29FC31239C48519C63A994D6D79EF760B'),
('spr_AddEditMeeting', @H11, '6CF0A43B240A3F68D83DCC018CD2BCCB600673B95593126D0F62C7610997F64F0E5A9401D950B649'),
('spr_AddEditAgenda', @H12, '8EB6F8E6EC9AF9F9190501200854DC6550D5A7B4C49A094457E5F971412057479A4EDE24AFDE7A4DDBF3681943E16E09FC8BCD9068C9FEDC197D5270D583DAAC83FE4B1437689AD682FABC2A31C7A1B350419736438E4CF2D6872C9C6FD7955EB88A7C13'),
('spr_AddEditAgendaByManager', @H13, '932EC8CC434CD573EB8D80E502FD9C6E8A050862D2992D0B9D61905EE0E7FB0EA2A24834103E746039FEC5AF6FA8E6CB86878A3C40CAD94CE99CCEC54DE37F35749D0664AE87874C135DE170949B7A6E995909DAADB7A28FAF00AF5AA2F3AB81348D2FEB'),
('spr_AddEditAgendaByController', @H14, '0E6252B56DDEECE77B30D0003DB3B58670E9F8FF1C00E570697F6B3F9B83B282A9C6BC7670EF8FDC0B01DA99867188D55234D1D0857B58905F22E47C0733731BF0097EAA800A91E6896352C47ECA54D68CF6DCF2DF78F9221B81B51C0C5B1BD852035088'),
('spr_UpdateAgendaByAgendaId', @H15, '2A62B18591EE2A14864ABB7F3A05EC05D5635B6623DD81F632108458C46725918C11F0701300DA781E2E740E202BDFE804E72A96F2E01F084A5CA167'),
('spr_AddEditUser', @H16, 'F4251C6114E2A6CB319B17E80DAC9ADECE311C797EBEEAC9DB54DBE19DC20D0306CFEFEF44E96DB2C52F7BF7C1294380C1F88F495CFA3D156F0F48D601E5A004C42CFE95F5BE9722AECACC31B19078E2'),
('spr_SetUserStatusByUserId', @H17, '0E740A527590161EEAAF73000467AC2827BFE2D9A5F56D9CC99C2FF011923CED1A6E1C0409C3B54E7385B90014A5FA422DD90F8F9B422C94CEBB3221');

SET @Bad = (SELECT TOP 1 Name FROM @Texts WHERE ISNULL(Hash, '') <> BuiltFrom ORDER BY Name);

-- Items at AC on an open agenda that no active Manager may decide under the restored rule of step 20 (the creator's
-- manager, or a Manager with a row on the item's alert)
DECLARE @Orphans INT = (SELECT COUNT(*) FROM Agenda a JOIN Meeting mt ON mt.MeetingId = a.MeetingId
                        WHERE a.AgendaStatusCode = 'AC' AND ISNULL(mt.AgendaStatus, 'Open') = 'Open'
                          AND NOT EXISTS (SELECT 1 FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                                          LEFT JOIN Users c ON c.UserId = a.CreatedBy
                                          WHERE r.RoleCode = 'manager' AND u.AccountStatus = 1 AND u.IsSystem = 0
                                            AND (c.ManagerId = u.UserId
                                                 OR EXISTS (SELECT 1 FROM Alert_User_Map mp JOIN Alert_Master am ON am.AlertId = mp.AlertId
                                                            WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId AND mp.UserId = u.UserId))));
-- Rows on the alerts of items at AC (open agenda) of active Manager-role users who are not Managers of the item's
-- department (open User_Department row, or Users.DepartmentId without any row): under the restored rule each such row
-- lets that Manager decide the item. Counted apart: rows marked 'N' and 'M' by step 53, and other rows.
DECLARE @OutN INT, @OutM INT, @OutOther INT;
SELECT @OutN = ISNULL(SUM(CASE WHEN m.HandledReason = 'N' THEN 1 ELSE 0 END), 0),
       @OutM = ISNULL(SUM(CASE WHEN m.HandledReason = 'M' THEN 1 ELSE 0 END), 0),
       @OutOther = ISNULL(SUM(CASE WHEN ISNULL(m.HandledReason, '') NOT IN ('N', 'M') THEN 1 ELSE 0 END), 0)
FROM Alert_User_Map m
JOIN Alert_Master am ON am.AlertId = m.AlertId AND am.SourceType = 'Agenda'
JOIN Agenda a ON a.AgendaId = am.SourceTypeId
JOIN Meeting mt ON mt.MeetingId = a.MeetingId
JOIN Users u ON u.UserId = m.UserId
JOIN Roles r ON r.RoleId = u.RoleId
WHERE a.AgendaStatusCode = 'AC' AND ISNULL(mt.AgendaStatus, 'Open') = 'Open'
  AND r.RoleCode = 'manager' AND u.AccountStatus = 1 AND u.IsSystem = 0
  AND NOT EXISTS (SELECT 1 FROM User_Department ud WHERE ud.UserId = u.UserId AND ud.DepartmentId = a.DepartmentId AND ud.EffectiveTo IS NULL)
  AND NOT (u.DepartmentId = a.DepartmentId AND NOT EXISTS (SELECT 1 FROM User_Department ux WHERE ux.UserId = u.UserId));
IF (@OutN + @OutM + @OutOther > 0)
    PRINT 'Note: ' + CAST(@OutN + @OutM + @OutOther AS VARCHAR(12)) + ' alert row(s) of items at AC belong to active Managers who are not Managers of the item''s department ('
        + CAST(@OutN AS VARCHAR(12)) + ' marked N (no longer Manager) and ' + CAST(@OutM AS VARCHAR(12)) + ' marked M (item moved) by step 53, ' + CAST(@OutOther AS VARCHAR(12)) + ' other); under the restored rule each lets that Manager approve or reject the item. Before the next approvals, remove those rows (the Consultant) or tell those Managers not to decide those items.';
ELSE
    PRINT 'Alert rows of items at AC held by Managers outside the item''s department: 0.';

IF (@Orphans > 0)
    PRINT 'Note: ' + CAST(@Orphans AS VARCHAR(12)) + ' item(s) wait at AC on an open agenda that no active Manager may decide under the restored rule (no active Manager is the creator''s Reporting Person or has a row on the item''s alert). Only the Controller can reject them now. To send them on, give their creators an active Manager as Reporting Person, or send them to the Controllers with the one-time re-route of step 20: EXEC dbo.spr_RerouteWaitingAgendas;';
ELSE
    PRINT 'Items at AC that no active Manager may decide under the restored rule: 0.';

IF (@Bad IS NOT NULL)
    RAISERROR('Step 53: the 18 texts were put back, but %s is NOT letter for letter the text step 53 was built from (SHA-1 differs). Tell the Consultant.', 16, 1, @Bad);
ELSE
    PRINT 'Step 53 rolled back: the 18 texts are again those of the earlier steps, letter for letter (SHA-1 compared); fn_DepartmentManagers and spr_SetManagerAlertRows are dropped. The columns HandledReason, HandledBy, HandledOn (Alert_User_Map) and RouteNote (Agenda), their checks and key, and the rows step 53 marked or added are kept.';
GO

SET NOEXEC OFF;
GO
