/* ============================================================================
   BMMS - Tests for BMMS-Fix-SystemAccount-Stage3.sql (step 18)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-SystemAccount-Stage3.sql, on the TEST COPY. It stops if
   step 18 is not installed.

   Creates its own users (two ordinary Admins, a Controller, a Manager and a
   User), committee, meetings, agenda items, minutes and action items and
   checks, through the real procedures:
     * the column, check, view column, exactly one system account and the
       markers of steps 3, 6, 8 and 13 to 18
     * Reason 7 for edit, Login ID change, delete, deactivate and role change
       by another Admin, by the Controller and by the account itself, and
       for a password reset by anyone else; its own password change works
     * Activate of the system account: Admin allowed, Controller Reason 4
     * the last ordinary active Admin (Reason 2) with the system account
       still active
     * user lists: User Master shows it greyed, spr_GetUser shows it, the
       active list leaves it out, another user named "admin" now shows
     * no new alerts, action items or alert mail for it; a late action item
       of an agenda it created goes to the Controllers; it cannot approve
       or reject (Reason 12); an ordinary Admin is unchanged; saved rows kept
     * the Reset Database seed (procedure text only; it is not run here)

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for the checks does not exist.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUser')), '') NOT LIKE '%SystemAccount3-Step18%')
BEGIN
    RAISERROR('The system account (step 18) is not installed in "%s". Run BMMS-Fix-SystemAccount-Stage3.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(120), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));
DECLARE @ML TABLE (EmailId VARCHAR(100));

DECLARE @Now DATETIME = GETDATE();
DECLARE @MDate DATETIME = DATEADD(DAY, -10, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @E VARCHAR(10) = '';

DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @AdminRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @MgrRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @UserRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @DepartmentId INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DecisionOther INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);
DECLARE @HasFollowup INT = CASE WHEN EXISTS (SELECT 1 FROM Decision_Type WHERE DecisionTypeId = 1) THEN 1 ELSE 0 END;

DECLARE @AdmA INT, @AdmB INT, @CtlA INT, @MgrA INT, @UsrA INT, @Admin2 INT;
DECLARE @C INT, @Mt INT, @MtF INT, @MtU INT;
DECLARE @AgA INT, @AgM INT, @AgK INT, @AgSys INT, @AgF1 INT, @AgF2 INT, @MinF1 INT, @MinF2 INT, @MinU INT, @AI2 INT, @AISaved INT;
DECLARE @A INT, @SavedAlertRow INT;
DECLARE @SysLogin VARCHAR(50), @SysName VARCHAR(50), @SysPassword VARCHAR(MAX);
DECLARE @Def NVARCHAR(MAX);
DECLARE @ActiveCtrls INT;

IF (@Sys IS NULL OR @AdminRoleId IS NULL OR @CtrlRoleId IS NULL OR @MgrRoleId IS NULL OR @UserRoleId IS NULL OR @DepartmentId IS NULL
    OR @DesignationId IS NULL OR @SubjectTypeId IS NULL OR @DecisionOther IS NULL OR @HasFollowup = 0)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, department, designation, subject type or decision type (Followup = 1 and another) is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT TOP 0 v.*, CAST(0 AS INT) AS CanEdit, CAST(0 AS INT) AS CanChangeRole, CAST(0 AS INT) AS CanDelete, CAST('' AS VARCHAR(8)) AS Status,
       CAST(0 AS INT) AS CanDeactivate, CAST(0 AS INT) AS CanActivate, CAST(0 AS INT) AS ManagedCount
INTO #L FROM View_Users v;
SELECT TOP 0 * INTO #U FROM View_Users;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures
    ---------------------------------------------------------------------------
    SELECT @SysLogin = LoginName, @SysName = UserName, @SysPassword = [Password] FROM Users WHERE UserId = @Sys;
    -- A distinct address for the mail checks (rolled back)
    UPDATE Users SET EmailId = 'zz18system@example.invalid' WHERE UserId = @Sys;

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ18 admin A', @DepartmentId, @DesignationId, NULL, @AdminRoleId, 'zz18adma@example.invalid', 'zz18adma', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @AdmA = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ18 admin B', @DepartmentId, @DesignationId, NULL, @AdminRoleId, 'zz18admb@example.invalid', 'zz18admb', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @AdmB = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ18 controller', @DepartmentId, @DesignationId, NULL, @CtrlRoleId, 'zz18ctla@example.invalid', 'zz18ctla', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @CtlA = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ18 manager', @DepartmentId, @DesignationId, NULL, @MgrRoleId, 'zz18mgra@example.invalid', 'zz18mgra', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @MgrA = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ18 user', @DepartmentId, @DesignationId, @MgrA, @UserRoleId, 'zz18usra@example.invalid', 'zz18usra', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @UsrA = SCOPE_IDENTITY();

    SET @ActiveCtrls = (SELECT COUNT(*) FROM Users WHERE RoleId = 2 AND AccountStatus = 1 AND IsSystem = 0);

    ---------------------------------------------------------------------------
    -- 1. Schema and markers
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Schema: Users.IsSystem NOT NULL with a default', '1 1',
           CAST((SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'IsSystem' AND is_nullable = 0) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID('dbo.Users')
                 AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.Users'), 'IsSystem', 'ColumnId')) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Schema: CK_Users_IsSystem exists', '1',
           CAST(COUNT(*) AS VARCHAR(12)) FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.Users') AND name = 'CK_Users_IsSystem';
    INSERT INTO @T SELECT 'Schema: View_Users has IsSystem', '1',
           CAST(COUNT(*) AS VARCHAR(12)) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.View_Users') AND name = 'IsSystem';
    INSERT INTO @T SELECT 'Exactly one system account', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Users WHERE IsSystem = 1;
    INSERT INTO @T SELECT 'The system account is the active Admin "admin"', 'admin 1 admin',
           LOWER(u.LoginName) + ' ' + CAST(u.AccountStatus AS VARCHAR(2)) + ' ' + r.RoleCode
    FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @Sys;

    INSERT INTO @T
    SELECT 'Markers: SystemAccount3-Step18 in all 15 objects', '15', CAST(COUNT(*) AS VARCHAR(12))
    FROM (VALUES ('View_Users'), ('fn_UserChangeRefusal'), ('spr_GetUserListForUserPage'), ('spr_GetUser'), ('spr_GetActiveUserList'),
                 ('spr_AddEditCommittee'), ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'),
                 ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaByAgendaId'), ('spr_MinutesFinalizeByMeetingId'),
                 ('spr_UpdateMinutes'), ('spr_GetAlertMailId'), ('spr_sys_ResetDatabase')) o(Name)
    WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%SystemAccount3-Step18%';

    INSERT INTO @T SELECT 'Markers kept: Stage1 / Stage2a in the function and the list, Stage2a in the active list', '1 1 1 1 1',
           CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%UserProtection-Stage1%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%UserStatus-Stage2a%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUserListForUserPage')) LIKE '%UserProtection-Stage1%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUserListForUserPage')) LIKE '%UserStatus-Stage2a%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetActiveUserList')) LIKE '%UserStatus-Stage2a%' THEN '1' ELSE '0' END;

    INSERT INTO @T SELECT 'Markers kept: step 17 (9), step 16 (6), step 15, step 8, FK #5, FK#5-ManagerId-NULL', '9 6 1 1 1 1',
           CAST((SELECT COUNT(*) FROM (VALUES ('spr_AddEditCommittee'), ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'),
                 ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaByAgendaId'), ('spr_MinutesFinalizeByMeetingId'), ('spr_UpdateMinutes'),
                 ('spr_GetAlertMailId')) o(Name) WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%UserStatus2b-Step17%') AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM (VALUES ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController'),
                 ('spr_UpdateAgendaByAgendaId'), ('spr_UpdateMinutes')) o(Name) WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%MeetingLocks-Step16%') AS VARCHAR(4)) + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) LIKE '%MeetingLocks-Step15%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) LIKE '%NOT EXISTS (SELECT 1 FROM ActionItem_User_Map x%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%FK #5%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%FK#5-ManagerId-NULL%' THEN '1' ELSE '0' END;

    ---------------------------------------------------------------------------
    -- 2. Reason 7: nobody changes the system account
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Update', @UserId = @Sys, @UserName = @SysName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = NULL, @RoleId = @AdminRoleId, @EmailId = 'x@example.invalid', @LoginName = @SysLogin,
         @Password = @E, @CreatedOn = @Now, @CreatedBy = @AdmA, @UpdatedOn = @Now, @UpdatedBy = @AdmA;
    INSERT INTO @T SELECT 'Edit by another Admin refused', 'Result 0, Reason 7', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Update', @UserId = @Sys, @UserName = @SysName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = NULL, @RoleId = @AdminRoleId, @EmailId = 'x@example.invalid', @LoginName = 'zz18renamed',
         @Password = @E, @CreatedOn = @Now, @CreatedBy = @AdmA, @UpdatedOn = @Now, @UpdatedBy = @AdmA;
    INSERT INTO @T SELECT 'Login ID change by another Admin refused, Login ID unchanged', 'Result 0, Reason 7; ' + @SysLogin,
           (SELECT Txt FROM @R) + '; ' + (SELECT LoginName FROM Users WHERE UserId = @Sys);

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Update', @UserId = @Sys, @UserName = 'ZZ18 new name', @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = NULL, @RoleId = @AdminRoleId, @EmailId = 'x@example.invalid', @LoginName = @SysLogin,
         @Password = @E, @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Edit of its own details by the system account refused, name unchanged', 'Result 0, Reason 7; ' + @SysName,
           (SELECT Txt FROM @R) + '; ' + (SELECT UserName FROM Users WHERE UserId = @Sys);

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Update', @UserId = @Sys, @UserName = @SysName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = NULL, @RoleId = @CtrlRoleId, @EmailId = 'x@example.invalid', @LoginName = @SysLogin,
         @Password = @E, @CreatedOn = @Now, @CreatedBy = @AdmA, @UpdatedOn = @Now, @UpdatedBy = @AdmA;
    INSERT INTO @T SELECT 'Role change by another Admin refused, role unchanged', 'Result 0, Reason 7; admin',
           (SELECT Txt FROM @R) + '; ' + (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @Sys);

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @AdmA, @TargetUserId = @Sys, @Action = 'RoleChange', @NewRoleId = @CtrlRoleId;
    INSERT INTO @T SELECT 'Role change check for the page', 'Result 0, Reason 7', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Sys, @ActingUserId = @AdmA;
    INSERT INTO @T SELECT 'Delete by another Admin refused, account still there', 'Result 0, Reason 7; 1',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Users WHERE UserId = @Sys) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Sys, @AccountStatus = 0, @ActingUserId = @AdmA;
    INSERT INTO @T SELECT 'Deactivate by another Admin refused, still active', 'Result 0, Reason 7; 1',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT AccountStatus FROM Users WHERE UserId = @Sys) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Sys, @ActingUserId = @CtlA;
    INSERT INTO @T SELECT 'Delete by the Controller refused (7 before 4)', 'Result 0, Reason 7', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Sys, @AccountStatus = 0, @ActingUserId = @CtlA;
    INSERT INTO @T SELECT 'Deactivate by the Controller refused (7 before 4)', 'Result 0, Reason 7', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Sys, @AccountStatus = 0, @ActingUserId = @Sys;
    INSERT INTO @T SELECT 'Deactivate by itself refused (7 before 1)', 'Result 0, Reason 7', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Sys, @ActingUserId = @Sys;
    INSERT INTO @T SELECT 'Delete by itself refused (7 before 1)', 'Result 0, Reason 7', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @AdmA, @TargetUserId = @Sys, @Action = 'Edit', @NewRoleId = NULL;
    INSERT INTO @T SELECT 'Edit check for the page', 'Result 0, Reason 7', Txt FROM @R;

    ---------------------------------------------------------------------------
    -- 3. Password: only the account itself
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_ResetPasswordByUserId @UserId = @Sys, @Password = 'zz18-reset-by-admin', @UpdatedBy = @AdmA;
    INSERT INTO @T SELECT 'Reset Password by another Admin refused, password unchanged', 'Result 0, Reason 7; same',
           (SELECT Txt FROM @R) + '; ' + CASE WHEN (SELECT [Password] FROM Users WHERE UserId = @Sys) = @SysPassword THEN 'same' ELSE 'changed' END;

    DELETE FROM @R; INSERT INTO @R EXEC spr_ResetPasswordByUserId @UserId = @Sys, @Password = 'zz18-reset-by-controller', @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Reset Password by the Controller refused', 'Result 0, Reason 7', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @Sys, @TargetUserId = @Sys, @Action = 'ResetPassword', @NewRoleId = NULL;
    INSERT INTO @T SELECT 'Own password change check for the page', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_ResetPasswordByUserId @UserId = @Sys, @Password = 'zz18-own-change', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Own Change Password allowed and stored', 'Result 1, Reason 0; zz18-own-change',
           (SELECT Txt FROM @R) + '; ' + (SELECT [Password] FROM Users WHERE UserId = @Sys);

    ---------------------------------------------------------------------------
    -- 4. Activate (the account set inactive here, rolled back)
    ---------------------------------------------------------------------------
    UPDATE Users SET AccountStatus = 0 WHERE UserId = @Sys;
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Sys, @AccountStatus = 1, @ActingUserId = @CtlA;
    INSERT INTO @T SELECT 'Activate by the Controller refused (target is an Admin)', 'Result 0, Reason 4', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Sys, @AccountStatus = 1, @ActingUserId = @AdmA;
    INSERT INTO @T SELECT 'Activate by an active Admin allowed', 'Result 1, Reason 0; 1',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT AccountStatus FROM Users WHERE UserId = @Sys) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 5. Reason 2 counts ordinary Admins only
    ---------------------------------------------------------------------------
    -- Only AdmA and AdmB are ordinary active Admins now (others switched off, rolled back)
    UPDATE Users SET AccountStatus = 0 WHERE RoleId = @AdminRoleId AND IsSystem = 0 AND UserId NOT IN (@AdmA, @AdmB) AND AccountStatus = 1;

    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @Sys, @TargetUserId = @AdmB, @Action = 'Deactivate', @NewRoleId = NULL;
    INSERT INTO @T SELECT 'Two ordinary Admins: one may be deactivated', 'Result 1, Reason 0', Txt FROM @R;

    UPDATE Users SET AccountStatus = 0 WHERE UserId = @AdmA;
    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @Sys, @TargetUserId = @AdmB, @Action = 'Deactivate', @NewRoleId = NULL;
    INSERT INTO @T SELECT 'Last ordinary active Admin: deactivate refused although the system account is active', 'Result 0, Reason 2', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R EXEC spr_CheckUserChange @ActingUserId = @Sys, @TargetUserId = @AdmB, @Action = 'Delete', @NewRoleId = NULL;
    INSERT INTO @T SELECT 'Last ordinary active Admin: delete refused', 'Result 0, Reason 2', Txt FROM @R;
    UPDATE Users SET AccountStatus = 1 WHERE UserId = @AdmA;

    ---------------------------------------------------------------------------
    -- 6. User lists
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('admin', @DepartmentId, @DesignationId, NULL, @UserRoleId, 'zz18named@example.invalid', 'zz18namedadmin', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Admin2 = SCOPE_IDENTITY();

    DELETE FROM #L; INSERT INTO #L EXEC spr_GetUserListForUserPage @ActingUserId = @AdmA;
    INSERT INTO @T SELECT 'User Master: system row shown, IsSystem / edit / role / delete / deactivate / status', '1 0 0 0 0 Active',
           ISNULL((SELECT CAST(CAST(IsSystem AS INT) AS VARCHAR(2)) + ' ' + CAST(CanEdit AS VARCHAR(2)) + ' ' + CAST(CanChangeRole AS VARCHAR(2)) + ' '
                 + CAST(CanDelete AS VARCHAR(2)) + ' ' + CAST(CanDeactivate AS VARCHAR(2)) + ' ' + Status FROM #L WHERE UserId = @Sys), 'not listed');
    INSERT INTO @T SELECT 'User Master: an ordinary Admin row stays editable', '1 1',
           ISNULL((SELECT CAST(CanEdit AS VARCHAR(2)) + ' ' + CAST(CanDeactivate AS VARCHAR(2)) FROM #L WHERE UserId = @AdmB), 'not listed');

    DELETE FROM #U; INSERT INTO #U EXEC spr_GetUser;
    INSERT INTO @T SELECT 'spr_GetUser (Audit Trail) lists the system account', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM #U WHERE UserId = @Sys;

    DELETE FROM #U; INSERT INTO #U EXEC spr_GetActiveUserList;
    INSERT INTO @T SELECT 'Active user list (workflow mail) leaves it out', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM #U WHERE UserId = @Sys;
    INSERT INTO @T SELECT 'Another user named "admin": now in User Master and the active list', '1 1',
           CAST((SELECT COUNT(*) FROM #L WHERE UserId = @Admin2) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM #U WHERE UserId = @Admin2) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 7. No workflow alerts, action items or alert mail
    ---------------------------------------------------------------------------
    EXEC spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'Z8A', @CommitteeName = 'ZZ step 18 committee',
         @Board = 0, @IncorporationDate = '2000-01-01', @MeetingStartNo = 1, @CommitteeColorCode = '#FFFFFF', @CessationDate = '',
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA;
    SET @C = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'Z8A');
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Committee' AND SourceTypeId = @C ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Committee alert: system account / ordinary Admin mapped', '0 1',
           CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Sys) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @AdmA) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99981', @CommitteeId = @C,
         @Place = 'ZZ', @Venue = 'ZZ', @MeetingDate = @MDate, @MeetingTime = '10:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA;
    SET @Mt = (SELECT MeetingId FROM Meeting WHERE CommitteeId = @C AND MeetingNo = '99981');
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @Mt ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Meeting alert: system account / ordinary Admin mapped', '0 1',
           CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Sys) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @AdmA) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ18 user', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrA, @UpdatedOn = @Now, @UpdatedBy = @UsrA, @SubjectNo = NULL, @ActingUserId = @UsrA;
    SET @AgA = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @UsrA ORDER BY AgendaId DESC);
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgA ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Agenda by a User (AC): ordinary Admin / system account / manager mapped', 'Result 1, Reason 0; 1 0 1',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @AdmA) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Sys) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @MgrA) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ18 manager', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = 'ok', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @MgrA, @UpdatedOn = @Now, @UpdatedBy = @MgrA, @SubjectNo = NULL, @ActingUserId = @MgrA;
    SET @AgM = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @MgrA ORDER BY AgendaId DESC);
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgM ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Agenda by a Manager (AMA): ordinary Admin / system account mapped', '1 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @AdmA) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Sys) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ18 controller', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = 'ok', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA, @SubjectNo = NULL, @ActingUserId = @CtlA;
    SET @AgK = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @CtlA ORDER BY AgendaId DESC);
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgK ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Agenda by the Controller (ACA): ordinary Admin / system account mapped', '1 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @AdmA) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Sys) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 8. Approve / reject: the system account cannot sign off
    ---------------------------------------------------------------------------
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgA ORDER BY AlertId DESC);
    -- A row the system account had on this alert before step 18 (kept)
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@A, @Sys, 1, 1);
    SET @SavedAlertRow = SCOPE_IDENTITY();

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = 'ZZ18 user', @ProposedResolution = 'ZZ',
         @MgrComments = 'sys', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'System account approves as Manager: refused, agenda unchanged, no audit row', 'Result 0, Reason 12; AC 0',
           (SELECT Txt FROM @R) + '; ' + (SELECT ISNULL(AgendaStatusCode, 'NULL') FROM Agenda WHERE AgendaId = @AgA) + ' '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Update_By = @Sys AND Key_Field = 'AgendaNo' AND Update_On >= @Now) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = 'ZZ18 user', @ProposedResolution = 'ZZ',
         @MgrComments = '', @ControllerComments = 'sys', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'System account rejects as Controller: refused, agenda unchanged', 'Result 0, Reason 12; AC',
           (SELECT Txt FROM @R) + '; ' + (SELECT ISNULL(AgendaStatusCode, 'NULL') FROM Agenda WHERE AgendaId = @AgA);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = 'ZZ18 user', @ProposedResolution = 'ZZ',
         @MgrComments = '', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = '', @UpdatedBy = @AdmA;
    INSERT INTO @T SELECT 'Ordinary Admin approve: unchanged behaviour (done, no status change)', 'Result 1, Reason 0; AC',
           (SELECT Txt FROM @R) + '; ' + (SELECT ISNULL(AgendaStatusCode, 'NULL') FROM Agenda WHERE AgendaId = @AgA);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = 'ZZ18 user', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @MgrA;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = 'ZZ18 user', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Manager then Controller approve: done, the system account''s saved row kept', 'Result 1, Reason 0; ACA kept',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgA) + ' '
         + CASE WHEN EXISTS (SELECT 1 FROM Alert_User_Map WHERE AlertUserId = @SavedAlertRow AND UserId = @Sys) THEN 'kept' ELSE 'gone' END;

    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAlertMailId @Code = 'ACA', @UserId = @CtlA, @AgendaId = @AgA;
    INSERT INTO @T SELECT 'Mail ACA: the system account''s saved row is not mailed, the ordinary Admin is', '0 1',
           CAST((SELECT COUNT(*) FROM @ML WHERE EmailId = 'zz18system@example.invalid') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @ML WHERE EmailId = 'zz18adma@example.invalid') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 9. Action items
    ---------------------------------------------------------------------------
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99982', @C, 'ZZ', 'ZZ', @MDate, '10:00', @MDate, 'Close', 'Open');
    SET @MtF = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z8A-99982-001', @C, @MtF, @DepartmentId, @SubjectTypeId, 'ZZ18 F1', 'Entry', 'ZZ', 'ZZ', 'Approved', @Now, @UsrA);
    SET @AgF1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z8A-99982-002', @C, @MtF, @DepartmentId, @SubjectTypeId, 'ZZ18 F2', 'Entry', 'ZZ', 'ZZ', 'Approved', @Now, @UsrA);
    SET @AgF2 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgF1, 1, 'ZZ', 'ZZ', @Now, @CtlA, @Now, @CtlA);
    SET @MinF1 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgF2, 1, 'ZZ', 'ZZ', @Now, @CtlA, @Now, @CtlA);
    SET @MinF2 = SCOPE_IDENTITY();
    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy) VALUES (@MinF2, 'ZZ', '', '', @Now, @CtlA);
    SET @AI2 = SCOPE_IDENTITY();
    INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId) VALUES (@AI2, @Sys, 1, 1);
    SET @AISaved = SCOPE_IDENTITY();

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MtF, @UserId = @CtlA;
    INSERT INTO @T SELECT 'Minutes finalize, new item: ordinary Admin / system account mapped', 'Result 1, Reason 0; 1 0',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinF1 AND m.UserId = @AdmA) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinF1 AND m.UserId = @Sys) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Minutes finalize, existing item: the system account''s saved row kept', 'kept',
           CASE WHEN EXISTS (SELECT 1 FROM ActionItem_User_Map WHERE ActionItemUserMapId = @AISaved AND UserId = @Sys) THEN 'kept' ELSE 'gone' END;

    -- An agenda item the system account created long ago; a follow-up is added on the Minutes Update page
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99983', @C, 'ZZ', 'ZZ', @MDate, '10:00', @MDate, 'Close', 'F');
    SET @MtU = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z8A-99983-001', @C, @MtU, @DepartmentId, @SubjectTypeId, 'ZZ18 sys', 'Entry', 'ZZ', 'ZZ', 'Approved', @Now, @Sys);
    SET @AgSys = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgSys, @DecisionOther, 'ZZ', 'ZZ', @Now, @CtlA, @Now, @CtlA);
    SET @MinU = SCOPE_IDENTITY();
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @MinU, @DecisionTypeId = 1,
         @Directions = '', @ActualResolution = '', @ShortText = 'ZZ18 sys', @CreatedBy = @CtlA, @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Late action item of an agenda by the system account: goes to the Controllers', 'Result 1, Reason 0; 0 ' + CAST(@ActiveCtrls AS VARCHAR(12)),
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinU AND m.UserId = @Sys) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId JOIN Users u ON u.UserId = m.UserId
                 WHERE a.MinutesId = @MinU AND u.RoleId = 2) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 10. Reset Database seed (procedure text; the procedure is not run here)
    ---------------------------------------------------------------------------
    SET @Def = OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase'));
    INSERT INTO @T SELECT 'Reset Database: Users insert lists IsSystem', '1',
           CASE WHEN @Def LIKE '%,[[]UpdatedBy],[[]IsSystem])%' THEN '1' ELSE '0' END;
    INSERT INTO @T SELECT 'Reset Database: one seed user with IsSystem 1, three with 0', '1 3',
           CAST((LEN(@Def) - LEN(REPLACE(@Def, 'GETDATE(), 1, GETDATE(), 1, 1', ''))) / LEN('GETDATE(), 1, GETDATE(), 1, 1') AS VARCHAR(4)) + ' '
         + CAST((LEN(@Def) - LEN(REPLACE(@Def, 'GETDATE(), 1, GETDATE(), 1, 0', ''))) / LEN('GETDATE(), 1, GETDATE(), 1, 0') AS VARCHAR(4));
    INSERT INTO @T SELECT 'Reset Database: the IsSystem 1 row is the "admin" seed', '1',
           CASE WHEN SUBSTRING(@Def, CHARINDEX('SELECT ''admin'', 1, 1,', @Def), 300) LIKE 'SELECT ''admin'', 1, 1,%GETDATE(), 1, GETDATE(), 1, 1%' THEN '1' ELSE '0' END;
    INSERT INTO @T SELECT 'Reset Database: seed e-mail addresses are placeholders', '3',
           CAST((LEN(@Def) - LEN(REPLACE(@Def, '@example.invalid''', ''))) / LEN('@example.invalid''') AS VARCHAR(4));

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
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

-- Confirm nothing was kept: should be 0 0 and one system account
SELECT (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z8A') AS TestCommitteesLeft,
       (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz18%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Users WHERE IsSystem = 1) AS SystemAccounts;
GO

SET NOEXEC OFF;
GO
