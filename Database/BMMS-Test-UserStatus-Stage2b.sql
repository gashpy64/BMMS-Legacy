/* ============================================================================
   BMMS - Tests for BMMS-Fix-UserStatus-Stage2b.sql (step 17)
   ----------------------------------------------------------------------------
   Run AFTER BMMS-Fix-UserStatus-Stage2b.sql, on the TEST COPY. It stops if
   step 17 is not installed.

   Creates its own department, users (active and inactive Controller, Admin,
   Manager and Users), committees, meetings, agenda items, minutes and action
   items and checks, through the real procedures:
     * markers of steps 6, 8, 15, 16 and 17 in the replaced procedures
     * committee and meeting alerts (create, update, refused update)
     * agenda by a User (manager active, inactive: Reason 11, none: NULL),
       by a Manager, by the Controller; Reason 8 before Reason 11
     * approve / reject by Manager and Controller with an active and an
       inactive creator; saved rows of inactive users kept
     * minutes finalize and minutes update (late action item: creator
       active, inactive -> the active Controllers)
     * spr_GetAlertMailId for AMR, AMA, ACA and an unknown code
     * the last active Controller / Admin cannot be deactivated, a manager
       approval still reaches the only active Controller, a re-activated user
       gets no back-fill but the next alert

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), '') NOT LIKE '%UserStatus2b-Step17%')
BEGIN
    RAISERROR('User status stage 2b (step 17) is not installed in "%s". Run BMMS-Fix-UserStatus-Stage2b.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(120), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));
DECLARE @ML TABLE (EmailId VARCHAR(100));
DECLARE @TU TABLE (UserId INT PRIMARY KEY);

DECLARE @Now DATETIME = GETDATE();
DECLARE @MDate DATETIME = DATEADD(DAY, -10, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @E VARCHAR(10) = '';

DECLARE @Admin INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 ORDER BY u.UserId);
DECLARE @AdminRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @MgrRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @UserRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DecisionOther INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);
DECLARE @HasFollowup INT = CASE WHEN EXISTS (SELECT 1 FROM Decision_Type WHERE DecisionTypeId = 1) THEN 1 ELSE 0 END;

DECLARE @Dept INT;
DECLARE @CtlA INT, @CtlOff INT, @AdmOff INT, @MgrA INT, @MgrOff INT, @UsrA INT, @UsrB INT, @UsrC INT, @DepA INT, @DepOff INT, @UsrOff INT;
DECLARE @C INT, @C2 INT, @Mt INT, @MtF INT, @MtU INT, @MtO INT;
DECLARE @AgA INT, @AgB INT, @AgC INT, @AgM INT, @AgK INT, @AgS INT;
DECLARE @AgOff1 INT, @AgOff2 INT, @AgOff3 INT, @AgOff4 INT;
DECLARE @AgF1 INT, @AgF2 INT, @AgU1 INT, @AgU2 INT, @AgU3 INT;
DECLARE @MinF1 INT, @MinF2 INT, @MinU1 INT, @MinU2 INT, @MinU3 INT;
DECLARE @AI2 INT, @AISaved INT;
DECLARE @A INT, @ACC INT, @ACU INT, @AMC INT, @AMU INT, @AOff3 INT, @SavedRow INT;
DECLARE @Rows INT, @Rows2 INT;
DECLARE @ActiveAdmins INT, @ActiveCtrls INT;

-- Step 18: the protected system account (NULL before step 18). It gets no workflow alerts, so the
-- counts of recipients below leave it out, and its own refusals are Reason 7
DECLARE @SystemUser INT;
IF (COL_LENGTH('dbo.Users', 'IsSystem') IS NOT NULL)
    EXEC sp_executesql N'SELECT @id = UserId FROM dbo.Users WHERE IsSystem = 1', N'@id INT OUTPUT', @id = @SystemUser OUTPUT;
DECLARE @Note18 VARCHAR(40) = CASE WHEN @SystemUser IS NOT NULL THEN ' [step 18: not the system account]' ELSE '' END;

IF (@Admin IS NULL OR @AdminRoleId IS NULL OR @CtrlRoleId IS NULL OR @MgrRoleId IS NULL OR @UserRoleId IS NULL
    OR @DesignationId IS NULL OR @SubjectTypeId IS NULL OR @DecisionOther IS NULL OR @HasFollowup = 0)
BEGIN
    INSERT INTO @T VALUES ('An active Admin, a role, designation, subject type or decision type (Followup = 1 and another) is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures: one department holding every test user
    --   active:   CtlA, MgrA, UsrA (manager MgrA), UsrB (manager MgrOff), UsrC (no manager), DepA
    --   inactive: CtlOff, AdmOff, MgrOff, DepOff, UsrOff (manager MgrOff)
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ17', 'ZZ step 17 department', 999, 1, @Now, @Admin);
    SET @Dept = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 controller', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz17ctla@example.invalid', 'zz17ctla', 'not-a-login', 1, @Now, @Admin, @Now, @Admin);
    SET @CtlA = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 inactive controller', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz17ctloff@example.invalid', 'zz17ctloff', 'not-a-login', 0, @Now, @Admin, @Now, @Admin);
    SET @CtlOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 inactive admin', @Dept, @DesignationId, NULL, @AdminRoleId, 'zz17admoff@example.invalid', 'zz17admoff', 'not-a-login', 0, @Now, @Admin, @Now, @Admin);
    SET @AdmOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz17mgra@example.invalid', 'zz17mgra', 'not-a-login', 1, @Now, @Admin, @Now, @Admin);
    SET @MgrA = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 inactive manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz17mgroff@example.invalid', 'zz17mgroff', 'not-a-login', 0, @Now, @Admin, @Now, @Admin);
    SET @MgrOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 user A', @Dept, @DesignationId, @MgrA, @UserRoleId, 'zz17usra@example.invalid', 'zz17usra', 'not-a-login', 1, @Now, @Admin, @Now, @Admin);
    SET @UsrA = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 user B', @Dept, @DesignationId, @MgrOff, @UserRoleId, 'zz17usrb@example.invalid', 'zz17usrb', 'not-a-login', 1, @Now, @Admin, @Now, @Admin);
    SET @UsrB = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 user C', @Dept, @DesignationId, NULL, @UserRoleId, 'zz17usrc@example.invalid', 'zz17usrc', 'not-a-login', 1, @Now, @Admin, @Now, @Admin);
    SET @UsrC = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 department user', @Dept, @DesignationId, @MgrA, @UserRoleId, 'zz17depa@example.invalid', 'zz17depa', 'not-a-login', 1, @Now, @Admin, @Now, @Admin);
    SET @DepA = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 inactive department user', @Dept, @DesignationId, @MgrA, @UserRoleId, 'zz17depoff@example.invalid', 'zz17depoff', 'not-a-login', 0, @Now, @Admin, @Now, @Admin);
    SET @DepOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ17 inactive user', @Dept, @DesignationId, @MgrOff, @UserRoleId, 'zz17usroff@example.invalid', 'zz17usroff', 'not-a-login', 0, @Now, @Admin, @Now, @Admin);
    SET @UsrOff = SCOPE_IDENTITY();

    INSERT INTO @TU VALUES (@CtlA), (@CtlOff), (@AdmOff), (@MgrA), (@MgrOff), (@UsrA), (@UsrB), (@UsrC), (@DepA), (@DepOff), (@UsrOff);

    SET @ActiveAdmins = (SELECT COUNT(*) FROM Users WHERE RoleId = 1 AND AccountStatus = 1 AND UserId <> ISNULL(@SystemUser, -1));
    SET @ActiveCtrls = (SELECT COUNT(*) FROM Users WHERE RoleId = 2 AND AccountStatus = 1);

    ---------------------------------------------------------------------------
    -- 1. Markers
    ---------------------------------------------------------------------------
    INSERT INTO @T
    SELECT 'Markers: UserStatus2b-Step17 in all 9 objects', '9', CAST(COUNT(*) AS VARCHAR(12))
    FROM (VALUES ('spr_AddEditCommittee'), ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'),
                 ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaByAgendaId'), ('spr_MinutesFinalizeByMeetingId'),
                 ('spr_UpdateMinutes'), ('spr_GetAlertMailId')) o(Name)
    WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UserStatus2b-Step17%';

    INSERT INTO @T
    SELECT 'Markers: MeetingLocks-Step16 kept in the 6 step-16 procedures', '6', CAST(COUNT(*) AS VARCHAR(12))
    FROM (VALUES ('spr_AddEditMeeting'), ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController'),
                 ('spr_UpdateAgendaByAgendaId'), ('spr_UpdateMinutes')) o(Name)
    WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%MeetingLocks-Step16%';

    INSERT INTO @T
    SELECT 'Markers: minutes finalize keeps MeetingLocks-Step15 and the step 8 check', '1 1',
           CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) LIKE '%MeetingLocks-Step15%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) LIKE '%NOT EXISTS (SELECT 1 FROM ActionItem_User_Map x%' THEN '1' ELSE '0' END;

    INSERT INTO @T
    SELECT 'Markers: minutes update keeps FK #5', '1',
           CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%FK #5%' THEN '1' ELSE '0' END;

    ---------------------------------------------------------------------------
    -- 2. Committee (alert to every other active user)
    ---------------------------------------------------------------------------
    EXEC spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'Z7A', @CommitteeName = 'ZZ step 17 committee',
         @Board = 0, @IncorporationDate = '2000-01-01', @MeetingStartNo = 1, @CommitteeColorCode = '#FFFFFF', @CessationDate = '',
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA;
    SET @C = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'Z7A');
    SET @ACC = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Committee' AND SourceTypeId = @C AND AlertTypeCode = 'CC' ORDER BY AlertId DESC);

    INSERT INTO @T SELECT 'Committee created: CC alert exists', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_Master WHERE AlertId = @ACC;
    INSERT INTO @T SELECT 'Committee CC: active test users other than the creator (5) mapped', '5',
           CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @ACC AND u.AccountStatus = 1;
    INSERT INTO @T SELECT 'Committee CC: inactive test users mapped', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @ACC AND u.AccountStatus <> 1;
    INSERT INTO @T SELECT 'Committee CC: inactive users anywhere in the alert', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @ACC AND u.AccountStatus <> 1;
    INSERT INTO @T SELECT 'Committee CC: creator not mapped', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map WHERE AlertId = @ACC AND UserId = @CtlA;

    EXEC spr_AddEditCommittee @Code = 'Update', @CommitteeId = @C, @CommitteeCode = 'Z7A', @CommitteeName = 'ZZ step 17 committee B',
         @Board = 0, @IncorporationDate = '2000-01-01', @MeetingStartNo = 1, @CommitteeColorCode = '#FFFFFF', @CessationDate = '',
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA;
    SET @ACU = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Committee' AND SourceTypeId = @C AND AlertTypeCode = 'CU' ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Committee CU: active test users / inactive users anywhere', '5 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @ACU AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @ACU AND u.AccountStatus <> 1) AS VARCHAR(12));

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z7B', 'ZZ step 17 other', '2000-01-01', 1, 0);
    SET @C2 = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- 3. Meeting
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99971', @CommitteeId = @C,
         @Place = 'ZZ', @Venue = 'ZZ', @MeetingDate = @MDate, @MeetingTime = '10:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Meeting created', 'Result 1, Reason 0', Txt FROM @R;
    SET @Mt = (SELECT MeetingId FROM Meeting WHERE CommitteeId = @C AND MeetingNo = '99971');
    SET @AMC = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @Mt AND AlertTypeCode = 'MC' ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Meeting MC: active test users / inactive test users', '5 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @AMC AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @AMC AND u.AccountStatus <> 1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Meeting MC: inactive users anywhere in the alert', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @AMC AND u.AccountStatus <> 1;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @Mt, @MeetingNo = '99971', @CommitteeId = @C,
         @Place = 'ZZ', @Venue = 'ZZ venue 2', @MeetingDate = @MDate, @MeetingTime = '11:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA;
    SET @AMU = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @Mt AND AlertTypeCode = 'MU' ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Meeting MU: saved; active test users / inactive users anywhere', 'Result 1, Reason 0; 5 0',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @AMU AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @AMU AND u.AccountStatus <> 1) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 4. Agenda by a User (spr_AddEditAgenda)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ17 user A', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrA, @UpdatedOn = @Now, @UpdatedBy = @UsrA, @SubjectNo = NULL, @ActingUserId = @UsrA;
    INSERT INTO @T SELECT 'Agenda by User, manager active: saved', 'Result 1, Reason 0', Txt FROM @R;
    SET @AgA = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @UsrA ORDER BY AgendaId DESC);
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgA ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Agenda by User, manager active: AC alert to the manager', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @MgrA;
    INSERT INTO @T SELECT 'Agenda by User, manager active: active Admins mapped / inactive Admin mapped' + @Note18, CAST(@ActiveAdmins AS VARCHAR(12)) + ' 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.RoleId = 1 AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @AdmOff) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Agenda by User, manager active: inactive users anywhere in the alert', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.AccountStatus <> 1;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ17 user B', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrB, @UpdatedOn = @Now, @UpdatedBy = @UsrB, @SubjectNo = NULL, @ActingUserId = @UsrB;
    INSERT INTO @T SELECT 'Agenda by User, manager inactive: refused', 'Result 0, Reason 11, ZZ17 inactive manager', Txt FROM @R;
    INSERT INTO @T SELECT 'Agenda by User, manager inactive: no agenda, alert or audit row', '0 0 0',
           CAST((SELECT COUNT(*) FROM Agenda WHERE CreatedBy = @UsrB) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_Master WHERE CreatedBy = @UsrB) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Update_By = @UsrB) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ17 inactive user', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrOff, @UpdatedOn = @Now, @UpdatedBy = @UsrOff, @SubjectNo = NULL, @ActingUserId = @UsrOff;
    INSERT INTO @T SELECT 'Agenda by inactive User with inactive manager: Reason 8 comes first', 'Result 0, Reason 8', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ17 user C', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrC, @UpdatedOn = @Now, @UpdatedBy = @UsrC, @SubjectNo = NULL, @ActingUserId = @UsrC;
    INSERT INTO @T SELECT 'Agenda by User, no manager (NULL): saved as before', 'Result 1, Reason 0', Txt FROM @R;
    SET @AgC = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @UsrC ORDER BY AgendaId DESC);
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgC ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Agenda by User, no manager: AC alert to the active Admins only' + @Note18, 'admins ' + CAST(@ActiveAdmins AS VARCHAR(12)) + ', others 0',
           'admins ' + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.RoleId = 1 AND u.AccountStatus = 1) AS VARCHAR(12))
         + ', others ' + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND NOT (u.RoleId = 1 AND u.AccountStatus = 1)) AS VARCHAR(12));

    -- An item UsrB saved before the manager was deactivated can still be edited
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z7A-99971-090', @C, @Mt, @Dept, @SubjectTypeId, 'ZZ17 B old', 'Entry', 'ZZ', 'ZZ', 'AC', @Now, @UsrB);
    SET @AgB = SCOPE_IDENTITY();
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgB, @AgendaNo = 'Z7A-99971-090', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ17 B edited', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrB, @UpdatedOn = @Now, @UpdatedBy = @UsrB, @SubjectNo = NULL, @ActingUserId = @UsrB;
    INSERT INTO @T SELECT 'Agenda by User, manager inactive: editing an existing item is allowed', 'Result 1, Reason 0; ZZ17 B edited',
           (SELECT Txt FROM @R) + '; ' + (SELECT ShortText FROM Agenda WHERE AgendaId = @AgB);

    ---------------------------------------------------------------------------
    -- 5. Agenda by a Manager and by the Controller (department of the test users)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ17 manager', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = 'ok', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @MgrA, @UpdatedOn = @Now, @UpdatedBy = @MgrA, @SubjectNo = NULL, @ActingUserId = @MgrA;
    INSERT INTO @T SELECT 'Agenda by Manager: saved', 'Result 1, Reason 0', Txt FROM @R;
    SET @AgM = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @MgrA ORDER BY AgendaId DESC);
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgM ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Agenda by Manager AMA: active test users (6) / inactive test users', '6 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.AccountStatus <> 1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Agenda by Manager AMA: active Controllers mapped / inactive users anywhere', CAST(@ActiveCtrls AS VARCHAR(12)) + ' 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.RoleId = 2 AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.AccountStatus <> 1) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ17 controller', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = 'ok', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA, @SubjectNo = NULL, @ActingUserId = @CtlA;
    INSERT INTO @T SELECT 'Agenda by Controller: saved', 'Result 1, Reason 0', Txt FROM @R;
    SET @AgK = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @CtlA ORDER BY AgendaId DESC);
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgK ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Agenda by Controller ACA: active test users (6) / inactive test users', '6 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.AccountStatus <> 1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Agenda by Controller ACA: inactive users anywhere in the alert', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.AccountStatus <> 1;

    -- A refused meeting edit (committee change with agenda items, Reason 10) still writes no alert
    SET @Rows = (SELECT COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @Mt);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @Mt, @MeetingNo = '99971', @CommitteeId = @C2,
         @Place = 'ZZ', @Venue = 'ZZ', @MeetingDate = @MDate, @MeetingTime = '10:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Meeting with agenda items: committee change refused, no alert written', 'Result 0, Reason 10, CommitteeId; ' + CAST(@Rows AS VARCHAR(12)),
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @Mt) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 6. Approve / reject (spr_UpdateAgendaByAgendaId) and alert mail (spr_GetAlertMailId)
    ---------------------------------------------------------------------------
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgA ORDER BY AlertId DESC);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = 'ZZ17 user A', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @MgrA;
    INSERT INTO @T SELECT 'Manager approves (creator active)', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Manager approves AMA: test Controller active / inactive mapped', '1 0',
           CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @CtlA) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @CtlOff) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Manager approves AMA: active creator mapped', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @UsrA;

    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAlertMailId @Code = 'AMA', @UserId = @MgrA, @AgendaId = @AgA;
    INSERT INTO @T SELECT 'Mail AMA: active / inactive test Controller address', '1 0',
           CAST((SELECT COUNT(*) FROM @ML WHERE EmailId = 'zz17ctla@example.invalid') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @ML WHERE EmailId = 'zz17ctloff@example.invalid') AS VARCHAR(12));
    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAlertMailId @Code = 'AMR', @UserId = @MgrA, @AgendaId = @AgA;
    INSERT INTO @T SELECT 'Mail AMR: active creator address', 'zz17usra@example.invalid', ISNULL((SELECT TOP 1 EmailId FROM @ML), 'none');

    -- A row an inactive user saved earlier on this alert (kept; never mailed)
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@A, @CtlOff, 1, 1);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = 'ZZ17 user A', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Controller approves ACA (creator active): creator has one unread row', 'Result 1, Reason 0; 1 0',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @UsrA) AS VARCHAR(12)) + ' '
         + CAST((SELECT MAX(ReadStatus) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @UsrA) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Controller approves ACA: saved row of the inactive Controller kept', '1',
           CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @CtlOff;

    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAlertMailId @Code = 'ACA', @UserId = @CtlA, @AgendaId = @AgA;
    INSERT INTO @T SELECT 'Mail ACA: mapped active Controller / mapped inactive Controller address', '1 0',
           CAST((SELECT COUNT(*) FROM @ML WHERE EmailId = 'zz17ctla@example.invalid') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @ML WHERE EmailId = 'zz17ctloff@example.invalid') AS VARCHAR(12));
    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAlertMailId @Code = 'XX', @UserId = @CtlA, @AgendaId = @AgA;
    INSERT INTO @T SELECT 'Mail with an unknown code: no addresses', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM @ML;

    -- Agenda items whose creator is now inactive (saved before the deactivation)
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z7A-99971-091', @C, @Mt, @Dept, @SubjectTypeId, 'ZZ17 off 1', 'Entry', 'ZZ', 'ZZ', 'AC', @Now, @UsrOff);
    SET @AgOff1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('Z7A-99971-092', @C, @Mt, @Dept, @SubjectTypeId, 'ZZ17 off 2', 'Entry', 'ZZ', 'ZZ', 'AC', @Now, @UsrOff);
    SET @AgOff2 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, MgrApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z7A-99971-093', @C, @Mt, @Dept, @SubjectTypeId, 'ZZ17 off 3', 'Entry', 'ZZ', 'ZZ', 'AMA', 'Approved', @Now, @UsrOff);
    SET @AgOff3 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, MgrApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z7A-99971-094', @C, @Mt, @Dept, @SubjectTypeId, 'ZZ17 off 4', 'Entry', 'ZZ', 'ZZ', 'AMA', 'Approved', @Now, @UsrOff);
    SET @AgOff4 = SCOPE_IDENTITY();

    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Agenda', @Dept, @AgOff1, 'Agenda (Z7A-99971-091)', 'AC', 3, @C, @Now, @UsrOff),
           ('Agenda', @Dept, @AgOff2, 'Agenda (Z7A-99971-092)', 'AC', 3, @C, @Now, @UsrOff),
           ('Agenda', @Dept, @AgOff3, 'Agenda (Z7A-99971-093)', 'AMA', 3, @C, @Now, @UsrOff),
           ('Agenda', @Dept, @AgOff4, 'Agenda (Z7A-99971-094)', 'AMA', 3, @C, @Now, @UsrOff);

    -- The creator's own saved rows on the first and third (kept)
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
    SELECT AlertId, @UsrOff, 1, 1 FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId IN (@AgOff1, @AgOff3);
    SET @AOff3 = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgOff3);
    SET @SavedRow = (SELECT AlertUserId FROM Alert_User_Map WHERE AlertId = @AOff3 AND UserId = @UsrOff);

    SET @Rows = (SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Alert_Master am ON am.AlertId = m.AlertId
                 WHERE am.SourceType = 'Agenda' AND am.SourceTypeId IN (@AgOff1, @AgOff2, @AgOff3, @AgOff4) AND u.AccountStatus <> 1);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgOff1, @ShortText = 'ZZ17 off 1', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @MgrA;
    SET @A = (SELECT AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgOff1);
    INSERT INTO @T SELECT 'Manager approves, creator inactive: creator rows (saved only) / test Controller active / inactive', 'Result 1, Reason 0; 1 1 0',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @UsrOff) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @CtlA) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @CtlOff) AS VARCHAR(12));
    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAlertMailId @Code = 'AMA', @UserId = @MgrA, @AgendaId = @AgOff1;
    INSERT INTO @T SELECT 'Mail AMA, creator inactive: creator address / active test Controller address', '0 1',
           CAST((SELECT COUNT(*) FROM @ML WHERE EmailId = 'zz17usroff@example.invalid') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @ML WHERE EmailId = 'zz17ctla@example.invalid') AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgOff2, @ShortText = 'ZZ17 off 2', @ProposedResolution = 'ZZ',
         @MgrComments = 'no', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Rejected', @UpdatedBy = @MgrA;
    INSERT INTO @T SELECT 'Manager rejects, creator inactive: done, no row for the creator, status AMR', 'Result 1, Reason 0; 0 AMR',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgOff2 AND m.UserId = @UsrOff) AS VARCHAR(12)) + ' '
         + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgOff2);
    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAlertMailId @Code = 'AMR', @UserId = @MgrA, @AgendaId = @AgOff2;
    INSERT INTO @T SELECT 'Mail AMR, creator inactive: no addresses', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM @ML;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgOff3, @ShortText = 'ZZ17 off 3', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = 'ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Controller approves, creator inactive: done, the saved row is the same row', 'Result 1, Reason 0; kept',
           (SELECT Txt FROM @R) + '; '
         + CASE WHEN (SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @AOff3 AND UserId = @UsrOff) = 1
                 AND EXISTS (SELECT 1 FROM Alert_User_Map WHERE AlertUserId = @SavedRow AND UserId = @UsrOff) THEN 'kept' ELSE 'changed' END;
    DELETE FROM @ML; INSERT INTO @ML EXEC spr_GetAlertMailId @Code = 'ACA', @UserId = @CtlA, @AgendaId = @AgOff3;
    INSERT INTO @T SELECT 'Mail ACA, creator inactive: the creator''s saved row is not mailed', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM @ML WHERE EmailId = 'zz17usroff@example.invalid';

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgOff4, @ShortText = 'ZZ17 off 4', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = 'no', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Controller rejects, creator inactive: done, no row for the creator, status ACR', 'Result 1, Reason 0; 0 ACR',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgOff4 AND m.UserId = @UsrOff) AS VARCHAR(12)) + ' '
         + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgOff4);

    INSERT INTO @T SELECT 'Approve / reject: rows of inactive users on these alerts unchanged in number', CAST(@Rows AS VARCHAR(12)),
           CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Alert_Master am ON am.AlertId = m.AlertId
           WHERE am.SourceType = 'Agenda' AND am.SourceTypeId IN (@AgOff1, @AgOff2, @AgOff3, @AgOff4) AND u.AccountStatus <> 1;

    ---------------------------------------------------------------------------
    -- 7. Minutes finalize: new action items mapped to active users only
    ---------------------------------------------------------------------------
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99972', @C, 'ZZ', 'ZZ', @MDate, '10:00', @MDate, 'Close', 'Open');
    SET @MtF = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z7A-99972-001', @C, @MtF, @Dept, @SubjectTypeId, 'ZZ17 F1', 'Entry', 'ZZ', 'ZZ', 'Approved', @Now, @UsrA);
    SET @AgF1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z7A-99972-002', @C, @MtF, @Dept, @SubjectTypeId, 'ZZ17 F2', 'Entry', 'ZZ', 'ZZ', 'Approved', @Now, @UsrA);
    SET @AgF2 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgF1, 1, 'ZZ dir', 'ZZ res', @Now, @CtlA, @Now, @CtlA);
    SET @MinF1 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgF2, 1, 'ZZ dir', 'ZZ res', @Now, @CtlA, @Now, @CtlA);
    SET @MinF2 = SCOPE_IDENTITY();
    -- F2 already has an action item, seen earlier by a user who is now inactive
    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy) VALUES (@MinF2, 'ZZ', '', '', @Now, @CtlA);
    SET @AI2 = SCOPE_IDENTITY();
    INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId) VALUES (@AI2, @UsrOff, 1, 1);
    SET @AISaved = SCOPE_IDENTITY();

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MtF, @UserId = @CtlA;
    INSERT INTO @T SELECT 'Minutes finalize: done', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Minutes finalize, new item: active test users (6) / inactive test users', '6 0',
           CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId
                 WHERE a.MinutesId = @MinF1 AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId
                 WHERE a.MinutesId = @MinF1 AND u.AccountStatus <> 1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Minutes finalize, new item: inactive users anywhere / all active users mapped' + @Note18, '0 ' + CAST((SELECT COUNT(*) FROM Users WHERE AccountStatus = 1 AND UserId <> ISNULL(@SystemUser, -1)) AS VARCHAR(12)),
           CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId JOIN Users u ON u.UserId = m.UserId
                 WHERE a.MinutesId = @MinF1 AND u.AccountStatus <> 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId JOIN Users u ON u.UserId = m.UserId
                 WHERE a.MinutesId = @MinF1 AND u.AccountStatus = 1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Minutes finalize, existing item: saved row of the inactive user kept / active test users added', 'kept 6',
           CASE WHEN EXISTS (SELECT 1 FROM ActionItem_User_Map WHERE ActionItemUserMapId = @AISaved AND UserId = @UsrOff AND ActionItemId = @AI2) THEN 'kept' ELSE 'gone' END + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN @TU t ON t.UserId = m.UserId JOIN Users u ON u.UserId = m.UserId WHERE m.ActionItemId = @AI2 AND u.AccountStatus = 1) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 8. Minutes update: an action item created on the Minutes Update page
    ---------------------------------------------------------------------------
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99973', @C, 'ZZ', 'ZZ', @MDate, '10:00', @MDate, 'Close', 'F');
    SET @MtU = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99974', @C, 'ZZ', 'ZZ', @MDate, '10:00', @MDate, 'Close', 'Open');
    SET @MtO = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z7A-99973-001', @C, @MtU, @Dept, @SubjectTypeId, 'ZZ17 U1', 'Entry', 'ZZ', 'ZZ', 'Approved', @Now, @UsrA);
    SET @AgU1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z7A-99973-002', @C, @MtU, @Dept, @SubjectTypeId, 'ZZ17 U2', 'Entry', 'ZZ', 'ZZ', 'Approved', @Now, @UsrOff);
    SET @AgU2 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z7A-99974-001', @C, @MtO, @Dept, @SubjectTypeId, 'ZZ17 U3', 'Entry', 'ZZ', 'ZZ', 'Approved', @Now, @UsrA);
    SET @AgU3 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgU1, @DecisionOther, 'ZZ dir', 'ZZ res', @Now, @CtlA, @Now, @CtlA);
    SET @MinU1 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgU2, @DecisionOther, 'ZZ dir', 'ZZ res', @Now, @CtlA, @Now, @CtlA);
    SET @MinU2 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgU3, @DecisionOther, 'ZZ dir', 'ZZ res', @Now, @CtlA, @Now, @CtlA);
    SET @MinU3 = SCOPE_IDENTITY();

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @MinU1, @DecisionTypeId = 1,
         @Directions = '', @ActualResolution = '', @ShortText = 'ZZ17 U1', @CreatedBy = @CtlA, @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Minutes F, follow-up added, creator active: done; rows / creator rows', 'Result 1, Reason 0; 1 1',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinU1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinU1 AND m.UserId = @UsrA) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @MinU2, @DecisionTypeId = 1,
         @Directions = '', @ActualResolution = '', @ShortText = 'ZZ17 U2', @CreatedBy = @CtlA, @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Minutes F, follow-up added, creator inactive: done and the item exists', 'Result 1, Reason 0; 1',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Action_Item WHERE MinutesId = @MinU2) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Minutes F, creator inactive: creator rows / active Controllers / test Controller / inactive users', '0 ' + CAST(@ActiveCtrls AS VARCHAR(12)) + ' 1 0',
           CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinU2 AND m.UserId = @UsrOff) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId JOIN Users u ON u.UserId = m.UserId
                 WHERE a.MinutesId = @MinU2 AND u.RoleId = 2 AND u.AccountStatus = 1) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinU2 AND m.UserId = @CtlA) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId JOIN Users u ON u.UserId = m.UserId
                 WHERE a.MinutesId = @MinU2 AND u.AccountStatus <> 1) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Minutes F, creator inactive: only Controllers mapped', '0',
           CAST(COUNT(*) AS VARCHAR(12)) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId JOIN Users u ON u.UserId = m.UserId
           WHERE a.MinutesId = @MinU2 AND u.RoleId <> 2;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @MinU3, @DecisionTypeId = 1,
         @Directions = '', @ActualResolution = '', @ShortText = 'ZZ17 U3', @CreatedBy = @CtlA, @UpdatedBy = @CtlA;
    INSERT INTO @T SELECT 'Minutes Open, follow-up added, creator active: mapped to the creator only', 'Result 1, Reason 0; 1 1',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinU3) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinU3 AND m.UserId = @UsrA) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 9. Sole recipients and re-activation
    ---------------------------------------------------------------------------
    -- Only CtlA left as active Controller (rolled back)
    UPDATE Users SET AccountStatus = 0 WHERE RoleId = 2 AND AccountStatus = 1 AND UserId <> @CtlA;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @CtlA, @AccountStatus = 0, @ActingUserId = @Admin;
    INSERT INTO @T SELECT 'Last active Controller: deactivation refused', 'Result 0, Reason 3', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ17 sole', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @UsrA, @UpdatedOn = @Now, @UpdatedBy = @UsrA, @SubjectNo = NULL, @ActingUserId = @UsrA;
    SET @AgS = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @UsrA AND ShortText = 'ZZ17 sole');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgS, @ShortText = 'ZZ17 sole', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @MgrA;
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgS ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Only active Controller: a manager approval reaches it, and no other Controller', 'Result 1, Reason 0; 1 0',
           (SELECT Txt FROM @R) + '; '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @CtlA) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE m.AlertId = @A AND u.RoleId = 2 AND m.UserId <> @CtlA) AS VARCHAR(12));

    -- Only @Admin left as active Admin: nobody else can deactivate it, and it cannot deactivate itself
    UPDATE Users SET AccountStatus = 0 WHERE RoleId = 1 AND AccountStatus = 1 AND UserId <> @Admin;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @Admin, @AccountStatus = 0, @ActingUserId = @Admin;
    -- Step 18: when that Admin is the protected system account both refusals are Reason 7
    INSERT INTO @T SELECT 'Last active Admin: deactivation refused (only it could act, own account)'
                          + CASE WHEN @Admin = ISNULL(@SystemUser, -1) THEN ' [step 18: system account, Reason 7]' ELSE '' END,
                          CASE WHEN @Admin = ISNULL(@SystemUser, -1) THEN 'Result 0, Reason 7' ELSE 'Result 0, Reason 1' END, Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @Admin, @AccountStatus = 0, @ActingUserId = @CtlA;
    INSERT INTO @T SELECT 'Last active Admin: deactivation by the Controller refused'
                          + CASE WHEN @Admin = ISNULL(@SystemUser, -1) THEN ' [step 18: system account, Reason 7]' ELSE '' END,
                          CASE WHEN @Admin = ISNULL(@SystemUser, -1) THEN 'Result 0, Reason 7' ELSE 'Result 0, Reason 4' END, Txt FROM @R;

    -- Re-activation: nothing missed is added, the next alert arrives
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @DepOff, @AccountStatus = 1, @ActingUserId = @Admin;
    INSERT INTO @T SELECT 'Re-activated user: no back-fill of the committee / meeting alerts', 'Result 1, Reason 0; 0',
           (SELECT Txt FROM @R) + '; ' + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE UserId = @DepOff AND AlertId IN (@ACC, @ACU, @AMC, @AMU)) AS VARCHAR(12));
    EXEC spr_AddEditCommittee @Code = 'Update', @CommitteeId = @C, @CommitteeCode = 'Z7A', @CommitteeName = 'ZZ step 17 committee C',
         @Board = 0, @IncorporationDate = '2000-01-01', @MeetingStartNo = 1, @CommitteeColorCode = '#FFFFFF', @CessationDate = '',
         @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @CtlA, @UpdatedOn = @Now, @UpdatedBy = @CtlA;
    SET @A = (SELECT TOP 1 AlertId FROM Alert_Master WHERE SourceType = 'Committee' AND SourceTypeId = @C AND AlertTypeCode = 'CU' ORDER BY AlertId DESC);
    INSERT INTO @T SELECT 'Re-activated user: receives the next alert', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @DepOff;

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

-- Confirm nothing was kept: should be 0 0 0
SELECT (SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z7A', 'Z7B')) AS TestCommitteesLeft,
       (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz17%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode = 'ZZ17') AS TestDepartmentsLeft;
GO

SET NOEXEC OFF;
GO
