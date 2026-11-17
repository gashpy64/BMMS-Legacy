/* ============================================================================
   BMMS - Test script for step 49 (Followup reports: who confirmed or
   reopened; one list of blank characters; a tie-break; step FU2b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 49
   is not installed.

   Run it in a NEW query window (it uses temporary tables and procedures of
   its own names). Result: one grid with a numbered row per check (TestNo,
   Test, Expected, Actual, Status) and one summary row (Passed, Failed,
   Skipped). Every row must read PASS.

   Part 1 reads only: the markers (and the kept marker of step 47);
   parameters and result columns; no feature above compatibility level 100;
   no marker of steps 46, 47 and 48 in the new objects; the condition on
   which the Rollback of step 47 refuses (step 49 installed) is met.

   Part 2, inside ONE transaction that is rolled back (made-up data ZZ49: two
   departments, every role, an inactive user, a user with no name and no
   login, a committee with a meeting with finalised minutes and one with open
   minutes, twelve followups):
     1  Pending, never confirmed            7  reopened by a user now inactive
     2  Confirmed                           8  confirmed by a user with no name
     3  Confirmed before history               and no login
     4  Reopened                            9, 10  Pending, the same committee,
     5  re-confirmed after a Reopen            meeting, department and flag:
     6  confirmed, latest row a Reopen         agenda numbers in the reverse
        (an older build after a rollback)      order of their ids (tie-break)
                                            11 department B; 12 the second meeting
   - who may call: spr_GetFollowupReport the Controller and Management;
     spr_GetFollowupByDepartmentReport the Controller only; Reason 4 for the
     other roles, Reason 8 for the system account, an inactive and no user;
   - the status columns of every case (the texts are built by the page);
   - parity (R26): spr_GetFollowupReport for the Controller against a copy
     of the query ReportsMgr.GetFollowupReport built before, and for
     Management against spr_GetFollowupReportForManagement (step 41, the
     minutes status included), for every filter combination: every
     committee; the ZZ49 committee with one meeting, every meeting, a range;
     with and without a department; Both, Confirmed, Pending; the same rows
     in the same order (the tie-break AgendaNo, ActionItemId applied to the
     old rows, whose order the server chose among equal rows);
   - parity of spr_GetFollowupByDepartmentReport against
     spr_GetActionItemByMeetingIdDeptId with the committee and the subject
     range the page applied before;
   - the tie-break: 10 before 9 in all three lists (spr_GetFollowupList too,
     owner decision RA-1);
   - the one list of blank characters (RA-3): each of its 27 characters alone
     and all of them together refused (Reason 4, nothing written); a
     character not in the list (U+200C) and a reason with a zero-width space
     inside saved.

   Afterwards: nothing of ZZ49 is left, Action_Item, ActionItem_User_Map and
   Action_Item_Status_History are unchanged and every identity counter is
   put back.

   It has no USE line: select the TEST database in SSMS first. Written for
   compatibility level 100. Plain ASCII. From the command line use sqlcmd -I.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase = 'BMMS' OR @CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This test is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_FollowupStatusLatest', 'IF') IS NULL
         OR OBJECT_ID('dbo.spr_GetFollowupReport', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport', 'P') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') NOT LIKE '%FollowupReports-Step49%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') NOT LIKE '%FollowupReports-Step49%'
         OR OBJECT_ID('dbo.spr_GetFollowupReportForManagement', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetActionItemByMeetingIdDeptId', 'P') IS NULL)
BEGIN
    RAISERROR('Step 49 (BMMS-Fix-FollowupReports-Step49.sql) is not installed in "%s", or a procedure the parity checks compare with is missing. Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('tempdb..#T') IS NOT NULL OR OBJECT_ID('tempdb..#Ident') IS NOT NULL OR OBJECT_ID('tempdb..#NR') IS NOT NULL
         OR OBJECT_ID('tempdb..#ND') IS NOT NULL OR OBJECT_ID('tempdb..#O41') IS NOT NULL OR OBJECT_ID('tempdb..#OD') IS NOT NULL
         OR OBJECT_ID('tempdb..#FL') IS NOT NULL OR OBJECT_ID('tempdb..#Cols') IS NOT NULL)
BEGIN
    RAISERROR('A temporary table of this script already exists in this window. Run the script in a NEW query window. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(2000), Actual VARCHAR(2000));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
CREATE TABLE #Cols (TableName SYSNAME PRIMARY KEY, List NVARCHAR(MAX));

-- The result sets, with the columns the procedures return (made from the same tables, no rows), and ZzSeq for the
-- order in which the rows came
SELECT TOP 0 v.*, m.MinutesStatus, CAST(NULL AS VARCHAR(30)) AS MinutesStatusMark, s.StatusAction, s.StatusReason, s.StatusOn,
       s.StatusByName, s.StatusByLogin, s.StatusByActive
INTO #NR
FROM View_Action_Item v INNER JOIN Meeting m ON m.MeetingId = v.MeetingId OUTER APPLY dbo.fn_FollowupStatusLatest(v.ActionItemId) s;
SELECT TOP 0 v.*, s.StatusAction, s.StatusReason, s.StatusOn, s.StatusByName, s.StatusByLogin, s.StatusByActive
INTO #ND
FROM View_Action_Item v OUTER APPLY dbo.fn_FollowupStatusLatest(v.ActionItemId) s;
SELECT TOP 0 v.*, m.MinutesStatus, CAST(NULL AS VARCHAR(30)) AS MinutesStatusMark
INTO #O41
FROM View_Action_Item v INNER JOIN Meeting m ON m.MeetingId = v.MeetingId;
SELECT TOP 0 v.* INTO #OD FROM View_Action_Item v;
SELECT TOP 0 v.*, s.StatusAction, s.StatusReason, s.StatusOn, s.StatusByName, s.StatusByLogin, s.StatusByActive
INTO #FL
FROM View_Action_Item v OUTER APPLY dbo.fn_FollowupStatusLatest(v.ActionItemId) s;

INSERT INTO #Cols (TableName, List)
SELECT t.Name, STUFF((SELECT N',' + QUOTENAME(c.name) FROM tempdb.sys.columns c
                      WHERE c.object_id = OBJECT_ID('tempdb..' + t.Name) ORDER BY c.column_id FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N'')
FROM (VALUES ('#NR'), ('#ND'), ('#O41'), ('#OD'), ('#FL')) t(Name);

ALTER TABLE #NR ADD ZzSeq INT IDENTITY(1,1);
ALTER TABLE #ND ADD ZzSeq INT IDENTITY(1,1);
ALTER TABLE #O41 ADD ZzSeq INT IDENTITY(1,1);
ALTER TABLE #OD ADD ZzSeq INT IDENTITY(1,1);
ALTER TABLE #FL ADD ZzSeq INT IDENTITY(1,1);

INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-- spr_GetFollowupReport into #NR: the ActionItemIds in the order returned, the row count, Result and Reason
CREATE PROCEDURE #R49
@a INT, @c INT, @s INT, @m INT, @f INT, @t INT, @d INT, @k INT,
@Ids NVARCHAR(MAX) OUTPUT, @Rows INT OUTPUT, @R INT OUTPUT, @Rs INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    DELETE FROM #NR;
    SET @Sql = N'INSERT INTO #NR (' + (SELECT List FROM #Cols WHERE TableName = '#NR') + N') EXEC dbo.spr_GetFollowupReport @ActingUserId = @a,
        @CommitteeId = @c, @MeetingNoSearch = @s, @MeetingId = @m, @FromMeetingId = @f, @ToMeetingId = @t, @DepartmentId = @d,
        @ConfirmStatus = @k, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;';
    EXEC sp_executesql @Sql, N'@a INT, @c INT, @s INT, @m INT, @f INT, @t INT, @d INT, @k INT, @R INT OUTPUT, @Rs INT OUTPUT',
         @a = @a, @c = @c, @s = @s, @m = @m, @f = @f, @t = @t, @d = @d, @k = @k, @R = @R OUTPUT, @Rs = @Rs OUTPUT;
    SET @Rows = (SELECT COUNT(*) FROM #NR);
    SET @Ids = ISNULL(STUFF((SELECT N',' + CAST(ActionItemId AS NVARCHAR(12)) FROM #NR ORDER BY ZzSeq FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''), N'');
END
GO

-- spr_GetFollowupByDepartmentReport into #ND
CREATE PROCEDURE #D49
@a INT, @c INT, @f INT, @t INT, @d INT, @sf INT, @st INT,
@Ids NVARCHAR(MAX) OUTPUT, @Rows INT OUTPUT, @R INT OUTPUT, @Rs INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    DELETE FROM #ND;
    SET @Sql = N'INSERT INTO #ND (' + (SELECT List FROM #Cols WHERE TableName = '#ND') + N') EXEC dbo.spr_GetFollowupByDepartmentReport @ActingUserId = @a,
        @CommitteeId = @c, @MeetingNoFrom = @f, @MeetingNoTo = @t, @DepartmentId = @d, @SubjectNoFrom = @sf, @SubjectNoTo = @st,
        @Result = @R OUTPUT, @Reason = @Rs OUTPUT;';
    EXEC sp_executesql @Sql, N'@a INT, @c INT, @f INT, @t INT, @d INT, @sf INT, @st INT, @R INT OUTPUT, @Rs INT OUTPUT',
         @a = @a, @c = @c, @f = @f, @t = @t, @d = @d, @sf = @sf, @st = @st, @R = @R OUTPUT, @Rs = @Rs OUTPUT;
    SET @Rows = (SELECT COUNT(*) FROM #ND);
    SET @Ids = ISNULL(STUFF((SELECT N',' + CAST(ActionItemId AS NVARCHAR(12)) FROM #ND ORDER BY ZzSeq FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''), N'');
END
GO

-- spr_GetFollowupList into #FL: the ActionItemIds in the order returned
CREATE PROCEDURE #L49
@a INT, @c INT, @s INT, @m INT, @f INT, @t INT, @d INT, @k INT,
@Ids NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @R INT, @Rs INT;
    DELETE FROM #FL;
    SET @Sql = N'INSERT INTO #FL (' + (SELECT List FROM #Cols WHERE TableName = '#FL') + N') EXEC dbo.spr_GetFollowupList @ActingUserId = @a,
        @CommitteeId = @c, @MeetingNoSearch = @s, @MeetingId = @m, @FromMeetingId = @f, @ToMeetingId = @t, @DepartmentId = @d,
        @ConfirmStatus = @k, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;';
    EXEC sp_executesql @Sql, N'@a INT, @c INT, @s INT, @m INT, @f INT, @t INT, @d INT, @k INT, @R INT OUTPUT, @Rs INT OUTPUT',
         @a = @a, @c = @c, @s = @s, @m = @m, @f = @f, @t = @t, @d = @d, @k = @k, @R = @R OUTPUT, @Rs = @Rs OUTPUT;
    SET @Ids = ISNULL(STUFF((SELECT N',' + CAST(ActionItemId AS NVARCHAR(12)) FROM #FL ORDER BY ZzSeq FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''), N'');
END
GO

-- spr_GetFollowupReportForManagement (step 41) into #O41: the ActionItemIds in the order of step 49 (the four keys of
-- step 41, then AgendaNo, ActionItemId), whether the order step 41 returned keeps its four keys (1: no row out of
-- order), and "id:mark" of every row by id
CREATE PROCEDURE #M41
@a INT, @c INT, @s INT, @m INT, @f INT, @t INT, @d INT, @k INT,
@Ids NVARCHAR(MAX) OUTPUT, @Rows INT OUTPUT, @Kept INT OUTPUT, @Marks NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @R INT, @Rs INT;
    DELETE FROM #O41;
    SET @Sql = N'INSERT INTO #O41 (' + (SELECT List FROM #Cols WHERE TableName = '#O41') + N') EXEC dbo.spr_GetFollowupReportForManagement
        @CommitteeId = @c, @MeetingNoSearch = @s, @MeetingId = @m, @FromMeetingId = @f, @ToMeetingId = @t, @DepartmentId = @d,
        @ConfirmStatus = @k, @ActingUserId = @a, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;';
    EXEC sp_executesql @Sql, N'@a INT, @c INT, @s INT, @m INT, @f INT, @t INT, @d INT, @k INT, @R INT OUTPUT, @Rs INT OUTPUT',
         @a = @a, @c = @c, @s = @s, @m = @m, @f = @f, @t = @t, @d = @d, @k = @k, @R = @R OUTPUT, @Rs = @Rs OUTPUT;
    SET @Rows = (SELECT COUNT(*) FROM #O41);
    SET @Ids = ISNULL(STUFF((SELECT N',' + CAST(o.ActionItemId AS NVARCHAR(12)) FROM #O41 o
                             ORDER BY o.CommitteeId, o.MeetingId, o.DepartmentId, o.IsConfirmed, o.AgendaNo, o.ActionItemId
                             FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''), N'');
    SET @Kept = CASE WHEN EXISTS (SELECT 1 FROM #O41 x INNER JOIN #O41 y ON x.ZzSeq < y.ZzSeq
                                  WHERE x.CommitteeId > y.CommitteeId
                                     OR (x.CommitteeId = y.CommitteeId AND x.MeetingId > y.MeetingId)
                                     OR (x.CommitteeId = y.CommitteeId AND x.MeetingId = y.MeetingId AND x.DepartmentId > y.DepartmentId)
                                     OR (x.CommitteeId = y.CommitteeId AND x.MeetingId = y.MeetingId AND x.DepartmentId = y.DepartmentId
                                         AND x.IsConfirmed > y.IsConfirmed))
                     THEN 0 ELSE 1 END;
    SET @Marks = ISNULL((SELECT CAST(ActionItemId AS NVARCHAR(12)) + N':' + ISNULL(MinutesStatusMark, N'-') + N';' FROM #O41 ORDER BY ActionItemId
                         FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'');
END
GO

-- spr_GetActionItemByMeetingIdDeptId (unchanged) into #OD, with what the page did before: only the rows of the
-- committee, and the subject range. The ActionItemIds in the order of step 49 (SubjectNo, then AgendaNo,
-- ActionItemId), and whether the order it returned keeps SubjectNo (1: no row out of order)
CREATE PROCEDURE #OD49
@c INT, @f INT, @t INT, @d INT, @sf INT, @st INT,
@Ids NVARCHAR(MAX) OUTPUT, @Rows INT OUTPUT, @Kept INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    DELETE FROM #OD;
    SET @Sql = N'INSERT INTO #OD (' + (SELECT List FROM #Cols WHERE TableName = '#OD') + N') EXEC dbo.spr_GetActionItemByMeetingIdDeptId
        @CommitteeId = @c, @MeetingNoFrom = @f, @MeetingNoTo = @t, @DepartmentId = @d;';
    EXEC sp_executesql @Sql, N'@c INT, @f INT, @t INT, @d INT', @c = @c, @f = @f, @t = @t, @d = @d;
    SET @Kept = CASE WHEN EXISTS (SELECT 1 FROM #OD x INNER JOIN #OD y ON x.ZzSeq < y.ZzSeq WHERE x.SubjectNo > y.SubjectNo) THEN 0 ELSE 1 END;
    DELETE FROM #OD WHERE CommitteeId <> @c;
    IF (@sf IS NOT NULL AND @st IS NOT NULL)
        DELETE FROM #OD WHERE NOT (SubjectNo >= @sf AND SubjectNo <= @st);
    SET @Rows = (SELECT COUNT(*) FROM #OD);
    SET @Ids = ISNULL(STUFF((SELECT N',' + CAST(o.ActionItemId AS NVARCHAR(12)) FROM #OD o ORDER BY o.SubjectNo, o.AgendaNo, o.ActionItemId
                             FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''), N'');
END
GO

-- The query BMMSBAL/ReportsMgr.cs GetFollowupReport built in the code before step 49 (the Controller's Followup and
-- Followup Summary), built the same way for the same filters, with the tie-break of step 49 (AgendaNo, ActionItemId)
-- for the rows the old ORDER BY left to the server: the ActionItemIds in order.
CREATE PROCEDURE #ZZ49Old
@Committee INT, @Search INT, @Meeting INT, @From INT, @To INT, @Dept INT, @Confirm INT,
@Ids NVARCHAR(MAX) OUTPUT, @Rows INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @O TABLE (Seq BIGINT PRIMARY KEY, ActionItemId INT);

    SET @Sql = N'SELECT ROW_NUMBER() OVER (ORDER BY CommitteeId, MeetingId, DepartmentId, IsConfirmed, AgendaNo, ActionItemId) AS Seq, ActionItemId FROM View_Action_Item WHERE 1=1';
    IF (@Committee > 0)
    BEGIN
        SET @Sql = @Sql + N' AND CommitteeId = ' + CAST(@Committee AS NVARCHAR(12));
        IF (@Search = 0)
            IF (@Meeting > 0)
                SET @Sql = @Sql + N' AND MeetingId = ' + CAST(@Meeting AS NVARCHAR(12));
        IF (@Search = 1)
            SET @Sql = @Sql + N' AND (MeetingId BETWEEN ' + CAST(@From AS NVARCHAR(12)) + N' AND ' + CAST(@To AS NVARCHAR(12)) + N')';
    END
    IF (@Dept > 0)
        SET @Sql = @Sql + N' AND DepartmentId = ' + CAST(@Dept AS NVARCHAR(12));
    IF (@Confirm >= 0)
        SET @Sql = @Sql + N' AND IsConfirmed = ' + CAST(@Confirm AS NVARCHAR(12));

    INSERT INTO @O (Seq, ActionItemId) EXEC (@Sql);

    SET @Rows = (SELECT COUNT(*) FROM @O);
    SET @Ids = ISNULL(STUFF((SELECT N',' + CAST(ActionItemId AS NVARCHAR(12)) FROM @O ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''), N'');
END
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T SELECT 'Marker FollowupReports-Step49 in the five objects; FollowupFinal-Step47 kept in spr_GetFollowupList and spr_ReopenFollowup', '5, 2',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_FollowupStatusLatest'), ('spr_GetFollowupReport'), ('spr_GetFollowupByDepartmentReport'),
                                          ('spr_GetFollowupList'), ('spr_ReopenFollowup')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupReports-Step49%') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM (VALUES ('spr_GetFollowupList'), ('spr_ReopenFollowup')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupFinal-Step47%') AS VARCHAR(12));

INSERT INTO #T SELECT 'Parameters of the new objects, in their order',
       'fn: @ActionItemId | report: @ActingUserId,@CommitteeId,@MeetingNoSearch,@MeetingId,@FromMeetingId,@ToMeetingId,@DepartmentId,@ConfirmStatus,@Result,@Reason | department: @ActingUserId,@CommitteeId,@MeetingNoFrom,@MeetingNoTo,@DepartmentId,@SubjectNoFrom,@SubjectNoTo,@Result,@Reason',
       'fn: ' + ISNULL(STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.fn_FollowupStatusLatest') AND p.parameter_id > 0 ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, ''), '-')
     + ' | report: ' + ISNULL(STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetFollowupReport') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, ''), '-')
     + ' | department: ' + ISNULL(STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, ''), '-');

INSERT INTO #T SELECT 'Parameters of spr_GetFollowupList and spr_ReopenFollowup unchanged (step 47)',
       '@ActingUserId,@CommitteeId,@MeetingNoSearch,@MeetingId,@FromMeetingId,@ToMeetingId,@DepartmentId,@ConfirmStatus,@Result,@Reason | @ActingUserId,@ActionItemId,@ReopenReason,@Result,@Reason',
       ISNULL(STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetFollowupList') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, ''), '-')
     + ' | ' + ISNULL(STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_ReopenFollowup') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, ''), '-');

DECLARE @View VARCHAR(MAX), @Cols VARCHAR(MAX);
SELECT @View = ISNULL(@View + ',', '') + c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.View_Action_Item') ORDER BY c.column_id;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetFollowupReport'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetFollowupReport: the View_Action_Item columns, MinutesStatus, MinutesStatusMark, the six status columns',
       @View + ',MinutesStatus,MinutesStatusMark,StatusAction,StatusReason,StatusOn,StatusByName,StatusByLogin,StatusByActive', ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetFollowupByDepartmentReport: the View_Action_Item columns (those of spr_GetActionItemByMeetingIdDeptId) and the six status columns',
       @View + ',StatusAction,StatusReason,StatusOn,StatusByName,StatusByLogin,StatusByActive', ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.fn_FollowupStatusLatest') ORDER BY c.column_id;
INSERT INTO #T SELECT 'fn_FollowupStatusLatest: the six status columns', 'StatusAction,StatusReason,StatusOn,StatusByName,StatusByLogin,StatusByActive', ISNULL(@Cols, 'none');

INSERT INTO #T SELECT 'No feature above compatibility level 100 in the five texts (THROW, IIF, CONCAT, FORMAT, TRY_CONVERT, OFFSET, STRING_AGG, EOMONTH)', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_FollowupStatusLatest'), ('spr_GetFollowupReport'), ('spr_GetFollowupByDepartmentReport'),
                                          ('spr_GetFollowupList'), ('spr_ReopenFollowup')) o(Name)
             CROSS JOIN (VALUES ('%THROW%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('%TRY[_]CONVERT%'), ('% OFFSET %'), ('%STRING[_]AGG%'), ('%EOMONTH%')) f(Pattern)
             WHERE UPPER(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name))) LIKE f.Pattern) AS VARCHAR(12));

-- The Test scripts of steps 46, 47 and 48 count the objects that carry their markers
INSERT INTO #T SELECT 'No marker of steps 46, 47 and 48 in the three new objects', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_FollowupStatusLatest'), ('spr_GetFollowupReport'), ('spr_GetFollowupByDepartmentReport')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupSave-Step46%'
                OR OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupFinal-Step47%'
                OR OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardFollowupFinal-Step48%') AS VARCHAR(12));

INSERT INTO #T SELECT 'spr_GetFollowupReportForManagement (step 41) and spr_GetActionItemByMeetingIdDeptId are not changed (no step 49 marker)', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_GetFollowupReportForManagement'), ('spr_GetActionItemByMeetingIdDeptId')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupReports-Step49%') AS VARCHAR(12));

INSERT INTO #T SELECT 'The condition on which BMMS-Rollback-FollowupFinal-Step47.sql refuses (step 49 installed) is met', 'met',
       CASE WHEN OBJECT_ID('dbo.fn_FollowupStatusLatest', 'IF') IS NOT NULL
                 OR OBJECT_ID('dbo.spr_GetFollowupReport', 'P') IS NOT NULL
                 OR OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport', 'P') IS NOT NULL
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') LIKE '%FollowupReports-Step49%'
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') LIKE '%FollowupReports-Step49%'
            THEN 'met' ELSE 'not met' END;
GO

-------------------------------------------------------------------------------
-- Part 2: the rules, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(2000), Actual VARCHAR(2000));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @rMd INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect' ORDER BY RoleId);
DECLARE @Followup INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId = 1);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DeptA INT, @DeptB INT, @Com INT, @M1 INT, @M2 INT;
DECLARE @Adm INT, @Ctl INT, @Mgr INT, @Usr INT, @Gmt INT, @Mds INT, @Off INT, @Nob INT;
DECLARE @I1 INT, @I2 INT, @I3 INT, @I4 INT, @I5 INT, @I6 INT, @I7 INT, @I8 INT, @I9 INT, @I10 INT, @I11 INT, @I12 INT;
DECLARE @Res INT, @Rsn INT, @Txt VARCHAR(2000), @Ids NVARCHAR(MAX), @Ids2 NVARCHAR(MAX), @N INT, @N2 INT, @Kept INT, @Marks NVARCHAR(MAX), @MarksNew NVARCHAR(MAX);
DECLARE @Combos INT, @Differ INT, @Compared INT, @First VARCHAR(300), @Between NVARCHAR(MAX), @AllKept INT;
DECLARE @Cm INT, @Sr INT, @Mt INT, @Fm INT, @Tm INT, @Dp INT, @Cf INT, @SF INT, @ST INT;
DECLARE @Code INT, @Refused INT, @Codes INT, @All NVARCHAR(200), @HistCount INT, @Ag INT, @No INT, @One NVARCHAR(500);
DECLARE @ItemBefore VARCHAR(60), @ItemAfter VARCHAR(60), @MapBefore VARCHAR(60), @MapAfter VARCHAR(60), @HistBefore VARCHAR(60), @HistAfter VARCHAR(60);
DECLARE @Combo TABLE (Seq INT IDENTITY(1,1), Committee INT, Search INT, Meeting INT, FromM INT, ToM INT, Dept INT, Confirm INT);
DECLARE @DCombo TABLE (Seq INT IDENTITY(1,1), FromNo INT, ToNo INT, Dept INT, SubFrom INT, SubTo INT);
-- The one list of blank characters (step 49; ActionItemMgr.ReopenBlankCharacters in BMMSBAL has the same list)
DECLARE @Blank TABLE (Code INT PRIMARY KEY);
INSERT INTO @Blank (Code) VALUES (9), (10), (11), (12), (13), (32), (133), (160), (5760), (8192), (8193), (8194), (8195), (8196), (8197), (8198),
                                 (8199), (8200), (8201), (8202), (8203), (8232), (8233), (8239), (8287), (12288), (65279);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMd IS NULL OR @Followup IS NULL
    OR @Desig IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, a subject type or the decision type Followup (1) is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT @ItemBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;
SELECT @HistBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(StatusHistoryId, ActionItemId, [Action], ActedBy, ActedOn)), 0) AS VARCHAR(12)) FROM Action_Item_Status_History;

BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ49A', 'ZZ49 department A', 987, 1, @Now, @Sys);
    SET @DeptA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ49B', 'ZZ49 department B', 988, 1, @Now, @Sys);
    SET @DeptB = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ49 admin', @DeptA, @Desig, NULL, @rAdmin, 'zz49a@example.invalid', 'zz49adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ49 controller', @DeptA, @Desig, NULL, @rCtl, 'zz49c@example.invalid', 'zz49ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ49 manager', @DeptA, @Desig, NULL, @rMgr, 'zz49m@example.invalid', 'zz49mgr', 'not-a-login', 1, @Now);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ49 user', @DeptA, @Desig, @Mgr, @rUser, 'zz49u@example.invalid', 'zz49usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ49 management', @DeptA, @Desig, NULL, @rMgmt, 'zz49g@example.invalid', 'zz49gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ49 md secretariat', @DeptA, @Desig, NULL, @rMd, 'zz49s@example.invalid', 'zz49mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ49 inactive controller', @DeptA, @Desig, NULL, @rCtl, 'zz49i@example.invalid', 'zz49off', 'not-a-login', 0, @Now);
    SET @Off = SCOPE_IDENTITY();
    -- A controller with no name and no login (the page writes "an unknown user"); inactive, so it cannot sign in
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('', @DeptA, @Desig, NULL, @rCtl, 'zz49n@example.invalid', '', 'not-a-login', 0, @Now);
    SET @Nob = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z49', 'ZZ49 committee', '2000-01-01', 1, 0);
    SET @Com = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94901', @Com, 'ZZ49 test', 'ZZ', DATEADD(DAY, -20, @Day), '10:00', DATEADD(DAY, -25, @Day), 'Close', 'F', @Now, @Sys);
    SET @M1 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94902', @Com, 'ZZ49 test', 'ZZ', DATEADD(DAY, -10, @Day), '10:00', DATEADD(DAY, -15, @Day), 'Close', 'Open', @Now, @Sys);
    SET @M2 = SCOPE_IDENTITY();

    -- Twelve agenda items, inserted in this order (their ids follow it): 9 (ZZ49-T2) before 10 (ZZ49-T1), so 10 has the
    -- lower agenda number and the higher id; 9 and 10 share a subject number
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, SubjectNo, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT x.AgendaNo, @Com, CASE WHEN x.No = 12 THEN @M2 ELSE @M1 END, CASE WHEN x.No = 11 THEN @DeptB ELSE @DeptA END, @SubjectTypeId, x.SubjectNo,
           'ZZ49 item ' + CAST(x.No AS VARCHAR(4)), 'Entry', 'ACA', 'New', @Now, @Usr
    FROM (SELECT 1 AS No, 'ZZ49-01' AS AgendaNo, 9401 AS SubjectNo UNION ALL SELECT 2, 'ZZ49-02', 9402 UNION ALL SELECT 3, 'ZZ49-03', 9403
          UNION ALL SELECT 4, 'ZZ49-04', 9404 UNION ALL SELECT 5, 'ZZ49-05', 9405 UNION ALL SELECT 6, 'ZZ49-06', 9406
          UNION ALL SELECT 7, 'ZZ49-07', 9407 UNION ALL SELECT 8, 'ZZ49-08', 9408 UNION ALL SELECT 9, 'ZZ49-T2', 9409
          UNION ALL SELECT 10, 'ZZ49-T1', 9409 UNION ALL SELECT 11, 'ZZ49-11', 9411 UNION ALL SELECT 12, 'ZZ49-12', 9412) x
    ORDER BY x.No;

    INSERT INTO Minutes (AgendaId, DecisionTypeId, DueDate, StatusId, CreatedOn, CreatedBy)
    SELECT a.AgendaId, @Followup, NULL, 0, @Now, @Sys FROM Agenda a WHERE a.CommitteeId = @Com ORDER BY a.AgendaId;

    -- One action item per agenda item, one at a time in the order of the agenda ids; the action text "n ZZ49" names
    -- the case; 2, 3, 5, 6 and 8 are confirmed
    DECLARE AgCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT a.AgendaId, CAST(SUBSTRING(a.ShortText, 11, 4) AS INT) FROM Agenda a WHERE a.CommitteeId = @Com ORDER BY a.AgendaId;
    OPEN AgCursor;
    FETCH NEXT FROM AgCursor INTO @Ag, @No;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)
        SELECT mi.MinutesId, N'ZZ49', CAST(@No AS NVARCHAR(4)) + N' ZZ49', '', 0,
               CASE WHEN @No IN (2, 3, 5, 6, 8) THEN 1 ELSE 0 END, DATEADD(DAY, -3, @Day), @Sys
        FROM Minutes mi WHERE mi.AgendaId = @Ag;
        FETCH NEXT FROM AgCursor INTO @Ag, @No;
    END
    CLOSE AgCursor;
    DEALLOCATE AgCursor;

    SET @I1 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'1 ZZ49');
    SET @I2 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'2 ZZ49');
    SET @I3 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'3 ZZ49');
    SET @I4 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'4 ZZ49');
    SET @I5 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'5 ZZ49');
    SET @I6 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'6 ZZ49');
    SET @I7 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'7 ZZ49');
    SET @I8 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'8 ZZ49');
    SET @I9 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'9 ZZ49');
    SET @I10 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'10 ZZ49');
    SET @I11 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'11 ZZ49');
    SET @I12 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ49' AND ActionText = N'12 ZZ49');

    INSERT INTO @T SELECT 'The made-up data: twelve items; 10 has a higher id than 9 but the lower agenda number', '12, 1',
           CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ49') AS VARCHAR(12)) + ', '
         + CASE WHEN @I10 > @I9 THEN '1' ELSE '0' END;

    -- The history, as the Followup page writes it (step 47); 3 has none (confirmed before step 47)
    INSERT INTO Action_Item_Status_History (ActionItemId, [Action], Reason, ActedBy, ActedOn)
    SELECT h.Item, h.Act, h.Reason, h.ActedBy, DATEADD(HOUR, h.Hr, DATEADD(DAY, -2, @Day))
    FROM (SELECT 1 AS Seq, @I2 AS Item, 'Confirm' AS Act, CAST(NULL AS NVARCHAR(500)) AS Reason, @Ctl AS ActedBy, 9 AS Hr
          UNION ALL SELECT 2, @I4, 'Confirm', NULL, @Ctl, 9
          UNION ALL SELECT 3, @I4, 'Reopen', N'ZZ49 reopen <b> & "x"', @Ctl, 10
          UNION ALL SELECT 4, @I5, 'Confirm', NULL, @Ctl, 9
          UNION ALL SELECT 5, @I5, 'Reopen', N'ZZ49 reopen 5', @Ctl, 10
          UNION ALL SELECT 6, @I5, 'Confirm', NULL, @Ctl, 11
          UNION ALL SELECT 7, @I6, 'Confirm', NULL, @Ctl, 9
          UNION ALL SELECT 8, @I6, 'Reopen', N'ZZ49 reopen 6', @Ctl, 10
          UNION ALL SELECT 9, @I7, 'Confirm', NULL, @Ctl, 9
          UNION ALL SELECT 10, @I7, 'Reopen', N'ZZ49 reopen 7', @Off, 10
          UNION ALL SELECT 11, @I8, 'Confirm', NULL, @Nob, 9) h
    ORDER BY h.Seq;

    ---------------------------------------------------------------------------
    -- Who may call: "Result Reason rows"
    ---------------------------------------------------------------------------
    SET @Txt = '';
    EXEC #R49 @a = @Ctl, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + 'ctl ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #R49 @a = @Gmt, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', mgmt ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #R49 @a = @Mgr, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', mgr ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #R49 @a = @Usr, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', usr ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #R49 @a = @Mds, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', md ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #R49 @a = @Adm, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', admin ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #R49 @a = @Sys, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', system ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #R49 @a = @Off, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', inactive ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #R49 @a = NULL, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', none ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    INSERT INTO @T SELECT 'spr_GetFollowupReport (Result, Reason, rows of the ZZ49 committee): the Controller and Management; Reason 4 for the other roles; Reason 8 for the system account, an inactive and no user',
           'ctl 1 0 12, mgmt 1 0 12, mgr 0 4 0, usr 0 4 0, md 0 4 0, admin 0 4 0, system 0 8 0, inactive 0 8 0, none 0 8 0', @Txt;

    SET @Txt = '';
    EXEC #D49 @a = @Ctl, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + 'ctl ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #D49 @a = @Gmt, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', mgmt ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #D49 @a = @Mgr, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', mgr ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #D49 @a = @Usr, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', usr ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #D49 @a = @Mds, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', md ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #D49 @a = @Adm, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', admin ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #D49 @a = @Sys, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', system ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #D49 @a = @Off, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', inactive ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    EXEC #D49 @a = NULL, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', none ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST(@N AS VARCHAR(12));
    INSERT INTO @T SELECT 'spr_GetFollowupByDepartmentReport (Result, Reason, rows): the Controller only; Reason 4 for Management and the other roles; Reason 8 for the system account, an inactive and no user',
           'ctl 1 0 12, mgmt 0 4 0, mgr 0 4 0, usr 0 4 0, md 0 4 0, admin 0 4 0, system 0 8 0, inactive 0 8 0, none 0 8 0', @Txt;

    ---------------------------------------------------------------------------
    -- The status columns of every case (the Controller's report of the committee)
    ---------------------------------------------------------------------------
    EXEC #R49 @a = @Ctl, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Status columns (flag, action, reason, name, login, active, time): 1 Pending; 2 Confirmed; 3 before history; 4 Reopened; 5 re-confirmed; 6 confirmed, latest a Reopen; 7 reopened by an inactive user; 8 no name, no login',
           '1: 0 - - - - - -; 2: 1 Confirm - ZZ49 controller zz49ctl 1 09:00; 3: 1 - - - - - -; 4: 0 Reopen ZZ49 reopen <b> & "x" ZZ49 controller zz49ctl 1 10:00; '
         + '5: 1 Confirm - ZZ49 controller zz49ctl 1 11:00; 6: 1 Reopen ZZ49 reopen 6 ZZ49 controller zz49ctl 1 10:00; 7: 0 Reopen ZZ49 reopen 7 ZZ49 inactive controller zz49off 0 10:00; 8: 1 Confirm - [] [] 0 09:00',
           ISNULL(STUFF((SELECT '; ' + CAST(LEFT(CAST(r.ActionText AS NVARCHAR(10)), CHARINDEX(N' ', CAST(r.ActionText AS NVARCHAR(10))) - 1) AS VARCHAR(4)) + ': '
                                + CAST(r.IsConfirmed AS VARCHAR(2)) + ' ' + ISNULL(r.StatusAction, '-') + ' ' + ISNULL(CAST(r.StatusReason AS VARCHAR(100)), '-') + ' '
                                + CASE WHEN r.StatusByName IS NULL THEN '-' WHEN r.StatusByName = '' THEN '[]' ELSE r.StatusByName END + ' '
                                + CASE WHEN r.StatusByLogin IS NULL THEN '-' WHEN r.StatusByLogin = '' THEN '[]' ELSE r.StatusByLogin END + ' '
                                + ISNULL(CAST(r.StatusByActive AS VARCHAR(2)), '-') + ' ' + ISNULL(CONVERT(VARCHAR(5), r.StatusOn, 108), '-')
                         FROM #NR r WHERE r.ActionItemId IN (@I1, @I2, @I3, @I4, @I5, @I6, @I7, @I8) ORDER BY r.ActionItemId
                         FOR XML PATH(''), TYPE).value('.', 'VARCHAR(2000)'), 1, 2, ''), 'none');
    INSERT INTO @T SELECT 'The Controller''s rows have no minutes status (MinutesStatus and MinutesStatusMark NULL)', '0',
           CAST((SELECT COUNT(*) FROM #NR WHERE MinutesStatus IS NOT NULL OR MinutesStatusMark IS NOT NULL) AS VARCHAR(12));
    EXEC #R49 @a = @Gmt, @c = @Com, @s = 0, @m = 0, @f = 0, @t = 0, @d = 0, @k = -1, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Management''s rows have the minutes status (meeting 94901 Finalised, 94902 Draft) and the same status columns',
           'Finalised 11, Draft (not finalised) 1 | 6 items with history',
           ISNULL(STUFF((SELECT ', ' + MinutesStatusMark + ' ' + CAST(COUNT(*) AS VARCHAR(12)) FROM #NR GROUP BY MinutesStatusMark ORDER BY MinutesStatusMark DESC FOR XML PATH('')), 1, 2, ''), 'none')
         + ' | ' + CAST((SELECT COUNT(*) FROM #NR WHERE StatusAction IS NOT NULL) AS VARCHAR(12)) + ' items with history';
    EXEC #D49 @a = @Ctl, @c = @Com, @f = 94901, @t = 94902, @d = -1, @sf = NULL, @st = NULL, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Followup by Department: the same status columns as the Followup report (6 items with history: 2, 4 to 8; the reason of 4)',
           '6 | ZZ49 reopen <b> & "x"',
           CAST((SELECT COUNT(*) FROM #ND WHERE StatusAction IS NOT NULL) AS VARCHAR(12)) + ' | '
         + ISNULL((SELECT CAST(StatusReason AS VARCHAR(100)) FROM #ND WHERE ActionItemId = @I4), '-');
    INSERT INTO @T SELECT 'fn_FollowupStatusLatest: no row for an item without history (1, 3), one row for an item with three (5)', '0 0 1',
           CAST((SELECT COUNT(*) FROM dbo.fn_FollowupStatusLatest(@I1)) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM dbo.fn_FollowupStatusLatest(@I3)) AS VARCHAR(12))
         + ' ' + CAST((SELECT COUNT(*) FROM dbo.fn_FollowupStatusLatest(@I5)) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The tie-break (RA-1, Q2): 9 and 10 are equal in committee, meeting, department and flag (and in subject number);
    -- 10 has the lower agenda number and the higher id: 10 before 9 in all three lists
    ---------------------------------------------------------------------------
    EXEC #R49 @a = @Ctl, @c = @Com, @s = 0, @m = @M1, @f = 0, @t = 0, @d = @DeptA, @k = 0, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = 'report ' + CASE WHEN CHARINDEX(N',' + CAST(@I10 AS NVARCHAR(12)) + N',', N',' + @Ids + N',') < CHARINDEX(N',' + CAST(@I9 AS NVARCHAR(12)) + N',', N',' + @Ids + N',')
                                     AND CHARINDEX(N',' + CAST(@I10 AS NVARCHAR(12)) + N',', N',' + @Ids + N',') > 0 THEN '10,9' ELSE '9,10' END;
    EXEC #D49 @a = @Ctl, @c = @Com, @f = 94901, @t = 94901, @d = @DeptA, @sf = 9409, @st = 9409, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    SET @Txt = @Txt + ', department ' + CASE WHEN @Ids = CAST(@I10 AS NVARCHAR(12)) + N',' + CAST(@I9 AS NVARCHAR(12)) THEN '10,9' ELSE 'other: ' + CAST(@Ids AS VARCHAR(100)) END;
    EXEC #L49 @a = @Ctl, @c = @Com, @s = 0, @m = @M1, @f = 0, @t = 0, @d = @DeptA, @k = 0, @Ids = @Ids OUTPUT;
    SET @Txt = @Txt + ', list ' + CASE WHEN CHARINDEX(N',' + CAST(@I10 AS NVARCHAR(12)) + N',', N',' + @Ids + N',') < CHARINDEX(N',' + CAST(@I9 AS NVARCHAR(12)) + N',', N',' + @Ids + N',')
                                         AND CHARINDEX(N',' + CAST(@I10 AS NVARCHAR(12)) + N',', N',' + @Ids + N',') > 0 THEN '10,9' ELSE '9,10' END;
    INSERT INTO @T SELECT 'Tie-break AgendaNo, ActionItemId: 10 (ZZ49-T1, higher id) before 9 (ZZ49-T2) in the Followup report, Followup by Department (subject 9409 only) and the Followup page''s list',
           'report 10,9, department 10,9, list 10,9', @Txt;

    ---------------------------------------------------------------------------
    -- Parity (R26): the Followup report against the query before (Controller) and step 41 (Management)
    ---------------------------------------------------------------------------
    INSERT INTO @Combo (Committee, Search, Meeting, FromM, ToM, Dept, Confirm)
    SELECT f.Committee, f.Search, f.Meeting, f.FromM, f.ToM, d.Dept, c.Confirm
    FROM (SELECT 0 AS Committee, 0 AS Search, 0 AS Meeting, 0 AS FromM, 0 AS ToM          -- every committee
          UNION ALL SELECT @Com, 0, @M1, 0, 0                                                -- Particular, meeting 94901
          UNION ALL SELECT @Com, 0, 0, 0, 0                                                  -- Particular, every meeting
          UNION ALL SELECT @Com, 1, 0, @M1, @M2) f                                           -- Between 94901 and 94902
    CROSS JOIN (SELECT 0 AS Dept UNION ALL SELECT @DeptA) d
    CROSS JOIN (SELECT -1 AS Confirm UNION ALL SELECT 1 UNION ALL SELECT 0) c;

    SET @Differ = 0; SET @Combos = 0; SET @Compared = 0; SET @First = ''; SET @Between = N'';
    DECLARE ComboCursor CURSOR LOCAL FAST_FORWARD FOR SELECT Committee, Search, Meeting, FromM, ToM, Dept, Confirm FROM @Combo ORDER BY Seq;
    OPEN ComboCursor;
    FETCH NEXT FROM ComboCursor INTO @Cm, @Sr, @Mt, @Fm, @Tm, @Dp, @Cf;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        EXEC #R49 @a = @Ctl, @c = @Cm, @s = @Sr, @m = @Mt, @f = @Fm, @t = @Tm, @d = @Dp, @k = @Cf, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
        EXEC #ZZ49Old @Committee = @Cm, @Search = @Sr, @Meeting = @Mt, @From = @Fm, @To = @Tm, @Dept = @Dp, @Confirm = @Cf, @Ids = @Ids2 OUTPUT, @Rows = @N2 OUTPUT;
        SET @Combos = @Combos + 1;
        SET @Compared = @Compared + @N2;
        IF (@Cm = @Com AND @Sr = 1 AND @Dp = 0 AND @Cf = -1)
            SET @Between = @Ids;
        IF (@Res <> 1 OR @N <> @N2 OR CAST(@Ids AS VARBINARY(MAX)) <> CAST(@Ids2 AS VARBINARY(MAX)))
        BEGIN
            SET @Differ = @Differ + 1;
            IF (@First = '')
                SET @First = ' first: committee ' + CAST(@Cm AS VARCHAR(12)) + ' search ' + CAST(@Sr AS VARCHAR(2)) + ' dept ' + CAST(@Dp AS VARCHAR(12))
                           + ' confirm ' + CAST(@Cf AS VARCHAR(2)) + ' rows ' + CAST(@N AS VARCHAR(12)) + '/' + CAST(@N2 AS VARCHAR(12));
        END
        FETCH NEXT FROM ComboCursor INTO @Cm, @Sr, @Mt, @Fm, @Tm, @Dp, @Cf;
    END
    CLOSE ComboCursor;
    DEALLOCATE ComboCursor;
    INSERT INTO @T SELECT 'Parity, the Controller: spr_GetFollowupReport against the query ReportsMgr.GetFollowupReport built before, Both / Confirmed / Pending, every committee, one meeting, every meeting, Between, with and without a department ('
                        + CAST(@Compared AS VARCHAR(12)) + ' rows compared): combinations, combinations that differ',
           '24, 0', CAST(@Combos AS VARCHAR(12)) + ', ' + CAST(@Differ AS VARCHAR(12)) + @First;
    INSERT INTO @T SELECT 'Parity is not empty: the ZZ49 items in the Between combination (94901 and 94902, Both, no department)', '12',
           CAST((SELECT COUNT(*) FROM Action_Item a WHERE a.Directions = N'ZZ49'
                 AND N',' + ISNULL(@Between, N'') + N',' LIKE N'%,' + CAST(a.ActionItemId AS NVARCHAR(12)) + N',%') AS VARCHAR(12));

    SET @Differ = 0; SET @Combos = 0; SET @Compared = 0; SET @First = ''; SET @AllKept = 1;
    DECLARE ComboCursor2 CURSOR LOCAL FAST_FORWARD FOR SELECT Committee, Search, Meeting, FromM, ToM, Dept, Confirm FROM @Combo ORDER BY Seq;
    OPEN ComboCursor2;
    FETCH NEXT FROM ComboCursor2 INTO @Cm, @Sr, @Mt, @Fm, @Tm, @Dp, @Cf;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        EXEC #R49 @a = @Gmt, @c = @Cm, @s = @Sr, @m = @Mt, @f = @Fm, @t = @Tm, @d = @Dp, @k = @Cf, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
        SET @MarksNew = ISNULL((SELECT CAST(ActionItemId AS NVARCHAR(12)) + N':' + ISNULL(MinutesStatusMark, N'-') + N';' FROM #NR ORDER BY ActionItemId
                                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'');
        EXEC #M41 @a = @Gmt, @c = @Cm, @s = @Sr, @m = @Mt, @f = @Fm, @t = @Tm, @d = @Dp, @k = @Cf, @Ids = @Ids2 OUTPUT, @Rows = @N2 OUTPUT, @Kept = @Kept OUTPUT, @Marks = @Marks OUTPUT;
        SET @Combos = @Combos + 1;
        SET @Compared = @Compared + @N2;
        IF (@Kept = 0) SET @AllKept = 0;
        IF (@Res <> 1 OR @N <> @N2 OR CAST(@Ids AS VARBINARY(MAX)) <> CAST(@Ids2 AS VARBINARY(MAX)) OR CAST(@MarksNew AS VARBINARY(MAX)) <> CAST(@Marks AS VARBINARY(MAX)))
        BEGIN
            SET @Differ = @Differ + 1;
            IF (@First = '')
                SET @First = ' first: committee ' + CAST(@Cm AS VARCHAR(12)) + ' search ' + CAST(@Sr AS VARCHAR(2)) + ' dept ' + CAST(@Dp AS VARCHAR(12))
                           + ' confirm ' + CAST(@Cf AS VARCHAR(2)) + ' rows ' + CAST(@N AS VARCHAR(12)) + '/' + CAST(@N2 AS VARCHAR(12));
        END
        FETCH NEXT FROM ComboCursor2 INTO @Cm, @Sr, @Mt, @Fm, @Tm, @Dp, @Cf;
    END
    CLOSE ComboCursor2;
    DEALLOCATE ComboCursor2;
    INSERT INTO @T SELECT 'Parity, Management: spr_GetFollowupReport against spr_GetFollowupReportForManagement (step 41), the rows, their order and the minutes status, the same combinations ('
                        + CAST(@Compared AS VARCHAR(12)) + ' rows compared): combinations, combinations that differ, step 41 order kept its four keys',
           '24, 0, 1', CAST(@Combos AS VARCHAR(12)) + ', ' + CAST(@Differ AS VARCHAR(12)) + ', ' + CAST(@AllKept AS VARCHAR(2)) + @First;

    ---------------------------------------------------------------------------
    -- Parity of Followup by Department: against spr_GetActionItemByMeetingIdDeptId with the page's filters before
    ---------------------------------------------------------------------------
    INSERT INTO @DCombo (FromNo, ToNo, Dept, SubFrom, SubTo)
    SELECT m.FromNo, m.ToNo, d.Dept, s.SubFrom, s.SubTo
    FROM (SELECT 94901 AS FromNo, 94901 AS ToNo UNION ALL SELECT 94901, 94902) m
    CROSS JOIN (SELECT -1 AS Dept UNION ALL SELECT @DeptA UNION ALL SELECT @DeptB) d
    CROSS JOIN (SELECT CAST(NULL AS INT) AS SubFrom, CAST(NULL AS INT) AS SubTo UNION ALL SELECT 9402, 9407) s;

    SET @Differ = 0; SET @Combos = 0; SET @Compared = 0; SET @First = ''; SET @AllKept = 1;
    DECLARE DCursor CURSOR LOCAL FAST_FORWARD FOR SELECT FromNo, ToNo, Dept, SubFrom, SubTo FROM @DCombo ORDER BY Seq;
    OPEN DCursor;
    FETCH NEXT FROM DCursor INTO @Fm, @Tm, @Dp, @SF, @ST;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        EXEC #D49 @a = @Ctl, @c = @Com, @f = @Fm, @t = @Tm, @d = @Dp, @sf = @SF, @st = @ST, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
        EXEC #OD49 @c = @Com, @f = @Fm, @t = @Tm, @d = @Dp, @sf = @SF, @st = @ST, @Ids = @Ids2 OUTPUT, @Rows = @N2 OUTPUT, @Kept = @Kept OUTPUT;
        SET @Combos = @Combos + 1;
        SET @Compared = @Compared + @N2;
        IF (@Kept = 0) SET @AllKept = 0;
        IF (@Res <> 1 OR @N <> @N2 OR CAST(@Ids AS VARBINARY(MAX)) <> CAST(@Ids2 AS VARBINARY(MAX)))
        BEGIN
            SET @Differ = @Differ + 1;
            IF (@First = '')
                SET @First = ' first: meetings ' + CAST(@Fm AS VARCHAR(12)) + '-' + CAST(@Tm AS VARCHAR(12)) + ' dept ' + CAST(@Dp AS VARCHAR(12))
                           + ' subjects ' + ISNULL(CAST(@SF AS VARCHAR(12)), '-') + ' rows ' + CAST(@N AS VARCHAR(12)) + '/' + CAST(@N2 AS VARCHAR(12));
        END
        FETCH NEXT FROM DCursor INTO @Fm, @Tm, @Dp, @SF, @ST;
    END
    CLOSE DCursor;
    DEALLOCATE DCursor;
    INSERT INTO @T SELECT 'Parity, Followup by Department: against spr_GetActionItemByMeetingIdDeptId with the committee and subject range the page applied before; 1 and 2 meetings, every department, A, B, with and without subjects ('
                        + CAST(@Compared AS VARCHAR(12)) + ' rows compared): combinations, combinations that differ, old order kept SubjectNo',
           '12, 0, 1', CAST(@Combos AS VARCHAR(12)) + ', ' + CAST(@Differ AS VARCHAR(12)) + ', ' + CAST(@AllKept AS VARCHAR(2)) + @First;
    EXEC #D49 @a = @Ctl, @c = @Com, @f = 94901, @t = 94901, @d = @DeptA, @sf = 9402, @st = 9407, @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @R = @Res OUTPUT, @Rs = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Followup by Department, subject range 9402 to 9407, department A, meeting 94901: items 2 to 7 (whole numbers, both ends kept)', '6',
           CAST(@N AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The one list of blank characters (RA-3): each alone, and all together, refused; nothing written
    ---------------------------------------------------------------------------
    SET @HistCount = (SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I2);
    SET @Refused = 0; SET @Codes = 0; SET @All = N'';
    SELECT @Code = MIN(Code) FROM @Blank;
    WHILE (@Code IS NOT NULL)
    BEGIN
        SET @Res = NULL; SET @Rsn = NULL;
        SET @One = NCHAR(@Code);
        EXEC spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I2, @ReopenReason = @One, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
        SET @Codes = @Codes + 1;
        IF (@Res = 0 AND @Rsn = 4) SET @Refused = @Refused + 1;
        SET @All = @All + NCHAR(@Code) + NCHAR(@Code);
        SELECT @Code = MIN(Code) FROM @Blank WHERE Code > @Code;
    END
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I2, @ReopenReason = @All, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'spr_ReopenFollowup: each of the characters of the one list alone, and all of them twice in one reason: refused (Reason 4), the item still confirmed, no history row written',
           '27 of 27, all: 0 4, confirmed 1, history rows ' + CAST(@HistCount AS VARCHAR(12)),
           CAST(@Refused AS VARCHAR(12)) + ' of ' + CAST(@Codes AS VARCHAR(12)) + ', all: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-')
         + ', confirmed ' + CAST((SELECT IsConfirmed FROM Action_Item WHERE ActionItemId = @I2) AS VARCHAR(2))
         + ', history rows ' + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I2) AS VARCHAR(12));
    INSERT INTO @T SELECT 'The list of the test is the list of the procedure text: every code of the test appears as (n) in spr_ReopenFollowup, 27 codes', '27, 27',
           CAST((SELECT COUNT(*) FROM @Blank) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM @Blank b WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')) LIKE '%(' + CAST(b.Code AS VARCHAR(12)) + ')%') AS VARCHAR(12));

    -- A character not in the list (U+200C, zero-width non-joiner) alone, and a reason with a zero-width space inside: saved
    SET @Res = NULL; SET @Rsn = NULL;
    SET @One = NCHAR(8204);
    EXEC spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I2, @ReopenReason = @One, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = 'U+200C: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    SET @One = N'  ZZ49 inner' + NCHAR(8203) + N'space  ';
    EXEC spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I3, @ReopenReason = @One, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', inner: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', stored as trimmed: '
             + CASE WHEN (SELECT TOP 1 Reason FROM Action_Item_Status_History WHERE ActionItemId = @I3 ORDER BY StatusHistoryId DESC)
                         = N'ZZ49 inner' + NCHAR(8203) + N'space' COLLATE Latin1_General_BIN2 THEN 'yes' ELSE 'no' END;
    INSERT INTO @T SELECT 'spr_ReopenFollowup: a character not in the list (U+200C) alone, and a reason with a zero-width space inside (spaces at both ends): reopened; what is stored is trimmed as before',
           'U+200C: 1 0, inner: 1 0, stored as trimmed: yes', @Txt;
END TRY
BEGIN CATCH
    SET @Txt = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error', @Txt);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @ItemAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;
SELECT @HistAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(StatusHistoryId, ActionItemId, [Action], ActedBy, ActedOn)), 0) AS VARCHAR(12)) FROM Action_Item_Status_History;
INSERT INTO @T SELECT 'After the rollback: Action_Item unchanged (count, checksum)', @ItemBefore, @ItemAfter;
INSERT INTO @T SELECT 'After the rollback: ActionItem_User_Map unchanged (count, checksum)', @MapBefore, @MapAfter;
INSERT INTO @T SELECT 'After the rollback: Action_Item_Status_History unchanged (count, checksum)', @HistBefore, @HistAfter;
INSERT INTO @T SELECT 'After the rollback: step 49 is installed (markers in the five objects)', '5',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_FollowupStatusLatest'), ('spr_GetFollowupReport'), ('spr_GetFollowupByDepartmentReport'),
                                          ('spr_GetFollowupList'), ('spr_ReopenFollowup')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupReports-Step49%') AS VARCHAR(12));

Report:

INSERT INTO #T (Test, Expected, Actual) SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;
GO

-- Put every identity counter back (a rollback does not reliably), as BMMS-Test-ResetDatabase.sql does
DECLARE @Sql NVARCHAR(MAX);
DECLARE @TableName SYSNAME;
DECLARE @SavedValue BIGINT;
DECLARE @SeedValue BIGINT;
DECLARE @IncrementValue BIGINT;

DECLARE IdentCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName, SavedValue, SeedValue, IncrementValue FROM #Ident;

OPEN IdentCursor;
FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;

WHILE (@@FETCH_STATUS = 0)
BEGIN
    IF (@SavedValue IS NOT NULL
        OR EXISTS (SELECT 1 FROM sys.identity_columns ic
                   WHERE ic.object_id = OBJECT_ID('dbo.' + QUOTENAME(@TableName)) AND ic.last_value IS NOT NULL))
    BEGIN
        SET @Sql = N'DBCC CHECKIDENT (''dbo.' + QUOTENAME(@TableName) + N''', RESEED, '
                 + CAST(ISNULL(@SavedValue, @SeedValue - @IncrementValue) AS NVARCHAR(20)) + N') WITH NO_INFOMSGS';
        EXEC sp_executesql @Sql;
    END

    FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;
END

CLOSE IdentCursor;
DEALLOCATE IdentCursor;

INSERT INTO #T
SELECT 'After the test: used identity counters that changed', '0', CAST(COUNT(*) AS VARCHAR(12))
FROM #Ident i
WHERE i.SavedValue IS NOT NULL
AND CAST(IDENT_CURRENT('dbo.' + QUOTENAME(i.TableName)) AS BIGINT) <> i.SavedValue;

INSERT INTO #T
SELECT 'After the test: no ZZ49 department, user, committee, meeting, action item or history row left', '0 0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ49%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE EmailId LIKE 'zz49%@example.invalid') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z49') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ49 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ49') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Action_Item_Status_History h WHERE NOT EXISTS (SELECT 1 FROM Action_Item a WHERE a.ActionItemId = h.ActionItemId)) AS VARCHAR(12));

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM #T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND (Actual <> Expected OR Actual IS NULL) THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM #T;

DROP PROCEDURE #R49;
DROP PROCEDURE #D49;
DROP PROCEDURE #L49;
DROP PROCEDURE #M41;
DROP PROCEDURE #OD49;
DROP PROCEDURE #ZZ49Old;
DROP TABLE #FL;
DROP TABLE #OD;
DROP TABLE #O41;
DROP TABLE #ND;
DROP TABLE #NR;
DROP TABLE #Cols;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
