/* ============================================================================
   BMMS - Inactive users and the Admin role in mails, action items and Reset
   Password (step 55, step IU1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decisions 2026-11-25 (requirement IU1, plan approved with seven
   answers and the G3 fix):
     R1 The Meeting and Committee Created / Updated mails (MC, MU, CC, CU) go
        to exactly the users who get the alert row of the same event: active,
        not the protected system account, not the Admin role, not the person
        who saved (who stays the To of the mail). One rule for the alert rows
        and the mail: fn_FunctionalUsers. A user without an address keeps the
        alert and gets no mail. The Committee mail is sent again (it was
        switched off in the code since the baseline).
     R2 The action item rows of a minutes finalisation go to fn_FunctionalUsers
        only. No row for a user made active later. The late action item route
        (inactive creator: the active Controllers) is unchanged.
     R3 Rows already saved (of the Admin role, of users now inactive) are kept.
     R4 Reset Password reads the address and the status of the chosen user
        from the database, under the same acting-user check as the reset
        (spr_GetResetPasswordMail): never from the page.

   Objects (each carries the text InactiveUsers-Step55; a replaced text keeps
   the markers of its earlier steps)
     fn_FunctionalUsers               NEW (the rule)
     spr_GetMeetingCommitteeMailId    NEW (the Bcc of the Meeting and
                                      Committee mails)
     spr_GetResetPasswordMail         NEW (Reset Password: address, status)
     spr_AddEditMeeting               REPLACED (step 53): the MC / MU rows
                                      read fn_FunctionalUsers (same users)
     spr_AddEditCommittee             REPLACED (step 53): the CC / CU rows
                                      read fn_FunctionalUsers (same users)
     spr_MinutesFinalizeByMeetingId   REPLACED (step 23): the rows read
                                      fn_FunctionalUsers (the Admin role out)
   No table, view, column or data change; nothing granted; no back-fill and
   no row deleted.

   Order: installed after step 54. Needs steps 23, 53 and 54 and stops
   otherwise. The script was built from the three texts as installed
   (identical in BMMS_Test and BMMS_Quality on 2026-11-25; SHA-1 of the text
   without carriage returns, in pieces of 4,000 characters) and stops,
   changing nothing, when one of them is neither that text nor already the
   step 55 text (a later change would be lost). Safe to re-run.

   Re-run of an earlier step: the Fix scripts of steps 23 and 53 and the
   Rollback script of step 53 stop while step 55 is installed (guards added
   in step IU1). The Fix script of step 24 already stops while step 53 is
   installed, which step 55 needs. A re-run of step 8, 15, 16, 17, 18 or 21
   brings back an older text of one of the three: step 55 reads Partly; tell
   the Consultant (this script then refuses that text as unknown;
   BMMS-Rollback-InactiveUsers-Step55.sql does not look at the texts before
   it writes the three back, and compares them only at its end).

   BMMS-Rollback-InactiveUsers-Step55.sql puts the three texts back letter
   for letter and drops the three new objects. Roll back the build of step
   IU1 FIRST: the Meeting, Committee and Reset Password pages of IU1 call the
   new procedures.

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
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), CHAR(13), ''); SET @H1 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H1 = @H1 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditCommittee')), CHAR(13), ''); SET @H2 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H2 = @H2 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')), CHAR(13), ''); SET @H3 = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @H3 = @H3 + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
INSERT INTO @Texts (Name, Hash, BuiltFrom) VALUES
('spr_AddEditMeeting', @H1, 'A058BEE902EF43E0DFF8F2C7367E585C7E2EECFC6E5328D4EBE58FF6EDBAFBE9698513834C64682A'),
('spr_AddEditCommittee', @H2, '817EA0F49B8526EF915C83EB02DA9F7CAA07E073'),
('spr_MinutesFinalizeByMeetingId', @H3, 'FB127BB7509FE9C35B7BD3AB4C0848ACAC641E7F');

-- A text that is neither the one this step was built from nor already the step 55 text
SET @Bad = (SELECT TOP 1 t.Name FROM @Texts t
            WHERE ISNULL(t.Hash, '') <> t.BuiltFrom
              AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + t.Name)), '') NOT LIKE '%InactiveUsers-Step55%'
            ORDER BY t.Name);

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')), '') NOT LIKE '%WorkflowOrder-Step23%')
BEGIN
    RAISERROR('Step 23 (BMMS-Fix-WorkflowOrder-Step23.sql) is not installed in "%s". The steps are installed in order: run steps 23 to 54 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_DepartmentManagers', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') NOT LIKE '%DepartmentApprovers-Step53%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditCommittee')), '') NOT LIKE '%DepartmentApprovers-Step53%')
BEGIN
    RAISERROR('Step 53 (BMMS-Fix-DepartmentApprovers-Step53.sql) is not installed in "%s". Run steps 53 and 54 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_ManagerDepartments', 'IF') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%ManagerScope-Step54%')
BEGIN
    RAISERROR('Step 54 (BMMS-Fix-ManagerScope-Step54.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@Bad IS NOT NULL)
BEGIN
    RAISERROR('%s in "%s" is not the text this step was built from and not the step 55 text either: a change made since would be lost. Tell the Consultant. Nothing was changed.', 16, 1, @Bad, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- The users who get functional alerts, mails and action item rows (InactiveUsers-Step55, step IU1)
-------------------------------------------------------------------------------
-- One row per user who is active (AccountStatus 1), not the protected system account (IsSystem 0) and not of the
-- Admin role: the filter that steps 17, 18 and 53 wrote into each procedure, kept in one place. A user without a
-- role row counts (as before). The Meeting and Committee alert rows (spr_AddEditMeeting, spr_AddEditCommittee: other
-- than the person who saved), their mail (spr_GetMeetingCommitteeMailId) and the action item rows of a minutes
-- finalisation (spr_MinutesFinalizeByMeetingId) read it. EmailId as stored (may be empty).
CREATE OR ALTER FUNCTION [dbo].[fn_FunctionalUsers]
()
RETURNS TABLE
AS
RETURN
SELECT u.UserId, u.EmailId
FROM dbo.Users u
WHERE u.AccountStatus = 1
  AND u.IsSystem = 0
  AND NOT EXISTS (SELECT 1 FROM dbo.Roles ar WHERE ar.RoleId = u.RoleId AND ar.RoleCode = 'admin');
GO

-------------------------------------------------------------------------------
-- The Bcc of the Meeting and Committee Created / Updated mails (InactiveUsers-Step55, step IU1)
-------------------------------------------------------------------------------
-- The addresses of fn_FunctionalUsers other than the acting user (the person who saved, who is the To of the mail):
-- the users the MC / MU / CC / CU alert rows are written for, those with an address (blank left out), one row per
-- user, by UserId. Reads only. Called right after a successful save. @Reason (OUTPUT): 0 and the rows when allowed;
-- 8 when the acting user is missing, 0 or inactive; 4 for a role other than Admin and Controller (the two roles of
-- the Meeting and Committee pages); then no rows. The protected system account has the Admin role and is allowed,
-- as for the save itself.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMeetingCommitteeMailId]
@ActingUserId INT = NULL,
@Reason INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Role VARCHAR(50);

	SET @Role = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	             WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

	IF (ISNULL(@ActingUserId, 0) = 0 OR @Role IS NULL)
		SET @Reason = 8;
	ELSE IF (@Role NOT IN ('admin', 'controller'))
		SET @Reason = 4;
	ELSE
		SET @Reason = 0;

	SELECT fu.EmailId
	FROM dbo.fn_FunctionalUsers() fu
	WHERE @Reason = 0
	  AND fu.UserId <> @ActingUserId
	  AND LTRIM(RTRIM(ISNULL(fu.EmailId, ''))) <> ''
	ORDER BY fu.UserId;
END
GO

-------------------------------------------------------------------------------
-- Reset Password: the address and the status of the chosen user (InactiveUsers-Step55, step IU1)
-------------------------------------------------------------------------------
-- The stored EmailId and IsActive (1 when AccountStatus is 1) of @UserId, under the rule of the reset itself
-- (fn_UserChangeRefusal, action 'ResetPassword', as spr_ResetPasswordByUserId): the page never sends an address.
-- Reads only. @Reason (OUTPUT): 0 and one row when allowed; otherwise the refusal of the rule (8 acting user missing,
-- 0 or inactive; 4 another role than Admin for another user's account; 7 the protected system account) or 4 for a
-- user that does not exist; then no row.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetResetPasswordMail]
@ActingUserId INT = NULL,
@UserId INT = NULL,
@Reason INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	IF (ISNULL(@ActingUserId, 0) = 0)
		SET @Reason = 8;
	ELSE
		SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'ResetPassword', NULL);

	IF (@Reason = 0 AND NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @UserId))
		SET @Reason = 4;

	SELECT u.EmailId, CAST(CASE WHEN u.AccountStatus = 1 THEN 1 ELSE 0 END AS INT) AS IsActive
	FROM Users u
	WHERE @Reason = 0
	  AND u.UserId = @UserId;
END
GO

-------------------------------------------------------------------------------
-- spr_AddEditMeeting (replaced; the step 53 text with the MC / MU rows from fn_FunctionalUsers)
-------------------------------------------------------------------------------
GO

-- Meeting - add / edit; date and committee locked by attendance, committee by agenda items (MeetingLocks-Step16).
-- The alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- Dates (MeetingDates-Step24): both required; on create the meeting date and the agenda submission date not
-- before today; on edit a changed date not before today; the submission date always on or before the meeting
-- date. Today is the database server date; dates are compared as dates. Refused with Reason 16, ReasonDetail
-- Missing, MeetingBeforeToday, SubmissionBeforeToday or SubmissionAfterMeeting.
-- DepartmentApprovers-Step53 (step UD1b): the MC and MU alerts no longer go to the Admin role.
-- InactiveUsers-Step55 (step IU1): the MC and MU alert rows are written for fn_FunctionalUsers (active, not the
-- system account, not the Admin role) other than the creator, the rule the Meeting mail reads too
-- (spr_GetMeetingCommitteeMailId). The same users as the step 53 filter.
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditMeeting]
(@Code VARCHAR(50),
@MeetingId INT,
@MeetingNo VARCHAR(10),
@CommitteeId INT,
@Place VARCHAR(50),
@Venue VARCHAR(250),
@MeetingDate DATETIME,
@MeetingTime VARCHAR(10),
@AgendaSubmissionDate DATETIME,
@MeetingColorCode VARCHAR(10),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT)
AS
	DECLARE @alert_id INT
	DECLARE @alert_type_id INT
	DECLARE @meeting_id INT
	DECLARE @DepartmentId INT
	DECLARE @SourceType VARCHAR(150)
	DECLARE @DisplayText VARCHAR(150)
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @Found INT;
	DECLARE @OldMeetingDate DATETIME;
	DECLARE @OldCommitteeId INT;
	DECLARE @DateChanged INT;
	DECLARE @CommitteeChanged INT;
	DECLARE @Today DATE;
	DECLARE @OldSubmissionDate DATETIME;
	DECLARE @SubmissionChanged INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';
	SET @Today = CAST(GETDATE() AS date);

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION MeetingSave;

		SET @DepartmentId = (SELECT DepartmentId FROM Users WHERE UserId = @CreatedBy);

		IF (@Code = 'Save')
		BEGIN
			-- MeetingDates-Step24
			IF (@MeetingDate IS NULL OR @AgendaSubmissionDate IS NULL)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'Missing';
			END
			ELSE IF (CAST(@MeetingDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'MeetingBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) > CAST(@MeetingDate AS date))
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionAfterMeeting';
			END
			ELSE
			BEGIN
				INSERT INTO Meeting
				(MeetingNo, CommitteeId, Place, Venue, MeetingDate,
				MeetingTime, AgendaSubmissionDate, MeetingColorCode, CreatedOn, CreatedBy)
				VALUES
				(@MeetingNo, @CommitteeId, @Place, @Venue,@MeetingDate,
				@MeetingTime, @AgendaSubmissionDate, @MeetingColorCode, @CreatedOn, @CreatedBy);

				SET @meeting_id = @@identity;

				SET @SourceType = 'Meeting'
				SET @DisplayText = 'Meeting (' + (SELECT CommitteeCode FROM Committee WHERE
					 CommitteeId = @CommitteeId) + '-' + @MeetingNo + ')';

				INSERT INTO Alert_Master
				(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
				VALUES
				(@SourceType, 0, @meeting_id, @DisplayText, 'MC', 3, @CommitteeId, @CreatedOn, @CreatedBy);

				SET @alert_id = @@identity;

				INSERT INTO Alert_User_Map
				(AlertId, [UserId], ReadStatus, StatusId)
				(SELECT @alert_id, fu.[UserId],0,1 FROM dbo.fn_FunctionalUsers() fu WHERE fu.UserId <> @CreatedBy);   -- InactiveUsers-Step55

				SET @Result = 1;
			END
		END

		IF (@Code = 'Update')
		BEGIN
			SELECT @Found = 1, @OldMeetingDate = MeetingDate, @OldCommitteeId = CommitteeId, @OldSubmissionDate = AgendaSubmissionDate
			FROM Meeting WITH (UPDLOCK, HOLDLOCK)
			WHERE MeetingId = @MeetingId;

			-- Dates compared as dates: the page sends the date only
			SET @DateChanged = CASE WHEN @OldMeetingDate IS NULL AND @MeetingDate IS NULL THEN 0
			                        WHEN @OldMeetingDate IS NULL OR @MeetingDate IS NULL THEN 1
			                        WHEN CAST(@OldMeetingDate AS date) <> CAST(@MeetingDate AS date) THEN 1
			                        ELSE 0 END;
			SET @SubmissionChanged = CASE WHEN @OldSubmissionDate IS NULL AND @AgendaSubmissionDate IS NULL THEN 0
			                             WHEN @OldSubmissionDate IS NULL OR @AgendaSubmissionDate IS NULL THEN 1
			                             WHEN CAST(@OldSubmissionDate AS date) <> CAST(@AgendaSubmissionDate AS date) THEN 1
			                             ELSE 0 END;
			SET @CommitteeChanged = CASE WHEN ISNULL(@OldCommitteeId, -1) <> ISNULL(@CommitteeId, -1) THEN 1 ELSE 0 END;

			IF (@Found IS NULL)
				SET @Reason = 4;
			ELSE IF ((@DateChanged = 1 OR @CommitteeChanged = 1)
			         AND EXISTS (SELECT 1 FROM Attendance WHERE MeetingId = @MeetingId))
			BEGIN
				SET @Reason = 6;
				SET @Detail = CASE WHEN @DateChanged = 1 AND @CommitteeChanged = 1 THEN 'MeetingDate,CommitteeId'
				                   WHEN @DateChanged = 1 THEN 'MeetingDate'
				                   ELSE 'CommitteeId' END;
			END
			ELSE IF (@CommitteeChanged = 1 AND EXISTS (SELECT 1 FROM Agenda WHERE MeetingId = @MeetingId))
			BEGIN
				SET @Reason = 10;
				SET @Detail = 'CommitteeId';
			END
			-- MeetingDates-Step24: after the locks; "not before today" only for a date that changes
			ELSE IF (@MeetingDate IS NULL OR @AgendaSubmissionDate IS NULL)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'Missing';
			END
			ELSE IF (@DateChanged = 1 AND CAST(@MeetingDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'MeetingBeforeToday';
			END
			ELSE IF (@SubmissionChanged = 1 AND CAST(@AgendaSubmissionDate AS date) < @Today)
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionBeforeToday';
			END
			ELSE IF (CAST(@AgendaSubmissionDate AS date) > CAST(@MeetingDate AS date))
			BEGIN
				SET @Reason = 16;
				SET @Detail = 'SubmissionAfterMeeting';
			END
			ELSE
			BEGIN
				UPDATE Meeting SET
				CommitteeId = @CommitteeId,
				Place = @Place,
				Venue = @Venue,
				MeetingDate = @MeetingDate,
				MeetingTime = @MeetingTime,
				AgendaSubmissionDate = @AgendaSubmissionDate,
				MeetingColorCode = @MeetingColorCode,
				UpdatedOn = @UpdatedOn,
				UpdatedBy = @UpdatedBy
				WHERE
				MeetingId = @MeetingId;

				SET @SourceType = 'Meeting'
				SET @DisplayText = 'Meeting (' + (SELECT CommitteeCode FROM Committee WHERE
					 CommitteeId = @CommitteeId) + '-' + @MeetingNo + ')';

				INSERT INTO Alert_Master
				(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
				VALUES
				(@SourceType, 0, @MeetingId, @DisplayText, 'MU', 3, @CommitteeId, @CreatedOn, @CreatedBy);

				SET @alert_id = @@identity;

				INSERT INTO Alert_User_Map
				(AlertId, [UserId], ReadStatus, StatusId)
				(SELECT @alert_id, fu.[UserId],0,1 FROM dbo.fn_FunctionalUsers() fu WHERE fu.UserId <> @CreatedBy);   -- InactiveUsers-Step55

				SET @Result = 1;
			END
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
			ROLLBACK TRANSACTION MeetingSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO
-------------------------------------------------------------------------------
-- spr_AddEditCommittee (replaced; the step 53 text with the CC / CU rows from fn_FunctionalUsers)
-------------------------------------------------------------------------------
GO

-- Committee - add / edit; the alert goes to active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- DepartmentApprovers-Step53 (step UD1b): the CC and CU alerts no longer go to the Admin role.
-- InactiveUsers-Step55 (step IU1): the CC and CU alert rows are written for fn_FunctionalUsers (active, not the
-- system account, not the Admin role) other than the creator, the rule the Committee mail reads too
-- (spr_GetMeetingCommitteeMailId). The same users as the step 53 filter.
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditCommittee]
@Code VARCHAR(50),
@CommitteeId INT,
@CommitteeCode VARCHAR(10),
@CommitteeName VARCHAR(50), 
@Board INT,
@IncorporationDate DATETIME,
@MeetingStartNo INT,
@CommitteeColorCode VARCHAR(50), 
@CessationDate VARCHAR(50), 
@StatusId INT,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT
AS
	DECLARE @alert_id INT 
	DECLARE @alert_type_id INT
	DECLARE @committee_id INT
	DECLARE @DepartmentId INT 
	DECLARE @SourceType VARCHAR(150)	
	DECLARE @DisplayText VARCHAR(150)	
BEGIN

SET @DepartmentId = (SELECT DepartmentId FROM Users WHERE UserId = @CreatedBy);

	IF (@Code = 'Save') 
	BEGIN
		INSERT INTO Committee
		(CommitteeCode, CommitteeName, Board, IncorporationDate, MeetingStartNo, CommitteeColorCode, 
			CessationDate, StatusId, CreatedOn, CreatedBy)
		VALUES
		(@CommitteeCode, @CommitteeName, @Board, @IncorporationDate, @MeetingStartNo, @CommitteeColorCode, 
			@CessationDate, @StatusId, @CreatedOn, @CreatedBy);

		SET @committee_id = @@identity

		SET @SourceType = 'Committee'
		SET @DisplayText = 'Committee (' + @CommitteeCode + ')'		

		INSERT INTO Alert_Master
		(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
		VALUES
		(@SourceType, 0, @committee_id, @DisplayText, 'CC', 3, @committee_id, @CreatedOn, @CreatedBy)
		
		SET @alert_id = @@identity

		INSERT INTO Alert_User_Map
		(AlertId, [UserId], ReadStatus, StatusId)
		(SELECT @alert_id, fu.[UserId],0,1 FROM dbo.fn_FunctionalUsers() fu WHERE fu.UserId <> @CreatedBy)   -- InactiveUsers-Step55

	END
	IF (@Code = 'Update') 
	BEGIN
		UPDATE Committee SET
		CommitteeCode = @CommitteeCode,
		CommitteeName = @CommitteeName, 
		Board = @Board,
		IncorporationDate = @IncorporationDate,
		MeetingStartNo = @MeetingStartNo,
		CommitteeColorCode = @CommitteeColorCode, 
		CessationDate = @CessationDate,
		StatusId = @StatusId,
		UpdatedOn = @UpdatedOn, 
		UpdatedBy = @UpdatedBy
		WHERE
		CommitteeId = @CommitteeId;

		SET @SourceType = 'Committee'
		SET @DisplayText = 'Committee (' + @CommitteeCode + ')'		

		INSERT INTO Alert_Master
		(SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
		VALUES
		(@SourceType, 0, @CommitteeId, @DisplayText, 'CU', 3, @CommitteeId, @CreatedOn, @CreatedBy)
		
		SET @alert_id = @@identity

		INSERT INTO Alert_User_Map
		(AlertId, [UserId], ReadStatus, StatusId)
		(SELECT @alert_id, fu.[UserId],0,1 FROM dbo.fn_FunctionalUsers() fu WHERE fu.UserId <> @CreatedBy)   -- InactiveUsers-Step55
	END

END
GO
-------------------------------------------------------------------------------
-- spr_MinutesFinalizeByMeetingId (replaced; the step 23 text with the rows from fn_FunctionalUsers)
-------------------------------------------------------------------------------
GO

-- Minutes finalize - only from MinutesStatus 'Open' (MeetingLocks-Step15). Action items are
-- not duplicated and users are mapped only to this meeting's items (MinutesFinalize fix, step 8).
-- Only active users are mapped; rows already saved are kept (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
-- WorkflowOrder-Step23: a meeting created after step 23 needs the agenda finalized (17), attendance entered (18)
-- and every minute updated (19, ReasonDetail 'not updated/total'; '0/0' when it has no minutes).
-- InactiveUsers-Step55 (step IU1): the action item rows of a finalisation go to fn_FunctionalUsers only (active, not
-- the system account, not the Admin role). Rows already saved are kept; a user made active later gets no row.
CREATE OR ALTER PROCEDURE [dbo].[spr_MinutesFinalizeByMeetingId]
@MeetingId INT,
@UserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @MinutesStatus VARCHAR(50);
DECLARE @WfNew INT;
DECLARE @WfAgenda INT;
DECLARE @WfAttendance INT;
DECLARE @WfTotal INT;
DECLARE @WfUpdated INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION MinutesFinalize;

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @MeetingId;

		-- Workflow order (WorkflowOrder-Step23): the meeting's state; the order applies only to a meeting
		-- created after step 23 was installed (fn_WorkflowState.IsNew)
		SELECT @WfNew = IsNew, @WfAgenda = AgendaFinalized, @WfAttendance = AttendanceRecorded,
		       @WfTotal = MinutesTotal, @WfUpdated = MinutesUpdated
		FROM dbo.fn_WorkflowState(@MeetingId);

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus <> 'Open')
		BEGIN
			SET @Reason = 3;
			SET @Detail = @MinutesStatus;
		END
		-- WorkflowOrder-Step23
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAgenda, 0) = 0)
			SET @Reason = 17;
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND ISNULL(@WfAttendance, 0) = 0)
			SET @Reason = 18;
		ELSE IF (ISNULL(@WfNew, 0) = 1 AND (ISNULL(@WfTotal, 0) = 0 OR ISNULL(@WfUpdated, 0) < ISNULL(@WfTotal, 0)))
		BEGIN
			SET @Reason = 19;
			SET @Detail = CAST(ISNULL(@WfTotal, 0) - ISNULL(@WfUpdated, 0) AS VARCHAR(12)) + '/' + CAST(ISNULL(@WfTotal, 0) AS VARCHAR(12));
		END
		ELSE
		BEGIN
			UPDATE Meeting SET
			MinutesStatus = 'F',
			UpdatedOn = GETDATE(),
			UpdatedBy = @UserId
			WHERE MeetingId = @MeetingId;

			INSERT INTO Action_Item
				([MinutesId], Directions, ActionText, ActionStatus, UpdatedOn, UpdatedBy)
				(SELECT m.[MinutesId], ' ', ' ', 'Pending', GETDATE(), @UserId
					FROM Minutes m WHERE
						m.AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId) AND
						m.DecisionTypeId = 1 AND
						NOT EXISTS (SELECT 1 FROM Action_Item x WHERE x.MinutesId = m.MinutesId))

			INSERT INTO ActionItem_User_Map
				(ActionItemId, [UserId], ReadStatus, StatusId)
				(SELECT b.ActionItemId, a.UserId,0,1 FROM dbo.fn_FunctionalUsers() a, Action_Item b   -- InactiveUsers-Step55
					WHERE
						b.MinutesId IN (SELECT MinutesId FROM Minutes WHERE
							AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId)) AND
						NOT EXISTS (SELECT 1 FROM ActionItem_User_Map x
							WHERE x.ActionItemId = b.ActionItemId AND x.UserId = a.UserId))

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
			ROLLBACK TRANSACTION MinutesFinalize;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- Result
-------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM (VALUES ('fn_FunctionalUsers'), ('spr_GetMeetingCommitteeMailId'), ('spr_GetResetPasswordMail'),
                                 ('spr_AddEditMeeting'), ('spr_AddEditCommittee'), ('spr_MinutesFinalizeByMeetingId')) o(Name)
           WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') NOT LIKE '%InactiveUsers-Step55%')
    RAISERROR('Step 55 is NOT completely installed: an object is missing. Tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 55 installed: 6 objects carry InactiveUsers-Step55.';
GO

SET NOEXEC OFF;
GO
