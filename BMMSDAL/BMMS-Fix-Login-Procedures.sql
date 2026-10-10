/* ============================================================================
   BMMS — Critical fix #1 (password hashing): login stored procedures
   ----------------------------------------------------------------------------
   Why this is needed:
   spr_GetUserByLoginName currently uses "Password = @Password" to decide
   whether to write the login audit row (Audit_Trial_Login, status 'O').
   Once passwords are salted hashes, the application can no longer compute a
   value that matches the stored password, so that audit row would silently
   stop being written for every login.

   The fix splits the work:
     1. spr_GetUserByLoginName  -> lookup only (by LoginName). The application
        verifies the password in C#. Signature is unchanged on purpose so no
        DAL/BAL change is needed for this one; @Password is now ignored.
     2. spr_RecordLoginByUserId -> new. Called by the application only AFTER
        the password has been verified. Same audit logic as before.

   Safe to re-run (CREATE OR ALTER).
   ============================================================================ */

CREATE OR ALTER PROCEDURE [dbo].[spr_GetUserByLoginName]
	@LoginName VARCHAR(50),
	@Password VARCHAR(MAX),          -- retained for compatibility; ignored
	@User_IP_Address VARCHAR(250),   -- retained for compatibility; ignored
	@Server_Url VARCHAR(250)         -- retained for compatibility; ignored
AS
BEGIN
	SELECT Users.*,
	(SELECT DesignationName FROM Designation WHERE DesignationId = Users.DesignationId) AS DesignationName,
	Roles.RoleCode,
	Roles.RoleName
	FROM Users
	JOIN Roles ON Roles.RoleId = Users.RoleId
	WHERE
	Users.LoginName = @LoginName COLLATE SQL_Latin1_General_CP1_CS_AS;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spr_RecordLoginByUserId]
	@UserId INT,
	@User_IP_Address VARCHAR(250),
	@Server_Url VARCHAR(250)
AS
BEGIN
	-- Same behaviour as the block that used to live inside
	-- spr_GetUserByLoginName: close any earlier sessions, open a new one.
	UPDATE [Audit_Trial_Login] SET [Login_Status] = 'C' WHERE [User_Id] = @UserId;

	INSERT INTO [Audit_Trial_Login]
		([User_Id], [Login_DateTime], [Login_Status], [User_IP_Address], [Server_Url])
	VALUES
		(@UserId, GETDATE(), 'O', @User_IP_Address, @Server_Url);
END
GO
