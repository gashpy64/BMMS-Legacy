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

namespace BMMS.Error
{
    public partial class ErrorPage : System.Web.UI.Page
    {
        private string className = "ErrorPage";

        // The page shows a fixed text only (step E2): it no longer reads the "Error" query string or
        // Session["ErrMsg"], so no exception text and nothing from the address reaches the browser
        protected void Page_Load(object sender, EventArgs e)
        {
        }

        #region btnExit_Click
        protected void btnExit_Click(object sender, EventArgs e)
        {
            try
            {
                if (Session["PageURL"] != null)
                    Response.Redirect(Session["PageURL"].ToString(), false);
                else
                    Response.Redirect("~/DashBoard/DashBoard.aspx", false);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "ExitData", ex);
            }
        }
        #endregion
    }
}
