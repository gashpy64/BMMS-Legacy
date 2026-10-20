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
        }
        #endregion

        #region AlertCount
        // Number shown next to "Alerts" in the header: the same list the DashBoard shows.
        protected int AlertCount
        {
            get
            {
                try
                {
                    if (Session["RoleCode"] == null || Session["UserId"] == null)
                        return 0;

                    // The header is not redrawn on UpdatePanel postbacks, so skip the query there.
                    ScriptManager sm = ScriptManager.GetCurrent(Page);
                    if (sm != null && sm.IsInAsyncPostBack)
                        return 0;

                    return AlertMgr.GetAlertByUserId(Session["RoleCode"].ToString(), int.Parse(Session["UserId"].ToString())).Rows.Count;
                }
                catch (Exception ex)
                {
                    Utilities.WriteErrorLog("Main.Master", "AlertCount", ex.ToString());
                    return 0;
                }
            }
        }
        #endregion

    }
}
