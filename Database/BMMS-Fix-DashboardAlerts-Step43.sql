/* ============================================================================
   BMMS - Dashboard alert rules, "Remove from my list", overdue followups,
   header count; no functional alerts or mails for the Admin role
   (step 43, step UN6c1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision UN6c1 (2026-11-12 to 2026-11-13, plan approved): the
   Dashboard's Alerts card lists by one rule on the server, from the acting
   user id alone (the role is read from the database, nothing comes from the
   page); the header count uses the same rule.

   Eight new objects:

     fn_DashboardAlerts(@UserId INT)               inline table function
         The one listing rule. The user's Alert_User_Map rows with StatusId 1
         (not removed from the list), joined as View_Alert does (an alert
         without a committee or with an unknown type is not listed), with:
           - the role filters of spr_GetAlertByUserId: a Controller does not
             see ACA and ACR, a Manager does not see AMA and AMR;
           - nothing functional for the Admin role. All eleven alert types of
             today are functional (CC, CU, MC, MU, AC, AMA, AMR, ACA, ACR, AF,
             MF), so an Admin - the protected system account too, it has the
             Admin role - gets an empty list. The rows stay in the tables. A
             later technical type is not in this list and would be shown;
           - EventOn and the acting person (ActorUserId, ActorName,
             ActorLogin):
               an alert of an agenda item at AC      Agenda.UpdatedOn / UpdatedBy,
                                                     else Agenda.CreatedOn / CreatedBy
               AMA, AMR                              Agenda.MgrApprovedDate / MgrApprovedBy
               ACA, ACR                              Agenda.ControllerApprovedDate /
                                                     ControllerApprovedBy
               AMA to ACR, edited after the decision Agenda.UpdatedOn / UpdatedBy, when
                                                     UpdatedOn is MORE THAN ONE MINUTE
                                                     after the decision date (a decision
                                                     sets both columns with two clock
                                                     reads; they can differ by
                                                     milliseconds)
               AMA to ACR without a recorded         Agenda.UpdatedOn, else the alert's
               approver (before step 35)             CreatedOn; no acting person
               every other alert (CC, CU, MC, MU,    Alert_Master.CreatedOn / CreatedBy
               AF, MF; an agenda alert whose item
               is gone)
     spr_GetDashboardAlerts                        the Alerts card
         @ActingUserId, @Mode ('R' recent: every unread alert and the read
         alerts whose EventOn is today or in the seven days before; 'U'
         unread; 'A' all), @PageNo (10 rows a page, ROW_NUMBER; a page after
         the last gives the last), and as OUTPUT @Result, @Reason, @TotalRows
         (of the mode), @UnreadCount (of the whole list), @PageShown.
         Newest EventOn first.
     spr_GetAlertCount                             the header "Alerts (n)"
         @ActingUserId; OUTPUT @Result, @Reason, @UnreadCount: the unread rows
         of fn_DashboardAlerts.
     spr_RemoveAlertForUser                        "Remove from my list"
         @ActingUserId, @AlertUserId; OUTPUT @Result, @Reason. Sets StatusId 0
         on that row only when it is the acting user's own row. Nothing is
         deleted; step 36 shows the alert again, unread, on an edit.
     fn_DashboardActionItems(@UserId INT, @Today DATE)   inline table function
         The one scope rule of the Action Items card (owner decision
         2026-11-13, after the owner's test of UN6c1: the card listed only
         the items MAPPED to the signed-in user, and the mapping follows the
         creator of the agenda item or "every active user at finalising",
         never the department). An item is an Action_Item with IsConfirmed 0,
         tied to a department by its agenda item:
           Controller, Management   all of them, whatever the minutes status;
           Manager, User            those of their departments
                                    (fn_UserDepartmentScope, step 42) whose
                                    minutes are finalised (F) or confirmed (C);
           MD Secretariat, Admin    none.
         The mapping rows only hold each person's read state now: a person
         without a row sees the item unread. IsOverdue: 1 when Minutes.DueDate
         is set, its DATE is before the database server's date, and the item
         is neither complied (IsComplied 0) nor confirmed (IsConfirmed 0).

     spr_GetDashboardActionItems                   the Action Items card
         @ActingUserId; OUTPUT @Result, @Reason. The rows of the function,
         newest meeting first.

     spr_OpenDashboardActionItem                   opening an item of the card
         @ActingUserId, @ActionItemId; OUTPUT @Result, @Reason. Only an item
         in the acting user's scope. Marks the person's own row read and
         creates it when missing (never a second row). Returns the item.

     spr_SaveDashboardActionText                   Submit of the details panel
         @ActingUserId, @ActionItemId, @ActionText; OUTPUT @Result, @Reason.
         Only a Controller, a Manager or a User, only an item in the acting
         user's scope; writes Action_Item.ActionText (as spr_UpdateActionItem
         does for the code 'ActionText'). Management is refused.

     Reason 8  the acting user is missing, 0 or inactive
     Reason 4  a mode other than R, U, A; a page number below 1; an alert row
               that is not the acting user's (or does not exist); for the
               action items: a role without the card (MD Secretariat, Admin),
               an item outside the acting user's scope, a Submit by Management
     A refused call returns the same columns with no rows and changes nothing.

   Two procedures are REPLACED (their texts as installed by steps 18 and 37,
   with one change each; BMMS-Rollback-DashboardAlerts-Step43.sql puts the
   earlier texts back, letter for letter):

     spr_GetAlertMailId            the Bcc of the approve / reject mails
         (Dashboard and Agenda Finalization). The Admin role is left out in
         EVERY branch: AMR (the creator), AMA (the Controllers and the
         creator), ACA / ACR (the users of the item's alert).
     spr_GetAgendaUpdateMailId     the Bcc of the update mail (Agenda Entry).
         The Admin role is left out.

   The script stops when one of the two is neither the text this step was
   built from nor already the step 43 text (a later change would be lost).

   Not changed: spr_GetAlertByUserId, spr_UpdateAlertByAlertUserId (after the
   build of UN6c1 nothing calls them), spr_UpdateAlertByUserId, View_Alert,
   and the five procedures that write alerts (they still add rows for the
   Admin role until UD1b; the listing rule hides them). Not changed either:
   spr_UpdateMinutes and spr_MinutesFinalizeByMeetingId, which write the
   mapping rows of the action items as before (the creator; every active
   user at finalising), spr_UpdateActionItem (the Followup page; it has no
   acting-user check of its own), spr_UpdateActionItemByUserId,
   spr_GetActionItemByUserId, spr_GetActionItemByActionItemIdUserId and
   View_Action_Item_Users (after this build the Dashboard calls none of
   them).

   EXECUTE permission: as step 42, the script grants nothing. The application
   login holds EXECUTE on the schema dbo, which covers new procedures; the
   Test script checks that every database user who can run step 42's
   procedure can run the procedures of this step.

   Changes no data. Safe to re-run. Installed after step 42 (it stops
   otherwise). Install BEFORE the build of step UN6c1: that build calls these
   procedures.

   Marker DashboardAlerts-Step43 in each object (10 markers in
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
DECLARE @MailHash VARCHAR(40);
DECLARE @UpdateMailHash VARCHAR(40);

-- The two mail procedures as they are now: SHA-1 of the text without carriage returns
SET @MailHash = CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), CHAR(13), '') AS NVARCHAR(4000))), 2);
SET @UpdateMailHash = CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), CHAR(13), '') AS NVARCHAR(4000))), 2);

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') NOT LIKE '%DashboardMeetings-Step42%'
         OR OBJECT_ID('dbo.spr_GetAlertMailId', 'P') IS NULL OR OBJECT_ID('dbo.spr_GetAgendaUpdateMailId', 'P') IS NULL
         OR COL_LENGTH('dbo.Agenda', 'MgrApprovedBy') IS NULL OR COL_LENGTH('dbo.Minutes', 'DueDate') IS NULL)
BEGIN
    RAISERROR('Step 42 (BMMS-Fix-DashboardMeetings-Step42.sql) is not installed in "%s", or an earlier step is missing (spr_GetAlertMailId, spr_GetAgendaUpdateMailId of step 37, Agenda.MgrApprovedBy of step 35, Minutes.DueDate of step 38). The steps are installed in order: run them first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF ((@MailHash <> '7C811E422DCF63725C91DA81EC5EB3195B677E73' AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), '') NOT LIKE '%DashboardAlerts-Step43%')
         OR (@UpdateMailHash <> 'F6BD3580A632DF8643F2406DA53F1256D8FC6D33' AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), '') NOT LIKE '%DashboardAlerts-Step43%'))
BEGIN
    RAISERROR('spr_GetAlertMailId or spr_GetAgendaUpdateMailId in "%s" is not the text this step was built from (steps 18 and 37) and not the step 43 text either: a change made since would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
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

-- "Remove from my list" (DashboardAlerts-Step43, step UN6c1): StatusId 0 on one Alert_User_Map row, only when it is
-- the acting user's own row. Reason 8: acting user missing or inactive; Reason 4: the row is another user's or does
-- not exist; then nothing changes. Nothing is deleted (step 36 shows the alert again, unread, on an edit).
CREATE OR ALTER PROCEDURE [dbo].[spr_RemoveAlertForUser]
@ActingUserId INT = NULL,
@AlertUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;

	IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF NOT EXISTS (SELECT 1 FROM Alert_User_Map WHERE AlertUserId = @AlertUserId AND UserId = @ActingUserId)
		SET @Reason = 4;
	ELSE
	BEGIN
		UPDATE Alert_User_Map SET StatusId = 0
		WHERE AlertUserId = @AlertUserId AND UserId = @ActingUserId;

		SET @Result = 1;
	END
END
GO

-- Dashboard action items (DashboardAlerts-Step43, step UN6c1): the one scope rule of the Action Items card, from the
-- acting user id alone (the role is read from Users; nothing comes from the page). An item is an Action_Item that is
-- not confirmed (IsConfirmed 0), tied to a department by its agenda item (Agenda.DepartmentId).
--   Controller, Management   every such item, whatever the minutes status (they see draft minutes as well);
--   Manager, User            the items of their departments (fn_UserDepartmentScope on @Today: a Manager can have
--                            several) whose minutes are finalised (F) or confirmed (C);
--   every other role (MD Secretariat, Admin and with it the protected system account), an inactive or unknown
--   user                     no rows.
-- The mapping rows (ActionItem_User_Map) decide nothing about who sees an item any more: they only hold each
-- person's own read state. ReadStatus is that of the acting user's row (1 when one of several rows is read; the
-- table has no unique index), and 0 - unread - for a person without a row. UserId is the acting user.
-- IsOverdue: the due date (Minutes.DueDate) is set, its DATE is before @Today, and the item is neither complied
-- nor confirmed. The columns are those of View_Action_Item_Users, and IsOverdue.
CREATE OR ALTER FUNCTION [dbo].[fn_DashboardActionItems]
(
@UserId INT,
@Today DATE
)
RETURNS TABLE
AS
RETURN
SELECT
ai.ActionItemId,
ai.MinutesId,
ai.ActionText,
ai.ActionStatus,
mi.AgendaId,
mi.DecisionTypeId,
mi.DueDate,
a.AgendaNo,
a.CommitteeId,
a.MeetingId,
dt.DecisionTypeCode,
dt.DecisionTypeName,
a.SubjectNo,
d.DepartmentCode,
d.DepartmentName,
mi.ActualResolution,
c.CommitteeName,
c.CommitteeCode,
mt.MeetingDate,
mt.MeetingTime,
mt.Venue,
u.UserId,
CAST(ISNULL(rs.ReadStatus, 0) AS INT) AS ReadStatus,
a.DepartmentId,
ai.Directions,
ai.IsComplied,
ai.IsConfirmed,
CAST(CASE WHEN mi.DueDate IS NOT NULL AND CAST(mi.DueDate AS DATE) < @Today
               AND ISNULL(ai.IsComplied, 0) = 0 AND ISNULL(ai.IsConfirmed, 0) = 0 THEN 1 ELSE 0 END AS INT) AS IsOverdue
FROM Users u
INNER JOIN Roles r ON r.RoleId = u.RoleId
CROSS JOIN Action_Item ai
INNER JOIN Minutes mi ON mi.MinutesId = ai.MinutesId
INNER JOIN Agenda a ON a.AgendaId = mi.AgendaId
INNER JOIN Decision_Type dt ON dt.DecisionTypeId = mi.DecisionTypeId
INNER JOIN Meeting mt ON mt.MeetingId = a.MeetingId
INNER JOIN Committee c ON c.CommitteeId = a.CommitteeId
INNER JOIN Department d ON d.DepartmentId = a.DepartmentId
OUTER APPLY (SELECT MAX(ISNULL(m.ReadStatus, 0)) AS ReadStatus
             FROM ActionItem_User_Map m
             WHERE m.ActionItemId = ai.ActionItemId AND m.UserId = u.UserId) rs
WHERE u.UserId = @UserId
AND u.AccountStatus = 1
AND ISNULL(ai.IsConfirmed, 0) = 0
AND (r.RoleCode IN ('controller', 'mgmt')
     OR (r.RoleCode IN ('manager', 'user')
         AND ISNULL(mt.MinutesStatus, 'Open') IN ('F', 'C')
         AND a.DepartmentId IN (SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(u.UserId, @Today) s)));
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

-- Opening an action item from the Dashboard (DashboardAlerts-Step43, step UN6c1): allowed only for an item the
-- acting user sees by fn_DashboardActionItems. It marks the acting user's own read row (ActionItem_User_Map) as
-- read and creates that row when the person has none (the check and the insert are one statement under an update
-- lock that is held, so two calls at once cannot create two rows; the table has no unique index). Nothing of the
-- action item itself is changed, so Management opens read-only. Returns the item's row (the columns of the list).
-- Reason 8: acting user missing, 0 or inactive. Reason 4: a role without the card, or an item that is outside the
-- acting user's scope, confirmed or unknown; then no row is returned and nothing is written.
CREATE OR ALTER PROCEDURE [dbo].[spr_OpenDashboardActionItem]
@ActingUserId INT = NULL,
@ActionItemId INT = NULL,
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
	ELSE IF NOT EXISTS (SELECT 1 FROM dbo.fn_DashboardActionItems(@ActingUserId, @Today) f WHERE f.ActionItemId = @ActionItemId)
		SET @Reason = 4;
	ELSE
	BEGIN
		INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId)
		SELECT @ActionItemId, @ActingUserId, 1, 1
		WHERE NOT EXISTS (SELECT 1 FROM ActionItem_User_Map m WITH (UPDLOCK, HOLDLOCK)
		                  WHERE m.ActionItemId = @ActionItemId AND m.UserId = @ActingUserId);

		UPDATE ActionItem_User_Map SET
		ReadStatus = 1
		WHERE ActionItemId = @ActionItemId
		AND UserId = @ActingUserId
		AND ISNULL(ReadStatus, 0) <> 1;

		SET @Result = 1;
	END

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
	AND f.ActionItemId = @ActionItemId;
END
GO

-- Saving the action text from the Dashboard's Action Item Details panel (DashboardAlerts-Step43, step UN6c1). The
-- check is here, on the server, whatever the page sends: only a Controller, a Manager or a User (the roles whose
-- panel has an editable action text), and only for an item the acting user sees by fn_DashboardActionItems. It
-- writes what spr_UpdateActionItem writes for the code 'ActionText': Action_Item.ActionText, nothing else.
-- Reason 8: acting user missing, 0 or inactive. Reason 4: Management, MD Secretariat, Admin, or an item that is
-- outside the acting user's scope, confirmed or unknown; then nothing is saved. The scope is part of the UPDATE
-- itself, so an item that leaves the scope between the check and the write (confirmed meanwhile) is not written.
CREATE OR ALTER PROCEDURE [dbo].[spr_SaveDashboardActionText]
@ActingUserId INT = NULL,
@ActionItemId INT = NULL,
@ActionText NVARCHAR(MAX) = NULL,
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
	ELSE IF (ISNULL(@RoleCode, '') NOT IN ('controller', 'manager', 'user'))
		SET @Reason = 4;
	ELSE
	BEGIN
		UPDATE Action_Item SET
		ActionText = @ActionText
		WHERE ActionItemId = @ActionItemId
		AND EXISTS (SELECT 1 FROM dbo.fn_DashboardActionItems(@ActingUserId, @Today) f WHERE f.ActionItemId = @ActionItemId);

		IF (@@ROWCOUNT = 1)
			SET @Result = 1;
		ELSE
			SET @Reason = 4;
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

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardAlerts')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardAlerts')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertCount')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_RemoveAlertForUser')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Installed = @Installed + 1;

IF (@Installed = 10)
    PRINT 'Step 43 installed: fn_DashboardAlerts, spr_GetDashboardAlerts, spr_GetAlertCount, spr_RemoveAlertForUser, fn_DashboardActionItems, spr_GetDashboardActionItems, spr_OpenDashboardActionItem and spr_SaveDashboardActionText are new; spr_GetAlertMailId and spr_GetAgendaUpdateMailId leave out the Admin role (DashboardAlerts-Step43).';
ELSE
    RAISERROR('Step 43 is not complete: %d of 10 objects carry the marker DashboardAlerts-Step43. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
