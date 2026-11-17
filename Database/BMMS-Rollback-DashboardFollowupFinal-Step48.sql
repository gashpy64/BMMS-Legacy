/* ============================================================================
   BMMS - Roll back step 48 (Dashboard: a confirmed followup is final there
   too; step FU2a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Puts back the four objects step 48 replaced, letter for letter as steps
   43 and 45 installed them:
     fn_DashboardActionItems       (step 43: 28 columns)
     spr_GetDashboardActionItems   (step 45: 28 columns, the two filters)
     spr_OpenDashboardActionItem   (step 43: a confirmed item is refused,
                                    Reason 4)
     spr_SaveDashboardActionText   (step 43: a confirmed item is refused,
                                    Reason 4)
   and drops the new function of step 48:
     fn_DashboardActionItemScope
   At its end the script compares the restored texts with the texts step 48
   was built from (SHA-1, carriage returns left out, in pieces of 4,000
   characters) and says so.

   Roll back the application build of step FU2a first or at the same time.
   That build reads the seven status columns only when they are there, so it
   keeps working: no "Reopened" word, no status line, and a confirmed item
   is "This item no longer exists." again.

   Order of rollbacks: this script comes FIRST. The Rollbacks of steps 43
   and 45 refuse to run while step 48 is installed.

   Changes no data (the history rows and the read rows stay). Safe to
   re-run. BMMS-Check-InstalledSteps.sql then shows step 48 Missing; steps
   16 to 47 stay Installed.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS", and when step 48 is not
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
ELSE IF (OBJECT_ID('dbo.fn_DashboardActionItemScope', 'IF') IS NULL
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') NOT LIKE '%DashboardFollowupFinal-Step48%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') NOT LIKE '%DashboardFollowupFinal-Step48%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') NOT LIKE '%DashboardFollowupFinal-Step48%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') NOT LIKE '%DashboardFollowupFinal-Step48%')
BEGIN
    RAISERROR('Step 48 is not installed in "%s" (fn_DashboardActionItemScope does not exist and the four replaced objects do not carry its marker): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_DashboardCommitteeFilter', 'IF') IS NULL OR OBJECT_ID('dbo.fn_UserDepartmentScope', 'IF') IS NULL)
BEGIN
    RAISERROR('fn_DashboardCommitteeFilter (step 45) or fn_UserDepartmentScope (step 42) is missing in "%s": this is not a database step 48 was installed in. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- The four batches below are the texts of steps 43 and 45, unchanged. Do not tidy them: the comparison at the end
-- is letter for letter. They come first: while they run, the function they no longer read is still there.
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

-- The new function of step 48, now read by nothing
IF (OBJECT_ID('dbo.fn_DashboardActionItemScope', 'IF') IS NOT NULL)
    DROP FUNCTION dbo.fn_DashboardActionItemScope;
GO

DECLARE @D NVARCHAR(MAX), @I INT;
DECLARE @FnHash VARCHAR(400), @GetHash VARCHAR(400), @OpenHash VARCHAR(400), @SaveHash VARCHAR(400);

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

IF (OBJECT_ID('dbo.fn_DashboardActionItemScope', 'IF') IS NOT NULL)
    RAISERROR('Step 48 is not fully rolled back: fn_DashboardActionItemScope is still there. Read the messages above and run the script again.', 16, 1);
ELSE IF (@FnHash <> '61E1A276292DFC2D87B1D020A7BF22E62EF9D0F1' OR @GetHash <> 'CD5F7F60C335E45FF1EF5D3050FBA15B75C202F7'
         OR @OpenHash <> '38274C7102901790D622752F084CED37490FEFF8' OR @SaveHash <> 'F7465E31CACAD9ACB854761025F3D41BF7758223')
    RAISERROR('Step 48: fn_DashboardActionItemScope is dropped, but fn_DashboardActionItems, spr_GetDashboardActionItems, spr_OpenDashboardActionItem or spr_SaveDashboardActionText is NOT letter for letter the text of steps 43 and 45 (SHA-1 differs). Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 48 rolled back: fn_DashboardActionItems, spr_GetDashboardActionItems, spr_OpenDashboardActionItem and spr_SaveDashboardActionText are the texts of steps 43 and 45 again (SHA-1 checked); fn_DashboardActionItemScope is dropped.';
GO

SET NOEXEC OFF;
GO
