/* ============================================================================
   BMMS - Test of step 56 (step GM1a, the Governance Matrix and the
   governance change log)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY in a test copy whose name starts with "BMMS" and is not "BMMS"
   (BMMS_Test). It has no USE line: select BMMS_Test in SSMS first. Needs step
   56 installed. Written for compatibility level 100. The file is plain ASCII.
   Run the whole file (F5); it can run twice in one window.

   Part 1 reads only: the marker GovernanceLog-Step56 in the 26 objects, the
   markers of the earlier steps in the seven replaced texts, the parameters,
   no feature above compatibility level 100 in the new texts, the table, its
   key and the 32 keys to Users, the DENY of the log table and of the two
   internal procedures to public, Reset Database clearing the log before
   Users; M4 over the whole database for today: every row of the matrix
   (every transaction, department and column), the people by role, the
   settings, the departments' status and the Reporting Person equal between
   the live functions and their dated versions (both directions); the
   back-fill rows each match a history row of the same user and time.

   Part 2 runs in ONE transaction that is ROLLED BACK, with made-up data ZZ56:
   departments A, B, C; two Admins (made directly), a Controller, Management,
   MD Secretariat, an inactive Controller; users added through
   spr_AddEditUser (a Manager of A and B, a User of A, a User to delete).
   Checked: who may read (six roles, an inactive and a missing user, 0, the
   system account; Reasons 4 and 8); the dates (the day before the history
   start Reason 32, the history start, today, tomorrow and NULL Reason 33);
   the change log's dates (Reason 34); every change type written exactly once
   (UA, DA, DR, HC, RC, RP, UD, UV, UX with the role and departments held at
   the delete (C3), KD, KA, ST for both settings) and nothing written on a
   save that changes nothing (Edit with the same values, Deactivate of an
   inactive user, Activate of an active user, the same setting, the same
   department status); the delete of a user who wrote a log row (Reason 6
   "user changes"); spr_AddEditDepartment's refusals (8, 4) change nothing;
   the internal procedures refused at nesting level 1 and, run as bmms_app
   (when that user exists), EXECUTE and INSERT on the log refused; M4 again
   on the made-up data; past days: with the history rows moved back, the
   Manager of the day before the change, the setting, the department status
   and the Reporting Person of the day before; spr_GetGovernanceMatrix and
   spr_GetGovernanceChangeLog return the rows of the made-up data.
   Afterwards: Users, User_Role, User_Department, Department, App_Setting and
   Governance_Change_Log as before, no ZZ56 row left, every identity counter
   put back.
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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_WriteGovernanceChange')), '') NOT LIKE '%GovernanceLog-Step56%')
BEGIN
    RAISERROR('Step 56 (BMMS-Fix-GovernanceLog-Step56.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#ZZ56_Save') IS NOT NULL DROP PROCEDURE #ZZ56_Save;
IF OBJECT_ID('tempdb..#ZZ56_Edit') IS NOT NULL DROP PROCEDURE #ZZ56_Edit;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(400), Expected VARCHAR(400), Actual VARCHAR(400));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-- Add a user through spr_AddEditUser
CREATE PROCEDURE #ZZ56_Save
    @UserName VARCHAR(50), @LoginName VARCHAR(50), @RoleId INT, @DepartmentId INT, @ManagerId INT, @List VARCHAR(MAX), @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);

    EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @Desig, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @LoginName,
         @LoginName = @LoginName, @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
END
GO

-- Edit a user through spr_AddEditUser: the stored name, designation, mail and login, with the role, home
-- department, Reporting Person and department list given
CREATE PROCEDURE #ZZ56_Edit
    @UserId INT, @RoleId INT, @DepartmentId INT, @ManagerId INT, @List VARCHAR(MAX), @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @UserName VARCHAR(50), @DesignationId INT, @Mail VARCHAR(50), @LoginName VARCHAR(50);

    SELECT @UserName = UserName, @DesignationId = DesignationId, @Mail = EmailId, @LoginName = LoginName
    FROM Users WHERE UserId = @UserId;

    EXEC spr_AddEditUser @Code = 'Update', @UserId = @UserId, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @Mail,
         @LoginName = @LoginName, @Password = '', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
END
GO

-------------------------------------------------------------------------------
-- Part 1: reads only
-------------------------------------------------------------------------------
INSERT INTO #T (Test, Expected, Actual)
SELECT 'The marker GovernanceLog-Step56 in the 26 objects', '26',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_GovernanceHistoryStart'), ('fn_UserRoleOn'), ('fn_UserDepartmentsOn'), ('fn_DepartmentManagersOn'),
                 ('fn_ReportingPersonOn'), ('fn_SettingOn'), ('fn_DepartmentActiveOn'), ('fn_GovernanceRoleHolders'),
                 ('fn_GovernanceMatrixPeople'), ('fn_GovernanceRefusal'), ('fn_GovernanceDeptList'), ('fn_GovernanceUserSummary'),
                 ('spr_WriteGovernanceChange'), ('spr_WriteGovernanceUserChanges'), ('spr_GetGovernanceMatrix'),
                 ('spr_GetGovernanceSettings'), ('spr_GetGovernanceDepartments'), ('spr_GetGovernanceChangeLog'),
                 ('spr_GetGovernanceLogUsers'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId'), ('spr_DeleteUserByUserId'),
                 ('spr_AddEditDepartment'), ('spr_SetDepartmentManagerRule'), ('spr_SetAppSetting'), ('spr_sys_ResetDatabase')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%GovernanceLog-Step56%') AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'The replaced texts keep the markers of their earlier steps', '14',
       CAST((SELECT COUNT(*) FROM (VALUES
            ('spr_AddEditUser', '%UserHistory-Step39%'), ('spr_AddEditUser', '%ManagerRelease-Step52%'),
            ('spr_AddEditUser', '%DepartmentApprovers-Step53%'), ('spr_AddEditUser', '%ManagerScope-Step54%'),
            ('spr_SetUserStatusByUserId', '%UserHistory-Step39%'), ('spr_SetUserStatusByUserId', '%ManagerRelease-Step52%'),
            ('spr_SetUserStatusByUserId', '%DepartmentApprovers-Step53%'),
            ('spr_DeleteUserByUserId', '%UserHistory-Step39%'), ('spr_DeleteUserByUserId', '%FollowupFinal-Step47%'),
            ('spr_SetDepartmentManagerRule', '%UserHistory-Step39%'), ('spr_SetAppSetting', '%MeetingLocks-Step16%'),
            ('spr_sys_ResetDatabase', '%UserHistory-Step39%'), ('spr_sys_ResetDatabase', '%SmtpDefault-Step30%'),
            ('spr_sys_ResetDatabase', '%ResetSafe-Step29%')) m(Name, Marker)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + m.Name)), '') LIKE m.Marker) AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'Parameters: spr_AddEditDepartment 13 (@ActingUserId, @Result, @Reason added), spr_AddEditUser 17, spr_SetUserStatusByUserId 5, spr_DeleteUserByUserId 5, spr_GetGovernanceMatrix 5, spr_GetGovernanceChangeLog 8',
       '13 17 5 5 5 8',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditDepartment')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditUser')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_SetUserStatusByUserId')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_DeleteUserByUserId')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetGovernanceMatrix')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetGovernanceChangeLog')) AS VARCHAR(4));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'No THROW, TRY_CONVERT, IIF, CONCAT, FORMAT or OFFSET in the 19 new objects and the new spr_AddEditDepartment', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_GovernanceHistoryStart'), ('fn_UserRoleOn'), ('fn_UserDepartmentsOn'), ('fn_DepartmentManagersOn'),
                 ('fn_ReportingPersonOn'), ('fn_SettingOn'), ('fn_DepartmentActiveOn'), ('fn_GovernanceRoleHolders'),
                 ('fn_GovernanceMatrixPeople'), ('fn_GovernanceRefusal'), ('fn_GovernanceDeptList'), ('fn_GovernanceUserSummary'),
                 ('spr_WriteGovernanceChange'), ('spr_WriteGovernanceUserChanges'), ('spr_GetGovernanceMatrix'),
                 ('spr_GetGovernanceSettings'), ('spr_GetGovernanceDepartments'), ('spr_GetGovernanceChangeLog'),
                 ('spr_GetGovernanceLogUsers'), ('spr_AddEditDepartment')) o(Name)
             CROSS JOIN (VALUES ('%THROW%'), ('%TRY[_]CONVERT%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('% OFFSET %')) f(Pattern)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE f.Pattern) AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'The log table, its key to Users and the setting GovernanceLogFrom; keys to Users present and trusted', '1 1 1 32',
       CAST(CASE WHEN OBJECT_ID('dbo.Governance_Change_Log', 'U') IS NOT NULL THEN 1 ELSE 0 END AS VARCHAR(2)) + ' '
     + CAST(CASE WHEN OBJECT_ID('dbo.FK_Governance_Change_Log_ChangedBy', 'F') IS NOT NULL THEN 1 ELSE 0 END AS VARCHAR(2)) + ' '
     + CAST((SELECT COUNT(*) FROM App_Setting WHERE SettingCode = 'GovernanceLogFrom' AND ISDATE(SettingValue) = 1) AS VARCHAR(2)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.foreign_keys fk WHERE fk.referenced_object_id = OBJECT_ID('dbo.Users')
             AND fk.is_not_trusted = 0 AND fk.is_disabled = 0) AS VARCHAR(4));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'DENY to public: INSERT, UPDATE, DELETE on the log; EXECUTE on the two internal procedures (C5)', '3 2',
       CAST((SELECT COUNT(*) FROM sys.database_permissions p WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID('public')
             AND p.major_id = OBJECT_ID('dbo.Governance_Change_Log') AND p.state = 'D' AND p.permission_name IN ('INSERT', 'UPDATE', 'DELETE')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.database_permissions p WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID('public')
             AND p.major_id IN (OBJECT_ID('dbo.spr_WriteGovernanceChange'), OBJECT_ID('dbo.spr_WriteGovernanceUserChanges'))
             AND p.state = 'D' AND p.permission_name = 'EXECUTE') AS VARCHAR(4));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'Reset Database clears the log before Users, restarts its counter, and does not touch App_Setting (step 19)', '1 1 0',
       CAST(CASE WHEN CHARINDEX('DELETE FROM Governance_Change_Log;', OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')))
                      BETWEEN 1 AND CHARINDEX('DELETE FROM Users;', OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase'))) THEN 1 ELSE 0 END AS VARCHAR(2)) + ' '
     + CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%''User[_]Role'', ''User[_]Department'', ''Governance[_]Change[_]Log''%' THEN 1 ELSE 0 END AS VARCHAR(2)) + ' '
     + CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%App[_]Setting%' THEN 1 ELSE 0 END AS VARCHAR(2));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'LogFrom: the later of the install setting and the last Reset Database audit row', 'same',
       CASE WHEN ISNULL(CONVERT(VARCHAR(10), (SELECT LogFrom FROM dbo.fn_GovernanceHistoryStart()), 120), '-')
                 = ISNULL(CONVERT(VARCHAR(10), (SELECT MAX(x.d) FROM (
                       SELECT CONVERT(DATETIME, SettingValue, 126) AS d FROM App_Setting WHERE SettingCode = 'GovernanceLogFrom' AND ISDATE(SettingValue) = 1
                       UNION ALL SELECT MAX(Update_On) FROM Audit_Trail_Master WHERE Audit_Table = 'Database' AND Key_Field = 'Database' AND Field_Name = 'Reset') x), 120), '-')
            THEN 'same' ELSE 'DIFFERENT' END;
GO

-- M4 over the whole database, today
DECLARE @Today DATE = CAST(GETDATE() AS DATE);

INSERT INTO #T (Test, Expected, Actual)
SELECT 'M4, whole database, today: every row of the matrix (transaction, department, column, user), live not dated / dated not live', '0 0',
       CAST((SELECT COUNT(*) FROM (SELECT * FROM dbo.fn_GovernanceMatrixPeople(@Today, 1) EXCEPT SELECT * FROM dbo.fn_GovernanceMatrixPeople(@Today, 0)) x) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM (SELECT * FROM dbo.fn_GovernanceMatrixPeople(@Today, 0) EXCEPT SELECT * FROM dbo.fn_GovernanceMatrixPeople(@Today, 1)) x) AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'M4, whole database, today: fn_DepartmentManagersOn = fn_DepartmentManagers for every department (both directions)', '0 0',
       CAST((SELECT COUNT(*) FROM (SELECT d.DepartmentId, m.UserId FROM Department d CROSS APPLY dbo.fn_DepartmentManagers(d.DepartmentId) m
                                   EXCEPT SELECT d.DepartmentId, m.UserId FROM Department d CROSS APPLY dbo.fn_DepartmentManagersOn(d.DepartmentId, @Today) m) x) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM (SELECT d.DepartmentId, m.UserId FROM Department d CROSS APPLY dbo.fn_DepartmentManagersOn(d.DepartmentId, @Today) m
                                   EXCEPT SELECT d.DepartmentId, m.UserId FROM Department d CROSS APPLY dbo.fn_DepartmentManagers(d.DepartmentId) m) x) AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'M4, whole database, today: people by role, live not dated / dated not live', '0 0',
       CAST((SELECT COUNT(*) FROM (SELECT * FROM dbo.fn_GovernanceRoleHolders(@Today, 1) EXCEPT SELECT * FROM dbo.fn_GovernanceRoleHolders(@Today, 0)) x) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM (SELECT * FROM dbo.fn_GovernanceRoleHolders(@Today, 0) EXCEPT SELECT * FROM dbo.fn_GovernanceRoleHolders(@Today, 1)) x) AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'M4, whole database, today: the two settings, the departments status and the Reporting Person, dated = stored (differences)', '0 0 0 0',
       CAST((SELECT COUNT(*) FROM App_Setting s CROSS APPLY dbo.fn_SettingOn(s.SettingCode, @Today) f
             WHERE s.SettingCode = 'DeptNoManagerAction' AND ISNULL(f.SettingValue, '') <> ISNULL(s.SettingValue, '')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM App_Setting s CROSS APPLY dbo.fn_SettingOn(s.SettingCode, @Today) f
             WHERE s.SettingCode = 'AgendaControllerBypass' AND ISNULL(f.SettingValue, '') <> ISNULL(s.SettingValue, '')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM Department d JOIN dbo.fn_DepartmentActiveOn(@Today) a ON a.DepartmentId = d.DepartmentId
             WHERE a.IsActive <> CASE WHEN ISNULL(d.StatusId, 0) = 1 THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM Users u JOIN dbo.fn_ReportingPersonOn(@Today) r ON r.UserId = u.UserId
             WHERE ISNULL(r.ManagerId, 0) <> ISNULL(u.ManagerId, 0)) AS VARCHAR(4));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'Back-fill: every History row matches a history row of its user at its time; every Deactivate of the history after the migration has its UD row (mismatches / missing)', '0 0',
       CAST((SELECT COUNT(*) FROM Governance_Change_Log g WHERE g.Source = 'History'
             AND NOT EXISTS (SELECT 1 FROM User_Role r WHERE r.UserId = g.UserId AND (r.CreatedOn = g.ChangedOn OR r.ClosedOn = g.ChangedOn))
             AND NOT EXISTS (SELECT 1 FROM User_Department d WHERE d.UserId = g.UserId AND (d.CreatedOn = g.ChangedOn OR d.ClosedOn = g.ChangedOn))) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(DISTINCT CAST(r.UserId AS VARCHAR(12)) + '|' + CONVERT(VARCHAR(30), r.ClosedOn, 121)) FROM User_Role r
             WHERE r.CloseReason = 'D' AND r.ClosedOn > (SELECT MIN(CreatedOn) FROM User_Role)
             AND r.ClosedOn >= ISNULL((SELECT MIN(ChangedOn) FROM Governance_Change_Log WHERE Source = 'History'), '99991231')
             AND r.ClosedOn < ISNULL((SELECT MIN(ChangedOn) FROM Governance_Change_Log WHERE Source <> 'History' AND Source <> 'AuditTrail'), '99991231')
             AND NOT EXISTS (SELECT 1 FROM Governance_Change_Log g WHERE g.UserId = r.UserId AND g.ChangedOn = r.ClosedOn AND g.ChangeType = 'UD')) AS VARCHAR(12));
GO

-------------------------------------------------------------------------------
-- Part 2: made-up data in one transaction, rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(400), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @M TABLE (Kind CHAR(1), TransactionCode VARCHAR(10), DepartmentId INT, Col CHAR(1), RoleCode VARCHAR(50), UserId INT,
                  UserName VARCHAR(50), LoginName VARCHAR(50), ActiveNow INT, IsSystem INT);
DECLARE @L TABLE (GovChangeId INT, ChangedOn DATETIME, EffectiveOn DATE, ChangeType CHAR(2), ChangedBy INT, ChangedByName VARCHAR(50),
                  ChangedByLogin VARCHAR(50), ChangedByActive INT, UserId INT, UserName NVARCHAR(200), UserLogin NVARCHAR(50),
                  DepartmentId INT, DepartmentName NVARCHAR(200), SettingCode VARCHAR(50), OldValue NVARCHAR(1000),
                  NewValue NVARCHAR(1000), Source VARCHAR(64));
DECLARE @Now DATETIME = GETDATE();
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));
DECLARE @Tomorrow DATE = DATEADD(DAY, 1, CAST(GETDATE() AS DATE));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt');
DECLARE @rMds INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect');
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @Start DATE = (SELECT HistoryStart FROM dbo.fn_GovernanceHistoryStart());
DECLARE @DA INT, @DB INT, @DC INT, @Adm INT, @Adm2 INT, @Ctl INT, @Ctl0 INT, @Mgmt INT, @Mds INT, @Mgr INT, @Usr INT, @Del INT;
DECLARE @G0 INT, @Res INT, @Rsn INT, @Det VARCHAR(10), @Txt VARCHAR(400), @List VARCHAR(40), @Err VARCHAR(400);
DECLARE @DeptRule VARCHAR(250), @Bypass VARCHAR(250), @OtherRule VARCHAR(20), @OtherBypass VARCHAR(2);
DECLARE @UsersBefore VARCHAR(40), @UsersAfter VARCHAR(40), @HistBefore VARCHAR(80), @HistAfter VARCHAR(80);
DECLARE @LogBefore VARCHAR(40), @LogAfter VARCHAR(40), @SetBefore VARCHAR(40), @SetAfter VARCHAR(40);

SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, AccountStatus, RoleId, DepartmentId, ManagerId)), 0) AS VARCHAR(12)) FROM Users;
SET @HistBefore = CAST((SELECT COUNT(*) FROM User_Role) AS VARCHAR(12)) + ' ' + CAST((SELECT ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(*)), 0) FROM User_Role) AS VARCHAR(12)) + ' '
                + CAST((SELECT COUNT(*) FROM User_Department) AS VARCHAR(12)) + ' ' + CAST((SELECT ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(*)), 0) FROM User_Department) AS VARCHAR(12));
SELECT @LogBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(GovChangeId, ChangeType, UserId, OldValue, NewValue)), 0) AS VARCHAR(12)) FROM Governance_Change_Log;
SELECT @SetBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(SettingCode, SettingValue)), 0) AS VARCHAR(12)) FROM App_Setting;
SET @DeptRule = (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction');
SET @Bypass = (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass');
SET @OtherRule = CASE WHEN @DeptRule = 'controller' THEN 'refuse' ELSE 'controller' END;
SET @OtherBypass = CASE WHEN @Bypass = '0' THEN '1' ELSE '0' END;

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMds IS NULL
    OR @Desig IS NULL OR @Start IS NULL OR @DeptRule IS NULL OR @Bypass IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, the history start or one of the two settings is missing', 'PASS', 'SKIPPED');
END
ELSE
BEGIN
BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ56A', 'ZZ56 A', 996, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ56B', 'ZZ56 B', 997, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ56C', 'ZZ56 C', 998, 1, @Now, @Sys);
    SET @DC = SCOPE_IDENTITY();

    -- Made directly (no history rows: they count by Users, the rule of step 39)
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ56 admin', @DA, @Desig, NULL, @rAdmin, '', 'zz56adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ56 admin two', @DA, @Desig, NULL, @rAdmin, '', 'zz56adm2', 'not-a-login', 1, @Now);
    SET @Adm2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ56 controller', @DA, @Desig, NULL, @rCtl, '', 'zz56ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ56 controller inactive', @DA, @Desig, NULL, @rCtl, '', 'zz56ctl0', 'not-a-login', 0, @Now);
    SET @Ctl0 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ56 management', @DA, @Desig, NULL, @rMgmt, '', 'zz56mgmt', 'not-a-login', 1, @Now);
    SET @Mgmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ56 md secretariat', @DA, @Desig, NULL, @rMds, '', 'zz56mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- UA: a Manager of A (home) and B, added by the Admin
    ---------------------------------------------------------------------------
    SET @G0 = ISNULL((SELECT MAX(GovChangeId) FROM Governance_Change_Log), 0);
    SET @List = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Save @UserName = 'ZZ56 manager', @LoginName = 'zz56mgr', @RoleId = @rMgr, @DepartmentId = @DA, @ManagerId = NULL, @List = @List, @Actor = @Adm;
    SET @Mgr = (SELECT UserId FROM Users WHERE LoginName = 'zz56mgr');
    INSERT INTO @T SELECT 'UA: a new Manager (A home, B): saved, one UA row by the Admin with the role and the departments', 'Result 1; 1 row; UA ' + CAST(@Adm AS VARCHAR(12)) + ' Manager; ZZ56 A (home), ZZ56 B',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) FROM @R), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' row; '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(ChangedBy AS VARCHAR(12)) + ' ' + CAST(NewValue AS VARCHAR(200))
                   FROM Governance_Change_Log WHERE GovChangeId > @G0 AND UserId = @Mgr), 'none');

    -- A User of A, and a User to delete later
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Save @UserName = 'ZZ56 user', @LoginName = 'zz56usr', @RoleId = @rUser, @DepartmentId = @DA, @ManagerId = NULL, @List = NULL, @Actor = @Adm;
    SET @Usr = (SELECT UserId FROM Users WHERE LoginName = 'zz56usr');
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Save @UserName = 'ZZ56 to delete', @LoginName = 'zz56del', @RoleId = @rMgr, @DepartmentId = @DB, @ManagerId = NULL, @List = NULL, @Actor = @Adm2;
    SET @Del = (SELECT UserId FROM Users WHERE LoginName = 'zz56del');

    ---------------------------------------------------------------------------
    -- Nothing written on a save that changes nothing
    ---------------------------------------------------------------------------
    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Edit @UserId = @Mgr, @RoleId = @rMgr, @DepartmentId = @DA, @ManagerId = NULL, @List = @List, @Actor = @Adm;
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Edit @UserId = @Usr, @RoleId = @rUser, @DepartmentId = @DA, @ManagerId = NULL, @List = NULL, @Actor = @Adm;
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Usr, @AccountStatus = 1, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'No change: Edit of the Manager and of the User with the same values, Activate of an active user: saved, no row', 'Result 1; 0',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) FROM @R), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4));

    ---------------------------------------------------------------------------
    -- DA, DR, HC
    ---------------------------------------------------------------------------
    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    SET @List = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12));
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Edit @UserId = @Mgr, @RoleId = @rMgr, @DepartmentId = @DA, @ManagerId = NULL, @List = @List, @Actor = @Adm;
    INSERT INTO @T SELECT 'DA: department C added to the Manager: one row, DA ZZ56 C', '1 DA ZZ56 C',
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(DepartmentName AS VARCHAR(50)) FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');

    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    SET @List = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Edit @UserId = @Mgr, @RoleId = @rMgr, @DepartmentId = @DA, @ManagerId = NULL, @List = @List, @Actor = @Adm;
    INSERT INTO @T SELECT 'DR: department C removed from the Manager: one row, DR ZZ56 C', '1 DR ZZ56 C',
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(DepartmentName AS VARCHAR(50)) FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');

    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Edit @UserId = @Mgr, @RoleId = @rMgr, @DepartmentId = @DB, @ManagerId = NULL, @List = @List, @Actor = @Adm;
    INSERT INTO @T SELECT 'HC: the Manager''s home department A -> B (A kept): one row, HC ZZ56 A -> ZZ56 B, no DA or DR', '1 HC ZZ56 A -> ZZ56 B',
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(OldValue AS VARCHAR(50)) + ' -> ' + CAST(NewValue AS VARCHAR(50)) FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');

    ---------------------------------------------------------------------------
    -- RP, RC
    ---------------------------------------------------------------------------
    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Edit @UserId = @Usr, @RoleId = @rUser, @DepartmentId = @DA, @ManagerId = @Ctl, @List = NULL, @Actor = @Adm;
    INSERT INTO @T SELECT 'RP: the User''s Reporting Person (none) -> the Controller: one row RP with the ids', '1 RP - ' + CAST(@Ctl AS VARCHAR(12)),
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + ISNULL(CAST(OldId AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(NewId AS VARCHAR(12)), '-') FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');

    INSERT INTO @T SELECT 'Route C today: the User of A whose Reporting Person is a Controller is in AGU R (live and dated)', '1 1',
           CAST((SELECT COUNT(*) FROM dbo.fn_GovernanceMatrixPeople(@Today, 1) WHERE TransactionCode = 'AGU' AND Col = 'R' AND UserId = @Usr AND DepartmentId = @DA) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_GovernanceMatrixPeople(@Today, 0) WHERE TransactionCode = 'AGU' AND Col = 'R' AND UserId = @Usr AND DepartmentId = @DA) AS VARCHAR(4));

    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Edit @UserId = @Usr, @RoleId = @rMgmt, @DepartmentId = @DA, @ManagerId = @Ctl, @List = NULL, @Actor = @Adm;
    INSERT INTO @T SELECT 'RC: the User''s role User -> Management: one row RC User -> Management', '1 RC User -> Management',
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(OldValue AS VARCHAR(50)) + ' -> ' + CAST(NewValue AS VARCHAR(50)) FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');
    DELETE FROM @R;
    INSERT INTO @R EXEC #ZZ56_Edit @UserId = @Usr, @RoleId = @rUser, @DepartmentId = @DA, @ManagerId = @Ctl, @List = NULL, @Actor = @Adm;

    ---------------------------------------------------------------------------
    -- UD, UV and their no-change cases
    ---------------------------------------------------------------------------
    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Usr, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'UD: Deactivate of the User: one row, the role and department before', '1 UD User; ZZ56 A (home) -> Inactive',
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(OldValue AS VARCHAR(80)) + ' -> ' + CAST(NewValue AS VARCHAR(50)) FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');

    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Usr, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'No change: Deactivate of an inactive user: no row', '0',
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4));

    INSERT INTO @T SELECT 'An inactive user is never shown as able to act today (AGU E, AIS E, AIR E; live and dated)', '0 0',
           CAST((SELECT COUNT(*) FROM dbo.fn_GovernanceMatrixPeople(@Today, 1) WHERE UserId IN (@Usr, @Ctl0)) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_GovernanceMatrixPeople(@Today, 0) WHERE UserId IN (@Usr, @Ctl0)) AS VARCHAR(4));

    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @Usr, @AccountStatus = 1, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'UV: Activate of the User: one row', '1 UV Inactive -> User; ZZ56 A (home)',
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(OldValue AS VARCHAR(50)) + ' -> ' + CAST(NewValue AS VARCHAR(80)) FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');

    ---------------------------------------------------------------------------
    -- UX (C3) and the delete of a user who wrote a log row
    ---------------------------------------------------------------------------
    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Del, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'UX: delete of an unused Manager: deleted; one row with the role and home department held (C3); the UA row about him kept', 'Result 1; 1 UX Manager; ZZ56 B (home) -> Deleted; zz56del; UA kept',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) FROM @R), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(OldValue AS VARCHAR(80)) + ' -> ' + CAST(NewValue AS VARCHAR(50)) + '; ' + CAST(UserLogin AS VARCHAR(50))
                   FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none') + '; '
         + CASE WHEN EXISTS (SELECT 1 FROM Governance_Change_Log WHERE UserId = @Del AND ChangeType = 'UA') THEN 'UA kept' ELSE 'UA gone' END;

    DELETE FROM @R;
    INSERT INTO @R EXEC spr_DeleteUserByUserId @UserId = @Adm2, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Delete of the second Admin, who wrote a log row (ChangedBy): refused, Reason 6, "user changes"', 'Result 0, Reason 6, user changes',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4))
                          + CASE WHEN ReasonDetail LIKE '%user changes%' THEN ', user changes' ELSE ', ' + CAST(ReasonDetail AS VARCHAR(200)) END FROM @R), 'none');

    ---------------------------------------------------------------------------
    -- KD, KA (C1) and the refusals of spr_AddEditDepartment
    ---------------------------------------------------------------------------
    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_AddEditDepartment @Code = 'Update', @DepartmentId = @DC, @DepartmentCode = 'ZZ56C', @DepartmentName = 'ZZ56 C changed', @OrderNo = 998,
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @ActingUserId = @Ctl;
    INSERT INTO @R EXEC spr_AddEditDepartment @Code = 'Update', @DepartmentId = @DC, @DepartmentCode = 'ZZ56C', @DepartmentName = 'ZZ56 C changed', @OrderNo = 998,
         @StatusId = 0, @CreatedOn = @Now, @CreatedBy = @Ctl0, @UpdatedOn = @Now, @UpdatedBy = @Ctl0, @ActingUserId = @Ctl0;
    INSERT INTO @R EXEC spr_AddEditDepartment @Code = 'Update', @DepartmentId = @DC, @DepartmentCode = 'ZZ56C', @DepartmentName = 'ZZ56 C changed', @OrderNo = 998,
         @StatusId = 0, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @R EXEC spr_AddEditDepartment @Code = 'Save', @DepartmentId = 0, @DepartmentCode = 'ZZ56D', @DepartmentName = 'ZZ56 D', @OrderNo = 999,
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Mgmt, @UpdatedOn = @Now, @UpdatedBy = @Mgmt, @ActingUserId = @Mgmt;
    INSERT INTO @T SELECT 'Department save refused for the Controller (4), an inactive user (8), no acting user (8), Management on Save (4): nothing changed, no row',
           '0/4 0/8 0/8 0/4; ZZ56 C 1; no D; 0',
           ISNULL(STUFF((SELECT ' ' + CAST(Result AS VARCHAR(4)) + '/' + CAST(Reason AS VARCHAR(4)) FROM @R FOR XML PATH('')), 1, 1, ''), 'none') + '; '
         + (SELECT CAST(DepartmentName AS VARCHAR(50)) + ' ' + CAST(StatusId AS VARCHAR(4)) FROM Department WHERE DepartmentId = @DC) + '; '
         + CASE WHEN EXISTS (SELECT 1 FROM Department WHERE DepartmentCode = 'ZZ56D') THEN 'D saved' ELSE 'no D' END + '; '
         + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4));

    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_AddEditDepartment @Code = 'Update', @DepartmentId = @DC, @DepartmentCode = 'ZZ56C', @DepartmentName = 'ZZ56 C', @OrderNo = 998,
         @StatusId = 0, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'KD: department C made inactive by the Admin: saved, one row KD Active -> Inactive', 'Result 1; 1 KD Active -> Inactive',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) FROM @R), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType + ' ' + CAST(OldValue AS VARCHAR(50)) + ' -> ' + CAST(NewValue AS VARCHAR(50)) FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');

    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_AddEditDepartment @Code = 'Update', @DepartmentId = @DC, @DepartmentCode = 'ZZ56C', @DepartmentName = 'ZZ56 C renamed', @OrderNo = 998,
         @StatusId = 0, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm, @ActingUserId = @Adm;
    INSERT INTO @R EXEC spr_AddEditDepartment @Code = 'Save', @DepartmentId = 0, @DepartmentCode = 'ZZ56D', @DepartmentName = 'ZZ56 D', @OrderNo = 999,
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'No change: a rename with the same status, and a new department: saved, no row', '1 1; 0',
           ISNULL(STUFF((SELECT ' ' + CAST(Result AS VARCHAR(4)) FROM @R FOR XML PATH('')), 1, 1, ''), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4));

    INSERT INTO @T SELECT 'Department status as on yesterday and today (dated): C was active, is inactive', '1 0',
           CAST((SELECT IsActive FROM dbo.fn_DepartmentActiveOn(DATEADD(DAY, -1, @Today)) WHERE DepartmentId = @DC) AS VARCHAR(4)) + ' '
         + CAST((SELECT IsActive FROM dbo.fn_DepartmentActiveOn(@Today) WHERE DepartmentId = @DC) AS VARCHAR(4));

    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_AddEditDepartment @Code = 'Update', @DepartmentId = @DC, @DepartmentCode = 'ZZ56C', @DepartmentName = 'ZZ56 C', @OrderNo = 998,
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'KA: department C made active again: one row KA', '1 KA',
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 ChangeType FROM Governance_Change_Log WHERE GovChangeId > @G0), 'none');

    ---------------------------------------------------------------------------
    -- ST: both settings, and the same value again
    ---------------------------------------------------------------------------
    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    DELETE FROM @R;
    INSERT INTO @R EXEC spr_SetDepartmentManagerRule @SettingValue = @OtherRule, @ActingUserId = @Adm;
    INSERT INTO @R EXEC spr_SetDepartmentManagerRule @SettingValue = @OtherRule, @ActingUserId = @Adm;
    INSERT INTO @R EXEC spr_SetAppSetting @SettingCode = 'AgendaControllerBypass', @SettingValue = @OtherBypass, @ActingUserId = @Adm;
    INSERT INTO @R EXEC spr_SetAppSetting @SettingCode = 'AgendaControllerBypass', @SettingValue = @OtherBypass, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'ST: each setting changed once and saved again with the same value: two rows (one per setting), old and new value',
           '2; DeptNoManagerAction ' + @DeptRule + ' -> ' + @OtherRule + '; AgendaControllerBypass ' + @Bypass + ' -> ' + @OtherBypass,
           CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4)) + '; '
         + ISNULL((SELECT TOP 1 SettingCode + ' ' + CAST(OldValue AS VARCHAR(20)) + ' -> ' + CAST(NewValue AS VARCHAR(20)) FROM Governance_Change_Log
                   WHERE GovChangeId > @G0 AND ChangeType = 'ST' AND SettingCode = 'DeptNoManagerAction'), 'none') + '; '
         + ISNULL((SELECT TOP 1 SettingCode + ' ' + CAST(OldValue AS VARCHAR(20)) + ' -> ' + CAST(NewValue AS VARCHAR(20)) FROM Governance_Change_Log
                   WHERE GovChangeId > @G0 AND ChangeType = 'ST' AND SettingCode = 'AgendaControllerBypass'), 'none');

    INSERT INTO @T SELECT 'The settings as on yesterday (dated): the values before today''s change', @DeptRule + ' ' + @Bypass,
           ISNULL((SELECT SettingValue FROM dbo.fn_SettingOn('DeptNoManagerAction', DATEADD(DAY, -1, @Today))), 'NULL') + ' '
         + ISNULL((SELECT SettingValue FROM dbo.fn_SettingOn('AgendaControllerBypass', DATEADD(DAY, -1, @Today))), 'NULL');

    ---------------------------------------------------------------------------
    -- The internal procedures (C5)
    ---------------------------------------------------------------------------
    SET @G0 = (SELECT MAX(GovChangeId) FROM Governance_Change_Log);
    SET @Err = 'no error';
    BEGIN TRY
        EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @Adm, @Source = 'direct', @ChangeType = 'ST', @SettingCode = 'X';
    END TRY
    BEGIN CATCH
        SET @Err = CASE WHEN ERROR_MESSAGE() LIKE '%is internal%' THEN 'refused' ELSE LEFT(ERROR_MESSAGE(), 100) END;
    END CATCH
    SET @Txt = @Err;
    SET @Err = 'no error';
    BEGIN TRY
        EXEC dbo.spr_WriteGovernanceUserChanges @ActingUserId = @Adm, @Source = 'direct', @UserId = @Usr, @Existed = 0;
    END TRY
    BEGIN CATCH
        SET @Err = CASE WHEN ERROR_MESSAGE() LIKE '%is internal%' THEN 'refused' ELSE LEFT(ERROR_MESSAGE(), 100) END;
    END CATCH
    INSERT INTO @T SELECT 'A direct call (nesting level 1) of the two internal procedures is refused; no row', 'refused refused 0',
           @Txt + ' ' + @Err + ' ' + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4));

    IF (DATABASE_PRINCIPAL_ID('bmms_app') IS NULL)
        INSERT INTO @T VALUES ('As bmms_app: EXECUTE of the internal procedure and INSERT into the log refused (no bmms_app user in this database)', 'PASS', 'SKIPPED');
    ELSE
    BEGIN
        SET @Txt = '';
        EXECUTE AS USER = 'bmms_app';
        BEGIN TRY
            EXEC dbo.spr_WriteGovernanceChange @ActingUserId = 1, @Source = 'bmms_app', @ChangeType = 'ST', @SettingCode = 'X';
            SET @Txt = 'run';
        END TRY
        BEGIN CATCH
            SET @Txt = CASE WHEN ERROR_NUMBER() = 229 THEN 'denied' ELSE 'error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) END;
        END CATCH
        BEGIN TRY
            INSERT INTO dbo.Governance_Change_Log (ChangedOn, EffectiveOn, ChangeType, Source) VALUES (GETDATE(), GETDATE(), 'ST', 'bmms_app');
            SET @Txt = @Txt + ' inserted';
        END TRY
        BEGIN CATCH
            SET @Txt = @Txt + CASE WHEN ERROR_NUMBER() = 229 THEN ' denied' ELSE ' error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) END;
        END CATCH
        REVERT;
        INSERT INTO @T SELECT 'As bmms_app: EXECUTE of spr_WriteGovernanceChange and INSERT into the log refused (permission, error 229); no row', 'denied denied 0',
               @Txt + ' ' + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE GovChangeId > @G0) AS VARCHAR(4));
    END

    ---------------------------------------------------------------------------
    -- Who may read, and the dates
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Who may read: Admin, Controller, system account 0; Manager, User, Management, MD Secretariat 4; inactive Controller, missing user, 0 8',
           '0 0 0 4 4 4 4 8 8 8',
           (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Adm, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Ctl, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Sys, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Mgr, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Usr, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Mgmt, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Mds, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Ctl0, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(-5, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(0, @Today));

    INSERT INTO @T SELECT 'M2 dates: the day before the history start 32 (the start given), the start 0, today 0 (live), tomorrow 33, NULL 33',
           '32 ' + CONVERT(VARCHAR(10), @Start, 120) + ' 0 0 1 33 33',
           (SELECT CAST(Reason AS VARCHAR(4)) + ' ' + HistoryStart FROM dbo.fn_GovernanceRefusal(@Ctl, DATEADD(DAY, -1, @Start))) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Ctl, @Start)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) + ' ' + CAST(IsLive AS VARCHAR(2)) FROM dbo.fn_GovernanceRefusal(@Ctl, @Today)) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Ctl, DATEADD(DAY, 1, @Today))) + ' '
         + (SELECT CAST(Reason AS VARCHAR(4)) FROM dbo.fn_GovernanceRefusal(@Ctl, NULL));

    DELETE FROM @M; SET @Res = NULL; SET @Rsn = NULL; SET @Det = NULL;
    INSERT INTO @M EXEC spr_GetGovernanceMatrix @ActingUserId = @Mgr, @AsOn = @Today, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @Detail = @Det OUTPUT;
    SET @Txt = CAST(@Res AS VARCHAR(4)) + '/' + CAST(@Rsn AS VARCHAR(4)) + ' ' + CAST((SELECT COUNT(*) FROM @M) AS VARCHAR(12));
    DELETE FROM @M; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO @M EXEC spr_GetGovernanceMatrix @ActingUserId = @Ctl, @AsOn = @Today, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @Detail = @Det OUTPUT;
    INSERT INTO @T SELECT 'spr_GetGovernanceMatrix: refused for the Manager (0/4, no rows); for the Controller today: the Manager in APM A for A and B, the Controller in APC C, the User in AGU E and R for A',
           '0/4 0; 1/0 2 1 2',
           @Txt + '; ' + CAST(@Res AS VARCHAR(4)) + '/' + CAST(@Rsn AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM @M WHERE Kind = 'P' AND TransactionCode = 'APM' AND Col = 'A' AND UserId = @Mgr AND DepartmentId IN (@DA, @DB)) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM @M WHERE Kind = 'P' AND TransactionCode = 'APC' AND Col = 'C' AND UserId = @Ctl AND DepartmentId = 0) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM @M WHERE Kind = 'P' AND TransactionCode = 'AGU' AND Col IN ('E', 'R') AND UserId = @Usr AND DepartmentId = @DA) AS VARCHAR(4));

    ---------------------------------------------------------------------------
    -- M4 on the made-up data (after every change above)
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'M4 after the changes, today: every row of the matrix, live not dated / dated not live', '0 0',
           CAST((SELECT COUNT(*) FROM (SELECT * FROM dbo.fn_GovernanceMatrixPeople(@Today, 1) EXCEPT SELECT * FROM dbo.fn_GovernanceMatrixPeople(@Today, 0)) x) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM (SELECT * FROM dbo.fn_GovernanceMatrixPeople(@Today, 0) EXCEPT SELECT * FROM dbo.fn_GovernanceMatrixPeople(@Today, 1)) x) AS VARCHAR(12));

    INSERT INTO @T SELECT 'M4 after the changes, today: people by role, the Reporting Person, live = dated (differences)', '0 0 0',
           CAST((SELECT COUNT(*) FROM (SELECT * FROM dbo.fn_GovernanceRoleHolders(@Today, 1) EXCEPT SELECT * FROM dbo.fn_GovernanceRoleHolders(@Today, 0)) x) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM (SELECT * FROM dbo.fn_GovernanceRoleHolders(@Today, 0) EXCEPT SELECT * FROM dbo.fn_GovernanceRoleHolders(@Today, 1)) x) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Users u JOIN dbo.fn_ReportingPersonOn(@Today) r ON r.UserId = u.UserId WHERE ISNULL(r.ManagerId, 0) <> ISNULL(u.ManagerId, 0)) AS VARCHAR(4));

    INSERT INTO @T SELECT 'The Reporting Person of the User as on yesterday (none: changed today) and today (the Controller)', '- ' + CAST(@Ctl AS VARCHAR(12)),
           ISNULL((SELECT CAST(ManagerId AS VARCHAR(12)) FROM dbo.fn_ReportingPersonOn(DATEADD(DAY, -1, @Today)) WHERE UserId = @Usr), '-') + ' '
         + ISNULL((SELECT CAST(ManagerId AS VARCHAR(12)) FROM dbo.fn_ReportingPersonOn(@Today) WHERE UserId = @Usr), '-');

    ---------------------------------------------------------------------------
    -- A past day: the Manager's history moved back (he was a User of A from 10 days ago to 3 days ago, a Manager since)
    ---------------------------------------------------------------------------
    DELETE FROM User_Role WHERE UserId = @Mgr AND EffectiveTo IS NOT NULL;
    UPDATE User_Role SET EffectiveFrom = DATEADD(DAY, -3, @Today) WHERE UserId = @Mgr AND EffectiveTo IS NULL;
    INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, EffectiveTo, CreatedOn, CreatedBy, ClosedOn, ClosedBy, CloseReason)
    VALUES (@Mgr, @rUser, DATEADD(DAY, -10, @Today), DATEADD(DAY, -3, @Today), @Now, @Adm, @Now, @Adm, 'C');
    UPDATE User_Department SET EffectiveFrom = DATEADD(DAY, -10, @Today) WHERE UserId = @Mgr AND EffectiveTo IS NULL;

    INSERT INTO @T SELECT 'Past day (5 days ago): the Manager was a User (home B): not a Manager of A, in AGU E of B; today a Manager of A (dated and live)', '0 1 1 1',
           CAST((SELECT COUNT(*) FROM dbo.fn_DepartmentManagersOn(@DA, DATEADD(DAY, -5, @Today)) WHERE UserId = @Mgr) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_GovernanceMatrixPeople(DATEADD(DAY, -5, @Today), 0) WHERE TransactionCode = 'AGU' AND Col = 'E' AND UserId = @Mgr AND DepartmentId = @DB) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_DepartmentManagersOn(@DA, @Today) WHERE UserId = @Mgr) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_DepartmentManagers(@DA) WHERE UserId = @Mgr) AS VARCHAR(4));

    INSERT INTO @T SELECT 'Past day (11 days ago, before his first row): the Manager is not in the matrix of that day', '0',
           CAST((SELECT COUNT(*) FROM dbo.fn_GovernanceMatrixPeople(DATEADD(DAY, -11, @Today), 0) WHERE UserId = @Mgr) AS VARCHAR(4));

    ---------------------------------------------------------------------------
    -- The change log procedure
    ---------------------------------------------------------------------------
    DELETE FROM @L; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO @L EXEC spr_GetGovernanceChangeLog @ActingUserId = @Ctl, @From = @Today, @To = @Today, @UserId = @Mgr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = CAST(@Res AS VARCHAR(4)) + '/' + CAST(@Rsn AS VARCHAR(4)) + ' ' + CAST((SELECT COUNT(*) FROM @L) AS VARCHAR(4)) + ' '
             + ISNULL(STUFF((SELECT ',' + ChangeType FROM @L ORDER BY GovChangeId FOR XML PATH('')), 1, 1, ''), '-');
    DELETE FROM @L; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO @L EXEC spr_GetGovernanceChangeLog @ActingUserId = @Ctl, @From = @Today, @To = @Today, @DepartmentId = @DC, @ChangeType = 'KD', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + '; ' + CAST(@Res AS VARCHAR(4)) + '/' + CAST(@Rsn AS VARCHAR(4)) + ' ' + CAST((SELECT COUNT(*) FROM @L) AS VARCHAR(4));
    INSERT INTO @T SELECT 'spr_GetGovernanceChangeLog for the Controller, today: the Manager''s rows (UA, DA, DR, HC); department C, KD only', '1/0 4 UA,DA,DR,HC; 1/0 1', @Txt;

    SET @Txt = '';
    DELETE FROM @L; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO @L EXEC spr_GetGovernanceChangeLog @ActingUserId = @Ctl, @From = @Today, @To = @Yesterday, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = CAST(@Rsn AS VARCHAR(4)) + '/' + CAST((SELECT COUNT(*) FROM @L) AS VARCHAR(4));
    DELETE FROM @L; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO @L EXEC spr_GetGovernanceChangeLog @ActingUserId = @Ctl, @From = @Today, @To = @Tomorrow, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ' ' + CAST(@Rsn AS VARCHAR(4)) + '/' + CAST((SELECT COUNT(*) FROM @L) AS VARCHAR(4));
    DELETE FROM @L; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO @L EXEC spr_GetGovernanceChangeLog @ActingUserId = @Ctl, @From = NULL, @To = @Today, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ' ' + CAST(@Rsn AS VARCHAR(4)) + '/' + CAST((SELECT COUNT(*) FROM @L) AS VARCHAR(4));
    DELETE FROM @L; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO @L EXEC spr_GetGovernanceChangeLog @ActingUserId = @Mds, @From = @Today, @To = @Today, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    SET @Txt = @Txt + ' ' + CAST(@Rsn AS VARCHAR(4)) + '/' + CAST((SELECT COUNT(*) FROM @L) AS VARCHAR(4));
    INSERT INTO @T SELECT 'spr_GetGovernanceChangeLog refusals: From after To 34, To after today 34, From missing 34, MD Secretariat 4; no rows', '34/0 34/0 34/0 4/0', @Txt;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    INSERT INTO @T SELECT 'Part 2 ran to its end without an error', 'no error', LEFT('error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + ERROR_MESSAGE(), 400);
END CATCH
END

SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, AccountStatus, RoleId, DepartmentId, ManagerId)), 0) AS VARCHAR(12)) FROM Users;
SET @HistAfter = CAST((SELECT COUNT(*) FROM User_Role) AS VARCHAR(12)) + ' ' + CAST((SELECT ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(*)), 0) FROM User_Role) AS VARCHAR(12)) + ' '
               + CAST((SELECT COUNT(*) FROM User_Department) AS VARCHAR(12)) + ' ' + CAST((SELECT ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(*)), 0) FROM User_Department) AS VARCHAR(12));
SELECT @LogAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(GovChangeId, ChangeType, UserId, OldValue, NewValue)), 0) AS VARCHAR(12)) FROM Governance_Change_Log;
SELECT @SetAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(SettingCode, SettingValue)), 0) AS VARCHAR(12)) FROM App_Setting;

INSERT INTO @T SELECT 'After the rollback: Users, User_Role and User_Department, Governance_Change_Log, App_Setting as before',
       'same same same same',
       CASE WHEN @UsersAfter = @UsersBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @HistAfter = @HistBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @LogAfter = @LogBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @SetAfter = @SetBefore THEN 'same' ELSE 'DIFFERENT' END;

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
SELECT 'Identity counters as before the test', '0',
       CAST((SELECT COUNT(*) FROM #Ident i JOIN sys.tables t ON t.name = i.TableName JOIN sys.identity_columns ic ON ic.object_id = t.object_id
             WHERE ISNULL(CAST(ic.last_value AS BIGINT), -1) <> ISNULL(i.SavedValue, -1) AND i.SavedValue IS NOT NULL) AS VARCHAR(12));

INSERT INTO #T
SELECT 'After the test: no ZZ56 department, user or log row left', '0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ56%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz56%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Governance_Change_Log WHERE UserLogin LIKE 'zz56%' OR DepartmentName LIKE 'ZZ56%') AS VARCHAR(12));

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

DROP PROCEDURE #ZZ56_Edit;
DROP PROCEDURE #ZZ56_Save;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
