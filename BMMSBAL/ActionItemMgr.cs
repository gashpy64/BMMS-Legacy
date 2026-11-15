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
        // Step UN6d (step 46): the Submit of the Followup page, every row in one call. Rows: the action item id and
        // the tick (true = Confirmed) of each row of the page. The list is written with XmlWriter, so nothing of it
        // is ever read as markup. See ActionItemDB.
        public static int SaveFollowupConfirmed(int ActingUserId, IList<KeyValuePair<int, bool>> Rows, out int Saved)
        {
            StringBuilder sb = new StringBuilder();
            XmlWriterSettings settings = new XmlWriterSettings();
            settings.OmitXmlDeclaration = true;
            using (XmlWriter w = XmlWriter.Create(sb, settings))
            {
                w.WriteStartElement("items");
                if (Rows != null)
                {
                    foreach (KeyValuePair<int, bool> row in Rows)
                    {
                        w.WriteStartElement("i");
                        w.WriteAttributeString("id", row.Key.ToString(CultureInfo.InvariantCulture));
                        w.WriteAttributeString("c", row.Value ? "1" : "0");
                        w.WriteEndElement();
                    }
                }
                w.WriteEndElement();
            }

            return ActionItemDB.SaveFollowupConfirmed(ActingUserId, sb.ToString(), out Saved);
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
