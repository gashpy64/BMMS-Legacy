/* ============================================================================
   BMMS - Report access: the Minutes report in every status for the Controller
   and Management; Followup for Management (step 41, step RA1b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision RA1 (2026-11-10), part RA1b:
     * the Controller and Management see the Minutes report for every
       committee and every minutes status, drafts included, each meeting
       marked "Draft (not finalised)", "Finalised" or "Confirmed";
     * the Manager, the User and every other role keep seeing finalised and
       confirmed minutes only (step 22, unchanged);
     * Management gets Followup and Followup Summary with the same data as
       the Controller's (whose code path is unchanged), and the same mark.

   Three new read-only procedures. Each takes @ActingUserId and returns
   @Result (1 allowed, 0 refused) and @Reason as OUTPUT parameters:
     Reason 8  the acting user is missing, 0 or inactive
     Reason 4  the acting user's role may not use the procedure
   A refused call returns an empty result with the same columns.

     spr_GetMinutesReportMeetingsAllStatus  controller, mgmt
         @CommitteeId: the View_Meeting columns of spr_GetMinutesReportMeetings
         plus MinutesStatusMark, for the meetings of the committee in every
         status that have at least one row in View_Minute (what the Minutes
         report prints). A Minutes row is written only by Agenda Finalisation
         (spr_AgendaFinalizeByMeetingId) and for an item the Controller adds
         afterwards (spr_AddEditAgendaByController); spr_UpdateMinutes only
         updates rows. So a new meeting is not listed. By MeetingNo.
     spr_GetMinutesReportAllStatus          controller, mgmt
         the nine parameters of spr_GetMinutesReport: the same View_Minute
         columns, filters and order, without the finalised / confirmed
         filter, plus MinutesStatus and MinutesStatusMark.
     spr_GetFollowupReportForManagement     mgmt
         the View_Action_Item rows with the same filters and order as the
         query BMMSBAL/ReportsMgr.cs GetFollowupReport builds for the
         Controller (committee; one meeting or a meeting range; department;
         IsConfirmed; the page's From and To dates are not used, as there),
         plus MinutesStatus and MinutesStatusMark.

   The mark: MinutesStatus 'F' -> Finalised, 'C' -> Confirmed, anything else
   (NULL, 'Open' or any other value) -> Draft (not finalised).

   Unchanged: spr_GetMinutesReport, spr_GetMinutesReportMeetings (step 22),
   View_Minute, View_Meeting, View_Action_Item and every other object.
   Changes no data. Safe to re-run. Installed after step 40 (it stops
   otherwise). Install BEFORE the build of step RA1b: that build calls these
   procedures. BMMS-Rollback-ReportAccess-Step41.sql drops them (then roll
   back the build too).

   Marker ReportAccess-Step41 in each procedure (3 markers in
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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReport')), '') NOT LIKE '%MinutesGating-Step22%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportMeetings')), '') NOT LIKE '%MinutesGating-Step22%'
         OR OBJECT_ID('dbo.View_Minute', 'V') IS NULL OR OBJECT_ID('dbo.View_Meeting', 'V') IS NULL OR OBJECT_ID('dbo.View_Action_Item', 'V') IS NULL)
BEGIN
    RAISERROR('spr_GetMinutesReport or spr_GetMinutesReportMeetings does not have the text of step 22 (marker MinutesGating-Step22), or View_Minute, View_Meeting or View_Action_Item is missing, in "%s". Run step 22 first (BMMS-Check-InstalledSteps.sql shows which steps are installed). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%RoleAccess-Step40%')
BEGIN
    RAISERROR('Step 40 (BMMS-Fix-RoleAccess-Step40.sql) is not installed in "%s". The steps are installed in order: run step 40 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Minutes report, every status (ReportAccess-Step41, step RA1b): the meetings of a committee that have at
-- least one minutes row (View_Minute, what the report prints), for the Controller and Management only.
-- Reason 8: acting user missing or inactive; Reason 4: another role; then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMinutesReportMeetingsAllStatus]
@CommitteeId INT,
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN ('controller', 'mgmt'))
		SET @Reason = 4;
	ELSE
	BEGIN
		SET @Reason = 0;
		SET @Result = 1;
	END

	SELECT
	v.*,
	CAST(CASE ISNULL(v.MinutesStatus, 'Open') WHEN 'F' THEN 'Finalised' WHEN 'C' THEN 'Confirmed'
	     ELSE 'Draft (not finalised)' END AS VARCHAR(30)) AS MinutesStatusMark
	FROM View_Meeting v
	WHERE @Result = 1
	AND v.CommitteeId = @CommitteeId
	AND EXISTS (SELECT 1 FROM View_Minute vm WHERE vm.MeetingId = v.MeetingId)
	ORDER BY v.MeetingNo;
END
GO

-- Minutes report, every status (ReportAccess-Step41, step RA1b): the minutes rows for the Controller and
-- Management only. Same filters and order as spr_GetMinutesReport (step 22) without its finalised / confirmed
-- filter; MinutesStatus and MinutesStatusMark added:
--   @CommitteeId     0 or less: no rows (the page always asks for a committee)
--   @DepartmentId    0 or less (- All -): every department
--   @MeetingNoSearch 0: one meeting (@MeetingId; 0 or less = every meeting)
--                    1: @FromMeetingId to @ToMeetingId
--   @SubjectNoSearch 1: subject numbers @FromSubjectNo to @ToSubjectNo
-- Reason 8: acting user missing or inactive; Reason 4: another role; then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMinutesReportAllStatus]
@CommitteeId INT,
@DepartmentId INT,
@MeetingNoSearch INT,
@MeetingId INT,
@FromMeetingId INT,
@ToMeetingId INT,
@SubjectNoSearch INT,
@FromSubjectNo INT,
@ToSubjectNo INT,
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN ('controller', 'mgmt'))
		SET @Reason = 4;
	ELSE
	BEGIN
		SET @Reason = 0;
		SET @Result = 1;
	END

	SELECT
	v.*,
	m.MinutesStatus,
	CAST(CASE ISNULL(m.MinutesStatus, 'Open') WHEN 'F' THEN 'Finalised' WHEN 'C' THEN 'Confirmed'
	     ELSE 'Draft (not finalised)' END AS VARCHAR(30)) AS MinutesStatusMark
	FROM View_Minute v
	INNER JOIN Meeting m ON m.MeetingId = v.MeetingId
	WHERE @Result = 1
	AND @CommitteeId > 0
	AND v.CommitteeId = @CommitteeId
	AND (@DepartmentId <= 0 OR v.DepartmentId = @DepartmentId)
	AND (@MeetingNoSearch <> 0 OR @MeetingId <= 0 OR v.MeetingId = @MeetingId)
	AND (@MeetingNoSearch <> 1 OR v.MeetingId BETWEEN @FromMeetingId AND @ToMeetingId)
	AND (@SubjectNoSearch <> 1 OR v.SubjectNo BETWEEN @FromSubjectNo AND @ToSubjectNo)
	ORDER BY v.CommitteeId, v.MeetingId, v.SubjectNo;
END
GO

-- Followup and Followup Summary for Management (ReportAccess-Step41, step RA1b): the View_Action_Item rows with
-- the filters of the query BMMSBAL/ReportsMgr.cs GetFollowupReport builds for the Controller (unchanged):
--   @CommitteeId > 0: that committee, and then
--       @MeetingNoSearch 0 with @MeetingId > 0: that meeting
--       @MeetingNoSearch 1: @FromMeetingId to @ToMeetingId
--   @DepartmentId > 0: that department
--   @ConfirmStatus >= 0: IsConfirmed = @ConfirmStatus
-- in the same order; MinutesStatus and MinutesStatusMark added. Management only.
-- Reason 8: acting user missing or inactive; Reason 4: another role; then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetFollowupReportForManagement]
@CommitteeId INT,
@MeetingNoSearch INT,
@MeetingId INT,
@FromMeetingId INT,
@ToMeetingId INT,
@DepartmentId INT,
@ConfirmStatus INT,
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole <> 'mgmt')
		SET @Reason = 4;
	ELSE
	BEGIN
		SET @Reason = 0;
		SET @Result = 1;
	END

	SELECT
	v.*,
	m.MinutesStatus,
	CAST(CASE ISNULL(m.MinutesStatus, 'Open') WHEN 'F' THEN 'Finalised' WHEN 'C' THEN 'Confirmed'
	     ELSE 'Draft (not finalised)' END AS VARCHAR(30)) AS MinutesStatusMark
	FROM View_Action_Item v
	INNER JOIN Meeting m ON m.MeetingId = v.MeetingId
	WHERE @Result = 1
	AND (@CommitteeId <= 0
	     OR (v.CommitteeId = @CommitteeId
	         AND (@MeetingNoSearch <> 0 OR @MeetingId <= 0 OR v.MeetingId = @MeetingId)
	         AND (@MeetingNoSearch <> 1 OR v.MeetingId BETWEEN @FromMeetingId AND @ToMeetingId)))
	AND (@DepartmentId <= 0 OR v.DepartmentId = @DepartmentId)
	AND (@ConfirmStatus < 0 OR v.IsConfirmed = @ConfirmStatus)
	ORDER BY v.CommitteeId, v.MeetingId, v.DepartmentId, v.IsConfirmed;
END
GO

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus')), '') LIKE '%ReportAccess-Step41%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportAllStatus')), '') LIKE '%ReportAccess-Step41%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupReportForManagement')), '') LIKE '%ReportAccess-Step41%')
    SET @Installed = @Installed + 1;

IF (@Installed = 3)
    PRINT 'Step 41 installed: spr_GetMinutesReportMeetingsAllStatus, spr_GetMinutesReportAllStatus and spr_GetFollowupReportForManagement (ReportAccess-Step41); spr_GetMinutesReport and spr_GetMinutesReportMeetings of step 22 unchanged.';
ELSE
    RAISERROR('Step 41 is not complete: %d of 3 procedures carry the marker ReportAccess-Step41. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
