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

namespace BMMS
{
    public partial class Logout : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (Session["UserId"] != null)
            {
                int UserId = Convert.ToInt16(Session["UserId"].ToString());
                Utilities.AddEditAuditTrialLogin(UserId);
            }
            
            Session.Abandon();
            Response.Cache.SetCacheability(HttpCacheability.Private);
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            
            Response.Redirect(@"~/Default.aspx", false);
        }
    }
}
