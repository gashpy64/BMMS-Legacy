/* ============================================================================
   BMMS - Tests for BMMS-Fix-MeetingLocks.sql (step 15)
   ----------------------------------------------------------------------------
   Run AFTER BMMS-Fix-MeetingLocks.sql, on the TEST COPY. It stops if step 15
   is not installed.

   Creates its own meetings (past, in each state: Open, minutes finalized
   'F', minutes confirmed 'C', NULL statuses, one in the future) on an
   existing committee and checks, through the real procedures:
     * meeting member add / edit / delete in each state; delete refused when
       the member has attendance (Reason 2); unknown meeting / row (Reason 4)
     * attendance save refused once the minutes are finalized (and still
       refused for a future meeting, step 12)
     * chairman refused once the minutes are finalized; unknown member or
       wrong committee (Reason 4)
     * agenda finalize only from 'Open', minutes finalize only from 'Open',
       minutes confirm only from 'F'; a second call is refused (Reason 3,
       ReasonDetail = the status) and changes nothing
     * NULL AgendaStatus / MinutesStatus are treated as 'Open'
     * spr_GetMeetingStatusByMeetingId

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for that check does not exist.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeetingMember')), '') NOT LIKE '%MeetingLocks-Step15%')
BEGIN
    RAISERROR('Meeting locks (step 15) are not installed in "%s". Run BMMS-Fix-MeetingLocks.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(120), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @R1 TABLE (Result INT);
DECLARE @S TABLE (AgendaStatus VARCHAR(50), MinutesStatus VARCHAR(50), IsHeld INT, IsMinutesFinalized INT);

DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -7, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @CommitteeId INT = (SELECT TOP 1 CommitteeId FROM Committee ORDER BY CommitteeId);
DECLARE @OtherCommitteeId INT = (SELECT TOP 1 CommitteeId FROM Committee WHERE CommitteeId <> (SELECT TOP 1 CommitteeId FROM Committee ORDER BY CommitteeId) ORDER BY CommitteeId);
DECLARE @Member1 INT = (SELECT TOP 1 MemberId FROM Member ORDER BY MemberId);
DECLARE @Member2 INT = (SELECT TOP 1 MemberId FROM Member WHERE MemberId <> (SELECT TOP 1 MemberId FROM Member ORDER BY MemberId) ORDER BY MemberId);
-- A meeting type (2, 3 or 6) first: since step 21 a meeting member needs one
DECLARE @MemberTypeId INT = (SELECT TOP 1 MemberTypeId FROM Member_Type ORDER BY CASE WHEN MemberTypeId IN (2, 3, 6) THEN 0 ELSE 1 END, MemberTypeId);
DECLARE @UserId INT = (SELECT TOP 1 UserId FROM Users ORDER BY UserId);
DECLARE @HasFollowup INT = CASE WHEN EXISTS (SELECT 1 FROM Decision_Type WHERE DecisionTypeId = 1) THEN 1 ELSE 0 END;

DECLARE @MOpen INT, @MF INT, @MC INT, @MNull INT, @MFuture INT, @MFlow INT;
DECLARE @MM INT, @MMF INT, @MMC INT, @MMAtt INT;
DECLARE @Missing INT;
DECLARE @Rows INT, @Rows2 INT;
DECLARE @MinutesId INT;
DECLARE @Text VARCHAR(400);

IF (@CommitteeId IS NULL OR @Member1 IS NULL OR @Member2 IS NULL OR @MemberTypeId IS NULL OR @UserId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('A committee, two members, a member type or a user is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

BEGIN TRANSACTION;

BEGIN TRY

    -- Step 16: new attendance and a new chairman only for a member on the committee on the
    -- meeting date. Make @Member1 a member of @CommitteeId since 2000 (rolled back).
    IF EXISTS (SELECT 1 FROM Committee_Member WHERE CommitteeId = @CommitteeId AND MemberId = @Member1)
        UPDATE Committee_Member SET AppointmentDate = '2000-01-01', CessationDate = ''
        WHERE CommitteeId = @CommitteeId AND MemberId = @Member1;
    ELSE
        INSERT INTO Committee_Member (CommitteeId, MemberId, MemberTypeId, AppointmentDate, CessationDate, IsFeeApplicable, ApplicableFee, CreatedOn, CreatedBy)
        VALUES (@CommitteeId, @Member1, @MemberTypeId, '2000-01-01', '', 0, 0, @Now, @UserId);

    ---------------------------------------------------------------------------
    -- Test meetings (inserted directly), all held a week ago except @MFuture
    ---------------------------------------------------------------------------
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('ZZLOCK1', @CommitteeId, 'ZZ lock test', 'ZZ', @Past, '10:00', 'Close', 'Open');
    SET @MOpen = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('ZZLOCK2', @CommitteeId, 'ZZ lock test', 'ZZ', @Past, '10:00', 'Close', 'F');
    SET @MF = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('ZZLOCK3', @CommitteeId, 'ZZ lock test', 'ZZ', @Past, '10:00', 'Close', 'C');
    SET @MC = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('ZZLOCK4', @CommitteeId, 'ZZ lock test', 'ZZ', @Past, '10:00', NULL, NULL);
    SET @MNull = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('ZZLOCK5', @CommitteeId, 'ZZ lock test', 'ZZ', DATEADD(DAY, 7, @Now), '10:00', 'Open', 'Open');
    SET @MFuture = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('ZZLOCK6', @CommitteeId, 'ZZ lock test', 'ZZ', @Past, '10:00', 'Open', 'Open');
    SET @MFlow = SCOPE_IDENTITY();

    SET @Missing = (SELECT ISNULL(MAX(MeetingId), 0) + 1000 FROM Meeting);

    -- Existing member rows on the F and C meetings
    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy)
    VALUES (@MF, @Member1, @MemberTypeId, 1, @Now, @UserId);
    SET @MMF = SCOPE_IDENTITY();
    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy)
    VALUES (@MC, @Member1, @MemberTypeId, 1, @Now, @UserId);
    SET @MMC = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- Meeting member: add
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MOpen, @MemberId = @Member1,
         @MemberTypeId = @MemberTypeId, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    SET @MM = (SELECT MAX(MeetingMemberId) FROM Meeting_Member WHERE MeetingId = @MOpen AND MemberId = @Member1);
    INSERT INTO @T SELECT 'Member add, minutes Open', 'Result 1, Reason 0, row 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', row ' + CAST((SELECT COUNT(*) FROM Meeting_Member WHERE MeetingId = @MOpen) AS VARCHAR(12)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MF, @MemberId = @Member2,
         @MemberTypeId = @MemberTypeId, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Member add, minutes finalized (F)', 'Result 0, Reason 1, rows 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', rows ' + CAST((SELECT COUNT(*) FROM Meeting_Member WHERE MeetingId = @MF) AS VARCHAR(12)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MC, @MemberId = @Member2,
         @MemberTypeId = @MemberTypeId, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Member add, minutes confirmed (C)', 'Result 0, Reason 1, rows 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', rows ' + CAST((SELECT COUNT(*) FROM Meeting_Member WHERE MeetingId = @MC) AS VARCHAR(12)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @Missing, @MemberId = @Member2,
         @MemberTypeId = @MemberTypeId, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Member add, unknown meeting', 'Result 0, Reason 4',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MNull, @MemberId = @Member2,
         @MemberTypeId = @MemberTypeId, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Member add, MinutesStatus NULL (treated as Open)', 'Result 1, Reason 0',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    ---------------------------------------------------------------------------
    -- Meeting member: edit
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Update', @MeetingMemberId = @MM, @MeetingId = @MOpen, @MemberId = @Member1,
         @MemberTypeId = @MemberTypeId, @StatusId = 0, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Member edit, minutes Open', 'Result 1, Reason 0, status 0',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', status ' + ISNULL((SELECT CAST(StatusId AS VARCHAR(2)) FROM Meeting_Member WHERE MeetingMemberId = @MM), 'NULL') FROM @R;

    -- The meeting comes from the existing row, not from @MeetingId
    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Update', @MeetingMemberId = @MMF, @MeetingId = @MOpen, @MemberId = @Member1,
         @MemberTypeId = @MemberTypeId, @StatusId = 0, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Member edit, row of a finalized meeting (Open meeting id passed)', 'Result 0, Reason 1, status 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', status ' + ISNULL((SELECT CAST(StatusId AS VARCHAR(2)) FROM Meeting_Member WHERE MeetingMemberId = @MMF), 'NULL') FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Update', @MeetingMemberId = @MMC, @MeetingId = @MC, @MemberId = @Member1,
         @MemberTypeId = @MemberTypeId, @StatusId = 0, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Member edit, minutes confirmed (C)', 'Result 0, Reason 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AddEditMeetingMember @Code = 'Update', @MeetingMemberId = -1, @MeetingId = @MOpen, @MemberId = @Member1,
         @MemberTypeId = @MemberTypeId, @StatusId = 0, @CreatedOn = @Now, @CreatedBy = @UserId, @UpdatedOn = @Now, @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Member edit, unknown row', 'Result 0, Reason 4',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    ---------------------------------------------------------------------------
    -- Meeting member: delete
    ---------------------------------------------------------------------------
    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy)
    VALUES (@MOpen, @Member2, @MemberTypeId, 1, @Now, @UserId);
    SET @MMAtt = SCOPE_IDENTITY();
    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@CommitteeId, @MOpen, 'M', @Member2, 'P', 0, @Now, @UserId);

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteMeetingMemberByMeetingMemberId @MeetingMemberId = @MMAtt;
    INSERT INTO @T SELECT 'Member delete, attendance recorded', 'Result 0, Reason 2, row kept',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + CASE WHEN EXISTS (SELECT 1 FROM Meeting_Member WHERE MeetingMemberId = @MMAtt) THEN ', row kept' ELSE ', row DELETED' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteMeetingMemberByMeetingMemberId @MeetingMemberId = @MM;
    INSERT INTO @T SELECT 'Member delete, minutes Open, no attendance', 'Result 1, Reason 0, row gone',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + CASE WHEN EXISTS (SELECT 1 FROM Meeting_Member WHERE MeetingMemberId = @MM) THEN ', row kept' ELSE ', row gone' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteMeetingMemberByMeetingMemberId @MeetingMemberId = @MMF;
    INSERT INTO @T SELECT 'Member delete, minutes finalized (F)', 'Result 0, Reason 1, row kept',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + CASE WHEN EXISTS (SELECT 1 FROM Meeting_Member WHERE MeetingMemberId = @MMF) THEN ', row kept' ELSE ', row DELETED' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteMeetingMemberByMeetingMemberId @MeetingMemberId = @MMC;
    INSERT INTO @T SELECT 'Member delete, minutes confirmed (C)', 'Result 0, Reason 1, row kept',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + CASE WHEN EXISTS (SELECT 1 FROM Meeting_Member WHERE MeetingMemberId = @MMC) THEN ', row kept' ELSE ', row DELETED' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_DeleteMeetingMemberByMeetingMemberId @MeetingMemberId = -1;
    INSERT INTO @T SELECT 'Member delete, unknown row', 'Result 0, Reason 4',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    ---------------------------------------------------------------------------
    -- Attendance (returns only Result)
    ---------------------------------------------------------------------------
    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @MOpen, @MemberOf = 'C',
         @MemberId = @Member1, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Attendance, minutes Open', 'Result 1, rows 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', rows '
           + CAST((SELECT COUNT(*) FROM Attendance WHERE MeetingId = @MOpen AND MemberId = @Member1) AS VARCHAR(12)) FROM @R1;

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @MF, @MemberOf = 'C',
         @MemberId = @Member1, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Attendance, minutes finalized (F)', 'Result 0, rows 0',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', rows '
           + CAST((SELECT COUNT(*) FROM Attendance WHERE MeetingId = @MF) AS VARCHAR(12)) FROM @R1;

    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@CommitteeId, @MC, 'C', @Member1, 'P', 0, @Now, @UserId);
    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @MC, @MemberOf = 'C',
         @MemberId = @Member1, @Attendance = 'A', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Attendance change, minutes confirmed (C)', 'Result 0, still P',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', still '
           + ISNULL((SELECT TOP 1 Attendance FROM Attendance WHERE MeetingId = @MC AND MemberId = @Member1), 'none') FROM @R1;

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @MFuture, @MemberOf = 'C',
         @MemberId = @Member1, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Attendance, future meeting (step 12 kept)', 'Result 0', 'Result ' + CAST(Result AS VARCHAR(2)) FROM @R1;

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @CommitteeId, @MeetingId = @Missing, @MemberOf = 'C',
         @MemberId = @Member1, @Attendance = 'P', @UpdatedBy = @UserId;
    INSERT INTO @T SELECT 'Attendance, unknown meeting', 'Result 0', 'Result ' + CAST(Result AS VARCHAR(2)) FROM @R1;

    ---------------------------------------------------------------------------
    -- Chairman
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateMeetingChairman @MeetingId = @MOpen, @CommitteeId = @CommitteeId, @ChairmanNameId = @Member1;
    INSERT INTO @T SELECT 'Chairman, minutes Open', 'Result 1, Reason 0, set',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + CASE WHEN (SELECT ChairmanNameId FROM Meeting WHERE MeetingId = @MOpen) = @Member1 THEN ', set' ELSE ', not set' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateMeetingChairman @MeetingId = @MF, @CommitteeId = @CommitteeId, @ChairmanNameId = @Member1;
    INSERT INTO @T SELECT 'Chairman, minutes finalized (F)', 'Result 0, Reason 1, unchanged',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + CASE WHEN (SELECT ChairmanNameId FROM Meeting WHERE MeetingId = @MF) IS NULL THEN ', unchanged' ELSE ', CHANGED' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateMeetingChairman @MeetingId = @MC, @CommitteeId = @CommitteeId, @ChairmanNameId = @Member1;
    INSERT INTO @T SELECT 'Chairman, minutes confirmed (C)', 'Result 0, Reason 1, unchanged',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + CASE WHEN (SELECT ChairmanNameId FROM Meeting WHERE MeetingId = @MC) IS NULL THEN ', unchanged' ELSE ', CHANGED' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateMeetingChairman @MeetingId = @MOpen, @CommitteeId = @CommitteeId, @ChairmanNameId = -1;
    INSERT INTO @T SELECT 'Chairman, unknown member', 'Result 0, Reason 4, unchanged',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + CASE WHEN (SELECT ChairmanNameId FROM Meeting WHERE MeetingId = @MOpen) = @Member1 THEN ', unchanged' ELSE ', CHANGED' END FROM @R;

    IF (@OtherCommitteeId IS NULL)
        INSERT INTO @T VALUES ('Chairman, meeting of another committee', '', 'SKIPPED');
    ELSE
    BEGIN
        DELETE FROM @R; INSERT INTO @R EXEC spr_UpdateMeetingChairman @MeetingId = @MOpen, @CommitteeId = @OtherCommitteeId, @ChairmanNameId = @Member2;
        INSERT INTO @T SELECT 'Chairman, meeting of another committee', 'Result 0, Reason 4',
               'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;
    END

    ---------------------------------------------------------------------------
    -- Agenda finalize, minutes finalize, minutes confirm (@MFlow, in order)
    ---------------------------------------------------------------------------
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, ShortText, ProposedResolution, ControllerApprovedStatus, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('ZZLOCK-A1', @CommitteeId, @MFlow, 'ZZ lock test agenda', 'ZZ resolution', 'Approved', 'AC', @Now, @UserId);

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MFlow, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes confirm from Open', 'Result 0, Reason 3, Open, still Open',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) + ', ' + ReasonDetail
           + ', still ' + (SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MFlow) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @MFlow;
    SET @MinutesId = (SELECT TOP 1 m.MinutesId FROM Minutes m JOIN Agenda a ON a.AgendaId = m.AgendaId WHERE a.MeetingId = @MFlow);
    INSERT INTO @T SELECT 'Agenda finalize from Open', 'Result 1, Reason 0, Close, minutes 1',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', ' + (SELECT AgendaStatus FROM Meeting WHERE MeetingId = @MFlow)
           + ', minutes ' + CAST((SELECT COUNT(*) FROM Minutes m JOIN Agenda a ON a.AgendaId = m.AgendaId WHERE a.MeetingId = @MFlow) AS VARCHAR(12)) FROM @R;

    -- Minutes edited after the agenda finalize: a second finalize must not wipe them
    UPDATE Minutes SET StatusId = 1, Directions = 'ZZ edited', DecisionTypeId = CASE WHEN @HasFollowup = 1 THEN 1 ELSE DecisionTypeId END
    WHERE MinutesId = @MinutesId;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @MFlow;
    INSERT INTO @T SELECT 'Agenda finalize again (second tab)', 'Result 0, Reason 3, Close, edited minutes kept',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) + ', ' + ReasonDetail
           + CASE WHEN EXISTS (SELECT 1 FROM Minutes WHERE MinutesId = @MinutesId AND CAST(Directions AS VARCHAR(50)) = 'ZZ edited')
                  THEN ', edited minutes kept' ELSE ', MINUTES RE-CREATED' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @Missing;
    INSERT INTO @T SELECT 'Agenda finalize, unknown meeting', 'Result 0, Reason 4',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @MNull;
    INSERT INTO @T SELECT 'Agenda finalize, AgendaStatus NULL (treated as Open)', 'Result 1, Reason 0',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MFlow, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes finalize from Open', 'Result 1, Reason 0, F',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', ' + (SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MFlow) FROM @R;

    SET @Rows = (SELECT COUNT(*) FROM Action_Item WHERE MinutesId = @MinutesId);
    SET @Rows2 = (SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId IN (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @MinutesId));

    IF (@HasFollowup = 1)
        INSERT INTO @T SELECT 'Minutes finalize: one action item for the follow-up minute', '1', CAST(@Rows AS VARCHAR(12));
    ELSE
        INSERT INTO @T VALUES ('Minutes finalize: one action item for the follow-up minute', '', 'SKIPPED');

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MFlow, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes finalize again (second tab)', 'Result 0, Reason 3, F, nothing added',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) + ', ' + ReasonDetail
           + CASE WHEN (SELECT COUNT(*) FROM Action_Item WHERE MinutesId = @MinutesId) = @Rows
                   AND (SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId IN (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @MinutesId)) = @Rows2
                  THEN ', nothing added' ELSE ', ROWS ADDED' END FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MC, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes finalize from C', 'Result 0, Reason 3, C',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) + ', ' + ReasonDetail FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @Missing, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes finalize, unknown meeting', 'Result 0, Reason 4',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MNull, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes finalize, MinutesStatus NULL (treated as Open)', 'Result 1, Reason 0',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MFlow, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes confirm from F', 'Result 1, Reason 0, C',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2))
           + ', ' + (SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MFlow) FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MFlow, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes confirm again (second tab)', 'Result 0, Reason 3, C',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) + ', ' + ReasonDetail FROM @R;

    DELETE FROM @R; INSERT INTO @R EXEC spr_MinutesConfirmByMeetingId @MeetingId = @Missing, @UserId = @UserId;
    INSERT INTO @T SELECT 'Minutes confirm, unknown meeting', 'Result 0, Reason 4',
           'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(2)) FROM @R;

    ---------------------------------------------------------------------------
    -- spr_GetMeetingStatusByMeetingId
    ---------------------------------------------------------------------------
    DELETE FROM @S; INSERT INTO @S EXEC spr_GetMeetingStatusByMeetingId @MeetingId = @MOpen;
    INSERT INTO @T SELECT 'Status lookup, held Open meeting', 'Close Open 1 0',
           AgendaStatus + ' ' + MinutesStatus + ' ' + CAST(IsHeld AS VARCHAR(1)) + ' ' + CAST(IsMinutesFinalized AS VARCHAR(1)) FROM @S;
    DELETE FROM @S; INSERT INTO @S EXEC spr_GetMeetingStatusByMeetingId @MeetingId = @MF;
    INSERT INTO @T SELECT 'Status lookup, finalized meeting', 'Close F 1 1',
           AgendaStatus + ' ' + MinutesStatus + ' ' + CAST(IsHeld AS VARCHAR(1)) + ' ' + CAST(IsMinutesFinalized AS VARCHAR(1)) FROM @S;
    DELETE FROM @S; INSERT INTO @S EXEC spr_GetMeetingStatusByMeetingId @MeetingId = @MFuture;
    INSERT INTO @T SELECT 'Status lookup, future meeting', 'Open Open 0 0',
           AgendaStatus + ' ' + MinutesStatus + ' ' + CAST(IsHeld AS VARCHAR(1)) + ' ' + CAST(IsMinutesFinalized AS VARCHAR(1)) FROM @S;
    UPDATE Meeting SET AgendaStatus = NULL, MinutesStatus = NULL WHERE MeetingId = @MNull;
    DELETE FROM @S; INSERT INTO @S EXEC spr_GetMeetingStatusByMeetingId @MeetingId = @MNull;
    INSERT INTO @T SELECT 'Status lookup, NULL statuses read as Open', 'Open Open 1 0',
           AgendaStatus + ' ' + MinutesStatus + ' ' + CAST(IsHeld AS VARCHAR(1)) + ' ' + CAST(IsMinutesFinalized AS VARCHAR(1)) FROM @S;
    DELETE FROM @S; INSERT INTO @S EXEC spr_GetMeetingStatusByMeetingId @MeetingId = @Missing;
    INSERT INTO @T SELECT 'Status lookup, unknown meeting', '0 rows', CAST(COUNT(*) AS VARCHAR(12)) + ' rows' FROM @S;

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
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

-- Confirm nothing was kept: should be 0.
SELECT COUNT(*) AS TestMeetingsLeft FROM Meeting WHERE MeetingNo LIKE 'ZZLOCK%';
GO

SET NOEXEC OFF;
GO
