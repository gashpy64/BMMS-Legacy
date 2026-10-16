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
    public partial class SMTPServerConfig : System.Web.UI.Page
    {
        private string className = "SMTPServerConfig";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                InitCtrlAttributes();
                DefaultSetting();
                MsgHide();

            }
        }
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnUpdate.Attributes.Add("onclick", "return SMTPServerConfigValidation()");
        }
        #endregion

        #region DefaultSetting
        private void DefaultSetting()
        {
            txtPassword.Visible = false;
            txtPasswordDisplay.Visible = true;

            LoadSMTPMaster();

            txtSMTPServer.Enabled = false;
            txtSMTPServerPort.Enabled = false;
            txtUserName.Enabled = false;
            txtPasswordDisplay.Enabled = false;
            txtFromMailId.Enabled = false;
            txtBcc.Enabled = false;

            btnEdit.Visible = true;
            btnUpdate.Visible = false;
            btnCancel.Visible = false;
        }
        #endregion

        #region LoadSMTPMaster
        private void LoadSMTPMaster()
        {
            DataTable dtSMTPMaster = Utilities.GetSMTPMaster();

            txtSMTPServer.Text = dtSMTPMaster.Rows[0]["SMTPServer"].ToString();
            txtSMTPServerPort.Text = dtSMTPMaster.Rows[0]["SMTPServerPort"].ToString();
            txtUserName.Text = dtSMTPMaster.Rows[0]["UserName"].ToString();
            txtFromMailId.Text = dtSMTPMaster.Rows[0]["FromMailId"].ToString();
            txtBcc.Text = dtSMTPMaster.Rows[0]["Bcc"].ToString();

        }
        #endregion

        #region btnEdit_Click
        protected void btnEdit_Click(object sender, EventArgs e)
        {
            MsgHide();

            txtSMTPServer.Enabled = true;
            txtSMTPServerPort.Enabled = true;
            txtUserName.Enabled = true;
            txtPasswordDisplay.Visible = false;
            txtPassword.Visible = true;
            txtFromMailId.Enabled = true;
            txtBcc.Enabled = true;

            LoadSMTPMaster();

            btnEdit.Visible = false;
            btnUpdate.Visible = true;
            btnCancel.Visible = true;

            ScriptManager.GetCurrent(this).SetFocus(txtSMTPServer.ClientID);
        }
        #endregion

        #region btnUpdate_Click
        protected void btnUpdate_Click(object sender, EventArgs e)
        {
            string SMTPServer = txtSMTPServer.Text.Trim();
            string SMTPServerPort = txtSMTPServerPort.Text.Trim();
            string UserName = txtUserName.Text.Trim();
            string Password = Common.ProtectSecret(txtPassword.Text.Trim());
            string FromMailId = txtFromMailId.Text.Trim();
            string Bcc = txtBcc.Text.Trim();

            Utilities.UpdateSMTPMaster(SMTPServer, SMTPServerPort,
                UserName, Password, FromMailId, Bcc);

            DefaultSetting();
            MsgDisplay("Successfully updated.");
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            DefaultSetting();
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
