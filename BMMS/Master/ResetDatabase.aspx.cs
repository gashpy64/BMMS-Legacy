using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.IO;
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

        // Upload folders the reset leaves on disk (step 29: the page shows how many files each holds)
        private static readonly string[] FileFolders = { "AgendaAttach", "AgendaText", "MemberPhoto", "MemberResume", "SqlBackup" };

        // Seconds the browser and the server wait for the reset: above the 300-second command timeout
        // of UtilitiesDB.ResetDatabase, so the answer (sign-in page or message) always reaches the page
        private const int ResetRequestTimeout = 330;

        #region Page_Init
        protected void Page_Init(object sender, EventArgs e)
        {
            // Bind view state to this session so a forged postback is rejected.
            ViewStateUserKey = Session.SessionID;

            // Fail closed before view state is loaded and before any control event can
            // fire. This page invokes spr_sys_ResetDatabase, which deletes every record
            // in the database and re-creates the default users and masters. It must
            // never be reachable without an authenticated administrator.
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

            // This page only: the default is 90 seconds, after which the browser stops waiting
            ScriptManager.GetCurrent(Page).AsyncPostBackTimeout = ResetRequestTimeout;

            if (!IsPostBack)
            {
                btnResetDatabase.Visible = IsAdministrator();

                try
                {
                    string databaseName = Utilities.GetDatabaseName();

                    litDatabaseName.Text = HttpUtility.HtmlEncode(databaseName);
                    // The typed name is checked in the browser before the dialog opens (ResetDatabaseConfirm in the
                    // .aspx), and again on the server and in spr_sys_ResetDatabase
                    btnResetDatabase.OnClientClick = "return ResetDatabaseConfirm('" + HttpUtility.JavaScriptStringEncode(databaseName)
                        + "', 'This permanently deletes all committees, meetings, agenda items, minutes, "
                        + "members, users and audit records in database " + HttpUtility.JavaScriptStringEncode(databaseName)
                        + " and re-creates the default data. Organisation settings are kept; the mail settings are replaced "
                        + "by a safe default (localhost, port 25, no login, noreply@example.invalid); uploaded files are not removed. "
                        + "Afterwards sign in as admin with the default password and choose a new one. Continue?');";

                    BindFileCounts();
                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "Page_Load", ex);
                }
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

            MsgHide();

            MeetingChangeResult result;

            try
            {
                string typed = txtConfirmDatabaseName.Text.Trim();

                // The page compares ignoring case; spr_sys_ResetDatabase compares again
                if (!string.Equals(typed, Utilities.GetDatabaseName(), StringComparison.OrdinalIgnoreCase))
                {
                    MsgDisplay("The name you typed is not the name of this database. Nothing was changed.");
                    return;
                }

                int ActingUserId = int.Parse(Session["UserId"].ToString());

                // This request only: the default is 110 seconds, after which ASP.NET stops the request
                Server.ScriptTimeout = ResetRequestTimeout;

                result = Utilities.ResetDatabase(ActingUserId, typed);
            }
            catch (Exception ex)
            {
                // The reset runs in one transaction: an error or a timeout has rolled all of it back
                Utilities.WriteErrorLog(className, "btnResetDatabase_Click", ex.ToString());
                MsgDisplay("The reset did not run; nothing was changed. The error is in the error log.", MessageKind.Error);
                return;
            }

            if (result.Result == 1)
            {
                // The users this session refers to no longer exist: sign out
                Session.Clear();
                Session.Abandon();
                Response.Redirect(@"~/Default.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
            else if (result.Reason == MeetingChangeReason.ActingUserInvalid)
                MsgDisplay(result.RefusalMessage());
            else if (result.Reason == MeetingChangeReason.NotFound)
                MsgDisplay("Only an Admin can reset the database. Nothing was changed.");
            else
                MsgDisplay("The name you typed is not the name of this database. Nothing was changed.");
        }
        #endregion

        #region Render
        // After a reset the session is empty and the page is not drawn: the menu reads
        // Session["RoleCode"] while drawing (MenuUserControl.ascx) and would fail
        protected override void Render(HtmlTextWriter writer)
        {
            if (!Response.IsRequestBeingRedirected)
                base.Render(writer);
        }
        #endregion

        #region BindFileCounts
        private void BindFileCounts()
        {
            DataTable dt = new DataTable();
            dt.Columns.Add("Folder");
            dt.Columns.Add("Files", typeof(int));

            foreach (string folder in FileFolders)
            {
                string path = Server.MapPath("~/Files/" + folder);
                int count = Directory.Exists(path) ? Directory.GetFiles(path, "*", SearchOption.AllDirectories).Length : 0;
                dt.Rows.Add("Files/" + folder, count);
            }

            grvFiles.DataSource = dt;
            grvFiles.DataBind();
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

        #region MsgDisplay
        private void MsgDisplay(string errMsg, MessageKind kind = MessageKind.Warning)
        {
            divErrLogin.Attributes.Add("class", Common.MessageCss(kind));
            spanErrLogin.InnerHtml = errMsg;
        }
        #endregion

        #region MsgHide
        private void MsgHide()
        {
            divErrLogin.Attributes.Add("class", "divErrorHide");
        }
        #endregion

    }
}
