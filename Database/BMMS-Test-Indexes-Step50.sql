/* ============================================================================
   BMMS - Test step 50 (indexes for the Dashboard lists; step UN6e)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   READ ONLY. It changes nothing; it reads sys.indexes and sys.index_columns.
   Run it on the test copy (BMMS_Test) after BMMS-Fix-Indexes-Step50.sql.

   Checks (one row each; every row must read PASS):
     1 to 3  each step 50 index is present with exactly its definition:
             nonclustered, not unique, not filtered, not disabled, its key
             columns in order (ascending) and its included columns in order
     4 to 6  no other index on that table has the same first key column
             (the primary key included)
     7 to 9  the clustered primary key of Alert_User_Map, Alert_Master and
             Agenda is unchanged (PK_<Table>, clustered, on its id column)

   After it, the Test scripts of steps 42 to 49 are run again: they must
   still pass with step 50 installed (Database/README.md, section "Step
   UN6e").

   It has no USE line. It stops unless the current database name starts with
   "BMMS" and is not "BMMS". Plain ASCII.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase NOT LIKE 'BMMS%' OR @CurrentDatabase = 'BMMS')
BEGIN
    RAISERROR('Current database is "%s". This test is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @Want TABLE (No INT, IndexName SYSNAME, TableName SYSNAME, LeadKey SYSNAME, Def VARCHAR(400), PkName SYSNAME, PkDef VARCHAR(400));
INSERT INTO @Want VALUES
(1, 'IX_Alert_User_Map_UserId_StatusId', 'Alert_User_Map', 'UserId', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:UserId,StatusId|I:ReadStatus,AlertId',
    'PK_Alert_User_Map', 'CLUSTERED|UNIQUE|NOFILTER|ENABLED|K:AlertUserId|I:'),
(2, 'IX_Alert_Master_SourceType_SourceTypeId', 'Alert_Master', 'SourceType', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:SourceType,SourceTypeId|I:',
    'PK_Alert_Master', 'CLUSTERED|UNIQUE|NOFILTER|ENABLED|K:AlertId|I:'),
(3, 'IX_Agenda_MeetingId', 'Agenda', 'MeetingId', 'NONCLUSTERED|NONUNIQUE|NOFILTER|ENABLED|K:MeetingId|I:DepartmentId,AgendaStatusCode',
    'PK_Agenda', 'CLUSTERED|UNIQUE|NOFILTER|ENABLED|K:AgendaId|I:');

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

DECLARE @T TABLE (TestNo INT, Test VARCHAR(300), Expected VARCHAR(400), Actual VARCHAR(400));

INSERT INTO @T
SELECT w.No, w.TableName + '.' + w.IndexName + ' is present with its step 50 definition', w.Def,
       ISNULL((SELECT h.Def FROM @Have h WHERE h.TableName = w.TableName AND h.IndexName = w.IndexName), 'missing')
FROM @Want w;

INSERT INTO @T
SELECT w.No + 3, 'No other index on ' + w.TableName + ' has the first key column ' + w.LeadKey, 'none',
       ISNULL(STUFF((SELECT ', ' + h.IndexName FROM @Have h
                     WHERE h.TableName = w.TableName AND h.LeadKey = w.LeadKey AND h.IndexName <> w.IndexName
                     ORDER BY h.IndexName FOR XML PATH('')), 1, 2, ''), 'none')
FROM @Want w;

INSERT INTO @T
SELECT w.No + 6, 'The primary key ' + w.PkName + ' of ' + w.TableName + ' is unchanged', w.PkDef,
       ISNULL((SELECT h.Def FROM @Have h WHERE h.TableName = w.TableName AND h.IndexName = w.PkName), 'missing')
FROM @Want w;

SELECT TestNo, Test, Expected, Actual, CASE WHEN Actual = Expected THEN 'PASS' ELSE 'FAIL' END AS Status
FROM @T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> Expected OR Actual IS NULL THEN 1 ELSE 0 END) AS Failed,
       0 AS Skipped
FROM @T;
GO

SET NOEXEC OFF;
GO
