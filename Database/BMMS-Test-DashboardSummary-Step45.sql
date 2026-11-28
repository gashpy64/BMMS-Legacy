/* ============================================================================
   BMMS - Test of step 45 (Dashboard summary cards, the filters on every
   Dashboard card, statistics for the MD Secretariat; step UN6c2b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 45
   is not installed.

   Run it in a NEW query window (it uses temporary tables of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS.

   Part 1 reads only: the markers (those of step 45 and those of the earlier
   steps in the three replaced procedures), parameters and result columns;
   that the objects step 45 does not change carry no marker and are the
   texts of before; no feature above compatibility level 100 in the five
   texts; that every database user who can run step 42's procedure can run
   the procedures of this step; the condition the step 44 Rollback refuses
   on (step 45 installed) is met.

   Step 48 (step FU2a) replaced spr_GetDashboardActionItems and
   fn_DashboardActionItems: seven status columns after IsOverdue, the same
   rows. With step 48 installed (its marker DashboardFollowupFinal-Step48)
   this script expects the 35 columns and the step 48 text (SHA-1) of
   fn_DashboardActionItems, and the table #AI gets the seven columns;
   without step 48 it expects what step 45 gave. Every other check is as it
   was.

   Part 2, inside ONE transaction that is rolled back (made-up data ZZ45:
   three departments, the six roles, an inactive user, an active, a second
   active and an INACTIVE committee, scheduled meetings dated today, later
   and without a date, completed meetings with finalised minutes, items in
   every status in every department, action items):
     - the Committee filter function: 0 and an active committee allowed; an
       inactive, unknown, negative or NULL id not;
     - spr_GetDashboardSummary: for every active user of the four roles with
       cards, every committee value (0 and each active committee) and every
       department value of the scope: the two counts equal an independent
       count (status codes and departments read straight from the tables)
       AND the totals of the columns In progress and Rejected of the
       Scheduled list of spr_GetDashboardMeetings; fixed values on ZZ45;
       Reason 12, 8 and 4;
     - an inactive, unknown and negative committee refused with Reason 4 by
       all four procedures for every role that has the block;
     - the MD Secretariat: statistics shown, row by row the counts of
       Management, no Waiting for me, no My approvals, no Action Items;
     - the earlier texts (steps 44 and 43) beside the new ones under
       temporary names, on every active user x committee value x department
       value: the meeting list, My approvals and the Action Items card give
       the same as before in every case but the two changes of this step
       (the MD Secretariat's statistics; an inactive committee); the Action
       Items card with a committee or a department chosen gives the rows of
       before of that committee and that department;
     - the Rollback's three batches (the texts of steps 44 and 43) run here,
       and their SHA-1 is compared with the texts step 45 was built from;
       the rollback of the transaction puts step 45 back.

   Afterwards: nothing of ZZ45 is left, the agenda, minutes, action item and
   alert tables are unchanged and every identity counter is put back.

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
ELSE IF (OBJECT_ID('dbo.fn_DashboardCommitteeFilter', 'IF') IS NULL
         OR OBJECT_ID('dbo.spr_GetDashboardSummary', 'P') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') NOT LIKE '%DashboardSummary-Step45%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), '') NOT LIKE '%DashboardSummary-Step45%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') NOT LIKE '%DashboardSummary-Step45%')
BEGIN
    RAISERROR('Step 45 (BMMS-Fix-DashboardSummary-Step45.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('tempdb..#T') IS NOT NULL OR OBJECT_ID('tempdb..#Ident') IS NOT NULL OR OBJECT_ID('tempdb..#MT') IS NOT NULL
         OR OBJECT_ID('tempdb..#MO') IS NOT NULL OR OBJECT_ID('tempdb..#MG') IS NOT NULL OR OBJECT_ID('tempdb..#AP') IS NOT NULL
         OR OBJECT_ID('tempdb..#APO') IS NOT NULL OR OBJECT_ID('tempdb..#AI') IS NOT NULL OR OBJECT_ID('tempdb..#AIO') IS NOT NULL)
BEGIN
    RAISERROR('This query window still has temporary tables of an earlier run. Open a NEW query window and run the script there. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(1000), Actual VARCHAR(1000));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
-- The meeting list (new, old, and the new list of the Management user for the MD Secretariat comparison)
CREATE TABLE #MT (MeetingId INT, CommitteeId INT, CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), MeetingNo VARCHAR(50),
                  MeetingDate DATETIME, MeetingTime VARCHAR(50), AgendaSubmissionDate DATETIME, ListCode CHAR(1), StateCode VARCHAR(50),
                  StateLabel VARCHAR(100), Items INT, Approved INT, Rejected INT, Pending INT, WaitingForMe INT);
CREATE TABLE #MO (MeetingId INT, CommitteeId INT, CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), MeetingNo VARCHAR(50),
                  MeetingDate DATETIME, MeetingTime VARCHAR(50), AgendaSubmissionDate DATETIME, ListCode CHAR(1), StateCode VARCHAR(50),
                  StateLabel VARCHAR(100), Items INT, Approved INT, Rejected INT, Pending INT, WaitingForMe INT);
CREATE TABLE #MG (MeetingId INT, CommitteeId INT, CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), MeetingNo VARCHAR(50),
                  MeetingDate DATETIME, MeetingTime VARCHAR(50), AgendaSubmissionDate DATETIME, ListCode CHAR(1), StateCode VARCHAR(50),
                  StateLabel VARCHAR(100), Items INT, Approved INT, Rejected INT, Pending INT, WaitingForMe INT);
-- My approvals (new, old)
CREATE TABLE #AP (RowNo INT, AgendaId INT, AgendaNo VARCHAR(50), SubjectNo INT, ShortText NVARCHAR(MAX), AgendaStatusCode VARCHAR(50),
                  CommitteeId INT, CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), MeetingId INT, MeetingNo VARCHAR(50),
                  MeetingDate DATETIME, DepartmentId INT, DepartmentName NVARCHAR(200), AlertId INT);
CREATE TABLE #APO (RowNo INT, AgendaId INT, AgendaNo VARCHAR(50), SubjectNo INT, ShortText NVARCHAR(MAX), AgendaStatusCode VARCHAR(50),
                   CommitteeId INT, CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), MeetingId INT, MeetingNo VARCHAR(50),
                   MeetingDate DATETIME, DepartmentId INT, DepartmentName NVARCHAR(200), AlertId INT);
-- The Action Items card (new, old)
CREATE TABLE #AI (ActionItemId INT, MinutesId INT, ActionText NVARCHAR(MAX), ActionStatus VARCHAR(50), AgendaId INT, DecisionTypeId INT,
                  DueDate DATETIME, AgendaNo VARCHAR(50), CommitteeId INT, MeetingId INT, DecisionTypeCode VARCHAR(50), DecisionTypeName VARCHAR(200),
                  SubjectNo INT, DepartmentCode VARCHAR(50), DepartmentName NVARCHAR(200), ActualResolution NVARCHAR(MAX), CommitteeName NVARCHAR(200),
                  CommitteeCode VARCHAR(50), MeetingDate DATETIME, MeetingTime VARCHAR(50), Venue NVARCHAR(500), UserId INT, ReadStatus INT,
                  DepartmentId INT, Directions NVARCHAR(MAX), IsComplied INT, IsConfirmed INT, IsOverdue INT);
CREATE TABLE #AIO (ActionItemId INT, MinutesId INT, ActionText NVARCHAR(MAX), ActionStatus VARCHAR(50), AgendaId INT, DecisionTypeId INT,
                   DueDate DATETIME, AgendaNo VARCHAR(50), CommitteeId INT, MeetingId INT, DecisionTypeCode VARCHAR(50), DecisionTypeName VARCHAR(200),
                   SubjectNo INT, DepartmentCode VARCHAR(50), DepartmentName NVARCHAR(200), ActualResolution NVARCHAR(MAX), CommitteeName NVARCHAR(200),
                   CommitteeCode VARCHAR(50), MeetingDate DATETIME, MeetingTime VARCHAR(50), Venue NVARCHAR(500), UserId INT, ReadStatus INT,
                   DepartmentId INT, Directions NVARCHAR(MAX), IsComplied INT, IsConfirmed INT, IsOverdue INT);
-- Step 48 (step FU2a) installed: spr_GetDashboardActionItems returns seven status columns more (INSERT ... EXEC needs
-- the same columns); #AIO holds the rows of the old text (28 columns) and stays as it is
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%')
    ALTER TABLE #AI ADD IsReopened INT, StatusAction VARCHAR(10), StatusReason NVARCHAR(500), StatusOn DATETIME,
                        StatusByName NVARCHAR(200), StatusByLogin NVARCHAR(200), StatusByActive INT;

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
INSERT INTO #T SELECT 'Marker DashboardSummary-Step45 in the two new objects and the three replaced procedures', '5',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardCommitteeFilter'), ('spr_GetDashboardSummary'), ('spr_GetDashboardMeetings'),
                                          ('spr_GetDashboardApprovals'), ('spr_GetDashboardActionItems')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardSummary-Step45%') AS VARCHAR(12));

INSERT INTO #T SELECT 'The replaced procedures keep the markers of their earlier steps (meetings 42 and 44, approvals 44, action items 43)', '4 of 4',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')) LIKE '%DashboardMeetings-Step42%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')) LIKE '%AgendaWaitingFor-Step44%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')) LIKE '%AgendaWaitingFor-Step44%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')) LIKE '%DashboardAlerts-Step43%' THEN 1 ELSE 0 END AS VARCHAR(2)) + ' of 4';

INSERT INTO #T SELECT 'Parameters (all, OUTPUT): summary 7 4, meetings 8 5, approvals 8 4, action items 5 2, committee function 1 0', '7 4, 8 5, 8 4, 5 2, 1 0',
       STUFF((SELECT ', ' + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.' + o.Name) AND p.parameter_id > 0) AS VARCHAR(12))
                     + ' ' + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.' + o.Name) AND p.is_output = 1 AND p.parameter_id > 0) AS VARCHAR(12))
              FROM (VALUES (1, 'spr_GetDashboardSummary'), (2, 'spr_GetDashboardMeetings'), (3, 'spr_GetDashboardApprovals'),
                           (4, 'spr_GetDashboardActionItems'), (5, 'fn_DashboardCommitteeFilter')) o(Seq, Name)
              ORDER BY o.Seq FOR XML PATH('')), 1, 2, '');

INSERT INTO #T SELECT 'spr_GetDashboardActionItems: the three parameters of before in their order, then @CommitteeId and @DepartmentId',
       '@ActingUserId,@Result,@Reason,@CommitteeId,@DepartmentId',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetDashboardActionItems') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '');

INSERT INTO #T SELECT 'spr_GetDashboardSummary: the parameters in their order',
       '@ActingUserId,@CommitteeId,@DepartmentId,@Result,@Reason,@InProgress,@Rejected',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetDashboardSummary') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '');

INSERT INTO #T SELECT 'spr_GetDashboardMeetings and spr_GetDashboardApprovals: the parameters of before in their order',
       '@ActingUserId,@CommitteeId,@DepartmentId,@Result,@Reason,@StatisticsShown,@ActingRoleCode,@WaitingShown | @ActingUserId,@CommitteeId,@DepartmentId,@PageNo,@Result,@Reason,@TotalRows,@PageShown',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetDashboardMeetings') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '')
     + ' | ' + STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetDashboardApprovals') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '');

DECLARE @Cols VARCHAR(MAX);
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardMeetings'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardMeetings: the sixteen result columns of before, in their order',
       'MeetingId,CommitteeId,CommitteeCode,CommitteeName,MeetingNo,MeetingDate,MeetingTime,AgendaSubmissionDate,ListCode,StateCode,StateLabel,Items,Approved,Rejected,Pending,WaitingForMe', @Cols;
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardApprovals'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardApprovals: the result columns of before, in their order',
       'RowNo,AgendaId,AgendaNo,SubjectNo,ShortText,AgendaStatusCode,CommitteeId,CommitteeCode,CommitteeName,MeetingId,MeetingNo,MeetingDate,DepartmentId,DepartmentName,AlertId', @Cols;
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardActionItems'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardActionItems: the columns of View_Action_Item_Users and IsOverdue, as before (with step 48 installed: and the seven status columns)',
       'ActionItemId,MinutesId,ActionText,ActionStatus,AgendaId,DecisionTypeId,DueDate,AgendaNo,CommitteeId,MeetingId,DecisionTypeCode,DecisionTypeName,SubjectNo,DepartmentCode,DepartmentName,ActualResolution,CommitteeName,CommitteeCode,MeetingDate,MeetingTime,Venue,UserId,ReadStatus,DepartmentId,Directions,IsComplied,IsConfirmed,IsOverdue'
       + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%'
              THEN ',IsReopened,StatusAction,StatusReason,StatusOn,StatusByName,StatusByLogin,StatusByActive' ELSE '' END, @Cols;
INSERT INTO #T SELECT 'spr_GetDashboardSummary returns no result set (the counts are outputs); the committee function returns the column Allowed', '0 | Allowed',
       CAST((SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardSummary'), 0)) AS VARCHAR(12)) + ' | '
     + ISNULL(STUFF((SELECT ',' + c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.fn_DashboardCommitteeFilter') ORDER BY c.column_id FOR XML PATH('')), 1, 1, ''), '-');

INSERT INTO #T SELECT 'Objects step 45 does not change carry no DashboardSummary-Step45 marker (status groups, meeting state, scope, waiting-for, action item and alert functions, alerts, alert count, committee list)', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_AgendaStatusGroup'), ('fn_MeetingDashboardState'), ('fn_UserDepartmentScope'), ('fn_AgendaWaitingFor'),
                                          ('fn_DashboardActionItems'), ('fn_DashboardAlerts'), ('spr_GetDashboardAlerts'), ('spr_GetAlertCount'),
                                          ('spr_GetDashboardDepartments'), ('spr_GetCommittee')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardSummary-Step45%') AS VARCHAR(12));

-- The one status definition and the action item rule are the texts of steps 42 and 43 (SHA-1 as installed by them)
DECLARE @D NVARCHAR(MAX), @I INT, @GroupHash VARCHAR(400), @ActFnHash VARCHAR(400);
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_AgendaStatusGroup')), CHAR(13), ''); SET @GroupHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @GroupHash = @GroupHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), CHAR(13), ''); SET @ActFnHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @ActFnHash = @ActFnHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
-- Step 48 (step FU2a) replaced fn_DashboardActionItems: with its marker, the step 48 text is expected
INSERT INTO #T SELECT 'fn_AgendaStatusGroup and fn_DashboardActionItems are the texts of steps 42 and 43 (with step 48 installed: of step 48) (SHA-1): one status definition, one action item rule', 'same, same',
       CASE WHEN @GroupHash = '39AFA7C8133CDBC5CB158861799144F6229E27BA' THEN 'same' ELSE 'differs' END + ', '
     + CASE WHEN @ActFnHash = CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')), '') LIKE '%DashboardFollowupFinal-Step48%'
                                   THEN '842025D6BF2609C53F16EC77116538F9D7FCE368'
                                   ELSE '61E1A276292DFC2D87B1D020A7BF22E62EF9D0F1' END THEN 'same' ELSE 'differs' END;

INSERT INTO #T SELECT 'No feature above compatibility level 100 in the five texts (THROW, IIF, CONCAT, FORMAT, TRY_CONVERT, OFFSET, STRING_AGG, EOMONTH)', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardCommitteeFilter'), ('spr_GetDashboardSummary'), ('spr_GetDashboardMeetings'),
                                          ('spr_GetDashboardApprovals'), ('spr_GetDashboardActionItems')) o(Name)
             CROSS JOIN (VALUES ('%THROW%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('%TRY[_]CONVERT%'), ('% OFFSET %'), ('%STRING[_]AGG%'), ('%EOMONTH%')) f(Pattern)
             WHERE UPPER(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name))) LIKE f.Pattern) AS VARCHAR(12));

-- The step 44 Rollback refuses while step 45 is installed: its condition (the same five tests) is met now
INSERT INTO #T SELECT 'The condition on which BMMS-Rollback-AgendaWaitingFor-Step44.sql refuses (step 45 installed) is met', 'met',
       CASE WHEN OBJECT_ID('dbo.fn_DashboardCommitteeFilter') IS NOT NULL
                 OR OBJECT_ID('dbo.spr_GetDashboardSummary') IS NOT NULL
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') LIKE '%DashboardSummary-Step45%'
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), '') LIKE '%DashboardSummary-Step45%'
                 OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), '') LIKE '%DashboardSummary-Step45%'
            THEN 'met' ELSE 'not met' END;
GO

-- Every database user who can run step 42's spr_GetDashboardDepartments (the application login among them) can run the
-- four procedures of this step. Asked of the server as that user (EXECUTE AS USER), so a schema grant counts.
DECLARE @Name SYSNAME, @Can INT, @Users INT = 0, @Cannot INT = 0, @Names VARCHAR(500) = '';
DECLARE UserCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT dp.name FROM sys.database_principals dp
    WHERE dp.type IN ('S', 'U', 'G') AND dp.name NOT IN ('dbo', 'guest', 'sys', 'INFORMATION_SCHEMA');
OPEN UserCursor;
FETCH NEXT FROM UserCursor INTO @Name;
WHILE (@@FETCH_STATUS = 0)
BEGIN
    BEGIN TRY
        EXECUTE AS USER = @Name;
        SET @Can = CASE WHEN HAS_PERMS_BY_NAME('dbo.spr_GetDashboardDepartments', 'OBJECT', 'EXECUTE') = 1 THEN
                        HAS_PERMS_BY_NAME('dbo.spr_GetDashboardSummary', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetDashboardMeetings', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetDashboardApprovals', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetDashboardActionItems', 'OBJECT', 'EXECUTE') ELSE -1 END;
        REVERT;
        IF (@Can >= 0) SET @Users = @Users + 1;
        IF (@Can >= 0 AND @Can < 4)
        BEGIN
            SET @Cannot = @Cannot + 1;
            SET @Names = LEFT(@Names + ' ' + @Name, 500);
        END
    END TRY
    BEGIN CATCH
        -- a user that cannot be impersonated (no login behind it) cannot sign in either: not counted
        SET @Can = -1;
    END CATCH
    FETCH NEXT FROM UserCursor INTO @Name;
END
CLOSE UserCursor;
DEALLOCATE UserCursor;
INSERT INTO #T SELECT 'EXECUTE: database users who can run step 42''s department procedure but not all four procedures of step 45 (' + CAST(@Users AS VARCHAR(12)) + ' such users asked)',
       '0', CAST(@Cannot AS VARCHAR(12)) + CASE WHEN @Cannot > 0 THEN ':' + @Names ELSE '' END;
GO

-------------------------------------------------------------------------------
-- Part 2
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(1000), Actual VARCHAR(1000));
DECLARE @CaseUsers TABLE (UserId INT PRIMARY KEY, RoleCode VARCHAR(50));
DECLARE @CaseComs TABLE (CommitteeId INT PRIMARY KEY);
DECLARE @CaseDepts TABLE (UserId INT, DepartmentId INT, PRIMARY KEY (UserId, DepartmentId));
DECLARE @Scope TABLE (DepartmentId INT PRIMARY KEY);

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @rMd INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @Followup INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type ORDER BY DecisionTypeId);
DECLARE @Unknown INT = (SELECT ISNULL(MAX(CommitteeId), 0) + 1000 FROM Committee);
DECLARE @DA INT, @DB INT, @DC INT, @CZ INT, @CY INT, @CW INT;
DECLARE @Ctl INT, @Gmt INT, @MgAB INT, @MgC INT, @UsrA INT, @Mds INT, @Adm INT, @Off INT;
DECLARE @Res INT, @Rsn INT, @Shown INT, @Wait INT, @Total INT, @Page INT, @InP INT, @Rej INT, @Role VARCHAR(50);
DECLARE @oRes INT, @oRsn INT, @oShown INT, @oWait INT, @oTotal INT, @oPage INT, @oRole VARCHAR(50);
DECLARE @IndP INT, @IndR INT, @SumP INT, @SumR INT, @ExpRsn INT;
DECLARE @dRes INT, @dRsn INT, @dShown INT, @dWait INT, @dRole VARCHAR(50);
DECLARE @cUser INT, @cRole VARCHAR(50), @cCom INT, @cDept INT, @cScoped INT;
DECLARE @N INT, @Bad INT, @NMd INT, @GoodMd INT, @Txt VARCHAR(1000), @NewS NVARCHAR(MAX), @OldS NVARCHAR(MAX), @GmtS NVARCHAR(MAX);
DECLARE @AgendaBefore VARCHAR(60), @AgendaAfter VARCHAR(60), @MinBefore VARCHAR(60), @MinAfter VARCHAR(60), @ActBefore VARCHAR(60), @ActAfter VARCHAR(60);
DECLARE @MapBefore VARCHAR(60), @MapAfter VARCHAR(60);
DECLARE @Hd NVARCHAR(MAX), @Hi INT, @MeetHash VARCHAR(400), @ApprHash VARCHAR(400), @ActHash VARCHAR(400);
DECLARE @OldMeet NVARCHAR(MAX), @OldAppr NVARCHAR(MAX), @OldAct NVARCHAR(MAX);
DECLARE @OldMeetTmp NVARCHAR(MAX), @OldApprTmp NVARCHAR(MAX), @OldActTmp NVARCHAR(MAX);
DECLARE @Started DATETIME, @Ms INT;

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMd IS NULL
    OR @Desig IS NULL OR @SubjectTypeId IS NULL OR @Followup IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, a subject type or a decision type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MeetingId, DepartmentId, UpdatedOn)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MinBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, AgendaId, DecisionTypeId, DueDate, StatusId)), 0) AS VARCHAR(12)) FROM Minutes;
SELECT @ActBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, IsComplied, IsConfirmed, UpdatedOn)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;

-- The earlier texts (steps 44 and 43): as the Rollback script has them (sqlcmd sends a batch with the line break before
-- its GO, so each ends with one), and under temporary names
SET @OldMeet = N'
-- Dashboard meeting list (DashboardMeetings-Step42, step UN6b), for all six roles. The role and the departments come
-- from the database (the acting user id); the two filters are checked against them:
--   @CommitteeId   0: every committee; otherwise it must exist (any role), else Reason 4
--   @DepartmentId  0: all of a Manager''s or a User''s departments; otherwise it must be one of them (Manager and User
--                  only), else Reason 4
-- Reason 8: acting user missing or inactive; Reason 4: a role outside the six or a filter outside the scope; then
-- no rows. Rows: every scheduled meeting (no cap), then the last 10 completed meetings for EVERY role (for a Manager
-- and a User only completed meetings with an item of the chosen department(s)). Statistics (fn_AgendaStatusGroup,
-- Pending = AC + AMA) for the Controller, Management, the Manager and the User (for the last two over the chosen
-- department(s) only); NULL and @StatisticsShown 0 for MD Secretariat and Admin.
-- AgendaWaitingFor-Step44 (step UN6c2a): the column WaitingForMe (last) and the output @WaitingShown (last): for a
-- Controller and a Manager the number of items of a SCHEDULED meeting that wait for this person''s approval
-- (fn_AgendaWaitingFor, IsWaiting; for a Manager within the chosen department); NULL on completed meetings and for
-- every other role (@WaitingShown 0). Everything else is unchanged.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardMeetings]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@DepartmentId INT = 0,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@StatisticsShown INT = NULL OUTPUT,
@ActingRoleCode VARCHAR(50) = NULL OUTPUT,
@WaitingShown INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
DECLARE @Today DATE;
DECLARE @DeptScoped INT;
DECLARE @Dept TABLE (DepartmentId INT PRIMARY KEY);
DECLARE @List TABLE (MeetingId INT PRIMARY KEY, ListCode CHAR(1));
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @StatisticsShown = 0;
	SET @WaitingShown = 0;
	SET @ActingRoleCode = NULL;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);

	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);
	SET @DeptScoped = CASE WHEN @ActingRole IN (''manager'', ''user'') THEN 1 ELSE 0 END;

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN (''admin'', ''controller'', ''manager'', ''user'', ''mgmt'', ''md_sect''))
		SET @Reason = 4;
	ELSE IF (@CommitteeId < 0
	         OR (@CommitteeId > 0 AND NOT EXISTS (SELECT 1 FROM Committee WHERE CommitteeId = @CommitteeId)))
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @DeptScoped = 0)
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE
	BEGIN
		SET @Result = 1;
		SET @StatisticsShown = CASE WHEN @ActingRole IN (''controller'', ''mgmt'', ''manager'', ''user'') THEN 1 ELSE 0 END;
		SET @WaitingShown = CASE WHEN @ActingRole IN (''controller'', ''manager'') THEN 1 ELSE 0 END;
	END

	-- The role of an active user is returned even when a filter is refused (the page words its message by it)
	IF (@ActingRole IN (''admin'', ''controller'', ''manager'', ''user'', ''mgmt'', ''md_sect''))
		SET @ActingRoleCode = @ActingRole;

	IF (@Result = 1 AND @DeptScoped = 1)
		INSERT INTO @Dept (DepartmentId)
		SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
		WHERE @DepartmentId = 0 OR s.DepartmentId = @DepartmentId;

	-- Scheduled: every one (no cap)
	INSERT INTO @List (MeetingId, ListCode)
	SELECT m.MeetingId, ''S''
	FROM Meeting m
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	WHERE @Result = 1
	AND st.IsScheduled = 1
	AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId);

	-- Completed: the last 10, for every role
	INSERT INTO @List (MeetingId, ListCode)
	SELECT TOP (10) m.MeetingId, ''C''
	FROM Meeting m
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	WHERE @Result = 1
	AND st.IsScheduled = 0
	AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId)
	AND (@DeptScoped = 0
	     OR EXISTS (SELECT 1 FROM Agenda a INNER JOIN @Dept d ON d.DepartmentId = a.DepartmentId
	                WHERE a.MeetingId = m.MeetingId))
	ORDER BY m.MeetingDate DESC, m.MeetingTime DESC, m.MeetingId DESC;

	SELECT
	m.MeetingId,
	m.CommitteeId,
	c.CommitteeCode,
	c.CommitteeName,
	m.MeetingNo,
	m.MeetingDate,
	m.MeetingTime,
	m.AgendaSubmissionDate,
	l.ListCode,
	st.StateCode,
	st.StateLabel,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Items, 0) END AS INT) AS Items,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Approved, 0) END AS INT) AS Approved,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Rejected, 0) END AS INT) AS Rejected,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Pending, 0) END AS INT) AS Pending,
	CAST(CASE WHEN @WaitingShown = 1 AND l.ListCode = ''S'' THEN ISNULL(w.Waiting, 0) END AS INT) AS WaitingForMe
	FROM @List l
	INNER JOIN Meeting m ON m.MeetingId = l.MeetingId
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	LEFT JOIN (SELECT ag.MeetingId,
	                  COUNT(*) AS Items,
	                  SUM(CASE WHEN ag.StatusGroup = ''approved'' THEN 1 ELSE 0 END) AS Approved,
	                  SUM(CASE WHEN ag.StatusGroup = ''rejected'' THEN 1 ELSE 0 END) AS Rejected,
	                  SUM(CASE WHEN ag.StatusGroup = ''in progress'' THEN 1 ELSE 0 END) AS Pending
	           FROM dbo.fn_AgendaStatusGroup() ag
	           INNER JOIN @List gl ON gl.MeetingId = ag.MeetingId
	           WHERE @StatisticsShown = 1
	           AND (@DeptScoped = 0 OR ag.DepartmentId IN (SELECT DepartmentId FROM @Dept))
	           GROUP BY ag.MeetingId) g ON g.MeetingId = m.MeetingId
	LEFT JOIN (SELECT wf.MeetingId, COUNT(*) AS Waiting
	           FROM dbo.fn_AgendaWaitingFor(@ActingUserId, @Today) wf
	           WHERE @WaitingShown = 1
	           AND wf.IsWaiting = 1
	           AND (@DepartmentId = 0 OR wf.DepartmentId = @DepartmentId)
	           GROUP BY wf.MeetingId) w ON w.MeetingId = m.MeetingId
	ORDER BY
	CASE l.ListCode WHEN ''S'' THEN 0 ELSE 1 END,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingDate END ASC,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingTime END ASC,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingId END ASC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingDate END DESC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingTime END DESC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingId END DESC;
END
';
SET @OldAppr = N'
-- Dashboard My approvals panel (AgendaWaitingFor-Step44, step UN6c2a): the items that wait for the acting user''s
-- approval (fn_AgendaWaitingFor, IsWaiting: he may approve, the agenda is open, the meeting date has not passed),
-- newest meeting first, a page of 10. @CommitteeId 0: every committee; otherwise it must exist. @DepartmentId 0: no
-- department filter; otherwise one of a Manager''s departments (fn_UserDepartmentScope). AlertId: the item''s alert
-- (the page marks the acting user''s own row of it read when the item is opened).
-- Reason 12: the protected system account. Reason 8: acting user missing, 0 or inactive. Reason 4: a role without
-- the panel (anyone but Controller and Manager), a filter that is not allowed, a page number below 1. A refused
-- call returns the same columns with no rows. A page number past the end gives the last page (@PageShown).
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardApprovals]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@DepartmentId INT = 0,
@PageNo INT = 1,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@TotalRows INT = NULL OUTPUT,
@PageShown INT = NULL OUTPUT
AS
DECLARE @Today DATE;
DECLARE @RoleCode VARCHAR(50);
DECLARE @PageSize INT;
DECLARE @Rows TABLE (RowNo INT PRIMARY KEY, AgendaId INT);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @TotalRows = 0;
	SET @PageShown = 1;
	SET @PageSize = 10;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	IF EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND IsSystem = 1)
		SET @Reason = 12;
	ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (ISNULL(@RoleCode, '''') NOT IN (''controller'', ''manager''))
		SET @Reason = 4;
	ELSE IF (@CommitteeId < 0
	         OR (@CommitteeId > 0 AND NOT EXISTS (SELECT 1 FROM Committee WHERE CommitteeId = @CommitteeId)))
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @RoleCode <> ''manager'')
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE IF (@PageNo IS NULL OR @PageNo < 1)
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	IF (@Result = 1)
	BEGIN
		INSERT INTO @Rows (RowNo, AgendaId)
		SELECT ROW_NUMBER() OVER (ORDER BY m.MeetingDate DESC, m.MeetingId DESC, a.AgendaNo, a.AgendaId), a.AgendaId
		FROM dbo.fn_AgendaWaitingFor(@ActingUserId, @Today) w
		INNER JOIN Agenda a ON a.AgendaId = w.AgendaId
		INNER JOIN Meeting m ON m.MeetingId = a.MeetingId
		WHERE w.IsWaiting = 1
		AND (@CommitteeId = 0 OR a.CommitteeId = @CommitteeId)
		AND (@DepartmentId = 0 OR a.DepartmentId = @DepartmentId);

		SET @TotalRows = @@ROWCOUNT;
		SET @PageShown = CASE WHEN @TotalRows = 0 THEN 1
		                      WHEN @PageNo > (@TotalRows + @PageSize - 1) / @PageSize THEN (@TotalRows + @PageSize - 1) / @PageSize
		                      ELSE @PageNo END;
	END

	SELECT
	x.RowNo,
	a.AgendaId,
	a.AgendaNo,
	a.SubjectNo,
	a.ShortText,
	a.AgendaStatusCode,
	a.CommitteeId,
	c.CommitteeCode,
	c.CommitteeName,
	a.MeetingId,
	m.MeetingNo,
	m.MeetingDate,
	a.DepartmentId,
	d.DepartmentName,
	(SELECT TOP 1 am.AlertId FROM Alert_Master am
	 WHERE am.SourceType = ''Agenda'' AND am.SourceTypeId = a.AgendaId ORDER BY am.AlertId) AS AlertId
	FROM @Rows x
	INNER JOIN Agenda a ON a.AgendaId = x.AgendaId
	INNER JOIN Meeting m ON m.MeetingId = a.MeetingId
	LEFT JOIN Committee c ON c.CommitteeId = a.CommitteeId
	LEFT JOIN Department d ON d.DepartmentId = a.DepartmentId
	WHERE @Result = 1
	AND x.RowNo > (@PageShown - 1) * @PageSize
	AND x.RowNo <= @PageShown * @PageSize
	ORDER BY x.RowNo;
END
';
SET @OldAct = N'
-- Dashboard Action Items card (DashboardAlerts-Step43, step UN6c1): the rows of fn_DashboardActionItems for the
-- acting user, newest meeting first. Reason 8: acting user missing, 0 or inactive. Reason 4: a role without an
-- Action Items card (MD Secretariat, Admin; the page hides the card on this answer). A refused call returns the
-- same columns with no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardActionItems]
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @Today DATE;
DECLARE @RoleCode VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Today = CAST(GETDATE() AS DATE);

	SELECT @RoleCode = r.RoleCode
	FROM Users u
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

	IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @ActingUserId AND AccountStatus = 1)
		SET @Reason = 8;
	ELSE IF (ISNULL(@RoleCode, '''') NOT IN (''controller'', ''mgmt'', ''manager'', ''user''))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	f.ActionItemId,
	f.MinutesId,
	f.ActionText,
	f.ActionStatus,
	f.AgendaId,
	f.DecisionTypeId,
	f.DueDate,
	f.AgendaNo,
	f.CommitteeId,
	f.MeetingId,
	f.DecisionTypeCode,
	f.DecisionTypeName,
	f.SubjectNo,
	f.DepartmentCode,
	f.DepartmentName,
	f.ActualResolution,
	f.CommitteeName,
	f.CommitteeCode,
	f.MeetingDate,
	f.MeetingTime,
	f.Venue,
	f.UserId,
	f.ReadStatus,
	f.DepartmentId,
	f.Directions,
	f.IsComplied,
	f.IsConfirmed,
	f.IsOverdue
	FROM dbo.fn_DashboardActionItems(@ActingUserId, @Today) f
	WHERE @Result = 1
	ORDER BY f.MeetingDate DESC, f.AgendaNo, f.ActionItemId;
END
';
SET @OldMeetTmp = REPLACE(@OldMeet, N'CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardMeetings]', N'CREATE PROCEDURE [dbo].[spr_ZZ45_MeetingsOld]');
SET @OldApprTmp = REPLACE(@OldAppr, N'CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardApprovals]', N'CREATE PROCEDURE [dbo].[spr_ZZ45_ApprovalsOld]');
SET @OldActTmp = REPLACE(@OldAct, N'CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardActionItems]', N'CREATE PROCEDURE [dbo].[spr_ZZ45_ActionItemsOld]');

INSERT INTO @T SELECT 'The three earlier texts in this script are whole (characters without carriage returns) and are renamed for the comparison', '6908 3977 1638, 1 1 1',
       CAST(LEN(REPLACE(@OldMeet, NCHAR(13), N'')) AS VARCHAR(12)) + ' ' + CAST(LEN(REPLACE(@OldAppr, NCHAR(13), N'')) AS VARCHAR(12)) + ' ' + CAST(LEN(REPLACE(@OldAct, NCHAR(13), N'')) AS VARCHAR(12)) + ', '
     + CAST(CASE WHEN @OldMeetTmp LIKE N'%spr_ZZ45_MeetingsOld%' THEN 1 ELSE 0 END AS VARCHAR(1)) + ' '
     + CAST(CASE WHEN @OldApprTmp LIKE N'%spr_ZZ45_ApprovalsOld%' THEN 1 ELSE 0 END AS VARCHAR(1)) + ' '
     + CAST(CASE WHEN @OldActTmp LIKE N'%spr_ZZ45_ActionItemsOld%' THEN 1 ELSE 0 END AS VARCHAR(1));

BEGIN TRANSACTION;

BEGIN TRY
    EXEC (@OldMeetTmp);
    EXEC (@OldApprTmp);
    EXEC (@OldActTmp);

    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ45A', 'ZZ45 department A', 991, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ45B', 'ZZ45 department B', 992, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ45C', 'ZZ45 department C', 993, 1, @Now, @Sys);
    SET @DC = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ45 controller', @DA, @Desig, NULL, @rCtl, 'zz45c@example.invalid', 'zz45ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ45 management', @DA, @Desig, NULL, @rMgmt, 'zz45g@example.invalid', 'zz45gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ45 manager of A and B', @DA, @Desig, NULL, @rMgr, 'zz45m1@example.invalid', 'zz45mab', 'not-a-login', 1, @Now);
    SET @MgAB = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ45 manager of C', @DC, @Desig, NULL, @rMgr, 'zz45m2@example.invalid', 'zz45mgc', 'not-a-login', 1, @Now);
    SET @MgC = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ45 user of A', @DA, @Desig, @MgAB, @rUser, 'zz45u@example.invalid', 'zz45usr', 'not-a-login', 1, @Now);
    SET @UsrA = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ45 md secretariat', @DA, @Desig, NULL, @rMd, 'zz45s@example.invalid', 'zz45mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ45 admin', @DA, @Desig, NULL, @rAdmin, 'zz45a@example.invalid', 'zz45adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ45 inactive controller', @DA, @Desig, NULL, @rCtl, 'zz45i@example.invalid', 'zz45off', 'not-a-login', 0, @Now);
    SET @Off = SCOPE_IDENTITY();

    INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, CreatedOn, CreatedBy)
    VALUES (@MgAB, @DA, 1, DATEADD(DAY, -30, @Today), NULL, @Now, @Sys),
           (@MgAB, @DB, 0, DATEADD(DAY, -30, @Today), NULL, @Now, @Sys),
           (@MgC, @DC, 1, DATEADD(DAY, -30, @Today), NULL, @Now, @Sys),
           (@UsrA, @DA, 1, DATEADD(DAY, -30, @Today), NULL, @Now, @Sys);

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z45', 'ZZ45 committee', '2000-01-01', 1, 0);
    SET @CZ = SCOPE_IDENTITY();
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Y45', 'ZZ45 second committee', '2000-01-01', 1, 0);
    SET @CY = SCOPE_IDENTITY();
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('W45', 'ZZ45 inactive committee', '2000-01-01', 0, 0);
    SET @CW = SCOPE_IDENTITY();

    -- Seven meetings: Z45 today, in 10 days, without a date (all three scheduled) and 5 days ago (completed, minutes
    -- finalised); Y45 in 3 days and 5 days ago (finalised); W45 (inactive committee) in 4 days
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    SELECT x.MeetingNo, x.CommitteeId, 'ZZ45 test', 'ZZ', x.MeetingDate, CASE WHEN x.MeetingDate IS NULL THEN NULL ELSE '10:00' END,
           CASE WHEN x.MeetingDate IS NULL THEN NULL ELSE DATEADD(DAY, -2, x.MeetingDate) END, x.AgendaStatus, x.MinutesStatus, @Now, @Sys
    FROM (SELECT '94501' AS MeetingNo, @CZ AS CommitteeId, @Day AS MeetingDate, 'Open' AS AgendaStatus, 'Open' AS MinutesStatus
          UNION ALL SELECT '94502', @CZ, DATEADD(DAY, 10, @Day), 'Open', 'Open'
          UNION ALL SELECT '94503', @CZ, NULL, 'Open', 'Open'
          UNION ALL SELECT '94504', @CZ, DATEADD(DAY, -5, @Day), 'Close', 'F'
          UNION ALL SELECT '94505', @CY, DATEADD(DAY, 3, @Day), 'Open', 'Open'
          UNION ALL SELECT '94506', @CY, DATEADD(DAY, -5, @Day), 'Close', 'F'
          UNION ALL SELECT '94507', @CW, DATEADD(DAY, 4, @Day), 'Open', 'Open') x;

    -- In every meeting, in every department, one item of each status (AC, AMA, AMR, ACR, ACA, AF and none). The items
    -- of A are saved by the user of A (his manager is the manager of A and B), the others by the Controller.
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT 'ZZ45-' + m.MeetingNo + '-' + d.Code + '-' + ISNULL(s.Code, 'none'), m.CommitteeId, m.MeetingId, d.DepartmentId, @SubjectTypeId,
           'ZZ45 ' + m.MeetingNo + ' ' + d.Code + ' ' + ISNULL(s.Code, 'none'), 'Entry', s.Code, 'New', @Now, CASE WHEN d.Code = 'A' THEN @UsrA ELSE @Ctl END
    FROM Meeting m
    CROSS JOIN (SELECT 'A' AS Code, @DA AS DepartmentId UNION ALL SELECT 'B', @DB UNION ALL SELECT 'C', @DC) d
    CROSS JOIN (SELECT 'AC' AS Code UNION ALL SELECT 'AMA' UNION ALL SELECT 'AMR' UNION ALL SELECT 'ACR' UNION ALL SELECT 'ACA'
                UNION ALL SELECT 'AF' UNION ALL SELECT NULL) s
    WHERE m.Place = 'ZZ45 test';

    -- Action items: the approved item of every department of the two completed meetings (finalised minutes)
    INSERT INTO Minutes (AgendaId, DecisionTypeId, DueDate, StatusId, CreatedOn, CreatedBy)
    SELECT a.AgendaId, @Followup, NULL, 0, @Now, @Sys
    FROM Agenda a INNER JOIN Meeting m ON m.MeetingId = a.MeetingId
    WHERE m.Place = 'ZZ45 test' AND m.MeetingNo IN ('94504', '94506') AND a.AgendaStatusCode = 'ACA';
    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)
    SELECT mi.MinutesId, N'ZZ45', N'ZZ45 ' + a.AgendaNo, '', 0, 0, @Now, @Sys
    FROM Minutes mi INNER JOIN Agenda a ON a.AgendaId = mi.AgendaId
    WHERE a.AgendaNo LIKE 'ZZ45-%';

    INSERT INTO @T SELECT 'Made-up data: departments, users, committees, meetings, items, action items', '3, 8, 3, 7, 147, 6',
           CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ45%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz45%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z45', 'Y45', 'W45')) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ45 test') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'ZZ45-%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ45') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The Committee filter function
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'fn_DashboardCommitteeFilter: 0, an active committee, the inactive one, an unknown id, -5, NULL', '1 1 0 0 0 0',
           CAST((SELECT Allowed FROM dbo.fn_DashboardCommitteeFilter(0)) AS VARCHAR(1)) + ' '
         + CAST((SELECT Allowed FROM dbo.fn_DashboardCommitteeFilter(@CZ)) AS VARCHAR(1)) + ' '
         + CAST((SELECT Allowed FROM dbo.fn_DashboardCommitteeFilter(@CW)) AS VARCHAR(1)) + ' '
         + CAST((SELECT Allowed FROM dbo.fn_DashboardCommitteeFilter(@Unknown)) AS VARCHAR(1)) + ' '
         + CAST((SELECT Allowed FROM dbo.fn_DashboardCommitteeFilter(-5)) AS VARCHAR(1)) + ' '
         + CAST((SELECT Allowed FROM dbo.fn_DashboardCommitteeFilter(NULL)) AS VARCHAR(1));

    ---------------------------------------------------------------------------
    -- spr_GetDashboardSummary: fixed values on the made-up committees (in progress, rejected)
    ---------------------------------------------------------------------------
    DECLARE SumCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT x.Name, x.UserId, x.CommitteeId, x.DepartmentId, x.Expected
        FROM (SELECT 1 AS Seq, 'Controller, Z45: three scheduled meetings (today, later, no date) x three departments x AC and AMA / AMR and ACR' AS Name,
                     @Ctl AS UserId, @CZ AS CommitteeId, 0 AS DepartmentId, 'Result 1, Reason 0: 18 in progress, 18 rejected' AS Expected
              UNION ALL SELECT 2, 'Management, Z45: the same', @Gmt, @CZ, 0, 'Result 1, Reason 0: 18 in progress, 18 rejected'
              UNION ALL SELECT 3, 'Manager of A and B, Z45, all his departments', @MgAB, @CZ, 0, 'Result 1, Reason 0: 12 in progress, 12 rejected'
              UNION ALL SELECT 4, 'Manager of A and B, Z45, department B chosen', @MgAB, @CZ, @DB, 'Result 1, Reason 0: 6 in progress, 6 rejected'
              UNION ALL SELECT 5, 'Manager of C, Z45', @MgC, @CZ, 0, 'Result 1, Reason 0: 6 in progress, 6 rejected'
              UNION ALL SELECT 6, 'User of A, Z45', @UsrA, @CZ, 0, 'Result 1, Reason 0: 6 in progress, 6 rejected'
              UNION ALL SELECT 7, 'User of A, Z45, his own department chosen', @UsrA, @CZ, @DA, 'Result 1, Reason 0: 6 in progress, 6 rejected'
              UNION ALL SELECT 8, 'Controller, Y45: one scheduled meeting (the completed one is not counted)', @Ctl, @CY, 0, 'Result 1, Reason 0: 6 in progress, 6 rejected'
              UNION ALL SELECT 9, 'Manager of A and B, Y45', @MgAB, @CY, 0, 'Result 1, Reason 0: 4 in progress, 4 rejected'
              UNION ALL SELECT 10, 'User of A, Y45', @UsrA, @CY, 0, 'Result 1, Reason 0: 2 in progress, 2 rejected'
              UNION ALL SELECT 11, 'Controller, the inactive committee W45: refused', @Ctl, @CW, 0, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 12, 'Controller, an unknown committee: refused', @Ctl, @Unknown, 0, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 13, 'Controller, committee -5: refused', @Ctl, -5, 0, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 14, 'User of A, the inactive committee W45: refused', @UsrA, @CW, 0, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 15, 'Controller with a department: refused', @Ctl, @CZ, @DA, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 16, 'Management with a department: refused', @Gmt, 0, @DA, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 17, 'Manager of A and B with department C (not his): refused', @MgAB, 0, @DC, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 18, 'User of A with department B (not his): refused', @UsrA, 0, @DB, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 19, 'Manager of A and B with department -1: refused', @MgAB, 0, -1, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 20, 'MD Secretariat: no cards (Reason 4)', @Mds, 0, 0, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 21, 'Admin: no cards (Reason 4)', @Adm, 0, 0, 'Result 0, Reason 4: - in progress, - rejected'
              UNION ALL SELECT 22, 'The protected system account: Reason 12', @Sys, 0, 0, 'Result 0, Reason 12: - in progress, - rejected'
              UNION ALL SELECT 23, 'An inactive user: Reason 8', @Off, 0, 0, 'Result 0, Reason 8: - in progress, - rejected'
              UNION ALL SELECT 24, 'Acting user 0: Reason 8', 0, 0, 0, 'Result 0, Reason 8: - in progress, - rejected'
              UNION ALL SELECT 25, 'An unknown acting user: Reason 8', -1, 0, 0, 'Result 0, Reason 8: - in progress, - rejected'
              UNION ALL SELECT 26, 'No acting user: Reason 8', NULL, 0, 0, 'Result 0, Reason 8: - in progress, - rejected') x
        ORDER BY x.Seq;
    OPEN SumCursor;
    FETCH NEXT FROM SumCursor INTO @Txt, @cUser, @cCom, @cDept, @NewS;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @Res = NULL; SET @Rsn = NULL; SET @InP = -9; SET @Rej = -9;
        EXEC spr_GetDashboardSummary @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = @cDept,
             @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @InProgress = @InP OUTPUT, @Rejected = @Rej OUTPUT;
        INSERT INTO @T SELECT 'Summary: ' + @Txt, @NewS,
               'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': '
             + ISNULL(CAST(@InP AS VARCHAR(12)), '-') + ' in progress, ' + ISNULL(CAST(@Rej AS VARCHAR(12)), '-') + ' rejected';
        FETCH NEXT FROM SumCursor INTO @Txt, @cUser, @cCom, @cDept, @NewS;
    END
    CLOSE SumCursor;
    DEALLOCATE SumCursor;

    ---------------------------------------------------------------------------
    -- The cases of the comparisons: every active user; 0 and every active committee; 0, each department of the
    -- person's scope and the department C (outside the scope of all but the manager of C)
    ---------------------------------------------------------------------------
    INSERT INTO @CaseUsers (UserId, RoleCode)
    SELECT u.UserId, r.RoleCode FROM Users u INNER JOIN Roles r ON r.RoleId = u.RoleId WHERE u.AccountStatus = 1;
    INSERT INTO @CaseComs (CommitteeId) SELECT 0 UNION SELECT CommitteeId FROM Committee WHERE StatusId = 1;
    INSERT INTO @CaseDepts (UserId, DepartmentId)
    SELECT cu.UserId, 0 FROM @CaseUsers cu
    UNION SELECT cu.UserId, @DC FROM @CaseUsers cu
    UNION SELECT ud.UserId, ud.DepartmentId FROM User_Department ud INNER JOIN @CaseUsers cu ON cu.UserId = ud.UserId
          WHERE ud.EffectiveFrom <= @Today AND (ud.EffectiveTo IS NULL OR ud.EffectiveTo > @Today)
    UNION SELECT u.UserId, u.DepartmentId FROM Users u INNER JOIN @CaseUsers cu ON cu.UserId = u.UserId WHERE u.DepartmentId IS NOT NULL;

    ---------------------------------------------------------------------------
    -- Summary = an independent count = the totals of the Scheduled list (every user of the four roles with cards)
    ---------------------------------------------------------------------------
    SET @N = 0; SET @Bad = 0; SET @Started = GETDATE();
    DECLARE CountCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT cu.UserId, cu.RoleCode, cc.CommitteeId, cd.DepartmentId
        FROM @CaseUsers cu CROSS JOIN @CaseComs cc INNER JOIN @CaseDepts cd ON cd.UserId = cu.UserId
        WHERE cu.RoleCode IN ('controller', 'mgmt', 'manager', 'user')
        AND (cd.DepartmentId = 0 OR cu.RoleCode IN ('manager', 'user'))
        ORDER BY cu.UserId, cc.CommitteeId, cd.DepartmentId;
    OPEN CountCursor;
    FETCH NEXT FROM CountCursor INTO @cUser, @cRole, @cCom, @cDept;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @cScoped = CASE WHEN @cRole IN ('manager', 'user') THEN 1 ELSE 0 END;
        -- The person's departments, read straight from User_Department and Users
        DELETE FROM @Scope;
        INSERT INTO @Scope (DepartmentId)
        SELECT x.DepartmentId FROM (SELECT ud.DepartmentId FROM User_Department ud
                                    WHERE ud.UserId = @cUser AND ud.EffectiveFrom <= @Today AND (ud.EffectiveTo IS NULL OR ud.EffectiveTo > @Today)
                                    UNION SELECT u.DepartmentId FROM Users u WHERE u.UserId = @cUser AND u.DepartmentId IS NOT NULL) x
        WHERE @cDept = 0 OR x.DepartmentId = @cDept;
        -- A department outside the scope is a refusal, checked below; only the allowed cases are counted
        IF (@cScoped = 0 OR @cDept = 0 OR EXISTS (SELECT 1 FROM @Scope))
        BEGIN
            SET @N = @N + 1;
            SELECT @IndP = SUM(CASE WHEN a.AgendaStatusCode IN ('AC', 'AMA') THEN 1 ELSE 0 END),
                   @IndR = SUM(CASE WHEN a.AgendaStatusCode IN ('AMR', 'ACR') THEN 1 ELSE 0 END)
            FROM Agenda a
            INNER JOIN Meeting m ON m.MeetingId = a.MeetingId
            INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
            WHERE (m.MeetingDate IS NULL OR CAST(m.MeetingDate AS DATE) >= @Today)
            AND (@cCom = 0 OR m.CommitteeId = @cCom)
            AND (@cScoped = 0 OR a.DepartmentId IN (SELECT DepartmentId FROM @Scope));
            SET @IndP = ISNULL(@IndP, 0); SET @IndR = ISNULL(@IndR, 0);

            SET @Res = NULL; SET @Rsn = NULL; SET @InP = NULL; SET @Rej = NULL;
            EXEC spr_GetDashboardSummary @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = @cDept,
                 @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @InProgress = @InP OUTPUT, @Rejected = @Rej OUTPUT;

            DELETE FROM #MT;
            INSERT INTO #MT EXEC spr_GetDashboardMeetings @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = @cDept,
                 @Result = @oRes OUTPUT, @Reason = @oRsn OUTPUT, @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT, @WaitingShown = @Wait OUTPUT;
            SELECT @SumP = ISNULL(SUM(Pending), 0), @SumR = ISNULL(SUM(Rejected), 0) FROM #MT WHERE ListCode = 'S';

            IF (ISNULL(@Res, -1) <> 1 OR ISNULL(@Rsn, -1) <> 0 OR ISNULL(@InP, -1) <> @IndP OR ISNULL(@Rej, -1) <> @IndR
                OR ISNULL(@oRes, -1) <> 1 OR @SumP <> @IndP OR @SumR <> @IndR)
                SET @Bad = @Bad + 1;
        END
        FETCH NEXT FROM CountCursor INTO @cUser, @cRole, @cCom, @cDept;
    END
    CLOSE CountCursor;
    DEALLOCATE CountCursor;
    SET @Ms = DATEDIFF(MILLISECOND, @Started, GETDATE());
    INSERT INTO @T SELECT 'Summary: every active Controller, Management user, Manager and User x every committee value x every department of the scope ('
                        + CAST(@N AS VARCHAR(12)) + ' cases): the counts equal the independent count and the totals of the Scheduled list; cases that differ',
           '0', CAST(@Bad AS VARCHAR(12));
    INSERT INTO @T SELECT 'Summary: the comparison covered the made-up data and the data of this database (at least 40 cases)', 'yes',
           CASE WHEN @N >= 40 THEN 'yes' ELSE 'no: ' + CAST(@N AS VARCHAR(12)) END;
    SET @Txt = 'Information: the ' + CAST(@N AS VARCHAR(12)) + ' summary cases (summary, independent count and meeting list each) took ' + CAST(@Ms AS VARCHAR(12)) + ' ms.';
    PRINT @Txt;

    ---------------------------------------------------------------------------
    -- An inactive, unknown or negative committee: refused with Reason 4 by all four procedures, for every role with
    -- the block (Result Reason rows; the summary: Result Reason counts)
    ---------------------------------------------------------------------------
    SET @N = 0; SET @Bad = 0;
    DECLARE BadComCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT u.UserId, r.RoleCode, x.CommitteeId
        FROM Users u INNER JOIN Roles r ON r.RoleId = u.RoleId
        CROSS JOIN (SELECT @CW AS CommitteeId UNION ALL SELECT @Unknown UNION ALL SELECT -5) x
        WHERE u.UserId IN (@Ctl, @Gmt, @MgAB, @MgC, @UsrA, @Mds, @Adm);
    OPEN BadComCursor;
    FETCH NEXT FROM BadComCursor INTO @cUser, @cRole, @cCom;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        -- The meeting list: every role has it
        SET @N = @N + 1;
        DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL;
        INSERT INTO #MT EXEC spr_GetDashboardMeetings @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = 0,
             @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT, @WaitingShown = @Wait OUTPUT;
        IF (ISNULL(@Res, -1) <> 0 OR ISNULL(@Rsn, -1) <> 4 OR (SELECT COUNT(*) FROM #MT) <> 0) SET @Bad = @Bad + 1;
        -- The summary: the four roles with cards
        IF (@cRole IN ('controller', 'mgmt', 'manager', 'user'))
        BEGIN
            SET @N = @N + 1;
            SET @Res = NULL; SET @Rsn = NULL; SET @InP = -9; SET @Rej = -9;
            EXEC spr_GetDashboardSummary @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = 0,
                 @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @InProgress = @InP OUTPUT, @Rejected = @Rej OUTPUT;
            IF (ISNULL(@Res, -1) <> 0 OR ISNULL(@Rsn, -1) <> 4 OR @InP IS NOT NULL OR @Rej IS NOT NULL) SET @Bad = @Bad + 1;
        END
        -- My approvals: the Controller and the Managers
        IF (@cRole IN ('controller', 'manager'))
        BEGIN
            SET @N = @N + 1;
            DELETE FROM #AP; SET @Res = NULL; SET @Rsn = NULL;
            INSERT INTO #AP EXEC spr_GetDashboardApprovals @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = 0, @PageNo = 1,
                 @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @PageShown = @Page OUTPUT;
            IF (ISNULL(@Res, -1) <> 0 OR ISNULL(@Rsn, -1) <> 4 OR (SELECT COUNT(*) FROM #AP) <> 0) SET @Bad = @Bad + 1;
        END
        -- The Action Items card: the four roles with the card
        IF (@cRole IN ('controller', 'mgmt', 'manager', 'user'))
        BEGIN
            SET @N = @N + 1;
            DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
            INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @cUser, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT,
                 @CommitteeId = @cCom, @DepartmentId = 0;
            IF (ISNULL(@Res, -1) <> 0 OR ISNULL(@Rsn, -1) <> 4 OR (SELECT COUNT(*) FROM #AI) <> 0) SET @Bad = @Bad + 1;
        END
        FETCH NEXT FROM BadComCursor INTO @cUser, @cRole, @cCom;
    END
    CLOSE BadComCursor;
    DEALLOCATE BadComCursor;
    INSERT INTO @T SELECT 'The inactive committee W45, an unknown committee and -5, for the Controller, Management, both Managers, the User, the MD Secretariat and the Admin: every call of the four procedures refused with Reason 4 and nothing returned ('
                        + CAST(@N AS VARCHAR(12)) + ' calls); calls that differ', '0', CAST(@Bad AS VARCHAR(12));
    INSERT INTO @T SELECT 'The refusal calls: 7 users x 3 committees x the blocks of their role (21 meeting lists, 15 summaries, 9 approvals, 15 action item lists)', '60', CAST(@N AS VARCHAR(12));

    -- Before step 45 the inactive committee was accepted (the earlier texts, for the record of the change)
    DELETE FROM #MO; SET @oRes = NULL; SET @oRsn = NULL;
    INSERT INTO #MO EXEC spr_ZZ45_MeetingsOld @ActingUserId = @Ctl, @CommitteeId = @CW, @DepartmentId = 0,
         @Result = @oRes OUTPUT, @Reason = @oRsn OUTPUT, @StatisticsShown = @oShown OUTPUT, @ActingRoleCode = @oRole OUTPUT, @WaitingShown = @oWait OUTPUT;
    DELETE FROM #APO; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #APO EXEC spr_ZZ45_ApprovalsOld @ActingUserId = @Ctl, @CommitteeId = @CW, @DepartmentId = 0, @PageNo = 1,
         @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'For the record: the earlier meeting list and My approvals ACCEPTED the inactive committee W45 (Result 1; one scheduled meeting; its AMA items waiting)',
           'meetings 1 0 1, approvals 1 0 3',
           'meetings ' + ISNULL(CAST(@oRes AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@oRsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #MO) AS VARCHAR(12))
         + ', approvals ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #APO) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Refusals of the other procedures for the acting user (unchanged by step 45, checked once more)
    ---------------------------------------------------------------------------
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Off, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @CommitteeId = @CZ, @DepartmentId = 0;
    SET @Txt = ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = 0, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @CommitteeId = 0, @DepartmentId = 0;
    SET @Txt = @Txt + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Mds, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @CommitteeId = @CZ, @DepartmentId = 0;
    SET @Txt = @Txt + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @CommitteeId = 0, @DepartmentId = @DA;
    SET @Txt = @Txt + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @UsrA, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @CommitteeId = 0, @DepartmentId = @DB;
    SET @Txt = @Txt + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    INSERT INTO @T SELECT 'Action Items: inactive user, user 0 (Reason 8); MD Secretariat (4); Controller with a department, User with another department (4)', '8 8 4 4 4', @Txt;

    -- Fixed values: the action items of the made-up committees by filter
    SET @Txt = '';
    DECLARE AiCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT x.UserId, x.CommitteeId, x.DepartmentId
        FROM (SELECT 1 AS Seq, @Ctl AS UserId, @CZ AS CommitteeId, 0 AS DepartmentId
              UNION ALL SELECT 2, @Ctl, @CY, 0 UNION ALL SELECT 3, @Gmt, @CZ, 0 UNION ALL SELECT 4, @MgAB, @CZ, 0 UNION ALL SELECT 5, @MgAB, @CZ, @DB
              UNION ALL SELECT 6, @MgAB, @CY, @DA UNION ALL SELECT 7, @MgC, @CZ, 0 UNION ALL SELECT 8, @UsrA, @CZ, 0 UNION ALL SELECT 9, @UsrA, @CY, @DA) x
        ORDER BY x.Seq;
    OPEN AiCursor;
    FETCH NEXT FROM AiCursor INTO @cUser, @cCom, @cDept;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
        INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @cUser, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @CommitteeId = @cCom, @DepartmentId = @cDept;
        SET @Txt = @Txt + CASE WHEN @Txt = '' THEN '' ELSE ', ' END + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ':'
                 + ISNULL(STUFF((SELECT '+' + REPLACE(REPLACE(AgendaNo, 'ZZ45-', ''), '-ACA', '') FROM #AI ORDER BY AgendaNo FOR XML PATH('')), 1, 1, ''), 'none');
        FETCH NEXT FROM AiCursor INTO @cUser, @cCom, @cDept;
    END
    CLOSE AiCursor;
    DEALLOCATE AiCursor;
    INSERT INTO @T SELECT 'Action Items by filter (Reason:items): Controller Z45, Y45; Management Z45; Manager of A and B Z45, Z45 with B, Y45 with A; Manager of C Z45; User of A Z45, Y45 with A',
           '0:94504-A+94504-B+94504-C, 0:94506-A+94506-B+94506-C, 0:94504-A+94504-B+94504-C, 0:94504-A+94504-B, 0:94504-B, 0:94506-A, 0:94504-C, 0:94504-A, 0:94506-A', @Txt;

    ---------------------------------------------------------------------------
    -- The MD Secretariat: the statistics, row by row those of Management; no Waiting for me, no approvals panel
    ---------------------------------------------------------------------------
    SET @Txt = '';
    DECLARE MdCursor CURSOR LOCAL FAST_FORWARD FOR SELECT CommitteeId FROM (SELECT 0 AS CommitteeId UNION ALL SELECT @CZ UNION ALL SELECT @CY) x ORDER BY CommitteeId;
    OPEN MdCursor;
    FETCH NEXT FROM MdCursor INTO @cCom;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL; SET @Shown = NULL; SET @Wait = NULL; SET @Role = NULL;
        INSERT INTO #MT EXEC spr_GetDashboardMeetings @ActingUserId = @Mds, @CommitteeId = @cCom, @DepartmentId = 0,
             @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT, @WaitingShown = @Wait OUTPUT;
        DELETE FROM #MG;
        INSERT INTO #MG EXEC spr_GetDashboardMeetings @ActingUserId = @Gmt, @CommitteeId = @cCom, @DepartmentId = 0,
             @Result = @oRes OUTPUT, @Reason = @oRsn OUTPUT, @StatisticsShown = @oShown OUTPUT, @ActingRoleCode = @oRole OUTPUT, @WaitingShown = @oWait OUTPUT;
        SET @NewS = ISNULL((SELECT ';' + CAST(MeetingId AS VARCHAR(12)) + ':' + ListCode + ':' + ISNULL(CAST(Items AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Approved AS VARCHAR(12)), '-')
                                   + ' ' + ISNULL(CAST(Rejected AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Pending AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(WaitingForMe AS VARCHAR(12)), '-')
                            FROM #MT ORDER BY ListCode, MeetingId FOR XML PATH('')), '');
        SET @GmtS = ISNULL((SELECT ';' + CAST(MeetingId AS VARCHAR(12)) + ':' + ListCode + ':' + ISNULL(CAST(Items AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Approved AS VARCHAR(12)), '-')
                                   + ' ' + ISNULL(CAST(Rejected AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Pending AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(WaitingForMe AS VARCHAR(12)), '-')
                            FROM #MG ORDER BY ListCode, MeetingId FOR XML PATH('')), '');
        SET @Txt = @Txt + CASE WHEN @Txt = '' THEN '' ELSE '; ' END
                 + 'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' shown ' + ISNULL(CAST(@Shown AS VARCHAR(2)), '-') + ' waiting ' + ISNULL(CAST(@Wait AS VARCHAR(2)), '-')
                 + ' role ' + ISNULL(@Role, '-') + ' rows ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12))
                 + CASE WHEN (SELECT COUNT(*) FROM #MT) > 0 AND @NewS = @GmtS THEN ' = Management'
                        ELSE ' differ from Management' END
                 + CASE WHEN EXISTS (SELECT 1 FROM #MT WHERE Items IS NULL OR Pending IS NULL) THEN ', some counts NULL' ELSE '' END
                 + CASE WHEN EXISTS (SELECT 1 FROM #MT WHERE WaitingForMe IS NOT NULL) THEN ', waiting values' ELSE '' END;
        FETCH NEXT FROM MdCursor INTO @cCom;
    END
    CLOSE MdCursor;
    DEALLOCATE MdCursor;
    INSERT INTO @T SELECT 'MD Secretariat, all committees, Z45, Y45: statistics shown, every row and count equal to Management''s, no Waiting for me',
           'Result 1 shown 1 waiting 0 role md_sect rows ' + CAST((SELECT COUNT(*) FROM Meeting m INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
                                                                   INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId WHERE st.IsScheduled = 1)
                                                                  + CASE WHEN (SELECT COUNT(*) FROM Meeting m INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
                                                                               INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId WHERE st.IsScheduled = 0) > 10 THEN 10
                                                                         ELSE (SELECT COUNT(*) FROM Meeting m INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
                                                                               INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId WHERE st.IsScheduled = 0) END AS VARCHAR(12))
         + ' = Management; Result 1 shown 1 waiting 0 role md_sect rows 4 = Management; Result 1 shown 1 waiting 0 role md_sect rows 2 = Management',
           @Txt;

    DELETE FROM #AP; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AP EXEC spr_GetDashboardApprovals @ActingUserId = @Mds, @CommitteeId = 0, @DepartmentId = 0, @PageNo = 1,
         @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @PageShown = @Page OUTPUT;
    SET @Txt = 'approvals ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AP) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Mds, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ', action items ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12));
    DELETE FROM #MT; SET @Res = NULL; SET @Rsn = NULL; SET @Shown = NULL;
    INSERT INTO #MT EXEC spr_GetDashboardMeetings @ActingUserId = @Adm, @CommitteeId = @CZ, @DepartmentId = 0,
         @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT, @WaitingShown = @Wait OUTPUT;
    SET @Txt = @Txt + ', Admin meetings shown ' + ISNULL(CAST(@Shown AS VARCHAR(2)), '-') + ' rows with a count '
             + CAST((SELECT COUNT(*) FROM #MT WHERE Items IS NOT NULL OR Approved IS NOT NULL OR Rejected IS NOT NULL OR Pending IS NOT NULL OR WaitingForMe IS NOT NULL) AS VARCHAR(12))
             + ' of ' + CAST((SELECT COUNT(*) FROM #MT) AS VARCHAR(12));
    INSERT INTO @T SELECT 'MD Secretariat: no My approvals (Reason 4), no Action Items (Reason 4); the Admin still without statistics',
           'approvals 4 0, action items 4 0, Admin meetings shown 0 rows with a count 0 of 4', @Txt;

    ---------------------------------------------------------------------------
    -- The meeting list: the earlier text (step 44) beside the new one
    ---------------------------------------------------------------------------
    SET @N = 0; SET @Bad = 0; SET @NMd = 0; SET @GoodMd = 0;
    DECLARE MeetCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT cu.UserId, cu.RoleCode, cc.CommitteeId, cd.DepartmentId
        FROM @CaseUsers cu CROSS JOIN @CaseComs cc INNER JOIN @CaseDepts cd ON cd.UserId = cu.UserId
        ORDER BY cu.UserId, cc.CommitteeId, cd.DepartmentId;
    OPEN MeetCursor;
    FETCH NEXT FROM MeetCursor INTO @cUser, @cRole, @cCom, @cDept;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @N = @N + 1;
        DELETE FROM #MT; DELETE FROM #MO;
        SET @Res = NULL; SET @Rsn = NULL; SET @Shown = NULL; SET @Role = NULL; SET @Wait = NULL;
        SET @oRes = NULL; SET @oRsn = NULL; SET @oShown = NULL; SET @oRole = NULL; SET @oWait = NULL;
        INSERT INTO #MT EXEC spr_GetDashboardMeetings @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = @cDept,
             @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT, @WaitingShown = @Wait OUTPUT;
        INSERT INTO #MO EXEC spr_ZZ45_MeetingsOld @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = @cDept,
             @Result = @oRes OUTPUT, @Reason = @oRsn OUTPUT, @StatisticsShown = @oShown OUTPUT, @ActingRoleCode = @oRole OUTPUT, @WaitingShown = @oWait OUTPUT;
        -- Every column but the four counts
        SET @NewS = ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ISNULL(@Role, '-') + ISNULL(CAST(@Wait AS VARCHAR(2)), '-')
                  + ISNULL((SELECT '|' + CAST(MeetingId AS VARCHAR(12)) + ':' + CAST(CommitteeId AS VARCHAR(12)) + ':' + ISNULL(CommitteeCode, '-') + ':' + ISNULL(CommitteeName, N'-')
                                   + ':' + ISNULL(MeetingNo, '-') + ':' + ISNULL(CONVERT(VARCHAR(23), MeetingDate, 121), '-') + ':' + ISNULL(MeetingTime, '-')
                                   + ':' + ISNULL(CONVERT(VARCHAR(23), AgendaSubmissionDate, 121), '-') + ':' + ListCode + ':' + ISNULL(StateCode, '-') + ':' + ISNULL(StateLabel, '-')
                                   + ':' + ISNULL(CAST(WaitingForMe AS VARCHAR(12)), '-')
                            FROM #MT ORDER BY ListCode, MeetingId FOR XML PATH('')), '');
        SET @OldS = ISNULL(CAST(@oRes AS VARCHAR(2)), '-') + ISNULL(CAST(@oRsn AS VARCHAR(3)), '-') + ISNULL(@oRole, '-') + ISNULL(CAST(@oWait AS VARCHAR(2)), '-')
                  + ISNULL((SELECT '|' + CAST(MeetingId AS VARCHAR(12)) + ':' + CAST(CommitteeId AS VARCHAR(12)) + ':' + ISNULL(CommitteeCode, '-') + ':' + ISNULL(CommitteeName, N'-')
                                   + ':' + ISNULL(MeetingNo, '-') + ':' + ISNULL(CONVERT(VARCHAR(23), MeetingDate, 121), '-') + ':' + ISNULL(MeetingTime, '-')
                                   + ':' + ISNULL(CONVERT(VARCHAR(23), AgendaSubmissionDate, 121), '-') + ':' + ListCode + ':' + ISNULL(StateCode, '-') + ':' + ISNULL(StateLabel, '-')
                                   + ':' + ISNULL(CAST(WaitingForMe AS VARCHAR(12)), '-')
                            FROM #MO ORDER BY ListCode, MeetingId FOR XML PATH('')), '');
        IF (@cRole = 'md_sect' AND @Res = 1)
        BEGIN
            -- The one change for the MD Secretariat: statistics shown (1, was 0) and the counts those of a Management
            -- user on the same filter (the earlier text had none); everything else as before
            SET @NMd = @NMd + 1;
            DELETE FROM #MG;
            INSERT INTO #MG EXEC spr_GetDashboardMeetings @ActingUserId = @Gmt, @CommitteeId = @cCom, @DepartmentId = 0,
                 @Result = @dRes OUTPUT, @Reason = @dRsn OUTPUT, @StatisticsShown = @dShown OUTPUT, @ActingRoleCode = @dRole OUTPUT, @WaitingShown = @dWait OUTPUT;
            IF (@NewS = @OldS AND ISNULL(@Shown, -1) = 1 AND ISNULL(@oShown, -1) = 0
                AND NOT EXISTS (SELECT 1 FROM #MO WHERE Items IS NOT NULL OR Approved IS NOT NULL OR Rejected IS NOT NULL OR Pending IS NOT NULL)
                AND ISNULL((SELECT ';' + CAST(MeetingId AS VARCHAR(12)) + ':' + ISNULL(CAST(Items AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Approved AS VARCHAR(12)), '-')
                                   + ' ' + ISNULL(CAST(Rejected AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Pending AS VARCHAR(12)), '-')
                            FROM #MT ORDER BY ListCode, MeetingId FOR XML PATH('')), '')
                  = ISNULL((SELECT ';' + CAST(MeetingId AS VARCHAR(12)) + ':' + ISNULL(CAST(Items AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Approved AS VARCHAR(12)), '-')
                                   + ' ' + ISNULL(CAST(Rejected AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Pending AS VARCHAR(12)), '-')
                            FROM #MG ORDER BY ListCode, MeetingId FOR XML PATH('')), ''))
                SET @GoodMd = @GoodMd + 1;
            ELSE
                SET @Bad = @Bad + 1;
        END
        ELSE IF (@NewS <> @OldS OR ISNULL(@Shown, -1) <> ISNULL(@oShown, -1)
                 OR ISNULL((SELECT ';' + CAST(MeetingId AS VARCHAR(12)) + ':' + ISNULL(CAST(Items AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Approved AS VARCHAR(12)), '-')
                                   + ' ' + ISNULL(CAST(Rejected AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Pending AS VARCHAR(12)), '-')
                            FROM #MT ORDER BY ListCode, MeetingId FOR XML PATH('')), '')
                  <> ISNULL((SELECT ';' + CAST(MeetingId AS VARCHAR(12)) + ':' + ISNULL(CAST(Items AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Approved AS VARCHAR(12)), '-')
                                   + ' ' + ISNULL(CAST(Rejected AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Pending AS VARCHAR(12)), '-')
                            FROM #MO ORDER BY ListCode, MeetingId FOR XML PATH('')), ''))
            SET @Bad = @Bad + 1;
        FETCH NEXT FROM MeetCursor INTO @cUser, @cRole, @cCom, @cDept;
    END
    CLOSE MeetCursor;
    DEALLOCATE MeetCursor;
    INSERT INTO @T SELECT 'Meeting list, the earlier text beside the new one: every active user x 0 and every active committee x 0, each department of the scope and C ('
                        + CAST(@N AS VARCHAR(12)) + ' cases): cases that differ other than by the MD Secretariat''s statistics', '0', CAST(@Bad AS VARCHAR(12));
    INSERT INTO @T SELECT 'Meeting list: the MD Secretariat cases differ only by StatisticsShown 1 (was 0) and counts equal to those of Management (at least 3 cases)', 'all, at least 3',
           CASE WHEN @NMd >= 3 AND @GoodMd = @NMd THEN 'all, at least 3' ELSE CAST(@GoodMd AS VARCHAR(12)) + ' of ' + CAST(@NMd AS VARCHAR(12)) END;

    ---------------------------------------------------------------------------
    -- My approvals: the earlier text (step 44) beside the new one, on the same cases
    ---------------------------------------------------------------------------
    SET @N = 0; SET @Bad = 0;
    DECLARE ApprCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT cu.UserId, cc.CommitteeId, cd.DepartmentId
        FROM @CaseUsers cu CROSS JOIN @CaseComs cc INNER JOIN @CaseDepts cd ON cd.UserId = cu.UserId
        ORDER BY cu.UserId, cc.CommitteeId, cd.DepartmentId;
    OPEN ApprCursor;
    FETCH NEXT FROM ApprCursor INTO @cUser, @cCom, @cDept;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @N = @N + 1;
        DELETE FROM #AP; DELETE FROM #APO;
        SET @Res = NULL; SET @Rsn = NULL; SET @Total = NULL; SET @Page = NULL;
        SET @oRes = NULL; SET @oRsn = NULL; SET @oTotal = NULL; SET @oPage = NULL;
        INSERT INTO #AP EXEC spr_GetDashboardApprovals @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = @cDept, @PageNo = 1,
             @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @PageShown = @Page OUTPUT;
        INSERT INTO #APO EXEC spr_ZZ45_ApprovalsOld @ActingUserId = @cUser, @CommitteeId = @cCom, @DepartmentId = @cDept, @PageNo = 1,
             @Result = @oRes OUTPUT, @Reason = @oRsn OUTPUT, @TotalRows = @oTotal OUTPUT, @PageShown = @oPage OUTPUT;
        SET @NewS = ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ' ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(@Page AS VARCHAR(12)), '-')
                  + ISNULL((SELECT '|' + CAST(RowNo AS VARCHAR(12)) + ':' + CAST(AgendaId AS VARCHAR(12)) + ':' + ISNULL(CAST(AlertId AS VARCHAR(12)), '-') + ':' + ISNULL(DepartmentName, N'-')
                            FROM #AP ORDER BY RowNo FOR XML PATH('')), '');
        SET @OldS = ISNULL(CAST(@oRes AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@oRsn AS VARCHAR(3)), '-') + ' ' + ISNULL(CAST(@oTotal AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(@oPage AS VARCHAR(12)), '-')
                  + ISNULL((SELECT '|' + CAST(RowNo AS VARCHAR(12)) + ':' + CAST(AgendaId AS VARCHAR(12)) + ':' + ISNULL(CAST(AlertId AS VARCHAR(12)), '-') + ':' + ISNULL(DepartmentName, N'-')
                            FROM #APO ORDER BY RowNo FOR XML PATH('')), '');
        IF (@NewS <> @OldS) SET @Bad = @Bad + 1;
        FETCH NEXT FROM ApprCursor INTO @cUser, @cCom, @cDept;
    END
    CLOSE ApprCursor;
    DEALLOCATE ApprCursor;
    INSERT INTO @T SELECT 'My approvals, the earlier text beside the new one: every active user x 0 and every active committee x 0, each department of the scope and C ('
                        + CAST(@N AS VARCHAR(12)) + ' cases): cases that differ', '0', CAST(@Bad AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The Action Items card: the earlier text (step 43) beside the new one. With a committee and a department the
    -- expected answer is worked out here: the earlier refusal, else Reason 4 for a department not allowed (a role
    -- without departments, a department outside the scope), else the earlier rows of that committee and department.
    ---------------------------------------------------------------------------
    SET @N = 0; SET @Bad = 0;
    DECLARE ActCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT cu.UserId, cu.RoleCode, cc.CommitteeId, cd.DepartmentId
        FROM @CaseUsers cu CROSS JOIN @CaseComs cc INNER JOIN @CaseDepts cd ON cd.UserId = cu.UserId
        ORDER BY cu.UserId, cc.CommitteeId, cd.DepartmentId;
    OPEN ActCursor;
    FETCH NEXT FROM ActCursor INTO @cUser, @cRole, @cCom, @cDept;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @N = @N + 1;
        DELETE FROM #AI; DELETE FROM #AIO;
        SET @Res = NULL; SET @Rsn = NULL; SET @oRes = NULL; SET @oRsn = NULL;
        INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @cUser, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @CommitteeId = @cCom, @DepartmentId = @cDept;
        INSERT INTO #AIO EXEC spr_ZZ45_ActionItemsOld @ActingUserId = @cUser, @Result = @oRes OUTPUT, @Reason = @oRsn OUTPUT;
        SET @ExpRsn = CASE WHEN ISNULL(@oRsn, -1) <> 0 THEN @oRsn
                           WHEN @cDept > 0 AND @cRole NOT IN ('manager', 'user') THEN 4
                           WHEN @cDept > 0 AND NOT EXISTS (SELECT 1 FROM User_Department ud WHERE ud.UserId = @cUser AND ud.DepartmentId = @cDept
                                                           AND ud.EffectiveFrom <= @Today AND (ud.EffectiveTo IS NULL OR ud.EffectiveTo > @Today))
                                AND NOT EXISTS (SELECT 1 FROM Users u WHERE u.UserId = @cUser AND u.DepartmentId = @cDept) THEN 4
                           ELSE 0 END;
        IF (@ExpRsn <> 0)
            DELETE FROM #AIO;
        ELSE
            DELETE FROM #AIO WHERE NOT ((@cCom = 0 OR CommitteeId = @cCom) AND (@cDept = 0 OR DepartmentId = @cDept));
        SET @NewS = ISNULL(CAST(@Rsn AS VARCHAR(3)), '-')
                  + ISNULL((SELECT '|' + CAST(ActionItemId AS VARCHAR(12)) + ':' + CAST(ReadStatus AS VARCHAR(3)) + ':' + CAST(IsOverdue AS VARCHAR(3)) + ':' + ISNULL(AgendaNo, '-')
                            FROM #AI ORDER BY ActionItemId FOR XML PATH('')), '');
        SET @OldS = ISNULL(CAST(@ExpRsn AS VARCHAR(3)), '-')
                  + ISNULL((SELECT '|' + CAST(ActionItemId AS VARCHAR(12)) + ':' + CAST(ReadStatus AS VARCHAR(3)) + ':' + CAST(IsOverdue AS VARCHAR(3)) + ':' + ISNULL(AgendaNo, '-')
                            FROM #AIO ORDER BY ActionItemId FOR XML PATH('')), '');
        IF (@NewS <> @OldS) SET @Bad = @Bad + 1;
        FETCH NEXT FROM ActCursor INTO @cUser, @cRole, @cCom, @cDept;
    END
    CLOSE ActCursor;
    DEALLOCATE ActCursor;
    INSERT INTO @T SELECT 'Action Items, the earlier text beside the new one: every active user x 0 and every active committee x 0, each department of the scope and C ('
                        + CAST(@N AS VARCHAR(12)) + ' cases): cases that differ from the earlier rows of that committee and department', '0', CAST(@Bad AS VARCHAR(12));

    -- Without the new parameters (the earlier build): the rows of step 43 for every active user
    SET @N = 0; SET @Bad = 0;
    DECLARE PlainCursor CURSOR LOCAL FAST_FORWARD FOR SELECT UserId FROM @CaseUsers ORDER BY UserId;
    OPEN PlainCursor;
    FETCH NEXT FROM PlainCursor INTO @cUser;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @N = @N + 1;
        DELETE FROM #AI; DELETE FROM #AIO;
        INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @cUser, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
        INSERT INTO #AIO EXEC spr_ZZ45_ActionItemsOld @ActingUserId = @cUser, @Result = @oRes OUTPUT, @Reason = @oRsn OUTPUT;
        IF (ISNULL(@Res, -1) <> ISNULL(@oRes, -1) OR ISNULL(@Rsn, -1) <> ISNULL(@oRsn, -1)
            OR ISNULL((SELECT '|' + CAST(ActionItemId AS VARCHAR(12)) + ':' + CAST(ReadStatus AS VARCHAR(3)) + ':' + CAST(IsOverdue AS VARCHAR(3)) FROM #AI ORDER BY ActionItemId FOR XML PATH('')), '')
            <> ISNULL((SELECT '|' + CAST(ActionItemId AS VARCHAR(12)) + ':' + CAST(ReadStatus AS VARCHAR(3)) + ':' + CAST(IsOverdue AS VARCHAR(3)) FROM #AIO ORDER BY ActionItemId FOR XML PATH('')), ''))
            SET @Bad = @Bad + 1;
        FETCH NEXT FROM PlainCursor INTO @cUser;
    END
    CLOSE PlainCursor;
    DEALLOCATE PlainCursor;
    INSERT INTO @T SELECT 'Action Items called without the two new parameters (the earlier build), every active user (' + CAST(@N AS VARCHAR(12)) + '): cases that differ from step 43', '0', CAST(@Bad AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The Rollback's three batches (the texts of steps 44 and 43), run inside this transaction: SHA-1 compared with the
    -- texts step 45 was built from. Last: after this the procedures are the earlier ones until the rollback below.
    ---------------------------------------------------------------------------
    EXEC (@OldMeet);
    EXEC (@OldAppr);
    EXEC (@OldAct);
    SET @Hd = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), CHAR(13), ''); SET @MeetHash = ''; SET @Hi = 1;
    WHILE (@Hd IS NOT NULL AND @Hi <= DATALENGTH(@Hd) / 2)
    BEGIN
        SET @MeetHash = @MeetHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@Hd, @Hi, 4000) AS NVARCHAR(4000))), 2);
        SET @Hi = @Hi + 4000;
    END
    SET @Hd = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardApprovals')), CHAR(13), ''); SET @ApprHash = ''; SET @Hi = 1;
    WHILE (@Hd IS NOT NULL AND @Hi <= DATALENGTH(@Hd) / 2)
    BEGIN
        SET @ApprHash = @ApprHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@Hd, @Hi, 4000) AS NVARCHAR(4000))), 2);
        SET @Hi = @Hi + 4000;
    END
    SET @Hd = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardActionItems')), CHAR(13), ''); SET @ActHash = ''; SET @Hi = 1;
    WHILE (@Hd IS NOT NULL AND @Hi <= DATALENGTH(@Hd) / 2)
    BEGIN
        SET @ActHash = @ActHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@Hd, @Hi, 4000) AS NVARCHAR(4000))), 2);
        SET @Hi = @Hi + 4000;
    END
    INSERT INTO @T SELECT 'The Rollback''s three batches give the texts of steps 44 and 43 letter for letter (SHA-1), without the step 45 marker', 'same, same, same, 0 markers',
           CASE WHEN @MeetHash = '018126C666059C775382F2D990FD0E6894CB1960A0DBD4D95E46DC9E033221FEA12D64364BED4928' THEN 'same' ELSE 'differs' END + ', '
         + CASE WHEN @ApprHash = 'B39CC2B64BCF0068CA13908C21302FC1212452A7' THEN 'same' ELSE 'differs' END + ', '
         + CASE WHEN @ActHash = 'A3117268FEA43FAB4F7FA858DAD14CA978FB0D02' THEN 'same' ELSE 'differs' END + ', '
         + CAST((SELECT COUNT(*) FROM (VALUES ('spr_GetDashboardMeetings'), ('spr_GetDashboardApprovals'), ('spr_GetDashboardActionItems')) o(Name)
                 WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardSummary-Step45%') AS VARCHAR(2)) + ' markers';

END TRY
BEGIN CATCH
    SET @Txt = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error', @Txt);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MeetingId, DepartmentId, UpdatedOn)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MinAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, AgendaId, DecisionTypeId, DueDate, StatusId)), 0) AS VARCHAR(12)) FROM Minutes;
SELECT @ActAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, IsComplied, IsConfirmed, UpdatedOn)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
INSERT INTO @T SELECT 'After the rollback: Agenda unchanged (count, checksum)', @AgendaBefore, @AgendaAfter;
INSERT INTO @T SELECT 'After the rollback: Minutes unchanged (count, checksum)', @MinBefore, @MinAfter;
INSERT INTO @T SELECT 'After the rollback: Action_Item unchanged (count, checksum)', @ActBefore, @ActAfter;
INSERT INTO @T SELECT 'After the rollback: Alert_User_Map unchanged (count, checksum)', @MapBefore, @MapAfter;
INSERT INTO @T SELECT 'After the rollback: step 45 is installed again (markers in the five objects), the temporary objects are gone', '5, 0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardCommitteeFilter'), ('spr_GetDashboardSummary'), ('spr_GetDashboardMeetings'),
                                          ('spr_GetDashboardApprovals'), ('spr_GetDashboardActionItems')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardSummary-Step45%') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM sys.objects WHERE name LIKE '%ZZ45%') AS VARCHAR(12));

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
SELECT 'After the test: no ZZ45 department, user, committee, meeting, item or action item left', '0 0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ45%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz45%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z45', 'Y45', 'W45')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ45 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'ZZ45-%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ45') AS VARCHAR(12));

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

DROP TABLE #AIO;
DROP TABLE #AI;
DROP TABLE #APO;
DROP TABLE #AP;
DROP TABLE #MG;
DROP TABLE #MO;
DROP TABLE #MT;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
