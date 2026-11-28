/* ============================================================================
   BMMS - Unicode agenda and minutes text (step 31)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Agenda and minutes text was stored as VARCHAR (code page 1252, collation
   SQL_Latin1_General_CP1_CI_AS): the rupee sign and Tamil or Hindi letters
   became "?" when they were saved. From this step they are kept.

   Columns changed from VARCHAR(MAX) to NVARCHAR(MAX) (collation and NULL /
   NOT NULL kept as they are):
     Agenda              ShortText, AgendaText, AgendaTextPath,
                         ProposedResolution, FilePath, MgrComments,
                         ControllerComments
     Minutes             Directions, ActualResolution
     Action_Item         Directions, ActionText
     Audit_Trail_Master  Old_Value, New_Value
   The views that read these tables are refreshed (View_Agenda, View_Minute,
   View_Action_Item, View_Action_Item_Users and any other view on them).

   Existing data is unchanged: every code page 1252 character has exactly one
   Unicode character. The script proves it in one transaction: before the
   change it keeps a SHA-256 hash of every value (as NVARCHAR), after the
   change it hashes the stored values again; any difference, or any change in
   the number of rows, rolls everything back and stops the script.

   Procedures (each carries the text UnicodeText-Step31; everything else is
   the text of the step that last set it):
     spr_AddEditAgenda              REPLACED (from step 20)
     spr_UpdateAgendaByAgendaId     REPLACED (from step 20)
     spr_AddEditAgendaByManager     REPLACED (from step 18)
     spr_AddEditAgendaByController  REPLACED (from step 18)
     spr_UpdateAgendaShortText      REPLACED (from step 23)
     spr_UpdateMinutes              REPLACED (from step 23)
     spr_UpdateActionItem           REPLACED (from the original database; no
                                    numbered script had it)
   Each parameter and old-value variable that carries one of these texts
   becomes NVARCHAR(MAX) (spr_UpdateMinutes and spr_UpdateActionItem had
   TEXT; @FilePath was VARCHAR(255) and now takes the whole list). Parameter
   names, order and defaults are unchanged, so the current build keeps
   working. In the three agenda add / edit procedures a change of the
   Proposed Resolution is now written to the audit trail as
   'ProposedResolution' (it was 'ShortText'); rows written before keep the
   old label.

   Needs steps 18, 20 and 23 (checked through their texts in the procedures)
   and stops otherwise. Steps 6, 15, 16, 17, 18, 20 and 23 each contain an
   older version of one of these procedures: if one of them is re-run, run
   this script again afterwards (the columns are kept; the procedures are
   replaced again). It stops if step 32 (the role permissions,
   RolePermissions-Step32) has already replaced one of its procedures: then
   run step 32 again instead. Safe to re-run: columns that are already
   NVARCHAR are left alone.

   Take a backup first: the change rewrites the rows of the four tables, and
   the text columns take about twice the space.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS",
   or if the database compatibility level is below 100.

   If you install from the command line, use sqlcmd -I (quoted identifiers ON);
   installing from SSMS already does this.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
DECLARE @Compat INT = (SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID());
DECLARE @CompatText VARCHAR(12) = CAST(ISNULL(@Compat, 0) AS VARCHAR(12));
DECLARE @Missing TABLE (Seq INT IDENTITY(1,1), ObjectName SYSNAME, Marker VARCHAR(100), Step VARCHAR(10));
DECLARE @MissingObject SYSNAME;
DECLARE @MissingStep VARCHAR(10);
DECLARE @LaterObject SYSNAME;
DECLARE @BadColumn NVARCHAR(300);
DECLARE @BoundObject NVARCHAR(300);
DECLARE @StatsColumn NVARCHAR(300);
DECLARE @ActionItemText NVARCHAR(MAX) = ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateActionItem')), '');

-- The older texts each replaced procedure must carry: whatever this script finds missing was replaced by
-- a later re-run of an older step, which has to be run again first
INSERT INTO @Missing (ObjectName, Marker, Step)
SELECT r.ObjectName, r.Marker, r.Step
FROM (VALUES
    ('spr_AddEditAgenda', '%MeetingLocks-Step16%', '16'),
    ('spr_AddEditAgenda', '%UserStatus2b-Step17%', '17'),
    ('spr_AddEditAgenda', '%SystemAccount3-Step18%', '18'),
    ('spr_AddEditAgenda', '%AgendaRouting-Step20%', '20'),
    ('spr_UpdateAgendaByAgendaId', '%MeetingLocks-Step16%', '16'),
    ('spr_UpdateAgendaByAgendaId', '%UserStatus2b-Step17%', '17'),
    ('spr_UpdateAgendaByAgendaId', '%SystemAccount3-Step18%', '18'),
    ('spr_UpdateAgendaByAgendaId', '%AgendaRouting-Step20%', '20'),
    ('spr_AddEditAgendaByManager', '%MeetingLocks-Step16%', '16'),
    ('spr_AddEditAgendaByManager', '%UserStatus2b-Step17%', '17'),
    ('spr_AddEditAgendaByManager', '%SystemAccount3-Step18%', '18'),
    ('spr_AddEditAgendaByController', '%MeetingLocks-Step16%', '16'),
    ('spr_AddEditAgendaByController', '%UserStatus2b-Step17%', '17'),
    ('spr_AddEditAgendaByController', '%SystemAccount3-Step18%', '18'),
    ('spr_UpdateAgendaShortText', '%MeetingLocks-Step16%', '16'),
    ('spr_UpdateAgendaShortText', '%WorkflowOrder-Step23%', '23'),
    ('spr_UpdateMinutes', '%FK #5%', '6'),
    ('spr_UpdateMinutes', '%MeetingLocks-Step16%', '16'),
    ('spr_UpdateMinutes', '%UserStatus2b-Step17%', '17'),
    ('spr_UpdateMinutes', '%SystemAccount3-Step18%', '18'),
    ('spr_UpdateMinutes', '%WorkflowOrder-Step23%', '23')
) r (ObjectName, Marker, Step)
WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + r.ObjectName)), '') NOT LIKE r.Marker;

SELECT TOP 1 @MissingObject = ObjectName, @MissingStep = Step FROM @Missing ORDER BY Seq;

-- Step 32 builds on this step: once it has replaced one of these procedures, this script must not undo it
SELECT TOP 1 @LaterObject = o.Name
FROM (VALUES ('spr_AddEditAgenda'), ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController'),
             ('spr_UpdateAgendaShortText'), ('spr_UpdateMinutes'), ('spr_UpdateActionItem')) o(Name)
WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%RolePermissions-Step32%';

-- Each column must exist and be VARCHAR(MAX) (not yet changed) or NVARCHAR(MAX) (a re-run)
SELECT TOP 1 @BadColumn = c.TableName + '.' + c.ColumnName
                        + ISNULL(' (' + t.name + CASE WHEN sc.max_length = -1 THEN '(max)' ELSE '(' + CAST(sc.max_length AS VARCHAR(12)) + ')' END + ')', ' (missing)')
FROM (VALUES ('Agenda', 'ShortText'), ('Agenda', 'AgendaText'), ('Agenda', 'AgendaTextPath'), ('Agenda', 'ProposedResolution'),
             ('Agenda', 'FilePath'), ('Agenda', 'MgrComments'), ('Agenda', 'ControllerComments'),
             ('Minutes', 'Directions'), ('Minutes', 'ActualResolution'),
             ('Action_Item', 'Directions'), ('Action_Item', 'ActionText'),
             ('Audit_Trail_Master', 'Old_Value'), ('Audit_Trail_Master', 'New_Value')) c (TableName, ColumnName)
LEFT JOIN sys.columns sc ON sc.object_id = OBJECT_ID('dbo.' + c.TableName) AND sc.name = c.ColumnName
LEFT JOIN sys.types t ON t.user_type_id = sc.user_type_id
WHERE sc.column_id IS NULL OR t.name NOT IN ('varchar', 'nvarchar') OR sc.max_length <> -1;

-- A schema-bound object on these tables, a statistic created by hand, or a full-text index on one of the
-- columns would make the column change fail
SELECT TOP 1 @BoundObject = OBJECT_SCHEMA_NAME(d.referencing_id) + '.' + OBJECT_NAME(d.referencing_id)
FROM sys.sql_expression_dependencies d
WHERE d.is_schema_bound_reference = 1
  AND d.referenced_id IN (OBJECT_ID('dbo.Agenda'), OBJECT_ID('dbo.Minutes'), OBJECT_ID('dbo.Action_Item'), OBJECT_ID('dbo.Audit_Trail_Master'));

SELECT TOP 1 @StatsColumn = OBJECT_NAME(s.object_id) + '.' + c.name + ' (' + s.name + ')'
FROM sys.stats s
JOIN sys.stats_columns sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id
JOIN sys.columns c ON c.object_id = sc.object_id AND c.column_id = sc.column_id
WHERE s.user_created = 1
  AND ((s.object_id = OBJECT_ID('dbo.Agenda') AND c.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments'))
    OR (s.object_id = OBJECT_ID('dbo.Minutes') AND c.name IN ('Directions', 'ActualResolution'))
    OR (s.object_id = OBJECT_ID('dbo.Action_Item') AND c.name IN ('Directions', 'ActionText'))
    OR (s.object_id = OBJECT_ID('dbo.Audit_Trail_Master') AND c.name IN ('Old_Value', 'New_Value')));

IF (@StatsColumn IS NULL)
    SELECT TOP 1 @StatsColumn = OBJECT_NAME(f.object_id) + '.' + c.name + ' (full-text index)'
    FROM sys.fulltext_index_columns f
    JOIN sys.columns c ON c.object_id = f.object_id AND c.column_id = f.column_id
    WHERE f.object_id IN (OBJECT_ID('dbo.Agenda'), OBJECT_ID('dbo.Minutes'), OBJECT_ID('dbo.Action_Item'), OBJECT_ID('dbo.Audit_Trail_Master'));

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(@Compat, 0) < 100)
BEGIN
    RAISERROR('The compatibility level of "%s" is %s; this script needs 100 or higher. Nothing was changed.', 16, 1, @CurrentDatabase, @CompatText);
    SET NOEXEC ON;
END
ELSE IF (COL_LENGTH('dbo.Audit_Trail_Master', 'Audit_Trail_Maser_Id') IS NULL OR COL_LENGTH('dbo.Agenda', 'AgendaId') IS NULL
         OR COL_LENGTH('dbo.Minutes', 'MinutesId') IS NULL OR COL_LENGTH('dbo.Action_Item', 'ActionItemId') IS NULL)
BEGIN
    RAISERROR('A key column (Agenda.AgendaId, Minutes.MinutesId, Action_Item.ActionItemId or Audit_Trail_Master.Audit_Trail_Maser_Id) is missing in "%s". Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@BadColumn IS NOT NULL)
BEGIN
    RAISERROR('In "%s", column %s is not VARCHAR(MAX) or NVARCHAR(MAX) as expected. Nothing was changed.', 16, 1, @CurrentDatabase, @BadColumn);
    SET NOEXEC ON;
END
ELSE IF (@BoundObject IS NOT NULL)
BEGIN
    RAISERROR('In "%s", %s is schema-bound to one of the tables Agenda, Minutes, Action_Item or Audit_Trail_Master; the columns cannot be changed while it exists. Nothing was changed.', 16, 1, @CurrentDatabase, @BoundObject);
    SET NOEXEC ON;
END
ELSE IF (@StatsColumn IS NOT NULL)
BEGIN
    RAISERROR('In "%s", column %s has a statistic created by hand or a full-text index; the column cannot be changed while it exists. Nothing was changed.', 16, 1, @CurrentDatabase, @StatsColumn);
    SET NOEXEC ON;
END
ELSE IF (@LaterObject IS NOT NULL)
BEGIN
    RAISERROR('In "%s", %s already carries the text of step 32 (RolePermissions-Step32), which contains this step. Run step 32 again instead of this script. Nothing was changed.', 16, 1, @CurrentDatabase, @LaterObject);
    SET NOEXEC ON;
END
ELSE IF (@MissingObject IS NOT NULL)
BEGIN
    RAISERROR('In "%s", %s does not carry the text of step %s: that step (or a later one in the README re-run order) was replaced by a re-run. Run steps %s to 23 again as the README says, then this script. Nothing was changed.', 16, 1, @CurrentDatabase, @MissingObject, @MissingStep, @MissingStep);
    SET NOEXEC ON;
END
-- spr_UpdateActionItem: the text of the original database (TEXT parameters, three @Code branches) or this step
ELSE IF (@ActionItemText NOT LIKE '%UnicodeText-Step31%'
         AND NOT (@ActionItemText LIKE '%@ActualResolution text,%' AND @ActionItemText LIKE '%@ActionText text,%'
                  AND @ActionItemText LIKE '%IF (@Code = ''All'')%' AND @ActionItemText LIKE '%IF (@Code = ''ActualResolution'')%'
                  AND @ActionItemText LIKE '%IF (@Code = ''ActionText'')%'))
BEGIN
    RAISERROR('In "%s", spr_UpdateActionItem is missing or is not the version this script expects (TEXT parameters @ActualResolution and @ActionText, @Code All / ActualResolution / ActionText). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

-- Read only: what this database has today
DECLARE @AgendaRows INT = (SELECT COUNT(*) FROM dbo.Agenda);
DECLARE @MinutesRows INT = (SELECT COUNT(*) FROM dbo.Minutes);
DECLARE @ActionRows INT = (SELECT COUNT(*) FROM dbo.Action_Item);
DECLARE @AuditRows INT = (SELECT COUNT(*) FROM dbo.Audit_Trail_Master);
DECLARE @ToChange INT;

SELECT @ToChange = COUNT(*)
FROM sys.columns sc
JOIN sys.types t ON t.user_type_id = sc.user_type_id
WHERE t.name = 'varchar'
  AND ((sc.object_id = OBJECT_ID('dbo.Agenda') AND sc.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments'))
    OR (sc.object_id = OBJECT_ID('dbo.Minutes') AND sc.name IN ('Directions', 'ActualResolution'))
    OR (sc.object_id = OBJECT_ID('dbo.Action_Item') AND sc.name IN ('Directions', 'ActionText'))
    OR (sc.object_id = OBJECT_ID('dbo.Audit_Trail_Master') AND sc.name IN ('Old_Value', 'New_Value')));

PRINT 'Database: ' + DB_NAME();
PRINT 'Rows: Agenda ' + CAST(@AgendaRows AS VARCHAR(12)) + ', Minutes ' + CAST(@MinutesRows AS VARCHAR(12))
    + ', Action_Item ' + CAST(@ActionRows AS VARCHAR(12)) + ', Audit_Trail_Master ' + CAST(@AuditRows AS VARCHAR(12));
PRINT 'Columns still VARCHAR: ' + CAST(@ToChange AS VARCHAR(12)) + ' of 13';
GO

-------------------------------------------------------------------------------
-- The columns (UnicodeText-Step31): one transaction; hashes before and after; any difference rolls back
-------------------------------------------------------------------------------
SET XACT_ABORT ON;

IF (OBJECT_ID('tempdb..#U31Cols') IS NOT NULL)
    DROP TABLE #U31Cols;
IF (OBJECT_ID('tempdb..#U31Before') IS NOT NULL)
    DROP TABLE #U31Before;
IF (OBJECT_ID('tempdb..#U31After') IS NOT NULL)
    DROP TABLE #U31After;

CREATE TABLE #U31Cols (Seq INT IDENTITY(1,1), TableName SYSNAME, ColumnName SYSNAME, KeyColumn SYSNAME,
                       TypeName SYSNAME, IsNullable BIT, CollationName SYSNAME NULL);
CREATE TABLE #U31Before (TableName SYSNAME, ColumnName SYSNAME, KeyId INT, ValueHash VARBINARY(32) NULL, Chars BIGINT NULL);
CREATE TABLE #U31After (TableName SYSNAME, ColumnName SYSNAME, KeyId INT, ValueHash VARBINARY(32) NULL, Chars BIGINT NULL);

INSERT INTO #U31Cols (TableName, ColumnName, KeyColumn, TypeName, IsNullable, CollationName)
SELECT c.TableName, c.ColumnName, c.KeyColumn, t.name, sc.is_nullable, sc.collation_name
FROM (VALUES ('Agenda', 'ShortText', 'AgendaId'), ('Agenda', 'AgendaText', 'AgendaId'), ('Agenda', 'AgendaTextPath', 'AgendaId'),
             ('Agenda', 'ProposedResolution', 'AgendaId'), ('Agenda', 'FilePath', 'AgendaId'), ('Agenda', 'MgrComments', 'AgendaId'),
             ('Agenda', 'ControllerComments', 'AgendaId'),
             ('Minutes', 'Directions', 'MinutesId'), ('Minutes', 'ActualResolution', 'MinutesId'),
             ('Action_Item', 'Directions', 'ActionItemId'), ('Action_Item', 'ActionText', 'ActionItemId'),
             ('Audit_Trail_Master', 'Old_Value', 'Audit_Trail_Maser_Id'), ('Audit_Trail_Master', 'New_Value', 'Audit_Trail_Maser_Id')) c (TableName, ColumnName, KeyColumn)
JOIN sys.columns sc ON sc.object_id = OBJECT_ID('dbo.' + c.TableName) AND sc.name = c.ColumnName
JOIN sys.types t ON t.user_type_id = sc.user_type_id;

DECLARE @i INT;
DECLARE @n INT = (SELECT COUNT(*) FROM #U31Cols);
DECLARE @Table SYSNAME, @Column SYSNAME, @Key SYSNAME, @Type SYSNAME, @Nullable BIT, @Collation SYSNAME;
DECLARE @Sql NVARCHAR(MAX);
DECLARE @Changed INT = 0;
DECLARE @StatsDropped INT = 0;
DECLARE @ViewsRefreshed INT = 0;
DECLARE @Checked INT;
DECLARE @Differences INT;
DECLARE @Message NVARCHAR(2048);
DECLARE @View NVARCHAR(300);
DECLARE @Views TABLE (Seq INT IDENTITY(1,1), ViewName NVARCHAR(300));
DECLARE @Stats TABLE (Seq INT IDENTITY(1,1), Stmt NVARCHAR(600));

BEGIN TRY
    BEGIN TRANSACTION;

    -- Nobody may change these tables between the two hashes
    SELECT @Checked = COUNT(*) FROM dbo.Agenda WITH (TABLOCKX, HOLDLOCK);
    SELECT @Checked = COUNT(*) FROM dbo.Minutes WITH (TABLOCKX, HOLDLOCK);
    SELECT @Checked = COUNT(*) FROM dbo.Action_Item WITH (TABLOCKX, HOLDLOCK);
    SELECT @Checked = COUNT(*) FROM dbo.Audit_Trail_Master WITH (TABLOCKX, HOLDLOCK);

    -- 1. The hash of every value as NVARCHAR, before
    SET @i = 1;
    WHILE (@i <= @n)
    BEGIN
        SELECT @Table = TableName, @Column = ColumnName, @Key = KeyColumn FROM #U31Cols WHERE Seq = @i;
        SET @Sql = N'INSERT INTO #U31Before (TableName, ColumnName, KeyId, ValueHash, Chars) SELECT N''' + @Table + N''', N''' + @Column + N''', '
                 + QUOTENAME(@Key) + N', HASHBYTES(''SHA2_256'', CAST(' + QUOTENAME(@Column) + N' AS NVARCHAR(MAX))), '
                 + N'DATALENGTH(CAST(' + QUOTENAME(@Column) + N' AS NVARCHAR(MAX))) / 2 FROM dbo.' + QUOTENAME(@Table) + N';';
        EXEC sp_executesql @Sql;
        SET @i = @i + 1;
    END

    -- 2. Statistics SQL Server created by itself on a column to change (it creates them again when needed)
    INSERT INTO @Stats (Stmt)
    SELECT N'DROP STATISTICS dbo.' + QUOTENAME(OBJECT_NAME(s.object_id)) + N'.' + QUOTENAME(s.name) + N';'
    FROM sys.stats s
    WHERE s.auto_created = 1
      AND EXISTS (SELECT 1 FROM sys.stats_columns stc
                  JOIN sys.columns c ON c.object_id = stc.object_id AND c.column_id = stc.column_id
                  JOIN #U31Cols u ON OBJECT_ID('dbo.' + u.TableName) = c.object_id AND u.ColumnName = c.name AND u.TypeName = 'varchar'
                  WHERE stc.object_id = s.object_id AND stc.stats_id = s.stats_id);
    SET @i = 1;
    WHILE (@i <= (SELECT COUNT(*) FROM @Stats))
    BEGIN
        SELECT @Sql = Stmt FROM @Stats WHERE Seq = (SELECT MIN(Seq) FROM @Stats) + @i - 1;
        EXEC sp_executesql @Sql;
        SET @StatsDropped = @StatsDropped + 1;
        SET @i = @i + 1;
    END

    -- 3. The columns still VARCHAR(MAX) become NVARCHAR(MAX), same collation, same NULL / NOT NULL
    SET @i = 1;
    WHILE (@i <= @n)
    BEGIN
        SELECT @Table = TableName, @Column = ColumnName, @Type = TypeName, @Nullable = IsNullable, @Collation = CollationName
        FROM #U31Cols WHERE Seq = @i;
        IF (@Type = 'varchar')
        BEGIN
            SET @Sql = N'ALTER TABLE dbo.' + QUOTENAME(@Table) + N' ALTER COLUMN ' + QUOTENAME(@Column) + N' NVARCHAR(MAX)'
                     + ISNULL(N' COLLATE ' + @Collation, N'') + CASE WHEN @Nullable = 1 THEN N' NULL;' ELSE N' NOT NULL;' END;
            EXEC sp_executesql @Sql;
            SET @Changed = @Changed + 1;
        END
        SET @i = @i + 1;
    END

    -- 4. The hash of every stored value, after
    SET @i = 1;
    WHILE (@i <= @n)
    BEGIN
        SELECT @Table = TableName, @Column = ColumnName, @Key = KeyColumn FROM #U31Cols WHERE Seq = @i;
        SET @Sql = N'INSERT INTO #U31After (TableName, ColumnName, KeyId, ValueHash, Chars) SELECT N''' + @Table + N''', N''' + @Column + N''', '
                 + QUOTENAME(@Key) + N', HASHBYTES(''SHA2_256'', ' + QUOTENAME(@Column) + N'), '
                 + N'DATALENGTH(' + QUOTENAME(@Column) + N') / 2 FROM dbo.' + QUOTENAME(@Table) + N';';
        EXEC sp_executesql @Sql;
        SET @i = @i + 1;
    END

    -- 5. Before and after must be the same rows with the same values (duplicate keys counted, not merged)
    SET @Differences =
        (SELECT COUNT(*) FROM (SELECT TableName, ColumnName, KeyId, ValueHash, Chars, COUNT(*) AS Cnt FROM #U31Before
                               GROUP BY TableName, ColumnName, KeyId, ValueHash, Chars
                               EXCEPT
                               SELECT TableName, ColumnName, KeyId, ValueHash, Chars, COUNT(*) FROM #U31After
                               GROUP BY TableName, ColumnName, KeyId, ValueHash, Chars) d)
      + (SELECT COUNT(*) FROM (SELECT TableName, ColumnName, KeyId, ValueHash, Chars, COUNT(*) AS Cnt FROM #U31After
                               GROUP BY TableName, ColumnName, KeyId, ValueHash, Chars
                               EXCEPT
                               SELECT TableName, ColumnName, KeyId, ValueHash, Chars, COUNT(*) FROM #U31Before
                               GROUP BY TableName, ColumnName, KeyId, ValueHash, Chars) d);
    SET @Checked = (SELECT COUNT(*) FROM #U31Before);

    IF (@Differences <> 0 OR @Checked <> (SELECT COUNT(*) FROM #U31After))
        RAISERROR('The values after the change differ from the values before (%d differences).', 16, 1, @Differences);

    -- 6. Refresh every view that reads one of the four tables (the four known ones included)
    INSERT INTO @Views (ViewName)
    SELECT DISTINCT QUOTENAME(OBJECT_SCHEMA_NAME(v.object_id)) + N'.' + QUOTENAME(v.name)
    FROM sys.views v
    JOIN sys.sql_expression_dependencies d ON d.referencing_id = v.object_id
    WHERE d.referenced_id IN (OBJECT_ID('dbo.Agenda'), OBJECT_ID('dbo.Minutes'), OBJECT_ID('dbo.Action_Item'), OBJECT_ID('dbo.Audit_Trail_Master'))
       OR v.object_id IN (OBJECT_ID('dbo.View_Agenda'), OBJECT_ID('dbo.View_Minute'), OBJECT_ID('dbo.View_Action_Item'), OBJECT_ID('dbo.View_Action_Item_Users'));
    SET @i = 1;
    WHILE (@i <= (SELECT COUNT(*) FROM @Views))
    BEGIN
        SELECT @View = ViewName FROM @Views WHERE Seq = (SELECT MIN(Seq) FROM @Views) + @i - 1;
        EXEC sp_refreshview @View;
        SET @ViewsRefreshed = @ViewsRefreshed + 1;
        SET @i = @i + 1;
    END

    COMMIT TRANSACTION;

    PRINT 'Columns changed to NVARCHAR(MAX): ' + CAST(@Changed AS VARCHAR(12)) + ' (UnicodeText-Step31). Values checked: '
        + CAST(@Checked AS VARCHAR(12)) + ', all unchanged. Statistics re-made later by SQL Server: ' + CAST(@StatsDropped AS VARCHAR(12))
        + '. Views refreshed: ' + CAST(@ViewsRefreshed AS VARCHAR(12)) + '.';
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    SET @Message = 'Step 31 stopped and changed nothing: ' + ERROR_MESSAGE();
    RAISERROR('%s', 16, 1, @Message);
    SET NOEXEC ON;
END CATCH

IF (OBJECT_ID('tempdb..#U31Cols') IS NOT NULL)
    DROP TABLE #U31Cols;
IF (OBJECT_ID('tempdb..#U31Before') IS NOT NULL)
    DROP TABLE #U31Before;
IF (OBJECT_ID('tempdb..#U31After') IS NOT NULL)
    DROP TABLE #U31After;
GO

SET XACT_ABORT OFF;
GO


-------------------------------------------------------------------------------
-- The two agenda procedures
-------------------------------------------------------------------------------

-- Agenda - add / edit by a user, refused once the agenda is finalized (MeetingLocks-Step16).
-- A new item is refused when the creator's manager is set but inactive (Reason 11); no manager
-- (NULL) was unchanged until step 20 (see below). The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- A new item waits for the manager (AC) only when the manager is active and a Manager; otherwise it goes
-- straight to the Controllers (AMA, manager fields empty) and the active Controllers get the alert;
-- refused when no Controller is active (Reason 15) (AgendaRouting-Step20)
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX); @FilePath
-- VARCHAR(255)); a change of the Proposed Resolution is audited as 'ProposedResolution' (was 'ShortText')
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgenda]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText NVARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText NVARCHAR(MAX),
@AgendaTextPath NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@FilePath NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
@CurrentStatus VARCHAR(50),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@SubjectNo INT,
@ActingUserId INT)
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @agenda_id INT
	DECLARE @Mgr_Id INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @SubjectTypeName VARCHAR(50)
	DECLARE @SubjectTypeNameOld VARCHAR(50)
	DECLARE @SubjectTypeIdOld INT
	DECLARE @ShortTextOld NVARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld NVARCHAR(MAX)
	DECLARE @AgendaTextPathOld NVARCHAR(MAX)
	DECLARE @ProposedResolutionOld NVARCHAR(MAX)
	DECLARE @MinutesId INT
	DECLARE @NextAgendaNo AS VARCHAR(50);
	DECLARE @Prefix1 AS VARCHAR(50);
	DECLARE @Prefix2 AS VARCHAR(50);
	DECLARE @Prefix AS VARCHAR(50);
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @Locked INT;
	DECLARE @Route CHAR(1);
	DECLARE @ManagerName NVARCHAR(200);
	DECLARE @ActiveControllers INT;
	DECLARE @StatusCode VARCHAR(10);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaSave;

		-- An edit stays on the meeting of the existing row
		IF (@Code = 'Update')
			SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 0);

		-- The new item waits for the creator's manager (AC): refused while that manager is inactive,
		-- since nobody else can approve it on the Dashboard (UserStatus2b-Step17).
		-- The creator's route (AgendaRouting-Step20): M the manager step (AC); C straight to the Controllers
		-- (AMA): no manager, or the manager is a Controller or has another role; I refused while the manager
		-- is inactive (Reason 11). C with no active Controller is refused (Reason 15): nobody could approve it.
		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SELECT @Route = Route, @ManagerName = ManagerName, @ActiveControllers = ActiveControllers
			FROM dbo.fn_AgendaRoute(@CreatedBy);

			IF (@Route = 'I')
			BEGIN
				SET @Reason = 11;
				SET @Detail = ISNULL(@ManagerName, '');
			END
			ELSE IF (@Route = 'C' AND @ActiveControllers = 0)
				SET @Reason = 15;

			SET @StatusCode = CASE WHEN @Route = 'C' THEN 'AMA' ELSE 'AC' END;
		END

		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SET @Prefix1 = (SELECT CommitteeCode FROM Committee WHERE CommitteeId = @CommitteeId)
			SET @Prefix2 = (SELECT MeetingNo FROM Meeting WHERE MeetingId = @MeetingId)
			SET @Prefix = @Prefix1 + '-' + @Prefix2 + '-';

			SET @NextAgendaNo = (SELECT MAX(AgendaNo) FROM Agenda
						WHERE MeetingId = @MeetingId);

			SET @AgendaNo = SUBSTRING(ISNULL(@NextAgendaNo,0),11,13);
			SET @AgendaNo = @AgendaNo + 1;

			IF (@AgendaNo <= 0)
			BEGIN
				SET @NextAgendaNo = @Prefix + '001';
			END
			IF (@AgendaNo >= 1 AND @AgendaNo <= 9)
			BEGIN
				SET @NextAgendaNo = @Prefix + '00' + CONVERT(VARCHAR(50),@AgendaNo);
			END
			IF (@AgendaNo >= 10 AND @AgendaNo <= 99)
			BEGIN
				SET @NextAgendaNo = @Prefix + '0' + CONVERT(VARCHAR(50),@AgendaNo);
			END

			SET @AgendaNo = @NextAgendaNo;

			INSERT INTO Agenda
			(AgendaNo, CommitteeId, MeetingId, DepartmentId,
			SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath,
			AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
			VALUES
			(@AgendaNo, @CommitteeId, @MeetingId, @DepartmentId,
			@SubjectTypeId, @ShortText, @AgendaType, @AgendaText, @AgendaTextPath, @ProposedResolution, @FilePath,
			@StatusCode, @CurrentStatus, @CreatedOn, @CreatedBy);

			SET @agenda_id = @@identity

			SET @SourceType = 'Agenda'
			SET @DisplayText = 'Agenda (' + @AgendaNo + ')'

			INSERT INTO Alert_Master
			(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
			VALUES
			(@SourceType, @DepartmentId, @agenda_id, @DisplayText, @StatusCode, 3, @CommitteeId, @CreatedOn, @CreatedBy)

			SET @alert_id = @@identity

			SET @Mgr_Id = (SELECT ManagerId FROM Users WHERE UserId = @CreatedBy)

			-- Route M: the Admins and the manager; route C: the Admins and the active Controllers (AgendaRouting-Step20)
			IF (@Route = 'C')
				INSERT INTO Alert_User_Map
				(AlertId, [UserId], ReadStatus, StatusId)
				(SELECT @alert_id, u.[UserId],0,1 FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
				 WHERE r.RoleCode IN ('admin', 'controller') AND u.AccountStatus = 1 AND u.IsSystem = 0);
			ELSE
				INSERT INTO Alert_User_Map
				(AlertId, [UserId], ReadStatus, StatusId)
				(SELECT @alert_id, [UserId],0,1 FROM Users WHERE (RoleId = 1 OR UserId = @Mgr_Id) AND AccountStatus = 1 AND IsSystem = 0);

			SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);

			INSERT INTO [Audit_Trail_Master]
	           ([Audit_Type], [Audit_Table], [Key_Field], [Key_Value], [Field_Name],
				[Old_Value], [New_Value], [Update_By], [Update_On])
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', '', @SubjectTypeName, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', '', @ShortText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', '', @AgendaType, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', '', @AgendaText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', '', @AgendaTextPath, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', '', @ProposedResolution, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'FilePath', '', @FilePath, @UpdatedBy, GETDATE();

			SET @Result = 1;
		END

		IF (@Reason = 0 AND @Code = 'Update')
		BEGIN
			SET @SubjectTypeIdOld = (SELECT SubjectTypeId FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTypeOld = (SELECT AgendaType FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextOld = (SELECT AgendaText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextPathOld = (SELECT AgendaTextPath FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ProposedResolutionOld = (SELECT ProposedResolution FROM Agenda WHERE AgendaId = @AgendaId);

			UPDATE Agenda SET
			SubjectTypeId = @SubjectTypeId,
			ShortText = @ShortText,
			AgendaType = @AgendaType,
			AgendaText = @AgendaText,
			AgendaTextPath = @AgendaTextPath,
			ProposedResolution = @ProposedResolution,
			FilePath = @FilePath,
			MgrComments = @MgrComments,
			ControllerComments = @ControllerComments,
			CurrentStatus = @CurrentStatus,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy,
			SubjectNo = @SubjectNo
			WHERE
			AgendaId = @AgendaId;

			SET @MinutesId = 0;
			SET @MinutesId = (SELECT MinutesId FROM View_Minute WHERE AgendaId = @AgendaId);

			UPDATE Minutes SET
			ActualResolution = @ProposedResolution
			WHERE MinutesId = @MinutesId;

			IF (@SubjectTypeIdOld != @SubjectTypeId)
			BEGIN
				SET @SubjectTypeNameOld = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeIdOld);
				SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', @SubjectTypeNameOld, @SubjectTypeName, @UpdatedBy, GETDATE());
			END
			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTypeOld != @AgendaType)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', @AgendaTypeOld, @AgendaType, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextOld != @AgendaText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', @AgendaTextOld, @AgendaText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextPathOld != @AgendaTextPath)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', @AgendaTextPathOld, @AgendaTextPath, @UpdatedBy, GETDATE());
			END
			IF (@ProposedResolutionOld != @ProposedResolution)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
			END

			SET @Result = 1;
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION AgendaSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO


-- Agenda - manager / controller approve or reject; refused once the agenda is finalized,
-- for every role: no Minutes row would be created for it (MeetingLocks-Step16). New alert rows go to
-- active users only; an inactive creator's saved row is left as it is (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account; the system account cannot
-- approve or reject (Reason 12) (SystemAccount3-Step18)
-- Who may act at which stage (AgendaRouting-Step20): a Manager approves or rejects at AC an item routed
-- to them (or of whom they are the creator's manager); a Controller approves at AMA and rejects at AC or
-- AMA; anything else is refused (Reason 14, ReasonDetail the status name). An inactive or unknown acting
-- user is refused (Reason 8). A Controller may approve an item they created.
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX))
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateAgendaByAgendaId]
@AgendaId INT,
@ShortText NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
@ControllerApprovedStatus varchar(50),
@MgrApprovedStatus varchar(50),
@UpdatedBy INT
AS
	DECLARE @AlertId INT
	DECLARE @User_Id INT
	DECLARE @MgrCommentsOld NVARCHAR(MAX)
	DECLARE @ControllerCommentsOld NVARCHAR(MAX)
	DECLARE @AgendaNo VARCHAR(50)
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @AgendaStatus VARCHAR(50);
	DECLARE @ActingRole VARCHAR(50);
	DECLARE @StatusCode VARCHAR(50);
	DECLARE @StatusName VARCHAR(100);
	DECLARE @CreatorManagerId INT;
	DECLARE @MgrAction INT;
	DECLARE @CtlAction INT;
	DECLARE @Allowed INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaApprove;

		SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);

		SELECT @AgendaStatus = ISNULL(AgendaStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		-- The protected system account takes no part in the workflow (SystemAccount3-Step18)
		IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UpdatedBy AND IsSystem = 1)
			SET @Reason = 12;
		-- Acting user missing or inactive (AgendaRouting-Step20)
		ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @UpdatedBy AND AccountStatus = 1)
			SET @Reason = 8;
		ELSE IF (@AgendaStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@AgendaStatus <> 'Open')
		BEGIN
			SET @Reason = 5;
			SET @Detail = 'Finalized';
		END
		ELSE
		BEGIN
			-- Who may act at which stage (AgendaRouting-Step20)
			SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @UpdatedBy);

			SELECT @StatusCode = a.AgendaStatusCode, @CreatorManagerId = c.ManagerId,
			       @StatusName = ISNULL(st.AgendaStatusName, ISNULL(a.AgendaStatusCode, ''))
			FROM Agenda a
			LEFT JOIN Users c ON c.UserId = a.CreatedBy
			LEFT JOIN Agenda_Status st ON st.AgendaStatusCode = a.AgendaStatusCode
			WHERE a.AgendaId = @AgendaId;

			SET @MgrAction = CASE WHEN ISNULL(@MgrApprovedStatus, '') IN ('Approved', 'Rejected') THEN 1 ELSE 0 END;
			SET @CtlAction = CASE WHEN ISNULL(@ControllerApprovedStatus, '') IN ('Approved', 'Rejected') THEN 1 ELSE 0 END;

			-- Allowed only when a rule says so: a NULL anywhere counts as not allowed
			SET @Allowed = CASE
				WHEN @MgrAction = 1 AND @CtlAction = 0 AND ISNULL(@ActingRole, '') = 'manager' AND ISNULL(@StatusCode, '') = 'AC'
				     AND (@UpdatedBy = ISNULL(@CreatorManagerId, 0)
				          OR EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
				                     WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgendaId AND m.UserId = @UpdatedBy))
				THEN 1
				WHEN @CtlAction = 1 AND @MgrAction = 0 AND ISNULL(@ActingRole, '') = 'controller'
				     AND (ISNULL(@StatusCode, '') = 'AMA'
				          OR (ISNULL(@StatusCode, '') = 'AC' AND @ControllerApprovedStatus = 'Rejected'))
				THEN 1
				ELSE 0 END;

			IF (@Allowed = 0)
			BEGIN
				SET @Reason = 14;
				SET @Detail = ISNULL(@StatusName, '');
			END
		END

		IF (@Reason = 0)
		BEGIN
			SET @AgendaNo = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgendaId);

			IF @MgrApprovedStatus = 'Rejected'
			BEGIN
				UPDATE Agenda SET MgrComments = @MgrComments, MgrApprovedStatus = @MgrApprovedStatus,
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				UPDATE Alert_Master SET AlertTypeCode = 'AMR' WHERE AlertId = @AlertId;
				UPDATE Agenda SET AgendaStatusCode = 'AMR' WHERE AgendaId = @AgendaId;
				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;

				INSERT INTO Alert_User_Map
					(AlertId, [UserId], ReadStatus, StatusId)
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1 AND IsSystem = 0);

				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'MgrComments', '', @MgrComments, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'MgrApprovedStatus', '', @MgrApprovedStatus, @UpdatedBy, GETDATE();
			END

			IF @MgrApprovedStatus = 'Approved'
			BEGIN
				UPDATE Agenda SET MgrComments = @MgrComments, MgrApprovedStatus = @MgrApprovedStatus,
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				UPDATE Alert_Master SET AlertTypeCode = 'AMA' WHERE AlertId = @AlertId;
				UPDATE Agenda SET AgendaStatusCode = 'AMA' WHERE AgendaId = @AgendaId;
				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;

				INSERT INTO Alert_User_Map
					(AlertId, [UserId], ReadStatus, StatusId)
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1 AND IsSystem = 0);

				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'MgrComments', '', @MgrComments, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'MgrApprovedStatus', '', @MgrApprovedStatus, @UpdatedBy, GETDATE();
			END

			IF @ControllerApprovedStatus = 'Approved' OR @ControllerApprovedStatus = 'Rejected'
			BEGIN
				UPDATE Agenda SET
					ShortText = @ShortText, ProposedResolution = @ProposedResolution,
					ControllerComments = @ControllerComments, ControllerApprovedStatus = @ControllerApprovedStatus,
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				IF @ControllerApprovedStatus = 'Approved'
				BEGIN
					UPDATE Alert_Master SET AlertTypeCode = 'ACA' WHERE AlertId = @AlertId;
					UPDATE Agenda SET AgendaStatusCode = 'ACA' WHERE AgendaId = @AgendaId;
				END
				IF @ControllerApprovedStatus = 'Rejected'
				BEGIN
					UPDATE Alert_Master SET AlertTypeCode = 'ACR' WHERE AlertId = @AlertId;
					UPDATE Agenda SET AgendaStatusCode = 'ACR' WHERE AgendaId = @AgendaId;
				END

				-- The creator's row is renewed only while the creator is active (UserStatus2b-Step17)
				IF EXISTS (SELECT 1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1 AND IsSystem = 0)
				BEGIN
					DELETE FROM Alert_User_Map WHERE UserId = @User_Id AND AlertId = @AlertId;

					INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
						VALUES (@AlertId, @User_Id, 0, 1);
				END

				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;
				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ControllerApprovedStatus', '', @ControllerApprovedStatus, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT 'UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ControllerComments', '', @ControllerComments, @UpdatedBy, GETDATE();
			END

			SET @Result = 1;
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION AgendaApprove;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO


-- Agenda - add / edit by a manager, refused once the agenda is finalized (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX); @FilePath
-- VARCHAR(255)); a change of the Proposed Resolution is audited as 'ProposedResolution' (was 'ShortText')
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgendaByManager]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText NVARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText NVARCHAR(MAX),
@AgendaTextPath NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@FilePath NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
@CurrentStatus VARCHAR(50),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@SubjectNo INT,
@ActingUserId INT)
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @agenda_id INT
	DECLARE @Mgr_Id INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @SubNo INT
	DECLARE @SubjectTypeName VARCHAR(50)
	DECLARE @SubjectTypeNameOld VARCHAR(50)
	DECLARE @SubjectTypeIdOld INT
	DECLARE @ShortTextOld NVARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld NVARCHAR(MAX)
	DECLARE @AgendaTextPathOld NVARCHAR(MAX)
	DECLARE @ProposedResolutionOld NVARCHAR(MAX)
	DECLARE @MinutesId INT
	DECLARE @NextAgendaNo AS VARCHAR(50);
	DECLARE @Prefix1 AS VARCHAR(50);
	DECLARE @Prefix2 AS VARCHAR(50);
	DECLARE @Prefix AS VARCHAR(50);
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @Locked INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaSaveManager;

		IF (@Code = 'Update')
			SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 0);

		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SET @Prefix1 = (SELECT CommitteeCode FROM Committee WHERE CommitteeId = @CommitteeId)
			SET @Prefix2 = (SELECT MeetingNo FROM Meeting WHERE MeetingId = @MeetingId)
			SET @Prefix = @Prefix1 + '-' + @Prefix2 + '-';

			SET @NextAgendaNo = (SELECT MAX(AgendaNo) FROM Agenda
						WHERE MeetingId = @MeetingId);

			SET @AgendaNo = SUBSTRING(ISNULL(@NextAgendaNo,0),11,13);
			SET @AgendaNo = @AgendaNo + 1;

			IF (@AgendaNo <= 0)
			BEGIN
				SET @NextAgendaNo = @Prefix + '001';
			END
			IF (@AgendaNo >= 1 AND @AgendaNo <= 9)
			BEGIN
				SET @NextAgendaNo = @Prefix + '00' + CONVERT(VARCHAR(50),@AgendaNo);
			END
			IF (@AgendaNo >= 10 AND @AgendaNo <= 99)
			BEGIN
				SET @NextAgendaNo = @Prefix + '0' + CONVERT(VARCHAR(50),@AgendaNo);
			END

			SET @AgendaNo = @NextAgendaNo;

			INSERT INTO Agenda
			(AgendaNo, CommitteeId, MeetingId, DepartmentId,
			SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath,
			AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, MgrComments, MgrApprovedStatus)
			VALUES
			(@AgendaNo, @CommitteeId, @MeetingId, @DepartmentId,
			@SubjectTypeId, @ShortText, @AgendaType, @AgendaText, @AgendaTextPath, @ProposedResolution, @FilePath,
			'AMA', @CurrentStatus, @CreatedOn, @CreatedBy, @MgrComments, 'Approved');

			SET @agenda_id = @@identity

			SET @SourceType = 'Agenda'
			SET @DisplayText = 'Agenda (' + @AgendaNo + ')'

			INSERT INTO Alert_Master
			(SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
			VALUES
			(@SourceType, @agenda_id, @DepartmentId, @DisplayText, 'AMA', 3, @CommitteeId, @CreatedOn, @CreatedBy)

			SET @alert_id = @@identity

			INSERT INTO Alert_User_Map
			(AlertId, [UserId], ReadStatus, StatusId)
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE (RoleId = 1 OR RoleId = 2 OR
				UserId IN (SELECT Users.UserId FROM Users WHERE Users.DepartmentId = @DepartmentId))
				AND AccountStatus = 1 AND IsSystem = 0);

			SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);

			INSERT INTO [Audit_Trail_Master]
	           ([Audit_Type], [Audit_Table], [Key_Field], [Key_Value], [Field_Name],
				[Old_Value], [New_Value], [Update_By], [Update_On])
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', '', @SubjectTypeName, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', '', @ShortText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', '', @AgendaType, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', '', @AgendaText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', '', @AgendaTextPath, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', '', @ProposedResolution, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'FilePath', '', @FilePath, @UpdatedBy, GETDATE();

			SET @Result = 1;
		END

		IF (@Reason = 0 AND @Code = 'Update')
		BEGIN
			SET @SubjectTypeIdOld = (SELECT SubjectTypeId FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTypeOld = (SELECT AgendaType FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextOld = (SELECT AgendaText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextPathOld = (SELECT AgendaTextPath FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ProposedResolutionOld = (SELECT ProposedResolution FROM Agenda WHERE AgendaId = @AgendaId);

			UPDATE Agenda SET
			SubjectTypeId = @SubjectTypeId,
			ShortText = @ShortText,
			AgendaType = @AgendaType,
			AgendaText = @AgendaText,
			AgendaTextPath = @AgendaTextPath,
			ProposedResolution = @ProposedResolution,
			FilePath = @FilePath,
			MgrComments = @MgrComments,
			ControllerComments = @ControllerComments,
			CurrentStatus = @CurrentStatus,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy,
			SubjectNo = @SubjectNo
			WHERE
			AgendaId = @AgendaId;

			SET @MinutesId = 0;
			SET @MinutesId = (SELECT MinutesId FROM View_Minute WHERE AgendaId = @AgendaId);

			UPDATE Minutes SET
			ActualResolution = @ProposedResolution
			WHERE MinutesId = @MinutesId;

			IF (@SubjectTypeIdOld != @SubjectTypeId)
			BEGIN
				SET @SubjectTypeNameOld = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeIdOld);
				SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', @SubjectTypeNameOld, @SubjectTypeName, @UpdatedBy, GETDATE());
			END
			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTypeOld != @AgendaType)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', @AgendaTypeOld, @AgendaType, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextOld != @AgendaText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', @AgendaTextOld, @AgendaText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextPathOld != @AgendaTextPath)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', @AgendaTextPathOld, @AgendaTextPath, @UpdatedBy, GETDATE());
			END
			IF (@ProposedResolutionOld != @ProposedResolution)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
			END

			SET @Result = 1;
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION AgendaSaveManager;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO


-- Agenda - add / edit by the Controller; after the agenda is finalized only with the Admin option on (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX); @FilePath
-- VARCHAR(255)); a change of the Proposed Resolution is audited as 'ProposedResolution' (was 'ShortText')
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgendaByController]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText NVARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText NVARCHAR(MAX),
@AgendaTextPath NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@FilePath NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
@CurrentStatus VARCHAR(50),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@SubjectNo INT,
@ActingUserId INT)
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @agenda_id INT
	DECLARE @Mgr_Id INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @SubNo INT
	DECLARE @SubjectTypeName VARCHAR(50)
	DECLARE @SubjectTypeNameOld VARCHAR(50)
	DECLARE @SubjectTypeIdOld INT
	DECLARE @ShortTextOld NVARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld NVARCHAR(MAX)
	DECLARE @AgendaTextPathOld NVARCHAR(MAX)
	DECLARE @ProposedResolutionOld NVARCHAR(MAX)
	DECLARE @AgendaStatus VARCHAR(50)
	DECLARE @MinutesId INT
	DECLARE @NextAgendaNo AS VARCHAR(50);
	DECLARE @Prefix1 AS VARCHAR(50);
	DECLARE @Prefix2 AS VARCHAR(50);
	DECLARE @Prefix AS VARCHAR(50);
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @Locked INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaSaveController;

		IF (@Code = 'Update')
			SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 1);

		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SET @Prefix1 = (SELECT CommitteeCode FROM Committee WHERE CommitteeId = @CommitteeId)
			SET @Prefix2 = (SELECT MeetingNo FROM Meeting WHERE MeetingId = @MeetingId)
			SET @Prefix = @Prefix1 + '-' + @Prefix2 + '-';

			SET @NextAgendaNo = (SELECT MAX(AgendaNo) FROM Agenda
						WHERE MeetingId = @MeetingId);

			SET @AgendaNo = SUBSTRING(ISNULL(@NextAgendaNo,0),11,13);
			SET @AgendaNo = @AgendaNo + 1;

			IF (@AgendaNo <= 0)
			BEGIN
				SET @NextAgendaNo = @Prefix + '001';
			END
			IF (@AgendaNo >= 1 AND @AgendaNo <= 9)
			BEGIN
				SET @NextAgendaNo = @Prefix + '00' + CONVERT(VARCHAR(50),@AgendaNo);
			END
			IF (@AgendaNo >= 10 AND @AgendaNo <= 99)
			BEGIN
				SET @NextAgendaNo = @Prefix + '0' + CONVERT(VARCHAR(50),@AgendaNo);
			END

			SET @AgendaNo = @NextAgendaNo;

			INSERT INTO Agenda
			(AgendaNo, CommitteeId, MeetingId, DepartmentId,
			SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath,
			AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, ControllerComments, ControllerApprovedStatus)
			VALUES
			(@AgendaNo, @CommitteeId, @MeetingId, @DepartmentId,
			@SubjectTypeId, @ShortText, @AgendaType, @AgendaText, @AgendaTextPath, @ProposedResolution, @FilePath,
			'ACA', @CurrentStatus, @CreatedOn, @CreatedBy, @ControllerComments, 'Approved');

			SET @agenda_id = @@identity

			SET @SourceType = 'Agenda'
			SET @DisplayText = 'Agenda (' + @AgendaNo + ')'

			INSERT INTO Alert_Master
			(SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
			VALUES
			(@SourceType, @agenda_id, @DepartmentId, @DisplayText, 'ACA', 3, @CommitteeId, @CreatedOn, @CreatedBy)

			SET @alert_id = @@identity

			INSERT INTO Alert_User_Map
			(AlertId, [UserId], ReadStatus, StatusId)
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE (RoleId = 1 OR
				UserId IN (SELECT Users.UserId FROM Users WHERE Users.DepartmentId = @DepartmentId))
				AND AccountStatus = 1 AND IsSystem = 0);

			SET @SubNo = (SELECT MAX(SubjectNo) FROM Agenda WHERE MeetingId = @MeetingId
								AND ControllerApprovedStatus = 'Approved');
			SET @SubNo = ISNULL(@SubNo,0);
			SET @SubNo = @SubNo + 1;

			UPDATE Agenda SET
			SubjectNo = @SubNo
			WHERE MeetingId = @MeetingId
			AND ControllerApprovedStatus = 'Approved'
			AND AgendaId = @agenda_id;

			-- An agenda added after the agenda was finalized gets its Minutes row here
			SET @AgendaStatus = (SELECT AgendaStatus FROM Meeting WHERE MeetingId = @MeetingId);

			IF (@AgendaStatus = 'Close')
			BEGIN
				INSERT INTO Minutes
				(
				AgendaId, DecisionTypeId, Directions, ActualResolution,
				CreatedOn, CreatedBy, UpdatedOn, UpdatedBy
				)
				VALUES
				(@agenda_id, 3, ' ', @ProposedResolution, GETDATE(), 1, GETDATE(), 1);
			END

			SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);

			INSERT INTO [Audit_Trail_Master]
	           ([Audit_Type], [Audit_Table], [Key_Field], [Key_Value], [Field_Name],
				[Old_Value], [New_Value], [Update_By], [Update_On])
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', '', @SubjectTypeName, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', '', @ShortText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', '', @AgendaType, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', '', @AgendaText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', '', @AgendaTextPath, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', '', @ProposedResolution, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'FilePath', '', @FilePath, @UpdatedBy, GETDATE();

			SET @Result = 1;
		END

		IF (@Reason = 0 AND @Code = 'Update')
		BEGIN
			SET @SubjectTypeIdOld = (SELECT SubjectTypeId FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTypeOld = (SELECT AgendaType FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextOld = (SELECT AgendaText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextPathOld = (SELECT AgendaTextPath FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ProposedResolutionOld = (SELECT ProposedResolution FROM Agenda WHERE AgendaId = @AgendaId);

			UPDATE Agenda SET
			DepartmentId = @DepartmentId,
			SubjectTypeId = @SubjectTypeId,
			ShortText = @ShortText,
			AgendaType = @AgendaType,
			AgendaText = @AgendaText,
			AgendaTextPath = @AgendaTextPath,
			ProposedResolution = @ProposedResolution,
			FilePath = @FilePath,
			MgrComments = @MgrComments,
			ControllerComments = @ControllerComments,
			CurrentStatus = @CurrentStatus,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy,
			SubjectNo = @SubjectNo
			WHERE
			AgendaId = @AgendaId;

			SET @MinutesId = 0;
			SET @MinutesId = (SELECT MinutesId FROM View_Minute WHERE AgendaId = @AgendaId);

			UPDATE Minutes SET
			ActualResolution = @ProposedResolution
			WHERE MinutesId = @MinutesId;

			IF (@SubjectTypeIdOld != @SubjectTypeId)
			BEGIN
				SET @SubjectTypeNameOld = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeIdOld);
				SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', @SubjectTypeNameOld, @SubjectTypeName, @UpdatedBy, GETDATE());
			END
			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTypeOld != @AgendaType)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', @AgendaTypeOld, @AgendaType, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextOld != @AgendaText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', @AgendaTextOld, @AgendaText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextPathOld != @AgendaTextPath)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', @AgendaTextPathOld, @AgendaTextPath, @UpdatedBy, GETDATE());
			END
			IF (@ProposedResolutionOld != @ProposedResolution)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
			END

			SET @Result = 1;
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION AgendaSaveController;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO


-- Agenda short text (edited on the minutes page) - refused once the minutes are confirmed (MeetingLocks-Step16)
-- WorkflowOrder-Step23: a meeting created after step 23 needs the agenda finalized (17) and attendance entered (18).
-- UnicodeText-Step31: @ShortText and @ShortTextOld are NVARCHAR(MAX) (were VARCHAR(MAX))
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateAgendaShortText]
@AgendaId INT,
@ShortText NVARCHAR(MAX),
@UpdatedBy INT
AS
	DECLARE @ShortTextOld NVARCHAR(MAX)
	DECLARE @AgendaNo VARCHAR(50)
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @MinutesStatus VARCHAR(50);
	DECLARE @WfNew INT;
	DECLARE @WfAgenda INT;
	DECLARE @WfAttendance INT;
	DECLARE @WfTotal INT;
	DECLARE @WfUpdated INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaShortText;

		SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		-- Workflow order (WorkflowOrder-Step23): the meeting's state; the order applies only to a meeting
		-- created after step 23 was installed (fn_WorkflowState.IsNew)
		SELECT @WfNew = IsNew, @WfAgenda = AgendaFinalized, @WfAttendance = AttendanceRecorded,
		       @WfTotal = MinutesTotal, @WfUpdated = MinutesUpdated
		FROM dbo.fn_WorkflowState(@LockMeetingId);

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus = 'C')
			SET @Reason = 7;
		-- WorkflowOrder-Step23: a meeting created after step 23 updates its minutes only once the agenda
		-- is finalized and the attendance is entered (chairman and at least one member present)
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAgenda, 0) = 0)
			SET @Reason = 17;
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAttendance, 0) = 0)
			SET @Reason = 18;
		ELSE
		BEGIN
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaNo = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgendaId);

			UPDATE Agenda SET
			ShortText = @ShortText
			WHERE
			AgendaId = @AgendaId;

			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
			END

			SET @Result = 1;
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION AgendaShortText;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO


-- Minutes update - refused once the minutes are confirmed (MeetingLocks-Step16). The new action item is
-- mapped to the agenda creator only if that user still exists (FK #5, step 6). An inactive creator gets
-- no new row and the item goes to the active Controllers instead (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- WorkflowOrder-Step23: a meeting created after step 23 needs the agenda finalized (17) and attendance entered (18).
-- UnicodeText-Step31: @Directions, @ActualResolution and @ShortText are NVARCHAR(MAX) (were TEXT)
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateMinutes]
@Code VARCHAR(50),
@MinutesId INT,
@DecisionTypeId INT,
@Directions NVARCHAR(MAX),
@ActualResolution NVARCHAR(MAX),
@ShortText NVARCHAR(MAX),
@CreatedBy INT,
@UpdatedBy INT
AS
	DECLARE @ActionItemId INT;
	DECLARE @CountActionItemId INT;
	DECLARE @AgendaId INT;
	DECLARE @UserId INT;
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @MinutesStatus VARCHAR(50);
	DECLARE @WfNew INT;
	DECLARE @WfAgenda INT;
	DECLARE @WfAttendance INT;
	DECLARE @WfTotal INT;
	DECLARE @WfUpdated INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION MinutesUpdate;

		SET @LockMeetingId = (SELECT a.MeetingId FROM Minutes mi WITH (UPDLOCK, HOLDLOCK)
		                      JOIN Agenda a ON a.AgendaId = mi.AgendaId
		                      WHERE mi.MinutesId = @MinutesId);

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		-- Workflow order (WorkflowOrder-Step23): the meeting's state; the order applies only to a meeting
		-- created after step 23 was installed (fn_WorkflowState.IsNew)
		SELECT @WfNew = IsNew, @WfAgenda = AgendaFinalized, @WfAttendance = AttendanceRecorded,
		       @WfTotal = MinutesTotal, @WfUpdated = MinutesUpdated
		FROM dbo.fn_WorkflowState(@LockMeetingId);

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus = 'C')
			SET @Reason = 7;
		-- WorkflowOrder-Step23: a meeting created after step 23 updates its minutes only once the agenda
		-- is finalized and the attendance is entered (chairman and at least one member present)
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAgenda, 0) = 0)
			SET @Reason = 17;
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAttendance, 0) = 0)
			SET @Reason = 18;
		ELSE
		BEGIN
			IF (@Code = 'All')
			BEGIN
				UPDATE Minutes SET
				DecisionTypeId = @DecisionTypeId,
				StatusId = 1,
				UpdatedOn = GETDATE(),
				UpdatedBy = @UpdatedBy
				WHERE
				MinutesId = @MinutesId;

				SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);

				UPDATE Agenda SET ShortText = @ShortText WHERE AgendaId = @AgendaId;

				SET @Directions = (SELECT Directions FROM Minutes WHERE MinutesId = @MinutesId);

				IF (@DecisionTypeId != 1)
				BEGIN
					DELETE FROM Action_Item WHERE MinutesId = @MinutesId;
				END

				IF (@DecisionTypeId = 1)
				BEGIN
					SET @CountActionItemId = (SELECT COUNT(ActionItemId) FROM Action_Item WHERE MinutesId = @MinutesId);
					SET @ActionItemId = (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @MinutesId);

					IF (@CountActionItemId >= 1)
					BEGIN
						UPDATE [Action_Item] SET
						Directions = @Directions, UpdatedOn = GETDATE()
						WHERE ActionItemId = @ActionItemId;

						UPDATE ActionItem_User_Map SET
						ReadStatus = 1
						WHERE ActionItemId = @ActionItemId;
					END

					IF (@CountActionItemId <= 0)
					BEGIN
						INSERT INTO [Action_Item]
							([MinutesId],[Directions],[ActionText],[ActionStatus],[UpdatedOn],[UpdatedBy])
						VALUES
							(@MinutesId, @Directions, '','',GETDATE(),@UpdatedBy);

						SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);
						SET @UserId = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId);
						SET @ActionItemId = (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @MinutesId);

						-- FK #5: was INSERT ... VALUES (@ActionItemId, @UserId, 0, 1)
						INSERT INTO ActionItem_User_Map
							(ActionItemId, UserId, ReadStatus, StatusId)
						SELECT @ActionItemId, UserId, 0, 1
						FROM Users
						WHERE UserId = @UserId AND AccountStatus = 1 AND IsSystem = 0;

						-- Creator inactive: the active Controllers see the item (UserStatus2b-Step17).
						-- A creator who no longer exists is unchanged (no row, FK #5).
						IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UserId AND (AccountStatus <> 1 OR IsSystem = 1))
							INSERT INTO ActionItem_User_Map
								(ActionItemId, UserId, ReadStatus, StatusId)
							SELECT @ActionItemId, u.UserId, 0, 1
							FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
							WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0;
					END
				END
			END

			IF (@Code = 'Directions')
			BEGIN
				UPDATE Minutes SET
				Directions = @Directions, StatusId = 1, UpdatedOn = GETDATE(), UpdatedBy = @UpdatedBy
				WHERE MinutesId = @MinutesId;
			END

			IF (@Code = 'ActualResolution')
			BEGIN
				SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);

				UPDATE Minutes SET
				ActualResolution = @ActualResolution, StatusId = 1,	UpdatedOn = GETDATE(), 	UpdatedBy = @UpdatedBy
				WHERE MinutesId = @MinutesId;

				UPDATE Agenda SET ProposedResolution = @ActualResolution
				WHERE AgendaId = @AgendaId;
			END

			SET @Result = 1;
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION MinutesUpdate;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Action item - save the actual resolution (into the minute), the action text, or the complied / confirmed flags.
-- From the original database (no numbered script had it before step 31).
-- UnicodeText-Step31: @ActualResolution and @ActionText are NVARCHAR(MAX) (were TEXT); everything else unchanged
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateActionItem]
@Code varchar(50),
@ActionItemId INT,
@ActualResolution NVARCHAR(MAX),
@ActionText NVARCHAR(MAX),
@IsComplied int,
@IsConfirmed int
AS
    DECLARE @MinutesId INT
BEGIN

    IF (@Code = 'All')
    BEGIN
        UPDATE Action_Item SET
            IsComplied = @IsComplied,
            IsConfirmed = @IsConfirmed
            WHERE
            ActionItemId = @ActionItemId;

        IF (@IsConfirmed = 1)
        BEGIN
            UPDATE ActionItem_User_Map SET StatusId = 0
            WHERE ActionItemId = @ActionItemId;
        END

    END

    IF (@Code = 'ActualResolution')
    BEGIN

        SET @MinutesId = (SELECT MinutesId FROM Action_Item WHERE ActionItemId = @ActionItemId);

        UPDATE Minutes SET
            ActualResolution = @ActualResolution
            WHERE
            MinutesId = @MinutesId;
    END

    IF (@Code = 'ActionText')
    BEGIN
        UPDATE Action_Item SET
            ActionText = @ActionText
            WHERE
            ActionItemId = @ActionItemId;
    END


END
GO

-- What is installed now (read only)
DECLARE @Markers INT;
DECLARE @VarcharColumns INT;
DECLARE @NvarcharColumns INT;
DECLARE @OldParams INT;
DECLARE @NewParams INT;
DECLARE @OldViewColumns INT;

SELECT @Markers = COUNT(*)
FROM (VALUES ('spr_AddEditAgenda'), ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController'),
             ('spr_UpdateAgendaShortText'), ('spr_UpdateMinutes'), ('spr_UpdateActionItem')) o(Name)
WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UnicodeText-Step31%';

SELECT @VarcharColumns = SUM(CASE WHEN t.name = 'nvarchar' THEN 0 ELSE 1 END),
       @NvarcharColumns = SUM(CASE WHEN t.name = 'nvarchar' AND sc.max_length = -1 THEN 1 ELSE 0 END)
FROM sys.columns sc
JOIN sys.types t ON t.user_type_id = sc.user_type_id
WHERE (sc.object_id = OBJECT_ID('dbo.Agenda') AND sc.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments'))
   OR (sc.object_id = OBJECT_ID('dbo.Minutes') AND sc.name IN ('Directions', 'ActualResolution'))
   OR (sc.object_id = OBJECT_ID('dbo.Action_Item') AND sc.name IN ('Directions', 'ActionText'))
   OR (sc.object_id = OBJECT_ID('dbo.Audit_Trail_Master') AND sc.name IN ('Old_Value', 'New_Value'));

SELECT @OldParams = SUM(CASE WHEN t.name = 'nvarchar' AND p.max_length = -1 THEN 0 ELSE 1 END),
       @NewParams = SUM(CASE WHEN t.name = 'nvarchar' AND p.max_length = -1 THEN 1 ELSE 0 END)
FROM sys.parameters p
JOIN sys.types t ON t.user_type_id = p.user_type_id
WHERE p.object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'),
                      OBJECT_ID('dbo.spr_AddEditAgendaByController'), OBJECT_ID('dbo.spr_UpdateAgendaShortText'), OBJECT_ID('dbo.spr_UpdateMinutes'),
                      OBJECT_ID('dbo.spr_UpdateActionItem'))
  AND p.name IN ('@ShortText', '@AgendaText', '@AgendaTextPath', '@ProposedResolution', '@FilePath', '@MgrComments', '@ControllerComments',
                 '@Directions', '@ActualResolution', '@ActionText');

SELECT @OldViewColumns = COUNT(*)
FROM sys.columns sc
JOIN sys.types t ON t.user_type_id = sc.user_type_id
WHERE sc.object_id IN (OBJECT_ID('dbo.View_Agenda'), OBJECT_ID('dbo.View_Minute'), OBJECT_ID('dbo.View_Action_Item'), OBJECT_ID('dbo.View_Action_Item_Users'))
  AND sc.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments',
                  'Directions', 'ActualResolution', 'ActionText')
  AND t.name <> 'nvarchar';

IF (@Markers = 7 AND @VarcharColumns = 0 AND @NvarcharColumns = 13 AND @OldParams = 0 AND @NewParams = 31 AND @OldViewColumns = 0)
    PRINT 'Step 31 installed: 13 columns NVARCHAR(MAX), 31 procedure parameters NVARCHAR(MAX), the views refreshed, marker on the 7 procedures (UnicodeText-Step31).';
ELSE
    PRINT 'Step 31 NOT complete: markers ' + CAST(ISNULL(@Markers, 0) AS VARCHAR(4)) + ' of 7, NVARCHAR(MAX) columns '
        + CAST(ISNULL(@NvarcharColumns, 0) AS VARCHAR(4)) + ' of 13, NVARCHAR(MAX) parameters ' + CAST(ISNULL(@NewParams, 0) AS VARCHAR(4))
        + ' of 31, other parameters ' + CAST(ISNULL(@OldParams, 0) AS VARCHAR(4)) + ', VARCHAR view columns ' + CAST(ISNULL(@OldViewColumns, 0) AS VARCHAR(4))
        + '. See the messages above.';
GO

SET NOEXEC OFF;
GO
