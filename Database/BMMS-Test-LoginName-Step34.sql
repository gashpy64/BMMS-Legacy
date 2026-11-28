/* ============================================================================
   BMMS - Test of step 34 (the access log carries the login ID)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY on the database BMMS_Test: it stops with a message on any other
   database. It has no USE line: select BMMS_Test in SSMS first. Written for
   compatibility level 100. The file is plain ASCII. Run the whole file (F5);
   it can run twice in one window.

   LEAVES NO CHANGE. Checks 4 to 6 call spr_RecordLoginByUserId inside one
   transaction and roll it back: the rows it writes and the rows it closes
   are undone, and check 7 confirms it. Only the identity counter of
   Audit_Trial_Login moves on by two (the next real login gets a higher
   Audit_Trial_Login_Id). Audit_Trial_Login is locked for that moment: run it
   when nobody is logging in. It stops when a transaction is already open in
   the window.

   Checks, with PASS / FAIL / SKIPPED:
     1  Audit_Trial_Login.Login_Name exists, VARCHAR(50) NULL
     2  spr_RecordLoginByUserId carries the marker LoginName-Step34
     3  spr_RecordLoginByUserId keeps the parameters of step 1 (@UserId INT,
        @User_IP_Address VARCHAR(250), @Server_Url VARCHAR(250)), so the
        build before step UN2 still calls it
     4  a login of mgruser writes one open row with User_Id, Login_Name =
        Users.LoginName (exact spelling), the IP and URL given, no logout
        time (SKIPPED when mgruser does not exist)
     5  the same login closed every earlier row of mgruser (Login_Status 'C')
     6  a login of an id with no user row writes its row with Login_Name
        NULL and no error (SKIPPED when a foreign key on User_Id refuses such
        an id)
     7  after the rollback Audit_Trial_Login holds exactly the rows it held
        before the test, and no test row
   Checks 4 to 7 are SKIPPED when check 1 or 2 fails (step 34 not installed).
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@@TRANCOUNT > 0)
BEGIN
    RAISERROR('A transaction is open in this window. Commit or roll it back, then run the test again. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (No INT, CheckName NVARCHAR(200), Result VARCHAR(10), Detail NVARCHAR(400));
DECLARE @Detail NVARCHAR(400);

-- 1. the column
DECLARE @HasColumn INT = 0;
IF EXISTS (SELECT 1 FROM sys.columns sc JOIN sys.types t ON t.user_type_id = sc.user_type_id
           WHERE sc.object_id = OBJECT_ID('dbo.Audit_Trial_Login') AND sc.name = 'Login_Name'
           AND t.name = 'varchar' AND sc.max_length = 50 AND sc.is_nullable = 1)
    SET @HasColumn = 1;
SET @Detail = CASE WHEN @HasColumn = 1 THEN N'present'
                   WHEN COL_LENGTH('dbo.Audit_Trial_Login', 'Login_Name') IS NULL THEN N'missing: run step 34'
                   ELSE N'present but not VARCHAR(50) NULL' END;
INSERT INTO @T VALUES (1, N'Audit_Trial_Login.Login_Name VARCHAR(50) NULL', CASE WHEN @HasColumn = 1 THEN 'PASS' ELSE 'FAIL' END, @Detail);

-- 2. the marker
DECLARE @HasMarker INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_RecordLoginByUserId')), '') LIKE '%LoginName-Step34%')
    SET @HasMarker = 1;
INSERT INTO @T VALUES (2, N'spr_RecordLoginByUserId is the step 34 version', CASE WHEN @HasMarker = 1 THEN 'PASS' ELSE 'FAIL' END,
                       CASE WHEN @HasMarker = 1 THEN N'marker LoginName-Step34 present' ELSE N'marker missing: run step 34' END);

-- 3. the parameters
DECLARE @ParamsTotal INT, @ParamsRight INT;
SET @ParamsTotal = (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_RecordLoginByUserId'));
SET @ParamsRight = (SELECT COUNT(*) FROM sys.parameters p JOIN sys.types t ON t.user_type_id = p.user_type_id
                    WHERE p.object_id = OBJECT_ID('dbo.spr_RecordLoginByUserId')
                    AND ((p.name = '@UserId' AND t.name = 'int' AND p.parameter_id = 1)
                      OR (p.name = '@User_IP_Address' AND t.name = 'varchar' AND p.max_length = 250 AND p.parameter_id = 2)
                      OR (p.name = '@Server_Url' AND t.name = 'varchar' AND p.max_length = 250 AND p.parameter_id = 3)));
SET @Detail = CAST(@ParamsRight AS VARCHAR(12)) + N' of 3 parameters as in step 1; ' + CAST(@ParamsTotal AS VARCHAR(12)) + N' parameters in all';
INSERT INTO @T VALUES (3, N'Parameters unchanged (the old build still calls it)',
                       CASE WHEN @ParamsTotal = 3 AND @ParamsRight = 3 THEN 'PASS' ELSE 'FAIL' END, @Detail);

-- 4 to 7. one transaction, rolled back
DECLARE @TestIp VARCHAR(250) = 'step34-test';
DECLARE @TestUrl VARCHAR(250) = 'http://step34-test/Default.aspx';
DECLARE @TestUserId INT, @TestLogin VARCHAR(50);
DECLARE @UnknownUserId INT;
DECLARE @HasUserFk INT = 0;
DECLARE @RowsBefore INT, @RowsAfter INT, @TestRowsAfter INT;
DECLARE @NewRows INT, @NewLogin VARCHAR(50), @NewStatus VARCHAR(3), @NewLogout DATETIME, @LoginMatches INT;
DECLARE @StillOpen INT, @EarlierRows INT;
DECLARE @UnknownRows INT, @UnknownLogin VARCHAR(50);
DECLARE @ErrorText NVARCHAR(400);

SELECT @TestUserId = UserId, @TestLogin = LoginName FROM Users WHERE LoginName = 'mgruser';
SET @UnknownUserId = (SELECT ISNULL(MAX(UserId), 0) + 1000 FROM Users);
IF EXISTS (SELECT 1 FROM sys.foreign_key_columns fkc
           WHERE fkc.parent_object_id = OBJECT_ID('dbo.Audit_Trial_Login')
           AND COL_NAME(fkc.parent_object_id, fkc.parent_column_id) = 'User_Id')
    SET @HasUserFk = 1;

IF (@HasColumn = 1 AND @HasMarker = 1)
BEGIN
    SET @RowsBefore = (SELECT COUNT(*) FROM Audit_Trial_Login);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF (@TestUserId IS NOT NULL)
        BEGIN
            SET @EarlierRows = (SELECT COUNT(*) FROM Audit_Trial_Login WHERE [User_Id] = @TestUserId);

            EXEC dbo.spr_RecordLoginByUserId @UserId = @TestUserId, @User_IP_Address = @TestIp, @Server_Url = @TestUrl;

            -- Login_Name is read through sp_executesql, so this batch also compiles before step 34
            EXEC sp_executesql N'SELECT @rows = COUNT(*) FROM dbo.Audit_Trial_Login WHERE [User_Id] = @uid AND User_IP_Address = @ip AND Server_Url = @url;
                SELECT TOP 1 @login = Login_Name, @status = Login_Status, @logout = Logout_DateTime,
                       @matches = CASE WHEN Login_Name COLLATE Latin1_General_BIN = @expected COLLATE Latin1_General_BIN THEN 1 ELSE 0 END
                FROM dbo.Audit_Trial_Login WHERE [User_Id] = @uid AND User_IP_Address = @ip AND Server_Url = @url
                ORDER BY Audit_Trial_Login_Id DESC;',
                N'@uid INT, @ip VARCHAR(250), @url VARCHAR(250), @expected VARCHAR(50), @rows INT OUTPUT, @login VARCHAR(50) OUTPUT,
                  @status VARCHAR(3) OUTPUT, @logout DATETIME OUTPUT, @matches INT OUTPUT',
                @uid = @TestUserId, @ip = @TestIp, @url = @TestUrl, @expected = @TestLogin, @rows = @NewRows OUTPUT,
                @login = @NewLogin OUTPUT, @status = @NewStatus OUTPUT, @logout = @NewLogout OUTPUT, @matches = @LoginMatches OUTPUT;

            SET @StillOpen = (SELECT COUNT(*) FROM Audit_Trial_Login
                              WHERE [User_Id] = @TestUserId AND ISNULL(Login_Status, '') <> 'C'
                              AND NOT (User_IP_Address = @TestIp AND Server_Url = @TestUrl));
        END

        IF (@HasUserFk = 0)
        BEGIN
            EXEC dbo.spr_RecordLoginByUserId @UserId = @UnknownUserId, @User_IP_Address = @TestIp, @Server_Url = @TestUrl;

            EXEC sp_executesql N'SELECT @rows = COUNT(*) FROM dbo.Audit_Trial_Login WHERE [User_Id] = @uid AND User_IP_Address = @ip;
                SELECT TOP 1 @login = Login_Name FROM dbo.Audit_Trial_Login WHERE [User_Id] = @uid AND User_IP_Address = @ip
                ORDER BY Audit_Trial_Login_Id DESC;',
                N'@uid INT, @ip VARCHAR(250), @rows INT OUTPUT, @login VARCHAR(50) OUTPUT',
                @uid = @UnknownUserId, @ip = @TestIp, @rows = @UnknownRows OUTPUT, @login = @UnknownLogin OUTPUT;
        END

        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
            ROLLBACK TRANSACTION;
        SET @ErrorText = LEFT(ERROR_MESSAGE(), 400);
    END CATCH

    SET @RowsAfter = (SELECT COUNT(*) FROM Audit_Trial_Login);
    SET @TestRowsAfter = (SELECT COUNT(*) FROM Audit_Trial_Login WHERE User_IP_Address = @TestIp);

    IF (@ErrorText IS NOT NULL)
    BEGIN
        INSERT INTO @T VALUES (4, N'Login of mgruser writes its login ID', 'FAIL', N'error: ' + @ErrorText);
        INSERT INTO @T VALUES (5, N'The earlier rows of mgruser are closed', 'SKIPPED', N'see check 4');
        INSERT INTO @T VALUES (6, N'An id with no user row: Login_Name NULL', 'SKIPPED', N'see check 4');
    END
    ELSE
    BEGIN
        IF (@TestUserId IS NULL)
        BEGIN
            INSERT INTO @T VALUES (4, N'Login of mgruser writes its login ID', 'SKIPPED', N'no user with the login mgruser');
            INSERT INTO @T VALUES (5, N'The earlier rows of mgruser are closed', 'SKIPPED', N'no user with the login mgruser');
        END
        ELSE
        BEGIN
            SET @Detail = CAST(@NewRows AS VARCHAR(12)) + N' new row; Login_Name ' + ISNULL(N'"' + @NewLogin + N'"', N'NULL')
                        + N', status ' + ISNULL(@NewStatus, N'NULL') + N', logout ' + CASE WHEN @NewLogout IS NULL THEN N'none' ELSE N'set' END;
            INSERT INTO @T VALUES (4, N'Login of mgruser writes its login ID',
                                   CASE WHEN @NewRows = 1 AND @LoginMatches = 1 AND @NewStatus = 'O' AND @NewLogout IS NULL THEN 'PASS' ELSE 'FAIL' END, @Detail);

            SET @Detail = CAST(@EarlierRows AS VARCHAR(12)) + N' earlier rows; ' + CAST(@StillOpen AS VARCHAR(12)) + N' not closed';
            INSERT INTO @T VALUES (5, N'The earlier rows of mgruser are closed',
                                   CASE WHEN @StillOpen = 0 THEN 'PASS' ELSE 'FAIL' END, @Detail);
        END

        IF (@HasUserFk = 1)
            INSERT INTO @T VALUES (6, N'An id with no user row: Login_Name NULL', 'SKIPPED', N'a foreign key on Audit_Trial_Login.User_Id refuses such an id');
        ELSE
        BEGIN
            SET @Detail = N'UserId ' + CAST(@UnknownUserId AS VARCHAR(12)) + N': ' + CAST(@UnknownRows AS VARCHAR(12)) + N' row; Login_Name '
                        + ISNULL(N'"' + @UnknownLogin + N'"', N'NULL');
            INSERT INTO @T VALUES (6, N'An id with no user row: Login_Name NULL',
                                   CASE WHEN @UnknownRows = 1 AND @UnknownLogin IS NULL THEN 'PASS' ELSE 'FAIL' END, @Detail);
        END
    END

    SET @Detail = CAST(@RowsBefore AS VARCHAR(12)) + N' rows before, ' + CAST(@RowsAfter AS VARCHAR(12)) + N' after; '
                + CAST(@TestRowsAfter AS VARCHAR(12)) + N' test rows left';
    INSERT INTO @T VALUES (7, N'Rolled back: no row added or left', CASE WHEN @RowsAfter = @RowsBefore AND @TestRowsAfter = 0 THEN 'PASS' ELSE 'FAIL' END, @Detail);
END
ELSE
BEGIN
    INSERT INTO @T VALUES (4, N'Login of mgruser writes its login ID', 'SKIPPED', N'step 34 not installed');
    INSERT INTO @T VALUES (5, N'The earlier rows of mgruser are closed', 'SKIPPED', N'step 34 not installed');
    INSERT INTO @T VALUES (6, N'An id with no user row: Login_Name NULL', 'SKIPPED', N'step 34 not installed');
    INSERT INTO @T VALUES (7, N'Rolled back: no row added or left', 'SKIPPED', N'step 34 not installed');
END

SELECT No, CheckName, Result, Detail FROM @T ORDER BY No;

SELECT DB_NAME() AS CurrentDatabase, @@TRANCOUNT AS OpenTransactions;
GO

SET NOEXEC OFF;
GO
