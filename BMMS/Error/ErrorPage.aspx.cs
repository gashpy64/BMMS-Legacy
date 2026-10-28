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

        #region OnPreInit
        // No signed-in user (the session expired, or its cookie was removed): straight to the login page, on GET
        // and on POST, with no log entry (step E2b). The page is public in PageAccess.xml, so PageAccessModule does
        // not send the visitor away, and the menu of Main.Master cannot render without Session["RoleCode"].
        // PreInit runs before the master page and its menu are created and before any postback event (Exit), and
        // Response.Redirect(url, true) ends the request here, as Common.InitSetup does on the other pages; the
        // ThreadAbortException it uses is the normal end of a request and does not reach Application_Error.
        // The test is the one PageAccessModule uses: Session["UserName"] empty.
        protected override void OnPreInit(EventArgs e)
        {
            if (string.IsNullOrEmpty(Session["UserName"] as string))
                Response.Redirect("~/Default.aspx", true);

            base.OnPreInit(e);
        }
        #endregion

        // The page shows a fixed text only (step E2): it no longer reads the "Error" query string or
        // Session["ErrMsg"], so no exception text and nothing from the address reaches the browser
        protected void Page_Load(object sender, EventArgs e)
        {
        }

        #region btnExit_Click
        // Back to the page that failed, with its original query string (Session["ErrorReturnPage"], set by
        // Utilities.GoToErrPage; step E2b), when it is a normal page of this application that exists; otherwise
        // the Dashboard. Session["PageURL"] is no longer used: it can be stale or wrong.
        protected void btnExit_Click(object sender, EventArgs e)
        {
            try
            {
                string target = "~/DashBoard/DashBoard.aspx";

                string returnPage = Session[Utilities.ErrorReturnPageKey] as string;
                Session.Remove(Utilities.ErrorReturnPageKey);

                if (IsExistingReturnPage(returnPage))
                    target = returnPage;

                Response.Redirect(target, false);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "ExitData", ex);
            }
        }
        #endregion

        #region IsExistingReturnPage
        // ~/path.aspx?query: the path passes Utilities.IsReturnablePage and the file exists
        private bool IsExistingReturnPage(string ReturnPage)
        {
            if (string.IsNullOrEmpty(ReturnPage))
                return false;

            int query = ReturnPage.IndexOf('?');
            string path = query < 0 ? ReturnPage : ReturnPage.Substring(0, query);

            if (!Utilities.IsReturnablePage(path))
                return false;

            try
            {
                return System.IO.File.Exists(Server.MapPath(path));
            }
            catch (Exception)
            {
                return false;
            }
        }
        #endregion
    }
}
