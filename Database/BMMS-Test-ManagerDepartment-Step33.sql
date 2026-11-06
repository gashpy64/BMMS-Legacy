/* ============================================================================
   BMMS - Test of step 33 (Agenda Entry list: a Manager sees the items of
   their department; EnteredByName in both lists)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   READ ONLY. It runs the two list procedures and compares what they return;
   it inserts, changes and deletes nothing in BMMS tables (one temporary
   table, #C2Rows, is created and dropped). Runs ONLY on the database
   BMMS_Test: it stops with a message on any other database. It has no USE
   line: select BMMS_Test in SSMS first. Needs step 33 installed (check 1
   says so otherwise). Written for compatibility level 100. The file is plain
   ASCII. Run the whole file (F5); it can run twice in one window.

   It uses the agenda items already in BMMS_Test: every meeting that has at
   least one item, and every user (any role, active or not).

   Checks, with PASS / FAIL / SKIPPED:
     1  both procedures carry the marker ManagerDepartment-Step33
     2  spr_GetAgendaByMeetingId (Controller): every item of every meeting,
        each once, nothing else
     3  spr_GetAgendaByMeetingIdDeptId, every user and every meeting: the
        items the user entered and, for a Manager, every item whose
        Agenda.DepartmentId is the Manager's department; each once, nothing
        else
     4  EnteredByName in every row of both lists: the creator's User Name,
        " (inactive)" added for an inactive account, "(unknown user)" when
        the user row is missing
     5  mgruser (Manager): sees items of the department entered by other
        users (SKIPPED when the department has none: add one as depuser on
        Agenda Entry first)
     6  depuser (User): sees no item entered by another user
     7  credmanager and secuser (Managers of other departments): see no item
        of mgruser's department that they did not enter
     8  an item entered by an inactive user shows "(inactive)" (SKIPPED when
        no such item exists)
   A FAIL lists the first 50 rows that differ in a second result.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was read.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#C2Rows') IS NOT NULL DROP TABLE #C2Rows;

-- The shape of both lists: every View_Agenda column, then EnteredByName. The join keeps SELECT INTO from
-- copying the IDENTITY property of AgendaId, so INSERT ... EXEC can fill it.
SELECT TOP 0 va.*, CAST(NULL AS VARCHAR(80)) AS EnteredByName
INTO #C2Rows
FROM View_Agenda va
LEFT JOIN Users nobody ON 1 = 0;

DECLARE @T TABLE (No INT, CheckName NVARCHAR(200), Result VARCHAR(10), Detail NVARCHAR(400));
DECLARE @Bad TABLE (CheckNo INT, MeetingId INT, UserId INT, AgendaId INT, Problem VARCHAR(60));
DECLARE @Mtg TABLE (MeetingId INT PRIMARY KEY);
DECLARE @UserList TABLE (UserId INT PRIMARY KEY, IsManager INT, DepartmentId INT, LoginName VARCHAR(50));

DECLARE @Marker INT = 0;
DECLARE @m INT;
DECLARE @u INT;
DECLARE @IsManager INT;
DECLARE @Dept INT;
DECLARE @Meetings INT;
DECLARE @Items INT;
DECLARE @Users INT;
DECLARE @Lists INT = 0;
DECLARE @n INT;
DECLARE @Detail NVARCHAR(400);
DECLARE @MgrUser INT;
DECLARE @MgrDept INT;
DECLARE @DepUser INT;
DECLARE @Seen5 INT = 0;
DECLARE @Seen7 INT = 0;
DECLARE @InactiveItems INT;

-- 1. Markers
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingIdDeptId')), '') LIKE '%ManagerDepartment-Step33%')
    SET @Marker = @Marker + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingId')), '') LIKE '%ManagerDepartment-Step33%')
    SET @Marker = @Marker + 1;
SET @Detail = CAST(@Marker AS VARCHAR(4)) + N' of 2 procedures carry the marker';
INSERT INTO @T VALUES (1, N'Both list procedures are the step 33 versions', CASE WHEN @Marker = 2 THEN 'PASS' ELSE 'FAIL' END, @Detail);

IF (@Marker = 2)
BEGIN
    INSERT INTO @Mtg (MeetingId) SELECT DISTINCT MeetingId FROM View_Agenda WHERE MeetingId IS NOT NULL;

    INSERT INTO @UserList (UserId, IsManager, DepartmentId, LoginName)
    SELECT us.UserId, CASE WHEN r.RoleCode = 'manager' THEN 1 ELSE 0 END, us.DepartmentId, us.LoginName
    FROM Users us
    LEFT JOIN Roles r ON r.RoleId = us.RoleId;

    SET @Meetings = (SELECT COUNT(*) FROM @Mtg);
    SET @Items = (SELECT COUNT(*) FROM View_Agenda WHERE MeetingId IS NOT NULL);
    SET @Users = (SELECT COUNT(*) FROM @UserList);

    SET @MgrUser = (SELECT TOP 1 UserId FROM @UserList WHERE LoginName = 'mgruser');
    SET @MgrDept = (SELECT TOP 1 DepartmentId FROM @UserList WHERE LoginName = 'mgruser');
    SET @DepUser = (SELECT TOP 1 UserId FROM @UserList WHERE LoginName = 'depuser');

    SET @m = 0;
    WHILE (1 = 1)
    BEGIN
        SET @m = (SELECT MIN(MeetingId) FROM @Mtg WHERE MeetingId > @m);
        IF (@m IS NULL)
            BREAK;

        -- 2 and 4: the Controller's list
        TRUNCATE TABLE #C2Rows;
        INSERT INTO #C2Rows EXEC dbo.spr_GetAgendaByMeetingId @MeetingId = @m;
        SET @Lists = @Lists + 1;

        INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
        SELECT 2, @m, NULL, va.AgendaId, 'missing from the Controller list'
        FROM View_Agenda va
        WHERE va.MeetingId = @m
        AND NOT EXISTS (SELECT 1 FROM #C2Rows r WHERE r.AgendaId = va.AgendaId);

        INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
        SELECT 2, @m, NULL, r.AgendaId, 'not an item of the meeting, or listed twice'
        FROM #C2Rows r
        WHERE r.MeetingId <> @m OR r.MeetingId IS NULL
        OR (SELECT COUNT(*) FROM #C2Rows r2 WHERE r2.AgendaId = r.AgendaId) > 1;

        INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
        SELECT 4, @m, NULL, r.AgendaId, 'EnteredByName wrong (Controller list)'
        FROM #C2Rows r
        LEFT JOIN Users c ON c.UserId = r.CreatedBy
        WHERE ISNULL(r.EnteredByName, '#') COLLATE DATABASE_DEFAULT <>
              (CASE WHEN c.UserId IS NULL THEN '(unknown user)'
                    WHEN c.AccountStatus = 1 THEN c.UserName
                    ELSE c.UserName + ' (inactive)' END) COLLATE DATABASE_DEFAULT;

        -- 3 and 4 to 7: every user's list
        SET @u = -2147483647;
        WHILE (1 = 1)
        BEGIN
            SET @u = (SELECT MIN(UserId) FROM @UserList WHERE UserId > @u);
            IF (@u IS NULL)
                BREAK;

            SET @IsManager = (SELECT IsManager FROM @UserList WHERE UserId = @u);
            SET @Dept = (SELECT DepartmentId FROM @UserList WHERE UserId = @u);

            TRUNCATE TABLE #C2Rows;
            INSERT INTO #C2Rows EXEC dbo.spr_GetAgendaByMeetingIdDeptId @MeetingId = @m, @UserId = @u;
            SET @Lists = @Lists + 1;

            INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
            SELECT 3, @m, @u, va.AgendaId, 'missing from the list'
            FROM View_Agenda va
            WHERE va.MeetingId = @m
            AND (va.CreatedBy = @u OR (@IsManager = 1 AND va.DepartmentId = @Dept))
            AND NOT EXISTS (SELECT 1 FROM #C2Rows r WHERE r.AgendaId = va.AgendaId);

            INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
            SELECT 3, @m, @u, r.AgendaId, 'listed but not allowed, or listed twice'
            FROM #C2Rows r
            WHERE r.MeetingId <> @m OR r.MeetingId IS NULL
            OR NOT (ISNULL(r.CreatedBy, -1) = @u OR (@IsManager = 1 AND ISNULL(r.DepartmentId, -1) = ISNULL(@Dept, -2)))
            OR (SELECT COUNT(*) FROM #C2Rows r2 WHERE r2.AgendaId = r.AgendaId) > 1;

            INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
            SELECT 4, @m, @u, r.AgendaId, 'EnteredByName wrong'
            FROM #C2Rows r
            LEFT JOIN Users c ON c.UserId = r.CreatedBy
            WHERE ISNULL(r.EnteredByName, '#') COLLATE DATABASE_DEFAULT <>
                  (CASE WHEN c.UserId IS NULL THEN '(unknown user)'
                        WHEN c.AccountStatus = 1 THEN c.UserName
                        ELSE c.UserName + ' (inactive)' END) COLLATE DATABASE_DEFAULT;

            IF (@u = @MgrUser)
            BEGIN
                SET @n = (SELECT COUNT(*) FROM #C2Rows WHERE CreatedBy <> @u AND DepartmentId = @MgrDept);
                SET @Seen5 = @Seen5 + @n;

                INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
                SELECT 5, @m, @u, r.AgendaId, 'another user''s item of another department'
                FROM #C2Rows r
                WHERE r.CreatedBy <> @u AND (r.DepartmentId <> @MgrDept OR r.DepartmentId IS NULL);
            END

            IF (@u = @DepUser)
                INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
                SELECT 6, @m, @u, r.AgendaId, 'item entered by another user'
                FROM #C2Rows r
                WHERE r.CreatedBy <> @u OR r.CreatedBy IS NULL;

            IF (@u IN (SELECT UserId FROM @UserList WHERE LoginName IN ('credmanager', 'secuser')))
            BEGIN
                SET @n = (SELECT COUNT(*) FROM View_Agenda va WHERE va.MeetingId = @m AND va.DepartmentId = @MgrDept AND va.CreatedBy <> @u);
                SET @Seen7 = @Seen7 + @n;

                INSERT INTO @Bad (CheckNo, MeetingId, UserId, AgendaId, Problem)
                SELECT 7, @m, @u, r.AgendaId, 'item of mgruser''s department not entered by this user'
                FROM #C2Rows r
                WHERE r.DepartmentId = @MgrDept AND r.CreatedBy <> @u
                AND ISNULL(@Dept, -1) <> @MgrDept;
            END
        END
    END

    -- Results
    SET @n = (SELECT COUNT(*) FROM @Bad WHERE CheckNo = 2);
    SET @Detail = CAST(@Meetings AS VARCHAR(12)) + N' meetings, ' + CAST(@Items AS VARCHAR(12)) + N' items; '
                + CAST(@n AS VARCHAR(12)) + N' rows differ';
    INSERT INTO @T VALUES (2, N'Controller list: every item of the meeting, each once', CASE WHEN @Meetings = 0 THEN 'SKIPPED' WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
                           CASE WHEN @Meetings = 0 THEN N'no agenda items in BMMS_Test' ELSE @Detail END);

    SET @n = (SELECT COUNT(*) FROM @Bad WHERE CheckNo = 3);
    SET @Detail = CAST(@Users AS VARCHAR(12)) + N' users x ' + CAST(@Meetings AS VARCHAR(12)) + N' meetings; '
                + CAST(@n AS VARCHAR(12)) + N' rows differ';
    INSERT INTO @T VALUES (3, N'Manager / User list: own items, and for a Manager the department''s items', CASE WHEN @Meetings = 0 THEN 'SKIPPED' WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
                           CASE WHEN @Meetings = 0 THEN N'no agenda items in BMMS_Test' ELSE @Detail END);

    SET @n = (SELECT COUNT(*) FROM @Bad WHERE CheckNo = 4);
    SET @Detail = CAST(@Lists AS VARCHAR(12)) + N' lists read; ' + CAST(@n AS VARCHAR(12)) + N' rows with a wrong EnteredByName';
    INSERT INTO @T VALUES (4, N'EnteredByName in both lists', CASE WHEN @Meetings = 0 THEN 'SKIPPED' WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END, @Detail);

    SET @n = (SELECT COUNT(*) FROM @Bad WHERE CheckNo = 5);
    SET @Detail = CAST(@Seen5 AS VARCHAR(12)) + N' department rows entered by others seen; ' + CAST(@n AS VARCHAR(12)) + N' wrong rows';
    INSERT INTO @T VALUES (5, N'mgruser sees the department''s items entered by others',
                           CASE WHEN @MgrUser IS NULL THEN 'SKIPPED' WHEN @n > 0 THEN 'FAIL' WHEN @Seen5 = 0 THEN 'SKIPPED' ELSE 'PASS' END,
                           CASE WHEN @MgrUser IS NULL THEN N'no user mgruser'
                                WHEN @n = 0 AND @Seen5 = 0 THEN N'no item of mgruser''s department entered by another user: add one as depuser on Agenda Entry, run again'
                                ELSE @Detail END);

    SET @n = (SELECT COUNT(*) FROM @Bad WHERE CheckNo = 6);
    SET @Detail = CAST(@n AS VARCHAR(12)) + N' rows entered by another user';
    INSERT INTO @T VALUES (6, N'depuser sees only the items depuser entered',
                           CASE WHEN @DepUser IS NULL THEN 'SKIPPED' WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
                           CASE WHEN @DepUser IS NULL THEN N'no user depuser' ELSE @Detail END);

    SET @n = (SELECT COUNT(*) FROM @Bad WHERE CheckNo = 7);
    SET @Detail = CAST(@Seen7 AS VARCHAR(12)) + N' items of mgruser''s department exist for them; ' + CAST(@n AS VARCHAR(12)) + N' listed';
    INSERT INTO @T VALUES (7, N'credmanager and secuser do not see mgruser''s department',
                           CASE WHEN @MgrUser IS NULL OR NOT EXISTS (SELECT 1 FROM @UserList WHERE LoginName IN ('credmanager', 'secuser')) THEN 'SKIPPED'
                                WHEN @n > 0 THEN 'FAIL' WHEN @Seen7 = 0 THEN 'SKIPPED' ELSE 'PASS' END,
                           CASE WHEN @Seen7 = 0 AND @n = 0 THEN N'no item of mgruser''s department to hide' ELSE @Detail END);

    SET @InactiveItems = (SELECT COUNT(*) FROM View_Agenda va JOIN Users c ON c.UserId = va.CreatedBy WHERE c.AccountStatus = 0 AND va.MeetingId IS NOT NULL);
    SET @n = (SELECT COUNT(*) FROM @Bad b JOIN View_Agenda va ON va.AgendaId = b.AgendaId JOIN Users c ON c.UserId = va.CreatedBy
              WHERE b.CheckNo = 4 AND c.AccountStatus = 0);
    SET @Detail = CAST(@InactiveItems AS VARCHAR(12)) + N' items entered by an inactive user; ' + CAST(@n AS VARCHAR(12)) + N' rows wrong';
    INSERT INTO @T VALUES (8, N'An inactive creator shows "(inactive)"',
                           CASE WHEN @InactiveItems = 0 THEN 'SKIPPED' WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END,
                           CASE WHEN @InactiveItems = 0 THEN N'no item entered by an inactive user' ELSE @Detail END);
END
ELSE
BEGIN
    INSERT INTO @T VALUES (2, N'Controller list', 'SKIPPED', N'step 33 not installed');
    INSERT INTO @T VALUES (3, N'Manager / User list', 'SKIPPED', N'step 33 not installed');
END

SELECT No, CheckName, Result, Detail FROM @T ORDER BY No;

IF EXISTS (SELECT 1 FROM @Bad)
    SELECT TOP 50 b.CheckNo, b.MeetingId, b.UserId, us.LoginName, b.AgendaId, b.Problem
    FROM @Bad b
    LEFT JOIN Users us ON us.UserId = b.UserId
    ORDER BY b.CheckNo, b.MeetingId, b.UserId, b.AgendaId;

SELECT DB_NAME() AS CurrentDatabase;

IF OBJECT_ID('tempdb..#C2Rows') IS NOT NULL DROP TABLE #C2Rows;
GO

SET NOEXEC OFF;
GO
