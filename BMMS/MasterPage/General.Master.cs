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
    public partial class General : System.Web.UI.MasterPage
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

            lblFooter.Text = Common.GetAppSetting("FooterText");
        }
        #endregion
    }
}
