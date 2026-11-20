using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region ActionItemDAL
    public class ActionItemDAL
    {
        #region Properties

        #endregion
    }
    #endregion

    #region ActionItemDALList
    public class ActionItemDALList : List<ActionItemDAL>
    {
        #region ActionItemDALList
        public ActionItemDALList()
        {

        }
        #endregion
    }
    #endregion

    #region ActionItemDB
    public class ActionItemDB
    {

        #region GetFollowupReport
        // Step FU2b (BMMS-Fix-FollowupReports-Step49.sql): Followup and Followup Summary, the Controller and Management,
        // in place of the query built in ReportsMgr before (Controller) and spr_GetFollowupReportForManagement (step 41,
        // Management). The procedure reads the role from the acting user id: Reason 8 (missing, inactive or the system
        // account) or 4 (another role), then no rows; 0 when allowed. The View_Action_Item columns, MinutesStatus and
        // MinutesStatusMark (Management; NULL for the Controller) and the six status columns of the latest history row.
        public static DataTable GetFollowupReport(int ActingUserId, int CommitteeId, int MeetingNoSearch, int MeetingId, int FromMeetingId,
            int ToMeetingId, int DepartmentId, int ConfirmStatus, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[10];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[2] = new SqlParameter("@MeetingNoSearch", MeetingNoSearch);
            parameter[3] = new SqlParameter("@MeetingId", MeetingId);
            parameter[4] = new SqlParameter("@FromMeetingId", FromMeetingId);
            parameter[5] = new SqlParameter("@ToMeetingId", ToMeetingId);
            parameter[6] = new SqlParameter("@DepartmentId", DepartmentId);
            parameter[7] = new SqlParameter("@ConfirmStatus", ConfirmStatus);
            parameter[8] = result;
            parameter[9] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_GetFollowupReport", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            return dt;
        }
        #endregion

        #region GetFollowupByDepartmentReport
        // Step FU2b (BMMS-Fix-FollowupReports-Step49.sql): Followup by Department, the Controller only, in place of
        // spr_GetActionItemByMeetingIdDeptId and the page's filters: the committee, the meeting numbers, the department
        // (-1: every department) and the subject range (whole numbers; null: no range), with the six status columns.
        // Reason 8 (missing, inactive or the system account) or 4 (every role but the Controller), then no rows.
        public static DataTable GetFollowupByDepartmentReport(int ActingUserId, int CommitteeId, int MeetingNoFrom, int MeetingNoTo,
            int DepartmentId, int? SubjectNoFrom, int? SubjectNoTo, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;
            SqlParameter subjectFrom = new SqlParameter("@SubjectNoFrom", SqlDbType.Int);
            subjectFrom.Value = SubjectNoFrom.HasValue ? (object)SubjectNoFrom.Value : DBNull.Value;
            SqlParameter subjectTo = new SqlParameter("@SubjectNoTo", SqlDbType.Int);
            subjectTo.Value = SubjectNoTo.HasValue ? (object)SubjectNoTo.Value : DBNull.Value;

            SqlParameter[] parameter = new SqlParameter[9];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[2] = new SqlParameter("@MeetingNoFrom", MeetingNoFrom);
            parameter[3] = new SqlParameter("@MeetingNoTo", MeetingNoTo);
            parameter[4] = new SqlParameter("@DepartmentId", DepartmentId);
            parameter[5] = subjectFrom;
            parameter[6] = subjectTo;
            parameter[7] = result;
            parameter[8] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_GetFollowupByDepartmentReport", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            return dt;
        }
        #endregion

        #region GetDashboardActionItems
        // Step UN6c1 (BMMS-Fix-DashboardAlerts-Step43.sql): the Dashboard's Action Items card. The procedure reads the
        // role from the acting user id: a Controller and Management get every item that is not confirmed, a Manager
        // and a User those of their departments with finalised or confirmed minutes; each row with the person's own
        // read state and IsOverdue (due date before the database server's date, not complied, not confirmed).
        // Reason 0 when allowed; 8 (user missing or inactive) or 4 (a role without the card: MD Secretariat, Admin),
        // and then no rows.
        public static DataTable GetDashboardActionItems(int ActingUserId, out int Reason)
        {
            return GetDashboardActionItems(ActingUserId, 0, 0, out Reason);
        }

        // Step UN6c2b (BMMS-Fix-DashboardSummary-Step45.sql): the filters at the top of the Dashboard. CommitteeId 0 =
        // every committee, otherwise an active committee; DepartmentId 0 = no department filter, otherwise one of a
        // Manager's or a User's own departments. The procedure checks both against the acting user (Reason 4 when
        // not allowed, and then no rows).
        public static DataTable GetDashboardActionItems(int ActingUserId, int CommitteeId, int DepartmentId, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[5];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = result;
            parameter[2] = reason;
            parameter[3] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[4] = new SqlParameter("@DepartmentId", DepartmentId);

            DataTable dt = CommonDB.GetDataTable("spr_GetDashboardActionItems", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            return dt;
        }
        #endregion

        #region OpenDashboardActionItem
        // Step UN6c1 (step 43): opening an item of the card. Only an item the acting user sees in the card; the
        // procedure marks the person's own read row (and creates it when missing) and returns the item's row.
        // Reason 0 when allowed; 8, or 4 (outside the person's scope, confirmed, unknown, or a role without the
        // card), and then no row and nothing written.
        public static DataTable OpenDashboardActionItem(int ActingUserId, int ActionItemId, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[4];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@ActionItemId", ActionItemId);
            parameter[2] = result;
            parameter[3] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_OpenDashboardActionItem", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            return dt;
        }
        #endregion

        #region SaveDashboardActionText
        // Step UN6c1 (step 43): the Submit of the Dashboard's Action Item Details panel. The procedure saves the
        // action text only for a Controller, a Manager or a User and only for an item in the acting user's scope.
        // Returns 0 when saved; 8, or 4 (Management, MD Secretariat, Admin, or an item outside the scope), and then
        // nothing was saved.
        public static int SaveDashboardActionText(int ActingUserId, int ActionItemId, string ActionText)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter text = new SqlParameter("@ActionText", SqlDbType.NVarChar, -1);
            text.Value = (object)ActionText ?? DBNull.Value;

            SqlParameter[] parameter = new SqlParameter[5];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@ActionItemId", ActionItemId);
            parameter[2] = text;
            parameter[3] = result;
            parameter[4] = reason;

            CommonDB.ExecuteProcedure("spr_SaveDashboardActionText", parameter);
            return MinutesDB.RefusalReason(result, reason);
        }
        #endregion

        #region GetActionItemByUserId
        public static DataTable GetActionItemByUserId(int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@UserId", UserId);

            return CommonDB.GetDataTable("spr_GetActionItemByUserId", parameter); ;
        }
        #endregion

        #region GetActionItemByMeetingId
        public static DataTable GetActionItemByMeetingId(int MeetingId, int IsConfirmed)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@IsConfirmed", IsConfirmed);

            return CommonDB.GetDataTable("spr_GetActionItemByMeetingId", parameter); ;
        }
        #endregion

        #region GetActionItemByActionItemIdUserId
        public static DataTable GetActionItemByActionItemIdUserId(int ActionItemId, int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@ActionItemId", ActionItemId);
            parameter[1] = new SqlParameter("@UserId", UserId);

            return CommonDB.GetDataTable("spr_GetActionItemByActionItemIdUserId", parameter); ;
        }
        #endregion

        #region GetActionItemByActionItemId
        public static DataTable GetActionItemByActionItemId(int ActionItemId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@ActionItemId", ActionItemId);

            return CommonDB.GetDataTable("spr_GetActionItemByActionItemId", parameter); ;
        }
        #endregion

        #region SaveFollowupActionText
        // Step UN6d (BMMS-Fix-FollowupSave-Step46.sql): the Save of the Followup page's Action Text panel. The procedure
        // decides from the acting user id (the role read from the database): only an active Controller. It writes
        // Action_Item.ActionText only, as spr_UpdateActionItem did for the code 'ActionText'. Returns 0 when saved;
        // 12 (the system account), 8 (user missing or inactive) or 4 (another role, or an item that does not exist),
        // and then nothing was saved. Step FU1 (step 47): 26 when the item is confirmed (a confirmed followup is final).
        public static int SaveFollowupActionText(int ActingUserId, int ActionItemId, string ActionText)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter text = new SqlParameter("@ActionText", SqlDbType.NVarChar, -1);
            text.Value = (object)ActionText ?? DBNull.Value;

            SqlParameter[] parameter = new SqlParameter[5];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@ActionItemId", ActionItemId);
            parameter[2] = text;
            parameter[3] = result;
            parameter[4] = reason;

            CommonDB.ExecuteProcedure("spr_SaveFollowupActionText", parameter);
            return MinutesDB.RefusalReason(result, reason);
        }
        #endregion

        #region SaveFollowupConfirmed
        // Step FU1 (step 47): the Submit of the Followup page, in ONE call and one transaction: all rows are written or
        // none. Items: <items><i id=".."/>...</items> (built by ActionItemMgr), only the rows the Controller changed from
        // Pending to Confirmed. The procedure writes the rows still not confirmed (IsConfirmed 1, IsComplied 0, the
        // item's mapping rows StatusId 0, one Confirm history row each) and skips a row already confirmed. Returns 0
        // when saved (Saved = rows confirmed now, Skipped = rows already confirmed); 12, 8 or 4 (another role, an item
        // that does not exist, a list that is not allowed), and then nothing was saved.
        public static int SaveFollowupConfirmed(int ActingUserId, string Items, out int Saved, out int Skipped)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;
            SqlParameter saved = new SqlParameter("@Saved", SqlDbType.Int);
            saved.Direction = ParameterDirection.Output;
            SqlParameter skipped = new SqlParameter("@Skipped", SqlDbType.Int);
            skipped.Direction = ParameterDirection.Output;

            SqlParameter items = new SqlParameter("@Items", SqlDbType.Xml);
            items.Value = (object)Items ?? DBNull.Value;

            SqlParameter[] parameter = new SqlParameter[6];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = items;
            parameter[2] = result;
            parameter[3] = reason;
            parameter[4] = saved;
            parameter[5] = skipped;

            CommonDB.ExecuteProcedure("spr_SaveFollowupConfirmed", parameter);
            Saved = saved.Value == null || saved.Value == DBNull.Value ? 0 : Convert.ToInt32(saved.Value);
            Skipped = skipped.Value == null || skipped.Value == DBNull.Value ? 0 : Convert.ToInt32(skipped.Value);
            return MinutesDB.RefusalReason(result, reason);
        }
        #endregion

        #region ReopenFollowup
        // Step FU1 (step 47): the Save of the Reopen panel, one item at once (never part of Submit). The procedure
        // decides from the acting user id: only an active Controller; it sets IsConfirmed 0 and writes one Reopen history
        // row with the reason, in one transaction. Returns 0 when reopened; 12, 8, 4 (another role, an item that does not
        // exist, a blank reason) or 27 (the item is not confirmed any more), and then nothing was saved. The reason is at
        // most ReopenReasonMaxLength characters (the caller checks it; the parameter is NVARCHAR(500)).
        public const int ReopenReasonMaxLength = 500;

        public static int ReopenFollowup(int ActingUserId, int ActionItemId, string ReopenReason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter text = new SqlParameter("@ReopenReason", SqlDbType.NVarChar, ReopenReasonMaxLength);
            text.Value = (object)ReopenReason ?? DBNull.Value;

            SqlParameter[] parameter = new SqlParameter[5];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@ActionItemId", ActionItemId);
            parameter[2] = text;
            parameter[3] = result;
            parameter[4] = reason;

            CommonDB.ExecuteProcedure("spr_ReopenFollowup", parameter);
            return MinutesDB.RefusalReason(result, reason);
        }
        #endregion

        #region GetFollowupList
        // Step FU1 (step 47): the Followup page's list. The rows and the order of the query ReportsMgr.GetFollowupReport
        // builds (it stays for the Followup reports), with the latest history row of each item (StatusAction, StatusReason,
        // StatusOn) and the user who acted (StatusByName, StatusByLogin, StatusByActive). Only an active Controller or MD
        // Secretariat gets rows; Reason 0 when allowed, 12, 8 or 4 otherwise (then no rows).
        public static DataTable GetFollowupList(int ActingUserId, int CommitteeId, int MeetingNoSearch, int MeetingId, int FromMeetingId,
            int ToMeetingId, int DepartmentId, int ConfirmStatus, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[10];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[2] = new SqlParameter("@MeetingNoSearch", MeetingNoSearch);
            parameter[3] = new SqlParameter("@MeetingId", MeetingId);
            parameter[4] = new SqlParameter("@FromMeetingId", FromMeetingId);
            parameter[5] = new SqlParameter("@ToMeetingId", ToMeetingId);
            parameter[6] = new SqlParameter("@DepartmentId", DepartmentId);
            parameter[7] = new SqlParameter("@ConfirmStatus", ConfirmStatus);
            parameter[8] = result;
            parameter[9] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_GetFollowupList", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            return dt;
        }
        #endregion

        #region UpdateActionItemByUserId
        public static void UpdateActionItemByUserId(int UserId, int ActionItemId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@UserId", UserId);
            parameter[1] = new SqlParameter("@ActionItemId", ActionItemId);

            CommonDB.ExecuteProcedure("spr_UpdateActionItemByUserId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
