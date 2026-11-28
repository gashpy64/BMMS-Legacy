/* ============================================================================
   BMMS - Governance Matrix and the governance change log (step 56, step
   GM1a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decisions 2026-11-25 (requirement GM1, section 5, M1 to M11; the
   plan approved with the 12 answers as recommended and the changes C1 to
   C7):
     M1 to M7  A read-only page "Governance Matrix" for the Controller and
               the Admin: who enters, who approves (Managers: any one of)
               and the Controllers of every transaction and department, as
               on a date. Today's matrix reads the functions the software
               uses (fn_DepartmentManagers, fn_AgendaRoute,
               fn_FunctionalUsers, fn_UserDepartmentScope); a past date reads
               the dated versions over the history tables of step 39 and
               the change log. The history starts at the first User_Role
               row (step 39, or the last Reset Database).
     M8, M11   Governance_Change_Log: written by the procedures that change
               a user, a department's status or a setting, in the same
               transaction, only when something changed; no page updates or
               deletes a row (the application's database users may not
               insert, update or delete it directly: DENY to public; the
               procedures write it through ownership chaining). The
               Reporting Person and the department status are known from
               the install (App_Setting GovernanceLogFrom) or the last
               Reset Database (its audit row), whichever is later.
     M9        Back-fill at the first install: the step 39 history rows
               (Source 'History') and the Audit_Trail_Master rows of the
               settings DeptNoManagerAction and AgendaControllerBypass
               (Source 'AuditTrail').
     C1        spr_AddEditDepartment takes @ActingUserId and refuses a
               missing, 0 or inactive acting user (Reason 8) and any role
               other than Admin (Reason 4) before any change.
     C3        A delete (UX) records the role, the home department and the
               Manager's departments held at the delete.
     C5        spr_WriteGovernanceChange and spr_WriteGovernanceUserChanges
               are internal: EXECUTE is denied to public (bmms_app,
               bmms_site) and a call at nesting level 1 is refused.

   Objects (each carries the text GovernanceLog-Step56; a replaced text keeps
   the markers of its earlier steps)
     Governance_Change_Log            NEW table (key to Users: ChangedBy)
     App_Setting GovernanceLogFrom    NEW row
     fn_GovernanceHistoryStart        NEW (history start, log start)
     fn_UserRoleOn                    NEW (dated roles)
     fn_UserDepartmentsOn             NEW (dated departments)
     fn_DepartmentManagersOn          NEW (dated fn_DepartmentManagers)
     fn_ReportingPersonOn             NEW (dated Users.ManagerId)
     fn_SettingOn                     NEW (dated App_Setting value)
     fn_DepartmentActiveOn            NEW (dated Department.StatusId)
     fn_GovernanceRoleHolders         NEW (people by role, live or dated)
     fn_GovernanceMatrixPeople        NEW (the people of every rule, live
                                      or dated)
     fn_GovernanceRefusal             NEW (who may read; the date rules)
     fn_GovernanceDeptList            NEW (a user's departments, ids)
     fn_GovernanceUserSummary         NEW (role and departments, as text)
     spr_WriteGovernanceChange        NEW (internal: one log row)
     spr_WriteGovernanceUserChanges   NEW (internal: a user before / after)
     spr_GetGovernanceMatrix          NEW (the page: the people)
     spr_GetGovernanceSettings        NEW (the page: dates and settings)
     spr_GetGovernanceDepartments     NEW (the page: departments)
     spr_GetGovernanceChangeLog       NEW (the page: the change log)
     spr_GetGovernanceLogUsers        NEW (the page: the user filter)
     spr_AddEditUser                  REPLACED (step 54 text)
     spr_SetUserStatusByUserId        REPLACED (step 53 text)
     spr_DeleteUserByUserId           REPLACED (step 47 text)
     spr_AddEditDepartment            REPLACED (baseline text)
     spr_SetDepartmentManagerRule     REPLACED (step 39 text)
     spr_SetAppSetting                REPLACED (step 16 text)
     spr_sys_ResetDatabase            REPLACED (step 39 text): clears the
                                      log before Users (App_Setting is not
                                      touched, as since step 19)
   Keys to Users: 31 become 32 (FK_Governance_Change_Log_ChangedBy).

   Order: installed after step 55. Needs steps 39, 53, 54 and 55 and stops
   otherwise. The script was built from the seven texts as installed
   (identical in BMMS_Test and BMMS_Quality on 2026-11-25; SHA-1 of the text
   without carriage returns, in pieces of 4,000 characters) and stops,
   changing nothing, when one of them is neither that text nor already the
   step 56 text (a later change would be lost). Safe to re-run: the
   back-fill runs only while the log is empty.

   Re-run of an earlier step: the Fix and Rollback scripts of steps 47 and
   54 stop while step 56 is installed (guards added in step GM1a). The Fix
   scripts of steps 39, 52 and 53 and the Rollback scripts of steps 39, 52
   and 53 already stop while step 53, 54 or 55 is installed, which step 56
   needs. A re-run of step 2, 3, 6, 10, 13, 16, 18, 21, 29 or 30 brings back
   an older text of one of the seven: step 56 reads Partly; tell the
   Consultant.

   BMMS-Rollback-GovernanceLog-Step56.sql puts the seven texts back letter
   for letter and drops the new functions and procedures; it keeps the
   table, its rows and the setting row. Roll back the build of step GM1a
   FIRST: the Governance Matrix and Department Master pages of GM1a call the
   new procedures and the new parameter.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.
   QUOTED_IDENTIFIER and ANSI_NULLS must be ON (the filtered indexes of step
   39): the script sets them. From the command line use sqlcmd -I.
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
DECLARE @D NVARCHAR(MAX), @I INT, @H VARCHAR(400), @Name SYSNAME;
DECLARE @Texts TABLE (Name SYSNAME, Hash VARCHAR(400) NULL, BuiltFrom VARCHAR(400));
DECLARE @Bad SYSNAME;

INSERT INTO @Texts (Name, BuiltFrom) VALUES
('spr_AddEditUser', 'B7B728AECA90F66BC2B8BF260367087E8163D4BAED1D0B4D6F988CFD57AAE69E97780A47B4FEC048E893F07F33E7A83575408407BB7CB230E1F08F8D3973EC5A4971EE4E7EA5007668C3B4333630BEE62629469F19159239D87F3E1AA8A02C96C62C94D8'),
('spr_SetUserStatusByUserId', 'CBA0ECF3B91A1EB7FCFD85DDA18EF98D919A8C5EC1560A285DF4D8EFFDA1E134AE708FAF985133B070649ED0C78131B7B012E830BEBE99723B0773C0'),
('spr_DeleteUserByUserId', '33692C6B212590B65700F968F0A17A4B77C6B62A52180DD11D96D7C1057372273F1392791D25C595'),
('spr_AddEditDepartment', 'A286A255ADC713F7AAD861F5EDB32DAB11724F45'),
('spr_SetDepartmentManagerRule', '9E1F423421452F943E15EE9D341A323FA9AA6D8F'),
('spr_SetAppSetting', '66592EA6229BE421FC71A8DB14CB2005B2735DED'),
('spr_sys_ResetDatabase', 'ACFC620D8AA0877942AB02B40F21FBA97737EEB0F61B05B73F436CEDD14467D16E3E8107E1AFE27BC598AD998CEABED6CC4D072F69EC8B1667E36D2EDF19405C7F1FFB81A77F9123CC1CD66C8D9786AFAC752FAD72B8CDC83232763038760E6150C65498');

-- The seven objects as they are now
SET @Name = (SELECT MIN(Name) FROM @Texts);
WHILE (@Name IS NOT NULL)
BEGIN
    SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.' + @Name)), CHAR(13), ''); SET @H = ''; SET @I = 1;
    WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
    BEGIN
        SET @H = @H + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
        SET @I = @I + 4000;
    END
    UPDATE @Texts SET Hash = @H WHERE Name = @Name;
    SET @Name = (SELECT MIN(Name) FROM @Texts WHERE Name > @Name);
END

-- A text that is neither the one this step was built from nor already the step 56 text
SET @Bad = (SELECT TOP 1 t.Name FROM @Texts t
            WHERE ISNULL(t.Hash, '') <> t.BuiltFrom
              AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + t.Name)), '') NOT LIKE '%GovernanceLog-Step56%'
            ORDER BY t.Name);

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.User_Role', 'U') IS NULL OR OBJECT_ID('dbo.User_Department', 'U') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetDepartmentManagerRule')), '') NOT LIKE '%UserHistory-Step39%')
BEGIN
    RAISERROR('Step 39 (BMMS-Fix-UserHistory-Step39.sql) is not installed in "%s". The steps are installed in order: run steps 39 to 55 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_DepartmentManagers', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetUserStatusByUserId')), '') NOT LIKE '%DepartmentApprovers-Step53%')
BEGIN
    RAISERROR('Step 53 (BMMS-Fix-DepartmentApprovers-Step53.sql) is not installed in "%s". Run steps 53 to 55 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_ManagerDepartments', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%ManagerScope-Step54%')
BEGIN
    RAISERROR('Step 54 (BMMS-Fix-ManagerScope-Step54.sql) is not installed in "%s". Run steps 54 and 55 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_FunctionalUsers', 'IF') IS NULL)
BEGIN
    RAISERROR('Step 55 (BMMS-Fix-InactiveUsers-Step55.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@Bad IS NOT NULL)
BEGIN
    RAISERROR('%s in "%s" is not the text this step was built from and not the step 56 text either: a change made since would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @Bad, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- The governance change log (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- One row per change of a matrix input. ChangedOn the time of the change, EffectiveOn its day (a matrix "as on" a
-- day shows the state at the end of that day). ChangedBy the acting user (a key to Users: a user who changed
-- something cannot be deleted, Reason 6 'user changes'). UserId, DepartmentId: the user or department changed,
-- with their names as they were (no key: the rows about a deleted user stay). OldId / NewId: the role, department,
-- Reporting Person (a UserId) or status (0 / 1) before and after; OldValue / NewValue the same as text. Source: the
-- procedure that wrote the row, 'History' (back-filled from the step 39 history) or 'AuditTrail' (back-filled from
-- Audit_Trail_Master).
IF OBJECT_ID('dbo.Governance_Change_Log', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Governance_Change_Log
    (
        GovChangeId INT IDENTITY(1, 1) NOT NULL CONSTRAINT PK_Governance_Change_Log PRIMARY KEY,
        ChangedOn DATETIME NOT NULL,
        EffectiveOn DATE NOT NULL,
        ChangedBy INT NULL CONSTRAINT FK_Governance_Change_Log_ChangedBy REFERENCES dbo.Users (UserId),
        ChangeType CHAR(2) NOT NULL CONSTRAINT CK_Governance_Change_Log_ChangeType
            CHECK (ChangeType IN ('UA', 'RC', 'HC', 'DA', 'DR', 'RP', 'UV', 'UD', 'UX', 'KA', 'KD', 'ST')),
        UserId INT NULL,
        UserLogin NVARCHAR(50) NULL,
        UserName NVARCHAR(200) NULL,
        DepartmentId INT NULL,
        DepartmentName NVARCHAR(200) NULL,
        SettingCode VARCHAR(50) NULL,
        OldId INT NULL,
        NewId INT NULL,
        OldValue NVARCHAR(1000) NULL,
        NewValue NVARCHAR(1000) NULL,
        Source VARCHAR(64) NOT NULL CONSTRAINT CK_Governance_Change_Log_Source CHECK (LEN(Source) > 0)
    );

    CREATE INDEX IX_Governance_Change_Log_EffectiveOn ON dbo.Governance_Change_Log (EffectiveOn, ChangeType);
    CREATE INDEX IX_Governance_Change_Log_UserId ON dbo.Governance_Change_Log (UserId, ChangeType, EffectiveOn);

    PRINT 'Table Governance_Change_Log created.';
END
GO

-- The application's database users may read the log, not write it: the procedures write it (ownership chaining)
DENY INSERT, UPDATE, DELETE ON dbo.Governance_Change_Log TO public;
GO

-- From when the Reporting Person and the department status are recorded (the install; after a Reset Database the time of
-- the reset, read from its audit row)
IF NOT EXISTS (SELECT 1 FROM dbo.App_Setting WHERE SettingCode = 'GovernanceLogFrom')
    INSERT INTO dbo.App_Setting (SettingCode, SettingValue, Description)
    VALUES ('GovernanceLogFrom', CONVERT(VARCHAR(23), GETDATE(), 126),
            'The governance change log records the Reporting Person and the department status from this time (GovernanceLog-Step56)');
GO

-------------------------------------------------------------------------------
-- History start and log start (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- HistoryStart: the first day of the role history (the first User_Role row: step 39, or the last Reset Database).
-- LogFrom: the day from which the change log records the Reporting Person and the department status: the later of
-- App_Setting GovernanceLogFrom (the install of step 56) and the last Reset Database (its audit row; Reset Database
-- clears the log and does not touch App_Setting). NULL when unknown.
CREATE OR ALTER FUNCTION [dbo].[fn_GovernanceHistoryStart]
()
RETURNS TABLE
AS
RETURN
SELECT
(SELECT MIN(ur.EffectiveFrom) FROM dbo.User_Role ur) AS HistoryStart,
CAST(CASE WHEN x.ResetOn IS NOT NULL AND (x.InstalledOn IS NULL OR x.ResetOn > x.InstalledOn) THEN x.ResetOn
          ELSE x.InstalledOn END AS DATE) AS LogFrom
FROM (SELECT
      (SELECT CASE WHEN ISDATE(s.SettingValue) = 1 THEN CONVERT(DATETIME, s.SettingValue, 126) ELSE NULL END
       FROM dbo.App_Setting s WHERE s.SettingCode = 'GovernanceLogFrom') AS InstalledOn,
      (SELECT MAX(a.Update_On) FROM dbo.Audit_Trail_Master a
       WHERE a.Audit_Table = 'Database' AND a.Key_Field = 'Database' AND a.Field_Name = 'Reset') AS ResetOn) x;
GO

-------------------------------------------------------------------------------
-- Roles as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- One row per user who held a role at the end of @AsOn: the User_Role row that covers the day (a row covers
-- EffectiveFrom up to, not including, EffectiveTo; Deactivate closes every row, so an inactive user has none). A user
-- without any User_Role row (inserted directly, as the older test scripts do) counts with his role in Users while he
-- is active (the rule of step 39). For today this is the role of Users.RoleId of every active user (Test 56).
CREATE OR ALTER FUNCTION [dbo].[fn_UserRoleOn]
(
@AsOn DATE
)
RETURNS TABLE
AS
RETURN
SELECT ur.UserId, ur.RoleId, r.RoleCode, CAST(u.IsSystem AS INT) AS IsSystem
FROM dbo.User_Role ur
INNER JOIN dbo.Users u ON u.UserId = ur.UserId
INNER JOIN dbo.Roles r ON r.RoleId = ur.RoleId
WHERE ur.EffectiveFrom <= @AsOn
  AND (ur.EffectiveTo IS NULL OR ur.EffectiveTo > @AsOn)
UNION ALL
SELECT u.UserId, u.RoleId, r.RoleCode, CAST(u.IsSystem AS INT) AS IsSystem
FROM dbo.Users u
INNER JOIN dbo.Roles r ON r.RoleId = u.RoleId
WHERE u.AccountStatus = 1
  AND NOT EXISTS (SELECT 1 FROM dbo.User_Role x WHERE x.UserId = u.UserId);
GO

-------------------------------------------------------------------------------
-- Departments as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- One row per user and department of the User_Department rows that cover the end of @AsOn, IsHome 1 for the home
-- department. A user without any User_Department row counts as mapped to Users.DepartmentId (the rule of step 39).
CREATE OR ALTER FUNCTION [dbo].[fn_UserDepartmentsOn]
(
@AsOn DATE
)
RETURNS TABLE
AS
RETURN
SELECT ud.UserId, ud.DepartmentId, MAX(CAST(ud.IsHome AS INT)) AS IsHome
FROM dbo.User_Department ud
WHERE ud.EffectiveFrom <= @AsOn
  AND (ud.EffectiveTo IS NULL OR ud.EffectiveTo > @AsOn)
GROUP BY ud.UserId, ud.DepartmentId
UNION ALL
SELECT u.UserId, u.DepartmentId, 1 AS IsHome
FROM dbo.Users u
WHERE u.DepartmentId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.User_Department x WHERE x.UserId = u.UserId);
GO

-------------------------------------------------------------------------------
-- The Managers of a department as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- fn_DepartmentManagers (step 53) over the history: the users whose role at the end of @AsOn is Manager, not the
-- protected system account, mapped to @DepartmentId on that day. For today it gives the rows of
-- fn_DepartmentManagers (Test 56 compares the two for every department).
CREATE OR ALTER FUNCTION [dbo].[fn_DepartmentManagersOn]
(
@DepartmentId INT,
@AsOn DATE
)
RETURNS TABLE
AS
RETURN
SELECT ro.UserId
FROM dbo.fn_UserRoleOn(@AsOn) ro
WHERE ro.RoleCode = 'manager'
  AND ro.IsSystem = 0
  AND EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentsOn(@AsOn) d WHERE d.UserId = ro.UserId AND d.DepartmentId = @DepartmentId);
GO

-------------------------------------------------------------------------------
-- The Reporting Person as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- Users.ManagerId with every change after @AsOn undone: the OldId of the first 'RP' row of the user dated after
-- @AsOn, else the value in Users. Complete only from LogFrom (fn_GovernanceHistoryStart): the callers do not use
-- it for an earlier day.
CREATE OR ALTER FUNCTION [dbo].[fn_ReportingPersonOn]
(
@AsOn DATE
)
RETURNS TABLE
AS
RETURN
SELECT u.UserId,
       CASE WHEN f.GovChangeId IS NULL THEN u.ManagerId ELSE f.OldId END AS ManagerId
FROM dbo.Users u
OUTER APPLY (SELECT TOP 1 g.GovChangeId, g.OldId
             FROM dbo.Governance_Change_Log g
             WHERE g.UserId = u.UserId AND g.ChangeType = 'RP' AND g.EffectiveOn > @AsOn
             ORDER BY g.ChangedOn, g.GovChangeId) f;
GO

-------------------------------------------------------------------------------
-- A setting as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- App_Setting.SettingValue with every change after @AsOn undone: the OldValue of the first 'ST' row of the setting
-- dated after @AsOn (back-filled from Audit_Trail_Master at the install), else the stored value. An empty or NULL
-- value: the setting was not stored then (the procedures use their default).
CREATE OR ALTER FUNCTION [dbo].[fn_SettingOn]
(
@SettingCode VARCHAR(50),
@AsOn DATE
)
RETURNS TABLE
AS
RETURN
SELECT CASE WHEN f.GovChangeId IS NULL THEN s.SettingValue ELSE CAST(f.OldValue AS VARCHAR(250)) END AS SettingValue
FROM (SELECT 1 AS One) d
LEFT JOIN dbo.App_Setting s ON s.SettingCode = @SettingCode
OUTER APPLY (SELECT TOP 1 g.GovChangeId, g.OldValue
             FROM dbo.Governance_Change_Log g
             WHERE g.ChangeType = 'ST' AND g.SettingCode = @SettingCode AND g.EffectiveOn > @AsOn
             ORDER BY g.ChangedOn, g.GovChangeId) f;
GO

-------------------------------------------------------------------------------
-- The departments' status as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- IsActive (1 / 0) of every department with every change after @AsOn undone: the OldId of the first 'KA' or 'KD'
-- row of the department dated after @AsOn, else Department.StatusId (1 active). Complete only from LogFrom.
CREATE OR ALTER FUNCTION [dbo].[fn_DepartmentActiveOn]
(
@AsOn DATE
)
RETURNS TABLE
AS
RETURN
SELECT d.DepartmentId,
       CAST(d.DepartmentName AS NVARCHAR(200)) AS DepartmentName,
       CAST(CASE WHEN f.GovChangeId IS NOT NULL THEN f.OldId
                 WHEN ISNULL(d.StatusId, 0) = 1 THEN 1 ELSE 0 END AS INT) AS IsActive
FROM dbo.Department d
OUTER APPLY (SELECT TOP 1 g.GovChangeId, g.OldId
             FROM dbo.Governance_Change_Log g
             WHERE g.DepartmentId = d.DepartmentId AND g.ChangeType IN ('KA', 'KD') AND g.EffectiveOn > @AsOn
             ORDER BY g.ChangedOn, g.GovChangeId) f;
GO

-------------------------------------------------------------------------------
-- People by role, live or dated (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- @Live 1: every active user with his role in Users (the role the page check of RA1d reads); @Live 0: the roles of
-- fn_UserRoleOn(@AsOn). IsSystem 1 for the protected system account (shown in the Admin rows only, marked).
CREATE OR ALTER FUNCTION [dbo].[fn_GovernanceRoleHolders]
(
@AsOn DATE,
@Live INT
)
RETURNS TABLE
AS
RETURN
SELECT u.UserId, r.RoleCode, CAST(u.IsSystem AS INT) AS IsSystem
FROM dbo.Users u
INNER JOIN dbo.Roles r ON r.RoleId = u.RoleId
WHERE @Live = 1 AND u.AccountStatus = 1
UNION ALL
SELECT ro.UserId, ro.RoleCode, ro.IsSystem
FROM dbo.fn_UserRoleOn(@AsOn) ro
WHERE @Live = 0;
GO

-------------------------------------------------------------------------------
-- The people of every rule of the matrix, live or dated (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- One row per transaction, department (0: all departments), column and user. @Live 1 reads the functions the
-- software uses; @Live 0 their dated versions on @AsOn. Test 56 proves that both give the same rows for today.
--   AGU  Agenda entry by a User:  E the active Users whose home department it is; A every active Manager of the
--        department (any one of them approves: fn_DepartmentManagers); C the active Controllers;
--        R the Users whose items go straight to the Controller (fn_AgendaRoute route C: the Reporting Person is an
--        active Controller); I the Users whose new items are refused (route I: the Reporting Person is inactive).
--        R and I need the Reporting Person: for a day before LogFrom the dated version gives none.
--   AGM  Agenda entry by a Manager: E the Managers of the department; C the Controllers.
--   APM  Manager approval or rejection at AC: A the Managers of the department (never the item's creator).
--   AGC  Agenda entry by the Controller, APC Controller approval or rejection: the Controllers (department 0).
--   AIR  Action item rows at Minutes Finalisation (department 0): fn_FunctionalUsers.
--   AIS  Who can open the department's action items on the Dashboard (fn_DashboardActionItemScope): Controller and
--        Management every item; a Manager or a User the items of his departments (fn_UserDepartmentScope) once the
--        minutes are finalised.
CREATE OR ALTER FUNCTION [dbo].[fn_GovernanceMatrixPeople]
(
@AsOn DATE,
@Live INT
)
RETURNS TABLE
AS
RETURN
-- Users of a department (AGU E)
SELECT CAST('AGU' AS VARCHAR(10)) AS TransactionCode, u.DepartmentId, CAST('E' AS CHAR(1)) AS Col, u.UserId
FROM dbo.Users u
INNER JOIN dbo.Roles r ON r.RoleId = u.RoleId
WHERE @Live = 1 AND r.RoleCode = 'user' AND u.AccountStatus = 1 AND u.IsSystem = 0 AND u.DepartmentId IS NOT NULL
UNION ALL
SELECT 'AGU', d.DepartmentId, 'E', ro.UserId
FROM dbo.fn_UserRoleOn(@AsOn) ro
INNER JOIN dbo.fn_UserDepartmentsOn(@AsOn) d ON d.UserId = ro.UserId AND d.IsHome = 1
WHERE @Live = 0 AND ro.RoleCode = 'user' AND ro.IsSystem = 0
UNION ALL
-- Managers of a department (AGU A, AGM E, APM A)
SELECT t.TransactionCode, dp.DepartmentId, t.Col, m.UserId
FROM dbo.Department dp
CROSS APPLY dbo.fn_DepartmentManagers(dp.DepartmentId) m
CROSS JOIN (SELECT CAST('AGU' AS VARCHAR(10)) AS TransactionCode, CAST('A' AS CHAR(1)) AS Col
            UNION ALL SELECT 'AGM', 'E' UNION ALL SELECT 'APM', 'A') t
WHERE @Live = 1
UNION ALL
SELECT t.TransactionCode, dp.DepartmentId, t.Col, m.UserId
FROM dbo.Department dp
CROSS APPLY dbo.fn_DepartmentManagersOn(dp.DepartmentId, @AsOn) m
CROSS JOIN (SELECT CAST('AGU' AS VARCHAR(10)) AS TransactionCode, CAST('A' AS CHAR(1)) AS Col
            UNION ALL SELECT 'AGM', 'E' UNION ALL SELECT 'APM', 'A') t
WHERE @Live = 0
UNION ALL
-- Controllers (AGU C and AGM C for every department; AGC E and APC C for all departments)
SELECT t.TransactionCode, dp.DepartmentId, t.Col, c.UserId
FROM dbo.fn_GovernanceRoleHolders(@AsOn, @Live) c
CROSS JOIN dbo.Department dp
CROSS JOIN (SELECT CAST('AGU' AS VARCHAR(10)) AS TransactionCode, CAST('C' AS CHAR(1)) AS Col
            UNION ALL SELECT 'AGM', 'C') t
WHERE c.RoleCode = 'controller' AND c.IsSystem = 0
UNION ALL
SELECT t.TransactionCode, 0, t.Col, c.UserId
FROM dbo.fn_GovernanceRoleHolders(@AsOn, @Live) c
CROSS JOIN (SELECT CAST('AGC' AS VARCHAR(10)) AS TransactionCode, CAST('E' AS CHAR(1)) AS Col
            UNION ALL SELECT 'APC', 'C') t
WHERE c.RoleCode = 'controller' AND c.IsSystem = 0
UNION ALL
-- Route C and route I of a User's new item (AGU R, AGU I): live from fn_AgendaRoute itself
SELECT 'AGU', u.DepartmentId, CASE WHEN rt.Route = 'I' THEN 'I' ELSE 'R' END, u.UserId
FROM dbo.Users u
INNER JOIN dbo.Roles r ON r.RoleId = u.RoleId
CROSS APPLY dbo.fn_AgendaRoute(u.UserId, u.DepartmentId) rt
WHERE @Live = 1 AND r.RoleCode = 'user' AND u.AccountStatus = 1 AND u.IsSystem = 0 AND u.DepartmentId IS NOT NULL
  AND (rt.Route = 'I' OR (rt.Route = 'C' AND rt.RouteNote IS NULL))
UNION ALL
SELECT 'AGU', d.DepartmentId, CASE WHEN rp.ManagerId IS NOT NULL AND mro.UserId IS NULL THEN 'I' ELSE 'R' END, ro.UserId
FROM dbo.fn_UserRoleOn(@AsOn) ro
INNER JOIN dbo.fn_UserDepartmentsOn(@AsOn) d ON d.UserId = ro.UserId AND d.IsHome = 1
INNER JOIN dbo.fn_ReportingPersonOn(@AsOn) rp ON rp.UserId = ro.UserId
LEFT JOIN dbo.fn_UserRoleOn(@AsOn) mro ON mro.UserId = rp.ManagerId
WHERE @Live = 0 AND ro.RoleCode = 'user' AND ro.IsSystem = 0 AND rp.ManagerId IS NOT NULL
  AND @AsOn >= ISNULL((SELECT h.LogFrom FROM dbo.fn_GovernanceHistoryStart() h), '99991231')
  AND (mro.UserId IS NULL OR (mro.RoleCode = 'controller' AND mro.IsSystem = 0))
UNION ALL
-- Action item rows at Minutes Finalisation (AIR E)
SELECT 'AIR', 0, 'E', fu.UserId
FROM dbo.fn_FunctionalUsers() fu
WHERE @Live = 1
UNION ALL
SELECT 'AIR', 0, 'E', ro.UserId
FROM dbo.fn_UserRoleOn(@AsOn) ro
WHERE @Live = 0 AND ro.IsSystem = 0 AND ro.RoleCode <> 'admin'
UNION ALL
-- Who can open the department's action items on the Dashboard (AIS E)
SELECT 'AIS', dp.DepartmentId, 'E', u.UserId
FROM dbo.Users u
INNER JOIN dbo.Roles r ON r.RoleId = u.RoleId
CROSS JOIN dbo.Department dp
WHERE @Live = 1 AND u.AccountStatus = 1
  AND (r.RoleCode IN ('controller', 'mgmt')
       OR (r.RoleCode IN ('manager', 'user')
           AND dp.DepartmentId IN (SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(u.UserId, @AsOn) s)))
UNION ALL
SELECT 'AIS', dp.DepartmentId, 'E', ro.UserId
FROM dbo.fn_UserRoleOn(@AsOn) ro
CROSS JOIN dbo.Department dp
WHERE @Live = 0
  AND (ro.RoleCode IN ('controller', 'mgmt')
       OR (ro.RoleCode IN ('manager', 'user')
           AND EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentsOn(@AsOn) d WHERE d.UserId = ro.UserId AND d.DepartmentId = dp.DepartmentId)));
GO

-------------------------------------------------------------------------------
-- Who may read the Governance Matrix, and the date rules (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- One row: Reason 8 the acting user is missing, 0 or inactive; 4 a role other than Admin and Controller; 33 @AsOn
-- is missing or after today (the database server's date); 32 @AsOn is before the history start (HistoryStart, as
-- yyyy-mm-dd, is given for the message); 0 allowed. IsLive 1 when @AsOn is today. The protected system account has
-- the Admin role and is allowed.
CREATE OR ALTER FUNCTION [dbo].[fn_GovernanceRefusal]
(
@ActingUserId INT,
@AsOn DATE
)
RETURNS TABLE
AS
RETURN
SELECT
CAST(CASE WHEN a.RoleCode IS NULL THEN 8
          WHEN a.RoleCode NOT IN ('admin', 'controller') THEN 4
          WHEN @AsOn IS NULL OR @AsOn > CAST(GETDATE() AS DATE) THEN 33
          WHEN h.HistoryStart IS NULL OR @AsOn < h.HistoryStart THEN 32
          ELSE 0 END AS INT) AS Reason,
CAST(ISNULL(CONVERT(VARCHAR(10), h.HistoryStart, 120), '') AS VARCHAR(10)) AS HistoryStart,
CAST(CASE WHEN @AsOn = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS INT) AS IsLive
FROM (SELECT 1 AS One) d
LEFT JOIN (SELECT r.RoleCode FROM dbo.Users u INNER JOIN dbo.Roles r ON r.RoleId = u.RoleId
           WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1) a ON 1 = 1
CROSS JOIN dbo.fn_GovernanceHistoryStart() h;
GO

-------------------------------------------------------------------------------
-- A user's departments as a list of ids (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- The open User_Department rows of an active user, ids in order, comma separated; for an inactive user or a user
-- without open rows the department in Users. NULL for a user that does not exist. The log compares the list before
-- and after a save.
CREATE OR ALTER FUNCTION [dbo].[fn_GovernanceDeptList]
(
@UserId INT
)
RETURNS VARCHAR(MAX)
AS
BEGIN
	DECLARE @List VARCHAR(MAX);

	SET @List = STUFF((SELECT ',' + CAST(ud.DepartmentId AS VARCHAR(12))
	                   FROM dbo.User_Department ud
	                   INNER JOIN dbo.Users u ON u.UserId = ud.UserId
	                   WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL AND u.AccountStatus = 1
	                   GROUP BY ud.DepartmentId
	                   ORDER BY ud.DepartmentId
	                   FOR XML PATH('')), 1, 1, '');

	IF (@List IS NULL)
		SET @List = (SELECT CAST(DepartmentId AS VARCHAR(12)) FROM dbo.Users WHERE UserId = @UserId);

	RETURN @List;
END
GO

-------------------------------------------------------------------------------
-- A user's role and departments as text (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- "Manager; HRD (home), Credit" (the role name, the home department marked, the other open departments of an active
-- user by name); "; inactive" added for an inactive user. NULL for a user that does not exist. Written to the log
-- for a new user, an Activate, a Deactivate and a delete (C3).
CREATE OR ALTER FUNCTION [dbo].[fn_GovernanceUserSummary]
(
@UserId INT
)
RETURNS NVARCHAR(1000)
AS
BEGIN
	DECLARE @Role NVARCHAR(100);
	DECLARE @Home INT;
	DECLARE @HomeName NVARCHAR(200);
	DECLARE @Active INT;
	DECLARE @Others NVARCHAR(800);

	IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
		RETURN NULL;

	SELECT @Role = CAST(r.RoleName AS NVARCHAR(100)), @Home = u.DepartmentId,
	       @HomeName = CAST(d.DepartmentName AS NVARCHAR(200)), @Active = ISNULL(u.AccountStatus, 0)
	FROM dbo.Users u
	LEFT JOIN dbo.Roles r ON r.RoleId = u.RoleId
	LEFT JOIN dbo.Department d ON d.DepartmentId = u.DepartmentId
	WHERE u.UserId = @UserId;

	IF (@Active = 1)
		SET @Others = STUFF((SELECT N', ' + CAST(d.DepartmentName AS NVARCHAR(200))
		                     FROM dbo.User_Department ud
		                     INNER JOIN dbo.Department d ON d.DepartmentId = ud.DepartmentId
		                     WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL AND ud.DepartmentId <> ISNULL(@Home, 0)
		                     GROUP BY d.DepartmentName
		                     ORDER BY d.DepartmentName
		                     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(800)'), 1, 2, N'');

	RETURN LEFT(ISNULL(@Role, N'(no role)') + N'; ' + ISNULL(@HomeName, N'(no department)') + N' (home)'
	            + ISNULL(N', ' + @Others, N'') + CASE WHEN @Active = 1 THEN N'' ELSE N'; inactive' END, 1000);
END
GO

-------------------------------------------------------------------------------
-- One row of the governance change log (GovernanceLog-Step56, step GM1a); internal
-------------------------------------------------------------------------------
-- Called only by the procedures that change a user, a department or a setting, inside their transaction. A call at
-- nesting level 1 (a direct call) is refused and writes nothing; EXECUTE is denied to public (the application's
-- database users), so the application cannot call it directly either. The user's login and name are read from Users
-- when they are not passed; the department's name from Department. ChangedOn is the time of the call.
CREATE OR ALTER PROCEDURE [dbo].[spr_WriteGovernanceChange]
@ActingUserId INT,
@Source VARCHAR(64),
@ChangeType CHAR(2),
@UserId INT = NULL,
@UserLogin NVARCHAR(50) = NULL,
@UserName NVARCHAR(200) = NULL,
@DepartmentId INT = NULL,
@SettingCode VARCHAR(50) = NULL,
@OldId INT = NULL,
@NewId INT = NULL,
@OldValue NVARCHAR(1000) = NULL,
@NewValue NVARCHAR(1000) = NULL
AS
DECLARE @Now DATETIME;
BEGIN
	SET NOCOUNT ON;

	IF (@@NESTLEVEL < 2)
	BEGIN
		RAISERROR('spr_WriteGovernanceChange is internal: only the procedures that change users, departments and settings call it. Nothing was written.', 16, 1);
		RETURN;
	END

	IF (@UserId IS NOT NULL AND @UserLogin IS NULL AND @UserName IS NULL)
		SELECT @UserLogin = CAST(LoginName AS NVARCHAR(50)), @UserName = CAST(UserName AS NVARCHAR(200))
		FROM dbo.Users WHERE UserId = @UserId;

	SET @Now = GETDATE();

	INSERT INTO dbo.Governance_Change_Log
	(ChangedOn, EffectiveOn, ChangedBy, ChangeType, UserId, UserLogin, UserName, DepartmentId, DepartmentName,
	 SettingCode, OldId, NewId, OldValue, NewValue, Source)
	SELECT @Now, CAST(@Now AS DATE), (SELECT a.UserId FROM dbo.Users a WHERE a.UserId = @ActingUserId), @ChangeType,
	       @UserId, @UserLogin, @UserName, @DepartmentId,
	       (SELECT CAST(d.DepartmentName AS NVARCHAR(200)) FROM dbo.Department d WHERE d.DepartmentId = @DepartmentId),
	       @SettingCode, @OldId, @NewId, @OldValue, @NewValue, @Source;
END
GO

-------------------------------------------------------------------------------
-- What a save changed in a user, to the governance change log (GovernanceLog-Step56, step GM1a); internal
-------------------------------------------------------------------------------
-- Compares the user before the save (the parameters, read by the caller under its lock) with the user now, and
-- writes one row per change: UA a new user (@Existed 0; NewValue the role and departments, and the Reporting
-- Person); UX the user is gone (OldValue the role, the home department and the Manager's departments held at the
-- delete); UV / UD the status changed (then nothing else is compared: Activate and Deactivate change nothing else);
-- otherwise RC the role, HC the home department, DA / DR a department added to or removed from the user's
-- departments (not the home department, which HC covers), and RP the Reporting Person. Nothing when nothing changed.
-- Internal as spr_WriteGovernanceChange (nesting level, EXECUTE denied to public).
CREATE OR ALTER PROCEDURE [dbo].[spr_WriteGovernanceUserChanges]
@ActingUserId INT,
@Source VARCHAR(64),
@UserId INT,
@Existed INT,
@OldActive INT = NULL,
@OldRoleId INT = NULL,
@OldHome INT = NULL,
@OldManagerId INT = NULL,
@OldDepts VARCHAR(MAX) = NULL,
@OldSummary NVARCHAR(1000) = NULL,
@OldLogin NVARCHAR(50) = NULL,
@OldName NVARCHAR(200) = NULL
AS
DECLARE @NewExists INT;
DECLARE @NewActive INT;
DECLARE @NewRoleId INT;
DECLARE @NewHome INT;
DECLARE @NewManagerId INT;
DECLARE @NewSummary NVARCHAR(1000);
DECLARE @Text NVARCHAR(1000);
DECLARE @OldText NVARCHAR(1000);
DECLARE @Rest VARCHAR(MAX);
DECLARE @Pos INT;
DECLARE @Token VARCHAR(20);
DECLARE @DeptId INT;
DECLARE @ZeroId INT;
DECLARE @OneId INT;
DECLARE @O TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @N TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
BEGIN
	SET NOCOUNT ON;

	IF (@@NESTLEVEL < 2)
	BEGIN
		RAISERROR('spr_WriteGovernanceUserChanges is internal: only the procedures that change users call it. Nothing was written.', 16, 1);
		RETURN;
	END

	SET @ZeroId = 0;
	SET @OneId = 1;
	SET @NewExists = 0;
	SELECT @NewExists = 1, @NewActive = ISNULL(AccountStatus, 0), @NewRoleId = RoleId, @NewHome = DepartmentId,
	       @NewManagerId = ManagerId
	FROM dbo.Users WHERE UserId = @UserId;

	IF (@NewExists = 1)
		SET @NewSummary = dbo.fn_GovernanceUserSummary(@UserId);

	-- A new user
	IF (ISNULL(@Existed, 0) = 0)
	BEGIN
		IF (@NewExists = 1)
		BEGIN
			SET @Text = LEFT(@NewSummary
			                 + ISNULL(N'; Reporting Person: '
			                          + (SELECT CAST(m.UserName AS NVARCHAR(200)) + N' (' + CAST(m.LoginName AS NVARCHAR(50)) + N')'
			                             FROM dbo.Users m WHERE m.UserId = @NewManagerId), N''), 1000);
			EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'UA',
			     @UserId = @UserId, @DepartmentId = @NewHome, @NewId = @NewRoleId, @NewValue = @Text;
		END
		RETURN;
	END

	-- The user is gone (C3: OldValue the role and the departments held at the delete)
	IF (@NewExists = 0)
	BEGIN
		SET @Text = N'Deleted';
		EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'UX',
		     @UserId = @UserId, @UserLogin = @OldLogin, @UserName = @OldName, @DepartmentId = @OldHome,
		     @OldId = @OldRoleId, @OldValue = @OldSummary, @NewValue = @Text;
		RETURN;
	END

	-- Activate or Deactivate
	IF (ISNULL(@OldActive, 0) <> @NewActive)
	BEGIN
		IF (@NewActive = 1)
		BEGIN
			SET @Text = N'Inactive';
			EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'UV',
			     @UserId = @UserId, @DepartmentId = @NewHome, @OldId = @ZeroId, @NewId = @OneId,
			     @OldValue = @Text, @NewValue = @NewSummary;
		END
		ELSE
		BEGIN
			SET @Text = N'Inactive';
			EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'UD',
			     @UserId = @UserId, @DepartmentId = @OldHome, @OldId = @OneId, @NewId = @ZeroId,
			     @OldValue = @OldSummary, @NewValue = @Text;
		END
	END
	ELSE
	BEGIN
		-- The role
		IF (ISNULL(@OldRoleId, -1) <> ISNULL(@NewRoleId, -1))
		BEGIN
			SET @OldText = (SELECT CAST(RoleName AS NVARCHAR(1000)) FROM dbo.Roles WHERE RoleId = @OldRoleId);
			SET @Text = (SELECT CAST(RoleName AS NVARCHAR(1000)) FROM dbo.Roles WHERE RoleId = @NewRoleId);
			EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'RC',
			     @UserId = @UserId, @DepartmentId = @NewHome, @OldId = @OldRoleId, @NewId = @NewRoleId,
			     @OldValue = @OldText, @NewValue = @Text;
		END

		-- The home department
		IF (ISNULL(@OldHome, -1) <> ISNULL(@NewHome, -1))
		BEGIN
			SET @OldText = (SELECT CAST(DepartmentName AS NVARCHAR(1000)) FROM dbo.Department WHERE DepartmentId = @OldHome);
			SET @Text = (SELECT CAST(DepartmentName AS NVARCHAR(1000)) FROM dbo.Department WHERE DepartmentId = @NewHome);
			EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'HC',
			     @UserId = @UserId, @DepartmentId = @NewHome, @OldId = @OldHome, @NewId = @NewHome,
			     @OldValue = @OldText, @NewValue = @Text;
		END

		-- The departments before (the list the caller read) and now
		SET @Rest = ISNULL(@OldDepts, '');
		IF (@Rest LIKE '%[^0-9,]%')
			SET @Rest = '';
		SET @Rest = @Rest + ',';
		WHILE (LEN(@Rest) > 0)
		BEGIN
			SET @Pos = CHARINDEX(',', @Rest);
			SET @Token = LEFT(@Rest, @Pos - 1);
			SET @Rest = SUBSTRING(@Rest, @Pos + 1, LEN(@Rest));
			IF (LEN(@Token) BETWEEN 1 AND 9 AND NOT EXISTS (SELECT 1 FROM @O WHERE DepartmentId = CAST(@Token AS INT)))
				INSERT INTO @O (DepartmentId) VALUES (CAST(@Token AS INT));
		END

		SET @Rest = ISNULL(dbo.fn_GovernanceDeptList(@UserId), '') + ',';
		WHILE (LEN(@Rest) > 0)
		BEGIN
			SET @Pos = CHARINDEX(',', @Rest);
			SET @Token = LEFT(@Rest, @Pos - 1);
			SET @Rest = SUBSTRING(@Rest, @Pos + 1, LEN(@Rest));
			IF (LEN(@Token) BETWEEN 1 AND 9 AND NOT EXISTS (SELECT 1 FROM @N WHERE DepartmentId = CAST(@Token AS INT)))
				INSERT INTO @N (DepartmentId) VALUES (CAST(@Token AS INT));
		END

		-- Added (not the new home department)
		SET @DeptId = (SELECT MIN(n.DepartmentId) FROM @N n
		               WHERE n.DepartmentId <> ISNULL(@NewHome, 0) AND NOT EXISTS (SELECT 1 FROM @O o WHERE o.DepartmentId = n.DepartmentId));
		WHILE (@DeptId IS NOT NULL)
		BEGIN
			SET @Text = (SELECT CAST(DepartmentName AS NVARCHAR(1000)) FROM dbo.Department WHERE DepartmentId = @DeptId);
			EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'DA',
			     @UserId = @UserId, @DepartmentId = @DeptId, @NewId = @DeptId, @NewValue = @Text;
			SET @DeptId = (SELECT MIN(n.DepartmentId) FROM @N n
			               WHERE n.DepartmentId > @DeptId AND n.DepartmentId <> ISNULL(@NewHome, 0)
			                 AND NOT EXISTS (SELECT 1 FROM @O o WHERE o.DepartmentId = n.DepartmentId));
		END

		-- Removed (not the old home department)
		SET @DeptId = (SELECT MIN(o.DepartmentId) FROM @O o
		               WHERE o.DepartmentId <> ISNULL(@OldHome, 0) AND NOT EXISTS (SELECT 1 FROM @N n WHERE n.DepartmentId = o.DepartmentId));
		WHILE (@DeptId IS NOT NULL)
		BEGIN
			SET @OldText = (SELECT CAST(DepartmentName AS NVARCHAR(1000)) FROM dbo.Department WHERE DepartmentId = @DeptId);
			EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'DR',
			     @UserId = @UserId, @DepartmentId = @DeptId, @OldId = @DeptId, @OldValue = @OldText;
			SET @DeptId = (SELECT MIN(o.DepartmentId) FROM @O o
			               WHERE o.DepartmentId > @DeptId AND o.DepartmentId <> ISNULL(@OldHome, 0)
			                 AND NOT EXISTS (SELECT 1 FROM @N n WHERE n.DepartmentId = o.DepartmentId));
		END
	END

	-- The Reporting Person
	IF (ISNULL(@OldManagerId, 0) <> ISNULL(@NewManagerId, 0))
	BEGIN
		SET @OldText = ISNULL((SELECT CAST(m.UserName AS NVARCHAR(200)) + N' (' + CAST(m.LoginName AS NVARCHAR(50)) + N')'
		                       FROM dbo.Users m WHERE m.UserId = @OldManagerId), N'(none)');
		SET @Text = ISNULL((SELECT CAST(m.UserName AS NVARCHAR(200)) + N' (' + CAST(m.LoginName AS NVARCHAR(50)) + N')'
		                    FROM dbo.Users m WHERE m.UserId = @NewManagerId), N'(none)');
		EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = @Source, @ChangeType = 'RP',
		     @UserId = @UserId, @DepartmentId = @NewHome, @OldId = @OldManagerId, @NewId = @NewManagerId,
		     @OldValue = @OldText, @NewValue = @Text;
	END
END
GO

-------------------------------------------------------------------------------
-- Governance Matrix: the people of every rule as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- Reads only. @Result 1 and the rows when fn_GovernanceRefusal allows (Admin or Controller; @AsOn from the history
-- start up to today); otherwise @Result 0, @Reason 8, 4, 32 or 33 (@Detail the history start for 32) and no rows.
-- Today reads the live functions, an earlier day their dated versions (fn_GovernanceMatrixPeople). Rows: Kind 'P'
-- the people of a rule (TransactionCode, DepartmentId 0 = all departments, Col E enters, A approves, C Controller,
-- R route to the Controller, I refused), Kind 'H' the people of every role (RoleCode; the page uses them for the
-- transactions whose rule is a page rule of PageAccess.xml and for the Read-only access block). ActiveNow: the
-- account is active today (a past day may show a person who is inactive now).
CREATE OR ALTER PROCEDURE [dbo].[spr_GetGovernanceMatrix]
@ActingUserId INT = NULL,
@AsOn DATE = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@Detail VARCHAR(10) = NULL OUTPUT
AS
DECLARE @Live INT;
BEGIN
	SET NOCOUNT ON;

	SELECT @Reason = Reason, @Detail = HistoryStart, @Live = IsLive FROM dbo.fn_GovernanceRefusal(@ActingUserId, @AsOn);
	SET @Result = CASE WHEN @Reason = 0 THEN 1 ELSE 0 END;

	SELECT CAST('P' AS CHAR(1)) AS Kind, p.TransactionCode, p.DepartmentId, CAST(p.Col AS CHAR(1)) AS Col,
	       CAST(NULL AS VARCHAR(50)) AS RoleCode, p.UserId, u.UserName, u.LoginName,
	       CAST(CASE WHEN u.AccountStatus = 1 THEN 1 ELSE 0 END AS INT) AS ActiveNow, CAST(u.IsSystem AS INT) AS IsSystem
	FROM dbo.fn_GovernanceMatrixPeople(@AsOn, @Live) p
	INNER JOIN dbo.Users u ON u.UserId = p.UserId
	WHERE @Result = 1
	UNION ALL
	SELECT 'H', NULL, 0, NULL, CAST(h.RoleCode AS VARCHAR(50)), h.UserId, u.UserName, u.LoginName,
	       CAST(CASE WHEN u.AccountStatus = 1 THEN 1 ELSE 0 END AS INT), h.IsSystem
	FROM dbo.fn_GovernanceRoleHolders(@AsOn, @Live) h
	INNER JOIN dbo.Users u ON u.UserId = h.UserId
	WHERE @Result = 1
	ORDER BY 1, 2, 3, 4, 8, 7;
END
GO

-------------------------------------------------------------------------------
-- Governance Matrix: the dates and the settings as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- One row when allowed (the same refusals as spr_GetGovernanceMatrix): Today, HistoryStart, LogFrom, IsLive, and the
-- settings DeptNoManagerAction and AgendaControllerBypass as on @AsOn (today: App_Setting; earlier: fn_SettingOn).
CREATE OR ALTER PROCEDURE [dbo].[spr_GetGovernanceSettings]
@ActingUserId INT = NULL,
@AsOn DATE = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@Detail VARCHAR(10) = NULL OUTPUT
AS
DECLARE @Live INT;
BEGIN
	SET NOCOUNT ON;

	SELECT @Reason = Reason, @Detail = HistoryStart, @Live = IsLive FROM dbo.fn_GovernanceRefusal(@ActingUserId, @AsOn);
	SET @Result = CASE WHEN @Reason = 0 THEN 1 ELSE 0 END;

	SELECT CAST(GETDATE() AS DATE) AS Today, h.HistoryStart, h.LogFrom, @Live AS IsLive,
	       CASE WHEN @Live = 1 THEN (SELECT SettingValue FROM dbo.App_Setting WHERE SettingCode = 'DeptNoManagerAction')
	            ELSE (SELECT s.SettingValue FROM dbo.fn_SettingOn('DeptNoManagerAction', @AsOn) s) END AS DeptNoManagerAction,
	       CASE WHEN @Live = 1 THEN (SELECT SettingValue FROM dbo.App_Setting WHERE SettingCode = 'AgendaControllerBypass')
	            ELSE (SELECT s.SettingValue FROM dbo.fn_SettingOn('AgendaControllerBypass', @AsOn) s) END AS AgendaControllerBypass
	FROM dbo.fn_GovernanceHistoryStart() h
	WHERE @Result = 1;
END
GO

-------------------------------------------------------------------------------
-- Governance Matrix: the departments as on a day (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- One row per department when allowed (the same refusals): DepartmentId, DepartmentName, IsActive (today:
-- Department.StatusId; earlier: fn_DepartmentActiveOn), OrderNo, ordered as the Department Master lists them.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetGovernanceDepartments]
@ActingUserId INT = NULL,
@AsOn DATE = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@Detail VARCHAR(10) = NULL OUTPUT
AS
DECLARE @Live INT;
BEGIN
	SET NOCOUNT ON;

	SELECT @Reason = Reason, @Detail = HistoryStart, @Live = IsLive FROM dbo.fn_GovernanceRefusal(@ActingUserId, @AsOn);
	SET @Result = CASE WHEN @Reason = 0 THEN 1 ELSE 0 END;

	SELECT d.DepartmentId, CAST(d.DepartmentName AS NVARCHAR(200)) AS DepartmentName,
	       CAST(CASE WHEN @Live = 1 THEN CASE WHEN ISNULL(d.StatusId, 0) = 1 THEN 1 ELSE 0 END ELSE a.IsActive END AS INT) AS IsActive,
	       d.OrderNo
	FROM dbo.Department d
	INNER JOIN dbo.fn_DepartmentActiveOn(@AsOn) a ON a.DepartmentId = d.DepartmentId
	WHERE @Result = 1
	ORDER BY d.OrderNo, d.DepartmentName, d.DepartmentId;
END
GO

-------------------------------------------------------------------------------
-- Governance Matrix: the change log (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- Reads only. Admin and Controller (Reason 8, 4 as above); Reason 34 when @From or @To is missing, @From is after
-- @To or @To is after today; then no rows. The rows of the days @From to @To (EffectiveOn), newest first, filtered by
-- the user changed (@UserId), the department (@DepartmentId) and the change type (@ChangeType); NULL or 0 = all.
-- ChangedBy as name and login (empty when the person no longer exists); the user as recorded in the row.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetGovernanceChangeLog]
@ActingUserId INT = NULL,
@From DATE = NULL,
@To DATE = NULL,
@UserId INT = NULL,
@DepartmentId INT = NULL,
@ChangeType CHAR(2) = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT @Reason = Reason FROM dbo.fn_GovernanceRefusal(@ActingUserId, CAST(GETDATE() AS DATE));

	IF (@Reason = 0 AND (@From IS NULL OR @To IS NULL OR @From > @To OR @To > CAST(GETDATE() AS DATE)))
		SET @Reason = 34;

	SET @Result = CASE WHEN @Reason = 0 THEN 1 ELSE 0 END;

	SELECT g.GovChangeId, g.ChangedOn, g.EffectiveOn, g.ChangeType, g.ChangedBy,
	       cb.UserName AS ChangedByName, cb.LoginName AS ChangedByLogin,
	       CAST(CASE WHEN cb.AccountStatus = 1 THEN 1 ELSE 0 END AS INT) AS ChangedByActive,
	       g.UserId, g.UserName, g.UserLogin, g.DepartmentId, g.DepartmentName, g.SettingCode,
	       g.OldValue, g.NewValue, g.Source
	FROM dbo.Governance_Change_Log g
	LEFT JOIN dbo.Users cb ON cb.UserId = g.ChangedBy
	WHERE @Result = 1
	  AND g.EffectiveOn >= @From AND g.EffectiveOn <= @To
	  AND (ISNULL(@UserId, 0) = 0 OR g.UserId = @UserId)
	  AND (ISNULL(@DepartmentId, 0) = 0 OR g.DepartmentId = @DepartmentId)
	  AND (ISNULL(@ChangeType, '') = '' OR g.ChangeType = @ChangeType)
	ORDER BY g.ChangedOn DESC, g.GovChangeId DESC;
END
GO

-------------------------------------------------------------------------------
-- Governance Matrix: the users of the change log filter (GovernanceLog-Step56, step GM1a)
-------------------------------------------------------------------------------
-- Every user in Users and every user named in the log who no longer exists (by the latest name in the log), with
-- IsActive (0 for a deleted user) and Deleted. Admin and Controller only (Reason 8, 4); then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetGovernanceLogUsers]
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT @Reason = Reason FROM dbo.fn_GovernanceRefusal(@ActingUserId, CAST(GETDATE() AS DATE));
	SET @Result = CASE WHEN @Reason = 0 THEN 1 ELSE 0 END;

	SELECT u.UserId, CAST(u.UserName AS NVARCHAR(200)) AS UserName, CAST(u.LoginName AS NVARCHAR(50)) AS LoginName,
	       CAST(CASE WHEN u.AccountStatus = 1 THEN 1 ELSE 0 END AS INT) AS IsActive, CAST(0 AS INT) AS Deleted
	FROM dbo.Users u
	WHERE @Result = 1
	UNION ALL
	SELECT g.UserId, g.UserName, g.UserLogin, 0, 1
	FROM dbo.Governance_Change_Log g
	WHERE @Result = 1 AND g.UserId IS NOT NULL
	  AND NOT EXISTS (SELECT 1 FROM dbo.Users x WHERE x.UserId = g.UserId)
	  AND g.GovChangeId = (SELECT MAX(g2.GovChangeId) FROM dbo.Governance_Change_Log g2 WHERE g2.UserId = g.UserId)
	ORDER BY 2, 3, 1;
END
GO

DENY EXECUTE ON dbo.spr_WriteGovernanceChange TO public;
DENY EXECUTE ON dbo.spr_WriteGovernanceUserChanges TO public;
GO

-------------------------------------------------------------------------------
-- spr_AddEditUser (replaced; the step 54 text with the governance change log)
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Users - add / edit (UserProtection-Stage1; UserHistory-Step39)
-------------------------------------------------------------------------------
-- Save checks Create (acting user = @CreatedBy); Update checks Edit and, when the role really
-- changes, RoleChange (acting user = @UpdatedBy) (UserProtection-Stage1).
-- UserHistory-Step39: @DepartmentIds (optional, last) is the comma list of the user's departments:
-- digits and commas only, at most 2000 characters, each id at most 9 digits and a department that
-- exists; a department added by the list must be active. Only a Manager may have several; the home
-- department (@DepartmentId) must be in the list (Reason 23). NULL = not passed: a new user gets the
-- home department; an edit keeps the Manager's mappings and adds the home department. Every change is
-- written to User_Role / User_Department in the same transaction (rows dated today, by the acting
-- user). An inactive user's rows are left closed: only Users changes, Activate opens the rows.
-- A role change away from Manager closes his other departments (R) and is refused (Reason 24) when he
-- is the last active Manager of one of his departments with items waiting for a Manager, or when items
-- waiting at AC are routed to him; an edit that removes a department of a Manager checks that
-- department only. On success ReasonDetail is 'MappingsClosed:<names>' when departments were closed
-- by a role change away from Manager, otherwise ''.
-- ManagerRelease-Step52 (step MR1): the items routed to him are those fn_AgendaWaitingFor lets him approve, counted
-- apart by the meeting date (fn_ManagerReleaseRefusal Kinds 'P' and 'Q'). The Reason 24 ReasonDetail is
-- 'open:<n>|past:<n>|<department part>', the department part as before ('last active Manager of ...' or nothing).
-- DepartmentApprovers-Step53 (step UD1b): rule 12 refuses only for the items no other Manager of the department could
-- decide (fn_ManagerReleaseRefusal). When the change is allowed, his rows on the alerts of items at AC of the
-- departments he leaves are marked 'N' (no longer Manager of the department) in the same transaction, and the
-- successful ReasonDetail ends with '|Released:<n>:<department names>'. A Manager after the save (a new user, a role
-- changed to Manager, a department added) gets a row on the alert of every item waiting at AC in his departments
-- (spr_SetManagerAlertRows; his own 'N' row is opened again).
-- ManagerScope-Step54 (step UD1c): the Reporting Person (@ManagerId) must be one of fn_ReportingPersonAllowed for the
-- user's (home) department @DepartmentId: an active Controller or an active Manager of that department, never the
-- user himself; none (NULL or 0, "- Select -") stays allowed. Otherwise Reason 31 and nothing is saved, on Create
-- and on every Update (also when the Reporting Person is not changed).
-- GovernanceLog-Step56 (step GM1a): a new user and every change of the role, the home department, a Manager's
-- departments and the Reporting Person are written to Governance_Change_Log in the same transaction
-- (spr_WriteGovernanceUserChanges compares the user before and after the save); a save that changes none of them
-- writes nothing.
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditUser]
@Code VARCHAR(50),
@UserId INT,
@UserName VARCHAR(50),
@DepartmentId INT,
@DesignationId INT,
@ManagerId INT,
@RoleId INT,
@EmailId VARCHAR(50),
@LoginName VARCHAR(50),
@Password VARCHAR(MAX),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT,
@DepartmentIds VARCHAR(MAX) = NULL
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @ActingUserId INT;
DECLARE @OldRoleId INT;
DECLARE @OldActive INT;
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @NewUserId INT;
DECLARE @IsManager INT;
DECLARE @WasManager INT;
DECLARE @Today DATE;
DECLARE @Now DATETIME;
DECLARE @Rest VARCHAR(MAX);
DECLARE @Pos INT;
DECLARE @Token VARCHAR(20);
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @Posted TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @Wanted TABLE (DepartmentId INT NOT NULL PRIMARY KEY, IsHome BIT NOT NULL);
DECLARE @OpenNow TABLE (DepartmentId INT NOT NULL PRIMARY KEY, IsHome BIT NOT NULL, IsVirtual BIT NOT NULL);
DECLARE @OldDepartmentId INT;
DECLARE @Lost TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @Refusal TABLE (Kind CHAR(1), DepartmentId INT NULL, DepartmentName NVARCHAR(200), Items INT);
DECLARE @Rel TABLE (DepartmentId INT NOT NULL PRIMARY KEY);   -- DepartmentApprovers-Step53
DECLARE @RelDept INT;
DECLARE @RelCount INT;
DECLARE @RelTotal INT;
DECLARE @GovOldManagerId INT;   -- GovernanceLog-Step56: the user before the save
DECLARE @GovOldDepts VARCHAR(MAX);
DECLARE @GovOldSummary NVARCHAR(1000);
DECLARE @GovOldLogin NVARCHAR(50);
DECLARE @GovOldName NVARCHAR(200);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
	SET @RelTotal = 0;
	SET @ActingUserId = CASE WHEN @Code = 'Save' THEN @CreatedBy ELSE @UpdatedBy END;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @Now = GETDATE();
	SET @IsManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleId AND RoleCode = 'manager') THEN 1 ELSE 0 END;

	-- The posted list, read as numbers only (UserHistory-Step39)
	IF (@DepartmentIds IS NOT NULL)
	BEGIN
		IF (LEN(@DepartmentIds) = 0 OR LEN(@DepartmentIds) > 2000 OR @DepartmentIds LIKE '%[^0-9,]%')
			SET @Detail = N'ListNotValid';
		ELSE
		BEGIN
			SET @Rest = @DepartmentIds + ',';
			WHILE (LEN(@Rest) > 0 AND @Detail = N'')
			BEGIN
				SET @Pos = CHARINDEX(',', @Rest);
				IF (@Pos <= 1 OR @Pos > 10)
					SET @Detail = N'ListNotValid';
				ELSE
				BEGIN
					SET @Token = LEFT(@Rest, @Pos - 1);
					SET @Rest = SUBSTRING(@Rest, @Pos + 1, LEN(@Rest));
					IF NOT EXISTS (SELECT 1 FROM @Posted WHERE DepartmentId = CAST(@Token AS INT))
						INSERT INTO @Posted (DepartmentId) VALUES (CAST(@Token AS INT));
				END
			END
		END

		IF (@Detail = N'' AND EXISTS (SELECT 1 FROM @Posted p WHERE NOT EXISTS (SELECT 1 FROM Department d WHERE d.DepartmentId = p.DepartmentId)))
			SET @Detail = N'DepartmentNotFound';
		ELSE IF (@Detail = N'' AND @IsManager = 0 AND (SELECT COUNT(*) FROM @Posted) > 1)
			SET @Detail = N'OneDepartmentOnly';
		ELSE IF (@Detail = N'' AND NOT EXISTS (SELECT 1 FROM @Posted WHERE DepartmentId = @DepartmentId))
			SET @Detail = N'HomeNotTicked';
	END

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
		SET @Detail = N'';
	END
	ELSE IF (@Code = 'Save')
	BEGIN
		SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, NULL, 'Create', @RoleId);

		IF (@Reason <> 0)
			SET @Detail = N'';
		ELSE IF (@Detail <> N'')
			SET @Reason = 23;
		ELSE IF (EXISTS (SELECT 1 FROM @Posted p JOIN Department d ON d.DepartmentId = p.DepartmentId WHERE ISNULL(d.StatusId, 0) <> 1))
		BEGIN
			SET @Reason = 23;
			SET @Detail = N'DepartmentInactive';
		END
		-- ManagerScope-Step54: the Reporting Person (Reason 31)
		ELSE IF (ISNULL(@ManagerId, 0) > 0
		         AND NOT EXISTS (SELECT 1 FROM dbo.fn_ReportingPersonAllowed(@DepartmentId, NULL) rp WHERE rp.UserId = @ManagerId))
		BEGIN
			SET @Reason = 31;
			SET @Detail = N'';
		END

		IF (@Reason = 0)
		BEGIN
			IF (@@TRANCOUNT = 0)
				SET @OwnTransaction = 1;
			ELSE
				SET @OwnTransaction = 0;

			BEGIN TRY
				IF (@OwnTransaction = 1)
					BEGIN TRANSACTION;
				ELSE
					SAVE TRANSACTION AddUser;

				INSERT INTO Users
				(UserName, DepartmentId, DesignationId, ManagerId,
					RoleId, EmailId, LoginName, Password, AccountStatus, CreatedOn, CreatedBy)
				VALUES
				(@UserName, @DepartmentId, @DesignationId, @ManagerId,
					@RoleId, @EmailId, @LoginName, @Password, 1, @CreatedOn, @CreatedBy);

				SET @NewUserId = SCOPE_IDENTITY();

				INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
				VALUES (@NewUserId, @RoleId, @Today, @Now, @ActingUserId);

				INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
				VALUES (@NewUserId, @DepartmentId, 1, @Today, @Now, @ActingUserId);

				INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
				SELECT @NewUserId, p.DepartmentId, 0, @Today, @Now, @ActingUserId
				FROM @Posted p
				WHERE p.DepartmentId <> @DepartmentId;

				-- DepartmentApprovers-Step53: a new Manager gets his rows of the items waiting at AC in his departments
				IF (@IsManager = 1)
					EXEC dbo.spr_SetManagerAlertRows @UserId = @NewUserId, @ActingUserId = @ActingUserId;

				-- GovernanceLog-Step56: the new user in the governance change log
				EXEC dbo.spr_WriteGovernanceUserChanges @ActingUserId = @ActingUserId, @Source = 'spr_AddEditUser',
				     @UserId = @NewUserId, @Existed = 0;

				SET @Result = 1;

				IF (@OwnTransaction = 1)
					COMMIT TRANSACTION;
			END TRY
			BEGIN CATCH
				SET @ErrMsg = ERROR_MESSAGE();

				IF (@OwnTransaction = 1)
				BEGIN
					IF (@@TRANCOUNT > 0)
						ROLLBACK TRANSACTION;
				END
				ELSE IF (XACT_STATE() = 1)
					ROLLBACK TRANSACTION AddUser;

				RAISERROR('%s', 16, 1, @ErrMsg);
				RETURN;
			END CATCH
		END
	END
	ELSE IF (@Code = 'Update')
	BEGIN
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION EditUser;

			SELECT @OldRoleId = RoleId, @OldDepartmentId = DepartmentId, @OldActive = ISNULL(AccountStatus, 0)
			FROM Users WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId;

			-- GovernanceLog-Step56: the user before the save, for the governance change log
			SELECT @GovOldManagerId = ManagerId, @GovOldLogin = LoginName, @GovOldName = UserName FROM Users WHERE UserId = @UserId;
			SET @GovOldDepts = dbo.fn_GovernanceDeptList(@UserId);
			SET @GovOldSummary = dbo.fn_GovernanceUserSummary(@UserId);

			SET @WasManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @OldRoleId AND RoleCode = 'manager') THEN 1 ELSE 0 END;

			-- Rule 2 under concurrency (only a role change can break it here)
			IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
				WHERE AccountStatus = 1
				AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'Edit', NULL);

			IF (@Reason = 0 AND ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'RoleChange', @RoleId);

			IF (@Reason <> 0)
				SET @Detail = N'';
			ELSE IF (@Detail <> N'' AND @OldActive = 1)
				SET @Reason = 23;
			ELSE IF (@OldActive <> 1)
				-- An inactive user keeps closed rows: the list is not used (Activate opens the rows)
				SET @Detail = N'';

			IF (@Reason = 0 AND @OldActive = 1)
			BEGIN
				-- The open rows today, and the rows wanted after the save
				INSERT INTO @OpenNow (DepartmentId, IsHome, IsVirtual)
				SELECT DepartmentId, MAX(CAST(IsHome AS INT)), 0 FROM User_Department WITH (UPDLOCK, HOLDLOCK)
				WHERE UserId = @UserId AND EffectiveTo IS NULL
				GROUP BY DepartmentId;

				-- A user without an open department row (inserted directly, as the older test scripts do) counts
				-- as mapped to the department in Users: a row is written only when it changes
				IF NOT EXISTS (SELECT 1 FROM @OpenNow) AND @OldDepartmentId IS NOT NULL
					INSERT INTO @OpenNow (DepartmentId, IsHome, IsVirtual) VALUES (@OldDepartmentId, 1, 1);

				IF (@DepartmentIds IS NOT NULL)
					INSERT INTO @Wanted (DepartmentId, IsHome)
					SELECT DepartmentId, CASE WHEN DepartmentId = @DepartmentId THEN 1 ELSE 0 END FROM @Posted;
				ELSE IF (@IsManager = 1)
					INSERT INTO @Wanted (DepartmentId, IsHome)
					SELECT DepartmentId, CASE WHEN DepartmentId = @DepartmentId THEN 1 ELSE 0 END FROM @OpenNow
					UNION
					SELECT @DepartmentId, 1 WHERE NOT EXISTS (SELECT 1 FROM @OpenNow WHERE DepartmentId = @DepartmentId);
				ELSE
					INSERT INTO @Wanted (DepartmentId, IsHome) VALUES (@DepartmentId, 1);

				-- A department added by the list must be active
				IF EXISTS (SELECT 1 FROM @Posted p JOIN Department d ON d.DepartmentId = p.DepartmentId
				           WHERE ISNULL(d.StatusId, 0) <> 1
				             AND NOT EXISTS (SELECT 1 FROM @OpenNow o WHERE o.DepartmentId = p.DepartmentId))
				BEGIN
					SET @Reason = 23;
					SET @Detail = N'DepartmentInactive';
				END
			END

			-- ManagerScope-Step54: the Reporting Person (Reason 31), checked on every Update
			IF (@Reason = 0 AND ISNULL(@ManagerId, 0) > 0
			    AND NOT EXISTS (SELECT 1 FROM dbo.fn_ReportingPersonAllowed(@DepartmentId, @UserId) rp WHERE rp.UserId = @ManagerId))
			BEGIN
				SET @Reason = 31;
				SET @Detail = N'';
			END

			-- Rule 12: a Manager who leaves departments
			IF (@Reason = 0 AND @OldActive = 1 AND @WasManager = 1)
			BEGIN
				IF (@IsManager = 0)
					INSERT INTO @Lost (DepartmentId) SELECT DepartmentId FROM @OpenNow;
				ELSE
					INSERT INTO @Lost (DepartmentId)
					SELECT o.DepartmentId FROM @OpenNow o WHERE NOT EXISTS (SELECT 1 FROM @Wanted w WHERE w.DepartmentId = o.DepartmentId);

				IF (EXISTS (SELECT 1 FROM @Lost) OR @IsManager = 0)
				BEGIN
					-- Two Managers of one department changing at the same time are serialised here
					SELECT @Locked = COUNT(*) FROM User_Department WITH (UPDLOCK, HOLDLOCK)
					WHERE EffectiveTo IS NULL AND DepartmentId IN (SELECT DepartmentId FROM @Lost);

					IF (@IsManager = 0)
						INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
						SELECT Kind, DepartmentId, DepartmentName, Items FROM dbo.fn_ManagerReleaseRefusal(@UserId, NULL, 1);
					ELSE
						INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
						SELECT f.Kind, f.DepartmentId, f.DepartmentName, f.Items
						FROM @Lost l
						CROSS APPLY dbo.fn_ManagerReleaseRefusal(@UserId, l.DepartmentId, 0) f;

					IF EXISTS (SELECT 1 FROM @Refusal)
					BEGIN
						SET @Reason = 24;
						-- ManagerRelease-Step52: 'open:<n>|past:<n>|' and then the department part as before ('last active
						-- Manager of <names with counts>', or nothing). open: Kind 'P', past: Kind 'Q'. The page builds the message.
						SET @Detail = N'open:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'P'), 0) AS NVARCHAR(12))
						            + N'|past:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'Q'), 0) AS NVARCHAR(12))
						            + N'|'
						            + ISNULL(N'last active Manager of '
						              + STUFF((SELECT N', ' + r.DepartmentName + N' (' + CAST(r.Items AS NVARCHAR(12))
						                              + CASE WHEN r.Items = 1 THEN N' item waiting)' ELSE N' items waiting)' END
						                       FROM @Refusal r WHERE r.Kind = 'D' ORDER BY r.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');
						SET @Detail = LEFT(@Detail, 2000);
					END
				END
			END

			IF (@Reason = 0)
			BEGIN
				UPDATE Users SET
				UserName = @UserName,
				DepartmentId = @DepartmentId,
				DesignationId = @DesignationId,
				ManagerId = @ManagerId,
				RoleId = @RoleId,
				EmailId = @EmailId,
				LoginName = @LoginName,
				UpdatedOn = @UpdatedOn,
				UpdatedBy = @UpdatedBy
				WHERE
				UserId = @UserId;

				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;

				-- History (UserHistory-Step39): active users only
				IF (@Result = 1 AND @OldActive = 1)
				BEGIN
					IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
					BEGIN
						UPDATE User_Role SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'C'
						WHERE UserId = @UserId AND EffectiveTo IS NULL;

						INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @RoleId, @Today, @Now, @ActingUserId);
					END

					IF (@WasManager = 1 AND @IsManager = 0)
						SET @Detail = ISNULL(N'MappingsClosed:'
						              + STUFF((SELECT N', ' + d.DepartmentName FROM @OpenNow o JOIN Department d ON d.DepartmentId = o.DepartmentId
						                       WHERE o.IsVirtual = 0
						                         AND NOT EXISTS (SELECT 1 FROM @Wanted w WHERE w.DepartmentId = o.DepartmentId)
						                       ORDER BY d.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');

					-- Close the rows that go away or whose home flag changes
					UPDATE ud SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId,
					       CloseReason = CASE WHEN @WasManager = 1 AND @IsManager = 0 AND w.DepartmentId IS NULL THEN 'R' ELSE 'C' END
					FROM User_Department ud
					LEFT JOIN @Wanted w ON w.DepartmentId = ud.DepartmentId
					WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL
					  AND (w.DepartmentId IS NULL OR w.IsHome <> ud.IsHome);

					-- Open the rows that are wanted and not open (nor unchanged in Users, for a user without rows)
					INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
					SELECT @UserId, w.DepartmentId, w.IsHome, @Today, @Now, @ActingUserId
					FROM @Wanted w
					WHERE NOT EXISTS (SELECT 1 FROM User_Department ud
					                  WHERE ud.UserId = @UserId AND ud.DepartmentId = w.DepartmentId AND ud.EffectiveTo IS NULL)
					  AND NOT EXISTS (SELECT 1 FROM @OpenNow o
					                  WHERE o.IsVirtual = 1 AND o.DepartmentId = w.DepartmentId AND o.IsHome = w.IsHome);

					-- DepartmentApprovers-Step53: his waiting approval alerts of the departments he leaves are closed for him
					-- ('N'); rule 12 above has made sure another Manager of the department still has them
					IF (@WasManager = 1)
					BEGIN
						INSERT INTO @Rel (DepartmentId)
						SELECT DISTINCT a.DepartmentId
						FROM Alert_User_Map m
						JOIN Alert_Master am ON am.AlertId = m.AlertId
						JOIN Agenda a ON am.SourceType = 'Agenda' AND a.AgendaId = am.SourceTypeId
						WHERE m.UserId = @UserId AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC'
						  AND a.DepartmentId IS NOT NULL
						  AND (@IsManager = 0 OR a.DepartmentId IN (SELECT l.DepartmentId FROM @Lost l));

						SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel);
						WHILE (@RelDept IS NOT NULL)
						BEGIN
							EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @DepartmentId = @RelDept, @Release = 1,
							     @ActingUserId = @ActingUserId, @Released = @RelCount OUTPUT;
							SET @RelTotal = @RelTotal + ISNULL(@RelCount, 0);
							SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel WHERE DepartmentId > @RelDept);
						END
					END

					-- DepartmentApprovers-Step53: a Manager (new role, or a department added) gets his rows of the items
					-- waiting at AC in his departments
					IF (@IsManager = 1)
						EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @ActingUserId = @ActingUserId;
				END

				-- GovernanceLog-Step56: what this save changed, in the governance change log (nothing when nothing changed)
				IF (@Result = 1)
					EXEC dbo.spr_WriteGovernanceUserChanges @ActingUserId = @ActingUserId, @Source = 'spr_AddEditUser',
					     @UserId = @UserId, @Existed = 1, @OldActive = @OldActive, @OldRoleId = @OldRoleId,
					     @OldHome = @OldDepartmentId, @OldManagerId = @GovOldManagerId, @OldDepts = @GovOldDepts,
					     @OldSummary = @GovOldSummary, @OldLogin = @GovOldLogin, @OldName = @GovOldName;
			END

			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION EditUser;

			RAISERROR('%s', 16, 1, @ErrMsg);
			RETURN;
		END CATCH
	END

	IF (@Result <> 1 AND @Reason = 0)
		SET @Detail = N'';

	-- DepartmentApprovers-Step53: '|Released:<n>:<department names>' at the end of a successful detail
	IF (@Result = 1 AND @RelTotal > 0)
		SET @Detail = LEFT(@Detail + N'|Released:' + CAST(@RelTotal AS NVARCHAR(12)) + N':'
		              + ISNULL(STUFF((SELECT N', ' + CAST(d.DepartmentName AS NVARCHAR(200)) FROM @Rel r
		                              JOIN Department d ON d.DepartmentId = r.DepartmentId ORDER BY d.DepartmentName
		                              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N''), 2000);

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_SetUserStatusByUserId (replaced; the step 53 text with the governance change log)
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Users - deactivate / activate (UserProtection-Stage1; UserHistory-Step39)
-------------------------------------------------------------------------------
-- UserHistory-Step39: Deactivate closes every open role and department row (D). Activate of an
-- inactive user is refused while the home department is inactive (Reason 23,
-- 'HomeDepartmentInactive:<name>'); otherwise it opens the role row (Users.RoleId) and the home
-- department, and for a Manager the other departments closed by the last deactivation; one that is
-- inactive now is skipped and named in ReasonDetail ('NotRestored:<names>'). Rows that are already
-- open are kept (an active user's Activate opens nothing).
-- ManagerRelease-Step52 (step MR1, owner 2026-11-19; UD1a had no check here): Deactivate of an active Manager is
-- refused by rule 12 as a role change away from Manager is (fn_ManagerReleaseRefusal, the department part and the
-- personal part): Reason 24, ReasonDetail 'open:<n>|past:<n>|<department part>', the same as spr_AddEditUser.
-- DepartmentApprovers-Step53 (step UD1b): rule 12 refuses only for the items no other Manager of the department could
-- decide. An allowed Deactivate of a Manager marks his rows on the alerts of items at AC 'N' (no longer Manager of the
-- department) in the same transaction; the successful ReasonDetail ends with '|Released:<n>:<department names>'. An
-- Activate of a Manager gives him a row on the alert of every item waiting at AC in his departments
-- (spr_SetManagerAlertRows; his own 'N' row is opened again).
-- GovernanceLog-Step56 (step GM1a): an Activate or a Deactivate that changes the status is written to
-- Governance_Change_Log in the same transaction (spr_WriteGovernanceUserChanges); one of an active user (or of an
-- inactive user) that changes nothing writes nothing.
CREATE OR ALTER PROCEDURE [dbo].[spr_SetUserStatusByUserId]
@UserId INT,
@AccountStatus INT,
@ActingUserId INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @OldActive INT;
DECLARE @HomeId INT;
DECLARE @RoleIdNow INT;
DECLARE @IsManager INT;
DECLARE @LastClosed DATETIME;
DECLARE @Today DATE;
DECLARE @Now DATETIME;
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @Restore TABLE (DepartmentId INT NOT NULL PRIMARY KEY, Active INT NOT NULL, DepartmentName NVARCHAR(200));
DECLARE @Refusal TABLE (Kind CHAR(1), DepartmentId INT NULL, DepartmentName NVARCHAR(200), Items INT);
DECLARE @Rel TABLE (DepartmentId INT NOT NULL PRIMARY KEY);   -- DepartmentApprovers-Step53
DECLARE @RelDept INT;
DECLARE @RelCount INT;
DECLARE @RelTotal INT;
DECLARE @GovOldManagerId INT;   -- GovernanceLog-Step56: the user before the change
DECLARE @GovOldDepts VARCHAR(MAX);
DECLARE @GovOldSummary NVARCHAR(1000);
DECLARE @GovOldLogin NVARCHAR(50);
DECLARE @GovOldName NVARCHAR(200);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
	SET @RelTotal = 0;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @Now = GETDATE();

	IF (@AccountStatus IS NULL OR @AccountStatus NOT IN (0, 1))
	BEGIN
		RAISERROR('spr_SetUserStatusByUserId: @AccountStatus must be 0 (inactive) or 1 (active).', 16, 1);
		RETURN;
	END

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
	END
	ELSE
	BEGIN
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION SetUserStatus;

			-- Rule 2 under concurrency: hold the active Admin / Controller rows
			-- until this transaction ends.
			SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
			WHERE AccountStatus = 1
			AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId,
			                  CASE WHEN @AccountStatus = 0 THEN 'Deactivate' ELSE 'Activate' END, NULL);

			SELECT @OldActive = ISNULL(AccountStatus, 0), @HomeId = DepartmentId, @RoleIdNow = RoleId
			FROM Users WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId;

			-- GovernanceLog-Step56: the user before the change, for the governance change log
			SELECT @GovOldManagerId = ManagerId, @GovOldLogin = LoginName, @GovOldName = UserName FROM Users WHERE UserId = @UserId;
			SET @GovOldDepts = dbo.fn_GovernanceDeptList(@UserId);
			SET @GovOldSummary = dbo.fn_GovernanceUserSummary(@UserId);

			-- ManagerRelease-Step52: rule 12 on Deactivate of an active Manager, under the same lock as a role change
			IF (@Reason = 0 AND @AccountStatus = 0 AND @OldActive = 1
			    AND EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager'))
			BEGIN
				SELECT @Locked = COUNT(*) FROM User_Department WITH (UPDLOCK, HOLDLOCK)
				WHERE EffectiveTo IS NULL
				AND DepartmentId IN (SELECT DepartmentId FROM User_Department WHERE UserId = @UserId AND EffectiveTo IS NULL);

				INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
				SELECT Kind, DepartmentId, DepartmentName, Items FROM dbo.fn_ManagerReleaseRefusal(@UserId, NULL, 1);

				IF EXISTS (SELECT 1 FROM @Refusal)
				BEGIN
					SET @Reason = 24;
					-- ManagerRelease-Step52: 'open:<n>|past:<n>|' and then the department part as before ('last active
					-- Manager of <names with counts>', or nothing). open: Kind 'P', past: Kind 'Q'. The page builds the message.
					SET @Detail = N'open:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'P'), 0) AS NVARCHAR(12))
					            + N'|past:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'Q'), 0) AS NVARCHAR(12))
					            + N'|'
					            + ISNULL(N'last active Manager of '
					              + STUFF((SELECT N', ' + r.DepartmentName + N' (' + CAST(r.Items AS NVARCHAR(12))
					                              + CASE WHEN r.Items = 1 THEN N' item waiting)' ELSE N' items waiting)' END
					                       FROM @Refusal r WHERE r.Kind = 'D' ORDER BY r.DepartmentName
					                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');
					SET @Detail = LEFT(@Detail, 2000);
				END
			END

			-- UserHistory-Step39: no activation into an inactive home department
			IF (@Reason = 0 AND @AccountStatus = 1 AND @OldActive = 0
			    AND EXISTS (SELECT 1 FROM Department WHERE DepartmentId = @HomeId AND ISNULL(StatusId, 0) <> 1))
			BEGIN
				SET @Reason = 23;
				SET @Detail = LEFT(N'HomeDepartmentInactive:' + ISNULL((SELECT CAST(DepartmentName AS NVARCHAR(200)) FROM Department WHERE DepartmentId = @HomeId), N''), 2000);
			END

			IF (@Reason = 0)
			BEGIN
				UPDATE Users SET
				AccountStatus = @AccountStatus,
				UpdatedOn = GETDATE(),
				UpdatedBy = @ActingUserId
				WHERE
				UserId = @UserId;

				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;

				-- History (UserHistory-Step39)
				IF (@Result = 1 AND @AccountStatus = 0)
				BEGIN
					UPDATE User_Role SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'D'
					WHERE UserId = @UserId AND EffectiveTo IS NULL;

					UPDATE User_Department SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'D'
					WHERE UserId = @UserId AND EffectiveTo IS NULL;

					-- DepartmentApprovers-Step53: a deactivated Manager's waiting approval alerts are closed for him ('N')
					IF (@OldActive = 1 AND EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager'))
					BEGIN
						INSERT INTO @Rel (DepartmentId)
						SELECT DISTINCT a.DepartmentId
						FROM Alert_User_Map m
						JOIN Alert_Master am ON am.AlertId = m.AlertId
						JOIN Agenda a ON am.SourceType = 'Agenda' AND a.AgendaId = am.SourceTypeId
						WHERE m.UserId = @UserId AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC'
						  AND a.DepartmentId IS NOT NULL;

						SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel);
						WHILE (@RelDept IS NOT NULL)
						BEGIN
							EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @DepartmentId = @RelDept, @Release = 1,
							     @ActingUserId = @ActingUserId, @Released = @RelCount OUTPUT;
							SET @RelTotal = @RelTotal + ISNULL(@RelCount, 0);
							SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel WHERE DepartmentId > @RelDept);
						END
					END
				END

				-- DepartmentApprovers-Step53: an activated Manager gets his rows of the items waiting at AC in his departments
				-- (after his department rows are opened below)
				IF (@Result = 1 AND @AccountStatus = 1)
				BEGIN
					IF NOT EXISTS (SELECT 1 FROM User_Role WHERE UserId = @UserId AND EffectiveTo IS NULL)
					   AND EXISTS (SELECT 1 FROM User_Role WHERE UserId = @UserId)
						INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @RoleIdNow, @Today, @Now, @ActingUserId);

					IF NOT EXISTS (SELECT 1 FROM User_Department WHERE UserId = @UserId AND EffectiveTo IS NULL)
					   AND EXISTS (SELECT 1 FROM User_Department WHERE UserId = @UserId)
					BEGIN
						INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @HomeId, 1, @Today, @Now, @ActingUserId);

						SET @IsManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager') THEN 1 ELSE 0 END;

						IF (@IsManager = 1)
						BEGIN
							SET @LastClosed = (SELECT MAX(ClosedOn) FROM User_Department WHERE UserId = @UserId AND CloseReason = 'D');

							INSERT INTO @Restore (DepartmentId, Active, DepartmentName)
							SELECT DISTINCT ud.DepartmentId, CASE WHEN ISNULL(d.StatusId, 0) = 1 THEN 1 ELSE 0 END, CAST(d.DepartmentName AS NVARCHAR(200))
							FROM User_Department ud
							JOIN Department d ON d.DepartmentId = ud.DepartmentId
							WHERE ud.UserId = @UserId AND ud.CloseReason = 'D' AND ud.ClosedOn = @LastClosed
							  AND ud.DepartmentId <> @HomeId;

							INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
							SELECT @UserId, r.DepartmentId, 0, @Today, @Now, @ActingUserId
							FROM @Restore r WHERE r.Active = 1;

							IF EXISTS (SELECT 1 FROM @Restore WHERE Active = 0)
								SET @Detail = LEFT(N'NotRestored:'
								              + STUFF((SELECT N', ' + r.DepartmentName FROM @Restore r WHERE r.Active = 0 ORDER BY r.DepartmentName
								                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), 2000);
						END
					END

					IF EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager')
						EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @ActingUserId = @ActingUserId;   -- DepartmentApprovers-Step53
				END

				-- GovernanceLog-Step56: the change of status in the governance change log (nothing when it did not change)
				IF (@Result = 1)
					EXEC dbo.spr_WriteGovernanceUserChanges @ActingUserId = @ActingUserId, @Source = 'spr_SetUserStatusByUserId',
					     @UserId = @UserId, @Existed = 1, @OldActive = @OldActive, @OldRoleId = @RoleIdNow,
					     @OldHome = @HomeId, @OldManagerId = @GovOldManagerId, @OldDepts = @GovOldDepts,
					     @OldSummary = @GovOldSummary, @OldLogin = @GovOldLogin, @OldName = @GovOldName;
			END

			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION SetUserStatus;

			RAISERROR('%s', 16, 1, @ErrMsg);
			RETURN;
		END CATCH
	END


	-- DepartmentApprovers-Step53: '|Released:<n>:<department names>' at the end of a successful detail
	IF (@Result = 1 AND @RelTotal > 0)
		SET @Detail = LEFT(@Detail + N'|Released:' + CAST(@RelTotal AS NVARCHAR(12)) + N':'
		              + ISNULL(STUFF((SELECT N', ' + CAST(d.DepartmentName AS NVARCHAR(200)) FROM @Rel r
		                              JOIN Department d ON d.DepartmentId = r.DepartmentId ORDER BY d.DepartmentName
		                              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N''), 2000);

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_DeleteUserByUserId (replaced; the step 47 text with the governance change log)
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Users - delete (UserHistory-Step39)
-------------------------------------------------------------------------------
-- Users - delete (FK #5, FK#5-UserDelete-AllColumns, UserProtection-Stage1)
-- UserHistory-Step39: rows the user wrote in another user's role or department history (CreatedBy /
-- ClosedBy) are history: Reason 6, group 'user changes'. The user's own User_Role and User_Department
-- rows go with an otherwise unused user.
-- FollowupFinal-Step47: rows the user wrote in Action_Item_Status_History (ActedBy: a Confirm or a Reopen on the
-- Followup page) are history in the group 'minutes' (Reason 6); its foreign key to Users would refuse the delete otherwise.
-- GovernanceLog-Step56 (step GM1a): rows the user wrote in the governance change log (ChangedBy) are history in the
-- group 'user changes' (Reason 6). A delete is written to Governance_Change_Log in the same transaction (ChangeType
-- 'UX', OldValue the role, the home department and the Manager's departments held at the delete); the log rows
-- about the deleted user stay (their UserId is no key to Users).
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteUserByUserId]
@UserId INT,
@ActingUserId INT = NULL,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT,
@OutReasonDetail NVARCHAR(2000) = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @UserCreatedOn DATETIME;
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @ErrNo INT;
DECLARE @GovOldActive INT;   -- GovernanceLog-Step56: the user before the delete
DECLARE @GovOldRoleId INT;
DECLARE @GovOldHome INT;
DECLARE @GovOldManagerId INT;
DECLARE @GovOldDepts VARCHAR(MAX);
DECLARE @GovOldSummary NVARCHAR(1000);
DECLARE @GovOldLogin NVARCHAR(50);
DECLARE @GovOldName NVARCHAR(200);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
	END
	ELSE
	BEGIN
		-- Called by the application there is no open transaction, so this
		-- procedure starts and ends its own. Called inside someone else's
		-- transaction (the test scripts) it only uses a savepoint.
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION DeleteUser;

			-- Rule 2 under concurrency: hold the active Admin / Controller rows
			-- until this transaction ends.
			SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
			WHERE AccountStatus = 1
			AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'Delete', NULL);

			-- 5. other users point at this user
			IF (@Reason = 0)
			BEGIN
				SET @Detail = ISNULL(STUFF((SELECT N', ' + u.UserName
				                            FROM Users u
				                            WHERE u.UserId <> @UserId
				                            AND (u.ManagerId = @UserId OR u.CreatedBy = @UserId OR u.UpdatedBy = @UserId)
				                            ORDER BY u.UserName
				                            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');

				IF (@Detail <> N'')
					SET @Reason = 5;
			END

			-- 6. history, every group that applies
			IF (@Reason = 0)
			BEGIN
				SET @UserCreatedOn = (SELECT CreatedOn FROM Users WHERE UserId = @UserId);

				IF EXISTS (SELECT 1 FROM Agenda WHERE CreatedBy = @UserId OR UpdatedBy = @UserId
				           OR MgrApprovedBy = @UserId OR ControllerApprovedBy = @UserId)
					SET @Detail = @Detail + N', agendas/approvals';
				IF EXISTS (SELECT 1 FROM Meeting WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Meeting_Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', meetings';
				IF EXISTS (SELECT 1 FROM Minutes WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Action_Item WHERE UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Action_Item_Status_History WHERE ActedBy = @UserId)   -- FollowupFinal-Step47
					SET @Detail = @Detail + N', minutes';
				IF EXISTS (SELECT 1 FROM Committee WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Committee_Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', committees/members';
				IF EXISTS (SELECT 1 FROM Attendance WHERE UpdatedBy = @UserId)
					SET @Detail = @Detail + N', attendance';
				IF EXISTS (SELECT 1 FROM Alert_Master WHERE CreatedBy = @UserId)
					SET @Detail = @Detail + N', alerts sent';
				IF EXISTS (SELECT 1 FROM Audit_Trail_Master WHERE Update_By = @UserId)
					SET @Detail = @Detail + N', audit trail';
				-- Rows older than the user belong to an earlier user with the same id.
				IF EXISTS (SELECT 1 FROM Audit_Trail_SendMail WHERE Mail_Send_By = @UserId
				           AND (@UserCreatedOn IS NULL OR Mail_Send_On IS NULL OR Mail_Send_On >= @UserCreatedOn))
					SET @Detail = @Detail + N', mail sent';
				IF EXISTS (SELECT 1 FROM Audit_Trail_SqlBackup WHERE [User_Id] = @UserId)
					SET @Detail = @Detail + N', backups';
				IF EXISTS (SELECT 1 FROM Audit_Trial_Login WHERE [User_Id] = @UserId
				           AND (@UserCreatedOn IS NULL OR Login_DateTime IS NULL OR Login_DateTime >= @UserCreatedOn))
					SET @Detail = @Detail + N', login history';
				IF EXISTS (SELECT 1 FROM Department WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Designation WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Roles WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Alert_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Decision_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Member_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Subject_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', master data';
				IF EXISTS (SELECT 1 FROM User_Role WHERE UserId <> @UserId AND (CreatedBy = @UserId OR ClosedBy = @UserId))
				   OR EXISTS (SELECT 1 FROM User_Department WHERE UserId <> @UserId AND (CreatedBy = @UserId OR ClosedBy = @UserId))
				   OR EXISTS (SELECT 1 FROM Governance_Change_Log WHERE ChangedBy = @UserId)   -- GovernanceLog-Step56
					SET @Detail = @Detail + N', user changes';

				IF (@Detail <> N'')
				BEGIN
					SET @Detail = STUFF(@Detail, 1, 2, N'');
					SET @Reason = 6;
				END
			END

			IF (@Reason = 0)
			BEGIN
				-- GovernanceLog-Step56: the user before the delete, for the governance change log
				SELECT @GovOldActive = ISNULL(AccountStatus, 0), @GovOldRoleId = RoleId, @GovOldHome = DepartmentId,
				       @GovOldManagerId = ManagerId, @GovOldLogin = LoginName, @GovOldName = UserName
				FROM Users WHERE UserId = @UserId;
				SET @GovOldDepts = dbo.fn_GovernanceDeptList(@UserId);
				SET @GovOldSummary = dbo.fn_GovernanceUserSummary(@UserId);

				-- Alerts received and action-item read flags go with the user.
				DELETE FROM Alert_User_Map WHERE UserId = @UserId;

				DELETE FROM ActionItem_User_Map WHERE UserId = @UserId;

				-- The user's own role and department history (UserHistory-Step39)
				DELETE FROM User_Department WHERE UserId = @UserId;

				DELETE FROM User_Role WHERE UserId = @UserId;

				DELETE FROM Users WHERE UserId = @UserId;

				-- GovernanceLog-Step56: the delete in the governance change log (UX), only when a user was deleted
				IF (@@ROWCOUNT = 1)
					EXEC dbo.spr_WriteGovernanceUserChanges @ActingUserId = @ActingUserId, @Source = 'spr_DeleteUserByUserId',
					     @UserId = @UserId, @Existed = 1, @OldActive = @GovOldActive, @OldRoleId = @GovOldRoleId,
					     @OldHome = @GovOldHome, @OldManagerId = @GovOldManagerId, @OldDepts = @GovOldDepts,
					     @OldSummary = @GovOldSummary, @OldLogin = @GovOldLogin, @OldName = @GovOldName;

				SET @Result = 1;
			END

			-- A refusal changed nothing, so there is nothing to roll back.
			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();
			SET @ErrNo = ERROR_NUMBER();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION DeleteUser;

			-- 547 = a foreign key the checks above do not know still points at
			-- the user. Anything else is a real error and is passed on.
			IF (@ErrNo <> 547)
			BEGIN
				RAISERROR('%s', 16, 1, @ErrMsg);
				RETURN;
			END

			SET @Result = 0;
			SET @Reason = 9;
			SET @Detail = LEFT(@ErrMsg, 2000);
		END CATCH
	END

	SET @OutResult = @Result;
	SET @OutReason = @Reason;
	SET @OutReasonDetail = @Detail;

	SELECT @Result AS Result, @Reason AS Reason, @Detail AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_AddEditDepartment (replaced; the baseline text with the governance change log)
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Department - add / edit (GovernanceLog-Step56, step GM1a; the baseline text had no check and no transaction)
-------------------------------------------------------------------------------
-- Only an active Admin (Department Master is an Admin page since step RA1a): @ActingUserId missing, 0 or inactive
-- Reason 8, any other role Reason 4; checked before anything is changed. @ActingUserId is optional for the call
-- shape only: an older build that does not pass it gets Reason 8 and nothing is saved. One transaction. An Update
-- that changes the status (StatusId 1 active, anything else inactive) writes one row to Governance_Change_Log
-- (ChangeType 'KA' activated or 'KD' deactivated) in the same transaction; a new department and an Update that
-- keeps the status write none. An Update of a department that does not exist, or another @Code: Reason 3, nothing
-- saved. @CreatedBy and @UpdatedBy are stored as before. One row Result, Reason, ReasonDetail
-- (also in @Result and @Reason).
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditDepartment]
@Code VARCHAR(50),
@DepartmentId INT,
@DepartmentCode VARCHAR(10),
@DepartmentName VARCHAR(50),
@OrderNo INT,
@StatusId INT,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @OldStatus INT;
DECLARE @Found INT;
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @WasActive INT;
DECLARE @IsActive INT;
DECLARE @ChangeType CHAR(2);
DECLARE @OldText NVARCHAR(20);
DECLARE @NewText NVARCHAR(20);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';

	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

	IF (ISNULL(@ActingUserId, 0) = 0 OR @ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole <> 'admin')
		SET @Reason = 4;
	ELSE IF (ISNULL(@Code, '') NOT IN ('Save', 'Update'))
	BEGIN
		SET @Reason = 3;
		SET @Detail = N'Code';
	END

	IF (@Reason = 0)
	BEGIN
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION DepartmentSave;

			IF (@Code = 'Save')
			BEGIN
				INSERT INTO Department
				(DepartmentCode, DepartmentName, OrderNo,
					StatusId, CreatedOn, CreatedBy)
				VALUES
				(@DepartmentCode, @DepartmentName, @OrderNo,
					@StatusId, @CreatedOn, @CreatedBy);

				SET @Result = 1;
			END
			ELSE
			BEGIN
				SET @Found = 0;
				SELECT @Found = 1, @OldStatus = StatusId FROM Department WITH (UPDLOCK, HOLDLOCK) WHERE DepartmentId = @DepartmentId;

				IF (@Found = 0)
				BEGIN
					SET @Reason = 3;
					SET @Detail = N'NotFound';
				END
				ELSE
				BEGIN
					UPDATE Department SET
					DepartmentCode = @DepartmentCode,
					DepartmentName = @DepartmentName,
					OrderNo = @OrderNo,
					StatusId = @StatusId,
					UpdatedOn = @UpdatedOn,
					UpdatedBy = @UpdatedBy
					WHERE
					DepartmentId = @DepartmentId;

					SET @Result = 1;

					-- The status in the governance change log, only when it changes between active and inactive
					SET @WasActive = CASE WHEN ISNULL(@OldStatus, 0) = 1 THEN 1 ELSE 0 END;
					SET @IsActive = CASE WHEN ISNULL(@StatusId, 0) = 1 THEN 1 ELSE 0 END;

					IF (@WasActive <> @IsActive)
					BEGIN
						SET @ChangeType = CASE WHEN @IsActive = 1 THEN 'KA' ELSE 'KD' END;
						SET @OldText = CASE WHEN @WasActive = 1 THEN N'Active' ELSE N'Inactive' END;
						SET @NewText = CASE WHEN @IsActive = 1 THEN N'Active' ELSE N'Inactive' END;

						EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = 'spr_AddEditDepartment',
						     @ChangeType = @ChangeType, @DepartmentId = @DepartmentId, @OldId = @WasActive, @NewId = @IsActive,
						     @OldValue = @OldText, @NewValue = @NewText;
					END
				END
			END

			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();
			SET @Result = 0;

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION DepartmentSave;

			RAISERROR('%s', 16, 1, @ErrMsg);
			RETURN;
		END CATCH
	END

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_SetDepartmentManagerRule (replaced; the step 39 text with the governance change log)
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Settings - DeptNoManagerAction, rule 6 (UserHistory-Step39); only an active Admin.
-------------------------------------------------------------------------------
-- Values 'refuse' (default) and 'controller'. Stored only: nothing reads it until a later step.
-- One row Result, Reason, ReasonDetail as spr_SetAppSetting: 8 acting user missing or inactive,
-- 4 not an Admin, 3 value not valid (ReasonDetail the value). A change writes one Audit_Trail_Master
-- row (Audit_Table 'App_Setting'); saving the same value writes none.
-- GovernanceLog-Step56 (step GM1a): a change is also written to Governance_Change_Log (ChangeType 'ST').
CREATE OR ALTER PROCEDURE [dbo].[spr_SetDepartmentManagerRule]
@SettingValue VARCHAR(250),
@ActingUserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @OldValue VARCHAR(250);
DECLARE @ErrMsg NVARCHAR(2048);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION DeptRuleSave;

		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

		IF (@ActingRole IS NULL)
			SET @Reason = 8;
		ELSE IF (@ActingRole <> 'admin')
			SET @Reason = 4;
		ELSE IF (ISNULL(@SettingValue, '') NOT IN ('refuse', 'controller'))
		BEGIN
			SET @Reason = 3;
			SET @Detail = LEFT(ISNULL(@SettingValue, 'NULL'), 250);
		END
		ELSE
		BEGIN
			SET @OldValue = (SELECT SettingValue FROM App_Setting WITH (UPDLOCK, HOLDLOCK) WHERE SettingCode = 'DeptNoManagerAction');

			IF (@OldValue IS NULL)
				INSERT INTO App_Setting (SettingCode, SettingValue, Description)
				VALUES ('DeptNoManagerAction', @SettingValue, 'When a department has no active Manager: refuse the item (refuse, default) or send it to the Controllers (controller). Stored now, used from a later step (step 39)');
			ELSE
				UPDATE App_Setting SET SettingValue = @SettingValue WHERE SettingCode = 'DeptNoManagerAction';

			IF (ISNULL(@OldValue, '') <> @SettingValue)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'App_Setting', 'SettingCode', 'DeptNoManagerAction', 'SettingValue', ISNULL(@OldValue, ''), @SettingValue, @ActingUserId, GETDATE());

				-- GovernanceLog-Step56 (step GM1a): the change in the governance change log, in the same transaction
				EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = 'spr_SetDepartmentManagerRule',
				     @ChangeType = 'ST', @SettingCode = 'DeptNoManagerAction', @OldValue = @OldValue, @NewValue = @SettingValue;
			END

			SET @Result = 1;
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		SET @ErrMsg = ERROR_MESSAGE();

		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION DeptRuleSave;

		RAISERROR('%s', 16, 1, @ErrMsg);
		RETURN;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, @Detail AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_SetAppSetting (replaced; the step 16 text with the governance change log)
-------------------------------------------------------------------------------
GO

-- Settings - change one; only an active Admin (MeetingLocks-Step16)
-- GovernanceLog-Step56 (step GM1a): a change is also written to Governance_Change_Log (ChangeType 'ST').
CREATE OR ALTER PROCEDURE [dbo].[spr_SetAppSetting]
@SettingCode VARCHAR(50),
@SettingValue VARCHAR(250),
@ActingUserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @OldValue VARCHAR(250);
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
			SAVE TRANSACTION AppSettingSave;

		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

		IF (@ActingRole IS NULL)
			SET @Reason = 8;
		ELSE IF (@ActingRole <> 'admin')
			SET @Reason = 4;
		ELSE IF (ISNULL(@SettingCode, '') <> 'AgendaControllerBypass' OR ISNULL(@SettingValue, '') NOT IN ('0', '1'))
		BEGIN
			SET @Reason = 3;
			SET @Detail = ISNULL(@SettingValue, 'NULL');
		END
		ELSE
		BEGIN
			SET @OldValue = (SELECT SettingValue FROM App_Setting WITH (UPDLOCK, HOLDLOCK) WHERE SettingCode = @SettingCode);

			IF (@OldValue IS NULL)
				INSERT INTO App_Setting (SettingCode, SettingValue, Description)
				VALUES (@SettingCode, @SettingValue, 'Controller can add, edit and delete agenda items after the agenda is finalized (until the minutes are finalized)');
			ELSE
				UPDATE App_Setting SET SettingValue = @SettingValue WHERE SettingCode = @SettingCode;

			IF (ISNULL(@OldValue, '') <> @SettingValue)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'App_Setting', 'SettingCode', @SettingCode, 'SettingValue', ISNULL(@OldValue, ''), @SettingValue, @ActingUserId, GETDATE());

				-- GovernanceLog-Step56 (step GM1a): the change in the governance change log, in the same transaction
				EXEC dbo.spr_WriteGovernanceChange @ActingUserId = @ActingUserId, @Source = 'spr_SetAppSetting',
				     @ChangeType = 'ST', @SettingCode = @SettingCode, @OldValue = @OldValue, @NewValue = @SettingValue;
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
			ROLLBACK TRANSACTION AppSettingSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_sys_ResetDatabase (replaced; the step 39 text with the governance change log)
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Reset Database (UserHistory-Step39), the step 30 text plus the history tables
-------------------------------------------------------------------------------
-- Reset Database: wipes all data and seeds the defaults. The "admin" user is seeded as the protected
-- system account (IsSystem = 1), the other three with IsSystem = 0; the seed e-mail addresses are
-- placeholders (SystemAccount3-Step18). Seeded passwords are hashes of the application's default password,
-- Common.DefaultPassword in BMMSBAL/Common.cs (DefaultPassword-Step29).
-- Member types are seeded with their scope (C committee, M meeting), display order and the reserved
-- flag: 2 Invitee, 3 In Attendance and 6 Special Invitee are reserved (MemberTypes-Step21).
-- ResetSafe-Step29: only an active Admin who names the current database; prechecks before anything is
-- cleared; one transaction (XACT_ABORT ON), identity counters put back after a rollback; the send-mail
-- audit is cleared too; one audit row records who reset the database.
-- SmtpDefault-Step30: the mail settings (SMTP_Master) are replaced inside the transaction by the one safe
-- default row of spr_sys_SetSmtpDefault (localhost, port 25, no login, From noreply@example.invalid, no Bcc).
-- UserHistory-Step39: User_Role and User_Department are cleared before Users, their counters start again
-- at the seed (as the five tables TRUNCATE used to clear), and each seed user gets one open row in each,
-- dated today, created by user 1 (the system account), the home department marked IsHome = 1.
-- GovernanceLog-Step56 (step GM1a): the governance change log (Governance_Change_Log) is cleared before Users (its
-- ChangedBy is a key to Users) and its counter starts again at the seed. the settings are not touched (step 19): the log's
-- start after a reset is the time of the reset's own audit row (fn_GovernanceHistoryStart).
CREATE OR ALTER PROCEDURE [dbo].[spr_sys_ResetDatabase]
	@ActingUserId INT,
	@ConfirmDatabaseName NVARCHAR(128),
	@Result INT = NULL OUTPUT,
	@Reason INT = NULL OUTPUT
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Detail VARCHAR(100);
DECLARE @ActingRole VARCHAR(50);
DECLARE @ActingLogin VARCHAR(50);
DECLARE @Sql NVARCHAR(400);
DECLARE @TableName SYSNAME;
DECLARE @SavedValue BIGINT;
DECLARE @SeedValue BIGINT;
DECLARE @IncrementValue BIGINT;
DECLARE @Ident TABLE (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
DECLARE @DbName NVARCHAR(128);
DECLARE @SmtpResult INT;
DECLARE @SmtpReason INT;

SET @Result = 0;
SET @Reason = 0;
SET @Detail = '';
SET @DbName = DB_NAME();

-------------------------------------------------------------------------------
-- Prechecks: nothing has been changed yet
-------------------------------------------------------------------------------
SELECT @ActingRole = r.RoleCode, @ActingLogin = CAST(u.LoginName AS VARCHAR(50))
FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

IF (@ActingRole IS NULL)
	SET @Reason = 8;
ELSE IF (LTRIM(RTRIM(@ActingRole)) <> 'admin')
	SET @Reason = 4;
ELSE IF (UPPER(LTRIM(RTRIM(ISNULL(@ConfirmDatabaseName, N'')))) <> UPPER(DB_NAME()))
BEGIN
	SET @Reason = 3;
	SET @Detail = 'DatabaseName';
END

IF (@Reason = 0)
BEGIN
	-- Every identity counter as it is now (a counter never used has no saved value)
	INSERT INTO @Ident (TableName, SavedValue, SeedValue, IncrementValue)
	SELECT t.name,
	       CASE WHEN ic.last_value IS NULL THEN NULL ELSE CAST(IDENT_CURRENT('dbo.' + QUOTENAME(t.name)) AS BIGINT) END,
	       CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
	FROM sys.identity_columns ic
	INNER JOIN sys.tables t ON t.object_id = ic.object_id
	WHERE t.is_ms_shipped = 0 AND SCHEMA_NAME(t.schema_id) = 'dbo';

	BEGIN TRY
	BEGIN TRANSACTION;

	---------------------------------------------------------------------------
	-- 1. Clear (DELETE only, child tables first)
	---------------------------------------------------------------------------
	DELETE FROM ActionItem_User_Map;
	DELETE FROM Alert_User_Map;
	DELETE FROM Meeting_Member;
	DELETE FROM Committee_Member;
	DELETE FROM Attendance;

	DELETE FROM SysCodeSetting;
	DELETE FROM Audit_Trail_Master;
	DELETE FROM Audit_Trail_SqlBackup;
	DELETE FROM Audit_Trial_Login;
	DELETE FROM Audit_Trail_SendMail;
	DELETE FROM Action_Item;
	DELETE FROM Alert_Master;
	DELETE FROM Minutes;
	DELETE FROM Agenda;
	DELETE FROM Agenda_Status;
	DELETE FROM Meeting;
	DELETE FROM Committee;
	DELETE FROM Member;
	DELETE FROM Member_Type;
	DELETE FROM Alert_Type;
	DELETE FROM Decision_Type;
	DELETE FROM Governance_Change_Log;   -- GovernanceLog-Step56
	DELETE FROM User_Department;
	DELETE FROM User_Role;
	DELETE FROM Users;
	DELETE FROM Department;
	DELETE FROM Designation;
	DELETE FROM Subject_Type;
	DELETE FROM Roles;

	---------------------------------------------------------------------------
	-- 2. Identity counters, all after the clearing
	---------------------------------------------------------------------------
	-- The five tables TRUNCATE used to clear: a used counter starts again at its seed, as TRUNCATE did;
	-- the two history tables of step 39 the same way (UserHistory-Step39)
	DECLARE SeedCursor CURSOR LOCAL FAST_FORWARD FOR
		SELECT TableName, SeedValue, IncrementValue FROM @Ident
		WHERE SavedValue IS NOT NULL
		  AND TableName IN ('ActionItem_User_Map', 'Alert_User_Map', 'Meeting_Member', 'Committee_Member', 'Attendance',
		                    'User_Role', 'User_Department', 'Governance_Change_Log');   -- GovernanceLog-Step56

	OPEN SeedCursor;
	FETCH NEXT FROM SeedCursor INTO @TableName, @SeedValue, @IncrementValue;

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @Sql = N'DBCC CHECKIDENT (''dbo.' + QUOTENAME(@TableName) + N''', RESEED, '
		         + CAST(@SeedValue - @IncrementValue AS NVARCHAR(20)) + N') WITH NO_INFOMSGS';
		EXEC sp_executesql @Sql;
		FETCH NEXT FROM SeedCursor INTO @TableName, @SeedValue, @IncrementValue;
	END

	CLOSE SeedCursor;
	DEALLOCATE SeedCursor;

	DBCC CHECKIDENT (Audit_Trail_Master, RESEED, 0);
	DBCC CHECKIDENT (Audit_Trail_SqlBackup, RESEED, 0);
	DBCC CHECKIDENT (Audit_Trial_Login, RESEED, 0);
	DBCC CHECKIDENT (Audit_Trail_SendMail, RESEED, 0);
	DBCC CHECKIDENT (Action_Item, RESEED, 0);
	DBCC CHECKIDENT (Alert_Master, RESEED, 0);
	DBCC CHECKIDENT (Minutes, RESEED, 0);
	DBCC CHECKIDENT (Agenda, RESEED, 0);
	DBCC CHECKIDENT (Meeting, RESEED, 0);
	DBCC CHECKIDENT (Committee, RESEED, 0);
	DBCC CHECKIDENT (Member, RESEED, 0);
	DBCC CHECKIDENT (Member_Type, RESEED, 0);
	DBCC CHECKIDENT (Decision_Type, RESEED, 0);
	DBCC CHECKIDENT (Users, RESEED, 0);
	DBCC CHECKIDENT (Department, RESEED, 0);
	DBCC CHECKIDENT (Designation, RESEED, 0);
	DBCC CHECKIDENT (Subject_Type, RESEED, 0);
	DBCC CHECKIDENT (Roles, RESEED, 0);

	---------------------------------------------------------------------------
	-- 3. The mail settings: one row with the safe default, so a reset database sends no real mail
	--    (SmtpDefault-Step30). Before the default rows: a failure in them rolls this back too.
	---------------------------------------------------------------------------
	EXEC dbo.spr_sys_SetSmtpDefault @ConfirmDatabaseName = @DbName, @ReturnRow = 0,
	     @Result = @SmtpResult OUTPUT, @Reason = @SmtpReason OUTPUT;

	IF (ISNULL(@SmtpResult, 0) <> 1)
		THROW 50030, 'Reset Database: the mail settings could not be set to the default (spr_sys_SetSmtpDefault).', 1;

	---------------------------------------------------------------------------
	-- 4. The default rows
	---------------------------------------------------------------------------
INSERT INTO [SysCodeSetting]
([SysCodeId], [MainCode],[SubCode],[DisplayName],[Remarks],[DisplayOrder],[IsActive])
SELECT 1, 'Status', '1', 'Active', 'Status', 1, 1
UNION ALL
SELECT 2, 'Status', '0', 'InActive', 'Status', 2, 1
UNION ALL
SELECT 3, 'Sex', '1', 'Male', 'Sex', 1, 1
UNION ALL
SELECT 4, 'Sex', '0', 'Female', 'Sex', 2, 1;

INSERT INTO [Agenda_Status]
([AgendaStatusCode],[AgendaStatusName])
SELECT 'AC', 'Agenda Creation'
UNION ALL
SELECT 'AMA', 'Manager Approved'
UNION ALL
SELECT 'ACA', 'Controller Approved'
UNION ALL
SELECT 'AMR', 'Manager Rejected'
UNION ALL
SELECT 'ACR', 'Controller Rejected'
UNION ALL
SELECT 'AF', 'Finalized';


INSERT INTO [Alert_Type]
([AlertTypeCode],[AlertTypeName],[AlertTypeDescription],[OrderNo],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'CC', 'Creation', 'Committee Creation', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MC', 'Creation', 'Meeting Creation', 2, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AC', 'Creation', 'Agenda Creation', 3, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AMA', 'Manager Approved', 'Agenda Manager Approved', 4, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ACA', 'Controller Approved', 'Agenda Controller Approved', 5, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AMR', 'Manager Rejected', 'Agenda Manager Rejected', 6, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ACR', 'Controller Rejected', 'Agenda Controller Rejected', 7, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AF', 'Finalized', 'Agenda Finalized', 8, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MF', 'Finalized', 'Minutes Finalized', 9, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MU', 'Updated', 'Meeting Updated', 10, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'CU', 'Updated', 'Committee Updated', 11, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Member_Type]
([MemberTypeCode],[MemberTypeName],[StatusId],[IsDelete],[MemberScope],[DisplayOrder],[IsReserved],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'Member', 'Member', 1, 1, 'C', 1, 0, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Invitee', 'Invitee', 1, 1, 'M', 2, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'InAttendance', 'In Attendance', 1, 1, 'M', 3, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Chairman', 'Chairman', 1, 1, 'C', 4, 0, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MD', 'Managing Director', 1, 1, 'C', 5, 0, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Special Invitee', 'Special Invitee', 1, 1, 'M', 6, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Decision_Type]
([DecisionTypeCode],[DecisionTypeName],[StatusId],[IsDelete],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'DT001', 'Followup', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DT002', 'Pending', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DT003', 'Sanctioned', 1, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Subject_Type]
([SubjectTypeCode],[SubjectTypeName],[OrderNo],[StatusId],[IsDelete],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'ST001', 'Ratification', 1, 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ST002', 'Information', 2, 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ST003', 'Sanction', 3, 1, 1, GETDATE(), 1, GETDATE(), 1;


INSERT INTO [Department]
([DepartmentCode],[DepartmentName],[OrderNo],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'D001', 'Admin', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D002', 'Secretarial', 2, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D003', 'HRD', 3, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D004', 'Credit', 4, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Designation]
([DesignationCode],[DesignationName],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'DESIGN001', 'Administrator', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN002', 'Company Secretary', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN003', 'Chairman', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN004', 'Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN005', 'Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN006', 'Assistant Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN007', 'General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN008', 'Assistant General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN009', 'Deputy General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN010', 'Managing Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN011', 'Executive Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN012', 'Chief Operating Officer', 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Roles]
([RoleCode],[RoleName],[RoleDescription],[OrderNo],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'admin', 'Admin', 'Administrator', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'controller', 'Controller', 'Controller', 2, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'manager', 'Manager', 'Manager', 3, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'user', 'User', 'User', 4, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'mgmt', 'Management', 'Management', 5, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'md_sect', 'MD Secretariat', 'MD Secretariat', 6, GETDATE(), 1, GETDATE(), 1;


-- FK#5-ManagerId-NULL: no manager is stored as NULL, never 0
INSERT INTO [Users]
([UserName],[DepartmentId],[DesignationId],[ManagerId],[RoleId],[EmailId],[LoginName],[Password]
           ,[AccountStatus],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy],[IsSystem])
SELECT 'admin', 1, 1, NULL, 1, '', 'admin', '100000.gURba0Xwa3iXhBwkFEi/hA==.yxFedi3Cfs3FLcDlU7oWXp94eY15AGoU4AN+c3tf8j0=', 1, GETDATE(), 1, GETDATE(), 1, 1
UNION ALL
SELECT 'Controller', 2, 3, NULL, 2, 'con@example.invalid', 'secuser', '100000.QcDvazIat4fcHJw+tivVTg==.dLQDFP7A1cYcAcaYsIvwlXFsZv8lAYDJIVqwDUWNBJ8=', 1, GETDATE(), 1, GETDATE(), 1, 0
UNION ALL
SELECT 'Manager', 4, 4, NULL, 3, 'mgr@example.invalid', 'credmanager', '100000.pJ5r7xUvCSnGHp+32dpp4w==.ity6i4nc8MrUUoy2nnHfxy17AZp61+bNYkvs1gYQLhI=', 1, GETDATE(), 1, GETDATE(), 1, 0
UNION ALL
SELECT 'User', 4, 5, 3, 4, 'usr@example.invalid', 'creduser', '100000.UfrmZn5v9zOs6DlxPdFy9Q==.qHS0QM1qZuYJfnITWbrNUucDryAyVLNz1HdnnDcxLbc=', 1, GETDATE(), 1, GETDATE(), 1, 0;

-- UserHistory-Step39: one open role row and one open home department row per seed user
INSERT INTO [User_Role] ([UserId], [RoleId], [EffectiveFrom], [CreatedOn], [CreatedBy])
SELECT u.UserId, u.RoleId, CAST(GETDATE() AS DATE), GETDATE(), 1 FROM Users u;

INSERT INTO [User_Department] ([UserId], [DepartmentId], [IsHome], [EffectiveFrom], [CreatedOn], [CreatedBy])
SELECT u.UserId, u.DepartmentId, 1, CAST(GETDATE() AS DATE), GETDATE(), 1 FROM Users u;


INSERT INTO [Committee]
([CommitteeCode],[CommitteeName],[Board],[IncorporationDate],[StatusId],[IsDelete],
	[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'C01', 'Board of Directors',1, GETDATE(), 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'C02', 'Audit Committee',0, GETDATE(), 1, 0, GETDATE(), 1, GETDATE(), 1;

	---------------------------------------------------------------------------
	-- 5. Who reset the database (by user 1: the acting user no longer exists)
	---------------------------------------------------------------------------
	INSERT INTO [Audit_Trail_Master]
	   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
	VALUES
		('UP', 'Database', 'Database', CAST(LEFT(DB_NAME(), 23) AS VARCHAR(23)), 'Reset', '',
		 'Reset by ' + ISNULL(@ActingLogin, ''), 1, GETDATE());

	COMMIT TRANSACTION;
	SET @Result = 1;
	END TRY
	BEGIN CATCH
		IF (XACT_STATE() <> 0)
			ROLLBACK TRANSACTION;

		-- Put every counter back: a counter that was used gets its saved value; one that was never used and
		-- is used now goes back to its seed (the same rule as BMMS-Test-ResetDatabase.sql)
		DECLARE IdentCursor CURSOR LOCAL FAST_FORWARD FOR
			SELECT TableName, SavedValue, SeedValue, IncrementValue FROM @Ident;

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
				-- Best effort: a counter that cannot be set back must not hide the error that is re-raised below
				BEGIN TRY
					EXEC sp_executesql @Sql;
				END TRY
				BEGIN CATCH
				END CATCH
			END

			FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;
		END

		CLOSE IdentCursor;
		DEALLOCATE IdentCursor;

		THROW;
	END CATCH
END

SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- Back-fill (M9): only while the log is empty (the first install)
-------------------------------------------------------------------------------
-- From the step 39 history: every call that opened or closed history rows of a user, grouped by the user and the
-- time stamp of the call (the procedures write one time, @Now, to CreatedOn and ClosedOn), other than the first
-- migration of step 39 (the earliest CreatedOn of each table, and the rows it closed at that time for the inactive
-- users: the starting state). A call that closed rows with
-- CloseReason 'D' is a Deactivate (UD); one that opened a role row of a user with earlier rows and closed none an
-- Activate (UV); one that opened the first role row of a user a new user (UA); otherwise a role row closed and one
-- opened is a role change (RC), a home row closed and another opened a home department change (HC), a department
-- opened (not home) and not closed in the same call added (DA), one closed (not home) and not opened removed (DR).
-- ChangedBy is the person who wrote the history row. The Reporting Person and the department status have no history:
-- none is back-filled. From Audit_Trail_Master: the changes of DeptNoManagerAction and AgendaControllerBypass (ST).
-- Source 'History' or 'AuditTrail'.
IF NOT EXISTS (SELECT 1 FROM dbo.Governance_Change_Log)
BEGIN
    DECLARE @BaseRole DATETIME;
    DECLARE @BaseDept DATETIME;
    SET @BaseRole = (SELECT MIN(CreatedOn) FROM dbo.User_Role);
    SET @BaseDept = (SELECT MIN(CreatedOn) FROM dbo.User_Department);
    DECLARE @Ev TABLE (UserId INT NOT NULL, Stamp DATETIME NOT NULL, ByUser INT NULL, Kind CHAR(2) NULL,
                       PRIMARY KEY (UserId, Stamp));

    INSERT INTO @Ev (UserId, Stamp, ByUser)
    SELECT x.UserId, x.Stamp, MAX(x.ByUser)
    FROM (SELECT UserId, CreatedOn AS Stamp, CreatedBy AS ByUser FROM dbo.User_Role WHERE CreatedOn <> @BaseRole
          UNION ALL SELECT UserId, ClosedOn, ClosedBy FROM dbo.User_Role WHERE ClosedOn IS NOT NULL AND ClosedOn <> @BaseRole
          UNION ALL SELECT UserId, CreatedOn, CreatedBy FROM dbo.User_Department WHERE CreatedOn <> @BaseDept
          UNION ALL SELECT UserId, ClosedOn, ClosedBy FROM dbo.User_Department WHERE ClosedOn IS NOT NULL AND ClosedOn <> @BaseDept) x
    GROUP BY x.UserId, x.Stamp;

    UPDATE e SET Kind =
        CASE WHEN EXISTS (SELECT 1 FROM dbo.User_Role r WHERE r.UserId = e.UserId AND r.ClosedOn = e.Stamp AND r.CloseReason = 'D')
               OR EXISTS (SELECT 1 FROM dbo.User_Department d WHERE d.UserId = e.UserId AND d.ClosedOn = e.Stamp AND d.CloseReason = 'D')
                  THEN 'UD'
             WHEN EXISTS (SELECT 1 FROM dbo.User_Role r WHERE r.UserId = e.UserId AND r.CreatedOn = e.Stamp)
              AND NOT EXISTS (SELECT 1 FROM dbo.User_Role r WHERE r.UserId = e.UserId AND r.ClosedOn = e.Stamp)
              AND EXISTS (SELECT 1 FROM dbo.User_Role r WHERE r.UserId = e.UserId AND r.CreatedOn < e.Stamp)
                  THEN 'UV'
             WHEN EXISTS (SELECT 1 FROM dbo.User_Role r WHERE r.UserId = e.UserId AND r.CreatedOn = e.Stamp)
              AND NOT EXISTS (SELECT 1 FROM dbo.User_Role r WHERE r.UserId = e.UserId AND r.ClosedOn = e.Stamp)
                  THEN 'UA'
             ELSE 'CH' END
    FROM @Ev e;

    -- The rows in the order of the calls
    INSERT INTO dbo.Governance_Change_Log
    (ChangedOn, EffectiveOn, ChangedBy, ChangeType, UserId, UserLogin, UserName, DepartmentId, DepartmentName,
     SettingCode, OldId, NewId, OldValue, NewValue, Source)
    SELECT z.Stamp, CAST(z.Stamp AS DATE), (SELECT a.UserId FROM dbo.Users a WHERE a.UserId = z.ByUser), z.ChangeType,
           z.UserId, CAST(u.LoginName AS NVARCHAR(50)), CAST(u.UserName AS NVARCHAR(200)), z.DepartmentId,
           (SELECT CAST(d.DepartmentName AS NVARCHAR(200)) FROM dbo.Department d WHERE d.DepartmentId = z.DepartmentId),
           NULL, z.OldId, z.NewId, z.OldValue, z.NewValue, 'History'
    FROM (
        -- UA and UV: the role and the departments opened in the call
        SELECT e.UserId, e.Stamp, e.ByUser, e.Kind AS ChangeType, 1 AS Seq,
               (SELECT TOP 1 d.DepartmentId FROM dbo.User_Department d WHERE d.UserId = e.UserId AND d.CreatedOn = e.Stamp AND d.IsHome = 1) AS DepartmentId,
               CASE WHEN e.Kind = 'UV' THEN 0 ELSE NULL END AS OldId,
               CASE WHEN e.Kind = 'UV' THEN 1 ELSE (SELECT TOP 1 r.RoleId FROM dbo.User_Role r WHERE r.UserId = e.UserId AND r.CreatedOn = e.Stamp) END AS NewId,
               CASE WHEN e.Kind = 'UV' THEN N'Inactive' ELSE NULL END AS OldValue,
               CAST(ISNULL((SELECT TOP 1 CAST(ro.RoleName AS NVARCHAR(100)) FROM dbo.User_Role r JOIN dbo.Roles ro ON ro.RoleId = r.RoleId
                            WHERE r.UserId = e.UserId AND r.CreatedOn = e.Stamp), N'(no role)')
                    + N'; ' + ISNULL(STUFF((SELECT N', ' + CAST(dp.DepartmentName AS NVARCHAR(200)) + CASE WHEN d.IsHome = 1 THEN N' (home)' ELSE N'' END
                                            FROM dbo.User_Department d JOIN dbo.Department dp ON dp.DepartmentId = d.DepartmentId
                                            WHERE d.UserId = e.UserId AND d.CreatedOn = e.Stamp
                                            ORDER BY d.IsHome DESC, dp.DepartmentName
                                            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(800)'), 1, 2, N''), N'(no department)') AS NVARCHAR(1000)) AS NewValue
        FROM @Ev e WHERE e.Kind IN ('UA', 'UV')
        UNION ALL
        -- UD: the role and the departments closed in the call
        SELECT e.UserId, e.Stamp, e.ByUser, 'UD', 1,
               (SELECT TOP 1 d.DepartmentId FROM dbo.User_Department d WHERE d.UserId = e.UserId AND d.ClosedOn = e.Stamp AND d.IsHome = 1),
               1, 0,
               CAST(ISNULL((SELECT TOP 1 CAST(ro.RoleName AS NVARCHAR(100)) FROM dbo.User_Role r JOIN dbo.Roles ro ON ro.RoleId = r.RoleId
                            WHERE r.UserId = e.UserId AND r.ClosedOn = e.Stamp), N'(no role)')
                    + N'; ' + ISNULL(STUFF((SELECT N', ' + CAST(dp.DepartmentName AS NVARCHAR(200)) + CASE WHEN d.IsHome = 1 THEN N' (home)' ELSE N'' END
                                            FROM dbo.User_Department d JOIN dbo.Department dp ON dp.DepartmentId = d.DepartmentId
                                            WHERE d.UserId = e.UserId AND d.ClosedOn = e.Stamp
                                            ORDER BY d.IsHome DESC, dp.DepartmentName
                                            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(800)'), 1, 2, N''), N'(no department)') AS NVARCHAR(1000)),
               N'Inactive'
        FROM @Ev e WHERE e.Kind = 'UD'
        UNION ALL
        -- RC: a role row closed and another opened in the call
        SELECT e.UserId, e.Stamp, e.ByUser, 'RC', 1, NULL, rc.RoleId, ro2.RoleId,
               CAST(rn1.RoleName AS NVARCHAR(1000)), CAST(rn2.RoleName AS NVARCHAR(1000))
        FROM @Ev e
        INNER JOIN dbo.User_Role rc ON rc.UserId = e.UserId AND rc.ClosedOn = e.Stamp
        INNER JOIN dbo.User_Role ro2 ON ro2.UserId = e.UserId AND ro2.CreatedOn = e.Stamp
        INNER JOIN dbo.Roles rn1 ON rn1.RoleId = rc.RoleId
        INNER JOIN dbo.Roles rn2 ON rn2.RoleId = ro2.RoleId
        WHERE e.Kind = 'CH' AND rc.RoleId <> ro2.RoleId
        UNION ALL
        -- HC: a home row closed and a home row of another department opened in the call
        SELECT e.UserId, e.Stamp, e.ByUser, 'HC', 2, hn.DepartmentId, hc.DepartmentId, hn.DepartmentId,
               (SELECT CAST(dp.DepartmentName AS NVARCHAR(1000)) FROM dbo.Department dp WHERE dp.DepartmentId = hc.DepartmentId),
               (SELECT CAST(dp.DepartmentName AS NVARCHAR(1000)) FROM dbo.Department dp WHERE dp.DepartmentId = hn.DepartmentId)
        FROM @Ev e
        INNER JOIN dbo.User_Department hc ON hc.UserId = e.UserId AND hc.ClosedOn = e.Stamp AND hc.IsHome = 1
        INNER JOIN dbo.User_Department hn ON hn.UserId = e.UserId AND hn.CreatedOn = e.Stamp AND hn.IsHome = 1
        WHERE e.Kind = 'CH' AND hc.DepartmentId <> hn.DepartmentId
        UNION ALL
        -- DA: a department opened (not home), not closed in the same call
        SELECT e.UserId, e.Stamp, e.ByUser, 'DA', 3, a.DepartmentId, NULL, a.DepartmentId, NULL,
               (SELECT CAST(dp.DepartmentName AS NVARCHAR(1000)) FROM dbo.Department dp WHERE dp.DepartmentId = a.DepartmentId)
        FROM @Ev e
        INNER JOIN dbo.User_Department a ON a.UserId = e.UserId AND a.CreatedOn = e.Stamp AND a.IsHome = 0
        WHERE e.Kind = 'CH'
          AND NOT EXISTS (SELECT 1 FROM dbo.User_Department c WHERE c.UserId = e.UserId AND c.ClosedOn = e.Stamp AND c.DepartmentId = a.DepartmentId)
        UNION ALL
        -- DR: a department closed (not home), not opened again in the same call
        SELECT e.UserId, e.Stamp, e.ByUser, 'DR', 4, c.DepartmentId, c.DepartmentId, NULL,
               (SELECT CAST(dp.DepartmentName AS NVARCHAR(1000)) FROM dbo.Department dp WHERE dp.DepartmentId = c.DepartmentId), NULL
        FROM @Ev e
        INNER JOIN dbo.User_Department c ON c.UserId = e.UserId AND c.ClosedOn = e.Stamp AND c.IsHome = 0
        WHERE e.Kind = 'CH'
          AND NOT EXISTS (SELECT 1 FROM dbo.User_Department a WHERE a.UserId = e.UserId AND a.CreatedOn = e.Stamp AND a.DepartmentId = c.DepartmentId)
    ) z
    LEFT JOIN dbo.Users u ON u.UserId = z.UserId
    ORDER BY z.Stamp, z.UserId, z.Seq, z.DepartmentId;

    -- The settings, from Audit_Trail_Master
    INSERT INTO dbo.Governance_Change_Log
    (ChangedOn, EffectiveOn, ChangedBy, ChangeType, UserId, UserLogin, UserName, DepartmentId, DepartmentName,
     SettingCode, OldId, NewId, OldValue, NewValue, Source)
    SELECT a.Update_On, CAST(a.Update_On AS DATE), (SELECT x.UserId FROM dbo.Users x WHERE x.UserId = a.Update_By), 'ST',
           NULL, NULL, NULL, NULL, NULL, a.Key_Value, NULL, NULL, LEFT(a.Old_Value, 1000), LEFT(a.New_Value, 1000), 'AuditTrail'
    FROM dbo.Audit_Trail_Master a
    WHERE a.Audit_Type = 'UP' AND a.Audit_Table = 'App_Setting' AND a.Key_Field = 'SettingCode' AND a.Field_Name = 'SettingValue'
      AND a.Key_Value IN ('DeptNoManagerAction', 'AgendaControllerBypass') AND a.Update_On IS NOT NULL
    ORDER BY a.Update_On, a.Audit_Trail_Maser_Id;

    DECLARE @FromHistory INT;
    DECLARE @FromAudit INT;
    DECLARE @ByType VARCHAR(400);
    SET @FromHistory = (SELECT COUNT(*) FROM dbo.Governance_Change_Log WHERE Source = 'History');
    SET @FromAudit = (SELECT COUNT(*) FROM dbo.Governance_Change_Log WHERE Source = 'AuditTrail');
    SET @ByType = ISNULL(STUFF((SELECT ', ' + g.ChangeType + ' ' + CAST(COUNT(*) AS VARCHAR(12))
                                FROM dbo.Governance_Change_Log g GROUP BY g.ChangeType ORDER BY g.ChangeType
                                FOR XML PATH('')), 1, 2, ''), 'none');
    PRINT 'Back-fill: ' + CAST(@FromHistory AS VARCHAR(12)) + ' rows from the history (step 39), '
          + CAST(@FromAudit AS VARCHAR(12)) + ' rows from the audit trail (settings).';
    PRINT 'Back-fill by change type: ' + @ByType + '.';
END
ELSE
    PRINT 'Back-fill: skipped (the log already has rows; it runs only at the first install).';
GO

-------------------------------------------------------------------------------
-- Result
-------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM (VALUES ('fn_GovernanceHistoryStart'), ('fn_UserRoleOn'), ('fn_UserDepartmentsOn'), ('fn_DepartmentManagersOn'),
                                 ('fn_ReportingPersonOn'), ('fn_SettingOn'), ('fn_DepartmentActiveOn'), ('fn_GovernanceRoleHolders'),
                                 ('fn_GovernanceMatrixPeople'), ('fn_GovernanceRefusal'), ('fn_GovernanceDeptList'), ('fn_GovernanceUserSummary'),
                                 ('spr_WriteGovernanceChange'), ('spr_WriteGovernanceUserChanges'), ('spr_GetGovernanceMatrix'),
                                 ('spr_GetGovernanceSettings'), ('spr_GetGovernanceDepartments'), ('spr_GetGovernanceChangeLog'),
                                 ('spr_GetGovernanceLogUsers'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId'), ('spr_DeleteUserByUserId'),
                                 ('spr_AddEditDepartment'), ('spr_SetDepartmentManagerRule'), ('spr_SetAppSetting'), ('spr_sys_ResetDatabase')) o(Name)
           WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') NOT LIKE '%GovernanceLog-Step56%')
   OR OBJECT_ID('dbo.FK_Governance_Change_Log_ChangedBy', 'F') IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.App_Setting WHERE SettingCode = 'GovernanceLogFrom')
    RAISERROR('Step 56 is NOT completely installed: an object is missing. Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 56 installed: 26 objects carry GovernanceLog-Step56; the table, its key and the setting row are there.';
GO

SET NOEXEC OFF;
GO
