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

        #region GetDashboardActionItems
        // Step UN6c1 (step 43): see ActionItemDB
        public static DataTable GetDashboardActionItems(int ActingUserId, out int Reason)
        {
            return ActionItemDB.GetDashboardActionItems(ActingUserId, out Reason);
        }
        #endregion

        #region OpenDashboardActionItem
        // Step UN6c1 (step 43): see ActionItemDB
        public static DataTable OpenDashboardActionItem(int ActingUserId, int ActionItemId, out int Reason)
        {
            return ActionItemDB.OpenDashboardActionItem(ActingUserId, ActionItemId, out Reason);
        }
        #endregion

        #region SaveDashboardActionText
        // Step UN6c1 (step 43): see ActionItemDB
        public static int SaveDashboardActionText(int ActingUserId, int ActionItemId, string ActionText)
        {
            return ActionItemDB.SaveDashboardActionText(ActingUserId, ActionItemId, ActionText);
        }
        #endregion

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
            // Rich text cleaned before it is stored (step A1a)
            ActionItemDB.UpdateActionItem(Code, ActionItemId, HtmlCleaner.Clean(ActualResolution), HtmlCleaner.Clean(ActionText), IsComplied, IsConfirmed);
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
