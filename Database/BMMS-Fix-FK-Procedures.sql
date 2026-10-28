/* ============================================================================
   BMMS - Critical fix #5, step 3: procedure changes needed BEFORE the last
   four foreign keys can be added
   ----------------------------------------------------------------------------
   Keys this prepares for (added by a separate script, not by this one):
     Action_Item.MinutesId       -> Minutes.MinutesId
     ActionItem_User_Map.UserId  -> Users.UserId
     Meeting.ChairmanNameId      -> Member.MemberId
     Member.State_Id             -> State_Master.State_Id

   Seven procedures are replaced. Each is IDENTICAL to the version currently
   in the database except for the lines marked "FK #5":

     1. spr_AddEditMember              no state selected (0 or blank) is stored
                                       as NULL instead of 0
     2. spr_UpdateMeetingChairman      only sets a chairman that exists in Member
     3. spr_DeleteMemberByMemberId     refuses (Result = 0) while the member is
                                       the chairman of a meeting
     4. spr_UpdateMinutes              maps the new action item to the agenda
                                       creator only if that user still exists
     5. spr_AgendaFinalizeByMeetingId  removes the action items of the minutes
                                       it deletes and re-creates
     6. spr_DeleteAgendaByAgendaId     removes the action items of the minutes
                                       it deletes
     7. spr_DeleteUserByUserId         removes the user's ActionItem_User_Map
                                       rows when the delete is allowed, in one
                                       transaction with the user delete

   Notes:
     * This script only replaces procedures. It changes no data and adds no
       constraint. It is safe to run before the keys exist.
     * Deleting an Action_Item also removes its ActionItem_User_Map rows through
       the existing key FK_ActionItem_User_Map_Action_Item (ON DELETE CASCADE).
     * After change 1, Member.State_Id can be NULL. BMMSDAL/MemberDB.cs must
       read a NULL state as 0 before a member without a state is edited.
     * Safe to re-run: each uses CREATE OR ALTER.
   ============================================================================ */

USE [BMMS];
GO

-- 1. Member - State_Id: "- Select -" (0) or blank is stored as NULL
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditMember]
@Code VARCHAR(50),
@MemberId INT,
@MemberCode VARCHAR(10),
@MemberName VARCHAR(50),
@SexId INT,
@DesignationId INT,
@DOB VARCHAR(50),
@Address1 VARCHAR(150),
@Address2 VARCHAR(150),
@Address3 VARCHAR(150),
@CityName VARCHAR(150),
@State_Id VARCHAR(50),
@PinCode VARCHAR(50),
@DOJ VARCHAR(50),
@EmailId VARCHAR(50),
@DinNo VARCHAR(50),
@PhotoPath VARCHAR(50),
@ResumePath VARCHAR(50),
@RelievingDate VARCHAR(50),
@StatusId INT,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT
AS
BEGIN
	-- FK #5: no state selected
	IF (LTRIM(RTRIM(ISNULL(@State_Id, ''))) IN ('', '0'))
	BEGIN
		SET @State_Id = NULL;
	END

	IF (@Code = 'Save')
	BEGIN
		INSERT INTO Member
		(MemberCode, MemberName, SexId, DesignationId,
			DOB, Address1, Address2, Address3, CityName, State_Id, PinCode,
			DOJ, EmailId, DinNo, PhotoPath, ResumePath, RelievingDate,
			StatusId, CreatedOn, CreatedBy)
		VALUES
		(@MemberCode, @MemberName, @SexId, @DesignationId,
			@DOB, @Address1, @Address2, @Address3, @CityName, @State_Id, @PinCode,
			@DOJ, @EmailId, @DinNo, @PhotoPath, @ResumePath, @RelievingDate,
			@StatusId, @CreatedOn, @CreatedBy);

	END
	IF (@Code = 'Update')
	BEGIN
		UPDATE Member SET
		MemberCode = @MemberCode,
		MemberName = @MemberName,
		SexId = @SexId,
		DesignationId = @DesignationId,
		DOB = @DOB,
		Address1 = @Address1,
		Address2 = @Address2,
		Address3 = @Address3,
		CityName = @CityName,
		State_Id = @State_Id,
		PinCode = @PinCode,
		DOJ = @DOJ,
		EmailId = @EmailId,
		DinNo = @DinNo,
		PhotoPath = @PhotoPath,
		ResumePath = @ResumePath,
		RelievingDate = @RelievingDate,
		StatusId = @StatusId,
		UpdatedOn = @UpdatedOn,
		UpdatedBy = @UpdatedBy
		WHERE
		MemberId = @MemberId;

		IF (@RelievingDate != '')
		BEGIN
			UPDATE Committee_Member SET
			CessationDate = @RelievingDate
			WHERE MemberId = @MemberId
			AND CessationDate = '';
		END

	END

END
GO

-- 2. Meeting - ChairmanNameId: only a member that exists can be set
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateMeetingChairman]
(
@MeetingId INT,
@CommitteeId INT,
@ChairmanNameId INT
)
AS
BEGIN
		UPDATE Meeting SET
		ChairmanNameId = @ChairmanNameId
		WHERE
		MeetingId = @MeetingId AND
		CommitteeId = @CommitteeId AND
		-- FK #5
		EXISTS (SELECT 1 FROM Member WHERE MemberId = @ChairmanNameId);
END
GO

-- 3. Member - referenced by Committee_Member, Meeting_Member and
--    Meeting (as chairman)
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteMemberByMemberId]
@MemberId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN

	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Committee_Member WHERE MemberId = @MemberId);

	IF (@CountRec <= 0)
	BEGIN
		SET @CountRec = (SELECT COUNT(*) FROM Meeting_Member WHERE MemberId = @MemberId);

		IF (@CountRec <= 0)
		BEGIN
			-- FK #5
			SET @CountRec = (SELECT COUNT(*) FROM Meeting WHERE ChairmanNameId = @MemberId);

			IF (@CountRec <= 0)
			BEGIN
				SET @Result = 1;
			END
		END
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Member WHERE MemberId = @MemberId;
	END

	SELECT @Result AS Result;

END
GO

-- 4. Minutes update - the new action item is mapped to the agenda creator
--    only if that user still exists
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateMinutes]
@Code VARCHAR(50),
@MinutesId INT,
@DecisionTypeId INT,
@Directions TEXT,
@ActualResolution TEXT,
@ShortText TEXT,
@CreatedBy INT,
@UpdatedBy INT
AS
DECLARE @ActionItemId INT;
	DECLARE @CountActionItemId INT;
	DECLARE @AgendaId INT;
	DECLARE @UserId INT;
BEGIN
	IF (@Code = 'All')
	BEGIN

		UPDATE Minutes SET
		DecisionTypeId = @DecisionTypeId,
		StatusId = 1,
		UpdatedOn = GETDATE(),
		UpdatedBy = @UpdatedBy
		WHERE
		MinutesId = @MinutesId;

		SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);

		UPDATE Agenda SET ShortText = @ShortText WHERE AgendaId = @AgendaId;

		SET @Directions = (SELECT Directions FROM Minutes WHERE MinutesId = @MinutesId);

		IF (@DecisionTypeId != 1)
		BEGIN
			DELETE FROM Action_Item WHERE MinutesId = @MinutesId;
		END

		IF (@DecisionTypeId = 1)
		BEGIN
			SET @CountActionItemId = (SELECT COUNT(ActionItemId) FROM Action_Item WHERE MinutesId = @MinutesId);
			SET @ActionItemId = (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @MinutesId);

			IF (@CountActionItemId >= 1)
			BEGIN
				UPDATE [Action_Item] SET
				Directions = @Directions, UpdatedOn = GETDATE()
				WHERE ActionItemId = @ActionItemId;

				UPDATE ActionItem_User_Map SET
				ReadStatus = 1
				WHERE ActionItemId = @ActionItemId;

			END

			IF (@CountActionItemId <= 0)
			BEGIN
				INSERT INTO [Action_Item]
					([MinutesId],[Directions],[ActionText],[ActionStatus],[UpdatedOn],[UpdatedBy])
				VALUES
					(@MinutesId, @Directions, '','',GETDATE(),@UpdatedBy);

				SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);
				SET @UserId = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId);
				SET @ActionItemId = (SELECT ActionItemId FROM Action_Item WHERE MinutesId = @MinutesId);

				-- FK #5: was INSERT ... VALUES (@ActionItemId, @UserId, 0, 1)
				INSERT INTO ActionItem_User_Map
					(ActionItemId, UserId, ReadStatus, StatusId)
				SELECT @ActionItemId, UserId, 0, 1
				FROM Users
				WHERE UserId = @UserId;
			END

		END

	END
	IF (@Code = 'Directions')
	BEGIN
		UPDATE Minutes SET
		Directions = @Directions, StatusId = 1, UpdatedOn = GETDATE(), UpdatedBy = @UpdatedBy
		WHERE MinutesId = @MinutesId;

	END
	IF (@Code = 'ActualResolution')
	BEGIN

		SET @AgendaId = (SELECT AgendaId FROM View_Minute WHERE MinutesId = @MinutesId);

		UPDATE Minutes SET
		ActualResolution = @ActualResolution, StatusId = 1,	UpdatedOn = GETDATE(), 	UpdatedBy = @UpdatedBy
		WHERE MinutesId = @MinutesId;

		UPDATE Agenda SET ProposedResolution = @ActualResolution
		WHERE AgendaId = @AgendaId;

	END

END
GO

-- 5. Agenda finalize - the minutes of the meeting are deleted and re-created,
--    so their action items go first
CREATE OR ALTER PROCEDURE [dbo].[spr_AgendaFinalizeByMeetingId]
@MeetingId INT
AS
BEGIN

	-- FK #5
	DELETE FROM Action_Item WHERE
	MinutesId IN (SELECT MinutesId FROM Minutes WHERE
		AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId));

	DELETE FROM Minutes WHERE
	AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId);

	INSERT INTO Minutes
	(
	AgendaId, DecisionTypeId, Directions, ActualResolution,
	CreatedOn, CreatedBy, UpdatedOn, UpdatedBy
	)
	(
	SELECT
	AgendaId, 3, ' ', ProposedResolution,
	GETDATE(), 1, GETDATE(), 1
	FROM Agenda
	WHERE MeetingId = @MeetingId
	AND
	ControllerApprovedStatus = 'Approved'
	);

	UPDATE Meeting SET
	AgendaStatus = 'Close'
	WHERE MeetingId = @MeetingId;

END
GO

-- 6. Agenda delete - action items of the agenda's minutes go first
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteAgendaByAgendaId]
@AgendaId INT
AS
BEGIN

	DELETE FROM Alert_Master
		WHERE SourceType = 'Agenda'
		AND SourceTypeId = @AgendaId;

	-- FK #5
	DELETE FROM Action_Item WHERE
	MinutesId IN (SELECT MinutesId FROM Minutes WHERE AgendaId = @AgendaId);

	DELETE FROM Minutes WHERE AgendaId = @AgendaId;

	DELETE FROM Agenda WHERE AgendaId = @AgendaId;
END
GO

-- 7. Users - referenced by Agenda (as approver) and by other Users (as manager).
--    The user's ActionItem_User_Map rows are per-user read flags, so they are
--    removed with the user instead of blocking the delete. Both deletes run
--    in one transaction: with XACT_ABORT ON any error rolls back both and is
--    raised to the caller, so the map rows are never removed on their own.
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteUserByUserId]
@UserId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET XACT_ABORT ON;

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
		-- FK #5
		BEGIN TRANSACTION;

		DELETE FROM ActionItem_User_Map WHERE UserId = @UserId;

		DELETE FROM Users WHERE UserId = @UserId;

		COMMIT TRANSACTION;
	END

	SELECT @Result AS Result;
END
GO

/* ============================================================================
   Sanity check after running: all seven should be listed with today's date.
   ============================================================================ */
-- SELECT name, modify_date FROM sys.procedures
-- WHERE name IN ('spr_AddEditMember', 'spr_UpdateMeetingChairman', 'spr_DeleteMemberByMemberId',
--                'spr_UpdateMinutes', 'spr_AgendaFinalizeByMeetingId', 'spr_DeleteAgendaByAgendaId',
--                'spr_DeleteUserByUserId')
-- ORDER BY name;
