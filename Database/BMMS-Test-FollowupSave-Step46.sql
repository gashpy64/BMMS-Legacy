/* ============================================================================
   BMMS - Test of step 46 (Followup page saves decided on the server; step
   UN6d)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 46
   is not installed.

   Replaced by step 47 (step FU1): while step 47 is installed it runs no
   check and names BMMS-Test-FollowupFinal-Step47.sql instead (not a
   failure). With step 47 rolled back it runs as before (56 checks).

   Run it in a NEW query window (it uses temporary objects of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS.

   Part 1 reads only: the markers, parameters, no result set, no feature
   above compatibility level 100; spr_UpdateActionItem is the step 31 text
   (SHA-1) and carries no marker of this step; the objects of steps 43 and
   45 carry their markers as before; every database user who can run step
   42's procedure can run the two procedures of this step.

   Part 2, inside ONE transaction that is rolled back (made-up data ZZ46: one
   department, a committee, a meeting with finalised minutes, the six roles,
   an inactive Controller, 17 action items with two mapping rows each):
     - the writes of the two procedures compared with spr_UpdateActionItem
       on twin items (the same starting values): Submit on six pairs that
       cover both ticks from every start (IsComplied and IsConfirmed 0 and 1,
       a mapping row already at StatusId 0), the Action Text on a confirmed
       pair with a Unicode text; every column of Action_Item, the mapping
       rows and Minutes; and the values expected by name;
     - each role refused (Manager, User, Management, MD Secretariat, Admin:
       Reason 4), the system account (12), an inactive Controller, a missing
       user, 0 and NULL (8), for both procedures, and nothing written;
     - Submit by the Controller refused as a whole when one row is bad:
       an unknown item LAST of four and FIRST of four, an id given twice, a
       tick of 2 or missing, an id that is not a whole number, too large or
       negative, an element other than <i>, two roots, no list (NULL); every
       row as it was. An empty list: Result 1, nothing written;
     - Save of the Action Text refused for an unknown and a NULL item;
     - the Rollback's two DROPs run here; the rollback of the transaction
       puts step 46 back.

   Afterwards: nothing of ZZ46 is left, the agenda, minutes, action item and
   mapping tables are unchanged and every identity counter is put back.

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
-- Replaced by step 47 (step FU1): step 47 changed what the two procedures write (only the rows changed to Confirmed;
-- a confirmed item is final), so these checks no longer apply; BMMS-Test-FollowupFinal-Step47.sql carries those that
-- still hold. With step 47 rolled back this script runs as before.
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') LIKE '%FollowupFinal-Step47%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') LIKE '%FollowupFinal-Step47%')
BEGIN
    RAISERROR('Step 47 is installed in "%s": it replaced the two procedures of step 46. Run BMMS-Test-FollowupFinal-Step47.sql instead (it carries the step 46 checks that still hold). This script ran no check; this is not a failure.', 10, 1, @CurrentDatabase) WITH NOWAIT;
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') NOT LIKE '%FollowupSave-Step46%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') NOT LIKE '%FollowupSave-Step46%')
BEGIN
    RAISERROR('Step 46 (BMMS-Fix-FollowupSave-Step46.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('tempdb..#T') IS NOT NULL OR OBJECT_ID('tempdb..#Ident') IS NOT NULL OR OBJECT_ID('tempdb..#ZZ46State') IS NOT NULL)
BEGIN
    RAISERROR('This query window still has temporary objects of an earlier run. Open a NEW query window and run the script there. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(1000), Actual VARCHAR(1000));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-- The state of every ZZ46 row (action items, their mapping rows, their minutes) as one text, to prove that a refused
-- call writes nothing
CREATE PROCEDURE #ZZ46State
@S NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @S = ISNULL((SELECT CAST(a.ActionItemId AS NVARCHAR(12)) + N'|' + ISNULL(CAST(a.IsComplied AS NVARCHAR(12)), N'n') + N'|'
                          + ISNULL(CAST(a.IsConfirmed AS NVARCHAR(12)), N'n') + N'|' + ISNULL(a.ActionText, N'n') + N'|'
                          + ISNULL(CAST(a.ActionStatus AS NVARCHAR(50)), N'n') + N'|' + ISNULL(CONVERT(NVARCHAR(23), a.UpdatedOn, 121), N'n') + N'|'
                          + ISNULL(CAST(a.UpdatedBy AS NVARCHAR(12)), N'n') + N'|' + ISNULL(a.Directions, N'n') + N';'
                     FROM Action_Item a WHERE a.Directions = N'ZZ46' ORDER BY a.ActionItemId
                     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'')
           + N'#'
           + ISNULL((SELECT CAST(m.ActionItemUserMapId AS NVARCHAR(12)) + N'|' + CAST(m.ActionItemId AS NVARCHAR(12)) + N'|'
                          + ISNULL(CAST(m.UserId AS NVARCHAR(12)), N'n') + N'|' + ISNULL(CAST(m.ReadStatus AS NVARCHAR(12)), N'n') + N'|'
                          + ISNULL(CAST(m.StatusId AS NVARCHAR(12)), N'n') + N';'
                     FROM ActionItem_User_Map m INNER JOIN Action_Item a ON a.ActionItemId = m.ActionItemId
                     WHERE a.Directions = N'ZZ46' ORDER BY m.ActionItemUserMapId
                     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'')
           + N'#'
           + ISNULL((SELECT CAST(mi.MinutesId AS NVARCHAR(12)) + N'|' + ISNULL(mi.ActualResolution, N'n') + N'|'
                          + ISNULL(CAST(mi.StatusId AS NVARCHAR(12)), N'n') + N'|' + ISNULL(CONVERT(NVARCHAR(23), mi.DueDate, 121), N'n') + N';'
                     FROM Minutes mi INNER JOIN Action_Item a ON a.MinutesId = mi.MinutesId
                     WHERE a.Directions = N'ZZ46' ORDER BY mi.MinutesId
                     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'');
END
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T SELECT 'Marker FollowupSave-Step46 in the two new procedures', '2',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_SaveFollowupActionText'), ('spr_SaveFollowupConfirmed')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupSave-Step46%') AS VARCHAR(12));

INSERT INTO #T SELECT 'spr_SaveFollowupActionText: the parameters in their order',
       '@ActingUserId,@ActionItemId,@ActionText,@Result,@Reason',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupActionText') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '');

INSERT INTO #T SELECT 'spr_SaveFollowupConfirmed: the parameters in their order, @Items of type xml',
       '@ActingUserId,@Items,@Result,@Reason,@Saved | xml',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupConfirmed') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '')
     + ' | ' + ISNULL((SELECT TYPE_NAME(p.user_type_id) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupConfirmed') AND p.name = '@Items'), '-');

INSERT INTO #T SELECT 'OUTPUT parameters: action text 2, confirmed 3', '2, 3',
       CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupActionText') AND p.is_output = 1) AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupConfirmed') AND p.is_output = 1) AS VARCHAR(12));

INSERT INTO #T SELECT 'Neither procedure returns a result set (the answer is in the outputs)', '0 0',
       CAST((SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_SaveFollowupActionText'), 0) WHERE name IS NOT NULL) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_SaveFollowupConfirmed'), 0) WHERE name IS NOT NULL) AS VARCHAR(12));

INSERT INTO #T SELECT 'No feature above compatibility level 100 in the two texts (THROW, IIF, CONCAT, FORMAT, TRY_CONVERT, OFFSET, STRING_AGG, EOMONTH)', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_SaveFollowupActionText'), ('spr_SaveFollowupConfirmed')) o(Name)
             CROSS JOIN (VALUES ('%THROW%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('%TRY[_]CONVERT%'), ('% OFFSET %'), ('%STRING[_]AGG%'), ('%EOMONTH%')) f(Pattern)
             WHERE UPPER(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name))) LIKE f.Pattern) AS VARCHAR(12));

-- spr_UpdateActionItem is left as step 31 installed it (SHA-1 of the text without carriage returns)
INSERT INTO #T SELECT 'spr_UpdateActionItem is the step 31 text (SHA-1), with the step 31 marker and no FollowupSave-Step46 marker', 'same, 1, 0',
       CASE WHEN CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateActionItem')), CHAR(13), '') AS NVARCHAR(4000))), 2)
                 = '7EC3DBDD2E40D966EDFA54EEBF52EF18797EF865' THEN 'same' ELSE 'differs' END + ', '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateActionItem')) LIKE '%UnicodeText-Step31%' THEN '1' ELSE '0' END + ', '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateActionItem')) LIKE '%FollowupSave-Step46%' THEN '1' ELSE '0' END;

INSERT INTO #T SELECT 'The Dashboard save of step 43 and the objects of step 45 are not changed (markers 43 and 45 as before, no FollowupSave-Step46 marker)', '1, 5, 0',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')) LIKE '%DashboardAlerts-Step43%' THEN '1' ELSE '0' END + ', '
     + CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardCommitteeFilter'), ('spr_GetDashboardSummary'), ('spr_GetDashboardMeetings'),
                                          ('spr_GetDashboardApprovals'), ('spr_GetDashboardActionItems')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardSummary-Step45%') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM sys.sql_modules sm
             WHERE sm.definition LIKE '%FollowupSave-Step46%'
               AND sm.object_id NOT IN (OBJECT_ID('dbo.spr_SaveFollowupActionText'), OBJECT_ID('dbo.spr_SaveFollowupConfirmed'))) AS VARCHAR(12));
GO

-- Every database user who can run step 42's spr_GetDashboardDepartments (the application login among them) can run the
-- two procedures of this step. Asked of the server as that user (EXECUTE AS USER), so a schema grant counts.
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
                        HAS_PERMS_BY_NAME('dbo.spr_SaveFollowupActionText', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_SaveFollowupConfirmed', 'OBJECT', 'EXECUTE') ELSE -1 END;
        REVERT;
        IF (@Can >= 0) SET @Users = @Users + 1;
        IF (@Can >= 0 AND @Can < 2)
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
INSERT INTO #T SELECT 'EXECUTE: database users who can run step 42''s department procedure but not both procedures of step 46 (' + CAST(@Users AS VARCHAR(12)) + ' such users asked)',
       '0', CAST(@Cannot AS VARCHAR(12)) + CASE WHEN @Cannot > 0 THEN ':' + @Names ELSE '' END;
GO

-------------------------------------------------------------------------------
-- Part 2
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(1000), Actual VARCHAR(1000));
DECLARE @Item TABLE (K INT PRIMARY KEY, ActionItemId INT, MinutesId INT);
DECLARE @Pair TABLE (K INT PRIMARY KEY, NewId INT, OldId INT, Tick INT);
DECLARE @Case TABLE (Seq INT IDENTITY(1,1) PRIMARY KEY, Label VARCHAR(100), UserId INT NULL, Expected INT);

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @Missing INT = (SELECT ISNULL(MAX(UserId), 0) + 100000 FROM Users);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @rMd INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @Followup INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type ORDER BY DecisionTypeId);

DECLARE @DA INT, @CZ INT, @MeetingId INT;
DECLARE @Ctl INT, @Mgr INT, @Usr INT, @Gmt INT, @Mds INT, @Adm INT, @Off INT;
DECLARE @R INT, @Rs INT, @Sv INT, @R2 INT, @Rs2 INT;
DECLARE @X XML;
DECLARE @Str NVARCHAR(MAX);
DECLARE @Before NVARCHAR(MAX), @After NVARCHAR(MAX);
DECLARE @Txt VARCHAR(1000);
DECLARE @Uni NVARCHAR(200) = N'ZZ46 action text ' + NCHAR(2949) + NCHAR(2965) + NCHAR(3014) + N' <p>end</p>';
DECLARE @G1 INT, @G2 INT, @G3 INT, @G4 INT, @Unknown INT;
DECLARE @Seq INT, @Label VARCHAR(100), @CaseUser INT, @Expected INT;
DECLARE @AgendaBefore VARCHAR(40), @MinBefore VARCHAR(40), @ActBefore VARCHAR(40), @MapBefore VARCHAR(40);
DECLARE @AgendaAfter VARCHAR(40), @MinAfter VARCHAR(40), @ActAfter VARCHAR(40), @MapAfter VARCHAR(40);

SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MeetingId, DepartmentId, UpdatedOn)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MinBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, AgendaId, DecisionTypeId, DueDate, StatusId, ActualResolution)), 0) AS VARCHAR(12)) FROM Minutes;
SELECT @ActBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, ActionText, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;

SET @Unknown = (SELECT ISNULL(MAX(ActionItemId), 0) + 100000 FROM Action_Item);

BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ46A', 'ZZ46 department A', 996, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ46 controller', @DA, @Desig, NULL, @rCtl, 'zz46c@example.invalid', 'zz46ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ46 manager', @DA, @Desig, NULL, @rMgr, 'zz46m@example.invalid', 'zz46mgr', 'not-a-login', 1, @Now);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ46 user', @DA, @Desig, @Mgr, @rUser, 'zz46u@example.invalid', 'zz46usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ46 management', @DA, @Desig, NULL, @rMgmt, 'zz46g@example.invalid', 'zz46gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ46 md secretariat', @DA, @Desig, NULL, @rMd, 'zz46s@example.invalid', 'zz46mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ46 admin', @DA, @Desig, NULL, @rAdmin, 'zz46a@example.invalid', 'zz46adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ46 inactive controller', @DA, @Desig, NULL, @rCtl, 'zz46i@example.invalid', 'zz46off', 'not-a-login', 0, @Now);
    SET @Off = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z46', 'ZZ46 committee', '2000-01-01', 1, 0);
    SET @CZ = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94601', @CZ, 'ZZ46 test', 'ZZ', DATEADD(DAY, -5, @Day), '10:00', DATEADD(DAY, -7, @Day), 'Close', 'F', @Now, @Sys);
    SET @MeetingId = SCOPE_IDENTITY();

    -- 17 approved items, one minute (Followup) and one action item each
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT 'ZZ46-' + RIGHT('0' + CAST(n.K AS VARCHAR(2)), 2), @CZ, @MeetingId, @DA, @SubjectTypeId, 'ZZ46 item ' + CAST(n.K AS VARCHAR(2)),
           'Entry', 'ACA', 'New', @Now, @Ctl
    FROM (SELECT TOP 17 ROW_NUMBER() OVER (ORDER BY object_id) AS K FROM sys.objects) n;

    INSERT INTO Minutes (AgendaId, DecisionTypeId, DueDate, StatusId, CreatedOn, CreatedBy, ActualResolution)
    SELECT a.AgendaId, @Followup, NULL, 0, @Now, @Sys, N'ZZ46 resolution ' + a.AgendaNo
    FROM Agenda a WHERE a.AgendaNo LIKE 'ZZ46-%';

    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)
    SELECT mi.MinutesId, N'ZZ46', N'ZZ46 text ' + a.AgendaNo, '', 0, 0, DATEADD(DAY, -1, @Now), @Sys
    FROM Minutes mi INNER JOIN Agenda a ON a.AgendaId = mi.AgendaId
    WHERE a.AgendaNo LIKE 'ZZ46-%';

    INSERT INTO @Item (K, ActionItemId, MinutesId)
    SELECT CAST(RIGHT(a.AgendaNo, 2) AS INT), ai.ActionItemId, ai.MinutesId
    FROM Action_Item ai INNER JOIN Minutes mi ON mi.MinutesId = ai.MinutesId INNER JOIN Agenda a ON a.AgendaId = mi.AgendaId
    WHERE a.AgendaNo LIKE 'ZZ46-%';

    -- Two mapping rows per item (the Controller and the User), read, StatusId 1
    INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId)
    SELECT i.ActionItemId, u.UserId, 1, 1
    FROM @Item i CROSS JOIN (SELECT @Ctl AS UserId UNION ALL SELECT @Usr) u;

    -- The twin pairs for the Submit: K 1 to 6 by the new procedure, K 7 to 12 the same starts by spr_UpdateActionItem.
    -- Start (IsComplied, IsConfirmed) and tick: (1,1) 0; (1,1) 1; (0,0) 0; (0,0) 1; (1,0) 1; (0,1) 0, and in pair 6 the
    -- Controller's mapping row already at StatusId 0.
    INSERT INTO @Pair (K, NewId, OldId, Tick)
    SELECT n.K, n.ActionItemId, o.ActionItemId, x.Tick
    FROM (SELECT 1 AS K, 0 AS Tick UNION ALL SELECT 2, 1 UNION ALL SELECT 3, 0 UNION ALL SELECT 4, 1 UNION ALL SELECT 5, 1 UNION ALL SELECT 6, 0) x
    INNER JOIN @Item n ON n.K = x.K
    INNER JOIN @Item o ON o.K = x.K + 6;

    UPDATE a SET IsComplied = s.C, IsConfirmed = s.F
    FROM Action_Item a
    INNER JOIN @Pair p ON a.ActionItemId IN (p.NewId, p.OldId)
    INNER JOIN (SELECT 1 AS K, 1 AS C, 1 AS F UNION ALL SELECT 2, 1, 1 UNION ALL SELECT 3, 0, 0 UNION ALL SELECT 4, 0, 0
                UNION ALL SELECT 5, 1, 0 UNION ALL SELECT 6, 0, 1) s ON s.K = p.K;
    UPDATE m SET StatusId = 0
    FROM ActionItem_User_Map m INNER JOIN @Pair p ON m.ActionItemId IN (p.NewId, p.OldId)
    WHERE p.K = 6 AND m.UserId = @Ctl;
    -- The twins get the same action text, so every column can be compared
    UPDATE a SET ActionText = N'ZZ46 text pair ' + CAST(p.K AS NVARCHAR(2))
    FROM Action_Item a INNER JOIN @Pair p ON a.ActionItemId IN (p.NewId, p.OldId);

    -- K 13 and 14: the Action Text pair, a confirmed item each (the Followup page saves a confirmed item's text too)
    UPDATE a SET IsComplied = 0, IsConfirmed = 1, ActionText = N'ZZ46 text pair 13'
    FROM Action_Item a INNER JOIN @Item i ON i.ActionItemId = a.ActionItemId WHERE i.K IN (13, 14);
    -- K 15 to 17: good rows for the refused Submits (IsComplied 1: a written row would show)
    UPDATE a SET IsComplied = 1, IsConfirmed = 0
    FROM Action_Item a INNER JOIN @Item i ON i.ActionItemId = a.ActionItemId WHERE i.K IN (15, 16, 17);
    SELECT @G1 = ActionItemId FROM @Item WHERE K = 15;
    SELECT @G2 = ActionItemId FROM @Item WHERE K = 16;
    SELECT @G3 = ActionItemId FROM @Item WHERE K = 17;
    SELECT @G4 = ActionItemId FROM @Item WHERE K = 1;

    INSERT INTO @T SELECT 'Made-up data: department, users, committee, meeting, items, action items, mapping rows', '1, 7, 1, 1, 17, 17, 34',
           CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ46%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz46%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z46') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ46 test') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'ZZ46-%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ46') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m INNER JOIN @Item i ON i.ActionItemId = m.ActionItemId) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Submit: the new procedure on K 1 to 6, spr_UpdateActionItem row by row on K 7 to 12 (as the page did)
    ---------------------------------------------------------------------------
    SET @Str = N'<items>' + ISNULL((SELECT N'<i id="' + CAST(p.NewId AS NVARCHAR(12)) + N'" c="' + CAST(p.Tick AS NVARCHAR(1)) + N'"/>'
                                    FROM @Pair p ORDER BY p.K FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'') + N'</items>';
    SET @X = CAST(@Str AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT;
    INSERT INTO @T SELECT 'Submit by the Controller, six rows in one call: Result, Reason, Saved', '1 0 6',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12));

    DECLARE @OldId INT, @Tick INT;
    DECLARE PairCursor CURSOR LOCAL FAST_FORWARD FOR SELECT OldId, Tick FROM @Pair ORDER BY K;
    OPEN PairCursor;
    FETCH NEXT FROM PairCursor INTO @OldId, @Tick;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        EXEC dbo.spr_UpdateActionItem @Code = 'All', @ActionItemId = @OldId, @ActualResolution = N'', @ActionText = N'', @IsComplied = 0, @IsConfirmed = @Tick;
        FETCH NEXT FROM PairCursor INTO @OldId, @Tick;
    END
    CLOSE PairCursor;
    DEALLOCATE PairCursor;

    INSERT INTO @T SELECT 'Submit: every column of Action_Item of the six pairs is the same as spr_UpdateActionItem wrote (pairs that differ)', '0',
           CAST((SELECT COUNT(*) FROM @Pair p
                 INNER JOIN Action_Item n ON n.ActionItemId = p.NewId
                 INNER JOIN Action_Item o ON o.ActionItemId = p.OldId
                 WHERE NOT (ISNULL(n.IsComplied, -1) = ISNULL(o.IsComplied, -1)
                        AND ISNULL(n.IsConfirmed, -1) = ISNULL(o.IsConfirmed, -1)
                        AND ISNULL(CAST(n.ActionText AS VARBINARY(MAX)), 0x00) = ISNULL(CAST(o.ActionText AS VARBINARY(MAX)), 0x00)
                        AND ISNULL(n.ActionStatus, '~') = ISNULL(o.ActionStatus, '~')
                        AND ISNULL(n.UpdatedOn, '19000101') = ISNULL(o.UpdatedOn, '19000101')
                        AND ISNULL(n.UpdatedBy, -1) = ISNULL(o.UpdatedBy, -1)
                        AND ISNULL(CAST(n.Directions AS VARBINARY(MAX)), 0x00) = ISNULL(CAST(o.Directions AS VARBINARY(MAX)), 0x00))) AS VARCHAR(12));

    INSERT INTO @T SELECT 'Submit: the mapping rows of the six pairs are the same as spr_UpdateActionItem left them (rows that differ)', '0',
           CAST((SELECT COUNT(*) FROM
                 ((SELECT p.K, m.UserId, m.ReadStatus, m.StatusId FROM @Pair p INNER JOIN ActionItem_User_Map m ON m.ActionItemId = p.NewId
                   EXCEPT
                   SELECT p.K, m.UserId, m.ReadStatus, m.StatusId FROM @Pair p INNER JOIN ActionItem_User_Map m ON m.ActionItemId = p.OldId)
                  UNION ALL
                  (SELECT p.K, m.UserId, m.ReadStatus, m.StatusId FROM @Pair p INNER JOIN ActionItem_User_Map m ON m.ActionItemId = p.OldId
                   EXCEPT
                   SELECT p.K, m.UserId, m.ReadStatus, m.StatusId FROM @Pair p INNER JOIN ActionItem_User_Map m ON m.ActionItemId = p.NewId)) d) AS VARCHAR(12));

    INSERT INTO @T SELECT 'Submit, by name: IsComplied and IsConfirmed of pairs 1 to 6 (IsComplied 0 on every row, IsConfirmed the tick)', '0 0, 0 1, 0 0, 0 1, 0 1, 0 0',
           STUFF((SELECT ', ' + CAST(a.IsComplied AS VARCHAR(2)) + ' ' + CAST(a.IsConfirmed AS VARCHAR(2))
                  FROM @Pair p INNER JOIN Action_Item a ON a.ActionItemId = p.NewId ORDER BY p.K FOR XML PATH('')), 1, 2, '');

    INSERT INTO @T SELECT 'Submit, by name: StatusId of the two mapping rows (Controller, User) of pairs 1 to 6 (a tick sets 0, no tick leaves them)', '1 1, 0 0, 1 1, 0 0, 0 0, 0 1',
           STUFF((SELECT ', ' + CAST((SELECT m.StatusId FROM ActionItem_User_Map m WHERE m.ActionItemId = p.NewId AND m.UserId = @Ctl) AS VARCHAR(2)) + ' '
                             + CAST((SELECT m.StatusId FROM ActionItem_User_Map m WHERE m.ActionItemId = p.NewId AND m.UserId = @Usr) AS VARCHAR(2))
                  FROM @Pair p ORDER BY p.K FOR XML PATH('')), 1, 2, '');

    INSERT INTO @T SELECT 'Submit: the action text, the minutes (Actual Resolution) and UpdatedOn / UpdatedBy of pairs 1 to 6 untouched (rows changed)', '0',
           CAST((SELECT COUNT(*) FROM @Pair p
                 INNER JOIN @Item i ON i.ActionItemId = p.NewId
                 INNER JOIN Action_Item a ON a.ActionItemId = p.NewId
                 INNER JOIN Minutes mi ON mi.MinutesId = i.MinutesId
                 INNER JOIN Agenda ag ON ag.AgendaId = mi.AgendaId
                 WHERE CAST(a.ActionText AS VARBINARY(MAX)) <> CAST(N'ZZ46 text pair ' + CAST(p.K AS NVARCHAR(2)) AS VARBINARY(MAX))
                    OR CAST(mi.ActualResolution AS VARBINARY(MAX)) <> CAST(N'ZZ46 resolution ' + ag.AgendaNo AS VARBINARY(MAX))
                    OR a.UpdatedBy <> @Sys OR a.UpdatedOn <> DATEADD(DAY, -1, @Now)) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Save of the Action Text: the new procedure on K 13, spr_UpdateActionItem 'ActionText' on K 14
    ---------------------------------------------------------------------------
    DECLARE @N13 INT = (SELECT ActionItemId FROM @Item WHERE K = 13);
    DECLARE @O14 INT = (SELECT ActionItemId FROM @Item WHERE K = 14);
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = @N13, @ActionText = @Uni, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    EXEC dbo.spr_UpdateActionItem @Code = 'ActionText', @ActionItemId = @O14, @ActualResolution = N'', @ActionText = @Uni, @IsComplied = 0, @IsConfirmed = 0;
    INSERT INTO @T SELECT 'Action Text by the Controller on a confirmed item: Result, Reason', '1 0', CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12));
    INSERT INTO @T SELECT 'Action Text: the text is written letter for letter (Unicode), the item stays confirmed and not complied', 'same, 0 1',
           CASE WHEN CAST(a.ActionText AS VARBINARY(MAX)) = CAST(@Uni AS VARBINARY(MAX)) THEN 'same' ELSE 'differs' END + ', '
         + CAST(a.IsComplied AS VARCHAR(2)) + ' ' + CAST(a.IsConfirmed AS VARCHAR(2))
    FROM Action_Item a WHERE a.ActionItemId = @N13;
    INSERT INTO @T SELECT 'Action Text: every column of Action_Item, the mapping rows and the minutes are the same as spr_UpdateActionItem left them', 'same, same, same',
           CASE WHEN ISNULL(n.IsComplied, -1) = ISNULL(o.IsComplied, -1) AND ISNULL(n.IsConfirmed, -1) = ISNULL(o.IsConfirmed, -1)
                 AND CAST(n.ActionText AS VARBINARY(MAX)) = CAST(o.ActionText AS VARBINARY(MAX)) AND ISNULL(n.ActionStatus, '~') = ISNULL(o.ActionStatus, '~')
                 AND n.UpdatedOn = o.UpdatedOn AND n.UpdatedBy = o.UpdatedBy AND n.Directions = o.Directions THEN 'same' ELSE 'differs' END + ', '
         + CASE WHEN NOT EXISTS (SELECT m.UserId, m.ReadStatus, m.StatusId FROM ActionItem_User_Map m WHERE m.ActionItemId = @N13
                                 EXCEPT SELECT m.UserId, m.ReadStatus, m.StatusId FROM ActionItem_User_Map m WHERE m.ActionItemId = @O14)
                 AND NOT EXISTS (SELECT m.UserId, m.ReadStatus, m.StatusId FROM ActionItem_User_Map m WHERE m.ActionItemId = @O14
                                 EXCEPT SELECT m.UserId, m.ReadStatus, m.StatusId FROM ActionItem_User_Map m WHERE m.ActionItemId = @N13)
                 AND (SELECT COUNT(*) FROM ActionItem_User_Map m WHERE m.ActionItemId = @N13 AND m.StatusId = 1 AND m.ReadStatus = 1) = 2
                THEN 'same' ELSE 'differs' END + ', '
         + CASE WHEN (SELECT COUNT(*) FROM Minutes mi INNER JOIN @Item i ON i.MinutesId = mi.MinutesId INNER JOIN Agenda ag ON ag.AgendaId = mi.AgendaId
                      WHERE i.K IN (13, 14) AND CAST(mi.ActualResolution AS VARBINARY(MAX)) = CAST(N'ZZ46 resolution ' + ag.AgendaNo AS VARBINARY(MAX))) = 2
                THEN 'same' ELSE 'differs' END
    FROM Action_Item n CROSS JOIN Action_Item o
    WHERE n.ActionItemId = @N13 AND o.ActionItemId = @O14;

    ---------------------------------------------------------------------------
    -- Refused acting users, for both procedures; nothing written
    ---------------------------------------------------------------------------
    INSERT INTO @Case (Label, UserId, Expected) VALUES
    ('a Manager', @Mgr, 4), ('a User', @Usr, 4), ('Management', @Gmt, 4), ('MD Secretariat', @Mds, 4), ('an Admin', @Adm, 4),
    ('the system account', @Sys, 12), ('an inactive Controller', @Off, 8), ('a user id that does not exist', @Missing, 8),
    ('acting user 0', 0, 8), ('acting user NULL', NULL, 8);

    SET @Str = N'<items><i id="' + CAST(@G1 AS NVARCHAR(12)) + N'" c="1"/><i id="' + CAST(@G2 AS NVARCHAR(12)) + N'" c="1"/></items>';
    SET @X = CAST(@Str AS XML);

    DECLARE CaseCursor CURSOR LOCAL FAST_FORWARD FOR SELECT Seq, Label, UserId, Expected FROM @Case ORDER BY Seq;
    OPEN CaseCursor;
    FETCH NEXT FROM CaseCursor INTO @Seq, @Label, @CaseUser, @Expected;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        EXEC #ZZ46State @S = @Before OUTPUT;
        EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @CaseUser, @ActionItemId = @G1, @ActionText = N'ZZ46 must not be written', @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
        EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @CaseUser, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT;
        EXEC #ZZ46State @S = @After OUTPUT;
        INSERT INTO @T SELECT 'Refused: ' + @Label + ' (Action Text Result Reason; Submit Result Reason Saved; ZZ46 rows)',
               '0 ' + CAST(@Expected AS VARCHAR(2)) + '; 0 ' + CAST(@Expected AS VARCHAR(2)) + ' 0; unchanged',
               CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + '; ' + CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + '; '
             + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;
        FETCH NEXT FROM CaseCursor INTO @Seq, @Label, @CaseUser, @Expected;
    END
    CLOSE CaseCursor;
    DEALLOCATE CaseCursor;

    ---------------------------------------------------------------------------
    -- Submit by the Controller refused as a whole when one row is bad; every row as it was
    ---------------------------------------------------------------------------
    DECLARE @Bad TABLE (Seq INT IDENTITY(1,1) PRIMARY KEY, Label VARCHAR(150), Body NVARCHAR(MAX) NULL);
    DECLARE @Good NVARCHAR(MAX) = N'<i id="' + CAST(@G1 AS NVARCHAR(12)) + N'" c="1"/><i id="' + CAST(@G2 AS NVARCHAR(12)) + N'" c="1"/><i id="' + CAST(@G3 AS NVARCHAR(12)) + N'" c="1"/>';
    INSERT INTO @Bad (Label, Body) VALUES
    ('an unknown item LAST of four', N'<items>' + @Good + N'<i id="' + CAST(@Unknown AS NVARCHAR(12)) + N'" c="1"/></items>'),
    ('an unknown item FIRST of four', N'<items><i id="' + CAST(@Unknown AS NVARCHAR(12)) + N'" c="1"/>' + @Good + N'</items>'),
    ('an id given twice (the last row repeats the first)', N'<items>' + @Good + N'<i id="' + CAST(@G1 AS NVARCHAR(12)) + N'" c="0"/></items>'),
    ('a tick of 2 in the last row', N'<items>' + @Good + N'<i id="' + CAST(@G4 AS NVARCHAR(12)) + N'" c="2"/></items>'),
    ('no tick in the last row', N'<items>' + @Good + N'<i id="' + CAST(@G4 AS NVARCHAR(12)) + N'"/></items>'),
    ('an id that is not a whole number in the last row', N'<items>' + @Good + N'<i id="1x" c="1"/></items>'),
    ('an id with a space in the last row', N'<items>' + @Good + N'<i id=" ' + CAST(@G4 AS NVARCHAR(12)) + N'" c="1"/></items>'),
    ('a negative id in the last row', N'<items>' + @Good + N'<i id="-5" c="1"/></items>'),
    ('an id larger than an INT in the last row', N'<items>' + @Good + N'<i id="9999999999" c="1"/></items>'),
    ('an id of 11 digits in the last row', N'<items>' + @Good + N'<i id="00000000001" c="1"/></items>'),
    ('an element other than <i> at the end', N'<items>' + @Good + N'<x id="' + CAST(@G4 AS NVARCHAR(12)) + N'" c="1"/></items>'),
    ('two roots', N'<items>' + @Good + N'</items><items/>'),
    ('another root name', N'<rows>' + @Good + N'</rows>'),
    ('no list (NULL)', NULL);

    DECLARE @Body NVARCHAR(MAX);
    DECLARE BadCursor CURSOR LOCAL FAST_FORWARD FOR SELECT Label, Body FROM @Bad ORDER BY Seq;
    OPEN BadCursor;
    FETCH NEXT FROM BadCursor INTO @Label, @Body;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @X = CAST(@Body AS XML);
        EXEC #ZZ46State @S = @Before OUTPUT;
        EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT;
        EXEC #ZZ46State @S = @After OUTPUT;
        INSERT INTO @T SELECT 'Submit by the Controller refused, ' + @Label + ': Result Reason Saved; every row as it was', '0 4 0; unchanged',
               CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + '; '
             + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;
        FETCH NEXT FROM BadCursor INTO @Label, @Body;
    END
    CLOSE BadCursor;
    DEALLOCATE BadCursor;

    -- The good rows of those lists alone are saved (so the refusals above were for the bad row only)
    SET @Str = N'<items>' + @Good + N'</items>';
    SET @X = CAST(@Str AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT;
    INSERT INTO @T SELECT 'The three good rows of those lists alone: saved (Result Reason Saved; IsComplied IsConfirmed of each)', '1 0 3; 0 1, 0 1, 0 1',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + '; '
         + STUFF((SELECT ', ' + CAST(a.IsComplied AS VARCHAR(2)) + ' ' + CAST(a.IsConfirmed AS VARCHAR(2))
                  FROM Action_Item a INNER JOIN @Item i ON i.ActionItemId = a.ActionItemId WHERE i.K IN (15, 16, 17) ORDER BY i.K FOR XML PATH('')), 1, 2, '');

    -- An empty list: nothing to write, as an empty page before
    SET @X = CAST(N'<items/>' AS XML);
    EXEC #ZZ46State @S = @Before OUTPUT;
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT;
    EXEC #ZZ46State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Submit by the Controller of an empty list: Result Reason Saved; nothing written', '1 0 0; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;

    -- The procedure kept the caller's transaction open (it never rolls back a transaction it did not begin)
    INSERT INTO @T SELECT 'After the refused and the done Submits the test''s own transaction is still open (@@TRANCOUNT)', '1', CAST(@@TRANCOUNT AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Save of the Action Text refused for an unknown and a NULL item
    ---------------------------------------------------------------------------
    EXEC #ZZ46State @S = @Before OUTPUT;
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = @Unknown, @ActionText = N'ZZ46 must not be written', @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = NULL, @ActionText = N'ZZ46 must not be written', @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
    EXEC #ZZ46State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Action Text by the Controller for an unknown and a NULL item: Result Reason each; nothing written', '0 4, 0 4; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ', ' + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;
    INSERT INTO @T SELECT 'Nowhere in Action_Item is the text of a refused save', '0',
           CAST((SELECT COUNT(*) FROM Action_Item WHERE ActionText = N'ZZ46 must not be written') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The Rollback's DROPs, here inside the transaction
    ---------------------------------------------------------------------------
    EXEC (N'DROP PROCEDURE dbo.spr_SaveFollowupActionText;');
    EXEC (N'DROP PROCEDURE dbo.spr_SaveFollowupConfirmed;');
    INSERT INTO @T SELECT 'The Rollback''s two DROPs: both procedures gone, spr_UpdateActionItem still there', '0, 1',
           CAST((SELECT COUNT(*) FROM sys.objects WHERE name IN ('spr_SaveFollowupActionText', 'spr_SaveFollowupConfirmed')) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM sys.objects WHERE name = 'spr_UpdateActionItem' AND type = 'P') AS VARCHAR(12));

END TRY
BEGIN CATCH
    SET @Txt = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error', @Txt);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MeetingId, DepartmentId, UpdatedOn)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MinAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, AgendaId, DecisionTypeId, DueDate, StatusId, ActualResolution)), 0) AS VARCHAR(12)) FROM Minutes;
SELECT @ActAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, ActionText, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;
INSERT INTO @T SELECT 'After the rollback: Agenda unchanged (count, checksum)', @AgendaBefore, @AgendaAfter;
INSERT INTO @T SELECT 'After the rollback: Minutes unchanged (count, checksum)', @MinBefore, @MinAfter;
INSERT INTO @T SELECT 'After the rollback: Action_Item unchanged (count, checksum)', @ActBefore, @ActAfter;
INSERT INTO @T SELECT 'After the rollback: ActionItem_User_Map unchanged (count, checksum)', @MapBefore, @MapAfter;
INSERT INTO @T SELECT 'After the rollback: step 46 is installed again (markers in the two procedures), no transaction open', '2, 0',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_SaveFollowupActionText'), ('spr_SaveFollowupConfirmed')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupSave-Step46%') AS VARCHAR(12)) + ', '
     + CAST(@@TRANCOUNT AS VARCHAR(12));

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
SELECT 'After the test: no ZZ46 department, user, committee, meeting, item or action item left', '0 0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ46%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz46%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z46') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ46 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'ZZ46-%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ46') AS VARCHAR(12));

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

DROP PROCEDURE #ZZ46State;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
