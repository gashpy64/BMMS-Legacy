/* ============================================================================
   BMMS tester - fixture check for BMMS_Quality (step WF3a1; committee QA2
   checked since step UN6b)
   ----------------------------------------------------------------------------
   READ ONLY. It reads rows and changes nothing (one table variable).
   Run by the tester after the fixture, after every restore of the baseline
   and by Update-Baseline.ps1. It lists every check with what was expected and
   what was found, and ends with

       FIXTURE CHECK: PASS (n checks)

   or with an error naming the number of failed checks. It runs on BMMS_Quality
   only. No password or hash is shown: of a hash only its form is checked.
   Compatibility level 100. Plain ASCII.
   ============================================================================ */
SET NOCOUNT ON;
GO
DECLARE @CurrentDatabase SYSNAME;
SET @CurrentDatabase = DB_NAME();
IF (@CurrentDatabase COLLATE Latin1_General_BIN <> N'BMMS_Quality')
BEGIN
    RAISERROR('Current database is "%s". This check runs on BMMS_Quality only.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO
DECLARE @T TABLE (Seq INT IDENTITY(1, 1), Name VARCHAR(120), Expected VARCHAR(200), Actual VARCHAR(200));
DECLARE @Today DATETIME;
DECLARE @C INT;
DECLARE @C2 INT;
DECLARE @Failed INT;
DECLARE @Total INT;
DECLARE @A TABLE (LoginName VARCHAR(50), RoleCode VARCHAR(50), Active INT, Departments INT);

SET @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);
SET @C = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'QA1');
SET @C2 = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'QA2');

-- Accounts: role, active flag, open department rows
INSERT INTO @A VALUES ('qa_admin', 'admin', 1, 1);
INSERT INTO @A VALUES ('qa_ctrl', 'controller', 1, 1);
INSERT INTO @A VALUES ('qa_manager', 'manager', 1, 1);
INSERT INTO @A VALUES ('qa_manager2', 'manager', 1, 2);
INSERT INTO @A VALUES ('qa_user', 'user', 1, 1);
INSERT INTO @A VALUES ('qa_user2', 'user', 1, 1);
INSERT INTO @A VALUES ('qa_mgmt', 'mgmt', 1, 1);
INSERT INTO @A VALUES ('qa_mdsec', 'md_sect', 1, 1);
INSERT INTO @A VALUES ('qa_inactive', 'user', 0, 0);

INSERT INTO @T (Name, Expected, Actual)
SELECT 'Account ' + a.LoginName + ': role, active, open role rows, open department rows',
       a.RoleCode + ', ' + CAST(a.Active AS VARCHAR(2)) + ', ' + CAST(a.Active AS VARCHAR(2)) + ', ' + CAST(a.Departments AS VARCHAR(2)),
       ISNULL((SELECT r.RoleCode + ', ' + CAST(u.AccountStatus AS VARCHAR(2)) + ', '
                    + CAST((SELECT COUNT(*) FROM User_Role ur WHERE ur.UserId = u.UserId AND ur.EffectiveTo IS NULL) AS VARCHAR(12)) + ', '
                    + CAST((SELECT COUNT(*) FROM User_Department ud WHERE ud.UserId = u.UserId AND ud.EffectiveTo IS NULL) AS VARCHAR(12))
               FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.LoginName = a.LoginName), 'account missing')
FROM @A a;

INSERT INTO @T (Name, Expected, Actual)
SELECT 'Accounts with a password hash of the application (100000.salt.hash)', '9',
       CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'qa[_]%' AND Password LIKE '100000._%._%' AND LEN(Password) > 60) AS VARCHAR(12));
INSERT INTO @T (Name, Expected, Actual)
SELECT 'qa_ accounts in all', '9', CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'qa[_]%') AS VARCHAR(12));
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Users in all (four seeded and nine qa_)', '13', CAST((SELECT COUNT(*) FROM Users) AS VARCHAR(12));
INSERT INTO @T (Name, Expected, Actual)
SELECT 'qa_user reports to qa_manager; qa_user2 to qa_manager2', 'yes',
       CASE WHEN EXISTS (SELECT 1 FROM Users u JOIN Users m ON m.UserId = u.ManagerId WHERE u.LoginName = 'qa_user' AND m.LoginName = 'qa_manager')
             AND EXISTS (SELECT 1 FROM Users u JOIN Users m ON m.UserId = u.ManagerId WHERE u.LoginName = 'qa_user2' AND m.LoginName = 'qa_manager2')
            THEN 'yes' ELSE 'no' END;
INSERT INTO @T (Name, Expected, Actual)
SELECT 'qa_manager2 departments (home first)', 'D003*, D002',
       ISNULL(STUFF((SELECT ', ' + d.DepartmentCode + CASE WHEN ud.IsHome = 1 THEN '*' ELSE '' END
                     FROM User_Department ud JOIN Department d ON d.DepartmentId = ud.DepartmentId JOIN Users u ON u.UserId = ud.UserId
                     WHERE u.LoginName = 'qa_manager2' AND ud.EffectiveTo IS NULL
                     ORDER BY ud.IsHome DESC, d.DepartmentCode FOR XML PATH('')), 1, 2, ''), 'none');

-- Committee and members
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Committee QA1: active, committee members', '1, 2',
       ISNULL((SELECT CAST(c.StatusId AS VARCHAR(2)) + ', ' + CAST((SELECT COUNT(*) FROM Committee_Member cm WHERE cm.CommitteeId = c.CommitteeId) AS VARCHAR(12))
               FROM Committee c WHERE c.CommitteeId = @C), 'committee missing');

-- Meetings: agenda status, minutes status, minutes rows, where the dates lie
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Meeting ' + x.MeetingNo + ' (' + x.What + '): agenda, minutes, minutes rows, meeting date, submission date',
       x.Expected,
       ISNULL((SELECT ISNULL(m.AgendaStatus, 'Open') + ', ' + ISNULL(m.MinutesStatus, 'Open') + ', '
                    + CAST((SELECT COUNT(*) FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.MeetingId = m.MeetingId) AS VARCHAR(12)) + ', '
                    + CASE WHEN m.MeetingDate > @Today THEN 'ahead' WHEN m.MeetingDate < @Today THEN 'passed' ELSE 'today' END + ', '
                    + CASE WHEN m.AgendaSubmissionDate > @Today THEN 'ahead' WHEN m.AgendaSubmissionDate < @Today THEN 'passed' ELSE 'today' END
               FROM Meeting m WHERE m.CommitteeId = @C AND m.MeetingNo = x.MeetingNo), 'meeting missing')
FROM (SELECT '00001' AS MeetingNo, 'agenda open' AS What, 'Open, Open, 0, ahead, ahead' AS Expected
      UNION ALL SELECT '00002', 'submission date passed', 'Open, Open, 0, ahead, passed'
      UNION ALL SELECT '00003', 'agenda finalised', 'Close, Open, 1, ahead, passed'
      UNION ALL SELECT '00004', 'minutes in Draft', 'Close, Open, 2, passed, passed'
      UNION ALL SELECT '00005', 'minutes Finalised', 'Close, F, 2, passed, passed'
      UNION ALL SELECT '00006', 'minutes Confirmed', 'Close, C, 1, passed, passed') x;

INSERT INTO @T (Name, Expected, Actual)
SELECT 'Meetings of QA1 in all', '6', CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C) AS VARCHAR(12));

-- Agenda items of meeting 00001 by status
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Meeting 00001 items by status (AC, AMA, ACA, AMR, ACR)', '2, 1, 1, 1, 1',
       ISNULL((SELECT CAST(SUM(CASE WHEN a.AgendaStatusCode = 'AC' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ', '
                    + CAST(SUM(CASE WHEN a.AgendaStatusCode = 'AMA' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ', '
                    + CAST(SUM(CASE WHEN a.AgendaStatusCode = 'ACA' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ', '
                    + CAST(SUM(CASE WHEN a.AgendaStatusCode = 'AMR' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ', '
                    + CAST(SUM(CASE WHEN a.AgendaStatusCode = 'ACR' THEN 1 ELSE 0 END) AS VARCHAR(12))
               FROM Agenda a JOIN Meeting m ON m.MeetingId = a.MeetingId WHERE m.CommitteeId = @C AND m.MeetingNo = '00001'), 'no items');
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Meeting 00001: an HRD item at AC (the second department)', '1',
       CAST((SELECT COUNT(*) FROM Agenda a JOIN Meeting m ON m.MeetingId = a.MeetingId JOIN Department d ON d.DepartmentId = a.DepartmentId
             WHERE m.CommitteeId = @C AND m.MeetingNo = '00001' AND d.DepartmentCode = 'D003' AND a.AgendaStatusCode = 'AC') AS VARCHAR(12));
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Meeting 00002: items at AC', '1',
       CAST((SELECT COUNT(*) FROM Agenda a JOIN Meeting m ON m.MeetingId = a.MeetingId
             WHERE m.CommitteeId = @C AND m.MeetingNo = '00002' AND a.AgendaStatusCode = 'AC') AS VARCHAR(12));
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Agenda items of QA1 in all', '13',
       CAST((SELECT COUNT(*) FROM Agenda a JOIN Meeting m ON m.MeetingId = a.MeetingId WHERE m.CommitteeId = @C) AS VARCHAR(12));

-- Minutes side
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Meeting 00004 workflow state (agenda finalised, attendance, minutes updated/total)', '1, 1, 2/2',
       ISNULL((SELECT CAST(s.AgendaFinalized AS VARCHAR(2)) + ', ' + CAST(s.AttendanceRecorded AS VARCHAR(2)) + ', '
                    + CAST(s.MinutesUpdated AS VARCHAR(12)) + '/' + CAST(s.MinutesTotal AS VARCHAR(12))
               FROM Meeting m CROSS APPLY dbo.fn_WorkflowState(m.MeetingId) s WHERE m.CommitteeId = @C AND m.MeetingNo = '00004'), 'no state');
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Meetings 00005 and 00006: Followup action items (step UN6c1: two and one)', '2, 1',
       CAST((SELECT COUNT(*) FROM Action_Item ai JOIN Minutes mi ON mi.MinutesId = ai.MinutesId JOIN Agenda a ON a.AgendaId = mi.AgendaId
             JOIN Meeting m ON m.MeetingId = a.MeetingId WHERE m.CommitteeId = @C AND m.MeetingNo = '00005') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM Action_Item ai JOIN Minutes mi ON mi.MinutesId = ai.MinutesId JOIN Agenda a ON a.AgendaId = mi.AgendaId
             JOIN Meeting m ON m.MeetingId = a.MeetingId WHERE m.CommitteeId = @C AND m.MeetingNo = '00006') AS VARCHAR(12));
-- Step UN6c1: the scope of the Action Items card
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Action items in all; who is mapped to QA1-00006-001; to QA2-00003-1; to QA2-00002-1', '5; qa_user; qa_ctrl; qa_user',
       CAST((SELECT COUNT(*) FROM Action_Item) AS VARCHAR(12)) + '; '
     + ISNULL(STUFF((SELECT ',' + u.LoginName FROM ActionItem_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Action_Item ai ON ai.ActionItemId = m.ActionItemId
                     JOIN Minutes mi ON mi.MinutesId = ai.MinutesId JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.AgendaNo = 'QA1-00006-001' ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), 'none') + '; '
     + ISNULL(STUFF((SELECT ',' + u.LoginName FROM ActionItem_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Action_Item ai ON ai.ActionItemId = m.ActionItemId
                     JOIN Minutes mi ON mi.MinutesId = ai.MinutesId JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.AgendaNo = 'QA2-00003-1' ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), 'none') + '; '
     + ISNULL(STUFF((SELECT ',' + u.LoginName FROM ActionItem_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Action_Item ai ON ai.ActionItemId = m.ActionItemId
                     JOIN Minutes mi ON mi.MinutesId = ai.MinutesId JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.AgendaNo = 'QA2-00002-1' ORDER BY u.LoginName FOR XML PATH('')), 1, 1, ''), 'none');
-- Step UN6c1: the Alerts card
INSERT INTO @T (Name, Expected, Actual)
SELECT 'qa_user: alerts in all, read (QA1-00004-001, QA1-00004-002, Committee (QA2))', '12, 3',
       CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE u.LoginName = 'qa_user' AND m.StatusId = 1) AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Alert_Master am ON am.AlertId = m.AlertId
             WHERE u.LoginName = 'qa_user' AND m.StatusId = 1 AND m.ReadStatus = 1
             AND am.DisplayText IN ('Agenda (QA1-00004-001)', 'Agenda (QA1-00004-002)', 'Committee (QA2)')) AS VARCHAR(12));
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Item QA1-00005-001 has no recorded approver; qa_admin has alert rows (the listing rule hides them)', 'none, yes',
       ISNULL((SELECT CASE WHEN a.ControllerApprovedBy IS NULL AND a.ControllerApprovedDate IS NULL THEN 'none' ELSE 'recorded' END
               FROM Agenda a WHERE a.CommitteeId = @C AND a.AgendaNo = 'QA1-00005-001'), 'item missing') + ', '
     + CASE WHEN EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId WHERE u.LoginName = 'qa_admin' AND m.StatusId = 1) THEN 'yes' ELSE 'no' END;

-- Committee QA2 (step UN6b): the Dashboard's meeting list
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Committee QA2: active; meetings; dated today; completed', '1; 12; 1; 11',
       ISNULL((SELECT CAST(c.StatusId AS VARCHAR(2)) FROM Committee c WHERE c.CommitteeId = @C2), 'committee missing') + '; '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C2) AS VARCHAR(12)) + '; '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C2 AND MeetingDate = @Today) AS VARCHAR(12)) + '; '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C2 AND MeetingDate < @Today) AS VARCHAR(12));
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Committee QA2: minutes Open, F, C', '2, 1, 9',
       CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C2 AND ISNULL(MinutesStatus, 'Open') = 'Open') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C2 AND MinutesStatus = 'F') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C2 AND MinutesStatus = 'C') AS VARCHAR(12));
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Committee QA2 items: Credit ACA, Credit ACR, Secretarial ACA; minutes rows (the two Followups of step UN6c1); alerts', '10, 1, 1; 2; 0',
       CAST((SELECT COUNT(*) FROM Agenda a JOIN Department d ON d.DepartmentId = a.DepartmentId WHERE a.CommitteeId = @C2 AND d.DepartmentCode = 'D004' AND a.AgendaStatusCode = 'ACA') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM Agenda a JOIN Department d ON d.DepartmentId = a.DepartmentId WHERE a.CommitteeId = @C2 AND d.DepartmentCode = 'D004' AND a.AgendaStatusCode = 'ACR') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM Agenda a JOIN Department d ON d.DepartmentId = a.DepartmentId WHERE a.CommitteeId = @C2 AND d.DepartmentCode = 'D002' AND a.AgendaStatusCode = 'ACA') AS VARCHAR(12)) + '; '
     + CAST((SELECT COUNT(*) FROM Minutes mi JOIN Agenda a ON a.AgendaId = mi.AgendaId WHERE a.CommitteeId = @C2) AS VARCHAR(12)) + '; '
     + CAST((SELECT COUNT(*) FROM Alert_Master am JOIN Agenda a ON a.AgendaId = am.SourceTypeId WHERE am.SourceType = 'Agenda' AND a.CommitteeId = @C2) AS VARCHAR(12));

-- Mail: the safe default row only (no real mail can be sent)
INSERT INTO @T (Name, Expected, Actual)
SELECT 'Mail settings: rows; server and port', '1; localhost:25',
       CAST((SELECT COUNT(*) FROM SMTP_Master) AS VARCHAR(12)) + '; '
     + ISNULL((SELECT TOP 1 CAST(SMTPServer AS VARCHAR(100)) + ':' + CAST(SMTPServerPort AS VARCHAR(12)) FROM SMTP_Master), 'none');

SELECT Seq, Name, Expected, Actual, CASE WHEN Expected = Actual THEN 'PASS' ELSE 'FAIL' END AS Result FROM @T ORDER BY Seq;

SET @Total = (SELECT COUNT(*) FROM @T);
SET @Failed = (SELECT COUNT(*) FROM @T WHERE Expected <> Actual OR Actual IS NULL);
IF (@Failed > 0)
    RAISERROR('FIXTURE CHECK: FAIL (%d of %d checks failed)', 16, 1, @Failed, @Total);
ELSE
    PRINT 'FIXTURE CHECK: PASS (' + CAST(@Total AS VARCHAR(12)) + ' checks)';
GO
SET NOEXEC OFF;
GO
