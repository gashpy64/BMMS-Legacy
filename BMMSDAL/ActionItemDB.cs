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
