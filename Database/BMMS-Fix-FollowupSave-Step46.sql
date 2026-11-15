/* ============================================================================
   BMMS - Followup page: every save decided on the server from the acting
   user (step 46, step UN6d)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision UN6d (2026-11-15, plan approved): the two saves of the
   Followup page (Master/Followup.aspx) are decided on the server from the
   acting user id; the role is read from the database, nothing comes from the
   page or the session. Only an active Controller may save. What a save
   writes does not change.

   Two new procedures:

     spr_SaveFollowupActionText                    Save of the Action Text panel
         @ActingUserId, @ActionItemId, @ActionText; OUTPUT @Result, @Reason.
         Writes Action_Item.ActionText of that item, nothing else, as
         spr_UpdateActionItem does for the code 'ActionText' (no UpdatedOn,
         no UpdatedBy, no flag, no mapping row; a confirmed item too).

     spr_SaveFollowupConfirmed                     Submit of the Confirmed ticks
         @ActingUserId, @Items XML; OUTPUT @Result, @Reason, @Saved.
         @Items is <items><i id="12" c="1"/> ... </items>, one element per
         row of the page (c: the tick, 0 or 1). ONE call for all rows, in one
         transaction, all or nothing. For each row it writes what
         spr_UpdateActionItem writes for the code 'All' with the values the
         page always sent (IsComplied 0, IsConfirmed the tick):
           Action_Item.IsComplied = 0, Action_Item.IsConfirmed = the tick;
           a ticked row (c 1): every ActionItem_User_Map row of the item gets
           StatusId 0; an unticked row leaves the mapping rows as they are.
         @Saved: the number of rows written. An empty list (<items/>) writes
         nothing and gives Result 1, Saved 0, as an empty page did before.
         The whole Submit is refused (Reason 4, nothing written) when the
         list cannot be read, when an element other than <i> is in it, or
         when one row has an id that is not a whole number, an item that does
         not exist, an id given twice, or a tick other than 0 or 1.

     The reasons, in the order of steps 44 and 45:
     Reason 12  the protected system account (Users.IsSystem 1)
     Reason 8   the acting user is missing, 0 or inactive
     Reason 4   a role other than Controller (Manager, User, Management,
                MD Secretariat, Admin), or an item that does not exist (and
                for the Submit the list rules above)
     A refused call changes nothing and returns Result 0.

   Not changed: spr_UpdateActionItem (step 31; after the build of UN6d
   nothing calls it, see "Known items for later steps" in Database/README.md).
   A re-run of step 31 does not touch the two procedures of this step.

   EXECUTE permission: as steps 42 to 45, the script grants nothing. The
   application login holds EXECUTE on the schema dbo, which covers new
   procedures; the Test script checks it.

   Changes no data. Safe to re-run. Installed after step 45 (it stops
   otherwise). Install BEFORE the build of step UN6d: that build calls these
   procedures.

   Marker FollowupSave-Step46 in each procedure (2 markers in
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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardSummary')), '') NOT LIKE '%DashboardSummary-Step45%'
         OR OBJECT_ID('dbo.Action_Item', 'U') IS NULL OR OBJECT_ID('dbo.ActionItem_User_Map', 'U') IS NULL
         OR COL_LENGTH('dbo.Users', 'IsSystem') IS NULL OR COL_LENGTH('dbo.Users', 'AccountStatus') IS NULL)
BEGIN
    RAISERROR('Step 45 (BMMS-Fix-DashboardSummary-Step45.sql) is not installed in "%s", or an earlier step is missing (Users.IsSystem of step 18, Users.AccountStatus of step 14). The steps are installed in order: run them first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Followup page, Save of the Action Text panel (FollowupSave-Step46, step UN6d). Decided here, whatever the page sends:
-- only an active Controller that is not the system account. It writes what spr_UpdateActionItem writes for the code
-- 'ActionText': Action_Item.ActionText of the item, nothing else (a confirmed item too, as before). Reason 12: the system
-- account; Reason 8: acting user missing, 0 or inactive; Reason 4: another role, or an item that does not exist. Then
-- nothing is saved.
CREATE OR ALTER PROCEDURE [dbo].[spr_SaveFollowupActionText]
@ActingUserId INT = NULL,
@ActionItemId INT = NULL,
@ActionText NVARCHAR(MAX) = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @RoleCode VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	IF EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND IsSystem = 1)
		SET @Reason = 12;
	ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (ISNULL(@RoleCode, '') <> 'controller')
		SET @Reason = 4;
	ELSE
	BEGIN
		UPDATE Action_Item SET
		ActionText = @ActionText
		WHERE ActionItemId = @ActionItemId;

		IF (@@ROWCOUNT = 1)
			SET @Result = 1;
		ELSE
			SET @Reason = 4;
	END
END
GO

-- Followup page, Submit of the Confirmed ticks (FollowupSave-Step46, step UN6d). One call for every row of the page, in
-- one transaction: all rows are written or none. Decided here, whatever the page sends: only an active Controller
-- that is not the system account. For each row it writes what spr_UpdateActionItem writes for the code 'All' with the
-- values the page always sent: IsComplied 0 and IsConfirmed the tick; for a ticked row every mapping row of the item
-- gets StatusId 0. @Items: <items><i id="..." c="0|1"/>...</items>. Reason 12, 8 and 4 as spr_SaveFollowupActionText;
-- Reason 4 also for a list that cannot be read, an element other than <i>, an id that is not a whole number, an item
-- that does not exist, an id given twice or a tick other than 0 or 1. An empty list: Result 1, nothing written.
CREATE OR ALTER PROCEDURE [dbo].[spr_SaveFollowupConfirmed]
@ActingUserId INT = NULL,
@Items XML = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@Saved INT = NULL OUTPUT
AS
DECLARE @RoleCode VARCHAR(50);
DECLARE @Rows INT;
DECLARE @Elements INT;
DECLARE @OwnTran INT = 0;
DECLARE @Raw TABLE (Seq INT IDENTITY(1,1), IdText NVARCHAR(50), TickText NVARCHAR(50));
DECLARE @List TABLE (ActionItemId INT PRIMARY KEY, Tick INT);
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Saved = 0;

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	IF EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND IsSystem = 1)
		SET @Reason = 12;
	ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (ISNULL(@RoleCode, '') <> 'controller')
		SET @Reason = 4;
	ELSE IF (@Items IS NULL)
		SET @Reason = 4;

	IF (@Reason <> 0)
		RETURN;

	-- The list: one root <items>, only <i> elements under it, each with the attributes id and c
	SET @Elements = @Items.value('count(//*)', 'INT');
	SET @Rows = @Items.value('count(/items/i)', 'INT');
	IF (@Items.value('count(/*)', 'INT') <> 1 OR @Items.value('count(/items)', 'INT') <> 1 OR @Elements <> @Rows + 1)
	BEGIN
		SET @Reason = 4;
		RETURN;
	END

	INSERT INTO @Raw (IdText, TickText)
	SELECT x.n.value('@id', 'NVARCHAR(50)'), x.n.value('@c', 'NVARCHAR(50)')
	FROM @Items.nodes('/items/i') x(n);

	-- Every id a whole number of at most 10 digits that fits an INT, every tick 0 or 1
	IF EXISTS (SELECT 1 FROM @Raw
	           WHERE IdText IS NULL OR LEN(IdText) NOT BETWEEN 1 AND 10 OR IdText LIKE N'%[^0-9]%'
	              OR TickText IS NULL OR TickText NOT IN (N'0', N'1'))
	BEGIN
		SET @Reason = 4;
		RETURN;
	END
	IF EXISTS (SELECT 1 FROM @Raw WHERE CAST(IdText AS BIGINT) > 2147483647)
	BEGIN
		SET @Reason = 4;
		RETURN;
	END

	-- An id given twice
	IF EXISTS (SELECT CAST(IdText AS BIGINT) FROM @Raw GROUP BY CAST(IdText AS BIGINT) HAVING COUNT(*) > 1)
	BEGIN
		SET @Reason = 4;
		RETURN;
	END

	INSERT INTO @List (ActionItemId, Tick)
	SELECT CAST(IdText AS INT), CAST(TickText AS INT) FROM @Raw;

	-- Its own transaction when the caller has none (the page); inside a caller's transaction (the Test script) it
	-- writes in that one and never rolls it back itself
	IF (@@TRANCOUNT = 0)
	BEGIN
		BEGIN TRANSACTION;
		SET @OwnTran = 1;
	END

	-- Every item must exist; the rows are locked until the end, so none can go in between. Nothing is written yet.
	IF EXISTS (SELECT 1 FROM @List l
	           WHERE NOT EXISTS (SELECT 1 FROM Action_Item a WITH (UPDLOCK, HOLDLOCK) WHERE a.ActionItemId = l.ActionItemId))
	BEGIN
		IF (@OwnTran = 1)
			ROLLBACK TRANSACTION;
		SET @Reason = 4;
		RETURN;
	END

	UPDATE a SET
	IsComplied = 0,
	IsConfirmed = l.Tick
	FROM Action_Item a
	INNER JOIN @List l ON l.ActionItemId = a.ActionItemId;

	SET @Saved = @@ROWCOUNT;

	UPDATE m SET
	StatusId = 0
	FROM ActionItem_User_Map m
	INNER JOIN @List l ON l.ActionItemId = m.ActionItemId
	WHERE l.Tick = 1;

	IF (@OwnTran = 1)
		COMMIT TRANSACTION;

	SET @Result = 1;
END
GO

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') LIKE '%FollowupSave-Step46%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') LIKE '%FollowupSave-Step46%')
    SET @Installed = @Installed + 1;

IF (@Installed = 2)
    PRINT 'Step 46 installed: spr_SaveFollowupActionText and spr_SaveFollowupConfirmed are new; spr_UpdateActionItem is not changed (FollowupSave-Step46).';
ELSE
    RAISERROR('Step 46 is not complete: %d of 2 procedures carry the marker FollowupSave-Step46. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
