/* ============================================================================
   BMMS - Tests for BMMS-Fix-ReportAccess-Step41.sql (step 41, step RA1b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   TEST DATABASE ONLY. It refuses to run in a database named exactly "BMMS".
   Run it AFTER BMMS-Fix-ReportAccess-Step41.sql; it stops if step 41 is not
   installed.

   Part 1, read only: the three markers, the parameters, the result columns
   (the old columns in the same order plus the new ones), the step 22
   procedures unchanged.

   Part 2, inside one transaction that is ROLLED BACK, with made-up users, a
   committee, meetings, agenda items, minutes rows and action items (ZZ41...):
     * who may call each procedure: Controller and Management the two Minutes
       procedures, Management only the Followup one; Manager, User, Admin and
       MD Secretariat Reason 4; an inactive, unknown or missing acting user
       Reason 8; a refused call returns no rows
     * the meeting list in every status, by MeetingNo, with the marks
       (Open, NULL and an unknown value: Draft (not finalised); F: Finalised;
       C: Confirmed); a meeting without a minutes row and the meetings of
       another committee are not listed
     * the minutes rows in every status with their marks: every meeting, one
       meeting, a range, a department, a subject number range
     * the step 22 procedures still return finalised and confirmed only
     * spr_GetFollowupReportForManagement against a copy of the query that
       BMMSBAL/ReportsMgr.cs GetFollowupReport builds (the Controller's
       path), for nine filter combinations: the same rows (count and
       ActionItemId); the marks of the Followup rows
     * rows outside the test are unchanged after the rollback, and every
       identity counter is put back

   Result: one grid, one row per check. Status should be PASS for every row.

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
ELSE IF (OBJECT_ID('dbo.spr_GetMinutesReportAllStatus', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetFollowupReportForManagement', 'P') IS NULL)
BEGIN
    RAISERROR('Step 41 (BMMS-Fix-ReportAccess-Step41.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#MT') IS NOT NULL DROP TABLE #MT;
IF OBJECT_ID('tempdb..#MR') IS NOT NULL DROP TABLE #MR;
IF OBJECT_ID('tempdb..#OldMT') IS NOT NULL DROP TABLE #OldMT;
IF OBJECT_ID('tempdb..#OldMR') IS NOT NULL DROP TABLE #OldMR;
IF OBJECT_ID('tempdb..#FA') IS NOT NULL DROP TABLE #FA;
IF OBJECT_ID('tempdb..#FQ') IS NOT NULL DROP TABLE #FQ;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- Result tables: the view columns plus the columns the procedures add (built from the views, so they follow them)
SELECT TOP 0 v.*, CAST(NULL AS VARCHAR(30)) AS MinutesStatusMark INTO #MT FROM View_Meeting v;
SELECT TOP 0 v.*, CAST(NULL AS VARCHAR(50)) AS MinutesStatus, CAST(NULL AS VARCHAR(30)) AS MinutesStatusMark INTO #MR FROM View_Minute v;
SELECT TOP 0 v.* INTO #OldMT FROM View_Meeting v;
SELECT TOP 0 v.* INTO #OldMR FROM View_Minute v;
SELECT TOP 0 v.*, CAST(NULL AS VARCHAR(50)) AS MinutesStatus, CAST(NULL AS VARCHAR(30)) AS MinutesStatusMark INTO #FA FROM View_Action_Item v;
SELECT TOP 0 v.* INTO #FQ FROM View_Action_Item v;

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T SELECT 'Marker ReportAccess-Step41 in the three new procedures', '3',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus')) LIKE '%ReportAccess-Step41%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportAllStatus')) LIKE '%ReportAccess-Step41%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupReportForManagement')) LIKE '%ReportAccess-Step41%' THEN 1 ELSE 0 END AS VARCHAR(12));
INSERT INTO #T SELECT 'Parameters: meetings 4, minutes 12, followup 10 (each ends with @ActingUserId, @Result OUTPUT, @Reason OUTPUT)', '4 12 10 3',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetMinutesReportAllStatus')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetFollowupReportForManagement')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id IN (OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus'),
               OBJECT_ID('dbo.spr_GetMinutesReportAllStatus'), OBJECT_ID('dbo.spr_GetFollowupReportForManagement'))
               AND name = '@Reason' AND is_output = 1) AS VARCHAR(12));
INSERT INTO #T SELECT 'Step 22 procedures unchanged: marker MinutesGating-Step22, the F and C filter, no step 41 marker', '2 2 0',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReport')) LIKE '%MinutesGating-Step22%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportMeetings')) LIKE '%MinutesGating-Step22%' THEN 1 ELSE 0 END AS VARCHAR(12)) + ' '
     + CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReport')) LIKE '%IN (''F'', ''C'')%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportMeetings')) LIKE '%IN (''F'', ''C'')%' THEN 1 ELSE 0 END AS VARCHAR(12)) + ' '
     + CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReport')) LIKE '%ReportAccess-Step41%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMinutesReportMeetings')) LIKE '%ReportAccess-Step41%' THEN 1 ELSE 0 END AS VARCHAR(12));

-- Result columns: the old columns in the same order, then the new ones (the pages read them by name)
DECLARE @OldCols VARCHAR(MAX), @NewCols VARCHAR(MAX);
SELECT @OldCols = ISNULL(@OldCols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetMinutesReport'), 0) ORDER BY column_ordinal;
SELECT @NewCols = ISNULL(@NewCols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetMinutesReportAllStatus'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetMinutesReportAllStatus: the columns of spr_GetMinutesReport, then MinutesStatus, MinutesStatusMark', 'same',
       CASE WHEN @NewCols = @OldCols + ',MinutesStatus,MinutesStatusMark' THEN 'same' ELSE 'differs' END;
SET @OldCols = NULL; SET @NewCols = NULL;
SELECT @OldCols = ISNULL(@OldCols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetMinutesReportMeetings'), 0) ORDER BY column_ordinal;
SELECT @NewCols = ISNULL(@NewCols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetMinutesReportMeetingsAllStatus: the columns of spr_GetMinutesReportMeetings, then MinutesStatusMark', 'same',
       CASE WHEN @NewCols = @OldCols + ',MinutesStatusMark' THEN 'same' ELSE 'differs' END;
SET @OldCols = NULL; SET @NewCols = NULL;
SELECT @OldCols = ISNULL(@OldCols + ',', '') + c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.View_Action_Item') ORDER BY c.column_id;
SELECT @NewCols = ISNULL(@NewCols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetFollowupReportForManagement'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetFollowupReportForManagement: the View_Action_Item columns, then MinutesStatus, MinutesStatusMark', 'same',
       CASE WHEN @NewCols = @OldCols + ',MinutesStatus,MinutesStatusMark' THEN 'same' ELSE 'differs' END;
GO

-------------------------------------------------------------------------------
-- Part 2: the rules, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -7, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @rMd INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DecisionTypeId INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type ORDER BY DecisionTypeId);
DECLARE @C INT, @C2 INT, @DeptA INT, @DeptB INT;
DECLARE @MO INT, @MN INT, @MZ INT, @MF INT, @MC INT, @ME INT, @MX INT;
DECLARE @Adm INT, @Ctl INT, @CtlOff INT, @Gmt INT, @Mgr INT, @Usr INT, @Md INT;
DECLARE @Res INT, @Rsn INT;
DECLARE @Txt VARCHAR(400);
DECLARE @UsersBefore VARCHAR(60), @UsersAfter VARCHAR(60), @MeetBefore VARCHAR(60), @MeetAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMd IS NULL
    OR @Desig IS NULL OR @SubjectTypeId IS NULL OR @DecisionTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, a subject type or a decision type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, AccountStatus)), 0) AS VARCHAR(12)) FROM Users;
SELECT @MeetBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MeetingId, MinutesStatus, AgendaStatus)), 0) AS VARCHAR(12)) FROM Meeting;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names)
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ41A', 'ZZ step 41 department A', 988, 1, @Now, @Sys);
    SET @DeptA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ41B', 'ZZ step 41 department B', 989, 1, @Now, @Sys);
    SET @DeptB = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ41 admin', @DeptA, @Desig, NULL, @rAdmin, 'zz41a@example.invalid', 'zz41adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ41 controller', @DeptA, @Desig, NULL, @rCtl, 'zz41c@example.invalid', 'zz41ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ41 controller inactive', @DeptA, @Desig, NULL, @rCtl, 'zz41i@example.invalid', 'zz41off', 'not-a-login', 0, @Now);
    SET @CtlOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ41 management', @DeptA, @Desig, NULL, @rMgmt, 'zz41g@example.invalid', 'zz41gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ41 manager', @DeptA, @Desig, NULL, @rMgr, 'zz41m@example.invalid', 'zz41mgr', 'not-a-login', 1, @Now);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ41 user', @DeptA, @Desig, @Mgr, @rUser, 'zz41u@example.invalid', 'zz41usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ41 md secretariat', @DeptA, @Desig, NULL, @rMd, 'zz41s@example.invalid', 'zz41md', 'not-a-login', 1, @Now);
    SET @Md = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z41', 'ZZ step 41 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Y41', 'ZZ step 41 other committee', '2000-01-01', 1, 0);
    SET @C2 = SCOPE_IDENTITY();

    -- Meetings in MeetingId order: Open, NULL, an unknown status, F, C, a NULL meeting without minutes, other committee (F)
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99411', @C, 'ZZ41 test', 'ZZ', @Past, '10:00', 'Close', 'Open');
    SET @MO = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99412', @C, 'ZZ41 test', 'ZZ', @Past, '10:00', 'Close', NULL);
    SET @MN = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99413', @C, 'ZZ41 test', 'ZZ', @Past, '10:00', 'Close', 'ZZ');
    SET @MZ = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99414', @C, 'ZZ41 test', 'ZZ', @Past, '10:00', 'Close', 'F');
    SET @MF = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99415', @C, 'ZZ41 test', 'ZZ', @Past, '10:00', 'Close', 'C');
    SET @MC = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99416', @C, 'ZZ41 test', 'ZZ', @Past, '10:00', 'Open', NULL);
    SET @ME = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99417', @C2, 'ZZ41 test', 'ZZ', @Past, '10:00', 'Close', 'F');
    SET @MX = SCOPE_IDENTITY();

    -- One approved agenda item, its minutes row and its action item per line (IsConfirmed 0, 1 or NULL)
    DECLARE @Items TABLE (AgendaNo VARCHAR(20), MeetingId INT, DepartmentId INT, SubjectNo INT, IsConfirmed INT);
    INSERT INTO @Items VALUES
    ('Z41O1', @MO, @DeptA, 1, 0), ('Z41O2', @MO, @DeptB, 2, 1),
    ('Z41N1', @MN, @DeptA, 1, 0),
    ('Z41Z1', @MZ, @DeptB, 1, NULL),
    ('Z41F1', @MF, @DeptA, 1, 1), ('Z41F2', @MF, @DeptB, 2, 0), ('Z41F3', @MF, @DeptA, 3, 0),
    ('Z41C1', @MC, @DeptB, 1, 1),
    ('Y41X1', @MX, @DeptA, 1, 0);

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        AgendaStatusCode, ControllerApprovedStatus, SubjectNo, CreatedOn, CreatedBy)
    SELECT i.AgendaNo, m.CommitteeId, i.MeetingId, i.DepartmentId, @SubjectTypeId, 'ZZ41 ' + i.AgendaNo, 'Entry', 'ZZ', 'ZZ41 resolution',
           'ACA', 'Approved', i.SubjectNo, @Now, @Sys
    FROM @Items i JOIN Meeting m ON m.MeetingId = i.MeetingId;

    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, StatusId, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    SELECT a.AgendaId, @DecisionTypeId, ' ', 'ZZ41 resolution', 1, @Now, @Sys, @Now, @Sys
    FROM Agenda a JOIN @Items i ON i.AgendaNo = a.AgendaNo AND i.MeetingId = a.MeetingId;

    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, IsConfirmed, UpdatedOn, UpdatedBy)
    SELECT mi.MinutesId, 'ZZ41', 'ZZ41 action ' + i.AgendaNo, 'Open', i.IsConfirmed, @Now, @Sys
    FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId JOIN @Items i ON i.AgendaNo = a.AgendaNo AND i.MeetingId = a.MeetingId;

    ---------------------------------------------------------------------------
    -- Who may call: the meeting list
    ---------------------------------------------------------------------------
    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, Controller: allowed, 5 meetings', 'Result 1, Reason 0, 5 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';
    INSERT INTO @T SELECT 'Meeting list, Controller: by MeetingNo with the marks; the meeting without minutes and the other committee left out',
           '99411 Draft (not finalised), 99412 Draft (not finalised), 99413 Draft (not finalised), 99414 Finalised, 99415 Confirmed',
           ISNULL(STUFF((SELECT ', ' + CAST(MeetingNo AS VARCHAR(12)) + ' ' + MinutesStatusMark FROM #MT ORDER BY MeetingNo FOR XML PATH('')), 1, 2, ''), 'none');

    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = @Gmt, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, Management: allowed, 5 meetings', 'Result 1, Reason 0, 5 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';

    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = @Mgr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, Manager: refused, no rows', 'Result 0, Reason 4, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';

    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = @Usr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, User: refused, no rows', 'Result 0, Reason 4, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';

    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = @Adm, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, Admin: refused, no rows', 'Result 0, Reason 4, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';

    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = @Md, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, MD Secretariat: refused, no rows', 'Result 0, Reason 4, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';

    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = @CtlOff, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, inactive Controller: Reason 8, no rows', 'Result 0, Reason 8, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';

    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = 0, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, acting user 0: Reason 8', 'Result 0, Reason 8, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';

    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MT EXEC spr_GetMinutesReportMeetingsAllStatus @CommitteeId = @C, @ActingUserId = NULL, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Meeting list, no acting user: Reason 8', 'Result 0, Reason 8, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12)) + ' rows';

    ---------------------------------------------------------------------------
    -- The minutes rows in every status
    ---------------------------------------------------------------------------
    DELETE FROM #MR; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MR EXEC spr_GetMinutesReportAllStatus @CommitteeId = @C, @DepartmentId = 0, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0,
         @ActingUserId = @Gmt, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Minutes rows, Management, every meeting: all statuses by meeting and subject number, with the marks',
           'Result 1, Reason 0 | Z41O1 Draft (not finalised), Z41O2 Draft (not finalised), Z41N1 Draft (not finalised), Z41Z1 Draft (not finalised), Z41F1 Finalised, Z41F2 Finalised, Z41F3 Finalised, Z41C1 Confirmed',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ' | '
         + ISNULL(STUFF((SELECT ', ' + AgendaNo + ' ' + MinutesStatusMark FROM #MR ORDER BY MeetingId, SubjectNo FOR XML PATH('')), 1, 2, ''), 'none');
    INSERT INTO @T SELECT 'Minutes rows: MinutesStatus as stored (Open, NULL, ZZ, F, C)', 'Open,NULL,ZZ,F,C',
           ISNULL(STUFF((SELECT ',' + ISNULL(MinutesStatus, 'NULL') FROM (SELECT DISTINCT MeetingId, MinutesStatus FROM #MR) x ORDER BY MeetingId FOR XML PATH('')), 1, 1, ''), 'none');

    DELETE FROM #MR; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MR EXEC spr_GetMinutesReportAllStatus @CommitteeId = @C, @DepartmentId = 0, @MeetingNoSearch = 0, @MeetingId = @MO,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0,
         @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Minutes rows, Controller, one Open meeting', 'Z41O1,Z41O2',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #MR ORDER BY SubjectNo FOR XML PATH('')), 1, 1, ''), 'none');

    DELETE FROM #MR; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MR EXEC spr_GetMinutesReportAllStatus @CommitteeId = @C, @DepartmentId = 0, @MeetingNoSearch = 1, @MeetingId = 0,
         @FromMeetingId = @MN, @ToMeetingId = @MF, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0,
         @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Minutes rows, a meeting range NULL to F', 'Z41N1,Z41Z1,Z41F1,Z41F2,Z41F3',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #MR ORDER BY MeetingId, SubjectNo FOR XML PATH('')), 1, 1, ''), 'none');

    DELETE FROM #MR; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MR EXEC spr_GetMinutesReportAllStatus @CommitteeId = @C, @DepartmentId = @DeptB, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0,
         @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Minutes rows, department B only', 'Z41O2,Z41Z1,Z41F2,Z41C1',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #MR ORDER BY MeetingId, SubjectNo FOR XML PATH('')), 1, 1, ''), 'none');

    DELETE FROM #MR; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MR EXEC spr_GetMinutesReportAllStatus @CommitteeId = @C, @DepartmentId = 0, @MeetingNoSearch = 0, @MeetingId = @MF,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 1, @FromSubjectNo = 2, @ToSubjectNo = 3,
         @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Minutes rows, one meeting, subject numbers 2 to 3', 'Z41F2,Z41F3',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #MR ORDER BY SubjectNo FOR XML PATH('')), 1, 1, ''), 'none');

    DELETE FROM #MR; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MR EXEC spr_GetMinutesReportAllStatus @CommitteeId = 0, @DepartmentId = 0, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0,
         @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Minutes rows, committee 0: no rows (as spr_GetMinutesReport)', '0', CAST((SELECT COUNT(*) FROM #MR) AS VARCHAR(12));

    DELETE FROM #MR; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MR EXEC spr_GetMinutesReportAllStatus @CommitteeId = @C, @DepartmentId = 0, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0,
         @ActingUserId = @Mgr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Minutes rows, Manager: refused, no rows', 'Result 0, Reason 4, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MR) AS VARCHAR(12)) + ' rows';

    DELETE FROM #MR; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #MR EXEC spr_GetMinutesReportAllStatus @CommitteeId = @C, @DepartmentId = 0, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0,
         @ActingUserId = @CtlOff, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Minutes rows, inactive Controller: Reason 8, no rows', 'Result 0, Reason 8, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #MR) AS VARCHAR(12)) + ' rows';

    ---------------------------------------------------------------------------
    -- The step 22 procedures (Manager and the other roles) still finalised and confirmed only
    ---------------------------------------------------------------------------
    DELETE FROM #OldMT; INSERT INTO #OldMT EXEC spr_GetMinutesReportMeetings @CommitteeId = @C;
    INSERT INTO @T SELECT 'Step 22 meeting list: F and C only', '99414 F, 99415 C',
           ISNULL(STUFF((SELECT ', ' + CAST(MeetingNo AS VARCHAR(12)) + ' ' + MinutesStatus FROM #OldMT ORDER BY MeetingNo FOR XML PATH('')), 1, 2, ''), 'none');
    DELETE FROM #OldMR; INSERT INTO #OldMR EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = 0, @MeetingNoSearch = 0, @MeetingId = 0,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Step 22 minutes rows: F and C only', 'Z41F1,Z41F2,Z41F3,Z41C1',
           ISNULL(STUFF((SELECT ',' + AgendaNo FROM #OldMR ORDER BY MeetingId, SubjectNo FOR XML PATH('')), 1, 1, ''), 'none');

    ---------------------------------------------------------------------------
    -- Followup for Management: who may call
    ---------------------------------------------------------------------------
    DELETE FROM #FA; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #FA EXEC spr_GetFollowupReportForManagement @CommitteeId = @C, @MeetingNoSearch = 0, @MeetingId = 0, @FromMeetingId = 0,
         @ToMeetingId = 0, @DepartmentId = 0, @ConfirmStatus = -1, @ActingUserId = @Gmt, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Followup, Management: allowed; the rows of the committee with their marks',
           'Result 1, Reason 0 | Z41O1 Draft (not finalised), Z41O2 Draft (not finalised), Z41N1 Draft (not finalised), Z41Z1 Draft (not finalised), Z41F1 Finalised, Z41F2 Finalised, Z41F3 Finalised, Z41C1 Confirmed',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ' | '
         + ISNULL(STUFF((SELECT ', ' + AgendaNo + ' ' + MinutesStatusMark FROM #FA ORDER BY MeetingId, SubjectNo FOR XML PATH('')), 1, 2, ''), 'none');

    DELETE FROM #FA; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #FA EXEC spr_GetFollowupReportForManagement @CommitteeId = @C, @MeetingNoSearch = 0, @MeetingId = 0, @FromMeetingId = 0,
         @ToMeetingId = 0, @DepartmentId = 0, @ConfirmStatus = -1, @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Followup procedure, Controller: refused (Management only; the Controller keeps its own path)', 'Result 0, Reason 4, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #FA) AS VARCHAR(12)) + ' rows';

    DELETE FROM #FA; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #FA EXEC spr_GetFollowupReportForManagement @CommitteeId = @C, @MeetingNoSearch = 0, @MeetingId = 0, @FromMeetingId = 0,
         @ToMeetingId = 0, @DepartmentId = 0, @ConfirmStatus = -1, @ActingUserId = @Mgr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Followup procedure, Manager: refused', 'Result 0, Reason 4, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #FA) AS VARCHAR(12)) + ' rows';

    DELETE FROM #FA; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #FA EXEC spr_GetFollowupReportForManagement @CommitteeId = @C, @MeetingNoSearch = 0, @MeetingId = 0, @FromMeetingId = 0,
         @ToMeetingId = 0, @DepartmentId = 0, @ConfirmStatus = -1, @ActingUserId = @CtlOff, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Followup procedure, inactive acting user: Reason 8', 'Result 0, Reason 8, 0 rows',
           'Result ' + CAST(@Res AS VARCHAR(2)) + ', Reason ' + CAST(@Rsn AS VARCHAR(3)) + ', ' + CAST((SELECT COUNT(*) FROM #FA) AS VARCHAR(12)) + ' rows';

    ---------------------------------------------------------------------------
    -- Followup for Management against a copy of the Controller's code-built query (ReportsMgr.GetFollowupReport)
    ---------------------------------------------------------------------------
    DECLARE @Combos TABLE (Seq INT IDENTITY(1,1), Label VARCHAR(120), CommitteeId INT, MeetingNoSearch INT, MeetingId INT,
                           FromMeetingId INT, ToMeetingId INT, DepartmentId INT, ConfirmStatus INT, NeedRows INT);
    INSERT INTO @Combos (Label, CommitteeId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId, DepartmentId, ConfirmStatus, NeedRows) VALUES
    ('no filter', 0, 0, 0, 0, 0, 0, -1, 1),
    ('committee', @C, 0, 0, 0, 0, 0, -1, 1),
    ('committee, one meeting', @C, 0, @MF, 0, 0, 0, -1, 1),
    ('committee, meeting range', @C, 1, 0, @MN, @MF, 0, -1, 1),
    ('department', 0, 0, 0, 0, 0, @DeptB, -1, 1),
    ('confirmed', 0, 0, 0, 0, 0, 0, 1, 1),
    ('not confirmed', 0, 0, 0, 0, 0, 0, 0, 1),
    ('committee, department, not confirmed', @C, 0, 0, 0, 0, @DeptA, 0, 1),
    ('meeting range without a committee (ignored, as in the code)', 0, 1, 0, @MF, @MF, 0, -1, 1);

    DECLARE @Seq INT = 1, @MaxSeq INT = (SELECT MAX(Seq) FROM @Combos);
    DECLARE @Label VARCHAR(120), @fC INT, @fS INT, @fM INT, @fFrom INT, @fTo INT, @fD INT, @fCf INT, @fNeed INT;
    DECLARE @Q NVARCHAR(2000), @CntA INT, @CntQ INT, @Miss INT, @Extra INT, @Fix INT;

    WHILE (@Seq <= @MaxSeq)
    BEGIN
        SELECT @Label = Label, @fC = CommitteeId, @fS = MeetingNoSearch, @fM = MeetingId, @fFrom = FromMeetingId, @fTo = ToMeetingId,
               @fD = DepartmentId, @fCf = ConfirmStatus, @fNeed = NeedRows
        FROM @Combos WHERE Seq = @Seq;

        -- The Controller's query, as ReportsMgr.GetFollowupReport builds it (integers only)
        SET @Q = N'SELECT * FROM View_Action_Item WHERE 1=1';
        IF (@fC > 0)
        BEGIN
            SET @Q = @Q + N' AND CommitteeId = ' + CAST(@fC AS NVARCHAR(12));
            IF (@fS = 0)
                IF (@fM > 0)
                    SET @Q = @Q + N' AND MeetingId = ' + CAST(@fM AS NVARCHAR(12));
            IF (@fS = 1)
                SET @Q = @Q + N' AND (MeetingId BETWEEN ' + CAST(@fFrom AS NVARCHAR(12)) + N' AND ' + CAST(@fTo AS NVARCHAR(12)) + N')';
        END
        IF (@fD > 0)
            SET @Q = @Q + N' AND DepartmentId = ' + CAST(@fD AS NVARCHAR(12));
        IF (@fCf >= 0)
            SET @Q = @Q + N' AND IsConfirmed = ' + CAST(@fCf AS NVARCHAR(12));
        SET @Q = @Q + N' ORDER BY CommitteeId, MeetingId, DepartmentId, IsConfirmed;';

        DELETE FROM #FQ; INSERT INTO #FQ EXEC sp_executesql @Q;
        DELETE FROM #FA; SET @Res = NULL; SET @Rsn = NULL;
        INSERT INTO #FA EXEC spr_GetFollowupReportForManagement @CommitteeId = @fC, @MeetingNoSearch = @fS, @MeetingId = @fM, @FromMeetingId = @fFrom,
             @ToMeetingId = @fTo, @DepartmentId = @fD, @ConfirmStatus = @fCf, @ActingUserId = @Gmt, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;

        SET @CntA = (SELECT COUNT(*) FROM #FA);
        SET @CntQ = (SELECT COUNT(*) FROM #FQ);
        SET @Miss = (SELECT COUNT(*) FROM (SELECT ActionItemId FROM #FQ EXCEPT SELECT ActionItemId FROM #FA) x);
        SET @Extra = (SELECT COUNT(*) FROM (SELECT ActionItemId FROM #FA EXCEPT SELECT ActionItemId FROM #FQ) x);
        SET @Fix = (SELECT COUNT(*) FROM #FA WHERE AgendaNo LIKE 'Z41%' OR AgendaNo LIKE 'Y41%');

        INSERT INTO @T SELECT 'Followup = the Controller''s query: ' + @Label,
               'same' + CASE WHEN @fNeed = 1 THEN ', test rows found' ELSE '' END,
               CASE WHEN @CntA = @CntQ AND @Miss = 0 AND @Extra = 0 THEN 'same'
                    ELSE 'differs: ' + CAST(@CntA AS VARCHAR(12)) + ' vs ' + CAST(@CntQ AS VARCHAR(12)) + ' rows, ' + CAST(@Miss AS VARCHAR(12)) + ' missing, ' + CAST(@Extra AS VARCHAR(12)) + ' extra' END
             + CASE WHEN @fNeed = 1 THEN CASE WHEN @Fix > 0 THEN ', test rows found' ELSE ', no test rows' END ELSE '' END;

        SET @Seq = @Seq + 1;
    END

END TRY
BEGIN CATCH
    SET @Txt = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error', @Txt);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, AccountStatus)), 0) AS VARCHAR(12)) FROM Users;
SELECT @MeetAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MeetingId, MinutesStatus, AgendaStatus)), 0) AS VARCHAR(12)) FROM Meeting;
INSERT INTO @T SELECT 'After the rollback: Users unchanged (count, checksum)', @UsersBefore, @UsersAfter;
INSERT INTO @T SELECT 'After the rollback: Meeting unchanged (count, checksum)', @MeetBefore, @MeetAfter;

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
SELECT 'After the test: no ZZ41 department, user, committee or meeting left', '0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ41%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz41%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z41', 'Y41')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ41 test') AS VARCHAR(12));

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

DROP TABLE #FQ;
DROP TABLE #FA;
DROP TABLE #OldMR;
DROP TABLE #OldMT;
DROP TABLE #MR;
DROP TABLE #MT;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
