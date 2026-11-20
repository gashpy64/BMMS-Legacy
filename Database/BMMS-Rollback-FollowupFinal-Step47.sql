/* ============================================================================
   BMMS - Roll back step 47 (a confirmed followup becomes final, step FU1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Puts back, letter for letter:
     spr_SaveFollowupActionText, spr_SaveFollowupConfirmed   the step 46 texts
                                  (BMMS-Fix-FollowupSave-Step46.sql)
     spr_DeleteUserByUserId       the step 39 text
                                  (BMMS-Fix-UserHistory-Step39.sql)
   Drops the two new procedures: spr_ReopenFollowup, spr_GetFollowupList.

   KEEPS the table Action_Item_Status_History with its rows, keys and index
   (as the step 39 Rollback keeps its history tables): nothing of the record
   of who confirmed or reopened is lost, and a later run of step 47 finds it
   again. The step 46 texts do not write to it. The IsConfirmed values stay
   as they are (an item reopened stays not confirmed). With the step 39 text
   of spr_DeleteUserByUserId, deleting a user who has rows in the table is
   refused by the table's foreign key (an error; nothing deleted).

   Roll back the application build of step FU1 first or at the same time:
   that build calls spr_ReopenFollowup and spr_GetFollowupList and sends the
   Submit without the attribute c, which the step 46 text refuses. The build
   of UN6d works with the restored texts. Roll back step 47 before step 46.
   The Rollback of step 49 comes before this script: it refuses while step 49
   is installed (step FU2b).

   Changes no data. A second run refuses (step 47 is not installed: nothing
   to roll back) and changes nothing. BMMS-Check-InstalledSteps.sql then
   shows step 47 Partly, 1 of 6 (the table is kept), step 46 Installed.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS". Plain ASCII. From the
   command line use sqlcmd -I.
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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') NOT LIKE '%FollowupFinal-Step47%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') NOT LIKE '%FollowupFinal-Step47%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') NOT LIKE '%FollowupFinal-Step47%'
         AND OBJECT_ID('dbo.spr_ReopenFollowup', 'P') IS NULL AND OBJECT_ID('dbo.spr_GetFollowupList', 'P') IS NULL)
BEGIN
    RAISERROR('Step 47 is not installed in "%s" (no object carries the marker FollowupFinal-Step47): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
-- Step 49 (step FU2b) replaced spr_GetFollowupList and spr_ReopenFollowup after step 47 and reads the history table:
-- roll it back first (BMMS-Rollback-FollowupReports-Step49.sql)
ELSE IF (OBJECT_ID('dbo.fn_FollowupStatusLatest', 'IF') IS NOT NULL
         OR OBJECT_ID('dbo.spr_GetFollowupReport', 'P') IS NOT NULL
         OR OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport', 'P') IS NOT NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') LIKE '%FollowupReports-Step49%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') LIKE '%FollowupReports-Step49%')
BEGIN
    RAISERROR('Step 49 (BMMS-Fix-FollowupReports-Step49.sql) is installed in "%s" and replaced spr_GetFollowupList and spr_ReopenFollowup after step 47. Roll back step 49 first (BMMS-Rollback-FollowupReports-Step49.sql), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

IF OBJECT_ID('dbo.spr_ReopenFollowup', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_ReopenFollowup;
IF OBJECT_ID('dbo.spr_GetFollowupList', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetFollowupList;
GO

-- The step 46 texts (BMMS-Fix-FollowupSave-Step46.sql), letter for letter
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

-- The step 39 text of spr_DeleteUserByUserId (BMMS-Fix-UserHistory-Step39.sql), letter for letter
GO

-------------------------------------------------------------------------------
-- Users - delete (UserHistory-Step39)
-------------------------------------------------------------------------------
-- Users - delete (FK #5, FK#5-UserDelete-AllColumns, UserProtection-Stage1)
-- UserHistory-Step39: rows the user wrote in another user's role or department history (CreatedBy /
-- ClosedBy) are history: Reason 6, group 'user changes'. The user's own User_Role and User_Department
-- rows go with an otherwise unused user.
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteUserByUserId]
@UserId INT,
@ActingUserId INT = NULL,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT,
@OutReasonDetail NVARCHAR(2000) = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @UserCreatedOn DATETIME;
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @ErrNo INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
	END
	ELSE
	BEGIN
		-- Called by the application there is no open transaction, so this
		-- procedure starts and ends its own. Called inside someone else's
		-- transaction (the test scripts) it only uses a savepoint.
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION DeleteUser;

			-- Rule 2 under concurrency: hold the active Admin / Controller rows
			-- until this transaction ends.
			SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
			WHERE AccountStatus = 1
			AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'Delete', NULL);

			-- 5. other users point at this user
			IF (@Reason = 0)
			BEGIN
				SET @Detail = ISNULL(STUFF((SELECT N', ' + u.UserName
				                            FROM Users u
				                            WHERE u.UserId <> @UserId
				                            AND (u.ManagerId = @UserId OR u.CreatedBy = @UserId OR u.UpdatedBy = @UserId)
				                            ORDER BY u.UserName
				                            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');

				IF (@Detail <> N'')
					SET @Reason = 5;
			END

			-- 6. history, every group that applies
			IF (@Reason = 0)
			BEGIN
				SET @UserCreatedOn = (SELECT CreatedOn FROM Users WHERE UserId = @UserId);

				IF EXISTS (SELECT 1 FROM Agenda WHERE CreatedBy = @UserId OR UpdatedBy = @UserId
				           OR MgrApprovedBy = @UserId OR ControllerApprovedBy = @UserId)
					SET @Detail = @Detail + N', agendas/approvals';
				IF EXISTS (SELECT 1 FROM Meeting WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Meeting_Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', meetings';
				IF EXISTS (SELECT 1 FROM Minutes WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Action_Item WHERE UpdatedBy = @UserId)
					SET @Detail = @Detail + N', minutes';
				IF EXISTS (SELECT 1 FROM Committee WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Committee_Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', committees/members';
				IF EXISTS (SELECT 1 FROM Attendance WHERE UpdatedBy = @UserId)
					SET @Detail = @Detail + N', attendance';
				IF EXISTS (SELECT 1 FROM Alert_Master WHERE CreatedBy = @UserId)
					SET @Detail = @Detail + N', alerts sent';
				IF EXISTS (SELECT 1 FROM Audit_Trail_Master WHERE Update_By = @UserId)
					SET @Detail = @Detail + N', audit trail';
				-- Rows older than the user belong to an earlier user with the same id.
				IF EXISTS (SELECT 1 FROM Audit_Trail_SendMail WHERE Mail_Send_By = @UserId
				           AND (@UserCreatedOn IS NULL OR Mail_Send_On IS NULL OR Mail_Send_On >= @UserCreatedOn))
					SET @Detail = @Detail + N', mail sent';
				IF EXISTS (SELECT 1 FROM Audit_Trail_SqlBackup WHERE [User_Id] = @UserId)
					SET @Detail = @Detail + N', backups';
				IF EXISTS (SELECT 1 FROM Audit_Trial_Login WHERE [User_Id] = @UserId
				           AND (@UserCreatedOn IS NULL OR Login_DateTime IS NULL OR Login_DateTime >= @UserCreatedOn))
					SET @Detail = @Detail + N', login history';
				IF EXISTS (SELECT 1 FROM Department WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Designation WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Roles WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Alert_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Decision_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Member_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Subject_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', master data';
				IF EXISTS (SELECT 1 FROM User_Role WHERE UserId <> @UserId AND (CreatedBy = @UserId OR ClosedBy = @UserId))
				   OR EXISTS (SELECT 1 FROM User_Department WHERE UserId <> @UserId AND (CreatedBy = @UserId OR ClosedBy = @UserId))
					SET @Detail = @Detail + N', user changes';

				IF (@Detail <> N'')
				BEGIN
					SET @Detail = STUFF(@Detail, 1, 2, N'');
					SET @Reason = 6;
				END
			END

			IF (@Reason = 0)
			BEGIN
				-- Alerts received and action-item read flags go with the user.
				DELETE FROM Alert_User_Map WHERE UserId = @UserId;

				DELETE FROM ActionItem_User_Map WHERE UserId = @UserId;

				-- The user's own role and department history (UserHistory-Step39)
				DELETE FROM User_Department WHERE UserId = @UserId;

				DELETE FROM User_Role WHERE UserId = @UserId;

				DELETE FROM Users WHERE UserId = @UserId;

				SET @Result = 1;
			END

			-- A refusal changed nothing, so there is nothing to roll back.
			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();
			SET @ErrNo = ERROR_NUMBER();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION DeleteUser;

			-- 547 = a foreign key the checks above do not know still points at
			-- the user. Anything else is a real error and is passed on.
			IF (@ErrNo <> 547)
			BEGIN
				RAISERROR('%s', 16, 1, @ErrMsg);
				RETURN;
			END

			SET @Result = 0;
			SET @Reason = 9;
			SET @Detail = LEFT(@ErrMsg, 2000);
		END CATCH
	END

	SET @OutResult = @Result;
	SET @OutReason = @Reason;
	SET @OutReasonDetail = @Detail;

	SELECT @Result AS Result, @Reason AS Reason, @Detail AS ReasonDetail;
END
GO

DECLARE @Left INT = 0;
IF (OBJECT_ID('dbo.spr_ReopenFollowup', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetFollowupList', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') NOT LIKE '%FollowupSave-Step46%'
    OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') LIKE '%FollowupFinal-Step47%') SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') NOT LIKE '%FollowupSave-Step46%'
    OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') LIKE '%FollowupFinal-Step47%') SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') NOT LIKE '%UserHistory-Step39%'
    OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') LIKE '%FollowupFinal-Step47%') SET @Left = @Left + 1;

IF (@Left > 0)
    RAISERROR('Step 47 is not fully rolled back: %d of 5 objects are not as before. Read the messages above and run the script again.', 16, 1, @Left);
ELSE
    PRINT 'Step 47 rolled back: spr_SaveFollowupActionText and spr_SaveFollowupConfirmed are the step 46 texts again, spr_DeleteUserByUserId the step 39 text; spr_ReopenFollowup and spr_GetFollowupList are dropped; the table Action_Item_Status_History is kept with its rows.';
GO

SET NOEXEC OFF;
GO
