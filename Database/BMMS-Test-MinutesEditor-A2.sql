/* ============================================================================
   BMMS - Test setup for the rich-text editor on Update Minutes (step A2a) and,
   later, Followup and the Dashboard action items (step A3)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY on the database BMMS_Test: every part stops with a message on any
   other database. It has no USE line: select BMMS_Test in SSMS first.

   The file has four parts. Select the lines of ONE part and press F5.
   Every row is written through the stored procedures the pages use, so their
   rules are exercised; no table is written directly. No mail is sent (only
   the pages send mail). The file is plain ASCII: Tamil, Hindi and the rupee
   sign are written with NCHAR().

   Before part 1: set @ControllerLogin at the top of part 1 to the login of an
   active Controller on BMMS_Test (Users.LoginName, not the system account,
   with a department). Everything is created, approved and updated as that
   user; the agenda items take that user's department. Part 1b reads the user
   back from the test committee.

   Test rows (one letter and digits, A sorts below the real C and M codes, so
   spr_GetNextCommitteeCode and spr_GetNextMemberCode are not affected; the
   committee code has 3 characters because spr_AddEditAgendaByController
   numbers agenda items by position and a 4-character code gives every item
   -001, see step N3):
     committee A92  "ZZ A2 minutes editor"
     members   A921 "ZZ A2 member 1 (chair)"   committee member, chairman
               A922 "ZZ A2 member 2"           committee member
               A923 "ZZ A2 member 3 (invitee)" meeting member of both meetings
     meetings  00951  today: agenda finalised, attendance entered, minutes
                      OPEN (3 items, none updated yet): Update Minutes and
                      Minutes Finalisation
               00952  today: agenda finalised, attendance entered, both
                      minutes updated (item 1 decision Followup), minutes
                      FINALISED: one Pending action item, mapped to every
                      active user (Followup, Dashboard action list)
   Seen by other users of BMMS_Test until part 3 (accepted): the committee,
   meeting and agenda alerts, and the action item on every Dashboard.

   PART 1   Creates everything above in one transaction; any refusal of a
            procedure rolls back all of it and names the step and Reason.
            Refuses when rows of an earlier run are still there (run part 3
            first) or when a test code is used by a row that is not a test
            row. Lists any trigger on the tables it writes (they could write
            rows this file does not know about).
   PART 1b  Optional: confirms the minutes of 00952
            (spr_MinutesConfirmByMeetingId), for a page that lists confirmed
            minutes only.
   PART 2   Read-only: everything the setup created, the workflow state of
            both meetings and the Controller's Dashboard action list.
   PART 3   Cleanup: deletes, by id, every row of the test committee, its
            meetings and members, including rows added in the browser tests
            (agenda items, minutes, action items, attendance, alerts, audit
            rows), prints one count per table and then checks that nothing is
            left. Refuses, deleting nothing, when a test code or name was
            changed on screen or when other data uses the test rows.

   Running it twice: part 1 refuses while the rows of an earlier run exist;
   part 3 with nothing to delete says so. Only identity values move on. The
   meetings are dated on the day part 1 runs; for a fresh setup on another
   day run part 3, then part 1.

   No TRY_CONVERT, THROW, IIF, FORMAT, CONCAT or OFFSET (compatibility level
   100). The procedures themselves may THROW; part 1 catches it and rolls
   back.
   ============================================================================ */


/* ============================================================================
   PART 1 - create the test setup
   ============================================================================ */
SET NOCOUNT ON;

-- Set this first: the login (Users.LoginName) of an active Controller on BMMS_Test
DECLARE @ControllerLogin VARCHAR(50) = '<set the Controller login>';

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

IF (@ControllerLogin LIKE '%<%' OR LTRIM(RTRIM(@ControllerLogin)) = '')
BEGIN
    RAISERROR('Set @ControllerLogin at the top of part 1 to the login of an active Controller, then run part 1 again. Nothing was changed.', 16, 1);
    RETURN;
END

-- The workflow order (step 23) and the Unicode procedures (step 31) are what this setup goes through
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_WorkflowState')), '') NOT LIKE '%WorkflowOrder-Step23%'
    OR OBJECT_ID('dbo.spr_AddEditAgendaByController') IS NULL)
BEGIN
    RAISERROR('Step 23 (BMMS-Fix-WorkflowOrder-Step23.sql) is not installed on this database. Nothing was changed.', 16, 1);
    RETURN;
END

-- The Controller
DECLARE @Ctl INT, @CtlDept INT, @CtlRole VARCHAR(50), @CtlActive INT, @CtlSystem INT, @CtlCount INT;
SELECT @CtlCount = COUNT(*) FROM Users WHERE LoginName = @ControllerLogin;
SELECT TOP 1 @Ctl = u.UserId, @CtlDept = u.DepartmentId, @CtlRole = r.RoleCode,
       @CtlActive = CAST(u.AccountStatus AS INT), @CtlSystem = CAST(ISNULL(u.IsSystem, 0) AS INT)
FROM Users u LEFT JOIN Roles r ON r.RoleId = u.RoleId
WHERE u.LoginName = @ControllerLogin
ORDER BY u.UserId;

IF (@CtlCount <> 1)
BEGIN
    RAISERROR('The login "%s" was found %d times (expected once). Nothing was changed.', 16, 1, @ControllerLogin, @CtlCount);
    RETURN;
END
IF (ISNULL(@CtlRole, '') <> 'controller' OR ISNULL(@CtlActive, 0) <> 1 OR @CtlSystem = 1)
BEGIN
    RAISERROR('The login "%s" is not an active Controller (or it is the system account). Nothing was changed.', 16, 1, @ControllerLogin);
    RETURN;
END
IF (@CtlDept IS NULL OR NOT EXISTS (SELECT 1 FROM Department WHERE DepartmentId = @CtlDept))
BEGIN
    RAISERROR('The Controller "%s" has no department; the agenda items need one. Nothing was changed.', 16, 1, @ControllerLogin);
    RETURN;
END

-- Lookups (the first active row of each, as a page would offer them)
DECLARE @TypeC INT = (SELECT TOP 1 MemberTypeId FROM Member_Type WHERE MemberScope = 'C' AND StatusId = 1 ORDER BY MemberTypeId);
DECLARE @TypeM INT = (SELECT TOP 1 MemberTypeId FROM Member_Type WHERE MemberScope = 'M' AND StatusId = 1 ORDER BY MemberTypeId);
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation WHERE StatusId = 1 ORDER BY DesignationId);
DECLARE @SexId INT = (SELECT TOP 1 SysCodeId FROM SysCodeSetting WHERE MainCode = 'Sex' AND IsActive = 1 ORDER BY DisplayOrder, SysCodeId);
DECLARE @StateIdNo INT = (SELECT MIN(State_Id) FROM State_Master);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DecisionOther INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);
DECLARE @ColorCode VARCHAR(50) = (SELECT TOP 1 CommitteeColorCode FROM Committee WHERE ISNULL(CommitteeColorCode, '') <> '' ORDER BY CommitteeId);

IF (@TypeC IS NULL OR @TypeM IS NULL OR @DesignationId IS NULL OR @SexId IS NULL OR @StateIdNo IS NULL
    OR @SubjectTypeId IS NULL OR @DecisionOther IS NULL
    OR NOT EXISTS (SELECT 1 FROM Decision_Type WHERE DecisionTypeId = 1)
    OR NOT EXISTS (SELECT 1 FROM Agenda_Status WHERE AgendaStatusCode = 'ACA'))
BEGIN
    RAISERROR('A lookup row is missing: an active member type of scope C and of scope M, an active designation, a Sex code, a state, a subject type, decision type 1 and another one, agenda status ACA. Nothing was changed.', 16, 1);
    RETURN;
END
IF (@ColorCode IS NULL)
    SET @ColorCode = '';

-- Test codes used by rows that are not test rows: change the codes in this file
DECLARE @Taken INT =
      (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'A92' AND CommitteeName NOT LIKE 'ZZ A2%')
    + (SELECT COUNT(*) FROM Member WHERE MemberCode IN ('A921', 'A922', 'A923') AND MemberName NOT LIKE 'ZZ A2 member%');
IF (@Taken > 0)
BEGIN
    RAISERROR('The test code A92, A921, A922 or A923 is used by %d row(s) that are not test rows. Change the test codes in this file. Nothing was changed.', 16, 1, @Taken);
    RETURN;
END

-- Rows of an earlier run
DECLARE @Earlier INT =
      (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'A92' OR CommitteeName LIKE 'ZZ A2 minutes editor%')
    + (SELECT COUNT(*) FROM Member WHERE MemberCode IN ('A921', 'A922', 'A923') OR MemberName LIKE 'ZZ A2 member%');
IF (@Earlier > 0)
BEGIN
    RAISERROR('%d test row(s) from an earlier run are still there. Run part 3 first. Nothing was changed.', 16, 1, @Earlier);
    RETURN;
END

-- Triggers on the tables the procedures write (information only)
DECLARE @Triggers NVARCHAR(2000) = N'';
SELECT @Triggers = @Triggers + OBJECT_NAME(t.parent_id) + N'.' + t.name + N'  '
FROM sys.triggers t
WHERE t.parent_class = 1
  AND OBJECT_NAME(t.parent_id) IN ('Committee', 'Member', 'Committee_Member', 'Meeting', 'Meeting_Member', 'Agenda', 'Minutes',
                                    'Attendance', 'Action_Item', 'ActionItem_User_Map', 'Alert_Master', 'Alert_User_Map', 'Audit_Trail_Master');
IF (@Triggers <> N'')
BEGIN
    DECLARE @TriggerLine NVARCHAR(2100) = N'Note: triggers on the tables written: ' + @Triggers + N'- check part 2 for rows they write.';
    PRINT @TriggerLine;
END

-- Values
DECLARE @Now DATETIME = GETDATE();
DECLARE @Today DATETIME = CAST(CAST(GETDATE() AS date) AS DATETIME);
DECLARE @Incorporation DATETIME = '20000101';
DECLARE @StateId VARCHAR(50) = CAST(@StateIdNo AS VARCHAR(50));
DECLARE @CommitteeName VARCHAR(50) = 'ZZ A2 minutes editor';

DECLARE @Tamil NVARCHAR(50) = NCHAR(0x0B95) + NCHAR(0x0BC2) + NCHAR(0x0B9F) + NCHAR(0x0BCD) + NCHAR(0x0B9F) + NCHAR(0x0BAE) + NCHAR(0x0BCD);
DECLARE @Hindi NVARCHAR(50) = NCHAR(0x092C) + NCHAR(0x0948) + NCHAR(0x0920) + NCHAR(0x0915);
DECLARE @Rupee NVARCHAR(50) = NCHAR(0x20B9) + N' 1,250.00';

-- The texts in the form HtmlCleaner.Clean writes them
DECLARE @Text1 NVARCHAR(MAX) = N'<p><strong>ZZ A2</strong> rich text item.</p><ul><li>First point</li><li>Second point</li><li>Third point</li></ul>'
    + N'<table border="1" cellpadding="4" cellspacing="0"><tbody><tr><td>A1</td><td>B1</td></tr><tr><td>A2</td><td>B2</td></tr></tbody></table>';
DECLARE @Res1 NVARCHAR(MAX) = N'<ol><li>Resolved first.</li><li>Resolved second.</li></ol>';
DECLARE @Text2 NVARCHAR(MAX) = N'<p>Tamil: ' + @Tamil + N'</p><p>Hindi: ' + @Hindi + N'</p><p>Amount: ' + @Rupee + N'</p>';
DECLARE @Res2 NVARCHAR(MAX) = N'<p>Resolved: ' + @Tamil + N' ' + @Hindi + N' ' + @Rupee + N'</p>';
DECLARE @Text3 NVARCHAR(MAX) = N'<p>ZZ A2 plain agenda text.</p>';
DECLARE @Res3 NVARCHAR(MAX) = N'<p>ZZ A2 plain resolution.</p>';
DECLARE @Text4 NVARCHAR(MAX) = N'<p>ZZ A2 follow up item.</p>';
DECLARE @Res4 NVARCHAR(MAX) = N'<p>Action to be taken by the department.</p>';
DECLARE @Text5 NVARCHAR(MAX) = N'<p>ZZ A2 sanctioned item.</p>';
DECLARE @Res5 NVARCHAR(MAX) = N'<p>Sanctioned.</p>';
DECLARE @Short1 NVARCHAR(MAX) = N'ZZ A2 rich text';
DECLARE @Short2 NVARCHAR(MAX) = N'ZZ A2 unicode';
DECLARE @Short3 NVARCHAR(MAX) = N'ZZ A2 plain';
DECLARE @Short4 NVARCHAR(MAX) = N'ZZ A2 follow up';
DECLARE @Short5 NVARCHAR(MAX) = N'ZZ A2 sanctioned';
DECLARE @Empty NVARCHAR(MAX) = N'';

DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @R1 TABLE (Result INT);
DECLARE @Res INT, @Rea INT, @Det NVARCHAR(2000), @Step NVARCHAR(200);

DECLARE @CommitteeId INT, @M1 INT, @M2 INT, @M3 INT, @Meet1 INT, @Meet2 INT;
DECLARE @Ag1 INT, @Ag2 INT, @Ag3 INT, @Ag4 INT, @Ag5 INT, @Min4 INT, @Min5 INT;

BEGIN TRY
    BEGIN TRANSACTION;

    -- 1. Committee (no result set: found again by code and name)
    EXEC dbo.spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'A92', @CommitteeName = @CommitteeName,
        @Board = 0, @IncorporationDate = @Incorporation, @MeetingStartNo = 951, @CommitteeColorCode = @ColorCode,
        @CessationDate = '', @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SET @CommitteeId = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'A92' AND CommitteeName = @CommitteeName);
    IF (@CommitteeId IS NULL)
        RAISERROR('Step 1 (spr_AddEditCommittee): the committee A92 was not created.', 16, 1);

    -- 2. Members
    EXEC dbo.spr_AddEditMember @Code = 'Save', @MemberId = 0, @MemberCode = 'A921', @MemberName = 'ZZ A2 member 1 (chair)',
        @SexId = @SexId, @DesignationId = @DesignationId, @DOB = '01-Jan-1970', @Address1 = 'ZZ A2', @Address2 = '', @Address3 = '',
        @CityName = 'ZZ A2', @State_Id = @StateId, @PinCode = '600001', @DOJ = '01-Jan-2020', @EmailId = 'zz-a2-member1@example.invalid',
        @DinNo = '', @PhotoPath = '', @ResumePath = '', @RelievingDate = '', @StatusId = 1,
        @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    EXEC dbo.spr_AddEditMember @Code = 'Save', @MemberId = 0, @MemberCode = 'A922', @MemberName = 'ZZ A2 member 2',
        @SexId = @SexId, @DesignationId = @DesignationId, @DOB = '01-Jan-1971', @Address1 = 'ZZ A2', @Address2 = '', @Address3 = '',
        @CityName = 'ZZ A2', @State_Id = @StateId, @PinCode = '600001', @DOJ = '01-Jan-2020', @EmailId = 'zz-a2-member2@example.invalid',
        @DinNo = '', @PhotoPath = '', @ResumePath = '', @RelievingDate = '', @StatusId = 1,
        @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    EXEC dbo.spr_AddEditMember @Code = 'Save', @MemberId = 0, @MemberCode = 'A923', @MemberName = 'ZZ A2 member 3 (invitee)',
        @SexId = @SexId, @DesignationId = @DesignationId, @DOB = '01-Jan-1972', @Address1 = 'ZZ A2', @Address2 = '', @Address3 = '',
        @CityName = 'ZZ A2', @State_Id = @StateId, @PinCode = '600001', @DOJ = '01-Jan-2020', @EmailId = 'zz-a2-member3@example.invalid',
        @DinNo = '', @PhotoPath = '', @ResumePath = '', @RelievingDate = '', @StatusId = 1,
        @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SET @M1 = (SELECT MemberId FROM Member WHERE MemberCode = 'A921' AND MemberName LIKE 'ZZ A2 member%');
    SET @M2 = (SELECT MemberId FROM Member WHERE MemberCode = 'A922' AND MemberName LIKE 'ZZ A2 member%');
    SET @M3 = (SELECT MemberId FROM Member WHERE MemberCode = 'A923' AND MemberName LIKE 'ZZ A2 member%');
    IF (@M1 IS NULL OR @M2 IS NULL OR @M3 IS NULL)
        RAISERROR('Step 2 (spr_AddEditMember): a test member was not created.', 16, 1);

    -- 3. Committee members A921 and A922
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditCommitteeMember @Code = 'Save', @CommitteeMemberId = 0, @CommitteeId = @CommitteeId, @MemberId = @M1,
        @MemberTypeId = @TypeC, @AppointmentDate = @Today, @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 3 (spr_AddEditCommitteeMember, A921)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditCommitteeMember @Code = 'Save', @CommitteeMemberId = 0, @CommitteeId = @CommitteeId, @MemberId = @M2,
        @MemberTypeId = @TypeC, @AppointmentDate = @Today, @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 3 (spr_AddEditCommitteeMember, A922)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    -- 4. Meetings 00951 and 00952, today (step 24 accepts today)
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '00951', @CommitteeId = @CommitteeId, @Place = 'ZZ A2',
        @Venue = 'ZZ A2 minutes open', @MeetingDate = @Today, @MeetingTime = '10:00', @AgendaSubmissionDate = @Today,
        @MeetingColorCode = '', @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 4 (spr_AddEditMeeting, 00951)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '00952', @CommitteeId = @CommitteeId, @Place = 'ZZ A2',
        @Venue = 'ZZ A2 minutes finalised', @MeetingDate = @Today, @MeetingTime = '11:00', @AgendaSubmissionDate = @Today,
        @MeetingColorCode = '', @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 4 (spr_AddEditMeeting, 00952)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    SET @Meet1 = (SELECT MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00951');
    SET @Meet2 = (SELECT MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00952');
    IF (@Meet1 IS NULL OR @Meet2 IS NULL)
        RAISERROR('Step 4 (spr_AddEditMeeting): a test meeting was not found after the save.', 16, 1);

    -- 5. Meeting member A923 on both meetings
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @Meet1, @MemberId = @M3,
        @MemberTypeId = @TypeM, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 5 (spr_AddEditMeetingMember, 00951)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @Meet2, @MemberId = @M3,
        @MemberTypeId = @TypeM, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 5 (spr_AddEditMeetingMember, 00952)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    -- 6. Agenda items by the Controller: approved at once (ACA), Subject No = MAX + 1, Agenda No by the procedure
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @CommitteeId, @MeetingId = @Meet1,
        @DepartmentId = @CtlDept, @SubjectTypeId = @SubjectTypeId, @ShortText = @Short1, @AgendaType = 'Entry', @AgendaText = @Text1,
        @AgendaTextPath = @Empty, @ProposedResolution = @Res1, @FilePath = @Empty, @MgrComments = @Empty, @ControllerComments = @Empty,
        @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = 0, @ActingUserId = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 6 (spr_AddEditAgendaByController, 00951 item 1)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @CommitteeId, @MeetingId = @Meet1,
        @DepartmentId = @CtlDept, @SubjectTypeId = @SubjectTypeId, @ShortText = @Short2, @AgendaType = 'Entry', @AgendaText = @Text2,
        @AgendaTextPath = @Empty, @ProposedResolution = @Res2, @FilePath = @Empty, @MgrComments = @Empty, @ControllerComments = @Empty,
        @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = 0, @ActingUserId = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 6 (spr_AddEditAgendaByController, 00951 item 2)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @CommitteeId, @MeetingId = @Meet1,
        @DepartmentId = @CtlDept, @SubjectTypeId = @SubjectTypeId, @ShortText = @Short3, @AgendaType = 'Entry', @AgendaText = @Text3,
        @AgendaTextPath = @Empty, @ProposedResolution = @Res3, @FilePath = @Empty, @MgrComments = @Empty, @ControllerComments = @Empty,
        @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = 0, @ActingUserId = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 6 (spr_AddEditAgendaByController, 00951 item 3)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @CommitteeId, @MeetingId = @Meet2,
        @DepartmentId = @CtlDept, @SubjectTypeId = @SubjectTypeId, @ShortText = @Short4, @AgendaType = 'Entry', @AgendaText = @Text4,
        @AgendaTextPath = @Empty, @ProposedResolution = @Res4, @FilePath = @Empty, @MgrComments = @Empty, @ControllerComments = @Empty,
        @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = 0, @ActingUserId = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 6 (spr_AddEditAgendaByController, 00952 item 1)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @CommitteeId, @MeetingId = @Meet2,
        @DepartmentId = @CtlDept, @SubjectTypeId = @SubjectTypeId, @ShortText = @Short5, @AgendaType = 'Entry', @AgendaText = @Text5,
        @AgendaTextPath = @Empty, @ProposedResolution = @Res5, @FilePath = @Empty, @MgrComments = @Empty, @ControllerComments = @Empty,
        @CurrentStatus = 'New', @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = 0, @ActingUserId = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 6 (spr_AddEditAgendaByController, 00952 item 2)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    SET @Ag1 = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet1 AND CAST(ShortText AS NVARCHAR(MAX)) = @Short1);
    SET @Ag2 = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet1 AND CAST(ShortText AS NVARCHAR(MAX)) = @Short2);
    SET @Ag3 = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet1 AND CAST(ShortText AS NVARCHAR(MAX)) = @Short3);
    SET @Ag4 = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet2 AND CAST(ShortText AS NVARCHAR(MAX)) = @Short4);
    SET @Ag5 = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet2 AND CAST(ShortText AS NVARCHAR(MAX)) = @Short5);
    IF (@Ag1 IS NULL OR @Ag2 IS NULL OR @Ag3 IS NULL OR @Ag4 IS NULL OR @Ag5 IS NULL)
        RAISERROR('Step 6 (spr_AddEditAgendaByController): an agenda item was not found after the save.', 16, 1);

    -- 7. Agenda Finalisation: the agenda closes and each approved item gets its Minutes row
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AgendaFinalizeByMeetingId @MeetingId = @Meet1;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 7 (spr_AgendaFinalizeByMeetingId, 00951)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_AgendaFinalizeByMeetingId @MeetingId = @Meet2;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 7 (spr_AgendaFinalizeByMeetingId, 00952)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    -- 8. Chairman A921 (after Agenda Finalisation, as step 23 requires)
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_UpdateMeetingChairman @MeetingId = @Meet1, @CommitteeId = @CommitteeId, @ChairmanNameId = @M1;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 8 (spr_UpdateMeetingChairman, 00951)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_UpdateMeetingChairman @MeetingId = @Meet2, @CommitteeId = @CommitteeId, @ChairmanNameId = @M1;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 8 (spr_UpdateMeetingChairman, 00952)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    -- 9. Attendance: A921 and A922 as committee members (C), A923 as meeting member (M), all present
    DELETE FROM @R1;
    INSERT INTO @R1 EXEC dbo.spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Meet1, @MemberOf = 'C', @MemberId = @M1, @Attendance = 'P', @UpdatedBy = @Ctl;
    INSERT INTO @R1 EXEC dbo.spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Meet1, @MemberOf = 'C', @MemberId = @M2, @Attendance = 'P', @UpdatedBy = @Ctl;
    INSERT INTO @R1 EXEC dbo.spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Meet1, @MemberOf = 'M', @MemberId = @M3, @Attendance = 'P', @UpdatedBy = @Ctl;
    INSERT INTO @R1 EXEC dbo.spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Meet2, @MemberOf = 'C', @MemberId = @M1, @Attendance = 'P', @UpdatedBy = @Ctl;
    INSERT INTO @R1 EXEC dbo.spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Meet2, @MemberOf = 'C', @MemberId = @M2, @Attendance = 'P', @UpdatedBy = @Ctl;
    INSERT INTO @R1 EXEC dbo.spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Meet2, @MemberOf = 'M', @MemberId = @M3, @Attendance = 'P', @UpdatedBy = @Ctl;
    SET @Res = (SELECT COUNT(*) FROM @R1 WHERE Result = 1);
    IF (@Res <> 6)
        RAISERROR('Step 9 (spr_UpdateAttendance): %d of 6 attendance saves were accepted.', 16, 1, @Res);

    -- 10. Meeting 00952: both minutes updated (item 1 Followup, which makes the action item; item 2 another decision)
    SET @Min4 = (SELECT MinutesId FROM Minutes WHERE AgendaId = @Ag4);
    SET @Min5 = (SELECT MinutesId FROM Minutes WHERE AgendaId = @Ag5);
    IF (@Min4 IS NULL OR @Min5 IS NULL)
        RAISERROR('Step 7 (spr_AgendaFinalizeByMeetingId): the minutes of meeting 00952 were not created.', 16, 1);

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_UpdateMinutes @Code = 'All', @MinutesId = @Min4, @DecisionTypeId = 1, @Directions = @Empty, @ActualResolution = @Empty,
        @ShortText = @Short4, @CreatedBy = @Ctl, @UpdatedBy = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 10 (spr_UpdateMinutes All, 00952 item 1)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_UpdateMinutes @Code = 'All', @MinutesId = @Min5, @DecisionTypeId = @DecisionOther, @Directions = @Empty, @ActualResolution = @Empty,
        @ShortText = @Short5, @CreatedBy = @Ctl, @UpdatedBy = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 10 (spr_UpdateMinutes All, 00952 item 2)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    -- 11. Minutes Finalisation of 00952: status F, the Pending action item mapped to the active users
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC dbo.spr_MinutesFinalizeByMeetingId @MeetingId = @Meet2, @UserId = @Ctl;
    SELECT @Res = NULL, @Rea = NULL, @Det = NULL;
    SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;
    IF (ISNULL(@Res, 0) <> 1)
    BEGIN
        SET @Step = N'Step 11 (spr_MinutesFinalizeByMeetingId, 00952)';
        RAISERROR('%s refused: Result %d, Reason %d %s', 16, 1, @Step, @Res, @Rea, @Det);
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    DECLARE @ErrorText NVARCHAR(2048) = ERROR_MESSAGE();
    RAISERROR('Part 1 failed and was rolled back, nothing was changed: %s', 16, 1, @ErrorText);
    RETURN;
END CATCH

-- Summary
DECLARE @No1 VARCHAR(50) = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @Ag1);
DECLARE @No3 VARCHAR(50) = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @Ag3);
DECLARE @No4 VARCHAR(50) = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @Ag4);
DECLARE @No5 VARCHAR(50) = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @Ag5);
DECLARE @Subj1 VARCHAR(200) = (SELECT CAST(MIN(SubjectNo) AS VARCHAR(12)) + ' to ' + CAST(MAX(SubjectNo) AS VARCHAR(12)) FROM Agenda WHERE MeetingId = @Meet1);
DECLARE @Subj2 VARCHAR(200) = (SELECT CAST(MIN(SubjectNo) AS VARCHAR(12)) + ' to ' + CAST(MAX(SubjectNo) AS VARCHAR(12)) FROM Agenda WHERE MeetingId = @Meet2);
DECLARE @State1 VARCHAR(200) = (SELECT CAST(IsNew AS VARCHAR(2)) + ',' + CAST(AgendaFinalized AS VARCHAR(2)) + ',' + CAST(AttendanceRecorded AS VARCHAR(2))
                                       + ',' + CAST(MinutesUpdated AS VARCHAR(12)) + '/' + CAST(MinutesTotal AS VARCHAR(12)) FROM dbo.fn_WorkflowState(@Meet1));
DECLARE @State2 VARCHAR(200) = (SELECT CAST(IsNew AS VARCHAR(2)) + ',' + CAST(AgendaFinalized AS VARCHAR(2)) + ',' + CAST(AttendanceRecorded AS VARCHAR(2))
                                       + ',' + CAST(MinutesUpdated AS VARCHAR(12)) + '/' + CAST(MinutesTotal AS VARCHAR(12)) FROM dbo.fn_WorkflowState(@Meet2));
DECLARE @Status2 VARCHAR(50) = (SELECT ISNULL(MinutesStatus, 'Open') FROM Meeting WHERE MeetingId = @Meet2);
DECLARE @ActionItems INT = (SELECT COUNT(*) FROM Action_Item WHERE MinutesId IN (@Min4, @Min5));
DECLARE @ActionMaps INT = (SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId IN (SELECT ActionItemId FROM Action_Item WHERE MinutesId IN (@Min4, @Min5)));

DECLARE @Line NVARCHAR(400);
SET @Line = N'Created: committee A92 (CommitteeId ' + CAST(@CommitteeId AS NVARCHAR(12)) + N'), members A921, A922, A923 (MemberId '
          + CAST(@M1 AS NVARCHAR(12)) + N', ' + CAST(@M2 AS NVARCHAR(12)) + N', ' + CAST(@M3 AS NVARCHAR(12)) + N').';
PRINT @Line;
SET @Line = N'Meeting 00951 (MeetingId ' + CAST(@Meet1 AS NVARCHAR(12)) + N'): items ' + ISNULL(@No1, N'?') + N' to ' + ISNULL(@No3, N'?')
          + N', Subject No ' + ISNULL(@Subj1, N'?') + N'; state new,agenda,attendance,updated/total = ' + ISNULL(@State1, N'?') + N' (expected 1,1,1,0/3).';
PRINT @Line;
SET @Line = N'Meeting 00952 (MeetingId ' + CAST(@Meet2 AS NVARCHAR(12)) + N'): items ' + ISNULL(@No4, N'?') + N', ' + ISNULL(@No5, N'?')
          + N', Subject No ' + ISNULL(@Subj2, N'?') + N'; state ' + ISNULL(@State2, N'?') + N' (expected 1,1,1,2/2), minutes status '
          + ISNULL(@Status2, N'?') + N' (expected F).';
PRINT @Line;
SET @Line = N'Action items: ' + CAST(@ActionItems AS NVARCHAR(12)) + N' (expected 1), mapped to ' + CAST(@ActionMaps AS NVARCHAR(12)) + N' user(s) (the active users).';
PRINT @Line;
PRINT N'Next: the browser checks (Database/README.md, test script for the minutes editor); part 2 lists everything; part 3 at the end.';
GO


/* ============================================================================
   PART 1b - optional: confirm the minutes of meeting 00952
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CommitteeId INT, @Ctl INT;
SELECT TOP 1 @CommitteeId = CommitteeId, @Ctl = CreatedBy FROM Committee
WHERE CommitteeCode = 'A92' AND CommitteeName LIKE 'ZZ A2 minutes editor%' ORDER BY CommitteeId;
IF (@CommitteeId IS NULL)
BEGIN
    RAISERROR('The test committee A92 was not found. Run part 1 first. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @Meet2 INT = (SELECT MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00952');
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @Res INT, @Rea INT, @Det NVARCHAR(2000);

IF (@Meet2 IS NULL)
BEGIN
    RAISERROR('Meeting 00952 of the test committee was not found. Nothing was changed.', 16, 1);
    RETURN;
END

INSERT INTO @R (Result, Reason, ReasonDetail)
EXEC dbo.spr_MinutesConfirmByMeetingId @MeetingId = @Meet2, @UserId = @Ctl;
SELECT TOP 1 @Res = Result, @Rea = Reason, @Det = ReasonDetail FROM @R;

DECLARE @Line NVARCHAR(400) = N'Confirm minutes of 00952: Result ' + ISNULL(CAST(@Res AS NVARCHAR(12)), N'?') + N', Reason '
    + ISNULL(CAST(@Rea AS NVARCHAR(12)), N'?') + N' ' + ISNULL(@Det, N'') + N' (expected Result 1; Reason 3 with C means it was already confirmed).';
PRINT @Line;
GO


/* ============================================================================
   PART 2 - read-only: the test setup
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CommitteeId INT, @Ctl INT;
SELECT TOP 1 @CommitteeId = CommitteeId, @Ctl = CreatedBy FROM Committee
WHERE CommitteeCode = 'A92' AND CommitteeName LIKE 'ZZ A2 minutes editor%' ORDER BY CommitteeId;

SELECT 'Committee' AS Grid, c.CommitteeId, c.CommitteeCode, c.CommitteeName, c.StatusId, c.CreatedBy, u.LoginName AS CreatedByLogin
FROM Committee c LEFT JOIN Users u ON u.UserId = c.CreatedBy
WHERE c.CommitteeCode = 'A92' OR c.CommitteeName LIKE 'ZZ A2%';

SELECT 'Members' AS Grid, m.MemberId, m.MemberCode, m.MemberName, m.StatusId,
       (SELECT COUNT(*) FROM Committee_Member cm WHERE cm.MemberId = m.MemberId) AS CommitteeTags,
       (SELECT COUNT(*) FROM Meeting_Member mm WHERE mm.MemberId = m.MemberId) AS MeetingTags
FROM Member m
WHERE m.MemberCode IN ('A921', 'A922', 'A923') OR m.MemberName LIKE 'ZZ A2 member%'
ORDER BY m.MemberCode;

SELECT 'Meetings' AS Grid, mt.MeetingId, mt.MeetingNo, mt.MeetingDate, ISNULL(mt.AgendaStatus, 'Open') AS AgendaStatus,
       ISNULL(mt.MinutesStatus, 'Open') AS MinutesStatus, ch.MemberCode AS Chairman,
       ws.IsNew, ws.AgendaFinalized, ws.AttendanceRecorded, ws.MinutesUpdated, ws.MinutesTotal,
       (SELECT COUNT(*) FROM Meeting_Member mm WHERE mm.MeetingId = mt.MeetingId) AS MeetingMembers,
       (SELECT COUNT(*) FROM Attendance a WHERE a.MeetingId = mt.MeetingId AND a.Attendance = 'P') AS Present
FROM Meeting mt
LEFT JOIN Member ch ON ch.MemberId = mt.ChairmanNameId
OUTER APPLY dbo.fn_WorkflowState(mt.MeetingId) ws
WHERE mt.CommitteeId = @CommitteeId
ORDER BY mt.MeetingNo;

SELECT 'Agenda items and minutes' AS Grid, a.AgendaId, a.AgendaNo, mt.MeetingNo, a.SubjectNo, a.AgendaStatusCode, a.ShortText,
       mi.MinutesId, mi.DecisionTypeId, mi.StatusId AS MinuteUpdated
FROM Agenda a
JOIN Meeting mt ON mt.MeetingId = a.MeetingId
LEFT JOIN Minutes mi ON mi.AgendaId = a.AgendaId
WHERE mt.CommitteeId = @CommitteeId
ORDER BY a.AgendaNo;

SELECT 'Action items' AS Grid, ai.ActionItemId, a.AgendaNo, ai.ActionStatus,
       (SELECT COUNT(*) FROM ActionItem_User_Map x WHERE x.ActionItemId = ai.ActionItemId) AS MappedUsers
FROM Action_Item ai
JOIN Minutes mi ON mi.MinutesId = ai.MinutesId
JOIN Agenda a ON a.AgendaId = mi.AgendaId
JOIN Meeting mt ON mt.MeetingId = a.MeetingId
WHERE mt.CommitteeId = @CommitteeId;

SELECT 'Alerts and audit rows' AS Grid,
       (SELECT COUNT(*) FROM Alert_Master am
        WHERE am.CommitteeId = @CommitteeId
           OR (am.SourceType = 'Committee' AND am.SourceTypeId = @CommitteeId)
           OR (am.SourceType = 'Meeting' AND am.SourceTypeId IN (SELECT MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId))
           OR (am.SourceType = 'Agenda' AND am.SourceTypeId IN (SELECT AgendaId FROM Agenda WHERE CommitteeId = @CommitteeId))) AS AlertMasterRows,
       (SELECT COUNT(*) FROM Audit_Trail_Master t
        WHERE t.Audit_Table = 'Agenda' AND t.Key_Field = 'AgendaNo' AND t.Key_Value LIKE 'A92-%'
          AND t.Key_Value IN (SELECT AgendaNo FROM Agenda WHERE CommitteeId = @CommitteeId)) AS AgendaAuditRows;

-- What the Dashboard action list shows the Controller who ran part 1 (it should include the A92-00952 item)
IF (@Ctl IS NOT NULL)
    EXEC dbo.spr_GetActionItemByUserId @UserId = @Ctl;
GO


/* ============================================================================
   PART 3 - cleanup by id, only for rows that match the test codes and names
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

-- The test rows, by code AND name
DECLARE @CommitteeId INT = (SELECT TOP 1 CommitteeId FROM Committee WHERE CommitteeCode = 'A92' AND CommitteeName LIKE 'ZZ A2 minutes editor%' ORDER BY CommitteeId);
DECLARE @Members TABLE (MemberId INT PRIMARY KEY, MemberCode VARCHAR(10));
INSERT INTO @Members (MemberId, MemberCode)
SELECT MemberId, MemberCode FROM Member WHERE MemberCode IN ('A921', 'A922', 'A923') AND MemberName LIKE 'ZZ A2 member%';

-- A code or a name that no longer matches: changed on screen, or a row that is not a test row
DECLARE @Mismatch INT =
      (SELECT COUNT(*) FROM Committee WHERE (CommitteeCode = 'A92' AND CommitteeName NOT LIKE 'ZZ A2 minutes editor%')
                                         OR (CommitteeName LIKE 'ZZ A2 minutes editor%' AND CommitteeCode <> 'A92'))
    + (SELECT COUNT(*) FROM Member WHERE (MemberCode IN ('A921', 'A922', 'A923') AND MemberName NOT LIKE 'ZZ A2 member%')
                                      OR (MemberName LIKE 'ZZ A2 member%' AND MemberCode NOT IN ('A921', 'A922', 'A923')));
IF (@Mismatch > 0)
BEGIN
    RAISERROR('%d row(s) carry a test code with another name, or a test name with another code (edited on screen, or not a test row). Put the code and name back, or delete them by hand. Nothing was deleted.', 16, 1, @Mismatch);
    RETURN;
END

IF (@CommitteeId IS NULL AND NOT EXISTS (SELECT 1 FROM @Members))
BEGIN
    PRINT N'The test committee A92 and the test members were not found: nothing to delete.';
    RETURN;
END

DECLARE @Meetings TABLE (MeetingId INT PRIMARY KEY);
INSERT INTO @Meetings (MeetingId) SELECT MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo IN ('00951', '00952');

DECLARE @Agendas TABLE (AgendaId INT PRIMARY KEY, AgendaNo VARCHAR(50) NULL);
INSERT INTO @Agendas (AgendaId, AgendaNo)
SELECT AgendaId, AgendaNo FROM Agenda WHERE MeetingId IN (SELECT MeetingId FROM @Meetings) OR CommitteeId = @CommitteeId;

DECLARE @Minutes TABLE (MinutesId INT PRIMARY KEY);
INSERT INTO @Minutes (MinutesId) SELECT MinutesId FROM Minutes WHERE AgendaId IN (SELECT AgendaId FROM @Agendas);

DECLARE @ActionItems TABLE (ActionItemId INT PRIMARY KEY);
INSERT INTO @ActionItems (ActionItemId) SELECT ActionItemId FROM Action_Item WHERE MinutesId IN (SELECT MinutesId FROM @Minutes);

DECLARE @CommitteeMembers TABLE (CommitteeMemberId INT PRIMARY KEY);
INSERT INTO @CommitteeMembers (CommitteeMemberId)
SELECT CommitteeMemberId FROM Committee_Member WHERE CommitteeId = @CommitteeId OR MemberId IN (SELECT MemberId FROM @Members);

DECLARE @MeetingMembers TABLE (MeetingMemberId INT PRIMARY KEY);
INSERT INTO @MeetingMembers (MeetingMemberId)
SELECT MeetingMemberId FROM Meeting_Member WHERE MeetingId IN (SELECT MeetingId FROM @Meetings) OR MemberId IN (SELECT MemberId FROM @Members);

DECLARE @Alerts TABLE (AlertId INT PRIMARY KEY);
INSERT INTO @Alerts (AlertId)
SELECT AlertId FROM Alert_Master
WHERE (@CommitteeId IS NOT NULL AND CommitteeId = @CommitteeId)
   OR (SourceType = 'Committee' AND SourceTypeId = @CommitteeId)
   OR (SourceType = 'Meeting' AND SourceTypeId IN (SELECT MeetingId FROM @Meetings))
   OR (SourceType = 'Agenda' AND SourceTypeId IN (SELECT AgendaId FROM @Agendas));

-- Keys the audit trail could carry for the test rows (the procedures in this repository write Agenda / AgendaNo only)
DECLARE @AuditKeys TABLE (Audit_Table VARCHAR(100), Key_Value VARCHAR(100));
INSERT INTO @AuditKeys SELECT 'Agenda', AgendaNo FROM @Agendas WHERE AgendaNo LIKE 'A92-%';
INSERT INTO @AuditKeys SELECT 'Agenda', CAST(AgendaId AS VARCHAR(100)) FROM @Agendas;
INSERT INTO @AuditKeys SELECT 'Committee', 'A92' WHERE @CommitteeId IS NOT NULL;
INSERT INTO @AuditKeys SELECT 'Committee', CAST(@CommitteeId AS VARCHAR(100)) WHERE @CommitteeId IS NOT NULL;
INSERT INTO @AuditKeys SELECT 'Member', MemberCode FROM @Members;
INSERT INTO @AuditKeys SELECT 'Member', CAST(MemberId AS VARCHAR(100)) FROM @Members;
INSERT INTO @AuditKeys SELECT 'Committee_Member', CAST(CommitteeMemberId AS VARCHAR(100)) FROM @CommitteeMembers;
INSERT INTO @AuditKeys SELECT 'Meeting', CAST(MeetingId AS VARCHAR(100)) FROM @Meetings;
INSERT INTO @AuditKeys SELECT 'Meeting', 'A92-' + MeetingNo FROM Meeting WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
INSERT INTO @AuditKeys SELECT 'Meeting_Member', CAST(MeetingMemberId AS VARCHAR(100)) FROM @MeetingMembers;
INSERT INTO @AuditKeys SELECT 'Minutes', CAST(MinutesId AS VARCHAR(100)) FROM @Minutes;
INSERT INTO @AuditKeys SELECT 'Action_Item', CAST(ActionItemId AS VARCHAR(100)) FROM @ActionItems;

-- Other data that uses the test rows stops the cleanup
DECLARE @OtherMeetings INT, @OtherAgendas INT, @OtherChair INT, @OtherAttendance INT;
SELECT @OtherMeetings = COUNT(*) FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings);
SELECT @OtherAgendas = COUNT(*) FROM Agenda WHERE AgendaId IN (SELECT AgendaId FROM @Agendas)
                                              AND (CommitteeId <> @CommitteeId OR MeetingId NOT IN (SELECT MeetingId FROM @Meetings));
SELECT @OtherChair = COUNT(*) FROM Meeting WHERE ChairmanNameId IN (SELECT MemberId FROM @Members) AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings);
SELECT @OtherAttendance = COUNT(*) FROM Attendance WHERE MemberId IN (SELECT MemberId FROM @Members) AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings);
DECLARE @OtherTags INT =
      (SELECT COUNT(*) FROM Committee_Member WHERE MemberId IN (SELECT MemberId FROM @Members) AND ISNULL(CommitteeId, 0) <> ISNULL(@CommitteeId, -1))
    + (SELECT COUNT(*) FROM Meeting_Member WHERE MemberId IN (SELECT MemberId FROM @Members) AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings));

IF (@OtherMeetings + @OtherAgendas + @OtherChair + @OtherAttendance + @OtherTags > 0)
BEGIN
    RAISERROR('Other rows use the test rows; this cleanup does not delete them. Other meetings of A92 %d, agenda items under another committee or meeting %d, test members chairing other meetings %d, attendance of test members in other meetings %d, test members tagged elsewhere %d. Nothing was deleted.', 16, 1,
              @OtherMeetings, @OtherAgendas, @OtherChair, @OtherAttendance, @OtherTags);
    RETURN;
END

DECLARE @nMap INT, @nAction INT, @nAttendance INT, @nAlertMap INT, @nAlert INT, @nAudit INT, @nMinutes INT, @nAgenda INT,
        @nMeetingMember INT, @nMeeting INT, @nCommitteeMember INT, @nMember INT, @nCommittee INT;

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM ActionItem_User_Map WHERE ActionItemId IN (SELECT ActionItemId FROM @ActionItems);
    SET @nMap = @@ROWCOUNT;

    DELETE FROM Action_Item WHERE ActionItemId IN (SELECT ActionItemId FROM @ActionItems);
    SET @nAction = @@ROWCOUNT;

    DELETE FROM Attendance WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @nAttendance = @@ROWCOUNT;

    DELETE FROM Alert_User_Map WHERE AlertId IN (SELECT AlertId FROM @Alerts);
    SET @nAlertMap = @@ROWCOUNT;

    DELETE FROM Alert_Master WHERE AlertId IN (SELECT AlertId FROM @Alerts);
    SET @nAlert = @@ROWCOUNT;

    DELETE t FROM Audit_Trail_Master t
    JOIN @AuditKeys k ON k.Audit_Table = t.Audit_Table AND k.Key_Value = t.Key_Value;
    SET @nAudit = @@ROWCOUNT;

    DELETE FROM Minutes WHERE MinutesId IN (SELECT MinutesId FROM @Minutes);
    SET @nMinutes = @@ROWCOUNT;

    DELETE FROM Agenda WHERE AgendaId IN (SELECT AgendaId FROM @Agendas);
    SET @nAgenda = @@ROWCOUNT;

    DELETE FROM Meeting_Member WHERE MeetingMemberId IN (SELECT MeetingMemberId FROM @MeetingMembers);
    SET @nMeetingMember = @@ROWCOUNT;

    DELETE FROM Meeting WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @nMeeting = @@ROWCOUNT;

    DELETE FROM Committee_Member WHERE CommitteeMemberId IN (SELECT CommitteeMemberId FROM @CommitteeMembers);
    SET @nCommitteeMember = @@ROWCOUNT;

    DELETE FROM Member WHERE MemberId IN (SELECT MemberId FROM @Members);
    SET @nMember = @@ROWCOUNT;

    DELETE FROM Committee WHERE CommitteeId = @CommitteeId;
    SET @nCommittee = @@ROWCOUNT;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    DECLARE @ErrorText NVARCHAR(2048) = ERROR_MESSAGE();
    RAISERROR('Part 3 failed and was rolled back, nothing was deleted: %s', 16, 1, @ErrorText);
    RETURN;
END CATCH

DECLARE @Line NVARCHAR(400);
SET @Line = N'Deleted: ActionItem_User_Map ' + CAST(@nMap AS NVARCHAR(12)) + N', Action_Item ' + CAST(@nAction AS NVARCHAR(12))
          + N', Attendance ' + CAST(@nAttendance AS NVARCHAR(12)) + N', Alert_User_Map ' + CAST(@nAlertMap AS NVARCHAR(12))
          + N', Alert_Master ' + CAST(@nAlert AS NVARCHAR(12)) + N', Audit_Trail_Master ' + CAST(@nAudit AS NVARCHAR(12)) + N',';
PRINT @Line;
SET @Line = N'         Minutes ' + CAST(@nMinutes AS NVARCHAR(12)) + N', Agenda ' + CAST(@nAgenda AS NVARCHAR(12))
          + N', Meeting_Member ' + CAST(@nMeetingMember AS NVARCHAR(12)) + N', Meeting ' + CAST(@nMeeting AS NVARCHAR(12))
          + N', Committee_Member ' + CAST(@nCommitteeMember AS NVARCHAR(12)) + N', Member ' + CAST(@nMember AS NVARCHAR(12))
          + N', Committee ' + CAST(@nCommittee AS NVARCHAR(12)) + N'.';
PRINT @Line;

-- Nothing of the test may be left
DECLARE @Left INT =
      (SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId IN (SELECT ActionItemId FROM @ActionItems))
    + (SELECT COUNT(*) FROM Action_Item WHERE ActionItemId IN (SELECT ActionItemId FROM @ActionItems) OR MinutesId IN (SELECT MinutesId FROM @Minutes))
    + (SELECT COUNT(*) FROM Attendance WHERE MeetingId IN (SELECT MeetingId FROM @Meetings) OR MemberId IN (SELECT MemberId FROM @Members))
    + (SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId IN (SELECT AlertId FROM @Alerts))
    + (SELECT COUNT(*) FROM Alert_Master WHERE AlertId IN (SELECT AlertId FROM @Alerts)
                                            OR (SourceType = 'Committee' AND SourceTypeId = @CommitteeId)
                                            OR (SourceType = 'Meeting' AND SourceTypeId IN (SELECT MeetingId FROM @Meetings))
                                            OR (SourceType = 'Agenda' AND SourceTypeId IN (SELECT AgendaId FROM @Agendas)))
    + (SELECT COUNT(*) FROM Audit_Trail_Master t JOIN @AuditKeys k ON k.Audit_Table = t.Audit_Table AND k.Key_Value = t.Key_Value)
    + (SELECT COUNT(*) FROM Minutes WHERE MinutesId IN (SELECT MinutesId FROM @Minutes) OR AgendaId IN (SELECT AgendaId FROM @Agendas))
    + (SELECT COUNT(*) FROM Agenda WHERE AgendaId IN (SELECT AgendaId FROM @Agendas) OR CommitteeId = @CommitteeId)
    + (SELECT COUNT(*) FROM Meeting_Member WHERE MeetingMemberId IN (SELECT MeetingMemberId FROM @MeetingMembers))
    + (SELECT COUNT(*) FROM Meeting WHERE MeetingId IN (SELECT MeetingId FROM @Meetings) OR CommitteeId = @CommitteeId)
    + (SELECT COUNT(*) FROM Committee_Member WHERE CommitteeMemberId IN (SELECT CommitteeMemberId FROM @CommitteeMembers))
    + (SELECT COUNT(*) FROM Member WHERE MemberId IN (SELECT MemberId FROM @Members) OR MemberCode IN ('A921', 'A922', 'A923'))
    + (SELECT COUNT(*) FROM Committee WHERE CommitteeId = @CommitteeId OR CommitteeCode = 'A92');
SET @Line = N'Rows of the test left anywhere: ' + CAST(@Left AS NVARCHAR(12)) + N' (expected 0).';
PRINT @Line;
PRINT N'Expected after part 1 and part 3 with no browser changes: ActionItem_User_Map = the active users, Action_Item 1, Attendance 6, Alert_Master 8 (1 committee, 2 meetings, 5 items), Audit_Trail_Master 35 (7 per item), Minutes 5, Agenda 5, Meeting_Member 2, Meeting 2, Committee_Member 2, Member 3, Committee 1.';
GO
