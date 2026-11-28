/* ============================================================================
   BMMS - Dashboard: a confirmed followup is final there too; who confirmed
   or reopened it, and when; the word "Reopened" in the Action Items card
   (step 48, step FU2a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision FU2a (2026-11-16, plan approved with four answers: the
   saved text is shown after a refusal; a read row made by opening a
   confirmed item gets StatusId 0; the older Test scripts expect by the
   step 48 marker; the name of the step).

   Step 47 (step FU1) made a confirmed followup final on the Followup page,
   with Reopen and the table Action_Item_Status_History. This step does the
   same for the Dashboard's Action Items card and its Action Item Details
   panel.

   New:
     fn_DashboardActionItemScope(@UserId INT, @Today DATE)   inline table function
         The scope rule of the Action Items card (step 43) WITHOUT the
         filter on confirmed items: which items a person may open. The 28
         columns of step 43 and seven more, from the latest history row of
         the item (the highest StatusHistoryId) and the user who acted:
           IsReopened      1 when that row is a Reopen and the item is not
                           confirmed; else 0
           StatusAction    'Confirm', 'Reopen' or NULL (no history row: never
                           confirmed, or confirmed before step 47)
           StatusReason    the reason of a Reopen (NULL for a Confirm)
           StatusOn        when (the database server's time)
           StatusByName, StatusByLogin, StatusByActive   the user who acted

   Replaced (their texts as installed by steps 43 and 45; each keeps the
   markers of its earlier steps; BMMS-Rollback-DashboardFollowupFinal-
   Step48.sql puts the earlier texts back, letter for letter):
     fn_DashboardActionItems       (step 43) the rows of the scope function
         that are not confirmed: the same rows as before, with the seven
         columns after IsOverdue (35 columns).
     spr_GetDashboardActionItems   (step 45) the seven columns. Parameters,
         rows, order and Reasons are unchanged.
     spr_OpenDashboardActionItem   (step 43) by the scope function: a
         confirmed item in the person's scope is returned (IsConfirmed 1) and
         marked read, as every item is; the page opens it read-only. A read
         row it creates for a confirmed item gets StatusId 0, as a Confirm
         writes. Reason 4 only for a role without the card, an item outside
         the scope and an unknown item.
     spr_SaveDashboardActionText   (step 43) refuses a confirmed item for
         every role: the role checks of before first (Reason 8, Reason 4),
         then, in one transaction (its own only when the caller has none),
         the item is read under an update lock together with the scope rule:
         outside the scope or unknown, Reason 4; confirmed, Reason 26 and
         nothing is saved; else the action text is written. A Confirm or a
         Reopen on the Followup page cannot change the item in between.

     Reason 8   the acting user is missing, 0 or inactive
     Reason 4   a role without the card; Management, MD Secretariat and Admin
                for the save; an item outside the acting user's scope or
                unknown
     Reason 26  the followup is confirmed (the save; as on the Followup page)

   The script stops when one of the four is neither the text this step was
   built from (steps 43 and 45) nor already the step 48 text (a later change
   would be lost).

   Re-running step 43 or step 45 puts back their texts and so removes step
   48 (BMMS-Check-InstalledSteps.sql then reads step 48 Partly): run this
   script again after. The Rollbacks of steps 43 and 45 refuse while step 48
   is installed.

   Install step 48 and deploy the FU2a build TOGETHER. The FU2a build reads
   the seven columns when they are there; without them it shows no
   "Reopened" word and no status line, and the step 43 texts refuse a
   confirmed item with Reason 4 as before.

   EXECUTE permission: as steps 42 to 47, the script grants nothing; the
   application login holds EXECUTE on the schema dbo.

   Changes no data. Safe to re-run. Installed after steps 43, 45 and 47 (it
   stops otherwise).

   Marker DashboardFollowupFinal-Step48 in each of the five objects (five
   rows in BMMS-Check-InstalledSteps.sql).

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
DECLARE @FnHash VARCHAR(400), @GetHash VARCHAR(400), @OpenHash VARCHAR(400), @SaveHash VARCHAR(400);

-- The four objects as they are now: SHA-1 of the text without carriage returns, in pieces of 4,000 characters
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), CHAR(13), ''); SET @FnHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @FnHash = @FnHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), CHAR(13), ''); SET @GetHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @GetHash = @GetHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), CHAR(13), ''); SET @OpenHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @OpenHash = @OpenHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), CHAR(13), ''); SET @SaveHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @SaveHash = @SaveHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') NOT LIKE '%DashboardAlerts-Step43%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') NOT LIKE '%DashboardAlerts-Step43%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') NOT LIKE '%DashboardAlerts-Step43%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') NOT LIKE '%DashboardSummary-Step45%'
         OR OBJECT_ID('dbo.Action_Item_Status_History', 'U') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') NOT LIKE '%FollowupFinal-Step47%'
         OR OBJECT_ID('dbo.fn_UserDepartmentScope', 'IF') IS NULL)
BEGIN
    RAISERROR('Step 43, 45 or 47 is not installed in "%s" (the Dashboard action item objects of steps 43 and 45, or the table Action_Item_Status_History and spr_ReopenFollowup of step 47). The steps are installed in order: run them first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF ((@FnHash <> '61E1A276292DFC2D87B1D020A7BF22E62EF9D0F1'
          AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') NOT LIKE '%DashboardFollowupFinal-Step48%')
         OR (@GetHash <> 'CD5F7F60C335E45FF1EF5D3050FBA15B75C202F7'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') NOT LIKE '%DashboardFollowupFinal-Step48%')
         OR (@OpenHash <> '38274C7102901790D622752F084CED37490FEFF8'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') NOT LIKE '%DashboardFollowupFinal-Step48%')
         OR (@SaveHash <> 'F7465E31CACAD9ACB854761025F3D41BF7758223'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') NOT LIKE '%DashboardFollowupFinal-Step48%'))
BEGIN
    RAISERROR('fn_DashboardActionItems, spr_GetDashboardActionItems, spr_OpenDashboardActionItem or spr_SaveDashboardActionText in "%s" is not the text this step was built from (steps 43 and 45) and not the step 48 text either: a change made since would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Dashboard action item scope (DashboardFollowupFinal-Step48, step FU2a): the scope rule of the Action Items card
-- (step 43) without the filter on confirmed items, from the acting user id alone (the role is read from Users; nothing
-- comes from the page). Which items a person may open from the Dashboard:
--   Controller, Management   every action item tied to a department by its agenda item, whatever the minutes status;
--   Manager, User            those of their departments (fn_UserDepartmentScope on @Today) whose minutes are
--                            finalised (F) or confirmed (C);
--   every other role (MD Secretariat, Admin and with it the protected system account), an inactive or unknown
--   user                     no rows.
-- ReadStatus is that of the acting user's own read row (1 when one of several rows is read), 0 for a person without
-- a row. IsOverdue: the due date is set, its DATE is before @Today, the item is neither complied nor confirmed.
-- The seven columns after IsOverdue come from the latest history row of the item (Action_Item_Status_History, the
-- highest StatusHistoryId) and the user who acted: IsReopened (1 when that row is a Reopen and the item is not
-- confirmed), StatusAction ('Confirm', 'Reopen', or NULL without a history row), StatusReason, StatusOn,
-- StatusByName, StatusByLogin, StatusByActive.
CREATE OR ALTER FUNCTION [dbo].[fn_DashboardActionItemScope]
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
               AND ISNULL(ai.IsComplied, 0) = 0 AND ISNULL(ai.IsConfirmed, 0) = 0 THEN 1 ELSE 0 END AS INT) AS IsOverdue,
CAST(CASE WHEN h.[Action] = 'Reopen' AND ISNULL(ai.IsConfirmed, 0) = 0 THEN 1 ELSE 0 END AS INT) AS IsReopened,
h.[Action] AS StatusAction,
h.Reason AS StatusReason,
h.ActedOn AS StatusOn,
hu.UserName AS StatusByName,
hu.LoginName AS StatusByLogin,
hu.AccountStatus AS StatusByActive
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
OUTER APPLY (SELECT TOP 1 sh.[Action], sh.Reason, sh.ActedOn, sh.ActedBy
             FROM Action_Item_Status_History sh
             WHERE sh.ActionItemId = ai.ActionItemId
             ORDER BY sh.StatusHistoryId DESC) h
LEFT JOIN Users hu ON hu.UserId = h.ActedBy
WHERE u.UserId = @UserId
AND u.AccountStatus = 1
AND (r.RoleCode IN ('controller', 'mgmt')
     OR (r.RoleCode IN ('manager', 'user')
         AND ISNULL(mt.MinutesStatus, 'Open') IN ('F', 'C')
         AND a.DepartmentId IN (SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(u.UserId, @Today) s)));
GO

-- Dashboard action items (DashboardAlerts-Step43, step UN6c1): the one scope rule of the Action Items card. An item
-- is an Action_Item that is not confirmed (IsConfirmed 0), tied to a department by its agenda item; Controller and
-- Management see all of them, a Manager and a User those of their departments whose minutes are finalised or
-- confirmed, every other role none. ReadStatus is the acting user's own read state; IsOverdue as before.
-- DashboardFollowupFinal-Step48 (step FU2a): the rows of fn_DashboardActionItemScope that are not confirmed - the
-- same rows as before - with the seven status columns of the latest history row after IsOverdue (IsReopened,
-- StatusAction, StatusReason, StatusOn, StatusByName, StatusByLogin, StatusByActive). The card never lists a
-- confirmed item.
CREATE OR ALTER FUNCTION [dbo].[fn_DashboardActionItems]
(
@UserId INT,
@Today DATE
)
RETURNS TABLE
AS
RETURN
SELECT
s.ActionItemId,
s.MinutesId,
s.ActionText,
s.ActionStatus,
s.AgendaId,
s.DecisionTypeId,
s.DueDate,
s.AgendaNo,
s.CommitteeId,
s.MeetingId,
s.DecisionTypeCode,
s.DecisionTypeName,
s.SubjectNo,
s.DepartmentCode,
s.DepartmentName,
s.ActualResolution,
s.CommitteeName,
s.CommitteeCode,
s.MeetingDate,
s.MeetingTime,
s.Venue,
s.UserId,
s.ReadStatus,
s.DepartmentId,
s.Directions,
s.IsComplied,
s.IsConfirmed,
s.IsOverdue,
s.IsReopened,
s.StatusAction,
s.StatusReason,
s.StatusOn,
s.StatusByName,
s.StatusByLogin,
s.StatusByActive
FROM dbo.fn_DashboardActionItemScope(@UserId, @Today) s
WHERE ISNULL(s.IsConfirmed, 0) = 0;
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
-- The rows are those of fn_DashboardActionItems of the committee and the department chosen; with both 0 they are
-- the rows of step 43.
-- DashboardFollowupFinal-Step48 (step FU2a): the seven status columns after IsOverdue (IsReopened: the word
-- "Reopened" in the Due date column). Parameters, rows, order and Reasons are unchanged.
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
	f.IsOverdue,
	f.IsReopened,
	f.StatusAction,
	f.StatusReason,
	f.StatusOn,
	f.StatusByName,
	f.StatusByLogin,
	f.StatusByActive
	FROM dbo.fn_DashboardActionItems(@ActingUserId, @Today) f
	WHERE @Result = 1
	AND (@CommitteeId = 0 OR f.CommitteeId = @CommitteeId)
	AND (@DepartmentId = 0 OR f.DepartmentId = @DepartmentId)
	ORDER BY f.MeetingDate DESC, f.AgendaNo, f.ActionItemId;
END
GO

-- Opening an action item from the Dashboard (DashboardAlerts-Step43, step UN6c1): it marks the acting user's own
-- read row (ActionItem_User_Map) as read and creates that row when the person has none (the check and the insert are
-- one statement under an update lock that is held, so two calls at once cannot create two rows; the table has no
-- unique index). Nothing of the action item itself is changed, so Management opens read-only. Returns the item's row
-- (the columns of the list). Reason 8: acting user missing, 0 or inactive.
-- DashboardFollowupFinal-Step48 (step FU2a): allowed for an item in the acting user's scope by
-- fn_DashboardActionItemScope, confirmed or not: a confirmed item (a stale row of the card, or a panel opened before
-- the confirm) is returned with IsConfirmed 1 and marked read, and the page opens it read-only. A read row created
-- for a confirmed item gets StatusId 0, as a Confirm writes for every row of the item. The row has the seven status
-- columns. Reason 4: a role without the card (MD Secretariat, Admin), an item outside the acting user's scope or
-- unknown; then no row is returned and nothing is written.
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
	ELSE IF NOT EXISTS (SELECT 1 FROM dbo.fn_DashboardActionItemScope(@ActingUserId, @Today) f WHERE f.ActionItemId = @ActionItemId)
		SET @Reason = 4;
	ELSE
	BEGIN
		INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId)
		SELECT @ActionItemId, @ActingUserId, 1, CASE WHEN ISNULL(ai.IsConfirmed, 0) = 0 THEN 1 ELSE 0 END
		FROM Action_Item ai
		WHERE ai.ActionItemId = @ActionItemId
		AND NOT EXISTS (SELECT 1 FROM ActionItem_User_Map m WITH (UPDLOCK, HOLDLOCK)
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
	f.IsOverdue,
	f.IsReopened,
	f.StatusAction,
	f.StatusReason,
	f.StatusOn,
	f.StatusByName,
	f.StatusByLogin,
	f.StatusByActive
	FROM dbo.fn_DashboardActionItemScope(@ActingUserId, @Today) f
	WHERE @Result = 1
	AND f.ActionItemId = @ActionItemId;
END
GO

-- Saving the action text from the Dashboard's Action Item Details panel (DashboardAlerts-Step43, step UN6c1). The
-- check is here, on the server, whatever the page sends: only a Controller, a Manager or a User (the roles whose
-- panel has an editable action text). It writes what spr_UpdateActionItem writes for the code 'ActionText':
-- Action_Item.ActionText, nothing else. Reason 8: acting user missing, 0 or inactive. Reason 4: Management, MD
-- Secretariat, Admin.
-- DashboardFollowupFinal-Step48 (step FU2a): a confirmed followup is final for every role. After the role checks, in
-- one transaction (its own only when the caller has none; inside a caller's transaction it writes in that one and
-- never ends it), the item is read under an update lock that is held, together with the scope rule
-- (fn_DashboardActionItemScope): an item outside the acting user's scope or unknown, Reason 4; a confirmed item,
-- Reason 26; then nothing is saved. Otherwise the action text is written. A Confirm or a Reopen on the Followup page
-- waits for the lock, so it cannot change the item in between.
CREATE OR ALTER PROCEDURE [dbo].[spr_SaveDashboardActionText]
@ActingUserId INT = NULL,
@ActionItemId INT = NULL,
@ActionText NVARCHAR(MAX) = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @Today DATE;
DECLARE @RoleCode VARCHAR(50);
DECLARE @OwnTran INT = 0;
DECLARE @Confirmed INT;
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

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

	IF (@Reason <> 0)
		RETURN;

	IF (@@TRANCOUNT = 0)
	BEGIN
		BEGIN TRANSACTION;
		SET @OwnTran = 1;
	END

	SELECT @Confirmed = CASE WHEN ISNULL(a.IsConfirmed, 0) = 0 THEN 0 ELSE 1 END
	FROM Action_Item a WITH (UPDLOCK, HOLDLOCK)
	WHERE a.ActionItemId = @ActionItemId
	AND EXISTS (SELECT 1 FROM dbo.fn_DashboardActionItemScope(@ActingUserId, @Today) f WHERE f.ActionItemId = @ActionItemId);

	IF (@Confirmed IS NULL)
		SET @Reason = 4;
	ELSE IF (@Confirmed = 1)
		SET @Reason = 26;
	ELSE
	BEGIN
		UPDATE Action_Item SET
		ActionText = @ActionText
		WHERE ActionItemId = @ActionItemId;

		SET @Result = 1;
	END

	IF (@OwnTran = 1)
		COMMIT TRANSACTION;
END
GO

DECLARE @Installed INT = 0;
DECLARE @Kept INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItemScope')), '') LIKE '%DashboardFollowupFinal-Step48%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') LIKE '%DashboardFollowupFinal-Step48%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') LIKE '%DashboardFollowupFinal-Step48%')
    SET @Installed = @Installed + 1;

-- The markers of steps 43 and 45 are kept (BMMS-Check-InstalledSteps.sql reads them)
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardSummary-Step45%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') LIKE '%DashboardAlerts-Step43%')
    SET @Kept = @Kept + 1;

IF (@Installed = 5 AND @Kept = 5)
    PRINT 'Step 48 installed: fn_DashboardActionItemScope is new; fn_DashboardActionItems, spr_GetDashboardActionItems and spr_OpenDashboardActionItem have the seven status columns, a confirmed item opens read-only and spr_SaveDashboardActionText refuses it with Reason 26 (DashboardFollowupFinal-Step48).';
ELSE
    RAISERROR('Step 48 is not complete: %d of 5 objects carry the marker DashboardFollowupFinal-Step48 and %d of 5 markers of steps 43 and 45 are kept. Read the messages above and run the script again.', 16, 1, @Installed, @Kept);
GO

SET NOEXEC OFF;
GO
