/* ============================================================================
   BMMS - Test of step 55 (step IU1, inactive users and the Admin role in
   mails, action items and Reset Password)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY in a test copy whose name starts with "BMMS" and is not "BMMS"
   (BMMS_Test). It has no USE line: select BMMS_Test in SSMS first. Needs step
   55 installed. Written for compatibility level 100. The file is plain ASCII.
   Run the whole file (F5); it can run twice in one window.

   Part 1 reads only: the marker InactiveUsers-Step55 in the six objects, the
   markers of the earlier steps in the three replaced texts, the parameters
   (spr_GetResetPasswordMail takes no address), no feature above
   compatibility level 100 in the new objects, and fn_FunctionalUsers over the
   whole database equal to the filter of step 53 (active, not the system
   account, not the Admin role).

   Part 2 runs in ONE transaction that is ROLLED BACK, with made-up data ZZ55:
   a department; a Controller who saves (C), a second Controller, an Admin
   (A), an inactive Admin, an MD Secretariat user, a User (U), a User without
   an address, an inactive User (creator of an agenda item), an inactive
   Manager; the protected system account of the database. Checked:
     R1  Committee Save (CC) and Update (CU), Meeting Save (MC) and Update
         (MU): the alert rows equal the step 53 filter on the same data (both
         directions: no behaviour change), none for C, the Admins, the
         inactive users and the system account; spr_GetMeetingCommitteeMailId
         for C equals the addresses of those alert users that have one (both
         directions), never C's address; for the Admin A the same rule
         without A; refused for an inactive acting user (8) and for MD
         Secretariat (4), with no rows
     R2  minutes finalisation: the rows of every action item of the meeting
         equal fn_FunctionalUsers (both directions); none for the Admins, the
         inactive users and the system account; a user made active after the
         finalisation gets no row (a second finalisation is refused, Reason
         3); the late action item of an inactive creator still goes to the
         active Controllers (spr_UpdateMinutes, unchanged)
     R3  rows saved before the finalisation for the Admin and an inactive
         user are kept
     R4  spr_ResetPasswordByUserId resets an inactive user for the Admin;
         refused for an inactive Admin (8) and the Controller (4);
         spr_GetResetPasswordMail returns the stored address and the status
         (also after the address is changed in Users: the address can only
         come from the database), refusals 8, 4, 7 and 4 (no such user) with
         no row
   Afterwards: Users, Committee, Meeting, Agenda, Minutes, Action_Item,
   Alert_User_Map and ActionItem_User_Map as before, no ZZ55 row left, every
   identity counter put back.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase = 'BMMS' OR @CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This test is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_FunctionalUsers', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') NOT LIKE '%InactiveUsers-Step55%')
BEGIN
    RAISERROR('Step 55 (BMMS-Fix-InactiveUsers-Step55.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(400), Expected VARCHAR(400), Actual VARCHAR(400));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-------------------------------------------------------------------------------
-- Part 1: reads only
-------------------------------------------------------------------------------
INSERT INTO #T (Test, Expected, Actual)
SELECT 'The marker InactiveUsers-Step55 in the six objects', '6',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_FunctionalUsers'), ('spr_GetMeetingCommitteeMailId'), ('spr_GetResetPasswordMail'),
                                          ('spr_AddEditMeeting'), ('spr_AddEditCommittee'), ('spr_MinutesFinalizeByMeetingId')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%InactiveUsers-Step55%') AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'The replaced texts keep the markers of their earlier steps (and the step 8 text that the older tests read)', '13',
       CAST((SELECT COUNT(*) FROM (VALUES
            ('spr_AddEditMeeting', '%MeetingLocks-Step16%'), ('spr_AddEditMeeting', '%UserStatus2b-Step17%'),
            ('spr_AddEditMeeting', '%SystemAccount3-Step18%'), ('spr_AddEditMeeting', '%MeetingDates-Step24%'),
            ('spr_AddEditMeeting', '%DepartmentApprovers-Step53%'),
            ('spr_AddEditCommittee', '%UserStatus2b-Step17%'), ('spr_AddEditCommittee', '%SystemAccount3-Step18%'),
            ('spr_AddEditCommittee', '%DepartmentApprovers-Step53%'),
            ('spr_MinutesFinalizeByMeetingId', '%MeetingLocks-Step15%'), ('spr_MinutesFinalizeByMeetingId', '%UserStatus2b-Step17%'),
            ('spr_MinutesFinalizeByMeetingId', '%SystemAccount3-Step18%'), ('spr_MinutesFinalizeByMeetingId', '%WorkflowOrder-Step23%'),
            ('spr_MinutesFinalizeByMeetingId', '%NOT EXISTS (SELECT 1 FROM ActionItem[_]User[_]Map x%')) m(Name, Marker)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + m.Name)), '') LIKE m.Marker) AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'Parameters: spr_AddEditMeeting, spr_AddEditCommittee, spr_MinutesFinalizeByMeetingId, fn_FunctionalUsers', '14 14 2 0',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditMeeting')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditCommittee')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_FunctionalUsers') AND parameter_id > 0) AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'Parameters of spr_GetMeetingCommitteeMailId (no recipient comes from the caller)', '@ActingUserId,@Reason OUT',
       ISNULL(STUFF((SELECT ',' + p.name + CASE WHEN p.is_output = 1 THEN ' OUT' ELSE '' END FROM sys.parameters p
                     WHERE p.object_id = OBJECT_ID('dbo.spr_GetMeetingCommitteeMailId') ORDER BY p.parameter_id
                     FOR XML PATH('')), 1, 1, ''), 'none');

INSERT INTO #T (Test, Expected, Actual)
SELECT 'G3: parameters of spr_GetResetPasswordMail: no address can be passed from the page', '@ActingUserId,@UserId,@Reason OUT',
       ISNULL(STUFF((SELECT ',' + p.name + CASE WHEN p.is_output = 1 THEN ' OUT' ELSE '' END FROM sys.parameters p
                     WHERE p.object_id = OBJECT_ID('dbo.spr_GetResetPasswordMail') ORDER BY p.parameter_id
                     FOR XML PATH('')), 1, 1, ''), 'none');

INSERT INTO #T (Test, Expected, Actual)
SELECT 'No THROW, TRY_CONVERT, IIF, CONCAT, FORMAT or OFFSET in the three new objects', '0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_FunctionalUsers'), ('spr_GetMeetingCommitteeMailId'), ('spr_GetResetPasswordMail')) o(Name)
             CROSS JOIN (VALUES ('%THROW%'), ('%TRY[_]CONVERT%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('%OFFSET %')) f(Pattern)
             WHERE UPPER(ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '')) LIKE f.Pattern) AS VARCHAR(12));

INSERT INTO #T (Test, Expected, Actual)
SELECT 'fn_FunctionalUsers over the whole database = the step 53 filter (not in the filter / not in the function)', '0 0',
       CAST((SELECT COUNT(*) FROM dbo.fn_FunctionalUsers() fu
             WHERE NOT EXISTS (SELECT 1 FROM Users u WHERE u.UserId = fu.UserId AND u.AccountStatus = 1 AND u.IsSystem = 0
                               AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = u.RoleId AND ar.RoleCode = 'admin'))) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users u WHERE u.AccountStatus = 1 AND u.IsSystem = 0
             AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = u.RoleId AND ar.RoleCode = 'admin')
             AND NOT EXISTS (SELECT 1 FROM dbo.fn_FunctionalUsers() fu WHERE fu.UserId = u.UserId)) AS VARCHAR(12));
GO

-------------------------------------------------------------------------------
-- Part 2: made-up data ZZ55 in one transaction, rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(400), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @Mail TABLE (EmailId VARCHAR(250));
DECLARE @Reset TABLE (EmailId VARCHAR(250), IsActive INT);
DECLARE @Ev TABLE (Code VARCHAR(4), AlertId INT);
DECLARE @Now DATETIME = GETDATE();
DECLARE @Today DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @rMds INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect');
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @OtherDecision INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);
DECLARE @Dept INT, @Ctl INT, @Ctl2 INT, @Adm INT, @Adm0 INT, @Mds INT, @Usr INT, @UsrNoMail INT, @Usr0 INT, @Mgr0 INT;
DECLARE @C INT, @Mt INT, @MtF INT, @Ag1 INT, @Ag2 INT, @Ag3 INT, @Min1 INT, @Min2 INT, @Min3 INT, @AI1 INT, @AI2 INT, @AI3 INT;
DECLARE @Rsn INT, @Code VARCHAR(4), @A INT, @Res INT;
DECLARE @UsersBefore VARCHAR(40), @UsersAfter VARCHAR(40), @MapBefore VARCHAR(40), @MapAfter VARCHAR(40);
DECLARE @AiMapBefore VARCHAR(40), @AiMapAfter VARCHAR(40), @DataBefore VARCHAR(80), @DataAfter VARCHAR(80);

SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, AccountStatus, RoleId, EmailId, [Password])), 0) AS VARCHAR(12)) FROM Users;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
SELECT @AiMapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;
SET @DataBefore = CAST((SELECT COUNT(*) FROM Committee) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM Meeting) AS VARCHAR(12)) + ' '
                + CAST((SELECT COUNT(*) FROM Agenda) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM Minutes) AS VARCHAR(12)) + ' '
                + CAST((SELECT COUNT(*) FROM Action_Item) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM Alert_Master) AS VARCHAR(12));

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMds IS NULL
    OR @Desig IS NULL OR @SubjectTypeId IS NULL OR @OtherDecision IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, a subject type or a decision type other than Followup is missing', 'PASS', 'SKIPPED');
END
ELSE
BEGIN
BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ55', 'ZZ step 55 department', 998, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 controller', @Dept, @Desig, NULL, @rCtl, 'zz55ctl@example.invalid', 'zz55ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 controller two', @Dept, @Desig, NULL, @rCtl, 'zz55ctl2@example.invalid', 'zz55ctl2', 'not-a-login', 1, @Now);
    SET @Ctl2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 admin', @Dept, @Desig, NULL, @rAdmin, 'zz55adm@example.invalid', 'zz55adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 admin inactive', @Dept, @Desig, NULL, @rAdmin, 'zz55adm0@example.invalid', 'zz55adm0', 'not-a-login', 0, @Now);
    SET @Adm0 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 md secretariat', @Dept, @Desig, NULL, @rMds, 'zz55mds@example.invalid', 'zz55mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 user', @Dept, @Desig, NULL, @rUser, 'zz55usr@example.invalid', 'zz55usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 user without address', @Dept, @Desig, NULL, @rUser, '', 'zz55nomail', 'not-a-login', 1, @Now);
    SET @UsrNoMail = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 user inactive', @Dept, @Desig, NULL, @rUser, 'zz55usr0@example.invalid', 'zz55usr0', 'not-a-login', 0, @Now);
    SET @Usr0 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ55 manager inactive', @Dept, @Desig, NULL, @rMgr, 'zz55mgr0@example.invalid', 'zz55mgr0', 'not-a-login', 0, @Now);
    SET @Mgr0 = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- R1: Committee CC / CU and Meeting MC / MU
    ---------------------------------------------------------------------------
    EXEC spr_AddEditCommittee @Code = 'Save', @CommitteeId = 0, @CommitteeCode = 'Z55', @CommitteeName = 'ZZ step 55 committee', @Board = 0,
         @IncorporationDate = @Today, @MeetingStartNo = 1, @CommitteeColorCode = '', @CessationDate = '', @StatusId = 1,
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SET @C = (SELECT CommitteeId FROM Committee WHERE CommitteeCode = 'Z55');
    INSERT INTO @Ev SELECT 'CC', MAX(AlertId) FROM Alert_Master WHERE AlertTypeCode = 'CC' AND SourceTypeId = @C;

    EXEC spr_AddEditCommittee @Code = 'Update', @CommitteeId = @C, @CommitteeCode = 'Z55', @CommitteeName = 'ZZ step 55 committee (u)', @Board = 0,
         @IncorporationDate = @Today, @MeetingStartNo = 1, @CommitteeColorCode = '', @CessationDate = '', @StatusId = 1,
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @Ev SELECT 'CU', MAX(AlertId) FROM Alert_Master WHERE AlertTypeCode = 'CU' AND SourceTypeId = @C;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99551', @CommitteeId = @C, @Place = 'ZZ55 test', @Venue = 'ZZ',
         @MeetingDate = @Today, @MeetingTime = '10:00', @AgendaSubmissionDate = @Today, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    SET @Mt = (SELECT MeetingId FROM Meeting WHERE CommitteeId = @C AND MeetingNo = '99551');
    INSERT INTO @T SELECT 'Meeting Save by the Controller: saved', 'Result 1, Reason 0',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R), 'none');
    INSERT INTO @Ev SELECT 'MC', MAX(AlertId) FROM Alert_Master WHERE AlertTypeCode = 'MC' AND SourceTypeId = @Mt;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @Mt, @MeetingNo = '99551', @CommitteeId = @C, @Place = 'ZZ55 test', @Venue = 'ZZ (u)',
         @MeetingDate = @Today, @MeetingTime = '11:00', @AgendaSubmissionDate = @Today, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Meeting Update by the Controller: saved', 'Result 1, Reason 0',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R), 'none');
    INSERT INTO @Ev SELECT 'MU', MAX(AlertId) FROM Alert_Master WHERE AlertTypeCode = 'MU' AND SourceTypeId = @Mt;

    -- The mail list for the Controller who saved
    DELETE FROM @Mail; SET @Rsn = NULL;
    INSERT INTO @Mail EXEC spr_GetMeetingCommitteeMailId @ActingUserId = @Ctl, @Reason = @Rsn OUTPUT;

    SET @Code = (SELECT MIN(Code) FROM @Ev);
    WHILE (@Code IS NOT NULL)
    BEGIN
        SET @A = (SELECT AlertId FROM @Ev WHERE Code = @Code);

        INSERT INTO @T SELECT @Code + ': the alert rows = the step 53 filter on the same data (rows not in the filter / filter not in rows)', '0 0',
               CAST((SELECT COUNT(*) FROM Alert_User_Map m WHERE m.AlertId = @A
                     AND NOT EXISTS (SELECT 1 FROM Users u WHERE u.UserId = m.UserId AND u.UserId <> @Ctl AND u.AccountStatus = 1 AND u.IsSystem = 0
                                     AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = u.RoleId AND ar.RoleCode = 'admin'))) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Users u WHERE u.UserId <> @Ctl AND u.AccountStatus = 1 AND u.IsSystem = 0
                     AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = u.RoleId AND ar.RoleCode = 'admin')
                     AND NOT EXISTS (SELECT 1 FROM Alert_User_Map m WHERE m.AlertId = @A AND m.UserId = u.UserId)) AS VARCHAR(12));

        INSERT INTO @T SELECT @Code + ': rows of the saver, Admin, inactive Admin, inactive User, inactive Manager, system account / User, User without address, Controller two, MD Secretariat',
               '0 0 0 0 0 0 / 1 1 1 1',
               CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Ctl) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Adm) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Adm0) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Usr0) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Mgr0) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Sys) AS VARCHAR(12)) + ' / '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Usr) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @UsrNoMail) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Ctl2) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @A AND UserId = @Mds) AS VARCHAR(12));

        INSERT INTO @T SELECT @Code + ': the mail list = the addresses of the alert users that have one, minus the saver (mail not in alert / alert not in mail / rows, users)', '0 0 same',
               CAST((SELECT COUNT(*) FROM @Mail ml
                     WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId
                                       WHERE m.AlertId = @A AND u.EmailId = ml.EmailId)) AS VARCHAR(12)) + ' '
             + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId
                     WHERE m.AlertId = @A AND LTRIM(RTRIM(ISNULL(u.EmailId, ''))) <> ''
                     AND NOT EXISTS (SELECT 1 FROM @Mail ml WHERE ml.EmailId = u.EmailId)) AS VARCHAR(12)) + ' '
             + CASE WHEN (SELECT COUNT(*) FROM @Mail)
                         = (SELECT COUNT(*) FROM Alert_User_Map m JOIN Users u ON u.UserId = m.UserId
                            WHERE m.AlertId = @A AND LTRIM(RTRIM(ISNULL(u.EmailId, ''))) <> '') THEN 'same' ELSE 'DIFFERENT' END;

        SET @Code = (SELECT MIN(Code) FROM @Ev WHERE Code > @Code);
    END

    INSERT INTO @T SELECT 'Mail list for the Controller: Reason 0; the saver, the Admin, the inactive users, the system account not in it; the User and Controller two in it',
           '0; 0 0 0 0 0; 1 1',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + '; '
         + CAST((SELECT COUNT(*) FROM @Mail WHERE EmailId = 'zz55ctl@example.invalid') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @Mail WHERE EmailId = 'zz55adm@example.invalid') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @Mail WHERE EmailId IN ('zz55adm0@example.invalid', 'zz55usr0@example.invalid')) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @Mail WHERE EmailId = 'zz55mgr0@example.invalid') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @Mail ml JOIN Users u ON u.EmailId = ml.EmailId WHERE u.UserId = @Sys) AS VARCHAR(12)) + '; '
         + CAST((SELECT COUNT(*) FROM @Mail WHERE EmailId = 'zz55usr@example.invalid') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM @Mail WHERE EmailId = 'zz55ctl2@example.invalid') AS VARCHAR(12));

    INSERT INTO @T SELECT 'Mail list: no blank address', '0',
           CAST((SELECT COUNT(*) FROM @Mail WHERE LTRIM(RTRIM(ISNULL(EmailId, ''))) = '') AS VARCHAR(12));

    -- An Admin saves: the same rule, without the Admin
    DELETE FROM @Mail; SET @Rsn = NULL;
    INSERT INTO @Mail EXEC spr_GetMeetingCommitteeMailId @ActingUserId = @Adm, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Mail list for the Admin: Reason 0; = fn_FunctionalUsers with an address (both directions); the Controller in it', '0; 0 0; 1',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + '; '
         + CAST((SELECT COUNT(*) FROM @Mail ml WHERE NOT EXISTS (SELECT 1 FROM dbo.fn_FunctionalUsers() fu WHERE fu.EmailId = ml.EmailId AND fu.UserId <> @Adm)) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_FunctionalUsers() fu WHERE fu.UserId <> @Adm AND LTRIM(RTRIM(ISNULL(fu.EmailId, ''))) <> ''
                 AND NOT EXISTS (SELECT 1 FROM @Mail ml WHERE ml.EmailId = fu.EmailId)) AS VARCHAR(12)) + '; '
         + CAST((SELECT COUNT(*) FROM @Mail WHERE EmailId = 'zz55ctl@example.invalid') AS VARCHAR(12));

    DELETE FROM @Mail; SET @Rsn = NULL;
    INSERT INTO @Mail EXEC spr_GetMeetingCommitteeMailId @ActingUserId = @Adm0, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Mail list for an inactive acting user: Reason 8, no rows', '8 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + ' ' + CAST((SELECT COUNT(*) FROM @Mail) AS VARCHAR(12));

    DELETE FROM @Mail; SET @Rsn = NULL;
    INSERT INTO @Mail EXEC spr_GetMeetingCommitteeMailId @ActingUserId = @Mds, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Mail list for MD Secretariat (not a role of the two pages): Reason 4, no rows', '4 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + ' ' + CAST((SELECT COUNT(*) FROM @Mail) AS VARCHAR(12));

    DELETE FROM @Mail; SET @Rsn = NULL;
    INSERT INTO @Mail EXEC spr_GetMeetingCommitteeMailId @ActingUserId = NULL, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Mail list without an acting user: Reason 8, no rows', '8 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + ' ' + CAST((SELECT COUNT(*) FROM @Mail) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- R2 / R3: minutes finalisation; the late action item
    ---------------------------------------------------------------------------
    -- A meeting from before step 23 (no CreatedOn: the workflow order does not apply), agenda closed, minutes open
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99552', @C, 'ZZ55 test', 'ZZ', @Today, '10:00', @Today, 'Close', 'Open');
    SET @MtF = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z55-99552-001', @C, @MtF, @Dept, @SubjectTypeId, N'ZZ55 F1', 'Entry', N'ZZ', N'ZZ', 'Approved', @Now, @Usr);
    SET @Ag1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z55-99552-002', @C, @MtF, @Dept, @SubjectTypeId, N'ZZ55 F2', 'Entry', N'ZZ', N'ZZ', 'Approved', @Now, @Usr);
    SET @Ag2 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z55-99552-003', @C, @MtF, @Dept, @SubjectTypeId, N'ZZ55 F3', 'Entry', N'ZZ', N'ZZ', 'Approved', @Now, @Usr0);
    SET @Ag3 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@Ag1, 1, N'ZZ', N'ZZ', @Now, @Ctl, @Now, @Ctl);
    SET @Min1 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@Ag2, 1, N'ZZ', N'ZZ', @Now, @Ctl, @Now, @Ctl);
    SET @Min2 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@Ag3, @OtherDecision, N'ZZ', N'ZZ', @Now, @Ctl, @Now, @Ctl);
    SET @Min3 = SCOPE_IDENTITY();

    -- R3: an action item saved before, with rows of the Admin and of the inactive User (as written before step 55)
    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy) VALUES (@Min1, N'ZZ', N'', 'Pending', @Now, @Ctl);
    SET @AI1 = SCOPE_IDENTITY();
    INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId) VALUES (@AI1, @Adm, 0, 1);
    INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId) VALUES (@AI1, @Usr0, 0, 1);

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MtF, @UserId = @Ctl;
    SET @AI2 = (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @Min2);
    INSERT INTO @T SELECT 'Minutes finalisation: done; the follow-up minute without an item got one', 'Result 1, Reason 0; 1',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Action_Item WHERE MinutesId = @Min2) AS VARCHAR(12));

    INSERT INTO @T SELECT 'R2: the rows of the new item = fn_FunctionalUsers (rows not in it / it not in rows)', '0 0',
           CAST((SELECT COUNT(*) FROM ActionItem_User_Map m WHERE m.ActionItemId = @AI2
                 AND NOT EXISTS (SELECT 1 FROM dbo.fn_FunctionalUsers() fu WHERE fu.UserId = m.UserId)) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM dbo.fn_FunctionalUsers() fu
                 WHERE NOT EXISTS (SELECT 1 FROM ActionItem_User_Map m WHERE m.ActionItemId = @AI2 AND m.UserId = fu.UserId)) AS VARCHAR(12));

    INSERT INTO @T SELECT 'R2: the item saved before got the rows of fn_FunctionalUsers it lacked (it not in rows)', '0',
           CAST((SELECT COUNT(*) FROM dbo.fn_FunctionalUsers() fu
                 WHERE NOT EXISTS (SELECT 1 FROM ActionItem_User_Map m WHERE m.ActionItemId = @AI1 AND m.UserId = fu.UserId)) AS VARCHAR(12));

    INSERT INTO @T SELECT 'R2: new item: rows of the Admin, inactive Admin, inactive User, inactive Manager, system account / Controller, User, MD Secretariat',
           '0 0 0 0 0 / 1 1 1',
           CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Adm) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Adm0) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Usr0) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Mgr0) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Sys) AS VARCHAR(12)) + ' / '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Ctl) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Usr) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Mds) AS VARCHAR(12));

    INSERT INTO @T SELECT 'R3: the rows saved before for the Admin and the inactive User are kept (one each)', '1 1',
           CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI1 AND UserId = @Adm) AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI1 AND UserId = @Usr0) AS VARCHAR(12));

    -- No back-fill: the inactive User is made active; a second finalisation is refused and adds nothing
    UPDATE Users SET AccountStatus = 1 WHERE UserId = @Usr0;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MtF, @UserId = @Ctl;
    INSERT INTO @T SELECT 'R2: a user made active later: finalisation again refused (Reason 3), still no row on the new item', 'Result 0, Reason 3; 0',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI2 AND UserId = @Usr0) AS VARCHAR(12));
    UPDATE Users SET AccountStatus = 0 WHERE UserId = @Usr0;

    -- The late action item: a minute of the inactive User's item becomes a Followup after the finalisation
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail)
    EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Min3, @DecisionTypeId = 1, @Directions = N'ZZ', @ActualResolution = N'ZZ',
         @ShortText = N'ZZ55 F3', @CreatedBy = @Ctl, @UpdatedBy = @Ctl;
    SET @AI3 = (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @Min3);
    INSERT INTO @T SELECT 'Late action item of an inactive creator (unchanged): creator 0; the active Controllers (not the system account) / rows of others',
           'Result 1; 0; same / 0',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) FROM @R), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI3 AND UserId = @Usr0) AS VARCHAR(12)) + '; '
         + CASE WHEN (SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @AI3)
                     = (SELECT COUNT(*) FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0)
                THEN 'same' ELSE 'DIFFERENT' END + ' / '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map m JOIN Users u ON u.UserId = m.UserId JOIN Roles r ON r.RoleId = u.RoleId
                 WHERE m.ActionItemId = @AI3 AND r.RoleCode <> 'controller') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- R4: Reset Password
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_ResetPasswordByUserId @UserId = @Usr0, @Password = 'zz55-reset', @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Reset of an inactive user by the Admin: done, the password changed', 'Result 1, Reason 0; changed',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R), 'none') + '; '
         + CASE WHEN (SELECT [Password] FROM Users WHERE UserId = @Usr0) = 'zz55-reset' THEN 'changed' ELSE 'not changed' END;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_ResetPasswordByUserId @UserId = @Usr, @Password = 'zz55-x', @UpdatedBy = @Adm0;
    INSERT INTO @T SELECT 'Reset by an inactive Admin: refused (8), nothing changed', 'Result 0, Reason 8; not-a-login',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R), 'none') + '; '
         + (SELECT [Password] FROM Users WHERE UserId = @Usr);

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_ResetPasswordByUserId @UserId = @Usr, @Password = 'zz55-x', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Reset of another user by the Controller: refused (4), nothing changed', 'Result 0, Reason 4; not-a-login',
           ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(4)) + ', Reason ' + CAST(Reason AS VARCHAR(4)) FROM @R), 'none') + '; '
         + (SELECT [Password] FROM Users WHERE UserId = @Usr);

    DELETE FROM @Reset; SET @Rsn = NULL;
    INSERT INTO @Reset EXEC spr_GetResetPasswordMail @ActingUserId = @Adm, @UserId = @Usr0, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Reset mail of an inactive user for the Admin: Reason 0; the stored address; inactive', '0; zz55usr0@example.invalid; 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + '; ' + ISNULL((SELECT TOP 1 EmailId FROM @Reset), 'none') + '; '
         + ISNULL((SELECT TOP 1 CAST(IsActive AS VARCHAR(4)) FROM @Reset), '-');

    DELETE FROM @Reset; SET @Rsn = NULL;
    INSERT INTO @Reset EXEC spr_GetResetPasswordMail @ActingUserId = @Adm, @UserId = @Usr, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Reset mail of an active user for the Admin: Reason 0; one row; the stored address; active', '0; 1; zz55usr@example.invalid; 1',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + '; ' + CAST((SELECT COUNT(*) FROM @Reset) AS VARCHAR(12)) + '; '
         + ISNULL((SELECT TOP 1 EmailId FROM @Reset), 'none') + '; ' + ISNULL((SELECT TOP 1 CAST(IsActive AS VARCHAR(4)) FROM @Reset), '-');

    -- G3: the address follows the database, whatever a page held before
    UPDATE Users SET EmailId = 'zz55usr-new@example.invalid' WHERE UserId = @Usr;
    DELETE FROM @Reset; SET @Rsn = NULL;
    INSERT INTO @Reset EXEC spr_GetResetPasswordMail @ActingUserId = @Adm, @UserId = @Usr, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'G3: after the address is changed in Users, the reset mail goes to the new stored address', '0; zz55usr-new@example.invalid',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + '; ' + ISNULL((SELECT TOP 1 EmailId FROM @Reset), 'none');

    DELETE FROM @Reset; SET @Rsn = NULL;
    INSERT INTO @Reset EXEC spr_GetResetPasswordMail @ActingUserId = @Adm0, @UserId = @Usr, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Reset mail for an inactive Admin: Reason 8, no row', '8 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + ' ' + CAST((SELECT COUNT(*) FROM @Reset) AS VARCHAR(12));

    DELETE FROM @Reset; SET @Rsn = NULL;
    INSERT INTO @Reset EXEC spr_GetResetPasswordMail @ActingUserId = @Ctl, @UserId = @Usr, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Reset mail of another user for the Controller: Reason 4, no row', '4 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + ' ' + CAST((SELECT COUNT(*) FROM @Reset) AS VARCHAR(12));

    DELETE FROM @Reset; SET @Rsn = NULL;
    INSERT INTO @Reset EXEC spr_GetResetPasswordMail @ActingUserId = @Adm, @UserId = @Sys, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Reset mail of the protected system account for the Admin: Reason 7, no row', '7 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + ' ' + CAST((SELECT COUNT(*) FROM @Reset) AS VARCHAR(12));

    DELETE FROM @Reset; SET @Rsn = NULL;
    INSERT INTO @Reset EXEC spr_GetResetPasswordMail @ActingUserId = @Adm, @UserId = -1, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Reset mail of a user that does not exist: Reason 4, no row', '4 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + ' ' + CAST((SELECT COUNT(*) FROM @Reset) AS VARCHAR(12));

    DELETE FROM @Reset; SET @Rsn = NULL;
    INSERT INTO @Reset EXEC spr_GetResetPasswordMail @ActingUserId = 0, @UserId = @Usr, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Reset mail without an acting user (0): Reason 8, no row', '8 0',
           ISNULL(CAST(@Rsn AS VARCHAR(4)), '-') + ' ' + CAST((SELECT COUNT(*) FROM @Reset) AS VARCHAR(12));

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    INSERT INTO @T SELECT 'Part 2 ran to its end without an error', 'no error', LEFT('error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + ERROR_MESSAGE(), 400);
END CATCH
END

SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, AccountStatus, RoleId, EmailId, [Password])), 0) AS VARCHAR(12)) FROM Users;
SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
SELECT @AiMapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;
SET @DataAfter = CAST((SELECT COUNT(*) FROM Committee) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM Meeting) AS VARCHAR(12)) + ' '
               + CAST((SELECT COUNT(*) FROM Agenda) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM Minutes) AS VARCHAR(12)) + ' '
               + CAST((SELECT COUNT(*) FROM Action_Item) AS VARCHAR(12)) + ' ' + CAST((SELECT COUNT(*) FROM Alert_Master) AS VARCHAR(12));

INSERT INTO @T SELECT 'After the rollback: Users, Alert_User_Map, ActionItem_User_Map and the counts of Committee, Meeting, Agenda, Minutes, Action_Item, Alert_Master as before',
       'same same same same',
       CASE WHEN @UsersAfter = @UsersBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @MapAfter = @MapBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @AiMapAfter = @AiMapBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN @DataAfter = @DataBefore THEN 'same' ELSE 'DIFFERENT' END;

INSERT INTO #T (Test, Expected, Actual) SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;
GO

-- Every identity counter as before the test (a rolled-back insert still moves it)
DECLARE @TableName SYSNAME, @SavedValue BIGINT, @SeedValue BIGINT, @IncrementValue BIGINT, @Sql NVARCHAR(400);
DECLARE IdentCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName, SavedValue, SeedValue, IncrementValue FROM #Ident;

OPEN IdentCursor;
FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;

WHILE (@@FETCH_STATUS = 0)
BEGIN
    IF (@SavedValue IS NOT NULL
        OR EXISTS (SELECT 1 FROM sys.identity_columns ic
                   WHERE ic.object_id = OBJECT_ID('dbo.' + QUOTENAME(@TableName)) AND ic.last_value IS NOT NULL))
    BEGIN
        SET @Sql = N'DBCC CHECKIDENT (''dbo.' + QUOTENAME(@TableName) + N''', RESEED, '
                 + CAST(ISNULL(@SavedValue, @SeedValue - @IncrementValue) AS NVARCHAR(20)) + N') WITH NO_INFOMSGS';
        EXEC sp_executesql @Sql;
    END

    FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;
END

CLOSE IdentCursor;
DEALLOCATE IdentCursor;

INSERT INTO #T
SELECT 'Identity counters as before the test', '0',
       CAST((SELECT COUNT(*) FROM #Ident i JOIN sys.tables t ON t.name = i.TableName JOIN sys.identity_columns ic ON ic.object_id = t.object_id
             WHERE ISNULL(CAST(ic.last_value AS BIGINT), -1) <> ISNULL(i.SavedValue, -1) AND i.SavedValue IS NOT NULL) AS VARCHAR(12));

INSERT INTO #T
SELECT 'After the test: no ZZ55 department, user, committee, meeting or item left', '0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode = 'ZZ55') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz55%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z55') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ55 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'Z55-%') AS VARCHAR(12));

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM #T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND (Actual <> Expected OR Actual IS NULL) THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM #T;

DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
