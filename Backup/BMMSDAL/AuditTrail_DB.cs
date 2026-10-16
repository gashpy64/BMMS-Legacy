using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region AuditTrail_DB
    public class AuditTrail_DB
    {

        #region AddEditAuditTrailSqlBackup
        public static int AddEditAuditTrailSqlBackup(string Backup_File_Name, int User_Id, string User_IP_Address, string Server_Url)
        {
            SqlParameter[] parameter = new SqlParameter[4];
            parameter[0] = new SqlParameter("@Backup_File_Name", Backup_File_Name);
            parameter[1] = new SqlParameter("@User_Id", User_Id);
            parameter[2] = new SqlParameter("@User_IP_Address", User_IP_Address);
            parameter[3] = new SqlParameter("@Server_Url", Server_Url);

            return CommonDB.ExecuteProcedure("spr_AddEditAuditTrailSqlBackup", parameter); ;
        }
        #endregion

        #region GetAuditTrailSqlBackup
        public static DataTable GetAuditTrailSqlBackup()
        {
            return CommonDB.GetDataTable("spr_GetAuditTrailSqlBackup", null); ;
        }
        #endregion

        #region GetAuditTrailMasterByUserId
        public static DataTable GetAuditTrailMasterByUserId(int UserId, DateTime From_Date, DateTime To_Date)
        {

            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@UserId", UserId);
            parameter[1] = new SqlParameter("@From_Date", From_Date);
            parameter[2] = new SqlParameter("@To_Date", To_Date);

            return CommonDB.GetDataTable("spr_GetAuditTrailMasterByUserId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
