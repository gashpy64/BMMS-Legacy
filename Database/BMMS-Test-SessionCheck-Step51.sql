/* ============================================================================
   BMMS - Test of step 51 (the role, status and departments read on every
   signed-in request; step RA1d)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 51
   or step 39 is not installed.

   Run it in a NEW query window (it uses temporary objects of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS.

   Part 1 reads only: the marker, the one parameter, the columns of the
   result (no Password, no EmailId), no feature above compatibility level
   100, and that every database user who can run spr_GetUserStatusByUserId
   (step 14; the application login among them) can run the new procedure.

   Part 2, inside ONE transaction that is rolled back (made-up data ZZ51:
   three departments, an Admin inserted directly, a Manager written through
   the real spr_AddEditUser and spr_SetUserStatusByUserId):
     - an unchanged user reads the same twice;
     - a department added, a department removed, the home department moved
       inside the same set: each gives another DepartmentSet;
     - Users.DepartmentId changed alone (no history row): another
       DepartmentSet;
     - the role changed (Manager to User): another RoleCode;
     - the user deactivated: AccountStatus 0;
     - a missing UserId: no row;
     - the protected system account: one row, IsSystem 1.

   Afterwards: nothing of ZZ51 is left, the Users, User_Role and
   User_Department rows are as before and every identity counter is put
   back.

   It has no USE line: select the TEST database in SSMS first. Written for
   compatibility level 100. Plain ASCII. QUOTED_IDENTIFIER and ANSI_NULLS ON
   (the filtered indexes of step 39 need them; sqlcmd -I).
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase = 'BMMS' OR @CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This test is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUserAccessState')), '') NOT LIKE '%SessionCheck-Step51%')
BEGIN
    RAISERROR('Step 51 (BMMS-Fix-SessionCheck-Step51.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%UserHistory-Step39%'
         OR OBJECT_ID('dbo.User_Department', 'U') IS NULL)
BEGIN
    RAISERROR('Step 39 (BMMS-Fix-UserHistory-Step39.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#ZZ51_Save') IS NOT NULL DROP PROCEDURE #ZZ51_Save;
IF OBJECT_ID('tempdb..#ZZ51_Edit') IS NOT NULL DROP PROCEDURE #ZZ51_Edit;
IF OBJECT_ID('tempdb..#ZZ51_State') IS NOT NULL DROP PROCEDURE #ZZ51_State;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-- Add a user through spr_AddEditUser, with a department list
CREATE PROCEDURE #ZZ51_Save
    @UserName VARCHAR(50), @LoginName VARCHAR(50), @RoleId INT, @DepartmentId INT, @List VARCHAR(MAX), @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);

    EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @Desig, @ManagerId = NULL, @RoleId = @RoleId, @EmailId = 'zz51@example.invalid',
         @LoginName = @LoginName, @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
END
GO

-- Edit a user through spr_AddEditUser: the stored values, with the role, home department and list given
CREATE PROCEDURE #ZZ51_Edit
    @UserId INT, @RoleId INT, @DepartmentId INT, @List VARCHAR(MAX), @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @UserName VARCHAR(50), @DesignationId INT, @ManagerId INT, @Mail VARCHAR(50), @LoginName VARCHAR(50);

    SELECT @UserName = UserName, @DesignationId = DesignationId, @ManagerId = ManagerId, @Mail = EmailId, @LoginName = LoginName
    FROM Users WHERE UserId = @UserId;

    EXEC spr_AddEditUser @Code = 'Update', @UserId = @UserId, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @Mail,
         @LoginName = @LoginName, @Password = '', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
END
GO

-- What spr_GetUserAccessState returns for one user, as one text: "rows role status system departmentset"
CREATE PROCEDURE #ZZ51_State
    @UserId INT, @Text VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @A TABLE (UserId INT, RoleCode VARCHAR(50), RoleName VARCHAR(100), AccountStatus INT, IsSystem INT, DepartmentSet VARCHAR(MAX));
    INSERT INTO @A EXEC spr_GetUserAccessState @UserId = @UserId;
    SET @Text = CAST((SELECT COUNT(*) FROM @A) AS VARCHAR(4))
              + ISNULL((SELECT TOP 1 ' ' + RTRIM(RoleCode) + ' ' + CAST(AccountStatus AS VARCHAR(4)) + ' ' + CAST(IsSystem AS VARCHAR(4))
                               + ' ' + CAST(DepartmentSet AS VARCHAR(300)) FROM @A), '');
END
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T
SELECT 'spr_GetUserAccessState carries the marker SessionCheck-Step51 and has one parameter, @UserId INT', '1 1 @UserId int',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUserAccessState')) LIKE '%SessionCheck-Step51%' THEN '1' ELSE '0' END + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetUserAccessState')) AS VARCHAR(4)) + ' '
     + ISNULL((SELECT TOP 1 p.name + ' ' + TYPE_NAME(p.user_type_id) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetUserAccessState')), '-');

INSERT INTO #T
SELECT 'The result columns, in order (no Password, no EmailId)', 'UserId,RoleCode,RoleName,AccountStatus,IsSystem,DepartmentSet',
       ISNULL(STUFF((SELECT ',' + r.name FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.spr_GetUserAccessState @UserId = 0', NULL, 0) r
                     ORDER BY r.column_ordinal FOR XML PATH('')), 1, 1, ''), '-');

INSERT INTO #T
SELECT 'No feature above compatibility level 100 in the text (THROW, TRY_CONVERT, IIF, CONCAT, FORMAT, OFFSET, STRING_AGG)', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('%THROW%'), ('%TRY_CONVERT%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('% OFFSET %'), ('%STRING_AGG%')) w(Pattern)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUserAccessState')) LIKE w.Pattern) AS VARCHAR(4));
GO

-- Every database user who can run step 14's spr_GetUserStatusByUserId (the application login among them) can run the new
-- procedure. Asked of the server as that user (EXECUTE AS USER), so a schema grant counts.
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
        SET @Can = CASE WHEN HAS_PERMS_BY_NAME('dbo.spr_GetUserStatusByUserId', 'OBJECT', 'EXECUTE') = 1 THEN
                        HAS_PERMS_BY_NAME('dbo.spr_GetUserAccessState', 'OBJECT', 'EXECUTE') ELSE -1 END;
        REVERT;
        IF (@Can >= 0) SET @Users = @Users + 1;
        IF (@Can = 0)
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

INSERT INTO #T
SELECT 'Every database user who can run spr_GetUserStatusByUserId can run spr_GetUserAccessState (users counted: '
       + CAST(@Users AS VARCHAR(4)) + ')', '0', CAST(@Cannot AS VARCHAR(4)) + @Names;
GO

-------------------------------------------------------------------------------
-- Part 2: the cases, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))));
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @Adm INT, @M INT, @DA INT, @DB INT, @DC INT, @Missing INT;
DECLARE @L VARCHAR(MAX), @S1 VARCHAR(400), @S2 VARCHAR(400), @E VARCHAR(400), @SysRole VARCHAR(50), @SysDept INT;
DECLARE @HistBefore VARCHAR(100), @HistAfter VARCHAR(100), @UsersBefore VARCHAR(60), @UsersAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @Desig IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role (admin, manager, user) or a designation is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

-- Rows outside the test, before
SELECT @HistBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistBefore = @HistBefore + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;

BEGIN TRANSACTION;

BEGIN TRY
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ51A', 'ZZ step 51 department A', 991, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ51B', 'ZZ step 51 department B', 992, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ51C', 'ZZ step 51 department C', 993, 1, @Now, @Sys);
    SET @DC = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ51 admin', @DA, @Desig, NULL, @rAdmin, 'zz51a@example.invalid', 'zz51adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();

    -- A Manager with A (home) and B
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ51_Save @UserName = 'ZZ51 manager', @LoginName = 'zz51mgr', @RoleId = @rMgr, @DepartmentId = @DA, @List = @L, @Actor = @Adm;
    SET @M = (SELECT UserId FROM Users WHERE LoginName = 'zz51mgr');
    EXEC #ZZ51_State @UserId = @M, @Text = @S1 OUTPUT;
    SET @E = '1 manager 1 0 ' + CAST(@DA AS VARCHAR(12)) + '|' + CAST(@DA AS VARCHAR(12)) + 'h,' + CAST(@DB AS VARCHAR(12));
    INSERT INTO @T SELECT 'A Manager added with A (home) and B: role, status, system flag, departments', 'Result 1, Reason 0 | ' + @E, ISNULL((SELECT Txt FROM @R), '-') + ' | ' + @S1;

    -- 1. unchanged
    EXEC #ZZ51_State @UserId = @M, @Text = @S2 OUTPUT;
    INSERT INTO @T SELECT 'Unchanged user: the same text at the second read', @S1, @S2;

    -- 2. department added
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ51_Edit @UserId = @M, @RoleId = @rMgr, @DepartmentId = @DA, @List = @L, @Actor = @Adm;
    EXEC #ZZ51_State @UserId = @M, @Text = @S2 OUTPUT;
    SET @E = '1 manager 1 0 ' + CAST(@DA AS VARCHAR(12)) + '|' + CAST(@DA AS VARCHAR(12)) + 'h,' + CAST(@DB AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12));
    INSERT INTO @T SELECT 'Department C added: another DepartmentSet', 'Result 1, Reason 0 | ' + @E + ' | changed', ISNULL((SELECT Txt FROM @R), '-') + ' | ' + @S2 + ' | ' + CASE WHEN @S2 <> @S1 THEN 'changed' ELSE 'same' END;
    SET @S1 = @S2;

    -- 3. department removed
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ51_Edit @UserId = @M, @RoleId = @rMgr, @DepartmentId = @DA, @List = @L, @Actor = @Adm;
    EXEC #ZZ51_State @UserId = @M, @Text = @S2 OUTPUT;
    SET @E = '1 manager 1 0 ' + CAST(@DA AS VARCHAR(12)) + '|' + CAST(@DA AS VARCHAR(12)) + 'h,' + CAST(@DC AS VARCHAR(12));
    INSERT INTO @T SELECT 'Department B removed: another DepartmentSet', 'Result 1, Reason 0 | ' + @E + ' | changed', ISNULL((SELECT Txt FROM @R), '-') + ' | ' + @S2 + ' | ' + CASE WHEN @S2 <> @S1 THEN 'changed' ELSE 'same' END;
    SET @S1 = @S2;

    -- 4. home moved inside the same set (A, C): C is home now
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ51_Edit @UserId = @M, @RoleId = @rMgr, @DepartmentId = @DC, @List = @L, @Actor = @Adm;
    EXEC #ZZ51_State @UserId = @M, @Text = @S2 OUTPUT;
    SET @E = '1 manager 1 0 ' + CAST(@DC AS VARCHAR(12)) + '|' + CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12)) + 'h';
    INSERT INTO @T SELECT 'Home department moved from A to C, the same set: another DepartmentSet', 'Result 1, Reason 0 | ' + @E + ' | changed', ISNULL((SELECT Txt FROM @R), '-') + ' | ' + @S2 + ' | ' + CASE WHEN @S2 <> @S1 THEN 'changed' ELSE 'same' END;
    SET @S1 = @S2;

    -- 5. Users.DepartmentId changed alone (no writer of the application does this; the text must still change)
    UPDATE Users SET DepartmentId = @DA WHERE UserId = @M;
    EXEC #ZZ51_State @UserId = @M, @Text = @S2 OUTPUT;
    SET @E = '1 manager 1 0 ' + CAST(@DA AS VARCHAR(12)) + '|' + CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12)) + 'h';
    INSERT INTO @T SELECT 'Users.DepartmentId changed alone, history rows unchanged: another DepartmentSet', @E + ' | changed', @S2 + ' | ' + CASE WHEN @S2 <> @S1 THEN 'changed' ELSE 'same' END;
    UPDATE Users SET DepartmentId = @DC WHERE UserId = @M;
    EXEC #ZZ51_State @UserId = @M, @Text = @S1 OUTPUT;

    -- 6. role changed: Manager to User, home C only
    SET @L = CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ51_Edit @UserId = @M, @RoleId = @rUser, @DepartmentId = @DC, @List = @L, @Actor = @Adm;
    EXEC #ZZ51_State @UserId = @M, @Text = @S2 OUTPUT;
    SET @E = '1 user 1 0 ' + CAST(@DC AS VARCHAR(12)) + '|' + CAST(@DC AS VARCHAR(12)) + 'h';
    INSERT INTO @T SELECT 'Role changed from Manager to User: RoleCode user (A closed, R)', 'Result 1, Reason 0 | ' + @E, ISNULL((SELECT Txt FROM @R), '-') + ' | ' + @S2;
    SET @S1 = @S2;

    -- 7. deactivated
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @M, @AccountStatus = 0, @ActingUserId = @Adm;
    EXEC #ZZ51_State @UserId = @M, @Text = @S2 OUTPUT;
    SET @E = '1 user 0 0 ' + CAST(@DC AS VARCHAR(12)) + '|';
    INSERT INTO @T SELECT 'Deactivated: AccountStatus 0 (every open row closed)', 'Result 1, Reason 0 | ' + @E, ISNULL((SELECT Txt FROM @R), '-') + ' | ' + @S2;

    -- 8. a missing UserId
    SET @Missing = (SELECT ISNULL(MAX(UserId), 0) + 1000 FROM Users);
    EXEC #ZZ51_State @UserId = @Missing, @Text = @S2 OUTPUT;
    INSERT INTO @T SELECT 'A UserId that does not exist: no row', '0', @S2;
    EXEC #ZZ51_State @UserId = 0, @Text = @S2 OUTPUT;
    INSERT INTO @T SELECT 'UserId 0: no row', '0', @S2;

    -- 9. the protected system account
    SELECT @SysRole = RTRIM(r.RoleCode), @SysDept = u.DepartmentId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @Sys;
    EXEC #ZZ51_State @UserId = @Sys, @Text = @S2 OUTPUT;
    INSERT INTO @T SELECT 'The protected system account: one row, its role, IsSystem 1, its home department first', '1 ' + ISNULL(@SysRole, '-') + ' 1 1 ' + ISNULL(CAST(@SysDept AS VARCHAR(12)), '-') + '|',
           LEFT(@S2, LEN('1 ' + ISNULL(@SysRole, '-') + ' 1 1 ' + ISNULL(CAST(@SysDept AS VARCHAR(12)), '-') + '|'));

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION;
    INSERT INTO @T SELECT 'Part 2 ran to the end without an error', 'no error', LEFT('error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + ERROR_MESSAGE(), 400);
END CATCH

-- Rows outside the test, after
SELECT @HistAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistAfter = @HistAfter + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
INSERT INTO @T SELECT 'After the rollback: User_Role and User_Department as before', @HistBefore, @HistAfter;
INSERT INTO @T SELECT 'After the rollback: Users as before', @UsersBefore, @UsersAfter;

Report:
INSERT INTO #T (Test, Expected, Actual) SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;
GO

-- Every identity counter as before the test (a rolled-back insert still moves it)
DECLARE @TableName SYSNAME, @SavedValue BIGINT, @SeedValue BIGINT, @IncrementValue BIGINT, @Sql NVARCHAR(400);
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
SELECT 'After the test: no ZZ51 department or user left', '0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ51%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz51%') AS VARCHAR(12));

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

DROP PROCEDURE #ZZ51_State;
DROP PROCEDURE #ZZ51_Edit;
DROP PROCEDURE #ZZ51_Save;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
