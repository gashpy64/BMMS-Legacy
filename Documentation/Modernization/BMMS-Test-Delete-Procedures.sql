/* ============================================================================
   BMMS — Validation script for the 7 remaining fixed delete procedures
   ----------------------------------------------------------------------------
   For each procedure, this script:
     1. Finds a row that IS referenced elsewhere -> expects Result = 0 (blocked)
     2. Finds a row that is NOT referenced anywhere -> expects Result = 1,
        then confirms the row is actually gone afterward

   Run this against a DEV/TEST copy of the database, not production data —
   the "unreferenced" branch of each test actually deletes a real row.
   If a given test prints "No unreferenced row found", that's informational,
   not a failure — it just means every row of that type currently has a
   reference, so only the "blocked" half of that test could run.

   Read the PRINT output in SSMS's Messages tab as you go.
   ============================================================================ */

SET NOCOUNT ON;

-------------------------------------------------------------------------------
PRINT '=== 1. Committee ===';
-------------------------------------------------------------------------------
DECLARE @RefCommitteeId INT = (SELECT TOP 1 CommitteeId FROM Meeting);
DECLARE @UnrefCommitteeId INT = (
    SELECT TOP 1 c.CommitteeId FROM Committee c
    WHERE NOT EXISTS (SELECT 1 FROM Meeting m WHERE m.CommitteeId = c.CommitteeId)
      AND NOT EXISTS (SELECT 1 FROM Committee_Member cm WHERE cm.CommitteeId = c.CommitteeId)
);

IF @RefCommitteeId IS NOT NULL
BEGIN
    PRINT '  Referenced CommitteeId = ' + CAST(@RefCommitteeId AS VARCHAR) + ' (expect Result = 0):';
    EXEC spr_DeleteCommitteeByCommitteeId @CommitteeId = @RefCommitteeId;
END
ELSE PRINT '  No referenced Committee found to test.';

IF @UnrefCommitteeId IS NOT NULL
BEGIN
    PRINT '  Unreferenced CommitteeId = ' + CAST(@UnrefCommitteeId AS VARCHAR) + ' (expect Result = 1):';
    EXEC spr_DeleteCommitteeByCommitteeId @CommitteeId = @UnrefCommitteeId;
    PRINT '  Row count after (expect 0):';
    SELECT COUNT(*) AS RemainingRows FROM Committee WHERE CommitteeId = @UnrefCommitteeId;
END
ELSE PRINT '  No unreferenced Committee found — skipped delete test.';


-------------------------------------------------------------------------------
PRINT '=== 2. Committee_Member ===';
-------------------------------------------------------------------------------
DECLARE @RefCommitteeMemberId INT = (
    SELECT TOP 1 cm.CommitteeMemberId FROM Committee_Member cm
    WHERE EXISTS (SELECT 1 FROM Attendance a WHERE a.CommitteeId = cm.CommitteeId AND a.MemberId = cm.MemberId)
);
DECLARE @UnrefCommitteeMemberId INT = (
    SELECT TOP 1 cm.CommitteeMemberId FROM Committee_Member cm
    WHERE NOT EXISTS (SELECT 1 FROM Attendance a WHERE a.CommitteeId = cm.CommitteeId AND a.MemberId = cm.MemberId)
);

IF @RefCommitteeMemberId IS NOT NULL
BEGIN
    PRINT '  Referenced CommitteeMemberId = ' + CAST(@RefCommitteeMemberId AS VARCHAR) + ' (expect Result = 0):';
    EXEC spr_DeleteCommitteeMemberByCommitteeMemberId @CommitteeMemberId = @RefCommitteeMemberId;
END
ELSE PRINT '  No referenced Committee_Member found to test.';

IF @UnrefCommitteeMemberId IS NOT NULL
BEGIN
    PRINT '  Unreferenced CommitteeMemberId = ' + CAST(@UnrefCommitteeMemberId AS VARCHAR) + ' (expect Result = 1):';
    EXEC spr_DeleteCommitteeMemberByCommitteeMemberId @CommitteeMemberId = @UnrefCommitteeMemberId;
    PRINT '  Row count after (expect 0):';
    SELECT COUNT(*) AS RemainingRows FROM Committee_Member WHERE CommitteeMemberId = @UnrefCommitteeMemberId;
END
ELSE PRINT '  No unreferenced Committee_Member found — skipped delete test.';


-------------------------------------------------------------------------------
PRINT '=== 3. Designation ===';
-------------------------------------------------------------------------------
DECLARE @RefDesignationId INT = (
    SELECT TOP 1 DesignationId FROM (
        SELECT DesignationId FROM Users
        UNION ALL
        SELECT DesignationId FROM Member
    ) x WHERE DesignationId IS NOT NULL
);
DECLARE @UnrefDesignationId INT = (
    SELECT TOP 1 d.DesignationId FROM Designation d
    WHERE NOT EXISTS (SELECT 1 FROM Users u WHERE u.DesignationId = d.DesignationId)
      AND NOT EXISTS (SELECT 1 FROM Member m WHERE m.DesignationId = d.DesignationId)
);

IF @RefDesignationId IS NOT NULL
BEGIN
    PRINT '  Referenced DesignationId = ' + CAST(@RefDesignationId AS VARCHAR) + ' (expect Result = 0):';
    EXEC spr_DeleteDesignationByDesignationId @DesignationId = @RefDesignationId;
END
ELSE PRINT '  No referenced Designation found to test.';

IF @UnrefDesignationId IS NOT NULL
BEGIN
    PRINT '  Unreferenced DesignationId = ' + CAST(@UnrefDesignationId AS VARCHAR) + ' (expect Result = 1):';
    EXEC spr_DeleteDesignationByDesignationId @DesignationId = @UnrefDesignationId;
    PRINT '  Row count after (expect 0):';
    SELECT COUNT(*) AS RemainingRows FROM Designation WHERE DesignationId = @UnrefDesignationId;
END
ELSE PRINT '  No unreferenced Designation found — skipped delete test.';


-------------------------------------------------------------------------------
PRINT '=== 4. Member_Type ===';
-------------------------------------------------------------------------------
DECLARE @RefMemberTypeId INT = (
    SELECT TOP 1 MemberTypeId FROM (
        SELECT MemberTypeId FROM Committee_Member
        UNION ALL
        SELECT MemberTypeId FROM Meeting_Member
    ) x WHERE MemberTypeId IS NOT NULL
);
DECLARE @UnrefMemberTypeId INT = (
    SELECT TOP 1 mt.MemberTypeId FROM Member_Type mt
    WHERE NOT EXISTS (SELECT 1 FROM Committee_Member cm WHERE cm.MemberTypeId = mt.MemberTypeId)
      AND NOT EXISTS (SELECT 1 FROM Meeting_Member mm WHERE mm.MemberTypeId = mt.MemberTypeId)
);

IF @RefMemberTypeId IS NOT NULL
BEGIN
    PRINT '  Referenced MemberTypeId = ' + CAST(@RefMemberTypeId AS VARCHAR) + ' (expect Result = 0):';
    EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @RefMemberTypeId;
END
ELSE PRINT '  No referenced Member_Type found to test.';

IF @UnrefMemberTypeId IS NOT NULL
BEGIN
    PRINT '  Unreferenced MemberTypeId = ' + CAST(@UnrefMemberTypeId AS VARCHAR) + ' (expect Result = 1):';
    EXEC spr_DeleteMemberTypeByMemberTypeId @MemberTypeId = @UnrefMemberTypeId;
    PRINT '  Row count after (expect 0):';
    SELECT COUNT(*) AS RemainingRows FROM Member_Type WHERE MemberTypeId = @UnrefMemberTypeId;
END
ELSE PRINT '  No unreferenced Member_Type found — skipped delete test.';


-------------------------------------------------------------------------------
PRINT '=== 5. Subject_Type ===';
-------------------------------------------------------------------------------
DECLARE @RefSubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Agenda);
DECLARE @UnrefSubjectTypeId INT = (
    SELECT TOP 1 st.SubjectTypeId FROM Subject_Type st
    WHERE NOT EXISTS (SELECT 1 FROM Agenda a WHERE a.SubjectTypeId = st.SubjectTypeId)
);

IF @RefSubjectTypeId IS NOT NULL
BEGIN
    PRINT '  Referenced SubjectTypeId = ' + CAST(@RefSubjectTypeId AS VARCHAR) + ' (expect Result = 0):';
    EXEC spr_DeleteSubjectTypeBySubjectTypeId @SubjectTypeId = @RefSubjectTypeId;
END
ELSE PRINT '  No referenced Subject_Type found to test.';

IF @UnrefSubjectTypeId IS NOT NULL
BEGIN
    PRINT '  Unreferenced SubjectTypeId = ' + CAST(@UnrefSubjectTypeId AS VARCHAR) + ' (expect Result = 1):';
    EXEC spr_DeleteSubjectTypeBySubjectTypeId @SubjectTypeId = @UnrefSubjectTypeId;
    PRINT '  Row count after (expect 0):';
    SELECT COUNT(*) AS RemainingRows FROM Subject_Type WHERE SubjectTypeId = @UnrefSubjectTypeId;
END
ELSE PRINT '  No unreferenced Subject_Type found — skipped delete test.';


-------------------------------------------------------------------------------
PRINT '=== 6. Decision_Type ===';
-------------------------------------------------------------------------------
DECLARE @RefDecisionTypeId INT = (SELECT TOP 1 DecisionTypeId FROM Minutes WHERE DecisionTypeId IS NOT NULL);
DECLARE @UnrefDecisionTypeId INT = (
    SELECT TOP 1 dt.DecisionTypeId FROM Decision_Type dt
    WHERE NOT EXISTS (SELECT 1 FROM Minutes m WHERE m.DecisionTypeId = dt.DecisionTypeId)
);

IF @RefDecisionTypeId IS NOT NULL
BEGIN
    PRINT '  Referenced DecisionTypeId = ' + CAST(@RefDecisionTypeId AS VARCHAR) + ' (expect Result = 0):';
    EXEC spr_DeleteDecisionTypeByDecisionTypeId @DecisionTypeId = @RefDecisionTypeId;
END
ELSE PRINT '  No referenced Decision_Type found to test.';

IF @UnrefDecisionTypeId IS NOT NULL
BEGIN
    PRINT '  Unreferenced DecisionTypeId = ' + CAST(@UnrefDecisionTypeId AS VARCHAR) + ' (expect Result = 1):';
    EXEC spr_DeleteDecisionTypeByDecisionTypeId @DecisionTypeId = @UnrefDecisionTypeId;
    PRINT '  Row count after (expect 0):';
    SELECT COUNT(*) AS RemainingRows FROM Decision_Type WHERE DecisionTypeId = @UnrefDecisionTypeId;
END
ELSE PRINT '  No unreferenced Decision_Type found — skipped delete test.';


-------------------------------------------------------------------------------
PRINT '=== 7. Users ===';
-------------------------------------------------------------------------------
DECLARE @RefUserId INT = (
    SELECT TOP 1 UserId FROM (
        SELECT MgrApprovedBy AS UserId FROM Agenda WHERE MgrApprovedBy IS NOT NULL
        UNION ALL
        SELECT ControllerApprovedBy FROM Agenda WHERE ControllerApprovedBy IS NOT NULL
        UNION ALL
        SELECT ManagerId FROM Users WHERE ManagerId IS NOT NULL
    ) x
);
DECLARE @UnrefUserId INT = (
    SELECT TOP 1 u.UserId FROM Users u
    WHERE NOT EXISTS (SELECT 1 FROM Agenda a WHERE a.MgrApprovedBy = u.UserId OR a.ControllerApprovedBy = u.UserId)
      AND NOT EXISTS (SELECT 1 FROM Users u2 WHERE u2.ManagerId = u.UserId)
);

IF @RefUserId IS NOT NULL
BEGIN
    PRINT '  Referenced UserId = ' + CAST(@RefUserId AS VARCHAR) + ' (expect Result = 0):';
    EXEC spr_DeleteUserByUserId @UserId = @RefUserId;
END
ELSE PRINT '  No referenced User found to test.';

IF @UnrefUserId IS NOT NULL
BEGIN
    PRINT '  CAUTION: this will actually delete UserId = ' + CAST(@UnrefUserId AS VARCHAR) + ' (expect Result = 1).';
    PRINT '  Comment out the EXEC below if you want to keep this user.';
    EXEC spr_DeleteUserByUserId @UserId = @UnrefUserId;
    PRINT '  Row count after (expect 0):';
    SELECT COUNT(*) AS RemainingRows FROM Users WHERE UserId = @UnrefUserId;
END
ELSE PRINT '  No unreferenced User found — skipped delete test.';


PRINT '=== Done. Scroll up through the Messages tab and check each Result value above. ===';
