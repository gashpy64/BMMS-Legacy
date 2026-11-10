/* ============================================================================
   BMMS - Tests for BMMS-Fix-RoleAccess-Step40.sql (step 40, step RA1a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   TEST DATABASE ONLY. It refuses to run in a database named exactly "BMMS".
   Run it AFTER BMMS-Fix-RoleAccess-Step40.sql; it stops if step 40 is not
   installed.

   Part 1, read only: the markers of step 40 and the older markers kept
   (steps 13, 14, 18 and 21), the parameters unchanged, no THROW left in the
   two member type procedures.

   Part 2, inside one transaction that is ROLLED BACK, with made-up users, a
   department and a member type (ZZ40...):
     * fn_UserChangeRefusal: a Controller is refused (Reason 4) on Create, on
       Edit, RoleChange, Deactivate, Activate, Delete and ResetPassword of
       another account, also of a User; it may Edit and ResetPassword its own
       account; Delete of its own account stays Reason 1 and ResetPassword of
       the system account stays Reason 7; an inactive Controller is Reason 8;
       an Admin may do all of these to a User and to a Controller; a Manager
       is refused as before
     * through the procedures: spr_CheckUserChange, spr_ResetPasswordByUserId
       (another user refused and the password unchanged; the Controller's own
       password changed; an Admin allowed), spr_SetUserStatusByUserId and
       spr_DeleteUserByUserId refuse a Controller with Reason 4 and change
       nothing
     * the User Master list (spr_GetUserListForUserPage) seen by a Controller:
       on the Manager, User and Management rows CanEdit, CanChangeRole,
       CanDelete and CanDeactivate are all 0; on its own row only CanEdit;
       an Admin sees 1 on the User row
     * member types: a Controller's Save and Delete are refused (Reason 4,
       nothing written); an Admin's Save and Delete work; a Manager (4) and an
       inactive Controller (8) are refused as before
     * rows outside the test are unchanged after the rollback, and every
       identity counter is put back

   Result: one grid, one row per check. Status should be PASS for every row.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%RoleAccess-Step40%')
BEGIN
    RAISERROR('Step 40 (BMMS-Fix-RoleAccess-Step40.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#List') IS NOT NULL DROP TABLE #List;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- spr_GetUserListForUserPage: View_Users plus the flags (as BMMS-Test-UserStatus-Stage2a.sql)
SELECT TOP 0 v.*, CAST(NULL AS INT) AS CanEdit, CAST(NULL AS INT) AS CanChangeRole, CAST(NULL AS INT) AS CanDelete,
       CAST(NULL AS VARCHAR(10)) AS Status, CAST(NULL AS INT) AS CanDeactivate, CAST(NULL AS INT) AS CanActivate, CAST(NULL AS INT) AS ManagedCount
INTO #List FROM View_Users v;

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T SELECT 'Marker RoleAccess-Step40 in fn_UserChangeRefusal, spr_AddEditMemberType, spr_DeleteMemberTypeByMemberTypeId', '3',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%RoleAccess-Step40%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')) LIKE '%RoleAccess-Step40%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')) LIKE '%RoleAccess-Step40%' THEN 1 ELSE 0 END AS VARCHAR(12));
INSERT INTO #T SELECT 'Older markers kept: steps 13, 14 and 18 in the function, step 21 in both procedures', '5',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%UserProtection-Stage1%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%UserStatus-Stage2a%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%SystemAccount3-Step18%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')) LIKE '%MemberTypes-Step21%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')) LIKE '%MemberTypes-Step21%' THEN 1 ELSE 0 END AS VARCHAR(12));
INSERT INTO #T SELECT 'The Controller branch is gone from fn_UserChangeRefusal', '0',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%@ActingRole = ''controller''%' THEN 1 ELSE 0 END AS VARCHAR(12));
INSERT INTO #T SELECT 'Parameters unchanged: fn_UserChangeRefusal 4, spr_AddEditMemberType 12, spr_DeleteMemberTypeByMemberTypeId 2', '4 12 2',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_UserChangeRefusal') AND parameter_id > 0) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditMemberType')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')) AS VARCHAR(12));
INSERT INTO #T SELECT 'No THROW left in the two member type procedures', '0',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')) LIKE '%THROW%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')) LIKE '%THROW%' THEN 1 ELSE 0 END AS VARCHAR(12));
GO

-------------------------------------------------------------------------------
-- Part 2: the rules, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @Dept INT, @Adm INT, @Ctl INT, @CtlOff INT, @Mgr INT, @Usr INT, @Gmt INT, @Mt INT;
DECLARE @Txt VARCHAR(400);
DECLARE @UsersBefore VARCHAR(60), @UsersAfter VARCHAR(60), @TypesBefore VARCHAR(60), @TypesAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @Desig IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role (admin, controller, manager, user, mgmt) or a designation is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

-- Rows outside the test, before
SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, [Password], UpdatedBy)), 0) AS VARCHAR(12)) FROM Users;
SELECT @TypesBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MemberTypeId, MemberTypeCode, MemberTypeName, StatusId, MemberScope, DisplayOrder)), 0) AS VARCHAR(12)) FROM Member_Type;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names). Users inserted directly have no history rows.
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ40D', 'ZZ step 40 department', 990, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ40 admin', @Dept, @Desig, NULL, @rAdmin, 'zz40a@example.invalid', 'zz40adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ40 controller', @Dept, @Desig, NULL, @rCtl, 'zz40c@example.invalid', 'zz40ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ40 controller inactive', @Dept, @Desig, NULL, @rCtl, 'zz40i@example.invalid', 'zz40off', 'not-a-login', 0, @Now);
    SET @CtlOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ40 manager', @Dept, @Desig, NULL, @rMgr, 'zz40m@example.invalid', 'zz40mgr', 'not-a-login', 1, @Now);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ40 user', @Dept, @Desig, @Mgr, @rUser, 'zz40u@example.invalid', 'zz40usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ40 management', @Dept, @Desig, NULL, @rMgmt, 'zz40g@example.invalid', 'zz40gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- fn_UserChangeRefusal: the Controller
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Controller: Create a user', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, NULL, 'Create', @rUser) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: Edit a User', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Usr, 'Edit', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: give a User the Manager role', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Usr, 'RoleChange', @rMgr) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: Deactivate a User', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Usr, 'Deactivate', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: Activate a user (the inactive Controller)', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, @CtlOff, 'Activate', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: Delete a User', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Usr, 'Delete', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: ResetPassword of a User', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Usr, 'ResetPassword', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: Edit a Manager', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Mgr, 'Edit', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: Edit an Admin (refused before step 40 too)', '4', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Adm, 'Edit', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: Edit its own account', '0', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Ctl, 'Edit', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: ResetPassword of its own account (Change Password)', '0', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Ctl, 'ResetPassword', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: Delete its own account (rule 1, unchanged)', '1', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Ctl, 'Delete', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller: ResetPassword of the system account (rule 7, unchanged)', '7', CAST(dbo.fn_UserChangeRefusal(@Ctl, @Sys, 'ResetPassword', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Inactive Controller: Edit its own account (Reason 8, unchanged)', '8', CAST(dbo.fn_UserChangeRefusal(@CtlOff, @CtlOff, 'Edit', NULL) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- fn_UserChangeRefusal: Admin and Manager (unchanged)
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Admin: Create, Edit, RoleChange, Deactivate, Delete, ResetPassword of a User', '0 0 0 0 0 0',
           CAST(dbo.fn_UserChangeRefusal(@Adm, NULL, 'Create', @rUser) AS VARCHAR(12)) + ' '
         + CAST(dbo.fn_UserChangeRefusal(@Adm, @Usr, 'Edit', NULL) AS VARCHAR(12)) + ' '
         + CAST(dbo.fn_UserChangeRefusal(@Adm, @Usr, 'RoleChange', @rMgr) AS VARCHAR(12)) + ' '
         + CAST(dbo.fn_UserChangeRefusal(@Adm, @Usr, 'Deactivate', NULL) AS VARCHAR(12)) + ' '
         + CAST(dbo.fn_UserChangeRefusal(@Adm, @Usr, 'Delete', NULL) AS VARCHAR(12)) + ' '
         + CAST(dbo.fn_UserChangeRefusal(@Adm, @Usr, 'ResetPassword', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Admin: Edit and ResetPassword of a Controller, Activate the inactive Controller', '0 0 0',
           CAST(dbo.fn_UserChangeRefusal(@Adm, @Ctl, 'Edit', NULL) AS VARCHAR(12)) + ' '
         + CAST(dbo.fn_UserChangeRefusal(@Adm, @Ctl, 'ResetPassword', NULL) AS VARCHAR(12)) + ' '
         + CAST(dbo.fn_UserChangeRefusal(@Adm, @CtlOff, 'Activate', NULL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Manager: Edit a User, ResetPassword of a User (refused, unchanged)', '4 4',
           CAST(dbo.fn_UserChangeRefusal(@Mgr, @Usr, 'Edit', NULL) AS VARCHAR(12)) + ' '
         + CAST(dbo.fn_UserChangeRefusal(@Mgr, @Usr, 'ResetPassword', NULL) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The user procedures, called as the pages call them
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @Ctl, @TargetUserId = @Usr, @Action = 'Edit', @NewRoleId = NULL;
    INSERT INTO @T SELECT 'spr_CheckUserChange: Controller edits a User', 'Result 0, Reason 4',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R);

    DELETE FROM @R; INSERT INTO @R EXEC spr_ResetPasswordByUserId @UserId = @Usr, @Password = 'zz40-reset-by-controller', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'spr_ResetPasswordByUserId: Controller resets a User; the password is unchanged', 'Result 0, Reason 4 | unchanged',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CASE WHEN (SELECT [Password] FROM Users WHERE UserId = @Usr) = 'not-a-login' THEN 'unchanged' ELSE 'changed' END;

    DELETE FROM @R; INSERT INTO @R EXEC spr_ResetPasswordByUserId @UserId = @Ctl, @Password = 'zz40-own', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'spr_ResetPasswordByUserId: Controller changes its own password', 'Result 1, Reason 0 | changed',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CASE WHEN (SELECT [Password] FROM Users WHERE UserId = @Ctl) = 'zz40-own' THEN 'changed' ELSE 'unchanged' END;

    DELETE FROM @R; INSERT INTO @R EXEC spr_ResetPasswordByUserId @UserId = @Usr, @Password = 'zz40-reset-by-admin', @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'spr_ResetPasswordByUserId: Admin resets a User', 'Result 1, Reason 0 | changed',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CASE WHEN (SELECT [Password] FROM Users WHERE UserId = @Usr) = 'zz40-reset-by-admin' THEN 'changed' ELSE 'unchanged' END;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Mgr, @AccountStatus = 0, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'spr_SetUserStatusByUserId: Controller deactivates a Manager; still active', 'Result 0, Reason 4 | 1',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CAST((SELECT AccountStatus FROM Users WHERE UserId = @Mgr) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Usr, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'spr_DeleteUserByUserId: Controller deletes a User; the user is still there', 'Result 0, Reason 4 | 1',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CAST((SELECT COUNT(*) FROM Users WHERE UserId = @Usr) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The User Master list: the flags a Controller and an Admin see
    -- (CanEdit, CanChangeRole, CanDelete, CanDeactivate)
    ---------------------------------------------------------------------------
    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'List for a Controller: Manager row', '0 0 0 0',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) + ' ' + CAST(CanDeactivate AS VARCHAR(1)) FROM #List WHERE UserId = @Mgr), 'row missing');
    INSERT INTO @T SELECT 'List for a Controller: User row', '0 0 0 0',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) + ' ' + CAST(CanDeactivate AS VARCHAR(1)) FROM #List WHERE UserId = @Usr), 'row missing');
    INSERT INTO @T SELECT 'List for a Controller: Management row', '0 0 0 0',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) + ' ' + CAST(CanDeactivate AS VARCHAR(1)) FROM #List WHERE UserId = @Gmt), 'row missing');
    INSERT INTO @T SELECT 'List for a Controller: own row (edit only)', '1 0 0 0',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) + ' ' + CAST(CanDeactivate AS VARCHAR(1)) FROM #List WHERE UserId = @Ctl), 'row missing');
    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'List for an Admin: User row (unchanged)', '1 1 1 1',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) + ' ' + CAST(CanDeactivate AS VARCHAR(1)) FROM #List WHERE UserId = @Usr), 'row missing');

    ---------------------------------------------------------------------------
    -- Member types
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0, @MemberTypeCode = N'ZZ40', @MemberTypeName = N'ZZ step 40 type',
         @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 99, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Member type Save by a Controller: refused, nothing written', 'Result 0, Reason 4 | 0',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CAST((SELECT COUNT(*) FROM Member_Type WHERE MemberTypeCode = 'ZZ40') AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0, @MemberTypeCode = N'ZZ40', @MemberTypeName = N'ZZ step 40 type',
         @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 99, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Member type Save by a Manager: refused (unchanged)', 'Result 0, Reason 4',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R);

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0, @MemberTypeCode = N'ZZ40', @MemberTypeName = N'ZZ step 40 type',
         @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 99, @ActingUserId = @CtlOff;
    INSERT INTO @T SELECT 'Member type Save by an inactive Controller: Reason 8 (unchanged)', 'Result 0, Reason 8',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R);

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0, @MemberTypeCode = N'ZZ40', @MemberTypeName = N'ZZ step 40 type',
         @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 99, @ActingUserId = @Adm;
    SET @Mt = (SELECT TOP 1 MemberTypeId FROM Member_Type WHERE MemberTypeCode = 'ZZ40' ORDER BY MemberTypeId);
    INSERT INTO @T SELECT 'Member type Save by an Admin: saved', 'Result 1, Reason 0 | 1',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CAST((SELECT COUNT(*) FROM Member_Type WHERE MemberTypeCode = 'ZZ40') AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @Mt, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Member type Delete by a Controller: refused, the type stays', 'Result 0, Reason 4 | 1',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CAST((SELECT COUNT(*) FROM Member_Type WHERE MemberTypeId = @Mt) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @Mt, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Member type Delete by an Admin: deleted', 'Result 1, Reason 0 | 0',
           (SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R)
         + ' | ' + CAST((SELECT COUNT(*) FROM Member_Type WHERE MemberTypeId = @Mt) AS VARCHAR(12));

END TRY
BEGIN CATCH
    SET @Txt = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error', @Txt);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, [Password], UpdatedBy)), 0) AS VARCHAR(12)) FROM Users;
SELECT @TypesAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MemberTypeId, MemberTypeCode, MemberTypeName, StatusId, MemberScope, DisplayOrder)), 0) AS VARCHAR(12)) FROM Member_Type;
INSERT INTO @T SELECT 'After the rollback: Users unchanged (count, checksum)', @UsersBefore, @UsersAfter;
INSERT INTO @T SELECT 'After the rollback: Member_Type unchanged (count, checksum)', @TypesBefore, @TypesAfter;

Report:

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
SELECT 'After the test: no ZZ40 department, user or member type left', '0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ40%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz40%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Member_Type WHERE MemberTypeCode LIKE 'ZZ40%') AS VARCHAR(12));

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

DROP TABLE #List;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
