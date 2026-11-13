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
    public partial class Main : System.Web.UI.MasterPage
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

            lblFooter.Text = Common.ProductFooter(typeof(Main).Assembly);
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

        #region Alert count
        // Step UN6c1: "Alerts (n)" in the header: the unread alerts of the signed-in user by the rule of the
        // Dashboard's Alerts card (spr_GetAlertCount, step 43; the role is read from the database, not from the
        // session). Read on every full page load. On an UpdatePanel postback the header is not redrawn, unless the
        // page asks for it with RefreshAlertCount (the Dashboard does, after an action that can change the count).
        protected override void OnPreRender(EventArgs e)
        {
            base.OnPreRender(e);

            ScriptManager sm = ScriptManager.GetCurrent(Page);
            if (sm == null || !sm.IsInAsyncPostBack)
                ShowAlertCount();
        }

        // Reads the count again and redraws it in the header. When it cannot be read the header shows "Alerts"
        // without a number: the number shown before may be out of date after the action.
        public void RefreshAlertCount()
        {
            ShowAlertCount();
            upAlertCount.Update();
        }

        // A count that cannot be read shows "Alerts" without a number (never a misleading 0 or an old number)
        private void ShowAlertCount()
        {
            try
            {
                int userId;
                if (Session["UserId"] == null || !int.TryParse(Session["UserId"].ToString(), out userId))
                {
                    litAlertCount.Text = string.Empty;
                    return;
                }

                int reason;
                int count = AlertMgr.GetAlertCount(userId, out reason);
                litAlertCount.Text = reason == 0 ? " (" + count + ")" : string.Empty;
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog("Main.Master", "ShowAlertCount", ex.ToString());
                litAlertCount.Text = string.Empty;
            }
        }
        #endregion

    }
}
