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
    public partial class ChangePassword : System.Web.UI.Page
    {
        private string className = "ChangePassword";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                ScriptManager.GetCurrent(this).SetFocus(txtOldPassword.ClientID);
            }
        }
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            txtOldPassword.Attributes.Add("MaxLength", Common.GetAppSetting("PasswordMaxLength"));
            txtNewPassword.Attributes.Add("MaxLength", Common.GetAppSetting("PasswordMaxLength"));
            txtConfirmPassword.Attributes.Add("MaxLength", Common.GetAppSetting("PasswordMaxLength"));

            btnChangePwd.Attributes.Add("onclick", "return ChangePasswordValidation()");

            txtOldPassword.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + txtOldPassword.ClientID + "');GoToNxtTxtBox(event,'" + txtOldPassword.ClientID + "')");
            txtNewPassword.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + txtNewPassword.ClientID + "');GoToNxtTxtBox(event,'" + txtNewPassword.ClientID + "')");
            txtConfirmPassword.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + txtConfirmPassword.ClientID + "');GoToNxtTxtBox(event,'" + txtConfirmPassword.ClientID + "')");

        }
        #endregion

        #region btnChangePwd_Click
        protected void btnChangePwd_Click(object sender, EventArgs e)
        {
            MsgHide();

            if (PageValidation())
            {
                int UserId = Convert.ToInt16(Session["UserId"].ToString());
                string Password = Common.HashPassword(txtNewPassword.Text.Trim());
                int UpdatedBy = Convert.ToInt16(Session["UserId"].ToString());

                UserMgr.ResetPasswordByUserId(UserId, Password, UpdatedBy);

                string sMsg = "Successfully Saved";
                MsgDisplay(sMsg);
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {

            int UserId = Convert.ToInt16(Session["UserId"].ToString());

            DataTable dtUser = UserMgr.GetUserDataTableByUserId(UserId);

            if (!Common.VerifyPassword(txtOldPassword.Text.Trim(), dtUser.Rows[0]["Password"].ToString()))
            {
                MsgDisplay("Plese enter correct old password.");
                ScriptManager.GetCurrent(this).SetFocus(txtOldPassword.ClientID);
                return false;
            }

            int PasswordMinLength = Convert.ToInt16(Common.GetAppSetting("PasswordMinLength"));
            if (txtNewPassword.Text.Trim().Length <= PasswordMinLength)
            {
                MsgDisplay("Password length minimum of " + PasswordMinLength.ToString() + " characters in length");
                ScriptManager.GetCurrent(this).SetFocus(txtNewPassword.ClientID);
                return false;
            }

            return true;
        }
        #endregion

        #region MsgDisplay
        private void MsgDisplay(string errMsg)
        {
            divErrLogin.Attributes.Add("class", "divError");
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
