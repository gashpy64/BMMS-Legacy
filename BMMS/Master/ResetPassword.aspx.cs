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
    public partial class ResetPassword : System.Web.UI.Page
    {
        private string className = "ResetPassword";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                pnlResetPassword.Visible = false;
                ltrlUserDetails.Text = string.Empty;
                hdnEmailId.Value = string.Empty;
                MsgHide();
                LoadLoginUser();
            }
        }
        #endregion


        #region LoadLoginUser
        private void LoadLoginUser()
        {
            try
            {
                DataTable dtUser = new DataTable();
                dtUser = UserMgr.GetUserList();

                Common.LoadDropdownlist(ddlLoginUser, dtUser, "LoginName", "UserId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadLoginUser", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region ddlLoginUser_SelectedIndexChanged
        protected void ddlLoginUser_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();

            if (ddlLoginUser.Text == "0")
            {
                pnlResetPassword.Visible = false;
                ltrlUserDetails.Text = string.Empty;
                hdnEmailId.Value = string.Empty;
            }
            else
            {
                pnlResetPassword.Visible = true;

                int UserId = Convert.ToInt16(ddlLoginUser.SelectedValue);

                DataTable dtUser = new DataTable();
                dtUser = UserMgr.GetUserDataTableByUserId(UserId);
                hdnEmailId.Value = dtUser.Rows[0]["EmailId"].ToString();

                ltrlUserDetails.Text = Common.LoadUserDetails(dtUser);
            }
        }
        #endregion

        #region btnResetPassword_Click
        protected void btnResetPassword_Click(object sender, EventArgs e)
        {
            int PasswordLength = 8; // Convert.ToInt16(Common.GetAppSetting("PasswordMaxLength"));
            string NewPassword = "lvb@123"; // Common.CreateRandomPassword(PasswordLength);

            string ToMailId = hdnEmailId.Value.ToString();
            string Subject = "Your password has been reset to default password";
            string BodyText = "Your password has been reset to default password. <br />";
            BodyText += "Please change your password after login.";

            string result = string.Empty;
            result = Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, null);
            
            

            string errMsg = string.Empty;

            if (result == "Success")
            {
                int UserId = Convert.ToInt16(ddlLoginUser.SelectedValue);
                int UpdatedBy = Convert.ToInt16(Session["UserId"].ToString());

                string Password = Common.EncryptVal(NewPassword);

                errMsg = "New passward was sent through mail.";

                UserMgr.ResetPasswordByUserId(UserId, Password, UpdatedBy);
            }
            else
            {
                errMsg = "Error : " + result;
            }

            MsgDisplay(errMsg);
            pnlResetPassword.Visible = false;
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
