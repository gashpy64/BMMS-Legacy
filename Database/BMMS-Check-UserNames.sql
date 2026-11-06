/* ============================================================================
   BMMS - User names: which users still have no real name (step UN-data)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   READ ONLY. It reads Users, Roles and Department; it creates, changes and
   deletes nothing, and it can run on BMMS as well as on a copy.

   Users.LoginName is the login ID (for example mgruser). Users.UserName is
   the person's actual name, shown wherever a person or a role is shown. The
   names are entered in User Master; this script lists the users whose name
   still needs attention.

   Result 1  the role words compared against: every RoleName and every
             RoleCode in Roles, once each (ignoring case). Also printed in
             the Messages tab.
   Result 2  one row per user (also inactive users and the system account):
             UserId, LoginName, UserName, RoleName, DepartmentName, Active
             (Yes/No), Problem. Problem lists every problem of the user,
             separated by "; ", blank when there is none:
               blank name        UserName is empty or spaces only
               name equals login UserName is the LoginName
               name is a role word
                                 UserName is a RoleName or RoleCode of Roles
               duplicate name    another user has the same UserName
               duplicate login   another user has the same LoginName
             Every comparison ignores case and leading and trailing spaces.
             A blank name is not compared further (it is not "equal to the
             login" and not a duplicate of another blank name).
   Result 3  the number of users per problem (zero included), the number of
             users with at least one problem, and the number of users.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was read.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

-- The role words: every RoleName and RoleCode, trimmed, once each ignoring case
DECLARE @RoleWords TABLE (Word VARCHAR(50) NOT NULL);

INSERT INTO @RoleWords (Word)
SELECT MIN(w.Word)
FROM (SELECT LTRIM(RTRIM(RoleName)) AS Word FROM Roles
      UNION ALL
      SELECT LTRIM(RTRIM(RoleCode)) FROM Roles) w
WHERE w.Word IS NOT NULL AND w.Word <> ''
GROUP BY UPPER(w.Word);

DECLARE @RoleWordList VARCHAR(2000);
SET @RoleWordList = ISNULL(STUFF((SELECT ', ' + rw.Word FROM @RoleWords rw ORDER BY UPPER(rw.Word)
                                  FOR XML PATH(''), TYPE).value('.', 'VARCHAR(2000)'), 1, 2, ''), '(none)');
PRINT 'Database: ' + DB_NAME();
PRINT 'Role words compared (every RoleName and RoleCode in Roles, ignoring case): ' + @RoleWordList;

SELECT rw.Word AS RoleWordCompared
FROM @RoleWords rw
ORDER BY UPPER(rw.Word);

-- One row per user with a flag per problem
DECLARE @UserRows TABLE
(
    UserId INT NOT NULL,
    LoginName VARCHAR(50) NULL,
    UserName VARCHAR(50) NULL,
    RoleName VARCHAR(50) NULL,
    DepartmentName VARCHAR(200) NULL,
    Active VARCHAR(3) NOT NULL,
    BlankName INT NOT NULL,
    NameIsLogin INT NOT NULL,
    NameIsRoleWord INT NOT NULL,
    DuplicateName INT NOT NULL,
    DuplicateLogin INT NOT NULL
);

INSERT INTO @UserRows
SELECT
    u.UserId,
    u.LoginName,
    u.UserName,
    r.RoleName,
    d.DepartmentName,
    CASE WHEN u.AccountStatus = 1 THEN 'Yes' ELSE 'No' END,
    CASE WHEN LTRIM(RTRIM(ISNULL(u.UserName, ''))) = '' THEN 1 ELSE 0 END,
    CASE WHEN LTRIM(RTRIM(ISNULL(u.UserName, ''))) <> ''
          AND UPPER(LTRIM(RTRIM(u.UserName))) = UPPER(LTRIM(RTRIM(ISNULL(u.LoginName, '')))) THEN 1 ELSE 0 END,
    CASE WHEN LTRIM(RTRIM(ISNULL(u.UserName, ''))) <> ''
          AND EXISTS (SELECT 1 FROM @RoleWords rw WHERE UPPER(rw.Word) = UPPER(LTRIM(RTRIM(u.UserName)))) THEN 1 ELSE 0 END,
    CASE WHEN LTRIM(RTRIM(ISNULL(u.UserName, ''))) <> ''
          AND EXISTS (SELECT 1 FROM Users o
                      WHERE o.UserId <> u.UserId
                      AND UPPER(LTRIM(RTRIM(o.UserName))) = UPPER(LTRIM(RTRIM(u.UserName)))) THEN 1 ELSE 0 END,
    CASE WHEN LTRIM(RTRIM(ISNULL(u.LoginName, ''))) <> ''
          AND EXISTS (SELECT 1 FROM Users o
                      WHERE o.UserId <> u.UserId
                      AND UPPER(LTRIM(RTRIM(o.LoginName))) = UPPER(LTRIM(RTRIM(u.LoginName)))) THEN 1 ELSE 0 END
FROM Users u
LEFT JOIN Roles r ON r.RoleId = u.RoleId
LEFT JOIN Department d ON d.DepartmentId = u.DepartmentId;

SELECT
    ur.UserId,
    ur.LoginName,
    ur.UserName,
    ur.RoleName,
    ur.DepartmentName,
    ur.Active,
    ISNULL(STUFF(  CASE WHEN ur.BlankName = 1 THEN '; blank name' ELSE '' END
                 + CASE WHEN ur.NameIsLogin = 1 THEN '; name equals login' ELSE '' END
                 + CASE WHEN ur.NameIsRoleWord = 1 THEN '; name is a role word' ELSE '' END
                 + CASE WHEN ur.DuplicateName = 1 THEN '; duplicate name' ELSE '' END
                 + CASE WHEN ur.DuplicateLogin = 1 THEN '; duplicate login' ELSE '' END, 1, 2, ''), '') AS Problem
FROM @UserRows ur
ORDER BY ur.UserId;

-- The counts per problem
DECLARE @UsersTotal INT, @UsersWithProblem INT;
SET @UsersTotal = (SELECT COUNT(*) FROM @UserRows);
SET @UsersWithProblem = (SELECT COUNT(*) FROM @UserRows
                         WHERE BlankName + NameIsLogin + NameIsRoleWord + DuplicateName + DuplicateLogin > 0);

SELECT c.Problem, c.Users
FROM (
    SELECT 1 AS Ord, 'blank name' AS Problem, ISNULL(SUM(BlankName), 0) AS Users FROM @UserRows
    UNION ALL SELECT 2, 'name equals login', ISNULL(SUM(NameIsLogin), 0) FROM @UserRows
    UNION ALL SELECT 3, 'name is a role word', ISNULL(SUM(NameIsRoleWord), 0) FROM @UserRows
    UNION ALL SELECT 4, 'duplicate name', ISNULL(SUM(DuplicateName), 0) FROM @UserRows
    UNION ALL SELECT 5, 'duplicate login', ISNULL(SUM(DuplicateLogin), 0) FROM @UserRows
    UNION ALL SELECT 6, 'users with at least one problem', @UsersWithProblem
    UNION ALL SELECT 7, 'users', @UsersTotal
) c
ORDER BY c.Ord;
GO

SET NOEXEC OFF;
GO
