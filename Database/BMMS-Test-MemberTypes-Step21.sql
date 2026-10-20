/* ============================================================================
   BMMS - Tests for BMMS-Fix-MemberTypes-Step21.sql (step 21)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-MemberTypes-Step21.sql, on the TEST COPY. It stops if
   step 21 is not installed.

   Creates its own users (an Admin, a Controller, a Manager, an inactive
   Admin), two meetings and its own member types, and checks, through the
   real procedures, with made-up sample values only:
     * the markers (and the step 3, 15 and 18 markers kept), the columns,
       the constraints, the reserved rows (2, 3, 6 where they exist), scope
       against use, the check constraints and unique indexes refusing
       direct changes
     * save by an Admin and by a Controller (trimmed), Manager (Reason 4),
       inactive / unknown / no acting user (Reason 8), Reason 3 naming the
       field for each bad value and for duplicates, nothing saved after a
       refusal
     * edit: a free type, its own name kept, not found, every change of a
       reserved type refused (Reason 7), scope change of a type in use
       refused (Reason 5), deactivation of a type in use allowed
     * the drop-down lists per scope, the current type marked
     * committee member and meeting member save / edit by scope, status and
       existence (Reason 13), an edit keeping its current type, the step 15
       lock still first
     * delete: free and unused, in use (Reason 5), reserved (Reason 7),
       roles and acting user, not found
     * the master list columns and the Reset Database seed (procedure text
       only; it is not run here: see BMMS-Test-ResetDatabase.sql)

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') NOT LIKE '%MemberTypes-Step21%')
BEGIN
    RAISERROR('The member types (step 21) are not installed in "%s". Run BMMS-Fix-MemberTypes-Step21.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));
DECLARE @L TABLE (MemberTypeId INT, MemberTypeCode VARCHAR(50), MemberTypeName VARCHAR(50), StatusId INT, StatusName VARCHAR(100),
                  MemberScope CHAR(1), ScopeName VARCHAR(20), DisplayOrder INT, IsReserved INT,
                  CommitteeUseCount INT, MeetingUseCount INT, CanEdit INT, CanDelete INT);
DECLARE @D TABLE (Seq INT IDENTITY(1,1), MemberTypeId INT, MemberTypeName VARCHAR(50), DisplayName VARCHAR(100));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -7, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @AdminRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @MgrRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @DepartmentId INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @CommitteeId INT = (SELECT TOP 1 CommitteeId FROM Committee ORDER BY CommitteeId);
DECLARE @Member1 INT = (SELECT TOP 1 MemberId FROM Member ORDER BY MemberId);
DECLARE @Member2 INT = (SELECT TOP 1 MemberId FROM Member WHERE MemberId <> (SELECT TOP 1 MemberId FROM Member ORDER BY MemberId) ORDER BY MemberId);
DECLARE @InAttendance INT = (SELECT MemberTypeId FROM Member_Type WHERE MemberTypeId = 3);
DECLARE @SpecialInvitee INT = (SELECT MemberTypeId FROM Member_Type WHERE MemberTypeId = 6);
DECLARE @CommitteeType INT = (SELECT TOP 1 MemberTypeId FROM Member_Type WHERE MemberScope = 'C' AND StatusId = 1 ORDER BY MemberTypeId);
DECLARE @CommitteeTypeName VARCHAR(50) = (SELECT MemberTypeName FROM Member_Type WHERE MemberTypeId = @CommitteeType);

DECLARE @Adm INT, @Ctl INT, @Mgr INT, @AdmOff INT;
DECLARE @MOpen INT, @MF INT;
DECLARE @TC INT, @TM INT, @TOff INT, @TMOff INT, @TCtl INT, @TDel INT;
DECLARE @CM INT, @MM INT, @Missing INT;
DECLARE @Count INT, @Count2 INT, @Snap VARCHAR(MAX), @Snap2 VARCHAR(MAX), @Expected VARCHAR(MAX);
DECLARE @Long50 NVARCHAR(400) = REPLICATE(N'q', 50);
DECLARE @Long51 NVARCHAR(400) = REPLICATE(N'w', 51);
DECLARE @Err VARCHAR(20);
DECLARE @Accented NVARCHAR(400) = N'ZZ21 Sample & Soci' + NCHAR(233) + N't' + NCHAR(233);

IF (@Sys IS NULL OR @AdminRoleId IS NULL OR @CtrlRoleId IS NULL OR @MgrRoleId IS NULL OR @DepartmentId IS NULL OR @DesignationId IS NULL
    OR @CommitteeId IS NULL OR @Member1 IS NULL OR @Member2 IS NULL OR @InAttendance IS NULL OR @SpecialInvitee IS NULL OR @CommitteeType IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a department, a designation, a committee, two members, type 3, type 6 or an active committee type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ21 admin', @DepartmentId, @DesignationId, NULL, @AdminRoleId, 'zz21adm@example.invalid', 'zz21adm', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ21 controller', @DepartmentId, @DesignationId, NULL, @CtrlRoleId, 'zz21ctl@example.invalid', 'zz21ctl', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ21 manager', @DepartmentId, @DesignationId, NULL, @MgrRoleId, 'zz21mgr@example.invalid', 'zz21mgr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ21 admin off', @DepartmentId, @DesignationId, NULL, @AdminRoleId, 'zz21off@example.invalid', 'zz21off', 'not-a-login', 0, @Now, @Sys, @Now, @Sys);
    SET @AdmOff = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('ZZ21A', @CommitteeId, 'ZZ21 test', 'ZZ', @Past, '10:00', 'Open', 'Open');
    SET @MOpen = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaStatus, MinutesStatus)
    VALUES ('ZZ21B', @CommitteeId, 'ZZ21 test', 'ZZ', @Past, '10:00', 'Close', 'F');
    SET @MF = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- Installation
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Markers: 8 objects carry MemberTypes-Step21', '8',
           CAST(COUNT(*) AS VARCHAR(4)) FROM sys.sql_modules WHERE definition LIKE '%MemberTypes-Step21%'
           AND object_id IN (OBJECT_ID('dbo.spr_GetMemberType'), OBJECT_ID('dbo.spr_GetMemberTypeByMemberTypeId'),
                             OBJECT_ID('dbo.spr_GetMemberTypeForTagging'), OBJECT_ID('dbo.spr_AddEditMemberType'),
                             OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId'), OBJECT_ID('dbo.spr_AddEditCommitteeMember'),
                             OBJECT_ID('dbo.spr_AddEditMeetingMember'), OBJECT_ID('dbo.spr_sys_ResetDatabase'));
    INSERT INTO @T SELECT 'Older markers kept: MeetingLocks-Step15, SystemAccount3-Step18, FK#5-ManagerId-NULL', '1 1 1',
           CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeetingMember')) LIKE '%MeetingLocks-Step15%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%SystemAccount3-Step18%' THEN '1' ELSE '0' END + ' '
         + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%FK#5-ManagerId-NULL%' THEN '1' ELSE '0' END;
    INSERT INTO @T SELECT 'Columns: IsReserved bit NOT NULL, MemberScope char(1) NOT NULL', 'IsReserved bit 0|MemberScope char 0',
           STUFF((SELECT '|' + c.name + ' ' + t.name + ' ' + CAST(c.is_nullable AS VARCHAR(1))
                  FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
                  WHERE c.object_id = OBJECT_ID('dbo.Member_Type') AND c.name IN ('IsReserved', 'MemberScope')
                  ORDER BY c.name FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
    INSERT INTO @T SELECT 'Constraints: 2 checks, 2 unique indexes', '4',
           CAST((SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.Member_Type')
                  AND name IN ('CK_Member_Type_MemberScope', 'CK_Member_Type_Reserved'))
              + (SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Member_Type') AND is_unique = 1
                  AND name IN ('UX_Member_Type_Code', 'UX_Member_Type_Name')) AS VARCHAR(4));
    INSERT INTO @T SELECT 'Reserved: exactly the rows 2, 3, 6 that exist',
           STUFF((SELECT ',' + CAST(MemberTypeId AS VARCHAR(12)) FROM Member_Type WHERE MemberTypeId IN (2, 3, 6) ORDER BY MemberTypeId FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, ''),
           STUFF((SELECT ',' + CAST(MemberTypeId AS VARCHAR(12)) FROM Member_Type WHERE IsReserved = 1 ORDER BY MemberTypeId FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
    INSERT INTO @T SELECT 'Reserved rows are meeting types and active', '0',
           CAST(COUNT(*) AS VARCHAR(4)) FROM Member_Type WHERE IsReserved = 1 AND (MemberScope <> 'M' OR StatusId <> 1);
    INSERT INTO @T SELECT 'Scope matches use (committee rows C, meeting rows M)', '0',
           CAST(COUNT(*) AS VARCHAR(4)) FROM Member_Type mt
           WHERE (mt.MemberScope <> 'C' AND EXISTS (SELECT 1 FROM Committee_Member cm WHERE cm.MemberTypeId = mt.MemberTypeId))
              OR (mt.MemberScope <> 'M' AND EXISTS (SELECT 1 FROM Meeting_Member mm WHERE mm.MemberTypeId = mt.MemberTypeId));
    INSERT INTO @T SELECT 'No DisplayOrder is NULL', '0', CAST(COUNT(*) AS VARCHAR(4)) FROM Member_Type WHERE DisplayOrder IS NULL;
    INSERT INTO @T SELECT 'spr_GetCompanySecretary still reads type 3 (unchanged)', '1',
           CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetCompanySecretary')) LIKE '%MemberTypeId = 3%' THEN '1' ELSE '0' END;

    -- Direct changes the table itself refuses
    SET @Err = 'none';
    BEGIN TRY UPDATE Member_Type SET StatusId = 0 WHERE MemberTypeId = @InAttendance; END TRY
    BEGIN CATCH SET @Err = CAST(ERROR_NUMBER() AS VARCHAR(12)); END CATCH
    INSERT INTO @T SELECT 'Direct SQL: a reserved type cannot be made inactive (check constraint)', '547', @Err;
    SET @Err = 'none';
    BEGIN TRY UPDATE Member_Type SET MemberScope = 'X' WHERE MemberTypeId = @CommitteeType; END TRY
    BEGIN CATCH SET @Err = CAST(ERROR_NUMBER() AS VARCHAR(12)); END CATCH
    INSERT INTO @T SELECT 'Direct SQL: scope other than C or M refused (check constraint)', '547', @Err;
    SET @Err = 'none';
    BEGIN TRY INSERT INTO Member_Type (MemberTypeCode, MemberTypeName, StatusId) VALUES ('ZZ21dup', 'IN ATTENDANCE', 1); END TRY
    BEGIN CATCH SET @Err = CAST(ERROR_NUMBER() AS VARCHAR(12)); END CATCH
    INSERT INTO @T SELECT 'Direct SQL: duplicate name refused, ignoring case (unique index)', '2601', @Err;

    ---------------------------------------------------------------------------
    -- Save
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'  ZZ21C  ', @MemberTypeName = N'  ZZ21 Director  ', @StatusId = 1, @MemberScope = 'c', @DisplayOrder = 50, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Admin saves a committee type', 'Result 1, Reason 0', Txt FROM @R;
    SET @TC = (SELECT MemberTypeId FROM Member_Type WHERE MemberTypeCode = 'ZZ21C');
    INSERT INTO @T SELECT 'Stored: trimmed, scope C, order 50, not reserved, active, by the Admin', 'ZZ21C|ZZ21 Director|C|50|0|1|1|1',
           ISNULL((SELECT MemberTypeCode + '|' + MemberTypeName + '|' + MemberScope + '|' + CAST(DisplayOrder AS VARCHAR(12)) + '|'
                   + CAST(CAST(IsReserved AS INT) AS VARCHAR(1)) + '|' + CAST(StatusId AS VARCHAR(2)) + '|'
                   + CASE WHEN CreatedBy = @Adm THEN '1' ELSE '0' END + '|' + CASE WHEN UpdatedBy = @Adm THEN '1' ELSE '0' END
                   FROM Member_Type WHERE MemberTypeId = @TC), 'none');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ21M', @MemberTypeName = N'ZZ21 Observer', @StatusId = 1, @MemberScope = 'M', @DisplayOrder = 40, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Controller saves a meeting type', 'Result 1, Reason 0', Txt FROM @R;
    SET @TM = (SELECT MemberTypeId FROM Member_Type WHERE MemberTypeCode = 'ZZ21M');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ21OFF', @MemberTypeName = N'ZZ21 Former role', @StatusId = 0, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Save an inactive committee type', 'Result 1, Reason 0', Txt FROM @R;
    SET @TOff = (SELECT MemberTypeId FROM Member_Type WHERE MemberTypeCode = 'ZZ21OFF');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ21MOFF', @MemberTypeName = N'ZZ21 Former guest', @StatusId = 0, @MemberScope = 'M', @DisplayOrder = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Save an inactive meeting type', 'Result 1, Reason 0', Txt FROM @R;
    SET @TMOff = (SELECT MemberTypeId FROM Member_Type WHERE MemberTypeCode = 'ZZ21MOFF');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = @Long50, @MemberTypeName = @Long50, @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 9999, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Code and name of exactly 50 characters, order 9999', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ21S', @MemberTypeName = @Accented, @StatusId = 1, @MemberScope = 'C', @DisplayOrder = NULL, @ActingUserId = @Sys;
    INSERT INTO @T SELECT 'System account saves; "&" and accented letters kept; NULL order is 0', 'Result 1, Reason 0 / 1 0',
           (SELECT Txt FROM @R) + ' / '
         + ISNULL((SELECT CASE WHEN CAST(MemberTypeName AS NVARCHAR(50)) COLLATE Latin1_General_BIN = @Accented COLLATE Latin1_General_BIN THEN '1' ELSE '0' END
                   + ' ' + CAST(DisplayOrder AS VARCHAR(12)) FROM Member_Type WHERE MemberTypeCode = 'ZZ21S'), 'none');

    -- Refusals change nothing
    SET @Count = (SELECT COUNT(*) FROM Member_Type);

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ21X', @MemberTypeName = N'ZZ21 X', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Manager refused', 'Result 0, Reason 4', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ21X', @MemberTypeName = N'ZZ21 X', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @AdmOff;
    INSERT INTO @T SELECT 'Inactive Admin refused', 'Result 0, Reason 8', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ21X', @MemberTypeName = N'ZZ21 X', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = 0;
    INSERT INTO @T SELECT 'Unknown acting user refused', 'Result 0, Reason 8', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
        @MemberTypeCode = 'ZZ21X', @MemberTypeName = 'ZZ21 X', @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Call of the older build (no acting user) refused', 'Result 0, Reason 8', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Insert', @MemberTypeId = 0,
        @MemberTypeCode = N'ZZ21X', @MemberTypeName = N'ZZ21 X', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Unknown @Code refused', 'Result 0, Reason 3, Code', Txt FROM @R;

    -- Reason 3: each bad value, with every other value valid
    DECLARE @Bad TABLE (No INT IDENTITY(1,1), Label VARCHAR(100), Field VARCHAR(50), Value NVARCHAR(400), Num INT);
    INSERT INTO @Bad (Label, Field, Value, Num) VALUES
    ('Empty code', 'MemberTypeCode', N'   ', NULL),
    ('Code of 51 characters', 'MemberTypeCode', @Long51, NULL),
    ('Line break in the code', 'MemberTypeCode', N'ZZ21' + NCHAR(13) + NCHAR(10) + N'X', NULL),
    ('Empty name', 'MemberTypeName', N'', NULL),
    ('Name of 51 characters', 'MemberTypeName', @Long51, NULL),
    ('Tab in the name', 'MemberTypeName', N'ZZ21' + NCHAR(9) + N'X', NULL),
    ('Letter outside Windows-1252 (a with macron)', 'MemberTypeName', N'ZZ21 ' + NCHAR(257), NULL),
    ('Scope X', 'MemberScope', N'X', NULL),
    ('Scope missing', 'MemberScope', NULL, NULL),
    ('Scope "Both"', 'MemberScope', N'B', NULL),
    ('Display order -1', 'DisplayOrder', NULL, -1),
    ('Display order 10000', 'DisplayOrder', NULL, 10000),
    ('Status 2', 'StatusId', NULL, 2),
    ('Status missing', 'StatusId', NULL, NULL),
    ('Same code, other case', 'DuplicateCode', N'zz21c', NULL),
    ('Same code as a reserved type', 'DuplicateCode', N'InAttendance', NULL),
    ('Same name, other case and spaces', 'DuplicateName', N'  zz21 director ', NULL),
    ('Same name as a reserved type', 'DuplicateName', N'Special Invitee', NULL);

    DECLARE @No INT = 1, @Max INT = (SELECT MAX(No) FROM @Bad), @Field VARCHAR(50), @Value NVARCHAR(400), @Num INT, @Label VARCHAR(100);
    DECLARE @pCode NVARCHAR(400), @pName NVARCHAR(400), @pScope VARCHAR(10), @pOrder INT, @pStatus INT;
    WHILE (@No <= @Max)
    BEGIN
        SELECT @Field = Field, @Value = Value, @Num = Num, @Label = Label FROM @Bad WHERE No = @No;
        SELECT @pCode = N'ZZ21X', @pName = N'ZZ21 X', @pScope = 'C', @pOrder = 0, @pStatus = 1;
        IF (@Field IN ('MemberTypeCode', 'DuplicateCode')) SET @pCode = @Value;
        IF (@Field IN ('MemberTypeName', 'DuplicateName')) SET @pName = @Value;
        IF (@Field = 'MemberScope') SET @pScope = CAST(@Value AS VARCHAR(10));
        IF (@Field = 'DisplayOrder') SET @pOrder = @Num;
        IF (@Field = 'StatusId') SET @pStatus = @Num;

        DELETE FROM @R;
        INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Save', @MemberTypeId = 0,
            @MemberTypeCode = @pCode, @MemberTypeName = @pName, @StatusId = @pStatus, @MemberScope = @pScope, @DisplayOrder = @pOrder, @ActingUserId = @Adm;
        INSERT INTO @T SELECT 'Refused: ' + @Label, 'Result 0, Reason 3, ' + @Field, Txt FROM @R;

        SET @No = @No + 1;
    END

    INSERT INTO @T SELECT 'After every refusal: no member type added', CAST(@Count AS VARCHAR(12)), CAST(COUNT(*) AS VARCHAR(12)) FROM Member_Type;

    ---------------------------------------------------------------------------
    -- Edit
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @TC,
        @MemberTypeCode = N'ZZ21C', @MemberTypeName = N'ZZ21 Independent Director', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 45, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Controller edits a free type (name, order)', 'Result 1, Reason 0 / ZZ21 Independent Director 45 1',
           (SELECT Txt FROM @R) + ' / ' + ISNULL((SELECT MemberTypeName + ' ' + CAST(DisplayOrder AS VARCHAR(12)) + ' '
                   + CASE WHEN UpdatedBy = @Ctl AND CreatedBy = @Adm THEN '1' ELSE '0' END FROM Member_Type WHERE MemberTypeId = @TC), 'none');

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @TC,
        @MemberTypeCode = N'zz21c', @MemberTypeName = N'ZZ21 INDEPENDENT DIRECTOR', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 45, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Edit keeping its own code and name (case change) is not a duplicate', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @TC,
        @MemberTypeCode = N'ZZ21M', @MemberTypeName = N'ZZ21 Independent Director', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 45, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Edit to the code of another type refused', 'Result 0, Reason 3, DuplicateCode', Txt FROM @R;

    SET @Missing = (SELECT ISNULL(MAX(MemberTypeId), 0) + 1000 FROM Member_Type);
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @Missing,
        @MemberTypeCode = N'ZZ21Y', @MemberTypeName = N'ZZ21 Y', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Edit of a type that does not exist', 'Result 0, Reason 3, NotFound', Txt FROM @R;

    -- Reserved: every change refused, even with the stored values
    SET @Snap = (SELECT MemberTypeCode + '|' + MemberTypeName + '|' + MemberScope + '|' + CAST(StatusId AS VARCHAR(2)) + '|' + CAST(DisplayOrder AS VARCHAR(12))
                 FROM Member_Type WHERE MemberTypeId = @InAttendance);
    DECLARE @RCode VARCHAR(50), @RName VARCHAR(50), @ROrder INT;
    SELECT @RCode = MemberTypeCode, @RName = MemberTypeName, @ROrder = DisplayOrder FROM Member_Type WHERE MemberTypeId = @InAttendance;
    DECLARE @ROrderNext INT = @ROrder + 1;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @InAttendance,
        @MemberTypeCode = @RCode, @MemberTypeName = N'Company Secretary', @StatusId = 1, @MemberScope = 'M', @DisplayOrder = @ROrder, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Reserved type 3: rename refused', 'Result 0, Reason 7', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @InAttendance,
        @MemberTypeCode = @RCode, @MemberTypeName = @RName, @StatusId = 0, @MemberScope = 'M', @DisplayOrder = @ROrder, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Reserved type 3: deactivate refused', 'Result 0, Reason 7', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @InAttendance,
        @MemberTypeCode = @RCode, @MemberTypeName = @RName, @StatusId = 1, @MemberScope = 'C', @DisplayOrder = @ROrder, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Reserved type 3: scope change refused', 'Result 0, Reason 7', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @InAttendance,
        @MemberTypeCode = @RCode, @MemberTypeName = @RName, @StatusId = 1, @MemberScope = 'M', @DisplayOrder = @ROrderNext, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Reserved type 3: display order change by the Controller refused', 'Result 0, Reason 7', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @InAttendance,
        @MemberTypeCode = @RCode, @MemberTypeName = @RName, @StatusId = 1, @MemberScope = 'M', @DisplayOrder = @ROrder, @ActingUserId = @Sys;
    INSERT INTO @T SELECT 'Reserved type 3: even unchanged values by the system account refused', 'Result 0, Reason 7', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @SpecialInvitee,
        @MemberTypeCode = N'Special Invitee', @MemberTypeName = N'Special Invitee', @StatusId = 0, @MemberScope = 'M', @DisplayOrder = 6, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Reserved type 6: deactivate refused', 'Result 0, Reason 7', Txt FROM @R;
    INSERT INTO @T SELECT 'Reserved type 3 unchanged after the refusals', @Snap,
           (SELECT MemberTypeCode + '|' + MemberTypeName + '|' + MemberScope + '|' + CAST(StatusId AS VARCHAR(2)) + '|' + CAST(DisplayOrder AS VARCHAR(12))
            FROM Member_Type WHERE MemberTypeId = @InAttendance);

    -- Scope change: free while unused, refused once in use
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @TM,
        @MemberTypeCode = N'ZZ21M', @MemberTypeName = N'ZZ21 Observer', @StatusId = 1, @MemberScope = 'C', @DisplayOrder = 40, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Scope change of an unused type', 'Result 1, Reason 0 / C', (SELECT Txt FROM @R) + ' / ' + (SELECT MemberScope FROM Member_Type WHERE MemberTypeId = @TM);
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @TM,
        @MemberTypeCode = N'ZZ21M', @MemberTypeName = N'ZZ21 Observer', @StatusId = 1, @MemberScope = 'M', @DisplayOrder = 40, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Scope changed back', 'Result 1, Reason 0', Txt FROM @R;

    ---------------------------------------------------------------------------
    -- Drop-down lists
    ---------------------------------------------------------------------------
    DELETE FROM @D; INSERT INTO @D (MemberTypeId, MemberTypeName, DisplayName) EXEC spr_GetMemberTypeForTagging @MemberScope = 'C';
    INSERT INTO @T SELECT 'Committee list: active committee types only', '0 1 0 0 0',
           CAST(SUM(CASE WHEN mt.MemberScope <> 'C' OR mt.StatusId <> 1 THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN d.MemberTypeId = @TC THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN d.MemberTypeId IN (@TOff, @TM, @InAttendance) THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN d.MemberTypeId = @SpecialInvitee THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN d.DisplayName <> d.MemberTypeName THEN 1 ELSE 0 END) AS VARCHAR(4))
           FROM @D d JOIN Member_Type mt ON mt.MemberTypeId = d.MemberTypeId;
    INSERT INTO @T SELECT 'Committee list: every active committee type listed', CAST(COUNT(*) AS VARCHAR(4)),
           CAST((SELECT COUNT(*) FROM @D) AS VARCHAR(4)) FROM Member_Type WHERE MemberScope = 'C' AND StatusId = 1;
    SET @Expected = STUFF((SELECT ',' + CAST(MemberTypeId AS VARCHAR(12)) FROM Member_Type WHERE MemberScope = 'C' AND StatusId = 1
                           ORDER BY DisplayOrder, MemberTypeName FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
    INSERT INTO @T SELECT 'Committee list: by display order, then name', @Expected,
           STUFF((SELECT ',' + CAST(MemberTypeId AS VARCHAR(12)) FROM @D ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');

    DELETE FROM @D; INSERT INTO @D (MemberTypeId, MemberTypeName, DisplayName) EXEC spr_GetMemberTypeForTagging @MemberScope = 'M';
    INSERT INTO @T SELECT 'Meeting list: types 3, 6 and the new meeting type; no committee or inactive type', '1 1 1 0 0',
           CAST(SUM(CASE WHEN d.MemberTypeId = @InAttendance THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN d.MemberTypeId = @SpecialInvitee THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN d.MemberTypeId = @TM THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN mt.MemberScope <> 'M' THEN 1 ELSE 0 END) AS VARCHAR(4)) + ' '
         + CAST(SUM(CASE WHEN d.MemberTypeId = @TMOff THEN 1 ELSE 0 END) AS VARCHAR(4))
           FROM @D d JOIN Member_Type mt ON mt.MemberTypeId = d.MemberTypeId;

    DELETE FROM @D; INSERT INTO @D (MemberTypeId, MemberTypeName, DisplayName) EXEC spr_GetMemberTypeForTagging @MemberScope = 'C', @CurrentMemberTypeId = @TOff;
    INSERT INTO @T SELECT 'Edit: the current inactive type is added last, marked', 'ZZ21 Former role (inactive)',
           ISNULL((SELECT TOP 1 DisplayName FROM @D ORDER BY Seq DESC), 'none');
    DELETE FROM @D; INSERT INTO @D (MemberTypeId, MemberTypeName, DisplayName) EXEC spr_GetMemberTypeForTagging @MemberScope = 'C', @CurrentMemberTypeId = @InAttendance;
    INSERT INTO @T SELECT 'Edit: a current type of the other scope is marked', 'In Attendance (meeting type)',
           ISNULL((SELECT DisplayName FROM @D WHERE MemberTypeId = @InAttendance), 'none');
    DELETE FROM @D; INSERT INTO @D (MemberTypeId, MemberTypeName, DisplayName) EXEC spr_GetMemberTypeForTagging @MemberScope = 'C', @CurrentMemberTypeId = @TC;
    INSERT INTO @T SELECT 'Edit: a current type already in the list is not repeated', '1',
           CAST(COUNT(*) AS VARCHAR(4)) FROM @D WHERE MemberTypeId = @TC;

    ---------------------------------------------------------------------------
    -- Committee member save / edit
    ---------------------------------------------------------------------------
    DELETE FROM Committee_Member WHERE CommitteeId = @CommitteeId AND MemberId = @Member2;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Save', @CommitteeMemberId = 0, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @InAttendance, @AppointmentDate = '2000-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Committee member with a meeting type refused', 'Result 0, Reason 13, In Attendance', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Save', @CommitteeMemberId = 0, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @TOff, @AppointmentDate = '2000-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Committee member with an inactive committee type refused', 'Result 0, Reason 13, ZZ21 Former role', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Save', @CommitteeMemberId = 0, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @Missing, @AppointmentDate = '2000-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Committee member with a type that does not exist refused', 'Result 0, Reason 13, ' + CAST(@Missing AS VARCHAR(12)), Txt FROM @R;
    INSERT INTO @T SELECT 'No committee member row saved by the refusals', '0',
           CAST(COUNT(*) AS VARCHAR(4)) FROM Committee_Member WHERE CommitteeId = @CommitteeId AND MemberId = @Member2;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Save', @CommitteeMemberId = 0, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @TC, @AppointmentDate = '2000-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    SET @CM = (SELECT MAX(CommitteeMemberId) FROM Committee_Member WHERE CommitteeId = @CommitteeId AND MemberId = @Member2);
    INSERT INTO @T SELECT 'Committee member with an active committee type saved', 'Result 1, Reason 0 / 1',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Committee_Member WHERE CommitteeMemberId = @CM AND MemberTypeId = @TC;

    -- The type is now in use: its scope is locked, it can be deactivated, the edit keeps it
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @TC,
        @MemberTypeCode = N'ZZ21C', @MemberTypeName = N'ZZ21 Independent Director', @StatusId = 1, @MemberScope = 'M', @DisplayOrder = 45, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Scope change of a type in use refused', 'Result 0, Reason 5, 1 committee, 0 meeting', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMemberType @Code = 'Update', @MemberTypeId = @TC,
        @MemberTypeCode = N'ZZ21C', @MemberTypeName = N'ZZ21 Independent Director', @StatusId = 0, @MemberScope = 'C', @DisplayOrder = 45, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Deactivating a type in use is allowed', 'Result 1, Reason 0', Txt FROM @R;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Update', @CommitteeMemberId = @CM, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @TC, @AppointmentDate = '2001-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Committee member edit keeping its (now inactive) type', 'Result 1, Reason 0', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Update', @CommitteeMemberId = @CM, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @TOff, @AppointmentDate = '2001-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Committee member edit to another inactive type refused', 'Result 0, Reason 13, ZZ21 Former role', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Update', @CommitteeMemberId = @CM, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @SpecialInvitee, @AppointmentDate = '2001-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Committee member edit to a meeting type refused', 'Result 0, Reason 13, Special Invitee', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Update', @CommitteeMemberId = @CM, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @CommitteeType, @AppointmentDate = '2001-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Committee member edit to an active committee type', 'Result 1, Reason 0 / 1',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Committee_Member WHERE CommitteeMemberId = @CM AND MemberTypeId = @CommitteeType;
    UPDATE Committee_Member SET MemberTypeId = @TC WHERE CommitteeMemberId = @CM;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditCommitteeMember @Code = 'Update', @CommitteeMemberId = -1, @CommitteeId = @CommitteeId,
        @MemberId = @Member2, @MemberTypeId = @CommitteeType, @AppointmentDate = '2001-01-01', @CessationDate = '', @IsFeeApplicable = 0, @ApplicableFee = 0,
        @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Committee member edit of a row that does not exist', 'Result 0, Reason 4', Txt FROM @R;

    ---------------------------------------------------------------------------
    -- Meeting member save / edit
    ---------------------------------------------------------------------------
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MOpen,
        @MemberId = @Member1, @MemberTypeId = @CommitteeType, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Meeting member with a committee type refused', 'Result 0, Reason 13, ' + @CommitteeTypeName, Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MOpen,
        @MemberId = @Member1, @MemberTypeId = @TMOff, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Meeting member with an inactive meeting type refused', 'Result 0, Reason 13, ZZ21 Former guest', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MF,
        @MemberId = @Member1, @MemberTypeId = @CommitteeType, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Finalized minutes still refused first (step 15)', 'Result 0, Reason 1', Txt FROM @R;
    INSERT INTO @T SELECT 'No meeting member row saved by the refusals', '0',
           CAST(COUNT(*) AS VARCHAR(4)) FROM Meeting_Member WHERE MeetingId IN (@MOpen, @MF);

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MOpen,
        @MemberId = @Member1, @MemberTypeId = @TM, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    SET @MM = (SELECT MAX(MeetingMemberId) FROM Meeting_Member WHERE MeetingId = @MOpen);
    INSERT INTO @T SELECT 'Meeting member with an active meeting type saved', 'Result 1, Reason 0 / 1',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Meeting_Member WHERE MeetingMemberId = @MM AND MemberTypeId = @TM;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeetingMember @Code = 'Save', @MeetingMemberId = 0, @MeetingId = @MOpen,
        @MemberId = @Member2, @MemberTypeId = @InAttendance, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Meeting member as In Attendance (type 3) saved', 'Result 1, Reason 0', Txt FROM @R;

    UPDATE Member_Type SET StatusId = 0 WHERE MemberTypeId = @TM;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeetingMember @Code = 'Update', @MeetingMemberId = @MM, @MeetingId = @MOpen,
        @MemberId = @Member1, @MemberTypeId = @TM, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Meeting member edit keeping its (now inactive) type', 'Result 1, Reason 0', Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeetingMember @Code = 'Update', @MeetingMemberId = @MM, @MeetingId = @MOpen,
        @MemberId = @Member1, @MemberTypeId = @CommitteeType, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Meeting member edit to a committee type refused', 'Result 0, Reason 13, ' + @CommitteeTypeName, Txt FROM @R;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeetingMember @Code = 'Update', @MeetingMemberId = @MM, @MeetingId = @MOpen,
        @MemberId = @Member1, @MemberTypeId = @SpecialInvitee, @StatusId = 1, @CreatedOn = @Now, @CreatedBy = @Adm, @UpdatedOn = @Now, @UpdatedBy = @Adm;
    INSERT INTO @T SELECT 'Meeting member edit to Special Invitee (type 6)', 'Result 1, Reason 0', Txt FROM @R;
    UPDATE Meeting_Member SET MemberTypeId = @TM WHERE MeetingMemberId = @MM;
    UPDATE Member_Type SET StatusId = 1 WHERE MemberTypeId = @TM;

    ---------------------------------------------------------------------------
    -- Master list
    ---------------------------------------------------------------------------
    DELETE FROM @L; INSERT INTO @L EXEC spr_GetMemberType @StatusId = -1;
    INSERT INTO @T SELECT 'List: reserved type 3 not editable or deletable', 'Meeting 1 0 0',
           ISNULL((SELECT ScopeName + ' ' + CAST(IsReserved AS VARCHAR(1)) + ' ' + CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1))
                   FROM @L WHERE MemberTypeId = @InAttendance), 'none');
    INSERT INTO @T SELECT 'List: type in use editable, not deletable, with its count', 'Committee 0 1 0 1 0',
           ISNULL((SELECT ScopeName + ' ' + CAST(IsReserved AS VARCHAR(1)) + ' ' + CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1))
                   + ' ' + CAST(CommitteeUseCount AS VARCHAR(4)) + ' ' + CAST(MeetingUseCount AS VARCHAR(4)) FROM @L WHERE MemberTypeId = @TC), 'none');
    INSERT INTO @T SELECT 'List: unused free type deletable; status name', 'InActive 1 1',
           ISNULL((SELECT StatusName + ' ' + CAST(CanEdit AS VARCHAR(1)) + ' ' + CAST(CanDelete AS VARCHAR(1)) FROM @L WHERE MemberTypeId = @TOff), 'none');
    INSERT INTO @T SELECT 'List -1: every member type', CAST(COUNT(*) AS VARCHAR(4)), CAST((SELECT COUNT(*) FROM @L) AS VARCHAR(4)) FROM Member_Type;
    DELETE FROM @L; INSERT INTO @L EXEC spr_GetMemberType @StatusId = 1;
    INSERT INTO @T SELECT 'List 1: active types only', '0', CAST(COUNT(*) AS VARCHAR(4)) FROM @L WHERE StatusId <> 1;
    DELETE FROM @L; INSERT INTO @L EXEC spr_GetMemberTypeByMemberTypeId @MemberTypeId = @TM;
    INSERT INTO @T SELECT 'One type: code, name, scope, order, use count', 'ZZ21M|ZZ21 Observer|M|40|1',
           ISNULL((SELECT MemberTypeCode + '|' + MemberTypeName + '|' + MemberScope + '|' + CAST(DisplayOrder AS VARCHAR(12)) + '|' + CAST(MeetingUseCount AS VARCHAR(4)) FROM @L), 'none');

    ---------------------------------------------------------------------------
    -- Delete
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @TC, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Delete a type in use refused, with the counts', 'Result 0, Reason 5, 1 committee, 0 meeting', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @TM, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Delete a meeting type in use refused', 'Result 0, Reason 5, 0 committee, 1 meeting', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @SpecialInvitee, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Delete reserved type 6 refused', 'Result 0, Reason 7 / 1',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Member_Type WHERE MemberTypeId = @SpecialInvitee;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @TOff, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Delete by a Manager refused', 'Result 0, Reason 4', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @TOff, @ActingUserId = @AdmOff;
    INSERT INTO @T SELECT 'Delete by an inactive Admin refused', 'Result 0, Reason 8', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @TOff;
    INSERT INTO @T SELECT 'Delete by the older build (no acting user) refused', 'Result 0, Reason 8 / 1',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Member_Type WHERE MemberTypeId = @TOff;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @Missing, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Delete of a type that does not exist', 'Result 0, Reason 3, NotFound', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @TOff, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Admin deletes an unused free type', 'Result 1, Reason 0 / 0',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Member_Type WHERE MemberTypeId = @TOff;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @TMOff, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Controller deletes an unused free type', 'Result 1, Reason 0 / 0',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Member_Type WHERE MemberTypeId = @TMOff;

    ---------------------------------------------------------------------------
    -- Reset Database seed (procedure text; BMMS-Test-ResetDatabase.sql runs it)
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Reset Database seeds scope, order and reserved flag for the 6 types', '6',
           CAST((CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%''Member'', ''Member'', 1, 1, ''C'', 1, 0,%' THEN 1 ELSE 0 END)
              + (CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%''Invitee'', ''Invitee'', 1, 1, ''M'', 2, 1,%' THEN 1 ELSE 0 END)
              + (CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%''InAttendance'', ''In Attendance'', 1, 1, ''M'', 3, 1,%' THEN 1 ELSE 0 END)
              + (CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%''Chairman'', ''Chairman'', 1, 1, ''C'', 4, 0,%' THEN 1 ELSE 0 END)
              + (CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%''MD'', ''Managing Director'', 1, 1, ''C'', 5, 0,%' THEN 1 ELSE 0 END)
              + (CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')) LIKE '%''Special Invitee'', ''Special Invitee'', 1, 1, ''M'', 6, 1,%' THEN 1 ELSE 0 END) AS VARCHAR(4));

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
       SUM(CASE WHEN Actual <> 'SKIPPED' AND (Actual <> Expected OR Actual IS NULL) THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM @T;

-- Confirm nothing was kept: should be 0, 0 and 0
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz21%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Member_Type WHERE MemberTypeCode LIKE 'ZZ21%' OR MemberTypeCode LIKE 'qqq%') AS TestMemberTypesLeft,
       (SELECT COUNT(*) FROM Meeting WHERE MeetingNo LIKE 'ZZ21%') AS TestMeetingsLeft;
GO

SET NOEXEC OFF;
GO
