/* ============================================================================
   BMMS - Roll back step 49 (Followup reports: who confirmed or reopened;
   step FU2b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Puts back the two procedures step 49 replaced, letter for letter as step
   47 installed them:
     spr_GetFollowupList   (ORDER BY ..., IsConfirmed, ActionItemId)
     spr_ReopenFollowup    (blank: spaces, tabs, line breaks, no-break and
                            zero-width spaces only)
   and drops the three new objects of step 49:
     spr_GetFollowupReport, spr_GetFollowupByDepartmentReport,
     fn_FollowupStatusLatest
   At its end the script compares the restored texts with the step 47 texts
   (SHA-1, carriage returns left out, in pieces of 4,000 characters) and says
   so.

   Before it changes anything it checks that each of the two procedures is
   the step 49 text (or already the step 47 text): a later change that kept
   the step 49 marker would otherwise be lost. It refuses then.

   Roll back the application build of step FU2b first or at the same time:
   that build reads spr_GetFollowupReport and
   spr_GetFollowupByDepartmentReport; without them the Followup reports show
   their "could not be read" path (error page).

   Order of rollbacks: this script comes FIRST. The Rollback of step 47
   refuses while step 49 is installed.

   Changes no data. Safe to re-run. BMMS-Check-InstalledSteps.sql then shows
   step 49 Missing; steps 16 to 48 stay Installed.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS", and when step 49 is not
   installed (nothing to roll back). Plain ASCII. From the command line use
   sqlcmd -I.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
DECLARE @D NVARCHAR(MAX), @I INT;
DECLARE @ListHash VARCHAR(400), @ReopenHash VARCHAR(400);

SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), CHAR(13), ''); SET @ListHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @ListHash = @ListHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), CHAR(13), ''); SET @ReopenHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @ReopenHash = @ReopenHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_FollowupStatusLatest', 'IF') IS NULL
         AND OBJECT_ID('dbo.spr_GetFollowupReport', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport', 'P') IS NULL
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') NOT LIKE '%FollowupReports-Step49%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') NOT LIKE '%FollowupReports-Step49%')
BEGIN
    RAISERROR('Step 49 is not installed in "%s" (none of its three new objects exists and the two replaced procedures do not carry its marker): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF ((@ListHash <> '6479AB33FCF1A8570DC1A801EFE633414F11827F' AND @ListHash <> '025A53F49FDC364956504FB3C1D44C573FFAC3E2')
         OR (@ReopenHash <> '5582CF03AFC04769800892EAA6A0BEAA3345F2A7' AND @ReopenHash <> '58C2D6D5CD5F481934475C613B42FEBC3B2AE928'))
BEGIN
    RAISERROR('spr_GetFollowupList or spr_ReopenFollowup in "%s" is neither the step 49 text nor the step 47 text: a change made after step 49 would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- The two batches below are the texts of step 47, unchanged. Do not tidy them: the comparison at the end is letter
-- for letter.
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

-- The three new objects of step 49, now read by nothing (the procedures first: they read the function)
IF (OBJECT_ID('dbo.spr_GetFollowupReport', 'P') IS NOT NULL)
    DROP PROCEDURE dbo.spr_GetFollowupReport;
IF (OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport', 'P') IS NOT NULL)
    DROP PROCEDURE dbo.spr_GetFollowupByDepartmentReport;
IF (OBJECT_ID('dbo.fn_FollowupStatusLatest', 'IF') IS NOT NULL)
    DROP FUNCTION dbo.fn_FollowupStatusLatest;
GO

DECLARE @D NVARCHAR(MAX), @I INT;
DECLARE @ListHash VARCHAR(400), @ReopenHash VARCHAR(400);
DECLARE @Left INT = 0;

SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), CHAR(13), ''); SET @ListHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @ListHash = @ListHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), CHAR(13), ''); SET @ReopenHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @ReopenHash = @ReopenHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END

IF (OBJECT_ID('dbo.spr_GetFollowupReport', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.fn_FollowupStatusLatest', 'IF') IS NOT NULL) SET @Left = @Left + 1;

IF (@Left > 0)
    RAISERROR('Step 49 is not fully rolled back: %d of its three new objects are still there. Read the messages above and run the script again.', 16, 1, @Left);
ELSE IF (@ListHash <> '025A53F49FDC364956504FB3C1D44C573FFAC3E2' OR @ReopenHash <> '58C2D6D5CD5F481934475C613B42FEBC3B2AE928')
    RAISERROR('Step 49: the three new objects are dropped, but spr_GetFollowupList or spr_ReopenFollowup is NOT letter for letter the text of step 47 (SHA-1 differs). Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 49 rolled back: spr_GetFollowupList and spr_ReopenFollowup are the texts of step 47 again (SHA-1 checked); spr_GetFollowupReport, spr_GetFollowupByDepartmentReport and fn_FollowupStatusLatest are dropped.';
GO

SET NOEXEC OFF;
GO
