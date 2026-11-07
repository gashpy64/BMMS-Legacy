/* ============================================================================
   BMMS - Tests for BMMS-Fix-UnicodeText-Step31.sql (step 31)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-UnicodeText-Step31.sql, on the TEST COPY. It stops if
   step 31 is not installed.

   Creates its own committee, department, three users (a Controller, a
   Manager and a user of that Manager) and an open meeting, and checks,
   through the real procedures, with made-up sample values only:
     * the marker on the 7 procedures and the older texts they keep
     * the 13 columns: NVARCHAR(MAX), collation and NULL unchanged; no
       VARCHAR text column left in the four views
     * the 31 text parameters NVARCHAR(MAX), every parameter list unchanged
     * a round trip of the rupee sign, a Tamil word and a Hindi word through
       every save procedure (agenda add and edit by a user, a Manager and the
       Controller, Manager and Controller approval comments, the short text
       of the minutes page, Update Minutes Directions / Actual Resolution /
       All, the action item text and actual resolution), read back from the
       tables, the views and the minutes report procedure
     * text of about 50,000 characters kept whole
     * the audit trail keeps the Unicode text; a Proposed Resolution change is
       labelled 'ProposedResolution'; the Audit Trail report does not filter
       on the field name
     * no procedure returns one of these text columns as VARCHAR
   The test text is built with NCHAR(), so this file is plain ASCII and is
   read the same way by every editor.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateActionItem')), '') NOT LIKE '%UnicodeText-Step31%')
BEGIN
    RAISERROR('Step 31 (Unicode text) is not installed in "%s". Run BMMS-Fix-UnicodeText-Step31.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF (OBJECT_ID('tempdb..#U31VM') IS NOT NULL)
    DROP TABLE #U31VM;

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))));

-- The sample text: the rupee sign, a Tamil word (vanakkam) and a Hindi word (namaste), by code point
DECLARE @Rupee NVARCHAR(20) = NCHAR(8377) + N' 1,250';
DECLARE @Tamil NVARCHAR(20) = NCHAR(2997) + NCHAR(2979) + NCHAR(2965) + NCHAR(3021) + NCHAR(2965) + NCHAR(2990) + NCHAR(3021);
DECLARE @Hindi NVARCHAR(20) = NCHAR(2344) + NCHAR(2350) + NCHAR(2360) + NCHAR(2381) + NCHAR(2340) + NCHAR(2375);
DECLARE @U NVARCHAR(200) = @Rupee + N' ' + @Tamil + N' ' + @Hindi;
DECLARE @U2 NVARCHAR(200) = @U + N' (2)';
DECLARE @U3 NVARCHAR(200) = @U + N' (3)';
DECLARE @Long NVARCHAR(MAX) = REPLICATE(CAST(@U + N' ' AS NVARCHAR(MAX)), 2200);
DECLARE @LongLen VARCHAR(12) = CAST(LEN(@Long) AS VARCHAR(12));
DECLARE @E VARCHAR(10) = '';

DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -3, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @MgrRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @UserRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DecisionOther INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);
DECLARE @HasAction INT = (SELECT COUNT(*) FROM Decision_Type WHERE DecisionTypeId = 1);
DECLARE @C INT, @Dept INT, @Ctl INT, @Mgr INT, @Usr INT, @Mt INT;
DECLARE @AgA INT, @AgB INT, @AgC INT, @MinA INT, @AiA INT;
DECLARE @AgendaNoA VARCHAR(50), @AgendaNoC VARCHAR(50);
DECLARE @Count INT, @Text VARCHAR(400), @Lost NVARCHAR(200), @Def NVARCHAR(MAX);

IF (@Sys IS NULL OR @CtrlRoleId IS NULL OR @MgrRoleId IS NULL OR @UserRoleId IS NULL OR @DesignationId IS NULL
    OR @SubjectTypeId IS NULL OR @DecisionOther IS NULL OR @HasAction = 0)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, a subject type or the decision types (1 and another) are missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

---------------------------------------------------------------------------
-- 1. Installation
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'Marker on the 7 procedures (UnicodeText-Step31)', '7',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_AddEditAgenda'), ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditAgendaByManager'),
             ('spr_AddEditAgendaByController'), ('spr_UpdateAgendaShortText'), ('spr_UpdateMinutes'), ('spr_UpdateActionItem')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UnicodeText-Step31%') AS VARCHAR(12));
INSERT INTO @T SELECT 'spr_AddEditAgenda and spr_UpdateAgendaByAgendaId keep the texts of steps 16, 17, 18 and 20', '2',
       CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'))
             AND definition LIKE '%MeetingLocks-Step16%' AND definition LIKE '%UserStatus2b-Step17%'
             AND definition LIKE '%SystemAccount3-Step18%' AND definition LIKE '%AgendaRouting-Step20%') AS VARCHAR(12));
INSERT INTO @T SELECT 'spr_AddEditAgendaByManager and ByController keep the texts of steps 16, 17 and 18', '2',
       CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN (OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'))
             AND definition LIKE '%MeetingLocks-Step16%' AND definition LIKE '%UserStatus2b-Step17%' AND definition LIKE '%SystemAccount3-Step18%') AS VARCHAR(12));
INSERT INTO @T SELECT 'spr_UpdateAgendaShortText keeps steps 16 and 23; spr_UpdateMinutes keeps steps 6, 16, 17, 18 and 23', 'yes yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaShortText')) LIKE '%MeetingLocks-Step16%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaShortText')) LIKE '%WorkflowOrder-Step23%' THEN 'yes' ELSE 'no' END + ' '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%FK #5%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%MeetingLocks-Step16%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%UserStatus2b-Step17%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%SystemAccount3-Step18%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%WorkflowOrder-Step23%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'Proposed Resolution audit label: no add / edit procedure writes it as ''ShortText'' any more', '0 3',
       CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE definition LIKE '%''ShortText'', @ProposedResolutionOld%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE definition LIKE '%''ProposedResolution'', @ProposedResolutionOld%'
             AND object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'))) AS VARCHAR(12));

-- Columns
INSERT INTO @T SELECT 'The 13 columns are NVARCHAR(MAX)', '13',
       CAST((SELECT COUNT(*) FROM sys.columns sc JOIN sys.types t ON t.user_type_id = sc.user_type_id
             WHERE t.name = 'nvarchar' AND sc.max_length = -1
             AND ((sc.object_id = OBJECT_ID('dbo.Agenda') AND sc.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments'))
               OR (sc.object_id = OBJECT_ID('dbo.Minutes') AND sc.name IN ('Directions', 'ActualResolution'))
               OR (sc.object_id = OBJECT_ID('dbo.Action_Item') AND sc.name IN ('Directions', 'ActionText'))
               OR (sc.object_id = OBJECT_ID('dbo.Audit_Trail_Master') AND sc.name IN ('Old_Value', 'New_Value')))) AS VARCHAR(12));
INSERT INTO @T SELECT 'Their collation is the one of Agenda.AgendaNo (unchanged column)', '13',
       CAST((SELECT COUNT(*) FROM sys.columns sc
             WHERE sc.collation_name = (SELECT collation_name FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Agenda') AND name = 'AgendaNo')
             AND ((sc.object_id = OBJECT_ID('dbo.Agenda') AND sc.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments'))
               OR (sc.object_id = OBJECT_ID('dbo.Minutes') AND sc.name IN ('Directions', 'ActualResolution'))
               OR (sc.object_id = OBJECT_ID('dbo.Action_Item') AND sc.name IN ('Directions', 'ActionText'))
               OR (sc.object_id = OBJECT_ID('dbo.Audit_Trail_Master') AND sc.name IN ('Old_Value', 'New_Value')))) AS VARCHAR(12));
INSERT INTO @T SELECT 'The 11 agenda and minutes columns still allow NULL (as before)', '11',
       CAST((SELECT COUNT(*) FROM sys.columns sc WHERE sc.is_nullable = 1
             AND ((sc.object_id = OBJECT_ID('dbo.Agenda') AND sc.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments'))
               OR (sc.object_id = OBJECT_ID('dbo.Minutes') AND sc.name IN ('Directions', 'ActualResolution'))
               OR (sc.object_id = OBJECT_ID('dbo.Action_Item') AND sc.name IN ('Directions', 'ActionText')))) AS VARCHAR(12));
INSERT INTO @T SELECT 'No VARCHAR text column left in View_Agenda, View_Minute, View_Action_Item, View_Action_Item_Users', '0',
       CAST((SELECT COUNT(*) FROM sys.columns sc JOIN sys.types t ON t.user_type_id = sc.user_type_id
             WHERE sc.object_id IN (OBJECT_ID('dbo.View_Agenda'), OBJECT_ID('dbo.View_Minute'), OBJECT_ID('dbo.View_Action_Item'), OBJECT_ID('dbo.View_Action_Item_Users'))
             AND sc.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments',
                             'Directions', 'ActualResolution', 'ActionText')
             AND t.name <> 'nvarchar') AS VARCHAR(12));

-- Parameters
INSERT INTO @T SELECT 'The 31 text parameters of the 7 procedures are NVARCHAR(MAX), none other', '31 0',
       CAST(SUM(CASE WHEN t.name = 'nvarchar' AND p.max_length = -1 THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' '
     + CAST(SUM(CASE WHEN t.name = 'nvarchar' AND p.max_length = -1 THEN 0 ELSE 1 END) AS VARCHAR(12))
       FROM sys.parameters p JOIN sys.types t ON t.user_type_id = p.user_type_id
       WHERE p.object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'),
                             OBJECT_ID('dbo.spr_AddEditAgendaByController'), OBJECT_ID('dbo.spr_UpdateAgendaShortText'), OBJECT_ID('dbo.spr_UpdateMinutes'),
                             OBJECT_ID('dbo.spr_UpdateActionItem'))
       AND p.name IN ('@ShortText', '@AgendaText', '@AgendaTextPath', '@ProposedResolution', '@FilePath', '@MgrComments', '@ControllerComments',
                      '@Directions', '@ActualResolution', '@ActionText');
INSERT INTO @T SELECT 'Parameter counts unchanged; no output parameter',
       'spr_AddEditAgenda 22; spr_AddEditAgendaByController 22; spr_AddEditAgendaByManager 22; spr_UpdateActionItem 6; spr_UpdateAgendaByAgendaId 8; spr_UpdateAgendaShortText 3; spr_UpdateMinutes 8; outputs 0',
       ISNULL(STUFF((SELECT '; ' + OBJECT_NAME(p.object_id) + ' ' + CAST(COUNT(*) AS VARCHAR(4))
                     FROM sys.parameters p
                     WHERE p.object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'),
                                           OBJECT_ID('dbo.spr_AddEditAgendaByController'), OBJECT_ID('dbo.spr_UpdateAgendaShortText'), OBJECT_ID('dbo.spr_UpdateMinutes'),
                                           OBJECT_ID('dbo.spr_UpdateActionItem'))
                     GROUP BY p.object_id ORDER BY OBJECT_NAME(p.object_id)
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 2, ''), 'none')
     + '; outputs ' + CAST((SELECT COUNT(*) FROM sys.parameters WHERE is_output = 1 AND object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'),
             OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'), OBJECT_ID('dbo.spr_UpdateAgendaShortText'),
             OBJECT_ID('dbo.spr_UpdateMinutes'), OBJECT_ID('dbo.spr_UpdateActionItem'))) AS VARCHAR(4));
INSERT INTO @T SELECT 'spr_AddEditAgenda parameter names in order', '@Code,@AgendaId,@AgendaNo,@CommitteeId,@MeetingId,@DepartmentId,@SubjectTypeId,@ShortText,@AgendaType,@AgendaText,@AgendaTextPath,@ProposedResolution,@FilePath,@MgrComments,@ControllerComments,@CurrentStatus,@CreatedOn,@CreatedBy,@UpdatedOn,@UpdatedBy,@SubjectNo,@ActingUserId',
       ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgenda') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
INSERT INTO @T SELECT 'spr_AddEditAgendaByManager and ByController: the same names in the same order', 'same same',
       CASE WHEN ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgendaByManager') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'x')
               = ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgenda') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'y') THEN 'same' ELSE 'different' END + ' '
     + CASE WHEN ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgendaByController') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'x')
               = ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgenda') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'y') THEN 'same' ELSE 'different' END;
INSERT INTO @T SELECT 'spr_UpdateAgendaByAgendaId, spr_UpdateAgendaShortText, spr_UpdateMinutes, spr_UpdateActionItem parameter names in order',
       '@AgendaId,@ShortText,@ProposedResolution,@MgrComments,@ControllerComments,@ControllerApprovedStatus,@MgrApprovedStatus,@UpdatedBy | @AgendaId,@ShortText,@UpdatedBy | @Code,@MinutesId,@DecisionTypeId,@Directions,@ActualResolution,@ShortText,@CreatedBy,@UpdatedBy | @Code,@ActionItemId,@ActualResolution,@ActionText,@IsComplied,@IsConfirmed',
       ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none') + ' | '
     + ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateAgendaShortText') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none') + ' | '
     + ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateMinutes') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none') + ' | '
     + ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateActionItem') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');

-- Reading procedures: none may hand one of these texts back as VARCHAR (it would turn the letters into ?)
SELECT @Text = ISNULL(STUFF((SELECT DISTINCT ', ' + o.name + '.' + r.name
                             FROM sys.procedures o
                             CROSS APPLY sys.dm_exec_describe_first_result_set_for_object(o.object_id, 0) r
                             WHERE o.is_ms_shipped = 0 AND r.error_number IS NULL
                             AND r.name IN ('ShortText', 'AgendaText', 'AgendaTextPath', 'ProposedResolution', 'FilePath', 'MgrComments', 'ControllerComments',
                                            'Directions', 'ActualResolution', 'ActionText')
                             AND r.system_type_name NOT LIKE 'nvarchar%' AND r.system_type_name NOT LIKE 'ntext%'
                             FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 2, ''), 'none');
INSERT INTO @T SELECT 'No procedure returns one of the text columns as VARCHAR', 'none', @Text;

SET @Def = ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAuditTrailMasterByUserId')), '');
INSERT INTO @T SELECT 'The Audit Trail report procedure does not filter on a field name (the label change cannot hide rows)', 'yes',
       CASE WHEN @Def = '' THEN 'procedure missing'
            WHEN @Def LIKE '%''ShortText''%' OR @Def LIKE '%''ProposedResolution''%' THEN 'no: it names one of the two labels'
            ELSE 'yes' END;

-- Why the step is needed: a VARCHAR copy of the sample text loses its letters
SET @Lost = CAST(CAST(@U AS VARCHAR(200)) AS NVARCHAR(200));
INSERT INTO @T SELECT 'A VARCHAR copy of the sample text is not the text (what happened before step 31)', 'lost',
       CASE WHEN @Lost COLLATE Latin1_General_BIN2 = @U COLLATE Latin1_General_BIN2 THEN 'kept' ELSE 'lost' END;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names). The meeting has no CreatedOn: it counts as older than step 23, so the
    -- minutes can be updated without attendance
    ---------------------------------------------------------------------------
    -- Own committee with a three-letter code: the agenda number is read by position
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z31', 'ZZ step 31 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ31', 'ZZ step 31 department', 999, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ31 controller', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz31ctl@example.invalid', 'zz31ctl', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ31 manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz31mgr@example.invalid', 'zz31mgr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ31 user', @Dept, @DesignationId, @Mgr, @UserRoleId, 'zz31usr@example.invalid', 'zz31usr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Usr = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99931', @C, 'ZZ31 test', 'ZZ', @Past, '10:00', @Past, 'Open', 'Open');
    SET @Mt = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- 2. Agenda: a user's item, saved and edited (spr_AddEditAgenda)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = @U, @AgendaType = 'Entry', @AgendaText = @U, @AgendaTextPath = @U,
         @ProposedResolution = @U, @FilePath = @U, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @AgA = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr);
    SET @AgendaNoA = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgA);
    INSERT INTO @T SELECT 'User saves an item (spr_AddEditAgenda): result, status', 'Result 1, Reason 0; AC',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgA), 'none');
    INSERT INTO @T SELECT 'User save: Short Text, Agenda Text, file name, Proposed Resolution, attachment list kept (table)', '5',
           CAST((SELECT CASE WHEN ShortText COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN AgendaText COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                      + CASE WHEN AgendaTextPath COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN ProposedResolution COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                      + CASE WHEN FilePath COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                 FROM Agenda WHERE AgendaId = @AgA) AS VARCHAR(4));
    INSERT INTO @T SELECT 'User save: the same five through View_Agenda', '5',
           CAST((SELECT CASE WHEN ShortText COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN AgendaText COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                      + CASE WHEN AgendaTextPath COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN ProposedResolution COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                      + CASE WHEN FilePath COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                 FROM View_Agenda WHERE AgendaId = @AgA) AS VARCHAR(4));
    INSERT INTO @T SELECT 'User save: the audit trail keeps the Short Text and the Proposed Resolution', '1 1',
           CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA AND Audit_Type = 'IN'
                 AND Field_Name = 'ShortText' AND New_Value COLLATE Latin1_General_BIN2 = @U) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA AND Audit_Type = 'IN'
                 AND Field_Name = 'ProposedResolution' AND New_Value COLLATE Latin1_General_BIN2 = @U) AS VARCHAR(4));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @AgendaNoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = @U2, @AgendaType = 'Entry', @AgendaText = @Long, @AgendaTextPath = @U,
         @ProposedResolution = @U3, @FilePath = @U, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'User edits the item: result; Short Text and Proposed Resolution changed', 'Result 1, Reason 0; same same',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT CASE WHEN ShortText COLLATE Latin1_General_BIN2 = @U2 THEN 'same' ELSE 'different' END + ' '
                        + CASE WHEN ProposedResolution COLLATE Latin1_General_BIN2 = @U3 THEN 'same' ELSE 'different' END
                   FROM Agenda WHERE AgendaId = @AgA), 'none');
    INSERT INTO @T SELECT 'User edit: an Agenda Text of about 50,000 characters is kept whole', @LongLen + ' same',
           ISNULL((SELECT CAST(LEN(AgendaText) AS VARCHAR(12)) + ' ' + CASE WHEN AgendaText COLLATE Latin1_General_BIN2 = @Long THEN 'same' ELSE 'different' END
                   FROM Agenda WHERE AgendaId = @AgA), 'none');
    INSERT INTO @T SELECT 'User edit: the Proposed Resolution change is audited as ProposedResolution, old and new text kept', '1',
           CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA AND Audit_Type = 'UP'
                 AND Field_Name = 'ProposedResolution' AND Old_Value COLLATE Latin1_General_BIN2 = @U AND New_Value COLLATE Latin1_General_BIN2 = @U3) AS VARCHAR(4));
    INSERT INTO @T SELECT 'User edit: the Short Text change is still audited as ShortText; no ShortText row holds the Proposed Resolution', '1 0',
           CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA AND Audit_Type = 'UP'
                 AND Field_Name = 'ShortText' AND Old_Value COLLATE Latin1_General_BIN2 = @U AND New_Value COLLATE Latin1_General_BIN2 = @U2) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA AND Audit_Type = 'UP'
                 AND Field_Name = 'ShortText' AND New_Value COLLATE Latin1_General_BIN2 = @U3) AS VARCHAR(4));
    INSERT INTO @T SELECT 'User edit: the audit trail keeps the 50,000-character Agenda Text whole', '1',
           CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA AND Audit_Type = 'UP'
                 AND Field_Name = 'AgendaText' AND New_Value COLLATE Latin1_General_BIN2 = @Long) AS VARCHAR(4));

    ---------------------------------------------------------------------------
    -- 3. Approval comments (spr_UpdateAgendaByAgendaId): the Manager at AC, the Controller at AMA
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = @U2, @ProposedResolution = @U3,
         @MgrComments = @U, @ControllerComments = @E, @ControllerApprovedStatus = @E, @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    INSERT INTO @T SELECT 'Manager approves with a comment: result, status, comment kept', 'Result 1, Reason 0; AMA; same',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT AgendaStatusCode + '; ' + CASE WHEN MgrComments COLLATE Latin1_General_BIN2 = @U THEN 'same' ELSE 'different' END
                   FROM Agenda WHERE AgendaId = @AgA), 'none');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = @U2, @ProposedResolution = @U3,
         @MgrComments = @U, @ControllerComments = @U3, @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = @E, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Controller approves with a comment: result, status, both comments kept (table and View_Agenda)', 'Result 1, Reason 0; ACA; same same; same same',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT AgendaStatusCode + '; ' + CASE WHEN MgrComments COLLATE Latin1_General_BIN2 = @U THEN 'same' ELSE 'different' END + ' '
                        + CASE WHEN ControllerComments COLLATE Latin1_General_BIN2 = @U3 THEN 'same' ELSE 'different' END
                   FROM Agenda WHERE AgendaId = @AgA), 'none') + '; '
         + ISNULL((SELECT CASE WHEN MgrComments COLLATE Latin1_General_BIN2 = @U THEN 'same' ELSE 'different' END + ' '
                        + CASE WHEN ControllerComments COLLATE Latin1_General_BIN2 = @U3 THEN 'same' ELSE 'different' END
                   FROM View_Agenda WHERE AgendaId = @AgA), 'none');
    INSERT INTO @T SELECT 'Approval comments: the audit trail keeps both texts', '1 1',
           CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA
                 AND Field_Name = 'MgrComments' AND New_Value COLLATE Latin1_General_BIN2 = @U) AS VARCHAR(4)) + ' '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA
                 AND Field_Name = 'ControllerComments' AND New_Value COLLATE Latin1_General_BIN2 = @U3) AS VARCHAR(4));

    ---------------------------------------------------------------------------
    -- 4. A Manager's own item and a Controller's item (spr_AddEditAgendaByManager / ByController)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = @U, @AgendaType = 'Entry', @AgendaText = @U, @AgendaTextPath = @U,
         @ProposedResolution = @U, @FilePath = @U, @MgrComments = @U, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @AgB = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Mgr);
    INSERT INTO @T SELECT 'Manager saves an item (ByManager): result; six texts kept (Short Text ... Manager Comments)', 'Result 1, Reason 0; 6',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT CAST(CASE WHEN ShortText COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN AgendaText COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                        + CASE WHEN AgendaTextPath COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN ProposedResolution COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                        + CASE WHEN FilePath COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN MgrComments COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END AS VARCHAR(4))
                   FROM Agenda WHERE AgendaId = @AgB), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = @U, @AgendaType = 'Entry', @AgendaText = @U, @AgendaTextPath = @U,
         @ProposedResolution = @U, @FilePath = @U, @MgrComments = @E, @ControllerComments = @U, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    SET @AgC = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Ctl);
    SET @AgendaNoC = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgC);
    INSERT INTO @T SELECT 'Controller saves an item (ByController): result; six texts kept (Short Text ... Controller Comments)', 'Result 1, Reason 0; 6',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT CAST(CASE WHEN ShortText COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN AgendaText COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                        + CASE WHEN AgendaTextPath COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN ProposedResolution COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                        + CASE WHEN FilePath COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END + CASE WHEN ControllerComments COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END AS VARCHAR(4))
                   FROM Agenda WHERE AgendaId = @AgC), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgC, @AgendaNo = @AgendaNoC, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = @U, @AgendaType = 'Entry', @AgendaText = @U, @AgendaTextPath = @U,
         @ProposedResolution = @U3, @FilePath = @U, @MgrComments = @E, @ControllerComments = @U, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Controller edits the Proposed Resolution: result; kept; audited as ProposedResolution', 'Result 1, Reason 0; same; 1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT CASE WHEN ProposedResolution COLLATE Latin1_General_BIN2 = @U3 THEN 'same' ELSE 'different' END FROM Agenda WHERE AgendaId = @AgC), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoC AND Audit_Type = 'UP'
                 AND Field_Name = 'ProposedResolution' AND Old_Value COLLATE Latin1_General_BIN2 = @U AND New_Value COLLATE Latin1_General_BIN2 = @U3) AS VARCHAR(4));

    ---------------------------------------------------------------------------
    -- 5. The minutes page: short text, Directions, Actual Resolution, All (spr_UpdateAgendaShortText, spr_UpdateMinutes)
    ---------------------------------------------------------------------------
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, StatusId, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgA, @DecisionOther, ' ', 'ZZ', 0, @Now, @Sys, @Now, @Sys);
    SET @MinA = SCOPE_IDENTITY();

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaShortText @AgendaId = @AgA, @ShortText = @U3, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Short text on the minutes page (spr_UpdateAgendaShortText): result; kept; audited', 'Result 1, Reason 0; same; 1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT CASE WHEN ShortText COLLATE Latin1_General_BIN2 = @U3 THEN 'same' ELSE 'different' END FROM Agenda WHERE AgendaId = @AgA), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Table = 'Agenda' AND Key_Value = @AgendaNoA AND Audit_Type = 'UP'
                 AND Field_Name = 'ShortText' AND Old_Value COLLATE Latin1_General_BIN2 = @U2 AND New_Value COLLATE Latin1_General_BIN2 = @U3) AS VARCHAR(4));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @MinA, @DecisionTypeId = @DecisionOther,
        @Directions = @U, @ActualResolution = @E, @ShortText = @E, @CreatedBy = @Ctl, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Update Minutes, Directions: result; kept', 'Result 1, Reason 0; same',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT CASE WHEN Directions COLLATE Latin1_General_BIN2 = @U THEN 'same' ELSE 'different' END FROM Minutes WHERE MinutesId = @MinA), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'ActualResolution', @MinutesId = @MinA, @DecisionTypeId = @DecisionOther,
        @Directions = @E, @ActualResolution = @Long, @ShortText = @E, @CreatedBy = @Ctl, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Update Minutes, Actual Resolution of about 50,000 characters: result; kept whole in the minute and copied to the agenda', 'Result 1, Reason 0; same same',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT CASE WHEN ActualResolution COLLATE Latin1_General_BIN2 = @Long THEN 'same' ELSE 'different' END FROM Minutes WHERE MinutesId = @MinA), 'none') + ' '
         + ISNULL((SELECT CASE WHEN ProposedResolution COLLATE Latin1_General_BIN2 = @Long THEN 'same' ELSE 'different' END FROM Agenda WHERE AgendaId = @AgA), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @MinA, @DecisionTypeId = 1,
        @Directions = @E, @ActualResolution = @E, @ShortText = @U2, @CreatedBy = @Ctl, @UpdatedBy = @Ctl;
    SET @AiA = (SELECT MAX(ActionItemId) FROM Action_Item WHERE MinutesId = @MinA);
    INSERT INTO @T SELECT 'Update Minutes, All (action item): result; short text kept; the new action item has the Directions', 'Result 1, Reason 0; same; same',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + ISNULL((SELECT CASE WHEN ShortText COLLATE Latin1_General_BIN2 = @U2 THEN 'same' ELSE 'different' END FROM Agenda WHERE AgendaId = @AgA), 'none') + '; '
         + ISNULL((SELECT CASE WHEN Directions COLLATE Latin1_General_BIN2 = @U THEN 'same' ELSE 'different' END FROM Action_Item WHERE ActionItemId = @AiA), 'none');

    ---------------------------------------------------------------------------
    -- 6. The action item (spr_UpdateActionItem)
    ---------------------------------------------------------------------------
    EXEC spr_UpdateActionItem @Code = 'ActionText', @ActionItemId = @AiA, @ActualResolution = @E, @ActionText = @U3, @IsComplied = 0, @IsConfirmed = 0;
    EXEC spr_UpdateActionItem @Code = 'ActualResolution', @ActionItemId = @AiA, @ActualResolution = @U2, @ActionText = @E, @IsComplied = 0, @IsConfirmed = 0;
    INSERT INTO @T SELECT 'Action item: the action text and the actual resolution (in the minute) kept', 'same same',
           ISNULL((SELECT CASE WHEN ActionText COLLATE Latin1_General_BIN2 = @U3 THEN 'same' ELSE 'different' END FROM Action_Item WHERE ActionItemId = @AiA), 'none') + ' '
         + ISNULL((SELECT CASE WHEN ActualResolution COLLATE Latin1_General_BIN2 = @U2 THEN 'same' ELSE 'different' END FROM Minutes WHERE MinutesId = @MinA), 'none');

    ---------------------------------------------------------------------------
    -- 7. Reading back through the views and the minutes report
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'View_Minute returns the five texts exactly as the tables hold them', '5',
           ISNULL((SELECT CAST(CASE WHEN v.Directions COLLATE Latin1_General_BIN2 = m.Directions THEN 1 ELSE 0 END
                             + CASE WHEN v.ActualResolution COLLATE Latin1_General_BIN2 = m.ActualResolution THEN 1 ELSE 0 END
                             + CASE WHEN v.ShortText COLLATE Latin1_General_BIN2 = a.ShortText THEN 1 ELSE 0 END
                             + CASE WHEN v.AgendaText COLLATE Latin1_General_BIN2 = a.AgendaText THEN 1 ELSE 0 END
                             + CASE WHEN v.ProposedResolution COLLATE Latin1_General_BIN2 = a.ProposedResolution THEN 1 ELSE 0 END AS VARCHAR(4))
                   FROM View_Minute v JOIN Minutes m ON m.MinutesId = v.MinutesId JOIN Agenda a ON a.AgendaId = v.AgendaId
                   WHERE v.MinutesId = @MinA), 'none');
    INSERT INTO @T SELECT 'View_Action_Item returns the action text, directions, actual resolution, short text and proposed resolution', '5',
           ISNULL((SELECT CAST(CASE WHEN v.ActionText COLLATE Latin1_General_BIN2 = @U3 THEN 1 ELSE 0 END
                             + CASE WHEN v.Directions COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                             + CASE WHEN v.ActualResolution COLLATE Latin1_General_BIN2 = @U2 THEN 1 ELSE 0 END
                             + CASE WHEN v.ShortText COLLATE Latin1_General_BIN2 = @U2 THEN 1 ELSE 0 END
                             + CASE WHEN v.ProposedResolution COLLATE Latin1_General_BIN2 = @Long THEN 1 ELSE 0 END AS VARCHAR(4))
                   FROM View_Action_Item v WHERE v.ActionItemId = @AiA), 'none');
    INSERT INTO @T SELECT 'View_Action_Item_Users (the item of the agenda creator) returns the three texts', '3',
           ISNULL((SELECT TOP 1 CAST(CASE WHEN v.ActionText COLLATE Latin1_General_BIN2 = @U3 THEN 1 ELSE 0 END
                                   + CASE WHEN v.Directions COLLATE Latin1_General_BIN2 = @U THEN 1 ELSE 0 END
                                   + CASE WHEN v.ActualResolution COLLATE Latin1_General_BIN2 = @U2 THEN 1 ELSE 0 END AS VARCHAR(4))
                   FROM View_Action_Item_Users v WHERE v.ActionItemId = @AiA AND v.UserId = @Usr), 'none');

    -- The minutes report lists finalized minutes only (step 22): mark this meeting's minutes finalized
    UPDATE Meeting SET MinutesStatus = 'F' WHERE MeetingId = @Mt;
    -- (UNION ALL: the copy must not inherit the identity of MinutesId)
    SELECT TOP 0 * INTO #U31VM FROM View_Minute UNION ALL SELECT TOP 0 * FROM View_Minute;
    INSERT INTO #U31VM EXEC spr_GetMinutesReport @CommitteeId = @C, @DepartmentId = 0, @MeetingNoSearch = 0, @MeetingId = @Mt,
         @FromMeetingId = 0, @ToMeetingId = 0, @SubjectNoSearch = 0, @FromSubjectNo = 0, @ToSubjectNo = 0;
    INSERT INTO @T SELECT 'Minutes report (spr_GetMinutesReport): the minute with its actual resolution and short text', '1 same same',
           CAST((SELECT COUNT(*) FROM #U31VM WHERE MinutesId = @MinA) AS VARCHAR(4)) + ' '
         + ISNULL((SELECT TOP 1 CASE WHEN ActualResolution COLLATE Latin1_General_BIN2 = @U2 THEN 'same' ELSE 'different' END + ' '
                               + CASE WHEN ShortText COLLATE Latin1_General_BIN2 = @U2 THEN 'same' ELSE 'different' END
                   FROM #U31VM WHERE MinutesId = @MinA), 'none');

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

Report:

IF (OBJECT_ID('tempdb..#U31VM') IS NOT NULL)
    DROP TABLE #U31VM;

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

-- Confirm nothing was kept: should be 0, 0, 0 and 0
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz31%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Meeting WHERE MeetingNo = '99931' AND Place = 'ZZ31 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode = 'ZZ31') AS TestDepartmentsLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z31' AND CommitteeName = 'ZZ step 31 committee') AS TestCommitteesLeft;
GO

SET NOEXEC OFF;
GO
