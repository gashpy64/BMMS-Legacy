using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Web;
using System.Web.Security;
using System.Web.SessionState;
using BMMSBAL;

namespace BMMS
{
    public class Global : System.Web.HttpApplication
    {

        protected void Application_Start(object sender, EventArgs e)
        {

        }

        protected void Application_End(object sender, EventArgs e)
        {

        }

        protected void Session_End(Object sender, EventArgs e)
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