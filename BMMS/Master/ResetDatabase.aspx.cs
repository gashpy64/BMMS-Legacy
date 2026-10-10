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

namespace BMMS.Master
{
    public partial class ResetDatabase : System.Web.UI.Page
    {
        // Previously "MinutesFinalization" (copy/paste), which set the wrong page title.
        private string className = "ResetDatabase";

        #region Page_Init
        protected void Page_Init(object sender, EventArgs e)
        {
            // Bind view state to this session so a forged postback is rejected.
            ViewStateUserKey = Session.SessionID;

            // Fail closed before view state is loaded and before any control event can
            // fire. This page invokes spr_sys_ResetDatabase, which deletes every record
            // in the database - including all of Users and Roles - leaving the
            // application with no accounts able to sign in. It must never be reachable
            // without an authenticated administrator.
            if (Session["UserName"] == null)
            {
                HttpContext.Current.Response.Redirect("~/", true);
            }

            if (!IsAdministrator())
            {
                DenyAccess();
            }
        }
        #endregion

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                btnResetDatabase.Visible = IsAdministrator();
            }
        }
        #endregion

        #region btnResetDatabase_Click
        protected void btnResetDatabase_Click(object sender, EventArgs e)
        {
            // Defence in depth. Page_Init already refuses the request, but a destructive
            // action should never rest on a single check.
            if (!IsAdministrator())
            {
                DenyAccess();
                return;
            }

            Utilities.ResetDatabase();

            Response.Redirect(@"~/Default.aspx", false);
        }
        #endregion

        #region IsAdministrator
        private static bool IsAdministrator()
        {
            object role = HttpContext.Current.Session["RoleCode"];

            return role != null
                && string.Equals(role.ToString().Trim(), "admin", StringComparison.OrdinalIgnoreCase);
        }
        #endregion

        #region DenyAccess
        private static void DenyAccess()
        {
            HttpContext context = HttpContext.Current;

            context.Response.Clear();
            context.Response.StatusCode = 403;
            context.Response.StatusDescription = "Forbidden";
            context.Response.Write("Access denied.");
            context.Response.End();
        }
        #endregion

    }
}
