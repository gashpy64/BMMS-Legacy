/* ============================================================================
   BMMS - Followup page: a confirmed followup becomes final; Reopen with a
   reason; a history row per Confirm and per Reopen (step 47, step FU1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision FU1 (2026-11-16, plan approved with four changes; D1
   cascade, D2 guard, D3 Reason 4 and 500 characters, D4 "Name (login)" and
   HH:mm, D5 a browser check for "<").

   New table Action_Item_Status_History
       StatusHistoryId INT IDENTITY (PK), ActionItemId (FK to Action_Item,
       ON DELETE CASCADE: the rows go with their action item, whichever
       procedure deletes it), [Action] 'Confirm' or 'Reopen', Reason
       NVARCHAR(500) (NULL for Confirm, not blank for Reopen), ActedBy (FK to
       Users), ActedOn (GETDATE()). Index on (ActionItemId, StatusHistoryId).
       Only inserted into; no procedure updates or deletes it.

   Replaced (the step 46 texts, FollowupSave-Step46):
     spr_SaveFollowupConfirmed    Submit of the Followup page. @Items is now
         <items><i id="12"/> ... </items>: only the rows the Controller
         changed from Pending to Confirmed. An element with any attribute but
         id (the c of step 46) refuses the whole Submit (Reason 4). Writes
         only the rows still not confirmed (under UPDLOCK): IsConfirmed 1,
         IsComplied 0, every mapping row of the item StatusId 0 (what a tick
         wrote before) and one Confirm history row each. A row confirmed in
         between is skipped, not refused. New OUTPUT @Skipped; @Saved is the
         number confirmed now. All or nothing, one transaction.
     spr_SaveFollowupActionText   refuses a confirmed item: Reason 26.

   New:
     spr_ReopenFollowup           @ActingUserId, @ActionItemId, @ReopenReason
         NVARCHAR(500); OUTPUT @Result, @Reason. Sets IsConfirmed 0 and adds
         one Reopen history row with the trimmed reason, in one transaction
         under UPDLOCK. Reason 27: the item is not confirmed (any more).
         Reason 4 also for a blank reason.
     spr_GetFollowupList          the Followup page's list: the rows and the
         order of the query ReportsMgr.GetFollowupReport builds (unchanged,
         the reports still use it) with the latest history row of each item
         and the name, login and status of the user who acted. Only an active
         Controller or MD Secretariat gets rows.

   Replaced (the step 39 text, UserHistory-Step39, every line kept):
     spr_DeleteUserByUserId       a user with history rows (ActedBy) has
         history in the group 'minutes' (Reason 6), as for Action_Item.
         UpdatedBy; the foreign key would refuse the delete otherwise.

   The reasons, as step 46: 12 the system account; 8 the acting user
   missing, 0 or inactive; 4 another role, an item that does not exist, a
   list that cannot be read, a blank reason. New: 26 the followup is
   confirmed (Action Text); 27 the followup is not confirmed (Reopen). A
   refused call writes nothing.

   The step 47 texts keep the marker FollowupSave-Step46 (step 46 reads
   Installed) and add FollowupFinal-Step47. Re-running step 46 brings back
   the step 46 texts of the two Followup procedures; re-running step 2, 6,
   10, 13 or 39 brings back an older text of spr_DeleteUserByUserId: step
   47 then reads Partly in BMMS-Check-InstalledSteps.sql; run step 47 again.

   Install step 47 and deploy the FU1 build TOGETHER: with step 47 and the
   build of UN6d, Submit is refused (Reason 4, nothing saved), because that
   page sends the attribute c.

   EXECUTE permission: as steps 42 to 46, the script grants nothing; the
   application login holds EXECUTE on the schema dbo.

   Changes no data (the table starts empty; items confirmed before step 47
   have no history row). Safe to re-run. Installed after step 46 (it stops
   otherwise).

   Marker FollowupFinal-Step47 in each of the five procedures (five rows and
   one table row in BMMS-Check-InstalledSteps.sql).

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') NOT LIKE '%FollowupSave-Step46%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') NOT LIKE '%FollowupSave-Step46%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') NOT LIKE '%UserHistory-Step39%'
         OR OBJECT_ID('dbo.Action_Item', 'U') IS NULL OR OBJECT_ID('dbo.Users', 'U') IS NULL)
BEGIN
    RAISERROR('Step 46 (BMMS-Fix-FollowupSave-Step46.sql) is not installed in "%s", or step 39 (spr_DeleteUserByUserId, BMMS-Fix-UserHistory-Step39.sql) is not. The steps are installed in order: run them first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- The history table (FollowupFinal-Step47). Created once; a re-run keeps it and its rows.
IF (OBJECT_ID('dbo.Action_Item_Status_History', 'U') IS NULL)
BEGIN
    CREATE TABLE dbo.Action_Item_Status_History
    (
        StatusHistoryId INT IDENTITY(1,1) NOT NULL,
        ActionItemId INT NOT NULL,
        [Action] VARCHAR(10) NOT NULL,
        Reason NVARCHAR(500) NULL,
        ActedBy INT NOT NULL,
        ActedOn DATETIME NOT NULL CONSTRAINT DF_Action_Item_Status_History_ActedOn DEFAULT (GETDATE()),
        CONSTRAINT PK_Action_Item_Status_History PRIMARY KEY CLUSTERED (StatusHistoryId),
        CONSTRAINT FK_Action_Item_Status_History_Action_Item FOREIGN KEY (ActionItemId)
            REFERENCES dbo.Action_Item (ActionItemId) ON DELETE CASCADE,
        CONSTRAINT FK_Action_Item_Status_History_Users FOREIGN KEY (ActedBy)
            REFERENCES dbo.Users (UserId),
        CONSTRAINT CK_Action_Item_Status_History_Action CHECK ([Action] IN ('Confirm', 'Reopen')),
        CONSTRAINT CK_Action_Item_Status_History_Reason CHECK
            (([Action] = 'Confirm' AND Reason IS NULL)
             OR ([Action] = 'Reopen' AND Reason IS NOT NULL AND LEN(LTRIM(RTRIM(Reason))) > 0))
    );

    CREATE NONCLUSTERED INDEX IX_Action_Item_Status_History_ActionItemId
        ON dbo.Action_Item_Status_History (ActionItemId, StatusHistoryId);

    PRINT 'Table Action_Item_Status_History created.';
END
ELSE
    PRINT 'Table Action_Item_Status_History is already there; kept with its rows.';
GO

-- Followup page, Save of the Action Text panel (FollowupFinal-Step47; replaces the FollowupSave-Step46 text, step FU1).
-- Decided here, whatever the page sends: only an active Controller that is not the system account, and only for an item
-- that is not confirmed. It writes Action_Item.ActionText of the item, nothing else. Reason 12: the system account;
-- Reason 8: acting user missing, 0 or inactive; Reason 4: another role, or an item that does not exist; Reason 26: the
-- item is confirmed (a confirmed followup is final). Then nothing is saved. The item is read under an update lock, so a
-- Submit or a Reopen cannot change it in between.
CREATE OR ALTER PROCEDURE [dbo].[spr_SaveFollowupActionText]
@ActingUserId INT = NULL,
@ActionItemId INT = NULL,
@ActionText NVARCHAR(MAX) = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @RoleCode VARCHAR(50);
DECLARE @OwnTran INT = 0;
DECLARE @Confirmed INT;
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

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

	IF (@Reason <> 0)
		RETURN;

	-- Its own transaction when the caller has none (the page); inside a caller's transaction (the Test script) it
	-- writes in that one and never rolls it back itself
	IF (@@TRANCOUNT = 0)
	BEGIN
		BEGIN TRANSACTION;
		SET @OwnTran = 1;
	END

	SELECT @Confirmed = CASE WHEN ISNULL(a.IsConfirmed, 0) = 0 THEN 0 ELSE 1 END
	FROM Action_Item a WITH (UPDLOCK, HOLDLOCK)
	WHERE a.ActionItemId = @ActionItemId;

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

-- Followup page, Submit (FollowupFinal-Step47; replaces the FollowupSave-Step46 text, step FU1). One call, one
-- transaction, all or nothing. @Items: <items><i id="..."/>...</items>, only the rows the Controller changed from
-- Pending to Confirmed. Decided here, whatever the page sends: only an active Controller that is not the system
-- account. Reason 12, 8 and 4 as spr_SaveFollowupActionText; Reason 4 also for a list that cannot be read, an element
-- other than <i>, an attribute other than id (the c of step 46), an id that is not a whole number, an item that does
-- not exist or an id given twice. Then nothing is written. Every row still not confirmed is written as a tick wrote it
-- before (IsConfirmed 1, IsComplied 0, every mapping row of the item StatusId 0) with one Confirm history row; a row
-- already confirmed (by another Controller, or in another tab) is skipped, not refused. @Saved: the rows confirmed
-- now; @Skipped: the rows skipped. An empty list: Result 1, nothing written.
CREATE OR ALTER PROCEDURE [dbo].[spr_SaveFollowupConfirmed]
@ActingUserId INT = NULL,
@Items XML = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@Saved INT = NULL OUTPUT,
@Skipped INT = NULL OUTPUT
AS
DECLARE @RoleCode VARCHAR(50);
DECLARE @Rows INT;
DECLARE @Elements INT;
DECLARE @OwnTran INT = 0;
DECLARE @Raw TABLE (Seq INT IDENTITY(1,1), IdText NVARCHAR(50));
DECLARE @List TABLE (ActionItemId INT PRIMARY KEY);
DECLARE @Done TABLE (ActionItemId INT PRIMARY KEY);
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Saved = 0;
	SET @Skipped = 0;

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

	-- The list: one root <items> without attributes, only <i> elements under it, each with the attribute id alone
	SET @Elements = @Items.value('count(//*)', 'INT');
	SET @Rows = @Items.value('count(/items/i)', 'INT');
	IF (@Items.value('count(/*)', 'INT') <> 1 OR @Items.value('count(/items)', 'INT') <> 1 OR @Elements <> @Rows + 1
	    OR @Items.value('count(/items/@*)', 'INT') <> 0
	    OR @Items.value('count(/items/i/@*)', 'INT') <> @Rows
	    OR @Items.value('count(/items/i/@id)', 'INT') <> @Rows)
	BEGIN
		SET @Reason = 4;
		RETURN;
	END

	INSERT INTO @Raw (IdText)
	SELECT x.n.value('@id', 'NVARCHAR(50)')
	FROM @Items.nodes('/items/i') x(n);

	-- Every id a whole number of at most 10 digits that fits an INT
	IF EXISTS (SELECT 1 FROM @Raw
	           WHERE IdText IS NULL OR LEN(IdText) NOT BETWEEN 1 AND 10 OR IdText LIKE N'%[^0-9]%')
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

	INSERT INTO @List (ActionItemId)
	SELECT CAST(IdText AS INT) FROM @Raw;

	-- Its own transaction when the caller has none (the page); inside a caller's transaction (the Test script) it
	-- writes in that one and never rolls it back itself
	IF (@@TRANCOUNT = 0)
	BEGIN
		BEGIN TRANSACTION;
		SET @OwnTran = 1;
	END

	-- Every item must exist; the rows are locked until the end, so none can change in between. Nothing is written yet.
	IF EXISTS (SELECT 1 FROM @List l
	           WHERE NOT EXISTS (SELECT 1 FROM Action_Item a WITH (UPDLOCK, HOLDLOCK) WHERE a.ActionItemId = l.ActionItemId))
	BEGIN
		IF (@OwnTran = 1)
			ROLLBACK TRANSACTION;
		SET @Reason = 4;
		RETURN;
	END

	-- Only the rows still not confirmed
	UPDATE a SET
	IsComplied = 0,
	IsConfirmed = 1
	OUTPUT inserted.ActionItemId INTO @Done (ActionItemId)
	FROM Action_Item a
	INNER JOIN @List l ON l.ActionItemId = a.ActionItemId
	WHERE ISNULL(a.IsConfirmed, 0) = 0;

	SET @Saved = (SELECT COUNT(*) FROM @Done);
	SET @Skipped = @Rows - @Saved;

	UPDATE m SET
	StatusId = 0
	FROM ActionItem_User_Map m
	INNER JOIN @Done d ON d.ActionItemId = m.ActionItemId;

	INSERT INTO Action_Item_Status_History (ActionItemId, [Action], Reason, ActedBy, ActedOn)
	SELECT d.ActionItemId, 'Confirm', NULL, @ActingUserId, GETDATE()
	FROM @Done d;

	IF (@OwnTran = 1)
		COMMIT TRANSACTION;

	SET @Result = 1;
END
GO

-- Followup page, Reopen of one confirmed followup (FollowupFinal-Step47, step FU1). Decided here, whatever the page
-- sends: only an active Controller that is not the system account. Reason 12, 8 and 4 as spr_SaveFollowupActionText;
-- Reason 4 also for a reason that is NULL or blank (spaces, tabs, line breaks, no-break and zero-width spaces) and for
-- an item that does not exist;
-- Reason 27: the item is not confirmed (any more). Then nothing is written. Otherwise, in one transaction under an
-- update lock: IsConfirmed 0, and one Reopen history row with the reason (spaces at both ends trimmed). The mapping
-- rows and IsComplied are left as they are. @ReopenReason is NVARCHAR(500): the page refuses a longer text before
-- the call.
CREATE OR ALTER PROCEDURE [dbo].[spr_ReopenFollowup]
@ActingUserId INT = NULL,
@ActionItemId INT = NULL,
@ReopenReason NVARCHAR(500) = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @RoleCode VARCHAR(50);
DECLARE @OwnTran INT = 0;
DECLARE @Confirmed INT;
DECLARE @Text NVARCHAR(500);
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Text = LTRIM(RTRIM(@ReopenReason));

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
	ELSE IF (@Text IS NULL
	         OR LEN(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@Text, NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' '),
	                                        NCHAR(160), N' '), NCHAR(8203), N' ')))) = 0)
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
	WHERE a.ActionItemId = @ActionItemId;

	IF (@Confirmed IS NULL)
		SET @Reason = 4;
	ELSE IF (@Confirmed = 0)
		SET @Reason = 27;
	ELSE
	BEGIN
		UPDATE Action_Item SET
		IsConfirmed = 0
		WHERE ActionItemId = @ActionItemId;

		INSERT INTO Action_Item_Status_History (ActionItemId, [Action], Reason, ActedBy, ActedOn)
		VALUES (@ActionItemId, 'Reopen', @Text, @ActingUserId, GETDATE());

		SET @Result = 1;
	END

	IF (@OwnTran = 1)
		COMMIT TRANSACTION;
END
GO

-- Followup page, the list (FollowupFinal-Step47, step FU1). The View_Action_Item rows and the order of the query
-- BMMSBAL/ReportsMgr.cs GetFollowupReport builds (it stays for the Followup reports):
--   @CommitteeId > 0: that committee, and then
--       @MeetingNoSearch 0 with @MeetingId > 0: that meeting
--       @MeetingNoSearch 1: @FromMeetingId to @ToMeetingId
--   @DepartmentId > 0: that department
--   @ConfirmStatus >= 0: IsConfirmed = @ConfirmStatus
-- ORDER BY CommitteeId, MeetingId, DepartmentId, IsConfirmed, and ActionItemId for rows equal in those four (the
-- old query left their order to the server). Added: the latest history row of each item (StatusAction, StatusReason,
-- StatusOn) and the user who acted (StatusByName, StatusByLogin, StatusByActive). Only an active Controller or MD
-- Secretariat that is not the system account; Reason 12, 8 or 4 otherwise, and then no rows (one result set always).
CREATE OR ALTER PROCEDURE [dbo].[spr_GetFollowupList]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@MeetingNoSearch INT = 0,
@MeetingId INT = 0,
@FromMeetingId INT = 0,
@ToMeetingId INT = 0,
@DepartmentId INT = 0,
@ConfirmStatus INT = -1,
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
	ELSE IF (ISNULL(@RoleCode, '') NOT IN ('controller', 'md_sect'))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	v.*,
	h.[Action] AS StatusAction,
	h.Reason AS StatusReason,
	h.ActedOn AS StatusOn,
	hu.UserName AS StatusByName,
	hu.LoginName AS StatusByLogin,
	hu.AccountStatus AS StatusByActive
	FROM View_Action_Item v
	OUTER APPLY (SELECT TOP 1 sh.[Action], sh.Reason, sh.ActedOn, sh.ActedBy
	             FROM Action_Item_Status_History sh
	             WHERE sh.ActionItemId = v.ActionItemId
	             ORDER BY sh.StatusHistoryId DESC) h
	LEFT JOIN Users hu ON hu.UserId = h.ActedBy
	WHERE @Result = 1
	AND (@CommitteeId <= 0
	     OR (v.CommitteeId = @CommitteeId
	         AND (@MeetingNoSearch <> 0 OR @MeetingId <= 0 OR v.MeetingId = @MeetingId)
	         AND (@MeetingNoSearch <> 1 OR v.MeetingId BETWEEN @FromMeetingId AND @ToMeetingId)))
	AND (@DepartmentId <= 0 OR v.DepartmentId = @DepartmentId)
	AND (@ConfirmStatus < 0 OR v.IsConfirmed = @ConfirmStatus)
	ORDER BY v.CommitteeId, v.MeetingId, v.DepartmentId, v.IsConfirmed, v.ActionItemId;
END
GO

-------------------------------------------------------------------------------
-- Users - delete (UserHistory-Step39)
-------------------------------------------------------------------------------
-- Users - delete (FK #5, FK#5-UserDelete-AllColumns, UserProtection-Stage1)
-- UserHistory-Step39: rows the user wrote in another user's role or department history (CreatedBy /
-- ClosedBy) are history: Reason 6, group 'user changes'. The user's own User_Role and User_Department
-- rows go with an otherwise unused user.
-- FollowupFinal-Step47: rows the user wrote in Action_Item_Status_History (ActedBy: a Confirm or a Reopen on the
-- Followup page) are history in the group 'minutes' (Reason 6); its foreign key to Users would refuse the delete otherwise.
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
				   OR EXISTS (SELECT 1 FROM Action_Item_Status_History WHERE ActedBy = @UserId)   -- FollowupFinal-Step47
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

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') LIKE '%FollowupFinal-Step47%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') LIKE '%FollowupFinal-Step47%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') LIKE '%FollowupFinal-Step47%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') LIKE '%FollowupFinal-Step47%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') LIKE '%FollowupFinal-Step47%')
    SET @Installed = @Installed + 1;
IF (OBJECT_ID('dbo.Action_Item_Status_History', 'U') IS NOT NULL)
    SET @Installed = @Installed + 1;

IF (@Installed = 6)
    PRINT 'Step 47 installed: table Action_Item_Status_History; spr_SaveFollowupActionText and spr_SaveFollowupConfirmed replaced; spr_ReopenFollowup and spr_GetFollowupList new; spr_DeleteUserByUserId replaced (FollowupFinal-Step47).';
ELSE
    RAISERROR('Step 47 is not complete: %d of 6 objects carry the marker FollowupFinal-Step47 or exist. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
