/* ============================================================================
   BMMS - Followup reports: who confirmed or reopened each followup; the
   reports read procedures with the acting user; one list of blank
   characters for a reopen reason; a tie-break in the Followup list (step
   49, step FU2b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision FU2b (2026-11-17, plan approved with seven answers and
   seven additions): the texts of BMMS/FollowupStatusText.cs as they are;
   tie-break AgendaNo, ActionItemId; Followup by Department for the
   Controller only; a Status column in the View grids; a new tester pack;
   the system account Reason 8; one list of blank characters, compared with
   the page's list by a harness; the subject range of Followup by
   Department as integer parameters.

   New:
     fn_FollowupStatusLatest(@ActionItemId INT)     inline table function
         The latest Action_Item_Status_History row of an item (the highest
         StatusHistoryId) and the user who acted: StatusAction ('Confirm',
         'Reopen'), StatusReason, StatusOn, StatusByName, StatusByLogin,
         StatusByActive. No row for an item without history (never
         confirmed, or confirmed before step 47).
     spr_GetFollowupReport                          Followup and Followup Summary
         @ActingUserId and the filters of the query BMMSBAL/ReportsMgr.cs
         GetFollowupReport built in the code before (@CommitteeId,
         @MeetingNoSearch, @MeetingId, @FromMeetingId, @ToMeetingId,
         @DepartmentId, @ConfirmStatus); OUTPUT @Result, @Reason. The same
         rows (IsConfirmed = @ConfirmStatus: a NULL flag is left out by both
         filters, as before), ORDER BY CommitteeId, MeetingId, DepartmentId,
         IsConfirmed and, for rows equal in those, AgendaNo, ActionItemId.
         The View_Action_Item columns, MinutesStatus and MinutesStatusMark
         (Management only; NULL for the Controller), then the six status
         columns of fn_FollowupStatusLatest. The Controller and Management.
     spr_GetFollowupByDepartmentReport              Followup by Department
         @ActingUserId, @CommitteeId, @MeetingNoFrom, @MeetingNoTo,
         @DepartmentId (-1: every department), @SubjectNoFrom, @SubjectNoTo
         (NULL: no subject range); OUTPUT @Result, @Reason. The rows of
         spr_GetActionItemByMeetingIdDeptId (which is not changed) of that
         committee (the page kept only those before) within the subject
         range, ORDER BY SubjectNo, AgendaNo, ActionItemId, with the six
         status columns. The Controller only.

     Reason 8  the acting user is missing, 0, inactive or the protected
               system account
     Reason 4  another role (Followup by Department: every role but the
               Controller)
     A refused call returns the same columns with no rows.

   Replaced (their step 47 texts, FollowupFinal-Step47 kept; BMMS-Rollback-
   FollowupReports-Step49.sql puts them back, letter for letter):
     spr_GetFollowupList   ORDER BY ..., IsConfirmed, AgendaNo, ActionItemId
         (AgendaNo added before ActionItemId). Nothing else changes.
     spr_ReopenFollowup    a reason is blank when nothing is left after the
         characters of one list are taken out: U+0009 to U+000D, U+0020,
         U+0085, U+00A0, U+1680, U+2000 to U+200B, U+2028, U+2029, U+202F,
         U+205F, U+3000, U+FEFF (the same list as ActionItemMgr.
         ReopenBlankCharacters in BMMSBAL). Reason 4 then, as before. What is
         stored is unchanged (the reason with spaces at both ends trimmed).

   Not changed: spr_GetFollowupReportForManagement (step 41) and
   spr_GetActionItemByMeetingIdDeptId: after the build of FU2b nothing calls
   them (Known items: drop list).

   The script stops when one of the two replaced procedures is neither the
   step 47 text nor already the step 49 text (a later change would be lost).

   Re-running step 47 puts back its texts of the two procedures: step 49 then
   reads Partly in BMMS-Check-InstalledSteps.sql; run step 49 again. The
   Rollback of step 47 refuses while step 49 is installed.

   Install step 49 and deploy the FU2b build TOGETHER: the FU2b build reads
   the two new procedures.

   EXECUTE permission: as steps 42 to 48, the script grants nothing; the
   application login holds EXECUTE on the schema dbo.

   Changes no data. Safe to re-run. Installed after steps 41, 47 and 48 (it
   stops otherwise).

   Marker FollowupReports-Step49 in each of the five objects (five rows in
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
DECLARE @D NVARCHAR(MAX), @I INT;
DECLARE @ListHash VARCHAR(400), @ReopenHash VARCHAR(400);

-- The two procedures as they are now: SHA-1 of the text without carriage returns, in pieces of 4,000 characters
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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupReportForManagement')), '') NOT LIKE '%ReportAccess-Step41%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') NOT LIKE '%FollowupFinal-Step47%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') NOT LIKE '%FollowupFinal-Step47%'
         OR OBJECT_ID('dbo.Action_Item_Status_History', 'U') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItemScope')), '') NOT LIKE '%DashboardFollowupFinal-Step48%'
         OR OBJECT_ID('dbo.View_Action_Item', 'V') IS NULL)
BEGIN
    RAISERROR('Step 41, 47 or 48 is not installed in "%s" (spr_GetFollowupReportForManagement of step 41; spr_GetFollowupList, spr_ReopenFollowup and the table Action_Item_Status_History of step 47; fn_DashboardActionItemScope of step 48). The steps are installed in order: run them first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF ((@ListHash <> '025A53F49FDC364956504FB3C1D44C573FFAC3E2'
          AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') NOT LIKE '%FollowupReports-Step49%')
         OR (@ReopenHash <> '58C2D6D5CD5F481934475C613B42FEBC3B2AE928'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') NOT LIKE '%FollowupReports-Step49%'))
BEGIN
    RAISERROR('spr_GetFollowupList or spr_ReopenFollowup in "%s" is not the text this step was built from (step 47) and not the step 49 text either: a change made since would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Followup status (FollowupReports-Step49, step FU2b): the latest history row of one action item (the highest
-- StatusHistoryId of Action_Item_Status_History, step 47) and the user who acted. No row for an item without history.
-- The one definition of "the latest row" for the Followup reports; the texts are built by the page
-- (BMMS/FollowupStatusText.cs).
CREATE OR ALTER FUNCTION [dbo].[fn_FollowupStatusLatest]
(
@ActionItemId INT
)
RETURNS TABLE
AS
RETURN
SELECT TOP 1
sh.[Action] AS StatusAction,
sh.Reason AS StatusReason,
sh.ActedOn AS StatusOn,
hu.UserName AS StatusByName,
hu.LoginName AS StatusByLogin,
hu.AccountStatus AS StatusByActive
FROM Action_Item_Status_History sh
LEFT JOIN Users hu ON hu.UserId = sh.ActedBy
WHERE sh.ActionItemId = @ActionItemId
ORDER BY sh.StatusHistoryId DESC;
GO

-- Followup and Followup Summary (FollowupReports-Step49, step FU2b) for the Controller and Management, in place of the
-- query BMMSBAL/ReportsMgr.cs GetFollowupReport built in the code (Controller) and spr_GetFollowupReportForManagement
-- (step 41, Management), which stays without a caller. The role is read from the database: Reason 8 for an acting user
-- that is missing, 0, inactive or the protected system account; Reason 4 for every role but the Controller and
-- Management; then the same columns with no rows. The filters of the query before, word for word:
--   @CommitteeId > 0: that committee, and then
--       @MeetingNoSearch 0 with @MeetingId > 0: that meeting
--       @MeetingNoSearch 1: @FromMeetingId to @ToMeetingId
--   @DepartmentId > 0: that department
--   @ConfirmStatus >= 0: IsConfirmed = @ConfirmStatus (an item whose flag is NULL is left out, as before)
-- ORDER BY CommitteeId, MeetingId, DepartmentId, IsConfirmed, then AgendaNo and ActionItemId for rows equal in those
-- four (the query before left their order to the server). Columns: View_Action_Item, MinutesStatus and
-- MinutesStatusMark (Management; NULL for the Controller, whose reports show no minutes status), the six status columns
-- of fn_FollowupStatusLatest.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetFollowupReport]
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
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @MeetingNoSearch = ISNULL(@MeetingNoSearch, 0);
	SET @MeetingId = ISNULL(@MeetingId, 0);
	SET @FromMeetingId = ISNULL(@FromMeetingId, 0);
	SET @ToMeetingId = ISNULL(@ToMeetingId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);
	SET @ConfirmStatus = ISNULL(@ConfirmStatus, -1);

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1 AND u.IsSystem = 0;

	IF (@RoleCode IS NULL)
		SET @Reason = 8;
	ELSE IF (@RoleCode NOT IN ('controller', 'mgmt'))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	v.*,
	CASE WHEN @RoleCode = 'mgmt' THEN m.MinutesStatus END AS MinutesStatus,
	CAST(CASE WHEN @RoleCode = 'mgmt' THEN
	          CASE ISNULL(m.MinutesStatus, 'Open') WHEN 'F' THEN 'Finalised' WHEN 'C' THEN 'Confirmed'
	               ELSE 'Draft (not finalised)' END END AS VARCHAR(30)) AS MinutesStatusMark,
	s.StatusAction,
	s.StatusReason,
	s.StatusOn,
	s.StatusByName,
	s.StatusByLogin,
	s.StatusByActive
	FROM View_Action_Item v
	INNER JOIN Meeting m ON m.MeetingId = v.MeetingId
	OUTER APPLY dbo.fn_FollowupStatusLatest(v.ActionItemId) s
	WHERE @Result = 1
	AND (@CommitteeId <= 0
	     OR (v.CommitteeId = @CommitteeId
	         AND (@MeetingNoSearch <> 0 OR @MeetingId <= 0 OR v.MeetingId = @MeetingId)
	         AND (@MeetingNoSearch <> 1 OR v.MeetingId BETWEEN @FromMeetingId AND @ToMeetingId)))
	AND (@DepartmentId <= 0 OR v.DepartmentId = @DepartmentId)
	AND (@ConfirmStatus < 0 OR v.IsConfirmed = @ConfirmStatus)
	ORDER BY v.CommitteeId, v.MeetingId, v.DepartmentId, v.IsConfirmed, v.AgendaNo, v.ActionItemId;
END
GO

-- Followup by Department (FollowupReports-Step49, step FU2b), the Controller only, in place of
-- spr_GetActionItemByMeetingIdDeptId (not changed; it stays without a caller) and the page's filters: the rows of that
-- procedure (meeting numbers @MeetingNoFrom to @MeetingNoTo, compared as before; @DepartmentId -1 every department,
-- else that department) of the committee @CommitteeId (the page kept only those before), and with @SubjectNoFrom and
-- @SubjectNoTo (whole numbers; NULL: no range) the subjects in that range (the page's filter before). ORDER BY
-- SubjectNo, then AgendaNo and ActionItemId for rows of the same subject number (the order before left them to the
-- server). With the six status columns of fn_FollowupStatusLatest. Reason 8 for an acting user that is missing, 0,
-- inactive or the protected system account; Reason 4 for every role but the Controller (Management too); then the
-- same columns with no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetFollowupByDepartmentReport]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@MeetingNoFrom INT = NULL,
@MeetingNoTo INT = NULL,
@DepartmentId INT = -1,
@SubjectNoFrom INT = NULL,
@SubjectNoTo INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @RoleCode VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, -1);

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1 AND u.IsSystem = 0;

	IF (@RoleCode IS NULL)
		SET @Reason = 8;
	ELSE IF (@RoleCode <> 'controller')
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	v.*,
	s.StatusAction,
	s.StatusReason,
	s.StatusOn,
	s.StatusByName,
	s.StatusByLogin,
	s.StatusByActive
	FROM View_Action_Item v
	OUTER APPLY dbo.fn_FollowupStatusLatest(v.ActionItemId) s
	WHERE @Result = 1
	AND v.CommitteeId = @CommitteeId
	AND v.MeetingNo BETWEEN @MeetingNoFrom AND @MeetingNoTo
	AND (@DepartmentId = -1 OR v.DepartmentId = @DepartmentId)
	AND (@SubjectNoFrom IS NULL OR v.SubjectNo >= @SubjectNoFrom)
	AND (@SubjectNoTo IS NULL OR v.SubjectNo <= @SubjectNoTo)
	ORDER BY v.SubjectNo, v.AgendaNo, v.ActionItemId;
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
-- FollowupReports-Step49 (step FU2b): one list of blank characters for the reason, the same as the page's (owner
-- decision RA-3): see below. Everything else is the step 47 text.
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
DECLARE @Rest NVARCHAR(500);
DECLARE @Code INT;
DECLARE @Blank TABLE (Code INT PRIMARY KEY);
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Text = LTRIM(RTRIM(@ReopenReason));

	-- FollowupReports-Step49 (step FU2b): the reason is blank when nothing is left after the characters of the one list
	-- are taken out (ActionItemMgr.ReopenBlankCharacters in BMMSBAL has the same list): U+0009 to U+000D, U+0020,
	-- U+0085, U+00A0, U+1680, U+2000 to U+200B, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF. Compared by code
	-- point (binary collation). What is stored is unchanged: @Text, the reason with spaces at both ends trimmed.
	INSERT INTO @Blank (Code) VALUES (9), (10), (11), (12), (13), (32), (133), (160), (5760), (8192), (8193), (8194), (8195), (8196), (8197), (8198), (8199), (8200), (8201), (8202), (8203), (8232), (8233), (8239), (8287), (12288), (65279);
	SET @Rest = @ReopenReason;
	SELECT @Code = MIN(Code) FROM @Blank;
	WHILE (@Code IS NOT NULL AND @Rest IS NOT NULL)
	BEGIN
		SET @Rest = REPLACE(@Rest COLLATE Latin1_General_BIN2, NCHAR(@Code), N'');
		SELECT @Code = MIN(Code) FROM @Blank WHERE Code > @Code;
	END

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
	ELSE IF (@Text IS NULL OR @Rest IS NULL OR DATALENGTH(@Rest) = 0)
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
-- FollowupReports-Step49 (step FU2b): AgendaNo before ActionItemId for rows equal in CommitteeId, MeetingId,
-- DepartmentId and IsConfirmed (owner decision RA-1). Nothing else changes.
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
	ORDER BY v.CommitteeId, v.MeetingId, v.DepartmentId, v.IsConfirmed, v.AgendaNo, v.ActionItemId;
END
GO
DECLARE @Installed INT = 0;
DECLARE @Kept INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_FollowupStatusLatest')), '') LIKE '%FollowupReports-Step49%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupReport')), '') LIKE '%FollowupReports-Step49%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport')), '') LIKE '%FollowupReports-Step49%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') LIKE '%FollowupReports-Step49%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') LIKE '%FollowupReports-Step49%')
    SET @Installed = @Installed + 1;

-- The marker of step 47 is kept in the two replaced procedures (BMMS-Check-InstalledSteps.sql reads it)
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') LIKE '%FollowupFinal-Step47%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') LIKE '%FollowupFinal-Step47%')
    SET @Kept = @Kept + 1;

IF (@Installed = 5 AND @Kept = 2)
    PRINT 'Step 49 installed: fn_FollowupStatusLatest, spr_GetFollowupReport and spr_GetFollowupByDepartmentReport are new; spr_GetFollowupList orders by AgendaNo before ActionItemId and spr_ReopenFollowup has the one list of blank characters (FollowupReports-Step49).';
ELSE
    RAISERROR('Step 49 is not complete: %d of 5 objects carry the marker FollowupReports-Step49 and %d of 2 markers of step 47 are kept. Read the messages above and run the script again.', 16, 1, @Installed, @Kept);
GO

SET NOEXEC OFF;
GO
