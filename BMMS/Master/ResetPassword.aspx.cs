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

        // Step IU1: the reset of an inactive user (no mail); the mail failure text of step M1
        private const string InactiveNoMailMessage = "The password was reset to the default password. No mail was sent because the user is inactive.";
        private const string MailNotSentMessage = "The password was reset to the default password, but the mail could not be sent. The error is in the error log.";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            // Step RA1a: Admin only (role read from the database; ends the request otherwise)
            BMMS.Security.PageAccessModule.RequireRole("admin");

            if (!IsPostBack)
            {
                pnlResetPassword.Visible = false;
                ltrlUserDetails.Text = string.Empty;
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

                // The protected system account changes its own password only (BMMS-Fix-SystemAccount-Stage3.sql)
                for (int i = dtUser.Rows.Count - 1; i >= 0; i--)
                    if (Common.IsSystemAccountRow(dtUser.Rows[i]))
                        dtUser.Rows.RemoveAt(i);

                // Step UN3: "Name (login)" (" (inactive)" added), sorted by name, then login; the value stays UserId
                Common.LoadDropdownlist(ddlLoginUser, UserMgr.WithUserDisplayName(dtUser), UserMgr.UserDisplayNameColumn, "UserId", true);
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
            }
            else
            {
                pnlResetPassword.Visible = true;

                int UserId = Convert.ToInt16(ddlLoginUser.SelectedValue);

                DataTable dtUser = new DataTable();
                dtUser = UserMgr.GetUserDataTableByUserId(UserId);

                ltrlUserDetails.Text = Common.LoadUserDetails(dtUser);
            }
        }
        #endregion

        #region btnResetPassword_Click
        protected void btnResetPassword_Click(object sender, EventArgs e)
        {
            // Step RA1a: checked again before the action
            BMMS.Security.PageAccessModule.RequireRole("admin");

            int PasswordLength = 8; // Convert.ToInt16(Common.GetAppSetting("PasswordMaxLength"));
            string NewPassword = Common.DefaultPassword; // Common.CreateRandomPassword(PasswordLength);

            string Subject = "Your password has been reset to default password";
            string BodyText = "Your password has been reset to default password. <br />";
            BodyText += "Please change your password after login.";

            string result = string.Empty;
            string errMsg = string.Empty;

            int UserId = Convert.ToInt16(ddlLoginUser.SelectedValue);
            // Acting user: the server-side session only
            int UpdatedBy = Session["UserId"] == null ? 0 : Convert.ToInt16(Session["UserId"].ToString());

            // Check the rule, reset, and only then send the mail
            UserChangeResult check = UserMgr.CheckUserChange(UpdatedBy, UserId, "ResetPassword", 0);

            if (check.Result != 1)
            {
                errMsg = check.RefusalMessage("reset this user's password", className);
            }
            else if (UserMgr.ResetPasswordByUserId(UserId, Common.HashPassword(NewPassword), UpdatedBy) != 1)
            {
                errMsg = "The password was not reset. Please try again.";
            }
            else
            {
                // Step IU1 (BMMS-Fix-InactiveUsers-Step55.sql): the address and the status of the chosen user come from
                // the database, under the rule of the reset itself; nothing the page holds is used for the mail
                int mailReason;
                string ToMailId;
                bool isActive;

                if (!UserMgr.GetResetPasswordMail(UpdatedBy, UserId, out mailReason, out ToMailId, out isActive))
                {
                    Utilities.WriteErrorLog(className, "btnResetPassword_Click", "spr_GetResetPasswordMail refused after the reset: Reason " + mailReason);
                    errMsg = MailNotSentMessage;
                }
                else if (!isActive)
                {
                    // An inactive user receives no mail (BMMS-Fix-UserStatus-Stage2b.sql)
                    errMsg = InactiveNoMailMessage;
                }
                else
                {
                    // Step ML2c: ToRequired: the mail is for this user; without a valid To address it fails (no Bcc-only mail)
                    result = Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, null, true);

                    if (result == "Success")
                        errMsg = "New passward was sent through mail.";
                    else
                        errMsg = MailNotSentMessage;   // step M1
                }
            }

            MsgDisplay(errMsg, (errMsg == "New passward was sent through mail." || errMsg == InactiveNoMailMessage) ? MessageKind.Success
                    : errMsg == "The password was not reset. Please try again." ? MessageKind.Error : MessageKind.Warning);
            pnlResetPassword.Visible = false;
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
