/* ============================================================================
   BMMS - Fix: Minutes finalization created duplicate action items and mapped
   every user to every action item in the database
   ----------------------------------------------------------------------------
   spr_MinutesFinalizeByMeetingId used to:
     * insert an Action_Item for every follow-up minute of the meeting, even
       when spr_UpdateMinutes had already created one. Two action items for one
       minute later make spr_UpdateMinutes fail ("Subquery returned more than
       1 value").
     * insert ActionItem_User_Map rows for ALL users x ALL action items of ALL
       meetings, so every finalization added a second copy of the rows of every
       earlier meeting, marked unread and active again.

   This version is IDENTICAL to the original except that:
     * an action item is only created for a follow-up minute that has none
     * users are only mapped to the action items of THIS meeting, and only
       where that user / action item row does not exist yet

   What stays the same: after finalization every user is mapped to every
   action item of the finalized meeting.

   This script only replaces the procedure. It changes no data.
   Safe to re-run: it uses CREATE OR ALTER.

   To see whether an existing database already holds duplicates from the old
   procedure (both queries return no rows when it is clean):
     SELECT MinutesId, COUNT(*) AS ActionItems FROM Action_Item
     GROUP BY MinutesId HAVING COUNT(*) > 1;
     SELECT ActionItemId, UserId, COUNT(*) AS MapRows FROM ActionItem_User_Map
     GROUP BY ActionItemId, UserId HAVING COUNT(*) > 1;
   ============================================================================ */

USE [BMMS];
GO

CREATE OR ALTER PROCEDURE [dbo].[spr_MinutesFinalizeByMeetingId]
@MeetingId INT,
@UserId INT
AS
DECLARE @actionItem_id INT
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
		(SELECT b.ActionItemId, a.UserId,0,1 FROM Users a, Action_Item b
			WHERE b.MinutesId IN (SELECT MinutesId FROM Minutes WHERE
					AgendaId IN (SELECT AgendaId FROM Agenda WHERE MeetingId = @MeetingId)) AND
				NOT EXISTS (SELECT 1 FROM ActionItem_User_Map x
					WHERE x.ActionItemId = b.ActionItemId AND x.UserId = a.UserId))

END
GO
