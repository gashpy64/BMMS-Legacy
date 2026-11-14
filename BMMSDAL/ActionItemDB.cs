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

        #region GetFollowup
        public static DataTable GetFollowup(string SQL_Query_Text)
        {
            return CommonDB.GetDataTableFromQuery(SQL_Query_Text);
        }
        #endregion

        #region GetFollowupReportForManagement
        // Step RA1b (BMMS-Fix-ReportAccess-Step41.sql): the Followup rows for Management, with the filters of the
        // Controller's query (ReportsMgr.GetFollowupReport) plus MinutesStatus and MinutesStatusMark. The procedure
        // checks the acting user in the database: Reason 8 (missing or inactive) or 4 (not Management), then no
        // rows. Reason comes back 0 when allowed.
        public static DataTable GetFollowupReportForManagement(int CommitteeId, int MeetingNoSearch, int MeetingId, int FromMeetingId,
            int ToMeetingId, int DepartmentId, int ConfirmStatus, int ActingUserId, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[10];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingNoSearch", MeetingNoSearch);
            parameter[2] = new SqlParameter("@MeetingId", MeetingId);
            parameter[3] = new SqlParameter("@FromMeetingId", FromMeetingId);
            parameter[4] = new SqlParameter("@ToMeetingId", ToMeetingId);
            parameter[5] = new SqlParameter("@DepartmentId", DepartmentId);
            parameter[6] = new SqlParameter("@ConfirmStatus", ConfirmStatus);
            parameter[7] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[8] = result;
            parameter[9] = reason;

            DataTable dt = CommonDB.GetDataTable("spr_GetFollowupReportForManagement", parameter);
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
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = result;
            parameter[2] = reason;

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

        #region GetActionItemByMeetingIdDeptId
        public static DataTable GetActionItemByMeetingIdDeptId(int CommitteeId, int MeetingNoFrom, int MeetingNoTo, int DepartmentId)
        {
            SqlParameter[] parameter = new SqlParameter[4];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingNoFrom", MeetingNoFrom);
            parameter[2] = new SqlParameter("@MeetingNoTo", MeetingNoTo);
            parameter[3] = new SqlParameter("@DepartmentId", DepartmentId);

            return CommonDB.GetDataTable("spr_GetActionItemByMeetingIdDeptId", parameter); ;
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

        #region UpdateActionItem
        public static void UpdateActionItem(string Code, int ActionItemId, string ActualResolution, string ActionText, int IsComplied, int IsConfirmed)
        {
            SqlParameter[] parameter = new SqlParameter[6];
            parameter[0] = new SqlParameter("@Code", Code);
            parameter[1] = new SqlParameter("@ActionItemId", ActionItemId);
            parameter[2] = new SqlParameter("@ActualResolution", ActualResolution);
            parameter[3] = new SqlParameter("@ActionText", ActionText);
            parameter[4] = new SqlParameter("@IsComplied", IsComplied);
            parameter[5] = new SqlParameter("@IsConfirmed", IsConfirmed);

            CommonDB.ExecuteProcedure("spr_UpdateActionItem", parameter); ;
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
