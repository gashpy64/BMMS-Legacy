/* ============================================================================
   BMMS - Lists for Managers with several departments (step 54, step UD1c)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decisions 2026-11-24 (requirement UD1c, plan approved with twelve
   answers):
     R1 "A Manager's departments" are the departments of which he is an
        active Manager by fn_DepartmentManagers (step 53): fn_ManagerDepartments.
        A User: his own department. The Controller: every department.
     R2 Agenda Entry list of a Manager: the items of his departments (a
        Department filter, "All my departments" first) and the items he
        entered. The server checks Edit and Update again; an Update never
        changes the department, the status or the creator.
     R3 A Manager's new item: only in an active department of his (Reason 30,
        "Not saved: you are not a Manager of that department.", nothing saved).
     R4 The Reporting Person of a user: an active Controller or an active
        Manager of the user's department, never the user himself; none stays
        allowed (Reason 31, on Create and on every Update).
     R5 Agenda Summary, Agenda Details, Minutes and Minutes Extract read
        procedures with the acting user: the Controller every department, a
        Manager his departments only (a department outside them: Reason 4).
     6  A Manager's new item also alerts the other Managers of its department.

   Objects (each carries the text ManagerScope-Step54; a replaced text keeps
   the markers of its earlier steps)
     fn_ManagerDepartments            NEW
     fn_ReportingPersonAllowed        NEW
     spr_GetManagerDepartments        NEW (the drop-downs)
     spr_GetReportingPersonList       NEW (User Master; replaces the call of
                                      spr_GetMgrControllerByDeptId, which is
                                      kept unchanged)
     spr_GetAgendaReport              NEW (Agenda Summary and Details; the SQL
                                      text the page built is gone)
     spr_GetMinutesReportByUser       NEW (Minutes, Minutes Extract;
                                      spr_GetMinutesReport kept unchanged)
     spr_GetReportSubjectNos          NEW (the subject number lists;
                                      spr_GetMinutesByMeetingId kept unchanged)
     spr_GetAgendaByMeetingIdDeptId   REPLACED (step 33): R1 and @DepartmentId
     spr_AddEditAgendaByManager       REPLACED (step 53): Reason 30; the alert
     spr_AddEditUser                  REPLACED (step 53): Reason 31
   No table, view, column or data change; nothing granted. The Dashboard is
   not changed: fn_UserDepartmentScope (step 42) gives an active Manager the
   same departments as fn_ManagerDepartments (checked by the Test script).

   Order: installed after step 53. Needs steps 33, 39, 52 and 53 and stops
   otherwise. The script was built from the three texts as installed
   (identical in BMMS_Test and BMMS_Quality on 2026-11-24; SHA-1 of the text
   without carriage returns, in pieces of 4,000 characters) and stops,
   changing nothing, when one of them is neither that text nor already the
   step 54 text (a later change would be lost). Safe to re-run.

   Re-run of an earlier step: the Fix and Rollback scripts of steps 33 and 53
   stop while step 54 is installed (guards added in step UD1c). The Fix
   scripts of steps 36, 37 and 52 and the Rollback scripts of steps 36, 37,
   39 and 52 already stop while step 53 is installed, which step 54 needs.
   A re-run of step 13, 16, 17, 18, 31 or 35 brings back an older text of
   spr_AddEditAgendaByManager or spr_AddEditUser: steps 53 and 54 read
   Partly; tell the Consultant (the way back is BMMS-Rollback-ManagerScope-
   Step54.sql, then the step 53 notes, then this script).

   BMMS-Rollback-ManagerScope-Step54.sql puts the three texts back letter for
   letter and drops the seven new objects. Roll back the build of step UD1c
   first or at the same time.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.
   QUOTED_IDENTIFIER and ANSI_NULLS must be ON (the filtered indexes of step
   39): the script sets them. From the command line use sqlcmd -I.
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
DECLARE @D NVARCHAR(MAX), @I INT;
DECLARE @H1 VARCHAR(400), @H2 VARCHAR(400), @H3 VARCHAR(400);
DECLARE @Texts TABLE (Name SYSNAME, Hash VARCHAR(400), BuiltFrom VARCHAR(400));
DECLARE @Bad SYSNAME;

-- The three objects as they are now
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingIdDeptId')), CHAR(13), ''); SET @H1 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H1 = @H1 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), CHAR(13), ''); SET @H2 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H2 = @H2 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), CHAR(13), ''); SET @H3 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H3 = @H3 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
INSERT INTO @Texts (Name, Hash, BuiltFrom) VALUES
('spr_GetAgendaByMeetingIdDeptId', @H1, '1BAFA47FC7840BA79D2EA4C77D54E5FCCEA46A56'),
('spr_AddEditAgendaByManager', @H2, '9396CDED616E66F8B0C27FFE1D1B33D7755166B22257D485D24285B525A823A86ACBF9C3095626BEB8EC55F4DFAA24402968958BB1A72EB53C9613038073C0062F7F85D95DDE8C22546A0B564A9FB153BA185301CCC8A8D91BA8BD8C6BF7257ABCCF93DA'),
('spr_AddEditUser', @H3, '29A619AF92BFE1F6E293CAF38C1A28C4E13675B3B5780357240390C14B6DD17CEE104CBC92FC9B235B2625160F54E9CAC1ED1CBC0375772779CCC08D20B4C35971FEB62EAFF5F44A9828BC37F98FCB3BCE27748BAB92EFF35704765A8F9BAAE28421F6ED');

-- A text that is neither the one this step was built from nor already the step 54 text
SET @Bad = (SELECT TOP 1 t.Name FROM @Texts t
            WHERE ISNULL(t.Hash, '') <> t.BuiltFrom
              AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + t.Name)), '') NOT LIKE '%ManagerScope-Step54%'
            ORDER BY t.Name);

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingIdDeptId')), '') NOT LIKE '%ManagerDepartment-Step33%')
BEGIN
    RAISERROR('Step 33 (BMMS-Fix-ManagerDepartment-Step33.sql) is not installed in "%s". The steps are installed in order: run steps 33 to 53 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.User_Department', 'U') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetDepartmentManagerRule')), '') NOT LIKE '%UserHistory-Step39%')
BEGIN
    RAISERROR('Step 39 (BMMS-Fix-UserHistory-Step39.sql) is not installed in "%s". Run steps 39 to 53 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%ManagerRelease-Step52%')
BEGIN
    RAISERROR('Step 52 (BMMS-Fix-ManagerRelease-Step52.sql) is not installed in "%s". Run steps 52 and 53 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_DepartmentManagers', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') NOT LIKE '%DepartmentApprovers-Step53%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%DepartmentApprovers-Step53%')
BEGIN
    RAISERROR('Step 53 (BMMS-Fix-DepartmentApprovers-Step53.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@Bad IS NOT NULL)
BEGIN
    RAISERROR('%s in "%s" is not the text this step was built from and not the step 54 text either: a change made since would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @Bad, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- A Manager's departments (ManagerScope-Step54, step UD1c)
-------------------------------------------------------------------------------
-- Every department D of which @UserId is an active Manager by fn_DepartmentManagers(D) (step 53), so the rule
-- "active Manager of department D" keeps one copy. No rows for a user who is not an active Manager (another role,
-- inactive, the protected system account). Inactive departments are included (Department.StatusId is not read
-- here): the callers decide. Agenda Entry (the list, Edit, Update and a new item) and the reports read it.
CREATE OR ALTER FUNCTION [dbo].[fn_ManagerDepartments]
(
@UserId INT
)
RETURNS TABLE
AS
RETURN
SELECT d.DepartmentId
FROM dbo.Department d
CROSS APPLY dbo.fn_DepartmentManagers(d.DepartmentId) m
WHERE m.UserId = @UserId;
GO

-------------------------------------------------------------------------------
-- Who may be a user's Reporting Person (ManagerScope-Step54, step UD1c)
-------------------------------------------------------------------------------
-- One row per allowed Reporting Person of a user whose (home) department is @DepartmentId: every active Controller
-- (not the protected system account) and every active Manager of @DepartmentId (fn_DepartmentManagers, step 53).
-- @UserId is the user himself (NULL or 0 for a new user): he is never his own Reporting Person. No Reporting Person
-- ("- Select -") is always allowed and has no row. spr_AddEditUser (Reason 31) and spr_GetReportingPersonList read it.
CREATE OR ALTER FUNCTION [dbo].[fn_ReportingPersonAllowed]
(
@DepartmentId INT,
@UserId INT
)
RETURNS TABLE
AS
RETURN
SELECT c.UserId
FROM dbo.Users c
INNER JOIN dbo.Roles cr ON cr.RoleId = c.RoleId
WHERE cr.RoleCode = 'controller'
  AND c.AccountStatus = 1
  AND c.IsSystem = 0
  AND c.UserId <> ISNULL(@UserId, 0)
UNION
SELECT m.UserId
FROM dbo.fn_DepartmentManagers(@DepartmentId) m
WHERE m.UserId <> ISNULL(@UserId, 0);
GO

-------------------------------------------------------------------------------
-- The departments of the acting Manager, for the drop-downs (ManagerScope-Step54, step UD1c)
-------------------------------------------------------------------------------
-- The rows of fn_ManagerDepartments for @ActingUserId with the name, IsHome (the home department, Users.DepartmentId)
-- and IsActive (Department.StatusId 1); the home department first, then by name. Agenda Entry lists every row in its
-- filter and the active ones for a new item; the reports list every row. Reason 8: acting user missing, inactive or
-- the protected system account; Reason 4: another role; then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetManagerDepartments]
@ActingUserId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
DECLARE @HomeDepartmentId INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SELECT @ActingRole = r.RoleCode, @HomeDepartmentId = u.DepartmentId
	FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1 AND u.IsSystem = 0;

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole <> 'manager')
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	d.DepartmentId,
	d.DepartmentName,
	CAST(CASE WHEN d.DepartmentId = @HomeDepartmentId THEN 1 ELSE 0 END AS BIT) AS IsHome,
	CAST(CASE WHEN d.StatusId = 1 THEN 1 ELSE 0 END AS BIT) AS IsActive
	FROM dbo.fn_ManagerDepartments(@ActingUserId) md
	INNER JOIN Department d ON d.DepartmentId = md.DepartmentId
	WHERE @Result = 1
	ORDER BY CASE WHEN d.DepartmentId = @HomeDepartmentId THEN 0 ELSE 1 END, d.DepartmentName, d.DepartmentId;
END
GO

-------------------------------------------------------------------------------
-- User Master: the Reporting Person list (ManagerScope-Step54, step UD1c)
-------------------------------------------------------------------------------
-- The rows of fn_ReportingPersonAllowed(@DepartmentId, @UserId) with Allowed 1, and the user's current Reporting
-- Person @CurrentManagerId with Allowed 0 when it is not one of them (the page shows it "(not allowed now)" and
-- refuses Save while it is chosen). Columns UserId, UserName, LoginName, AccountStatus, RoleCode, Allowed.
-- @UserId: the edited user (0 for a new user). Only an Admin opens User Master: Reason 8 when the acting user is
-- missing or inactive, Reason 4 for another role; then no rows. spr_GetMgrControllerByDeptId is no longer called.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetReportingPersonList]
@ActingUserId INT = NULL,
@DepartmentId INT = NULL,
@UserId INT = NULL,
@CurrentManagerId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole <> 'admin')
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT u.UserId, u.UserName, u.LoginName, u.AccountStatus, r.RoleCode, CAST(1 AS BIT) AS Allowed
	FROM dbo.fn_ReportingPersonAllowed(@DepartmentId, @UserId) a
	INNER JOIN Users u ON u.UserId = a.UserId
	INNER JOIN Roles r ON r.RoleId = u.RoleId
	WHERE @Result = 1
	UNION ALL
	SELECT u.UserId, u.UserName, u.LoginName, u.AccountStatus, r.RoleCode, CAST(0 AS BIT) AS Allowed
	FROM Users u
	LEFT JOIN Roles r ON r.RoleId = u.RoleId
	WHERE @Result = 1
	  AND ISNULL(@CurrentManagerId, 0) > 0
	  AND u.UserId = @CurrentManagerId
	  AND NOT EXISTS (SELECT 1 FROM dbo.fn_ReportingPersonAllowed(@DepartmentId, @UserId) a2 WHERE a2.UserId = u.UserId);
END
GO

-------------------------------------------------------------------------------
-- Reports: Agenda Summary and Agenda Details (ManagerScope-Step54, step UD1c)
-------------------------------------------------------------------------------
-- The approved items (AgendaStatusCode 'ACA') of View_Agenda, with the filters the page built as SQL text before:
--   @CommitteeId     0 or less: no rows (the page always asks for a committee)
--   @DepartmentId    0 or less (- All - / All my departments): every department of the acting user's scope
--   @MeetingNoSearch 0: one meeting (@MeetingId; 0 or less = every meeting)
--                    1: @FromMeetingId to @ToMeetingId
--   @SubjectNoSearch 1: subject numbers @FromSubjectNo to @ToSubjectNo
--   @OrderBy         1: committee, meeting, subject number (Summary of one meeting, Details); 2: department,
--                    meeting, subject number (Summary of every meeting or of a range)
-- The scope is read in the database from the acting user: the Controller every department; a Manager the
-- departments of fn_ManagerDepartments only, and a department outside them is refused. Reason 8: acting user
-- missing, inactive or the protected system account; Reason 4: another role, or a Manager's department that is not
-- his; then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaReport]
@ActingUserId INT = NULL,
@CommitteeId INT = NULL,
@DepartmentId INT = NULL,
@MeetingNoSearch INT = NULL,
@MeetingId INT = NULL,
@FromMeetingId INT = NULL,
@ToMeetingId INT = NULL,
@SubjectNoSearch INT = NULL,
@FromSubjectNo INT = NULL,
@ToSubjectNo INT = NULL,
@OrderBy INT = 1,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1 AND u.IsSystem = 0);

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN ('controller', 'manager'))
		SET @Reason = 4;
	ELSE IF (@ActingRole = 'manager' AND ISNULL(@DepartmentId, 0) > 0
	         AND NOT EXISTS (SELECT 1 FROM dbo.fn_ManagerDepartments(@ActingUserId) md WHERE md.DepartmentId = @DepartmentId))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	v.*
	FROM View_Agenda v
	WHERE @Result = 1
	AND ISNULL(@CommitteeId, 0) > 0
	AND v.AgendaStatusCode = 'ACA'
	AND v.CommitteeId = @CommitteeId
	AND (ISNULL(@DepartmentId, 0) <= 0 OR v.DepartmentId = @DepartmentId)
	AND (@ActingRole = 'controller'
	     OR v.DepartmentId IN (SELECT md.DepartmentId FROM dbo.fn_ManagerDepartments(@ActingUserId) md))
	AND (ISNULL(@MeetingNoSearch, 0) <> 0 OR ISNULL(@MeetingId, 0) <= 0 OR v.MeetingId = @MeetingId)
	AND (ISNULL(@MeetingNoSearch, 0) <> 1 OR v.MeetingId BETWEEN @FromMeetingId AND @ToMeetingId)
	AND (ISNULL(@SubjectNoSearch, 0) <> 1 OR v.SubjectNo BETWEEN @FromSubjectNo AND @ToSubjectNo)
	ORDER BY CASE WHEN @OrderBy = 2 THEN v.DepartmentId ELSE v.CommitteeId END, v.MeetingId, v.SubjectNo;
END
GO

-------------------------------------------------------------------------------
-- Reports: Minutes and Minutes Extract by the acting user (ManagerScope-Step54, step UD1c)
-------------------------------------------------------------------------------
-- The rows of spr_GetMinutesReport (step 22: only meetings whose minutes are finalized or confirmed; the same
-- filters and order), limited by the acting user's scope as spr_GetAgendaReport: the Controller every department,
-- a Manager the departments of fn_ManagerDepartments (a department outside them is refused). The Controller's and
-- Management's Minutes report in every status stays spr_GetMinutesReportAllStatus (step 41). spr_GetMinutesReport
-- is kept unchanged. Reason 8: acting user missing, inactive or the protected system account; Reason 4: another
-- role, or a Manager's department that is not his; then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMinutesReportByUser]
@ActingUserId INT = NULL,
@CommitteeId INT = NULL,
@DepartmentId INT = NULL,
@MeetingNoSearch INT = NULL,
@MeetingId INT = NULL,
@FromMeetingId INT = NULL,
@ToMeetingId INT = NULL,
@SubjectNoSearch INT = NULL,
@FromSubjectNo INT = NULL,
@ToSubjectNo INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1 AND u.IsSystem = 0);

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN ('controller', 'manager'))
		SET @Reason = 4;
	ELSE IF (@ActingRole = 'manager' AND ISNULL(@DepartmentId, 0) > 0
	         AND NOT EXISTS (SELECT 1 FROM dbo.fn_ManagerDepartments(@ActingUserId) md WHERE md.DepartmentId = @DepartmentId))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	v.*
	FROM View_Minute v
	INNER JOIN Meeting m ON m.MeetingId = v.MeetingId
	WHERE @Result = 1
	AND ISNULL(@CommitteeId, 0) > 0
	AND v.CommitteeId = @CommitteeId
	AND ISNULL(m.MinutesStatus, 'Open') IN ('F', 'C')
	AND (ISNULL(@DepartmentId, 0) <= 0 OR v.DepartmentId = @DepartmentId)
	AND (@ActingRole = 'controller'
	     OR v.DepartmentId IN (SELECT md.DepartmentId FROM dbo.fn_ManagerDepartments(@ActingUserId) md))
	AND (ISNULL(@MeetingNoSearch, 0) <> 0 OR ISNULL(@MeetingId, 0) <= 0 OR v.MeetingId = @MeetingId)
	AND (ISNULL(@MeetingNoSearch, 0) <> 1 OR v.MeetingId BETWEEN @FromMeetingId AND @ToMeetingId)
	AND (ISNULL(@SubjectNoSearch, 0) <> 1 OR v.SubjectNo BETWEEN @FromSubjectNo AND @ToSubjectNo)
	ORDER BY v.CommitteeId, v.MeetingId, v.SubjectNo;
END
GO

-------------------------------------------------------------------------------
-- Reports: the subject numbers of a meeting for the From / To lists (ManagerScope-Step54, step UD1c)
-------------------------------------------------------------------------------
-- The rows of spr_GetMinutesByMeetingId(@MeetingId, 1, @DepartmentId) as the report page read them (View_Minute,
-- StatusId 1, by SubjectNo; @DepartmentId -1 = every department, otherwise that department), limited by the acting
-- user's scope: the Controller and Management every department, a Manager the departments of
-- fn_ManagerDepartments (-1 = all of them; a department outside them is refused). spr_GetMinutesByMeetingId is kept
-- unchanged (other pages read it). Reason 8: acting user missing, inactive or the protected system account;
-- Reason 4: another role, or a Manager's department that is not his; then no rows.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetReportSubjectNos]
@ActingUserId INT = NULL,
@MeetingId INT = NULL,
@DepartmentId INT = NULL,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1 AND u.IsSystem = 0);

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN ('controller', 'mgmt', 'manager'))
		SET @Reason = 4;
	ELSE IF (@ActingRole = 'manager' AND ISNULL(@DepartmentId, -1) <> -1
	         AND NOT EXISTS (SELECT 1 FROM dbo.fn_ManagerDepartments(@ActingUserId) md WHERE md.DepartmentId = @DepartmentId))
		SET @Reason = 4;
	ELSE
		SET @Result = 1;

	SELECT
	v.*
	FROM View_Minute v
	WHERE @Result = 1
	AND v.MeetingId = @MeetingId
	AND v.StatusId = 1
	AND (ISNULL(@DepartmentId, -1) = -1 OR v.DepartmentId = @DepartmentId)
	AND (@ActingRole IN ('controller', 'mgmt')
	     OR v.DepartmentId IN (SELECT md.DepartmentId FROM dbo.fn_ManagerDepartments(@ActingUserId) md))
	ORDER BY v.SubjectNo;
END
GO

-- Agenda Entry list of every role but the Controller (ManagerDepartment-Step33): the items of the meeting that
-- the user entered (CreatedBy = @UserId) and, for a Manager (Roles.RoleCode 'manager'), every item of the
-- Manager's department (Agenda.DepartmentId = Users.DepartmentId of @UserId). EnteredByName: the creator's
-- User Name, " (inactive)" added when the account is inactive, "(unknown user)" when no user row exists.
-- ManagerScope-Step54 (step UD1c): a Manager's departments are those of fn_ManagerDepartments (every department of
-- which he is an active Manager, fn_DepartmentManagers of step 53), no longer Users.DepartmentId alone; a user who is
-- not an active Manager sees the items he entered. @DepartmentId (optional, last): 0 or less = every item the user may
-- see (the Manager's "All my departments"); otherwise only the items of that department.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaByMeetingIdDeptId]
@MeetingId INT,
@UserId INT,
@DepartmentId INT = 0
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	va.*,
	CAST(CASE WHEN u.UserId IS NULL THEN '(unknown user)'
	          WHEN u.AccountStatus = 1 THEN u.UserName
	          ELSE u.UserName + ' (inactive)' END AS VARCHAR(80)) AS EnteredByName
	FROM View_Agenda va
	LEFT JOIN Users u ON u.UserId = va.CreatedBy
	WHERE va.MeetingId = @MeetingId
	AND (ISNULL(@DepartmentId, 0) <= 0 OR va.DepartmentId = @DepartmentId)
	AND (va.CreatedBy = @UserId
	     OR va.DepartmentId IN (SELECT md.DepartmentId FROM dbo.fn_ManagerDepartments(@UserId) md))
	ORDER BY va.AgendaStatusCode, va.SubjectNo;
END
GO


-- Agenda - add / edit by a manager, refused once the agenda is finalized (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX); @FilePath
-- VARCHAR(255)); a change of the Proposed Resolution is audited as 'ProposedResolution' (was 'ShortText')
-- CommentAuthor-Step35: MgrApprovedBy and MgrApprovedDate are the acting user and GETDATE() when the Manager saves a new
-- item (it is saved as approved by the Manager) and, on an edit, only when the text of MgrComments changes
-- AlertRefresh-Step36: an Update that changes a saved field marks the item's alert unread again (ReadStatus 0)
-- and shown again (StatusId 1) for every recipient except the acting user; no alert row is added, and
-- Alert_Master (CreatedOn, AlertTypeCode) is not changed. Text is compared exactly (case and trailing spaces
-- count; NULL and empty text are the same); for a number a change from NULL or to NULL counts
-- UpdateMail-Step37: @ChangedFields (OUTPUT, optional) returns the fields an Update changed, by the comparison of
-- AlertRefresh-Step36, as a comma list of codes in a fixed order; empty for a new item, a refusal or an Update
-- that changes nothing. Agenda Entry sends the update mail from it; nothing else changes
-- DepartmentApprovers-Step53 (step UD1b): the new item's alert goes to the active Controllers and to the active users
-- whose home department is the item's department, never to the Admin role; the refresh of an Update leaves rows
-- marked as handled and rows of inactive users as they are. The route is unchanged (AMA, approved by himself).
-- ManagerScope-Step54 (step UD1c): a new item is saved only in an active department of which the acting user is an
-- active Manager (fn_ManagerDepartments), an Update only of an item he entered or of one of his departments; otherwise
-- Reason 30 and nothing is saved. An Update still never writes the department, the status or the creator. The new
-- item's alert also goes to the other active Managers of the item's department (fn_DepartmentManagers), whatever
-- their home department.
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditAgendaByManager]
(@Code VARCHAR(50),
@AgendaId INT,
@AgendaNo VARCHAR(50),
@CommitteeId INT,
@MeetingId INT,
@DepartmentId INT,
@SubjectTypeId INT,
@ShortText NVARCHAR(MAX),
@AgendaType VARCHAR(50),
@AgendaText NVARCHAR(MAX),
@AgendaTextPath NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@FilePath NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
@CurrentStatus VARCHAR(50),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@SubjectNo INT,
@ActingUserId INT,
@ChangedFields VARCHAR(400) = NULL OUTPUT)   -- UpdateMail-Step37
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @agenda_id INT
	DECLARE @Mgr_Id INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @SubNo INT
	DECLARE @SubjectTypeName VARCHAR(50)
	DECLARE @SubjectTypeNameOld VARCHAR(50)
	DECLARE @SubjectTypeIdOld INT
	DECLARE @ShortTextOld NVARCHAR(MAX)
	DECLARE @AgendaTypeOld VARCHAR(50)
	DECLARE @AgendaTextOld NVARCHAR(MAX)
	DECLARE @AgendaTextPathOld NVARCHAR(MAX)
	DECLARE @ProposedResolutionOld NVARCHAR(MAX)
	DECLARE @MgrCommentsOld NVARCHAR(MAX)
	DECLARE @MinutesId INT
	DECLARE @NextAgendaNo AS VARCHAR(50);
	DECLARE @Prefix1 AS VARCHAR(50);
	DECLARE @Prefix2 AS VARCHAR(50);
	DECLARE @Prefix AS VARCHAR(50);
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @Locked INT;
	DECLARE @RfSubjectTypeId INT;   -- AlertRefresh-Step36: the saved values before an Update
	DECLARE @RfShortText NVARCHAR(MAX);
	DECLARE @RfAgendaType VARCHAR(50);
	DECLARE @RfAgendaText NVARCHAR(MAX);
	DECLARE @RfAgendaTextPath NVARCHAR(MAX);
	DECLARE @RfProposedResolution NVARCHAR(MAX);
	DECLARE @RfFilePath NVARCHAR(MAX);
	DECLARE @RfMgrComments NVARCHAR(MAX);
	DECLARE @RfControllerComments NVARCHAR(MAX);
	DECLARE @RfSubjectNo INT;
	DECLARE @RfChanged INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';
	SET @ChangedFields = '';   -- UpdateMail-Step37

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaSaveManager;

		IF (@Code = 'Update')
			SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @Locked = MeetingId FROM Meeting WITH (UPDLOCK, HOLDLOCK) WHERE MeetingId = @LockMeetingId;

		SELECT @Reason = Reason, @Detail = ReasonDetail FROM dbo.fn_AgendaChangeRefusal(@LockMeetingId, @ActingUserId, 0);

		-- ManagerScope-Step54: the department of a new item, the item of an Update (Reason 30, nothing saved)
		IF (@Reason = 0 AND @Code = 'Save'
		    AND NOT EXISTS (SELECT 1 FROM dbo.fn_ManagerDepartments(@ActingUserId) md
		                    JOIN Department dd ON dd.DepartmentId = md.DepartmentId
		                    WHERE md.DepartmentId = @DepartmentId AND dd.StatusId = 1))
		BEGIN
			SET @Reason = 30;
			SET @Detail = N'';
		END
		IF (@Reason = 0 AND @Code = 'Update'
		    AND EXISTS (SELECT 1 FROM Agenda ag WHERE ag.AgendaId = @AgendaId)
		    AND NOT EXISTS (SELECT 1 FROM Agenda ag
		                    WHERE ag.AgendaId = @AgendaId
		                      AND (ag.CreatedBy = @ActingUserId
		                           OR ag.DepartmentId IN (SELECT md.DepartmentId FROM dbo.fn_ManagerDepartments(@ActingUserId) md))))
		BEGIN
			SET @Reason = 30;
			SET @Detail = N'';
		END

		IF (@Reason = 0 AND @Code = 'Save')
		BEGIN
			SET @Prefix1 = (SELECT CommitteeCode FROM Committee WHERE CommitteeId = @CommitteeId)
			SET @Prefix2 = (SELECT MeetingNo FROM Meeting WHERE MeetingId = @MeetingId)
			SET @Prefix = @Prefix1 + '-' + @Prefix2 + '-';

			SET @NextAgendaNo = (SELECT MAX(AgendaNo) FROM Agenda
						WHERE MeetingId = @MeetingId);

			SET @AgendaNo = SUBSTRING(ISNULL(@NextAgendaNo,0),11,13);
			SET @AgendaNo = @AgendaNo + 1;

			IF (@AgendaNo <= 0)
			BEGIN
				SET @NextAgendaNo = @Prefix + '001';
			END
			IF (@AgendaNo >= 1 AND @AgendaNo <= 9)
			BEGIN
				SET @NextAgendaNo = @Prefix + '00' + CONVERT(VARCHAR(50),@AgendaNo);
			END
			IF (@AgendaNo >= 10 AND @AgendaNo <= 99)
			BEGIN
				SET @NextAgendaNo = @Prefix + '0' + CONVERT(VARCHAR(50),@AgendaNo);
			END

			SET @AgendaNo = @NextAgendaNo;

			INSERT INTO Agenda
			(AgendaNo, CommitteeId, MeetingId, DepartmentId,
			SubjectTypeId, ShortText, AgendaType, AgendaText, AgendaTextPath, ProposedResolution, FilePath,
			AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy, MgrComments, MgrApprovedStatus)
			VALUES
			(@AgendaNo, @CommitteeId, @MeetingId, @DepartmentId,
			@SubjectTypeId, @ShortText, @AgendaType, @AgendaText, @AgendaTextPath, @ProposedResolution, @FilePath,
			'AMA', @CurrentStatus, @CreatedOn, @CreatedBy, @MgrComments, 'Approved');

			SET @agenda_id = @@identity

			-- CommentAuthor-Step35: the new item is saved as approved by the Manager: who and when
			UPDATE Agenda SET MgrApprovedBy = @ActingUserId, MgrApprovedDate = GETDATE() WHERE AgendaId = @agenda_id;

			SET @SourceType = 'Agenda'
			SET @DisplayText = 'Agenda (' + @AgendaNo + ')'

			INSERT INTO Alert_Master
			(SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
			VALUES
			(@SourceType, @agenda_id, @DepartmentId, @DisplayText, 'AMA', 3, @CommitteeId, @CreatedOn, @CreatedBy)

			SET @alert_id = @@identity

			INSERT INTO Alert_User_Map
			(AlertId, [UserId], ReadStatus, StatusId)
			(SELECT @alert_id, [UserId],0,1 FROM Users WHERE (RoleId = 2 OR
				UserId IN (SELECT Users.UserId FROM Users WHERE Users.DepartmentId = @DepartmentId)
				OR UserId IN (SELECT dm.UserId FROM dbo.fn_DepartmentManagers(@DepartmentId) dm))   -- ManagerScope-Step54
				AND AccountStatus = 1 AND IsSystem = 0
				AND NOT EXISTS (SELECT 1 FROM Roles ar WHERE ar.RoleId = Users.RoleId AND ar.RoleCode = 'admin'));   -- DepartmentApprovers-Step53

			SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);

			INSERT INTO [Audit_Trail_Master]
	           ([Audit_Type], [Audit_Table], [Key_Field], [Key_Value], [Field_Name],
				[Old_Value], [New_Value], [Update_By], [Update_On])
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', '', @SubjectTypeName, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', '', @ShortText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', '', @AgendaType, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', '', @AgendaText, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', '', @AgendaTextPath, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', '', @ProposedResolution, @UpdatedBy, GETDATE()
			UNION ALL
			SELECT 'IN', 'Agenda', 'AgendaNo', @AgendaNo, 'FilePath', '', @FilePath, @UpdatedBy, GETDATE();

			SET @Result = 1;
		END

		IF (@Reason = 0 AND @Code = 'Update')
		BEGIN
			-- AlertRefresh-Step36: the saved values, to see below whether this Update changes anything
			SELECT @RfSubjectTypeId = SubjectTypeId, @RfShortText = ShortText, @RfAgendaType = AgendaType,
			       @RfAgendaText = AgendaText, @RfAgendaTextPath = AgendaTextPath, @RfProposedResolution = ProposedResolution,
			       @RfFilePath = FilePath, @RfMgrComments = MgrComments, @RfControllerComments = ControllerComments,
			       @RfSubjectNo = SubjectNo
			FROM Agenda WHERE AgendaId = @AgendaId;

			SET @SubjectTypeIdOld = (SELECT SubjectTypeId FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ShortTextOld = (SELECT ShortText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTypeOld = (SELECT AgendaType FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextOld = (SELECT AgendaText FROM Agenda WHERE AgendaId = @AgendaId);
			SET @AgendaTextPathOld = (SELECT AgendaTextPath FROM Agenda WHERE AgendaId = @AgendaId);
			SET @ProposedResolutionOld = (SELECT ProposedResolution FROM Agenda WHERE AgendaId = @AgendaId);
			SET @MgrCommentsOld = (SELECT MgrComments FROM Agenda WHERE AgendaId = @AgendaId);   -- CommentAuthor-Step35

			UPDATE Agenda SET
			SubjectTypeId = @SubjectTypeId,
			ShortText = @ShortText,
			AgendaType = @AgendaType,
			AgendaText = @AgendaText,
			AgendaTextPath = @AgendaTextPath,
			ProposedResolution = @ProposedResolution,
			FilePath = @FilePath,
			MgrComments = @MgrComments,
			ControllerComments = @ControllerComments,
			CurrentStatus = @CurrentStatus,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy,
			SubjectNo = @SubjectNo
			WHERE
			AgendaId = @AgendaId;

			-- CommentAuthor-Step35: who and when of the Manager's comment, only when its text changed (an exact comparison:
			-- case and trailing spaces count; NULL and empty text are the same)
			IF (ISNULL(@MgrCommentsOld, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
			    OR DATALENGTH(ISNULL(@MgrCommentsOld, N'')) <> DATALENGTH(ISNULL(@MgrComments, N'')))
				UPDATE Agenda SET MgrApprovedBy = @ActingUserId, MgrApprovedDate = GETDATE() WHERE AgendaId = @AgendaId;

			SET @MinutesId = 0;
			SET @MinutesId = (SELECT MinutesId FROM View_Minute WHERE AgendaId = @AgendaId);

			UPDATE Minutes SET
			ActualResolution = @ProposedResolution
			WHERE MinutesId = @MinutesId;

			IF (@SubjectTypeIdOld != @SubjectTypeId)
			BEGIN
				SET @SubjectTypeNameOld = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeIdOld);
				SET @SubjectTypeName = (SELECT SubjectTypeName FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId);
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'SubjectTypeName', @SubjectTypeNameOld, @SubjectTypeName, @UpdatedBy, GETDATE());
			END
			IF (@ShortTextOld != @ShortText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ShortText', @ShortTextOld, @ShortText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTypeOld != @AgendaType)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaType', @AgendaTypeOld, @AgendaType, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextOld != @AgendaText)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaText', @AgendaTextOld, @AgendaText, @UpdatedBy, GETDATE());
			END
			IF (@AgendaTextPathOld != @AgendaTextPath)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'AgendaTextPath', @AgendaTextPathOld, @AgendaTextPath, @UpdatedBy, GETDATE());
			END
			IF (@ProposedResolutionOld != @ProposedResolution)
			BEGIN
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'Agenda', 'AgendaNo', @AgendaNo, 'ProposedResolution', @ProposedResolutionOld, @ProposedResolution, @UpdatedBy, GETDATE());
			END

			-- AlertRefresh-Step36: a change marks the item's alert unread again, and shown again if it was removed, for
			-- every recipient except the acting user; an Update that changes nothing leaves the alert as it is
			SET @RfChanged = CASE
				WHEN @RfSubjectTypeId <> @SubjectTypeId OR (@RfSubjectTypeId IS NULL AND @SubjectTypeId IS NOT NULL) OR (@RfSubjectTypeId IS NOT NULL AND @SubjectTypeId IS NULL) THEN 1
				WHEN @RfSubjectNo <> @SubjectNo OR (@RfSubjectNo IS NULL AND @SubjectNo IS NOT NULL) OR (@RfSubjectNo IS NOT NULL AND @SubjectNo IS NULL) THEN 1
				WHEN ISNULL(@RfShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ShortText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfShortText, N'')) <> DATALENGTH(ISNULL(@ShortText, N'')) THEN 1
				WHEN ISNULL(@RfAgendaType, '') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaType, '') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaType, '')) <> DATALENGTH(ISNULL(@AgendaType, '')) THEN 1
				WHEN ISNULL(@RfAgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaText, N'')) <> DATALENGTH(ISNULL(@AgendaText, N'')) THEN 1
				WHEN ISNULL(@RfAgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaTextPath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) <> DATALENGTH(ISNULL(@AgendaTextPath, N'')) THEN 1
				WHEN ISNULL(@RfProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ProposedResolution, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfProposedResolution, N'')) <> DATALENGTH(ISNULL(@ProposedResolution, N'')) THEN 1
				WHEN ISNULL(@RfFilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@FilePath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfFilePath, N'')) <> DATALENGTH(ISNULL(@FilePath, N'')) THEN 1
				WHEN ISNULL(@RfMgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfMgrComments, N'')) <> DATALENGTH(ISNULL(@MgrComments, N'')) THEN 1
				WHEN ISNULL(@RfControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfControllerComments, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N'')) THEN 1
				ELSE 0 END;

			-- DepartmentApprovers-Step53: rows marked as handled ('H', 'N' or 'M') and rows of inactive users are left as they are
			IF (@RfChanged = 1)
				UPDATE m SET ReadStatus = 0, StatusId = 1
				FROM Alert_User_Map m
				JOIN Alert_Master am ON am.AlertId = m.AlertId
				JOIN Users ru ON ru.UserId = m.UserId
				WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgendaId
				  AND m.UserId <> @ActingUserId
				  AND m.HandledReason IS NULL
				  AND ru.AccountStatus = 1;

			-- UpdateMail-Step37: the changed fields for the update mail (the comparisons above, one per field: the list is
			-- empty exactly when @RfChanged is 0)
			SET @ChangedFields =
				CASE WHEN @RfSubjectTypeId <> @SubjectTypeId OR (@RfSubjectTypeId IS NULL AND @SubjectTypeId IS NOT NULL) OR (@RfSubjectTypeId IS NOT NULL AND @SubjectTypeId IS NULL)
				       THEN ',SubjectType' ELSE '' END
				+ CASE WHEN ISNULL(@RfShortText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ShortText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfShortText, N'')) <> DATALENGTH(ISNULL(@ShortText, N''))
				       THEN ',ShortText' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaType, '') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaType, '') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaType, '')) <> DATALENGTH(ISNULL(@AgendaType, ''))
				       THEN ',AgendaType' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaText, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaText, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaText, N'')) <> DATALENGTH(ISNULL(@AgendaText, N''))
				       THEN ',AgendaText' ELSE '' END
				+ CASE WHEN ISNULL(@RfAgendaTextPath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@AgendaTextPath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) <> DATALENGTH(ISNULL(@AgendaTextPath, N''))
				       THEN CASE WHEN DATALENGTH(ISNULL(@RfAgendaTextPath, N'')) = 0 THEN ',AgendaTextFile:Attached'
				                 WHEN DATALENGTH(ISNULL(@AgendaTextPath, N'')) = 0 THEN ',AgendaTextFile:Removed'
				                 ELSE ',AgendaTextFile:Replaced' END
				       ELSE '' END
				+ CASE WHEN ISNULL(@RfProposedResolution, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ProposedResolution, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfProposedResolution, N'')) <> DATALENGTH(ISNULL(@ProposedResolution, N''))
				       THEN ',ProposedResolution' ELSE '' END
				+ CASE WHEN ISNULL(@RfFilePath, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@FilePath, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfFilePath, N'')) <> DATALENGTH(ISNULL(@FilePath, N''))
				       THEN ',Attachments' ELSE '' END
				+ CASE WHEN ISNULL(@RfMgrComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@MgrComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfMgrComments, N'')) <> DATALENGTH(ISNULL(@MgrComments, N''))
				       THEN ',MgrComments' ELSE '' END
				+ CASE WHEN ISNULL(@RfControllerComments, N'') COLLATE Latin1_General_BIN2 <> ISNULL(@ControllerComments, N'') COLLATE Latin1_General_BIN2
				     OR DATALENGTH(ISNULL(@RfControllerComments, N'')) <> DATALENGTH(ISNULL(@ControllerComments, N''))
				       THEN ',ControllerComments' ELSE '' END
				+ CASE WHEN @RfSubjectNo <> @SubjectNo OR (@RfSubjectNo IS NULL AND @SubjectNo IS NOT NULL) OR (@RfSubjectNo IS NOT NULL AND @SubjectNo IS NULL)
				       THEN ',SubjectNo' ELSE '' END
				+ '';
			IF (LEN(@ChangedFields) > 0)
				SET @ChangedFields = STUFF(@ChangedFields, 1, 1, '');

			SET @Result = 1;
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION AgendaSaveManager;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- Users - add / edit (UserProtection-Stage1; UserHistory-Step39)
-------------------------------------------------------------------------------
-- Save checks Create (acting user = @CreatedBy); Update checks Edit and, when the role really
-- changes, RoleChange (acting user = @UpdatedBy) (UserProtection-Stage1).
-- UserHistory-Step39: @DepartmentIds (optional, last) is the comma list of the user's departments:
-- digits and commas only, at most 2000 characters, each id at most 9 digits and a department that
-- exists; a department added by the list must be active. Only a Manager may have several; the home
-- department (@DepartmentId) must be in the list (Reason 23). NULL = not passed: a new user gets the
-- home department; an edit keeps the Manager's mappings and adds the home department. Every change is
-- written to User_Role / User_Department in the same transaction (rows dated today, by the acting
-- user). An inactive user's rows are left closed: only Users changes, Activate opens the rows.
-- A role change away from Manager closes his other departments (R) and is refused (Reason 24) when he
-- is the last active Manager of one of his departments with items waiting for a Manager, or when items
-- waiting at AC are routed to him; an edit that removes a department of a Manager checks that
-- department only. On success ReasonDetail is 'MappingsClosed:<names>' when departments were closed
-- by a role change away from Manager, otherwise ''.
-- ManagerRelease-Step52 (step MR1): the items routed to him are those fn_AgendaWaitingFor lets him approve, counted
-- apart by the meeting date (fn_ManagerReleaseRefusal Kinds 'P' and 'Q'). The Reason 24 ReasonDetail is
-- 'open:<n>|past:<n>|<department part>', the department part as before ('last active Manager of ...' or nothing).
-- DepartmentApprovers-Step53 (step UD1b): rule 12 refuses only for the items no other Manager of the department could
-- decide (fn_ManagerReleaseRefusal). When the change is allowed, his rows on the alerts of items at AC of the
-- departments he leaves are marked 'N' (no longer Manager of the department) in the same transaction, and the
-- successful ReasonDetail ends with '|Released:<n>:<department names>'. A Manager after the save (a new user, a role
-- changed to Manager, a department added) gets a row on the alert of every item waiting at AC in his departments
-- (spr_SetManagerAlertRows; his own 'N' row is opened again).
-- ManagerScope-Step54 (step UD1c): the Reporting Person (@ManagerId) must be one of fn_ReportingPersonAllowed for the
-- user's (home) department @DepartmentId: an active Controller or an active Manager of that department, never the
-- user himself; none (NULL or 0, "- Select -") stays allowed. Otherwise Reason 31 and nothing is saved, on Create
-- and on every Update (also when the Reporting Person is not changed).
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditUser]
@Code VARCHAR(50),
@UserId INT,
@UserName VARCHAR(50),
@DepartmentId INT,
@DesignationId INT,
@ManagerId INT,
@RoleId INT,
@EmailId VARCHAR(50),
@LoginName VARCHAR(50),
@Password VARCHAR(MAX),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT,
@DepartmentIds VARCHAR(MAX) = NULL
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @ActingUserId INT;
DECLARE @OldRoleId INT;
DECLARE @OldActive INT;
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @NewUserId INT;
DECLARE @IsManager INT;
DECLARE @WasManager INT;
DECLARE @Today DATE;
DECLARE @Now DATETIME;
DECLARE @Rest VARCHAR(MAX);
DECLARE @Pos INT;
DECLARE @Token VARCHAR(20);
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @Posted TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @Wanted TABLE (DepartmentId INT NOT NULL PRIMARY KEY, IsHome BIT NOT NULL);
DECLARE @OpenNow TABLE (DepartmentId INT NOT NULL PRIMARY KEY, IsHome BIT NOT NULL, IsVirtual BIT NOT NULL);
DECLARE @OldDepartmentId INT;
DECLARE @Lost TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @Refusal TABLE (Kind CHAR(1), DepartmentId INT NULL, DepartmentName NVARCHAR(200), Items INT);
DECLARE @Rel TABLE (DepartmentId INT NOT NULL PRIMARY KEY);   -- DepartmentApprovers-Step53
DECLARE @RelDept INT;
DECLARE @RelCount INT;
DECLARE @RelTotal INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
	SET @RelTotal = 0;
	SET @ActingUserId = CASE WHEN @Code = 'Save' THEN @CreatedBy ELSE @UpdatedBy END;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @Now = GETDATE();
	SET @IsManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleId AND RoleCode = 'manager') THEN 1 ELSE 0 END;

	-- The posted list, read as numbers only (UserHistory-Step39)
	IF (@DepartmentIds IS NOT NULL)
	BEGIN
		IF (LEN(@DepartmentIds) = 0 OR LEN(@DepartmentIds) > 2000 OR @DepartmentIds LIKE '%[^0-9,]%')
			SET @Detail = N'ListNotValid';
		ELSE
		BEGIN
			SET @Rest = @DepartmentIds + ',';
			WHILE (LEN(@Rest) > 0 AND @Detail = N'')
			BEGIN
				SET @Pos = CHARINDEX(',', @Rest);
				IF (@Pos <= 1 OR @Pos > 10)
					SET @Detail = N'ListNotValid';
				ELSE
				BEGIN
					SET @Token = LEFT(@Rest, @Pos - 1);
					SET @Rest = SUBSTRING(@Rest, @Pos + 1, LEN(@Rest));
					IF NOT EXISTS (SELECT 1 FROM @Posted WHERE DepartmentId = CAST(@Token AS INT))
						INSERT INTO @Posted (DepartmentId) VALUES (CAST(@Token AS INT));
				END
			END
		END

		IF (@Detail = N'' AND EXISTS (SELECT 1 FROM @Posted p WHERE NOT EXISTS (SELECT 1 FROM Department d WHERE d.DepartmentId = p.DepartmentId)))
			SET @Detail = N'DepartmentNotFound';
		ELSE IF (@Detail = N'' AND @IsManager = 0 AND (SELECT COUNT(*) FROM @Posted) > 1)
			SET @Detail = N'OneDepartmentOnly';
		ELSE IF (@Detail = N'' AND NOT EXISTS (SELECT 1 FROM @Posted WHERE DepartmentId = @DepartmentId))
			SET @Detail = N'HomeNotTicked';
	END

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
		SET @Detail = N'';
	END
	ELSE IF (@Code = 'Save')
	BEGIN
		SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, NULL, 'Create', @RoleId);

		IF (@Reason <> 0)
			SET @Detail = N'';
		ELSE IF (@Detail <> N'')
			SET @Reason = 23;
		ELSE IF (EXISTS (SELECT 1 FROM @Posted p JOIN Department d ON d.DepartmentId = p.DepartmentId WHERE ISNULL(d.StatusId, 0) <> 1))
		BEGIN
			SET @Reason = 23;
			SET @Detail = N'DepartmentInactive';
		END
		-- ManagerScope-Step54: the Reporting Person (Reason 31)
		ELSE IF (ISNULL(@ManagerId, 0) > 0
		         AND NOT EXISTS (SELECT 1 FROM dbo.fn_ReportingPersonAllowed(@DepartmentId, NULL) rp WHERE rp.UserId = @ManagerId))
		BEGIN
			SET @Reason = 31;
			SET @Detail = N'';
		END

		IF (@Reason = 0)
		BEGIN
			IF (@@TRANCOUNT = 0)
				SET @OwnTransaction = 1;
			ELSE
				SET @OwnTransaction = 0;

			BEGIN TRY
				IF (@OwnTransaction = 1)
					BEGIN TRANSACTION;
				ELSE
					SAVE TRANSACTION AddUser;

				INSERT INTO Users
				(UserName, DepartmentId, DesignationId, ManagerId,
					RoleId, EmailId, LoginName, Password, AccountStatus, CreatedOn, CreatedBy)
				VALUES
				(@UserName, @DepartmentId, @DesignationId, @ManagerId,
					@RoleId, @EmailId, @LoginName, @Password, 1, @CreatedOn, @CreatedBy);

				SET @NewUserId = SCOPE_IDENTITY();

				INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
				VALUES (@NewUserId, @RoleId, @Today, @Now, @ActingUserId);

				INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
				VALUES (@NewUserId, @DepartmentId, 1, @Today, @Now, @ActingUserId);

				INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
				SELECT @NewUserId, p.DepartmentId, 0, @Today, @Now, @ActingUserId
				FROM @Posted p
				WHERE p.DepartmentId <> @DepartmentId;

				-- DepartmentApprovers-Step53: a new Manager gets his rows of the items waiting at AC in his departments
				IF (@IsManager = 1)
					EXEC dbo.spr_SetManagerAlertRows @UserId = @NewUserId, @ActingUserId = @ActingUserId;

				SET @Result = 1;

				IF (@OwnTransaction = 1)
					COMMIT TRANSACTION;
			END TRY
			BEGIN CATCH
				SET @ErrMsg = ERROR_MESSAGE();

				IF (@OwnTransaction = 1)
				BEGIN
					IF (@@TRANCOUNT > 0)
						ROLLBACK TRANSACTION;
				END
				ELSE IF (XACT_STATE() = 1)
					ROLLBACK TRANSACTION AddUser;

				RAISERROR('%s', 16, 1, @ErrMsg);
				RETURN;
			END CATCH
		END
	END
	ELSE IF (@Code = 'Update')
	BEGIN
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION EditUser;

			SELECT @OldRoleId = RoleId, @OldDepartmentId = DepartmentId, @OldActive = ISNULL(AccountStatus, 0)
			FROM Users WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId;

			SET @WasManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @OldRoleId AND RoleCode = 'manager') THEN 1 ELSE 0 END;

			-- Rule 2 under concurrency (only a role change can break it here)
			IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
				WHERE AccountStatus = 1
				AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'Edit', NULL);

			IF (@Reason = 0 AND ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'RoleChange', @RoleId);

			IF (@Reason <> 0)
				SET @Detail = N'';
			ELSE IF (@Detail <> N'' AND @OldActive = 1)
				SET @Reason = 23;
			ELSE IF (@OldActive <> 1)
				-- An inactive user keeps closed rows: the list is not used (Activate opens the rows)
				SET @Detail = N'';

			IF (@Reason = 0 AND @OldActive = 1)
			BEGIN
				-- The open rows today, and the rows wanted after the save
				INSERT INTO @OpenNow (DepartmentId, IsHome, IsVirtual)
				SELECT DepartmentId, MAX(CAST(IsHome AS INT)), 0 FROM User_Department WITH (UPDLOCK, HOLDLOCK)
				WHERE UserId = @UserId AND EffectiveTo IS NULL
				GROUP BY DepartmentId;

				-- A user without an open department row (inserted directly, as the older test scripts do) counts
				-- as mapped to the department in Users: a row is written only when it changes
				IF NOT EXISTS (SELECT 1 FROM @OpenNow) AND @OldDepartmentId IS NOT NULL
					INSERT INTO @OpenNow (DepartmentId, IsHome, IsVirtual) VALUES (@OldDepartmentId, 1, 1);

				IF (@DepartmentIds IS NOT NULL)
					INSERT INTO @Wanted (DepartmentId, IsHome)
					SELECT DepartmentId, CASE WHEN DepartmentId = @DepartmentId THEN 1 ELSE 0 END FROM @Posted;
				ELSE IF (@IsManager = 1)
					INSERT INTO @Wanted (DepartmentId, IsHome)
					SELECT DepartmentId, CASE WHEN DepartmentId = @DepartmentId THEN 1 ELSE 0 END FROM @OpenNow
					UNION
					SELECT @DepartmentId, 1 WHERE NOT EXISTS (SELECT 1 FROM @OpenNow WHERE DepartmentId = @DepartmentId);
				ELSE
					INSERT INTO @Wanted (DepartmentId, IsHome) VALUES (@DepartmentId, 1);

				-- A department added by the list must be active
				IF EXISTS (SELECT 1 FROM @Posted p JOIN Department d ON d.DepartmentId = p.DepartmentId
				           WHERE ISNULL(d.StatusId, 0) <> 1
				             AND NOT EXISTS (SELECT 1 FROM @OpenNow o WHERE o.DepartmentId = p.DepartmentId))
				BEGIN
					SET @Reason = 23;
					SET @Detail = N'DepartmentInactive';
				END
			END

			-- ManagerScope-Step54: the Reporting Person (Reason 31), checked on every Update
			IF (@Reason = 0 AND ISNULL(@ManagerId, 0) > 0
			    AND NOT EXISTS (SELECT 1 FROM dbo.fn_ReportingPersonAllowed(@DepartmentId, @UserId) rp WHERE rp.UserId = @ManagerId))
			BEGIN
				SET @Reason = 31;
				SET @Detail = N'';
			END

			-- Rule 12: a Manager who leaves departments
			IF (@Reason = 0 AND @OldActive = 1 AND @WasManager = 1)
			BEGIN
				IF (@IsManager = 0)
					INSERT INTO @Lost (DepartmentId) SELECT DepartmentId FROM @OpenNow;
				ELSE
					INSERT INTO @Lost (DepartmentId)
					SELECT o.DepartmentId FROM @OpenNow o WHERE NOT EXISTS (SELECT 1 FROM @Wanted w WHERE w.DepartmentId = o.DepartmentId);

				IF (EXISTS (SELECT 1 FROM @Lost) OR @IsManager = 0)
				BEGIN
					-- Two Managers of one department changing at the same time are serialised here
					SELECT @Locked = COUNT(*) FROM User_Department WITH (UPDLOCK, HOLDLOCK)
					WHERE EffectiveTo IS NULL AND DepartmentId IN (SELECT DepartmentId FROM @Lost);

					IF (@IsManager = 0)
						INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
						SELECT Kind, DepartmentId, DepartmentName, Items FROM dbo.fn_ManagerReleaseRefusal(@UserId, NULL, 1);
					ELSE
						INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
						SELECT f.Kind, f.DepartmentId, f.DepartmentName, f.Items
						FROM @Lost l
						CROSS APPLY dbo.fn_ManagerReleaseRefusal(@UserId, l.DepartmentId, 0) f;

					IF EXISTS (SELECT 1 FROM @Refusal)
					BEGIN
						SET @Reason = 24;
						-- ManagerRelease-Step52: 'open:<n>|past:<n>|' and then the department part as before ('last active
						-- Manager of <names with counts>', or nothing). open: Kind 'P', past: Kind 'Q'. The page builds the message.
						SET @Detail = N'open:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'P'), 0) AS NVARCHAR(12))
						            + N'|past:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'Q'), 0) AS NVARCHAR(12))
						            + N'|'
						            + ISNULL(N'last active Manager of '
						              + STUFF((SELECT N', ' + r.DepartmentName + N' (' + CAST(r.Items AS NVARCHAR(12))
						                              + CASE WHEN r.Items = 1 THEN N' item waiting)' ELSE N' items waiting)' END
						                       FROM @Refusal r WHERE r.Kind = 'D' ORDER BY r.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');
						SET @Detail = LEFT(@Detail, 2000);
					END
				END
			END

			IF (@Reason = 0)
			BEGIN
				UPDATE Users SET
				UserName = @UserName,
				DepartmentId = @DepartmentId,
				DesignationId = @DesignationId,
				ManagerId = @ManagerId,
				RoleId = @RoleId,
				EmailId = @EmailId,
				LoginName = @LoginName,
				UpdatedOn = @UpdatedOn,
				UpdatedBy = @UpdatedBy
				WHERE
				UserId = @UserId;

				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;

				-- History (UserHistory-Step39): active users only
				IF (@Result = 1 AND @OldActive = 1)
				BEGIN
					IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
					BEGIN
						UPDATE User_Role SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'C'
						WHERE UserId = @UserId AND EffectiveTo IS NULL;

						INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @RoleId, @Today, @Now, @ActingUserId);
					END

					IF (@WasManager = 1 AND @IsManager = 0)
						SET @Detail = ISNULL(N'MappingsClosed:'
						              + STUFF((SELECT N', ' + d.DepartmentName FROM @OpenNow o JOIN Department d ON d.DepartmentId = o.DepartmentId
						                       WHERE o.IsVirtual = 0
						                         AND NOT EXISTS (SELECT 1 FROM @Wanted w WHERE w.DepartmentId = o.DepartmentId)
						                       ORDER BY d.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');

					-- Close the rows that go away or whose home flag changes
					UPDATE ud SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId,
					       CloseReason = CASE WHEN @WasManager = 1 AND @IsManager = 0 AND w.DepartmentId IS NULL THEN 'R' ELSE 'C' END
					FROM User_Department ud
					LEFT JOIN @Wanted w ON w.DepartmentId = ud.DepartmentId
					WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL
					  AND (w.DepartmentId IS NULL OR w.IsHome <> ud.IsHome);

					-- Open the rows that are wanted and not open (nor unchanged in Users, for a user without rows)
					INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
					SELECT @UserId, w.DepartmentId, w.IsHome, @Today, @Now, @ActingUserId
					FROM @Wanted w
					WHERE NOT EXISTS (SELECT 1 FROM User_Department ud
					                  WHERE ud.UserId = @UserId AND ud.DepartmentId = w.DepartmentId AND ud.EffectiveTo IS NULL)
					  AND NOT EXISTS (SELECT 1 FROM @OpenNow o
					                  WHERE o.IsVirtual = 1 AND o.DepartmentId = w.DepartmentId AND o.IsHome = w.IsHome);

					-- DepartmentApprovers-Step53: his waiting approval alerts of the departments he leaves are closed for him
					-- ('N'); rule 12 above has made sure another Manager of the department still has them
					IF (@WasManager = 1)
					BEGIN
						INSERT INTO @Rel (DepartmentId)
						SELECT DISTINCT a.DepartmentId
						FROM Alert_User_Map m
						JOIN Alert_Master am ON am.AlertId = m.AlertId
						JOIN Agenda a ON am.SourceType = 'Agenda' AND a.AgendaId = am.SourceTypeId
						WHERE m.UserId = @UserId AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC'
						  AND a.DepartmentId IS NOT NULL
						  AND (@IsManager = 0 OR a.DepartmentId IN (SELECT l.DepartmentId FROM @Lost l));

						SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel);
						WHILE (@RelDept IS NOT NULL)
						BEGIN
							EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @DepartmentId = @RelDept, @Release = 1,
							     @ActingUserId = @ActingUserId, @Released = @RelCount OUTPUT;
							SET @RelTotal = @RelTotal + ISNULL(@RelCount, 0);
							SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel WHERE DepartmentId > @RelDept);
						END
					END

					-- DepartmentApprovers-Step53: a Manager (new role, or a department added) gets his rows of the items
					-- waiting at AC in his departments
					IF (@IsManager = 1)
						EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @ActingUserId = @ActingUserId;
				END
			END

			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION EditUser;

			RAISERROR('%s', 16, 1, @ErrMsg);
			RETURN;
		END CATCH
	END

	IF (@Result <> 1 AND @Reason = 0)
		SET @Detail = N'';

	-- DepartmentApprovers-Step53: '|Released:<n>:<department names>' at the end of a successful detail
	IF (@Result = 1 AND @RelTotal > 0)
		SET @Detail = LEFT(@Detail + N'|Released:' + CAST(@RelTotal AS NVARCHAR(12)) + N':'
		              + ISNULL(STUFF((SELECT N', ' + CAST(d.DepartmentName AS NVARCHAR(200)) FROM @Rel r
		                              JOIN Department d ON d.DepartmentId = r.DepartmentId ORDER BY d.DepartmentName
		                              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N''), 2000);

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- Result
-------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM (VALUES ('fn_ManagerDepartments'), ('fn_ReportingPersonAllowed'), ('spr_GetManagerDepartments'),
                                 ('spr_GetReportingPersonList'), ('spr_GetAgendaReport'), ('spr_GetMinutesReportByUser'),
                                 ('spr_GetReportSubjectNos'), ('spr_GetAgendaByMeetingIdDeptId'), ('spr_AddEditAgendaByManager'),
                                 ('spr_AddEditUser')) o(Name)
           WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') NOT LIKE '%ManagerScope-Step54%')
    RAISERROR('Step 54 is NOT completely installed: an object is missing. Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 54 installed: 10 objects carry ManagerScope-Step54.';
GO

SET NOEXEC OFF;
GO
