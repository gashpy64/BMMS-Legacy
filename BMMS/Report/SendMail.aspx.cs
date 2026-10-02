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
using iTextSharp.text;
using iTextSharp.text.pdf;
using System.IO;

namespace BMMS.Report
{
    public partial class SendMail : System.Web.UI.Page
    {
        private string className = "SendMail";
        private string fPath = string.Empty;

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);
            InitCtrlAttributes();
            
            fPath = Server.MapPath("~/Files/Temp/");

            if (!IsPostBack)
            {
                aAttachment.Visible = false;
                MsgHide();
                LoadCommittee();
            }
        }
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            FileUploadAttachment.Attributes.Add("onchange", "javascript:return UploadClick('" + btnAddAttachment.ClientID + "')");
        }
        #endregion

        #region btnSendMail_Click
        protected void btnSendMail_Click(object sender, EventArgs e)
        {
            MsgHide();

            string result = CreateBodyText();
            if (result == "Success")
                MsgDisplay("Mail was sent to all members.");
            else
                MsgDisplay(result);
        }
        #endregion

        #region CreateBodyText
        private string CreateBodyText()
        {
            string ToMailId = txtToMailId.Text.Trim();

            string BodyText = ftxtBodyText.Xhtml.Trim();

            string Subject = txtSubject.Text.Trim();

            string AttachFileName = txtAttachmentPath.Text.Trim();

            if (aAttachment.Visible == true)
                return Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, fPath + AttachFileName, null);
            else
                return Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, null);

        }
        #endregion

        #region btnAttachment_Click
        protected void btnAttachment_Click(object sender, EventArgs e)
        {
            MsgHide();

            if (FileUploadAttachment.HasFile)
            {
                string tempPath = Server.MapPath("~/Files/Temp/");

                try
                {
                    Array.ForEach(Directory.GetFiles(tempPath),
                      delegate(string path) { File.Delete(path); });
                }
                catch (Exception ex)
                {
                }

                string fName = string.Empty;
                string fNameWithPath = string.Empty;

                fName = FileUploadAttachment.FileName;
                fNameWithPath = fPath + fName;

                FileUploadAttachment.SaveAs(fNameWithPath);

                aAttachment.Attributes.Add("href", "../Files/Temp/" + fName);
                txtAttachmentPath.Text = fName;

                aAttachment.Visible = true;

            }

        }
        #endregion

        #region LoadMeeting
        public void LoadMeeting(int CommitteeId)
        {
            DataTable dtMeeting = new DataTable();
            dtMeeting = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);

            Common.LoadDropdownlist(ddlMeeting, dtMeeting, "MeetingNo", "MeetingId", true);
        }
        #endregion

        #region LoadCommittee
        public void LoadCommittee()
        {
            DataTable dtCommittee = new DataTable();
            dtCommittee = CommitteeMgr.GetCommitteeList(1);

            Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();
            if (ddlCommittee.SelectedIndex <= 0)
            {
                ddlMeeting.Items.Clear();
            }
            if (ddlCommittee.SelectedIndex > 0)
            {
                LoadMeeting(Convert.ToInt32(ddlCommittee.SelectedValue));
            }
        }
        #endregion

        #region ddlMeeting_SelectedIndexChanged
        protected void ddlMeeting_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);
            int MeetingId = int.Parse(ddlMeeting.SelectedValue);

            string ToMailId = string.Empty;

            if (ddlMeeting.SelectedIndex > 0)
                ToMailId = Common.GetCommitteeMemberMailId(CommitteeId, MeetingId);

            txtToMailId.Text = ToMailId.ToString();
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
