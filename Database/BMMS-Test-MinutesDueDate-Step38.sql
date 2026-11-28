/* ============================================================================
   BMMS - Tests for BMMS-Fix-MinutesDueDate-Step38.sql (step 38, step UN6a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-MinutesDueDate-Step38.sql, on the TEST COPY. It stops if
   step 38 is not installed.

   Creates its own committee, two meetings (one with a date, one without; both
   count as older than step 23, so the workflow order does not apply), one
   agenda item per meeting and its minute, and checks through spr_UpdateMinutes,
   with made-up sample values only:
     * the marker, the texts of steps 6, 16, 17, 18, 23 and 31 kept, @DueDate
       the one new parameter (last, datetime, default NULL)
     * Code 'All', Followup: the date is stored without its time; the same date
       again writes no audit row; another date and NULL are stored and audited
     * another decision stores NULL even when a date is passed
     * the meeting date itself is accepted; the day before is refused
       (Reason 22, ReasonDetail the meeting date) and nothing is saved
     * a meeting without a date accepts any date
     * Codes 'Directions' and 'ActualResolution' leave the date as it is
     * a call without @DueDate keeps the stored date of a Followup (step UN6a1),
       and a caller without it that changes the decision stores NULL
     * finalized minutes (F) can still be updated; confirmed minutes (C) are
       refused (Reason 7) and the date is unchanged
     * the audit row: Minutes, AgendaNo, DueDate, old and new as dd-Mon-yyyy
     * rows outside the test are not changed
   Each Actual shows the result row and the stored due date (yyyy-mm-dd hh:mi,
   or NULL), and where checked the audit rows of the test item.

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for the checks does not exist.

   It has no USE line: select the database in SSMS first (the test copy). It
   stops if the current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') NOT LIKE '%MinutesDueDate-Step38%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') NOT LIKE '%DueDateKeep-Step38%')
BEGIN
    RAISERROR('Step 38 (due date on Update Minutes) is not installed in "%s", or it is the first step 38 text (no marker DueDateKeep-Step38). Run BMMS-Fix-MinutesDueDate-Step38.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))));

DECLARE @Now DATETIME = GETDATE();
DECLARE @MDate DATETIME = DATEADD(DAY, 10, CAST(CAST(GETDATE() AS date) AS DATETIME));   -- the meeting date
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @Actor INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 0 AND AccountStatus = 1 ORDER BY UserId);
DECLARE @Dept INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @Followup INT = (SELECT DecisionTypeId FROM Decision_Type WHERE DecisionTypeId = 1);
DECLARE @Other INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);
DECLARE @C INT, @Mt INT, @Mt2 INT, @Ag INT, @Ag2 INT, @Mi INT, @Mi2 INT, @No VARCHAR(50), @No2 VARCHAR(50);
DECLARE @Dd VARCHAR(40), @Aud INT, @AudLast VARCHAR(400), @E NVARCHAR(10) = N'';
DECLARE @DueArg DATETIME;
DECLARE @MinBefore VARCHAR(40), @MinAfter VARCHAR(40), @AudBefore VARCHAR(40), @AudAfter VARCHAR(40);

IF (@Sys IS NULL OR @Actor IS NULL OR @Dept IS NULL OR @SubjectTypeId IS NULL OR @Followup IS NULL OR @Other IS NULL)
BEGIN
    INSERT INTO @T VALUES ('A user, department, subject type or decision type (Followup = 1 and one other) is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

---------------------------------------------------------------------------
-- 1. Installation
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'Markers MinutesDueDate-Step38 and DueDateKeep-Step38 on spr_UpdateMinutes', 'yes yes',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') LIKE '%MinutesDueDate-Step38%' THEN 'yes' ELSE 'no' END + ' '
     + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')), '') LIKE '%DueDateKeep-Step38%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_UpdateMinutes keeps the texts of steps 6 (FK #5), 16, 17, 18, 23 and 31', 'yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%FK #5%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%MeetingLocks-Step16%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%UserStatus2b-Step17%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%SystemAccount3-Step18%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%WorkflowOrder-Step23%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%UnicodeText-Step31%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'Parameter names in order (step 31 list plus @DueDate); @DueDate datetime, default 99991231 (not passed)',
       '@Code,@MinutesId,@DecisionTypeId,@Directions,@ActualResolution,@ShortText,@CreatedBy,@UpdatedBy,@DueDate; datetime default',
       ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateMinutes') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none') + '; '
     + ISNULL((SELECT TYPE_NAME(user_type_id) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateMinutes') AND name = '@DueDate'), 'none')
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%@DueDate DATETIME = ''99991231''%' THEN ' default' ELSE ' no default' END;

-- Rows outside the test, before the test
SELECT @MinBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, DecisionTypeId, DueDate, StatusId, UpdatedOn)), 0) AS VARCHAR(12)) FROM Minutes;
SELECT @AudBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(MAX(Audit_Trail_Maser_Id), 0) AS VARCHAR(12)) FROM Audit_Trail_Master;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- 2. Fixtures (made-up names). The meetings have no CreatedOn: they count as older than step 23
    ---------------------------------------------------------------------------
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z38', 'ZZ step 38 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99938', @C, 'ZZ38 test', 'ZZ', @MDate, '10:00', @MDate, 'Close', 'Open');
    SET @Mt = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99939', @C, 'ZZ38 test', 'ZZ', NULL, '10:00', NULL, 'Close', 'Open');
    SET @Mt2 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        CurrentStatus, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('ZZ38-001', @C, @Mt, @Dept, @SubjectTypeId, N'ZZ38 short', 'Entry', N'ZZ38 text', N'ZZ38 resolution', 'New', 'ACA', @Now, @Actor);
    SET @Ag = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        CurrentStatus, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('ZZ38-002', @C, @Mt2, @Dept, @SubjectTypeId, N'ZZ38 short 2', 'Entry', N'ZZ38 text', N'ZZ38 resolution', 'New', 'ACA', @Now, @Actor);
    SET @Ag2 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, DueDate, Directions, ActualResolution, StatusId, CreatedOn, CreatedBy)
    VALUES (@Ag, @Other, NULL, N'', N'ZZ38 resolution', 0, @Now, @Actor);
    SET @Mi = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, DueDate, Directions, ActualResolution, StatusId, CreatedOn, CreatedBy)
    VALUES (@Ag2, @Other, NULL, N'', N'ZZ38 resolution', 0, @Now, @Actor);
    SET @Mi2 = SCOPE_IDENTITY();
    SET @No = 'ZZ38-001';
    SET @No2 = 'ZZ38-002';

    ---------------------------------------------------------------------------
    -- 3. Code 'All', Followup
    ---------------------------------------------------------------------------
    SET @DueArg = DATEADD(MINUTE, 930, DATEADD(DAY, 5, @MDate));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'Followup with a date and a time (15:30): the date is stored at 00:00; one audit row',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 5, @MDate), 120) + ' 00:00' + '; audit rows 1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SET @DueArg = DATEADD(DAY, 5, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'The same date again: no new audit row',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 5, @MDate), 120) + ' 00:00' + '; audit rows 1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SET @DueArg = DATEADD(DAY, 7, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'Another date: stored; a second audit row',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 7, @MDate), 120) + ' 00:00' + '; audit rows 2',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SELECT TOP 1 @AudLast = Old_Value + ' > ' + New_Value + ' (' + Audit_Type + ', ' + Key_Field + ')' FROM Audit_Trail_Master
    WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001' ORDER BY Audit_Trail_Maser_Id DESC;
    INSERT INTO @T SELECT 'The audit row: old > new as dd-Mon-yyyy (UP, AgendaNo)',
           REPLACE(CONVERT(VARCHAR(11), DATEADD(DAY, 5, @MDate), 106), ' ', '-') + ' > ' + REPLACE(CONVERT(VARCHAR(11), DATEADD(DAY, 7, @MDate), 106), ' ', '-') + ' (UP, AgendaNo)',
           ISNULL(@AudLast, 'none');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = NULL;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'Followup with no date: NULL; a third audit row (old date to empty)',
           'Result 1, Reason 0; due ' + 'NULL' + '; audit rows 3',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SET @DueArg = @MDate;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'The meeting date itself is accepted',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 0, @MDate), 120) + ' 00:00' + '; audit rows 4',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SET @DueArg = DATEADD(DAY, -1, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'The day before the meeting date: refused (Reason 22, the meeting date); date and decision unchanged; no audit row',
           'Result 0, Reason 22 ' + REPLACE(CONVERT(VARCHAR(11), @MDate, 106), ' ', '-') + '; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 0, @MDate), 120) + ' 00:00' + '; decision 1; audit rows 4',
           ISNULL((SELECT TOP 1 Txt + ' ' + CAST(ReasonDetail AS VARCHAR(40)) FROM @R), 'none') + '; due ' + @Dd
           + '; decision ' + CAST((SELECT DecisionTypeId FROM Minutes WHERE MinutesId = @Mi) AS VARCHAR(12)) + '; audit rows ' + CAST(@Aud AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 4. Directions and Actual Resolution leave the date; another decision clears it
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = NULL;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'Code ''Directions'' (with @DueDate NULL): the date is unchanged',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 0, @MDate), 120) + ' 00:00' + '; audit rows 4',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SET @DueArg = DATEADD(DAY, 30, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'ActualResolution', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'Code ''ActualResolution'' (with another date): the date is unchanged',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 0, @MDate), 120) + ' 00:00' + '; audit rows 4',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SET @DueArg = DATEADD(DAY, 3, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Other,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'Another decision with a date: NULL is stored; one audit row',
           'Result 1, Reason 0; due ' + 'NULL' + '; audit rows 5',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SET @DueArg = DATEADD(DAY, 3, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Other,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'Another decision again (NULL to NULL): no audit row',
           'Result 1, Reason 0; due ' + 'NULL' + '; audit rows 5',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    SET @DueArg = DATEADD(DAY, 2, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'Followup with a date again: stored; one audit row',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 2, @MDate), 120) + ' 00:00' + '; audit rows 6',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'A caller without @DueDate (Code ''All'', Followup): the stored date is kept; no audit row',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 2, @MDate), 120) + ' 00:00' + '; audit rows 6',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Other,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-001';
    INSERT INTO @T SELECT 'An older caller without @DueDate that changes Followup to another decision: NULL; one audit row',
           'Result 1, Reason 0; due ' + 'NULL' + '; audit rows 7',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 5. A meeting without a date; finalized and confirmed minutes
    ---------------------------------------------------------------------------
    SET @DueArg = '2001-01-01';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi2, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi2), 'NULL');
    SELECT @Aud = COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Minutes' AND Field_Name = 'DueDate' AND Key_Value = 'ZZ38-002';
    INSERT INTO @T SELECT 'A meeting without a date: any date is accepted',
           'Result 1, Reason 0; due ' + '2001-01-01 00:00' + '; audit rows 1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd + '; audit rows ' + CAST(@Aud AS VARCHAR(12));
    UPDATE Meeting SET MinutesStatus = 'F' WHERE MeetingId = @Mt;
    SET @DueArg = DATEADD(DAY, 4, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    INSERT INTO @T SELECT 'Finalized minutes (F): the date can still be changed',
           'Result 1, Reason 0; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 4, @MDate), 120) + ' 00:00',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd;
    UPDATE Meeting SET MinutesStatus = 'C' WHERE MeetingId = @Mt;
    SET @DueArg = DATEADD(DAY, 9, @MDate);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Mi, @DecisionTypeId = @Followup,
         @Directions = N'ZZ38 directions', @ActualResolution = N'ZZ38 actual', @ShortText = N'ZZ38 short', @CreatedBy = @Actor, @UpdatedBy = @Actor, @DueDate = @DueArg;
    SET @Dd = ISNULL((SELECT CONVERT(VARCHAR(16), DueDate, 120) FROM Minutes WHERE MinutesId = @Mi), 'NULL');
    INSERT INTO @T SELECT 'Confirmed minutes (C): refused (Reason 7); the date unchanged',
           'Result 0, Reason 7; due ' + CONVERT(VARCHAR(10), DATEADD(DAY, 4, @MDate), 120) + ' 00:00',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; due ' + @Dd;

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @MinAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MinutesId, DecisionTypeId, DueDate, StatusId, UpdatedOn)), 0) AS VARCHAR(12)) FROM Minutes;
SELECT @AudAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(MAX(Audit_Trail_Maser_Id), 0) AS VARCHAR(12)) FROM Audit_Trail_Master;
INSERT INTO @T SELECT 'After the rollback: Minutes unchanged (count, checksum)', @MinBefore, @MinAfter;
INSERT INTO @T SELECT 'After the rollback: Audit_Trail_Master unchanged (count, last id)', @AudBefore, @AudAfter;

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

-- Confirm nothing was kept: should be 0, 0 and 0
SELECT (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z38' AND CommitteeName = 'ZZ step 38 committee') AS TestCommitteesLeft,
       (SELECT COUNT(*) FROM Meeting WHERE MeetingNo IN ('99938', '99939') AND Place = 'ZZ38 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Agenda WHERE AgendaNo IN ('ZZ38-001', 'ZZ38-002')) AS TestAgendaLeft;
GO

SET NOEXEC OFF;
GO
