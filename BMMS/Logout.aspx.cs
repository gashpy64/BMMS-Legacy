using System;
using System.Web;
using BMMSBAL;

namespace BMMS
{
    public partial class Logout : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            try
            {
                if (Session["UserId"] != null)
                {
                    int UserId = Convert.ToInt16(Session["UserId"].ToString());
                    Utilities.AddEditAuditTrialLogin(UserId);
                }
            }
            catch (Exception)
            {
                // never let the audit write stop a logout
            }

            Session.Clear();
            Session.Abandon();
            Response.Cache.SetCacheability(HttpCacheability.NoCache);

            Response.Redirect("~/Default.aspx", true);
        }
    }
}