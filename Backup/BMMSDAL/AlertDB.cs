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
                        EmailId += dtResult.Rows[0]["EmailId"].ToString();
                    else
                        EmailId += dtResult.Rows[0]["EmailId"].ToString() + ", ";
            }

            return EmailId;
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
