using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using System.Globalization;
using System.Xml;
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

        // Step UN6c2b (step 45): with the Committee and Department filters of the Dashboard; see ActionItemDB
        public static DataTable GetDashboardActionItems(int ActingUserId, int CommitteeId, int DepartmentId, out int Reason)
        {
            return ActionItemDB.GetDashboardActionItems(ActingUserId, CommitteeId, DepartmentId, out Reason);
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

        #region SaveFollowupActionText
        // Step UN6d (step 46): see ActionItemDB. The rich text is cleaned before it is stored, as before (step A1a).
        public static int SaveFollowupActionText(int ActingUserId, int ActionItemId, string ActionText)
        {
            return ActionItemDB.SaveFollowupActionText(ActingUserId, ActionItemId, HtmlCleaner.Clean(ActionText));
        }
        #endregion

        #region SaveFollowupConfirmed
        // Step FU1 (step 47): the Submit of the Followup page in one call. ActionItemIds: only the rows the Controller
        // changed from Pending to Confirmed. The list is written with XmlWriter, so nothing of it is ever read as
        // markup. See ActionItemDB.
        public static int SaveFollowupConfirmed(int ActingUserId, IList<int> ActionItemIds, out int Saved, out int Skipped)
        {
            StringBuilder sb = new StringBuilder();
            XmlWriterSettings settings = new XmlWriterSettings();
            settings.OmitXmlDeclaration = true;
            using (XmlWriter w = XmlWriter.Create(sb, settings))
            {
                w.WriteStartElement("items");
                if (ActionItemIds != null)
                {
                    foreach (int id in ActionItemIds)
                    {
                        w.WriteStartElement("i");
                        w.WriteAttributeString("id", id.ToString(CultureInfo.InvariantCulture));
                        w.WriteEndElement();
                    }
                }
                w.WriteEndElement();
            }

            return ActionItemDB.SaveFollowupConfirmed(ActingUserId, sb.ToString(), out Saved, out Skipped);
        }
        #endregion

        #region ReopenFollowup
        // Step FU1 (step 47): see ActionItemDB. The reason is trimmed; a blank reason or one longer than
        // ReopenReasonMaxLength is never sent (Reason 4, nothing saved), so the parameter type never cuts a text.
        public const int ReopenReasonMaxLength = ActionItemDB.ReopenReasonMaxLength;

        public static int ReopenFollowup(int ActingUserId, int ActionItemId, string ReopenReason)
        {
            string text = (ReopenReason ?? string.Empty).Trim();
            if (text.Length == 0 || text.Length > ReopenReasonMaxLength)
                return 4;

            return ActionItemDB.ReopenFollowup(ActingUserId, ActionItemId, text);
        }
        #endregion

        #region GetFollowupList
        // Step FU1 (step 47): the Followup page's list with the latest status row of each item; see ActionItemDB
        public static DataTable GetFollowupList(int ActingUserId, int CommitteeId, int MeetingNoSearch, int MeetingId, int FromMeetingId,
            int ToMeetingId, int DepartmentId, int ConfirmStatus, out int Reason)
        {
            return ActionItemDB.GetFollowupList(ActingUserId, CommitteeId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                DepartmentId, ConfirmStatus, out Reason);
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
