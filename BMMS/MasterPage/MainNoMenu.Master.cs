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

namespace BMMS.MasterPage
{
    public partial class MainNoMenu : System.Web.UI.MasterPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            InitSetup();

            if (!IsPostBack)
            {
                
            }
        }

        #region InitSetup()
        private void InitSetup()
        {
            if (Session["PageTitle"] != null)
                Page.Title = Session["PageTitle"].ToString();
            else
                Page.Title = Common.GetAppSetting("PageTitle");

            lblFooter.Text = Common.ProductFooter(typeof(MainNoMenu).Assembly);
            SetFooterDatabase();
        }
        #endregion

        #region SetFooterDatabase
        // Step F1: "Database: <name>" under the footer line for Admin and Controller; for every other role and when
        // the name cannot be read the label is not rendered. Common.FooterDatabaseName returns the name HTML-encoded.
        private void SetFooterDatabase()
        {
            string databaseName = Common.FooterDatabaseName(Session["RoleCode"] as string);

            lblFooterDatabase.Visible = databaseName != null;
            if (databaseName != null)
                lblFooterDatabase.Text = "Database: " + databaseName;
        }
        #endregion

        #region ScriptManager1_AsyncPostBackError
        // An unhandled error in an UpdatePanel postback: written to the error log, and the browser gets a fixed
        // text instead of the exception (JScript/AsyncPostBackError.js shows the message bar; step E1)
        protected void ScriptManager1_AsyncPostBackError(object sender, AsyncPostBackErrorEventArgs e)
        {
            ScriptManager1.AsyncPostBackErrorMessage = Utilities.AsyncPostBackErrorMessage;
            Utilities.LogAsyncPostBackError(Page, e.Exception, ScriptManager1.AsyncPostBackSourceElementID);
        }
        #endregion

    }
}
