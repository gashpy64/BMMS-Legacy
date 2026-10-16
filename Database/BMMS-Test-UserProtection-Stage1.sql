/* ============================================================================
   BMMS - Tests for BMMS-Fix-UserProtection-Stage1.sql
   ----------------------------------------------------------------------------
   Run AFTER BMMS-Fix-UserProtection-Stage1.sql, on the TEST COPY only.

   Creates eight test users (2 Admins, 2 Controllers, a Manager, a User, a
   Management and an MD Secretariat user) and calls the real procedures:
     * Admin acting on every role: edit, role change, reset password,
       delete, deactivate, create
     * Controller acting on Admin / Controller: every action refused
       (Reason 4), including each detail edit (email, department,
       designation, manager), and the row is unchanged
     * Controller acting on Manager / User / Management / MD Secretariat:
       allowed; creating or promoting to Admin / Controller refused
     * own account: details and password allowed; role change, delete and
       deactivate refused (Reason 1)
     * other roles: only their own details and password
     * acting user NULL, 0 or unknown: Reason 8 on every procedure
     * last active Admin / Controller (Reasons 2 and 3); an inactive Admin
       does not count. Once BMMS-Fix-UserStatus-Stage2a.sql (step 14) is
       installed, an inactive Admin can no longer act at all: the three checks
       that let one act expect Reason 8 instead of 2, and say so in the label
     * Reason 5 and 6 with their detail text, Reason 9 for an unknown
       foreign key (user kept), any other error re-raised (and the delete
       cannot be committed)
     * the CanEdit / CanChangeRole / CanDelete flags of the User page list
       agree with the rules
     * rule 2 under concurrency: two deactivations one after the other, and
       the update / range locks the procedure holds until commit

   Everything runs inside transactions that are ROLLED BACK. The only lasting
   effect is that identity values skip a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for that check does not exist.
   One small extra grid (Result / Reason / ReasonDetail) appears above it: it
   comes from the Reason 9 test, which calls the procedure directly because a
   captured call (INSERT ... EXEC) cannot roll back.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(120), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Dept1 INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @Dept2 INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId DESC);
DECLARE @Desig1 INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @Desig2 INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId DESC);
DECLARE @rAdmin INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @rCtl INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @rMgr INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @rUser INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @rMgmt INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'mgmt');
DECLARE @rMd INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'md_sect');

DECLARE @UsersBefore INT = (SELECT COUNT(*) FROM Users);
DECLARE @UsersChecksumBefore INT = (SELECT CHECKSUM_AGG(CHECKSUM(UserId, UserName, DepartmentId, DesignationId, ManagerId, RoleId,
                                                                 EmailId, LoginName, [Password], AccountStatus, UpdatedOn, UpdatedBy)) FROM Users);

DECLARE @A1 INT, @A2 INT, @C1 INT, @C2 INT, @M INT, @U INT, @G INT, @S INT;
DECLARE @Other INT;

-- case runner
DECLARE @Cases TABLE (CaseNo INT IDENTITY(1,1), Label VARCHAR(160), Actor VARCHAR(4), Target VARCHAR(4), Act VARCHAR(20), NewRole INT, ExpReason INT);
DECLARE @CaseNo INT, @CaseCount INT, @Label VARCHAR(160), @ActorKey VARCHAR(4), @TargetKey VARCHAR(4), @Act VARCHAR(20), @NewRole INT, @ExpReason INT;
DECLARE @Actor INT, @Target INT, @Before INT, @After INT, @Changed VARCHAR(12), @ExpChanged VARCHAR(12);
DECLARE @UserName VARCHAR(50), @DepartmentId INT, @DesignationId INT, @ManagerId INT, @RoleId INT, @EmailId VARCHAR(50), @LoginName VARCHAR(50);
DECLARE @OutResult INT, @OutReason INT, @OutDetail NVARCHAR(2000), @ErrText NVARCHAR(400);

-- Rows of spr_GetUserListForUserPage (View_Users plus the three flags)
CREATE TABLE #List (UserId INT, UserName VARCHAR(50), DepartmentId INT, DesignationId INT, DepartmentCode VARCHAR(50), DepartmentName VARCHAR(250),
                    DesignationCode VARCHAR(50), DesignationName VARCHAR(250), ManagerId INT, RoleId INT, RoleName VARCHAR(250), RoleDescription VARCHAR(250),
                    DOB VARCHAR(50), EmailId VARCHAR(50), LoginName VARCHAR(50), [Password] VARCHAR(MAX), RoleCode VARCHAR(50), AccountStatus INT,
                    CanEdit INT, CanChangeRole INT, CanDelete INT);

-- Step 14 (UserStatus-Stage2a): the list has four more columns, and an inactive acting user gets Reason 8
DECLARE @Step14 INT = CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%UserStatus-Stage2a%' THEN 1 ELSE 0 END;
DECLARE @ExpInactiveActor VARCHAR(40) = CASE WHEN @Step14 = 1 THEN 'Result 0, Reason 8' ELSE 'Result 0, Reason 2' END;
DECLARE @InactiveActorNote VARCHAR(60) = CASE WHEN @Step14 = 1 THEN ' [step 14: inactive actor, Reason 8]' ELSE ' [before step 14: Reason 2]' END;

IF (@Step14 = 1)
    ALTER TABLE #List ADD Status VARCHAR(10), CanDeactivate INT, CanActivate INT, ManagedCount INT;

IF (@rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMd IS NULL OR @Dept1 IS NULL OR @Desig1 IS NULL)
BEGIN
    INSERT INTO @T VALUES ('A role (admin, controller, manager, user, mgmt, md_sect), department or designation is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Eight active test users (inserted directly; no login is possible with them)
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ prot admin 1', @Dept1, @Desig1, NULL, @rAdmin, 'zz@test', 'zzprota1', 'not-a-login', 1, @Now);
    SET @A1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ prot admin 2', @Dept1, @Desig1, NULL, @rAdmin, 'zz@test', 'zzprota2', 'not-a-login', 1, @Now);
    SET @A2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ prot controller 1', @Dept1, @Desig1, NULL, @rCtl, 'zz@test', 'zzprotc1', 'not-a-login', 1, @Now);
    SET @C1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ prot controller 2', @Dept1, @Desig1, NULL, @rCtl, 'zz@test', 'zzprotc2', 'not-a-login', 1, @Now);
    SET @C2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ prot manager', @Dept1, @Desig1, NULL, @rMgr, 'zz@test', 'zzprotm', 'not-a-login', 1, @Now);
    SET @M = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ prot user', @Dept1, @Desig1, NULL, @rUser, 'zz@test', 'zzprotu', 'not-a-login', 1, @Now);
    SET @U = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ prot management', @Dept1, @Desig1, NULL, @rMgmt, 'zz@test', 'zzprotg', 'not-a-login', 1, @Now);
    SET @G = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ prot md secretariat', @Dept1, @Desig1, NULL, @rMd, 'zz@test', 'zzprots', 'not-a-login', 1, @Now);
    SET @S = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- The permission matrix, through the real procedures
    ---------------------------------------------------------------------------
    -- Admin acting on others
    INSERT INTO @Cases (Label, Actor, Target, Act, NewRole, ExpReason) VALUES
    ('Admin edits email of another Admin', 'A1', 'A2', 'EditEmail', NULL, 0),
    ('Admin changes role of another Admin to User', 'A1', 'A2', 'RoleChange', @rUser, 0),
    ('Admin resets password of another Admin', 'A1', 'A2', 'ResetPassword', NULL, 0),
    ('Admin deletes another Admin', 'A1', 'A2', 'Delete', NULL, 0),
    ('Admin deactivates another Admin', 'A1', 'A2', 'Deactivate', NULL, 0),
    ('Admin edits email of a Controller', 'A1', 'C1', 'EditEmail', NULL, 0),
    ('Admin changes role of a Controller to Manager', 'A1', 'C1', 'RoleChange', @rMgr, 0),
    ('Admin resets password of a Controller', 'A1', 'C1', 'ResetPassword', NULL, 0),
    ('Admin deletes a Controller', 'A1', 'C1', 'Delete', NULL, 0),
    ('Admin deactivates a Controller', 'A1', 'C1', 'Deactivate', NULL, 0),
    ('Admin edits department of a Manager', 'A1', 'M', 'EditDepartment', NULL, 0),
    ('Admin changes role of a User to Controller', 'A1', 'U', 'RoleChange', @rCtl, 0),
    ('Admin deletes a Management user', 'A1', 'G', 'Delete', NULL, 0),
    ('Admin deactivates an MD Secretariat user', 'A1', 'S', 'Deactivate', NULL, 0),
    ('Admin creates an Admin', 'A1', '', 'Create', @rAdmin, 0),
    ('Admin creates a Controller', 'A1', '', 'Create', @rCtl, 0),
    -- Admin, own account
    ('Admin edits own email', 'A1', 'A1', 'EditEmail', NULL, 0),
    ('Admin resets own password', 'A1', 'A1', 'ResetPassword', NULL, 0),
    ('Admin changes own role', 'A1', 'A1', 'RoleChange', @rUser, 1),
    ('Admin deletes own account', 'A1', 'A1', 'Delete', NULL, 1),
    ('Admin deactivates own account', 'A1', 'A1', 'Deactivate', NULL, 1);

    -- Controller acting on Admin and on another Controller: everything refused
    INSERT INTO @Cases (Label, Actor, Target, Act, NewRole, ExpReason)
    SELECT 'Controller ' + a.Txt + ' ' + t.Txt, 'C1', t.K, a.Act, a.NewRole, 4
    FROM (VALUES ('A1', 'an Admin'), ('C2', 'another Controller')) t (K, Txt)
    CROSS JOIN (VALUES ('EditEmail', 'edits email of', NULL), ('EditDepartment', 'edits department of', NULL),
                       ('EditDesignation', 'edits designation of', NULL), ('EditManager', 'edits manager of', NULL),
                       ('RoleChange', 'changes role (to User) of', @rUser), ('ResetPassword', 'resets password of', NULL),
                       ('Delete', 'deletes', NULL), ('Deactivate', 'deactivates', NULL)) a (Act, Txt, NewRole);

    -- Controller acting on Manager, User, Management, MD Secretariat: allowed
    INSERT INTO @Cases (Label, Actor, Target, Act, NewRole, ExpReason)
    SELECT 'Controller ' + a.Txt + ' ' + t.Txt, 'C1', t.K, a.Act,
           CASE WHEN a.Act = 'RoleChange' THEN CASE WHEN t.K = 'U' THEN @rMgr ELSE @rUser END END, 0
    FROM (VALUES ('M', 'a Manager'), ('U', 'a User'), ('G', 'a Management user'), ('S', 'an MD Secretariat user')) t (K, Txt)
    CROSS JOIN (VALUES ('EditEmail', 'edits email of'), ('EditDepartment', 'edits department of'),
                       ('EditDesignation', 'edits designation of'), ('EditManager', 'edits manager of'),
                       ('RoleChange', 'changes role of'), ('ResetPassword', 'resets password of'),
                       ('Delete', 'deletes'), ('Deactivate', 'deactivates')) a (Act, Txt);

    INSERT INTO @Cases (Label, Actor, Target, Act, NewRole, ExpReason) VALUES
    ('Controller promotes a User to Admin', 'C1', 'U', 'RoleChange', @rAdmin, 4),
    ('Controller promotes a User to Controller', 'C1', 'U', 'RoleChange', @rCtl, 4),
    ('Controller promotes a Manager to Controller', 'C1', 'M', 'RoleChange', @rCtl, 4),
    ('Controller creates an Admin', 'C1', '', 'Create', @rAdmin, 4),
    ('Controller creates a Controller', 'C1', '', 'Create', @rCtl, 4),
    ('Controller creates a Manager', 'C1', '', 'Create', @rMgr, 0),
    ('Controller creates a User', 'C1', '', 'Create', @rUser, 0),
    ('Controller creates a Management user', 'C1', '', 'Create', @rMgmt, 0),
    ('Controller creates an MD Secretariat user', 'C1', '', 'Create', @rMd, 0),
    -- Controller, own account
    ('Controller edits own email', 'C1', 'C1', 'EditEmail', NULL, 0),
    ('Controller edits own department', 'C1', 'C1', 'EditDepartment', NULL, 0),
    ('Controller resets own password', 'C1', 'C1', 'ResetPassword', NULL, 0),
    ('Controller changes own role', 'C1', 'C1', 'RoleChange', @rUser, 1),
    ('Controller deletes own account', 'C1', 'C1', 'Delete', NULL, 1),
    ('Controller deactivates own account', 'C1', 'C1', 'Deactivate', NULL, 1),
    -- Another role (Manager)
    ('Manager edits own email', 'M', 'M', 'EditEmail', NULL, 0),
    ('Manager changes own password', 'M', 'M', 'ResetPassword', NULL, 0),
    ('Manager edits email of a User', 'M', 'U', 'EditEmail', NULL, 4),
    ('Manager resets password of a User', 'M', 'U', 'ResetPassword', NULL, 4),
    ('Manager deletes a User', 'M', 'U', 'Delete', NULL, 4),
    ('Manager deactivates a User', 'M', 'U', 'Deactivate', NULL, 4),
    ('Manager creates a User', 'M', '', 'Create', @rUser, 4),
    -- Acting user missing: NULL, 0 or not a user, on every procedure
    ('Acting user NULL: delete', 'NULL', 'U', 'Delete', NULL, 8),
    ('Acting user 0: delete', 'ZERO', 'U', 'Delete', NULL, 8),
    ('Acting user unknown: delete', 'NONE', 'U', 'Delete', NULL, 8),
    ('Acting user NULL: edit (spr_AddEditUser Update)', 'NULL', 'U', 'EditEmail', NULL, 8),
    ('Acting user 0: edit (spr_AddEditUser Update)', 'ZERO', 'U', 'EditEmail', NULL, 8),
    ('Acting user unknown: edit (spr_AddEditUser Update)', 'NONE', 'U', 'EditEmail', NULL, 8),
    ('Acting user NULL: create (spr_AddEditUser Save)', 'NULL', '', 'Create', @rUser, 8),
    ('Acting user 0: create (spr_AddEditUser Save)', 'ZERO', '', 'Create', @rUser, 8),
    ('Acting user unknown: create (spr_AddEditUser Save)', 'NONE', '', 'Create', @rUser, 8),
    ('Acting user NULL: reset password', 'NULL', 'U', 'ResetPassword', NULL, 8),
    ('Acting user 0: reset password', 'ZERO', 'U', 'ResetPassword', NULL, 8),
    ('Acting user unknown: reset password', 'NONE', 'U', 'ResetPassword', NULL, 8),
    ('Acting user NULL: deactivate', 'NULL', 'U', 'Deactivate', NULL, 8),
    ('Acting user 0: deactivate', 'ZERO', 'U', 'Deactivate', NULL, 8);

    SET @CaseNo = 1;
    SET @CaseCount = (SELECT COUNT(*) FROM @Cases);

    WHILE (@CaseNo <= @CaseCount)
    BEGIN
        SELECT @Label = Label, @ActorKey = Actor, @TargetKey = Target, @Act = Act, @NewRole = NewRole, @ExpReason = ExpReason
        FROM @Cases WHERE CaseNo = @CaseNo;

        SET @Actor = CASE @ActorKey WHEN 'A1' THEN @A1 WHEN 'C1' THEN @C1 WHEN 'M' THEN @M
                                    WHEN 'ZERO' THEN 0 WHEN 'NONE' THEN -1 ELSE NULL END;
        SET @Target = CASE @TargetKey WHEN 'A1' THEN @A1 WHEN 'A2' THEN @A2 WHEN 'C1' THEN @C1 WHEN 'C2' THEN @C2
                                      WHEN 'M' THEN @M WHEN 'U' THEN @U WHEN 'G' THEN @G WHEN 'S' THEN @S ELSE NULL END;

        IF ((@Act = 'EditDepartment' AND @Dept1 = @Dept2) OR (@Act = 'EditDesignation' AND @Desig1 = @Desig2))
        BEGIN
            INSERT INTO @T VALUES (@Label, '', 'SKIPPED');
        END
        ELSE
        BEGIN
            SAVE TRANSACTION CaseTest;

            SELECT @UserName = UserName, @DepartmentId = DepartmentId, @DesignationId = DesignationId, @ManagerId = ManagerId,
                   @RoleId = RoleId, @EmailId = EmailId, @LoginName = LoginName
            FROM Users WHERE UserId = @Target;

            SET @Before = CASE WHEN @Act = 'Create' THEN (SELECT COUNT(*) FROM Users WHERE LoginName = 'zzprotnew')
                               ELSE (SELECT CHECKSUM(UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, [Password], AccountStatus)
                                     FROM Users WHERE UserId = @Target) END;

            DELETE FROM @R;

            IF (@Act = 'Create')
                INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'ZZ prot new', @DepartmentId = @Dept1,
                     @DesignationId = @Desig1, @ManagerId = NULL, @RoleId = @NewRole, @EmailId = 'zz@test', @LoginName = 'zzprotnew',
                     @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = @Actor, @UpdatedOn = @Now, @UpdatedBy = @Actor;
            ELSE IF (@Act LIKE 'Edit%' OR @Act = 'RoleChange')
            BEGIN
                IF (@Act = 'EditEmail') SET @EmailId = 'zz.changed@test';
                IF (@Act = 'EditDepartment') SET @DepartmentId = @Dept2;
                IF (@Act = 'EditDesignation') SET @DesignationId = @Desig2;
                IF (@Act = 'EditManager') SET @ManagerId = CASE WHEN @Target = @M THEN @C2 ELSE @M END;
                IF (@Act = 'RoleChange') SET @RoleId = @NewRole;

                INSERT INTO @R EXEC spr_AddEditUser @Code = 'Update', @UserId = @Target, @UserName = @UserName, @DepartmentId = @DepartmentId,
                     @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @EmailId, @LoginName = @LoginName,
                     @Password = '', @CreatedOn = @Now, @CreatedBy = @Actor, @UpdatedOn = @Now, @UpdatedBy = @Actor;
            END
            ELSE IF (@Act = 'ResetPassword')
                INSERT INTO @R EXEC spr_ResetPasswordByUserId @UserId = @Target, @Password = 'zz-new-hash', @UpdatedBy = @Actor;
            ELSE IF (@Act = 'Delete')
                INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Target, @ActingUserId = @Actor;
            ELSE IF (@Act = 'Deactivate')
                INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Target, @AccountStatus = 0, @ActingUserId = @Actor;

            SET @After = CASE WHEN @Act = 'Create' THEN (SELECT COUNT(*) FROM Users WHERE LoginName = 'zzprotnew')
                              ELSE (SELECT CHECKSUM(UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, [Password], AccountStatus)
                                    FROM Users WHERE UserId = @Target) END;

            SET @Changed = CASE WHEN ISNULL(@Before, -1) = ISNULL(@After, -1) THEN 'unchanged' ELSE 'changed' END;
            SET @ExpChanged = CASE WHEN @ExpReason = 0 THEN 'changed' ELSE 'unchanged' END;

            INSERT INTO @T
            SELECT @Label,
                   'Result ' + CAST(CASE WHEN @ExpReason = 0 THEN 1 ELSE 0 END AS VARCHAR(2)) + ', Reason ' + CAST(@ExpReason AS VARCHAR(2)) + ', ' + @ExpChanged,
                   ISNULL((SELECT 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R), 'no result row') + ', ' + @Changed;

            ROLLBACK TRANSACTION CaseTest;
        END

        SET @CaseNo = @CaseNo + 1;
    END

    ---------------------------------------------------------------------------
    -- spr_CheckUserChange gives the same answers
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @C1, @TargetUserId = @A1, @Action = 'ResetPassword';
    INSERT INTO @T SELECT 'Check: Controller resets password of an Admin', 'Result 0, Reason 4', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;
    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @C1, @TargetUserId = @U, @Action = 'ResetPassword';
    INSERT INTO @T SELECT 'Check: Controller resets password of a User', 'Result 1, Reason 0', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;
    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = NULL, @TargetUserId = @U, @Action = 'ResetPassword';
    INSERT INTO @T SELECT 'Check: acting user NULL', 'Result 0, Reason 8', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;
    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = 0, @TargetUserId = @U, @Action = 'ResetPassword';
    INSERT INTO @T SELECT 'Check: acting user 0', 'Result 0, Reason 8', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    ---------------------------------------------------------------------------
    -- User page list: the flags agree with the rules
    ---------------------------------------------------------------------------
    DELETE FROM #List;
    INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @C1;

    INSERT INTO @T
    SELECT 'List for a Controller: Admin row (edit, role, delete)', '0 0 0',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) FROM #List WHERE UserId = @A1), 'row missing');
    INSERT INTO @T
    SELECT 'List for a Controller: other Controller row (edit, role, delete)', '0 0 0',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) FROM #List WHERE UserId = @C2), 'row missing');
    INSERT INTO @T
    SELECT 'List for a Controller: own row (edit, role, delete)', '1 0 0',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) FROM #List WHERE UserId = @C1), 'row missing');
    INSERT INTO @T
    SELECT 'List for a Controller: MD Secretariat row (edit, role, delete)', '1 1 1',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanChangeRole AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) FROM #List WHERE UserId = @S), 'row missing');

    -- Every row, for an Admin, a Controller and a Manager acting
    SET @Other = 0;
    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @A1;
    SET @Other = @Other + (SELECT COUNT(*) FROM #List
                           WHERE CanEdit <> CASE WHEN dbo.fn_UserChangeRefusal(@A1, UserId, 'Edit', NULL) = 0 THEN 1 ELSE 0 END
                           OR CanChangeRole <> CASE WHEN dbo.fn_UserChangeRefusal(@A1, UserId, 'RoleChange', NULL) = 0 THEN 1 ELSE 0 END
                           OR CanDelete <> CASE WHEN dbo.fn_UserChangeRefusal(@A1, UserId, 'Delete', NULL) = 0 THEN 1 ELSE 0 END);
    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @C1;
    SET @Other = @Other + (SELECT COUNT(*) FROM #List
                           WHERE CanEdit <> CASE WHEN dbo.fn_UserChangeRefusal(@C1, UserId, 'Edit', NULL) = 0 THEN 1 ELSE 0 END
                           OR CanChangeRole <> CASE WHEN dbo.fn_UserChangeRefusal(@C1, UserId, 'RoleChange', NULL) = 0 THEN 1 ELSE 0 END
                           OR CanDelete <> CASE WHEN dbo.fn_UserChangeRefusal(@C1, UserId, 'Delete', NULL) = 0 THEN 1 ELSE 0 END);
    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = @M;
    SET @Other = @Other + (SELECT COUNT(*) FROM #List
                           WHERE CanEdit <> CASE WHEN dbo.fn_UserChangeRefusal(@M, UserId, 'Edit', NULL) = 0 THEN 1 ELSE 0 END
                           OR CanChangeRole <> CASE WHEN dbo.fn_UserChangeRefusal(@M, UserId, 'RoleChange', NULL) = 0 THEN 1 ELSE 0 END
                           OR CanDelete <> CASE WHEN dbo.fn_UserChangeRefusal(@M, UserId, 'Delete', NULL) = 0 THEN 1 ELSE 0 END);
    INSERT INTO @T VALUES ('List flags that disagree with the rules (Admin, Controller, Manager acting)', '0', CAST(@Other AS VARCHAR(12)));

    DELETE FROM #List; INSERT INTO #List EXEC spr_GetUserListForUserPage @ActingUserId = 0;
    INSERT INTO @T
    SELECT 'List with acting user 0: rows with any action allowed', '0', CAST(COUNT(*) AS VARCHAR(12))
    FROM #List WHERE CanEdit = 1 OR CanChangeRole = 1 OR CanDelete = 1;

    ---------------------------------------------------------------------------
    -- Rule 2: last active Admin / Controller (all others made inactive)
    ---------------------------------------------------------------------------
    SAVE TRANSACTION Rule2;

    UPDATE Users SET AccountStatus = 0
    WHERE RoleId IN (@rAdmin, @rCtl) AND UserId NOT IN (@A1, @C1);

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @C1, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Last active Controller: delete', 'Result 0, Reason 3', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @C1, @AccountStatus = 0, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Last active Controller: deactivate', 'Result 0, Reason 3', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    SELECT @UserName = UserName, @DepartmentId = DepartmentId, @DesignationId = DesignationId, @ManagerId = ManagerId, @EmailId = EmailId, @LoginName = LoginName
    FROM Users WHERE UserId = @C1;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Update', @UserId = @C1, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @rMgr, @EmailId = @EmailId, @LoginName = @LoginName,
         @Password = '', @CreatedOn = @Now, @CreatedBy = @A1, @UpdatedOn = @Now, @UpdatedBy = @A1;
    INSERT INTO @T SELECT 'Last active Controller: role change to Manager', 'Result 0, Reason 3', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Update', @UserId = @C1, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @rCtl, @EmailId = 'zz.last@test', @LoginName = @LoginName,
         @Password = '', @CreatedOn = @Now, @CreatedBy = @A1, @UpdatedOn = @Now, @UpdatedBy = @A1;
    INSERT INTO @T SELECT 'Last active Controller: edit email still allowed', 'Result 1, Reason 0', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    -- A2 is an Admin but inactive: it does not count as active. Before step 14 it
    -- can act (Reason 2 for the last active Admin); from step 14 on it cannot (Reason 8).
    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @A1, @ActingUserId = @A2;
    INSERT INTO @T SELECT 'Last active Admin (another Admin inactive): delete' + @InactiveActorNote, @ExpInactiveActor, 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @A1, @AccountStatus = 0, @ActingUserId = @A2;
    INSERT INTO @T SELECT 'Last active Admin: deactivate' + @InactiveActorNote, @ExpInactiveActor, 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    SELECT @UserName = UserName, @DepartmentId = DepartmentId, @DesignationId = DesignationId, @ManagerId = ManagerId, @EmailId = EmailId, @LoginName = LoginName
    FROM Users WHERE UserId = @A1;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Update', @UserId = @A1, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @rUser, @EmailId = @EmailId, @LoginName = @LoginName,
         @Password = '', @CreatedOn = @Now, @CreatedBy = @A2, @UpdatedOn = @Now, @UpdatedBy = @A2;
    INSERT INTO @T SELECT 'Last active Admin: role change to User' + @InactiveActorNote, @ExpInactiveActor, 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    INSERT INTO @T SELECT 'Function, no acting user: last Admin delete', '2', CAST(dbo.fn_UserChangeRefusal(NULL, @A1, 'Delete', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function, no acting user: last Controller deactivate', '3', CAST(dbo.fn_UserChangeRefusal(NULL, @C1, 'Deactivate', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function, no acting user: User delete', '0', CAST(dbo.fn_UserChangeRefusal(NULL, @U, 'Delete', NULL) AS VARCHAR(2));
    INSERT INTO @T SELECT 'Function, acting user 0', '8', CAST(dbo.fn_UserChangeRefusal(0, @U, 'Delete', NULL) AS VARCHAR(2));

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @A2, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Inactive Admin can be deleted while one active Admin remains', 'Result 1, Reason 0', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    ROLLBACK TRANSACTION Rule2;

    ---------------------------------------------------------------------------
    -- Rule 2, two deactivations one after the other (what the lock serialises)
    ---------------------------------------------------------------------------
    SAVE TRANSACTION Rule2Seq;

    UPDATE Users SET AccountStatus = 0
    WHERE RoleId IN (@rAdmin, @rCtl) AND UserId NOT IN (@A1, @C1, @C2);

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @C1, @AccountStatus = 0, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Two active Controllers: first deactivation', 'Result 1, Reason 0', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @C2, @AccountStatus = 0, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'Two active Controllers: second deactivation sees the first', 'Result 0, Reason 3', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    INSERT INTO @T
    SELECT 'Active Controllers left', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Users WHERE RoleId = @rCtl AND AccountStatus = 1;

    ROLLBACK TRANSACTION Rule2Seq;

    ---------------------------------------------------------------------------
    -- Reason 5: other users point at the user
    ---------------------------------------------------------------------------
    SAVE TRANSACTION Reason5;

    UPDATE Users SET ManagerId = @U WHERE UserId = @M;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @U, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'User who manages another user: delete', 'Result 0, Reason 5, ZZ prot manager',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) + ', ' + CAST(ReasonDetail AS VARCHAR(200)) FROM @R;

    ROLLBACK TRANSACTION Reason5;

    ---------------------------------------------------------------------------
    -- Reason 6: history, every group listed
    ---------------------------------------------------------------------------
    SAVE TRANSACTION Reason6;

    INSERT INTO Audit_Trial_Login ([User_Id], Login_DateTime, Login_Status, User_IP_Address, Server_Url)
    VALUES (@U, DATEADD(MINUTE, 1, @Now), 'C', '', '');
    INSERT INTO Audit_Trail_SqlBackup (Backup_File_Name, [User_Id], Backup_Date_Time, User_IP_Address, Server_Url)
    VALUES ('zz.bak', @U, DATEADD(MINUTE, 1, @Now), '', '');

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @U, @ActingUserId = @A1;
    INSERT INTO @T SELECT 'User with login and backup history: delete', 'Result 0, Reason 6, backups, login history',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) + ', ' + CAST(ReasonDetail AS VARCHAR(200)) FROM @R;

    ROLLBACK TRANSACTION Reason6;

    ---------------------------------------------------------------------------
    -- Reason 9: a foreign key the checks do not know (called directly)
    ---------------------------------------------------------------------------
    SAVE TRANSACTION Reason9;

    CREATE TABLE dbo.ZZ_UserRefTest (UserId INT NOT NULL CONSTRAINT FK_ZZ_UserRefTest_Users REFERENCES dbo.Users (UserId));
    EXEC sp_executesql N'INSERT INTO dbo.ZZ_UserRefTest (UserId) VALUES (@u);', N'@u INT', @u = @U;

    SET @OutResult = NULL; SET @OutReason = NULL; SET @OutDetail = NULL;
    EXEC spr_DeleteUserByUserId @UserId = @U, @ActingUserId = @A1,
         @OutResult = @OutResult OUTPUT, @OutReason = @OutReason OUTPUT, @OutReasonDetail = @OutDetail OUTPUT;

    INSERT INTO @T VALUES ('Unknown foreign key: delete', 'Result 0, Reason 9',
                           'Result ' + ISNULL(CAST(@OutResult AS VARCHAR(2)), 'NULL') + ', Reason ' + ISNULL(CAST(@OutReason AS VARCHAR(2)), 'NULL'));
    INSERT INTO @T VALUES ('Unknown foreign key: detail names the key (for the log)', 'Yes',
                           CASE WHEN @OutDetail LIKE '%FK_ZZ_UserRefTest_Users%' THEN 'Yes' ELSE 'No: ' + ISNULL(LEFT(@OutDetail, 200), 'NULL') END);
    INSERT INTO @T SELECT 'Unknown foreign key: user kept', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Users WHERE UserId = @U;

    ROLLBACK TRANSACTION Reason9;

    ---------------------------------------------------------------------------
    -- Any other error is re-raised, never reported as "in use" (last: it uses a trigger)
    ---------------------------------------------------------------------------
    SAVE TRANSACTION ReRaise;

    EXEC (N'CREATE TRIGGER dbo.ZZ_trg_UserProtTest ON dbo.Users AFTER DELETE AS BEGIN RAISERROR(''ZZ trigger test error'', 16, 1); END');

    SET @OutReason = NULL; SET @ErrText = NULL;
    BEGIN TRY
        EXEC spr_DeleteUserByUserId @UserId = @U, @ActingUserId = @A1, @OutReason = @OutReason OUTPUT;
    END TRY
    BEGIN CATCH
        SET @ErrText = ERROR_MESSAGE();
    END CATCH

    INSERT INTO @T VALUES ('Other error during delete: re-raised to the caller', 'ZZ trigger test error',
                           ISNULL(@ErrText, 'not raised, Reason ' + ISNULL(CAST(@OutReason AS VARCHAR(2)), 'NULL')));

    -- An error raised in a trigger makes the whole transaction uncommittable, so
    -- the delete can never be committed. (Called by the page, the procedure owns
    -- its transaction and rolls all of it back.) This check is last for that reason.
    INSERT INTO @T VALUES ('Other error during delete: the delete cannot be committed (transaction state)', '-1',
                           CAST(XACT_STATE() AS VARCHAR(2)));

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - checks after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 220));
END CATCH

IF (@@TRANCOUNT > 0)
BEGIN
    ROLLBACK TRANSACTION;
END

---------------------------------------------------------------------------
-- Locks: the rule 2 count holds update / range locks on Users until the
-- transaction ends, so a second delete / deactivate / role change waits and
-- then sees the first. Uses a refused call (own account), so nothing changes.
---------------------------------------------------------------------------
SET @Other = (SELECT TOP 1 UserId FROM Users WHERE RoleId = @rAdmin AND AccountStatus = 1 ORDER BY UserId);

IF (@Other IS NULL)
BEGIN
    INSERT INTO @T VALUES ('Lock check: no active Admin to act with', 'PASS', 'SKIPPED');
END
ELSE
BEGIN
    BEGIN TRANSACTION;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Other, @AccountStatus = 0, @ActingUserId = @Other;
    INSERT INTO @T SELECT 'Lock check: own-account deactivate refused', 'Result 0, Reason 1', 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    INSERT INTO @T
    SELECT 'Lock check: update / range locks on Users held until commit', 'Yes',
           CASE WHEN COUNT(*) > 0 THEN 'Yes' ELSE 'No' END
    FROM sys.dm_tran_locks l
    WHERE l.request_session_id = @@SPID
    AND l.request_mode IN ('U', 'RangeS-U', 'IU', 'SIU', 'UIX')
    AND (l.resource_associated_entity_id = OBJECT_ID('dbo.Users')
         OR l.resource_associated_entity_id IN (SELECT hobt_id FROM sys.partitions WHERE object_id = OBJECT_ID('dbo.Users')));

    ROLLBACK TRANSACTION;
END

---------------------------------------------------------------------------
-- After the rollbacks: data unchanged
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'After rollback: Users row count unchanged', CAST(@UsersBefore AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12)) FROM Users;

INSERT INTO @T
SELECT 'After rollback: Users contents unchanged (checksum)', ISNULL(CAST(@UsersChecksumBefore AS VARCHAR(12)), 'NULL'),
       ISNULL(CAST(CHECKSUM_AGG(CHECKSUM(UserId, UserName, DepartmentId, DesignationId, ManagerId, RoleId,
                                         EmailId, LoginName, [Password], AccountStatus, UpdatedOn, UpdatedBy)) AS VARCHAR(12)), 'NULL')
FROM Users;

INSERT INTO @T
SELECT 'After rollback: test table and trigger gone', '0',
       CAST((SELECT COUNT(*) FROM sys.objects WHERE name IN ('ZZ_UserRefTest', 'ZZ_trg_UserProtTest')) AS VARCHAR(12));

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
SELECT COUNT(*) AS TestUsersLeft FROM Users WHERE LoginName LIKE 'zzprot%';

DROP TABLE #List;
GO

SET NOEXEC OFF;
GO
