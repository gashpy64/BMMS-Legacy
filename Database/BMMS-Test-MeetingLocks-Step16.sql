/* ============================================================================
   BMMS - Tests for BMMS-Fix-MeetingLocks-Step16.sql (step 16)
   ----------------------------------------------------------------------------
   Run AFTER BMMS-Fix-MeetingLocks-Step16.sql, on the TEST COPY. It stops if
   step 16 is not installed.

   Creates its own committees, members, users, meetings and agenda items and
   checks, through the real procedures:
     * meeting edit: venue / time always; date and committee refused once
       attendance is recorded (Reason 6); committee refused once agenda items
       exist (Reason 10); refused edits write no alert; edit lock lookup
     * agenda add / edit / delete / approve / subject no by User, Manager,
       Controller and Admin, Open and finalized, Controller option on and off,
       minutes finalized (Reason 1), inactive or missing acting user
       (Reason 8), NULL status, missing setting row; agenda lock lookup
     * System Settings: Admin only, inactive Admin, invalid value, audit row
     * minutes update and agenda short text at Open / F / C (Reason 7)
     * committee members against the meeting date: before / equal / after
       appointment, NULL appointment, ceased, not-a-date cessation, members
       with saved attendance; attendance and chairman saves

   Everything runs inside one transaction that is ROLLED BACK (the Admin
   option included). The only lasting effect is that identity values skip a
   few numbers.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaLockByMeetingId')), '') NOT LIKE '%MeetingLocks-Step16%')
BEGIN
    RAISERROR('Meeting locks part 2 (step 16) are not installed in "%s". Run BMMS-Fix-MeetingLocks-Step16.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(120), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));
DECLARE @R1 TABLE (Result INT);
DECLARE @L TABLE (HasAttendance INT, HasAgenda INT);
DECLARE @AL TABLE (AllowChange INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @SG TABLE (SettingCode VARCHAR(50), SettingValue VARCHAR(250), Description VARCHAR(250), LastChangedOn DATETIME, LastChangedBy VARCHAR(100));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Today DATETIME = CAST(CAST(GETDATE() AS date) AS DATETIME);
DECLARE @MDate DATETIME = DATEADD(DAY, -10, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @MDate15 DATETIME = DATEADD(HOUR, 15, @MDate);
DECLARE @Later DATETIME = DATEADD(MINUTE, 5, GETDATE());

DECLARE @Admin INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 ORDER BY u.UserId);
DECLARE @Ctrl INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 ORDER BY u.UserId);
DECLARE @Mgr INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'manager' AND u.AccountStatus = 1 ORDER BY u.UserId);
-- The User adds agenda items: from step 17 that is refused (Reason 11) while their manager is inactive
DECLARE @Usr INT = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'user' AND u.AccountStatus = 1
                    AND NOT EXISTS (SELECT 1 FROM Users m WHERE m.UserId = u.ManagerId AND m.AccountStatus <> 1) ORDER BY u.UserId);
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @AdminRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @DepartmentId INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @MemberTypeId INT = (SELECT TOP 1 MemberTypeId FROM Member_Type ORDER BY MemberTypeId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DecisionOther INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);
DECLARE @HasFollowup INT = CASE WHEN EXISTS (SELECT 1 FROM Decision_Type WHERE DecisionTypeId = 1) THEN 1 ELSE 0 END;

DECLARE @C16 INT, @C17 INT;
DECLARE @M1 INT, @M2 INT, @M3 INT, @M4 INT, @M5 INT, @M6 INT, @M7 INT;
DECLARE @CtrlOff INT, @AdminOff INT;
DECLARE @MA INT, @MB INT, @MAg INT, @MOpen INT, @MClose INT, @MFin INT, @MConf INT, @MNull INT, @MAppt INT, @Missing INT;
DECLARE @AOpen INT, @AOpen2 INT, @AClose INT, @AClose2 INT, @AFin INT, @AMinO INT, @AMinF INT, @AMinC INT, @ANew INT;
DECLARE @MinO INT, @MinF INT, @MinC INT, @MinFin INT;
DECLARE @Rows INT, @Rows2 INT;
DECLARE @Text VARCHAR(400);
DECLARE @UpdatedOnBefore DATETIME;
DECLARE @E VARCHAR(10) = '';

IF (@Admin IS NULL OR @Ctrl IS NULL OR @Mgr IS NULL OR @Usr IS NULL OR @DepartmentId IS NULL OR @DesignationId IS NULL
    OR @MemberTypeId IS NULL OR @SubjectTypeId IS NULL OR @DecisionOther IS NULL)
BEGIN
    INSERT INTO @T VALUES ('An active Admin, Controller, Manager and User, a department, designation, member type, subject type or decision type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT TOP 0 * INTO #CM FROM View_Committee_Member;
SELECT TOP 0 *, CAST(NULL AS VARCHAR(50)) AS MemberTypeName INTO #VM FROM View_Member;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures
    ---------------------------------------------------------------------------
    UPDATE App_Setting SET SettingValue = '1' WHERE SettingCode = 'AgendaControllerBypass';

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z16', 'ZZ step 16 committee', '2000-01-01', 1, 0);
    SET @C16 = SCOPE_IDENTITY();
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z17', 'ZZ step 16 other', '2000-01-01', 1, 0);
    SET @C17 = SCOPE_IDENTITY();

    INSERT INTO Member (MemberCode, MemberName, DesignationId, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ16M1', 'ZZ16 Before', @DesignationId, 1, @Now, @Admin);
    SET @M1 = SCOPE_IDENTITY();
    INSERT INTO Member (MemberCode, MemberName, DesignationId, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ16M2', 'ZZ16 Equal', @DesignationId, 1, @Now, @Admin);
    SET @M2 = SCOPE_IDENTITY();
    INSERT INTO Member (MemberCode, MemberName, DesignationId, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ16M3', 'ZZ16 After', @DesignationId, 1, @Now, @Admin);
    SET @M3 = SCOPE_IDENTITY();
    INSERT INTO Member (MemberCode, MemberName, DesignationId, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ16M4', 'ZZ16 NoDate', @DesignationId, 1, @Now, @Admin);
    SET @M4 = SCOPE_IDENTITY();
    INSERT INTO Member (MemberCode, MemberName, DesignationId, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ16M5', 'ZZ16 Ceased', @DesignationId, 1, @Now, @Admin);
    SET @M5 = SCOPE_IDENTITY();
    INSERT INTO Member (MemberCode, MemberName, DesignationId, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ16M6', 'ZZ16 AfterAttended', @DesignationId, 1, @Now, @Admin);
    SET @M6 = SCOPE_IDENTITY();
    INSERT INTO Member (MemberCode, MemberName, DesignationId, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ16M7', 'ZZ16 BadCessation', @DesignationId, 1, @Now, @Admin);
    SET @M7 = SCOPE_IDENTITY();

    INSERT INTO Committee_Member (CommitteeId, MemberId, MemberTypeId, AppointmentDate, CessationDate, IsFeeApplicable, ApplicableFee, CreatedOn, CreatedBy) VALUES
    (@C16, @M1, @MemberTypeId, DATEADD(DAY, -30, @MDate), '', 0, 0, @Now, @Admin),
    (@C16, @M2, @MemberTypeId, @MDate, '', 0, 0, @Now, @Admin),
    (@C16, @M3, @MemberTypeId, DATEADD(DAY, 1, @MDate), '', 0, 0, @Now, @Admin),
    (@C16, @M4, @MemberTypeId, NULL, '', 0, 0, @Now, @Admin),
    (@C16, @M5, @MemberTypeId, DATEADD(DAY, -30, @MDate), CONVERT(VARCHAR(8), DATEADD(DAY, -1, @MDate), 112), 0, 0, @Now, @Admin),
    (@C16, @M6, @MemberTypeId, DATEADD(DAY, 1, @MDate), '', 0, 0, @Now, @Admin),
    (@C16, @M7, @MemberTypeId, DATEADD(DAY, -30, @MDate), 'not a date', 0, 0, @Now, @Admin);

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ16 inactive controller', @DepartmentId, @DesignationId, NULL, @CtrlRoleId, '', 'zz16ctrloff', 'not-a-login', 0, @Now, @Admin, @Now, @Admin);
    SET @CtrlOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ16 inactive admin', @DepartmentId, @DesignationId, NULL, @AdminRoleId, '', 'zz16adminoff', 'not-a-login', 0, @Now, @Admin, @Now, @Admin);
    SET @AdminOff = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99901', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, 'Open', 'Open');
    SET @MA = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99902', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, 'Open', 'Open');
    SET @MB = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99903', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, 'Open', 'Open');
    SET @MAg = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99904', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, 'Open', 'Open');
    SET @MOpen = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99905', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, 'Close', 'Open');
    SET @MClose = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99906', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, 'Close', 'F');
    SET @MFin = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99907', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, 'Close', 'C');
    SET @MConf = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99908', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, NULL, NULL);
    SET @MNull = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99909', @C16, 'ZZ place', 'ZZ venue', @MDate, '10:00', @MDate, 'Close', 'Open');
    SET @MAppt = SCOPE_IDENTITY();

    SET @Missing = (SELECT ISNULL(MAX(MeetingId), 0) + 1000 FROM Meeting);

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z16-99903-001', @C16, @MAg, @DepartmentId, @SubjectTypeId, 'ZZ agenda', 'Entry', 'ZZ', 'ZZ resolution', 'Approved', @Now, @Usr);

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, CreatedOn, CreatedBy)
    VALUES ('Z16-99904-001', @C16, @MOpen, @DepartmentId, @SubjectTypeId, 'ZZ open', 'Entry', 'ZZ', 'ZZ resolution', @Now, @Usr);
    SET @AOpen = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, CreatedOn, CreatedBy)
    VALUES ('Z16-99904-002', @C16, @MOpen, @DepartmentId, @SubjectTypeId, 'ZZ open 2', 'Entry', 'ZZ', 'ZZ resolution', @Now, @Usr);
    SET @AOpen2 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z16-99905-001', @C16, @MClose, @DepartmentId, @SubjectTypeId, 'ZZ closed', 'Entry', 'ZZ', 'ZZ resolution', 'Approved', @Now, @Usr);
    SET @AClose = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z16-99905-002', @C16, @MClose, @DepartmentId, @SubjectTypeId, 'ZZ closed 2', 'Entry', 'ZZ', 'ZZ resolution', 'Approved', @Now, @Usr);
    SET @AClose2 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z16-99905-003', @C16, @MClose, @DepartmentId, @SubjectTypeId, 'ZZ minutes open', 'Entry', 'ZZ', 'ZZ resolution', 'Approved', @Now, @Usr);
    SET @AMinO = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z16-99906-001', @C16, @MFin, @DepartmentId, @SubjectTypeId, 'ZZ finalized', 'Entry', 'ZZ', 'ZZ resolution', 'Approved', @Now, @Usr);
    SET @AFin = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z16-99906-002', @C16, @MFin, @DepartmentId, @SubjectTypeId, 'ZZ minutes F', 'Entry', 'ZZ', 'ZZ resolution', 'Approved', @Now, @Usr);
    SET @AMinF = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z16-99907-001', @C16, @MConf, @DepartmentId, @SubjectTypeId, 'ZZ minutes C', 'Entry', 'ZZ', 'ZZ resolution', 'Approved', @Now, @Usr);
    SET @AMinC = SCOPE_IDENTITY();

    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AMinO, @DecisionOther, 'ZZ dir', 'ZZ res', @Now, 1, @Now, 1);
    SET @MinO = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AMinF, @DecisionOther, 'ZZ dir', 'ZZ res', @Now, 1, @Now, 1);
    SET @MinF = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AMinC, @DecisionOther, 'ZZ dir', 'ZZ res', @Now, 1, @Now, 1);
    SET @MinC = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AFin, @DecisionOther, 'ZZ dir', 'ZZ res', @Now, 1, @Now, 1);
    SET @MinFin = SCOPE_IDENTITY();
    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy)
    VALUES (@MinFin, 'ZZ', '', '', @Now, @Admin);

    -- Saved attendance: M1 on the meeting-edit meeting, M6 (appointed after the date) on the appointment meeting
    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@C16, @MA, 'C', @M1, 'P', 0, @Now, @Admin);
    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@C16, @MAppt, 'C', @M6, 'P', 0, @Now, @Admin);
    UPDATE Meeting SET AgendaStatus = 'Open' WHERE MeetingId = @MAppt;

    ---------------------------------------------------------------------------
    -- 1. Meeting edit
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99910', @CommitteeId = @C16,
         @Place = 'ZZ', @Venue = 'ZZ', @MeetingDate = @MDate, @MeetingTime = '10:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting: new meeting saved', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Meeting: new meeting row exists', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Meeting WHERE MeetingNo = '99910' AND CommitteeId = @C16;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MB, @MeetingNo = '99902', @CommitteeId = @C16,
         @Place = 'ZZ', @Venue = 'ZZ venue B', @MeetingDate = @MDate, @MeetingTime = '11:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting without attendance: venue change', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MB, @MeetingNo = '99902', @CommitteeId = @C16,
         @Place = 'ZZ', @Venue = 'ZZ venue B', @MeetingDate = @Today, @MeetingTime = '11:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting without attendance: date change', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MB, @MeetingNo = '99902', @CommitteeId = @C17,
         @Place = 'ZZ', @Venue = 'ZZ venue B', @MeetingDate = @Today, @MeetingTime = '11:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting without attendance or agenda: committee change', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Meeting without attendance: committee is now the other one', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Meeting WHERE MeetingId = @MB AND CommitteeId = @C17;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MA, @MeetingNo = '99901', @CommitteeId = @C16,
         @Place = 'ZZ new place', @Venue = 'ZZ new venue', @MeetingDate = @MDate, @MeetingTime = '15:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting with attendance: venue, place and time change', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Meeting with attendance: new venue and time stored', 'ZZ new venue 15:00', Venue + ' ' + MeetingTime FROM Meeting WHERE MeetingId = @MA;

    SET @UpdatedOnBefore = (SELECT UpdatedOn FROM Meeting WHERE MeetingId = @MA);
    SET @Rows = (SELECT COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @MA);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MA, @MeetingNo = '99901', @CommitteeId = @C16,
         @Place = 'ZZ new place', @Venue = 'ZZ new venue', @MeetingDate = @Today, @MeetingTime = '15:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Later, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting with attendance: date change refused', 'Result 0, Reason 6, MeetingDate', Txt FROM @R;
    INSERT INTO @T SELECT 'Meeting with attendance: date unchanged', CONVERT(VARCHAR(10), @MDate, 120), CONVERT(VARCHAR(10), MeetingDate, 120) FROM Meeting WHERE MeetingId = @MA;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MA, @MeetingNo = '99901', @CommitteeId = @C17,
         @Place = 'ZZ new place', @Venue = 'ZZ new venue', @MeetingDate = @MDate, @MeetingTime = '15:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Later, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting with attendance: committee change refused', 'Result 0, Reason 6, CommitteeId', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MA, @MeetingNo = '99901', @CommitteeId = @C17,
         @Place = 'ZZ new place', @Venue = 'ZZ new venue', @MeetingDate = @Today, @MeetingTime = '15:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Later, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting with attendance: date and committee change refused', 'Result 0, Reason 6, MeetingDate,CommitteeId', Txt FROM @R;

    INSERT INTO @T SELECT 'Meeting: refused edits wrote no alert', CAST(@Rows AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12))
    FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @MA;
    INSERT INTO @T SELECT 'Meeting: refused edits left UpdatedOn alone', 'same', CASE WHEN UpdatedOn = @UpdatedOnBefore THEN 'same' ELSE 'changed' END FROM Meeting WHERE MeetingId = @MA;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MA, @MeetingNo = '99901', @CommitteeId = @C16,
         @Place = 'ZZ new place', @Venue = 'ZZ new venue', @MeetingDate = @MDate15, @MeetingTime = '15:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting with attendance: same date, other time of day', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MAg, @MeetingNo = '99903', @CommitteeId = @C17,
         @Place = 'ZZ', @Venue = 'ZZ', @MeetingDate = @MDate, @MeetingTime = '10:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting with agenda items, no attendance: committee change refused', 'Result 0, Reason 10, CommitteeId', Txt FROM @R;
    INSERT INTO @T SELECT 'Meeting with agenda items: agenda rows untouched', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Agenda WHERE MeetingId = @MAg AND CommitteeId = @C16;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MAg, @MeetingNo = '99903', @CommitteeId = @C16,
         @Place = 'ZZ', @Venue = 'ZZ', @MeetingDate = @Today, @MeetingTime = '10:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting with agenda items, no attendance: date change', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @Missing, @MeetingNo = '99999', @CommitteeId = @C16,
         @Place = 'ZZ', @Venue = 'ZZ', @MeetingDate = @MDate, @MeetingTime = '10:00', @AgendaSubmissionDate = @MDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin;
    INSERT INTO @T SELECT 'Meeting: unknown meeting', 'Result 0, Reason 4', Txt FROM @R;

    DELETE FROM @L; INSERT INTO @L EXEC spr_GetMeetingEditLockByMeetingId @MeetingId = @MA;
    INSERT INTO @T SELECT 'Meeting edit lock lookup: attendance, no agenda', '1 0', CAST(HasAttendance AS VARCHAR(1)) + ' ' + CAST(HasAgenda AS VARCHAR(1)) FROM @L;
    DELETE FROM @L; INSERT INTO @L EXEC spr_GetMeetingEditLockByMeetingId @MeetingId = @MAg;
    INSERT INTO @T SELECT 'Meeting edit lock lookup: agenda, no attendance', '0 1', CAST(HasAttendance AS VARCHAR(1)) + ' ' + CAST(HasAgenda AS VARCHAR(1)) FROM @L;

    ---------------------------------------------------------------------------
    -- 2. Agenda
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MOpen,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ user add', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda Open: User adds', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AOpen, @AgendaNo = 'Z16-99904-001', @CommitteeId = @C16, @MeetingId = @MOpen,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ user edit', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda Open: User edits', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Agenda Open: User edit stored', 'ZZ user edit', ShortText FROM Agenda WHERE AgendaId = @AOpen;

    SET @Rows = (SELECT COUNT(*) FROM Agenda WHERE MeetingId = @MClose);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ user add late', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda finalized: User add refused', 'Result 0, Reason 5, Finalized', Txt FROM @R;
    INSERT INTO @T SELECT 'Agenda finalized: no agenda row added', CAST(@Rows AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12)) FROM Agenda WHERE MeetingId = @MClose;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AClose, @AgendaNo = 'Z16-99905-001', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ user edit late', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda finalized: User edit refused', 'Result 0, Reason 5, Finalized', Txt FROM @R;
    INSERT INTO @T SELECT 'Agenda finalized: short text unchanged', 'ZZ closed', ShortText FROM Agenda WHERE AgendaId = @AClose;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ mgr add late', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Agenda finalized: Manager add refused', 'Result 0, Reason 5, Finalized', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AClose, @AgendaNo = 'Z16-99905-001', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ mgr edit late', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Agenda finalized: Manager edit refused', 'Result 0, Reason 5, Finalized', Txt FROM @R;

    -- Controller, option on
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ ctrl add late', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ late resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctrl, @UpdatedOn = @Now, @UpdatedBy = @Ctrl, @SubjectNo = NULL, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda finalized, option on: Controller adds', 'Result 1, Reason 0', Txt FROM @R;
    SET @ANew = (SELECT TOP 1 AgendaId FROM Agenda WHERE MeetingId = @MClose AND ShortText = 'ZZ ctrl add late');
    INSERT INTO @T SELECT 'Agenda finalized, option on: the added item has its Minutes row', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Minutes WHERE AgendaId = @ANew;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AClose, @AgendaNo = 'Z16-99905-001', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ ctrl edit late', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctrl, @UpdatedOn = @Now, @UpdatedBy = @Ctrl, @SubjectNo = NULL, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda finalized, option on: Controller edits', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteAgendaByAgendaId @AgendaId = @AClose2, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda finalized, option on: Controller deletes', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Agenda finalized, option on: deleted item is gone', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM Agenda WHERE AgendaId = @AClose2;

    -- Controller, option off
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetAppSetting @SettingCode = 'AgendaControllerBypass', @SettingValue = '0', @ActingUserId = @Admin;
    INSERT INTO @T SELECT 'Setting: Admin switches the Controller option off', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Setting: value stored', '0', SettingValue FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass';
    INSERT INTO @T SELECT 'Setting: change written to the audit trail by the Admin', '1', CAST(COUNT(*) AS VARCHAR(12))
    FROM Audit_Trail_Master WHERE Audit_Table = 'App_Setting' AND Key_Value = 'AgendaControllerBypass' AND New_Value = '0' AND Update_By = @Admin AND Update_On >= @Now;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ ctrl add off', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctrl, @UpdatedOn = @Now, @UpdatedBy = @Ctrl, @SubjectNo = NULL, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda finalized, option off: Controller add refused', 'Result 0, Reason 5, BypassOff', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AClose, @AgendaNo = 'Z16-99905-001', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ ctrl edit off', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctrl, @UpdatedOn = @Now, @UpdatedBy = @Ctrl, @SubjectNo = NULL, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda finalized, option off: Controller edit refused', 'Result 0, Reason 5, BypassOff', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteAgendaByAgendaId @AgendaId = @AClose, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda finalized, option off: Controller delete refused', 'Result 0, Reason 5, BypassOff', Txt FROM @R;
    INSERT INTO @T SELECT 'Agenda finalized, option off: item still there', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM Agenda WHERE AgendaId = @AClose;

    DELETE FROM @AL; INSERT INTO @AL EXEC spr_GetAgendaLockByMeetingId @MeetingId = @MClose, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda lock lookup, finalized, option off: Controller', '0 5 BypassOff', CAST(AllowChange AS VARCHAR(1)) + ' ' + CAST(Reason AS VARCHAR(3)) + ' ' + CAST(ReasonDetail AS VARCHAR(50)) FROM @AL;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetAppSetting @SettingCode = 'AgendaControllerBypass', @SettingValue = '1', @ActingUserId = @Admin;
    INSERT INTO @T SELECT 'Setting: Admin switches the Controller option back on', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @AL; INSERT INTO @AL EXEC spr_GetAgendaLockByMeetingId @MeetingId = @MClose, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda lock lookup, finalized, option on: Controller', '1 0', CAST(AllowChange AS VARCHAR(1)) + ' ' + CAST(Reason AS VARCHAR(3)) FROM @AL;
    DELETE FROM @AL; INSERT INTO @AL EXEC spr_GetAgendaLockByMeetingId @MeetingId = @MClose, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda lock lookup, finalized: User', '0 5 Finalized', CAST(AllowChange AS VARCHAR(1)) + ' ' + CAST(Reason AS VARCHAR(3)) + ' ' + CAST(ReasonDetail AS VARCHAR(50)) FROM @AL;
    DELETE FROM @AL; INSERT INTO @AL EXEC spr_GetAgendaLockByMeetingId @MeetingId = @MOpen, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda lock lookup, Open: User', '1 0', CAST(AllowChange AS VARCHAR(1)) + ' ' + CAST(Reason AS VARCHAR(3)) FROM @AL;

    -- Other roles through the Controller procedures: the role comes from the database
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ mgr as ctrl', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Agenda finalized, option on: Manager through the Controller procedure refused', 'Result 0, Reason 5, Finalized', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ admin as ctrl', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Admin, @UpdatedOn = @Now, @UpdatedBy = @Admin, @SubjectNo = NULL, @ActingUserId = @Admin;
    INSERT INTO @T SELECT 'Agenda finalized, option on: Admin through the Controller procedure refused', 'Result 0, Reason 5, Finalized', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteAgendaByAgendaId @AgendaId = @AClose, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda finalized, option on: User delete refused', 'Result 0, Reason 5, Finalized', Txt FROM @R;

    -- Minutes finalized: nobody, the Controller included
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AFin, @AgendaNo = 'Z16-99906-001', @CommitteeId = @C16, @MeetingId = @MFin,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ ctrl edit F', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctrl, @UpdatedOn = @Now, @UpdatedBy = @Ctrl, @SubjectNo = NULL, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Minutes finalized, option on: Controller edit refused', 'Result 0, Reason 1', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteAgendaByAgendaId @AgendaId = @AFin, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Minutes finalized, option on: Controller delete refused', 'Result 0, Reason 1', Txt FROM @R;
    INSERT INTO @T SELECT 'Minutes finalized: agenda, minutes and action item intact', '1 1 1',
           CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaId = @AFin) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Minutes WHERE MinutesId = @MinFin) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Action_Item WHERE MinutesId = @MinFin) AS VARCHAR(12));

    -- Acting user
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MOpen,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ inactive ctrl', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @CtrlOff, @UpdatedOn = @Now, @UpdatedBy = @CtrlOff, @SubjectNo = NULL, @ActingUserId = @CtrlOff;
    INSERT INTO @T SELECT 'Agenda: inactive Controller refused', 'Result 0, Reason 8', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MOpen,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ no acting', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = NULL;
    INSERT INTO @T SELECT 'Agenda: acting user NULL refused', 'Result 0, Reason 8', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteAgendaByAgendaId @AgendaId = @AOpen, @ActingUserId = 0;
    INSERT INTO @T SELECT 'Agenda: acting user 0 refused', 'Result 0, Reason 8', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteAgendaByAgendaId @AgendaId = @AOpen, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda Open: User deletes', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteAgendaByAgendaId @AgendaId = -1, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda: delete of an unknown item', 'Result 0, Reason 4', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C16, @MeetingId = @MNull,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ null status', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'Agenda: NULL AgendaStatus counts as Open', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AClose, @AgendaNo = 'Z16-99905-001', @CommitteeId = @C16, @MeetingId = @MClose,
         @DepartmentId = @DepartmentId, @SubjectTypeId = @SubjectTypeId, @ShortText = 'ZZ ctrl no setting row', @AgendaType = 'Entry', @AgendaText = 'ZZ', @AgendaTextPath = @E,
         @ProposedResolution = 'ZZ resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctrl, @UpdatedOn = @Now, @UpdatedBy = @Ctrl, @SubjectNo = NULL, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Agenda finalized, setting row missing: counts as on', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO App_Setting (SettingCode, SettingValue, Description) VALUES ('AgendaControllerBypass', '1', 'test');

    -- Approve / reject
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AOpen2, @ShortText = 'ZZ', @ProposedResolution = 'ZZ',
         @MgrComments = 'ok', @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    INSERT INTO @T SELECT 'Approve, agenda Open: Manager approves', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AClose, @ShortText = 'ZZ', @ProposedResolution = 'ZZ',
         @MgrComments = @E, @ControllerComments = 'ok', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = @E, @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Approve, agenda finalized: Controller refused too', 'Result 0, Reason 5, Finalized', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateSubjectNoByAgendaId @AgendaId = @AClose, @SubjectNo = 9, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Subject no, agenda finalized: Manager refused', 'Result 0, Reason 5, Finalized', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateSubjectNoByAgendaId @AgendaId = @AClose, @SubjectNo = 9, @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Subject no, agenda finalized, option on: Controller', 'Result 1, Reason 0', Txt FROM @R;

    ---------------------------------------------------------------------------
    -- 3. System Settings
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetAppSetting @SettingCode = 'AgendaControllerBypass', @SettingValue = '0', @ActingUserId = @Ctrl;
    INSERT INTO @T SELECT 'Setting: Controller cannot change it', 'Result 0, Reason 4', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetAppSetting @SettingCode = 'AgendaControllerBypass', @SettingValue = '0', @ActingUserId = @AdminOff;
    INSERT INTO @T SELECT 'Setting: inactive Admin refused', 'Result 0, Reason 8', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetAppSetting @SettingCode = 'AgendaControllerBypass', @SettingValue = '2', @ActingUserId = @Admin;
    INSERT INTO @T SELECT 'Setting: value 2 refused', 'Result 0, Reason 3, 2', Txt FROM @R;
    INSERT INTO @T SELECT 'Setting: still on after the refusals', '1', SettingValue FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass';
    DELETE FROM @SG; INSERT INTO @SG EXEC spr_GetAppSetting @SettingCode = 'AgendaControllerBypass';
    INSERT INTO @T SELECT 'Setting lookup: value and last changed by', '1 ' + (SELECT UserName FROM Users WHERE UserId = @Admin), SettingValue + ' ' + LastChangedBy FROM @SG;

    ---------------------------------------------------------------------------
    -- 4. Minutes
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @MinO, @DecisionTypeId = @DecisionOther,
         @Directions = 'ZZ new dir', @ActualResolution = '', @ShortText = '', @CreatedBy = @Ctrl, @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Minutes Open: directions saved', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @MinF, @DecisionTypeId = @DecisionOther,
         @Directions = 'ZZ new dir F', @ActualResolution = '', @ShortText = '', @CreatedBy = @Ctrl, @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Minutes finalized (F): directions still saved', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @MinC, @DecisionTypeId = @DecisionOther,
         @Directions = 'ZZ new dir C', @ActualResolution = '', @ShortText = '', @CreatedBy = @Ctrl, @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Minutes confirmed: directions refused', 'Result 0, Reason 7', Txt FROM @R;
    INSERT INTO @T SELECT 'Minutes confirmed: directions unchanged', 'ZZ dir', Directions FROM Minutes WHERE MinutesId = @MinC;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'ActualResolution', @MinutesId = @MinC, @DecisionTypeId = @DecisionOther,
         @Directions = '', @ActualResolution = 'ZZ new res C', @ShortText = '', @CreatedBy = @Ctrl, @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Minutes confirmed: resolution refused', 'Result 0, Reason 7', Txt FROM @R;
    INSERT INTO @T SELECT 'Minutes confirmed: agenda resolution unchanged', 'ZZ resolution', ProposedResolution FROM Agenda WHERE AgendaId = @AMinC;

    IF (@HasFollowup = 1)
    BEGIN
        DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @MinC, @DecisionTypeId = 1,
             @Directions = '', @ActualResolution = '', @ShortText = 'ZZ short C', @CreatedBy = @Ctrl, @UpdatedBy = @Ctrl;
        INSERT INTO @T SELECT 'Minutes confirmed: All (follow-up) refused', 'Result 0, Reason 7', Txt FROM @R;
        INSERT INTO @T SELECT 'Minutes confirmed: no action item created', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM Action_Item WHERE MinutesId = @MinC;

        DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @MinO, @DecisionTypeId = 1,
             @Directions = '', @ActualResolution = '', @ShortText = 'ZZ short O', @CreatedBy = @Ctrl, @UpdatedBy = @Ctrl;
        INSERT INTO @T SELECT 'Minutes Open: All (follow-up) saved', 'Result 1, Reason 0', Txt FROM @R;
        INSERT INTO @T SELECT 'Minutes Open: one action item, mapped to the agenda creator (FK #5 kept)', '1 1',
               CAST((SELECT COUNT(*) FROM Action_Item WHERE MinutesId = @MinO) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Action_Item a ON a.ActionItemId = m.ActionItemId WHERE a.MinutesId = @MinO AND m.UserId = @Usr) AS VARCHAR(12));
    END
    ELSE
    BEGIN
        INSERT INTO @T VALUES ('Minutes confirmed: All (follow-up) refused', '', 'SKIPPED');
        INSERT INTO @T VALUES ('Minutes confirmed: no action item created', '', 'SKIPPED');
        INSERT INTO @T VALUES ('Minutes Open: All (follow-up) saved', '', 'SKIPPED');
        INSERT INTO @T VALUES ('Minutes Open: one action item, mapped to the agenda creator (FK #5 kept)', '', 'SKIPPED');
    END

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaShortText @AgendaId = @AMinC, @ShortText = 'ZZ short C', @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Minutes confirmed: agenda short text refused', 'Result 0, Reason 7', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaShortText @AgendaId = @AMinF, @ShortText = 'ZZ short F', @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Minutes finalized (F): agenda short text saved', 'Result 1, Reason 0', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = -1, @DecisionTypeId = @DecisionOther,
         @Directions = 'ZZ', @ActualResolution = '', @ShortText = '', @CreatedBy = @Ctrl, @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Minutes: unknown minutes row', 'Result 0, Reason 4', Txt FROM @R;

    ---------------------------------------------------------------------------
    -- 5. Committee members against the meeting date
    ---------------------------------------------------------------------------
    DELETE FROM #CM; INSERT INTO #CM EXEC spr_GetCommitteeMemberByCommitteeId @CommitteeId = @C16, @MeetingId = @MAppt;
    INSERT INTO @T SELECT 'Members of the meeting: appointed before the date listed', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM #CM WHERE MemberId = @M1;
    INSERT INTO @T SELECT 'Members of the meeting: appointed on the date listed', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM #CM WHERE MemberId = @M2;
    INSERT INTO @T SELECT 'Members of the meeting: appointed the day after not listed', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM #CM WHERE MemberId = @M3;
    INSERT INTO @T SELECT 'Members of the meeting: no appointment date listed', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM #CM WHERE MemberId = @M4;
    INSERT INTO @T SELECT 'Members of the meeting: ceased the day before not listed', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM #CM WHERE MemberId = @M5;
    INSERT INTO @T SELECT 'Members of the meeting: appointed after but attendance saved, still listed', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM #CM WHERE MemberId = @M6;
    INSERT INTO @T SELECT 'Members of the meeting: cessation not a date counts as not ceased', '1', CAST(COUNT(*) AS VARCHAR(12)) FROM #CM WHERE MemberId = @M7;

    DELETE FROM #CM; INSERT INTO #CM EXEC spr_GetCommitteeMemberByCommitteeId @CommitteeId = @C16, @MeetingId = -1;
    INSERT INTO @T SELECT 'All members of the committee (-1): unchanged, all 7 listed', '7', CAST(COUNT(*) AS VARCHAR(12)) FROM #CM;

    DELETE FROM #VM; INSERT INTO #VM EXEC spr_GetCommitteeMemberByMeetingId @MeetingId = @MAppt;
    INSERT INTO @T SELECT 'Meeting print list: before / equal / after / no date / ceased / attended / bad cessation', '1 1 0 1 0 1 1',
           CAST(SUM(CASE WHEN MemberId = @M1 THEN 1 ELSE 0 END) AS VARCHAR(2)) + ' ' + CAST(SUM(CASE WHEN MemberId = @M2 THEN 1 ELSE 0 END) AS VARCHAR(2)) + ' '
         + CAST(SUM(CASE WHEN MemberId = @M3 THEN 1 ELSE 0 END) AS VARCHAR(2)) + ' ' + CAST(SUM(CASE WHEN MemberId = @M4 THEN 1 ELSE 0 END) AS VARCHAR(2)) + ' '
         + CAST(SUM(CASE WHEN MemberId = @M5 THEN 1 ELSE 0 END) AS VARCHAR(2)) + ' ' + CAST(SUM(CASE WHEN MemberId = @M6 THEN 1 ELSE 0 END) AS VARCHAR(2)) + ' '
         + CAST(SUM(CASE WHEN MemberId = @M7 THEN 1 ELSE 0 END) AS VARCHAR(2))
    FROM #VM;

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C16, @MeetingId = @MAppt, @MemberOf = 'C', @MemberId = @M3, @Attendance = 'P', @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Attendance: new row for a member appointed after the date refused', '0', CAST(Result AS VARCHAR(2)) FROM @R1;
    INSERT INTO @T SELECT 'Attendance: no row saved for that member', '0', CAST(COUNT(*) AS VARCHAR(12)) FROM Attendance WHERE MeetingId = @MAppt AND MemberId = @M3;

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C16, @MeetingId = @MAppt, @MemberOf = 'C', @MemberId = @M5, @Attendance = 'P', @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Attendance: new row for a member ceased before the date refused', '0', CAST(Result AS VARCHAR(2)) FROM @R1;

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C16, @MeetingId = @MAppt, @MemberOf = 'C', @MemberId = @M2, @Attendance = 'P', @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Attendance: member appointed on the date saved', '1', CAST(Result AS VARCHAR(2)) FROM @R1;

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C16, @MeetingId = @MAppt, @MemberOf = 'C', @MemberId = @M6, @Attendance = 'A', @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Attendance: saved row of a member appointed after can still be edited', '1 A',
           CAST((SELECT Result FROM @R1) AS VARCHAR(2)) + ' ' + (SELECT Attendance FROM Attendance WHERE MeetingId = @MAppt AND MemberId = @M6);

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C16, @MeetingId = @MAppt, @MemberOf = 'M', @MemberId = @M3, @Attendance = 'P', @UpdatedBy = @Ctrl;
    INSERT INTO @T SELECT 'Attendance: invitee row (M) not affected', '1', CAST(Result AS VARCHAR(2)) FROM @R1;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MAppt, @CommitteeId = @C16, @ChairmanNameId = @M3;
    INSERT INTO @T SELECT 'Chairman: member appointed after the date refused', 'Result 0, Reason 9, ZZ16 After', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MAppt, @CommitteeId = @C16, @ChairmanNameId = @M1;
    INSERT INTO @T SELECT 'Chairman: member on the committee saved', 'Result 1, Reason 0', Txt FROM @R;
    UPDATE Meeting SET ChairmanNameId = @M3 WHERE MeetingId = @MAppt;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MAppt, @CommitteeId = @C16, @ChairmanNameId = @M3;
    INSERT INTO @T SELECT 'Chairman: unchanged chairman saved earlier can be saved again', 'Result 1, Reason 0', Txt FROM @R;

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

-- Confirm nothing was kept: should be 0 0 and the option should read as before the test.
SELECT (SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z16', 'Z17')) AS TestCommitteesLeft,
       (SELECT COUNT(*) FROM Member WHERE MemberCode LIKE 'ZZ16M%') AS TestMembersLeft,
       (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass') AS AgendaControllerBypass;
GO

SET NOEXEC OFF;
GO
