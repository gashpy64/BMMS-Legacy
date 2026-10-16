/* ============================================================================
   BMMS — Fix #3/#4: Add reference-integrity checks to 8 delete procedures
   ----------------------------------------------------------------------------
   These 8 procedures currently do an unconditional DELETE with no check at
   all (confirmed by reading the live schema export). This script brings them
   in line with the pattern already used correctly by
   spr_DeleteMemberByMemberId and spr_DeleteMeetingByMeetingId:
     - count referencing rows in each dependent table
     - only delete if every count is zero
     - return a Result flag (1 = deleted, 0 = blocked) via SELECT

   Run this against the BMMS database (not a copy with a different schema —
   it assumes the table/column names confirmed in the verified schema doc).
   Safe to re-run: each uses CREATE OR ALTER, so running twice just
   re-applies the same definition.
   ============================================================================ */

-- 1. Committee — referenced by Meeting and Committee_Member
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteCommitteeByCommitteeId]
@CommitteeId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @CommitteeId);

	IF (@CountRec <= 0)
	BEGIN
		SET @CountRec = (SELECT COUNT(*) FROM Committee_Member WHERE CommitteeId = @CommitteeId);

		IF (@CountRec <= 0)
		BEGIN
			SET @Result = 1;
		END
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Committee WHERE CommitteeId = @CommitteeId;
	END

	SELECT @Result AS Result;
END
GO

-- 2. Committee_Member — checked against Attendance for the same
--    Committee+Member combination (no CommitteeMemberId FK exists anywhere,
--    so this is the closest real reference the schema actually has)
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteCommitteeMemberByCommitteeMemberId]
@CommitteeMemberId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
DECLARE @CommitteeId INT;
DECLARE @MemberId INT;
BEGIN
	SET @Result = 0;

	SELECT @CommitteeId = CommitteeId, @MemberId = MemberId
	FROM Committee_Member
	WHERE CommitteeMemberId = @CommitteeMemberId;

	SET @CountRec = (SELECT COUNT(*) FROM Attendance
	                 WHERE CommitteeId = @CommitteeId AND MemberId = @MemberId);

	IF (@CountRec <= 0)
	BEGIN
		SET @Result = 1;
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Committee_Member WHERE CommitteeMemberId = @CommitteeMemberId;
	END

	SELECT @Result AS Result;
END
GO

-- 3. Department — referenced by Agenda and Users
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteDepartmentByDeptId]
@DeptId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Agenda WHERE DepartmentId = @DeptId);

	IF (@CountRec <= 0)
	BEGIN
		SET @CountRec = (SELECT COUNT(*) FROM Users WHERE DepartmentId = @DeptId);

		IF (@CountRec <= 0)
		BEGIN
			SET @Result = 1;
		END
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Department WHERE DepartmentId = @DeptId;
	END

	SELECT @Result AS Result;
END
GO

-- 4. Designation — referenced by Users and Member
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteDesignationByDesignationId]
@DesignationId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Users WHERE DesignationId = @DesignationId);

	IF (@CountRec <= 0)
	BEGIN
		SET @CountRec = (SELECT COUNT(*) FROM Member WHERE DesignationId = @DesignationId);

		IF (@CountRec <= 0)
		BEGIN
			SET @Result = 1;
		END
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Designation WHERE DesignationId = @DesignationId;
	END

	SELECT @Result AS Result;
END
GO

-- 5. Member_Type — referenced by Committee_Member and Meeting_Member
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteMemberTypeByMemberTypeId]
@MemberTypeId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Committee_Member WHERE MemberTypeId = @MemberTypeId);

	IF (@CountRec <= 0)
	BEGIN
		SET @CountRec = (SELECT COUNT(*) FROM Meeting_Member WHERE MemberTypeId = @MemberTypeId);

		IF (@CountRec <= 0)
		BEGIN
			SET @Result = 1;
		END
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Member_Type WHERE MemberTypeId = @MemberTypeId;
	END

	SELECT @Result AS Result;
END
GO

-- 6. Subject_Type — referenced by Agenda
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteSubjectTypeBySubjectTypeId]
@SubjectTypeId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Agenda WHERE SubjectTypeId = @SubjectTypeId);

	IF (@CountRec <= 0)
	BEGIN
		SET @Result = 1;
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Subject_Type WHERE SubjectTypeId = @SubjectTypeId;
	END

	SELECT @Result AS Result;
END
GO

-- 7. Decision_Type — referenced by Minutes
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteDecisionTypeByDecisionTypeId]
@DecisionTypeId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Minutes WHERE DecisionTypeId = @DecisionTypeId);

	IF (@CountRec <= 0)
	BEGIN
		SET @Result = 1;
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Decision_Type WHERE DecisionTypeId = @DecisionTypeId;
	END

	SELECT @Result AS Result;
END
GO

-- 8. Users — referenced by Agenda (as approver) and by other Users (as manager)
--    Note: Alert_User_Map.UserId and ActionItem_User_Map.UserId also reference
--    Users in practice but have no FK; add those two checks too if you want
--    maximum safety, following the same pattern.
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteUserByUserId]
@UserId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Agenda
	                 WHERE MgrApprovedBy = @UserId OR ControllerApprovedBy = @UserId);

	IF (@CountRec <= 0)
	BEGIN
		SET @CountRec = (SELECT COUNT(*) FROM Users WHERE ManagerId = @UserId);

		IF (@CountRec <= 0)
		BEGIN
			SET @Result = 1;
		END
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Users WHERE UserId = @UserId;
	END

	SELECT @Result AS Result;
END
GO

/* ============================================================================
   Sanity check after running: confirm all 8 now return a Result column
   on a harmless no-op call (an ID of 0 won't match any real row, so nothing
   is deleted, but you'll see the SELECT work).
   ============================================================================ */
-- EXEC spr_DeleteDepartmentByDeptId @DeptId = 0;
-- EXEC spr_DeleteUserByUserId @UserId = 0;
