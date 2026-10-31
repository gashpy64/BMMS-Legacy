/* ============================================================================
   BMMS - Browser test rows for step A1b-2 (plain text encoded on the master,
   meeting and report grids)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY on the database BMMS_Test: every part stops with a message on any
   other database. It has no USE line: select BMMS_Test in SSMS first.

   The file has three parts. Select the lines of ONE part and press F5.
   Rows are written with plain INSERTs, as in the A1 and F3 test scripts; no
   procedure is created, altered or run. The file is plain ASCII.

   Test texts, rotated over the name columns:
     A  ZZ A1b O'Brien & Sons <b>x</b>         (30 characters)
     B  ZZ A1b <script>alert(1)</script>       (32 characters)
     C  ZZ A1b <img src=x onerror=alert(2)>    (35 characters)
     D  <i>T'&</i>                             (10 characters, for the
                                                 10-character columns)
   Codes are short plain values (ZZB1D, ZZB1G ...), because the code columns
   are short. The member and the committee get one letter and digits (A902,
   A901): spr_GetNextMemberCode and spr_GetNextCommitteeCode read the highest
   code and convert the characters after the first one to a number, so a
   code such as ZZB1M or ZZB1C made the Add pages of Member Master and
   Committee Master fail; A sorts below the M and C codes they generate, so
   the test codes never become the highest. Because A901 and A902 look like
   ordinary codes, parts 2 and 3 take the member and the committee only when
   the name also starts with "ZZ A1b". Parts 2 and 3 also find the rows of an
   earlier run under the old codes ZZB1M and ZZB1C. Meeting numbers stay
   numeric (1 and 2): the Reports page reads them with int.Parse.

   PART 1  Checks every column it writes (it must exist and the text must
           fit) and stops before writing anything when one fails; refuses
           when rows of an earlier run are still there. Then inserts:
             Department     ZZB1D  name A
             Designation    ZZB1G  name B
             Decision Type  ZZB1T  name C
             Subject Type   ZZB1S  name A
             Member Type    ZZB1Y  name B (committee scope, not reserved)
             Member         A902   name C, Address1 A, DOJ B, designation ZZB1G
             Committee      A901   name A, with the member as committee
                                   member of type ZZB1Y (fee applicable)
             Meeting 2      dated tomorrow, no members: Place A, Venue B,
                            time 10:00 (Edit, Update and Delete on screen)
             Meeting 1      dated yesterday: Place B, Venue C, time D, with
                            the member as meeting member (an existing
                            meeting-scope type) and one Attendance row
                            (present, sitting fee 1000)
             User           login zza1b, name A, inactive, not a system
                            account, no usable password, department ZZB1D,
                            designation ZZB1G, role User
             Audit trail    one Audit_Trail_Master row by the test user:
                            table ZZA1b, Key_Value D, Field_Name B
             Backup         one Audit_Trail_SqlBackup row by the test user:
                            file name C, IP address B
           Prints the new ids.
   PART 2  Read-only: shows every test row.
   PART 3  Cleanup. Finds the test rows by their codes (ZZB1D ... ZZB1Y;
           member A902 or ZZB1M and committee A901 or ZZB1C, each with a name
           starting "ZZ A1b"; login zza1b, audit table ZZA1b, backup file name
           starting with "ZZ A1b"), so rows already deleted in the browser are simply
           skipped. Refuses, changing nothing, when other rows use them: an
           agenda item, another meeting of the test committee, the test
           member in another committee or meeting, another member, user,
           minute or agenda item using a test type, department or
           designation, or a user managed by the test user. Then deletes,
           children first: the alerts of the test committee and meetings
           (written by browser saves), Attendance, Meeting_Member, the
           meetings, Committee_Member, the committee, the member, the two
           audit rows, the user, then the five type rows. Prints a count for
           each. Rows added in the browser under other codes (for example
           the "ZZ O'Brien" rows of the save test) are deleted on screen.
           Audit trail rows written by browser saves are history and are kept.
   ============================================================================ */


/* ============================================================================
   PART 1 - check the columns, then insert the test rows
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @A VARCHAR(50) = 'ZZ A1b O''Brien & Sons <b>x</b>';
DECLARE @B VARCHAR(50) = 'ZZ A1b <script>alert(1)</script>';
DECLARE @C VARCHAR(50) = 'ZZ A1b <img src=x onerror=alert(2)>';
DECLARE @D VARCHAR(50) = '<i>T''&</i>';

-- Every column written: it must exist; a text column must hold the value (NeedChars NULL: must exist only)
DECLARE @Need TABLE (TableName SYSNAME, ColumnName SYSNAME, NeedChars INT NULL);
INSERT INTO @Need (TableName, ColumnName, NeedChars) VALUES
    ('Department', 'DepartmentCode', 5), ('Department', 'DepartmentName', LEN(@A)), ('Department', 'OrderNo', NULL),
    ('Designation', 'DesignationCode', 5), ('Designation', 'DesignationName', LEN(@B)),
    ('Decision_Type', 'DecisionTypeCode', 5), ('Decision_Type', 'DecisionTypeName', LEN(@C)), ('Decision_Type', 'IsDelete', NULL),
    ('Subject_Type', 'SubjectTypeCode', 5), ('Subject_Type', 'SubjectTypeName', LEN(@A)), ('Subject_Type', 'OrderNo', NULL), ('Subject_Type', 'IsDelete', NULL),
    ('Member_Type', 'MemberTypeCode', 5), ('Member_Type', 'MemberTypeName', LEN(@B)), ('Member_Type', 'IsDelete', NULL),
    ('Member_Type', 'MemberScope', 1), ('Member_Type', 'DisplayOrder', NULL), ('Member_Type', 'IsReserved', NULL),
    ('Member', 'MemberCode', 5), ('Member', 'MemberName', LEN(@C)), ('Member', 'Address1', LEN(@A)), ('Member', 'DOJ', LEN(@B)),
    ('Member', 'EmailId', 21),
    ('Committee', 'CommitteeCode', 5), ('Committee', 'CommitteeName', LEN(@A)), ('Committee', 'Board', NULL),
    ('Committee', 'IncorporationDate', NULL), ('Committee', 'MeetingStartNo', NULL), ('Committee', 'CommitteeColorCode', NULL),
    ('Committee', 'IsDelete', NULL),
    ('Committee_Member', 'AppointmentDate', NULL), ('Committee_Member', 'CessationDate', NULL),
    ('Committee_Member', 'IsFeeApplicable', NULL), ('Committee_Member', 'ApplicableFee', NULL),
    ('Meeting', 'MeetingNo', 1), ('Meeting', 'Place', LEN(@B)), ('Meeting', 'Venue', LEN(@C)), ('Meeting', 'MeetingTime', LEN(@D)),
    ('Meeting', 'AgendaSubmissionDate', NULL), ('Meeting', 'AgendaStatus', 4), ('Meeting', 'MinutesStatus', 4),
    ('Meeting_Member', 'MemberTypeId', NULL),
    ('Attendance', 'MemberOf', 1), ('Attendance', 'Attendance', 1), ('Attendance', 'SittingFees', NULL),
    ('Users', 'UserName', LEN(@A)), ('Users', 'LoginName', 5), ('Users', 'EmailId', 21), ('Users', 'IsSystem', NULL),
    ('Audit_Trail_Master', 'Audit_Type', 2), ('Audit_Trail_Master', 'Audit_Table', 5), ('Audit_Trail_Master', 'Key_Field', 5),
    ('Audit_Trail_Master', 'Key_Value', LEN(@D)), ('Audit_Trail_Master', 'Field_Name', LEN(@B)),
    ('Audit_Trail_Master', 'Old_Value', 6), ('Audit_Trail_Master', 'New_Value', 6),
    ('Audit_Trail_Master', 'Update_By', NULL), ('Audit_Trail_Master', 'Update_On', NULL),
    ('Audit_Trail_SqlBackup', 'Backup_File_Name', LEN(@C)), ('Audit_Trail_SqlBackup', 'User_Id', NULL),
    ('Audit_Trail_SqlBackup', 'User_IP_Address', LEN(@B)), ('Audit_Trail_SqlBackup', 'Server_Url', 6),
    ('Audit_Trail_SqlBackup', 'Backup_Date_Time', NULL);

-- ColumnId NULL: the column is not there; HasChars: the width of a character column (-1 for MAX), NULL for any other type
DECLARE @Columns TABLE (TableName SYSNAME, ColumnName SYSNAME, NeedChars INT NULL, ColumnId INT NULL, HasChars INT NULL);
INSERT INTO @Columns (TableName, ColumnName, NeedChars, ColumnId, HasChars)
SELECT n.TableName, n.ColumnName, n.NeedChars, c.ORDINAL_POSITION, c.CHARACTER_MAXIMUM_LENGTH
FROM @Need n
LEFT JOIN INFORMATION_SCHEMA.COLUMNS c
       ON c.TABLE_SCHEMA = N'dbo' AND c.TABLE_NAME = n.TableName AND c.COLUMN_NAME = n.ColumnName;

DECLARE @BadColumns INT;
SELECT @BadColumns = COUNT(*) FROM @Columns
WHERE ColumnId IS NULL
   OR (NeedChars IS NOT NULL AND (HasChars IS NULL OR (HasChars <> -1 AND HasChars < NeedChars)));
IF (@BadColumns > 0)
BEGIN
    SELECT TableName, ColumnName, NeedChars AS CharactersNeeded,
           CASE WHEN ColumnId IS NULL THEN 'column not found' ELSE 'text too long for the column' END AS Problem,
           HasChars AS ColumnCharacters
    FROM @Columns
    WHERE ColumnId IS NULL
       OR (NeedChars IS NOT NULL AND (HasChars IS NULL OR (HasChars <> -1 AND HasChars < NeedChars)))
    ORDER BY TableName, ColumnName;
    RAISERROR('%d column(s) are missing or too short for the test text (listed in the results). Nothing was changed.', 16, 1, @BadColumns);
    RETURN;
END

DECLARE @Existing INT;
SET @Existing =
      (SELECT COUNT(*) FROM Department    WHERE DepartmentCode   = 'ZZB1D' OR DepartmentName   LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Designation   WHERE DesignationCode  = 'ZZB1G' OR DesignationName  LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Decision_Type WHERE DecisionTypeCode = 'ZZB1T' OR DecisionTypeName LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Subject_Type  WHERE SubjectTypeCode  = 'ZZB1S' OR SubjectTypeName  LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Member_Type   WHERE MemberTypeCode   = 'ZZB1Y' OR MemberTypeName   LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Member        WHERE MemberCode IN ('A902', 'ZZB1M') OR MemberName LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Committee     WHERE CommitteeCode IN ('A901', 'ZZB1C') OR CommitteeName LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Users         WHERE LoginName        = 'zza1b' OR UserName         LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Audit_Trail_Master    WHERE Audit_Table = 'ZZA1b')
    + (SELECT COUNT(*) FROM Audit_Trail_SqlBackup WHERE Backup_File_Name LIKE 'ZZ A1b%');
-- A902 and A901 look like ordinary codes: a real member or committee holding one of them stops the test
DECLARE @CodeTaken INT;
SET @CodeTaken =
      (SELECT COUNT(*) FROM Member    WHERE MemberCode    = 'A902' AND MemberName    NOT LIKE 'ZZ A1b%')
    + (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'A901' AND CommitteeName NOT LIKE 'ZZ A1b%');
IF (@CodeTaken > 0)
BEGIN
    RAISERROR('A member with code A902 or a committee with code A901 already exists and is not a test row. Change the two test codes in this file. Nothing was changed.', 16, 1);
    RETURN;
END
IF (@Existing > 0)
BEGIN
    RAISERROR('%d test row(s) from an earlier run are still there. Run part 3 first. Nothing was changed.', 16, 1, @Existing);
    RETURN;
END

DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @UserRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @MeetingTypeId INT = (SELECT TOP 1 MemberTypeId FROM Member_Type WHERE MemberScope = 'M' AND StatusId = 1 ORDER BY DisplayOrder, MemberTypeId);
DECLARE @ColorCode VARCHAR(50) = (SELECT TOP 1 CommitteeColorCode FROM Committee WHERE ISNULL(CommitteeColorCode, '') <> '' ORDER BY CommitteeId);
IF (@Sys IS NULL OR @UserRoleId IS NULL OR @MeetingTypeId IS NULL)
BEGIN
    RAISERROR('The system account, the role "user" or an active meeting-scope member type was not found. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @Now DATETIME = GETDATE();
DECLARE @Today DATETIME = CAST(CAST(GETDATE() AS date) AS DATETIME);
DECLARE @Tomorrow DATETIME = DATEADD(DAY, 1, @Today);
DECLARE @Yesterday DATETIME = DATEADD(DAY, -1, @Today);
DECLARE @TwoDaysAgo DATETIME = DATEADD(DAY, -2, @Today);

DECLARE @DeptId INT, @DesigId INT, @DecisionId INT, @SubjectId INT, @MemberTypeId INT, @MemberId INT, @CommitteeId INT,
        @CommitteeMemberId INT, @MeetingNext INT, @MeetingPast INT, @MeetingMemberId INT, @AttendanceId INT, @TestUserId INT,
        @AuditId INT, @BackupId INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZB1D', @A, 999, 1, @Now, @Sys, @Now, @Sys);
    SET @DeptId = SCOPE_IDENTITY();

    INSERT INTO Designation (DesignationCode, DesignationName, StatusId, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZB1G', @B, 1, @Now, @Sys, @Now, @Sys);
    SET @DesigId = SCOPE_IDENTITY();

    INSERT INTO Decision_Type (DecisionTypeCode, DecisionTypeName, StatusId, IsDelete, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZB1T', @C, 1, 0, @Now, @Sys, @Now, @Sys);
    SET @DecisionId = SCOPE_IDENTITY();

    INSERT INTO Subject_Type (SubjectTypeCode, SubjectTypeName, OrderNo, StatusId, IsDelete, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZB1S', @A, 999, 1, 0, @Now, @Sys, @Now, @Sys);
    SET @SubjectId = SCOPE_IDENTITY();

    INSERT INTO Member_Type (MemberTypeCode, MemberTypeName, StatusId, IsDelete, MemberScope, DisplayOrder, IsReserved, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZB1Y', @B, 1, 0, 'C', 999, 0, @Now, @Sys, @Now, @Sys);
    SET @MemberTypeId = SCOPE_IDENTITY();

    INSERT INTO Member (MemberCode, MemberName, DesignationId, Address1, DOJ, EmailId, StatusId, CreatedOn, CreatedBy)
    VALUES ('A902', @C, @DesigId, @A, @B, 'zzb1m@example.invalid', 1, @Now, @Sys);
    SET @MemberId = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, Board, IncorporationDate, MeetingStartNo, CommitteeColorCode, StatusId, IsDelete, CreatedOn, CreatedBy)
    VALUES ('A901', @A, 0, '2000-01-01', 1, @ColorCode, 1, 0, @Now, @Sys);
    SET @CommitteeId = SCOPE_IDENTITY();

    INSERT INTO Committee_Member (CommitteeId, MemberId, MemberTypeId, AppointmentDate, CessationDate, IsFeeApplicable, ApplicableFee, CreatedOn, CreatedBy)
    VALUES (@CommitteeId, @MemberId, @MemberTypeId, '01-Jan-2000', '', 1, 1000, @Now, @Sys);
    SET @CommitteeMemberId = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('1', @CommitteeId, @B, @C, @Yesterday, @D, @TwoDaysAgo, 'Open', 'Open');
    SET @MeetingPast = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('2', @CommitteeId, @A, @B, @Tomorrow, '10:00', @Today, 'Open', 'Open');
    SET @MeetingNext = SCOPE_IDENTITY();

    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy)
    VALUES (@MeetingPast, @MemberId, @MeetingTypeId, 1, @Now, @Sys);
    SET @MeetingMemberId = SCOPE_IDENTITY();

    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@CommitteeId, @MeetingPast, 'C', @MemberId, 'P', 1000, @Now, @Sys);
    SET @AttendanceId = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus,
                       CreatedOn, CreatedBy, UpdatedOn, UpdatedBy, IsSystem)
    VALUES (@A, @DeptId, @DesigId, NULL, @UserRoleId, 'zza1b@example.invalid', 'zza1b', 'not-a-login', 0, @Now, @Sys, @Now, @Sys, 0);
    SET @TestUserId = SCOPE_IDENTITY();

    INSERT INTO Audit_Trail_Master (Audit_Type, Audit_Table, Key_Field, Key_Value, Field_Name, Old_Value, New_Value, Update_By, Update_On)
    VALUES ('UP', 'ZZA1b', 'ZZA1b', @D, @B, 'ZZ old', 'ZZ new', @TestUserId, @Now);
    SET @AuditId = SCOPE_IDENTITY();

    INSERT INTO Audit_Trail_SqlBackup (Backup_File_Name, User_Id, User_IP_Address, Server_Url, Backup_Date_Time)
    VALUES (@C, @TestUserId, @B, 'ZZ A1b', @Now);
    SET @BackupId = SCOPE_IDENTITY();

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
SET @Line = N'DepartmentId ' + CAST(@DeptId AS NVARCHAR(12)) + N', DesignationId ' + CAST(@DesigId AS NVARCHAR(12))
          + N', DecisionTypeId ' + CAST(@DecisionId AS NVARCHAR(12)) + N', SubjectTypeId ' + CAST(@SubjectId AS NVARCHAR(12))
          + N', MemberTypeId ' + CAST(@MemberTypeId AS NVARCHAR(12));
PRINT @Line;
SET @Line = N'MemberId ' + CAST(@MemberId AS NVARCHAR(12)) + N', CommitteeId ' + CAST(@CommitteeId AS NVARCHAR(12))
          + N', CommitteeMemberId ' + CAST(@CommitteeMemberId AS NVARCHAR(12));
PRINT @Line;
SET @Line = N'Meeting 1 (yesterday) MeetingId ' + CAST(@MeetingPast AS NVARCHAR(12)) + N', MeetingMemberId ' + CAST(@MeetingMemberId AS NVARCHAR(12))
          + N', AttendanceId ' + CAST(@AttendanceId AS NVARCHAR(12)) + N'; Meeting 2 (tomorrow) MeetingId ' + CAST(@MeetingNext AS NVARCHAR(12));
PRINT @Line;
SET @Line = N'UserId ' + CAST(@TestUserId AS NVARCHAR(12)) + N' (login zza1b, inactive), Audit_Trail_Master id ' + CAST(@AuditId AS NVARCHAR(12))
          + N', Audit_Trail_SqlBackup id ' + CAST(@BackupId AS NVARCHAR(12));
PRINT @Line;
PRINT N'Run the browser tests, then part 2. Part 3 finds the rows by their codes.';
GO


/* ============================================================================
   PART 2 - read-only: every test row
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

SELECT 'Department' AS RowType, DepartmentId AS Id, DepartmentCode AS Code, DepartmentName AS Name FROM Department WHERE DepartmentCode = 'ZZB1D'
UNION ALL SELECT 'Designation', DesignationId, DesignationCode, DesignationName FROM Designation WHERE DesignationCode = 'ZZB1G'
UNION ALL SELECT 'Decision_Type', DecisionTypeId, DecisionTypeCode, DecisionTypeName FROM Decision_Type WHERE DecisionTypeCode = 'ZZB1T'
UNION ALL SELECT 'Subject_Type', SubjectTypeId, SubjectTypeCode, SubjectTypeName FROM Subject_Type WHERE SubjectTypeCode = 'ZZB1S'
UNION ALL SELECT 'Member_Type', MemberTypeId, MemberTypeCode, MemberTypeName FROM Member_Type WHERE MemberTypeCode = 'ZZB1Y'
UNION ALL SELECT 'Member', MemberId, MemberCode, MemberName FROM Member WHERE MemberCode IN ('A902', 'ZZB1M') AND MemberName LIKE 'ZZ A1b%'
UNION ALL SELECT 'Committee', CommitteeId, CommitteeCode, CommitteeName FROM Committee WHERE CommitteeCode IN ('A901', 'ZZB1C') AND (CommitteeName LIKE 'ZZ A1b%' OR EXISTS (SELECT 1 FROM Committee_Member tcm JOIN Member tm ON tm.MemberId = tcm.MemberId WHERE tcm.CommitteeId = Committee.CommitteeId AND tm.MemberCode IN ('A902', 'ZZB1M') AND tm.MemberName LIKE 'ZZ A1b%'))
UNION ALL SELECT 'Users', UserId, LoginName, UserName FROM Users WHERE LoginName = 'zza1b';

SELECT MemberId, MemberCode, MemberName, Address1, DOJ, DesignationId FROM Member WHERE MemberCode IN ('A902', 'ZZB1M') AND MemberName LIKE 'ZZ A1b%';

SELECT mt.MeetingId, mt.MeetingNo, mt.MeetingDate, mt.MeetingTime, mt.Place, mt.Venue, mt.AgendaStatus, mt.MinutesStatus
FROM Meeting mt
JOIN Committee c ON c.CommitteeId = mt.CommitteeId
WHERE c.CommitteeCode IN ('A901', 'ZZB1C') AND (c.CommitteeName LIKE 'ZZ A1b%' OR EXISTS (SELECT 1 FROM Committee_Member tcm JOIN Member tm ON tm.MemberId = tcm.MemberId WHERE tcm.CommitteeId = c.CommitteeId AND tm.MemberCode IN ('A902', 'ZZB1M') AND tm.MemberName LIKE 'ZZ A1b%'))
ORDER BY mt.MeetingId;

SELECT 'Committee_Member' AS RowType, cm.CommitteeMemberId AS Id, cm.MemberId, cm.MemberTypeId, NULL AS MeetingId
FROM Committee_Member cm JOIN Committee c ON c.CommitteeId = cm.CommitteeId WHERE c.CommitteeCode IN ('A901', 'ZZB1C') AND (c.CommitteeName LIKE 'ZZ A1b%' OR EXISTS (SELECT 1 FROM Committee_Member tcm JOIN Member tm ON tm.MemberId = tcm.MemberId WHERE tcm.CommitteeId = c.CommitteeId AND tm.MemberCode IN ('A902', 'ZZB1M') AND tm.MemberName LIKE 'ZZ A1b%'))
UNION ALL
SELECT 'Meeting_Member', mm.MeetingMemberId, mm.MemberId, mm.MemberTypeId, mm.MeetingId
FROM Meeting_Member mm JOIN Meeting mt ON mt.MeetingId = mm.MeetingId JOIN Committee c ON c.CommitteeId = mt.CommitteeId WHERE c.CommitteeCode IN ('A901', 'ZZB1C') AND (c.CommitteeName LIKE 'ZZ A1b%' OR EXISTS (SELECT 1 FROM Committee_Member tcm JOIN Member tm ON tm.MemberId = tcm.MemberId WHERE tcm.CommitteeId = c.CommitteeId AND tm.MemberCode IN ('A902', 'ZZB1M') AND tm.MemberName LIKE 'ZZ A1b%'))
UNION ALL
SELECT 'Attendance', NULL, a.MemberId, NULL, a.MeetingId
FROM Attendance a JOIN Committee c ON c.CommitteeId = a.CommitteeId WHERE c.CommitteeCode IN ('A901', 'ZZB1C') AND (c.CommitteeName LIKE 'ZZ A1b%' OR EXISTS (SELECT 1 FROM Committee_Member tcm JOIN Member tm ON tm.MemberId = tcm.MemberId WHERE tcm.CommitteeId = c.CommitteeId AND tm.MemberCode IN ('A902', 'ZZB1M') AND tm.MemberName LIKE 'ZZ A1b%'));

SELECT Audit_Type, Audit_Table, Key_Field, Key_Value, Field_Name, Old_Value, New_Value, Update_By, Update_On
FROM Audit_Trail_Master WHERE Audit_Table = 'ZZA1b';

SELECT Backup_File_Name, User_Id, User_IP_Address, Server_Url, Backup_Date_Time
FROM Audit_Trail_SqlBackup WHERE Backup_File_Name LIKE 'ZZ A1b%';

SELECT am.AlertId, am.SourceType, am.SourceTypeId, am.DisplayText, am.AlertTypeCode, am.CommitteeId
FROM Alert_Master am
JOIN Committee c ON c.CommitteeId = am.CommitteeId
WHERE c.CommitteeCode IN ('A901', 'ZZB1C') AND (c.CommitteeName LIKE 'ZZ A1b%' OR EXISTS (SELECT 1 FROM Committee_Member tcm JOIN Member tm ON tm.MemberId = tcm.MemberId WHERE tcm.CommitteeId = c.CommitteeId AND tm.MemberCode IN ('A902', 'ZZB1M') AND tm.MemberName LIKE 'ZZ A1b%'))
ORDER BY am.AlertId;
GO


/* ============================================================================
   PART 3 - cleanup by the test codes
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @DeptId INT       = (SELECT DepartmentId   FROM Department    WHERE DepartmentCode   = 'ZZB1D');
DECLARE @DesigId INT      = (SELECT DesignationId  FROM Designation   WHERE DesignationCode  = 'ZZB1G');
DECLARE @DecisionId INT   = (SELECT DecisionTypeId FROM Decision_Type WHERE DecisionTypeCode = 'ZZB1T');
DECLARE @SubjectId INT    = (SELECT SubjectTypeId  FROM Subject_Type  WHERE SubjectTypeCode  = 'ZZB1S');
DECLARE @MemberTypeId INT = (SELECT MemberTypeId   FROM Member_Type   WHERE MemberTypeCode   = 'ZZB1Y');
DECLARE @MemberId INT     = (SELECT MemberId       FROM Member        WHERE MemberCode IN ('A902', 'ZZB1M') AND MemberName LIKE 'ZZ A1b%');
-- The committee name can be edited on screen: a test code and either the test name or the tagged test member
DECLARE @CommitteeId INT  = (SELECT TOP 1 c.CommitteeId FROM Committee c
                             WHERE c.CommitteeCode IN ('A901', 'ZZB1C')
                               AND (c.CommitteeName LIKE 'ZZ A1b%'
                                    OR EXISTS (SELECT 1 FROM Committee_Member cm WHERE cm.CommitteeId = c.CommitteeId AND cm.MemberId = @MemberId))
                             ORDER BY c.CommitteeId);
DECLARE @TestUserId INT   = (SELECT UserId         FROM Users         WHERE LoginName        = 'zza1b');

-- The test member tagged to a committee that is not recognised as a test committee stops the cleanup
DECLARE @UnknownCommittees NVARCHAR(400);
IF (@MemberId IS NOT NULL AND @CommitteeId IS NULL)
    SELECT @UnknownCommittees = STUFF((SELECT N', ' + CAST(cm.CommitteeId AS NVARCHAR(12))
                                       FROM Committee_Member cm WHERE cm.MemberId = @MemberId
                                       ORDER BY cm.CommitteeId FOR XML PATH('')), 1, 2, N'');
IF (@UnknownCommittees IS NOT NULL)
BEGIN
    RAISERROR('The test member is tagged to committee(s) %s that part 3 does not recognise as test committees. Nothing was changed.', 16, 1, @UnknownCommittees);
    RETURN;
END

DECLARE @Meetings TABLE (MeetingId INT PRIMARY KEY);
INSERT INTO @Meetings (MeetingId) SELECT MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo IN ('1', '2');

-- Anything else that uses the test rows stops the cleanup
DECLARE @OtherMeetings INT, @Agendas INT, @OtherCommittees INT, @OtherMeetingMembers INT, @OtherAttendance INT,
        @TypeInUse INT, @DeptInUse INT, @DesigInUse INT, @Managed INT;

SELECT @OtherMeetings = COUNT(*) FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings);
SELECT @Agendas = COUNT(*) FROM Agenda WHERE CommitteeId = @CommitteeId OR MeetingId IN (SELECT MeetingId FROM @Meetings);
SELECT @OtherCommittees = COUNT(*) FROM Committee_Member WHERE MemberId = @MemberId AND CommitteeId <> @CommitteeId;
SELECT @OtherMeetingMembers = COUNT(*) FROM Meeting_Member WHERE MemberId = @MemberId AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings);
SELECT @OtherAttendance = COUNT(*) FROM Attendance WHERE MemberId = @MemberId AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings);
SET @TypeInUse =
      (SELECT COUNT(*) FROM Committee_Member WHERE MemberTypeId = @MemberTypeId AND CommitteeId <> @CommitteeId)
    + (SELECT COUNT(*) FROM Meeting_Member   WHERE MemberTypeId = @MemberTypeId AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings))
    + (SELECT COUNT(*) FROM Minutes WHERE DecisionTypeId = @DecisionId)
    + (SELECT COUNT(*) FROM Agenda  WHERE SubjectTypeId  = @SubjectId);
SET @DeptInUse =
      (SELECT COUNT(*) FROM Users  WHERE DepartmentId = @DeptId AND UserId <> ISNULL(@TestUserId, 0))
    + (SELECT COUNT(*) FROM Agenda WHERE DepartmentId = @DeptId)
    + (SELECT COUNT(*) FROM Alert_Master WHERE DepartmentId = @DeptId AND ISNULL(CommitteeId, 0) <> ISNULL(@CommitteeId, 0));
SET @DesigInUse =
      (SELECT COUNT(*) FROM Users  WHERE DesignationId = @DesigId AND UserId <> ISNULL(@TestUserId, 0))
    + (SELECT COUNT(*) FROM Member WHERE DesignationId = @DesigId AND MemberId <> ISNULL(@MemberId, 0));
SELECT @Managed = COUNT(*) FROM Users WHERE ManagerId = @TestUserId;

IF (@OtherMeetings + @Agendas + @OtherCommittees + @OtherMeetingMembers + @OtherAttendance + @TypeInUse + @DeptInUse + @DesigInUse + @Managed > 0)
BEGIN
    RAISERROR('Other rows use the test rows; this cleanup does not delete them. Other meetings of the committee %d, agenda items %d, other committees of the member %d, other meeting memberships %d, other attendance %d, types in use %d, department in use %d, designation in use %d, users managed by the test user %d. Remove them on screen first. Nothing was changed.', 16, 1,
              @OtherMeetings, @Agendas, @OtherCommittees, @OtherMeetingMembers, @OtherAttendance, @TypeInUse, @DeptInUse, @DesigInUse, @Managed);
    RETURN;
END

DECLARE @MapRows INT, @AlertRows INT, @AttendanceRows INT, @MeetingMemberRows INT, @MeetingRows INT, @CommitteeMemberRows INT,
        @CommitteeRows INT, @MemberRows INT, @AuditRows INT, @BackupRows INT, @UserRows INT, @TypeRows INT;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Alerts written by browser saves of the test committee and meetings (also those of a meeting deleted on screen)
    DELETE m
    FROM Alert_User_Map m
    JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.CommitteeId = @CommitteeId
       OR (am.SourceType = 'Committee' AND am.SourceTypeId = @CommitteeId)
       OR (am.SourceType = 'Meeting' AND am.SourceTypeId IN (SELECT MeetingId FROM @Meetings));
    SET @MapRows = @@ROWCOUNT;

    DELETE FROM Alert_Master
    WHERE CommitteeId = @CommitteeId
       OR (SourceType = 'Committee' AND SourceTypeId = @CommitteeId)
       OR (SourceType = 'Meeting' AND SourceTypeId IN (SELECT MeetingId FROM @Meetings));
    SET @AlertRows = @@ROWCOUNT;

    DELETE FROM Attendance WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @AttendanceRows = @@ROWCOUNT;

    DELETE FROM Meeting_Member WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @MeetingMemberRows = @@ROWCOUNT;

    DELETE FROM Meeting WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @MeetingRows = @@ROWCOUNT;

    DELETE FROM Committee_Member WHERE CommitteeId = @CommitteeId;
    SET @CommitteeMemberRows = @@ROWCOUNT;

    DELETE FROM Committee WHERE CommitteeId = @CommitteeId;
    SET @CommitteeRows = @@ROWCOUNT;

    DELETE FROM Member WHERE MemberId = @MemberId;
    SET @MemberRows = @@ROWCOUNT;

    DELETE FROM Audit_Trail_Master WHERE Audit_Table = 'ZZA1b';
    SET @AuditRows = @@ROWCOUNT;

    DELETE FROM Audit_Trail_SqlBackup WHERE Backup_File_Name LIKE 'ZZ A1b%';
    SET @BackupRows = @@ROWCOUNT;

    DELETE FROM Users WHERE UserId = @TestUserId AND IsSystem = 0;
    SET @UserRows = @@ROWCOUNT;

    DELETE FROM Member_Type WHERE MemberTypeId = @MemberTypeId;
    SET @TypeRows = @@ROWCOUNT;
    DELETE FROM Subject_Type WHERE SubjectTypeId = @SubjectId;
    SET @TypeRows = @TypeRows + @@ROWCOUNT;
    DELETE FROM Decision_Type WHERE DecisionTypeId = @DecisionId;
    SET @TypeRows = @TypeRows + @@ROWCOUNT;
    DELETE FROM Designation WHERE DesignationId = @DesigId;
    SET @TypeRows = @TypeRows + @@ROWCOUNT;
    DELETE FROM Department WHERE DepartmentId = @DeptId;
    SET @TypeRows = @TypeRows + @@ROWCOUNT;

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
SET @Line = N'Deleted ' + CAST(@MapRows AS NVARCHAR(12)) + N' Alert_User_Map, ' + CAST(@AlertRows AS NVARCHAR(12)) + N' Alert_Master, '
          + CAST(@AttendanceRows AS NVARCHAR(12)) + N' Attendance, ' + CAST(@MeetingMemberRows AS NVARCHAR(12)) + N' Meeting_Member, '
          + CAST(@MeetingRows AS NVARCHAR(12)) + N' Meeting, ' + CAST(@CommitteeMemberRows AS NVARCHAR(12)) + N' Committee_Member row(s).';
PRINT @Line;
SET @Line = N'Deleted ' + CAST(@CommitteeRows AS NVARCHAR(12)) + N' Committee, ' + CAST(@MemberRows AS NVARCHAR(12)) + N' Member, '
          + CAST(@AuditRows AS NVARCHAR(12)) + N' Audit_Trail_Master, ' + CAST(@BackupRows AS NVARCHAR(12)) + N' Audit_Trail_SqlBackup, '
          + CAST(@UserRows AS NVARCHAR(12)) + N' Users and ' + CAST(@TypeRows AS NVARCHAR(12)) + N' type, department and designation row(s).';
PRINT @Line;
PRINT N'Expected when nothing was deleted on screen: alerts 0 or more, 1 Attendance, 1 Meeting_Member, 2 Meeting, 1 Committee_Member, 1 Committee, 1 Member, 1 audit, 1 backup, 1 user, 5 type rows.';
GO
