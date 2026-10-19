/* ============================================================================
   BMMS - Minutes reports only after Minutes Finalisation (step 22)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   The intended order of a meeting is: 1 Agenda Finalisation, 2 Attendance,
   3 Update Minutes, 4 Minutes Finalisation, 5 Minutes Generation, 6 Minutes
   Confirmation. Until now Reports -> Minutes and Reports -> Minutes Extract
   listed every meeting of the committee and printed the minutes as soon as
   Agenda Finalisation had created the Minutes rows: before attendance, before
   the minutes were updated, before they were finalized. They read the view
   with a query written in the code, not through a procedure.

   From this step both reports list, show (View) and print (Generate) only the
   meetings whose minutes are finalized or confirmed (Meeting.MinutesStatus
   'F' or 'C'). Confirmation is not needed: generation may come before it.

   Objects (each carries the text MinutesGating-Step22)
     spr_GetMinutesReportMeetings  NEW, the meetings of a committee with
                                   finalized or confirmed minutes, by
                                   MeetingNo (the View_Meeting columns); fills
                                   the meeting lists of both reports
     spr_GetMinutesReport          NEW, the minutes rows for both reports (the
                                   View_Minute columns), only of meetings with
                                   finalized or confirmed minutes; the same
                                   filters and order as the query in the code
                                   (committee, department, one meeting or a
                                   range of meetings, a range of subject
                                   numbers)

   Both only read. They return rows, no Result / Reason: the page shows the
   message when a meeting is not finalized (MeetingMgr.cs).

   Replaces nothing: View_Minute, View_Meeting, spr_GetMeetingByCommitteeId and
   spr_GetMinutesByMeetingId are used by other pages and are unchanged. No
   earlier numbered script contains these procedures, so no re-run of an
   earlier step changes them. The agenda reports, Update Minutes, Finalize
   Minutes, Minutes Confirmation, Attendance and the Followup reports are
   unchanged.

   Changes no data. Safe to re-run. Needs step 15 (BMMS-Fix-MeetingLocks.sql)
   and stops otherwise; it does not depend on steps 16 to 21. Run it BEFORE
   deploying the build that calls the new procedures; the older build never
   calls them.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMeetingStatusByMeetingId')), '') NOT LIKE '%MeetingLocks-Step15%')
BEGIN
    RAISERROR('Step 15 (BMMS-Fix-MeetingLocks.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Minutes reports - meetings of a committee with finalized or confirmed minutes (MinutesGating-Step22)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMinutesReportMeetings]
@CommitteeId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	*
	FROM View_Meeting
	WHERE CommitteeId = @CommitteeId
	AND ISNULL(MinutesStatus, 'Open') IN ('F', 'C')
	ORDER BY MeetingNo;
END
GO

-- Minutes and Minutes Extract reports - the minutes rows, only of meetings with finalized or
-- confirmed minutes (MinutesGating-Step22). Same filters and order as the query the code built:
--   @CommitteeId     0 or less: no rows (the page always asks for a committee)
--   @DepartmentId    0 or less (- All -): every department
--   @MeetingNoSearch 0: one meeting (@MeetingId; 0 or less = every meeting)
--                    1: @FromMeetingId to @ToMeetingId
--   @SubjectNoSearch 1: subject numbers @FromSubjectNo to @ToSubjectNo
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMinutesReport]
@CommitteeId INT,
@DepartmentId INT,
@MeetingNoSearch INT,
@MeetingId INT,
@FromMeetingId INT,
@ToMeetingId INT,
@SubjectNoSearch INT,
@FromSubjectNo INT,
@ToSubjectNo INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	v.*
	FROM View_Minute v
	INNER JOIN Meeting m ON m.MeetingId = v.MeetingId
	WHERE @CommitteeId > 0
	AND v.CommitteeId = @CommitteeId
	AND ISNULL(m.MinutesStatus, 'Open') IN ('F', 'C')
	AND (@DepartmentId <= 0 OR v.DepartmentId = @DepartmentId)
	AND (@MeetingNoSearch <> 0 OR @MeetingId <= 0 OR v.MeetingId = @MeetingId)
	AND (@MeetingNoSearch <> 1 OR v.MeetingId BETWEEN @FromMeetingId AND @ToMeetingId)
	AND (@SubjectNoSearch <> 1 OR v.SubjectNo BETWEEN @FromSubjectNo AND @ToSubjectNo)
	ORDER BY v.CommitteeId, v.MeetingId, v.SubjectNo;
END
GO

PRINT 'Step 22 installed: spr_GetMinutesReportMeetings and spr_GetMinutesReport (MinutesGating-Step22).';
GO

SET NOEXEC OFF;
GO
