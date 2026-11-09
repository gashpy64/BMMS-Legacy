/* ============================================================================
   BMMS - Tests for BMMS-Fix-UserHistory-Step39.sql (step 39, step UD1a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   TEST DATABASE ONLY. Part 3 EXECUTES spr_sys_ResetDatabase inside a
   transaction that is rolled back. It refuses to run in a database named
   exactly "BMMS". Run it AFTER BMMS-Fix-UserHistory-Step39.sql; it stops if
   step 39 is not installed.

   Part 1, read only: the markers, the texts kept, the parameters, the tables
   and indexes, the setting row, and the migrated rows of this database (every
   active user one open role row and one open home department row that agree
   with Users; an inactive user no open row but a closed one; nobody but a
   Manager with more than one open department).

   Part 2, inside one transaction that is ROLLED BACK, with made-up users and
   departments (ZZ39...):
     * Add a Manager with two departments; Edit adds and removes one; a change
       of the home department closes and reopens the two rows
     * refused with Reason 23: home department not ticked, several departments
       for a User, a list that is not digits and commas, an id too long, an
       unknown and an inactive department; nothing is created
     * rule 12: removing the department of which he is the last active Manager
       with an item waiting is refused (Reason 24, the department named); a
       role change away from Manager is refused for the department and for
       the item routed to him, then for the item alone once a second Manager
       is mapped, then allowed once the item is routed elsewhere: his other
       department closed (R), ReasonDetail MappingsClosed; an Edit that removes
       a department is not refused for items routed to him
     * an older caller (no @DepartmentIds) keeps the Manager's mappings
     * Deactivate closes every row (D); Activate reopens them, skips a
       department that is inactive now (NotRestored) and is refused while the
       home department is inactive (Reason 23, HomeDepartmentInactive)
     * Delete: an unused user goes with his rows; a Manager whose only
       footprint is his own history goes with it; a user whose only footprint
       is rows written for another user is refused (Reason 6, user changes)
     * Department delete: refused while mapped (Reason 25, Mapped:<name>), with
       only closed mappings (Reason 25, History), as before for a home
       department (Reason 5); an unused department is deleted
     * the protected system account: Edit refused (Reason 7), no row written
     * the setting DeptNoManagerAction: an Admin sets controller (one audit
       row), the same value again writes none; a bad value (3), a Manager (4)
       and acting user 0 (8) are refused
     * rows outside the test are unchanged after the rollback

   Part 3, rolled back: Reset Database seeds one open role row and one open
   home department row per seed user. Every identity counter is put back
   afterwards, as in BMMS-Test-ResetDatabase.sql.

   Result: one grid, one row per check. Status should be PASS for every row.

   It has no USE line: select the TEST database in SSMS first. Written for
   compatibility level 100. Plain ASCII. QUOTED_IDENTIFIER and ANSI_NULLS ON
   (the filtered indexes need them; sqlcmd -I).
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
    RAISERROR('Current database is "%s". This test runs spr_sys_ResetDatabase and is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%UserHistory-Step39%'
         OR OBJECT_ID('dbo.User_Role', 'U') IS NULL OR OBJECT_ID('dbo.User_Department', 'U') IS NULL)
BEGIN
    RAISERROR('Step 39 (BMMS-Fix-UserHistory-Step39.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#ZZ39_Save') IS NOT NULL DROP PROCEDURE #ZZ39_Save;
IF OBJECT_ID('tempdb..#ZZ39_Edit') IS NOT NULL DROP PROCEDURE #ZZ39_Edit;
IF OBJECT_ID('tempdb..#ZZ39_State') IS NOT NULL DROP PROCEDURE #ZZ39_State;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- Every identity counter before the test (put back after part 3)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-- Add a user through spr_AddEditUser; @PassList 0 calls it as an older build does (no @DepartmentIds)
CREATE PROCEDURE #ZZ39_Save
    @UserName VARCHAR(50), @LoginName VARCHAR(50), @RoleId INT, @DepartmentId INT, @ManagerId INT,
    @List VARCHAR(MAX), @PassList BIT, @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);

    IF (@PassList = 1)
        EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = @UserName, @DepartmentId = @DepartmentId,
             @DesignationId = @Desig, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = 'zz39@example.invalid',
             @LoginName = @LoginName, @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = @Actor,
             @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
    ELSE
        EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = @UserName, @DepartmentId = @DepartmentId,
             @DesignationId = @Desig, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = 'zz39@example.invalid',
             @LoginName = @LoginName, @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = @Actor,
             @UpdatedOn = @Now, @UpdatedBy = @Actor;
END
GO

-- Edit a user through spr_AddEditUser: the stored values, with the role, home department, list and e-mail given
CREATE PROCEDURE #ZZ39_Edit
    @UserId INT, @RoleId INT, @DepartmentId INT, @List VARCHAR(MAX), @PassList BIT, @Actor INT, @EmailId VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @UserName VARCHAR(50), @DesignationId INT, @ManagerId INT, @Mail VARCHAR(50), @LoginName VARCHAR(50);

    SELECT @UserName = UserName, @DesignationId = DesignationId, @ManagerId = ManagerId, @Mail = EmailId, @LoginName = LoginName
    FROM Users WHERE UserId = @UserId;
    SET @Mail = ISNULL(@EmailId, @Mail);

    IF (@PassList = 1)
        EXEC spr_AddEditUser @Code = 'Update', @UserId = @UserId, @UserName = @UserName, @DepartmentId = @DepartmentId,
             @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @Mail,
             @LoginName = @LoginName, @Password = '', @CreatedOn = @Now, @CreatedBy = @Actor,
             @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
    ELSE
        EXEC spr_AddEditUser @Code = 'Update', @UserId = @UserId, @UserName = @UserName, @DepartmentId = @DepartmentId,
             @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @Mail,
             @LoginName = @LoginName, @Password = '', @CreatedOn = @Now, @CreatedBy = @Actor,
             @UpdatedOn = @Now, @UpdatedBy = @Actor;
END
GO

-- A user's history as text: "role <open role code>; open <department codes, * = home>; closed <C>/<D>/<R>"
CREATE PROCEDURE #ZZ39_State
    @UserId INT, @Text VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Text = 'role ' + ISNULL((SELECT TOP 1 r.RoleCode FROM User_Role ur JOIN Roles r ON r.RoleId = ur.RoleId
                                  WHERE ur.UserId = @UserId AND ur.EffectiveTo IS NULL), '-')
              + '; open ' + ISNULL(STUFF((SELECT ',' + d.DepartmentCode + CASE WHEN ud.IsHome = 1 THEN '*' ELSE '' END
                                          FROM User_Department ud JOIN Department d ON d.DepartmentId = ud.DepartmentId
                                          WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL
                                          ORDER BY d.DepartmentCode
                                          FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), '-')
              + '; closed ' + CAST((SELECT COUNT(*) FROM User_Department WHERE UserId = @UserId AND CloseReason = 'C') AS VARCHAR(12))
              + '/' + CAST((SELECT COUNT(*) FROM User_Department WHERE UserId = @UserId AND CloseReason = 'D') AS VARCHAR(12))
              + '/' + CAST((SELECT COUNT(*) FROM User_Department WHERE UserId = @UserId AND CloseReason = 'R') AS VARCHAR(12));
END
GO

-------------------------------------------------------------------------------
-- Part 1: installation and the migrated rows (read only)
-------------------------------------------------------------------------------
DECLARE @Manager INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);

INSERT INTO #T SELECT 'Marker UserHistory-Step39 on the 8 objects', '8',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_ManagerReleaseRefusal'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId'),
                                          ('spr_DeleteUserByUserId'), ('spr_DeleteDepartmentByDeptId'), ('spr_sys_ResetDatabase'),
                                          ('spr_GetUserDepartmentMap'), ('spr_SetDepartmentManagerRule')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UserHistory-Step39%') AS VARCHAR(12));
INSERT INTO #T SELECT 'Texts kept: Stage1 (3 procedures), FK#5-UserDelete-AllColumns, steps 3, 18, 21, 29 (2) and 30 in the reset', '10',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')) LIKE '%UserProtection-Stage1%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetUserStatusByUserId')) LIKE '%UserProtection-Stage1%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')) LIKE '%UserProtection-Stage1%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')) LIKE '%FK#5-UserDelete-AllColumns%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%FK#5-ManagerId-NULL%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%SystemAccount3-Step18%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%MemberTypes-Step21%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%ResetSafe-Step29%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%DefaultPassword-Step29%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%SmtpDefault-Step30%' THEN 1 ELSE 0 END AS VARCHAR(12));
INSERT INTO #T SELECT 'spr_AddEditUser: the last parameter is @DepartmentIds varchar(max) with a default; 17 parameters', '@DepartmentIds varchar -1 17',
       ISNULL((SELECT TOP 1 name + ' ' + TYPE_NAME(user_type_id) + ' ' + CAST(max_length AS VARCHAR(12)) FROM sys.parameters
               WHERE object_id = OBJECT_ID('dbo.spr_AddEditUser') ORDER BY parameter_id DESC), 'none')
     + ' ' + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditUser')) AS VARCHAR(12));
INSERT INTO #T SELECT 'spr_DeleteUserByUserId 5 parameters, spr_sys_ResetDatabase 4, spr_SetUserStatusByUserId 5', '5 4 5',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_DeleteUserByUserId')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_sys_ResetDatabase')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_SetUserStatusByUserId')) AS VARCHAR(12));
INSERT INTO #T SELECT 'Filtered unique indexes: one open role row, one open row per department, one open home department', '3',
       CAST((SELECT COUNT(*) FROM sys.indexes WHERE is_unique = 1 AND has_filter = 1
             AND ((object_id = OBJECT_ID('dbo.User_Role') AND name = 'UX_User_Role_Open')
               OR (object_id = OBJECT_ID('dbo.User_Department') AND name IN ('UX_User_Department_Open', 'UX_User_Department_OpenHome')))) AS VARCHAR(12));
INSERT INTO #T SELECT 'Setting DeptNoManagerAction: one row, refuse or controller', '1 yes',
       CAST((SELECT COUNT(*) FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction') AS VARCHAR(12)) + ' '
     + CASE WHEN EXISTS (SELECT 1 FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction' AND SettingValue IN ('refuse', 'controller')) THEN 'yes' ELSE 'no' END;
INSERT INTO #T SELECT 'Migrated: active users without exactly one open role row equal to Users.RoleId', '0',
       CAST((SELECT COUNT(*) FROM Users u WHERE u.AccountStatus = 1
             AND (SELECT COUNT(*) FROM User_Role r WHERE r.UserId = u.UserId AND r.EffectiveTo IS NULL AND r.RoleId = u.RoleId) <> 1) AS VARCHAR(12));
INSERT INTO #T SELECT 'Migrated: active users without exactly one open home row equal to Users.DepartmentId', '0',
       CAST((SELECT COUNT(*) FROM Users u WHERE u.AccountStatus = 1
             AND (SELECT COUNT(*) FROM User_Department d WHERE d.UserId = u.UserId AND d.EffectiveTo IS NULL AND d.IsHome = 1
                  AND d.DepartmentId = u.DepartmentId) <> 1) AS VARCHAR(12));
INSERT INTO #T SELECT 'Migrated: inactive users with an open row, or without a row in each table', '0 0',
       CAST((SELECT COUNT(*) FROM Users u WHERE u.AccountStatus <> 1
             AND (EXISTS (SELECT 1 FROM User_Role r WHERE r.UserId = u.UserId AND r.EffectiveTo IS NULL)
               OR EXISTS (SELECT 1 FROM User_Department d WHERE d.UserId = u.UserId AND d.EffectiveTo IS NULL))) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users u WHERE u.AccountStatus <> 1
             AND (NOT EXISTS (SELECT 1 FROM User_Role r WHERE r.UserId = u.UserId)
               OR NOT EXISTS (SELECT 1 FROM User_Department d WHERE d.UserId = u.UserId))) AS VARCHAR(12));
INSERT INTO #T SELECT 'Migrated: users who are not Managers with more than one open department', '0',
       CAST((SELECT COUNT(*) FROM Users u WHERE u.RoleId <> ISNULL(@Manager, -1)
             AND (SELECT COUNT(*) FROM User_Department d WHERE d.UserId = u.UserId AND d.EffectiveTo IS NULL) > 1) AS VARCHAR(12));
GO

-------------------------------------------------------------------------------
-- Part 2: the rules, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(300)) ELSE '' END));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @Adm INT, @Adm2 INT, @M1 INT, @M2 INT, @U1 INT, @U2 INT, @U4 INT, @U5 INT;
DECLARE @DA INT, @DB INT, @DC INT, @DD INT, @DE INT, @DF INT, @DX INT;
DECLARE @C INT, @Mt INT, @Ag INT;
DECLARE @L VARCHAR(MAX), @S VARCHAR(400), @N1 INT, @N2 INT;
DECLARE @HistBefore VARCHAR(60), @HistAfter VARCHAR(60), @UsersBefore VARCHAR(60), @UsersAfter VARCHAR(60);
DECLARE @SetBefore VARCHAR(300), @SetAfter VARCHAR(300), @AudBefore VARCHAR(60), @AudAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @Desig IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role (admin, manager, user, mgmt), a designation or a subject type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

-- Rows outside the test, before
SELECT @HistBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistBefore = @HistBefore + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @SetBefore = ISNULL((SELECT SettingValue FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction'), 'none');
SELECT @AudBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(MAX(Audit_Trail_Maser_Id), 0) AS VARCHAR(12)) FROM Audit_Trail_Master;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names). Users inserted directly have no history rows.
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ39A', 'ZZ step 39 department A', 991, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ39B', 'ZZ step 39 department B', 992, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ39C', 'ZZ step 39 department C', 993, 1, @Now, @Sys);
    SET @DC = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ39D', 'ZZ step 39 department D', 994, 1, @Now, @Sys);
    SET @DD = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ39E', 'ZZ step 39 department E', 995, 1, @Now, @Sys);
    SET @DE = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ39F', 'ZZ step 39 department F', 996, 1, @Now, @Sys);
    SET @DF = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ39X', 'ZZ step 39 department X', 997, 0, @Now, @Sys);
    SET @DX = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ39 admin', @DA, @Desig, NULL, @rAdmin, 'zz39a@example.invalid', 'zz39adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ39 admin two', @DA, @Desig, NULL, @rAdmin, 'zz39b@example.invalid', 'zz39adm2', 'not-a-login', 1, @Now);
    SET @Adm2 = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z39', 'ZZ step 39 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99939', @C, 'ZZ39 test', 'ZZ', DATEADD(DAY, 10, CAST(CAST(GETDATE() AS DATE) AS DATETIME)), '10:00', CAST(CAST(GETDATE() AS DATE) AS DATETIME), 'Open', 'Open');
    SET @Mt = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- Add and Edit a Manager with several departments
    ---------------------------------------------------------------------------
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 manager one', @LoginName = 'zz39m1', @RoleId = @rMgr, @DepartmentId = @DA,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    SET @M1 = (SELECT UserId FROM Users WHERE LoginName = 'zz39m1');
    EXEC #ZZ39_State @UserId = @M1, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Add a Manager with departments A (home) and B', 'Result 1, Reason 0 | role manager; open ZZ39A*,ZZ39B; closed 0/0/0', (SELECT Txt FROM @R) + ' | ' + @S;

    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M1, @RoleId = @rMgr, @DepartmentId = @DA, @List = @L, @PassList = 1, @Actor = @Adm;
    EXEC #ZZ39_State @UserId = @M1, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Edit adds department C', 'Result 1, Reason 0 | role manager; open ZZ39A*,ZZ39B,ZZ39C; closed 0/0/0', (SELECT Txt FROM @R) + ' | ' + @S;

    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M1, @RoleId = @rMgr, @DepartmentId = @DA, @List = @L, @PassList = 1, @Actor = @Adm;
    EXEC #ZZ39_State @UserId = @M1, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Edit removes department B: closed today (C)', 'Result 1, Reason 0 | role manager; open ZZ39A*,ZZ39C; closed 1/0/0; B ends today', (SELECT Txt FROM @R) + ' | ' + @S
         + '; B ends ' + ISNULL((SELECT CASE WHEN EffectiveTo = CAST(GETDATE() AS DATE) THEN 'today' ELSE CONVERT(VARCHAR(10), EffectiveTo, 120) END
                                 FROM User_Department WHERE UserId = @M1 AND DepartmentId = @DB), 'never');

    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M1, @RoleId = @rMgr, @DepartmentId = @DC, @List = @L, @PassList = 1, @Actor = @Adm;
    EXEC #ZZ39_State @UserId = @M1, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Edit makes C the home department: both rows closed and reopened', 'Result 1, Reason 0 | role manager; open ZZ39A,ZZ39C*; closed 3/0/0; Users home C',
           (SELECT Txt FROM @R) + ' | ' + @S + '; Users home ' + CASE WHEN (SELECT DepartmentId FROM Users WHERE UserId = @M1) = @DC THEN 'C' ELSE 'not C' END;

    ---------------------------------------------------------------------------
    -- Reason 23: the list (nothing is created)
    ---------------------------------------------------------------------------
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 refused', @LoginName = 'zz39no', @RoleId = @rMgr, @DepartmentId = @DC,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'Manager whose home department C is not in the list (A, B)', 'Result 0, Reason 23, HomeNotTicked', (SELECT Txt FROM @R);
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 refused', @LoginName = 'zz39no', @RoleId = @rUser, @DepartmentId = @DA,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'User with two departments', 'Result 0, Reason 23, OneDepartmentOnly', (SELECT Txt FROM @R);
    SET @L = CAST(@DA AS VARCHAR(12)) + ',,' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 refused', @LoginName = 'zz39no', @RoleId = @rMgr, @DepartmentId = @DA,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'List with an empty item (A,,B)', 'Result 0, Reason 23, ListNotValid', (SELECT Txt FROM @R);
    SET @L = CAST(@DA AS VARCHAR(12)) + ';' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 refused', @LoginName = 'zz39no', @RoleId = @rMgr, @DepartmentId = @DA,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'List with another character (A;B)', 'Result 0, Reason 23, ListNotValid', (SELECT Txt FROM @R);
    SET @L = CAST(@DA AS VARCHAR(12)) + ',1234567890';
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 refused', @LoginName = 'zz39no', @RoleId = @rMgr, @DepartmentId = @DA,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'List with a 10-digit id', 'Result 0, Reason 23, ListNotValid', (SELECT Txt FROM @R);
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST((SELECT MAX(DepartmentId) + 1000 FROM Department) AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 refused', @LoginName = 'zz39no', @RoleId = @rMgr, @DepartmentId = @DA,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'List with an unknown department', 'Result 0, Reason 23, DepartmentNotFound', (SELECT Txt FROM @R);
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DX AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 refused', @LoginName = 'zz39no', @RoleId = @rMgr, @DepartmentId = @DA,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'List with an inactive department', 'Result 0, Reason 23, DepartmentInactive', (SELECT Txt FROM @R);
    INSERT INTO @T SELECT 'Refused adds created no user and no history row', '0 0 0',
           CAST((SELECT COUNT(*) FROM Users WHERE LoginName = 'zz39no') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM User_Role ur JOIN Users u ON u.UserId = ur.UserId WHERE u.LoginName = 'zz39no') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM User_Department ud JOIN Users u ON u.UserId = ud.UserId WHERE u.LoginName = 'zz39no') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Rule 12
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 user one', @LoginName = 'zz39u1', @RoleId = @rUser, @DepartmentId = @DA,
         @ManagerId = @M1, @List = NULL, @PassList = 0, @Actor = @Adm;
    SET @U1 = (SELECT UserId FROM Users WHERE LoginName = 'zz39u1');
    EXEC #ZZ39_State @UserId = @U1, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Add a User without @DepartmentIds (older caller): the home department', 'Result 1, Reason 0 | role user; open ZZ39A*; closed 0/0/0', (SELECT Txt FROM @R) + ' | ' + @S;

    -- One item of department A waiting for a Manager (AC, agenda open), created by U1 (manager M1)
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        CurrentStatus, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('ZZ39-001', @C, @Mt, @DA, @SubjectTypeId, N'ZZ39 short', 'Entry', N'ZZ39 text', N'ZZ39 resolution', 'New', 'AC', @Now, @U1);
    SET @Ag = SCOPE_IDENTITY();

    SET @L = CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M1, @RoleId = @rMgr, @DepartmentId = @DC, @List = @L, @PassList = 1, @Actor = @Adm;
    EXEC #ZZ39_State @UserId = @M1, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Edit removes A, of which he is the last active Manager with an item waiting',
           'Result 0, Reason 24, last active Manager of ZZ step 39 department A (1 item waiting) | role manager; open ZZ39A,ZZ39C*; closed 3/0/0', (SELECT Txt FROM @R) + ' | ' + @S;

    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M1, @RoleId = @rUser, @DepartmentId = @DC, @List = @L, @PassList = 1, @Actor = @Adm;
    EXEC #ZZ39_State @UserId = @M1, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Role change Manager to User: last Manager of A, and the item routed to him',
           'Result 0, Reason 24, last active Manager of ZZ step 39 department A (1 item waiting); 1 item waiting for their own approval | role manager; open ZZ39A,ZZ39C*; closed 3/0/0',
           (SELECT Txt FROM @R) + ' | ' + @S;

    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 manager two', @LoginName = 'zz39m2', @RoleId = @rMgr, @DepartmentId = @DA,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    SET @M2 = (SELECT UserId FROM Users WHERE LoginName = 'zz39m2');

    SET @L = CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M1, @RoleId = @rUser, @DepartmentId = @DC, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'Role change with a second Manager in A: still the item routed to him',
           'Result 0, Reason 24, 1 item waiting for their own approval', (SELECT Txt FROM @R);

    UPDATE Users SET ManagerId = @M2 WHERE UserId = @U1;
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M1, @RoleId = @rUser, @DepartmentId = @DC, @List = @L, @PassList = 1, @Actor = @Adm;
    EXEC #ZZ39_State @UserId = @M1, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Role change allowed once the item is routed to the other Manager: A closed (R), C stays',
           'Result 1, Reason 0, MappingsClosed:ZZ step 39 department A | role user; open ZZ39C*; closed 3/0/1; role rows 2, 1 open', (SELECT Txt FROM @R) + ' | ' + @S
         + '; role rows ' + CAST((SELECT COUNT(*) FROM User_Role WHERE UserId = @M1) AS VARCHAR(12))
         + ', ' + CAST((SELECT COUNT(*) FROM User_Role WHERE UserId = @M1 AND EffectiveTo IS NULL) AS VARCHAR(12)) + ' open';

    -- An Edit that removes a department is not refused for items routed to him (U1's manager is now M2)
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M2, @RoleId = @rMgr, @DepartmentId = @DA, @List = @L, @PassList = 1, @Actor = @Adm;
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M2, @RoleId = @rMgr, @DepartmentId = @DA, @List = @L, @PassList = 1, @Actor = @Adm;
    EXEC #ZZ39_State @UserId = @M2, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Edit removes B while an item is routed to him: allowed (department check only)', 'Result 1, Reason 0 | role manager; open ZZ39A*; closed 1/0/0',
           (SELECT Txt FROM @R) + ' | ' + @S;

    SET @L = CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M2, @RoleId = @rMgr, @DepartmentId = @DB, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'Edit moves him from A (last active Manager, item waiting) to B: the department only is named',
           'Result 0, Reason 24, last active Manager of ZZ step 39 department A (1 item waiting)', (SELECT Txt FROM @R);

    -- An older caller (no @DepartmentIds) keeps the Manager's mappings and writes no row
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M2, @RoleId = @rMgr, @DepartmentId = @DA, @List = @L, @PassList = 1, @Actor = @Adm;
    SET @N1 = (SELECT COUNT(*) FROM User_Department WHERE UserId = @M2);
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @M2, @RoleId = @rMgr, @DepartmentId = @DA, @List = NULL, @PassList = 0, @Actor = @Adm,
         @EmailId = 'zz39changed@example.invalid';
    SET @N2 = (SELECT COUNT(*) FROM User_Department WHERE UserId = @M2);
    EXEC #ZZ39_State @UserId = @M2, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Edit of a Manager without @DepartmentIds (older caller): mappings kept, no row written',
           'Result 1, Reason 0 | role manager; open ZZ39A*,ZZ39B; closed 1/0/0 | rows +0',
           (SELECT Txt FROM @R) + ' | ' + @S + ' | rows +' + CAST(@N2 - @N1 AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Deactivate and Activate
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @M2, @AccountStatus = 0, @ActingUserId = @Adm;
    EXEC #ZZ39_State @UserId = @M2, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Deactivate closes every row (D)', 'Result 1, Reason 0 | role -; open -; closed 1/2/0', (SELECT Txt FROM @R) + ' | ' + @S;

    UPDATE Department SET StatusId = 0 WHERE DepartmentId = @DB;
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @M2, @AccountStatus = 1, @ActingUserId = @Adm;
    EXEC #ZZ39_State @UserId = @M2, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Activate reopens the role and A; B is inactive now: skipped and named',
           'Result 1, Reason 0, NotRestored:ZZ step 39 department B | role manager; open ZZ39A*; closed 1/2/0', (SELECT Txt FROM @R) + ' | ' + @S;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @M2, @AccountStatus = 1, @ActingUserId = @Adm;
    EXEC #ZZ39_State @UserId = @M2, @Text = @S OUTPUT;
    INSERT INTO @T SELECT 'Activate of an active user opens nothing', 'Result 1, Reason 0 | role manager; open ZZ39A*; closed 1/2/0', (SELECT Txt FROM @R) + ' | ' + @S;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @M2, @AccountStatus = 0, @ActingUserId = @Adm;
    UPDATE Department SET StatusId = 0 WHERE DepartmentId = @DA;
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @M2, @AccountStatus = 1, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Activate while the home department is inactive: refused, still inactive, no row opened',
           'Result 0, Reason 23, HomeDepartmentInactive:ZZ step 39 department A | status 0 | open 0',
           (SELECT Txt FROM @R) + ' | status ' + CAST((SELECT AccountStatus FROM Users WHERE UserId = @M2) AS VARCHAR(2))
         + ' | open ' + CAST((SELECT COUNT(*) FROM User_Department WHERE UserId = @M2 AND EffectiveTo IS NULL) AS VARCHAR(12));
    UPDATE Department SET StatusId = 1 WHERE DepartmentId IN (@DA, @DB);

    ---------------------------------------------------------------------------
    -- Department delete
    ---------------------------------------------------------------------------
    SET @L = CAST(@DC AS VARCHAR(12)) + ',' + CAST(@DD AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 user four', @LoginName = 'zz39u4', @RoleId = @rMgr, @DepartmentId = @DC,
         @ManagerId = NULL, @List = @L, @PassList = 1, @Actor = @Adm;
    SET @U4 = (SELECT UserId FROM Users WHERE LoginName = 'zz39u4');
    SET @L = CAST(@DC AS VARCHAR(12)) + ',' + CAST(@DE AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @U4, @RoleId = @rMgr, @DepartmentId = @DC, @List = @L, @PassList = 1, @Actor = @Adm;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteDepartmentByDeptId @DeptId = @DE;
    INSERT INTO @T SELECT 'Delete a department mapped to a Manager (not his home)', 'Result 0, Reason 25, Mapped:ZZ39 user four | kept',
           (SELECT Txt FROM @R) + ' | ' + CASE WHEN EXISTS (SELECT 1 FROM Department WHERE DepartmentId = @DE) THEN 'kept' ELSE 'deleted' END;
    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteDepartmentByDeptId @DeptId = @DD;
    INSERT INTO @T SELECT 'Delete a department with only a closed mapping', 'Result 0, Reason 25, History | kept',
           (SELECT Txt FROM @R) + ' | ' + CASE WHEN EXISTS (SELECT 1 FROM Department WHERE DepartmentId = @DD) THEN 'kept' ELSE 'deleted' END;
    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteDepartmentByDeptId @DeptId = @DC;
    INSERT INTO @T SELECT 'Delete a home department (Users): refused as before', 'Result 0, Reason 5', (SELECT Txt FROM @R);
    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteDepartmentByDeptId @DeptId = @DF;
    INSERT INTO @T SELECT 'Delete an unused department', 'Result 1, Reason 0 | deleted',
           (SELECT Txt FROM @R) + ' | ' + CASE WHEN EXISTS (SELECT 1 FROM Department WHERE DepartmentId = @DF) THEN 'kept' ELSE 'deleted' END;

    ---------------------------------------------------------------------------
    -- User delete
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 user two', @LoginName = 'zz39u2', @RoleId = @rUser, @DepartmentId = @DB,
         @ManagerId = NULL, @List = NULL, @PassList = 0, @Actor = @Adm;
    SET @U2 = (SELECT UserId FROM Users WHERE LoginName = 'zz39u2');
    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @U2, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Delete an unused user: the user and his two rows are gone', 'Result 1, Reason 0 | 0 0 0',
           (SELECT Txt FROM @R) + ' | ' + CAST((SELECT COUNT(*) FROM Users WHERE UserId = @U2) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM User_Role WHERE UserId = @U2) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM User_Department WHERE UserId = @U2) AS VARCHAR(12));

    SET @N1 = (SELECT COUNT(*) FROM User_Role WHERE UserId = @M1) + (SELECT COUNT(*) FROM User_Department WHERE UserId = @M1);
    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @M1, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Delete a user whose only footprint is his own history (open and closed rows)', 'Result 1, Reason 0 | 7 rows before, 0 after',
           (SELECT Txt FROM @R) + ' | ' + CAST(@N1 AS VARCHAR(12)) + ' rows before, '
         + CAST((SELECT COUNT(*) FROM User_Role WHERE UserId = @M1) + (SELECT COUNT(*) FROM User_Department WHERE UserId = @M1) AS VARCHAR(12)) + ' after';

    -- Admin two changes a user's role (his rows in that user's history), then Admin one edits the user last
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Save @UserName = 'ZZ39 user five', @LoginName = 'zz39u5', @RoleId = @rUser, @DepartmentId = @DB,
         @ManagerId = NULL, @List = NULL, @PassList = 0, @Actor = @Adm;
    SET @U5 = (SELECT UserId FROM Users WHERE LoginName = 'zz39u5');
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @U5, @RoleId = @rMgmt, @DepartmentId = @DB, @List = NULL, @PassList = 0, @Actor = @Adm2;
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @U5, @RoleId = @rMgmt, @DepartmentId = @DB, @List = NULL, @PassList = 0, @Actor = @Adm,
         @EmailId = 'zz39five@example.invalid';
    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Adm2, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Delete a user whose only footprint is rows in another user''s history', 'Result 0, Reason 6, user changes | kept',
           (SELECT Txt FROM @R) + ' | ' + CASE WHEN EXISTS (SELECT 1 FROM Users WHERE UserId = @Adm2) THEN 'kept' ELSE 'deleted' END;

    ---------------------------------------------------------------------------
    -- The protected system account
    ---------------------------------------------------------------------------
    SET @N1 = (SELECT COUNT(*) FROM User_Role WHERE UserId = @Sys) + (SELECT COUNT(*) FROM User_Department WHERE UserId = @Sys);
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC #ZZ39_Edit @UserId = @Sys, @RoleId = @rAdmin, @DepartmentId = @DA, @List = @L, @PassList = 1, @Actor = @Adm;
    INSERT INTO @T SELECT 'System account: Edit refused, no history row written', 'Result 0, Reason 7 | +0',
           (SELECT Txt FROM @R) + ' | +' + CAST((SELECT COUNT(*) FROM User_Role WHERE UserId = @Sys) + (SELECT COUNT(*) FROM User_Department WHERE UserId = @Sys) - @N1 AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The setting DeptNoManagerAction
    ---------------------------------------------------------------------------
    UPDATE App_Setting SET SettingValue = 'refuse' WHERE SettingCode = 'DeptNoManagerAction';
    SET @N1 = (SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'App_Setting' AND Key_Value = 'DeptNoManagerAction');
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetDepartmentManagerRule @SettingValue = 'controller', @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Admin sets controller: stored, one audit row (refuse to controller, by him)', 'Result 1, Reason 0 | controller | 1 refuse controller yes',
           (SELECT Txt FROM @R) + ' | ' + (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction')
         + ' | ' + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'App_Setting' AND Key_Value = 'DeptNoManagerAction') - @N1 AS VARCHAR(12))
         + ' ' + ISNULL((SELECT TOP 1 CAST(Old_Value AS VARCHAR(20)) + ' ' + CAST(New_Value AS VARCHAR(20))
                                    + CASE WHEN Update_By = @Adm THEN ' yes' ELSE ' no' END
                         FROM Audit_Trail_Master WHERE Audit_Table = 'App_Setting' AND Key_Value = 'DeptNoManagerAction'
                         ORDER BY Audit_Trail_Maser_Id DESC), 'none');
    SET @N1 = (SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'App_Setting' AND Key_Value = 'DeptNoManagerAction');
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetDepartmentManagerRule @SettingValue = 'controller', @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'The same value again: no audit row', 'Result 1, Reason 0 | +0',
           (SELECT Txt FROM @R) + ' | +' + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'App_Setting' AND Key_Value = 'DeptNoManagerAction') - @N1 AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetDepartmentManagerRule @SettingValue = 'other', @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'A value that is not refuse or controller', 'Result 0, Reason 3, other', (SELECT Txt FROM @R);
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetDepartmentManagerRule @SettingValue = 'refuse', @ActingUserId = @M2;
    INSERT INTO @T SELECT 'Set by a Manager (inactive here) is refused', 'Result 0, Reason 8', (SELECT Txt FROM @R);
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetDepartmentManagerRule @SettingValue = 'refuse', @ActingUserId = @U4;
    INSERT INTO @T SELECT 'Set by an active Manager is refused', 'Result 0, Reason 4', (SELECT Txt FROM @R);
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetDepartmentManagerRule @SettingValue = 'refuse', @ActingUserId = 0;
    INSERT INTO @T SELECT 'Acting user 0', 'Result 0, Reason 8 | controller', (SELECT Txt FROM @R) + ' | ' + (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction');

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @HistAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistAfter = @HistAfter + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @SetAfter = ISNULL((SELECT SettingValue FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction'), 'none');
SELECT @AudAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(MAX(Audit_Trail_Maser_Id), 0) AS VARCHAR(12)) FROM Audit_Trail_Master;
INSERT INTO @T SELECT 'After the rollback: User_Role and User_Department unchanged (count, checksum)', @HistBefore, @HistAfter;
INSERT INTO @T SELECT 'After the rollback: Users unchanged (count, checksum)', @UsersBefore, @UsersAfter;
INSERT INTO @T SELECT 'After the rollback: the setting unchanged', @SetBefore, @SetAfter;
INSERT INTO @T SELECT 'After the rollback: Audit_Trail_Master unchanged (count, last id)', @AudBefore, @AudAfter;

Report:

INSERT INTO #T (Test, Expected, Actual) SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;
GO

-------------------------------------------------------------------------------
-- Part 3: Reset Database seeds (rolled back; the counters are put back below)
-------------------------------------------------------------------------------
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @DbName NVARCHAR(128) = DB_NAME();
DECLARE @ResetResult INT, @ResetReason INT;
DECLARE @Text VARCHAR(400);
-- A table variable: a rollback does not remove its rows (#T would lose them)
DECLARE @T3 TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));

BEGIN TRANSACTION;

BEGIN TRY
    EXEC spr_sys_ResetDatabase @ActingUserId = @Sys, @ConfirmDatabaseName = @DbName,
         @Result = @ResetResult OUTPUT, @Reason = @ResetReason OUTPUT;

    INSERT INTO @T3 SELECT 'Reset Database: Result', '1', CAST(ISNULL(@ResetResult, -1) AS VARCHAR(12));
    INSERT INTO @T3 SELECT 'Reset: users, role rows, open role rows, department rows, open home rows', '4 4 4 4 4',
           CAST((SELECT COUNT(*) FROM Users) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM User_Role) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM User_Role WHERE EffectiveTo IS NULL) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM User_Department) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM User_Department WHERE EffectiveTo IS NULL AND IsHome = 1) AS VARCHAR(12));
    INSERT INTO @T3 SELECT 'Reset: seed users whose open rows disagree with Users', '0',
           CAST((SELECT COUNT(*) FROM Users u
                 WHERE NOT EXISTS (SELECT 1 FROM User_Role r WHERE r.UserId = u.UserId AND r.RoleId = u.RoleId AND r.EffectiveTo IS NULL
                                   AND r.EffectiveFrom = CAST(GETDATE() AS DATE) AND r.CreatedBy = 1)
                    OR NOT EXISTS (SELECT 1 FROM User_Department d WHERE d.UserId = u.UserId AND d.DepartmentId = u.DepartmentId
                                   AND d.EffectiveTo IS NULL AND d.IsHome = 1 AND d.CreatedBy = 1)) AS VARCHAR(12));
    INSERT INTO @T3 SELECT 'Reset: the setting row DeptNoManagerAction survives (App_Setting is not cleared)', '1',
           CAST((SELECT COUNT(*) FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction') AS VARCHAR(12));
END TRY
BEGIN CATCH
    SET @Text = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T3 VALUES ('Reset Database: unexpected error - the reset checks did not run', 'No error', @Text);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

INSERT INTO #T (Test, Expected, Actual) SELECT Test, Expected, Actual FROM @T3 ORDER BY TestNo;
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
SELECT 'After the test: no ZZ39 department or user left', '0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ39%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz39%') AS VARCHAR(12));

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

DROP PROCEDURE #ZZ39_Save;
DROP PROCEDURE #ZZ39_Edit;
DROP PROCEDURE #ZZ39_State;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
