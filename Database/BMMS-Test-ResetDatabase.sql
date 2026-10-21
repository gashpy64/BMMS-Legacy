/* ============================================================================
   BMMS - Critical fix #5: Reset Database still works with the 21 user keys
   (and, since step 29, refuses safely and rolls back on failure)
   ----------------------------------------------------------------------------
   TEST DATABASE ONLY. This script EXECUTES spr_sys_ResetDatabase, the
   procedure that wipes every table and re-creates the default rows.

   It refuses to run in a database named exactly "BMMS". Run it only in the
   restored test copy (for example BMMS_Test), after
   BMMS-Fix-UserDelete-Procedure.sql, BMMS-Add-ForeignKeys-Step5.sql and
   BMMS-Fix-ResetDatabase-Step29.sql (step 29; it stops, changing nothing,
   if step 29 is not installed).

   How it protects the test copy:
     * every reset runs inside a transaction that is ROLLED BACK, so all rows
       come back;
     * identity counters are not reliably covered by a rollback, so every
       table's counter is saved before the reset and reseeded afterwards
       (after part 1 and again after part 2).
   The last rows of the result grid confirm that row counts and identity
   counters are the same as before the test.

   Part 1, checked while the database is in its reset state:
     * the procedure runs to completion with all keys in place
     * the 4 default users exist, admin is user 1, and the seeded manager link
       points at a real user
     * the seeded committees point at a real user
     * no user-id column covered by a key holds an unknown user
     * all 21 keys still exist and are trusted
     * a new user and a new committee can be added by user 1
     * the new, unused user can be deleted; admin (who has history) cannot
     * with step 19 installed: the organisation settings are unchanged
     * with step 21 installed: the six member types are seeded with their
       scope, display order and reserved flag
     * step 29: the reset (database name typed in lower case) returns
       Result 1; one audit row names the acting user; the send-mail audit is
       cleared; the four seeded users have the hashes of the new default
       password (the stored strings are compared; the hashes themselves are
       checked against the password in C#, outside SQL)

   Part 2 (step 29), each inside a rolled-back transaction:
     * the procedure text keeps the texts of steps 3, 18 and 21
     * refused without changing anything: a wrong database name (Reason 3),
       an empty name (3), a user who is not an Admin (4), an unknown user (8)
     * a forced failure (a test trigger on Committee that raises an error on
       the last seed insert): the error reaches the caller, the procedure has
       rolled back, every table has its rows and every identity counter its
       value again (put back by the procedure itself), and the trigger is gone

   Result: one grid, one row per check. Status should be PASS for every row.
   The procedure's own Result row of part 1 appears as a small grid above it.

   It has no USE line: select the TEST database in SSMS first.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase = 'BMMS' OR @CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This test runs spr_sys_ResetDatabase and is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_bak1). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_sys_ResetDatabase') AND name = '@ConfirmDatabaseName')
BEGIN
    RAISERROR('Step 29 (BMMS-Fix-ResetDatabase-Step29.sql) is not installed in "%s". Install it first; this test calls the step 29 procedure. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#Counts') IS NOT NULL DROP TABLE #Counts;
IF OBJECT_ID('tempdb..#ZZ_Step29_PutCountersBack') IS NOT NULL DROP PROCEDURE #ZZ_Step29_PutCountersBack;
IF OBJECT_ID('tempdb..#ZZ_Step29_Changed') IS NOT NULL DROP PROCEDURE #ZZ_Step29_Changed;

-- A test trigger left behind by an interrupted earlier run
IF OBJECT_ID('dbo.trg_ZZ_Step29Test_Fail', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_ZZ_Step29Test_Fail;

-- Temporary tables, not table variables: the identity counters are put back
-- and checked in separate batches further down.
CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(120), Expected VARCHAR(50), Actual VARCHAR(250));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
CREATE TABLE #Counts (TableName SYSNAME, RowsBefore INT, RowsAfter INT NULL);

DECLARE @Sql NVARCHAR(MAX);
DECLARE @TableName SYSNAME;
DECLARE @Rows INT;

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
GO

-------------------------------------------------------------------------------
-- Put the identity counters back (called after part 1 and after part 2).
-- On SQL Server 2025 a rollback was seen to leave some counters at a wrong
-- value while the catalog still showed the old one, so every counter that
-- has ever been used is reseeded to its saved value, without comparing.
-------------------------------------------------------------------------------
CREATE PROCEDURE #ZZ_Step29_PutCountersBack
AS
BEGIN
    SET NOCOUNT ON;

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
END
GO

-------------------------------------------------------------------------------
-- How many tables have another row count than before the test, and how many
-- used identity counters another value (part 2: "nothing changed")
-------------------------------------------------------------------------------
CREATE PROCEDURE #ZZ_Step29_Changed
    @Tables INT OUTPUT,
    @Counters INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @TableName SYSNAME;
    DECLARE @RowsBefore INT;
    DECLARE @Rows INT;

    SET @Tables = 0;

    DECLARE ChangedCursor CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, RowsBefore FROM #Counts;

    OPEN ChangedCursor;
    FETCH NEXT FROM ChangedCursor INTO @TableName, @RowsBefore;

    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @Sql = N'SELECT @n = COUNT(*) FROM dbo.' + QUOTENAME(@TableName);
        EXEC sp_executesql @Sql, N'@n INT OUTPUT', @n = @Rows OUTPUT;
        IF (@Rows <> @RowsBefore)
            SET @Tables = @Tables + 1;
        FETCH NEXT FROM ChangedCursor INTO @TableName, @RowsBefore;
    END

    CLOSE ChangedCursor;
    DEALLOCATE ChangedCursor;

    SELECT @Counters = COUNT(*)
    FROM #Ident i
    WHERE i.SavedValue IS NOT NULL
    AND CAST(IDENT_CURRENT('dbo.' + QUOTENAME(i.TableName)) AS BIGINT) <> i.SavedValue;
END
GO

-------------------------------------------------------------------------------
-- Part 1: the reset, inside a transaction that is rolled back
-------------------------------------------------------------------------------
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

-- Step 29: the acting Admin and the database name (typed in lower case: the name is compared ignoring case)
DECLARE @AdminId INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                        WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 ORDER BY u.UserId);
DECLARE @AdminLogin VARCHAR(50) = (SELECT CAST(LoginName AS VARCHAR(50)) FROM Users WHERE UserId = @AdminId);
DECLARE @TypedName NVARCHAR(128) = LOWER(DB_NAME());
DECLARE @ResetResult INT;
DECLARE @ResetReason INT;
DECLARE @AuditAfterReset VARCHAR(250) = 'not read';
DECLARE @SendMailAfterReset VARCHAR(12) = 'not read';

DECLARE @KeyCols TABLE (TableName SYSNAME, ColumnName SYSNAME);

INSERT INTO @KeyCols (TableName, ColumnName)
SELECT OBJECT_NAME(fc.parent_object_id), COL_NAME(fc.parent_object_id, fc.parent_column_id)
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fc ON fc.constraint_object_id = fk.object_id
WHERE fk.referenced_object_id = OBJECT_ID('dbo.Users');

-- Step 19: the organisation settings before the reset (they must survive it)
DECLARE @Step19 INT = CASE WHEN OBJECT_ID('dbo.spr_GetOrganisationSettings', 'P') IS NOT NULL THEN 1 ELSE 0 END;
DECLARE @OrgBefore VARCHAR(MAX) = '';
DECLARE @OrgAfter VARCHAR(MAX) = '';
DECLARE @OrgSql NVARCHAR(MAX) = N'SELECT @s = ISNULL(STUFF((SELECT ''|'' + SettingCode + ''='' + SettingValue FROM dbo.App_Setting
    WHERE SettingCode <> ''AgendaControllerBypass'' ORDER BY SettingCode FOR XML PATH(''''), TYPE).value(''.'', ''VARCHAR(MAX)''), 1, 1, ''''), '''')';

BEGIN TRANSACTION;

BEGIN TRY

    -- Step 19: two sample values (rolled back), then the settings as they are before the reset
    IF (@Step19 = 1)
    BEGIN
        UPDATE App_Setting SET SettingValue = 'Example Company Limited' WHERE SettingCode = 'OrganisationName';
        UPDATE App_Setting SET SettingValue = 'Sampletown' WHERE SettingCode = 'RegisteredOfficeCity';
        EXEC sp_executesql @OrgSql, N'@s VARCHAR(MAX) OUTPUT', @s = @OrgBefore OUTPUT;
    END

    EXEC spr_sys_ResetDatabase @ActingUserId = @AdminId, @ConfirmDatabaseName = @TypedName,
         @Result = @ResetResult OUTPUT, @Reason = @ResetReason OUTPUT;

    INSERT INTO @T VALUES ('spr_sys_ResetDatabase ran to completion', 'Yes', 'Yes');

    -- Step 29: read before the checks below add users and committees
    SELECT @AuditAfterReset = CAST(COUNT(*) AS VARCHAR(12)) + ' row, user ' + ISNULL(CAST(MAX(Update_By) AS VARCHAR(12)), '-')
                            + ', ' + ISNULL(MAX(CAST(New_Value AS VARCHAR(200))), '-')
    FROM Audit_Trail_Master
    WHERE Audit_Table = 'Database' AND Field_Name = 'Reset';
    SELECT @SendMailAfterReset = CAST(COUNT(*) AS VARCHAR(12)) FROM Audit_Trail_SendMail;

    INSERT INTO @T SELECT 'Default users re-created', '4', CAST(COUNT(*) AS VARCHAR(12)) FROM Users;

    -- Step 29: the seeds carry the hashes of the new default password (Common.DefaultPassword)
    INSERT INTO @T
    SELECT 'Seeded users: password hashes of the default password [step 29]', '4', CAST(COUNT(*) AS VARCHAR(12))
    FROM Users u
    JOIN (VALUES
        ('admin',       '100000.gURba0Xwa3iXhBwkFEi/hA==.yxFedi3Cfs3FLcDlU7oWXp94eY15AGoU4AN+c3tf8j0='),
        ('secuser',     '100000.QcDvazIat4fcHJw+tivVTg==.dLQDFP7A1cYcAcaYsIvwlXFsZv8lAYDJIVqwDUWNBJ8='),
        ('credmanager', '100000.pJ5r7xUvCSnGHp+32dpp4w==.ity6i4nc8MrUUoy2nnHfxy17AZp61+bNYkvs1gYQLhI='),
        ('creduser',    '100000.UfrmZn5v9zOs6DlxPdFy9Q==.qHS0QM1qZuYJfnITWbrNUucDryAyVLNz1HdnnDcxLbc=')
    ) AS h (LoginName, PasswordHash)
      -- Exact comparison: base64 and the login name are case sensitive
      ON CAST(u.LoginName AS VARCHAR(50)) COLLATE Latin1_General_BIN2 = h.LoginName COLLATE Latin1_General_BIN2
     AND CAST(u.[Password] AS VARCHAR(200)) COLLATE Latin1_General_BIN2 = h.PasswordHash COLLATE Latin1_General_BIN2;

    INSERT INTO @T
    SELECT 'User 1 is admin', 'admin', ISNULL((SELECT LoginName FROM Users WHERE UserId = 1), 'no user 1');

    -- Step 18: the "admin" seed is the protected system account, the other three are not
    DECLARE @Step18 INT = CASE WHEN COL_LENGTH('dbo.Users', 'IsSystem') IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @SystemAfterReset VARCHAR(40) = 'step 18 not installed';
    IF (@Step18 = 1)
    BEGIN
        EXEC sp_executesql N'SELECT @s = CAST(COUNT(*) AS VARCHAR(4)) + '' '' + ISNULL(MAX(CASE WHEN IsSystem = 1 THEN LOWER(LoginName) + '' '' + CAST(UserId AS VARCHAR(12)) END), ''none'') FROM dbo.Users WHERE IsSystem = 1',
             N'@s VARCHAR(40) OUTPUT', @s = @SystemAfterReset OUTPUT;
        INSERT INTO @T SELECT 'After reset: exactly one system account, the admin seed (count, login, id) [step 18]', '1 admin 1', @SystemAfterReset;
    END

    -- Step 19: Reset Database keeps the organisation settings
    IF (@Step19 = 1)
    BEGIN
        EXEC sp_executesql @OrgSql, N'@s VARCHAR(MAX) OUTPUT', @s = @OrgAfter OUTPUT;
        INSERT INTO @T SELECT 'After reset: organisation settings unchanged [step 19]', '12 rows, same values',
               CAST((SELECT COUNT(*) FROM App_Setting WHERE SettingCode IN ('OrganisationName', 'OrganisationShortName', 'OrganisationTerm',
                     'CertificateSignOff', 'RegisteredOfficeLabel', 'RegisteredOfficeLine1', 'RegisteredOfficeLine2', 'RegisteredOfficeCity',
                     'RegisteredOfficePinCode', 'OrganisationPhone', 'OrganisationFax', 'OrganisationEmail')) AS VARCHAR(4)) + ' rows, '
             + CASE WHEN @OrgAfter = @OrgBefore THEN 'same values' ELSE 'values changed' END;
    END

    -- Step 21: the six member types with their scope, display order and reserved flag (2, 3 and 6 reserved)
    IF (COL_LENGTH('dbo.Member_Type', 'MemberScope') IS NOT NULL)
    BEGIN
        DECLARE @TypesAfterReset VARCHAR(400) = '';
        EXEC sp_executesql N'SELECT @s = STUFF((SELECT ''|'' + CAST(MemberTypeId AS VARCHAR(12)) + '' '' + MemberTypeName + '' '' + MemberScope + '' ''
                 + CAST(DisplayOrder AS VARCHAR(12)) + '' '' + CAST(CAST(IsReserved AS INT) AS VARCHAR(1)) + '' '' + CAST(StatusId AS VARCHAR(2))
                 FROM dbo.Member_Type ORDER BY MemberTypeId FOR XML PATH(''''), TYPE).value(''.'', ''VARCHAR(400)''), 1, 1, '''')',
             N'@s VARCHAR(400) OUTPUT', @s = @TypesAfterReset OUTPUT;
        -- Each row: id, name, scope, display order, reserved, status
        INSERT INTO @T SELECT 'After reset: member types with scope, order, reserved flag, status [step 21]', 'as seeded',
               CASE WHEN @TypesAfterReset = '1 Member C 1 0 1|2 Invitee M 2 1 1|3 In Attendance M 3 1 1|4 Chairman C 4 0 1|5 Managing Director C 5 0 1|6 Special Invitee M 6 1 1'
                    THEN 'as seeded' ELSE LEFT(ISNULL(@TypesAfterReset, 'none'), 250) END;
    END

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
    -- Step 18: the admin seed is the protected system account, so the refusal is Reason 7
    INSERT INTO @T SELECT 'After reset: admin cannot delete itself (own account)' + CASE WHEN @Step18 = 1 THEN ' [step 18: system account, Reason 7]' ELSE '' END,
                          CASE WHEN @Step18 = 1 THEN 'Result 0, Reason 7' ELSE 'Result 0, Reason 1' END,
                          'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    -- Step 29
    INSERT INTO @T SELECT 'Reset (database name typed in lower case) returns Result 1, Reason 0 [step 29]', 'Result 1, Reason 0',
           'Result ' + ISNULL(CAST(@ResetResult AS VARCHAR(4)), 'NULL') + ', Reason ' + ISNULL(CAST(@ResetReason AS VARCHAR(4)), 'NULL');
    INSERT INTO @T SELECT 'After reset: one audit row, by user 1, naming the acting user [step 29]',
           LEFT('1 row, user 1, Reset by ' + ISNULL(@AdminLogin, '?'), 50), LEFT(@AuditAfterReset, 250);
    INSERT INTO @T SELECT 'After reset: Audit_Trail_SendMail is empty [step 29]', '0', @SendMailAfterReset;

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

EXEC #ZZ_Step29_PutCountersBack;
GO

-------------------------------------------------------------------------------
-- Part 2 (step 29): refusals and a forced failure, each rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(120), Expected VARCHAR(50), Actual VARCHAR(250));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));

DECLARE @Def NVARCHAR(MAX) = ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '');
DECLARE @AdminId INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                        WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 ORDER BY u.UserId);
DECLARE @OtherId INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                        WHERE r.RoleCode <> 'admin' AND u.AccountStatus = 1 ORDER BY u.UserId);
DECLARE @MissingId INT = (SELECT ISNULL(MAX(UserId), 0) + 1000 FROM Users);
DECLARE @DbName NVARCHAR(128) = DB_NAME();
DECLARE @WrongName NVARCHAR(128) = N'ZZ_not_this_database';
DECLARE @EmptyName NVARCHAR(128) = N'';
DECLARE @Tables INT;
DECLARE @Counters INT;
DECLARE @TranAfter INT;
DECLARE @ErrNo INT;
DECLARE @ErrMsg NVARCHAR(400);
DECLARE @FailResult INT;
DECLARE @FailReason INT;

-- FK#5-ManagerId-NULL, SystemAccount3-Step18, MemberTypes-Step21, ResetSafe-Step29, XACT_ABORT, no App_Setting
INSERT INTO @T SELECT 'Procedure text: texts of steps 3, 18, 21 and 29, XACT_ABORT, no App_Setting [step 29]',
       '1 1 1 1 1 0',
       CASE WHEN @Def LIKE '%FK#5-ManagerId-NULL%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN @Def LIKE '%SystemAccount3-Step18%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN @Def LIKE '%MemberTypes-Step21%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN @Def LIKE '%ResetSafe-Step29%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN @Def LIKE '%SET XACT_ABORT ON%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN @Def LIKE '%App_Setting%' THEN '1' ELSE '0' END;

-- Refusals: inside a transaction that is rolled back, in case one of them were to clear anything
BEGIN TRANSACTION;

BEGIN TRY
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_sys_ResetDatabase @ActingUserId = @AdminId, @ConfirmDatabaseName = @WrongName;
    INSERT INTO @T SELECT 'Refused: a wrong database name (Result, Reason, Detail) [step 29]', 'Result 0, Reason 3, DatabaseName',
           'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) + ', ' + ISNULL(CAST(ReasonDetail AS VARCHAR(100)), '') FROM @R;

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_sys_ResetDatabase @ActingUserId = @AdminId, @ConfirmDatabaseName = @EmptyName;
    INSERT INTO @T SELECT 'Refused: an empty database name [step 29]', 'Result 0, Reason 3',
           'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R;

    IF (@OtherId IS NULL)
        INSERT INTO @T VALUES ('Refused: a user who is not an Admin [step 29]', 'Result 0, Reason 4', 'SKIPPED');
    ELSE
    BEGIN
        DELETE FROM @R;
        INSERT INTO @R EXEC spr_sys_ResetDatabase @ActingUserId = @OtherId, @ConfirmDatabaseName = @DbName;
        INSERT INTO @T SELECT 'Refused: a user who is not an Admin [step 29]', 'Result 0, Reason 4',
               'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R;
    END

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_sys_ResetDatabase @ActingUserId = @MissingId, @ConfirmDatabaseName = @DbName;
    INSERT INTO @T SELECT 'Refused: an unknown user [step 29]', 'Result 0, Reason 8',
           'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R;

    EXEC #ZZ_Step29_Changed @Tables = @Tables OUTPUT, @Counters = @Counters OUTPUT;
    INSERT INTO @T SELECT 'Refusals changed nothing (tables, counters, open transactions) [step 29]', '0 0 1',
           CAST(@Tables AS VARCHAR(12)) + ' ' + CAST(@Counters AS VARCHAR(12)) + ' ' + CAST(@@TRANCOUNT AS VARCHAR(12));
END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error in the refusal checks', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 220));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

-- Forced failure: a test trigger makes the last seed insert (Committee) fail. The trigger is created
-- inside this transaction, so the procedure's rollback removes it again.
SET @ErrNo = 0;
SET @ErrMsg = N'';

BEGIN TRANSACTION;

BEGIN TRY
    EXEC (N'CREATE TRIGGER dbo.trg_ZZ_Step29Test_Fail ON dbo.Committee AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    THROW 50029, ''Step 29 test: forced failure'', 1;
END');

    EXEC spr_sys_ResetDatabase @ActingUserId = @AdminId, @ConfirmDatabaseName = @DbName,
         @Result = @FailResult OUTPUT, @Reason = @FailReason OUTPUT;
END TRY
BEGIN CATCH
    SET @ErrNo = ERROR_NUMBER();
    SET @ErrMsg = LEFT(ERROR_MESSAGE(), 400);
END CATCH

SET @TranAfter = @@TRANCOUNT;

-- If the procedure did not roll back, undo it here (the open-transaction check below then fails)
IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

-- Measured before the test puts any counter back: the procedure must have done it itself
EXEC #ZZ_Step29_Changed @Tables = @Tables OUTPUT, @Counters = @Counters OUTPUT;

INSERT INTO @T SELECT 'Forced failure: the error reaches the caller (50029; 266 accepted) [step 29]', 'error',
       CASE WHEN @ErrNo IN (50029, 266) THEN 'error' ELSE 'no error / ' + CAST(@ErrNo AS VARCHAR(12)) + ' ' + LEFT(@ErrMsg, 200) END;
INSERT INTO @T SELECT 'Forced failure: the procedure rolled back (open transactions afterwards) [step 29]', '0', CAST(@TranAfter AS VARCHAR(12));
INSERT INTO @T SELECT 'Forced failure: tables whose row count changed [step 29]', '0', CAST(@Tables AS VARCHAR(12));
INSERT INTO @T SELECT 'Forced failure: identity counters put back by the procedure (changed) [step 29]', '0', CAST(@Counters AS VARCHAR(12));
INSERT INTO @T SELECT 'Forced failure: the test trigger is gone [step 29]', '0',
       CASE WHEN OBJECT_ID('dbo.trg_ZZ_Step29Test_Fail', 'TR') IS NULL THEN '0' ELSE '1' END;

INSERT INTO #T (Test, Expected, Actual)
SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;
GO

-- A trigger left by a procedure that did not roll back (the check above has failed then)
IF OBJECT_ID('dbo.trg_ZZ_Step29Test_Fail', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_ZZ_Step29Test_Fail;

EXEC #ZZ_Step29_PutCountersBack;
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
DROP PROCEDURE #ZZ_Step29_PutCountersBack;
DROP PROCEDURE #ZZ_Step29_Changed;
GO

SET NOEXEC OFF;
GO
