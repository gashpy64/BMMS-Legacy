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

        protected void Page_Load(object sender, EventArgs e)
        {
            try
            {
                string error = "";
                if (Request.QueryString["Error"] != null)
                {
                    error = Request.QueryString["Error"].ToString();
                    if (error != null)
                        lblError.Text = error;
                    if (Session["ErrMsg"] != null)
                        lblErrDesc.Text = Session["ErrMsg"].ToString();
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "Page_Load", ex);
            }
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
