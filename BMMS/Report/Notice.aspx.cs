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
            CreateBodyText();
            MsgDisplay("Mail was sent to all members.");
        }
        #endregion

        #region CreateBodyText
        private void CreateBodyText()
        {
            int MeetingId = int.Parse(ddlMeeting.SelectedValue);
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            DataTable dtMeeting = new DataTable();
            dtMeeting = (DataTable)ViewState["dtMeeting"];

            DataTable dtCommitteeMember = new DataTable();
            dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByCommitteeId(CommitteeId, MeetingId);

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

                    bool IsMailSend = true;

                    for (int i = 0; i < dtCommitteeMember.Rows.Count; i++)
                    {
                        if (dtCommitteeMember.Rows[i]["CessationDate"].ToString().Trim() != string.Empty)
                        {
                            try
                            {
                                DateTime CessationDate = Convert.ToDateTime(dtCommitteeMember.Rows[i]["CessationDate"].ToString());
                                if (CessationDate <= System.DateTime.Now)
                                {
                                    IsMailSend = false;
                                }
                            }
                            catch (Exception ex)
                            {
                                IsMailSend = false;
                            }
                        }

                        if (IsMailSend)
                        {
                            string BodyText = string.Empty;


                            //pdfDocument.Add((PDFUtilities.PrintCompanyLogo()));

                            BodyText += "<table>";

                            BodyText += "<tr>";
                            BodyText += "<td colspan='2' style='text-align:center; font-weight:bold;'>";
                            BodyText += "LAKSHMI VILAS BANK <br />";
                            BodyText += "REGD & ADMIN OFFICE, KARUR";
                            BodyText += "</td>";
                            BodyText += "</tr>";

                            BodyText += "<tr>";
                            BodyText += "<td colspan='2' style='text-align:right'>";
                            BodyText += "Date : " + System.DateTime.Now.ToString("dd-MMM-yyyy");
                            BodyText += "</td>";
                            BodyText += "</tr>";

                            BodyText += "<tr>";
                            BodyText += "<td colspan='2' style='text-align:left'>";
                            BodyText += "To <br />";
                            BodyText += "<br />";
                            BodyText += dtCommitteeMember.Rows[i]["MemberName"].ToString() + " <br />";
                            if (dtCommitteeMember.Rows[i]["Address1"].ToString().Trim() != string.Empty)
                                BodyText += dtCommitteeMember.Rows[i]["Address1"].ToString() + " <br />";
                            if (dtCommitteeMember.Rows[i]["Address2"].ToString().Trim() != string.Empty)
                                BodyText += dtCommitteeMember.Rows[i]["Address2"].ToString() + " <br />";
                            if (dtCommitteeMember.Rows[i]["Address3"].ToString().Trim() != string.Empty)
                                BodyText += dtCommitteeMember.Rows[i]["Address3"].ToString() + " <br />";
                            if (dtCommitteeMember.Rows[i]["CityName"].ToString().Trim() != string.Empty)
                                BodyText += dtCommitteeMember.Rows[i]["CityName"].ToString() + " <br />";
                            if (dtCommitteeMember.Rows[i]["State_Name"].ToString().Trim() != string.Empty)
                                BodyText += dtCommitteeMember.Rows[i]["State_Name"].ToString() + " <br />";
                            BodyText += "<br /><br />";
                            BodyText += "Dear Sir/Madam,<br />";
                            BodyText += "<br /><br />";

                            BodyText += "<b>Subject : Notice of Next Meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString();

                            BodyText += "</b><br />";

                            BodyText += "<br />";
                            BodyText += "The next meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString() +
                                " is scheduled to be held on " + Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy") +
                                " at " + dtMeeting.Rows[0]["MeetingTime"].ToString() + " Hrs. at " + dtMeeting.Rows[0]["Venue"].ToString() + "<br />";
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
                                BodyText += "<b>(" + CompanySecretary + ")</b><br />";
                                BodyText += "<b>" + CompanySecretaryDesign + "</b>";
                            }
                            else
                            {
                                BodyText += "<b>Authorized Signatory</b>";
                            }

                            BodyText += "<br />";
                            BodyText += "</td>";
                            BodyText += "</tr>";
                            BodyText += "</table>";


                            string ToMailId = dtCommitteeMember.Rows[i]["EmailId"].ToString();
                            string Subject = "Notice of Next Meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString();
                            Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, null);

                            
                        }
                    }

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
        }
        #endregion

        #region btnCreatePDF_Click
        protected void btnCreatePDF_Click(object sender, EventArgs e)
        {
            CreatePDF();
        }
        #endregion

        #region CreatePDF
        private void CreatePDF()
        {
            int MeetingId = int.Parse(ddlMeeting.SelectedValue);
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            Document pdfDocument = new Document();
            string sFilePDF = Server.MapPath("~/Files/PDF") + "\\Notice.pdf";

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
            //else if (CompanySecretary == string.Empty)
            //{
            //    ScriptManager.RegisterStartupScript(this, this.GetType(), "msg", "alert('No such `In Attendance` meeting member tagging record for this meeting.');", true);
            //    ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
            //}
            else
            {
                try
                {
                    PdfWriter writer = PdfWriter.GetInstance(pdfDocument,
                                                 new FileStream(sFilePDF, FileMode.Create));
                    pdfDocument.Open();
                    pdfDocument.SetMargins(45f, 45f, 60f, 60f);

                    CommitteeBAL commiteeBal = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);
                    bool IsBoard = false;
                    if (commiteeBal.Board == 1)
                        IsBoard = true;

                    for (int i = 0; i < dtCommitteeMember.Rows.Count; i++)
                    {
                        Paragraph paragraph = new Paragraph(" ");
                        pdfDocument.Add(paragraph);

                        pdfDocument.Add((PDFUtilities.PrintCompanyLogo()));

                        Paragraph para = new Paragraph("REGD & ADMIN OFFICE, KARUR");
                        para.Alignment = Element.ALIGN_CENTER;
                        pdfDocument.Add(para);

                        pdfDocument.Add(new Paragraph(Environment.NewLine));

                        para = new Paragraph("Date : " + System.DateTime.Now.ToString("dd-MMM-yyyy"));
                        para.Alignment = Element.ALIGN_RIGHT;
                        pdfDocument.Add(para);

                        pdfDocument.Add(new Paragraph("To"));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph(dtCommitteeMember.Rows[i]["MemberName"].ToString()));
                        pdfDocument.Add(new Paragraph(dtCommitteeMember.Rows[i]["Address1"].ToString()));
                        pdfDocument.Add(new Paragraph(dtCommitteeMember.Rows[i]["Address2"].ToString()));
                        pdfDocument.Add(new Paragraph(dtCommitteeMember.Rows[i]["Address3"].ToString()));
                        pdfDocument.Add(new Paragraph(dtCommitteeMember.Rows[i]["CityName"].ToString()));
                        pdfDocument.Add(new Paragraph(dtCommitteeMember.Rows[i]["State_Name"].ToString()));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph("Dear Sir/Madam,"));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));

                        string strSubject = string.Empty;
                        strSubject = "Subject : Notice of Next Meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString();

                        pdfDocument.Add(new Paragraph(strSubject));

                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        //string test = dtMeeting.Rows[0]["Venue"].ToString();
                        //string tes1t = dtMeeting.Rows[0]["Venue"].ToString().Replace("\n", " ");
                        pdfDocument.Add(new Paragraph("The next meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString() +
                            " is scheduled to be held on " + Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy") +
                            " at " + dtMeeting.Rows[0]["MeetingTime"].ToString() + " Hrs. at " + dtMeeting.Rows[0]["Venue"].ToString().Replace("\n", " ")));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph("The Agenda Note will be sent to you in due course."));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph("You are requested to kindly make it convenient to attend the above meeting."));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph("Thanking You,"));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph("Yours faithfully,"));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));

                        if (CompanySecretary != string.Empty)
                        {
                            pdfDocument.Add(new Paragraph("(" + CompanySecretary + ")"));
                            pdfDocument.Add(new Paragraph(CompanySecretaryDesign));
                        }
                        else
                        {
                            pdfDocument.Add(new Paragraph("Authorized Signatory"));
                        }

                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph());
                        pdfDocument.Add(new Paragraph(""));
                        pdfDocument.Add(new Paragraph(""));
                        pdfDocument.NewPage();
                    }
                    pnlNoticeDownload.Visible = true;
                }
                catch (Exception ex)
                {
                    throw ex;
                }
                finally
                {
                    pdfDocument.Close();
                }
            }
            //System.Diagnostics.Process.Start(sFilePDF);
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
