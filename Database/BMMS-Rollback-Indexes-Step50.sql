/* ============================================================================
   BMMS - Roll back step 50 (indexes for the Dashboard lists; step UN6e)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Drops the three indexes of step 50, and nothing else:
     IX_Alert_User_Map_UserId_StatusId        on Alert_User_Map
     IX_Alert_Master_SourceType_SourceTypeId  on Alert_Master
     IX_Agenda_MeetingId                      on Agenda
   An index of one of these names that is not there is skipped.

   Before it drops anything it checks that each of them that is present has
   exactly the step 50 definition; an index of the same name with another
   definition was not made by this step, and the script then refuses
   (nothing is dropped).

   No procedure reads an index by name: the application build needs no
   change, the lists are only slower on a large database. Safe to re-run.
   No later step depends on step 50 today.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS". Plain ASCII.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- The gate table of an earlier run in this window that was cancelled before its end: dropped first, so only the
-- checks of this run can open the gate
IF OBJECT_ID('tempdb..#Step50RollbackChecked') IS NOT NULL DROP TABLE #Step50RollbackChecked;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
DECLARE @Problem VARCHAR(2000);

DECLARE @Want TABLE (IndexName SYSNAME, TableName SYSNAME, Def VARCHAR(400));
INSERT INTO @Want VALUES
('IX_Alert_User_Map_UserId_StatusId', 'Alert_User_Map', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:UserId,StatusId|I:ReadStatus,AlertId'),
('IX_Alert_Master_SourceType_SourceTypeId', 'Alert_Master', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:SourceType,SourceTypeId|I:'),
('IX_Agenda_MeetingId', 'Agenda', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:MeetingId|I:DepartmentId,AgendaStatusCode');

SELECT @Problem = ISNULL(@Problem + '; ', '') + w.TableName + '.' + w.IndexName + ' is ' + d.Def
FROM @Want w
JOIN sys.indexes i ON i.object_id = OBJECT_ID('dbo.' + w.TableName) AND i.name COLLATE DATABASE_DEFAULT = w.IndexName
CROSS APPLY (SELECT i.type_desc + '|' + CASE WHEN i.is_unique = 1 THEN 'UNIQUE' ELSE 'NONUNIQUE' END
       + '|' + CASE WHEN i.has_filter = 1 THEN 'FILTERED' ELSE 'NOFILTER' END
       + '|' + CASE WHEN i.is_disabled = 1 THEN 'DISABLED' ELSE 'ENABLED' END
       + '|K:' + ISNULL(STUFF((SELECT ',' + c.name + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE '' END
                               FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                               WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal > 0
                               ORDER BY ic.key_ordinal FOR XML PATH('')), 1, 1, ''), '')
       + '|I:' + ISNULL(STUFF((SELECT ',' + c.name
                               FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                               WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                               ORDER BY ic.index_column_id FOR XML PATH('')), 1, 1, ''), '') AS Def) d
WHERE d.Def COLLATE DATABASE_DEFAULT <> w.Def;

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@Problem IS NOT NULL)
BEGIN
    RAISERROR('An index of a step 50 name in "%s" has another definition and was not made by step 50: %s. Nothing was dropped. Tell the Consultant.', 16, 1, @CurrentDatabase, @Problem);
    SET NOEXEC ON;
END
ELSE
    -- The checks above ran to their end: the drops below run only when this table exists (a second gate, in case an
    -- error stopped this batch before NOEXEC could be set)
    CREATE TABLE #Step50RollbackChecked (Ok INT);
GO

PRINT 'Database: ' + DB_NAME();
GO

IF OBJECT_ID('tempdb..#Step50RollbackChecked') IS NULL
    PRINT 'IX_Alert_User_Map_UserId_StatusId: not dropped (the checks of this script did not run to their end).';
ELSE IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Alert_User_Map') AND name = 'IX_Alert_User_Map_UserId_StatusId')
BEGIN
    DROP INDEX IX_Alert_User_Map_UserId_StatusId ON dbo.Alert_User_Map;
    PRINT 'Dropped IX_Alert_User_Map_UserId_StatusId.';
END
ELSE
    PRINT 'IX_Alert_User_Map_UserId_StatusId is not present; skipped.';
GO

IF OBJECT_ID('tempdb..#Step50RollbackChecked') IS NULL
    PRINT 'IX_Alert_Master_SourceType_SourceTypeId: not dropped (the checks of this script did not run to their end).';
ELSE IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Alert_Master') AND name = 'IX_Alert_Master_SourceType_SourceTypeId')
BEGIN
    DROP INDEX IX_Alert_Master_SourceType_SourceTypeId ON dbo.Alert_Master;
    PRINT 'Dropped IX_Alert_Master_SourceType_SourceTypeId.';
END
ELSE
    PRINT 'IX_Alert_Master_SourceType_SourceTypeId is not present; skipped.';
GO

IF OBJECT_ID('tempdb..#Step50RollbackChecked') IS NULL
    PRINT 'IX_Agenda_MeetingId: not dropped (the checks of this script did not run to their end).';
ELSE IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Agenda') AND name = 'IX_Agenda_MeetingId')
BEGIN
    DROP INDEX IX_Agenda_MeetingId ON dbo.Agenda;
    PRINT 'Dropped IX_Agenda_MeetingId.';
END
ELSE
    PRINT 'IX_Agenda_MeetingId is not present; skipped.';
GO

IF OBJECT_ID('tempdb..#Step50RollbackChecked') IS NOT NULL
BEGIN
    PRINT 'Step 50 rolled back. BMMS-Check-InstalledSteps.sql now reads step 50 Missing.';
    DROP TABLE #Step50RollbackChecked;
END
GO

SET NOEXEC OFF;
GO
