#region Assembly
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
#endregion

namespace BMMS
{
    public partial class _Default : System.Web.UI.Page
    {
        private string className = "Login";


        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            InitSetup();

            if (!Page.IsPostBack)
            {
                InitCtrlAttributes();
                ScriptManager.GetCurrent(this).SetFocus(txtLoginName.ClientID);

                // Sent here by PageAccessModule: the account was deactivated while logged in
                if (Request.QueryString["status"] == "inactive")
                    MsgDisplay(InactiveMessage);
            }
        }
        #endregion

        private const string InactiveMessage = "Your account is inactive. Contact the administrator.";

        #region InitSetup()
        private void InitSetup()
        {
            Page.Title = Common.GetAppSetting("PageTitle") + " - Login";
            // the footer line of the other pages (step B3)
            lblFooter.Text = Common.ProductFooter(typeof(_Default).Assembly);
            Session["PageURL"] = "~/Default.aspx";
            txtLoginName.Attributes.Add("MaxLength", Common.GetAppSetting("LoginIdMaxLength"));
            txtPassword.Attributes.Add("MaxLength", Common.GetAppSetting("PasswordMaxLength"));
        }
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            txtLoginName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtLoginName.ClientID + "');GoToNxtTxtBox(event,'" + txtPassword.ClientID + "')");
            txtPassword.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtPassword.ClientID + "');GoToNxtTxtBox(event,'" + btnLogin.ClientID + "')");
            btnLogin.Attributes.Add("onclick", "return LoginValidation()");
        }
        #endregion

        #region btnLogin_Click
        protected void btnLogin_Click(object sender, ImageClickEventArgs e)
        {
            string errMsg = string.Empty;

            DataTable dtUser = new DataTable();

            string sLoginName = txtLoginName.Text.Trim();
            string sPasswordInput = txtPassword.Text.Trim();
            string User_IP_Address = Utilities.GetLocalIPAddress();
            string Server_Url = Request.Url.AbsoluteUri.ToString();

            try
            {
                dtUser = UserMgr.GetUserByLoginName(sLoginName, string.Empty, User_IP_Address, Server_Url);

                if (dtUser.Rows.Count <= 0)
                {
                    txtLoginName.Text = string.Empty;
                    txtPassword.Text = string.Empty;

                    errMsg = "Invalid User Id / Password";
                    ScriptManager.GetCurrent(this).SetFocus(txtLoginName.ClientID);

                }
                else if (!Common.VerifyPassword(sPasswordInput, dtUser.Rows[0]["Password"].ToString()))
                {
                    int UserId = int.Parse(dtUser.Rows[0]["UserId"].ToString());

                    txtLoginName.Text = string.Empty;
                    txtPassword.Text = string.Empty;

                    if (Session["LoginCount"] != null)
                        Session["LoginCount"] = int.Parse(Session["LoginCount"].ToString()) + 1;
                    else
                        Session["LoginCount"] = "1";

                    errMsg = "Invalid User Id / Password";
                    ScriptManager.GetCurrent(this).SetFocus(txtLoginName.ClientID);

                    //if (Session["LoginCount"].ToString() == "3")
                        //UserMgr.LockUserByUserId(UserId);
                }
                else if (dtUser.Rows[0]["AccountStatus"].ToString() != "1")
                {
                    // Checked after the password, so the message does not tell a stranger the login exists
                    errMsg = InactiveMessage;
                    ScriptManager.GetCurrent(this).SetFocus(txtLoginName.ClientID);
                }
                else
                {
                    int loggedInUserId = int.Parse(dtUser.Rows[0]["UserId"].ToString());
                    UserMgr.RecordLogin(loggedInUserId, User_IP_Address, Server_Url);

                    // Upgrade an old-format password to the new hash on first successful login
                    if (Common.IsLegacyFormat(dtUser.Rows[0]["Password"].ToString()))
                        UserMgr.ResetPasswordByUserId(loggedInUserId, Common.HashPassword(sPasswordInput), loggedInUserId);
                    Session["UserId"] = dtUser.Rows[0]["UserId"].ToString();
                    Session["UserName"] = dtUser.Rows[0]["UserName"].ToString();
                    Session["DesignName"] = dtUser.Rows[0]["DesignationName"].ToString();
                    Session["RoleCode"] = dtUser.Rows[0]["RoleCode"].ToString();
                    Session["RoleName"] = dtUser.Rows[0]["RoleName"].ToString();
                    Session["NoRecord"] = Common.GetAppSetting("NoRecord");
                    // The protected system account (BMMS-Fix-SystemAccount-Stage3.sql): "1" or "0"
                    Session["IsSystem"] = dtUser.Columns.Contains("IsSystem") && Convert.ToBoolean(dtUser.Rows[0]["IsSystem"]) ? "1" : "0";

                    if (sPasswordInput == Common.DefaultPassword)
                        Response.Redirect(@"~\ChangePasswordFirst.aspx", false);
                    else
                        Response.Redirect(@"~\DashBoard\Dashboard.aspx", false);
                }

            }
            catch (Exception ex)
            {
                errMsg = "Database not connected";
                Utilities.WriteErrorLog(className, "btnLogin_Click", ex.ToString());
            }
            finally
            {

            }

            MsgDisplay(errMsg, errMsg == "Database not connected" ? MessageKind.Error : MessageKind.Warning);

            //Response.Redirect(@"~\DashBoard\Dashboard.aspx", false);
        }
        #endregion

        #region MsgDisplay
        private void MsgDisplay(string errMsg, MessageKind kind = MessageKind.Warning)
        {
            divErrLogin.Attributes.Add("class", Common.MessageCss(kind));
            spanErrLogin.InnerHtml = errMsg;
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


    }
}
