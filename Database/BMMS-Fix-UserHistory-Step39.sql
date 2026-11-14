/* ============================================================================
   BMMS - Role and department history; several departments for a Manager
   (step 39, step UD1a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Data only (step UD1a). Approval, alerts, mails, lists, reports and the
   Dashboard behave exactly as before; UD1b (approval and alerts) and UD1c
   (lists and reports) will read the new tables. Users keeps the current
   RoleId and DepartmentId, so nothing that reads Users changes.

   Rules (requirement UD1, rules 1, 9, 11 and 12; Consultant, 2026-11-09)
     1. Only a Manager can have several departments. Users, Controllers,
        Admins and the other roles keep one.
     9. The home department (Users.DepartmentId) is one of the Manager's
        departments and is marked primary (User_Department.IsHome = 1).
    11. History from the start, for every user:
          User_Role        UserId, RoleId
          User_Department  UserId, DepartmentId, IsHome
        each with EffectiveFrom (required), EffectiveTo (NULL = current),
        CreatedOn / CreatedBy and ClosedOn / ClosedBy / CloseReason
        (C changed, D deactivated, R role changed away from Manager). A row
        covers EffectiveFrom up to, not including, EffectiveTo: a row closed
        today and the row opened today in its place do not overlap.
          Add         opens one role row and one row per department.
          Edit        closes the old row and opens a new one when the role or
                      a department changes (a change of the home department
                      closes and reopens the rows whose IsHome changes).
          Deactivate  closes every open row (D).
          Activate    opens the role row again and the departments closed by
                      the last deactivation; a department that is inactive
                      now is skipped and named (ReasonDetail
                      'NotRestored:<names>'); an inactive home department
                      refuses the activation (Reason 23,
                      'HomeDepartmentInactive:<name>').
          Delete      only when nothing refers to the user (Reasons 5, 6 as
                      before); the user's own rows go with an otherwise
                      unused user; rows the user wrote for others
                      (CreatedBy / ClosedBy) are history: Reason 6, group
                      "user changes".
          Reset Database seeds one open row per seed user in each table.
    12. A role change away from Manager closes the Manager's other
        departments (end date today, R); the home department stays. It is
        refused (Reason 24) when he is the last active Manager of one of his
        departments that has open items waiting for a Manager, or when items
        waiting at AC are routed to him personally (he has the item's alert or
        is the creator's manager). An Edit that removes a department checks
        the department only. No check on Deactivate in UD1a.
     E. A department cannot be deleted while a user has an open mapping to it
        (Reason 25, ReasonDetail 'Mapped:<names>'), nor when only closed
        mappings exist (Reason 25, 'History': make it inactive instead).
     6. Setting DeptNoManagerAction (App_Setting): what a later step does when
        a department has no active Manager: refuse (default) or controller.
        Stored only; nothing reads it in UD1a. Only an active Admin changes it
        (spr_SetDepartmentManagerRule); a change is written to
        Audit_Trail_Master (Audit_Table 'App_Setting'), as every setting.

   "Open items waiting for a Manager": Agenda.AgendaStatusCode 'AC' on a
   meeting whose agenda is open (Meeting.AgendaStatus 'Open' or NULL), for the
   department Agenda.DepartmentId.

   Reasons (one row Result, Reason, ReasonDetail, as before)
     23  the departments are not valid. ReasonDetail: ListNotValid,
         DepartmentNotFound, DepartmentInactive, OneDepartmentOnly,
         HomeNotTicked, HomeDepartmentInactive:<name>
     24  last active Manager / items routed to him. ReasonDetail: the text,
         for example "last active Manager of HRD (2 items waiting); 1 item
         waiting for their own approval"
     25  department delete: still mapped, or used in the history

   Objects (each carries the text UserHistory-Step39)
     User_Role, User_Department     NEW tables, with filtered unique indexes:
                                    one open role row per user, one open row
                                    per user and department, one open home
                                    department per user
     App_Setting DeptNoManagerAction NEW ROW, 'refuse' (only when missing)
     fn_ManagerReleaseRefusal       NEW, the rule 12 check
     spr_AddEditUser                REPLACED (step 13). New optional last
                                    parameter @DepartmentIds VARCHAR(MAX)
                                    (a comma list of DepartmentIds; NULL = not
                                    passed: a new user gets the home department,
                                    an edit keeps the mappings and adds the home
                                    department). Keeps UserProtection-Stage1.
     spr_SetUserStatusByUserId      REPLACED (step 13). Keeps Stage1.
     spr_DeleteUserByUserId         REPLACED (step 13; earlier 2, 6, 10).
                                    Five parameters, as before. Keeps
                                    FK#5-UserDelete-AllColumns and Stage1.
     spr_DeleteDepartmentByDeptId   REPLACED (step 2). Adds Reason and
                                    ReasonDetail after Result.
     spr_sys_ResetDatabase          REPLACED (step 30; earlier 3, 18, 21, 29).
                                    Keeps their texts and its 4 parameters.
     spr_GetUserDepartmentMap       NEW, the open mappings (User Master)
     spr_SetDepartmentManagerRule   NEW, the rule 6 setting

   Data. On the first run every user gets rows dated today (the install
   date): an active user one open role row and one open home department row;
   an inactive user one closed row in each table (From = To = today, D), so
   Activate works. A later run (also after the rollback) re-syncs: an open row
   that no longer agrees with Users is closed (C), an inactive user's open
   rows are closed (D), and a missing row is opened. It prints the counts.
   Rows are written as the protected system account (Users.IsSystem = 1).

   Order: installed after step 38. Needs steps 13, 14, 18 and 30 (and the
   App_Setting table of step 16) and stops otherwise. Re-running step 2, 3,
   6, 10, 13, 18, 21, 29 or 30 after this step brings back an older procedure:
   step 39 reads Partly; run step 39 again. Steps 14, 16, 17, 20, 31, 33 and
   35 to 38 contain none of its objects.

   Safe to re-run. BMMS-Rollback-UserHistory-Step39.sql restores the older
   procedures and keeps both tables, their rows and the setting row.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.

   QUOTED_IDENTIFIER and ANSI_NULLS must be ON (the filtered indexes need them
   for every procedure that writes the tables): the script sets them. From the
   command line use sqlcmd -I; SSMS already does this.
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
DECLARE @SystemAccounts INT = 0;
DECLARE @BadUsers INT = 0;

IF (@CurrentDatabase LIKE 'BMMS%' AND COL_LENGTH('dbo.Users', 'IsSystem') IS NOT NULL)
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.Users WHERE IsSystem = 1', N'@n INT OUTPUT', @n = @SystemAccounts OUTPUT;

IF (@CurrentDatabase LIKE 'BMMS%' AND OBJECT_ID('dbo.Users', 'U') IS NOT NULL AND OBJECT_ID('dbo.Department', 'U') IS NOT NULL
    AND OBJECT_ID('dbo.Roles', 'U') IS NOT NULL)
    SET @BadUsers = (SELECT COUNT(*) FROM dbo.Users u
                     WHERE NOT EXISTS (SELECT 1 FROM dbo.Department d WHERE d.DepartmentId = u.DepartmentId)
                        OR NOT EXISTS (SELECT 1 FROM dbo.Roles r WHERE r.RoleId = u.RoleId));

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%UserProtection-Stage1%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetUserStatusByUserId')), '') NOT LIKE '%UserProtection-Stage1%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') NOT LIKE '%UserProtection-Stage1%')
BEGIN
    RAISERROR('Step 13 (BMMS-Fix-UserProtection-Stage1.sql) is not installed in "%s" (or step 2, 6 or 10 was re-run after it). Run it first, then steps 14 and 18, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (COL_LENGTH('dbo.Users', 'IsSystem') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%SystemAccount3-Step18%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%UserStatus-Stage2a%')
BEGIN
    RAISERROR('Steps 14 and 18 (BMMS-Fix-UserStatus-Stage2a.sql, BMMS-Fix-SystemAccount-Stage3.sql) are not installed in "%s". Run them first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '') NOT LIKE '%SmtpDefault-Step30%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '') NOT LIKE '%ResetSafe-Step29%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '') NOT LIKE '%MemberTypes-Step21%'
         OR OBJECT_ID('dbo.spr_sys_SetSmtpDefault', 'P') IS NULL)
BEGIN
    RAISERROR('Step 30 (BMMS-Fix-SmtpDefault-Step30.sql) is not installed in "%s" (or step 3, 18, 21 or 29 was re-run after it). Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.App_Setting', 'U') IS NULL OR OBJECT_ID('dbo.Audit_Trail_Master', 'U') IS NULL)
BEGIN
    RAISERROR('Table App_Setting (step 16) or Audit_Trail_Master is missing in "%s". Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@SystemAccounts <> 1)
BEGIN
    RAISERROR('%d users in "%s" are flagged IsSystem = 1; exactly one is needed (see the README, step 18). Nothing was changed.', 16, 1, @SystemAccounts, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@BadUsers > 0)
BEGIN
    RAISERROR('%d users in "%s" have a DepartmentId or RoleId that is not in Department or Roles; their history rows cannot be written. Correct them first. Nothing was changed.', 16, 1, @BadUsers, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF ((OBJECT_ID('dbo.User_Role', 'U') IS NOT NULL AND COL_LENGTH('dbo.User_Role', 'CloseReason') IS NULL)
         OR (OBJECT_ID('dbo.User_Department', 'U') IS NOT NULL AND COL_LENGTH('dbo.User_Department', 'IsHome') IS NULL))
BEGIN
    RAISERROR('A table User_Role or User_Department exists in "%s" but is not the step 39 table. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- Tables (UserHistory-Step39). A re-run keeps them and their rows.
-------------------------------------------------------------------------------
IF (OBJECT_ID('dbo.User_Role', 'U') IS NULL)
BEGIN
    CREATE TABLE dbo.User_Role
    (
    UserRoleId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_User_Role PRIMARY KEY,
    UserId INT NOT NULL CONSTRAINT FK_User_Role_Users REFERENCES dbo.Users (UserId),
    RoleId INT NOT NULL CONSTRAINT FK_User_Role_Roles REFERENCES dbo.Roles (RoleId),
    EffectiveFrom DATE NOT NULL,
    EffectiveTo DATE NULL,
    CreatedOn DATETIME NOT NULL CONSTRAINT DF_User_Role_CreatedOn DEFAULT GETDATE(),
    CreatedBy INT NOT NULL CONSTRAINT FK_User_Role_CreatedBy REFERENCES dbo.Users (UserId),
    ClosedOn DATETIME NULL,
    ClosedBy INT NULL CONSTRAINT FK_User_Role_ClosedBy REFERENCES dbo.Users (UserId),
    CloseReason CHAR(1) NULL,
    CONSTRAINT CK_User_Role_Dates CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
    CONSTRAINT CK_User_Role_Closed CHECK ((EffectiveTo IS NULL AND ClosedOn IS NULL AND ClosedBy IS NULL AND CloseReason IS NULL)
                                       OR (EffectiveTo IS NOT NULL AND ClosedOn IS NOT NULL AND ClosedBy IS NOT NULL AND CloseReason IN ('C', 'D', 'R')))
    );
    PRINT 'Table User_Role created.';
END
GO

IF (OBJECT_ID('dbo.User_Department', 'U') IS NULL)
BEGIN
    CREATE TABLE dbo.User_Department
    (
    UserDepartmentId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_User_Department PRIMARY KEY,
    UserId INT NOT NULL CONSTRAINT FK_User_Department_Users REFERENCES dbo.Users (UserId),
    DepartmentId INT NOT NULL CONSTRAINT FK_User_Department_Department REFERENCES dbo.Department (DepartmentId),
    IsHome BIT NOT NULL CONSTRAINT DF_User_Department_IsHome DEFAULT 0,
    EffectiveFrom DATE NOT NULL,
    EffectiveTo DATE NULL,
    CreatedOn DATETIME NOT NULL CONSTRAINT DF_User_Department_CreatedOn DEFAULT GETDATE(),
    CreatedBy INT NOT NULL CONSTRAINT FK_User_Department_CreatedBy REFERENCES dbo.Users (UserId),
    ClosedOn DATETIME NULL,
    ClosedBy INT NULL CONSTRAINT FK_User_Department_ClosedBy REFERENCES dbo.Users (UserId),
    CloseReason CHAR(1) NULL,
    CONSTRAINT CK_User_Department_Dates CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom),
    CONSTRAINT CK_User_Department_Closed CHECK ((EffectiveTo IS NULL AND ClosedOn IS NULL AND ClosedBy IS NULL AND CloseReason IS NULL)
                                             OR (EffectiveTo IS NOT NULL AND ClosedOn IS NOT NULL AND ClosedBy IS NOT NULL AND CloseReason IN ('C', 'D', 'R')))
    );
    PRINT 'Table User_Department created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.User_Role') AND name = 'UX_User_Role_Open')
    CREATE UNIQUE NONCLUSTERED INDEX UX_User_Role_Open ON dbo.User_Role (UserId) WHERE EffectiveTo IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.User_Role') AND name = 'IX_User_Role_UserId')
    CREATE NONCLUSTERED INDEX IX_User_Role_UserId ON dbo.User_Role (UserId, EffectiveFrom);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.User_Department') AND name = 'UX_User_Department_Open')
    CREATE UNIQUE NONCLUSTERED INDEX UX_User_Department_Open ON dbo.User_Department (UserId, DepartmentId) WHERE EffectiveTo IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.User_Department') AND name = 'UX_User_Department_OpenHome')
    CREATE UNIQUE NONCLUSTERED INDEX UX_User_Department_OpenHome ON dbo.User_Department (UserId) WHERE EffectiveTo IS NULL AND IsHome = 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.User_Department') AND name = 'IX_User_Department_UserId')
    CREATE NONCLUSTERED INDEX IX_User_Department_UserId ON dbo.User_Department (UserId, EffectiveFrom);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.User_Department') AND name = 'IX_User_Department_Department')
    CREATE NONCLUSTERED INDEX IX_User_Department_Department ON dbo.User_Department (DepartmentId, EffectiveTo);
GO

-------------------------------------------------------------------------------
-- The rule 6 setting (UserHistory-Step39): stored only, nothing reads it yet
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.App_Setting WHERE SettingCode = 'DeptNoManagerAction')
BEGIN
    INSERT INTO dbo.App_Setting (SettingCode, SettingValue, Description)
    VALUES ('DeptNoManagerAction', 'refuse', 'When a department has no active Manager: refuse the item (refuse, default) or send it to the Controllers (controller). Stored now, used from a later step (step 39)');
    PRINT 'App_Setting DeptNoManagerAction added: "refuse".';
END
ELSE
BEGIN
    DECLARE @Kept VARCHAR(250) = (SELECT SettingValue FROM dbo.App_Setting WHERE SettingCode = 'DeptNoManagerAction');
    PRINT 'App_Setting DeptNoManagerAction kept: "' + @Kept + '".';
END
GO

-------------------------------------------------------------------------------
-- Migration and re-sync (UserHistory-Step39). Rows dated today (the install
-- date), written by the protected system account. One transaction.
-------------------------------------------------------------------------------
SET XACT_ABORT ON;

DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Now DATETIME = GETDATE();
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM dbo.Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @ManagerRoleId INT = (SELECT TOP 1 RoleId FROM dbo.Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @RoleClosedChanged INT, @RoleClosedInactive INT, @RoleOpened INT, @RoleClosedNew INT;
DECLARE @DeptClosedChanged INT, @DeptClosedInactive INT, @DeptOpened INT, @DeptClosedNew INT;
DECLARE @UsersAll INT, @UsersActive INT, @RoleOpen INT, @HomeOpen INT, @DeptOpen INT, @RoleRows INT, @DeptRows INT;
DECLARE @Msg VARCHAR(400);

BEGIN TRANSACTION;

-- Role rows
UPDATE r SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @Sys, CloseReason = 'C'
FROM dbo.User_Role r JOIN dbo.Users u ON u.UserId = r.UserId
WHERE r.EffectiveTo IS NULL AND u.AccountStatus = 1 AND r.RoleId <> u.RoleId;
SET @RoleClosedChanged = @@ROWCOUNT;

UPDATE r SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @Sys, CloseReason = 'D'
FROM dbo.User_Role r JOIN dbo.Users u ON u.UserId = r.UserId
WHERE r.EffectiveTo IS NULL AND u.AccountStatus <> 1;
SET @RoleClosedInactive = @@ROWCOUNT;

INSERT INTO dbo.User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
SELECT u.UserId, u.RoleId, @Today, @Now, @Sys
FROM dbo.Users u
WHERE u.AccountStatus = 1
  AND NOT EXISTS (SELECT 1 FROM dbo.User_Role r WHERE r.UserId = u.UserId AND r.EffectiveTo IS NULL);
SET @RoleOpened = @@ROWCOUNT;

-- An inactive user without any row: one closed row, so that Activate finds it
INSERT INTO dbo.User_Role (UserId, RoleId, EffectiveFrom, EffectiveTo, CreatedOn, CreatedBy, ClosedOn, ClosedBy, CloseReason)
SELECT u.UserId, u.RoleId, @Today, @Today, @Now, @Sys, @Now, @Sys, 'D'
FROM dbo.Users u
WHERE u.AccountStatus <> 1
  AND NOT EXISTS (SELECT 1 FROM dbo.User_Role r WHERE r.UserId = u.UserId);
SET @RoleClosedNew = @@ROWCOUNT;

-- Department rows of active users that no longer agree with Users: a home row of another
-- department, a non-home row of the home department, or any other department of a user who
-- is not a Manager
UPDATE d SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @Sys, CloseReason = 'C'
FROM dbo.User_Department d JOIN dbo.Users u ON u.UserId = d.UserId
WHERE d.EffectiveTo IS NULL AND u.AccountStatus = 1
  AND ((d.IsHome = 1 AND d.DepartmentId <> u.DepartmentId)
    OR (d.IsHome = 0 AND d.DepartmentId = u.DepartmentId)
    OR (d.DepartmentId <> u.DepartmentId AND u.RoleId <> ISNULL(@ManagerRoleId, -1)));
SET @DeptClosedChanged = @@ROWCOUNT;

UPDATE d SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @Sys, CloseReason = 'D'
FROM dbo.User_Department d JOIN dbo.Users u ON u.UserId = d.UserId
WHERE d.EffectiveTo IS NULL AND u.AccountStatus <> 1;
SET @DeptClosedInactive = @@ROWCOUNT;

INSERT INTO dbo.User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
SELECT u.UserId, u.DepartmentId, 1, @Today, @Now, @Sys
FROM dbo.Users u
WHERE u.AccountStatus = 1
  AND NOT EXISTS (SELECT 1 FROM dbo.User_Department d WHERE d.UserId = u.UserId AND d.EffectiveTo IS NULL AND d.IsHome = 1);
SET @DeptOpened = @@ROWCOUNT;

INSERT INTO dbo.User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, CreatedOn, CreatedBy, ClosedOn, ClosedBy, CloseReason)
SELECT u.UserId, u.DepartmentId, 1, @Today, @Today, @Now, @Sys, @Now, @Sys, 'D'
FROM dbo.Users u
WHERE u.AccountStatus <> 1
  AND NOT EXISTS (SELECT 1 FROM dbo.User_Department d WHERE d.UserId = u.UserId);
SET @DeptClosedNew = @@ROWCOUNT;

COMMIT TRANSACTION;

SET @UsersAll = (SELECT COUNT(*) FROM dbo.Users);
SET @UsersActive = (SELECT COUNT(*) FROM dbo.Users WHERE AccountStatus = 1);
SET @RoleOpen = (SELECT COUNT(*) FROM dbo.User_Role WHERE EffectiveTo IS NULL);
SET @HomeOpen = (SELECT COUNT(*) FROM dbo.User_Department WHERE EffectiveTo IS NULL AND IsHome = 1);
SET @DeptOpen = (SELECT COUNT(*) FROM dbo.User_Department WHERE EffectiveTo IS NULL);
SET @RoleRows = (SELECT COUNT(*) FROM dbo.User_Role);
SET @DeptRows = (SELECT COUNT(*) FROM dbo.User_Department);

SET @Msg = 'User_Role: ' + CAST(@RoleOpened AS VARCHAR(12)) + ' opened, ' + CAST(@RoleClosedNew AS VARCHAR(12)) + ' closed rows added for inactive users, '
         + CAST(@RoleClosedChanged AS VARCHAR(12)) + ' closed (role changed), ' + CAST(@RoleClosedInactive AS VARCHAR(12)) + ' closed (user inactive).';
PRINT @Msg;
SET @Msg = 'User_Department: ' + CAST(@DeptOpened AS VARCHAR(12)) + ' opened, ' + CAST(@DeptClosedNew AS VARCHAR(12)) + ' closed rows added for inactive users, '
         + CAST(@DeptClosedChanged AS VARCHAR(12)) + ' closed (department changed), ' + CAST(@DeptClosedInactive AS VARCHAR(12)) + ' closed (user inactive).';
PRINT @Msg;
SET @Msg = 'Now: ' + CAST(@UsersAll AS VARCHAR(12)) + ' users, ' + CAST(@UsersActive AS VARCHAR(12)) + ' active; open role rows '
         + CAST(@RoleOpen AS VARCHAR(12)) + ', open home department rows ' + CAST(@HomeOpen AS VARCHAR(12)) + ', open department rows '
         + CAST(@DeptOpen AS VARCHAR(12)) + '; all rows ' + CAST(@RoleRows AS VARCHAR(12)) + ' and ' + CAST(@DeptRows AS VARCHAR(12)) + '.';
PRINT @Msg;
GO

SET XACT_ABORT OFF;
GO

-------------------------------------------------------------------------------
-- Rule 12 (UserHistory-Step39): what stops a Manager from leaving a department
-------------------------------------------------------------------------------
-- One row per finding, none when nothing stops it. Kind 'D': @UserId is the last active Manager
-- (open User_Department row, active, Manager role, not the system account) of a department with
-- open items waiting for a Manager (AC on a meeting whose agenda is open); Items = their count.
-- @DepartmentId NULL = every department of @UserId, otherwise that one. Kind 'P' (only when
-- @Personal = 1): items waiting at AC routed to @UserId himself (he has the item's alert, or he is
-- the creator's manager), as step 20 lets a Manager approve them. The caller locks first.
CREATE OR ALTER FUNCTION [dbo].[fn_ManagerReleaseRefusal]
(
@UserId INT,
@DepartmentId INT,
@Personal BIT
)
RETURNS TABLE
AS
RETURN
SELECT CAST('D' AS CHAR(1)) AS Kind, d.DepartmentId, CAST(d.DepartmentName AS NVARCHAR(200)) AS DepartmentName, COUNT(*) AS Items
FROM dbo.User_Department ud
JOIN dbo.Department d ON d.DepartmentId = ud.DepartmentId
JOIN dbo.Agenda a ON a.DepartmentId = ud.DepartmentId
JOIN dbo.Meeting mt ON mt.MeetingId = a.MeetingId
WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL
  AND (@DepartmentId IS NULL OR ud.DepartmentId = @DepartmentId)
  AND a.AgendaStatusCode = 'AC' AND ISNULL(mt.AgendaStatus, 'Open') = 'Open'
  AND NOT EXISTS (SELECT 1 FROM dbo.User_Department o
                  JOIN dbo.Users ou ON ou.UserId = o.UserId
                  JOIN dbo.Roles orl ON orl.RoleId = ou.RoleId
                  WHERE o.DepartmentId = ud.DepartmentId AND o.EffectiveTo IS NULL AND o.UserId <> @UserId
                    AND ou.AccountStatus = 1 AND ou.IsSystem = 0 AND orl.RoleCode = 'manager')
GROUP BY d.DepartmentId, d.DepartmentName
UNION ALL
SELECT CAST('P' AS CHAR(1)), CAST(NULL AS INT), CAST(N'' AS NVARCHAR(200)), COUNT(*)
FROM dbo.Agenda a
JOIN dbo.Meeting mt ON mt.MeetingId = a.MeetingId
LEFT JOIN dbo.Users c ON c.UserId = a.CreatedBy
WHERE @Personal = 1
  AND a.AgendaStatusCode = 'AC' AND ISNULL(mt.AgendaStatus, 'Open') = 'Open'
  AND (c.ManagerId = @UserId
       OR EXISTS (SELECT 1 FROM dbo.Alert_Master am JOIN dbo.Alert_User_Map aum ON aum.AlertId = am.AlertId
                  WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId AND aum.UserId = @UserId))
HAVING COUNT(*) > 0;
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
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
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
						SET @Detail = ISNULL(N'last active Manager of '
						              + STUFF((SELECT N', ' + r.DepartmentName + N' (' + CAST(r.Items AS NVARCHAR(12))
						                              + CASE WHEN r.Items = 1 THEN N' item waiting)' ELSE N' items waiting)' END
						                       FROM @Refusal r WHERE r.Kind = 'D' ORDER BY r.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');
						IF EXISTS (SELECT 1 FROM @Refusal WHERE Kind = 'P')
							SET @Detail = @Detail + CASE WHEN @Detail <> N'' THEN N'; ' ELSE N'' END
							            + CAST((SELECT TOP 1 Items FROM @Refusal WHERE Kind = 'P') AS NVARCHAR(12))
							            + CASE WHEN (SELECT TOP 1 Items FROM @Refusal WHERE Kind = 'P') = 1
							                   THEN N' item waiting for their own approval' ELSE N' items waiting for their own approval' END;
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
				END
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

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
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
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
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
				END

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
				END
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

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- Users - delete (UserHistory-Step39)
-------------------------------------------------------------------------------
-- Users - delete (FK #5, FK#5-UserDelete-AllColumns, UserProtection-Stage1)
-- UserHistory-Step39: rows the user wrote in another user's role or department history (CreatedBy /
-- ClosedBy) are history: Reason 6, group 'user changes'. The user's own User_Role and User_Department
-- rows go with an otherwise unused user.
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
					SET @Detail = @Detail + N', user changes';

				IF (@Detail <> N'')
				BEGIN
					SET @Detail = STUFF(@Detail, 1, 2, N'');
					SET @Reason = 6;
				END
			END

			IF (@Reason = 0)
			BEGIN
				-- Alerts received and action-item read flags go with the user.
				DELETE FROM Alert_User_Map WHERE UserId = @UserId;

				DELETE FROM ActionItem_User_Map WHERE UserId = @UserId;

				-- The user's own role and department history (UserHistory-Step39)
				DELETE FROM User_Department WHERE UserId = @UserId;

				DELETE FROM User_Role WHERE UserId = @UserId;

				DELETE FROM Users WHERE UserId = @UserId;

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
-- Department - delete, referenced by Agenda and Users (step 2); UserHistory-Step39: also refused
-- while a user has an open mapping to it (Reason 25, 'Mapped:<names>') or when only closed mappings
-- exist (Reason 25, 'History'). Result as before; Reason and ReasonDetail added after it
-- (Reason 5 = used by agenda items or users, as before).
-------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteDepartmentByDeptId]
@DeptId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @CountRec INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';

	SET @CountRec = (SELECT COUNT(*) FROM Agenda WHERE DepartmentId = @DeptId);

	IF (@CountRec <= 0)
	BEGIN
		SET @CountRec = (SELECT COUNT(*) FROM Users WHERE DepartmentId = @DeptId);

		IF (@CountRec <= 0)
		BEGIN
			SET @Result = 1;
		END
	END

	IF (@Result = 0)
		SET @Reason = 5;

	IF (@Result = 1 AND EXISTS (SELECT 1 FROM User_Department WHERE DepartmentId = @DeptId AND EffectiveTo IS NULL))
	BEGIN
		SET @Result = 0;
		SET @Reason = 25;
		SET @Detail = LEFT(N'Mapped:' + ISNULL(STUFF((SELECT N', ' + CAST(u.UserName AS NVARCHAR(100))
		                                               FROM User_Department ud JOIN Users u ON u.UserId = ud.UserId
		                                               WHERE ud.DepartmentId = @DeptId AND ud.EffectiveTo IS NULL
		                                               ORDER BY u.UserName
		                                               FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N''), 2000);
	END
	ELSE IF (@Result = 1 AND EXISTS (SELECT 1 FROM User_Department WHERE DepartmentId = @DeptId))
	BEGIN
		SET @Result = 0;
		SET @Reason = 25;
		SET @Detail = N'History';
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Department WHERE DepartmentId = @DeptId;
	END

	SELECT @Result AS Result, @Reason AS Reason, @Detail AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- Users - the open department mappings, for User Master (UserHistory-Step39)
-------------------------------------------------------------------------------
-- @UserId NULL = every user. One row per open mapping: the home department first (IsHome 1),
-- then by name; DepartmentActive 1 when the department is active.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetUserDepartmentMap]
@UserId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	SELECT ud.UserId, ud.DepartmentId, d.DepartmentName, CAST(ud.IsHome AS INT) AS IsHome,
	       CASE WHEN ISNULL(d.StatusId, 0) = 1 THEN 1 ELSE 0 END AS DepartmentActive
	FROM User_Department ud
	JOIN Department d ON d.DepartmentId = ud.DepartmentId
	WHERE ud.EffectiveTo IS NULL
	  AND (@UserId IS NULL OR ud.UserId = @UserId)
	ORDER BY ud.UserId, ud.IsHome DESC, d.DepartmentName;
END
GO

-------------------------------------------------------------------------------
-- Settings - DeptNoManagerAction, rule 6 (UserHistory-Step39); only an active Admin.
-------------------------------------------------------------------------------
-- Values 'refuse' (default) and 'controller'. Stored only: nothing reads it until a later step.
-- One row Result, Reason, ReasonDetail as spr_SetAppSetting: 8 acting user missing or inactive,
-- 4 not an Admin, 3 value not valid (ReasonDetail the value). A change writes one Audit_Trail_Master
-- row (Audit_Table 'App_Setting'); saving the same value writes none.
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
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'App_Setting', 'SettingCode', 'DeptNoManagerAction', 'SettingValue', ISNULL(@OldValue, ''), @SettingValue, @ActingUserId, GETDATE());

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
		                    'User_Role', 'User_Department');

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
-- What is installed now
-------------------------------------------------------------------------------
DECLARE @Markers INT = (SELECT COUNT(*) FROM (VALUES ('fn_ManagerReleaseRefusal'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId'),
                                                     ('spr_DeleteUserByUserId'), ('spr_DeleteDepartmentByDeptId'), ('spr_sys_ResetDatabase'),
                                                     ('spr_GetUserDepartmentMap'), ('spr_SetDepartmentManagerRule')) o(Name)
                        WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UserHistory-Step39%');
DECLARE @ResetDef NVARCHAR(MAX) = ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '');
DECLARE @Older INT = CASE WHEN @ResetDef LIKE '%FK#5-ManagerId-NULL%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%SystemAccount3-Step18%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%MemberTypes-Step21%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%ResetSafe-Step29%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%DefaultPassword-Step29%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%SmtpDefault-Step30%' THEN 1 ELSE 0 END
                   + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') LIKE '%UserProtection-Stage1%' THEN 1 ELSE 0 END
                   + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetUserStatusByUserId')), '') LIKE '%UserProtection-Stage1%' THEN 1 ELSE 0 END
                   + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') LIKE '%UserProtection-Stage1%' THEN 1 ELSE 0 END
                   + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')), '') LIKE '%FK#5-UserDelete-AllColumns%' THEN 1 ELSE 0 END;
DECLARE @DeleteParams INT = (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_DeleteUserByUserId'));
DECLARE @ResetParams INT = (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_sys_ResetDatabase'));
DECLARE @Tables INT = CASE WHEN OBJECT_ID('dbo.User_Role', 'U') IS NOT NULL THEN 1 ELSE 0 END
                    + CASE WHEN OBJECT_ID('dbo.User_Department', 'U') IS NOT NULL THEN 1 ELSE 0 END;
DECLARE @SettingRow INT = (SELECT COUNT(*) FROM dbo.App_Setting WHERE SettingCode = 'DeptNoManagerAction');
DECLARE @Text VARCHAR(400);

IF (@Markers = 8 AND @Older = 10 AND @DeleteParams = 5 AND @ResetParams = 4 AND @Tables = 2 AND @SettingRow = 1)
    PRINT 'Step 39 installed: User_Role, User_Department, the setting DeptNoManagerAction and 8 procedures (UserHistory-Step39); the texts of steps 3, 10, 13, 18, 21, 29 and 30 kept.';
ELSE
BEGIN
    SET @Text = 'Step 39 is not complete: markers ' + CAST(@Markers AS VARCHAR(2)) + ' of 8, older texts ' + CAST(@Older AS VARCHAR(2))
              + ' of 10, tables ' + CAST(@Tables AS VARCHAR(1)) + ' of 2, setting row ' + CAST(@SettingRow AS VARCHAR(1))
              + ', delete parameters ' + CAST(@DeleteParams AS VARCHAR(2)) + ' of 5, reset parameters ' + CAST(@ResetParams AS VARCHAR(2)) + ' of 4.';
    RAISERROR('%s Read the messages above and run the script again.', 16, 1, @Text);
END
GO

SET NOEXEC OFF;
GO
