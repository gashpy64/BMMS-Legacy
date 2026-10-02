using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using BMMSBAL;

namespace BMMS.Master
{
    /*public partial class BackupDatabase : System.Web.UI.Page
    {
        private string className = "BackupDatabase";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                BindSqlBackup();
                string destinationPath = Server.MapPath("~/Files/SqlBackup");
                ltrlNote.Text = "<b>Note :</b> SQL Backup file was stored in the location of <b>" + destinationPath + @"\</b>";
            }
        }
        #endregion
        
        #region btnBackupDatabase_Click
        protected void btnBackupDatabase_Click(object sender, EventArgs e)
        {
            string Backup_File_Name = "SqlBakup-" + System.DateTime.Now.ToString("yyyy-MM-dd-HH-mm-ss")  + ".bak";
            string destinationPath = Server.MapPath("~/Files/SqlBackup") + "\\" + Backup_File_Name;
            Sql_Backup_Mgr.BackupDatabase(destinationPath);

            int User_Id = Convert.ToInt16(Session["UserId"].ToString());
            string User_IP_Address = Utilities.GetLocalIPAddress();
            string Server_Url = Request.Url.AbsoluteUri.ToString();

            AuditTrail_Mgr.AddEditAuditTrailSqlBackup(Backup_File_Name, User_Id, User_IP_Address, Server_Url);

            BindSqlBackup();
            //Response.Redirect(@"~/Default.aspx", false);
        }
        #endregion

        #region BindSqlBackup
        private void BindSqlBackup()
        {
            try
            {
                DataTable dtSqlBackup = new DataTable();

                dtSqlBackup = AuditTrail_Mgr.GetAuditTrailSqlBackup();

                grvSqlBackup.DataSource = dtSqlBackup;
                grvSqlBackup.DataBind();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindSqlBackup", ex);
            }
            finally
            {

            }
        }
        #endregion
        

    } */
}
