/* ============================================================================
   BMMS - Browser test rows for step A1a (stored HTML cleaned on display)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY on the database BMMS_Test: every part stops with a message on any
   other database. It has no USE line: select BMMS_Test in SSMS first.

   The file has three parts. Select the lines of ONE part and press F5.
   Rows are written with plain INSERTs, as in the F1 and F3 test scripts; no
   procedure is created, altered or run. Existing committees and meetings are
   reused; no master row is created.

   PART 1  For the test user (@TestLogin, the only value to fill in):
             Agenda ZZA1-99901 in the newest meeting whose agenda is still
               open (or @OpenMeetingId), status AC, with
               Short Text  O'Brien & Sons <Test>
               AgendaText, ProposedResolution, MgrComments and
               ControllerComments holding a script tag, an image with
               onerror, Word-paste leftovers (mso class, o:p, font, span
               with style, div), a table with colspan, Tamil, Hindi and
               the rupee sign with 1,000,
             and one unread Agenda alert for the test user pointing to it,
               display text "ZZ A1 test - O'Brien & Sons <Test>".
             Agenda ZZA1-99902 in the newest meeting that has minutes
               (finalized minutes first, or @MinutesMeetingId), status ACA,
               the same Short Text and texts, and one Minutes row for it
               whose ActualResolution holds the same kinds of content.
               When no meeting has minutes, this agenda is not added and
               the part says so.
           Prints the new ids. The text is built with NCHAR(), so this file
           is plain ASCII and opens the same in any editor.
   PART 2  Read-only: shows the test agendas, their minutes and their alerts.
   PART 3  Cleanup, by the ids of the two test agendas only: the
           Alert_User_Map and Alert_Master rows of Agenda alerts pointing to
           them (the test alert and any alert the browser tests add), the
           Minutes row of ZZA1-99902, then the two agendas. Prints the counts.
           It refuses when anything else references them: a Minutes row of
           ZZA1-99901, a second Minutes row of ZZA1-99902, or an action item
           on its minute. Audit trail rows written by browser saves are
           history and are kept.
           If an agenda was deleted in the browser, set @TestAgendaA or
           @TestAgendaB to the id printed by part 1.
   ============================================================================ */


/* ============================================================================
   PART 1 - insert the test agendas, minute and alert
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @TestLogin NVARCHAR(100) = N'Controller';    -- the login name of the test user
DECLARE @OpenMeetingId INT = NULL;                   -- NULL: the newest meeting whose agenda is still open
DECLARE @MinutesMeetingId INT = NULL;                -- NULL: the newest meeting that has minutes (finalized first)

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @UserId INT, @UserDepartmentId INT;
SELECT @UserId = UserId, @UserDepartmentId = DepartmentId FROM Users WHERE LoginName = @TestLogin AND AccountStatus = 1 AND IsSystem = 0;
IF (@UserId IS NULL)
BEGIN
    RAISERROR('No active user with the login "%s". Set @TestLogin at the top of part 1 and run again. Nothing was changed.', 16, 1, @TestLogin);
    RETURN;
END

DECLARE @Existing INT;
SELECT @Existing = COUNT(*) FROM Agenda WHERE AgendaNo IN ('ZZA1-99901', 'ZZA1-99902');
IF (@Existing > 0)
BEGIN
    RAISERROR('%d test agenda(s) ZZA1-99901 / ZZA1-99902 from an earlier run are still there. Run part 3 first. Nothing was changed.', 16, 1, @Existing);
    RETURN;
END

-- Department and send option of the alert copied from the newest alert the test user has (as in the F1 test)
DECLARE @AlertDepartmentId INT, @AlertSendOption INT, @CopiedRows INT;
SELECT TOP 1 @AlertDepartmentId = am.DepartmentId, @AlertSendOption = am.AlertSendOption
FROM Alert_Master am
JOIN Alert_User_Map m ON m.AlertId = am.AlertId
WHERE m.UserId = @UserId AND m.StatusId = 1
ORDER BY am.AlertId DESC;
SET @CopiedRows = @@ROWCOUNT;
IF (@CopiedRows = 0)
BEGIN
    RAISERROR('The user "%s" has no alert to copy from. Choose a test user who sees at least one alert on the Dashboard. Nothing was changed.', 16, 1, @TestLogin);
    RETURN;
END

DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
-- A decision type other than 1 (Action), so no action item is ever made from the test minute
DECLARE @DecisionTypeId INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type ORDER BY CASE WHEN DecisionTypeId = 1 THEN 1 ELSE 0 END, DecisionTypeId);
IF (@SubjectTypeId IS NULL OR @DecisionTypeId IS NULL)
BEGIN
    RAISERROR('Subject_Type or Decision_Type has no row. Nothing was changed.', 16, 1);
    RETURN;
END

IF (@OpenMeetingId IS NULL)
    SELECT TOP 1 @OpenMeetingId = MeetingId FROM Meeting WHERE ISNULL(AgendaStatus, 'Open') = 'Open' ORDER BY MeetingId DESC;
DECLARE @OpenCommitteeId INT = (SELECT CommitteeId FROM Meeting WHERE MeetingId = @OpenMeetingId);
IF (@OpenCommitteeId IS NULL)
BEGIN
    RAISERROR('No meeting with an open agenda was found (or @OpenMeetingId does not exist). Create one in Meeting or set @OpenMeetingId. Nothing was changed.', 16, 1);
    RETURN;
END

IF (@MinutesMeetingId IS NULL)
    SELECT TOP 1 @MinutesMeetingId = mt.MeetingId
    FROM Meeting mt
    WHERE EXISTS (SELECT 1 FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.MeetingId = mt.MeetingId)
    ORDER BY CASE WHEN ISNULL(mt.MinutesStatus, 'Open') IN ('F', 'C') THEN 0 ELSE 1 END, mt.MeetingId DESC;
DECLARE @MinutesCommitteeId INT = (SELECT CommitteeId FROM Meeting WHERE MeetingId = @MinutesMeetingId);

-- The sample text: the rupee sign, a Tamil word (vanakkam) and a Hindi word (namaste), by code point
DECLARE @Rupee NVARCHAR(20) = NCHAR(8377) + N' 1,000';
DECLARE @Tamil NVARCHAR(20) = NCHAR(2997) + NCHAR(2979) + NCHAR(2965) + NCHAR(3021) + NCHAR(2965) + NCHAR(2990) + NCHAR(3021);
DECLARE @Hindi NVARCHAR(20) = NCHAR(2344) + NCHAR(2350) + NCHAR(2360) + NCHAR(2381) + NCHAR(2340) + NCHAR(2375);

DECLARE @Short NVARCHAR(200) = N'O''Brien & Sons <Test>';

-- What a stored row may contain: active content, Word-paste leftovers, a table, Unicode
DECLARE @Rich NVARCHAR(MAX) =
      N'<p class="MsoNormal" style="margin:0cm;text-align:center"><span style="font-family:Arial;mso-bidi-font-family:Mangal"><b>Centred bold heading</b><o:p></o:p></span></p>'
    + N'<p>Text before the script.</p><script>alert(''A1 script'')</script>'
    + N'<p><img src="x" onerror="alert(''A1 image'')">Text after the image.</p>'
    + N'<div style="text-align:justify"><font face="Arial" size="2">Word font text in a div</font> with <i>italic</i> and <u>underline</u>.</div>'
    + N'<p class="MsoNormal"><o:p>&nbsp;</o:p></p><p class="MsoNormal"><o:p>&nbsp;</o:p></p>'
    + N'<table class="MsoTableGrid" style="border-collapse:collapse;border:none"><tr><td colspan="2" style="text-align:center;border:solid windowtext 1pt"><b>Merged heading</b></td></tr>'
    + N'<tr><td>' + @Tamil + N'</td><td>' + @Hindi + N'</td></tr><tr><td>Amount</td><td>' + @Rupee + N'</td></tr></table>'
    + N'<p>Unicode in a paragraph: ' + @Tamil + N' ' + @Hindi + N' ' + @Rupee + N'</p>';

DECLARE @Now DATETIME = GETDATE();
DECLARE @AgendaA INT, @AgendaB INT, @MinutesB INT, @AlertA INT, @MapA INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType,
                        AgendaText, ProposedResolution, MgrComments, ControllerComments, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('ZZA1-99901', @OpenCommitteeId, @OpenMeetingId, @UserDepartmentId, @SubjectTypeId, @Short, 'Entry',
            N'<p><b>Agenda Text</b></p>' + @Rich, N'<p><b>Proposed Resolution</b></p>' + @Rich,
            N'<p>Manager Comments</p>' + @Rich, N'<p>Controller Comments</p>' + @Rich, 'AC', @Now, @UserId);
    SET @AgendaA = SCOPE_IDENTITY();

    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Agenda', @AlertDepartmentId, @AgendaA, 'ZZ A1 test - O''Brien & Sons <Test>', 'AC', @AlertSendOption, @OpenCommitteeId, @Now, @UserId);
    SET @AlertA = SCOPE_IDENTITY();
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId) VALUES (@AlertA, @UserId, 0, 1);
    SET @MapA = SCOPE_IDENTITY();

    IF (@MinutesCommitteeId IS NOT NULL)
    BEGIN
        INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType,
                            AgendaText, ProposedResolution, MgrComments, ControllerComments, AgendaStatusCode, CreatedOn, CreatedBy)
        VALUES ('ZZA1-99902', @MinutesCommitteeId, @MinutesMeetingId, @UserDepartmentId, @SubjectTypeId, @Short, 'Entry',
                N'<p><b>Agenda Text</b></p>' + @Rich, N'<p><b>Proposed Resolution</b></p>' + @Rich,
                N'', N'', 'ACA', @Now, @UserId);
        SET @AgendaB = SCOPE_IDENTITY();

        INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, StatusId, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
        VALUES (@AgendaB, @DecisionTypeId, N' ', N'<p><b>Actual Resolution</b></p>' + @Rich, 1, @Now, @UserId, @Now, @UserId);
        SET @MinutesB = SCOPE_IDENTITY();
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

DECLARE @Line NVARCHAR(400);
SET @Line = N'Test user ' + @TestLogin + N' (UserId ' + CAST(@UserId AS NVARCHAR(12)) + N')';
PRINT @Line;
SET @Line = N'ZZA1-99901: AgendaId ' + CAST(@AgendaA AS NVARCHAR(12)) + N', MeetingId ' + CAST(@OpenMeetingId AS NVARCHAR(12))
          + N' (agenda open), alert AlertId ' + CAST(@AlertA AS NVARCHAR(12)) + N', AlertUserId ' + CAST(@MapA AS NVARCHAR(12));
PRINT @Line;
IF (@AgendaB IS NULL)
    PRINT N'ZZA1-99902 not added: no meeting has minutes yet. The Minutes report and Update Minutes tests need one (set @MinutesMeetingId).';
ELSE
BEGIN
    DECLARE @MinutesStatus NVARCHAR(20) = (SELECT ISNULL(MinutesStatus, 'Open') FROM Meeting WHERE MeetingId = @MinutesMeetingId);
    SET @Line = N'ZZA1-99902: AgendaId ' + CAST(@AgendaB AS NVARCHAR(12)) + N', MeetingId ' + CAST(@MinutesMeetingId AS NVARCHAR(12))
              + N' (minutes status ' + @MinutesStatus + N'), MinutesId ' + CAST(@MinutesB AS NVARCHAR(12));
    PRINT @Line;
END
PRINT N'Keep these ids for part 3. Sign in as the test user and run the browser tests, then part 2.';
GO


/* ============================================================================
   PART 2 - read-only: the test agendas, their minutes and alerts
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

SELECT AgendaId, AgendaNo, CommitteeId, MeetingId, AgendaStatusCode, ShortText,
       LEN(AgendaText) AS AgendaTextLength, AgendaText, ProposedResolution, MgrComments, ControllerComments
FROM Agenda
WHERE AgendaNo IN ('ZZA1-99901', 'ZZA1-99902')
ORDER BY AgendaNo;

SELECT mi.MinutesId, mi.AgendaId, a.AgendaNo, mi.DecisionTypeId, mi.ActualResolution
FROM Minutes mi
JOIN Agenda a ON a.AgendaId = mi.AgendaId
WHERE a.AgendaNo IN ('ZZA1-99901', 'ZZA1-99902');

SELECT am.AlertId, am.SourceType, am.SourceTypeId, am.DisplayText, am.AlertTypeCode, m.AlertUserId, u.LoginName, m.ReadStatus
FROM Alert_Master am
JOIN Alert_User_Map m ON m.AlertId = am.AlertId
LEFT JOIN Users u ON u.UserId = m.UserId
WHERE am.SourceType = 'Agenda'
  AND am.SourceTypeId IN (SELECT AgendaId FROM Agenda WHERE AgendaNo IN ('ZZA1-99901', 'ZZA1-99902'))
ORDER BY am.AlertId, m.AlertUserId;
GO


/* ============================================================================
   PART 3 - cleanup by the ids of the two test agendas
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @TestAgendaA INT = NULL;    -- leave NULL; set to the id of ZZA1-99901 printed by part 1 only if it was deleted in the browser
DECLARE @TestAgendaB INT = NULL;    -- leave NULL; the same for ZZA1-99902

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @Found INT;

-- ZZA1-99901: found by its agenda number, or the typed id must be that agenda or carry the test alert
IF (@TestAgendaA IS NULL)
    SELECT @TestAgendaA = AgendaId FROM Agenda WHERE AgendaNo = 'ZZA1-99901';
ELSE
BEGIN
    SELECT @Found = COUNT(*) FROM Agenda WHERE AgendaId = @TestAgendaA AND AgendaNo <> 'ZZA1-99901';
    IF (@Found > 0)
    BEGIN
        RAISERROR('AgendaId %d is not the test agenda ZZA1-99901. Check @TestAgendaA. Nothing was changed.', 16, 1, @TestAgendaA);
        RETURN;
    END
    SELECT @Found = COUNT(*) FROM Agenda WHERE AgendaId = @TestAgendaA;
    IF (@Found = 0)
    BEGIN
        SELECT @Found = COUNT(*) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @TestAgendaA AND DisplayText LIKE 'ZZ A1 test -%';
        IF (@Found = 0)
        BEGIN
            RAISERROR('AgendaId %d has no agenda and no "ZZ A1 test -" alert, so it is not the id printed by part 1. Check @TestAgendaA. Nothing was changed.', 16, 1, @TestAgendaA);
            RETURN;
        END
    END
END

-- ZZA1-99902: found by its agenda number, or the typed id must be that agenda or a deleted one
IF (@TestAgendaB IS NULL)
    SELECT @TestAgendaB = AgendaId FROM Agenda WHERE AgendaNo = 'ZZA1-99902';
ELSE
BEGIN
    SELECT @Found = COUNT(*) FROM Agenda WHERE AgendaId = @TestAgendaB AND AgendaNo <> 'ZZA1-99902';
    IF (@Found > 0)
    BEGIN
        RAISERROR('AgendaId %d is not the test agenda ZZA1-99902. Check @TestAgendaB. Nothing was changed.', 16, 1, @TestAgendaB);
        RETURN;
    END
END

IF (@TestAgendaA IS NULL AND @TestAgendaB IS NULL)
BEGIN
    RAISERROR('Neither ZZA1-99901 nor ZZA1-99902 was found. If one was deleted in the browser, set its id at the top of part 3. Nothing was changed.', 16, 1);
    RETURN;
END

-- Anything else that references the test rows stops the cleanup
DECLARE @MinutesOfA INT, @MinutesOfB INT, @ActionItems INT;
SELECT @MinutesOfA = COUNT(*) FROM Minutes WHERE AgendaId = @TestAgendaA;
SELECT @MinutesOfB = COUNT(*) FROM Minutes WHERE AgendaId = @TestAgendaB;
SELECT @ActionItems = COUNT(*) FROM Action_Item WHERE MinutesId IN (SELECT MinutesId FROM Minutes WHERE AgendaId = @TestAgendaB);
IF (@MinutesOfA > 0 OR @MinutesOfB > 1 OR @ActionItems > 0)
BEGIN
    RAISERROR('Other rows reference the test agendas (%d minute(s) of ZZA1-99901, %d minute(s) of ZZA1-99902, %d action item(s)); this cleanup does not delete them. Nothing was changed.', 16, 1,
              @MinutesOfA, @MinutesOfB, @ActionItems);
    RETURN;
END

DECLARE @MapRows INT, @AlertRows INT, @MinutesRows INT, @AgendaRows INT;

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE m
    FROM Alert_User_Map m
    JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId IN (@TestAgendaA, @TestAgendaB);
    SET @MapRows = @@ROWCOUNT;

    DELETE FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId IN (@TestAgendaA, @TestAgendaB);
    SET @AlertRows = @@ROWCOUNT;

    DELETE FROM Minutes WHERE AgendaId = @TestAgendaB;
    SET @MinutesRows = @@ROWCOUNT;

    DELETE FROM Agenda WHERE AgendaId IN (@TestAgendaA, @TestAgendaB);
    SET @AgendaRows = @@ROWCOUNT;

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
SET @Line = N'AgendaId ' + ISNULL(CAST(@TestAgendaA AS NVARCHAR(12)), N'-') + N' and ' + ISNULL(CAST(@TestAgendaB AS NVARCHAR(12)), N'-')
          + N': deleted ' + CAST(@MapRows AS NVARCHAR(12)) + N' Alert_User_Map row(s), ' + CAST(@AlertRows AS NVARCHAR(12)) + N' Alert_Master row(s), '
          + CAST(@MinutesRows AS NVARCHAR(12)) + N' Minutes row(s) and ' + CAST(@AgendaRows AS NVARCHAR(12)) + N' Agenda row(s).';
PRINT @Line;
PRINT N'Expected: at least 1 alert (more when the browser tests added alerts), 1 minute when ZZA1-99902 was added, 2 agendas (1 when no meeting had minutes).';
GO
