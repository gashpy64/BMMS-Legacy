/* ============================================================================
   BMMS - Critical fix #5: Reset Database still works with the 21 user keys
   ----------------------------------------------------------------------------
   TEST DATABASE ONLY. This script EXECUTES spr_sys_ResetDatabase, the
   procedure that wipes every table and re-creates the default rows.

   It refuses to run in a database named exactly "BMMS". Run it only in the
   restored test copy (for example BMMS_bak1), after
   BMMS-Fix-UserDelete-Procedure.sql and BMMS-Add-ForeignKeys-Step5.sql.

   How it protects the test copy:
     * the reset runs inside a transaction that is ROLLED BACK, so all rows
       come back;
     * identity counters are not reliably covered by a rollback, so every
       table's counter is saved before the reset and reseeded afterwards.
   The last rows of the result grid confirm that row counts and identity
   counters are the same as before the test.

   What is checked while the database is in its reset state:
     * the procedure runs to completion with all keys in place
     * the 4 default users exist, admin is user 1, and the seeded manager link
       points at a real user
     * the seeded committees point at a real user
     * no user-id column covered by a key holds an unknown user
     * all 21 keys still exist and are trusted
     * a new user and a new committee can be added by user 1
     * the new, unused user can be deleted; admin (who has history) cannot

   Result: one grid, one row per check. Status should be PASS for every row.

   It has no USE line: select the TEST database in SSMS first.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase = 'BMMS' OR @CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This test runs spr_sys_ResetDatabase and is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_bak1). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#Counts') IS NOT NULL DROP TABLE #Counts;

-- Temporary tables, not table variables: the identity counters are put back
-- and checked in separate batches further down.
CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(120), Expected VARCHAR(50), Actual VARCHAR(250));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
CREATE TABLE #Counts (TableName SYSNAME, RowsBefore INT, RowsAfter INT NULL);

-- Checks made inside the transaction go into a table variable (it survives
-- the rollback) and are copied to #T afterwards.
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(120), Expected VARCHAR(50), Actual VARCHAR(250));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));   -- spr_DeleteUserByUserId returns Result, Reason, ReasonDetail

DECLARE @Now DATETIME = GETDATE();
DECLARE @Sql NVARCHAR(MAX);
DECLARE @TableName SYSNAME;
DECLARE @Rows INT;
DECLARE @NewUserId INT;
DECLARE @DepartmentId INT;
DECLARE @DesignationId INT;
DECLARE @RoleId INT;
DECLARE @Orphans INT;

DECLARE @KeyCols TABLE (TableName SYSNAME, ColumnName SYSNAME);

INSERT INTO @KeyCols (TableName, ColumnName)
SELECT OBJECT_NAME(fc.parent_object_id), COL_NAME(fc.parent_object_id, fc.parent_column_id)
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fc ON fc.constraint_object_id = fk.object_id
WHERE fk.referenced_object_id = OBJECT_ID('dbo.Users');

-------------------------------------------------------------------------------
-- Before: identity counters and row counts of every table
-------------------------------------------------------------------------------
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';

DECLARE TableCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.tables WHERE is_ms_shipped = 0 AND name <> 'sysdiagrams' ORDER BY name;

OPEN TableCursor;
FETCH NEXT FROM TableCursor INTO @TableName;

WHILE (@@FETCH_STATUS = 0)
BEGIN
    SET @Sql = N'SELECT @n = COUNT(*) FROM dbo.' + QUOTENAME(@TableName);
    EXEC sp_executesql @Sql, N'@n INT OUTPUT', @n = @Rows OUTPUT;
    INSERT INTO #Counts (TableName, RowsBefore) VALUES (@TableName, @Rows);
    FETCH NEXT FROM TableCursor INTO @TableName;
END

CLOSE TableCursor;
DEALLOCATE TableCursor;

-------------------------------------------------------------------------------
-- The reset, inside a transaction that is rolled back
-------------------------------------------------------------------------------
BEGIN TRANSACTION;

BEGIN TRY

    EXEC spr_sys_ResetDatabase;

    INSERT INTO @T VALUES ('spr_sys_ResetDatabase ran to completion', 'Yes', 'Yes');

    INSERT INTO @T SELECT 'Default users re-created', '4', CAST(COUNT(*) AS VARCHAR(12)) FROM Users;

    INSERT INTO @T
    SELECT 'User 1 is admin', 'admin', ISNULL((SELECT LoginName FROM Users WHERE UserId = 1), 'no user 1');

    INSERT INTO @T
    SELECT 'Seeded users: ManagerId points at a real user or is empty', '0', CAST(COUNT(*) AS VARCHAR(12))
    FROM Users u WHERE u.ManagerId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Users m WHERE m.UserId = u.ManagerId);

    INSERT INTO @T
    SELECT 'Seeded users: one has a manager', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Users WHERE ManagerId IS NOT NULL;

    INSERT INTO @T SELECT 'Seeded committees re-created', '2', CAST(COUNT(*) AS VARCHAR(12)) FROM Committee;

    -- Every column that has a key to Users: no value without a matching user.
    SET @Orphans = 0;

    DECLARE KeyCursor CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColumnName FROM @KeyCols;
    DECLARE @ColumnName SYSNAME;

    OPEN KeyCursor;
    FETCH NEXT FROM KeyCursor INTO @TableName, @ColumnName;

    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @Sql = N'SELECT @n = COUNT(*) FROM dbo.' + QUOTENAME(@TableName) + N' c WHERE c.' + QUOTENAME(@ColumnName)
                 + N' IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Users u WHERE u.UserId = c.' + QUOTENAME(@ColumnName) + N')';
        EXEC sp_executesql @Sql, N'@n INT OUTPUT', @n = @Rows OUTPUT;
        SET @Orphans = @Orphans + @Rows;
        FETCH NEXT FROM KeyCursor INTO @TableName, @ColumnName;
    END

    CLOSE KeyCursor;
    DEALLOCATE KeyCursor;

    INSERT INTO @T VALUES ('After reset: rows pointing at an unknown user (keyed columns)', '0', CAST(@Orphans AS VARCHAR(12)));

    INSERT INTO @T
    SELECT 'Keys to Users still present and trusted', '23',
           CAST(SUM(CASE WHEN fk.is_not_trusted = 0 AND fk.is_disabled = 0 THEN 1 ELSE 0 END) AS VARCHAR(12))
    FROM sys.foreign_keys fk WHERE fk.referenced_object_id = OBJECT_ID('dbo.Users');

    -- New rows can be added on top of the seeded data.
    SET @DepartmentId = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
    SET @DesignationId = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
    SET @RoleId = (SELECT TOP 1 RoleId FROM Roles ORDER BY RoleId DESC);

    EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'ZZ reset test user', @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = NULL, @RoleId = @RoleId, @EmailId = '',
         @LoginName = 'zzresettestuser', @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = 1,
         @UpdatedOn = @Now, @UpdatedBy = 1;

    SET @NewUserId = (SELECT UserId FROM Users WHERE LoginName = 'zzresettestuser');

    INSERT INTO @T VALUES ('After reset: a new user can be added by user 1', 'Yes', CASE WHEN @NewUserId IS NULL THEN 'No' ELSE 'Yes' END);

    EXEC spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'ZT9', @CommitteeName = 'ZZ reset test committee',
         @Board = 0, @IncorporationDate = @Now, @MeetingStartNo = 1, @CommitteeColorCode = '#FFFFFF', @CessationDate = '',
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = 1, @UpdatedOn = @Now, @UpdatedBy = 1;

    INSERT INTO @T
    SELECT 'After reset: a new committee can be added by user 1', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Committee WHERE CommitteeCode = 'ZT9' AND CreatedBy = 1;

    -- The committee alert was sent to the new user; that must not block the delete.
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @NewUserId, @ActingUserId = 1;
    INSERT INTO @T SELECT 'After reset: the new unused user can be deleted', '1', CAST(Result AS VARCHAR(12)) FROM @R;

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = 1, @ActingUserId = 1;
    INSERT INTO @T SELECT 'After reset: admin cannot delete itself (own account)', 'Result 0, Reason 1',
                          'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - checks after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 220));
END CATCH

IF (@@TRANCOUNT > 0)
BEGIN
    ROLLBACK TRANSACTION;
END

INSERT INTO #T (Test, Expected, Actual)
SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;

GO

-------------------------------------------------------------------------------
-- Put the identity counters back.
-- On SQL Server 2025 the rollback above was seen to leave some counters at a
-- wrong value while the catalog still showed the old one, so every counter
-- that has ever been used is reseeded to its saved value, without comparing.
-------------------------------------------------------------------------------
DECLARE @Sql NVARCHAR(MAX);
DECLARE @TableName SYSNAME;
DECLARE @SavedValue BIGINT;
DECLARE @SeedValue BIGINT;
DECLARE @IncrementValue BIGINT;
DECLARE @Reseed BIGINT;

DECLARE IdentCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName, SavedValue, SeedValue, IncrementValue FROM #Ident;

OPEN IdentCursor;
FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;

WHILE (@@FETCH_STATUS = 0)
BEGIN
    -- A counter that was never used before the test and still has not been
    -- used needs nothing (reseeding it would change its first value).
    IF (@SavedValue IS NOT NULL
        OR EXISTS (SELECT 1 FROM sys.identity_columns ic
                   WHERE ic.object_id = OBJECT_ID('dbo.' + QUOTENAME(@TableName)) AND ic.last_value IS NOT NULL))
    BEGIN
        SET @Reseed = ISNULL(@SavedValue, @SeedValue - @IncrementValue);
        SET @Sql = N'DBCC CHECKIDENT (''dbo.' + QUOTENAME(@TableName) + N''', RESEED, ' + CAST(@Reseed AS NVARCHAR(20)) + N') WITH NO_INFOMSGS';
        EXEC sp_executesql @Sql;
    END

    FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;
END

CLOSE IdentCursor;
DEALLOCATE IdentCursor;
GO

-------------------------------------------------------------------------------
-- After: the test copy must look exactly as it did before
-------------------------------------------------------------------------------
DECLARE @Sql NVARCHAR(MAX);
DECLARE @TableName SYSNAME;
DECLARE @Rows INT;

DECLARE CountCursor CURSOR LOCAL FAST_FORWARD FOR SELECT TableName FROM #Counts;

OPEN CountCursor;
FETCH NEXT FROM CountCursor INTO @TableName;

WHILE (@@FETCH_STATUS = 0)
BEGIN
    SET @Sql = N'SELECT @n = COUNT(*) FROM dbo.' + QUOTENAME(@TableName);
    EXEC sp_executesql @Sql, N'@n INT OUTPUT', @n = @Rows OUTPUT;
    UPDATE #Counts SET RowsAfter = @Rows WHERE TableName = @TableName;
    FETCH NEXT FROM CountCursor INTO @TableName;
END

CLOSE CountCursor;
DEALLOCATE CountCursor;

INSERT INTO #T
SELECT 'Test copy restored: tables whose row count changed', '0', CAST(COUNT(*) AS VARCHAR(12))
FROM #Counts WHERE RowsBefore <> ISNULL(RowsAfter, -1);

INSERT INTO #T
SELECT 'Test copy restored: identity counters that changed', '0', CAST(COUNT(*) AS VARCHAR(12))
FROM #Ident i
WHERE i.SavedValue IS NOT NULL
AND CAST(IDENT_CURRENT('dbo.' + QUOTENAME(i.TableName)) AS BIGINT) <> i.SavedValue;

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM #T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> Expected THEN 1 ELSE 0 END) AS Failed
FROM #T;

DROP TABLE #T;
DROP TABLE #Ident;
DROP TABLE #Counts;
GO

SET NOEXEC OFF;
GO
