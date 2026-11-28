/* ============================================================================
   BMMS - Test of step 54 (step UD1c, lists for Managers with several
   departments)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY in a test copy whose name starts with "BMMS" and is not "BMMS"
   (BMMS_Test). It has no USE line: select BMMS_Test in SSMS first. Needs step
   54 installed. Written for compatibility level 100. The file is plain ASCII.
   Run the whole file (F5); it can run twice in one window.

   Part 1 reads only: the marker ManagerScope-Step54 in the ten objects, the
   markers of the earlier steps in the three replaced texts, the parameter
   counts, no feature above compatibility level 100, spr_GetMgrControllerByDeptId
   kept as it was, and for every active Manager in the database the Dashboard's
   departments (fn_UserDepartmentScope, step 42) equal to fn_ManagerDepartments
   (owner answer 7: the Dashboard is not changed).

   Part 2 runs in ONE transaction that is ROLLED BACK, with made-up data ZZ54:
   departments A, B, C and I (I made inactive after it was mapped); Managers
   M2 (home A, also B and I), MA (A), MB (B), MC (C); Users UA (A, Reporting
   Person MA) and UB (B, Reporting Person MB); a Controller and an inactive
   Controller; an Admin; a committee with a meeting to come (items of every
   department, one of C entered by M2) and a meeting whose minutes are
   finalised (one approved item with its minute per department). Checked:
     R1  fn_ManagerDepartments and spr_GetManagerDepartments (home first, the
         inactive department marked), refusals for another role and an
         unknown user
     R2  the Agenda Entry list for "All my departments", one department, a
         department not his (own items only), a one-department Manager and a
         User; a Manager's Update of a colleague's item of his second
         department (department, status and creator unchanged, also when
         another department is posted), of his own item of another department,
         and of an item of a department not his (Reason 30, nothing changed)
     R3  a Manager's new item in his second department (saved, AMA), in a
         department not his and in his inactive department (Reason 30, no
         item), by a User through the Manager's procedure (Reason 30)
     6   a new item of MB in B alerts M2 (a Manager of B whose home is A)
     R4  fn_ReportingPersonAllowed; Create and Update with a Manager of the
         department, a Manager of another department, a Controller, an
         inactive Controller, none (NULL and 0), himself, a department change;
         an unchanged Reporting Person that is not allowed (Reason 31, strict);
         spr_GetReportingPersonList with the "(not allowed now)" row, and its
         refusal for another role
     R5  spr_GetAgendaReport, spr_GetMinutesReportByUser and
         spr_GetReportSubjectNos for M2 (All, one department, a department not
         his: Reason 4), for the roles that are refused; and for the
         Controller, over every committee, department and meeting of the
         database, the same rows as the query the page built (agenda reports)
         and as spr_GetMinutesReport / spr_GetMinutesByMeetingId, in the order
         of the report
   Afterwards: Users, User_Role, User_Department, Agenda, Minutes and
   Alert_User_Map as before, no ZZ54 row left, every identity counter put
   back.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase = 'BMMS' OR @CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This test is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_ManagerDepartments', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%ManagerScope-Step54%')
BEGIN
    RAISERROR('Step 54 (BMMS-Fix-ManagerScope-Step54.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#VA') IS NOT NULL DROP TABLE #VA;
IF OBJECT_ID('tempdb..#VO') IS NOT NULL DROP TABLE #VO;
IF OBJECT_ID('tempdb..#VM') IS NOT NULL DROP TABLE #VM;
IF OBJECT_ID('tempdb..#VN') IS NOT NULL DROP TABLE #VN;
IF OBJECT_ID('tempdb..#VL') IS NOT NULL DROP TABLE #VL;
IF OBJECT_ID('tempdb..#ZZ54_Save') IS NOT NULL DROP PROCEDURE #ZZ54_Save;
IF OBJECT_ID('tempdb..#ZZ54_Edit') IS NOT NULL DROP PROCEDURE #ZZ54_Edit;
IF OBJECT_ID('tempdb..#ZZ54_Item') IS NOT NULL DROP PROCEDURE #ZZ54_Item;
IF OBJECT_ID('tempdb..#ZZ54_List') IS NOT NULL DROP PROCEDURE #ZZ54_List;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(400), Expected VARCHAR(400), Actual VARCHAR(400));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- The shapes of the report rows: every column of the view, then Seq (the order the procedure returned them in).
-- The join keeps SELECT INTO from copying the IDENTITY property of the key column.
SELECT TOP 0 v.* INTO #VA FROM View_Agenda v LEFT JOIN Users nobody ON 1 = 0;
ALTER TABLE #VA ADD Seq INT IDENTITY(1,1);
SELECT TOP 0 v.* INTO #VO FROM View_Agenda v LEFT JOIN Users nobody ON 1 = 0;
SELECT TOP 0 v.* INTO #VM FROM View_Minute v LEFT JOIN Users nobody ON 1 = 0;
ALTER TABLE #VM ADD Seq INT IDENTITY(1,1);
SELECT TOP 0 v.* INTO #VN FROM View_Minute v LEFT JOIN Users nobody ON 1 = 0;
SELECT TOP 0 v.*, CAST(NULL AS VARCHAR(80)) AS EnteredByName INTO #VL FROM View_Agenda v LEFT JOIN Users nobody ON 1 = 0;

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-- Add a user through spr_AddEditUser
CREATE PROCEDURE #ZZ54_Save
    @UserName VARCHAR(50), @LoginName VARCHAR(50), @RoleId INT, @DepartmentId INT, @ManagerId INT, @List VARCHAR(MAX), @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);

    EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @Desig, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @LoginName,
         @LoginName = @LoginName, @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
END
GO

-- Edit a user through spr_AddEditUser: the stored values, with the home department and the Reporting Person given
CREATE PROCEDURE #ZZ54_Edit
    @UserId INT, @DepartmentId INT, @ManagerId INT, @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @UserName VARCHAR(50), @DesignationId INT, @RoleId INT, @Mail VARCHAR(50), @LoginName VARCHAR(50);

    SELECT @UserName = UserName, @DesignationId = DesignationId, @RoleId = RoleId, @Mail = EmailId, @LoginName = LoginName
    FROM Users WHERE UserId = @UserId;

    EXEC spr_AddEditUser @Code = 'Update', @UserId = @UserId, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @Mail,
         @LoginName = @LoginName, @Password = '', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor;
END
GO

-- Save or Update an item through spr_AddEditAgendaByManager, as Agenda Entry calls it for a Manager
CREATE PROCEDURE #ZZ54_Item
    @Code VARCHAR(10), @AgendaId INT, @Actor INT, @DepartmentId INT, @CommitteeId INT, @MeetingId INT, @ShortText NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @E NVARCHAR(10) = N'';
    DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);

    EXEC spr_AddEditAgendaByManager @Code = @Code, @AgendaId = @AgendaId, @AgendaNo = '', @CommitteeId = @CommitteeId,
         @MeetingId = @MeetingId, @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = @ShortText,
         @AgendaType = 'Entry', @AgendaText = N'ZZ', @AgendaTextPath = @E, @ProposedResolution = N'ZZ', @FilePath = @E,
         @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor, @SubjectNo = NULL, @ActingUserId = @Actor;
END
GO

-- The Agenda Entry list of a user for a meeting, as the last three characters of the Agenda Nos, sorted
CREATE PROCEDURE #ZZ54_List
    @MeetingId INT, @UserId INT, @DepartmentId INT, @Text VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM #VL;
    INSERT INTO #VL EXEC dbo.spr_GetAgendaByMeetingIdDeptId @MeetingId = @MeetingId, @UserId = @UserId, @DepartmentId = @DepartmentId;
    SET @Text = ISNULL(STUFF((SELECT ' ' + RIGHT(AgendaNo, 3) FROM #VL ORDER BY AgendaNo FOR XML PATH('')), 1, 1, ''), '-');
END
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T
SELECT 'The 10 objects of step 54 carry ManagerScope-Step54', '10',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_ManagerDepartments'), ('fn_ReportingPersonAllowed'), ('spr_GetManagerDepartments'),
                                          ('spr_GetReportingPersonList'), ('spr_GetAgendaReport'), ('spr_GetMinutesReportByUser'),
                                          ('spr_GetReportSubjectNos'), ('spr_GetAgendaByMeetingIdDeptId'), ('spr_AddEditAgendaByManager'),
                                          ('spr_AddEditUser')) o(n)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%ManagerScope-Step54%') AS VARCHAR(4));

INSERT INTO #T
SELECT 'The 3 replaced texts keep the markers of their earlier steps (33; 37 and 53; 52 and 53)', '5',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_GetAgendaByMeetingIdDeptId', 'ManagerDepartment-Step33'),
                                          ('spr_AddEditAgendaByManager', 'UpdateMail-Step37'), ('spr_AddEditAgendaByManager', 'DepartmentApprovers-Step53'),
                                          ('spr_AddEditUser', 'ManagerRelease-Step52'), ('spr_AddEditUser', 'DepartmentApprovers-Step53')) o(n, mk)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%' + o.mk + '%') AS VARCHAR(4));

INSERT INTO #T
SELECT 'Parameters: fn_ManagerDepartments 1, fn_ReportingPersonAllowed 2, spr_GetManagerDepartments 3, spr_GetReportingPersonList 6, spr_GetAgendaReport 13, spr_GetMinutesReportByUser 12, spr_GetReportSubjectNos 5, spr_GetAgendaByMeetingIdDeptId 3, spr_AddEditAgendaByManager 23, spr_AddEditUser 17',
       '1 2 3 6 13 12 5 3 23 17',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_ManagerDepartments') AND parameter_id > 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_ReportingPersonAllowed') AND parameter_id > 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetManagerDepartments')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetReportingPersonList')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetAgendaReport')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetMinutesReportByUser')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetReportSubjectNos')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetAgendaByMeetingIdDeptId')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgendaByManager')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditUser')) AS VARCHAR(4));

INSERT INTO #T
SELECT 'No feature above compatibility level 100 in the 10 texts (TRY_CONVERT, IIF, CONCAT, FORMAT, OFFSET, STRING_AGG)', '0',
       CAST((SELECT COUNT(*)
             FROM (VALUES ('fn_ManagerDepartments'), ('fn_ReportingPersonAllowed'), ('spr_GetManagerDepartments'),
                          ('spr_GetReportingPersonList'), ('spr_GetAgendaReport'), ('spr_GetMinutesReportByUser'),
                          ('spr_GetReportSubjectNos'), ('spr_GetAgendaByMeetingIdDeptId'), ('spr_AddEditAgendaByManager'),
                          ('spr_AddEditUser')) o(n)
             CROSS JOIN (VALUES ('%TRY_CONVERT%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('% OFFSET %'), ('%STRING_AGG%')) w(Pattern)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE w.Pattern) AS VARCHAR(4));

INSERT INTO #T
SELECT 'Kept unchanged: spr_GetMgrControllerByDeptId (step 14, no longer called), spr_GetMinutesReport (step 22), spr_GetMinutesByMeetingId, fn_UserDepartmentScope (step 42): none carries ManagerScope-Step54',
       '4 0',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_GetMgrControllerByDeptId'), ('spr_GetMinutesReport'), ('spr_GetMinutesByMeetingId'), ('fn_UserDepartmentScope')) o(n)
             WHERE OBJECT_ID('dbo.' + o.n) IS NOT NULL) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM (VALUES ('spr_GetMgrControllerByDeptId'), ('spr_GetMinutesReport'), ('spr_GetMinutesByMeetingId'), ('fn_UserDepartmentScope')) o(n)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%ManagerScope-Step54%') AS VARCHAR(4));

-- Owner answer 7: the Dashboard reads fn_UserDepartmentScope; for every active Manager it must equal R1 today
INSERT INTO #T
SELECT 'R6: every active Manager of the database (' + CAST((SELECT COUNT(*) FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                                                            WHERE r.RoleCode = 'manager' AND u.AccountStatus = 1 AND u.IsSystem = 0) AS VARCHAR(12))
       + '): the Dashboard''s departments (fn_UserDepartmentScope today) are those of fn_ManagerDepartments; departments that differ',
       '0',
       CAST((SELECT COUNT(*)
             FROM Users u
             JOIN Roles r ON r.RoleId = u.RoleId
             CROSS APPLY (SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(u.UserId, CAST(GETDATE() AS DATE)) s
                          WHERE NOT EXISTS (SELECT 1 FROM dbo.fn_ManagerDepartments(u.UserId) md WHERE md.DepartmentId = s.DepartmentId)
                          UNION ALL
                          SELECT md.DepartmentId FROM dbo.fn_ManagerDepartments(u.UserId) md
                          WHERE NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(u.UserId, CAST(GETDATE() AS DATE)) s WHERE s.DepartmentId = md.DepartmentId)) x
             WHERE r.RoleCode = 'manager' AND u.AccountStatus = 1 AND u.IsSystem = 0) AS VARCHAR(12));
GO

-------------------------------------------------------------------------------
-- Part 1b: the Controller's reports against the queries they replace, over every committee, department and meeting
-------------------------------------------------------------------------------
DECLARE @Ctl INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                    WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0 ORDER BY u.UserId);
DECLARE @ColsA NVARCHAR(MAX) = STUFF((SELECT ', ' + QUOTENAME(name) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.View_Agenda') ORDER BY column_id FOR XML PATH('')), 1, 2, '');
DECLARE @ColsM NVARCHAR(MAX) = STUFF((SELECT ', ' + QUOTENAME(name) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.View_Minute') ORDER BY column_id FOR XML PATH('')), 1, 2, '');
DECLARE @SqlA NVARCHAR(MAX) = N'INSERT INTO #VA (' + @ColsA + N') EXEC dbo.spr_GetAgendaReport @ActingUserId = @a, @CommitteeId = @c, @DepartmentId = @d, @MeetingNoSearch = @ms, @MeetingId = @m, @FromMeetingId = @f, @ToMeetingId = @t, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @OrderBy = @o';
DECLARE @SqlM NVARCHAR(MAX) = N'INSERT INTO #VM (' + @ColsM + N') EXEC dbo.spr_GetMinutesReportByUser @ActingUserId = @a, @CommitteeId = @c, @DepartmentId = @d, @MeetingNoSearch = @ms, @MeetingId = @m, @FromMeetingId = @f, @ToMeetingId = @t, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0';
DECLARE @SqlS NVARCHAR(MAX) = N'INSERT INTO #VM (' + @ColsM + N') EXEC dbo.spr_GetReportSubjectNos @ActingUserId = @a, @MeetingId = @m, @DepartmentId = @d';
DECLARE @Cases TABLE (c INT, d INT, ms INT, m INT, f INT, t INT, o INT);
DECLARE @c INT, @d INT, @ms INT, @m INT, @f INT, @tt INT, @o INT;
DECLARE @CasesA INT = 0, @DiffA INT = 0, @OrderA INT = 0, @RowsA INT = 0;
DECLARE @CasesM INT = 0, @DiffM INT = 0, @OrderM INT = 0, @RowsM INT = 0;
DECLARE @CasesS INT = 0, @DiffS INT = 0, @OrderS INT = 0, @RowsS INT = 0;

IF (@Ctl IS NULL)
    INSERT INTO #T VALUES ('The Controller''s reports against the queries they replace', 'PASS', 'SKIPPED');
ELSE
BEGIN
    -- Agenda reports: every committee with an approved item; every department of its items and - All -; every
    -- meeting of the committee, all meetings, and the range of all its meetings; both orders
    INSERT INTO @Cases (c, d, ms, m, f, t, o)
    SELECT x.CommitteeId, dd.d, mm.ms, mm.m, mm.f, mm.t, oo.o
    FROM (SELECT DISTINCT CommitteeId FROM Agenda WHERE AgendaStatusCode = 'ACA') x
    CROSS APPLY (SELECT -1 AS d UNION SELECT DISTINCT a.DepartmentId FROM Agenda a WHERE a.CommitteeId = x.CommitteeId AND a.DepartmentId IS NOT NULL) dd
    CROSS APPLY (SELECT 0 AS ms, 0 AS m, 0 AS f, 0 AS t
                 UNION ALL SELECT 0, mt.MeetingId, 0, 0 FROM Meeting mt WHERE mt.CommitteeId = x.CommitteeId
                 UNION ALL SELECT 1, 0, MIN(mt.MeetingId), MAX(mt.MeetingId) FROM Meeting mt WHERE mt.CommitteeId = x.CommitteeId) mm
    CROSS APPLY (SELECT 1 AS o UNION ALL SELECT 2) oo;

    DECLARE CaseCursor CURSOR LOCAL FAST_FORWARD FOR SELECT c, d, ms, m, f, t, o FROM @Cases;
    OPEN CaseCursor;
    FETCH NEXT FROM CaseCursor INTO @c, @d, @ms, @m, @f, @tt, @o;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        TRUNCATE TABLE #VA;
        DELETE FROM #VO;
        EXEC sp_executesql @SqlA, N'@a INT, @c INT, @d INT, @ms INT, @m INT, @f INT, @t INT, @o INT',
             @a = @Ctl, @c = @c, @d = @d, @ms = @ms, @m = @m, @f = @f, @t = @tt, @o = @o;
        -- The query the page built before (ReportsMgr, as SQL text)
        INSERT INTO #VO
        SELECT v.* FROM View_Agenda v
        WHERE v.AgendaStatusCode = 'ACA' AND v.CommitteeId = @c
        AND (@d <= 0 OR v.DepartmentId = @d)
        AND (@ms <> 0 OR @m <= 0 OR v.MeetingId = @m)
        AND (@ms <> 1 OR v.MeetingId BETWEEN @f AND @tt);

        SET @CasesA = @CasesA + 1;
        SET @RowsA = @RowsA + (SELECT COUNT(*) FROM #VO);
        SET @DiffA = @DiffA + (SELECT COUNT(*) FROM #VA a WHERE NOT EXISTS (SELECT 1 FROM #VO b WHERE b.AgendaId = a.AgendaId))
                            + (SELECT COUNT(*) FROM #VO b WHERE NOT EXISTS (SELECT 1 FROM #VA a WHERE a.AgendaId = b.AgendaId))
                            + (SELECT COUNT(*) FROM #VA a WHERE (SELECT COUNT(*) FROM #VA a2 WHERE a2.AgendaId = a.AgendaId) > 1);
        -- The order of the report: committee (or department), meeting, subject number
        SET @OrderA = @OrderA + (SELECT COUNT(*) FROM #VA a JOIN #VA p ON p.Seq = a.Seq - 1
                                 WHERE (CASE WHEN @o = 2 THEN ISNULL(p.DepartmentId, -2147483647) ELSE p.CommitteeId END
                                        > CASE WHEN @o = 2 THEN ISNULL(a.DepartmentId, -2147483647) ELSE a.CommitteeId END)
                                    OR ((CASE WHEN @o = 2 THEN ISNULL(p.DepartmentId, -2147483647) ELSE p.CommitteeId END
                                         = CASE WHEN @o = 2 THEN ISNULL(a.DepartmentId, -2147483647) ELSE a.CommitteeId END)
                                        AND (p.MeetingId > a.MeetingId
                                             OR (p.MeetingId = a.MeetingId AND ISNULL(p.SubjectNo, -2147483647) > ISNULL(a.SubjectNo, -2147483647)))));
        FETCH NEXT FROM CaseCursor INTO @c, @d, @ms, @m, @f, @tt, @o;
    END
    CLOSE CaseCursor;
    DEALLOCATE CaseCursor;

    INSERT INTO #T
    SELECT 'R5 Controller, Agenda Summary / Details: spr_GetAgendaReport gives the rows of the query the page built, in the report''s order ('
           + CAST(@CasesA AS VARCHAR(12)) + ' cases, ' + CAST(@RowsA AS VARCHAR(12)) + ' rows); rows that differ, rows out of order',
           '0 0', CAST(@DiffA AS VARCHAR(12)) + ' ' + CAST(@OrderA AS VARCHAR(12));

    -- Minutes reports: every committee with a minutes row; every department of its items and - All -; every meeting, all meetings, the range
    DELETE FROM @Cases;
    INSERT INTO @Cases (c, d, ms, m, f, t, o)
    SELECT x.CommitteeId, dd.d, mm.ms, mm.m, mm.f, mm.t, 1
    FROM (SELECT DISTINCT CommitteeId FROM View_Minute) x
    CROSS APPLY (SELECT -1 AS d UNION SELECT DISTINCT v.DepartmentId FROM View_Minute v WHERE v.CommitteeId = x.CommitteeId AND v.DepartmentId IS NOT NULL) dd
    CROSS APPLY (SELECT 0 AS ms, 0 AS m, 0 AS f, 0 AS t
                 UNION ALL SELECT DISTINCT 0, v.MeetingId, 0, 0 FROM View_Minute v WHERE v.CommitteeId = x.CommitteeId
                 UNION ALL SELECT 1, 0, MIN(mt.MeetingId), MAX(mt.MeetingId) FROM Meeting mt WHERE mt.CommitteeId = x.CommitteeId) mm;

    DECLARE CaseCursor CURSOR LOCAL FAST_FORWARD FOR SELECT c, d, ms, m, f, t FROM @Cases;
    OPEN CaseCursor;
    FETCH NEXT FROM CaseCursor INTO @c, @d, @ms, @m, @f, @tt;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        TRUNCATE TABLE #VM;
        DELETE FROM #VN;
        EXEC sp_executesql @SqlM, N'@a INT, @c INT, @d INT, @ms INT, @m INT, @f INT, @t INT',
             @a = @Ctl, @c = @c, @d = @d, @ms = @ms, @m = @m, @f = @f, @t = @tt;
        INSERT INTO #VN EXEC dbo.spr_GetMinutesReport @CommitteeId = @c, @DepartmentId = @d, @MeetingNoSearch = @ms, @MeetingId = @m,
             @FromMeetingId = @f, @ToMeetingId = @tt, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;

        SET @CasesM = @CasesM + 1;
        SET @RowsM = @RowsM + (SELECT COUNT(*) FROM #VN);
        SET @DiffM = @DiffM + (SELECT COUNT(*) FROM #VM a WHERE NOT EXISTS (SELECT 1 FROM #VN b WHERE b.MinutesId = a.MinutesId))
                            + (SELECT COUNT(*) FROM #VN b WHERE NOT EXISTS (SELECT 1 FROM #VM a WHERE a.MinutesId = b.MinutesId))
                            + (SELECT COUNT(*) FROM #VM a WHERE (SELECT COUNT(*) FROM #VM a2 WHERE a2.MinutesId = a.MinutesId) > 1);
        SET @OrderM = @OrderM + (SELECT COUNT(*) FROM #VM a JOIN #VM p ON p.Seq = a.Seq - 1
                                 WHERE p.CommitteeId > a.CommitteeId
                                    OR (p.CommitteeId = a.CommitteeId AND (p.MeetingId > a.MeetingId
                                        OR (p.MeetingId = a.MeetingId AND ISNULL(p.SubjectNo, -2147483647) > ISNULL(a.SubjectNo, -2147483647)))));
        FETCH NEXT FROM CaseCursor INTO @c, @d, @ms, @m, @f, @tt;
    END
    CLOSE CaseCursor;
    DEALLOCATE CaseCursor;

    INSERT INTO #T
    SELECT 'R5 Controller, Minutes / Minutes Extract: spr_GetMinutesReportByUser gives the rows of spr_GetMinutesReport, in its order ('
           + CAST(@CasesM AS VARCHAR(12)) + ' cases, ' + CAST(@RowsM AS VARCHAR(12)) + ' rows); rows that differ, rows out of order',
           '0 0', CAST(@DiffM AS VARCHAR(12)) + ' ' + CAST(@OrderM AS VARCHAR(12));

    -- Subject number lists: every meeting with a minutes row; - All - (-1) and every department of its items
    DELETE FROM @Cases;
    INSERT INTO @Cases (c, d, ms, m, f, t, o)
    SELECT 0, dd.d, 0, x.MeetingId, 0, 0, 1
    FROM (SELECT DISTINCT MeetingId FROM View_Minute) x
    CROSS APPLY (SELECT -1 AS d UNION SELECT DISTINCT v.DepartmentId FROM View_Minute v WHERE v.MeetingId = x.MeetingId AND v.DepartmentId IS NOT NULL) dd;

    DECLARE CaseCursor CURSOR LOCAL FAST_FORWARD FOR SELECT d, m FROM @Cases;
    OPEN CaseCursor;
    FETCH NEXT FROM CaseCursor INTO @d, @m;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        TRUNCATE TABLE #VM;
        DELETE FROM #VN;
        EXEC sp_executesql @SqlS, N'@a INT, @m INT, @d INT', @a = @Ctl, @m = @m, @d = @d;
        INSERT INTO #VN EXEC dbo.spr_GetMinutesByMeetingId @MeetingId = @m, @StatusId = 1, @DepartmentId = @d;

        SET @CasesS = @CasesS + 1;
        SET @RowsS = @RowsS + (SELECT COUNT(*) FROM #VN);
        SET @DiffS = @DiffS + (SELECT COUNT(*) FROM #VM a WHERE NOT EXISTS (SELECT 1 FROM #VN b WHERE b.MinutesId = a.MinutesId))
                            + (SELECT COUNT(*) FROM #VN b WHERE NOT EXISTS (SELECT 1 FROM #VM a WHERE a.MinutesId = b.MinutesId))
                            + (SELECT COUNT(*) FROM #VM a WHERE (SELECT COUNT(*) FROM #VM a2 WHERE a2.MinutesId = a.MinutesId) > 1);
        SET @OrderS = @OrderS + (SELECT COUNT(*) FROM #VM a JOIN #VM p ON p.Seq = a.Seq - 1
                                 WHERE ISNULL(p.SubjectNo, -2147483647) > ISNULL(a.SubjectNo, -2147483647));
        FETCH NEXT FROM CaseCursor INTO @d, @m;
    END
    CLOSE CaseCursor;
    DEALLOCATE CaseCursor;

    INSERT INTO #T
    SELECT 'R5 Controller, subject number lists: spr_GetReportSubjectNos gives the rows of spr_GetMinutesByMeetingId (status 1), by subject number ('
           + CAST(@CasesS AS VARCHAR(12)) + ' cases, ' + CAST(@RowsS AS VARCHAR(12)) + ' rows); rows that differ, rows out of order',
           '0 0', CAST(@DiffS AS VARCHAR(12)) + ' ' + CAST(@OrderS AS VARCHAR(12));
END
GO

-------------------------------------------------------------------------------
-- Part 2: the cases, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))));
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(400), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @MD TABLE (DepartmentId INT, DepartmentName VARCHAR(200), IsHome BIT, IsActive BIT);
DECLARE @RP TABLE (UserId INT, UserName VARCHAR(100), LoginName VARCHAR(100), AccountStatus INT, RoleCode VARCHAR(50), Allowed BIT);

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = CAST(CAST(GETDATE() AS DATE) AS DATETIME);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DecisionTypeId INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type ORDER BY DecisionTypeId);
DECLARE @Adm INT, @Ctl INT, @Ctl0 INT, @Mg INT, @M2 INT, @MA INT, @MB INT, @MC INT, @UA INT, @UB INT;
DECLARE @DA INT, @DB INT, @DC INT, @DI INT, @Com INT, @MFut INT, @MFin INT;
DECLARE @iA1 INT, @iA2 INT, @iB1 INT, @iC1 INT, @iI1 INT, @iOwnC INT, @fA INT, @fB INT, @fC INT, @fI INT, @iNew INT;
DECLARE @n INT, @n2 INT, @Res INT, @Rsn INT, @S VARCHAR(400), @S2 VARCHAR(400), @L VARCHAR(MAX);
DECLARE @UsersBefore VARCHAR(60), @UsersAfter VARCHAR(60), @HistBefore VARCHAR(100), @HistAfter VARCHAR(100);
DECLARE @AgendaBefore VARCHAR(60), @AgendaAfter VARCHAR(60), @MapBefore VARCHAR(60), @MapAfter VARCHAR(60);
DECLARE @MinBefore VARCHAR(60), @MinAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @Desig IS NULL
    OR @SubjectTypeId IS NULL OR @DecisionTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role (admin, controller, manager, user, mgmt), a designation, a subject type or a decision type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

-- Rows outside the test, before
SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @HistBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistBefore = @HistBefore + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, DepartmentId, CreatedBy, ShortText)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, UserId, ReadStatus, StatusId, HandledReason, HandledBy)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
SELECT @MinBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, AgendaId, StatusId)), 0) AS VARCHAR(12)) FROM Minutes;

BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ54A', 'ZZ step 54 department A', 994, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ54B', 'ZZ step 54 department B', 995, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ54C', 'ZZ step 54 department C', 996, 1, @Now, @Sys);
    SET @DC = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ54I', 'ZZ step 54 department I', 997, 1, @Now, @Sys);
    SET @DI = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ54 admin', @DA, @Desig, NULL, @rAdmin, 'zz54adm', 'zz54adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ54 controller', @DC, @Desig, NULL, @rCtl, 'zz54ctl', 'zz54ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ54 controller inactive', @DA, @Desig, NULL, @rCtl, 'zz54ctl0', 'zz54ctl0', 'not-a-login', 0, @Now);
    SET @Ctl0 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ54 management', @DA, @Desig, NULL, @rMgmt, 'zz54mg', 'zz54mg', 'not-a-login', 1, @Now);
    SET @Mg = SCOPE_IDENTITY();

    -- The Managers, saved through spr_AddEditUser: M2 of A (home), B and I; MA of A; MB of B; MC of C
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12)) + ',' + CAST(@DI AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 manager two', 'zz54m2', @rMgr, @DA, NULL, @L, @Adm;
    SET @M2 = (SELECT UserId FROM Users WHERE LoginName = 'zz54m2');
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 manager A', 'zz54ma', @rMgr, @DA, NULL, @L, @Adm;
    SET @MA = (SELECT UserId FROM Users WHERE LoginName = 'zz54ma');
    SET @L = CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 manager B', 'zz54mb', @rMgr, @DB, NULL, @L, @Adm;
    SET @MB = (SELECT UserId FROM Users WHERE LoginName = 'zz54mb');
    SET @L = CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 manager C', 'zz54mc', @rMgr, @DC, NULL, @L, @Adm;
    SET @MC = (SELECT UserId FROM Users WHERE LoginName = 'zz54mc');
    -- The Users, saved with an allowed Reporting Person
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 user A', 'zz54ua', @rUser, @DA, @MA, @L, @Adm;
    SET @UA = (SELECT UserId FROM Users WHERE LoginName = 'zz54ua');
    SET @L = CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 user B', 'zz54ub', @rUser, @DB, @MB, @L, @Adm;
    SET @UB = (SELECT UserId FROM Users WHERE LoginName = 'zz54ub');
    -- Department I is made inactive after it was mapped to M2
    UPDATE Department SET StatusId = 0 WHERE DepartmentId = @DI;

    INSERT INTO @T SELECT 'Made-up data: four Managers and two Users saved through spr_AddEditUser (the Users with an allowed Reporting Person)', '6',
           CAST((SELECT COUNT(*) FROM Users WHERE LoginName IN ('zz54m2', 'zz54ma', 'zz54mb', 'zz54mc', 'zz54ua', 'zz54ub')) AS VARCHAR(4));

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z54', 'ZZ step 54 committee', '2000-01-01', 1, 0);
    SET @Com = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('95401', @Com, 'ZZ54 test', 'ZZ', DATEADD(DAY, 10, @Day), '10:00', DATEADD(DAY, 5, @Day), 'Open', 'Open');
    SET @MFut = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('95402', @Com, 'ZZ54 test', 'ZZ', DATEADD(DAY, -20, @Day), '10:00', DATEADD(DAY, -25, @Day), 'F', 'F');
    SET @MFin = SCOPE_IDENTITY();

    -- The meeting to come: items of A (UA, at AC; MA, AMA), B (UB, AC), C (MC, AMA), I (MC, AMA) and one of C entered by M2
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z54-95401-001', @Com, @MFut, @DA, @SubjectTypeId, N'ZZ54 A by UA', 'Entry', N'ZZ', 'AC', 'New', @Now, @UA);
    SET @iA1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z54-95401-002', @Com, @MFut, @DA, @SubjectTypeId, N'ZZ54 A by MA', 'Entry', N'ZZ', 'AMA', 'New', @Now, @MA);
    SET @iA2 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z54-95401-003', @Com, @MFut, @DB, @SubjectTypeId, N'ZZ54 B by UB', 'Entry', N'ZZ', 'AC', 'New', @Now, @UB);
    SET @iB1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z54-95401-004', @Com, @MFut, @DC, @SubjectTypeId, N'ZZ54 C by MC', 'Entry', N'ZZ', 'AMA', 'New', @Now, @MC);
    SET @iC1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z54-95401-005', @Com, @MFut, @DI, @SubjectTypeId, N'ZZ54 I by MC', 'Entry', N'ZZ', 'AMA', 'New', @Now, @MC);
    SET @iI1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z54-95401-006', @Com, @MFut, @DC, @SubjectTypeId, N'ZZ54 C by M2', 'Entry', N'ZZ', 'AMA', 'New', @Now, @M2);
    SET @iOwnC = SCOPE_IDENTITY();

    -- The finalised meeting: one approved item with its minute per department (subject numbers 1 to 4)
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, SubjectNo)
    VALUES ('Z54-95402-001', @Com, @MFin, @DA, @SubjectTypeId, N'ZZ54 final A', 'Entry', N'ZZ', 'ACA', 'New', @Now, @UA, 1);
    SET @fA = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, SubjectNo)
    VALUES ('Z54-95402-002', @Com, @MFin, @DB, @SubjectTypeId, N'ZZ54 final B', 'Entry', N'ZZ', 'ACA', 'New', @Now, @UB, 2);
    SET @fB = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, SubjectNo)
    VALUES ('Z54-95402-003', @Com, @MFin, @DC, @SubjectTypeId, N'ZZ54 final C', 'Entry', N'ZZ', 'ACA', 'New', @Now, @MC, 3);
    SET @fC = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, SubjectNo)
    VALUES ('Z54-95402-004', @Com, @MFin, @DI, @SubjectTypeId, N'ZZ54 final I', 'Entry', N'ZZ', 'ACA', 'New', @Now, @MC, 4);
    SET @fI = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, ActualResolution, StatusId)
    SELECT a.AgendaId, @DecisionTypeId, N'ZZ54', 1 FROM Agenda a WHERE a.AgendaId IN (@fA, @fB, @fC, @fI);

    ---------------------------------------------------------------------------
    -- R1: a Manager's departments
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'R1 fn_ManagerDepartments: M2 / MA / MC / UA (a User) / the Controller / the Admin (department letters)', 'A B I | A | C | - | - | -',
           ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_ManagerDepartments(@M2) md JOIN Department d ON d.DepartmentId = md.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' | '
         + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_ManagerDepartments(@MA) md JOIN Department d ON d.DepartmentId = md.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' | '
         + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_ManagerDepartments(@MC) md JOIN Department d ON d.DepartmentId = md.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' | '
         + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_ManagerDepartments(@UA) md JOIN Department d ON d.DepartmentId = md.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' | '
         + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_ManagerDepartments(@Ctl) md JOIN Department d ON d.DepartmentId = md.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' | '
         + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_ManagerDepartments(@Adm) md JOIN Department d ON d.DepartmentId = md.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-');

    INSERT INTO @T SELECT 'R6 with the made-up data: the Dashboard''s departments of M2 (fn_UserDepartmentScope today) are those of R1', 'A B I',
           ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_UserDepartmentScope(@M2, CAST(GETDATE() AS DATE)) s JOIN Department d ON d.DepartmentId = s.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-');

    DELETE FROM @MD;
    INSERT INTO @MD EXEC dbo.spr_GetManagerDepartments @ActingUserId = @M2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = ISNULL((SELECT TOP 1 STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) + CASE WHEN m.IsHome = 1 THEN 'h' ELSE '' END + CASE WHEN m.IsActive = 1 THEN '' ELSE 'x' END
                                        FROM @MD m JOIN Department d ON d.DepartmentId = m.DepartmentId FOR XML PATH('')), 1, 1, '')), '-');
    INSERT INTO @T SELECT 'R1 spr_GetManagerDepartments for M2: home first (h), then by name; the inactive department marked (x); Result, Reason', 'Ah B Ix; 1 0',
           @S + '; ' + CAST(@Res AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));

    DELETE FROM @MD;
    INSERT INTO @MD EXEC dbo.spr_GetManagerDepartments @ActingUserId = @UA, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = CAST((SELECT COUNT(*) FROM @MD) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM @MD;
    INSERT INTO @MD EXEC dbo.spr_GetManagerDepartments @ActingUserId = -1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM @MD) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM @MD;
    INSERT INTO @MD EXEC dbo.spr_GetManagerDepartments @ActingUserId = @Sys, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM @MD) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    INSERT INTO @T SELECT 'R1 spr_GetManagerDepartments for a User (Reason 4), an unknown user id and the system account (Reason 8): rows, Reason', '0 4 | 0 8 | 0 8', @S;

    ---------------------------------------------------------------------------
    -- R2: the Agenda Entry list
    ---------------------------------------------------------------------------
    EXEC #ZZ54_List @MFut, @M2, 0, @S OUTPUT;
    EXEC #ZZ54_List @MFut, @M2, @DB, @S2 OUTPUT;
    INSERT INTO @T SELECT 'R2 list of M2, All my departments / B only: the items of A, B and I and his own item of C; not the item of C entered by MC', '001 002 003 005 006 | 003',
           @S + ' | ' + @S2;
    EXEC #ZZ54_List @MFut, @M2, @DC, @S OUTPUT;
    EXEC #ZZ54_List @MFut, @M2, @DI, @S2 OUTPUT;
    INSERT INTO @T SELECT 'R2 list of M2 for C (not his department: his own item only) / for I (inactive, still his)', '006 | 005', @S + ' | ' + @S2;
    EXEC #ZZ54_List @MFut, @MA, 0, @S OUTPUT;
    EXEC #ZZ54_List @MFut, @UA, 0, @S2 OUTPUT;
    INSERT INTO @T SELECT 'R2 list of MA (one department) / of UA (a User: the items he entered)', '001 002 | 001', @S + ' | ' + @S2;
    EXEC #ZZ54_List @MFut, @UA, @DB, @S OUTPUT;
    INSERT INTO @T SELECT 'R2 list of UA with department B posted: nothing (a department only narrows the list)', '-', @S;

    ---------------------------------------------------------------------------
    -- R2: a Manager's Update
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Update', @iB1, @M2, @DC, @Com, @MFut, N'ZZ54 B changed by M2';
    INSERT INTO @T SELECT 'R2 M2 updates UB''s item of B (his second department), department C posted: saved; department, status and creator unchanged', 'Result 1, Reason 0; ZZ54 B changed by M2 B AC zz54ub',
           ISNULL((SELECT Txt FROM @R), '-') + '; ' + ISNULL((SELECT CAST(a.ShortText AS VARCHAR(100)) + ' ' + RIGHT(d.DepartmentCode, 1) + ' ' + a.AgendaStatusCode + ' ' + u.LoginName
                                                      FROM Agenda a JOIN Department d ON d.DepartmentId = a.DepartmentId JOIN Users u ON u.UserId = a.CreatedBy WHERE a.AgendaId = @iB1), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Update', @iC1, @M2, @DC, @Com, @MFut, N'ZZ54 C changed by M2';
    INSERT INTO @T SELECT 'R2 M2 updates MC''s item of C (not his department): Reason 30, nothing changed', 'Result 0, Reason 30; ZZ54 C by MC',
           ISNULL((SELECT Txt FROM @R), '-') + '; ' + ISNULL((SELECT CAST(ShortText AS VARCHAR(100)) FROM Agenda WHERE AgendaId = @iC1), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Update', @iOwnC, @M2, @DC, @Com, @MFut, N'ZZ54 own C changed';
    INSERT INTO @T SELECT 'R2 M2 updates his own item of C: saved', 'Result 1, Reason 0; ZZ54 own C changed',
           ISNULL((SELECT Txt FROM @R), '-') + '; ' + ISNULL((SELECT CAST(ShortText AS VARCHAR(100)) FROM Agenda WHERE AgendaId = @iOwnC), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Update', @iB1, @MA, @DB, @Com, @MFut, N'ZZ54 B changed by MA';
    INSERT INTO @T SELECT 'R2 MA (a Manager of A only) updates the item of B: Reason 30, nothing changed', 'Result 0, Reason 30; ZZ54 B changed by M2',
           ISNULL((SELECT Txt FROM @R), '-') + '; ' + ISNULL((SELECT CAST(ShortText AS VARCHAR(100)) FROM Agenda WHERE AgendaId = @iB1), '-');

    ---------------------------------------------------------------------------
    -- R3: a Manager's new item; owner answer 6: the alert
    ---------------------------------------------------------------------------
    SET @n = (SELECT COUNT(*) FROM Agenda WHERE MeetingId = @MFut);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Save', 0, @M2, @DB, @Com, @MFut, N'ZZ54 new of M2 in B';
    INSERT INTO @T SELECT 'R3 M2 adds an item in B (his second department): saved, department B, AMA, entered by M2', 'Result 1, Reason 0; B AMA zz54m2',
           ISNULL((SELECT Txt FROM @R), '-') + '; ' + ISNULL((SELECT RIGHT(d.DepartmentCode, 1) + ' ' + a.AgendaStatusCode + ' ' + u.LoginName
                                                      FROM Agenda a JOIN Department d ON d.DepartmentId = a.DepartmentId JOIN Users u ON u.UserId = a.CreatedBy
                                                      WHERE a.MeetingId = @MFut AND a.ShortText = N'ZZ54 new of M2 in B'), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Save', 0, @M2, @DC, @Com, @MFut, N'ZZ54 new of M2 in C';
    SET @S = ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Save', 0, @M2, @DI, @Com, @MFut, N'ZZ54 new of M2 in I';
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Save', 0, @UA, @DA, @Com, @MFut, N'ZZ54 new of UA';
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    INSERT INTO @T SELECT 'R3 M2 in C (not his) / M2 in I (his, inactive) / UA (a User) through the Manager''s procedure: Reason 30; items added in all (1: the item in B)',
           'Result 0, Reason 30 | Result 0, Reason 30 | Result 0, Reason 30; 1',
           @S + '; ' + CAST((SELECT COUNT(*) FROM Agenda WHERE MeetingId = @MFut) - @n AS VARCHAR(4));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Item 'Save', 0, @MB, @DB, @Com, @MFut, N'ZZ54 new of MB in B';
    SET @iNew = (SELECT AgendaId FROM Agenda WHERE MeetingId = @MFut AND ShortText = N'ZZ54 new of MB in B');
    INSERT INTO @T SELECT 'Answer 6: MB''s new item in B alerts the made-up Controller, MB and UB (home B) and M2 (a Manager of B, home A); not MA, MC, UA or the Admin',
           'Result 1, Reason 0; zz54ctl zz54m2 zz54mb zz54ub',
           ISNULL((SELECT Txt FROM @R), '-') + '; '
         + ISNULL(STUFF((SELECT ' ' + u.LoginName FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN Users u ON u.UserId = m.UserId
                         WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @iNew AND u.LoginName LIKE 'zz54%' ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), '-');

    ---------------------------------------------------------------------------
    -- R4: the Reporting Person
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'R4 fn_ReportingPersonAllowed for a user of A (UA) / of B (UB) / for M2 himself (A): the made-up users allowed',
           'zz54ctl zz54m2 zz54ma | zz54ctl zz54m2 zz54mb | zz54ctl zz54ma',
           ISNULL(STUFF((SELECT ' ' + u.LoginName FROM dbo.fn_ReportingPersonAllowed(@DA, @UA) a JOIN Users u ON u.UserId = a.UserId WHERE u.LoginName LIKE 'zz54%' ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), '-') + ' | '
         + ISNULL(STUFF((SELECT ' ' + u.LoginName FROM dbo.fn_ReportingPersonAllowed(@DB, @UB) a JOIN Users u ON u.UserId = a.UserId WHERE u.LoginName LIKE 'zz54%' ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), '-') + ' | '
         + ISNULL(STUFF((SELECT ' ' + u.LoginName FROM dbo.fn_ReportingPersonAllowed(@DA, @M2) a JOIN Users u ON u.UserId = a.UserId WHERE u.LoginName LIKE 'zz54%' ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), '-');

    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 new one', 'zz54n1', @rUser, @DA, @MB, @L, @Adm;
    SET @S = ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 new two', 'zz54n2', @rUser, @DA, @Ctl0, @L, @Adm;
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 new three', 'zz54n3', @rUser, @DA, @Adm, @L, @Adm;
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    INSERT INTO @T SELECT 'R4 Create of a User of A with MB (Manager of B only) / an inactive Controller / the Admin as Reporting Person: Reason 31, no user',
           'Result 0, Reason 31 | Result 0, Reason 31 | Result 0, Reason 31; 0',
           @S + '; ' + CAST((SELECT COUNT(*) FROM Users WHERE LoginName IN ('zz54n1', 'zz54n2', 'zz54n3')) AS VARCHAR(4));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 new four', 'zz54n4', @rUser, @DA, @M2, @L, @Adm;
    SET @S = ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 new five', 'zz54n5', @rUser, @DA, @Ctl, @L, @Adm;
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Save 'ZZ54 new six', 'zz54n6', @rUser, @DA, NULL, @L, @Adm;
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    -- "- Select -" reaches the procedure as NULL (UserDB sends DBNull for 0)
    INSERT INTO @T SELECT 'R4 Create of a User of A with M2 (a Manager of A, home A) / the Controller (another department) / none (NULL, as the page sends - Select -): saved',
           'Result 1, Reason 0 | Result 1, Reason 0 | Result 1, Reason 0; 3',
           @S + '; ' + CAST((SELECT COUNT(*) FROM Users WHERE LoginName IN ('zz54n4', 'zz54n5', 'zz54n6')) AS VARCHAR(4));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Edit @UA, @DA, @MA, @Adm;
    SET @S = ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Edit @UA, @DA, @MB, @Adm;
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    INSERT INTO @T SELECT 'R4 Update of UA: Reporting Person MA unchanged (saved) / changed to MB (Reason 31; still MA)', 'Result 1, Reason 0 | Result 0, Reason 31; zz54ma',
           @S + '; ' + ISNULL((SELECT m.LoginName FROM Users u JOIN Users m ON m.UserId = u.ManagerId WHERE u.UserId = @UA), '-');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Edit @UA, @DB, @MA, @Adm;
    SET @S = ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Edit @UA, @DB, @MB, @Adm;
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    INSERT INTO @T SELECT 'R4 Update of UA to department B: with MA (Manager of A only) Reason 31 / with MB saved; then UA is of B and reports to MB',
           'Result 0, Reason 31 | Result 1, Reason 0; B zz54mb',
           @S + '; ' + ISNULL((SELECT RIGHT(d.DepartmentCode, 1) + ' ' + m.LoginName FROM Users u JOIN Department d ON d.DepartmentId = u.DepartmentId
                               JOIN Users m ON m.UserId = u.ManagerId WHERE u.UserId = @UA), '-');

    -- A Reporting Person that is no longer allowed (set directly, as a removed department would leave it): strict
    UPDATE Users SET ManagerId = @MA WHERE UserId = @UB;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Edit @UB, @DB, @MA, @Adm;
    SET @S = ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Edit @UB, @DB, NULL, @Adm;
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    INSERT INTO @T SELECT 'R4 Update of UB whose saved Reporting Person MA is not allowed, unchanged: Reason 31 (strict) / with none: saved, none',
           'Result 0, Reason 31 | Result 1, Reason 0; none',
           @S + '; ' + ISNULL((SELECT CAST(ManagerId AS VARCHAR(12)) FROM Users WHERE UserId = @UB), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Edit @M2, @DA, @M2, @Adm;
    SET @S = ISNULL((SELECT Txt FROM @R), '-');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ54_Edit @M2, @DA, @MA, @Adm;
    SET @S = @S + ' | ' + ISNULL((SELECT Txt FROM @R), '-');
    INSERT INTO @T SELECT 'Answer 9: M2 as his own Reporting Person: Reason 31 / MA (another Manager of A): saved', 'Result 0, Reason 31 | Result 1, Reason 0', @S;

    -- spr_GetReportingPersonList: UB of B, current Reporting Person MC (not allowed)
    UPDATE Users SET ManagerId = @MC WHERE UserId = @UB;
    DELETE FROM @RP;
    INSERT INTO @RP EXEC dbo.spr_GetReportingPersonList @ActingUserId = @Adm, @DepartmentId = @DB, @UserId = @UB, @CurrentManagerId = @MC,
         @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'R4 spr_GetReportingPersonList for UB (B), current MC: the allowed made-up users (1) and MC (0); Result, Reason; real Controllers listed too',
           'zz54ctl:1 zz54m2:1 zz54mb:1 zz54mc:0; 1 0; yes',
           ISNULL(STUFF((SELECT ' ' + LoginName + ':' + CAST(CAST(Allowed AS INT) AS VARCHAR(1)) FROM @RP WHERE LoginName LIKE 'zz54%' ORDER BY LoginName FOR XML PATH('')), 1, 1, ''), '-')
         + '; ' + CAST(@Res AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4)) + '; '
         + CASE WHEN (SELECT COUNT(*) FROM @RP WHERE RoleCode = 'controller' AND Allowed = 1)
                     = (SELECT COUNT(*) FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0)
                THEN 'yes' ELSE 'no' END;
    DELETE FROM @RP;
    INSERT INTO @RP EXEC dbo.spr_GetReportingPersonList @ActingUserId = @Adm, @DepartmentId = @DB, @UserId = @UB, @CurrentManagerId = @MB,
         @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = CAST((SELECT COUNT(*) FROM @RP WHERE Allowed = 0) AS VARCHAR(4)) + ' ' + CAST((SELECT COUNT(*) FROM @RP WHERE UserId = @MB) AS VARCHAR(4));
    DELETE FROM @RP;
    INSERT INTO @RP EXEC dbo.spr_GetReportingPersonList @ActingUserId = @Ctl, @DepartmentId = @DB, @UserId = @UB, @CurrentManagerId = @MB,
         @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM @RP) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    INSERT INTO @T SELECT 'R4 spr_GetReportingPersonList with an allowed current one (no row at 0, listed once) / for the Controller (Reason 4, no rows)', '0 1 | 0 4', @S;

    ---------------------------------------------------------------------------
    -- R5: the reports of a Manager
    ---------------------------------------------------------------------------
    DELETE FROM #VO;
    INSERT INTO #VO EXEC dbo.spr_GetAgendaReport @ActingUserId = @M2, @CommitteeId = @Com, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @OrderBy = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM #VO v JOIN Department d ON d.DepartmentId = v.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VO;
    INSERT INTO #VO EXEC dbo.spr_GetAgendaReport @ActingUserId = @M2, @CommitteeId = @Com, @DepartmentId = @DB, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @OrderBy = 2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM #VO v JOIN Department d ON d.DepartmentId = v.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VO;
    INSERT INTO #VO EXEC dbo.spr_GetAgendaReport @ActingUserId = @M2, @CommitteeId = @Com, @DepartmentId = @DC, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @OrderBy = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM #VO) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    INSERT INTO @T SELECT 'R5 spr_GetAgendaReport for M2: All my departments / B / C (not his: Reason 4, no rows) (departments of the rows, Reason)', 'A B I 0 | B 0 | 0 4', @S;

    DELETE FROM #VN;
    INSERT INTO #VN EXEC dbo.spr_GetMinutesReportByUser @ActingUserId = @M2, @CommitteeId = @Com, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM #VN v JOIN Department d ON d.DepartmentId = v.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VN;
    INSERT INTO #VN EXEC dbo.spr_GetMinutesReportByUser @ActingUserId = @M2, @CommitteeId = @Com, @DepartmentId = @DI, @MeetingNoSearch = 0, @MeetingId = @MFin,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 1, @FromSubjectNo = 1, @ToSubjectNo = 4, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM #VN v JOIN Department d ON d.DepartmentId = v.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VN;
    INSERT INTO #VN EXEC dbo.spr_GetMinutesReportByUser @ActingUserId = @M2, @CommitteeId = @Com, @DepartmentId = @DC, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM #VN) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    INSERT INTO @T SELECT 'R5 spr_GetMinutesReportByUser for M2: All my departments / I (inactive, his; one meeting, subjects 1 to 4) / C (Reason 4, no rows)', 'A B I 0 | I 0 | 0 4', @S;

    DELETE FROM #VN;
    INSERT INTO #VN EXEC dbo.spr_GetReportSubjectNos @ActingUserId = @M2, @MeetingId = @MFin, @DepartmentId = -1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = ISNULL(STUFF((SELECT ' ' + CAST(SubjectNo AS VARCHAR(12)) FROM #VN ORDER BY SubjectNo FOR XML PATH('')), 1, 1, ''), '-') + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VN;
    INSERT INTO #VN EXEC dbo.spr_GetReportSubjectNos @ActingUserId = @M2, @MeetingId = @MFin, @DepartmentId = @DC, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM #VN) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VN;
    INSERT INTO #VN EXEC dbo.spr_GetReportSubjectNos @ActingUserId = @Mg, @MeetingId = @MFin, @DepartmentId = -1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + ISNULL(STUFF((SELECT ' ' + CAST(SubjectNo AS VARCHAR(12)) FROM #VN ORDER BY SubjectNo FOR XML PATH('')), 1, 1, ''), '-') + ' ' + CAST(@Rsn AS VARCHAR(4));
    INSERT INTO @T SELECT 'R5 spr_GetReportSubjectNos: M2 - All - (subjects of A, B, I) / M2 for C (Reason 4) / Management - All - (every department)', '1 2 4 0 | 0 4 | 1 2 3 4 0', @S;

    DELETE FROM #VO;
    INSERT INTO #VO EXEC dbo.spr_GetAgendaReport @ActingUserId = @Mg, @CommitteeId = @Com, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @OrderBy = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = CAST((SELECT COUNT(*) FROM #VO) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VO;
    INSERT INTO #VO EXEC dbo.spr_GetAgendaReport @ActingUserId = @UA, @CommitteeId = @Com, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @OrderBy = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM #VO) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VN;
    INSERT INTO #VN EXEC dbo.spr_GetMinutesReportByUser @ActingUserId = @Mg, @CommitteeId = @Com, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM #VN) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VO;
    INSERT INTO #VO EXEC dbo.spr_GetAgendaReport @ActingUserId = @Ctl0, @CommitteeId = @Com, @DepartmentId = -1, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @OrderBy = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM #VO) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    DELETE FROM #VN;
    INSERT INTO #VN EXEC dbo.spr_GetReportSubjectNos @ActingUserId = @Sys, @MeetingId = @MFin, @DepartmentId = -1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @S = @S + ' | ' + CAST((SELECT COUNT(*) FROM #VN) AS VARCHAR(4)) + ' ' + CAST(@Rsn AS VARCHAR(4));
    INSERT INTO @T SELECT 'R5 refused (rows, Reason): agenda report for Management (4) and a User (4); minutes report for Management (4); an inactive Controller (8); the system account (8)',
           '0 4 | 0 4 | 0 4 | 0 8 | 0 8', @S;

    DELETE FROM #VO;
    INSERT INTO #VO EXEC dbo.spr_GetAgendaReport @ActingUserId = @Ctl, @CommitteeId = @Com, @DepartmentId = -1, @MeetingNoSearch = 1, @MeetingId = 0,
         @FromMeetingId = @MFut, @ToMeetingId = @MFin, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0, @OrderBy = 2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'R5 spr_GetAgendaReport for the made-up Controller, a meeting range: the approved items of every department, not the items waiting', 'A B C I 0',
           ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM #VO v JOIN Department d ON d.DepartmentId = v.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), '-') + ' ' + CAST(@Rsn AS VARCHAR(4));
END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Error inside the test transaction (line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + ')', 'none', LEFT(ERROR_MESSAGE(), 400));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

Report:
-- Rows outside the test, after
SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @HistAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistAfter = @HistAfter + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, DepartmentId, CreatedBy, ShortText)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, UserId, ReadStatus, StatusId, HandledReason, HandledBy)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
SELECT @MinAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, AgendaId, StatusId)), 0) AS VARCHAR(12)) FROM Minutes;

INSERT INTO @T SELECT 'After the rollback: Users, User_Role / User_Department, Agenda, Alert_User_Map and Minutes as before', 'same same same same same',
       CASE WHEN @UsersAfter = @UsersBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @HistAfter = @HistBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @AgendaAfter = @AgendaBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @MapAfter = @MapBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @MinAfter = @MinBefore THEN 'same' ELSE 'DIFFERENT' END;

INSERT INTO #T (Test, Expected, Actual) SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;
GO

-- Every identity counter as before the test (a rolled-back insert still moves it)
DECLARE @TableName SYSNAME, @SavedValue BIGINT, @SeedValue BIGINT, @IncrementValue BIGINT, @Sql NVARCHAR(400);
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
SELECT 'Identity counters as before the test', '0',
       CAST((SELECT COUNT(*) FROM #Ident i JOIN sys.tables t ON t.name = i.TableName JOIN sys.identity_columns ic ON ic.object_id = t.object_id
             WHERE ISNULL(CAST(ic.last_value AS BIGINT), -1) <> ISNULL(i.SavedValue, -1) AND i.SavedValue IS NOT NULL) AS VARCHAR(12));

INSERT INTO #T
SELECT 'After the test: no ZZ54 department, user, committee, meeting or item left', '0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ54%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz54%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z54') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ54 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'Z54-%' OR ShortText LIKE N'ZZ54%') AS VARCHAR(12));

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

DROP PROCEDURE #ZZ54_List;
DROP PROCEDURE #ZZ54_Item;
DROP PROCEDURE #ZZ54_Edit;
DROP PROCEDURE #ZZ54_Save;
DROP TABLE #VL;
DROP TABLE #VN;
DROP TABLE #VM;
DROP TABLE #VO;
DROP TABLE #VA;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
