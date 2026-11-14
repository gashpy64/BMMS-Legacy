using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region AlertDAL
    public class AlertDAL
    {
        #region Properties

        #endregion
    }
    #endregion

    #region AlertDALList
    public class AlertDALList : List<AlertDAL>
    {
        #region AlertDALList
        public AlertDALList()
        {

        }
        #endregion
    }
    #endregion

    #region AlertDB
    public class AlertDB
    {

        #region GetAlertByUserId
        public static DataTable GetAlertByUserId(String RoleName, int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@RoleName", RoleName);
            parameter[1] = new SqlParameter("@UserId", UserId);

            return CommonDB.GetDataTable("spr_GetAlertByUserId", parameter); ;
        }
        #endregion

        #region GetAlertMailId
        public static string GetAlertMailId(string Code, int UserId, int AgendaId)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@Code", Code);
            parameter[1] = new SqlParameter("@UserId", UserId);
            parameter[2] = new SqlParameter("@AgendaId", AgendaId);

            DataTable dtResult = new DataTable();
            dtResult = CommonDB.GetDataTable("spr_GetAlertMailId", parameter); ;

            string EmailId = string.Empty;

            for (int i = 0; i < dtResult.Rows.Count; i++)
            {
                if (dtResult.Rows[i]["EmailId"].ToString().Trim() != string.Empty)
                    if (i == dtResult.Rows.Count - 1)
                        EmailId += dtResult.Rows[i]["EmailId"].ToString();
                    else
                        EmailId += dtResult.Rows[i]["EmailId"].ToString() + ", ";
            }

            return EmailId;
        }
        #endregion

        #region GetDashboardAlerts
        // Step UN6c1 (BMMS-Fix-DashboardAlerts-Step43.sql): the Alerts card. The procedure reads the role from the
        // acting user id and lists by fn_DashboardAlerts. Mode R (recent: unread, and read of the last 7 days),
        // U (unread) or A (all); a page of 10. Reason 0 when allowed, otherwise 8 (user missing or inactive) or 4
        // (mode or page number not allowed), and then no rows. TotalRows counts the mode, UnreadCount the whole
        // list; PageShown is the page given (the last one when a later page was asked).
        public static DataTable GetDashboardAlerts(int ActingUserId, string Mode, int PageNo,
            out int Reason, out int TotalRows, out int UnreadCount, out int PageShown)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;
            SqlParameter total = new SqlParameter("@TotalRows", SqlDbType.Int);
            total.Direction = ParameterDirection.Output;
            SqlParameter unread = new SqlParameter("@UnreadCount", SqlDbType.Int);
            unread.Direction = ParameterDirection.Output;
            SqlParameter shown = new SqlParameter("@PageShown", SqlDbType.Int);
            shown.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[8];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@Mode", Mode);
            parameter[2] = new SqlParameter("@PageNo", PageNo);
            parameter[3] = result;
            parameter[4] = reason;
            parameter[5] = total;
            parameter[6] = unread;
            parameter[7] = shown;

            DataTable dt = CommonDB.GetDataTable("spr_GetDashboardAlerts", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            TotalRows = OutputInt(total, 0);
            UnreadCount = OutputInt(unread, 0);
            PageShown = OutputInt(shown, 1);
            return dt;
        }
        #endregion

        #region GetAlertCount
        // Step UN6c1 (step 43): the unread alerts of the acting user by the rule of the Alerts card, for the header.
        // Reason 0 when allowed, otherwise 8 (user missing or inactive) and 0.
        public static int GetAlertCount(int ActingUserId, out int Reason)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;
            SqlParameter unread = new SqlParameter("@UnreadCount", SqlDbType.Int);
            unread.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[4];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = result;
            parameter[2] = reason;
            parameter[3] = unread;

            CommonDB.ExecuteProcedure("spr_GetAlertCount", parameter);
            Reason = MinutesDB.RefusalReason(result, reason);
            return Reason == 0 ? OutputInt(unread, 0) : 0;
        }
        #endregion

        #region RemoveAlertForUser
        // Step UN6c1 (step 43): "Remove from my list". The procedure hides the row only when it is the acting user's
        // own. Returns 0 when done, otherwise 8 (user missing or inactive) or 4 (the row is another user's or does not
        // exist); then nothing was changed.
        public static int RemoveAlertForUser(int ActingUserId, int AlertUserId)
        {
            SqlParameter result = new SqlParameter("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.Output;
            SqlParameter reason = new SqlParameter("@Reason", SqlDbType.Int);
            reason.Direction = ParameterDirection.Output;

            SqlParameter[] parameter = new SqlParameter[4];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@AlertUserId", AlertUserId);
            parameter[2] = result;
            parameter[3] = reason;

            CommonDB.ExecuteProcedure("spr_RemoveAlertForUser", parameter);
            return MinutesDB.RefusalReason(result, reason);
        }
        #endregion

        #region OutputInt
        private static int OutputInt(SqlParameter Parameter, int IfEmpty)
        {
            return Parameter.Value == null || Parameter.Value == DBNull.Value ? IfEmpty : Convert.ToInt32(Parameter.Value);
        }
        #endregion

        #region UpdateAlertByUserId
        public static void UpdateAlertByUserId(int UserId, int AlertId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@UserId", UserId);
            parameter[1] = new SqlParameter("@AlertId", AlertId);

            CommonDB.ExecuteProcedure("spr_UpdateAlertByUserId", parameter); ;
        }
        #endregion

        #region UpdateAlertByAlertUserId
        public static void UpdateAlertByAlertUserId(int AlertUserId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@AlertUserId", AlertUserId);

            CommonDB.ExecuteProcedure("spr_UpdateAlertByAlertUserId", parameter); ;
        }
        #endregion

        #region UpdateAlertByMeetingId
        public static void UpdateAlertByMeetingId(int MeetingId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            CommonDB.ExecuteProcedure("spr_UpdateAlertByMeetingId", parameter); ;
        }
        #endregion
    }
    #endregion

}
