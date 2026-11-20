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

        #region GetFollowupByDepartmentReport
        // Step FU2b (step 49): Followup by Department, the Controller only; see ActionItemDB. The subject range is two
        // whole numbers or none (null).
        public static DataTable GetFollowupByDepartmentReport(int ActingUserId, int CommitteeId, int MeetingNoFrom, int MeetingNoTo,
            int DepartmentId, int? SubjectNoFrom, int? SubjectNoTo, out int Reason)
        {
            return ActionItemDB.GetFollowupByDepartmentReport(ActingUserId, CommitteeId, MeetingNoFrom, MeetingNoTo, DepartmentId,
                SubjectNoFrom, SubjectNoTo, out Reason);
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
            if (IsBlankReopenReason(text) || text.Length > ReopenReasonMaxLength)
                return 4;

            return ActionItemDB.ReopenFollowup(ActingUserId, ActionItemId, text);
        }

        // Step FU2b (step 49, owner decision RA-3): the one list of characters that make a reopen reason blank, the
        // same as in spr_ReopenFollowup (BMMS-Fix-FollowupReports-Step49.sql): U+0009 to U+000D, U+0020, U+0085,
        // U+00A0, U+1680, U+2000 to U+200B, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF. A build check compares the
        // two lists.
        public static readonly char[] ReopenBlankCharacters =
        {
            (char)0x0009, (char)0x000A, (char)0x000B, (char)0x000C, (char)0x000D, (char)0x0020, (char)0x0085, (char)0x00A0, (char)0x1680,
            (char)0x2000, (char)0x2001, (char)0x2002, (char)0x2003, (char)0x2004, (char)0x2005, (char)0x2006, (char)0x2007, (char)0x2008,
            (char)0x2009, (char)0x200A, (char)0x200B, (char)0x2028, (char)0x2029, (char)0x202F, (char)0x205F, (char)0x3000, (char)0xFEFF
        };

        // A reason is blank when nothing is left after the characters of the list are taken out (null and "" too)
        public static bool IsBlankReopenReason(string Reason)
        {
            if (string.IsNullOrEmpty(Reason))
                return true;
            foreach (char c in Reason)
            {
                if (Array.IndexOf(ReopenBlankCharacters, c) < 0)
                    return false;
            }
            return true;
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
