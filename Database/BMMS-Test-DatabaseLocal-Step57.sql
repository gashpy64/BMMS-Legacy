/* ============================================================================
   BMMS - Tests for BMMS-Fix-DatabaseLocal-Step57.sql (step 57, step AZ2)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   TEST DATABASE ONLY. Run AFTER BMMS-Fix-DatabaseLocal-Step57.sql, on the
   TEST COPY. It stops if step 57 is not installed, and on a database named
   BMMS. It names no other database, so it also runs on Azure SQL Database.

   Part 1, read only:
     * the marker DatabaseLocal-Step57 in both procedures, and the older
       markers kept (OrganisationSettings-Step19; MemberTypes-Step21 and
       RoleAccess-Step40)
     * neither text contains spt_values or "master."; neither procedure has
       a reference to another database or server
     * the parameters unchanged (names, order, types)
     * no THROW in spr_AddEditMemberType; spr_SetOrganisationSettings still
       re-raises with THROW
   Part 2, inside one transaction that is ROLLED BACK, with made-up users
   ZZ57 (an Admin, an inactive Admin, a Controller), through the real
   procedures and with made-up sample values only:
     * each of the 33 control characters (0 to 31 and 127) inside an
       organisation value (the 7 free-text settings in turn), a member type
       code and a member type name: Result 0, Reason 3 and that setting code,
       MemberTypeCode or MemberTypeName; nothing written. A row lists the
       code points that did not give that answer ("none" when all did).
     * accepted: space (32), "~" (126) and NCHAR(160) in each of the three
       (each member type save with its own code and name)
     * NCHAR(129) accepted in each of the three, as before step 57 (code
       page 1252 keeps 129, 141, 143, 144 and 157 unchanged; owner decision
       2026-11-27; step CC1 decides whether to refuse them)
     * Controller Reason 4; unknown, NULL and inactive acting user Reason 8;
       for both procedures
   After the rollback: Users, App_Setting, Member_Type and Audit_Trail_Master
   as before, no ZZ57 row left, every identity counter put back.

   Result: one grid, one row per check (30 rows). Status should be PASS for
   every row. SKIPPED means a lookup row needed for the checks does not
   exist.

   It has no USE line: select the database in SSMS first (the test copy). It
   stops if the current database name does not start with "BMMS", or is
   BMMS. Written for compatibility level 100. Plain ASCII.
   From the command line use sqlcmd -I (quoted identifiers ON).
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the test copy of the BMMS database and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@CurrentDatabase = 'BMMS')
BEGIN
    RAISERROR('Current database is "%s". This test runs on the test copy only (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '') NOT LIKE '%DatabaseLocal-Step57%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') NOT LIKE '%DatabaseLocal-Step57%')
BEGIN
    RAISERROR('Step 57 is not installed in "%s". Run BMMS-Fix-DatabaseLocal-Step57.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(600), Actual VARCHAR(600));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));
DECLARE @Ident TABLE (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
DECLARE @Chars TABLE (No INT IDENTITY(0,1), Code INT);
DECLARE @TextFields TABLE (No INT, Field VARCHAR(50));

DECLARE @SetOrg NVARCHAR(MAX) = ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '');
DECLARE @AddMt NVARCHAR(MAX) = ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '');

DECLARE @Now DATETIME = GETDATE();
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @AdminRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @DepartmentId INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @Unknown INT = ISNULL((SELECT MAX(UserId) FROM Users), 0) + 100000;

DECLARE @Adm INT, @AdmOff INT, @Ctl INT;
DECLARE @No INT, @Max INT, @Code INT, @Field VARCHAR(50), @Fail VARCHAR(400), @Run INT, @Got VARCHAR(400);
DECLARE @p1 NVARCHAR(400), @p2 NVARCHAR(400), @p3 NVARCHAR(400), @p4 NVARCHAR(400), @p5 NVARCHAR(400), @p6 NVARCHAR(400),
        @p7 NVARCHAR(400), @p8 NVARCHAR(400), @p9 NVARCHAR(400), @p10 NVARCHAR(400), @p11 NVARCHAR(400), @p12 NVARCHAR(400);
DECLARE @mCode NVARCHAR(400), @mName NVARCHAR(400);
DECLARE @AuditBefore INT, @SetBefore VARCHAR(40), @MtBefore VARCHAR(40);
DECLARE @UsersBefore VARCHAR(40), @SettingsBefore VARCHAR(40), @TypesBefore VARCHAR(40), @AuditRowsBefore VARCHAR(40);
DECLARE @TableName SYSNAME, @SavedValue BIGINT, @SeedValue BIGINT, @IncrementValue BIGINT, @Sql NVARCHAR(400);

-- The 33 control characters, 0 to 31 and 127 (made here: no other database is read)
SET @Code = 0;
WHILE (@Code <= 31)
BEGIN
    INSERT INTO @Chars (Code) VALUES (@Code);
    SET @Code = @Code + 1;
END
INSERT INTO @Chars (Code) VALUES (127);

-- The seven free-text organisation settings (no other rule refuses a control character there)
INSERT INTO @TextFields VALUES
(0, 'OrganisationName'), (1, 'OrganisationShortName'), (2, 'CertificateSignOff'), (3, 'RegisteredOfficeLabel'),
(4, 'RegisteredOfficeLine1'), (5, 'RegisteredOfficeLine2'), (6, 'RegisteredOfficeCity');

-------------------------------------------------------------------------------
-- Part 1 - read only
-------------------------------------------------------------------------------
INSERT INTO @T SELECT 'Marker DatabaseLocal-Step57 in spr_SetOrganisationSettings and spr_AddEditMemberType', '2',
       CAST(CASE WHEN @SetOrg LIKE '%DatabaseLocal-Step57%' THEN 1 ELSE 0 END
          + CASE WHEN @AddMt LIKE '%DatabaseLocal-Step57%' THEN 1 ELSE 0 END AS VARCHAR(4));
INSERT INTO @T SELECT 'Older markers kept: OrganisationSettings-Step19; MemberTypes-Step21 and RoleAccess-Step40', '1 1 1',
       CASE WHEN @SetOrg LIKE '%OrganisationSettings-Step19%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN @AddMt LIKE '%MemberTypes-Step21%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN @AddMt LIKE '%RoleAccess-Step40%' THEN '1' ELSE '0' END;
INSERT INTO @T SELECT 'Neither text contains spt_values', '0',
       CAST(CASE WHEN @SetOrg LIKE '%spt[_]values%' THEN 1 ELSE 0 END
          + CASE WHEN @AddMt LIKE '%spt[_]values%' THEN 1 ELSE 0 END AS VARCHAR(4));
INSERT INTO @T SELECT 'Neither text contains "master."', '0',
       CAST(CASE WHEN @SetOrg LIKE '%master.%' THEN 1 ELSE 0 END
          + CASE WHEN @AddMt LIKE '%master.%' THEN 1 ELSE 0 END AS VARCHAR(4));
INSERT INTO @T SELECT 'Neither procedure has a reference to another database or server', '0',
       CAST(COUNT(*) AS VARCHAR(12)) FROM sys.sql_expression_dependencies d
       WHERE d.referencing_id IN (OBJECT_ID('dbo.spr_SetOrganisationSettings'), OBJECT_ID('dbo.spr_AddEditMemberType'))
         AND (d.referenced_database_name IS NOT NULL OR d.referenced_server_name IS NOT NULL);
INSERT INTO @T SELECT 'spr_SetOrganisationSettings: parameters unchanged (names, order, types)',
       '@ActingUserId int(4),@OrganisationName nvarchar(800),@OrganisationShortName nvarchar(800),@OrganisationTerm nvarchar(800),'
     + '@CertificateSignOff nvarchar(800),@RegisteredOfficeLabel nvarchar(800),@RegisteredOfficeLine1 nvarchar(800),'
     + '@RegisteredOfficeLine2 nvarchar(800),@RegisteredOfficeCity nvarchar(800),@RegisteredOfficePinCode nvarchar(800),'
     + '@OrganisationPhone nvarchar(800),@OrganisationFax nvarchar(800),@OrganisationEmail nvarchar(800)',
       ISNULL(STUFF((SELECT ',' + p.name + ' ' + TYPE_NAME(p.user_type_id) + '(' + CAST(p.max_length AS VARCHAR(6)) + ')'
                     FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_SetOrganisationSettings')
                     ORDER BY p.parameter_id FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), '');
INSERT INTO @T SELECT 'spr_AddEditMemberType: parameters unchanged (names, order, types)',
       '@Code varchar(50),@MemberTypeId int(4),@MemberTypeCode nvarchar(800),@MemberTypeName nvarchar(800),@StatusId int(4),'
     + '@CreatedOn datetime(8),@CreatedBy int(4),@UpdatedOn datetime(8),@UpdatedBy int(4),@MemberScope varchar(10),'
     + '@DisplayOrder int(4),@ActingUserId int(4)',
       ISNULL(STUFF((SELECT ',' + p.name + ' ' + TYPE_NAME(p.user_type_id) + '(' + CAST(p.max_length AS VARCHAR(6)) + ')'
                     FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_AddEditMemberType')
                     ORDER BY p.parameter_id FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''), '');
INSERT INTO @T SELECT 'No THROW in spr_AddEditMemberType (it re-raises with RAISERROR)', '0',
       CASE WHEN @AddMt LIKE '%THROW%' THEN '1' ELSE '0' END;
INSERT INTO @T SELECT 'spr_SetOrganisationSettings still re-raises with THROW (unchanged)', '1',
       CASE WHEN @SetOrg LIKE '%THROW;%' THEN '1' ELSE '0' END;

IF (@Sys IS NULL OR @AdminRoleId IS NULL OR @CtrlRoleId IS NULL OR @DepartmentId IS NULL OR @DesignationId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, the Admin or Controller role, a department or a designation is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

-- Before the test: rows and identity counters (put back and compared after the rollback)
INSERT INTO @Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';

SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, UserName, RoleId, AccountStatus)), 0) AS VARCHAR(12)) FROM Users;
SELECT @SettingsBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(SettingCode, SettingValue)), 0) AS VARCHAR(12)) FROM App_Setting;
SELECT @TypesBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MemberTypeId, MemberTypeCode, MemberTypeName, StatusId)), 0) AS VARCHAR(12)) FROM Member_Type;
SELECT @AuditRowsBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(MAX(Audit_Trail_Maser_Id), 0) AS VARCHAR(12)) FROM Audit_Trail_Master;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ57 admin', @DepartmentId, @DesignationId, NULL, @AdminRoleId, 'zz57adm@example.invalid', 'zz57adm', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ57 admin off', @DepartmentId, @DesignationId, NULL, @AdminRoleId, 'zz57off@example.invalid', 'zz57off', 'not-a-login', 0, @Now, @Sys, @Now, @Sys);
    SET @AdmOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ57 controller', @DepartmentId, @DesignationId, NULL, @CtrlRoleId, 'zz57ctl@example.invalid', 'zz57ctl', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- Part 2a - organisation settings: the 33 control characters
    ---------------------------------------------------------------------------
    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);
    SELECT @SetBefore = CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(SettingCode, SettingValue)), 0) AS VARCHAR(12)) FROM App_Setting;

    SELECT @No = 0, @Max = MAX(No), @Fail = '', @Run = 0 FROM @Chars;
    WHILE (@No <= @Max)
    BEGIN
        SET @Code = (SELECT Code FROM @Chars WHERE No = @No);
        SET @Field = (SELECT Field FROM @TextFields WHERE No = @No % 7);
        SELECT @p1 = N'Changed Company Limited', @p2 = N'Changed', @p3 = N'Company', @p4 = N'Changed Ltd.,', @p5 = N'Office',
               @p6 = N'1 Other Road', @p7 = N'Other Nagar', @p8 = N'Othertown', @p9 = N'600002', @p10 = N'1234', @p11 = N'5678',
               @p12 = N'other@example.com';
        IF (@Field = 'OrganisationName') SET @p1 = N'Sample' + NCHAR(@Code) + N'Value';
        IF (@Field = 'OrganisationShortName') SET @p2 = N'Sample' + NCHAR(@Code) + N'Value';
        IF (@Field = 'CertificateSignOff') SET @p4 = N'Sample' + NCHAR(@Code) + N'Value';
        IF (@Field = 'RegisteredOfficeLabel') SET @p5 = N'Sample' + NCHAR(@Code) + N'Value';
        IF (@Field = 'RegisteredOfficeLine1') SET @p6 = N'Sample' + NCHAR(@Code) + N'Value';
        IF (@Field = 'RegisteredOfficeLine2') SET @p7 = N'Sample' + NCHAR(@Code) + N'Value';
        IF (@Field = 'RegisteredOfficeCity') SET @p8 = N'Sample' + NCHAR(@Code) + N'Value';

        DELETE FROM @R;
        INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
            @OrganisationName = @p1, @OrganisationShortName = @p2, @OrganisationTerm = @p3, @CertificateSignOff = @p4,
            @RegisteredOfficeLabel = @p5, @RegisteredOfficeLine1 = @p6, @RegisteredOfficeLine2 = @p7, @RegisteredOfficeCity = @p8,
            @RegisteredOfficePinCode = @p9, @OrganisationPhone = @p10, @OrganisationFax = @p11, @OrganisationEmail = @p12;
        IF (ISNULL((SELECT Txt FROM @R), '') <> 'Result 0, Reason 3, ' + @Field)
            SET @Fail = @Fail + CASE WHEN @Fail = '' THEN '' ELSE ' ' END + CAST(@Code AS VARCHAR(4));
        SET @Run = @Run + 1;
        SET @No = @No + 1;
    END
    INSERT INTO @T SELECT 'Organisation: the 33 control characters (0-31, 127) inside a free-text value: Result 0, Reason 3, that setting code (code points that did not)',
           '33 run, not refused: none', CAST(@Run AS VARCHAR(4)) + ' run, not refused: ' + CASE WHEN @Fail = '' THEN 'none' ELSE @Fail END;
    SELECT @Got = CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(SettingCode, SettingValue)), 0) AS VARCHAR(12)) FROM App_Setting;
    INSERT INTO @T SELECT 'Organisation: after the 33 refusals no setting changed and no audit row', 'same 0',
           CASE WHEN @Got = @SetBefore THEN 'same' ELSE 'DIFFERENT' END
         + ' ' + CAST(COUNT(*) AS VARCHAR(12)) FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore;

    ---------------------------------------------------------------------------
    -- Part 2b - member type: the 33 control characters in the code and in the name
    ---------------------------------------------------------------------------
    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);
    SELECT @MtBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MemberTypeId, MemberTypeCode, MemberTypeName, StatusId)), 0) AS VARCHAR(12)) FROM Member_Type;

    SELECT @No = 0, @Max = MAX(No), @Fail = '', @Run = 0 FROM @Chars;
    WHILE (@No <= @Max)
    BEGIN
        SET @Code = (SELECT Code FROM @Chars WHERE No = @No);
        SET @mCode = N'ZZ57' + NCHAR(@Code) + N'C';
        DELETE FROM @R;
        INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
            @MemberTypeCode = @mCode, @MemberTypeName = N'ZZ57 Code Check', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
        IF (ISNULL((SELECT Txt FROM @R), '') <> 'Result 0, Reason 3, MemberTypeCode')
            SET @Fail = @Fail + CASE WHEN @Fail = '' THEN '' ELSE ' ' END + CAST(@Code AS VARCHAR(4));
        SET @Run = @Run + 1;
        SET @No = @No + 1;
    END
    INSERT INTO @T SELECT 'Member type: the 33 control characters inside the code: Result 0, Reason 3, MemberTypeCode (code points that did not)',
           '33 run, not refused: none', CAST(@Run AS VARCHAR(4)) + ' run, not refused: ' + CASE WHEN @Fail = '' THEN 'none' ELSE @Fail END;

    SELECT @No = 0, @Max = MAX(No), @Fail = '', @Run = 0 FROM @Chars;
    WHILE (@No <= @Max)
    BEGIN
        SET @Code = (SELECT Code FROM @Chars WHERE No = @No);
        SET @mName = N'ZZ57 Name' + NCHAR(@Code) + N'N';
        DELETE FROM @R;
        INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
            @MemberTypeCode = N'ZZ57N', @MemberTypeName = @mName, @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
        IF (ISNULL((SELECT Txt FROM @R), '') <> 'Result 0, Reason 3, MemberTypeName')
            SET @Fail = @Fail + CASE WHEN @Fail = '' THEN '' ELSE ' ' END + CAST(@Code AS VARCHAR(4));
        SET @Run = @Run + 1;
        SET @No = @No + 1;
    END
    INSERT INTO @T SELECT 'Member type: the 33 control characters inside the name: Result 0, Reason 3, MemberTypeName (code points that did not)',
           '33 run, not refused: none', CAST(@Run AS VARCHAR(4)) + ' run, not refused: ' + CASE WHEN @Fail = '' THEN 'none' ELSE @Fail END;
    SELECT @Got = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MemberTypeId, MemberTypeCode, MemberTypeName, StatusId)), 0) AS VARCHAR(12)) FROM Member_Type;
    INSERT INTO @T SELECT 'Member type: after the 66 refusals no member type added or changed and no audit row', 'same 0',
           CASE WHEN @Got = @MtBefore THEN 'same' ELSE 'DIFFERENT' END
         + ' ' + CAST(COUNT(*) AS VARCHAR(12)) FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore;

    ---------------------------------------------------------------------------
    -- Part 2c - accepted: space (32), ~ (126), NCHAR(160)
    ---------------------------------------------------------------------------
    SET @Got = '';
    SET @No = 1;
    WHILE (@No <= 3)
    BEGIN
        SET @Code = CASE @No WHEN 1 THEN 32 WHEN 2 THEN 126 ELSE 160 END;
        SET @p1 = N'Sample' + NCHAR(@Code) + N'Value';
        DELETE FROM @R;
        INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
            @OrganisationName = @p1, @OrganisationShortName = N'Changed', @OrganisationTerm = N'Company', @CertificateSignOff = N'Changed Ltd.,',
            @RegisteredOfficeLabel = N'Office', @RegisteredOfficeLine1 = N'1 Other Road', @RegisteredOfficeLine2 = N'Other Nagar',
            @RegisteredOfficeCity = N'Othertown', @RegisteredOfficePinCode = N'600002', @OrganisationPhone = N'1234', @OrganisationFax = N'5678',
            @OrganisationEmail = N'other@example.com';
        SET @Got = @Got + CASE WHEN @Got = '' THEN '' ELSE ' | ' END + ISNULL((SELECT Txt FROM @R), 'no result');
        SET @No = @No + 1;
    END
    INSERT INTO @T SELECT 'Organisation: space, ~ and NCHAR(160) inside the name accepted', 'Result 1, Reason 0 | Result 1, Reason 0 | Result 1, Reason 0', @Got;

    SET @Got = '';
    SET @No = 1;
    WHILE (@No <= 3)
    BEGIN
        SET @Code = CASE @No WHEN 1 THEN 32 WHEN 2 THEN 126 ELSE 160 END;
        SET @mCode = N'ZZ57' + NCHAR(@Code) + NCHAR(64 + @No);
        SET @mName = N'ZZ57 Accepted code ' + NCHAR(64 + @No);
        DELETE FROM @R;
        INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
            @MemberTypeCode = @mCode, @MemberTypeName = @mName, @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
        SET @Got = @Got + CASE WHEN @Got = '' THEN '' ELSE ' | ' END + ISNULL((SELECT Txt FROM @R), 'no result');
        SET @No = @No + 1;
    END
    INSERT INTO @T SELECT 'Member type: space, ~ and NCHAR(160) inside the code accepted (each save its own code and name)',
           'Result 1, Reason 0 | Result 1, Reason 0 | Result 1, Reason 0', @Got;

    SET @Got = '';
    SET @No = 1;
    WHILE (@No <= 3)
    BEGIN
        SET @Code = CASE @No WHEN 1 THEN 32 WHEN 2 THEN 126 ELSE 160 END;
        SET @mCode = N'ZZ57NM' + NCHAR(64 + @No);
        SET @mName = N'ZZ57 Accepted' + NCHAR(@Code) + N'name ' + NCHAR(64 + @No);
        DELETE FROM @R;
        INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
            @MemberTypeCode = @mCode, @MemberTypeName = @mName, @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
        SET @Got = @Got + CASE WHEN @Got = '' THEN '' ELSE ' | ' END + ISNULL((SELECT Txt FROM @R), 'no result');
        SET @No = @No + 1;
    END
    INSERT INTO @T SELECT 'Member type: space, ~ and NCHAR(160) inside the name accepted (each save its own code and name)',
           'Result 1, Reason 0 | Result 1, Reason 0 | Result 1, Reason 0', @Got;

    ---------------------------------------------------------------------------
    -- Part 2d - NCHAR(129): accepted, as before step 57 (owner decision 2026-11-27)
    -- Code page 1252 keeps 129, 141, 143, 144 and 157 unchanged, so the code-page rule does not
    -- refuse them, and they are not in the control-character list (0 to 31, 127). These rows check
    -- that the behaviour is unchanged; whether to refuse them is step CC1 (Database/README.md).
    ---------------------------------------------------------------------------
    -- Organisation name: accepted as before step 57 (code page 1252 keeps 129 unchanged)
    SET @p1 = N'Ex' + NCHAR(129) + N'mple Company Limited';
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
        @OrganisationName = @p1, @OrganisationShortName = N'Changed', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Changed Ltd.,', @RegisteredOfficeLabel = N'Office', @RegisteredOfficeLine1 = N'1 Other Road',
        @RegisteredOfficeLine2 = N'Other Nagar', @RegisteredOfficeCity = N'Othertown', @RegisteredOfficePinCode = N'600002',
        @OrganisationPhone = N'1234', @OrganisationFax = N'5678', @OrganisationEmail = N'other@example.com';
    INSERT INTO @T SELECT 'Organisation: NCHAR(129) in the name accepted, as before step 57 (code page 1252 keeps 129, 141, 143, 144 and 157 unchanged)',
           'Result 1, Reason 0', ISNULL((SELECT Txt FROM @R), 'no result');

    -- Member type code: accepted as before step 57 (code page 1252 keeps 129 unchanged)
    SET @mCode = N'ZZ57' + NCHAR(129) + N'X';
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = @mCode, @MemberTypeName = N'ZZ57 Code 129', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Member type: NCHAR(129) in the code accepted, as before step 57 (code page 1252 keeps 129, 141, 143, 144 and 157 unchanged)',
           'Result 1, Reason 0', ISNULL((SELECT Txt FROM @R), 'no result');

    -- Member type name: accepted as before step 57 (code page 1252 keeps 129 unchanged)
    SET @mName = N'ZZ57 Name' + NCHAR(129) + N'X';
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ57N129', @MemberTypeName = @mName, @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Member type: NCHAR(129) in the name accepted, as before step 57 (code page 1252 keeps 129, 141, 143, 144 and 157 unchanged)',
           'Result 1, Reason 0', ISNULL((SELECT Txt FROM @R), 'no result');

    ---------------------------------------------------------------------------
    -- Part 2e - who may save (valid values)
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Ctl,
        @OrganisationName = N'Changed Company Limited', @OrganisationShortName = N'Changed', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Changed Ltd.,', @RegisteredOfficeLabel = N'Office', @RegisteredOfficeLine1 = N'1 Other Road',
        @RegisteredOfficeLine2 = N'Other Nagar', @RegisteredOfficeCity = N'Othertown', @RegisteredOfficePinCode = N'600002',
        @OrganisationPhone = N'1234', @OrganisationFax = N'5678', @OrganisationEmail = N'other@example.com';
    INSERT INTO @T SELECT 'Organisation: Controller refused', 'Result 0, Reason 4', ISNULL((SELECT Txt FROM @R), 'no result');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Unknown,
        @OrganisationName = N'Changed Company Limited', @OrganisationShortName = N'Changed', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Changed Ltd.,', @RegisteredOfficeLabel = N'Office', @RegisteredOfficeLine1 = N'1 Other Road',
        @RegisteredOfficeLine2 = N'Other Nagar', @RegisteredOfficeCity = N'Othertown', @RegisteredOfficePinCode = N'600002',
        @OrganisationPhone = N'1234', @OrganisationFax = N'5678', @OrganisationEmail = N'other@example.com';
    INSERT INTO @T SELECT 'Organisation: unknown acting user refused', 'Result 0, Reason 8', ISNULL((SELECT Txt FROM @R), 'no result');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = NULL,
        @OrganisationName = N'Changed Company Limited', @OrganisationShortName = N'Changed', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Changed Ltd.,', @RegisteredOfficeLabel = N'Office', @RegisteredOfficeLine1 = N'1 Other Road',
        @RegisteredOfficeLine2 = N'Other Nagar', @RegisteredOfficeCity = N'Othertown', @RegisteredOfficePinCode = N'600002',
        @OrganisationPhone = N'1234', @OrganisationFax = N'5678', @OrganisationEmail = N'other@example.com';
    INSERT INTO @T SELECT 'Organisation: NULL acting user refused', 'Result 0, Reason 8', ISNULL((SELECT Txt FROM @R), 'no result');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @AdmOff,
        @OrganisationName = N'Changed Company Limited', @OrganisationShortName = N'Changed', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Changed Ltd.,', @RegisteredOfficeLabel = N'Office', @RegisteredOfficeLine1 = N'1 Other Road',
        @RegisteredOfficeLine2 = N'Other Nagar', @RegisteredOfficeCity = N'Othertown', @RegisteredOfficePinCode = N'600002',
        @OrganisationPhone = N'1234', @OrganisationFax = N'5678', @OrganisationEmail = N'other@example.com';
    INSERT INTO @T SELECT 'Organisation: inactive Admin refused', 'Result 0, Reason 8', ISNULL((SELECT Txt FROM @R), 'no result');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ57W', @MemberTypeName = N'ZZ57 Who', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Member type: Controller refused', 'Result 0, Reason 4', ISNULL((SELECT Txt FROM @R), 'no result');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ57W', @MemberTypeName = N'ZZ57 Who', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Unknown;
    INSERT INTO @T SELECT 'Member type: unknown acting user refused', 'Result 0, Reason 8', ISNULL((SELECT Txt FROM @R), 'no result');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ57W', @MemberTypeName = N'ZZ57 Who', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = NULL;
    INSERT INTO @T SELECT 'Member type: NULL acting user refused', 'Result 0, Reason 8', ISNULL((SELECT Txt FROM @R), 'no result');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ57W', @MemberTypeName = N'ZZ57 Who', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @AdmOff;
    INSERT INTO @T SELECT 'Member type: inactive Admin refused', 'Result 0, Reason 8', ISNULL((SELECT Txt FROM @R), 'no result');

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

-- Every identity counter as before the test (a rolled-back insert still moves it)
DECLARE IdentCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName, SavedValue, SeedValue, IncrementValue FROM @Ident;
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

INSERT INTO @T SELECT 'After the rollback: Users, App_Setting, Member_Type, Audit_Trail_Master as before; no ZZ57 user or member type left',
       'same same same same 0 0',
       CASE WHEN (SELECT CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, UserName, RoleId, AccountStatus)), 0) AS VARCHAR(12)) FROM Users) = @UsersBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN (SELECT CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(SettingCode, SettingValue)), 0) AS VARCHAR(12)) FROM App_Setting) = @SettingsBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN (SELECT CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MemberTypeId, MemberTypeCode, MemberTypeName, StatusId)), 0) AS VARCHAR(12)) FROM Member_Type) = @TypesBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CASE WHEN (SELECT CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(MAX(Audit_Trail_Maser_Id), 0) AS VARCHAR(12)) FROM Audit_Trail_Master) = @AuditRowsBefore THEN 'same' ELSE 'DIFFERENT' END + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz57%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Member_Type WHERE MemberTypeCode LIKE 'ZZ57%') AS VARCHAR(12));

INSERT INTO @T SELECT 'Identity counters as before the test', '0',
       CAST((SELECT COUNT(*) FROM @Ident i JOIN sys.tables t ON t.name = i.TableName JOIN sys.identity_columns ic ON ic.object_id = t.object_id
             WHERE i.SavedValue IS NOT NULL AND ISNULL(CAST(ic.last_value AS BIGINT), -1) <> i.SavedValue) AS VARCHAR(12));

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
GO

SET NOEXEC OFF;
GO
