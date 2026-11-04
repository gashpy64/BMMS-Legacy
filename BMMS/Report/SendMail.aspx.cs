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
using BMMS.Controls;
using BMMSBAL;
using iTextSharp.text;
using iTextSharp.text.pdf;
using System.IO;

namespace BMMS.Report
{
    public partial class SendMail : System.Web.UI.Page
    {
        private string className = "SendMail";

        // The attachment of this mail is one plain file ~/Files/Temp/<id>_<file name> (step SM1); Send Mail creates
        // and deletes no folder. The id (a Guid) and the file name live in ViewState, which the browser cannot change.
        private const string TempFolder = "~/Files/Temp/";
        private const string AttachIdKey = "SendMailAttachId";
        private const string AttachNameKey = "SendMailAttachName";
        private const string KeepFileName = ".gitkeep";
        private static readonly TimeSpan SweepAge = TimeSpan.FromHours(24);

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);
            InitCtrlAttributes();

            // Step A3: the editor keeps the posted body itself (cleaned by the control), so nothing is copied here

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

            // Step A3: rich text over the limit (Web.config): nothing is sent, the typed text stays
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            string ToMailId = txtToMailId.Text.Trim();

            // The addresses by the rule the mail uses (comma or semicolon); nothing is sent while one is not valid
            int ValidCount;
            string InvalidMailId = Mail_Mgr.FindInvalidMailAddress(ToMailId, out ValidCount);
            if (InvalidMailId != null)
            {
                MsgDisplay("This mail address is not valid: " + HttpUtility.HtmlEncode(InvalidMailId) + ". Correct it and send again.");
                return;
            }
            if (ValidCount == 0)
            {
                MsgDisplay("Enter at least one mail address in To.");
                return;
            }

            string AttachFile = null;
            string AttachName = null;
            if (ViewState[AttachIdKey] != null)
            {
                AttachFile = AttachmentFile();
                AttachName = AttachmentName();
                if (AttachFile == null || !File.Exists(AttachFile))
                {
                    ClearAttachment();
                    MsgDisplay("The attachment is no longer on the server. Attach the file again.");
                    return;
                }
            }

            // Mail_Mgr writes the error to the error log; the page shows a fixed text
            string result = CreateBodyText(ToMailId, AttachFile, AttachName);
            if (result == "Success")
            {
                ClearAttachment();
                ClearMail();
                MsgDisplay("The mail was sent.", MessageKind.Success);
            }
            else
                MsgDisplay("The mail could not be sent. The error is in the error log.", MessageKind.Error);   // the attachment is kept for a new try
        }
        #endregion

        #region CreateBodyText
        private string CreateBodyText(string ToMailId, string AttachFile, string AttachName)
        {
            // The typed mail body cleaned to the rich-text allow-list (step A1a)
            string BodyText = HtmlCleaner.Clean(ftxtBodyText.Text.Trim());

            string Subject = txtSubject.Text.Trim();

            // The mail attachment carries the clean name, not the stored <id>_<name>
            return Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, AttachFile, AttachName, null);
        }
        #endregion

        #region btnAttachment_Click
        protected void btnAttachment_Click(object sender, EventArgs e)
        {
            MsgHide();

            // Step A3: this post carries the body too; over the limit no file is stored and the typed text stays
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            // HasFile is false when no file arrived or the file is empty
            if (!FileUploadAttachment.HasFile)
            {
                MsgDisplay("The file is empty or was not received. Choose the file again.");
                return;
            }

            SweepTempFolder();

            string fName = SafeFileName.Clean(FileUploadAttachment.FileName);   // safe name (step N1)
            Guid AttachId = Guid.NewGuid();
            string NewFile = StoredFile(AttachId, fName);

            try
            {
                FileUploadAttachment.SaveAs(NewFile);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "btnAttachment_Click", ex.ToString());
                DeleteFile(NewFile);
                // The earlier attachment of this mail, if any, stays
                MsgDisplay("The file could not be attached. The error is in the error log.", MessageKind.Error);
                return;
            }

            // A new file replaces the earlier attachment of this mail
            DeleteFile(AttachmentFile());

            ViewState[AttachIdKey] = AttachId.ToString("N");
            ViewState[AttachNameKey] = fName;

            aAttachment.Attributes["href"] = "../Files/Temp/" + Uri.EscapeDataString(Path.GetFileName(NewFile));
            aAttachment.Visible = true;
            lblAttachmentName.Text = HttpUtility.HtmlEncode(fName);
        }
        #endregion

        #region StoredFile
        // ~/Files/Temp/<id>_<name>: a plain file, no folder of its own
        private string StoredFile(Guid AttachId, string Name)
        {
            return Path.Combine(Server.MapPath(TempFolder), AttachId.ToString("N") + "_" + Path.GetFileName(Name));
        }
        #endregion

        #region AttachmentName
        // The clean name of this mail's attachment, or null; reduced to a file name again
        private string AttachmentName()
        {
            string Name = Path.GetFileName((ViewState[AttachNameKey] as string) ?? string.Empty);
            return Name == string.Empty ? null : Name;
        }
        #endregion

        #region AttachmentFile
        // The full name of this mail's attachment, or null. The id from ViewState is used only when it is a Guid.
        private string AttachmentFile()
        {
            Guid AttachId;
            string Value = ViewState[AttachIdKey] as string;
            string Name = AttachmentName();

            if (Value == null || Name == null || !Guid.TryParse(Value, out AttachId))
                return null;

            return StoredFile(AttachId, Name);
        }
        #endregion

        #region ClearAttachment
        // Deletes this mail's attachment file and hides the View link and the name
        private void ClearAttachment()
        {
            DeleteFile(AttachmentFile());

            ViewState.Remove(AttachIdKey);
            ViewState.Remove(AttachNameKey);

            aAttachment.Attributes.Remove("href");
            aAttachment.Visible = false;
            lblAttachmentName.Text = string.Empty;
        }
        #endregion

        #region ClearMail
        // The page is ready for the next mail; the meetings are not loaded again
        private void ClearMail()
        {
            if (ddlCommittee.Items.Count > 0)
                ddlCommittee.SelectedIndex = 0;
            ddlMeeting.Items.Clear();

            txtToMailId.Text = string.Empty;
            txtSubject.Text = string.Empty;
            ftxtBodyText.Text = string.Empty;
        }
        #endregion

        #region DeleteFile
        // Deletes one file in ~/Files/Temp, never a folder: deleting a folder inside the application folder
        // restarts the application and loses the sessions. A failure is written to the error log and never
        // stops the mail; what stays behind is removed by SweepTempFolder after 24 hours.
        private void DeleteFile(string FileName)
        {
            if (FileName == null)
                return;

            try
            {
                if (File.Exists(FileName))
                    File.Delete(FileName);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "DeleteAttachment", ex.ToString());
            }
        }
        #endregion

        #region SweepTempFolder
        // Removes the files that mails left at the top of ~/Files/Temp more than 24 hours ago (creation and last
        // write both older). The .gitkeep file, folders and anything younger are never touched, so a mail being
        // written keeps its attachment.
        private void SweepTempFolder()
        {
            DateTime Before = DateTime.Now - SweepAge;
            string Root = Server.MapPath(TempFolder);

            try
            {
                if (!Directory.Exists(Root))
                    return;

                foreach (string FileName in Directory.GetFiles(Root))
                {
                    if (string.Equals(Path.GetFileName(FileName), KeepFileName, StringComparison.OrdinalIgnoreCase))
                        continue;

                    if (File.GetCreationTime(FileName) < Before && File.GetLastWriteTime(FileName) < Before)
                        DeleteFile(FileName);
                }
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "SweepTempFolder", ex.ToString());
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
