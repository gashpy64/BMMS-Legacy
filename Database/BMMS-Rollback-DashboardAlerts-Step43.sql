/* ============================================================================
   BMMS - Roll back step 43 (Dashboard alert rules, step UN6c1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Drops the eight new objects of step 43:
     spr_GetDashboardAlerts, spr_GetAlertCount, spr_RemoveAlertForUser,
     spr_GetDashboardActionItems, spr_OpenDashboardActionItem,
     spr_SaveDashboardActionText, fn_DashboardAlerts, fn_DashboardActionItems
   and puts back the two procedures step 43 replaced, letter for letter as
   steps 18 and 37 installed them (the Admin role is in their lists again):
     spr_GetAlertMailId, spr_GetAgendaUpdateMailId
   At its end the script compares the restored texts with the texts step 43
   was built from (SHA-1, carriage returns left out) and says so.

   Roll back the application build of step UN6c1 first or at the same time:
   that build calls the new objects for the Alerts card, the Action Items
   card and the header count; without them those show their "could not be
   loaded" messages and the header shows "Alerts" without a number.

   Changes no data: alerts removed from a list with "Remove from my list"
   stay removed (as with the earlier Delete button), and the read rows that
   opening an action item created stay (ActionItem_User_Map; the earlier
   build lists an item for everyone who has such a row). Safe to re-run.
   BMMS-Check-InstalledSteps.sql then shows step 43 Missing.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS", and when step 43 is not
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
ELSE IF (OBJECT_ID('dbo.fn_DashboardAlerts', 'IF') IS NULL
         AND OBJECT_ID('dbo.spr_GetDashboardAlerts', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_GetAlertCount', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_RemoveAlertForUser', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_GetDashboardActionItems', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_OpenDashboardActionItem', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_SaveDashboardActionText', 'P') IS NULL
         AND OBJECT_ID('dbo.fn_DashboardActionItems', 'IF') IS NULL
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), '') NOT LIKE '%DashboardAlerts-Step43%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), '') NOT LIKE '%DashboardAlerts-Step43%')
BEGIN
    RAISERROR('Step 43 is not installed in "%s" (none of its eight new objects exists and the two mail procedures do not carry its marker): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.spr_GetAlertMailId', 'P') IS NULL OR OBJECT_ID('dbo.spr_GetAgendaUpdateMailId', 'P') IS NULL)
BEGIN
    RAISERROR('spr_GetAlertMailId or spr_GetAgendaUpdateMailId is missing in "%s" (steps 18 and 37): this is not a database step 43 was installed in. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- The procedures first, the functions they read last
IF OBJECT_ID('dbo.spr_GetDashboardAlerts', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetDashboardAlerts;
IF OBJECT_ID('dbo.spr_GetAlertCount', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetAlertCount;
IF OBJECT_ID('dbo.spr_RemoveAlertForUser', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_RemoveAlertForUser;
IF OBJECT_ID('dbo.spr_GetDashboardActionItems', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetDashboardActionItems;
IF OBJECT_ID('dbo.spr_OpenDashboardActionItem', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_OpenDashboardActionItem;
IF OBJECT_ID('dbo.spr_SaveDashboardActionText', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_SaveDashboardActionText;
IF OBJECT_ID('dbo.fn_DashboardActionItems', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_DashboardActionItems;
IF OBJECT_ID('dbo.fn_DashboardAlerts', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_DashboardAlerts;
GO

-- The two batches below are the texts of steps 18 and 37, unchanged. Do not tidy them: the comparison at the end
-- is letter for letter.
GO

-- Agenda alert mail addresses (Bcc of the approve / reject mails): active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
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
	
    SELECT EmailId FROM Users WHERE UserId IN (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId) AND AccountStatus = 1 AND IsSystem = 0;

END

IF @Code = 'AMA'
BEGIN

	SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

	SELECT EmailId FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1 AND IsSystem = 0;

END

IF @Code = 'ACA' OR @Code = 'ACR'
BEGIN

	SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
	SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

	SELECT EmailId FROM Users WHERE UserId IN
		(SELECT UserId FROM Alert_User_Map WHERE AlertId = @AlertId) AND AccountStatus = 1 AND IsSystem = 0;

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
	  AND NOT (ISNULL(r.RoleCode, '') = 'controller' AND am.AlertTypeCode IN ('ACA', 'ACR'))
	  AND NOT (ISNULL(r.RoleCode, '') = 'manager' AND am.AlertTypeCode IN ('AMA', 'AMR'))
	GROUP BY u.UserId, u.EmailId
	ORDER BY u.UserId;
END
GO

DECLARE @Left INT = 0;
DECLARE @MailHash VARCHAR(40);
DECLARE @UpdateMailHash VARCHAR(40);

IF (OBJECT_ID('dbo.spr_GetDashboardAlerts', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetAlertCount', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_RemoveAlertForUser', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetDashboardActionItems', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_OpenDashboardActionItem', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_SaveDashboardActionText', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.fn_DashboardActionItems', 'IF') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.fn_DashboardAlerts', 'IF') IS NOT NULL) SET @Left = @Left + 1;

SET @MailHash = CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), CHAR(13), '') AS NVARCHAR(4000))), 2);
SET @UpdateMailHash = CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), CHAR(13), '') AS NVARCHAR(4000))), 2);

IF (@Left > 0)
    RAISERROR('Step 43 is not fully rolled back: %d of its eight new objects are still there. Read the messages above and run the script again.', 16, 1, @Left);
ELSE IF (ISNULL(@MailHash, '') <> '7C811E422DCF63725C91DA81EC5EB3195B677E73' OR ISNULL(@UpdateMailHash, '') <> 'F6BD3580A632DF8643F2406DA53F1256D8FC6D33')
    RAISERROR('Step 43: the eight new objects are dropped, but spr_GetAlertMailId or spr_GetAgendaUpdateMailId is NOT letter for letter the text of steps 18 and 37 (SHA-1 differs). Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 43 rolled back: the eight new objects are dropped; spr_GetAlertMailId and spr_GetAgendaUpdateMailId are again the texts of steps 18 and 37, letter for letter (SHA-1 compared).';
GO

SET NOEXEC OFF;
GO
