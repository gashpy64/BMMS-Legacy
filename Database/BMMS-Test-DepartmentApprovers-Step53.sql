/* ============================================================================
   BMMS - Test of step 53 (any Manager of the item's department approves;
   step UD1b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 53
   is not installed.

   Run it in a NEW query window (it uses temporary objects of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS.

   Part 1 reads only: the marker DepartmentApprovers-Step53 in the 20
   objects and the markers of their earlier steps, the parameter counts, no
   feature above compatibility level 100 added (TRY_CONVERT, IIF, CONCAT,
   FORMAT, OFFSET, STRING_AGG), the new columns, checks and key, and the
   internal procedure refusing a direct call.

   Part 2, inside ONE transaction that is rolled back (made-up data ZZ53:
   department A with two active Managers, an inactive Manager and a Manager
   without history rows; department B without a Manager; department C with
   one Manager; Users of A whose Reporting Person is a Manager of A, a
   Manager of C, a Controller, nobody, an inactive Manager; a User of B and
   of C; an Admin and two Controllers; a committee and two meetings, one to
   come and one passed):
     R1  the Managers of a department and who may decide (inactive, no
         history rows, another department, the creator himself);
     R2  the route of every user; refuse and controller under each setting
         value; Reason 11 and Reason 15;
     R3, R8  the rows per route (none for an Admin or an inactive user);
         committee and meeting alerts without Admin rows;
     R4, R5  approve and reject mark the other Managers' rows 'H' with who
         and when; the second Manager gets Reason 14; Reason 28 after the
         meeting date; the Controller's reject at AC;
         marked rows stay closed: the Controller's edit and decision do not
         reopen them; the refresh skips rows of inactive users;
         the lists: Recent, Unread, All and the header count; Remove on a
         marked row;
     R6  the mail lists per branch;
     R7  the back-fill run twice (no duplicates);
     R9  refused when he is the only Manager (P, Q and D); allowed with 'N'
         rows (role change, Deactivate, removed mapping) and the Released
         detail;
     R10 a new mapping, a role changed back to Manager and Activate ('N'
         rows opened again, an 'H' row never).

   Afterwards: nothing of ZZ53 is left; Users, User_Role, User_Department,
   Agenda, Alert_User_Map and App_Setting are as before and every identity
   counter is put back.

   The Rollback is checked by running it (it compares the 18 texts it puts
   back with the texts step 53 was built from, SHA-1), then the Fix again.

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
ELSE IF (OBJECT_ID('dbo.fn_DepartmentManagers', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_AgendaWaitingFor')), '') NOT LIKE '%DepartmentApprovers-Step53%'
         OR COL_LENGTH('dbo.Alert_User_Map', 'HandledReason') IS NULL)
BEGIN
    RAISERROR('Step 53 (BMMS-Fix-DepartmentApprovers-Step53.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#ZZ53_Save') IS NOT NULL DROP PROCEDURE #ZZ53_Save;
IF OBJECT_ID('tempdb..#ZZ53_Edit') IS NOT NULL DROP PROCEDURE #ZZ53_Edit;
IF OBJECT_ID('tempdb..#ZZ53_Add') IS NOT NULL DROP PROCEDURE #ZZ53_Add;
IF OBJECT_ID('tempdb..#ZZ53_Rows') IS NOT NULL DROP PROCEDURE #ZZ53_Rows;
IF OBJECT_ID('tempdb..#ZZ53_Mails') IS NOT NULL DROP PROCEDURE #ZZ53_Mails;
IF OBJECT_ID('tempdb..#ZZ53_Backfill') IS NOT NULL DROP PROCEDURE #ZZ53_Backfill;
IF OBJECT_ID('tempdb..#ZZ53_Direct') IS NOT NULL DROP PROCEDURE #ZZ53_Direct;
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

-- Add a user through spr_AddEditUser, with a department list
CREATE PROCEDURE #ZZ53_Save
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

-- Edit a user through spr_AddEditUser: the stored values, with the role, home department and list given
CREATE PROCEDURE #ZZ53_Edit
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

-- A new item of a user through spr_AddEditAgenda (Save), as Agenda Entry calls it
CREATE PROCEDURE #ZZ53_Add
    @CreatedBy INT, @DepartmentId INT, @CommitteeId INT, @MeetingId INT, @ShortText NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @E NVARCHAR(10) = N'';
    DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);

    EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @CommitteeId, @MeetingId = @MeetingId,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = @ShortText, @AgendaType = 'Entry', @AgendaText = N'ZZ',
         @AgendaTextPath = @E, @ProposedResolution = N'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E,
         @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @CreatedBy, @UpdatedOn = @Now, @UpdatedBy = @CreatedBy,
         @SubjectNo = NULL, @ActingUserId = @CreatedBy;
END
GO

-- The rows of an item's alert as one text: "<login>:<R|U><H|N|->" sorted by login, removed rows (StatusId 0) with "x";
-- the made-up users only (the real Controllers get rows too)
CREATE PROCEDURE #ZZ53_Rows
    @AgendaId INT, @Text VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Text = ISNULL(STUFF((SELECT ' ' + u.LoginName + ':' + CASE WHEN ISNULL(m.ReadStatus, 0) = 1 THEN 'R' ELSE 'U' END
                                     + ISNULL(m.HandledReason, '-') + CASE WHEN m.StatusId = 0 THEN 'x' ELSE '' END
                              FROM Alert_User_Map m
                              JOIN Alert_Master am ON am.AlertId = m.AlertId
                              JOIN Users u ON u.UserId = m.UserId
                              WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgendaId AND u.LoginName LIKE 'zz53%'
                              ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), '-');
END
GO

-- The mail addresses of a result set of one column EmailId, as one sorted text (the test users' address is their login)
CREATE PROCEDURE #ZZ53_Mails
    @Kind VARCHAR(20), @UserId INT, @AgendaId INT, @DepartmentId INT, @Text VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @M TABLE (EmailId VARCHAR(200));
    IF (@Kind = 'Created')
    BEGIN
        DECLARE @C TABLE (Route CHAR(1), ManagerName NVARCHAR(200), ActiveControllers INT, EmailId VARCHAR(200),
                          DepartmentManagers INT, RouteNote CHAR(1), DepartmentName NVARCHAR(200));
        INSERT INTO @C EXEC spr_GetAgendaCreationMailId @UserId = @UserId, @DepartmentId = @DepartmentId;
        INSERT INTO @M SELECT EmailId FROM @C WHERE EmailId IS NOT NULL;
    END
    ELSE IF (@Kind = 'Update')
        INSERT INTO @M EXEC spr_GetAgendaUpdateMailId @AgendaId = @AgendaId, @ActingUserId = @UserId;
    ELSE
        INSERT INTO @M EXEC spr_GetAlertMailId @Code = @Kind, @UserId = @UserId, @AgendaId = @AgendaId;

    -- Only the made-up users (their address starts with zz53); the real Controllers are counted apart where needed
    SET @Text = ISNULL(STUFF((SELECT DISTINCT ' ' + EmailId FROM @M WHERE EmailId LIKE 'zz53%' ORDER BY ' ' + EmailId FOR XML PATH('')), 1, 1, ''), '-');
END
GO

-- R7: the back-fill as the Fix runs it (the internal procedure needs a calling procedure)
CREATE PROCEDURE #ZZ53_Backfill
    @Actor INT, @Added INT OUTPUT, @Reopened INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spr_SetManagerAlertRows @ActingUserId = @Actor, @Added = @Added OUTPUT, @Reopened = @Reopened OUTPUT;
END
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T
SELECT 'The 20 objects carry DepartmentApprovers-Step53', '20',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DepartmentManagers'), ('spr_SetManagerAlertRows'), ('fn_AgendaRoute'), ('fn_AgendaWaitingFor'),
                                          ('fn_ManagerReleaseRefusal'), ('fn_DashboardAlerts'), ('spr_GetDashboardAlerts'), ('spr_GetAlertCount'),
                                          ('spr_GetAlertMailId'), ('spr_GetAgendaUpdateMailId'), ('spr_GetAgendaCreationMailId'), ('spr_RerouteWaitingAgendas'),
                                          ('spr_AddEditCommittee'), ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'),
                                          ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId')) o(n)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%DepartmentApprovers-Step53%') AS VARCHAR(4));

INSERT INTO #T
SELECT 'The 18 replaced texts keep the markers of their earlier steps (one per text: 18 20 20 20 24 37 37 37 43 43 43 43 43 44 52 52 52 52)', '18',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_AddEditCommittee', 'SystemAccount3-Step18'), ('fn_AgendaRoute', 'AgendaRouting-Step20'),
                                          ('spr_GetAgendaCreationMailId', 'AgendaRouting-Step20'), ('spr_RerouteWaitingAgendas', 'AgendaRouting-Step20'),
                                          ('spr_AddEditMeeting', 'MeetingDates-Step24'), ('spr_AddEditAgenda', 'UpdateMail-Step37'),
                                          ('spr_AddEditAgendaByManager', 'UpdateMail-Step37'), ('spr_AddEditAgendaByController', 'UpdateMail-Step37'),
                                          ('fn_DashboardAlerts', 'DashboardAlerts-Step43'), ('spr_GetDashboardAlerts', 'DashboardAlerts-Step43'),
                                          ('spr_GetAlertCount', 'DashboardAlerts-Step43'), ('spr_GetAlertMailId', 'DashboardAlerts-Step43'),
                                          ('spr_GetAgendaUpdateMailId', 'DashboardAlerts-Step43'), ('fn_AgendaWaitingFor', 'AgendaWaitingFor-Step44'),
                                          ('fn_ManagerReleaseRefusal', 'ManagerRelease-Step52'), ('spr_AddEditUser', 'ManagerRelease-Step52'),
                                          ('spr_SetUserStatusByUserId', 'ManagerRelease-Step52'), ('spr_UpdateAgendaByAgendaId', 'ManagerRelease-Step52')) o(n, mk)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%' + o.mk + '%') AS VARCHAR(4));

INSERT INTO #T
SELECT 'Parameters: fn_DepartmentManagers 1, fn_AgendaRoute 2, fn_AgendaWaitingFor 2, fn_ManagerReleaseRefusal 3, spr_GetAgendaCreationMailId 2, spr_SetManagerAlertRows 8, spr_UpdateAgendaByAgendaId 8, spr_AddEditUser 17, spr_SetUserStatusByUserId 5',
       '1 2 2 3 2 8 8 17 5',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_DepartmentManagers') AND parameter_id > 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_AgendaRoute') AND parameter_id > 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_AgendaWaitingFor') AND parameter_id > 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_ManagerReleaseRefusal') AND parameter_id > 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetAgendaCreationMailId')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_SetManagerAlertRows')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditUser')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_SetUserStatusByUserId')) AS VARCHAR(4));

INSERT INTO #T
SELECT 'No feature above compatibility level 100 in the 20 texts (TRY_CONVERT, IIF, CONCAT, FORMAT, OFFSET, STRING_AGG)', '0',
       CAST((SELECT COUNT(*)
             FROM (VALUES ('fn_DepartmentManagers'), ('spr_SetManagerAlertRows'), ('fn_AgendaRoute'), ('fn_AgendaWaitingFor'),
                          ('fn_ManagerReleaseRefusal'), ('fn_DashboardAlerts'), ('spr_GetDashboardAlerts'), ('spr_GetAlertCount'),
                          ('spr_GetAlertMailId'), ('spr_GetAgendaUpdateMailId'), ('spr_GetAgendaCreationMailId'), ('spr_RerouteWaitingAgendas'),
                          ('spr_AddEditCommittee'), ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'),
                          ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId')) o(n)
             CROSS JOIN (VALUES ('%TRY_CONVERT%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('% OFFSET %'), ('%STRING_AGG%')) w(Pattern)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE w.Pattern) AS VARCHAR(4));

INSERT INTO #T
SELECT 'Columns: Alert_User_Map.HandledReason char(1), HandledBy int, HandledOn datetime, Agenda.RouteNote char(1), all NULL allowed',
       'char 1 1 | int 4 1 | datetime 8 1 | char 1 1',
       ISNULL((SELECT TYPE_NAME(c.user_type_id) + ' ' + CAST(c.max_length AS VARCHAR(4)) + ' ' + CAST(c.is_nullable AS VARCHAR(1)) FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.Alert_User_Map') AND c.name = 'HandledReason'), 'none') + ' | '
     + ISNULL((SELECT TYPE_NAME(c.user_type_id) + ' ' + CAST(c.max_length AS VARCHAR(4)) + ' ' + CAST(c.is_nullable AS VARCHAR(1)) FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.Alert_User_Map') AND c.name = 'HandledBy'), 'none') + ' | '
     + ISNULL((SELECT TYPE_NAME(c.user_type_id) + ' ' + CAST(c.max_length AS VARCHAR(4)) + ' ' + CAST(c.is_nullable AS VARCHAR(1)) FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.Alert_User_Map') AND c.name = 'HandledOn'), 'none') + ' | '
     + ISNULL((SELECT TYPE_NAME(c.user_type_id) + ' ' + CAST(c.max_length AS VARCHAR(4)) + ' ' + CAST(c.is_nullable AS VARCHAR(1)) FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.Agenda') AND c.name = 'RouteNote'), 'none');

INSERT INTO #T
SELECT 'Checks and key in place and trusted: CK_Alert_User_Map_HandledReason (H, N, M), CK_Alert_User_Map_Handled, CK_Agenda_RouteNote, FK_Alert_User_Map_HandledBy (to Users)',
       '3 1 1',
       CAST((SELECT COUNT(*) FROM sys.check_constraints WHERE name IN ('CK_Alert_User_Map_HandledReason', 'CK_Alert_User_Map_Handled', 'CK_Agenda_RouteNote')
             AND is_not_trusted = 0 AND is_disabled = 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.foreign_keys WHERE name = 'FK_Alert_User_Map_HandledBy' AND referenced_object_id = OBJECT_ID('dbo.Users')
             AND is_not_trusted = 0 AND is_disabled = 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.check_constraints WHERE name = 'CK_Alert_User_Map_HandledReason' AND definition LIKE '%''M''%') AS VARCHAR(4));
GO

-- The internal procedure called directly (nest level 1): refused, nothing changed
DECLARE @Msg NVARCHAR(400) = N'no error';
DECLARE @MapBefore INT = (SELECT COUNT(*) FROM Alert_User_Map);
BEGIN TRY
    EXEC dbo.spr_SetManagerAlertRows;
END TRY
BEGIN CATCH
    SET @Msg = ERROR_MESSAGE();
END CATCH
INSERT INTO #T
SELECT 'spr_SetManagerAlertRows called directly (not from another procedure): refused, no row written', 'refused 0',
       CASE WHEN @Msg LIKE 'spr_SetManagerAlertRows is called only by other BMMS procedures%' THEN 'refused' ELSE CAST(@Msg AS VARCHAR(200)) END + ' '
     + CAST((SELECT COUNT(*) FROM Alert_User_Map) - @MapBefore AS VARCHAR(12));
GO

-------------------------------------------------------------------------------
-- Part 2: the cases, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(300)) ELSE '' END));
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(400), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @L2 TABLE (RowNo INT, AlertUserId INT, AlertId INT, UserId INT, ReadStatus INT, SourceType VARCHAR(150), SourceTypeId INT,
                   DepartmentId INT, DepartmentName VARCHAR(200), AlertTypeCode VARCHAR(10), AlertTypeName VARCHAR(100), CommitteeId INT,
                   CommitteeCode VARCHAR(50), CommitteeName VARCHAR(100), DisplayText VARCHAR(200), CreatedOn DATETIME, EventOn DATETIME,
                   ActorUserId INT, ActorName VARCHAR(100), ActorLogin VARCHAR(100), HandledReason CHAR(1), HandledOn DATETIME,
                   HandledByName VARCHAR(100), HandledByLogin VARCHAR(100));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = CAST(CAST(GETDATE() AS DATE) AS DATETIME);
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @SettingBefore VARCHAR(250) = (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction');
DECLARE @Adm INT, @Ctl1 INT, @Ctl2 INT, @MA1 INT, @MA2 INT, @MAi INT, @MAn INT, @MC INT, @MX INT;
DECLARE @U1 INT, @U2 INT, @U3 INT, @U4 INT, @U5 INT, @UB INT, @UC INT;
DECLARE @DA INT, @DB INT, @DC INT, @Com INT, @MFut INT, @MPast INT;
DECLARE @iMove INT, @MS INT;
DECLARE @i1 INT, @i2 INT, @i3 INT, @i4 INT, @i5 INT, @iC INT, @iCtl INT, @iB INT, @iOwn INT, @iFill INT, @iH INT;
DECLARE @A1 INT, @A INT, @AU INT, @n INT, @n2 INT, @Added INT, @Reopened INT, @Res INT, @Rsn INT, @Tot INT, @Unr INT, @Pg INT;
DECLARE @S VARCHAR(400), @S2 VARCHAR(400), @E NVARCHAR(10) = N'', @L VARCHAR(MAX);
DECLARE @Off TABLE (UserId INT PRIMARY KEY);
DECLARE @UsersBefore VARCHAR(60), @UsersAfter VARCHAR(60), @HistBefore VARCHAR(100), @HistAfter VARCHAR(100);
DECLARE @AgendaBefore VARCHAR(60), @AgendaAfter VARCHAR(60), @MapBefore VARCHAR(60), @MapAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @Desig IS NULL OR @SubjectTypeId IS NULL OR @SettingBefore IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role (admin, controller, manager, user), a designation, a subject type or the setting DeptNoManagerAction is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

-- Rows outside the test, before
SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @HistBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistBefore = @HistBefore + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MgrApprovedStatus, ControllerApprovedStatus, RouteNote)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, UserId, ReadStatus, StatusId, HandledReason, HandledBy)), 0) AS VARCHAR(12)) FROM Alert_User_Map;

BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ53A', 'ZZ step 53 department A', 993, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ53B', 'ZZ step 53 department B', 994, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ53C', 'ZZ step 53 department C', 995, 1, @Now, @Sys);
    SET @DC = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ53 admin', @DA, @Desig, NULL, @rAdmin, 'zz53adm', 'zz53adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ53 controller one', @DA, @Desig, NULL, @rCtl, 'zz53ctl1', 'zz53ctl1', 'not-a-login', 1, @Now);
    SET @Ctl1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ53 controller two', @DA, @Desig, NULL, @rCtl, 'zz53ctl2', 'zz53ctl2', 'not-a-login', 1, @Now);
    SET @Ctl2 = SCOPE_IDENTITY();

    -- Managers of A: MA1 and MA2 (saved), MAi (saved, then made inactive), MAn (no history rows: inserted directly);
    -- MC the only Manager of C; MX of A only for now
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Save 'ZZ53 manager A one', 'zz53ma1', @rMgr, @DA, NULL, @L, @Adm;
    SET @MA1 = (SELECT UserId FROM Users WHERE LoginName = 'zz53ma1');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Save 'ZZ53 manager A two', 'zz53ma2', @rMgr, @DA, NULL, @L, @Adm;
    SET @MA2 = (SELECT UserId FROM Users WHERE LoginName = 'zz53ma2');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Save 'ZZ53 manager A inactive', 'zz53mai', @rMgr, @DA, NULL, @L, @Adm;
    SET @MAi = (SELECT UserId FROM Users WHERE LoginName = 'zz53mai');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Save 'ZZ53 manager X', 'zz53mx', @rMgr, @DA, NULL, @L, @Adm;
    SET @MX = (SELECT UserId FROM Users WHERE LoginName = 'zz53mx');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @MAi, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ53 manager A no rows', @DA, @Desig, NULL, @rMgr, 'zz53man', 'zz53man', 'not-a-login', 1, @Now);
    SET @MAn = SCOPE_IDENTITY();
    SET @L = CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Save 'ZZ53 manager C', 'zz53mc', @rMgr, @DC, NULL, @L, @Adm;
    SET @MC = (SELECT UserId FROM Users WHERE LoginName = 'zz53mc');

    -- Users: of A reporting to MA1 (U1), to MC (U2), to Controller one (U3), to nobody (U4), to the inactive MAi (U5); UB of B; UC of C
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    SELECT x.Nm, x.Dept, @Desig, x.Rp, @rUser, x.Lg, x.Lg, 'not-a-login', 1, @Now
    FROM (SELECT 'ZZ53 user one' AS Nm, @DA AS Dept, @MA1 AS Rp, 'zz53u1' AS Lg
          UNION ALL SELECT 'ZZ53 user two', @DA, @MC, 'zz53u2'
          UNION ALL SELECT 'ZZ53 user three', @DA, @Ctl1, 'zz53u3'
          UNION ALL SELECT 'ZZ53 user four', @DA, NULL, 'zz53u4'
          UNION ALL SELECT 'ZZ53 user five', @DA, @MAi, 'zz53u5'
          UNION ALL SELECT 'ZZ53 user B', @DB, NULL, 'zz53ub'
          UNION ALL SELECT 'ZZ53 user C', @DC, NULL, 'zz53uc') x;
    SELECT @U1 = MAX(CASE WHEN LoginName = 'zz53u1' THEN UserId END), @U2 = MAX(CASE WHEN LoginName = 'zz53u2' THEN UserId END),
           @U3 = MAX(CASE WHEN LoginName = 'zz53u3' THEN UserId END), @U4 = MAX(CASE WHEN LoginName = 'zz53u4' THEN UserId END),
           @U5 = MAX(CASE WHEN LoginName = 'zz53u5' THEN UserId END), @UB = MAX(CASE WHEN LoginName = 'zz53ub' THEN UserId END),
           @UC = MAX(CASE WHEN LoginName = 'zz53uc' THEN UserId END)
    FROM Users WHERE LoginName LIKE 'zz53u%';

    INSERT INTO @T SELECT 'Made-up data: five Managers saved through spr_AddEditUser, MAi inactive, MAn without history rows', '5 0 0',
           CAST((SELECT COUNT(*) FROM Users WHERE LoginName IN ('zz53ma1', 'zz53ma2', 'zz53mai', 'zz53mx', 'zz53mc')) AS VARCHAR(4)) + ' '
         + CAST((SELECT AccountStatus FROM Users WHERE UserId = @MAi) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM User_Department WHERE UserId = @MAn) AS VARCHAR(4));

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z53', 'ZZ step 53 committee', '2000-01-01', 1, 0);
    SET @Com = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('95301', @Com, 'ZZ53 test', 'ZZ', DATEADD(DAY, 10, @Day), '10:00', DATEADD(DAY, 5, @Day), 'Open', 'Open');
    SET @MFut = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('95302', @Com, 'ZZ53 test', 'ZZ', DATEADD(DAY, -3, @Day), '10:00', DATEADD(DAY, -8, @Day), 'Open', 'Open');
    SET @MPast = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- R1: the Managers of a department, who may decide
    ---------------------------------------------------------------------------
    SET @S = ISNULL(STUFF((SELECT ' ' + u.LoginName FROM dbo.fn_DepartmentManagers(@DA) f JOIN Users u ON u.UserId = f.UserId ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), '-');
    INSERT INTO @T SELECT 'fn_DepartmentManagers(A): active Managers with an open row, and MAn without history rows by Users.DepartmentId; not the inactive MAi', 'zz53ma1 zz53ma2 zz53man zz53mx', @S;
    SET @S = ISNULL(STUFF((SELECT ' ' + u.LoginName FROM dbo.fn_DepartmentManagers(@DB) f JOIN Users u ON u.UserId = f.UserId ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), '-')
           + ' / ' + ISNULL(STUFF((SELECT ' ' + u.LoginName FROM dbo.fn_DepartmentManagers(@DC) f JOIN Users u ON u.UserId = f.UserId ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), '-');
    INSERT INTO @T SELECT 'fn_DepartmentManagers(B) none; fn_DepartmentManagers(C) MC only', '- / zz53mc', @S;

    ---------------------------------------------------------------------------
    -- R2: the route of every user
    ---------------------------------------------------------------------------
    SET @S = '';
    SELECT @S = @S + x.Lg + ':' + r.Route + ISNULL(CAST(r.RouteNote AS VARCHAR(1)), '') + '/' + CAST(r.DepartmentManagers AS VARCHAR(4)) + ' '
    FROM (SELECT 1 AS o, 'u1' AS Lg, @U1 AS Uid, @DA AS Dept UNION ALL SELECT 2, 'u2', @U2, @DA UNION ALL SELECT 3, 'u3', @U3, @DA
          UNION ALL SELECT 4, 'u4', @U4, @DA UNION ALL SELECT 5, 'u5', @U5, @DA UNION ALL SELECT 6, 'ub', @UB, @DB
          UNION ALL SELECT 7, 'ma1', @MA1, @DA) x
    CROSS APPLY dbo.fn_AgendaRoute(x.Uid, x.Dept) r
    ORDER BY x.o;
    INSERT INTO @T SELECT 'fn_AgendaRoute under "refuse": RP Manager of A M, RP Manager of C (not of A) M, RP Controller C, no RP M, inactive RP I, B without Manager R; the creator is not counted (ma1 sees 3)',
                          'u1:M/4 u2:M/4 u3:C/4 u4:M/4 u5:I/4 ub:R/0 ma1:M/3', RTRIM(@S);

    UPDATE App_Setting SET SettingValue = 'controller' WHERE SettingCode = 'DeptNoManagerAction';
    SELECT @S = r.Route + ISNULL(CAST(r.RouteNote AS VARCHAR(1)), '') + ' ' + r.DepartmentName FROM dbo.fn_AgendaRoute(@UB, @DB) r;
    SELECT @S = @S + ' / ' + r.Route + ISNULL(CAST(r.RouteNote AS VARCHAR(1)), '') FROM dbo.fn_AgendaRoute(@U1, @DA) r;
    INSERT INTO @T SELECT 'fn_AgendaRoute under "controller": B without Manager goes to the Controller with RouteNote N; A unchanged', 'CN ZZ step 53 department B / M', @S;
    UPDATE App_Setting SET SettingValue = 'refuse' WHERE SettingCode = 'DeptNoManagerAction';

    ---------------------------------------------------------------------------
    -- R2, R3, R8: saves through spr_AddEditAgenda
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U1, @DA, @Com, @MFut, N'ZZ53 i1';
    SET @i1 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @U1);
    EXEC #ZZ53_Rows @i1, @S OUTPUT;
    INSERT INTO @T SELECT 'Save of U1 (route M): AC; one unread row for every active Manager of A, none for the Admin, MAi, MC or the creator',
                          'Result 1, Reason 0; AC -; zz53ma1:U- zz53ma2:U- zz53man:U- zz53mx:U-',
                          (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode + ' ' + ISNULL(RouteNote, '-') FROM Agenda WHERE AgendaId = @i1) + '; ' + @S;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U2, @DA, @Com, @MFut, N'ZZ53 i2';
    SET @i2 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @U2);
    EXEC #ZZ53_Rows @i2, @S OUTPUT;
    INSERT INTO @T SELECT 'Save of U2 (RP the Manager of C, not of A): waits for the Managers of A, not for MC', 'Result 1, Reason 0; AC; zz53ma1:U- zz53ma2:U- zz53man:U- zz53mx:U-',
                          (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @i2) + '; ' + @S;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U3, @DA, @Com, @MFut, N'ZZ53 iCtl';
    SET @iCtl = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @U3);
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @iCtl);
    INSERT INTO @T SELECT 'Save of U3 (RP a Controller): AMA; rows for every active Controller and nobody else (no Admin, no Manager)', 'Result 1, Reason 0; AMA; 0 0',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @iCtl) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Roles r ON r.RoleId = u.RoleId WHERE m.AlertId = @A AND r.RoleCode <> 'controller') AS VARCHAR(4)) + ' '
         + CAST(ABS((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A)
                    - (SELECT COUNT(*) FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0)) AS VARCHAR(4));

    SET @n = (SELECT COUNT(*) FROM Agenda);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @UB, @DB, @Com, @MFut, N'ZZ53 iB refused';
    INSERT INTO @T SELECT 'Save of UB (B has no Manager), setting "refuse": Reason 29 with the department, nothing saved', 'Result 0, Reason 29, ZZ step 53 department B; 0',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Agenda) - @n AS VARCHAR(4));

    UPDATE App_Setting SET SettingValue = 'controller' WHERE SettingCode = 'DeptNoManagerAction';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @UB, @DB, @Com, @MFut, N'ZZ53 iB';
    SET @iB = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UB);
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @iB);
    INSERT INTO @T SELECT 'Save of UB, setting "controller": AMA with RouteNote N, ReasonDetail SentToController (the page says so); rows for the Controllers only', 'Result 1, Reason 0, SentToController; AMA N; 0',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode + ' ' + ISNULL(RouteNote, '-') FROM Agenda WHERE AgendaId = @iB) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Roles r ON r.RoleId = u.RoleId WHERE m.AlertId = @A AND r.RoleCode <> 'controller') AS VARCHAR(4));

    -- Reason 15: no active Controller (all Controllers made inactive inside the transaction, then back)
    INSERT INTO @Off (UserId) SELECT u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1;
    UPDATE Users SET AccountStatus = 0 WHERE UserId IN (SELECT UserId FROM @Off);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @UB, @DB, @Com, @MFut, N'ZZ53 r15a';
    SET @S = (SELECT Txt FROM @R);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U3, @DA, @Com, @MFut, N'ZZ53 r15b';
    INSERT INTO @T SELECT 'No active Controller: the "controller" route (UB) is refused with Reason 15; U3, whose RP is that Controller (now inactive), gets Reason 11 first (unchanged order)',
           'Result 0, Reason 15 / Result 0, Reason 11, ZZ53 controller one',
           @S + ' / ' + (SELECT Txt FROM @R);
    UPDATE Users SET AccountStatus = 1 WHERE UserId IN (SELECT UserId FROM @Off);
    UPDATE App_Setting SET SettingValue = 'refuse' WHERE SettingCode = 'DeptNoManagerAction';

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U5, @DA, @Com, @MFut, N'ZZ53 r11';
    INSERT INTO @T SELECT 'Save of U5 (RP inactive): Reason 11 unchanged, also while A has active Managers', 'Result 0, Reason 11, ZZ53 manager A inactive', (SELECT Txt FROM @R);

    -- More items of A at AC: i3 of U4 (no RP), i4 of U1, i5 of U1; iOwn created by MA2 himself (inserted directly)
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U4, @DA, @Com, @MFut, N'ZZ53 i3';
    SET @i3 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @U4);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U1, @DA, @Com, @MFut, N'ZZ53 i4';
    SET @i4 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @U1);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U1, @DA, @Com, @MFut, N'ZZ53 i5';
    SET @i5 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @U1);
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z53-95301-900', @Com, @MFut, @DA, @SubjectTypeId, 'ZZ53 own', 'Entry', 'AC', 'New', @Now, @MA2);
    SET @iOwn = SCOPE_IDENTITY();
    INSERT INTO Alert_Master (SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Agenda', @iOwn, @DA, 'Agenda (Z53-95301-900)', 'AC', 3, @Com, @Now, @MA2);
    -- Past item of A at AC, with the Managers' rows (as before the meeting date passed)
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z53-95302-901', @Com, @MPast, @DA, @SubjectTypeId, 'ZZ53 past', 'Entry', 'AC', 'New', @Now, @U1);
    SET @iH = SCOPE_IDENTITY();
    INSERT INTO Alert_Master (SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Agenda', @iH, @DA, 'Agenda (Z53-95302-901)', 'AC', 3, @Com, @Now, @U1);
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
    SELECT SCOPE_IDENTITY(), f.UserId, 0, 1 FROM dbo.fn_DepartmentManagers(@DA) f;

    SET @S = '';
    SELECT @S = @S + x.Lg + ':' + CAST((SELECT COUNT(*) FROM dbo.fn_AgendaWaitingFor(x.Uid, @Today) w WHERE w.AgendaId = @i1 AND w.CanApprove = 1) AS VARCHAR(1)) + ' '
    FROM (SELECT 1 AS o, 'ma1' AS Lg, @MA1 AS Uid UNION ALL SELECT 2, 'ma2', @MA2 UNION ALL SELECT 3, 'man', @MAn UNION ALL SELECT 4, 'mai', @MAi
          UNION ALL SELECT 5, 'mc', @MC UNION ALL SELECT 6, 'adm', @Adm UNION ALL SELECT 7, 'u1', @U1) x ORDER BY x.o;
    INSERT INTO @T SELECT 'fn_AgendaWaitingFor, i1 at AC: every active Manager of A may approve; not the inactive MAi, the Manager of C, the Admin or the creator',
                          'ma1:1 ma2:1 man:1 mai:0 mc:0 adm:0 u1:0', RTRIM(@S);
    INSERT INTO @T SELECT 'fn_AgendaWaitingFor, an item at AC created by MA2 himself: MA2 may not decide it, MA1 may', '0 1',
           CAST((SELECT COUNT(*) FROM dbo.fn_AgendaWaitingFor(@MA2, @Today) w WHERE w.AgendaId = @iOwn) AS VARCHAR(1)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_AgendaWaitingFor(@MA1, @Today) w WHERE w.AgendaId = @iOwn) AS VARCHAR(1));

    ---------------------------------------------------------------------------
    -- R6: the "Created" mail
    ---------------------------------------------------------------------------
    EXEC #ZZ53_Mails 'Created', @U1, NULL, @DA, @S OUTPUT;
    EXEC #ZZ53_Mails 'Created', @U3, NULL, @DA, @S2 OUTPUT;
    INSERT INTO @T SELECT 'Created mail: route M Bcc every active Manager of A (no Admin, no MAi, no MC); route C the Controllers', 'zz53ma1 zz53ma2 zz53man zz53mx / zz53ctl1 zz53ctl2', @S + ' / ' + @S2;
    EXEC #ZZ53_Mails 'Created', @UB, NULL, @DB, @S OUTPUT;
    EXEC #ZZ53_Mails 'Created', @U5, NULL, @DA, @S2 OUTPUT;
    INSERT INTO @T SELECT 'Created mail: route R (B, "refuse") and route I (inactive RP) have no address', '- / -', @S + ' / ' + @S2;

    ---------------------------------------------------------------------------
    -- R4, R5: decisions
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_UpdateAgendaByAgendaId @AgendaId = @i1, @ShortText = N'ZZ53 i1', @ProposedResolution = N'ZZ', @MgrComments = N'ok', @ControllerComments = @E,
         @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @MA1;
    EXEC #ZZ53_Rows @i1, @S OUTPUT;
    INSERT INTO @T SELECT 'MA1 approves i1: AMA; MA2, MAn and MX marked H and read; MA1 read; Controllers and the creator unread; no Admin row',
                          'Result 1, Reason 0; AMA; zz53ctl1:U- zz53ctl2:U- zz53ma1:R- zz53ma2:RH zz53man:RH zz53mx:RH zz53u1:U-',
                          (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @i1) + '; ' + @S;
    SET @A1 = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @i1);
    INSERT INTO @T SELECT 'The H rows record who (MA1) and when (now)', '3 3',
           CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A1 AND HandledReason = 'H' AND HandledBy = @MA1) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A1 AND HandledReason = 'H' AND HandledOn >= DATEADD(MINUTE, -5, GETDATE())) AS VARCHAR(4));
    EXEC #ZZ53_Mails 'AMA', @MA1, @i1, NULL, @S OUTPUT;
    INSERT INTO @T SELECT 'Approve mail (AMA): the Controllers, the creator and the other Managers of A; not MA1 who decided; no Admin',
                          'zz53ctl1 zz53ctl2 zz53ma2 zz53man zz53mx zz53u1', @S;

    EXEC #ZZ53_Rows @i1, @S OUTPUT;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_UpdateAgendaByAgendaId @AgendaId = @i1, @ShortText = N'ZZ53 i1', @ProposedResolution = N'ZZ', @MgrComments = N'late', @ControllerComments = @E,
         @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @MA2;
    EXEC #ZZ53_Rows @i1, @S2 OUTPUT;
    INSERT INTO @T SELECT 'MA2 approves i1 afterwards (first decision wins): Reason 14 with the status name (the item is at AMA); nothing changed',
           'Result 0, Reason 14, ' + (SELECT CAST(AgendaStatusName AS VARCHAR(100)) FROM Agenda_Status WHERE AgendaStatusCode = 'AMA') + '; same',
           (SELECT Txt FROM @R) + '; ' + CASE WHEN @S2 = @S THEN 'same' ELSE @S2 END;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_UpdateAgendaByAgendaId @AgendaId = @i3, @ShortText = N'ZZ53 i3', @ProposedResolution = N'ZZ', @MgrComments = N'no', @ControllerComments = @E,
         @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Rejected', @UpdatedBy = @MAn;
    EXEC #ZZ53_Rows @i3, @S OUTPUT;
    INSERT INTO @T SELECT 'MAn (no history rows) rejects i3: AMR; MA1, MA2 and MX marked H; the creator unread',
                          'Result 1, Reason 0; AMR; zz53ma1:RH zz53ma2:RH zz53man:R- zz53mx:RH zz53u4:U-',
                          (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @i3) + '; ' + @S;
    EXEC #ZZ53_Mails 'AMR', @MAn, @i3, NULL, @S OUTPUT;
    INSERT INTO @T SELECT 'Reject mail (AMR): the creator and the other Managers of A; not MAn who decided', 'zz53ma1 zz53ma2 zz53mx zz53u4', @S;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_UpdateAgendaByAgendaId @AgendaId = @iH, @ShortText = N'ZZ53 past', @ProposedResolution = N'ZZ', @MgrComments = N'ok', @ControllerComments = @E,
         @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @MA2;
    EXEC #ZZ53_Rows @iH, @S OUTPUT;
    INSERT INTO @T SELECT 'MA2 approves an item of A after its meeting date: Reason 28; no row marked', 'Result 0, Reason 28; zz53ma1:U- zz53ma2:U- zz53man:U- zz53mx:U-',
                          (SELECT Txt FROM @R) + '; ' + @S;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_UpdateAgendaByAgendaId @AgendaId = @i2, @ShortText = N'ZZ53 i2', @ProposedResolution = N'ZZ', @MgrComments = @E, @ControllerComments = N'no',
         @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @Ctl1;
    EXEC #ZZ53_Rows @i2, @S OUTPUT;
    SET @S = REPLACE(@S, 'zz53ctl1:R- ', '');
    INSERT INTO @T SELECT 'The Controller rejects i2 at AC: ACR; the Managers'' rows unread, not marked (unchanged rule)',
                          'Result 1, Reason 0; ACR; zz53ma1:U- zz53ma2:U- zz53man:U- zz53mx:U- zz53u2:U-',
                          (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @i2) + '; ' + @S;
    EXEC #ZZ53_Mails 'ACR', @Ctl1, @i2, NULL, @S OUTPUT;
    INSERT INTO @T SELECT 'Controller''s reject mail (ACR) at AC: every Manager of A (none handled) and the creator', 'zz53ma1 zz53ma2 zz53man zz53mx zz53u2', @S;

    ---------------------------------------------------------------------------
    -- R3: marked rows stay closed
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @i1, @AgendaNo = '', @CommitteeId = @Com, @MeetingId = @MFut, @DepartmentId = @DA,
         @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ53 i1 changed', @AgendaType = 'Entry', @AgendaText = N'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ', @FilePath = @E, @MgrComments = N'ok', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl1, @UpdatedOn = @Now, @UpdatedBy = @Ctl1, @SubjectNo = NULL, @ActingUserId = @Ctl1;
    EXEC #ZZ53_Rows @i1, @S OUTPUT;
    INSERT INTO @T SELECT 'The Controller edits i1 (at AMA): the refresh makes the ordinary rows unread; the H rows stay read and marked',
                          'Result 1, Reason 0; zz53ctl1:U- zz53ctl2:U- zz53ma1:U- zz53ma2:RH zz53man:RH zz53mx:RH zz53u1:U-',
                          (SELECT Txt FROM @R) + '; ' + @S;
    EXEC #ZZ53_Mails 'Update', @Ctl1, @i1, NULL, @S OUTPUT;
    INSERT INTO @T SELECT 'Update mail of that edit: the marked rows are left out (Controller two, MA1 and the creator; a Manager is not mailed at AMA)', 'zz53ctl2 zz53u1', @S;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_UpdateAgendaByAgendaId @AgendaId = @i1, @ShortText = N'ZZ53 i1 changed', @ProposedResolution = N'ZZ', @MgrComments = @E, @ControllerComments = N'fine',
         @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @Ctl2;
    EXEC #ZZ53_Rows @i1, @S OUTPUT;
    INSERT INTO @T SELECT 'The Controller approves i1: ACA; the H rows stay read and marked',
                          'Result 1, Reason 0; ACA; zz53ctl1:U- zz53ctl2:R- zz53ma1:U- zz53ma2:RH zz53man:RH zz53mx:RH zz53u1:U-',
                          (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @i1) + '; ' + @S;
    EXEC #ZZ53_Mails 'ACA', @Ctl2, @i1, NULL, @S OUTPUT;
    INSERT INTO @T SELECT 'Controller''s approve mail (ACA): the marked rows (MA2, MAn, MX) are left out', 'zz53ctl1 zz53ctl2 zz53ma1 zz53u1', @S;

    -- The refresh of a User's edit at AC: an inactive user's row and a marked row stay as they are
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @i5);
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@A, @MAi, 1, 1);
    UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @A;
    UPDATE Alert_User_Map SET HandledReason = 'N', HandledBy = @Adm, HandledOn = GETDATE() WHERE AlertId = @A AND UserId = @MX;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @i5, @AgendaNo = '', @CommitteeId = @Com, @MeetingId = @MFut, @DepartmentId = @DA,
         @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ53 i5 changed', @AgendaType = 'Entry', @AgendaText = N'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @U1, @UpdatedOn = @Now, @UpdatedBy = @U1, @SubjectNo = NULL, @ActingUserId = @U1;
    EXEC #ZZ53_Rows @i5, @S OUTPUT;
    INSERT INTO @T SELECT 'U1 edits i5 at AC: the Managers'' rows unread again; the inactive MAi''s row and MX''s marked row stay read',
                          'Result 1, Reason 0; zz53ma1:U- zz53ma2:U- zz53mai:R- zz53man:U- zz53mx:RN',
                          (SELECT Txt FROM @R) + '; ' + @S;
    EXEC #ZZ53_Mails 'Update', @U1, @i5, NULL, @S OUTPUT;
    INSERT INTO @T SELECT 'Update mail of that edit: the active Managers with an ordinary row (not MAi, not the marked MX)', 'zz53ma1 zz53ma2 zz53man', @S;
    UPDATE Alert_User_Map SET HandledReason = NULL, HandledBy = NULL, HandledOn = NULL WHERE AlertId = @A AND UserId = @MX;
    DELETE FROM Alert_User_Map WHERE AlertId = @A AND UserId = @MAi;

    ---------------------------------------------------------------------------
    -- The lists of a Manager with a handled row (MA2: i1 handled by MA1)
    ---------------------------------------------------------------------------
    SET @AU = (SELECT AlertUserId FROM Alert_User_Map WHERE AlertId = @A1 AND UserId = @MA2);
    DELETE FROM @L2; INSERT INTO @L2 EXEC spr_GetDashboardAlerts @ActingUserId = @MA2, @Mode = 'A', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Tot OUTPUT, @UnreadCount = @Unr OUTPUT, @PageShown = @Pg OUTPUT;
    INSERT INTO @T SELECT 'MA2, All: the handled row of i1 is listed (although i1 is at ACA) with HandledReason H, the name and login of MA1 and the marking time as its date',
                          'H ZZ53 manager A one zz53ma1 1 1',
           ISNULL((SELECT HandledReason + ' ' + HandledByName + ' ' + HandledByLogin + ' '
                          + CAST(CASE WHEN EventOn = HandledOn THEN 1 ELSE 0 END AS VARCHAR(1)) + ' '
                          + CAST(CASE WHEN ActorUserId = @MA1 THEN 1 ELSE 0 END AS VARCHAR(1)) FROM @L2 WHERE AlertUserId = @AU), 'not listed');
    SET @n = @Unr;
    DELETE FROM @L2; INSERT INTO @L2 EXEC spr_GetDashboardAlerts @ActingUserId = @MA2, @Mode = 'R', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Tot OUTPUT, @UnreadCount = @Unr OUTPUT, @PageShown = @Pg OUTPUT;
    SET @S = CAST((SELECT COUNT(*) FROM @L2 WHERE AlertUserId = @AU) AS VARCHAR(1));
    DELETE FROM @L2; INSERT INTO @L2 EXEC spr_GetDashboardAlerts @ActingUserId = @MA2, @Mode = 'U', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Tot OUTPUT, @UnreadCount = @Unr OUTPUT, @PageShown = @Pg OUTPUT;
    SET @S = @S + ' ' + CAST((SELECT COUNT(*) FROM @L2 WHERE AlertUserId = @AU) AS VARCHAR(1));
    EXEC spr_GetAlertCount @ActingUserId = @MA2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @UnreadCount = @n2 OUTPUT;
    INSERT INTO @T SELECT 'MA2, Recent and Unread: the handled row is left out; the header count equals the card''s unread count and counts no marked row', '0 0 1 0',
           @S + ' ' + CAST(CASE WHEN @n2 = @n AND @n2 = @Unr THEN 1 ELSE 0 END AS VARCHAR(1)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_DashboardAlerts(@MA2) f WHERE f.ReadStatus = 0 AND f.HandledReason IS NOT NULL) AS VARCHAR(4));
    EXEC spr_RemoveAlertForUser @ActingUserId = @MA2, @AlertUserId = @AU, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    DELETE FROM @L2; INSERT INTO @L2 EXEC spr_GetDashboardAlerts @ActingUserId = @MA2, @Mode = 'A', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Tot OUTPUT, @UnreadCount = @Unr OUTPUT, @PageShown = @Pg OUTPUT;
    INSERT INTO @T SELECT 'MA2 removes the handled row: removed (StatusId 0), still marked, no longer under All', '0 H 0',
           CAST((SELECT StatusId FROM Alert_User_Map WHERE AlertUserId = @AU) AS VARCHAR(2)) + ' ' + ISNULL((SELECT HandledReason FROM Alert_User_Map WHERE AlertUserId = @AU), '-') + ' '
         + CAST((SELECT COUNT(*) FROM @L2 WHERE AlertUserId = @AU) AS VARCHAR(1));

    ---------------------------------------------------------------------------
    -- R8: committee and meeting alerts without Admin rows
    ---------------------------------------------------------------------------
    EXEC spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'Z53B', @CommitteeName = 'ZZ step 53 committee two', @Board = 0,
         @IncorporationDate = '2000-01-01', @MeetingStartNo = 1, @CommitteeColorCode = '', @CessationDate = NULL, @StatusId = 1,
         @CreatedOn = @Now, @CreatedBy = @Ctl1, @UpdatedOn = @Now, @UpdatedBy = @Ctl1;
    SET @A = (SELECT MAX(am.AlertId) FROM Alert_Master am JOIN Committee c ON c.CommitteeId = am.SourceTypeId WHERE am.SourceType = 'Committee' AND c.CommitteeCode = 'Z53B');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '95303', @CommitteeId = @Com, @Place = 'ZZ53 test', @Venue = 'ZZ',
         @MeetingDate = @Day, @MeetingTime = '10:00', @AgendaSubmissionDate = @Day, @MeetingColorCode = '', @CreatedOn = @Now, @CreatedBy = @Ctl1,
         @UpdatedOn = @Now, @UpdatedBy = @Ctl1;
    SET @n = (SELECT MAX(am.AlertId) FROM Alert_Master am JOIN Meeting mt ON mt.MeetingId = am.SourceTypeId WHERE am.SourceType = 'Meeting' AND mt.MeetingNo = '95303' AND mt.CommitteeId = @Com);
    INSERT INTO @T SELECT 'Committee (CC) and meeting (MC) alerts: rows for active users, none of the Admin role', 'yes 0 / Result 1 yes 0',
           CASE WHEN EXISTS (SELECT 1 FROM Alert_User_Map WHERE AlertId = @A) THEN 'yes' ELSE 'no' END + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Roles r ON r.RoleId = u.RoleId WHERE m.AlertId = @A AND r.RoleCode = 'admin') AS VARCHAR(4)) + ' / '
         + 'Result ' + CAST(ISNULL((SELECT Result FROM @R), -1) AS VARCHAR(2)) + ' '
         + CASE WHEN EXISTS (SELECT 1 FROM Alert_User_Map WHERE AlertId = @n) THEN 'yes' ELSE 'no' END + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Roles r ON r.RoleId = u.RoleId WHERE m.AlertId = @n AND r.RoleCode = 'admin') AS VARCHAR(4));

    ---------------------------------------------------------------------------
    -- R7: the back-fill
    ---------------------------------------------------------------------------
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('Z53-95301-902', @Com, @MFut, @DA, @SubjectTypeId, 'ZZ53 fill', 'Entry', 'AC', 'New', @Now, @U1);
    SET @iFill = SCOPE_IDENTITY();
    INSERT INTO Alert_Master (SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Agenda', @iFill, @DA, 'Agenda (Z53-95301-902)', 'AC', 3, @Com, @Now, @U1);
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (SCOPE_IDENTITY(), @MA1, 1, 0);
    EXEC #ZZ53_Backfill @Adm, @Added OUTPUT, @Reopened OUTPUT;
    EXEC #ZZ53_Rows @iFill, @S OUTPUT;
    SET @S = @S + ' (' + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @iH) AS VARCHAR(4)) + ')';
    EXEC #ZZ53_Backfill @Adm, @n OUTPUT, @n2 OUTPUT;
    INSERT INTO @T SELECT 'Back-fill: an item at AC to come gets a row for each Manager of A without one (MA1''s removed row kept as it is); the past item is not touched; a second run adds 0',
                          'zz53ma1:R-x zz53ma2:U- zz53man:U- zz53mx:U- (4); 0 0',
                          @S + '; ' + CAST(@n AS VARCHAR(12)) + ' ' + CAST(@n2 AS VARCHAR(12));
    -- iOwn (created by MA2, an alert without rows) got rows from the back-fill too: MA2 left out
    EXEC #ZZ53_Rows @iOwn, @S OUTPUT;
    INSERT INTO @T SELECT 'Back-fill of an item created by MA2 himself: rows for the other Managers, none for MA2', 'zz53ma1:U- zz53man:U- zz53mx:U-', @S;

    ---------------------------------------------------------------------------
    -- R9: rule 12
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @UC, @DC, @Com, @MFut, N'ZZ53 iC';
    SET @iC = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UC);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Edit @MC, @rUser, @DC, NULL, @Adm;
    INSERT INTO @T SELECT 'MC, the only Manager of C with an item waiting, made a User: refused (Reason 24) with the open item and the department part; nothing changed',
                          'Result 0, Reason 24, open:1|past:0|last active Manager of ZZ step 53 department C (1 item waiting); manager',
                          (SELECT Txt FROM @R) + '; ' + (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @MC);

    -- MA1 made a User while A has other Managers: allowed; his rows of the items at AC of A marked N
    SET @n = (SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN Agenda a ON a.AgendaId = am.SourceTypeId AND am.SourceType = 'Agenda'
              WHERE m.UserId = @MA1 AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Edit @MA1, @rUser, @DA, NULL, @Adm;
    INSERT INTO @T SELECT 'MA1 made a User while A has other Managers: allowed; ReasonDetail ends with the Released part; his rows of the items at AC are marked N by the Admin, read',
                          'Result 1, Reason 0, |Released:' + CAST(@n AS VARCHAR(12)) + ':ZZ step 53 department A; ' + CAST(@n AS VARCHAR(12)) + ' 0',
                          (SELECT Txt FROM @R) + '; '
                        + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE UserId = @MA1 AND HandledReason = 'N' AND HandledBy = @Adm AND ReadStatus = 1) AS VARCHAR(12)) + ' '
                        + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN Agenda a ON a.AgendaId = am.SourceTypeId AND am.SourceType = 'Agenda'
                                WHERE m.UserId = @MA1 AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC') AS VARCHAR(12));
    INSERT INTO @T SELECT 'MA1''s handled row of i1 (at ACA) and the rows of other items are not touched by the release', '-', ISNULL((SELECT HandledReason FROM Alert_User_Map WHERE AlertId = @A1 AND UserId = @MA1), '-');

    -- MA2 deactivated while MAn and MX remain: allowed, rows N
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @MA2, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'MA2 deactivated while MAn and MX remain Managers of A: allowed with the Released part; no open row of an item at AC left for MA2',
                          'Result 1, Reason 0; Released 0',
                          'Result ' + CAST((SELECT Result FROM @R) AS VARCHAR(2)) + ', Reason ' + CAST((SELECT Reason FROM @R) AS VARCHAR(3)) + '; '
                        + CASE WHEN (SELECT ReasonDetail FROM @R) LIKE '|Released:%:ZZ step 53 department A' THEN 'Released' ELSE ISNULL(CAST((SELECT ReasonDetail FROM @R) AS VARCHAR(200)), 'NULL') END + ' '
                        + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN Agenda a ON a.AgendaId = am.SourceTypeId AND am.SourceType = 'Agenda'
                                WHERE m.UserId = @MA2 AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC' AND m.StatusId = 1) AS VARCHAR(12));

    -- MX gains C (R10, a new mapping), then loses it again (removed mapping: rows of C marked N; A untouched)
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Edit @MX, @rMgr, @DA, @L, @Adm;
    EXEC #ZZ53_Rows @iC, @S OUTPUT;
    INSERT INTO @T SELECT 'MX given department C: saved; he gets an unread row on the item waiting in C', 'Result 1, Reason 0; zz53mc:U- zz53mx:U-', (SELECT Txt FROM @R) + '; ' + @S;
    EXEC #ZZ53_Mails 'Created', @UC, NULL, @DC, @S OUTPUT;
    INSERT INTO @T SELECT 'Created mail of a new item of C now Bcc both Managers of C', 'zz53mc zz53mx', @S;
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Edit @MX, @rMgr, @DA, @L, @Adm;
    EXEC #ZZ53_Rows @iC, @S OUTPUT;
    EXEC #ZZ53_Rows @i4, @S2 OUTPUT;
    INSERT INTO @T SELECT 'MX loses C again (MC remains): allowed with Released:1 of C; his row of C marked N, his rows of A not touched',
                          'Result 1, Reason 0, |Released:1:ZZ step 53 department C; zz53mc:U- zz53mx:RN; mx:U-',
                          (SELECT Txt FROM @R) + '; ' + @S + '; ' + CASE WHEN @S2 LIKE '%zz53mx:U-%' THEN 'mx:U-' ELSE @S2 END;

    -- Now MAn and MX are the Managers of A: MAn alone is not refused; MX made a User: MAn remains
    EXEC #ZZ53_Rows @i4, @S OUTPUT;
    SET @S = ISNULL(STUFF((SELECT ' ' + f.Kind + '=' + CAST(f.Items AS VARCHAR(12)) FROM dbo.fn_ManagerReleaseRefusal(@MAn, NULL, 1) f ORDER BY f.Kind FOR XML PATH('')), 1, 1, ''), '-');
    INSERT INTO @T SELECT 'fn_ManagerReleaseRefusal(MAn) while MX is also a Manager of A: nothing stops him', '-', @S;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Edit @MX, @rUser, @DA, NULL, @Adm;
    SET @n = (SELECT COUNT(*) FROM Agenda a JOIN Meeting mt ON mt.MeetingId = a.MeetingId WHERE a.DepartmentId = @DA AND a.AgendaStatusCode = 'AC' AND ISNULL(mt.AgendaStatus, 'Open') = 'Open');
    SET @S = ISNULL(STUFF((SELECT ' ' + f.Kind + CASE WHEN f.Kind = 'D' THEN ':' + CAST(f.DepartmentName AS VARCHAR(200)) ELSE '' END + '=' + CAST(f.Items AS VARCHAR(12))
                           FROM dbo.fn_ManagerReleaseRefusal(@MAn, NULL, 1) f ORDER BY f.Kind FOR XML PATH('')), 1, 1, ''), '-');
    INSERT INTO @T SELECT 'MX made a User; now MAn is the only Manager of A: rule 12 names A (all its open items at AC), the open items (P) and the past ones (Q) he alone could decide',
                          'Result 1; D:ZZ step 53 department A=' + CAST(@n AS VARCHAR(12)) + ' P=4 Q=1',
                          'Result ' + CAST((SELECT Result FROM @R) AS VARCHAR(2)) + '; ' + @S;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @MAn, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Deactivate MAn, the only Manager of A: refused with the three parts; still active',
                          'Result 0, Reason 24, open:4|past:1|last active Manager of ZZ step 53 department A (' + CAST(@n AS VARCHAR(12)) + ' items waiting); 1',
                          (SELECT Txt FROM @R) + '; ' + CAST((SELECT AccountStatus FROM Users WHERE UserId = @MAn) AS VARCHAR(2));

    ---------------------------------------------------------------------------
    -- R10: back as Manager, Activate
    ---------------------------------------------------------------------------
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Edit @MA1, @rMgr, @DA, @L, @Adm;
    EXEC #ZZ53_Rows @i4, @S OUTPUT;
    EXEC #ZZ53_Rows @iH, @S2 OUTPUT;
    INSERT INTO @T SELECT 'MA1 made a Manager of A again: his N row on an item to come opened again (unread, not marked); the past item''s N row stays N',
                          'Result 1, Reason 0; ma1:U-; ma1:RN',
                          (SELECT Txt FROM @R) + '; '
                        + CASE WHEN @S LIKE '%zz53ma1:U-%' THEN 'ma1:U-' ELSE @S END + '; '
                        + CASE WHEN @S2 LIKE '%zz53ma1:RN%' THEN 'ma1:RN' ELSE @S2 END;
    -- An H row of MA2 on an item still at AC (made by hand) is never opened again
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @i4);
    UPDATE Alert_User_Map SET HandledReason = 'H', HandledBy = @MAn, HandledOn = GETDATE(), ReadStatus = 1 WHERE AlertId = @A AND UserId = @MA2;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @MA2, @AccountStatus = 1, @ActingUserId = @Adm;
    EXEC #ZZ53_Rows @i4, @S OUTPUT;
    EXEC #ZZ53_Rows @i5, @S2 OUTPUT;
    INSERT INTO @T SELECT 'MA2 activated: his N rows on items to come opened again (i5 unread); his H row on i4 stays H',
                          'Result 1, Reason 0; ma2:RH; ma2:U-',
                          (SELECT Txt FROM @R) + '; '
                        + CASE WHEN @S LIKE '%zz53ma2:RH%' THEN 'ma2:RH' ELSE @S END + '; '
                        + CASE WHEN @S2 LIKE '%zz53ma2:U-%' THEN 'ma2:U-' ELSE @S2 END;
    -- A Controller moves an item at AC from A to C: the Managers of A handled by the Controller, the Manager of C gets his row
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Add @U1, @DA, @Com, @MFut, N'ZZ53 move';
    SET @iMove = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @U1);
    EXEC #ZZ53_Rows @iMove, @S2 OUTPUT;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @iMove, @AgendaNo = '', @CommitteeId = @Com, @MeetingId = @MFut, @DepartmentId = @DC,
         @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ53 move', @AgendaType = 'Entry', @AgendaText = N'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl1, @UpdatedOn = @Now, @UpdatedBy = @Ctl1, @SubjectNo = NULL, @ActingUserId = @Ctl1;
    EXEC #ZZ53_Rows @iMove, @S OUTPUT;
    INSERT INTO @T SELECT 'The Controller moves an item at AC from A to C: the Managers of A marked M (moved) by the Controller, the Manager of C gets an unread row; MC decides, MA1 no longer',
                          'zz53ma1:U- zz53ma2:U- zz53man:U- / Result 1, Reason 0; zz53ma1:RM zz53ma2:RM zz53man:RM zz53mc:U-; 3 1 0',
                          @S2 + ' / ' + (SELECT Txt FROM @R) + '; ' + @S + '; '
                        + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @iMove AND m.HandledReason = 'M' AND m.HandledBy = @Ctl1) AS VARCHAR(4)) + ' '
                        + CAST((SELECT COUNT(*) FROM dbo.fn_AgendaWaitingFor(@MC, @Today) w WHERE w.AgendaId = @iMove) AS VARCHAR(1)) + ' '
                        + CAST((SELECT COUNT(*) FROM dbo.fn_AgendaWaitingFor(@MA1, @Today) w WHERE w.AgendaId = @iMove) AS VARCHAR(1));

    EXEC #ZZ53_Mails 'Update', @Ctl2, @iMove, NULL, @S OUTPUT;
    INSERT INTO @T SELECT 'Update mail of the moved item: the Managers of A (marked M) are left out; the Manager of C mailed', 'zz53mc', @S;
    DELETE FROM @L2; INSERT INTO @L2 EXEC spr_GetDashboardAlerts @ActingUserId = @MAn, @Mode = 'A', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Tot OUTPUT, @UnreadCount = @Unr OUTPUT, @PageShown = @Pg OUTPUT;
    INSERT INTO @T SELECT 'MAn, All: the moved item listed with HandledReason M and the Controller as the person', 'M ZZ53 controller one',
           ISNULL((SELECT l.HandledReason + ' ' + l.HandledByName FROM @L2 l JOIN Alert_Master am ON am.AlertId = l.AlertId
                   WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @iMove), 'not listed');
    -- Moved back to A: the M rows of A's Managers are opened again, MC's row marked M
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @iMove, @AgendaNo = '', @CommitteeId = @Com, @MeetingId = @MFut, @DepartmentId = @DA,
         @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ53 move', @AgendaType = 'Entry', @AgendaText = N'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl1, @UpdatedOn = @Now, @UpdatedBy = @Ctl1, @SubjectNo = NULL, @ActingUserId = @Ctl1;
    EXEC #ZZ53_Rows @iMove, @S OUTPUT;
    INSERT INTO @T SELECT 'The Controller moves it back to A: the M rows of A''s Managers opened again (unread), MC''s row marked M',
                          'Result 1, Reason 0; zz53ma1:U- zz53ma2:U- zz53man:U- zz53mc:RM', (SELECT Txt FROM @R) + '; ' + @S;

    -- The protected system account, as an Admin in User Master, changes a Manager (owner 2026-11-23): each change succeeds,
    -- and the rows it releases record it as HandledBy
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Save 'ZZ53 manager by system', 'zz53ms', @rMgr, @DA, NULL, @L, @Sys;
    SET @MS = (SELECT UserId FROM Users WHERE LoginName = 'zz53ms');
    SET @n = (SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN Agenda a ON a.AgendaId = am.SourceTypeId AND am.SourceType = 'Agenda'
              JOIN Meeting mt ON mt.MeetingId = a.MeetingId
              WHERE m.UserId = @MS AND m.ReadStatus = 0 AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC' AND a.DepartmentId = @DA);
    SET @n2 = (SELECT COUNT(*) FROM Agenda a JOIN Meeting mt ON mt.MeetingId = a.MeetingId
               WHERE a.AgendaStatusCode = 'AC' AND a.DepartmentId = @DA AND a.CreatedBy <> @MS AND ISNULL(mt.AgendaStatus, 'Open') = 'Open'
                 AND (mt.MeetingDate IS NULL OR CAST(mt.MeetingDate AS DATE) >= @Today)
                 AND EXISTS (SELECT 1 FROM Alert_Master am WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId));
    INSERT INTO @T SELECT 'The system account creates a Manager of A: saved; he gets an unread row on every item of A waiting at AC on a meeting to come',
                          'Result 1, Reason 0; ' + CAST(@n2 AS VARCHAR(12)) + ' rows', ISNULL((SELECT Txt FROM @R), '-') + '; ' + CAST(@n AS VARCHAR(12)) + ' rows';

    SET @L = CAST(@DC AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ53_Edit @MS, @rMgr, @DC, @L, @Sys;
    SET @n2 = (SELECT COUNT(*) FROM Alert_User_Map WHERE UserId = @MS AND HandledReason = 'N' AND HandledBy = @Sys);
    EXEC #ZZ53_Rows @iC, @S OUTPUT;
    INSERT INTO @T SELECT 'The system account moves that Manager from A to C: saved with the Released part; his rows of A marked N with the system account as HandledBy; a row on the item of C',
                          'Result 1, Reason 0, |Released:' + CAST(@n AS VARCHAR(12)) + ':ZZ step 53 department A; ' + CAST(@n AS VARCHAR(12)) + '; yes',
                          ISNULL((SELECT Txt FROM @R), '-') + '; ' + CAST(@n2 AS VARCHAR(12)) + '; ' + CASE WHEN @S LIKE '%zz53ms:U-%' THEN 'yes' ELSE @S END;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @MS, @AccountStatus = 0, @ActingUserId = @Sys;
    EXEC #ZZ53_Rows @iC, @S OUTPUT;
    INSERT INTO @T SELECT 'The system account deactivates that Manager (MC remains in C): done; his row of the item of C marked N with the system account as HandledBy',
                          'Result 1, Reason 0, |Released:1:ZZ step 53 department C; zz53ms:RN; 1',
                          ISNULL((SELECT Txt FROM @R), '-') + '; ' + CASE WHEN @S LIKE '%zz53ms:RN%' THEN 'zz53ms:RN' ELSE @S END + '; '
                        + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @iC AND m.UserId = @MS AND m.HandledBy = @Sys) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @MS, @AccountStatus = 1, @ActingUserId = @Sys;
    EXEC #ZZ53_Rows @iC, @S OUTPUT;
    INSERT INTO @T SELECT 'The system account activates him again: done; his row of the item of C opened again (unread, not marked)',
                          'Result 1, Reason 0; zz53ms:U-',
                          ISNULL((SELECT Txt FROM @R), '-') + '; ' + CASE WHEN @S LIKE '%zz53ms:U-%' THEN 'zz53ms:U-' ELSE @S END;

    -- The internal procedure, from a calling procedure, with an inactive user or an unknown user id as the acting user: refused
    SET @S = 'none';
    BEGIN TRY
        EXEC #ZZ53_Backfill @MAi, @n OUTPUT, @n2 OUTPUT;
    END TRY
    BEGIN CATCH
        SET @S = CASE WHEN ERROR_MESSAGE() LIKE 'spr_SetManagerAlertRows: the acting user must be a known, active user%' THEN 'refused' ELSE LEFT(ERROR_MESSAGE(), 100) END;
    END CATCH
    SET @S2 = 'none';
    BEGIN TRY
        EXEC #ZZ53_Backfill -1, @n OUTPUT, @n2 OUTPUT;
    END TRY
    BEGIN CATCH
        SET @S2 = CASE WHEN ERROR_MESSAGE() LIKE 'spr_SetManagerAlertRows: the acting user must be a known, active user%' THEN 'refused' ELSE LEFT(ERROR_MESSAGE(), 100) END;
    END CATCH
    INSERT INTO @T SELECT 'spr_SetManagerAlertRows from a calling procedure with an inactive user / an unknown user id as the acting user: refused', 'refused refused', @S + ' ' + @S2;

    INSERT INTO @T SELECT 'No row of any made-up item for the Admin (R8)', '0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE m.UserId = @Adm) AS VARCHAR(4));
    INSERT INTO @T SELECT 'Every marked row has its three handled columns (the check holds)', '0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE HandledReason IS NOT NULL AND (HandledBy IS NULL OR HandledOn IS NULL)) AS VARCHAR(4));
END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Error inside the test transaction (line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + ')', 'none', LEFT(ERROR_MESSAGE(), 400));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

Report:
-- Rows outside the test, after
SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @HistAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistAfter = @HistAfter + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MgrApprovedStatus, ControllerApprovedStatus, RouteNote)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, UserId, ReadStatus, StatusId, HandledReason, HandledBy)), 0) AS VARCHAR(12)) FROM Alert_User_Map;

INSERT INTO @T SELECT 'After the rollback: Users, User_Role / User_Department, Agenda and Alert_User_Map as before; the setting as before', 'same same same same same',
       CASE WHEN @UsersAfter = @UsersBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @HistAfter = @HistBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @AgendaAfter = @AgendaBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @MapAfter = @MapBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN ISNULL((SELECT SettingValue FROM App_Setting WHERE SettingCode = 'DeptNoManagerAction'), '') = ISNULL(@SettingBefore, '') THEN 'same' ELSE 'DIFFERENT' END;

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
SELECT 'After the test: no ZZ53 department, user, committee, meeting or item left', '0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ53%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz53%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z53', 'Z53B')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ53 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'Z53-%') AS VARCHAR(12));

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

DROP PROCEDURE #ZZ53_Backfill;
DROP PROCEDURE #ZZ53_Mails;
DROP PROCEDURE #ZZ53_Rows;
DROP PROCEDURE #ZZ53_Add;
DROP PROCEDURE #ZZ53_Edit;
DROP PROCEDURE #ZZ53_Save;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
