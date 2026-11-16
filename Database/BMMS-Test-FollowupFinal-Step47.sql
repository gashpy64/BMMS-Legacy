/* ============================================================================
   BMMS - Test of step 47 (a confirmed followup becomes final; Reopen with a
   reason; history; step FU1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 47
   is not installed.

   Run it in a NEW query window (it uses temporary objects of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS.

   Part 1 reads only: the markers (and the kept markers of steps 46 and 39),
   the parameters, the result sets, no feature above compatibility level
   100; the table, its keys, checks and index; no procedure updates or
   deletes the table by name; spr_UpdateActionItem and the objects of steps
   43 and 45 unchanged; every database user who can run step 42's procedure
   can run the two new procedures.

   Part 2, inside ONE transaction that is rolled back (made-up data ZZ47: two
   departments, a committee, three meetings, the six roles, a second and an
   inactive Controller, 22 action items with two mapping rows each):
     - Submit: only the rows sent (changed to Confirmed) are written, with a
       Confirm history row each; a row already confirmed is skipped (another
       Controller, or another tab), counted, not refused; the step 46 shape
       (attribute c) and every bad list refused as a whole, nothing written;
     - Action Text: saved on a pending item; Reason 26 on a confirmed one;
     - Reopen: IsConfirmed 0 and a Reopen row with the trimmed reason; Reason
       27 when not confirmed; Reason 4 for a blank, NULL or tab-only reason
       and an unknown item; the mapping rows and IsComplied left as they are;
       a reopened item is editable and can be confirmed again;
     - every role refused (Manager, User, Management, MD Secretariat, Admin:
       4; the system account 12; an inactive Controller, a missing user, 0
       and NULL: 8) for the three saves, and the list for every role but the
       Controller and the MD Secretariat; nothing written;
     - the list: the latest history row per item and who acted; an item
       confirmed before step 47 has none; parity with the query of
       ReportsMgr.GetFollowupReport for 24 filter combinations;
     - a reopened item counts as not confirmed in fn_DashboardActionItems
       (listed, Overdue), View_Action_Item and the Management report;
     - the history rows go with their item: spr_UpdateMinutes (decision no
       longer Followup), spr_DeleteAgendaByAgendaId,
       spr_AgendaFinalizeByMeetingId and a direct DELETE (as a test clean-up
       does); spr_DeleteUserByUserId refuses a user with history rows
       (Reason 6, 'minutes') and still deletes a user without.

   Afterwards: nothing of ZZ47 is left, the agenda, minutes, action item,
   mapping and history tables are unchanged and every identity counter is
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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') NOT LIKE '%FollowupFinal-Step47%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') NOT LIKE '%FollowupFinal-Step47%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') NOT LIKE '%FollowupFinal-Step47%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') NOT LIKE '%FollowupFinal-Step47%'
         OR OBJECT_ID('dbo.Action_Item_Status_History', 'U') IS NULL)
BEGIN
    RAISERROR('Step 47 (BMMS-Fix-FollowupFinal-Step47.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('tempdb..#T') IS NOT NULL OR OBJECT_ID('tempdb..#Ident') IS NOT NULL OR OBJECT_ID('tempdb..#ZZ47State') IS NOT NULL
         OR OBJECT_ID('tempdb..#ZZ47List') IS NOT NULL OR OBJECT_ID('tempdb..#ZZ47Old') IS NOT NULL)
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

-- The state of every ZZ47 row (action items, their mapping rows, their history rows) as one text, to prove that a
-- refused call writes nothing
CREATE PROCEDURE #ZZ47State
@S NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @S = ISNULL((SELECT CAST(a.ActionItemId AS NVARCHAR(12)) + N'|' + ISNULL(CAST(a.IsComplied AS NVARCHAR(12)), N'n') + N'|'
                          + ISNULL(CAST(a.IsConfirmed AS NVARCHAR(12)), N'n') + N'|' + ISNULL(a.ActionText, N'n') + N'|'
                          + ISNULL(CONVERT(NVARCHAR(23), a.UpdatedOn, 121), N'n') + N'|' + ISNULL(CAST(a.UpdatedBy AS NVARCHAR(12)), N'n') + N';'
                     FROM Action_Item a WHERE a.Directions = N'ZZ47' ORDER BY a.ActionItemId
                     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'')
           + N'#'
           + ISNULL((SELECT CAST(m.ActionItemUserMapId AS NVARCHAR(12)) + N'|' + ISNULL(CAST(m.ReadStatus AS NVARCHAR(12)), N'n') + N'|'
                          + ISNULL(CAST(m.StatusId AS NVARCHAR(12)), N'n') + N';'
                     FROM ActionItem_User_Map m INNER JOIN Action_Item a ON a.ActionItemId = m.ActionItemId
                     WHERE a.Directions = N'ZZ47' ORDER BY m.ActionItemUserMapId
                     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'')
           + N'#'
           + ISNULL((SELECT CAST(h.StatusHistoryId AS NVARCHAR(12)) + N'|' + CAST(h.ActionItemId AS NVARCHAR(12)) + N'|' + h.[Action] + N'|'
                          + ISNULL(h.Reason, N'n') + N'|' + CAST(h.ActedBy AS NVARCHAR(12)) + N';'
                     FROM Action_Item_Status_History h INNER JOIN Action_Item a ON a.ActionItemId = h.ActionItemId
                     WHERE a.Directions = N'ZZ47' ORDER BY h.StatusHistoryId
                     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'');
END
GO

-- spr_GetFollowupList for one acting user and one set of filters: the ActionItemIds in the order returned, the row
-- count, and for each row "id|action|reason|login|on" sorted by ActionItemId (on: 'now' when ActedOn is within the last
-- 10 minutes)
CREATE PROCEDURE #ZZ47List
@Acting INT, @Committee INT, @Search INT, @Meeting INT, @From INT, @To INT, @Dept INT, @Confirm INT,
@Ids NVARCHAR(MAX) OUTPUT, @Rows INT OUTPUT, @Status NVARCHAR(MAX) OUTPUT, @R INT OUTPUT, @Rs INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Cols NVARCHAR(MAX);
    DECLARE @Sql NVARCHAR(MAX);

    SELECT TOP 0 v.*, h.[Action] AS StatusAction, h.Reason AS StatusReason, h.ActedOn AS StatusOn,
           u.UserName AS StatusByName, u.LoginName AS StatusByLogin, u.AccountStatus AS StatusByActive
    INTO #L
    FROM View_Action_Item v
    LEFT JOIN Action_Item_Status_History h ON 1 = 0
    LEFT JOIN Users u ON 1 = 0;

    SET @Cols = STUFF((SELECT N',' + QUOTENAME(c.name) FROM tempdb.sys.columns c
                       WHERE c.object_id = OBJECT_ID('tempdb..#L') ORDER BY c.column_id FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N'');
    ALTER TABLE #L ADD ZzSeq INT IDENTITY(1,1);

    SET @Sql = N'INSERT INTO #L (' + @Cols + N') EXEC dbo.spr_GetFollowupList @ActingUserId = @a, @CommitteeId = @c, @MeetingNoSearch = @s,
        @MeetingId = @m, @FromMeetingId = @f, @ToMeetingId = @t, @DepartmentId = @d, @ConfirmStatus = @k, @Result = @r OUTPUT, @Reason = @rs OUTPUT;
        SELECT @n = COUNT(*) FROM #L;
        SELECT @i = ISNULL(STUFF((SELECT N'','' + CAST(ActionItemId AS NVARCHAR(12)) FROM #L ORDER BY ZzSeq FOR XML PATH(''''), TYPE).value(''.'', ''NVARCHAR(MAX)''), 1, 1, N''''), N'''');
        SELECT @st = ISNULL((SELECT CAST(ActionItemId AS NVARCHAR(12)) + N''|'' + ISNULL(StatusAction, N''-'') + N''|'' + ISNULL(StatusReason, N''-'') + N''|''
                                    + ISNULL(StatusByLogin, N''-'') + N''|''
                                    + CASE WHEN StatusOn IS NULL THEN N''-'' WHEN StatusOn >= DATEADD(MINUTE, -10, GETDATE()) THEN N''now'' ELSE N''old'' END + N'';''
                             FROM #L ORDER BY ActionItemId FOR XML PATH(''''), TYPE).value(''.'', ''NVARCHAR(MAX)''), N'''');';
    EXEC sp_executesql @Sql,
         N'@a INT, @c INT, @s INT, @m INT, @f INT, @t INT, @d INT, @k INT, @r INT OUTPUT, @rs INT OUTPUT, @n INT OUTPUT, @i NVARCHAR(MAX) OUTPUT, @st NVARCHAR(MAX) OUTPUT',
         @a = @Acting, @c = @Committee, @s = @Search, @m = @Meeting, @f = @From, @t = @To, @d = @Dept, @k = @Confirm,
         @r = @R OUTPUT, @rs = @Rs OUTPUT, @n = @Rows OUTPUT, @i = @Ids OUTPUT, @st = @Status OUTPUT;

    DROP TABLE #L;
END
GO

-- The query BMMSBAL/ReportsMgr.cs GetFollowupReport builds (the page's list before step 47), built the same way for
-- the same filters. Its ORDER BY (CommitteeId, MeetingId, DepartmentId, IsConfirmed) leaves the order of rows equal in
-- those four to the server; ActionItemId is added for them, as spr_GetFollowupList does.
CREATE PROCEDURE #ZZ47Old
@Committee INT, @Search INT, @Meeting INT, @From INT, @To INT, @Dept INT, @Confirm INT,
@Ids NVARCHAR(MAX) OUTPUT, @Rows INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @O TABLE (Seq BIGINT PRIMARY KEY, ActionItemId INT);

    SET @Sql = N'SELECT ROW_NUMBER() OVER (ORDER BY CommitteeId, MeetingId, DepartmentId, IsConfirmed, ActionItemId) AS Seq, ActionItemId FROM View_Action_Item WHERE 1=1';
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
INSERT INTO #T SELECT 'Marker FollowupFinal-Step47 in the five procedures of the step', '5',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_SaveFollowupActionText'), ('spr_SaveFollowupConfirmed'), ('spr_ReopenFollowup'),
                                          ('spr_GetFollowupList'), ('spr_DeleteUserByUserId')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupFinal-Step47%') AS VARCHAR(12));

INSERT INTO #T SELECT 'Kept markers: FollowupSave-Step46 in the two Followup saves, UserHistory-Step39 in spr_DeleteUserByUserId', '2, 1',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_SaveFollowupActionText'), ('spr_SaveFollowupConfirmed')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%FollowupSave-Step46%') AS VARCHAR(12)) + ', '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')) LIKE '%UserHistory-Step39%' THEN '1' ELSE '0' END;

INSERT INTO #T SELECT 'spr_SaveFollowupActionText: the parameters in their order (unchanged)',
       '@ActingUserId,@ActionItemId,@ActionText,@Result,@Reason',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupActionText') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '');

INSERT INTO #T SELECT 'spr_SaveFollowupConfirmed: the parameters in their order (@Skipped added), @Items of type xml',
       '@ActingUserId,@Items,@Result,@Reason,@Saved,@Skipped | xml',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupConfirmed') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '')
     + ' | ' + ISNULL((SELECT TYPE_NAME(p.user_type_id) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupConfirmed') AND p.name = '@Items'), '-');

INSERT INTO #T SELECT 'spr_ReopenFollowup: the parameters in their order, @ReopenReason nvarchar(500)',
       '@ActingUserId,@ActionItemId,@ReopenReason,@Result,@Reason | nvarchar 1000',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_ReopenFollowup') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '')
     + ' | ' + ISNULL((SELECT TYPE_NAME(p.user_type_id) + ' ' + CAST(p.max_length AS VARCHAR(12)) FROM sys.parameters p
                       WHERE p.object_id = OBJECT_ID('dbo.spr_ReopenFollowup') AND p.name = '@ReopenReason'), '-');

INSERT INTO #T SELECT 'spr_GetFollowupList: the parameters in their order',
       '@ActingUserId,@CommitteeId,@MeetingNoSearch,@MeetingId,@FromMeetingId,@ToMeetingId,@DepartmentId,@ConfirmStatus,@Result,@Reason',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetFollowupList') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '');

INSERT INTO #T SELECT 'OUTPUT parameters: action text 2, confirmed 4, reopen 2, list 2', '2, 4, 2, 2',
       CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupActionText') AND p.is_output = 1) AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SaveFollowupConfirmed') AND p.is_output = 1) AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_ReopenFollowup') AND p.is_output = 1) AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetFollowupList') AND p.is_output = 1) AS VARCHAR(12));

INSERT INTO #T SELECT 'The three saves return no result set (the answer is in the outputs)', '0 0 0',
       CAST((SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_SaveFollowupActionText'), 0) WHERE name IS NOT NULL) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_SaveFollowupConfirmed'), 0) WHERE name IS NOT NULL) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_ReopenFollowup'), 0) WHERE name IS NOT NULL) AS VARCHAR(12));

INSERT INTO #T SELECT 'spr_GetFollowupList: the columns of View_Action_Item, then the six status columns', 'same, StatusAction,StatusReason,StatusOn,StatusByName,StatusByLogin,StatusByActive',
       CASE WHEN (SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetFollowupList'), 0) r
                  INNER JOIN sys.columns c ON c.object_id = OBJECT_ID('dbo.View_Action_Item') AND c.column_id = r.column_ordinal AND c.name = r.name)
                 = (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.View_Action_Item')) THEN 'same' ELSE 'differs' END + ', '
     + ISNULL(STUFF((SELECT ',' + r.name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetFollowupList'), 0) r
                     WHERE r.column_ordinal > (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.View_Action_Item'))
                     ORDER BY r.column_ordinal FOR XML PATH('')), 1, 1, ''), '-');

INSERT INTO #T SELECT 'No feature above compatibility level 100 in the five texts (THROW, IIF, CONCAT, FORMAT, TRY_CONVERT, OFFSET, STRING_AGG, EOMONTH)', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_SaveFollowupActionText'), ('spr_SaveFollowupConfirmed'), ('spr_ReopenFollowup'),
                                          ('spr_GetFollowupList'), ('spr_DeleteUserByUserId')) o(Name)
             CROSS JOIN (VALUES ('%THROW%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('%TRY[_]CONVERT%'), ('% OFFSET %'), ('%STRING[_]AGG%'), ('%EOMONTH%')) f(Pattern)
             WHERE UPPER(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name))) LIKE f.Pattern) AS VARCHAR(12));

INSERT INTO #T SELECT 'Action_Item_Status_History: the columns (name type length nullable) in their order',
       'StatusHistoryId int 4 0,ActionItemId int 4 0,Action varchar 10 0,Reason nvarchar 1000 1,ActedBy int 4 0,ActedOn datetime 8 0',
       STUFF((SELECT ',' + c.name + ' ' + TYPE_NAME(c.user_type_id) + ' ' + CAST(c.max_length AS VARCHAR(12)) + ' ' + CAST(c.is_nullable AS VARCHAR(1))
              FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.Action_Item_Status_History') ORDER BY c.column_id FOR XML PATH('')), 1, 1, '');

INSERT INTO #T SELECT 'Action_Item_Status_History: identity, primary key, default of ActedOn', 'StatusHistoryId, StatusHistoryId, (getdate())',
       ISNULL((SELECT c.name FROM sys.identity_columns c WHERE c.object_id = OBJECT_ID('dbo.Action_Item_Status_History')), '-') + ', '
     + ISNULL((SELECT COL_NAME(ic.object_id, ic.column_id) FROM sys.indexes i INNER JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
               WHERE i.object_id = OBJECT_ID('dbo.Action_Item_Status_History') AND i.is_primary_key = 1), '-') + ', '
     + ISNULL((SELECT dc.definition FROM sys.default_constraints dc WHERE dc.parent_object_id = OBJECT_ID('dbo.Action_Item_Status_History')
               AND dc.parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.Action_Item_Status_History'), 'ActedOn', 'ColumnId')), '-');

INSERT INTO #T SELECT 'Action_Item_Status_History: foreign keys (column, table, on delete, trusted)', 'ActedBy Users NO_ACTION 1, ActionItemId Action_Item CASCADE 1',
       STUFF((SELECT ', ' + COL_NAME(fc.parent_object_id, fc.parent_column_id) + ' ' + OBJECT_NAME(fk.referenced_object_id) + ' '
                   + fk.delete_referential_action_desc + ' ' + CASE WHEN fk.is_not_trusted = 0 AND fk.is_disabled = 0 THEN '1' ELSE '0' END
              FROM sys.foreign_keys fk INNER JOIN sys.foreign_key_columns fc ON fc.constraint_object_id = fk.object_id
              WHERE fk.parent_object_id = OBJECT_ID('dbo.Action_Item_Status_History')
              ORDER BY COL_NAME(fc.parent_object_id, fc.parent_column_id) FOR XML PATH('')), 1, 2, '');

INSERT INTO #T SELECT 'Action_Item_Status_History: two check constraints, trusted; the index on (ActionItemId, StatusHistoryId)', '2, ActionItemId,StatusHistoryId',
       CAST((SELECT COUNT(*) FROM sys.check_constraints cc WHERE cc.parent_object_id = OBJECT_ID('dbo.Action_Item_Status_History')
             AND cc.is_not_trusted = 0 AND cc.is_disabled = 0) AS VARCHAR(12)) + ', '
     + ISNULL(STUFF((SELECT ',' + COL_NAME(ic.object_id, ic.column_id) FROM sys.indexes i
                     INNER JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
                     WHERE i.object_id = OBJECT_ID('dbo.Action_Item_Status_History') AND i.name = 'IX_Action_Item_Status_History_ActionItemId'
                     ORDER BY ic.key_ordinal FOR XML PATH('')), 1, 1, ''), '-');

INSERT INTO #T SELECT 'No procedure, function, view or trigger updates, deletes or truncates Action_Item_Status_History by name', '0',
       CAST((SELECT COUNT(*) FROM sys.sql_modules sm
             CROSS JOIN (VALUES ('%UPDATE Action[_]Item[_]Status[_]History%'), ('%UPDATE dbo.Action[_]Item[_]Status[_]History%'),
                                ('%UPDATE [[]dbo].[[]Action[_]Item[_]Status[_]History]%'),
                                ('%DELETE FROM Action[_]Item[_]Status[_]History%'), ('%DELETE FROM dbo.Action[_]Item[_]Status[_]History%'),
                                ('%DELETE Action[_]Item[_]Status[_]History%'), ('%DELETE dbo.Action[_]Item[_]Status[_]History%'),
                                ('%TRUNCATE TABLE%Action[_]Item[_]Status[_]History%')) f(Pattern)
             WHERE sm.definition LIKE f.Pattern) AS VARCHAR(12));

-- spr_UpdateActionItem is left as step 31 installed it (SHA-1 of the text without carriage returns)
INSERT INTO #T SELECT 'spr_UpdateActionItem is the step 31 text (SHA-1), without a marker of step 46 or 47', 'same, 0',
       CASE WHEN CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateActionItem')), CHAR(13), '') AS NVARCHAR(4000))), 2)
                 = '7EC3DBDD2E40D966EDFA54EEBF52EF18797EF865' THEN 'same' ELSE 'differs' END + ', '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateActionItem')) LIKE '%FollowupSave-Step46%'
              OR OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateActionItem')) LIKE '%FollowupFinal-Step47%' THEN '1' ELSE '0' END;

INSERT INTO #T SELECT 'The objects of steps 43 and 45 that read IsConfirmed are not changed (markers 43 and 45, no FollowupFinal-Step47 marker elsewhere)', '1, 1, 5, 0',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_DashboardActionItems')) LIKE '%DashboardAlerts-Step43%' THEN '1' ELSE '0' END + ', '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveDashboardActionText')) LIKE '%DashboardAlerts-Step43%' THEN '1' ELSE '0' END + ', '
     + CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardCommitteeFilter'), ('spr_GetDashboardSummary'), ('spr_GetDashboardMeetings'),
                                          ('spr_GetDashboardApprovals'), ('spr_GetDashboardActionItems')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardSummary-Step45%') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM sys.sql_modules sm
             WHERE sm.definition LIKE '%FollowupFinal-Step47%'
               AND sm.object_id NOT IN (OBJECT_ID('dbo.spr_SaveFollowupActionText'), OBJECT_ID('dbo.spr_SaveFollowupConfirmed'),
                                        OBJECT_ID('dbo.spr_ReopenFollowup'), OBJECT_ID('dbo.spr_GetFollowupList'),
                                        OBJECT_ID('dbo.spr_DeleteUserByUserId'))) AS VARCHAR(12));
GO

-- Every database user who can run step 42's spr_GetDashboardDepartments (the application login among them) can run the
-- four Followup procedures. Asked of the server as that user (EXECUTE AS USER), so a schema grant counts.
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
                      + HAS_PERMS_BY_NAME('dbo.spr_SaveFollowupConfirmed', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_ReopenFollowup', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetFollowupList', 'OBJECT', 'EXECUTE') ELSE -1 END;
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
INSERT INTO #T SELECT 'EXECUTE: database users who can run step 42''s department procedure but not all four Followup procedures (' + CAST(@Users AS VARCHAR(12)) + ' such users asked)',
       '0', CAST(@Cannot AS VARCHAR(12)) + CASE WHEN @Cannot > 0 THEN ':' + @Names ELSE '' END;
GO

-------------------------------------------------------------------------------
-- Part 2
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(1000), Actual VARCHAR(1000));
DECLARE @Item TABLE (K INT PRIMARY KEY, ActionItemId INT, MinutesId INT, AgendaId INT);
DECLARE @Case TABLE (Seq INT IDENTITY(1,1) PRIMARY KEY, Label VARCHAR(100), UserId INT NULL, Expected INT);
DECLARE @Res TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @Combo TABLE (Seq INT IDENTITY(1,1) PRIMARY KEY, Committee INT, Search INT, Meeting INT, FromM INT, ToM INT, Dept INT, Confirm INT);

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
DECLARE @Other INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);

DECLARE @DA INT, @DB INT, @CZ INT, @M1 INT, @M2 INT, @M3 INT;
DECLARE @Ctl INT, @Ct2 INT, @Mgr INT, @Usr INT, @Gmt INT, @Mds INT, @Adm INT, @Off INT, @Fresh INT;
DECLARE @R INT, @Rs INT, @Sv INT, @Sk INT, @R2 INT, @Rs2 INT, @R3 INT, @Rs3 INT, @R4 INT, @Rs4 INT, @N INT, @N2 INT;
DECLARE @X XML;
DECLARE @Str NVARCHAR(MAX), @Ids NVARCHAR(MAX), @Ids2 NVARCHAR(MAX), @St NVARCHAR(MAX), @Exp NVARCHAR(MAX);
DECLARE @Before NVARCHAR(MAX), @After NVARCHAR(MAX);
DECLARE @Txt VARCHAR(1000);
DECLARE @Uni NVARCHAR(200) = N'ZZ47 action text ' + NCHAR(2949) + NCHAR(2965) + NCHAR(3014) + N' <p>end</p>';
DECLARE @ReasonText NVARCHAR(500) = N'ZZ47 reopen ' + NCHAR(2949) + N' & "quoted" <b>';
DECLARE @Seq INT, @Label VARCHAR(100), @CaseUser INT, @Expected INT;
DECLARE @Unknown INT;
DECLARE @I1 INT, @I2 INT, @I3 INT, @I4 INT, @I5 INT, @I6 INT, @I7 INT, @I8 INT, @I9 INT, @I10 INT;
DECLARE @I17 INT, @I18 INT, @I19 INT, @I20 INT;
DECLARE @Cm INT, @Sr INT, @Mt INT, @Fm INT, @Tm INT, @Dp INT, @Cf INT, @Differ INT, @Combos INT, @Compared INT, @First VARCHAR(400), @Between NVARCHAR(MAX);
DECLARE @AgendaBefore VARCHAR(40), @MinBefore VARCHAR(40), @ActBefore VARCHAR(40), @MapBefore VARCHAR(40), @HisBefore VARCHAR(40);
DECLARE @AgendaAfter VARCHAR(40), @MinAfter VARCHAR(40), @ActAfter VARCHAR(40), @MapAfter VARCHAR(40), @HisAfter VARCHAR(40);

SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MeetingId, DepartmentId, UpdatedOn)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MinBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, AgendaId, DecisionTypeId, DueDate, StatusId, ActualResolution)), 0) AS VARCHAR(12)) FROM Minutes;
SELECT @ActBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, ActionText, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;
SELECT @HisBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(StatusHistoryId, ActionItemId, [Action], Reason, ActedBy, ActedOn)), 0) AS VARCHAR(12)) FROM Action_Item_Status_History;

SET @Unknown = (SELECT ISNULL(MAX(ActionItemId), 0) + 100000 FROM Action_Item);

BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ47A', 'ZZ47 department A', 995, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ47B', 'ZZ47 department B', 994, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 controller', @DA, @Desig, NULL, @rCtl, 'zz47c@example.invalid', 'zz47ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 controller two', @DA, @Desig, NULL, @rCtl, 'zz47d@example.invalid', 'zz47ct2', 'not-a-login', 1, @Now);
    SET @Ct2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 manager', @DA, @Desig, NULL, @rMgr, 'zz47m@example.invalid', 'zz47mgr', 'not-a-login', 1, @Now);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 user', @DA, @Desig, @Mgr, @rUser, 'zz47u@example.invalid', 'zz47usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 management', @DA, @Desig, NULL, @rMgmt, 'zz47g@example.invalid', 'zz47gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 md secretariat', @DA, @Desig, NULL, @rMd, 'zz47s@example.invalid', 'zz47mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 admin', @DA, @Desig, NULL, @rAdmin, 'zz47a@example.invalid', 'zz47adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 inactive controller', @DA, @Desig, NULL, @rCtl, 'zz47i@example.invalid', 'zz47off', 'not-a-login', 0, @Now);
    SET @Off = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ47 fresh user', @DA, @Desig, NULL, @rUser, 'zz47f@example.invalid', 'zz47new', 'not-a-login', 1, @Now);
    SET @Fresh = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z47', 'ZZ47 committee', '2000-01-01', 1, 0);
    SET @CZ = SCOPE_IDENTITY();

    -- M1: minutes finalised; M2 and M3: agenda and minutes open. All three created long ago, so the workflow order of
    -- step 23 does not apply
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94701', @CZ, 'ZZ47 test', 'ZZ', DATEADD(DAY, -5, @Day), '10:00', DATEADD(DAY, -7, @Day), 'Close', 'F', '2000-01-01', @Sys);
    SET @M1 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94702', @CZ, 'ZZ47 test', 'ZZ', DATEADD(DAY, -4, @Day), '10:00', DATEADD(DAY, -6, @Day), 'Open', NULL, '2000-01-01', @Sys);
    SET @M2 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94703', @CZ, 'ZZ47 test', 'ZZ', DATEADD(DAY, -3, @Day), '10:00', DATEADD(DAY, -5, @Day), 'Open', NULL, '2000-01-01', @Sys);
    SET @M3 = SCOPE_IDENTITY();

    -- 22 approved items, one minute (Followup) and one action item each: K 1 to 18 on M1 in department A, K 19 on M2,
    -- K 20 on M3, K 21 and 22 on M1 in department B
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT 'ZZ47-' + RIGHT('0' + CAST(n.K AS VARCHAR(2)), 2), @CZ,
           CASE WHEN n.K = 19 THEN @M2 WHEN n.K = 20 THEN @M3 ELSE @M1 END,
           CASE WHEN n.K IN (21, 22) THEN @DB ELSE @DA END,
           @SubjectTypeId, 'ZZ47 item ' + CAST(n.K AS VARCHAR(2)), 'Entry', 'ACA', 'New', @Now, @Ctl
    FROM (SELECT TOP 22 ROW_NUMBER() OVER (ORDER BY object_id) AS K FROM sys.objects) n;

    INSERT INTO Minutes (AgendaId, DecisionTypeId, DueDate, StatusId, CreatedOn, CreatedBy, ActualResolution)
    SELECT a.AgendaId, 1, NULL, 0, @Now, @Sys, N'ZZ47 resolution ' + a.AgendaNo
    FROM Agenda a WHERE a.AgendaNo LIKE 'ZZ47-%';

    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)
    SELECT mi.MinutesId, N'ZZ47', N'ZZ47 text ' + a.AgendaNo, '', 1, 0, DATEADD(DAY, -1, @Now), @Sys
    FROM Minutes mi INNER JOIN Agenda a ON a.AgendaId = mi.AgendaId
    WHERE a.AgendaNo LIKE 'ZZ47-%';

    INSERT INTO @Item (K, ActionItemId, MinutesId, AgendaId)
    SELECT CAST(RIGHT(a.AgendaNo, 2) AS INT), ai.ActionItemId, ai.MinutesId, a.AgendaId
    FROM Action_Item ai INNER JOIN Minutes mi ON mi.MinutesId = ai.MinutesId INNER JOIN Agenda a ON a.AgendaId = mi.AgendaId
    WHERE a.AgendaNo LIKE 'ZZ47-%';

    -- Two mapping rows per item (the Controller and the User), read, StatusId 1
    INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId)
    SELECT i.ActionItemId, u.UserId, 1, 1
    FROM @Item i CROSS JOIN (SELECT @Ctl AS UserId UNION ALL SELECT @Usr) u;

    SELECT @I1 = ActionItemId FROM @Item WHERE K = 1;   SELECT @I2 = ActionItemId FROM @Item WHERE K = 2;
    SELECT @I3 = ActionItemId FROM @Item WHERE K = 3;   SELECT @I4 = ActionItemId FROM @Item WHERE K = 4;
    SELECT @I5 = ActionItemId FROM @Item WHERE K = 5;   SELECT @I6 = ActionItemId FROM @Item WHERE K = 6;
    SELECT @I7 = ActionItemId FROM @Item WHERE K = 7;   SELECT @I8 = ActionItemId FROM @Item WHERE K = 8;
    SELECT @I9 = ActionItemId FROM @Item WHERE K = 9;   SELECT @I10 = ActionItemId FROM @Item WHERE K = 10;
    SELECT @I17 = ActionItemId FROM @Item WHERE K = 17; SELECT @I18 = ActionItemId FROM @Item WHERE K = 18;
    SELECT @I19 = ActionItemId FROM @Item WHERE K = 19; SELECT @I20 = ActionItemId FROM @Item WHERE K = 20;

    -- K 7: confirmed before step 47 (no history row); K 2: a due date three days ago (the Overdue rule)
    UPDATE Action_Item SET IsConfirmed = 1 WHERE ActionItemId = @I7;
    UPDATE mi SET DueDate = DATEADD(DAY, -3, @Day) FROM Minutes mi INNER JOIN @Item i ON i.MinutesId = mi.MinutesId WHERE i.K = 2;

    INSERT INTO @T SELECT 'Made-up data: departments, users, committee, meetings, items, action items, mapping rows', '2, 9, 1, 3, 22, 22, 44',
           CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ47%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz47%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z47') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ47 test') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'ZZ47-%') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ47') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m INNER JOIN @Item i ON i.ActionItemId = m.ActionItemId) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Submit: only the rows sent are written
    ---------------------------------------------------------------------------
    EXEC #ZZ47State @S = @Before OUTPUT;
    SET @Str = N'<items><i id="' + CAST(@I1 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I2 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I3 AS NVARCHAR(12)) + N'"/></items>';
    SET @X = CAST(@Str AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
    INSERT INTO @T SELECT 'Submit by the Controller of three pending rows: Result, Reason, Saved, Skipped', '1 0 3 0',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + ' ' + CAST(@Sk AS VARCHAR(12));
    INSERT INTO @T SELECT 'Submit: K 1 to 3 IsComplied 0, IsConfirmed 1 (what a tick wrote before)', '0 1, 0 1, 0 1',
           STUFF((SELECT ', ' + CAST(a.IsComplied AS VARCHAR(2)) + ' ' + CAST(a.IsConfirmed AS VARCHAR(2))
                  FROM @Item i INNER JOIN Action_Item a ON a.ActionItemId = i.ActionItemId WHERE i.K IN (1, 2, 3) ORDER BY i.K FOR XML PATH('')), 1, 2, '');
    INSERT INTO @T SELECT 'Submit: every mapping row of K 1 to 3 StatusId 0 (6 rows)', '6',
           CAST((SELECT COUNT(*) FROM ActionItem_User_Map m INNER JOIN @Item i ON i.ActionItemId = m.ActionItemId WHERE i.K IN (1, 2, 3) AND m.StatusId = 0) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Submit: one Confirm history row each for K 1 to 3, reason NULL, by the Controller, now', 'Confirm n Y now, Confirm n Y now, Confirm n Y now',
           STUFF((SELECT ', ' + h.[Action] + ' ' + CASE WHEN h.Reason IS NULL THEN 'n' ELSE 'text' END + ' '
                       + CASE WHEN h.ActedBy = @Ctl THEN 'Y' ELSE 'N' END + ' '
                       + CASE WHEN h.ActedOn >= DATEADD(MINUTE, -10, GETDATE()) THEN 'now' ELSE 'old' END
                  FROM @Item i INNER JOIN Action_Item_Status_History h ON h.ActionItemId = i.ActionItemId WHERE i.K IN (1, 2, 3) ORDER BY i.K, h.StatusHistoryId FOR XML PATH('')), 1, 2, '');
    INSERT INTO @T SELECT 'Submit: the rows not sent (K 4 to 22) are not written (IsComplied 1 kept, IsConfirmed as before, no history, mapping rows StatusId 1)', '19, 0, 38',
           CAST((SELECT COUNT(*) FROM @Item i INNER JOIN Action_Item a ON a.ActionItemId = i.ActionItemId
                 WHERE i.K >= 4 AND a.IsComplied = 1 AND a.IsConfirmed = CASE WHEN i.K = 7 THEN 1 ELSE 0 END) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Action_Item_Status_History h INNER JOIN @Item i ON i.ActionItemId = h.ActionItemId WHERE i.K >= 4) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m INNER JOIN @Item i ON i.ActionItemId = m.ActionItemId WHERE i.K >= 4 AND m.StatusId = 1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Submit: the action text and UpdatedOn / UpdatedBy of K 1 to 3 untouched (rows changed)', '0',
           CAST((SELECT COUNT(*) FROM @Item i INNER JOIN Action_Item a ON a.ActionItemId = i.ActionItemId INNER JOIN Agenda ag ON ag.AgendaId = i.AgendaId
                 WHERE i.K IN (1, 2, 3) AND (a.ActionText <> N'ZZ47 text ' + ag.AgendaNo OR a.UpdatedBy <> @Sys OR a.UpdatedOn >= DATEADD(HOUR, -1, @Now))) AS VARCHAR(12));

    -- A row confirmed in between (here K 1, by the first Controller) is skipped; the other row is written
    SET @Str = N'<items><i id="' + CAST(@I1 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I4 AS NVARCHAR(12)) + N'"/></items>';
    SET @X = CAST(@Str AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ct2, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
    INSERT INTO @T SELECT 'Submit by a second Controller of K 1 (already confirmed) and K 4: Result, Reason, Saved, Skipped', '1 0 1 1',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + ' ' + CAST(@Sk AS VARCHAR(12));
    INSERT INTO @T SELECT 'Skipped row K 1: still one history row, by the first Controller; K 4 confirmed with a row by the second', '1 Y, 1 1 Y',
           CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I1) AS VARCHAR(12)) + ' '
         + CASE WHEN (SELECT MAX(ActedBy) FROM Action_Item_Status_History WHERE ActionItemId = @I1) = @Ctl THEN 'Y' ELSE 'N' END + ', '
         + CAST((SELECT IsConfirmed FROM Action_Item WHERE ActionItemId = @I4) AS VARCHAR(2)) + ' '
         + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I4) AS VARCHAR(12)) + ' '
         + CASE WHEN (SELECT MAX(ActedBy) FROM Action_Item_Status_History WHERE ActionItemId = @I4) = @Ct2 THEN 'Y' ELSE 'N' END;

    -- Every row sent already confirmed (the same Controller in another tab): nothing written, counted as skipped
    EXEC #ZZ47State @S = @Before OUTPUT;
    SET @Str = N'<items><i id="' + CAST(@I1 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I2 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I7 AS NVARCHAR(12)) + N'"/></items>';
    SET @X = CAST(@Str AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
    EXEC #ZZ47State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Submit of three rows already confirmed (one before step 47): Result Reason Saved Skipped; nothing written', '1 0 0 3; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + ' ' + CAST(@Sk AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;

    -- An empty list: nothing to write
    EXEC #ZZ47State @S = @Before OUTPUT;
    SET @X = CAST(N'<items/>' AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
    EXEC #ZZ47State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Submit of an empty list: Result Reason Saved Skipped; nothing written', '1 0 0 0; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + ' ' + CAST(@Sk AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;

    ---------------------------------------------------------------------------
    -- Submit by the Controller refused as a whole: the step 46 shape and every bad list; every row as it was
    ---------------------------------------------------------------------------
    DECLARE @Bad TABLE (Seq INT IDENTITY(1,1) PRIMARY KEY, Label VARCHAR(150), Body NVARCHAR(MAX) NULL);
    DECLARE @Good NVARCHAR(MAX) = N'<i id="' + CAST(@I5 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I6 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I8 AS NVARCHAR(12)) + N'"/>';
    INSERT INTO @Bad (Label, Body) VALUES
    ('the step 46 shape (c="1" on every row; the build of UN6d)', N'<items><i id="' + CAST(@I5 AS NVARCHAR(12)) + N'" c="1"/><i id="' + CAST(@I6 AS NVARCHAR(12)) + N'" c="1"/></items>'),
    ('the step 46 shape (c="0" in the last row)', N'<items>' + @Good + N'<i id="' + CAST(@I9 AS NVARCHAR(12)) + N'" c="0"/></items>'),
    ('another attribute in the last row', N'<items>' + @Good + N'<i id="' + CAST(@I9 AS NVARCHAR(12)) + N'" x="1"/></items>'),
    ('no id in the last row', N'<items>' + @Good + N'<i/></items>'),
    ('an attribute on the root', N'<items a="1">' + @Good + N'</items>'),
    ('an unknown item LAST of four', N'<items>' + @Good + N'<i id="' + CAST(@Unknown AS NVARCHAR(12)) + N'"/></items>'),
    ('an unknown item FIRST of four', N'<items><i id="' + CAST(@Unknown AS NVARCHAR(12)) + N'"/>' + @Good + N'</items>'),
    ('an id given twice (the last row repeats the first)', N'<items>' + @Good + N'<i id="' + CAST(@I5 AS NVARCHAR(12)) + N'"/></items>'),
    ('an id that is not a whole number in the last row', N'<items>' + @Good + N'<i id="1x"/></items>'),
    ('an id with a space in the last row', N'<items>' + @Good + N'<i id=" ' + CAST(@I9 AS NVARCHAR(12)) + N'"/></items>'),
    ('a negative id in the last row', N'<items>' + @Good + N'<i id="-5"/></items>'),
    ('an id larger than an INT in the last row', N'<items>' + @Good + N'<i id="9999999999"/></items>'),
    ('an id of 11 digits in the last row', N'<items>' + @Good + N'<i id="00000000001"/></items>'),
    ('an element other than <i> at the end', N'<items>' + @Good + N'<x id="' + CAST(@I9 AS NVARCHAR(12)) + N'"/></items>'),
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
        EXEC #ZZ47State @S = @Before OUTPUT;
        EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
        EXEC #ZZ47State @S = @After OUTPUT;
        INSERT INTO @T SELECT 'Submit by the Controller refused, ' + @Label + ': Result Reason Saved Skipped; every row as it was', '0 4 0 0; unchanged',
               CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + ' ' + CAST(@Sk AS VARCHAR(12)) + '; '
             + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;
        FETCH NEXT FROM BadCursor INTO @Label, @Body;
    END
    CLOSE BadCursor;
    DEALLOCATE BadCursor;

    -- The good rows of those lists alone are saved (so the refusals above were for the bad row only)
    SET @Str = N'<items>' + @Good + N'</items>';
    SET @X = CAST(@Str AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
    INSERT INTO @T SELECT 'The three good rows of those lists alone: saved (Result Reason Saved Skipped; IsConfirmed of K 5, 6, 8)', '1 0 3 0; 1, 1, 1',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + ' ' + CAST(@Sk AS VARCHAR(12)) + '; '
         + STUFF((SELECT ', ' + CAST(a.IsConfirmed AS VARCHAR(2))
                  FROM Action_Item a INNER JOIN @Item i ON i.ActionItemId = a.ActionItemId WHERE i.K IN (5, 6, 8) ORDER BY i.K FOR XML PATH('')), 1, 2, '');

    INSERT INTO @T SELECT 'After the Submits the test''s own transaction is still open (@@TRANCOUNT)', '1', CAST(@@TRANCOUNT AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Save of the Action Text
    ---------------------------------------------------------------------------
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = @I9, @ActionText = @Uni, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    INSERT INTO @T SELECT 'Action Text by the Controller on a pending item: Result Reason; the text letter for letter (Unicode), nothing else changed', '1 0; same, 1 0, no history',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(a.ActionText AS VARBINARY(MAX)) = CAST(@Uni AS VARBINARY(MAX)) THEN 'same' ELSE 'differs' END + ', '
         + CAST(a.IsComplied AS VARCHAR(2)) + ' ' + CAST(a.IsConfirmed AS VARCHAR(2)) + ', '
         + CASE WHEN EXISTS (SELECT 1 FROM Action_Item_Status_History WHERE ActionItemId = @I9) THEN 'history' ELSE 'no history' END
    FROM Action_Item a WHERE a.ActionItemId = @I9;

    EXEC #ZZ47State @S = @Before OUTPUT;
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = @I1, @ActionText = N'ZZ47 must not be written', @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = @I7, @ActionText = N'ZZ47 must not be written', @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
    EXEC #ZZ47State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Action Text by the Controller on a confirmed item (with history; and before history): Result Reason each; nothing written', '0 26, 0 26; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ', ' + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;

    EXEC #ZZ47State @S = @Before OUTPUT;
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = @Unknown, @ActionText = N'ZZ47 must not be written', @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = NULL, @ActionText = N'ZZ47 must not be written', @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
    EXEC #ZZ47State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Action Text by the Controller for an unknown and a NULL item: Result Reason each; nothing written', '0 4, 0 4; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ', ' + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;

    ---------------------------------------------------------------------------
    -- Reopen
    ---------------------------------------------------------------------------
    SET @Str = N'  ' + @ReasonText + N'  ';
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I2, @ReopenReason = @Str, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    INSERT INTO @T SELECT 'Reopen by the Controller of a confirmed item (K 2): Result Reason; IsConfirmed; IsComplied kept', '1 0; 0; 0',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + '; '
         + CAST((SELECT IsConfirmed FROM Action_Item WHERE ActionItemId = @I2) AS VARCHAR(2)) + '; '
         + CAST((SELECT IsComplied FROM Action_Item WHERE ActionItemId = @I2) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Reopen: the latest history row of K 2 is Reopen, by the Controller, now, the reason trimmed and letter for letter', 'Reopen Y now same, 2 rows',
           h.[Action] + ' ' + CASE WHEN h.ActedBy = @Ctl THEN 'Y' ELSE 'N' END + ' '
         + CASE WHEN h.ActedOn >= DATEADD(MINUTE, -10, GETDATE()) THEN 'now' ELSE 'old' END + ' '
         + CASE WHEN CAST(h.Reason AS VARBINARY(MAX)) = CAST(@ReasonText AS VARBINARY(MAX)) THEN 'same' ELSE 'differs' END + ', '
         + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I2) AS VARCHAR(12)) + ' rows'
    FROM Action_Item_Status_History h
    WHERE h.StatusHistoryId = (SELECT MAX(StatusHistoryId) FROM Action_Item_Status_History WHERE ActionItemId = @I2);
    INSERT INTO @T SELECT 'Reopen: the mapping rows of K 2 left as the confirm set them (StatusId 0, ReadStatus 1)', '0 1, 0 1',
           STUFF((SELECT ', ' + CAST(m.StatusId AS VARCHAR(2)) + ' ' + CAST(m.ReadStatus AS VARCHAR(2))
                  FROM ActionItem_User_Map m WHERE m.ActionItemId = @I2 ORDER BY m.ActionItemUserMapId FOR XML PATH('')), 1, 2, '');

    EXEC #ZZ47State @S = @Before OUTPUT;
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ct2, @ActionItemId = @I2, @ReopenReason = N'ZZ47 second reopen', @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I10, @ReopenReason = N'ZZ47 never confirmed', @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
    EXEC #ZZ47State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Reopen of an item already reopened (by another Controller) and of a never confirmed item: Result Reason each; nothing written', '0 27, 0 27; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ', ' + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;

    EXEC #ZZ47State @S = @Before OUTPUT;
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I3, @ReopenReason = NULL, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I3, @ReopenReason = N'', @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I3, @ReopenReason = N'    ', @Result = @R3 OUTPUT, @Reason = @Rs3 OUTPUT;
    SET @Str = NCHAR(9) + NCHAR(13) + NCHAR(10) + N' ' + NCHAR(160) + NCHAR(8203) + NCHAR(9);
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I3, @ReopenReason = @Str, @Result = @R4 OUTPUT, @Reason = @Rs4 OUTPUT;
    EXEC #ZZ47State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Reopen of a confirmed item with a NULL, empty, spaces-only and tabs, line breaks, no-break and zero-width spaces reason: Result Reason each; nothing written', '0 4, 0 4, 0 4, 0 4; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ', ' + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + ', '
         + CAST(@R3 AS VARCHAR(12)) + ' ' + CAST(@Rs3 AS VARCHAR(12)) + ', ' + CAST(@R4 AS VARCHAR(12)) + ' ' + CAST(@Rs4 AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;

    EXEC #ZZ47State @S = @Before OUTPUT;
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @Unknown, @ReopenReason = N'ZZ47 unknown', @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = NULL, @ReopenReason = N'ZZ47 null', @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
    EXEC #ZZ47State @S = @After OUTPUT;
    INSERT INTO @T SELECT 'Reopen by the Controller for an unknown and a NULL item: Result Reason each; nothing written', '0 4, 0 4; unchanged',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ', ' + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END;

    -- 500 characters are stored whole; 501 are cut to 500 by the parameter type (the page refuses them before the call)
    SET @Str = REPLICATE(N'r', 499) + NCHAR(2949);
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I3, @ReopenReason = @Str, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    SET @Str = REPLICATE(N's', 501);
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I5, @ReopenReason = @Str, @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
    INSERT INTO @T SELECT 'Reopen with a reason of 500 characters (stored whole) and of 501 (cut to 500 by the parameter type): Result Reason length each', '1 0 500 same, 1 0 500',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' '
         + CAST((SELECT LEN(Reason) FROM Action_Item_Status_History WHERE StatusHistoryId = (SELECT MAX(StatusHistoryId) FROM Action_Item_Status_History WHERE ActionItemId = @I3)) AS VARCHAR(12)) + ' '
         + CASE WHEN (SELECT CAST(Reason AS VARBINARY(MAX)) FROM Action_Item_Status_History WHERE StatusHistoryId = (SELECT MAX(StatusHistoryId) FROM Action_Item_Status_History WHERE ActionItemId = @I3))
                     = CAST(REPLICATE(N'r', 499) + NCHAR(2949) AS VARBINARY(MAX)) THEN 'same' ELSE 'differs' END + ', '
         + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + ' '
         + CAST((SELECT LEN(Reason) FROM Action_Item_Status_History WHERE StatusHistoryId = (SELECT MAX(StatusHistoryId) FROM Action_Item_Status_History WHERE ActionItemId = @I5)) AS VARCHAR(12));

    -- Reopened: the item is editable again and can be confirmed again (a third history row)
    EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @Ctl, @ActionItemId = @I3, @ActionText = N'ZZ47 text after reopen', @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    SET @Str = N'<items><i id="' + CAST(@I3 AS NVARCHAR(12)) + N'"/></items>';
    SET @X = CAST(@Str AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ct2, @Items = @X, @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
    INSERT INTO @T SELECT 'Reopened K 3: Action Text saved (Result Reason), confirmed again (Result Reason Saved Skipped), its history Confirm, Reopen, Confirm', '1 0; 1 0 1 0; Confirm,Reopen,Confirm',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + '; '
         + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + ' ' + CAST(@Sv AS VARCHAR(12)) + ' ' + CAST(@Sk AS VARCHAR(12)) + '; '
         + STUFF((SELECT ',' + h.[Action] FROM Action_Item_Status_History h WHERE h.ActionItemId = @I3 ORDER BY h.StatusHistoryId FOR XML PATH('')), 1, 1, '');

    -- An item confirmed before step 47 can be reopened (its first history row is the Reopen)
    EXEC dbo.spr_ReopenFollowup @ActingUserId = @Ctl, @ActionItemId = @I7, @ReopenReason = N'ZZ47 before history', @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    INSERT INTO @T SELECT 'Reopen of K 7, confirmed before step 47 (no history row): Result Reason; IsConfirmed; its history', '1 0; 0; Reopen',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + '; '
         + CAST((SELECT IsConfirmed FROM Action_Item WHERE ActionItemId = @I7) AS VARCHAR(2)) + '; '
         + ISNULL(STUFF((SELECT ',' + h.[Action] FROM Action_Item_Status_History h WHERE h.ActionItemId = @I7 ORDER BY h.StatusHistoryId FOR XML PATH('')), 1, 1, ''), '-');
    -- and back to confirmed before step 47, without history, for the list check below
    DELETE FROM Action_Item_Status_History WHERE ActionItemId = @I7;
    UPDATE Action_Item SET IsConfirmed = 1 WHERE ActionItemId = @I7;

    ---------------------------------------------------------------------------
    -- Every role refused for the three saves; the list for every role but the Controller and the MD Secretariat
    ---------------------------------------------------------------------------
    INSERT INTO @Case (Label, UserId, Expected) VALUES
    ('a Manager', @Mgr, 4), ('a User', @Usr, 4), ('Management', @Gmt, 4), ('MD Secretariat', @Mds, 4), ('an Admin', @Adm, 4),
    ('the system account', @Sys, 12), ('an inactive Controller', @Off, 8), ('a user id that does not exist', @Missing, 8),
    ('acting user 0', 0, 8), ('acting user NULL', NULL, 8);

    SET @Str = N'<items><i id="' + CAST(@I9 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I10 AS NVARCHAR(12)) + N'"/></items>';
    SET @X = CAST(@Str AS XML);

    DECLARE CaseCursor CURSOR LOCAL FAST_FORWARD FOR SELECT Seq, Label, UserId, Expected FROM @Case ORDER BY Seq;
    OPEN CaseCursor;
    FETCH NEXT FROM CaseCursor INTO @Seq, @Label, @CaseUser, @Expected;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        EXEC #ZZ47State @S = @Before OUTPUT;
        EXEC dbo.spr_SaveFollowupActionText @ActingUserId = @CaseUser, @ActionItemId = @I9, @ActionText = N'ZZ47 must not be written', @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
        EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @CaseUser, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
        EXEC dbo.spr_ReopenFollowup @ActingUserId = @CaseUser, @ActionItemId = @I1, @ReopenReason = N'ZZ47 must not be written', @Result = @R3 OUTPUT, @Reason = @Rs3 OUTPUT;
        EXEC #ZZ47State @S = @After OUTPUT;
        EXEC #ZZ47List @Acting = @CaseUser, @Committee = @CZ, @Search = 0, @Meeting = 0, @From = 0, @To = 0, @Dept = 0, @Confirm = -1,
             @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @Status = @St OUTPUT, @R = @R4 OUTPUT, @Rs = @Rs4 OUTPUT;
        INSERT INTO @T SELECT 'Refused: ' + @Label + ' (Action Text; Submit Saved Skipped; Reopen; ZZ47 rows; list Result Reason rows)',
               '0 ' + CAST(@Expected AS VARCHAR(2)) + '; 0 ' + CAST(@Expected AS VARCHAR(2)) + ' 0 0; 0 ' + CAST(@Expected AS VARCHAR(2)) + '; unchanged; '
             + CASE WHEN @Label = 'MD Secretariat' THEN '1 0 22' ELSE '0 ' + CAST(@Expected AS VARCHAR(2)) + ' 0' END,
               CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@Rs2 AS VARCHAR(12)) + '; ' + CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' '
             + CAST(@Sv AS VARCHAR(12)) + ' ' + CAST(@Sk AS VARCHAR(12)) + '; ' + CAST(@R3 AS VARCHAR(12)) + ' ' + CAST(@Rs3 AS VARCHAR(12)) + '; '
             + CASE WHEN CAST(@Before AS VARBINARY(MAX)) = CAST(@After AS VARBINARY(MAX)) THEN 'unchanged' ELSE 'CHANGED' END + '; '
             + CAST(@R4 AS VARCHAR(12)) + ' ' + CAST(@Rs4 AS VARCHAR(12)) + ' ' + CAST(@N AS VARCHAR(12));
        FETCH NEXT FROM CaseCursor INTO @Seq, @Label, @CaseUser, @Expected;
    END
    CLOSE CaseCursor;
    DEALLOCATE CaseCursor;

    ---------------------------------------------------------------------------
    -- The list: the latest history row of each item and who acted
    ---------------------------------------------------------------------------
    EXEC #ZZ47List @Acting = @Ctl, @Committee = @CZ, @Search = 0, @Meeting = @M1, @From = 0, @To = 0, @Dept = @DA, @Confirm = -1,
         @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @Status = @St OUTPUT, @R = @R OUTPUT, @Rs = @Rs OUTPUT;
    SET @Exp = ISNULL((SELECT CAST(i.ActionItemId AS NVARCHAR(12)) + N'|'
                             + CASE i.K WHEN 1 THEN N'Confirm|-|zz47ctl|now' WHEN 2 THEN N'Reopen|' + @ReasonText + N'|zz47ctl|now'
                                        WHEN 3 THEN N'Confirm|-|zz47ct2|now' WHEN 4 THEN N'Confirm|-|zz47ct2|now'
                                        WHEN 5 THEN N'Reopen|' + REPLICATE(N's', 500) + N'|zz47ctl|now'
                                        WHEN 6 THEN N'Confirm|-|zz47ctl|now' WHEN 8 THEN N'Confirm|-|zz47ctl|now'
                                        ELSE N'-|-|-|-' END + N';'
                      FROM @Item i WHERE i.K <= 18 ORDER BY i.ActionItemId FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), N'');
    INSERT INTO @T SELECT 'List by the Controller, meeting M1, department A: Result Reason rows; each item''s latest action, reason, who (login), when (K 7 confirmed before history: none)',
           '1 0 18; same', CAST(@R AS VARCHAR(12)) + ' ' + CAST(@Rs AS VARCHAR(12)) + ' ' + CAST(@N AS VARCHAR(12)) + '; '
         + CASE WHEN CAST(@St AS VARBINARY(MAX)) = CAST(@Exp AS VARBINARY(MAX)) THEN 'same' ELSE 'differs: ' + LEFT(CAST(@St AS VARCHAR(MAX)), 300) END;

    EXEC #ZZ47List @Acting = @Ctl, @Committee = @CZ, @Search = 0, @Meeting = @M1, @From = 0, @To = 0, @Dept = @DA, @Confirm = 1,
         @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @Status = @St OUTPUT, @R = @R OUTPUT, @Rs = @Rs OUTPUT;
    EXEC #ZZ47List @Acting = @Mds, @Committee = @CZ, @Search = 0, @Meeting = @M1, @From = 0, @To = 0, @Dept = @DA, @Confirm = 0,
         @Ids = @Ids2 OUTPUT, @Rows = @N2 OUTPUT, @Status = @St OUTPUT, @R = @R2 OUTPUT, @Rs = @Rs2 OUTPUT;
    INSERT INTO @T SELECT 'List, Confirmed (Controller) and Pending (MD Secretariat), meeting M1, department A: rows each (K 1, 3, 4, 6, 7, 8 confirmed)', '6, 12',
           CAST(@N AS VARCHAR(12)) + ', ' + CAST(@N2 AS VARCHAR(12));
    INSERT INTO @T SELECT 'List, Pending: the reopened K 2 and K 5 are in it, the confirmed K 1 is not', '1 1 0',
           CASE WHEN N',' + @Ids2 + N',' LIKE N'%,' + CAST(@I2 AS NVARCHAR(12)) + N',%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN N',' + @Ids2 + N',' LIKE N'%,' + CAST(@I5 AS NVARCHAR(12)) + N',%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN N',' + @Ids2 + N',' LIKE N'%,' + CAST(@I1 AS NVARCHAR(12)) + N',%' THEN '1' ELSE '0' END;

    -- The user who acted, inactive: StatusByActive 0 (the page shows "(inactive)")
    UPDATE Users SET AccountStatus = 0 WHERE UserId = @Ct2;
    SET @N = NULL;
    SELECT @N = h.ActedBy FROM Action_Item_Status_History h WHERE h.StatusHistoryId = (SELECT MAX(StatusHistoryId) FROM Action_Item_Status_History WHERE ActionItemId = @I4);
    INSERT INTO @T SELECT 'The user who acted is read from Users at each list (a second Controller made inactive: AccountStatus 0, the name kept)', '0 ZZ47 controller two',
           CAST((SELECT AccountStatus FROM Users WHERE UserId = @N) AS VARCHAR(2)) + ' ' + (SELECT UserName FROM Users WHERE UserId = @N);
    UPDATE Users SET AccountStatus = 1 WHERE UserId = @Ct2;

    ---------------------------------------------------------------------------
    -- Parity: spr_GetFollowupList and the page's old query return the same ActionItemIds in the same order
    ---------------------------------------------------------------------------
    INSERT INTO @Combo (Committee, Search, Meeting, FromM, ToM, Dept, Confirm)
    SELECT f.Committee, f.Search, f.Meeting, f.FromM, f.ToM, d.Dept, c.Confirm
    FROM (SELECT 0 AS Committee, 0 AS Search, 0 AS Meeting, 0 AS FromM, 0 AS ToM          -- every committee
          UNION ALL SELECT @CZ, 0, @M1, 0, 0                                                 -- Particular, meeting M1
          UNION ALL SELECT @CZ, 0, 0, 0, 0                                                   -- Particular, all meetings
          UNION ALL SELECT @CZ, 1, 0, @M1, @M2) f                                            -- Between M1 and M2
    CROSS JOIN (SELECT 0 AS Dept UNION ALL SELECT @DA) d
    CROSS JOIN (SELECT -1 AS Confirm UNION ALL SELECT 1 UNION ALL SELECT 0) c;

    SET @Differ = 0;
    SET @Combos = 0;
    SET @Compared = 0;
    SET @First = '';
    DECLARE ComboCursor CURSOR LOCAL FAST_FORWARD FOR SELECT Committee, Search, Meeting, FromM, ToM, Dept, Confirm FROM @Combo ORDER BY Seq;
    OPEN ComboCursor;
    FETCH NEXT FROM ComboCursor INTO @Cm, @Sr, @Mt, @Fm, @Tm, @Dp, @Cf;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        EXEC #ZZ47List @Acting = @Ctl, @Committee = @Cm, @Search = @Sr, @Meeting = @Mt, @From = @Fm, @To = @Tm, @Dept = @Dp, @Confirm = @Cf,
             @Ids = @Ids OUTPUT, @Rows = @N OUTPUT, @Status = @St OUTPUT, @R = @R OUTPUT, @Rs = @Rs OUTPUT;
        EXEC #ZZ47Old @Committee = @Cm, @Search = @Sr, @Meeting = @Mt, @From = @Fm, @To = @Tm, @Dept = @Dp, @Confirm = @Cf,
             @Ids = @Ids2 OUTPUT, @Rows = @N2 OUTPUT;
        SET @Combos = @Combos + 1;
        IF (@Cm = @CZ AND @Sr = 1 AND @Dp = 0 AND @Cf = -1)
            SET @Between = @Ids;
        SET @Compared = @Compared + @N2;
        IF (@R <> 1 OR @N <> @N2 OR CAST(@Ids AS VARBINARY(MAX)) <> CAST(@Ids2 AS VARBINARY(MAX)))
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
    INSERT INTO @T SELECT 'Parity with the old query (ReportsMgr.GetFollowupReport) for Both / Confirmed / Pending, every committee, Particular (one and all meetings), Between, with and without a department ('
                        + CAST(@Compared AS VARCHAR(12)) + ' rows compared): combinations, combinations that differ',
           '24, 0', CAST(@Combos AS VARCHAR(12)) + ', ' + CAST(@Differ AS VARCHAR(12)) + @First;
    INSERT INTO @T SELECT 'Parity is not empty: the ZZ47 items in the Between combination (M1 and M2, Both, no department; K 20 is on M3)', '21',
           CAST((SELECT COUNT(*) FROM @Item i WHERE N',' + ISNULL(@Between, N'') + N',' LIKE N'%,' + CAST(i.ActionItemId AS NVARCHAR(12)) + N',%') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- A reopened item counts as not confirmed everywhere IsConfirmed is read
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'fn_DashboardActionItems for the Controller (Dashboard Action Items card): the reopened K 2 listed and Overdue; the confirmed K 1 not listed', '1 1, 0',
           CAST((SELECT COUNT(*) FROM dbo.fn_DashboardActionItems(@Ctl, CAST(GETDATE() AS DATE)) WHERE ActionItemId = @I2) AS VARCHAR(12)) + ' '
         + ISNULL((SELECT CAST(MAX(IsOverdue) AS VARCHAR(2)) FROM dbo.fn_DashboardActionItems(@Ctl, CAST(GETDATE() AS DATE)) WHERE ActionItemId = @I2), '-') + ', '
         + CAST((SELECT COUNT(*) FROM dbo.fn_DashboardActionItems(@Ctl, CAST(GETDATE() AS DATE)) WHERE ActionItemId = @I1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'View_Action_Item (the Controller''s Followup and Followup Summary reports): K 2 with IsConfirmed 0, K 1 with 1', '1, 1',
           CAST((SELECT COUNT(*) FROM View_Action_Item WHERE ActionItemId = @I2 AND IsConfirmed = 0) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM View_Action_Item WHERE ActionItemId = @I1 AND IsConfirmed = 1) AS VARCHAR(12));
    -- spr_GetFollowupReportForManagement (Management's Followup reports), Not Confirmed and Confirmed
    SELECT TOP 0 v.*, m.MinutesStatus, CAST('' AS VARCHAR(30)) AS MinutesStatusMark INTO #ZZ47Mg FROM View_Action_Item v INNER JOIN Meeting m ON m.MeetingId = v.MeetingId;
    INSERT INTO #ZZ47Mg EXEC dbo.spr_GetFollowupReportForManagement @CommitteeId = @CZ, @MeetingNoSearch = 0, @MeetingId = @M1, @FromMeetingId = 0,
         @ToMeetingId = 0, @DepartmentId = @DA, @ConfirmStatus = 0, @ActingUserId = @Gmt, @Result = @R OUTPUT, @Reason = @Rs OUTPUT;
    SET @N = (SELECT COUNT(*) FROM #ZZ47Mg WHERE ActionItemId = @I2);
    DELETE FROM #ZZ47Mg;
    INSERT INTO #ZZ47Mg EXEC dbo.spr_GetFollowupReportForManagement @CommitteeId = @CZ, @MeetingNoSearch = 0, @MeetingId = @M1, @FromMeetingId = 0,
         @ToMeetingId = 0, @DepartmentId = @DA, @ConfirmStatus = 1, @ActingUserId = @Gmt, @Result = @R2 OUTPUT, @Reason = @Rs2 OUTPUT;
    SET @N2 = (SELECT COUNT(*) FROM #ZZ47Mg WHERE ActionItemId = @I2);
    INSERT INTO @T SELECT 'spr_GetFollowupReportForManagement (Management''s Followup reports): the reopened K 2 under Not Confirmed, not under Confirmed (Result each)', '1 1, 1 0',
           CAST(@R AS VARCHAR(12)) + ' ' + CAST(@N AS VARCHAR(12)) + ', ' + CAST(@R2 AS VARCHAR(12)) + ' ' + CAST(@N2 AS VARCHAR(12));
    DROP TABLE #ZZ47Mg;

    ---------------------------------------------------------------------------
    -- The history rows go with their item, whichever procedure deletes it
    ---------------------------------------------------------------------------
    -- K 17, 18, 19, 20 confirmed with a history row each
    SET @Str = N'<items><i id="' + CAST(@I17 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I18 AS NVARCHAR(12)) + N'"/><i id="'
             + CAST(@I19 AS NVARCHAR(12)) + N'"/><i id="' + CAST(@I20 AS NVARCHAR(12)) + N'"/></items>';
    SET @X = CAST(@Str AS XML);
    EXEC dbo.spr_SaveFollowupConfirmed @ActingUserId = @Ctl, @Items = @X, @Result = @R OUTPUT, @Reason = @Rs OUTPUT, @Saved = @Sv OUTPUT, @Skipped = @Sk OUTPUT;
    INSERT INTO @T SELECT 'K 17 to 20 confirmed for the delete checks (Saved; history rows)', '4; 4',
           CAST(@Sv AS VARCHAR(12)) + '; '
         + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId IN (@I17, @I18, @I19, @I20)) AS VARCHAR(12));

    -- spr_UpdateMinutes: the decision of K 18 is no longer Followup, so its action item is deleted (step 38 text)
    DELETE FROM @Res;
    SET @N = (SELECT MinutesId FROM @Item WHERE K = 18);
    INSERT INTO @Res EXEC dbo.spr_UpdateMinutes @Code = 'All', @MinutesId = @N, @DecisionTypeId = @Other, @Directions = N'ZZ47', @ActualResolution = N'ZZ47',
         @ShortText = N'ZZ47 item 18', @CreatedBy = @Ctl, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'spr_UpdateMinutes, decision no longer Followup (K 18): Result; the action item and its history rows', '1; 0 0',
           ISNULL((SELECT CAST(MAX(Result) AS VARCHAR(12)) FROM @Res), '-') + '; '
         + CAST((SELECT COUNT(*) FROM Action_Item WHERE ActionItemId = @I18) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I18) AS VARCHAR(12));

    -- spr_DeleteAgendaByAgendaId: K 19 on M2 (agenda open, minutes open)
    DELETE FROM @Res;
    SET @N = (SELECT AgendaId FROM @Item WHERE K = 19);
    INSERT INTO @Res EXEC dbo.spr_DeleteAgendaByAgendaId @AgendaId = @N, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'spr_DeleteAgendaByAgendaId (K 19, agenda open): Result; the action item and its history rows', '1; 0 0',
           ISNULL((SELECT CAST(MAX(Result) AS VARCHAR(12)) FROM @Res), '-') + '; '
         + CAST((SELECT COUNT(*) FROM Action_Item WHERE ActionItemId = @I19) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I19) AS VARCHAR(12));

    -- spr_AgendaFinalizeByMeetingId: M3 (agenda open) deletes and re-creates its minutes, so K 20's action item goes
    DELETE FROM @Res;
    INSERT INTO @Res EXEC dbo.spr_AgendaFinalizeByMeetingId @MeetingId = @M3;
    INSERT INTO @T SELECT 'spr_AgendaFinalizeByMeetingId (M3, agenda open; K 20): Result; the action item and its history rows', '1; 0 0',
           ISNULL((SELECT CAST(MAX(Result) AS VARCHAR(12)) FROM @Res), '-') + '; '
         + CAST((SELECT COUNT(*) FROM Action_Item WHERE ActionItemId = @I20) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I20) AS VARCHAR(12));

    -- A direct DELETE (as BMMS-Test-MinutesEditor-A2.sql cleans up; spr_sys_ResetDatabase deletes every row the same way)
    DELETE FROM ActionItem_User_Map WHERE ActionItemId = @I17;
    DELETE FROM Action_Item WHERE ActionItemId = @I17;
    INSERT INTO @T SELECT 'A direct DELETE of the action item K 17: its history rows', '0',
           CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE ActionItemId = @I17) AS VARCHAR(12));

    -- spr_DeleteUserByUserId: a user with history rows is refused (Reason 6, 'minutes'); a user without is deleted
    DELETE FROM @Res;
    INSERT INTO @Res EXEC dbo.spr_DeleteUserByUserId @UserId = @Ct2, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'spr_DeleteUserByUserId of the second Controller (history rows only): Result Reason; minutes in the detail; still there', '0 6; 1; 1',
           ISNULL((SELECT CAST(MAX(Result) AS VARCHAR(12)) + ' ' + CAST(MAX(Reason) AS VARCHAR(12)) FROM @Res), '-') + '; '
         + CASE WHEN (SELECT MAX(ReasonDetail) FROM @Res) LIKE N'%minutes%' THEN '1' ELSE '0' END + '; '
         + CAST((SELECT COUNT(*) FROM Users WHERE UserId = @Ct2) AS VARCHAR(12));
    DELETE FROM @Res;
    INSERT INTO @Res EXEC dbo.spr_DeleteUserByUserId @UserId = @Fresh, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'spr_DeleteUserByUserId of a user without history: Result Reason; gone', '1 0; 0',
           ISNULL((SELECT CAST(MAX(Result) AS VARCHAR(12)) + ' ' + CAST(MAX(Reason) AS VARCHAR(12)) FROM @Res), '-') + '; '
         + CAST((SELECT COUNT(*) FROM Users WHERE UserId = @Fresh) AS VARCHAR(12));

    INSERT INTO @T SELECT 'At the end the test''s own transaction is still open (@@TRANCOUNT)', '1', CAST(@@TRANCOUNT AS VARCHAR(12));

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
SELECT @HisAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(StatusHistoryId, ActionItemId, [Action], Reason, ActedBy, ActedOn)), 0) AS VARCHAR(12)) FROM Action_Item_Status_History;
INSERT INTO @T SELECT 'After the rollback: Agenda unchanged (count, checksum)', @AgendaBefore, @AgendaAfter;
INSERT INTO @T SELECT 'After the rollback: Minutes unchanged (count, checksum)', @MinBefore, @MinAfter;
INSERT INTO @T SELECT 'After the rollback: Action_Item unchanged (count, checksum)', @ActBefore, @ActAfter;
INSERT INTO @T SELECT 'After the rollback: ActionItem_User_Map unchanged (count, checksum)', @MapBefore, @MapAfter;
INSERT INTO @T SELECT 'After the rollback: Action_Item_Status_History unchanged (count, checksum)', @HisBefore, @HisAfter;
INSERT INTO @T SELECT 'After the rollback: no transaction open', '0', CAST(@@TRANCOUNT AS VARCHAR(12));

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
SELECT 'After the test: no ZZ47 department, user, committee, meeting, item, action item or history row left', '0 0 0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ47%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz47%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z47') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ47 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'ZZ47-%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ47') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Action_Item_Status_History WHERE Reason LIKE N'ZZ47%') AS VARCHAR(12));

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

DROP PROCEDURE #ZZ47State;
DROP PROCEDURE #ZZ47List;
DROP PROCEDURE #ZZ47Old;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
