/* ============================================================================
   BMMS - Tests for BMMS-Fix-MinutesGating-Step22.sql (step 22)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-MinutesGating-Step22.sql, on the TEST COPY. It stops if
   step 22 is not installed.

   Creates its own two committees, two departments and six meetings with
   agenda items and minutes, one meeting in each state:
     Open        agenda Open,  minutes Open  (a minutes row inserted directly)
     NULL        agenda Close, minutes NULL  (counts as Open)
     Close/Open  agenda Close, minutes Open  (after Agenda Finalisation)
     F           agenda Close, minutes F     (Minutes Finalisation done)
     C           agenda Close, minutes C     (Minutes Confirmation done)
     other       F, in the other committee
   and checks, through the real procedures, with made-up sample values only:
     * markers; the step 15 procedure and the shared objects untouched
     * the result columns equal those of View_Meeting / View_Minute
     * the meeting list: only F and C, by MeetingNo, only the committee
     * the minutes rows: a single meeting in each state, All, a range,
       department, subject numbers, committee 0, the other committee
     * the old query of the code returned the Close/Open meeting; the new
       procedure does not, and returns the same rows for a finalized one
     * a meeting finalized (and then confirmed) through the real procedures
       is listed from that moment
   No mail is sent: only database procedures run.

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers. It can be run
   twice in the same query window (its temporary tables are dropped first and
   at the end).

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for the checks does not exist.

   It has no USE line: select the database in SSMS first (the test copy). It
   stops if the current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReport')), '') NOT LIKE '%MinutesGating-Step22%')
BEGIN
    RAISERROR('The minutes gating (step 22) is not installed in "%s". Run BMMS-Fix-MinutesGating-Step22.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

-- Run twice in one window: drop what a previous run may have left
IF OBJECT_ID('tempdb..#VM') IS NOT NULL DROP TABLE #VM;
IF OBJECT_ID('tempdb..#VMt') IS NOT NULL DROP TABLE #VMt;
GO

-- Capture tables shaped like the views; UNION ALL keeps the identity of MinutesId / MeetingId out.
-- Seq gives the order the procedure returned; it is read only in ORDER BY, never by its value.
SELECT TOP 0 * INTO #VM FROM View_Minute UNION ALL SELECT TOP 0 * FROM View_Minute;
ALTER TABLE #VM ADD Seq INT IDENTITY(1,1);
SELECT TOP 0 * INTO #VMt FROM View_Meeting UNION ALL SELECT TOP 0 * FROM View_Meeting;
ALTER TABLE #VMt ADD Seq INT IDENTITY(1,1);
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -7, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
-- A decision type other than 1 (Action), so finalizing creates no action items
DECLARE @DecisionTypeId INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type ORDER BY CASE WHEN DecisionTypeId = 1 THEN 1 ELSE 0 END, DecisionTypeId);
DECLARE @C INT, @C2 INT, @DeptA INT, @DeptB INT;
DECLARE @MO INT, @MN INT, @MA INT, @MF INT, @MX INT, @MC INT;
DECLARE @Ag INT, @Expected VARCHAR(400), @ViewCols VARCHAR(MAX), @ProcCols VARCHAR(MAX);

IF (@Sys IS NULL OR @SubjectTypeId IS NULL OR @DecisionTypeId IS NULL
    OR NOT EXISTS (SELECT 1 FROM Agenda_Status WHERE AgendaStatusCode = 'ACA'))
BEGIN
    INSERT INTO @T VALUES ('The system account, a subject type, a decision type or agenda status ACA is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

---------------------------------------------------------------------------
-- Objects (before any fixture)
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'Marker: spr_GetMinutesReportMeetings (MinutesGating-Step22)', 'yes',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportMeetings')), '') LIKE '%MinutesGating-Step22%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'Marker: spr_GetMinutesReport (MinutesGating-Step22)', 'yes',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReport')), '') LIKE '%MinutesGating-Step22%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_GetMinutesReport has the 9 parameters of the old query', '9',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetMinutesReport')) AS VARCHAR(12));
INSERT INTO @T SELECT 'Step 15: spr_GetMeetingStatusByMeetingId keeps its text and is not replaced', 'yes',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMeetingStatusByMeetingId')), '') LIKE '%MeetingLocks-Step15%'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMeetingStatusByMeetingId')), '') NOT LIKE '%MinutesGating-Step22%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'Shared objects unchanged: View_Minute, View_Meeting, spr_GetMeetingByCommitteeId, spr_GetMinutesByMeetingId', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('View_Minute'), ('View_Meeting'), ('spr_GetMeetingByCommitteeId'), ('spr_GetMinutesByMeetingId')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), 'missing') LIKE '%MinutesGating-Step22%'
                OR OBJECT_ID('dbo.' + o.Name) IS NULL) AS VARCHAR(12));

SET @ViewCols = STUFF((SELECT ',' + name FROM sys.columns WHERE object_id = OBJECT_ID('dbo.View_Minute') ORDER BY column_id
                       FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
SET @ProcCols = STUFF((SELECT ',' + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetMinutesReport'), 0) ORDER BY column_ordinal
                       FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
INSERT INTO @T SELECT 'spr_GetMinutesReport returns the View_Minute columns, in order (the pages read them by name)', 'same',
       CASE WHEN @ProcCols = @ViewCols THEN 'same' ELSE 'different: ' + LEFT(ISNULL(@ProcCols, 'none'), 380) END;

SET @ViewCols = STUFF((SELECT ',' + name FROM sys.columns WHERE object_id = OBJECT_ID('dbo.View_Meeting') ORDER BY column_id
                       FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
SET @ProcCols = STUFF((SELECT ',' + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetMinutesReportMeetings'), 0) ORDER BY column_ordinal
                       FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
INSERT INTO @T SELECT 'spr_GetMinutesReportMeetings returns the View_Meeting columns, in order', 'same',
       CASE WHEN @ProcCols = @ViewCols THEN 'same' ELSE 'different: ' + LEFT(ISNULL(@ProcCols, 'none'), 380) END;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names)
    ---------------------------------------------------------------------------
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z22', 'ZZ step 22 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Y22', 'ZZ step 22 other committee', '2000-01-01', 1, 0);
    SET @C2 = SCOPE_IDENTITY();

    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ22A', 'ZZ step 22 department A', 998, 1, @Now, @Sys);
    SET @DeptA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ22B', 'ZZ step 22 department B', 999, 1, @Now, @Sys);
    SET @DeptB = SCOPE_IDENTITY();

    -- Meetings in MeetingId order: Open, NULL, Close/Open, F, other committee (F), C
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99221', @C, 'ZZ22 test', 'ZZ', @Past, '10:00', 'Open', 'Open');
    SET @MO = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99222', @C, 'ZZ22 test', 'ZZ', @Past, '10:00', 'Close', NULL);
    SET @MN = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99223', @C, 'ZZ22 test', 'ZZ', @Past, '10:00', 'Close', 'Open');
    SET @MA = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99224', @C, 'ZZ22 test', 'ZZ', @Past, '10:00', 'Close', 'F');
    SET @MF = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99224', @C2, 'ZZ22 test', 'ZZ', @Past, '10:00', 'Close', 'F');
    SET @MX = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99225', @C, 'ZZ22 test', 'ZZ', @Past, '10:00', 'Close', 'C');
    SET @MC = SCOPE_IDENTITY();

    -- One approved agenda item and its minutes row per line: AgendaNo, meeting, department, subject number
    DECLARE @Items TABLE (AgendaNo VARCHAR(20), MeetingId INT, DepartmentId INT, SubjectNo INT);
    INSERT INTO @Items VALUES
    ('Z22O1', @MO, @DeptA, 1),
    ('Z22N1', @MN, @DeptA, 1),
    ('Z22A1', @MA, @DeptA, 1), ('Z22A2', @MA, @DeptB, 2),
    ('Z22F1', @MF, @DeptA, 1), ('Z22F2', @MF, @DeptB, 2),
    ('Y22X1', @MX, @DeptA, 1),
    ('Z22C1', @MC, @DeptA, 1), ('Z22C2', @MC, @DeptB, 2), ('Z22C3', @MC, @DeptA, 3);

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        AgendaStatusCode, ControllerApprovedStatus, SubjectNo, CreatedOn, CreatedBy)
    SELECT i.AgendaNo, m.CommitteeId, i.MeetingId, i.DepartmentId, @SubjectTypeId, 'ZZ22 ' + i.AgendaNo, 'Entry', 'ZZ', 'ZZ22 resolution',
           'ACA', 'Approved', i.SubjectNo, @Now, @Sys
    FROM @Items i JOIN Meeting m ON m.MeetingId = i.MeetingId;

    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, StatusId, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    SELECT a.AgendaId, @DecisionTypeId, ' ', 'ZZ22 resolution', 1, @Now, @Sys, @Now, @Sys
    FROM Agenda a JOIN @Items i ON i.AgendaNo = a.AgendaNo AND i.MeetingId = a.MeetingId;

    ---------------------------------------------------------------------------
    -- The meeting list
    ---------------------------------------------------------------------------
    DELETE FROM #VMt; INSERT INTO #VMt EXEC spr_GetMinutesReportMeetings @CommitteeId = @C;
    INSERT INTO @T SELECT 'List: only the F and C meetings of the committee, by MeetingNo (not Open, NULL, Close/Open)', '99224 F,99225 C',
           ISNULL(STUFF((SELECT ',' + MeetingNo + ' ' + ISNULL(MinutesStatus, 'NULL') FROM #VMt ORDER BY Seq
                         FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VMt; INSERT INTO #VMt EXEC spr_GetMinutesReportMeetings @CommitteeId = @C2;
    INSERT INTO @T SELECT 'List: the other committee lists only its own meeting', CAST(@MX AS VARCHAR(12)),
           ISNULL(STUFF((SELECT ',' + CAST(MeetingId AS VARCHAR(12)) FROM #VMt ORDER BY Seq
                         FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VMt; INSERT INTO #VMt EXEC spr_GetMinutesReportMeetings @CommitteeId = 0;
    INSERT INTO @T SELECT 'List: committee 0 lists nothing', '0', CAST((SELECT COUNT(*) FROM #VMt) AS VARCHAR(12));

    DELETE FROM #VMt; INSERT INTO #VMt EXEC spr_GetMeetingByCommitteeId @CommitteeId = @C;
    INSERT INTO @T SELECT 'Unchanged: spr_GetMeetingByCommitteeId still lists all 5 meetings (other pages use it)', '5',
           CAST((SELECT COUNT(*) FROM #VMt) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The minutes rows: one meeting in each state
    ---------------------------------------------------------------------------
    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MO,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'One meeting, Open (agenda and minutes Open): no rows', '0', CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12));

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MN,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'One meeting, minutes status NULL (counts as Open): no rows', '0', CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12));

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MA,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'One meeting, Close/Open (agenda finalized, minutes not): no rows', '0', CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12));

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MF,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'One meeting, F: its rows by subject number', 'Z22F1,Z22F2',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MC,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'One meeting, C: its rows by subject number', 'Z22C1,Z22C2,Z22C3',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MX,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'One meeting of another committee, asked for under this committee: no rows', '0', CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- All, ranges, department, subject numbers, committee 0
    ---------------------------------------------------------------------------
    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = -1,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'All meetings (- All -): the F and C rows only, by meeting then subject number', 'Z22F1,Z22F2,Z22C1,Z22C2,Z22C3',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 1, @MeetingId = 0,
        @FromMeetingId = @MO, @ToMeetingId = @MC, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Range first to last meeting: F and C rows only, not the other committee in between', 'Z22F1,Z22F2,Z22C1,Z22C2,Z22C3',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 1, @MeetingId = 0,
        @FromMeetingId = @MO, @ToMeetingId = @MA, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Range Open to Close/Open: no rows', '0', CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12));

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 1, @MeetingId = 0,
        @FromMeetingId = @MA, @ToMeetingId = @MF, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Range Close/Open to F: the F rows only', 'Z22F1,Z22F2',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = @DeptA, @MeetingNoSearch = 0, @MeetingId = -1,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Department A, all meetings: the F and C rows of department A only', 'Z22F1,Z22C1,Z22C3',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = @DeptB, @MeetingNoSearch = 0, @MeetingId = @MA,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Department B, the Close/Open meeting: no rows', '0', CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12));

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = @DeptB, @MeetingNoSearch = 0, @MeetingId = @MF,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Department B, the F meeting: its department B row', 'Z22F2',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MC,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 1, @FromSubjectNo = 2, @ToSubjectNo = 3;
    INSERT INTO @T SELECT 'Subject numbers 2 to 3, the C meeting', 'Z22C2,Z22C3',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = -1,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 1, @FromSubjectNo = 1, @ToSubjectNo = 1;
    INSERT INTO @T SELECT 'Subject number 1, all meetings: F and C only (not Open, NULL, Close/Open)', 'Z22F1,Z22C1',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MF,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 1, @FromSubjectNo = 3, @ToSubjectNo = 9;
    INSERT INTO @T SELECT 'Subject numbers 3 to 9, the F meeting (it has 1 and 2): no rows', '0', CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12));

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = 0, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = -1,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Committee 0: no rows (the page always asks for a committee)', '0', CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12));

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C2, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = -1,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'The other committee, all meetings: its own row only', 'Y22X1',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    ---------------------------------------------------------------------------
    -- Against the old query of the code (SELECT * FROM View_Minute WHERE CommitteeId = .. AND MeetingId = ..)
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Old query (the gap): it returned the Close/Open meeting''s rows', '2',
           CAST((SELECT COUNT(*) FROM View_Minute WHERE CommitteeId = @C AND MeetingId = @MA) AS VARCHAR(12));

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MF,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    SET @Expected = ISNULL(STUFF((SELECT ',' + CAST(MinutesId AS VARCHAR(12)) + ':' + AgendaNo + ':' + CAST(SubjectNo AS VARCHAR(12))
                                  FROM View_Minute WHERE CommitteeId = @C AND MeetingId = @MF ORDER BY CommitteeId, MeetingId, SubjectNo
                                  FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');
    INSERT INTO @T SELECT 'A finalized meeting: the same rows as the old query, in the same order', @Expected,
           ISNULL(STUFF((SELECT ',' + CAST(MinutesId AS VARCHAR(12)) + ':' + AgendaNo + ':' + CAST(SubjectNo AS VARCHAR(12))
                         FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    ---------------------------------------------------------------------------
    -- The Close/Open meeting goes through Finalize and Confirm (the real procedures)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MA, @UserId = @Sys;
    INSERT INTO @T SELECT 'Finalize the Close/Open meeting (spr_MinutesFinalizeByMeetingId)', 'Result 1; F',
           'Result ' + ISNULL((SELECT TOP 1 CAST(Result AS VARCHAR(2)) FROM @R), 'none') + '; '
           + ISNULL((SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MA), 'NULL');

    DELETE FROM #VMt; INSERT INTO #VMt EXEC spr_GetMinutesReportMeetings @CommitteeId = @C;
    INSERT INTO @T SELECT 'List after finalizing it: listed from that moment', '99223 F,99224 F,99225 C',
           ISNULL(STUFF((SELECT ',' + MeetingNo + ' ' + ISNULL(MinutesStatus, 'NULL') FROM #VMt ORDER BY Seq
                         FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MA,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Its rows after finalizing', 'Z22A1,Z22A2',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #VM ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MA, @UserId = @Sys;
    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = @MA,
        @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Confirm it (spr_MinutesConfirmByMeetingId): still listed and printed', 'Result 1; C; 2 rows',
           'Result ' + ISNULL((SELECT TOP 1 CAST(Result AS VARCHAR(2)) FROM @R), 'none') + '; '
           + ISNULL((SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MA), 'NULL') + '; '
           + CAST((SELECT COUNT(*) FROM #VM) AS VARCHAR(12)) + ' rows';

    ---------------------------------------------------------------------------
    -- Read only
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'The report procedures change no meeting state (Open, NULL, F, C unchanged)', 'Open,NULL,F,C',
           ISNULL((SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MO), 'NULL') + ','
           + ISNULL((SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MN), 'NULL') + ','
           + ISNULL((SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MF), 'NULL') + ','
           + ISNULL((SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MC), 'NULL');

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

Report:

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM @T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND (Actual <> Expected OR Actual IS NULL) THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM @T;

-- Confirm nothing was kept: should be 0, 0 and 0
SELECT (SELECT COUNT(*) FROM Meeting WHERE MeetingNo IN ('99221', '99222', '99223', '99224', '99225') AND Place = 'ZZ22 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode IN ('ZZ22A', 'ZZ22B')) AS TestDepartmentsLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z22', 'Y22') AND CommitteeName LIKE 'ZZ step 22%') AS TestCommitteesLeft;
GO

IF OBJECT_ID('tempdb..#VM') IS NOT NULL DROP TABLE #VM;
IF OBJECT_ID('tempdb..#VMt') IS NOT NULL DROP TABLE #VMt;
GO

SET NOEXEC OFF;
GO
