using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;

namespace BMMSDAL
{
    #region UtilitiesDB
    public class UtilitiesDB
    {

        #region ResetDatabase
        public static int ResetDatabase()
        {
            return CommonDB.ExecuteProcedure("spr_sys_ResetDatabase", null); ;
        }
        #endregion

        #region GetSMTPMaster
        public static DataTable GetSMTPMaster()
        {
            return CommonDB.GetDataTable("spr_GetSMTPMaster", null); ;
        }
        #endregion

        #region GetStateMaster
        public static DataTable GetStateMaster()
        {
            return CommonDB.GetDataTable("spr_GetStateMaster", null); ;
        }
        #endregion

        #region UpdateSMTPMaster
        public static DataTable UpdateSMTPMaster(string SMTPServer, string SMTPServerPort,
            string UserName, string Password, string FromMailId, string Bcc)
        {
            SqlParameter[] parameter = new SqlParameter[6];
            parameter[0] = new SqlParameter("@SMTPServer", SMTPServer);
            parameter[1] = new SqlParameter("@SMTPServerPort", SMTPServerPort);
            parameter[2] = new SqlParameter("@UserName", UserName);
            parameter[3] = new SqlParameter("@Password", Password);
            parameter[4] = new SqlParameter("@FromMailId", FromMailId);
            parameter[5] = new SqlParameter("@Bcc", Bcc);

            return CommonDB.GetDataTable("spr_UpdateSMTPMaster", parameter); ;
        }
        #endregion

        #region AddEditAuditTrialLogin
        public static int AddEditAuditTrialLogin(int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@UserId", UserId);

            return CommonDB.ExecuteProcedure("spr_AddEditAuditTrialLogin", parameter); ;
        }
        #endregion
    
    }
    #endregion
    
}
