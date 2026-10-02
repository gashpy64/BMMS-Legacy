using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region ActionItemBAL
    public class ActionItemBAL
    {
        #region Properties

        #endregion
    }
    #endregion

    #region ActionItemBALList
    public class ActionItemBALList : List<ActionItemBAL>
    {
        #region public ActionItemBALList()
        public ActionItemBALList()
        {

        }
        #endregion
    }
    #endregion

    #region ActionItemMgr
    public class ActionItemMgr
    {

        #region GetActionItemByUserId
        public static DataTable GetActionItemByUserId(int UserId)
        {
            return ActionItemDB.GetActionItemByUserId(UserId);
        }
        #endregion

        #region GetActionItemByMeetingId
        public static DataTable GetActionItemByMeetingId(int MeetingId, int IsConfirmed)
        {
            return ActionItemDB.GetActionItemByMeetingId(MeetingId, IsConfirmed);
        }
        #endregion

        #region GetActionItemByMeetingIdDeptId
        public static DataTable GetActionItemByMeetingIdDeptId(int CommitteeId, int MeetingNoFrom, int MeetingNoTo, int DepartmentId)
        {
            return ActionItemDB.GetActionItemByMeetingIdDeptId(CommitteeId, MeetingNoFrom, MeetingNoTo, DepartmentId);
        }
        #endregion

        #region GetActionItemByActionItemIdUserId
        public static DataTable GetActionItemByActionItemIdUserId(int ActionItemId, int UserId)
        {
            return ActionItemDB.GetActionItemByActionItemIdUserId(ActionItemId, UserId);
        }
        #endregion

        #region GetActionItemByActionItemId
        public static DataTable GetActionItemByActionItemId(int ActionItemId)
        {
            return ActionItemDB.GetActionItemByActionItemId(ActionItemId);
        }
        #endregion

        #region UpdateActionItem
        public static void UpdateActionItem(string Code, int ActionItemId, string ActualResolution, string ActionText, int IsComplied, int IsConfirmed)
        {
            ActionItemDB.UpdateActionItem(Code, ActionItemId, ActualResolution, ActionText, IsComplied, IsConfirmed);
        }
        #endregion

        #region UpdateActionItemByUserId
        public static void UpdateActionItemByUserId(int UserId, int ActionItemId)
        {
            ActionItemDB.UpdateActionItemByUserId(UserId, ActionItemId);
        }
        #endregion

    }
    #endregion

}
