/* ============================================================================
   BMMS - Agenda Entry list: a Manager sees the items of their department;
   "Entered by" in the list of every role (step 33, step C2)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Before this step the Agenda Entry list of a Manager held only the items the
   Manager had entered (spr_GetAgendaByMeetingIdDeptId: CreatedBy = @UserId),
   so the Manager did not see the items of the department's Users on Agenda
   Entry. The list of no role said who entered an item.

   Rules
     spr_GetAgendaByMeetingIdDeptId  (Agenda Entry list of every role but the
                                     Controller)
              an item of the meeting is listed when the user entered it
              (CreatedBy = @UserId, kept), or when the user's role is
              Manager (Roles.RoleCode 'manager') and the item's department
              is the user's department (Agenda.DepartmentId =
              Users.DepartmentId of @UserId). The department is the item's
              own, not the department of the user who entered it. An item
              with no department is listed only for the user who entered it.
              Every other role (User, and any other role that reaches the
              page) keeps only the items it entered.
     spr_GetAgendaByMeetingId        (Agenda Entry list of the Controller;
                                     also Reports, Agenda Approval)
              unchanged rows: every item of the meeting.
     Both     return every column of View_Agenda as before, in the same order
              (AgendaStatusCode, SubjectNo), and one more column at the end:
              EnteredByName  the User Name of the user who entered the item;
                             "<name> (inactive)" when that account is
                             inactive; "(unknown user)" when no user row
                             exists (FK_Agenda_CreatedBy of step 11 keeps a
                             creator from being deleted, so this is not
                             expected).
              View_Agenda itself is not changed: six procedures select every
              column from it.

   Objects
     spr_GetAgendaByMeetingIdDeptId  REPLACED (baseline text; no earlier step
                                     contains it); marker
                                     ManagerDepartment-Step33.
     spr_GetAgendaByMeetingId        REPLACED (baseline text; no earlier step
                                     contains it); marker
                                     ManagerDepartment-Step33.
   The page (Agenda.aspx.cs, step C2) checks Edit and Update by the same rule
   and refuses Delete for every role but the Controller.

   Changes no data. Safe to re-run. Needs step 14 (Users.AccountStatus) and
   stops otherwise. BMMS-Rollback-ManagerDepartment-Step33.sql restores both
   baseline texts. Run it BEFORE deploying the build of step C2: that build
   shows the "Entered by" column, which the old procedures do not return (the
   column is then empty).

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.

   If you install from the command line, use sqlcmd -I (quoted identifiers ON);
   installing from SSMS already does this.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (COL_LENGTH('dbo.Users', 'AccountStatus') IS NULL)
BEGIN
    RAISERROR('Users.AccountStatus is missing in "%s": step 14 (BMMS-Fix-UserStatus-Stage2a.sql) is not installed. Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (COL_LENGTH('dbo.View_Agenda', 'DepartmentId') IS NULL OR COL_LENGTH('dbo.View_Agenda', 'CreatedBy') IS NULL
         OR COL_LENGTH('dbo.Roles', 'RoleCode') IS NULL)
BEGIN
    RAISERROR('View_Agenda (DepartmentId, CreatedBy) or Roles.RoleCode is missing in "%s". This is not a BMMS database of the expected version. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Agenda Entry list of every role but the Controller (ManagerDepartment-Step33): the items of the meeting that
-- the user entered (CreatedBy = @UserId) and, for a Manager (Roles.RoleCode 'manager'), every item of the
-- Manager's department (Agenda.DepartmentId = Users.DepartmentId of @UserId). EnteredByName: the creator's
-- User Name, " (inactive)" added when the account is inactive, "(unknown user)" when no user row exists.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaByMeetingIdDeptId]
@MeetingId INT,
@UserId INT
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
	AND (va.CreatedBy = @UserId
	     OR EXISTS (SELECT 1
	                FROM Users me
	                JOIN Roles r ON r.RoleId = me.RoleId
	                WHERE me.UserId = @UserId
	                AND r.RoleCode = 'manager'
	                AND me.DepartmentId = va.DepartmentId))
	ORDER BY va.AgendaStatusCode, va.SubjectNo;
END
GO

-- Agenda Entry list of the Controller, and Reports, Agenda Approval (ManagerDepartment-Step33): every item of
-- the meeting, as before. EnteredByName: the creator's User Name, " (inactive)" added when the account is
-- inactive, "(unknown user)" when no user row exists.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaByMeetingId]
@MeetingId INT
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
	ORDER BY va.AgendaStatusCode, va.SubjectNo;
END
GO

DECLARE @Installed INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingIdDeptId')), '') LIKE '%ManagerDepartment-Step33%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingId')), '') LIKE '%ManagerDepartment-Step33%')
    SET @Installed = @Installed + 1;

IF (@Installed = 2)
    PRINT 'Step 33 installed: spr_GetAgendaByMeetingIdDeptId and spr_GetAgendaByMeetingId (ManagerDepartment-Step33).';
ELSE
    RAISERROR('Step 33 is not complete: %d of 2 procedures carry the marker ManagerDepartment-Step33. Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
