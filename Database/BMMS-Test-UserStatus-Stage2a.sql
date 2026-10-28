/* ============================================================================
   BMMS - Tests for BMMS-Fix-UserStatus-Stage2a.sql (step 14)
   ----------------------------------------------------------------------------
   Run AFTER BMMS-Fix-UserStatus-Stage2a.sql, on the TEST COPY. It stops if
   step 14 is not installed.

   Creates test users (2 Admins, 2 Controllers, an active and an inactive
   Manager, an active and an inactive User) and checks:
     * Users.AccountStatus: NOT NULL, default 1, CHECK trusted; 2 and NULL
       are refused
     * an inactive (or missing) acting user gets Reason 8, also on their own
       account and through spr_SetUserStatusByUserId
     * deactivate / activate through spr_SetUserStatusByUserId: Admin on a
       User, Controller on an Admin (Reason 4) and on a User, own account
       (Reason 1), a Manager acting (Reason 4), a Manager who manages users
       (allowed, users keep the manager), last active Controller (Reason 3)
     * spr_GetUserListForUserPage: Status, CanDeactivate, CanActivate,
       ManagedCount (active managed users only); inactive users stay listed;
       an inactive or missing acting user gets no flags
     * spr_GetActiveUserList: active users only, same admin-name filter as
       spr_GetUser; spr_GetUser still lists inactive users
     * spr_GetMgrControllerByDeptId: active only; @IncludeUserId adds an
       inactive current manager, with " (inactive)" in ManagerText
     * spr_GetUserStatusByUserId: 1, 0, no row for an unknown user
     * spr_LockUserByUserId: error 50002, nothing changed

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.

   It has no USE line: select the database in SSMS first (the test copy). It
   stops if the current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%UserStatus-Stage2a%')
BEGIN
    RAISERROR('User status stage 2a is not installed in "%s". Run BMMS-Fix-UserStatus-Stage2a.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(120), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Dept1 INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @Desig1 INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @rAdmin INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @rCtl INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @rMgr INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @rUser INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'user');

DECLARE @A1 INT, @A2 INT, @C1 INT, @C2 INT, @M INT, @M2 INT, @U INT, @U2 INT, @D INT;
DECLARE @Missing INT;
DECLARE @Rows INT;
DECLARE @Text VARCHAR(400);

-- The capture tables are built from View_Users, so they follow its columns (step 18 adds IsSystem)
-- View_Users columns (spr_GetUser, spr_GetActiveUserList)
SELECT TOP 0 * INTO #V FROM View_Users;

-- spr_GetUserListForUserPage: View_Users plus the flags
SELECT TOP 0 v.*, CAST(NULL AS INT) AS CanEdit, CAST(NULL AS INT) AS CanChangeRole, CAST(NULL AS INT) AS CanDelete,
       CAST(NULL AS VARCHAR(10)) AS Status, CAST(NULL AS INT) AS CanDeactivate, CAST(NULL AS INT) AS CanActivate, CAST(NULL AS INT) AS ManagedCount
INTO #List FROM View_Users v;

-- spr_GetMgrControllerByDeptId: View_Users plus ManagerText
SELECT TOP 0 v.*, CAST(NULL AS VARCHAR(80)) AS ManagerText INTO #Mgr FROM View_Users v;

-- Step 18: the protected system account (NULL before step 18)
DECLARE @SystemUser INT;
IF (COL_LENGTH('dbo.Users', 'IsSystem') IS NOT NULL)
    EXEC sp_executesql N'SELECT @id = UserId FROM dbo.Users WHERE IsSystem = 1', N'@id INT OUTPUT', @id = @SystemUser OUTPUT;

CREATE TABLE #St (AccountStatus INT);

IF (@rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @Dept1 IS NULL OR @Desig1 IS NULL)
BEGIN
    INSERT INTO @T VALUES ('A role (admin, controller, manager, user), department or designation is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Test users (inserted directly; no login is possible with them)
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ status admin 1', @Dept1, @Desig1, NULL, @rAdmin, 'zz@test', 'zzstata1', 'not-a-login', 1, @Now);
    SET @A1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ status admin 2', @Dept1, @Desig1, NULL, @rAdmin, 'zz@test', 'zzstata2', 'not-a-login', 1, @Now);
    SET @A2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ status controller 1', @Dept1, @Desig1, NULL, @rCtl, 'zz@test', 'zzstatc1', 'not-a-login', 1, @Now);
    SET @C1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ status controller 2', @Dept1, @Desig1, NULL, @rCtl, 'zz@test', 'zzstatc2', 'not-a-login', 1, @Now);
    SET @C2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ status manager', @Dept1, @Desig1, NULL, @rMgr, 'zz@test', 'zzstatm', 'not-a-login', 1, @Now);
    SET @M = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ status manager inactive', @Dept1, @Desig1, NULL, @rMgr, 'zz@test', 'zzstatm2', 'not-a-login', 0, @Now);
    SET @M2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ status user', @Dept1, @Desig1, @M, @rUser, 'zz@test', 'zzstatu', 'not-a-login', 1, @Now);
    SET @U = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ status user inactive', @Dept1, @Desig1, @M, @rUser, 'zz@test', 'zzstatu2', 'not-a-login', 0, @Now);
    SET @U2 = SCOPE_IDENTITY();

    SET @Missing = (SELECT ISNULL(MAX(UserId), 0) + 1000 FROM Users);

    ---------------------------------------------------------------------------
    -- Users.AccountStatus
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'AccountStatus is NOT NULL', '0', CAST(is_nullable AS VARCHAR(2))
    FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'AccountStatus';

    INSERT INTO @T SELECT 'CK_Users_AccountStatus exists and is trusted', '0',
           ISNULL((SELECT CAST(is_not_trusted AS VARCHAR(2)) FROM sys.check_constraints
                   WHERE parent_object_id = OBJECT_ID('dbo.Users') AND name = 'CK_Users_AccountStatus'), 'missing');

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], CreatedOn)
    VALUES ('ZZ status default', @Dept1, @Desig1, NULL, @rUser, 'zz@test', 'zzstatd', 'not-a-login', @Now);
    SET @D = SCOPE_IDENTITY();
    INSERT INTO @T SELECT 'Insert without AccountStatus gets 1', '1', CAST(AccountStatus AS VARCHAR(2)) FROM Users WHERE UserId = @D;

    BEGIN TRY
        UPDATE Users SET AccountStatus = 2 WHERE UserId = @D;
        INSERT INTO @T VALUES ('AccountStatus = 2 is refused', 'Error 547', 'No error');
    END TRY
    BEGIN CATCH
        INSERT INTO @T VALUES ('AccountStatus = 2 is refused', 'Error 547', 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)));
    END CATCH

    BEGIN TRY
        UPDATE Users SET AccountStatus = NULL WHERE UserId = @D;
        INSERT INTO @T VALUES ('AccountStatus = NULL is refused', 'Error 515', 'No error');
    END TRY
    BEGIN CATCH
        INSERT INTO @T VALUES ('AccountStatus = NULL is refused', 'Error 515', 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)));
    END CATCH

    ---------------------------------------------------------------------------
    -- Acting user must exist and be active (Reason 8)
    ---------------------------------------------------------------------------
    UPDATE Users SET AccountStatus = 0 WHERE UserId IN (@A2, @C2);

    INSERT INTO @T SELECT 'Function: active Admin edits a User', '0', CAST(dbo.fn_UserChangeRefusal(@A1, @U, 'Edit', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function: inactive Admin edits a User', '8', CAST(dbo.fn_UserChangeRefusal(@A2, @U, 'Edit', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function: inactive Admin deletes a User', '8', CAST(dbo.fn_UserChangeRefusal(@A2, @U, 'Delete', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function: inactive Admin edits own details', '8', CAST(dbo.fn_UserChangeRefusal(@A2, @A2, 'Edit', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function: inactive Controller deactivates a User', '8', CAST(dbo.fn_UserChangeRefusal(@C2, @U, 'Deactivate', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function: unknown acting user', '8', CAST(dbo.fn_UserChangeRefusal(@Missing, @U, 'Edit', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function: acting user 0', '8', CAST(dbo.fn_UserChangeRefusal(0, @U, 'Edit', NULL) AS VARCHAR(2));

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @U, @AccountStatus = 0, @ActingUserId = @A2;
    INSERT INTO @T SELECT 'Inactive Admin deactivates a User: refused', 'Result 0, Reason 8, user still 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', user still ' + (SELECT CAST(AccountStatus AS VARCHAR(2)) FROM Users WHERE UserId = @U) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @U, @ActingUserId = @A2;
    INSERT INTO @T SELECT 'Inactive Admin deletes a User: refused', 'Result 0, Reason 8',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    UPDATE Users SET AccountStatus = 1 WHERE UserId IN (@A2, @C2);

    ---------------------------------------------------------------------------
    -- Deactivate / activate (spr_SetUserStatusByUserId)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @U, @AccountStatus = 0, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Admin deactivates a User', 'Result 1, status 0, updated by Admin',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', status ' + (SELECT CAST(AccountStatus AS VARCHAR(2)) FROM Users WHERE UserId = @U)
           + CASE WHEN (SELECT UpdatedBy FROM Users WHERE UserId = @U) = @A1 THEN ', updated by Admin' ELSE ', updated by someone else' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @U, @AccountStatus = 1, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Admin activates the User again', 'Result 1, status 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', status ' + (SELECT CAST(AccountStatus AS VARCHAR(2)) FROM Users WHERE UserId = @U) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @A2, @AccountStatus = 0, @ActingUserId = @C1;
    INSERT INTO @T SELECT 'Controller deactivates an Admin', 'Result 0, Reason 4',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @U, @AccountStatus = 0, @ActingUserId = @C1;
    INSERT INTO @T SELECT 'Controller deactivates a User', 'Result 1, Reason 0',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @U, @AccountStatus = 1, @ActingUserId = @C1;
    INSERT INTO @T SELECT 'Controller activates a User', 'Result 1, Reason 0',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @A1, @AccountStatus = 0, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Admin deactivates own account', 'Result 0, Reason 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @U, @AccountStatus = 0, @ActingUserId = @M;
    INSERT INTO @T SELECT 'Manager deactivates a User', 'Result 0, Reason 4',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    SAVE TRANSACTION MgrDeactivate;
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @M, @AccountStatus = 0, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Admin deactivates a Manager who manages a user', 'Result 1, user keeps the manager',
           'Result ' + CAST(Result AS VARCHAR(2))
           + CASE WHEN (SELECT ManagerId FROM Users WHERE UserId = @U) = @M THEN ', user keeps the manager' ELSE ', manager changed' END FROM @R;
    ROLLBACK TRANSACTION MgrDeactivate;

    SAVE TRANSACTION LastController;
    UPDATE Users SET AccountStatus = 0 WHERE RoleId = @rCtl AND UserId <> @C1;
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @C1, @AccountStatus = 0, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Last active Controller: deactivate', 'Result 0, Reason 3',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;
    ROLLBACK TRANSACTION LastController;

    ---------------------------------------------------------------------------
    -- spr_GetUserListForUserPage
    ---------------------------------------------------------------------------
    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @A1;

    INSERT INTO @T SELECT 'List: Status of active / inactive User', 'Active / Inactive',
           ISNULL((SELECT Status FROM #List WHERE UserId = @U), 'row missing') + ' / ' + ISNULL((SELECT Status FROM #List WHERE UserId = @U2), 'row missing');
    INSERT INTO @T SELECT 'List (Admin): active User CanDeactivate / CanActivate', '1 0',
           ISNULL((SELECT CAST(CanDeactivate AS VARCHAR(1)) + ' ' + CAST(CanActivate AS VARCHAR(1)) FROM #List WHERE UserId = @U), 'row missing');
    INSERT INTO @T SELECT 'List (Admin): inactive User CanDeactivate / CanActivate', '0 1',
           ISNULL((SELECT CAST(CanDeactivate AS VARCHAR(1)) + ' ' + CAST(CanActivate AS VARCHAR(1)) FROM #List WHERE UserId = @U2), 'row missing');
    INSERT INTO @T SELECT 'List (Admin): own row CanDeactivate / CanActivate', '0 0',
           ISNULL((SELECT CAST(CanDeactivate AS VARCHAR(1)) + ' ' + CAST(CanActivate AS VARCHAR(1)) FROM #List WHERE UserId = @A1), 'row missing');
    INSERT INTO @T SELECT 'List: ManagedCount counts active managed users only', '1',
           ISNULL((SELECT CAST(ManagedCount AS VARCHAR(12)) FROM #List WHERE UserId = @M), 'row missing');
    INSERT INTO @T SELECT 'List: ManagedCount of a user who manages nobody', '0',
           ISNULL((SELECT CAST(ManagedCount AS VARCHAR(12)) FROM #List WHERE UserId = @U), 'row missing');

    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @C1;
    INSERT INTO @T SELECT 'List (Controller): Admin row CanDeactivate', '0',
           ISNULL((SELECT CAST(CanDeactivate AS VARCHAR(1)) FROM #List WHERE UserId = @A2), 'row missing');
    INSERT INTO @T SELECT 'List (Controller): User row CanDeactivate', '1',
           ISNULL((SELECT CAST(CanDeactivate AS VARCHAR(1)) FROM #List WHERE UserId = @U), 'row missing');

    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @M;
    INSERT INTO @T SELECT 'List (Manager): rows with Deactivate / Activate allowed', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM #List WHERE CanDeactivate = 1 OR CanActivate = 1;

    UPDATE Users SET AccountStatus = 0 WHERE UserId = @A2;
    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @A2;
    INSERT INTO @T SELECT 'List (inactive Admin): rows with any flag', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM #List
           WHERE CanEdit = 1 OR CanChangeRole = 1 OR CanDelete = 1 OR CanDeactivate = 1 OR CanActivate = 1;
    UPDATE Users SET AccountStatus = 1 WHERE UserId = @A2;

    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = 0;
    INSERT INTO @T SELECT 'List (acting user 0): rows with any flag', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM #List
           WHERE CanEdit = 1 OR CanChangeRole = 1 OR CanDelete = 1 OR CanDeactivate = 1 OR CanActivate = 1;

    ---------------------------------------------------------------------------
    -- spr_GetActiveUserList and spr_GetUser
    ---------------------------------------------------------------------------
    DELETE FROM #V; INSERT INTO #V EXEC spr_GetActiveUserList;
    INSERT INTO @T SELECT 'Active list: active User in, inactive User out', '1 0',
           CAST((SELECT COUNT(*) FROM #V WHERE UserId = @U) AS VARCHAR(2)) + ' ' + CAST((SELECT COUNT(*) FROM #V WHERE UserId = @U2) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Active list: rows that are not active', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM #V WHERE AccountStatus <> 1;
    -- Step 18 replaces the admin-name filter: the system account is left out by IsSystem
    IF (@SystemUser IS NULL)
        INSERT INTO @T SELECT 'Active list: keeps the admin-name filter', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM #V WHERE UserName LIKE 'admin';
    ELSE
        INSERT INTO @T SELECT 'Active list: leaves out the system account [step 18]', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM #V WHERE UserId = @SystemUser;
    SET @Rows = (SELECT COUNT(*) FROM #V);

    DELETE FROM #V; INSERT INTO #V EXEC spr_GetUser;
    INSERT INTO @T SELECT 'spr_GetUser: still lists the inactive User', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM #V WHERE UserId = @U2;
    INSERT INTO @T SELECT 'Active list = spr_GetUser rows that are active'
                          + CASE WHEN @SystemUser IS NOT NULL THEN ' [step 18: other than the system account]' ELSE '' END,
           CAST(@Rows AS VARCHAR(12)),
           CAST(COUNT(*) AS VARCHAR(12)) FROM #V WHERE AccountStatus = 1 AND UserId <> ISNULL(@SystemUser, -1);

    ---------------------------------------------------------------------------
    -- spr_GetMgrControllerByDeptId
    ---------------------------------------------------------------------------
    DELETE FROM #Mgr; INSERT INTO #Mgr EXEC spr_GetMgrControllerByDeptId @DepartmentId = @Dept1;
    INSERT INTO @T SELECT 'Manager list: active Manager in, inactive Manager out', '1 0',
           CAST((SELECT COUNT(*) FROM #Mgr WHERE UserId = @M) AS VARCHAR(2)) + ' ' + CAST((SELECT COUNT(*) FROM #Mgr WHERE UserId = @M2) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Manager list: rows that are not active', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM #Mgr WHERE AccountStatus <> 1;
    INSERT INTO @T SELECT 'Manager list: ManagerText of an active Manager', 'zzstatm', ISNULL((SELECT ManagerText FROM #Mgr WHERE UserId = @M), 'row missing');
    INSERT INTO @T SELECT 'Manager list: Users are not offered', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM #Mgr WHERE UserId = @U;
    SET @Rows = (SELECT COUNT(*) FROM #Mgr);

    DELETE FROM #Mgr; INSERT INTO #Mgr EXEC spr_GetMgrControllerByDeptId @DepartmentId = @Dept1, @IncludeUserId = @M2;
    INSERT INTO @T SELECT 'Manager list with the current (inactive) manager: included', 'zzstatm2 (inactive)',
           ISNULL((SELECT ManagerText FROM #Mgr WHERE UserId = @M2), 'row missing');
    INSERT INTO @T SELECT 'Manager list with the current manager: one extra row', CAST(@Rows + 1 AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12)) FROM #Mgr;

    DELETE FROM #Mgr; INSERT INTO #Mgr EXEC spr_GetMgrControllerByDeptId @DepartmentId = @Dept1, @IncludeUserId = @M;
    INSERT INTO @T SELECT 'Manager list with an active current manager: no duplicate', CAST(@Rows AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12)) FROM #Mgr;

    ---------------------------------------------------------------------------
    -- spr_GetUserStatusByUserId
    ---------------------------------------------------------------------------
    DELETE FROM #St; INSERT INTO #St EXEC spr_GetUserStatusByUserId @UserId = @U;
    INSERT INTO @T SELECT 'Status lookup: active User', '1', ISNULL((SELECT CAST(AccountStatus AS VARCHAR(2)) FROM #St), 'no row');
    DELETE FROM #St; INSERT INTO #St EXEC spr_GetUserStatusByUserId @UserId = @U2;
    INSERT INTO @T SELECT 'Status lookup: inactive User', '0', ISNULL((SELECT CAST(AccountStatus AS VARCHAR(2)) FROM #St), 'no row');
    DELETE FROM #St; INSERT INTO #St EXEC spr_GetUserStatusByUserId @UserId = @Missing;
    INSERT INTO @T SELECT 'Status lookup: unknown user', '0 rows', CAST(COUNT(*) AS VARCHAR(12)) + ' rows' FROM #St;

    ---------------------------------------------------------------------------
    -- spr_LockUserByUserId is retired
    ---------------------------------------------------------------------------
    BEGIN TRY
        EXEC spr_LockUserByUserId @UserId = @U;
        SET @Text = 'No error';
    END TRY
    BEGIN CATCH
        SET @Text = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12));
    END CATCH
    INSERT INTO @T SELECT 'spr_LockUserByUserId: refused, user unchanged', 'Error 50002, status 1',
           @Text + ', status ' + (SELECT CAST(AccountStatus AS VARCHAR(2)) FROM Users WHERE UserId = @U);

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

Report:

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM @T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual <> Expected THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM @T;

-- Confirm nothing was kept: should be 0.
SELECT COUNT(*) AS TestUsersLeft FROM Users WHERE LoginName LIKE 'zzstat%';

DROP TABLE #V;
DROP TABLE #List;
DROP TABLE #Mgr;
DROP TABLE #St;
GO

SET NOEXEC OFF;
GO
