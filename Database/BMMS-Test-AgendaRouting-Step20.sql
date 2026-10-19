/* ============================================================================
   BMMS - Tests for BMMS-Fix-AgendaRouting-Step20.sql (step 20)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-AgendaRouting-Step20.sql, on the TEST COPY. It stops if
   step 20 is not installed.

   Creates its own department, users (Admin, two Controllers, an inactive
   Controller, two Managers, an inactive Manager, mgmt, md_sect and users with
   each kind of manager), two meetings and meeting members, and checks, through
   the real procedures, with made-up sample values only:
     * markers; steps 16, 17 and 18 texts kept; step 21 objects untouched
     * the route of each kind of creator (fn_AgendaRoute)
     * saving: manager step (AC), straight to the Controllers (AMA, manager
       fields empty) for no manager, a Controller manager and a manager with
       another role; inactive manager (Reason 11), inactive creator (8), no
       active Controller (15); alert recipients; edits keep the status
     * the "agenda created" mail list per route
     * approve / reject: who may act at which stage (Reason 14), the system
       account (12), inactive or unknown acting user (8), finalized (5),
       unknown agenda (4), routed manager after a manager change, a Controller
       approving an item they created
     * the one-time re-route and its re-run
     * the signer order and the invitee list order
   No mail is sent: only database procedures run.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), '') NOT LIKE '%AgendaRouting-Step20%')
BEGIN
    RAISERROR('The agenda routing (step 20) is not installed in "%s". Run BMMS-Fix-AgendaRouting-Step20.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));
DECLARE @ML TABLE (Route CHAR(1), ManagerName NVARCHAR(200), ActiveControllers INT, EmailId VARCHAR(200));
DECLARE @RR TABLE (Rerouted INT);
DECLARE @CS TABLE (Seq INT IDENTITY(1,1), CompanySecretary VARCHAR(200), DesignationName VARCHAR(200), MeetingMemberId INT);
DECLARE @CtlOn TABLE (UserId INT);

DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -7, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @E VARCHAR(10) = '';
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @AdminRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @MgrRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @UserRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @MgmtRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt');
DECLARE @MdRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect');
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @C INT;
DECLARE @Mem1 INT, @Mem2 INT, @Mem3 INT, @Mem4 INT;
SELECT @Mem1 = MIN(MemberId) FROM Member m WHERE EXISTS (SELECT 1 FROM Designation d WHERE d.DesignationId = m.DesignationId);
SELECT @Mem2 = MIN(MemberId) FROM Member m WHERE MemberId > @Mem1 AND EXISTS (SELECT 1 FROM Designation d WHERE d.DesignationId = m.DesignationId);
SELECT @Mem3 = MIN(MemberId) FROM Member m WHERE MemberId > @Mem2 AND EXISTS (SELECT 1 FROM Designation d WHERE d.DesignationId = m.DesignationId);

DECLARE @Dept INT, @Adm INT, @Ctl1 INT, @Ctl2 INT, @CtlOff INT, @Mgr INT, @Mgr2 INT, @MgrOff INT, @Mgmt INT, @MdSect INT;
DECLARE @UsrM INT, @UsrN INT, @UsrC INT, @UsrX INT, @UsrI INT, @UsrCI INT, @UsrOff INT;
DECLARE @Mt INT, @MtF INT, @Mt2 INT;
DECLARE @AgM INT, @AgN INT, @AgC INT, @AgX INT, @AgM2 INT, @AgM3 INT, @AgM4 INT, @AgM5 INT, @AgOwn INT, @AgFin INT;
DECLARE @AgEditAMR INT, @AgEditACA INT, @RA INT, @RB INT, @RC INT, @RD INT, @A INT;
DECLARE @ActiveAdmins INT, @ActiveCtrls INT, @Count INT, @Expected VARCHAR(400), @Missing INT;
DECLARE @MM1 INT, @MM2 INT, @MS1 INT, @MS2 INT;

IF (@Sys IS NULL OR @AdminRoleId IS NULL OR @CtrlRoleId IS NULL OR @MgrRoleId IS NULL OR @UserRoleId IS NULL
    OR @MgmtRoleId IS NULL OR @MdRoleId IS NULL OR @DesignationId IS NULL OR @SubjectTypeId IS NULL OR @Mem3 IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, a subject type or three members is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names and addresses)
    ---------------------------------------------------------------------------
    -- Own committee with a three-letter code: the agenda number is read by position
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z20', 'ZZ step 20 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();

    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ20', 'ZZ step 20 department', 999, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 admin', @Dept, @DesignationId, NULL, @AdminRoleId, 'zz20adm@example.invalid', 'zz20adm', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 controller 1', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz20ctl1@example.invalid', 'zz20ctl1', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 controller 2', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz20ctl2@example.invalid', 'zz20ctl2', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 inactive controller', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz20ctloff@example.invalid', 'zz20ctloff', 'not-a-login', 0, @Now, @Sys, @Now, @Sys);
    SET @CtlOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz20mgr@example.invalid', 'zz20mgr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 other manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz20mgr2@example.invalid', 'zz20mgr2', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Mgr2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 inactive manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz20mgroff@example.invalid', 'zz20mgroff', 'not-a-login', 0, @Now, @Sys, @Now, @Sys);
    SET @MgrOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 mgmt', @Dept, @DesignationId, NULL, @MgmtRoleId, 'zz20mgmt@example.invalid', 'zz20mgmt', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Mgmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 md sect', @Dept, @DesignationId, NULL, @MdRoleId, 'zz20md@example.invalid', 'zz20md', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @MdSect = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 user M', @Dept, @DesignationId, @Mgr, @UserRoleId, 'zz20usrm@example.invalid', 'zz20usrm', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @UsrM = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 user N', @Dept, @DesignationId, NULL, @UserRoleId, 'zz20usrn@example.invalid', 'zz20usrn', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @UsrN = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 user C', @Dept, @DesignationId, @Ctl1, @UserRoleId, 'zz20usrc@example.invalid', 'zz20usrc', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @UsrC = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 user X', @Dept, @DesignationId, @Mgmt, @UserRoleId, 'zz20usrx@example.invalid', 'zz20usrx', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @UsrX = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 user I', @Dept, @DesignationId, @MgrOff, @UserRoleId, 'zz20usri@example.invalid', 'zz20usri', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @UsrI = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 user CI', @Dept, @DesignationId, @CtlOff, @UserRoleId, 'zz20usrci@example.invalid', 'zz20usrci', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @UsrCI = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ20 inactive user', @Dept, @DesignationId, @Mgr, @UserRoleId, 'zz20usroff@example.invalid', 'zz20usroff', 'not-a-login', 0, @Now, @Sys, @Now, @Sys);
    SET @UsrOff = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99920', @C, 'ZZ20 test', 'ZZ', @Past, '10:00', 'Open', 'Open');
    SET @Mt = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99921', @C, 'ZZ20 test', 'ZZ', @Past, '10:00', 'Close', 'Open');
    SET @MtF = SCOPE_IDENTITY();
    -- Items inserted directly go to their own open meeting, so the numbering of the saved ones is not affected
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('99922', @C, 'ZZ20 test', 'ZZ', @Past, '10:00', 'Open', 'Open');
    SET @Mt2 = SCOPE_IDENTITY();

    SET @ActiveAdmins = (SELECT COUNT(*) FROM Users WHERE RoleId = @AdminRoleId AND AccountStatus = 1 AND IsSystem = 0);
    SET @ActiveCtrls = (SELECT COUNT(*) FROM Users WHERE RoleId = @CtrlRoleId AND AccountStatus = 1 AND IsSystem = 0);
    SET @Missing = (SELECT ISNULL(MAX(AgendaId), 0) + 1000 FROM Agenda);

    ---------------------------------------------------------------------------
    -- 1. Installation
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Markers: 7 objects carry AgendaRouting-Step20', '7',
           CAST(COUNT(*) AS VARCHAR(4)) FROM sys.sql_modules WHERE definition LIKE '%AgendaRouting-Step20%'
           AND object_id IN (OBJECT_ID('dbo.fn_AgendaRoute'), OBJECT_ID('dbo.spr_GetAgendaCreationMailId'), OBJECT_ID('dbo.spr_AddEditAgenda'),
                             OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'), OBJECT_ID('dbo.spr_RerouteWaitingAgendas'),
                             OBJECT_ID('dbo.spr_GetCompanySecretary'), OBJECT_ID('dbo.spr_GetMeetingMemberByMeetingIdMemberTypeId'));
    INSERT INTO @T SELECT 'Both agenda procedures keep the steps 16, 17 and 18 texts', '2',
           CAST(COUNT(*) AS VARCHAR(4)) FROM sys.sql_modules
           WHERE definition LIKE '%MeetingLocks-Step16%' AND definition LIKE '%UserStatus2b-Step17%' AND definition LIKE '%SystemAccount3-Step18%'
           AND object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'));
    INSERT INTO @T SELECT 'Step 21 objects untouched (meeting member save, Reset Database)', '2 0',
           CAST(SUM(CASE WHEN definition LIKE '%MemberTypes-Step21%' THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN definition LIKE '%AgendaRouting-Step20%' THEN 1 ELSE 0 END) AS VARCHAR(4))
           FROM sys.sql_modules WHERE object_id IN (OBJECT_ID('dbo.spr_AddEditMeetingMember'), OBJECT_ID('dbo.spr_sys_ResetDatabase'));

    ---------------------------------------------------------------------------
    -- 2. Routes
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Route: manager / none / Controller / mgmt / inactive manager / inactive Controller', 'M C C C I I',
           (SELECT Route FROM dbo.fn_AgendaRoute(@UsrM)) + ' ' + (SELECT Route FROM dbo.fn_AgendaRoute(@UsrN)) + ' '
         + (SELECT Route FROM dbo.fn_AgendaRoute(@UsrC)) + ' ' + (SELECT Route FROM dbo.fn_AgendaRoute(@UsrX)) + ' '
         + (SELECT Route FROM dbo.fn_AgendaRoute(@UsrI)) + ' ' + (SELECT Route FROM dbo.fn_AgendaRoute(@UsrCI));
    INSERT INTO @T SELECT 'Route: active Controllers counted (system account and inactive left out)', CAST(@ActiveCtrls AS VARCHAR(12)),
           CAST((SELECT ActiveControllers FROM dbo.fn_AgendaRoute(@UsrN)) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 3. Saving (spr_AddEditAgenda)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 M', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrM, @UpdatedOn = @Now, @UpdatedBy = @UsrM, @SubjectNo = NULL, @ActingUserId = @UsrM;
    SET @AgM = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UsrM);
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgM);
    INSERT INTO @T SELECT 'Save, active Manager: waits for the manager', 'Result 1, Reason 0; AC',
           (SELECT Txt FROM @R) + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM), 'none');
    INSERT INTO @T SELECT 'Save, active Manager: alert to the Admins and the manager, no Controller (unchanged)',
           'AC; admins ' + CAST(@ActiveAdmins AS VARCHAR(12)) + ', manager 1, controllers 0',
           ISNULL((SELECT AlertTypeCode FROM Alert_Master WHERE AlertId = @A), 'none') + '; admins '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.RoleId = @AdminRoleId) AS VARCHAR(12))
         + ', manager ' + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Mgr) AS VARCHAR(12))
         + ', controllers ' + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.RoleId = @CtrlRoleId) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 N', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrN, @UpdatedOn = @Now, @UpdatedBy = @UsrN, @SubjectNo = NULL, @ActingUserId = @UsrN;
    SET @AgN = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UsrN);
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgN);
    INSERT INTO @T SELECT 'Save, no manager: straight to the Controllers, manager fields empty', 'Result 1, Reason 0; AMA; empty',
           (SELECT Txt FROM @R) + '; ' + ISNULL((SELECT AgendaStatusCode + '; ' + CASE WHEN ISNULL(MgrApprovedStatus, '') = '' AND ISNULL(CAST(MgrComments AS VARCHAR(10)), '') = ''
                                                  AND MgrApprovedBy IS NULL THEN 'empty' ELSE 'set' END FROM Agenda WHERE AgendaId = @AgN), 'none');
    INSERT INTO @T SELECT 'Save, no manager: alert AMA to the active Admins and Controllers only',
           'AMA; admins ' + CAST(@ActiveAdmins AS VARCHAR(12)) + ', controllers ' + CAST(@ActiveCtrls AS VARCHAR(12)) + ', others 0',
           ISNULL((SELECT AlertTypeCode FROM Alert_Master WHERE AlertId = @A), 'none') + '; admins '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.RoleId = @AdminRoleId AND u.AccountStatus = 1) AS VARCHAR(12))
         + ', controllers ' + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.RoleId = @CtrlRoleId AND u.AccountStatus = 1) AS VARCHAR(12))
         + ', others ' + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A
                               AND NOT (u.RoleId IN (@AdminRoleId, @CtrlRoleId) AND u.AccountStatus = 1 AND u.IsSystem = 0)) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 C', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrC, @UpdatedOn = @Now, @UpdatedBy = @UsrC, @SubjectNo = NULL, @ActingUserId = @UsrC;
    SET @AgC = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UsrC);
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgC);
    INSERT INTO @T SELECT 'Save, manager is a Controller: AMA, both test Controllers alerted, the inactive one not', 'Result 1, Reason 0; AMA; 1 1 0',
           (SELECT Txt FROM @R) + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgC), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Ctl1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Ctl2) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @CtlOff) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 X', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrX, @UpdatedOn = @Now, @UpdatedBy = @UsrX, @SubjectNo = NULL, @ActingUserId = @UsrX;
    SET @AgX = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UsrX);
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgX);
    INSERT INTO @T SELECT 'Save, manager has another role (mgmt): AMA, that manager not alerted', 'Result 1, Reason 0; AMA; 0',
           (SELECT Txt FROM @R) + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgX), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Mgmt) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 I', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrI, @UpdatedOn = @Now, @UpdatedBy = @UsrI, @SubjectNo = NULL, @ActingUserId = @UsrI;
    INSERT INTO @T SELECT 'Save, manager inactive: refused (unchanged), no item', 'Result 0, Reason 11, ZZ20 inactive manager; 0',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Agenda WHERE CreatedBy = @UsrI) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 CI', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrCI, @UpdatedOn = @Now, @UpdatedBy = @UsrCI, @SubjectNo = NULL, @ActingUserId = @UsrCI;
    INSERT INTO @T SELECT 'Save, manager an inactive Controller: refused, no item', 'Result 0, Reason 11, ZZ20 inactive controller; 0',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Agenda WHERE CreatedBy = @UsrCI) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 off', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrOff, @UpdatedOn = @Now, @UpdatedBy = @UsrOff, @SubjectNo = NULL, @ActingUserId = @UsrOff;
    INSERT INTO @T SELECT 'Save by an inactive user: refused first (Reason 8)', 'Result 0, Reason 8', Txt FROM @R;

    -- No active Controller (rolled back): the Controller route is refused, the manager route is not
    INSERT INTO @CtlOn (UserId) SELECT UserId FROM Users WHERE RoleId = @CtrlRoleId AND AccountStatus = 1;
    UPDATE Users SET AccountStatus = 0 WHERE UserId IN (SELECT UserId FROM @CtlOn);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 N none', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrN, @UpdatedOn = @Now, @UpdatedBy = @UsrN, @SubjectNo = NULL, @ActingUserId = @UsrN;
    INSERT INTO @T SELECT 'Save, no manager and no active Controller: refused, no item', 'Result 0, Reason 15; 0',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Agenda WHERE CreatedBy = @UsrN AND ShortText = 'ZZ20 N none') AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 M none', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrM, @UpdatedOn = @Now, @UpdatedBy = @UsrM, @SubjectNo = NULL, @ActingUserId = @UsrM;
    INSERT INTO @T SELECT 'Save, active Manager while no Controller is active: saved (AC)', 'Result 1, Reason 0; AC',
           (SELECT Txt FROM @R) + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE CreatedBy = @UsrM AND ShortText = 'ZZ20 M none'), 'none');

    UPDATE Users SET AccountStatus = 1 WHERE UserId IN (SELECT UserId FROM @CtlOn);

    -- Edits keep the status and the approval fields exactly as they are
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgN, @AgendaNo = 'ZZ', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 N edited', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrN, @UpdatedOn = @Now, @UpdatedBy = @UsrN, @SubjectNo = NULL, @ActingUserId = @UsrN;
    INSERT INTO @T SELECT 'Edit by the user before the Controller decides (AMA): saved, still AMA', 'Result 1, Reason 0; AMA',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgN);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgM, @AgendaNo = 'ZZ', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 M edited', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrM, @UpdatedOn = @Now, @UpdatedBy = @UsrM, @SubjectNo = NULL, @ActingUserId = @UsrM;
    INSERT INTO @T SELECT 'Edit of an item waiting for the manager: still AC', 'Result 1, Reason 0; AC',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM);

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, MgrApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z20-99922-090', @C, @Mt2, @Dept, @SubjectTypeId, 'ZZ20 rejected', 'Entry', 'ZZ', 'ZZ', 'AMR', 'Rejected', @Now, @UsrN);
    SET @AgEditAMR = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z20-99922-091', @C, @Mt2, @Dept, @SubjectTypeId, 'ZZ20 approved', 'Entry', 'ZZ', 'ZZ', 'ACA', 'Approved', @Now, @UsrN);
    SET @AgEditACA = SCOPE_IDENTITY();
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgEditAMR, @AgendaNo = 'Z20-99922-090', @CommitteeId = @C, @MeetingId = @Mt2,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 rejected edited', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrN, @UpdatedOn = @Now, @UpdatedBy = @UsrN, @SubjectNo = NULL, @ActingUserId = @UsrN;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgEditACA, @AgendaNo = 'Z20-99922-091', @CommitteeId = @C, @MeetingId = @Mt2,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 approved edited', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrN, @UpdatedOn = @Now, @UpdatedBy = @UsrN, @SubjectNo = NULL, @ActingUserId = @UsrN;
    INSERT INTO @T SELECT 'Edit of a rejected (AMR) and an approved (ACA) item: status and decision fields unchanged', 'AMR Rejected; ACA Approved',
           (SELECT AgendaStatusCode + ' ' + ISNULL(MgrApprovedStatus, 'NULL') FROM Agenda WHERE AgendaId = @AgEditAMR) + '; '
         + (SELECT AgendaStatusCode + ' ' + ISNULL(ControllerApprovedStatus, 'NULL') FROM Agenda WHERE AgendaId = @AgEditACA);

    ---------------------------------------------------------------------------
    -- 4. "Agenda created" mail list (spr_GetAgendaCreationMailId)
    ---------------------------------------------------------------------------
    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAgendaCreationMailId @UserId = @UsrM;
    INSERT INTO @T SELECT 'Mail list, manager route: the manager only', 'M 1 zz20mgr@example.invalid',
           ISNULL(MAX(Route), '-') + ' ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + ISNULL(MAX(EmailId), 'none') FROM @ML;
    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAgendaCreationMailId @UserId = @UsrN;
    INSERT INTO @T SELECT 'Mail list, Controller route: active Controllers, not the inactive one, the Admin or the creator', 'C 1 1 0 0 0',
           ISNULL(MAX(Route), '-') + ' '
         + CAST(SUM(CASE WHEN EmailId = 'zz20ctl1@example.invalid' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' '
         + CAST(SUM(CASE WHEN EmailId = 'zz20ctl2@example.invalid' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' '
         + CAST(SUM(CASE WHEN EmailId = 'zz20ctloff@example.invalid' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' '
         + CAST(SUM(CASE WHEN EmailId = 'zz20adm@example.invalid' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' '
         + CAST(SUM(CASE WHEN EmailId = 'zz20usrn@example.invalid' THEN 1 ELSE 0 END) AS VARCHAR(12)) FROM @ML;
    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAgendaCreationMailId @UserId = @UsrI;
    INSERT INTO @T SELECT 'Mail list, inactive manager: route I with the name, no address', 'I ZZ20 inactive manager 1 0',
           ISNULL(MAX(Route), '-') + ' ' + ISNULL(MAX(CAST(ManagerName AS VARCHAR(200))), '') + ' ' + CAST(COUNT(*) AS VARCHAR(12)) + ' '
         + CAST(COUNT(EmailId) AS VARCHAR(12)) FROM @ML;

    ---------------------------------------------------------------------------
    -- 5. Approve / reject (spr_UpdateAgendaByAgendaId): refusals first, nothing changes
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr2;
    INSERT INTO @T SELECT 'Another Manager (not routed, not the creator''s) approves at AC: refused', 'Result 0, Reason 14, Agenda Creation; AC',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl1;
    INSERT INTO @T SELECT 'Controller approves at AC: refused', 'Result 0, Reason 14, Agenda Creation; AC',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = @E, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Admin "Approve" (nothing to approve, the old button): refused, not a silent success', 'Result 0, Reason 14, Agenda Creation', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Approved', @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Admin approves as Manager: refused', 'Result 0, Reason 14, Agenda Creation', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Rejected', @UpdatedBy = @Mgmt;
    INSERT INTO @T SELECT 'mgmt rejects as Manager: refused', 'Result 0, Reason 14, Agenda Creation', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgN, @ShortText = 'ZZ20 N', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @MdSect;
    INSERT INTO @T SELECT 'md_sect approves as Controller at AMA: refused', 'Result 0, Reason 14, Manager Approved', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgN, @ShortText = 'ZZ20 N', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'System account approves: refused first (Reason 12, unchanged)', 'Result 0, Reason 12', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgN, @ShortText = 'ZZ20 N', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @CtlOff;
    INSERT INTO @T SELECT 'Inactive Controller approves: refused (Reason 8)', 'Result 0, Reason 8', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgN, @ShortText = 'ZZ20 N', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = 0;
    INSERT INTO @T SELECT 'Unknown acting user: refused (Reason 8)', 'Result 0, Reason 8', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgN, @ShortText = 'ZZ20 N', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Ctl1;
    INSERT INTO @T SELECT 'Manager and Controller decision in one call: refused', 'Result 0, Reason 14, Manager Approved', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @Missing, @ShortText = 'ZZ', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl1;
    INSERT INTO @T SELECT 'Unknown agenda item: refused (Reason 4)', 'Result 0, Reason 4', Txt FROM @R;
    INSERT INTO @T SELECT 'After the refusals: items unchanged, no audit row by the refused users', 'AC AMA 0',
           (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM) + ' ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgN) + ' '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Update_By IN (@Mgr2, @Adm, @Mgmt, @MdSect, @CtlOff, @Ctl1) AND Update_On >= @Now) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 6. Approve / reject: what is allowed
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    SET @A = (SELECT MAX(AlertId) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgM);
    INSERT INTO @T SELECT 'The routed Manager approves at AC: AMA, the Controllers alerted (unchanged)', 'Result 1, Reason 0; AMA Approved; 1',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode + ' ' + ISNULL(MgrApprovedStatus, 'NULL') FROM Agenda WHERE AgendaId = @AgM) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Ctl1) AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    INSERT INTO @T SELECT 'The Manager approves again (AMA): refused', 'Result 0, Reason 14, Manager Approved', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl1;
    INSERT INTO @T SELECT 'Controller approves at AMA: ACA', 'Result 1, Reason 0; ACA',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM, @ShortText = 'ZZ20 M', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = 'no', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl2;
    INSERT INTO @T SELECT 'Controller rejects an item already approved (ACA): refused', 'Result 0, Reason 14, Controller Approved; ACA',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgN, @ShortText = 'ZZ20 N', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl1;
    INSERT INTO @T SELECT 'Controller approves a no-manager item (skipped manager step): ACA, manager fields still empty', 'Result 1, Reason 0; ACA; empty',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode + '; ' + CASE WHEN ISNULL(MgrApprovedStatus, '') = '' THEN 'empty' ELSE 'set' END FROM Agenda WHERE AgendaId = @AgN);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgC, @ShortText = 'ZZ20 C', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'no', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl2;
    INSERT INTO @T SELECT 'Another Controller rejects the item of a user whose manager is a Controller: ACR', 'Result 1, Reason 0; ACR',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgC);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 M2', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrM, @UpdatedOn = @Now, @UpdatedBy = @UsrM, @SubjectNo = NULL, @ActingUserId = @UsrM;
    SET @AgM2 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UsrM);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM2, @ShortText = 'ZZ20 M2', @ProposedResolution = 'ZZ',
         @MgrComments = 'no', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Rejected', @UpdatedBy = @Mgr;
    INSERT INTO @T SELECT 'The routed Manager rejects at AC: AMR', 'Result 1, Reason 0; AMR',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM2);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 M3', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrM, @UpdatedOn = @Now, @UpdatedBy = @UsrM, @SubjectNo = NULL, @ActingUserId = @UsrM;
    SET @AgM3 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UsrM);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM3, @ShortText = 'ZZ20 M3', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'Agenda rejected by Controller on agenda finalized.', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl1;
    INSERT INTO @T SELECT 'Controller rejects an item still at AC (Agenda Finalization): ACR', 'Result 1, Reason 0; ACR',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM3);

    -- The creator's manager changes while an item waits (rolled back)
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 M4', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrM, @UpdatedOn = @Now, @UpdatedBy = @UsrM, @SubjectNo = NULL, @ActingUserId = @UsrM;
    SET @AgM4 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UsrM);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ20 M5', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrM, @UpdatedOn = @Now, @UpdatedBy = @UsrM, @SubjectNo = NULL, @ActingUserId = @UsrM;
    SET @AgM5 = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @UsrM);
    UPDATE Users SET ManagerId = @Mgr2 WHERE UserId = @UsrM;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM4, @ShortText = 'ZZ20 M4', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    INSERT INTO @T SELECT 'Manager change: the Manager the item was routed to may still approve', 'Result 1, Reason 0; AMA',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM4);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgM5, @ShortText = 'ZZ20 M5', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr2;
    INSERT INTO @T SELECT 'Manager change: the creator''s current Manager may approve too', 'Result 1, Reason 0; AMA',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgM5);
    UPDATE Users SET ManagerId = @Mgr WHERE UserId = @UsrM;

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z20-99922-092', @C, @Mt2, @Dept, @SubjectTypeId, 'ZZ20 own', 'Entry', 'ZZ', 'ZZ', 'AMA', @Now, @Ctl1);
    SET @AgOwn = SCOPE_IDENTITY();
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgOwn, @ShortText = 'ZZ20 own', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl1;
    INSERT INTO @T SELECT 'A Controller approves an AMA item they created: allowed', 'Result 1, Reason 0; ACA',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgOwn);

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z20-99921-001', @C, @MtF, @Dept, @SubjectTypeId, 'ZZ20 finalized', 'Entry', 'ZZ', 'ZZ', 'AMA', @Now, @UsrN);
    SET @AgFin = SCOPE_IDENTITY();
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgFin, @ShortText = 'ZZ20 finalized', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl1;
    INSERT INTO @T SELECT 'Agenda finalized: refused before the stage rule (Reason 5, unchanged)', 'Result 0, Reason 5, Finalized', Txt FROM @R;

    ---------------------------------------------------------------------------
    -- 7. One-time re-route (spr_RerouteWaitingAgendas)
    ---------------------------------------------------------------------------
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z20-99922-093', @C, @Mt2, @Dept, @SubjectTypeId, 'ZZ20 stuck', 'Entry', 'ZZ', 'ZZ', 'AC', @Now, @UsrN);
    SET @RA = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z20-99921-002', @C, @MtF, @Dept, @SubjectTypeId, 'ZZ20 stuck finalized', 'Entry', 'ZZ', 'ZZ', 'AC', @Now, @UsrN);
    SET @RB = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z20-99922-094', @C, @Mt2, @Dept, @SubjectTypeId, 'ZZ20 waits manager', 'Entry', 'ZZ', 'ZZ', 'AC', @Now, @UsrM);
    SET @RC = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z20-99922-095', @C, @Mt2, @Dept, @SubjectTypeId, 'ZZ20 waits inactive', 'Entry', 'ZZ', 'ZZ', 'AC', @Now, @UsrI);
    SET @RD = SCOPE_IDENTITY();
    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Agenda', @Dept, @RA, 'Agenda (Z20-99922-093)', 'AC', 3, @C, @Now, @UsrN);
    SET @A = SCOPE_IDENTITY();
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@A, @Adm, 1, 1);

    -- Every item the procedure should move: those above and any waiting in the copy's own data
    SET @Count = (SELECT COUNT(*) FROM Agenda a JOIN Meeting mt ON mt.MeetingId = a.MeetingId CROSS APPLY dbo.fn_AgendaRoute(a.CreatedBy) r
                  WHERE a.AgendaStatusCode = 'AC' AND ISNULL(mt.AgendaStatus, 'Open') = 'Open' AND r.Route = 'C' AND r.ActiveControllers > 0);

    DELETE FROM @RR; INSERT INTO @RR EXEC spr_RerouteWaitingAgendas;
    INSERT INTO @T SELECT 'Re-route: moves every waiting item of a creator without a manager step', CAST(@Count AS VARCHAR(12)),
           CAST(ISNULL((SELECT TOP 1 Rerouted FROM @RR), -1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Re-route: item and alert AMA, Controllers alerted unread, inactive Controller not, Admin row kept',
           'AMA AMA 1 1 0 1',
           (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @RA) + ' ' + (SELECT AlertTypeCode FROM Alert_Master WHERE AlertId = @A) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Ctl1 AND ReadStatus = 0) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Ctl2 AND ReadStatus = 0) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @CtlOff) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Adm) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Re-route leaves: finalized meeting, item waiting for an active Manager, inactive manager', 'AC AC AC',
           (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @RB) + ' ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @RC) + ' '
         + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @RD);
    INSERT INTO @T SELECT 'Re-route: manager fields empty, one audit row by the system account', 'empty 1',
           (SELECT CASE WHEN ISNULL(MgrApprovedStatus, '') = '' AND MgrApprovedBy IS NULL THEN 'empty' ELSE 'set' END FROM Agenda WHERE AgendaId = @RA) + ' '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = 'Z20-99922-093'
                 AND Field_Name = 'AgendaStatusCode' AND Old_Value = 'AC' AND New_Value = 'AMA' AND Update_By = @Sys) AS VARCHAR(12));
    DELETE FROM @RR; INSERT INTO @RR EXEC spr_RerouteWaitingAgendas;
    INSERT INTO @T SELECT 'Re-route run again: nothing moves, no duplicate alert row', '0 1',
           CAST(ISNULL((SELECT TOP 1 Rerouted FROM @RR), -1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Ctl1) AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @RA, @ShortText = 'ZZ20 stuck', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl2;
    INSERT INTO @T SELECT 'A re-routed item can be approved by a Controller', 'Result 1, Reason 0; ACA',
           (SELECT Txt FROM @R) + '; ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @RA);

    ---------------------------------------------------------------------------
    -- 8. The signer and the invitee list
    ---------------------------------------------------------------------------
    -- Two In Attendance members: the first tagged (lower MeetingMemberId) was saved with the later CreatedOn
    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy) VALUES (@Mt, @Mem1, 3, 1, DATEADD(DAY, 1, @Now), @Sys);
    SET @MM1 = SCOPE_IDENTITY();
    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy) VALUES (@Mt, @Mem2, 3, 1, DATEADD(DAY, -1, @Now), @Sys);
    SET @MM2 = SCOPE_IDENTITY();
    -- @CS keeps numbering after a DELETE (identity): the first row is the lowest Seq, not Seq 1
    DELETE FROM @CS; INSERT INTO @CS (CompanySecretary, DesignationName, MeetingMemberId) EXEC spr_GetCompanySecretary @MeetingId = @Mt;
    SET @Expected = (SELECT MemberName FROM Member WHERE MemberId = @Mem1);
    INSERT INTO @T SELECT 'Signer: both In Attendance members listed, the first tagged first (not by CreatedOn)', '2 ' + @Expected,
           CAST(COUNT(*) AS VARCHAR(12)) + ' ' + ISNULL((SELECT TOP 1 CompanySecretary FROM @CS ORDER BY Seq), 'none') FROM @CS;
    UPDATE Meeting_Member SET StatusId = 0 WHERE MeetingMemberId = @MM1;
    DELETE FROM @CS; INSERT INTO @CS (CompanySecretary, DesignationName, MeetingMemberId) EXEC spr_GetCompanySecretary @MeetingId = @Mt;
    INSERT INTO @T SELECT 'Signer: an inactive (StatusId 0) row is still listed first, as the other member lists do', '2 ' + @Expected,
           CAST(COUNT(*) AS VARCHAR(12)) + ' ' + ISNULL((SELECT TOP 1 CompanySecretary FROM @CS ORDER BY Seq), 'none') FROM @CS;
    DELETE FROM @CS; INSERT INTO @CS (CompanySecretary, DesignationName, MeetingMemberId) EXEC spr_GetCompanySecretary @MeetingId = @MtF;
    INSERT INTO @T SELECT 'Signer: a meeting without an In Attendance member returns no row', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM @CS;

    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy) VALUES (@Mt, @Mem3, 6, 1, DATEADD(DAY, 1, @Now), @Sys);
    SET @MS1 = SCOPE_IDENTITY();
    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy) VALUES (@Mt, @Mem2, 6, 1, DATEADD(DAY, -1, @Now), @Sys);
    SET @MS2 = SCOPE_IDENTITY();
    -- Capture table shaped like the view; Seq numbers the rows in the order the procedure returns them
    IF (OBJECT_ID('tempdb..#MMT') IS NOT NULL)
        DROP TABLE #MMT;
    -- (UNION ALL: the copy must not inherit the identity of MeetingMemberId)
    SELECT TOP 0 * INTO #MMT FROM View_Meeting_Member UNION ALL SELECT TOP 0 * FROM View_Meeting_Member;
    ALTER TABLE #MMT ADD Seq INT IDENTITY(1,1);
    INSERT INTO #MMT EXEC spr_GetMeetingMemberByMeetingIdMemberTypeId @MeetingId = @Mt, @MemberTypeId = 6;
    INSERT INTO @T SELECT 'Special Invitee list: in the order tagged (not by CreatedOn)', CAST(@MS1 AS VARCHAR(12)) + ',' + CAST(@MS2 AS VARCHAR(12)),
           ISNULL(STUFF((SELECT ',' + CAST(MeetingMemberId AS VARCHAR(12)) FROM #MMT ORDER BY Seq
                         FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), 'none');

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
       SUM(CASE WHEN Actual <> 'SKIPPED' AND (Actual <> Expected OR Actual IS NULL) THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM @T;

-- Confirm nothing was kept: should be 0, 0, 0 and 0
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz20%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Meeting WHERE MeetingNo IN ('99920', '99921', '99922') AND Place = 'ZZ20 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode = 'ZZ20') AS TestDepartmentsLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z20' AND CommitteeName = 'ZZ step 20 committee') AS TestCommitteesLeft;
GO

SET NOEXEC OFF;
GO
