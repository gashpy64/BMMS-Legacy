/* ============================================================================
   BMMS tester - fixture for BMMS_Quality (step WF3a1; committee QA2 added in
   step UN6b)
   ----------------------------------------------------------------------------
   Test data for the tester's database only. It is NOT a product step: it has no
   row in BMMS-Check-InstalledSteps.sql and must never run on BMMS or BMMS_Test.

   Run by Tests\_runner\Setup-Quality.ps1 (sqlcmd), after BMMS_Quality has been
   cleared with spr_sys_ResetDatabase. The setup script passes one sqlcmd
   variable per test account: the password hash made by the application's own
   Common.HashPassword (BMMSBAL). No password is in this file.

   Guards (nothing is changed when one stops the script)
     * the current database must be exactly BMMS_Quality;
     * the database must be in the cleared state: the four seeded users only,
       no qa_ account, no meeting.

   What it creates
     Accounts (created with spr_AddEditUser as the seeded Admin, so the role and
     department history rows of step 39 are written):
       qa_admin       Admin            Admin department
       qa_ctrl        Controller       Secretarial
       qa_manager     Manager          Credit
       qa_manager2    Manager          HRD (home) and Secretarial
       qa_user        User             Credit, manager qa_manager
       qa_user2       User             HRD, manager qa_manager2
       qa_mgmt        Management       Secretarial
       qa_mdsec       MD Secretariat   Secretarial
       qa_inactive    User             Credit; then made inactive (spr_SetUserStatusByUserId)
     Committee QA1 "QA Test Committee" with two members (Chairman, Member).
     Six meetings of QA1 (MeetingNo 00001 to 00006):
       00001 agenda open              items at AC, AMA, ACA, AMR and ACR; an HRD item at AC
       00002 submission date passed   agenda open, one item at AC
       00003 agenda finalised         meeting still to come, one approved item
       00004 minutes in Draft         meeting day passed, attendance entered
       00005 minutes Finalised        one Followup decision (an action item)
       00006 minutes Confirmed
     Committee QA2 "QA Dashboard Committee" (step UN6b, for the Dashboard's
     meeting list), twelve meetings and twelve agenda items:
       00001 dated today, submission today, agenda open, no items
             (scheduled until the end of the day, not "Minutes pending")
       00002 to 00012 eleven completed meetings (days -1 to -9, -11, -12):
             00002 agenda finalised, minutes Draft, a Credit item at ACA and
                   one at ACR
             00003 minutes Finalised, only a Secretarial item (ACA)
             00004 to 00012 minutes Confirmed, a Credit item at ACA each
       So every role's Completed list holds more than ten meetings where its
       scope allows it, and the cap of ten can be seen.

   How: the workflow is driven through the application's procedures, in the
   application's order (item saved by the User, approved or rejected by the
   Manager and the Controller, subject number, Agenda Finalisation, chairman,
   attendance, Update Minutes, Finalise, Confirm). The meeting rows themselves
   are inserted directly, as the repository's Test scripts do: spr_AddEditMeeting
   refuses a date before today, and four of the six meetings need a past date
   or a past submission date. BMMS-Quality-Fixture-Dates.sql sets the dates
   again after every restore, relative to that day.
   The QA2 meetings and their items are direct rows as well (eleven meetings in
   the past; their minutes status is set directly). The QA2 items have no
   minutes rows and no alerts, so the Minutes report and Followup are the same
   as without QA2. Saving committee QA2 with spr_AddEditCommittee writes its
   Committee alert, as for QA1: one more alert for every account except
   qa_ctrl, who saved it.

   Compatibility level 100. Plain ASCII. Safe to run once only (the guard
   refuses a second run).
   ============================================================================ */
SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO
DECLARE @CurrentDatabase SYSNAME;
SET @CurrentDatabase = DB_NAME();
IF (@CurrentDatabase COLLATE Latin1_General_BIN <> N'BMMS_Quality')
BEGIN
    RAISERROR('Current database is "%s". This fixture runs on BMMS_Quality only. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (EXISTS (SELECT 1 FROM Users WHERE LoginName LIKE 'qa[_]%')
         OR EXISTS (SELECT 1 FROM Meeting)
         OR (SELECT COUNT(*) FROM Users) <> 4
         OR NOT EXISTS (SELECT 1 FROM Users WHERE LoginName = 'admin' AND IsSystem = 1 AND AccountStatus = 1))
BEGIN
    RAISERROR('BMMS_Quality is not in the cleared state (four seeded users, no qa_ account, no meeting). Clear it first (Setup-Quality.ps1). Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
GO

DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @R1 TABLE (Result INT);
DECLARE @Step VARCHAR(200);
DECLARE @Err NVARCHAR(2048);
DECLARE @Why NVARCHAR(400);
DECLARE @Now DATETIME;
DECLARE @Today DATETIME;
DECLARE @Sys INT;
DECLARE @RoleAdmin INT, @RoleController INT, @RoleManager INT, @RoleUser INT, @RoleMgmt INT, @RoleMdSec INT;
DECLARE @DeptAdmin INT, @DeptSec INT, @DeptHrd INT, @DeptCredit INT;
DECLARE @Design INT;
DECLARE @QaAdmin INT, @QaController INT, @QaManager INT, @QaManager2 INT, @QaUser INT, @QaUser2 INT, @QaMgmt INT, @QaMdSec INT, @QaInactive INT;
DECLARE @DeptList VARCHAR(50);
DECLARE @C INT;
DECLARE @C2 INT;
DECLARE @TypeChairman INT, @TypeMember INT;
DECLARE @M1 INT, @M2 INT;
DECLARE @SubjectType INT;
DECLARE @DecisionFollowup INT, @DecisionOther INT;
DECLARE @Mt1 INT, @Mt2 INT, @Mt3 INT, @Mt4 INT, @Mt5 INT, @Mt6 INT;
DECLARE @Mt INT, @No INT, @Ag INT, @Min INT;
DECLARE @Title NVARCHAR(200);
DECLARE @Changed VARCHAR(400);

SET @Now = GETDATE();
SET @Today = DATEADD(DAY, DATEDIFF(DAY, 0, @Now), 0);

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Lookups in the cleared database (by code, never by a fixed id)
    ---------------------------------------------------------------------------
    SET @Step = 'lookups';
    SET @Sys = (SELECT UserId FROM Users WHERE LoginName = 'admin' AND IsSystem = 1);
    SET @RoleAdmin = (SELECT RoleId FROM Roles WHERE RoleCode = 'admin');
    SET @RoleController = (SELECT RoleId FROM Roles WHERE RoleCode = 'controller');
    SET @RoleManager = (SELECT RoleId FROM Roles WHERE RoleCode = 'manager');
    SET @RoleUser = (SELECT RoleId FROM Roles WHERE RoleCode = 'user');
    SET @RoleMgmt = (SELECT RoleId FROM Roles WHERE RoleCode = 'mgmt');
    SET @RoleMdSec = (SELECT RoleId FROM Roles WHERE RoleCode = 'md_sect');
    SET @DeptAdmin = (SELECT DepartmentId FROM Department WHERE DepartmentCode = 'D001');
    SET @DeptSec = (SELECT DepartmentId FROM Department WHERE DepartmentCode = 'D002');
    SET @DeptHrd = (SELECT DepartmentId FROM Department WHERE DepartmentCode = 'D003');
    SET @DeptCredit = (SELECT DepartmentId FROM Department WHERE DepartmentCode = 'D004');
    SET @Design = (SELECT DesignationId FROM Designation WHERE DesignationCode = 'DESIGN005');
    SET @TypeChairman = (SELECT MemberTypeId FROM Member_Type WHERE MemberTypeCode = 'Chairman' AND MemberScope = 'C' AND StatusId = 1);
    SET @TypeMember = (SELECT MemberTypeId FROM Member_Type WHERE MemberTypeCode = 'Member' AND MemberScope = 'C' AND StatusId = 1);
    SET @SubjectType = (SELECT SubjectTypeId FROM Subject_Type WHERE SubjectTypeCode = 'ST002');
    SET @DecisionFollowup = (SELECT DecisionTypeId FROM Decision_Type WHERE DecisionTypeCode = 'DT001');
    SET @DecisionOther = (SELECT DecisionTypeId FROM Decision_Type WHERE DecisionTypeCode = 'DT003');
    IF (@Sys IS NULL OR @RoleAdmin IS NULL OR @RoleController IS NULL OR @RoleManager IS NULL OR @RoleUser IS NULL
        OR @RoleMgmt IS NULL OR @RoleMdSec IS NULL OR @DeptAdmin IS NULL OR @DeptSec IS NULL OR @DeptHrd IS NULL
        OR @DeptCredit IS NULL OR @Design IS NULL OR @TypeChairman IS NULL OR @TypeMember IS NULL
        OR @SubjectType IS NULL OR @DecisionFollowup IS NULL OR @DecisionOther IS NULL)
        RAISERROR('a seed row of Reset Database was not found', 16, 1);
    -- Update Minutes treats DecisionTypeId 1 as Followup (a fixed id in the procedures)
    IF (@DecisionFollowup <> 1)
        RAISERROR('the Followup decision type is not DecisionTypeId 1', 16, 1);

    ---------------------------------------------------------------------------
    -- Accounts
    ---------------------------------------------------------------------------
    SET @Step = 'account qa_admin';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA Admin', @DepartmentId = @DeptAdmin,
        @DesignationId = @Design, @ManagerId = NULL, @RoleId = @RoleAdmin, @EmailId = 'qa_admin@example.invalid', @LoginName = 'qa_admin',
        @Password = '$(H_admin)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaAdmin = (SELECT UserId FROM Users WHERE LoginName = 'qa_admin');

    SET @Step = 'account qa_ctrl';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA Controller', @DepartmentId = @DeptSec,
        @DesignationId = @Design, @ManagerId = NULL, @RoleId = @RoleController, @EmailId = 'qa_ctrl@example.invalid', @LoginName = 'qa_ctrl',
        @Password = '$(H_controller)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaController = (SELECT UserId FROM Users WHERE LoginName = 'qa_ctrl');

    SET @Step = 'account qa_manager';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA Manager', @DepartmentId = @DeptCredit,
        @DesignationId = @Design, @ManagerId = NULL, @RoleId = @RoleManager, @EmailId = 'qa_manager@example.invalid', @LoginName = 'qa_manager',
        @Password = '$(H_manager)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaManager = (SELECT UserId FROM Users WHERE LoginName = 'qa_manager');

    SET @Step = 'account qa_manager2 (two departments)';
    SET @DeptList = CAST(@DeptHrd AS VARCHAR(12)) + ',' + CAST(@DeptSec AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA Manager Two', @DepartmentId = @DeptHrd,
        @DesignationId = @Design, @ManagerId = NULL, @RoleId = @RoleManager, @EmailId = 'qa_manager2@example.invalid', @LoginName = 'qa_manager2',
        @Password = '$(H_manager2)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys, @DepartmentIds = @DeptList;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaManager2 = (SELECT UserId FROM Users WHERE LoginName = 'qa_manager2');

    SET @Step = 'account qa_user';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA User', @DepartmentId = @DeptCredit,
        @DesignationId = @Design, @ManagerId = @QaManager, @RoleId = @RoleUser, @EmailId = 'qa_user@example.invalid', @LoginName = 'qa_user',
        @Password = '$(H_user)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaUser = (SELECT UserId FROM Users WHERE LoginName = 'qa_user');

    SET @Step = 'account qa_user2';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA User Two', @DepartmentId = @DeptHrd,
        @DesignationId = @Design, @ManagerId = @QaManager2, @RoleId = @RoleUser, @EmailId = 'qa_user2@example.invalid', @LoginName = 'qa_user2',
        @Password = '$(H_user2)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaUser2 = (SELECT UserId FROM Users WHERE LoginName = 'qa_user2');

    SET @Step = 'account qa_mgmt';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA Management', @DepartmentId = @DeptSec,
        @DesignationId = @Design, @ManagerId = NULL, @RoleId = @RoleMgmt, @EmailId = 'qa_mgmt@example.invalid', @LoginName = 'qa_mgmt',
        @Password = '$(H_mgmt)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaMgmt = (SELECT UserId FROM Users WHERE LoginName = 'qa_mgmt');

    SET @Step = 'account qa_mdsec';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA MD Secretariat', @DepartmentId = @DeptSec,
        @DesignationId = @Design, @ManagerId = NULL, @RoleId = @RoleMdSec, @EmailId = 'qa_mdsec@example.invalid', @LoginName = 'qa_mdsec',
        @Password = '$(H_mdsec)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaMdSec = (SELECT UserId FROM Users WHERE LoginName = 'qa_mdsec');

    SET @Step = 'account qa_inactive';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = 'QA Inactive', @DepartmentId = @DeptCredit,
        @DesignationId = @Design, @ManagerId = @QaManager, @RoleId = @RoleUser, @EmailId = 'qa_inactive@example.invalid', @LoginName = 'qa_inactive',
        @Password = '$(H_inactive)', @CreatedOn = @Now, @CreatedBy = @Sys, @UpdatedOn = @Now, @UpdatedBy = @Sys;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @QaInactive = (SELECT UserId FROM Users WHERE LoginName = 'qa_inactive');

    SET @Step = 'qa_inactive made inactive';
    DELETE FROM @R; INSERT INTO @R EXEC spr_SetUserStatusByUserId @UserId = @QaInactive, @AccountStatus = 0, @ActingUserId = @QaAdmin;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);

    ---------------------------------------------------------------------------
    -- Committee QA1 with a Chairman and a Member (the code has 3 characters and the
    -- meeting numbers 5: the agenda number is read by position)
    ---------------------------------------------------------------------------
    SET @Step = 'committee QA1';
    EXEC spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'QA1', @CommitteeName = 'QA Test Committee', @Board = 0,
        @IncorporationDate = '20200101', @MeetingStartNo = 1, @CommitteeColorCode = '', @CessationDate = '', @StatusId = 1,
        @CreatedOn = @Now, @CreatedBy = @QaController, @UpdatedOn = @Now, @UpdatedBy = @QaController;
    SET @C = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'QA1');
    IF (@C IS NULL) RAISERROR('not saved', 16, 1);

    SET @Step = 'members';
    EXEC spr_AddEditMember @Code = 'Save', @MemberId = 0, @MemberCode = 'QAM1', @MemberName = 'QA Chairman', @SexId = 3, @DesignationId = @Design,
        @DOB = '01-Jan-1970', @Address1 = 'QA', @Address2 = '', @Address3 = '', @CityName = 'QA', @State_Id = '', @PinCode = '', @DOJ = '01-Jan-2020',
        @EmailId = 'qa_member1@example.invalid', @DinNo = '', @PhotoPath = '', @ResumePath = '', @RelievingDate = '', @StatusId = 1,
        @CreatedOn = @Now, @CreatedBy = @QaController, @UpdatedOn = @Now, @UpdatedBy = @QaController;
    EXEC spr_AddEditMember @Code = 'Save', @MemberId = 0, @MemberCode = 'QAM2', @MemberName = 'QA Member', @SexId = 3, @DesignationId = @Design,
        @DOB = '01-Jan-1971', @Address1 = 'QA', @Address2 = '', @Address3 = '', @CityName = 'QA', @State_Id = '', @PinCode = '', @DOJ = '01-Jan-2020',
        @EmailId = 'qa_member2@example.invalid', @DinNo = '', @PhotoPath = '', @ResumePath = '', @RelievingDate = '', @StatusId = 1,
        @CreatedOn = @Now, @CreatedBy = @QaController, @UpdatedOn = @Now, @UpdatedBy = @QaController;
    SET @M1 = (SELECT MemberId FROM Member WHERE MemberCode = 'QAM1');
    SET @M2 = (SELECT MemberId FROM Member WHERE MemberCode = 'QAM2');
    IF (@M1 IS NULL OR @M2 IS NULL) RAISERROR('not saved', 16, 1);

    SET @Step = 'committee member 1 (Chairman)';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditCommitteeMember @Code = 'Save', @CommitteeMemberId = 0, @CommitteeId = @C, @MemberId = @M1,
        @MemberTypeId = @TypeChairman, @AppointmentDate = '20200101', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @QaController, @UpdatedOn = @Now, @UpdatedBy = @QaController;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
    SET @Step = 'committee member 2 (Member)';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditCommitteeMember @Code = 'Save', @CommitteeMemberId = 0, @CommitteeId = @C, @MemberId = @M2,
        @MemberTypeId = @TypeMember, @AppointmentDate = '20200101', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @QaController, @UpdatedOn = @Now, @UpdatedBy = @QaController;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);

    ---------------------------------------------------------------------------
    -- Meetings (direct rows: four need a past date; see the header). CreatedOn is now,
    -- so the workflow order of step 23 applies to all of them.
    ---------------------------------------------------------------------------
    SET @Step = 'meetings';
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, MeetingColorCode, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('00001', @C, 'QA', 'QA agenda open', DATEADD(DAY, 30, @Today), '10:00', DATEADD(DAY, 20, @Today), '', 'Open', 'Open', @Now, @QaController);
    SET @Mt1 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, MeetingColorCode, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('00002', @C, 'QA', 'QA submission date passed', DATEADD(DAY, 10, @Today), '10:00', DATEADD(DAY, -2, @Today), '', 'Open', 'Open', @Now, @QaController);
    SET @Mt2 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, MeetingColorCode, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('00003', @C, 'QA', 'QA agenda finalised', DATEADD(DAY, 5, @Today), '10:00', DATEADD(DAY, -5, @Today), '', 'Open', 'Open', @Now, @QaController);
    SET @Mt3 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, MeetingColorCode, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('00004', @C, 'QA', 'QA minutes draft', DATEADD(DAY, -10, @Today), '10:00', DATEADD(DAY, -20, @Today), '', 'Open', 'Open', @Now, @QaController);
    SET @Mt4 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, MeetingColorCode, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('00005', @C, 'QA', 'QA minutes finalised', DATEADD(DAY, -20, @Today), '10:00', DATEADD(DAY, -30, @Today), '', 'Open', 'Open', @Now, @QaController);
    SET @Mt5 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, MeetingColorCode, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('00006', @C, 'QA', 'QA minutes confirmed', DATEADD(DAY, -30, @Today), '10:00', DATEADD(DAY, -40, @Today), '', 'Open', 'Open', @Now, @QaController);
    SET @Mt6 = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- Agenda items. Each is saved by qa_user (route: the manager step, AC) with
    -- spr_AddEditAgenda, then moved on with spr_UpdateAgendaByAgendaId.
    --   @No 1..5  meeting 00001: AC, AMA, ACA, AMR, ACR
    --   @No 6     meeting 00002: AC
    --   @No 7     meeting 00003: ACA
    --   @No 8,9   meeting 00004: ACA, ACA
    --   @No 10,11 meeting 00005: ACA, ACA
    --   @No 12    meeting 00006: ACA
    ---------------------------------------------------------------------------
    SET @No = 1;
    WHILE (@No <= 12)
    BEGIN
        SET @Mt = CASE WHEN @No <= 5 THEN @Mt1 WHEN @No = 6 THEN @Mt2 WHEN @No = 7 THEN @Mt3
                       WHEN @No <= 9 THEN @Mt4 WHEN @No <= 11 THEN @Mt5 ELSE @Mt6 END;
        SET @Title = N'QA item ' + CAST(@No AS NVARCHAR(12)) + N' ('
                   + CASE @No WHEN 1 THEN N'waiting for the Manager' WHEN 2 THEN N'approved by the Manager' WHEN 3 THEN N'approved by the Controller'
                              WHEN 4 THEN N'rejected by the Manager' WHEN 5 THEN N'rejected by the Controller' WHEN 6 THEN N'waiting for the Manager'
                              ELSE N'approved by the Controller' END + N')';

        SET @Step = 'agenda item ' + CAST(@No AS VARCHAR(12)) + ': save by qa_user';
        DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
            @DepartmentId = @DeptCredit, @SubjectTypeId = @SubjectType, @ShortText = @Title, @AgendaType = 'Entry',
            @AgendaText = N'<p>QA agenda text.</p>', @AgendaTextPath = N'', @ProposedResolution = N'<p>QA proposed resolution.</p>', @FilePath = N'',
            @MgrComments = N'', @ControllerComments = N'', @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @QaUser,
            @UpdatedOn = @Now, @UpdatedBy = @QaUser, @SubjectNo = NULL, @ActingUserId = @QaUser, @ChangedFields = @Changed OUTPUT;
        IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
        SET @Ag = (SELECT MAX(AgendaId) FROM Agenda WHERE MeetingId = @Mt AND CreatedBy = @QaUser);
        IF ((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @Ag) <> 'AC') RAISERROR('the new item is not at AC', 16, 1);

        IF (@No = 4)
        BEGIN
            SET @Step = 'agenda item 4: reject by qa_manager';
            DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateAgendaByAgendaId @AgendaId = @Ag, @ShortText = @Title, @ProposedResolution = N'<p>QA proposed resolution.</p>',
                @MgrComments = N'QA: rejected by the Manager.', @ControllerComments = N'', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Rejected', @UpdatedBy = @QaManager;
            IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
        END
        ELSE IF (@No NOT IN (1, 6))
        BEGIN
            SET @Step = 'agenda item ' + CAST(@No AS VARCHAR(12)) + ': approve by qa_manager';
            DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateAgendaByAgendaId @AgendaId = @Ag, @ShortText = @Title, @ProposedResolution = N'<p>QA proposed resolution.</p>',
                @MgrComments = N'QA: approved by the Manager.', @ControllerComments = N'', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @QaManager;
            IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
        END

        IF (@No = 5)
        BEGIN
            SET @Step = 'agenda item 5: reject by qa_ctrl';
            DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateAgendaByAgendaId @AgendaId = @Ag, @ShortText = @Title, @ProposedResolution = N'<p>QA proposed resolution.</p>',
                @MgrComments = N'QA: approved by the Manager.', @ControllerComments = N'QA: rejected by the Controller.', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @QaController;
            IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
        END
        ELSE IF (@No = 3 OR @No >= 7)
        BEGIN
            SET @Step = 'agenda item ' + CAST(@No AS VARCHAR(12)) + ': approve by qa_ctrl';
            DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateAgendaByAgendaId @AgendaId = @Ag, @ShortText = @Title, @ProposedResolution = N'<p>QA proposed resolution.</p>',
                @MgrComments = N'QA: approved by the Manager.', @ControllerComments = N'QA: approved by the Controller.', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @QaController;
            IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
            SET @Step = 'agenda item ' + CAST(@No AS VARCHAR(12)) + ': subject number';
            EXEC spr_GenerateSubjectNoByMeetingId @MeetingId = @Mt, @AgendaId = @Ag;
            IF ((SELECT ISNULL(SubjectNo, 0) FROM Agenda WHERE AgendaId = @Ag) < 1) RAISERROR('no subject number', 16, 1);
        END
        SET @No = @No + 1;
    END

    -- The second department: one HRD item at AC on meeting 00001, saved by qa_user2 (manager qa_manager2)
    SET @Step = 'agenda item 13: save by qa_user2 (HRD)';
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt1,
        @DepartmentId = @DeptHrd, @SubjectTypeId = @SubjectType, @ShortText = N'QA item 13 (HRD, waiting for the Manager)', @AgendaType = 'Entry',
        @AgendaText = N'<p>QA agenda text.</p>', @AgendaTextPath = N'', @ProposedResolution = N'<p>QA proposed resolution.</p>', @FilePath = N'',
        @MgrComments = N'', @ControllerComments = N'', @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @QaUser2,
        @UpdatedOn = @Now, @UpdatedBy = @QaUser2, @SubjectNo = NULL, @ActingUserId = @QaUser2, @ChangedFields = @Changed OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);

    ---------------------------------------------------------------------------
    -- Meetings 00003 to 00006: Agenda Finalisation. Then 00004 to 00006: chairman,
    -- attendance, Update Minutes; 00005 and 00006 Finalise; 00006 Confirm.
    ---------------------------------------------------------------------------
    SET @No = 3;
    WHILE (@No <= 6)
    BEGIN
        SET @Mt = CASE @No WHEN 3 THEN @Mt3 WHEN 4 THEN @Mt4 WHEN 5 THEN @Mt5 ELSE @Mt6 END;

        SET @Step = 'meeting 0000' + CAST(@No AS VARCHAR(12)) + ': Agenda Finalisation';
        DELETE FROM @R; INSERT INTO @R EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @Mt;
        IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);

        IF (@No >= 4)
        BEGIN
            SET @Step = 'meeting 0000' + CAST(@No AS VARCHAR(12)) + ': chairman';
            DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateMeetingChairman @MeetingId = @Mt, @CommitteeId = @C, @ChairmanNameId = @M1;
            IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);

            SET @Step = 'meeting 0000' + CAST(@No AS VARCHAR(12)) + ': attendance';
            DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C, @MeetingId = @Mt, @MemberOf = 'C', @MemberId = @M1, @Attendance = 'P', @UpdatedBy = @QaController;
            IF NOT EXISTS (SELECT 1 FROM @R1 WHERE Result = 1) RAISERROR('refused (attendance)', 16, 1);
            DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C, @MeetingId = @Mt, @MemberOf = 'C', @MemberId = @M2, @Attendance = 'P', @UpdatedBy = @QaController;
            IF NOT EXISTS (SELECT 1 FROM @R1 WHERE Result = 1) RAISERROR('refused (attendance)', 16, 1);

            -- Update Minutes for every minute of the meeting. On meeting 00005 the first is a Followup.
            SET @Min = (SELECT MIN(mi.MinutesId) FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.MeetingId = @Mt);
            WHILE (@Min IS NOT NULL)
            BEGIN
                SET @Step = 'meeting 0000' + CAST(@No AS VARCHAR(12)) + ': Update Minutes';
                SET @Title = (SELECT a.ShortText FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE mi.MinutesId = @Min);
                IF (@No = 5 AND @Min = (SELECT MIN(mi.MinutesId) FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.MeetingId = @Mt))
                BEGIN
                    DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Min, @DecisionTypeId = @DecisionFollowup,
                        @Directions = N'<p>QA directions (followup).</p>', @ActualResolution = N'<p>QA resolution as passed.</p>', @ShortText = @Title,
                        @CreatedBy = @QaController, @UpdatedBy = @QaController, @DueDate = NULL;
                END
                ELSE
                BEGIN
                    DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Min, @DecisionTypeId = @DecisionOther,
                        @Directions = N'<p>QA directions.</p>', @ActualResolution = N'<p>QA resolution as passed.</p>', @ShortText = @Title,
                        @CreatedBy = @QaController, @UpdatedBy = @QaController;
                END
                IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
                SET @Min = (SELECT MIN(mi.MinutesId) FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.MeetingId = @Mt AND mi.MinutesId > @Min);
            END
        END

        IF (@No >= 5)
        BEGIN
            SET @Step = 'meeting 0000' + CAST(@No AS VARCHAR(12)) + ': Finalise Minutes';
            DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @Mt, @UserId = @QaController;
            IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
        END
        IF (@No = 6)
        BEGIN
            SET @Step = 'meeting 00006: Confirm Minutes';
            DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesConfirmByMeetingId @MeetingId = @Mt, @UserId = @QaController;
            IF NOT EXISTS (SELECT 1 FROM @R WHERE Result = 1) RAISERROR('refused', 16, 1);
        END
        SET @No = @No + 1;
    END

    ---------------------------------------------------------------------------
    -- Committee QA2 (step UN6b): the Dashboard's meeting list. Direct rows: eleven
    -- meetings lie in the past. Day offsets avoid -10, the day of QA1 00004.
    ---------------------------------------------------------------------------
    SET @Step = 'committee QA2';
    EXEC spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'QA2', @CommitteeName = 'QA Dashboard Committee', @Board = 0,
        @IncorporationDate = '20200101', @MeetingStartNo = 1, @CommitteeColorCode = '', @CessationDate = '', @StatusId = 1,
        @CreatedOn = @Now, @CreatedBy = @QaController, @UpdatedOn = @Now, @UpdatedBy = @QaController;
    SET @C2 = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'QA2');
    IF (@C2 IS NULL) RAISERROR('not saved', 16, 1);

    SET @Step = 'QA2 meetings';
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, MeetingColorCode, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    SELECT x.MeetingNo, @C2, 'QA', 'QA dashboard', DATEADD(DAY, x.DayOffset, @Today), '10:00', DATEADD(DAY, x.SubOffset, @Today), '',
           x.AgendaStatus, x.MinutesStatus, @Now, @QaController
    FROM (SELECT '00001' AS MeetingNo, 0 AS DayOffset, 0 AS SubOffset, 'Open' AS AgendaStatus, 'Open' AS MinutesStatus
          UNION ALL SELECT '00002', -1, -6, 'Close', 'Open'
          UNION ALL SELECT '00003', -2, -7, 'Close', 'F'
          UNION ALL SELECT '00004', -3, -8, 'Close', 'C'
          UNION ALL SELECT '00005', -4, -9, 'Close', 'C'
          UNION ALL SELECT '00006', -5, -10, 'Close', 'C'
          UNION ALL SELECT '00007', -6, -11, 'Close', 'C'
          UNION ALL SELECT '00008', -7, -12, 'Close', 'C'
          UNION ALL SELECT '00009', -8, -13, 'Close', 'C'
          UNION ALL SELECT '00010', -9, -14, 'Close', 'C'
          UNION ALL SELECT '00011', -11, -16, 'Close', 'C'
          UNION ALL SELECT '00012', -12, -17, 'Close', 'C') x;
    IF ((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C2) <> 12) RAISERROR('not all twelve QA2 meetings were saved', 16, 1);

    SET @Step = 'QA2 agenda items';
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        CurrentStatus, AgendaStatusCode, MgrApprovedStatus, ControllerApprovedStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    SELECT 'QA2-' + m.MeetingNo + '-' + x.Seq, @C2, m.MeetingId, CASE x.Dept WHEN 'S' THEN @DeptSec ELSE @DeptCredit END, @SubjectType,
           N'QA2 item ' + m.MeetingNo + N'-' + x.Seq, 'Entry', N'<p>QA agenda text.</p>', N'<p>QA proposed resolution.</p>',
           'New', x.StatusCode, 'Approved', CASE x.StatusCode WHEN 'ACR' THEN 'Rejected' ELSE 'Approved' END,
           @Now, CASE x.Dept WHEN 'S' THEN @QaController ELSE @QaUser END, @Now, @QaController
    FROM (SELECT '00002' AS MeetingNo, '1' AS Seq, 'C' AS Dept, 'ACA' AS StatusCode
          UNION ALL SELECT '00002', '2', 'C', 'ACR'
          UNION ALL SELECT '00003', '1', 'S', 'ACA'
          UNION ALL SELECT '00004', '1', 'C', 'ACA' UNION ALL SELECT '00005', '1', 'C', 'ACA' UNION ALL SELECT '00006', '1', 'C', 'ACA'
          UNION ALL SELECT '00007', '1', 'C', 'ACA' UNION ALL SELECT '00008', '1', 'C', 'ACA' UNION ALL SELECT '00009', '1', 'C', 'ACA'
          UNION ALL SELECT '00010', '1', 'C', 'ACA' UNION ALL SELECT '00011', '1', 'C', 'ACA' UNION ALL SELECT '00012', '1', 'C', 'ACA') x
    JOIN Meeting m ON m.CommitteeId = @C2 AND m.MeetingNo = x.MeetingNo;
    IF ((SELECT COUNT(*) FROM Agenda WHERE CommitteeId = @C2) <> 12) RAISERROR('not all twelve QA2 items were saved', 16, 1);

    COMMIT TRANSACTION;
    PRINT 'FIXTURE: DONE';
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
    SET @Why = ISNULL((SELECT TOP 1 N' (Result ' + CAST(Result AS NVARCHAR(12)) + N', Reason ' + CAST(Reason AS NVARCHAR(12)) + N', ' + LEFT(ISNULL(ReasonDetail, N''), 200) + N')' FROM @R), N'');
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    RAISERROR('Fixture failed at "%s": %s%s. Everything was rolled back.', 16, 1, @Step, @Err, @Why);
END CATCH
GO
SET NOEXEC OFF;
GO
