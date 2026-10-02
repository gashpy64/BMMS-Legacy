using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Web;
using System.Web.UI.WebControls;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    public class AuditTrail_Mgr
    {

        #region AddEditAuditTrailSqlBackup
        public static int AddEditAuditTrailSqlBackup(string Backup_File_Name, int User_Id, string User_IP_Address, string Server_Url)
        {
            return AuditTrail_DB.AddEditAuditTrailSqlBackup(Backup_File_Name, User_Id, User_IP_Address, Server_Url);
        }
        #endregion

        #region GetAuditTrailSqlBackup
        public static DataTable GetAuditTrailSqlBackup()
        {
            return AuditTrail_DB.GetAuditTrailSqlBackup();
        }
        #endregion

        #region GetAuditTrailMasterByUserId
        public static DataTable GetAuditTrailMasterByUserId(int UserId, DateTime From_Date, DateTime To_Date)
        {
            return AuditTrail_DB.GetAuditTrailMasterByUserId(UserId, From_Date, To_Date);
        }
        #endregion
    }
}
