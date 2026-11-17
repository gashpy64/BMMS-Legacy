/* ============================================================================
   BMMS - Test script for step 48 (Dashboard: a confirmed followup is final
   there too; step FU2a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 48
   is not installed.

   Run it in a NEW query window (it uses temporary tables of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS.

   Part 1 reads only: the markers of step 48 and those of steps 43 and 45 it
   keeps; parameters; the columns of the five objects; no feature above
   compatibility level 100; no marker of steps 46 and 47 in the texts of this
   step; the conditions on which the Rollbacks of steps 43 and 45 refuse
   (step 48 installed) are met.

   Part 2, inside ONE transaction that is rolled back (made-up data ZZ48: two
   departments, every role, an inactive user, a committee, a meeting with
   finalised minutes and one with open minutes, seven followups):
     1 Pending, due yesterday, never confirmed
     2 Confirmed (a Confirm row by the Controller)
     3 Reopened (a Confirm, then a Reopen with a 500-character reason by a
       user who is inactive now), due yesterday
     4 Confirmed before history (no history row)
     5 Confirmed, the other department
     6 Confirmed, open minutes
     7 Pending although its latest history row is a Confirm
   - the card (spr_GetDashboardActionItems) per role: no confirmed item for
     any role (R20); the reopened item with IsReopened 1 and its status
     columns (R19); MD Secretariat, Admin, the system account, an inactive
     and no user refused;
   - fn_DashboardActionItems gives the rows of the step 43 rule for every
     user of the database (the step 43 text is installed under another name
     inside the transaction and compared, 28 columns, both ways) (R20);
   - opening (spr_OpenDashboardActionItem): a confirmed item in the person's
     scope is returned with IsConfirmed 1 and the status columns and marked
     read for the Controller, Management, the Manager and the User; a read
     row it creates gets StatusId 0 (StatusId 1 for an item not confirmed);
     outside the scope, the other roles, Reasons 4 and 8 (R18, R21);
   - saving (spr_SaveDashboardActionText): Reason 26 for a confirmed item in
     the scope (Controller, Manager, User); Reason 4 first for Management,
     MD Secretariat, Admin, the system account, outside the scope or
     unknown; Reason 8; a Pending and a reopened item still save; the
     caller's transaction is left open (R16).

   Afterwards: nothing of ZZ48 is left, Action_Item, ActionItem_User_Map and
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
ELSE IF (OBJECT_ID('dbo.fn_DashboardActionItemScope', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') NOT LIKE '%DashboardFollowupFinal-Step48%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') NOT LIKE '%DashboardFollowupFinal-Step48%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') NOT LIKE '%DashboardFollowupFinal-Step48%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') NOT LIKE '%DashboardFollowupFinal-Step48%')
BEGIN
    RAISERROR('Step 48 (BMMS-Fix-DashboardFollowupFinal-Step48.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('tempdb..#T') IS NOT NULL OR OBJECT_ID('tempdb..#Ident') IS NOT NULL OR OBJECT_ID('tempdb..#AI') IS NOT NULL)
BEGIN
    RAISERROR('A temporary table of this script (#T, #Ident, #AI) already exists in this window. Run the script in a NEW query window. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(250), Expected VARCHAR(1000), Actual VARCHAR(1000));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
CREATE TABLE #AI (ActionItemId INT, MinutesId INT, ActionText NVARCHAR(MAX), ActionStatus VARCHAR(50), AgendaId INT, DecisionTypeId INT,
                  DueDate DATETIME, AgendaNo VARCHAR(50), CommitteeId INT, MeetingId INT, DecisionTypeCode VARCHAR(50),
                  DecisionTypeName NVARCHAR(200), SubjectNo NVARCHAR(50), DepartmentCode VARCHAR(50), DepartmentName NVARCHAR(200),
                  ActualResolution NVARCHAR(MAX), CommitteeName NVARCHAR(200), CommitteeCode VARCHAR(50), MeetingDate DATETIME,
                  MeetingTime VARCHAR(50), Venue NVARCHAR(500), UserId INT, ReadStatus INT, DepartmentId INT, Directions NVARCHAR(MAX),
                  IsComplied INT, IsConfirmed INT, IsOverdue INT, IsReopened INT, StatusAction VARCHAR(10), StatusReason NVARCHAR(500),
                  StatusOn DATETIME, StatusByName NVARCHAR(200), StatusByLogin NVARCHAR(200), StatusByActive INT);

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
INSERT INTO #T SELECT 'Marker DashboardFollowupFinal-Step48 in the new function and the four replaced objects', '5',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardActionItemScope'), ('fn_DashboardActionItems'), ('spr_GetDashboardActionItems'),
                                          ('spr_OpenDashboardActionItem'), ('spr_SaveDashboardActionText')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardFollowupFinal-Step48%') AS VARCHAR(12));

INSERT INTO #T SELECT 'The markers of steps 43 and 45 are kept: DashboardAlerts-Step43 in the four, DashboardSummary-Step45 in spr_GetDashboardActionItems only', '4, 1',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardActionItems'), ('spr_GetDashboardActionItems'), ('spr_OpenDashboardActionItem'),
                                          ('spr_SaveDashboardActionText')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardAlerts-Step43%') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardActionItemScope'), ('fn_DashboardActionItems'), ('spr_GetDashboardActionItems'),
                                          ('spr_OpenDashboardActionItem'), ('spr_SaveDashboardActionText')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardSummary-Step45%') AS VARCHAR(12));

INSERT INTO #T SELECT 'Parameters (all, OUTPUT): scope function 2 0, action item function 2 0, card 5 2, open 4 2, save 5 2 (as before)',
       '2 0, 2 0, 5 2, 4 2, 5 2',
       STUFF((SELECT ', ' + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.' + o.Name) AND p.parameter_id > 0) AS VARCHAR(12))
                     + ' ' + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.' + o.Name) AND p.is_output = 1 AND p.parameter_id > 0) AS VARCHAR(12))
              FROM (VALUES (1, 'fn_DashboardActionItemScope'), (2, 'fn_DashboardActionItems'), (3, 'spr_GetDashboardActionItems'),
                           (4, 'spr_OpenDashboardActionItem'), (5, 'spr_SaveDashboardActionText')) o(Seq, Name)
              ORDER BY o.Seq FOR XML PATH('')), 1, 2, '');

DECLARE @Want VARCHAR(MAX) = 'ActionItemId,MinutesId,ActionText,ActionStatus,AgendaId,DecisionTypeId,DueDate,AgendaNo,CommitteeId,MeetingId,DecisionTypeCode,DecisionTypeName,SubjectNo,DepartmentCode,DepartmentName,ActualResolution,CommitteeName,CommitteeCode,MeetingDate,MeetingTime,Venue,UserId,ReadStatus,DepartmentId,Directions,IsComplied,IsConfirmed,IsOverdue,IsReopened,StatusAction,StatusReason,StatusOn,StatusByName,StatusByLogin,StatusByActive';
DECLARE @Cols VARCHAR(MAX);
SELECT @Cols = ISNULL(@Cols + ',', '') + c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.fn_DashboardActionItemScope') ORDER BY c.column_id;
INSERT INTO #T SELECT 'fn_DashboardActionItemScope: the 28 columns of step 43 and the seven status columns, in this order', @Want, ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.fn_DashboardActionItems') ORDER BY c.column_id;
INSERT INTO #T SELECT 'fn_DashboardActionItems: the same 35 columns', @Want, ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardActionItems'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardActionItems: the same 35 columns (the card and its paging read them)', @Want, ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_OpenDashboardActionItem'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_OpenDashboardActionItem: the same 35 columns (the details panel reads them)', @Want, ISNULL(@Cols, 'none');
INSERT INTO #T SELECT 'spr_SaveDashboardActionText returns no result set', '0',
       CAST((SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_SaveDashboardActionText'), 0)) AS VARCHAR(12));

INSERT INTO #T SELECT 'No feature above compatibility level 100 in the five texts (THROW, IIF, CONCAT, FORMAT, TRY_CONVERT, OFFSET, STRING_AGG, EOMONTH)', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardActionItemScope'), ('fn_DashboardActionItems'), ('spr_GetDashboardActionItems'),
                                          ('spr_OpenDashboardActionItem'), ('spr_SaveDashboardActionText')) o(Name)
             CROSS JOIN (VALUES ('%THROW%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('%TRY[_]CONVERT%'), ('% OFFSET %'), ('%STRING[_]AGG%'), ('%EOMONTH%')) f(Pattern)
             WHERE UPPER(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name))) LIKE f.Pattern) AS VARCHAR(12));

-- The Test scripts of steps 45, 46 and 47 count the objects that carry their markers
INSERT INTO #T SELECT 'No marker of steps 46 and 47 in the five texts; no marker of step 45 in fn_DashboardActionItems and the scope function', '0, 0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardActionItemScope'), ('fn_DashboardActionItems'), ('spr_GetDashboardActionItems'),
                                          ('spr_OpenDashboardActionItem'), ('spr_SaveDashboardActionText')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupSave-Step46%'
                OR OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupFinal-Step47%') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardActionItemScope'), ('fn_DashboardActionItems')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardSummary-Step45%') AS VARCHAR(12));

-- The Rollbacks of steps 43 and 45 refuse while step 48 is installed: their condition is met now
INSERT INTO #T SELECT 'The condition on which BMMS-Rollback-DashboardAlerts-Step43.sql and BMMS-Rollback-DashboardSummary-Step45.sql refuse (step 48 installed) is met', 'met',
       CASE WHEN OBJECT_ID('dbo.fn_DashboardActionItemScope', 'IF') IS NOT NULL
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%'
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%'
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_OpenDashboardActionItem')), '') LIKE '%DashboardFollowupFinal-Step48%'
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')), '') LIKE '%DashboardFollowupFinal-Step48%'
            THEN 'met' ELSE 'not met' END;
GO

-------------------------------------------------------------------------------
-- Part 2: the rules, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(250), Expected VARCHAR(1000), Actual VARCHAR(1000));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);
DECLARE @TodayD DATE = CAST(GETDATE() AS DATE);
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
DECLARE @DeptA INT, @DeptB INT, @Com INT, @MeetF INT, @MeetO INT;
DECLARE @Adm INT, @Ctl INT, @Mgr INT, @Usr INT, @Gmt INT, @Mds INT, @Off INT;
DECLARE @I1 INT, @I2 INT, @I3 INT, @I4 INT, @I5 INT, @I6 INT, @I7 INT;
DECLARE @Res INT, @Rsn INT, @Tran INT, @Diff1 INT, @Diff2 INT, @Rows INT;
DECLARE @Txt VARCHAR(1000), @Reason500 NVARCHAR(500), @ItemState VARCHAR(400), @Sql NVARCHAR(MAX), @HistCount INT;
DECLARE @ItemBefore VARCHAR(60), @ItemAfter VARCHAR(60), @MapBefore VARCHAR(60), @MapAfter VARCHAR(60), @HistBefore VARCHAR(60), @HistAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMd IS NULL OR @Followup IS NULL
    OR @Desig IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, a subject type or the decision type Followup (1) is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT @ItemBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;
SELECT @HistBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(StatusHistoryId, ActionItemId, [Action], ActedBy, ActedOn)), 0) AS VARCHAR(12)) FROM Action_Item_Status_History;

-- A reopen reason of 500 characters with characters that HTML would read (the page encodes them)
SET @Reason500 = N'Reason <b> & "x" ' + REPLICATE(N'w', 483);

BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    -- Departments: A (the Manager's and the User's), B (nobody's here). Committee Z48; meeting 94801 with finalised
    -- minutes (F), meeting 94802 with open minutes. Seven followups (the first character of the action text is the
    -- number used in the checks); the lists below show the made-up items only (Directions ZZ48).
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ48A', 'ZZ48 department A', 987, 1, @Now, @Sys);
    SET @DeptA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ48B', 'ZZ48 department B', 988, 1, @Now, @Sys);
    SET @DeptB = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ48 admin', @DeptA, @Desig, NULL, @rAdmin, 'zz48a@example.invalid', 'zz48adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ48 controller', @DeptA, @Desig, NULL, @rCtl, 'zz48c@example.invalid', 'zz48ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ48 manager', @DeptA, @Desig, NULL, @rMgr, 'zz48m@example.invalid', 'zz48mgr', 'not-a-login', 1, @Now);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ48 user', @DeptA, @Desig, @Mgr, @rUser, 'zz48u@example.invalid', 'zz48usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ48 management', @DeptA, @Desig, NULL, @rMgmt, 'zz48g@example.invalid', 'zz48gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ48 md secretariat', @DeptA, @Desig, NULL, @rMd, 'zz48s@example.invalid', 'zz48mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ48 inactive controller', @DeptA, @Desig, NULL, @rCtl, 'zz48i@example.invalid', 'zz48off', 'not-a-login', 0, @Now);
    SET @Off = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z48', 'ZZ48 committee', '2000-01-01', 1, 0);
    SET @Com = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94801', @Com, 'ZZ48 test', 'ZZ', DATEADD(DAY, -20, @Day), '10:00', DATEADD(DAY, -25, @Day), 'Close', 'F', @Now, @Sys);
    SET @MeetF = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94802', @Com, 'ZZ48 test', 'ZZ', DATEADD(DAY, -15, @Day), '10:00', DATEADD(DAY, -20, @Day), 'Close', 'Open', @Now, @Sys);
    SET @MeetO = SCOPE_IDENTITY();

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT 'ZZ48-' + x.No, @Com, x.MeetingId, x.DepartmentId, @SubjectTypeId, 'ZZ48 item ' + x.No, 'Entry', 'ACA', 'New', @Now, @Usr
    FROM (SELECT '1' AS No, @MeetF AS MeetingId, @DeptA AS DepartmentId
          UNION ALL SELECT '2', @MeetF, @DeptA
          UNION ALL SELECT '3', @MeetF, @DeptA
          UNION ALL SELECT '4', @MeetF, @DeptA
          UNION ALL SELECT '5', @MeetF, @DeptB
          UNION ALL SELECT '6', @MeetO, @DeptA
          UNION ALL SELECT '7', @MeetF, @DeptA) x;

    INSERT INTO Minutes (AgendaId, DecisionTypeId, DueDate, StatusId, CreatedOn, CreatedBy)
    SELECT a.AgendaId, @Followup, CASE WHEN a.AgendaNo IN ('ZZ48-1', 'ZZ48-3') THEN DATEADD(HOUR, 10, DATEADD(DAY, -1, @Day))
                                       ELSE DATEADD(DAY, 5, @Day) END, 0, @Now, @Sys
    FROM Agenda a WHERE a.CommitteeId = @Com;

    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)
    SELECT mi.MinutesId, N'ZZ48', x.Label, '', 0, x.IsConfirmed, DATEADD(DAY, -3, @Day), @Sys
    FROM (SELECT 'ZZ48-1' AS AgendaNo, N'1 pending' AS Label, 0 AS IsConfirmed
          UNION ALL SELECT 'ZZ48-2', N'2 confirmed', 1
          UNION ALL SELECT 'ZZ48-3', N'3 reopened', 0
          UNION ALL SELECT 'ZZ48-4', N'4 confirmed before history', 1
          UNION ALL SELECT 'ZZ48-5', N'5 confirmed, department B', 1
          UNION ALL SELECT 'ZZ48-6', N'6 confirmed, open minutes', 1
          UNION ALL SELECT 'ZZ48-7', N'7 pending, latest row a Confirm', 0) x
    JOIN Agenda a ON a.CommitteeId = @Com AND a.AgendaNo = x.AgendaNo
    JOIN Minutes mi ON mi.AgendaId = a.AgendaId;

    SET @I1 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ48' AND ActionText LIKE N'1 %');
    SET @I2 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ48' AND ActionText LIKE N'2 %');
    SET @I3 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ48' AND ActionText LIKE N'3 %');
    SET @I4 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ48' AND ActionText LIKE N'4 %');
    SET @I5 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ48' AND ActionText LIKE N'5 %');
    SET @I6 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ48' AND ActionText LIKE N'6 %');
    SET @I7 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ48' AND ActionText LIKE N'7 %');

    -- The history, as the Followup page writes it (step 47); item 4 has none (confirmed before step 47)
    INSERT INTO Action_Item_Status_History (ActionItemId, [Action], Reason, ActedBy, ActedOn)
    VALUES (@I2, 'Confirm', NULL, @Ctl, DATEADD(HOUR, 9, DATEADD(DAY, -2, @Day))),
           (@I3, 'Confirm', NULL, @Ctl, DATEADD(HOUR, 9, DATEADD(DAY, -2, @Day))),
           (@I3, 'Reopen', @Reason500, @Off, DATEADD(HOUR, 11, DATEADD(DAY, -2, @Day))),
           (@I5, 'Confirm', NULL, @Ctl, DATEADD(HOUR, 9, DATEADD(DAY, -2, @Day))),
           (@I6, 'Confirm', NULL, @Ctl, DATEADD(HOUR, 9, DATEADD(DAY, -2, @Day))),
           (@I7, 'Confirm', NULL, @Ctl, DATEADD(HOUR, 9, DATEADD(DAY, -2, @Day)));

    -- The user's read row of item 2, as a Confirm leaves it (StatusId 0), not read yet
    INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId) VALUES (@I2, @Usr, 0, 0);

    ---------------------------------------------------------------------------
    -- The card per role (R20, R19): "number:IsReopened:IsOverdue" of the ZZ48 rows
    ---------------------------------------------------------------------------
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Card, the Controller: no confirmed item (2, 4, 5, 6); the reopened 3 with IsReopened 1 and Overdue; 7 (latest row a Confirm) not reopened',
           'Result 1, Reason 0: 1:0:1 3:1:1 7:0:0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ':'
         + ISNULL((SELECT ' ' + LEFT(CAST(ActionText AS VARCHAR(10)), 1) + ':' + CAST(IsReopened AS VARCHAR(2)) + ':' + CAST(IsOverdue AS VARCHAR(2))
                   FROM #AI WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), ' none');
    INSERT INTO @T SELECT 'Card, the Controller: the status columns of the reopened 3 (Reopen, the 500 characters as stored, the inactive user who reopened it, its time)',
           'Reopen | 500 | Reason <b> & "x" | ZZ48 inactive controller | zz48off | 0 | time 11:00',
           ISNULL((SELECT ISNULL(StatusAction, '-') + ' | ' + CAST(LEN(StatusReason) AS VARCHAR(12)) + ' | ' + CAST(LEFT(StatusReason, 16) AS VARCHAR(20))
                         + ' | ' + ISNULL(StatusByName, '-') + ' | ' + ISNULL(StatusByLogin, '-') + ' | ' + ISNULL(CAST(StatusByActive AS VARCHAR(2)), '-')
                         + ' | time ' + CONVERT(VARCHAR(5), StatusOn, 108)
                   FROM #AI WHERE ActionItemId = @I3), 'row missing');
    INSERT INTO @T SELECT 'Card, the Controller: the status columns of 1 (no history: all empty) and 7 (Confirm by the Controller, active, no reason)',
           '1: - - - - 0 | 7: Confirm - ZZ48 controller zz48ctl 1',
           ISNULL((SELECT '1: ' + ISNULL(StatusAction, '-') + ' ' + ISNULL(CAST(StatusReason AS VARCHAR(10)), '-') + ' ' + ISNULL(StatusByName, '-') + ' '
                         + ISNULL(CONVERT(VARCHAR(20), StatusOn, 120), '-') + ' ' + CAST(IsReopened AS VARCHAR(2)) FROM #AI WHERE ActionItemId = @I1), '1: row missing')
         + ' | ' + ISNULL((SELECT '7: ' + ISNULL(StatusAction, '-') + ' ' + ISNULL(CAST(StatusReason AS VARCHAR(10)), '-') + ' ' + ISNULL(StatusByName, '-') + ' '
                         + ISNULL(StatusByLogin, '-') + ' ' + ISNULL(CAST(StatusByActive AS VARCHAR(2)), '-') FROM #AI WHERE ActionItemId = @I7), '7: row missing');

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Gmt, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Card, Management: no confirmed item; 1, 3 (reopened), 7',
           'Result 1, Reason 0: 1:0:1 3:1:1 7:0:0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ':'
         + ISNULL((SELECT ' ' + LEFT(CAST(ActionText AS VARCHAR(10)), 1) + ':' + CAST(IsReopened AS VARCHAR(2)) + ':' + CAST(IsOverdue AS VARCHAR(2))
                   FROM #AI WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), ' none');

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Mgr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Card, the Manager of A: no confirmed item; 1, 3 (reopened), 7',
           'Result 1, Reason 0: 1:0:1 3:1:1 7:0:0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ':'
         + ISNULL((SELECT ' ' + LEFT(CAST(ActionText AS VARCHAR(10)), 1) + ':' + CAST(IsReopened AS VARCHAR(2)) + ':' + CAST(IsOverdue AS VARCHAR(2))
                   FROM #AI WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), ' none');

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Usr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Card, the User of A: no confirmed item (not 2, which he has a read row for); 1, 3 (reopened), 7',
           'Result 1, Reason 0: 1:0:1 3:1:1 7:0:0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ':'
         + ISNULL((SELECT ' ' + LEFT(CAST(ActionText AS VARCHAR(10)), 1) + ':' + CAST(IsReopened AS VARCHAR(2)) + ':' + CAST(IsOverdue AS VARCHAR(2))
                   FROM #AI WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), ' none');

    SET @Txt = '';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Mds, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + 'md ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Adm, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', admin ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Sys, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', system ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Off, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', inactive ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = NULL, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', none ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Card refused, no rows (Reason, rows): MD Secretariat, Admin, the system account, an inactive user, no user',
           'md 4 0, admin 4 0, system 4 0, inactive 8 0, none 8 0', @Txt;

    -- R20: fn_DashboardActionItems gives the rows of the step 43 rule, for every user of the database. The step 43
    -- text is installed here under another name (inside the transaction: the rollback removes it).
    SET @Sql = N'CREATE FUNCTION dbo.fn_ZZ48_ActionItemsOld (@UserId INT, @Today DATE) RETURNS TABLE AS RETURN
SELECT ai.ActionItemId, ai.MinutesId, ai.ActionText, ai.ActionStatus, mi.AgendaId, mi.DecisionTypeId, mi.DueDate, a.AgendaNo,
a.CommitteeId, a.MeetingId, dt.DecisionTypeCode, dt.DecisionTypeName, a.SubjectNo, d.DepartmentCode, d.DepartmentName,
mi.ActualResolution, c.CommitteeName, c.CommitteeCode, mt.MeetingDate, mt.MeetingTime, mt.Venue, u.UserId,
CAST(ISNULL(rs.ReadStatus, 0) AS INT) AS ReadStatus, a.DepartmentId, ai.Directions, ai.IsComplied, ai.IsConfirmed,
CAST(CASE WHEN mi.DueDate IS NOT NULL AND CAST(mi.DueDate AS DATE) < @Today
               AND ISNULL(ai.IsComplied, 0) = 0 AND ISNULL(ai.IsConfirmed, 0) = 0 THEN 1 ELSE 0 END AS INT) AS IsOverdue
FROM Users u
INNER JOIN Roles r ON r.RoleId = u.RoleId
CROSS JOIN Action_Item ai
INNER JOIN Minutes mi ON mi.MinutesId = ai.MinutesId
INNER JOIN Agenda a ON a.AgendaId = mi.AgendaId
INNER JOIN Decision_Type dt ON dt.DecisionTypeId = mi.DecisionTypeId
INNER JOIN Meeting mt ON mt.MeetingId = a.MeetingId
INNER JOIN Committee c ON c.CommitteeId = a.CommitteeId
INNER JOIN Department d ON d.DepartmentId = a.DepartmentId
OUTER APPLY (SELECT MAX(ISNULL(m.ReadStatus, 0)) AS ReadStatus
             FROM ActionItem_User_Map m
             WHERE m.ActionItemId = ai.ActionItemId AND m.UserId = u.UserId) rs
WHERE u.UserId = @UserId
AND u.AccountStatus = 1
AND ISNULL(ai.IsConfirmed, 0) = 0
AND (r.RoleCode IN (''controller'', ''mgmt'')
     OR (r.RoleCode IN (''manager'', ''user'')
         AND ISNULL(mt.MinutesStatus, ''Open'') IN (''F'', ''C'')
         AND a.DepartmentId IN (SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(u.UserId, @Today) s)));';
    EXEC sp_executesql @Sql;

    SET @Sql = N'
SELECT @D1 = COUNT(*) FROM (
    SELECT o.ActionItemId, o.MinutesId, CAST(o.ActionText AS NVARCHAR(MAX)) AS ActionText, o.ActionStatus, o.AgendaId, o.DecisionTypeId, o.DueDate,
           o.AgendaNo, o.CommitteeId, o.MeetingId, o.DecisionTypeCode, o.DecisionTypeName, o.SubjectNo, o.DepartmentCode, o.DepartmentName,
           CAST(o.ActualResolution AS NVARCHAR(MAX)) AS ActualResolution, o.CommitteeName, o.CommitteeCode, o.MeetingDate, o.MeetingTime, o.Venue,
           o.UserId, o.ReadStatus, o.DepartmentId, CAST(o.Directions AS NVARCHAR(MAX)) AS Directions, o.IsComplied, o.IsConfirmed, o.IsOverdue
    FROM Users u CROSS APPLY dbo.fn_ZZ48_ActionItemsOld(u.UserId, @Today) o
    EXCEPT
    SELECT n.ActionItemId, n.MinutesId, CAST(n.ActionText AS NVARCHAR(MAX)), n.ActionStatus, n.AgendaId, n.DecisionTypeId, n.DueDate,
           n.AgendaNo, n.CommitteeId, n.MeetingId, n.DecisionTypeCode, n.DecisionTypeName, n.SubjectNo, n.DepartmentCode, n.DepartmentName,
           CAST(n.ActualResolution AS NVARCHAR(MAX)), n.CommitteeName, n.CommitteeCode, n.MeetingDate, n.MeetingTime, n.Venue,
           n.UserId, n.ReadStatus, n.DepartmentId, CAST(n.Directions AS NVARCHAR(MAX)), n.IsComplied, n.IsConfirmed, n.IsOverdue
    FROM Users u CROSS APPLY dbo.fn_DashboardActionItems(u.UserId, @Today) n) x;
SELECT @D2 = COUNT(*) FROM (
    SELECT n.ActionItemId, n.MinutesId, CAST(n.ActionText AS NVARCHAR(MAX)) AS ActionText, n.ActionStatus, n.AgendaId, n.DecisionTypeId, n.DueDate,
           n.AgendaNo, n.CommitteeId, n.MeetingId, n.DecisionTypeCode, n.DecisionTypeName, n.SubjectNo, n.DepartmentCode, n.DepartmentName,
           CAST(n.ActualResolution AS NVARCHAR(MAX)) AS ActualResolution, n.CommitteeName, n.CommitteeCode, n.MeetingDate, n.MeetingTime, n.Venue,
           n.UserId, n.ReadStatus, n.DepartmentId, CAST(n.Directions AS NVARCHAR(MAX)) AS Directions, n.IsComplied, n.IsConfirmed, n.IsOverdue
    FROM Users u CROSS APPLY dbo.fn_DashboardActionItems(u.UserId, @Today) n
    EXCEPT
    SELECT o.ActionItemId, o.MinutesId, CAST(o.ActionText AS NVARCHAR(MAX)), o.ActionStatus, o.AgendaId, o.DecisionTypeId, o.DueDate,
           o.AgendaNo, o.CommitteeId, o.MeetingId, o.DecisionTypeCode, o.DecisionTypeName, o.SubjectNo, o.DepartmentCode, o.DepartmentName,
           CAST(o.ActualResolution AS NVARCHAR(MAX)), o.CommitteeName, o.CommitteeCode, o.MeetingDate, o.MeetingTime, o.Venue,
           o.UserId, o.ReadStatus, o.DepartmentId, CAST(o.Directions AS NVARCHAR(MAX)), o.IsComplied, o.IsConfirmed, o.IsOverdue
    FROM Users u CROSS APPLY dbo.fn_ZZ48_ActionItemsOld(u.UserId, @Today) o) x;
SELECT @N = COUNT(*) FROM Users u CROSS APPLY dbo.fn_DashboardActionItems(u.UserId, @Today) n;
SELECT @N = @N - COUNT(*) FROM Users u CROSS APPLY dbo.fn_ZZ48_ActionItemsOld(u.UserId, @Today) o;';
    EXEC sp_executesql @Sql, N'@Today DATE, @D1 INT OUTPUT, @D2 INT OUTPUT, @N INT OUTPUT', @Today = @TodayD, @D1 = @Diff1 OUTPUT, @D2 = @Diff2 OUTPUT, @N = @Rows OUTPUT;
    INSERT INTO @T SELECT 'fn_DashboardActionItems against the step 43 rule, every user of the database, 28 columns: rows only in the old, only in the new, difference of the counts',
           '0, 0, 0', ISNULL(CAST(@Diff1 AS VARCHAR(12)), '-') + ', ' + ISNULL(CAST(@Diff2 AS VARCHAR(12)), '-') + ', ' + ISNULL(CAST(@Rows AS VARCHAR(12)), '-');

    INSERT INTO @T SELECT 'fn_DashboardActionItems is the scope function without the confirmed items (the Controller: rows of the scope that are confirmed, rows of the card that are not in the scope)',
           '0, 0',
           CAST((SELECT COUNT(*) FROM dbo.fn_DashboardActionItems(@Ctl, @TodayD) WHERE ISNULL(IsConfirmed, 0) <> 0) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM dbo.fn_DashboardActionItems(@Ctl, @TodayD) f
                 WHERE NOT EXISTS (SELECT 1 FROM dbo.fn_DashboardActionItemScope(@Ctl, @TodayD) s WHERE s.ActionItemId = f.ActionItemId)) AS VARCHAR(12));

    INSERT INTO @T SELECT 'The scope function: the ZZ48 items each person may open (confirmed ones too): Controller, Management, Manager, User, MD Secretariat, inactive',
           'ctl 1234567, mgmt 1234567, mgr 12347, usr 12347, md -, off -',
           'ctl ' + ISNULL((SELECT LEFT(CAST(ActionText AS VARCHAR(10)), 1) FROM dbo.fn_DashboardActionItemScope(@Ctl, @TodayD) WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), '-')
         + ', mgmt ' + ISNULL((SELECT LEFT(CAST(ActionText AS VARCHAR(10)), 1) FROM dbo.fn_DashboardActionItemScope(@Gmt, @TodayD) WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), '-')
         + ', mgr ' + ISNULL((SELECT LEFT(CAST(ActionText AS VARCHAR(10)), 1) FROM dbo.fn_DashboardActionItemScope(@Mgr, @TodayD) WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), '-')
         + ', usr ' + ISNULL((SELECT LEFT(CAST(ActionText AS VARCHAR(10)), 1) FROM dbo.fn_DashboardActionItemScope(@Usr, @TodayD) WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), '-')
         + ', md ' + ISNULL((SELECT LEFT(CAST(ActionText AS VARCHAR(10)), 1) FROM dbo.fn_DashboardActionItemScope(@Mds, @TodayD) WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), '-')
         + ', off ' + ISNULL((SELECT LEFT(CAST(ActionText AS VARCHAR(10)), 1) FROM dbo.fn_DashboardActionItemScope(@Off, @TodayD) WHERE Directions = N'ZZ48' ORDER BY ActionItemId FOR XML PATH('')), '-');

    ---------------------------------------------------------------------------
    -- Opening (R18, R21): "Result, Reason, returned (IsConfirmed, StatusAction), own rows (read, StatusId)"
    ---------------------------------------------------------------------------
    SET @ItemState = (SELECT ISNULL(CAST(ActionText AS VARCHAR(100)), '') + '|' + CAST(IsComplied AS VARCHAR(2)) + CAST(IsConfirmed AS VARCHAR(2))
                             + '|' + CONVERT(VARCHAR(30), UpdatedOn, 126) + '|' + CAST(UpdatedBy AS VARCHAR(12)) FROM Action_Item WHERE ActionItemId = @I2);
    SET @HistCount = (SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId IN (@I1, @I2, @I3, @I4, @I5, @I6, @I7));

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Ctl, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the Controller opens the confirmed 2 (a stale row): returned confirmed, with who confirmed it; his read row is created read, StatusId 0',
           'Result 1, Reason 0, returned 1 (confirmed 1, Confirm by zz48ctl), own rows 1 (read 1, StatusId 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12))
         + ' (confirmed ' + ISNULL((SELECT CAST(MAX(IsConfirmed) AS VARCHAR(2)) + ', ' + ISNULL(MAX(StatusAction), '-') + ' by ' + ISNULL(MAX(StatusByLogin), '-') FROM #AI), '-') + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Ctl) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Ctl), 0) AS VARCHAR(12))
         + ', StatusId ' + ISNULL((SELECT CAST(MAX(StatusId) AS VARCHAR(2)) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Ctl), '-') + ')';

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Gmt, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: Management opens the confirmed 2: returned confirmed; its read row is created read, StatusId 0',
           'Result 1, Reason 0, returned 1 (confirmed 1, Confirm by zz48ctl), own rows 1 (read 1, StatusId 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12))
         + ' (confirmed ' + ISNULL((SELECT CAST(MAX(IsConfirmed) AS VARCHAR(2)) + ', ' + ISNULL(MAX(StatusAction), '-') + ' by ' + ISNULL(MAX(StatusByLogin), '-') FROM #AI), '-') + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Gmt) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Gmt), 0) AS VARCHAR(12))
         + ', StatusId ' + ISNULL((SELECT CAST(MAX(StatusId) AS VARCHAR(2)) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Gmt), '-') + ')';

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Mgr, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the Manager opens the confirmed 2 of his department: returned confirmed; his read row is created read, StatusId 0',
           'Result 1, Reason 0, returned 1 (confirmed 1, Confirm by zz48ctl), own rows 1 (read 1, StatusId 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12))
         + ' (confirmed ' + ISNULL((SELECT CAST(MAX(IsConfirmed) AS VARCHAR(2)) + ', ' + ISNULL(MAX(StatusAction), '-') + ' by ' + ISNULL(MAX(StatusByLogin), '-') FROM #AI), '-') + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Mgr) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Mgr), 0) AS VARCHAR(12))
         + ', StatusId ' + ISNULL((SELECT CAST(MAX(StatusId) AS VARCHAR(2)) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Mgr), '-') + ')';

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the User opens the confirmed 2 (his unread row of the Confirm): returned confirmed; the same row, now read, StatusId still 0 (no second row)',
           'Result 1, Reason 0, returned 1 (confirmed 1, Confirm by zz48ctl), own rows 1 (read 1, StatusId 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12))
         + ' (confirmed ' + ISNULL((SELECT CAST(MAX(IsConfirmed) AS VARCHAR(2)) + ', ' + ISNULL(MAX(StatusAction), '-') + ' by ' + ISNULL(MAX(StatusByLogin), '-') FROM #AI), '-') + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Usr) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Usr), 0) AS VARCHAR(12))
         + ', StatusId ' + ISNULL((SELECT CAST(MAX(StatusId) AS VARCHAR(2)) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Usr), '-') + ')';

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the User opens 2 a second time: still one row',
           'Result 1, own rows 1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Usr) AS VARCHAR(12));

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I4, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the User opens 4, confirmed before history: returned confirmed, no status row (the page shows "Confirmed (before history)")',
           'Result 1, Reason 0, returned 1 (confirmed 1, - by -)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12))
         + ' (confirmed ' + ISNULL((SELECT CAST(MAX(IsConfirmed) AS VARCHAR(2)) + ', ' + ISNULL(MAX(StatusAction), '-') + ' by ' + ISNULL(MAX(StatusByLogin), '-') FROM #AI), '-') + ')';

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I3, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the User opens the reopened 3: returned not confirmed, reopened, with the reason; his read row created read, StatusId 1',
           'Result 1, Reason 0, returned 1 (confirmed 0, reopened 1, reason 500), own rows 1 (read 1, StatusId 1)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12))
         + ' (confirmed ' + ISNULL((SELECT CAST(MAX(IsConfirmed) AS VARCHAR(2)) + ', reopened ' + CAST(MAX(IsReopened) AS VARCHAR(2)) + ', reason ' + CAST(MAX(LEN(StatusReason)) AS VARCHAR(12)) FROM #AI), '-') + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I3 AND UserId = @Usr) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I3 AND UserId = @Usr), 0) AS VARCHAR(12))
         + ', StatusId ' + ISNULL((SELECT CAST(MAX(StatusId) AS VARCHAR(2)) FROM ActionItem_User_Map WHERE ActionItemId = @I3 AND UserId = @Usr), '-') + ')';

    SET @Txt = '';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I5, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + 'usr 5: ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I5 AND UserId = @Usr) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I6, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', usr 6: ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I6 AND UserId = @Usr) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Mgr, @ActionItemId = @I5, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', mgr 5: ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I5 AND UserId = @Mgr) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Mds, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', md 2: ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Mds) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Adm, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', admin 2: ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Adm) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Sys, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', system 2: ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Sys) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Off, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', inactive 2: ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Off) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Ctl, @ActionItemId = -1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', unknown: ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Open refused, nothing returned or written (Reason, rows, own rows): confirmed outside the scope (another department, open minutes), the other roles, inactive, unknown',
           'usr 5: 4 0 0, usr 6: 4 0 0, mgr 5: 4 0 0, md 2: 4 0 0, admin 2: 4 0 0, system 2: 4 0 0, inactive 2: 8 0 0, unknown: 4 0', @Txt;

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Ctl, @ActionItemId = @I5, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the Controller opens the confirmed 5 of department B (every department is his): returned confirmed',
           'Result 1, Reason 0, returned 1 (confirmed 1)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12))
         + ' (confirmed ' + ISNULL((SELECT CAST(MAX(IsConfirmed) AS VARCHAR(2)) FROM #AI), '-') + ')';

    INSERT INTO @T SELECT 'Opening changed nothing of the confirmed 2 itself (text, flags, UpdatedOn, UpdatedBy) and wrote no history row', @ItemState + ' | ' + CAST(@HistCount AS VARCHAR(12)),
           (SELECT ISNULL(CAST(ActionText AS VARCHAR(100)), '') + '|' + CAST(IsComplied AS VARCHAR(2)) + CAST(IsConfirmed AS VARCHAR(2))
                 + '|' + CONVERT(VARCHAR(30), UpdatedOn, 126) + '|' + CAST(UpdatedBy AS VARCHAR(12)) FROM Action_Item WHERE ActionItemId = @I2)
         + ' | ' + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId IN (@I1, @I2, @I3, @I4, @I5, @I6, @I7)) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Saving (R16): "Result, Reason, text"
    ---------------------------------------------------------------------------
    SET @Txt = '';
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = @I2, @ActionText = N'ZZ48 by controller', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + 'ctl ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Mgr, @ActionItemId = @I2, @ActionText = N'ZZ48 by manager', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', mgr ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Usr, @ActionItemId = @I2, @ActionText = N'ZZ48 by user', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', usr ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Usr, @ActionItemId = @I4, @ActionText = N'ZZ48 by user', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', usr 4 ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = @I5, @ActionText = N'ZZ48 by controller', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', ctl 5 ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    INSERT INTO @T SELECT 'Save of a confirmed item in the person''s scope: Reason 26 for the Controller, the Manager and the User (2), the User (4, before history), the Controller (5)',
           'ctl 0 26, mgr 0 26, usr 0 26, usr 4 0 26, ctl 5 0 26', @Txt;

    SET @Txt = '';
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Gmt, @ActionItemId = @I2, @ActionText = N'ZZ48 by management', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + 'mgmt 2: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Gmt, @ActionItemId = @I1, @ActionText = N'ZZ48 by management', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', mgmt 1: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Mds, @ActionItemId = @I2, @ActionText = N'ZZ48 by md', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', md 2: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Adm, @ActionItemId = @I2, @ActionText = N'ZZ48 by admin', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', admin 2: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Sys, @ActionItemId = @I2, @ActionText = N'ZZ48 by system', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', system 2: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Usr, @ActionItemId = @I5, @ActionText = N'ZZ48 by user', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', usr 5: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Usr, @ActionItemId = @I6, @ActionText = N'ZZ48 by user', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', usr 6: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = -1, @ActionText = N'ZZ48 unknown', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', unknown: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Off, @ActionItemId = @I2, @ActionText = N'ZZ48 by inactive', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', inactive 2: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = NULL, @ActionItemId = @I2, @ActionText = N'ZZ48 by nobody', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', none 2: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    INSERT INTO @T SELECT 'Save refused before the confirmed check: Management (confirmed 2 and Pending 1), MD Secretariat, Admin, the system account Reason 4; outside the scope and unknown Reason 4; inactive and no user Reason 8',
           'mgmt 2: 0 4, mgmt 1: 0 4, md 2: 0 4, admin 2: 0 4, system 2: 0 4, usr 5: 0 4, usr 6: 0 4, unknown: 0 4, inactive 2: 0 8, none 2: 0 8', @Txt;

    INSERT INTO @T SELECT 'Nothing of the refused saves was written (texts of 1, 2, 4, 5 and 6 as made)',
           '1 pending; 2 confirmed; 4 confirmed before history; 5 confirmed, department B; 6 confirmed, open minutes',
           ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId IN (@I1, @I2, @I4, @I5, @I6) ORDER BY ActionItemId FOR XML PATH('')), 1, 2, ''), 'none');

    SET @Txt = '';
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Usr, @ActionItemId = @I1, @ActionText = N'1 saved by the user', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + 'usr 1: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Mgr, @ActionItemId = @I3, @ActionText = N'3 saved by the manager', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', mgr 3: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = @I7, @ActionText = N'7 saved by the controller', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', ctl 7: ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    INSERT INTO @T SELECT 'Save of a Pending item (1), a reopened item (3) and an item whose latest row is a Confirm but which is Pending (7): saved',
           'usr 1: 1 0, mgr 3: 1 0, ctl 7: 1 0 | 1 saved by the user; 3 saved by the manager; 7 saved by the controller',
           @Txt + ' | ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId IN (@I1, @I3, @I7) ORDER BY ActionItemId FOR XML PATH('')), 1, 2, ''), 'none');

    INSERT INTO @T SELECT 'The saves wrote the action text only: the flags of 1, 3 and 7 and every history row as before',
           '0 0, 0 0, 0 0 | ' + CAST(@HistCount AS VARCHAR(12)),
           ISNULL(STUFF((SELECT ', ' + CAST(IsComplied AS VARCHAR(2)) + ' ' + CAST(IsConfirmed AS VARCHAR(2)) FROM Action_Item WHERE ActionItemId IN (@I1, @I3, @I7) ORDER BY ActionItemId FOR XML PATH('')), 1, 2, ''), 'none')
         + ' | ' + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId IN (@I1, @I2, @I3, @I4, @I5, @I6, @I7)) AS VARCHAR(12));

    -- Inside a caller's transaction the save writes in it and never ends it (refused or saved)
    SET @Tran = @@TRANCOUNT;
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = @I2, @ActionText = N'ZZ48 again', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = CAST(@Tran AS VARCHAR(3)) + ' ' + CAST(@@TRANCOUNT AS VARCHAR(3)) + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = @I1, @ActionText = N'1 saved again', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', ' + CAST(@@TRANCOUNT AS VARCHAR(3)) + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    INSERT INTO @T SELECT 'Inside the caller''s transaction: open before and after a refused save (26) and a save (0)', '1 1 26, 1 0', @Txt;
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
INSERT INTO @T SELECT 'After the rollback: step 48 is installed (markers in the five objects), the function of the test is gone', '5, 0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardActionItemScope'), ('fn_DashboardActionItems'), ('spr_GetDashboardActionItems'),
                                          ('spr_OpenDashboardActionItem'), ('spr_SaveDashboardActionText')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardFollowupFinal-Step48%') AS VARCHAR(12)) + ', '
     + CASE WHEN OBJECT_ID('dbo.fn_ZZ48_ActionItemsOld') IS NULL THEN '0' ELSE '1' END;

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
SELECT 'After the test: no ZZ48 department, user, committee, meeting, action item or history row left', '0 0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ48%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz48%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z48') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ48 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ48') AS VARCHAR(12)) + ' '
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

DROP TABLE #AI;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
