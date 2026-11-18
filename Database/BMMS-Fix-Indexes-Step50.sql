/* ============================================================================
   BMMS - Indexes for the Dashboard lists (step 50, step UN6e)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision UN6e (2026-11-18, plan approved with six answers and five
   changes): nonclustered indexes only; no primary key, table, procedure or
   function is changed; a candidate is kept only where it at least halves
   the reads on its table in a path the Dashboard or the Followup page
   calls, measured on a copy of BMMS_Test filled to about one year of use
   (Database/README.md, section "Step UN6e", gives the table of reads).

   New (three nonclustered indexes, names IX_<Table>_<Keys>):
     IX_Alert_User_Map_UserId_StatusId
         ON Alert_User_Map (UserId, StatusId) INCLUDE (ReadStatus, AlertId)
         fn_DashboardAlerts / spr_GetDashboardAlerts (step 43): the alerts of
         one user (UserId = @UserId AND StatusId = 1); fn_AgendaWaitingFor
         (step 44) for My approvals and the Meetings card.
     IX_Alert_Master_SourceType_SourceTypeId
         ON Alert_Master (SourceType, SourceTypeId)
         spr_GetDashboardApprovals (step 44): the alert of an agenda item
         (SourceType = 'Agenda' AND SourceTypeId = AgendaId);
         fn_AgendaWaitingFor (step 44).
     IX_Agenda_MeetingId
         ON Agenda (MeetingId) INCLUDE (DepartmentId, AgendaStatusCode)
         spr_GetDashboardMeetings (steps 42 and 45): the agenda items of a
         meeting (a.MeetingId = m.MeetingId); spr_GetDashboardSummary
         (step 45).

   Measured and not kept (no index made): ActionItem_User_Map (UserId) and
   (ActionItemId, UserId), Agenda (AgendaStatusCode), Minutes (AgendaId),
   Meeting (MeetingDate), Users (ManagerId), Action_Item (MinutesId).
   Action_Item_Status_History (ActionItemId) and the User_Department index for
   fn_UserDepartmentScope already exist (steps 47 and 39).

   Safe to re-run: an index that is already there with the same definition
   is left as it is. Before it creates anything the script checks every
   index of this step and stops, changing nothing, when
     - an index of the same name on that table has another definition (key
       columns and their order, included columns, unique, filtered,
       clustered, disabled): it is never dropped silently; or
     - another index on that table already has the same first key column
       (it would be a duplicate).

   This step has no procedure text: a later re-run of an earlier step's Fix
   script does not remove these indexes, and step 50 keeps reading Installed.
   BMMS-Rollback-Indexes-Step50.sql drops these three indexes only.

   Express and compatibility level 100: no ONLINE, no compression, no
   filter. Changes no data. Installed after step 49 (it stops otherwise).

   Marker: one row per index in BMMS-Check-InstalledSteps.sql (name, table,
   key and included columns in order, compared with the index as it is).

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   The file is plain ASCII. From the command line use sqlcmd -I.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- The gate table of an earlier run in this window that was cancelled before its end: dropped first, so only the
-- checks of this run can open the gate
IF OBJECT_ID('tempdb..#Step50FixChecked') IS NOT NULL DROP TABLE #Step50FixChecked;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
DECLARE @Problem VARCHAR(2000);

-- The indexes of this step: name, table, definition (as built below from sys.indexes and sys.index_columns)
DECLARE @Want TABLE (IndexName SYSNAME, TableName SYSNAME, LeadKey SYSNAME, Def VARCHAR(400));
INSERT INTO @Want VALUES
('IX_Alert_User_Map_UserId_StatusId', 'Alert_User_Map', 'UserId', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:UserId,StatusId|I:ReadStatus,AlertId'),
('IX_Alert_Master_SourceType_SourceTypeId', 'Alert_Master', 'SourceType', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:SourceType,SourceTypeId|I:'),
('IX_Agenda_MeetingId', 'Agenda', 'MeetingId', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:MeetingId|I:DepartmentId,AgendaStatusCode');

-- Every index (not heaps) of the three tables as it is now, in the same form
DECLARE @Have TABLE (IndexName SYSNAME, TableName SYSNAME, LeadKey SYSNAME NULL, Def VARCHAR(400));
INSERT INTO @Have
SELECT i.name, t.name,
       (SELECT c.name FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal = 1),
       i.type_desc + '|' + CASE WHEN i.is_unique = 1 THEN 'UNIQUE' ELSE 'NONUNIQUE' END
       + '|' + CASE WHEN i.has_filter = 1 THEN 'FILTERED' ELSE 'NOFILTER' END
       + '|' + CASE WHEN i.is_disabled = 1 THEN 'DISABLED' ELSE 'ENABLED' END
       + '|K:' + ISNULL(STUFF((SELECT ',' + c.name + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE '' END
                               FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                               WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal > 0
                               ORDER BY ic.key_ordinal FOR XML PATH('')), 1, 1, ''), '')
       + '|I:' + ISNULL(STUFF((SELECT ',' + c.name
                               FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                               WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                               ORDER BY ic.index_column_id FOR XML PATH('')), 1, 1, ''), '')
FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
WHERE t.schema_id = SCHEMA_ID('dbo') AND t.name IN ('Alert_User_Map', 'Alert_Master', 'Agenda') AND i.type > 0;

-- An index of a step 50 name with another definition
SELECT @Problem = ISNULL(@Problem + '; ', '') + h.TableName + '.' + h.IndexName + ' is ' + h.Def + ', expected ' + w.Def
FROM @Want w JOIN @Have h ON h.TableName = w.TableName AND h.IndexName = w.IndexName
WHERE h.Def COLLATE DATABASE_DEFAULT <> w.Def;

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_FollowupStatusLatest')), '') NOT LIKE '%FollowupReports-Step49%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupReport')), '') NOT LIKE '%FollowupReports-Step49%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupByDepartmentReport')), '') NOT LIKE '%FollowupReports-Step49%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetFollowupList')), '') NOT LIKE '%FollowupReports-Step49%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_ReopenFollowup')), '') NOT LIKE '%FollowupReports-Step49%')
BEGIN
    RAISERROR('Step 49 (BMMS-Fix-FollowupReports-Step49.sql) is not installed in "%s" (one of its five markers is missing). The steps are installed in order: run step 49 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@Problem IS NOT NULL)
BEGIN
    RAISERROR('An index of this step exists in "%s" with another definition: %s. It is not dropped by this script. Tell the Consultant. Nothing was changed.', 16, 1, @CurrentDatabase, @Problem);
    SET NOEXEC ON;
END
ELSE
BEGIN
    -- Another index (other name) with the same first key column: the step 50 index would duplicate it
    SELECT @Problem = ISNULL(@Problem + '; ', '') + h.TableName + '.' + h.IndexName + ' (first key column ' + h.LeadKey + ')'
    FROM @Want w JOIN @Have h ON h.TableName = w.TableName AND h.LeadKey = w.LeadKey AND h.IndexName <> w.IndexName;
    IF (@Problem IS NOT NULL)
    BEGIN
        RAISERROR('An index in "%s" already has the first key column of a step 50 index: %s. A second one would duplicate it. Tell the Consultant. Nothing was changed.', 16, 1, @CurrentDatabase, @Problem);
        SET NOEXEC ON;
    END
    ELSE
        -- The checks above ran to their end: the indexes below are made only when this table exists (a second gate, in
        -- case an error stopped this batch before NOEXEC could be set)
        CREATE TABLE #Step50FixChecked (Ok INT);
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Indexes-Step50 (step UN6e): the alerts of one user, unread first (fn_DashboardAlerts, step 43)
IF OBJECT_ID('tempdb..#Step50FixChecked') IS NULL
    PRINT 'IX_Alert_User_Map_UserId_StatusId: not made (the checks of this script did not run to their end).';
ELSE IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Alert_User_Map') AND name = 'IX_Alert_User_Map_UserId_StatusId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Alert_User_Map_UserId_StatusId ON dbo.Alert_User_Map (UserId, StatusId) INCLUDE (ReadStatus, AlertId);
    PRINT 'Created IX_Alert_User_Map_UserId_StatusId.';
END
ELSE
    PRINT 'IX_Alert_User_Map_UserId_StatusId is already present with the same definition; left as it is.';
GO

-- Indexes-Step50 (step UN6e): the alert of an agenda item (spr_GetDashboardApprovals and fn_AgendaWaitingFor, step 44)
IF OBJECT_ID('tempdb..#Step50FixChecked') IS NULL
    PRINT 'IX_Alert_Master_SourceType_SourceTypeId: not made (the checks of this script did not run to their end).';
ELSE IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Alert_Master') AND name = 'IX_Alert_Master_SourceType_SourceTypeId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Alert_Master_SourceType_SourceTypeId ON dbo.Alert_Master (SourceType, SourceTypeId);
    PRINT 'Created IX_Alert_Master_SourceType_SourceTypeId.';
END
ELSE
    PRINT 'IX_Alert_Master_SourceType_SourceTypeId is already present with the same definition; left as it is.';
GO

-- Indexes-Step50 (step UN6e): the agenda items of a meeting (spr_GetDashboardMeetings and spr_GetDashboardSummary, step 45)
IF OBJECT_ID('tempdb..#Step50FixChecked') IS NULL
    PRINT 'IX_Agenda_MeetingId: not made (the checks of this script did not run to their end).';
ELSE IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Agenda') AND name = 'IX_Agenda_MeetingId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Agenda_MeetingId ON dbo.Agenda (MeetingId) INCLUDE (DepartmentId, AgendaStatusCode);
    PRINT 'Created IX_Agenda_MeetingId.';
END
ELSE
    PRINT 'IX_Agenda_MeetingId is already present with the same definition; left as it is.';
GO

IF OBJECT_ID('tempdb..#Step50FixChecked') IS NOT NULL
BEGIN
    PRINT 'Step 50 (Indexes-Step50) done. Run BMMS-Test-Indexes-Step50.sql on the test copy, then BMMS-Check-InstalledSteps.sql.';
    DROP TABLE #Step50FixChecked;
END
GO

SET NOEXEC OFF;
GO
