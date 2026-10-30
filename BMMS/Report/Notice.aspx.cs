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
    public partial class Notice : System.Web.UI.Page
    {
        private string className = "Notice";

        // The look of the outcome CreateBodyText returns (step B3): Success when every member with an address
        // got the notice, Warning when some have no address or some mails failed, Error when none was sent
        private MessageKind noticeKind = MessageKind.Warning;

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                LoadCommittee();
            }
        }

        #region btnSendMail_Click
        protected void btnSendMail_Click(object sender, EventArgs e)
        {
            MsgHide();

            // Never silent (step 28): the click is an UpdatePanel postback, so an error would otherwise
            // show nothing and leave no log entry
            try
            {
                string result = CreateBodyText();

                if (result != string.Empty)
                    MsgDisplay(result, noticeKind);
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.WriteErrorLog(className, "btnSendMail_Click", ex.ToString());
                MsgDisplay("The notice could not be sent: " + HttpUtility.HtmlEncode(ex.Message), MessageKind.Error);
            }
        }
        #endregion

        #region CreateBodyText
        // Sends the notice to each member with an e-mail address and returns the outcome for the page;
        // string.Empty when the meeting has no members (the alert says so) (step 28)
        private string CreateBodyText()
        {
            string result = string.Empty;

            int MeetingId = int.Parse(ddlMeeting.SelectedValue);
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            DataTable dtMeeting = new DataTable();
            dtMeeting = (DataTable)ViewState["dtMeeting"];

            // The same members as the printed notice (Create PDF): on the committee on the meeting date, or with
            // attendance (BMMS-Fix-MeetingLocks-Step16.sql), with address, city and state (View_Member) (step 28)
            DataTable dtCommitteeMember = new DataTable();
            dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByMeetingId(MeetingId);

            DataTable dtCompanySecretary = UserMgr.GetCompanySecretary(MeetingId);
            string CompanySecretary = string.Empty;
            string CompanySecretaryDesign = string.Empty;

            if (dtCompanySecretary.Rows.Count > 0)
            {
                CompanySecretary = dtCompanySecretary.Rows[0]["CompanySecretary"].ToString();
                CompanySecretaryDesign = dtCompanySecretary.Rows[0]["DesignationName"].ToString();
            }

            if (dtCommitteeMember.Rows.Count <= 0)
            {
                ScriptManager.RegisterStartupScript(this, this.GetType(), "msg", "alert('No Committee-Member or Meeting-Members Available');", true);
                ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
            }
            else
            {
                try
                {
                    CommitteeBAL commiteeBal = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);
                    bool IsBoard = false;
                    if (commiteeBal.Board == 1)
                        IsBoard = true;

                    // The procedure already leaves out members not on the committee on the meeting date, so there
                    // is no cessation check here; each send is counted for the page (step 28)
                    int membersWithMail = 0;
                    int sent = 0;
                    int failed = 0;
                    System.Collections.Generic.List<string> noMail = new System.Collections.Generic.List<string>();

                    for (int i = 0; i < dtCommitteeMember.Rows.Count; i++)
                    {
                        string ToMailId = dtCommitteeMember.Rows[i]["EmailId"].ToString().Trim();

                        if (ToMailId == string.Empty)
                            noMail.Add(dtCommitteeMember.Rows[i]["MemberName"].ToString());

                        if (ToMailId != string.Empty)
                        {
                            membersWithMail += 1;

                            string BodyText = string.Empty;


                            //pdfDocument.Add((PDFUtilities.PrintCompanyLogo()));

                            BodyText += "<table>";

                            BodyText += OrganisationDetails.Current.MailHeaderRowHtml();

                            BodyText += "<tr>";
                            BodyText += "<td colspan='2' style='text-align:right'>";
                            BodyText += "Date : " + System.DateTime.Now.ToString("dd-MMM-yyyy");
                            BodyText += "</td>";
                            BodyText += "</tr>";

                            BodyText += "<tr>";
                            BodyText += "<td colspan='2' style='text-align:left'>";
                            BodyText += "To <br />";
                            BodyText += "<br />";
                            BodyText += HttpUtility.HtmlEncode(dtCommitteeMember.Rows[i]["MemberName"].ToString()) + " <br />";
                            if (dtCommitteeMember.Rows[i]["Address1"].ToString().Trim() != string.Empty)
                                BodyText += HttpUtility.HtmlEncode(dtCommitteeMember.Rows[i]["Address1"].ToString()) + " <br />";
                            if (dtCommitteeMember.Rows[i]["Address2"].ToString().Trim() != string.Empty)
                                BodyText += HttpUtility.HtmlEncode(dtCommitteeMember.Rows[i]["Address2"].ToString()) + " <br />";
                            if (dtCommitteeMember.Rows[i]["Address3"].ToString().Trim() != string.Empty)
                                BodyText += HttpUtility.HtmlEncode(dtCommitteeMember.Rows[i]["Address3"].ToString()) + " <br />";
                            if (dtCommitteeMember.Rows[i]["CityName"].ToString().Trim() != string.Empty)
                                BodyText += HttpUtility.HtmlEncode(dtCommitteeMember.Rows[i]["CityName"].ToString()) + " <br />";
                            if (dtCommitteeMember.Rows[i]["State_Name"].ToString().Trim() != string.Empty)
                                BodyText += HttpUtility.HtmlEncode(dtCommitteeMember.Rows[i]["State_Name"].ToString()) + " <br />";
                            BodyText += "<br /><br />";
                            BodyText += "Dear Sir/Madam,<br />";
                            BodyText += "<br /><br />";

                            BodyText += "<b>Subject : Notice of Next Meeting of the " + HttpUtility.HtmlEncode(dtMeeting.Rows[0]["CommitteeName"].ToString());

                            BodyText += "</b><br />";

                            BodyText += "<br />";
                            BodyText += "The next meeting of the " + HttpUtility.HtmlEncode(dtMeeting.Rows[0]["CommitteeName"].ToString()) +
                                " is scheduled to be held on " + Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy") +
                                " at " + HttpUtility.HtmlEncode(dtMeeting.Rows[0]["MeetingTime"].ToString()) + " Hrs. at " + HttpUtility.HtmlEncode(dtMeeting.Rows[0]["Venue"].ToString()) + "<br />";
                            BodyText += "<br />";
                            BodyText += "The Agenda Note will be sent to you in due course.<br />";
                            BodyText += "<br />";
                            BodyText += "You are requested to kindly make it convenient to attend the above meeting.<br />";
                            BodyText += "<br />";
                            BodyText += "<br />";
                            BodyText += "Thanking You,<br />";
                            BodyText += "<br />";
                            BodyText += "Yours faithfully,<br />";
                            BodyText += "<br />";
                            BodyText += "<br />";
                            BodyText += "<br />";

                            if (CompanySecretary != string.Empty)
                            {
                                BodyText += "<b>(" + HttpUtility.HtmlEncode(CompanySecretary) + ")</b><br />";
                                BodyText += "<b>" + HttpUtility.HtmlEncode(CompanySecretaryDesign) + "</b>";
                            }
                            else
                            {
                                BodyText += "<b>Authorized Signatory</b>";
                            }

                            BodyText += "<br />";
                            BodyText += "</td>";
                            BodyText += "</tr>";
                            BodyText += "</table>";


                            string Subject = "Notice of Next Meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString();

                            // "Success", or "Error: ..." already written to the error log by Mail_Mgr
                            if (Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, null) == "Success")
                                sent += 1;
                            else
                                failed += 1;
                        }
                    }

                    result = "Notice sent to " + sent + " of " + membersWithMail + " members.";

                    if (noMail.Count > 0)
                        result += " " + noMail.Count + " member(s) have no e-mail address: "
                                + HttpUtility.HtmlEncode(string.Join(", ", noMail.ToArray())) + ".";

                    if (failed > 0)
                        result += " " + failed + " mail(s) could not be sent; see the error log.";

                    if (failed > 0 && sent == 0)
                        noticeKind = MessageKind.Error;
                    else if (failed > 0 || noMail.Count > 0)
                        noticeKind = MessageKind.Warning;
                    else
                        noticeKind = MessageKind.Success;
                }
                catch (Exception ex)
                {
                    throw ex;
                }
                finally
                {

                }
            }
            //System.Diagnostics.Process.Start(sFilePDF);

            return result;
        }
        #endregion

        #region btnCreatePDF_Click
        protected void btnCreatePDF_Click(object sender, EventArgs e)
        {
            // Built in memory and opened by ViewReport.aspx?pdf=1; nothing is written to ~/Files/PDF (step 26).
            // Two pop-ups of the same user at once: the last one built wins.
            MsgHide();
            byte[] pdf = CreatePDF();

            if (pdf != null)
            {
                Session["ReportPdf"] = pdf;
                Session["ReportPdfName"] = "Notice";
                ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(825,500,'ViewReport.aspx?pdf=1','Notice');", true);
                pnlNoticeDownload.Visible = true;
            }
        }
        #endregion

        #region CreatePDF
        // The notice letters as PDF bytes; null when the meeting has no members (step 26)
        private byte[] CreatePDF()
        {
            int MeetingId = int.Parse(ddlMeeting.SelectedValue);
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            Document pdfDocument = new Document();
            MemoryStream pdfStream = new MemoryStream();
            byte[] pdf = null;

            DataTable dtMeeting = new DataTable();
            dtMeeting = (DataTable)ViewState["dtMeeting"];

            DataTable dtCommitteeMember = new DataTable();
            dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByMeetingId(MeetingId); // MeetingMgr.GetMeetingFullMember(MeetingId, CommitteeId);

            DataTable dtCompanySecretary = UserMgr.GetCompanySecretary(MeetingId);
            string CompanySecretary = string.Empty;
            string CompanySecretaryDesign = string.Empty;

            if (dtCompanySecretary.Rows.Count > 0)
            {
                CompanySecretary = dtCompanySecretary.Rows[0]["CompanySecretary"].ToString();
                CompanySecretaryDesign = dtCompanySecretary.Rows[0]["DesignationName"].ToString();
            }

            if (dtCommitteeMember.Rows.Count <= 0)
            {
                ScriptManager.RegisterStartupScript(this, this.GetType(), "msg", "alert('No Committee-Member or Meeting-Members Available');", true);
                ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
            }
            else if (PdfFonts.HasIndicText(dtCommitteeMember, "MemberName", "Address1", "Address2", "Address3", "CityName", "State_Name")
                || PdfFonts.HasIndicText(dtMeeting, "CommitteeName", "MeetingTime", "Venue")
                || PdfFonts.HasIndicText(CompanySecretary, CompanySecretaryDesign) || PdfFonts.OrganisationHasIndicText())
            {
                // Tamil or Hindi text: no PDF; the notice by Send Mail shows it (step U1b)
                MsgDisplay(PdfFonts.IndicTextMessageFor("use Send Mail"));
            }
            //else if (CompanySecretary == string.Empty)
            //{
            //    ScriptManager.RegisterStartupScript(this, this.GetType(), "msg", "alert('No such `In Attendance` meeting member tagging record for this meeting.');", true);
            //    ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
            //}
            else
            {
                try
                {
                    PdfWriter writer = PdfWriter.GetInstance(pdfDocument, pdfStream);
                    pdfDocument.Open();
                    pdfDocument.SetMargins(45f, 45f, 60f, 60f);

                    CommitteeBAL commiteeBal = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);
                    bool IsBoard = false;
                    if (commiteeBal.Board == 1)
                        IsBoard = true;

                    for (int i = 0; i < dtCommitteeMember.Rows.Count; i++)
                    {
                        Paragraph paragraph = PdfFonts.Paragraph(" ");
                        pdfDocument.Add(paragraph);

                        PDFUtilities.AddCompanyLogo(pdfDocument);

                        Paragraph para = PdfFonts.Paragraph(OrganisationDetails.Current.OfficeLineUpper);
                        para.Alignment = Element.ALIGN_CENTER;
                        if (OrganisationDetails.Current.OfficeLineUpper != string.Empty)
                            pdfDocument.Add(para);

                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));

                        para = PdfFonts.Paragraph("Date : " + System.DateTime.Now.ToString("dd-MMM-yyyy"));
                        para.Alignment = Element.ALIGN_RIGHT;
                        pdfDocument.Add(para);

                        pdfDocument.Add(PdfFonts.Paragraph("To"));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(PdfFonts.Paragraph(dtCommitteeMember.Rows[i]["MemberName"].ToString()));
                        pdfDocument.Add(PdfFonts.Paragraph(dtCommitteeMember.Rows[i]["Address1"].ToString()));
                        pdfDocument.Add(PdfFonts.Paragraph(dtCommitteeMember.Rows[i]["Address2"].ToString()));
                        pdfDocument.Add(PdfFonts.Paragraph(dtCommitteeMember.Rows[i]["Address3"].ToString()));
                        pdfDocument.Add(PdfFonts.Paragraph(dtCommitteeMember.Rows[i]["CityName"].ToString()));
                        pdfDocument.Add(PdfFonts.Paragraph(dtCommitteeMember.Rows[i]["State_Name"].ToString()));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(PdfFonts.Paragraph("Dear Sir/Madam,"));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));

                        string strSubject = string.Empty;
                        strSubject = "Subject : Notice of Next Meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString();

                        pdfDocument.Add(PdfFonts.Paragraph(strSubject));

                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        //string test = dtMeeting.Rows[0]["Venue"].ToString();
                        //string tes1t = dtMeeting.Rows[0]["Venue"].ToString().Replace("\n", " ");
                        pdfDocument.Add(PdfFonts.Paragraph("The next meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString() +
                            " is scheduled to be held on " + Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy") +
                            " at " + dtMeeting.Rows[0]["MeetingTime"].ToString() + " Hrs. at " + dtMeeting.Rows[0]["Venue"].ToString().Replace("\n", " ")));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(PdfFonts.Paragraph("The Agenda Note will be sent to you in due course."));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(PdfFonts.Paragraph("You are requested to kindly make it convenient to attend the above meeting."));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(PdfFonts.Paragraph("Thanking You,"));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(PdfFonts.Paragraph("Yours faithfully,"));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));

                        if (CompanySecretary != string.Empty)
                        {
                            pdfDocument.Add(PdfFonts.Paragraph("(" + CompanySecretary + ")"));
                            pdfDocument.Add(PdfFonts.Paragraph(CompanySecretaryDesign));
                        }
                        else
                        {
                            pdfDocument.Add(PdfFonts.Paragraph("Authorized Signatory"));
                        }

                        pdfDocument.Add(PdfFonts.Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph());
                        pdfDocument.Add(PdfFonts.Paragraph(""));
                        pdfDocument.Add(PdfFonts.Paragraph(""));
                        pdfDocument.NewPage();
                    }
                }
                catch (Exception ex)
                {
                    throw ex;
                }
                finally
                {
                    pdfDocument.Close();
                }

                pdf = pdfStream.ToArray();
            }

            return pdf;
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
                pnlNoticeDownload.Visible = false;
                pnlNoticeDetails.Visible = false;
            }
            if (ddlCommittee.SelectedIndex > 0)
            {
                LoadMeeting(Convert.ToInt32(ddlCommittee.SelectedValue));
                pnlNoticeDetails.Visible = false;
                pnlNoticeDownload.Visible = false;
            }
        }
        #endregion

        #region ddlMeeting_SelectedIndexChanged
        protected void ddlMeeting_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();
            pnlNoticeDetails.Visible = false;
            pnlNoticeDownload.Visible = false;
            if (ddlMeeting.SelectedIndex > 0)
            {
                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByMeetingId(int.Parse(ddlMeeting.SelectedValue));

                pnlNoticeDetails.Visible = true;
                pnlNoticeDownload.Visible = false;

                ViewState["dtMeeting"] = dtMeeting;

                txtMeetingVenue.Text = dtMeeting.Rows[0]["Venue"].ToString();
                txtMeetingDate.Text = Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy");
                txtMeetingTime.Text = dtMeeting.Rows[0]["MeetingTime"].ToString();

            }
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
