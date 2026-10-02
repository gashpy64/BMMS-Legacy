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
    public partial class AgendaApproval : System.Web.UI.Page
    {
        private string className = "AgendaApproval";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                LoadCommittee();
            }
        }

        #region CreatePDF
        private void CreatePDF()
        {

            DataTable dtAgenda = new DataTable();
            dtAgenda = GetAgendaDetails();
            ViewState["dtAgenda"] = dtAgenda;

            if (dtAgenda.Rows.Count <= 0)
            {
                ScriptManager.RegisterStartupScript(this, this.GetType(), "msg", "alert('No Agenda Available');", true);
                ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
            }
            else
            {
                Document pdfDocument = new Document();
                string sFilePDF = Server.MapPath("~/Files/PDF") + "\\AgendaDetails.pdf";

                try
                {
                    string htmlTxt = string.Empty;

                    PdfWriter writer = PdfWriter.GetInstance(pdfDocument,
                                                 new FileStream(sFilePDF, FileMode.Create));
                    pdfDocument.Open();
                    pdfDocument.SetMargins(45f, 45f, 60f, 60f);

                    int _sNo = 1;

                    for (int j = 0; j < dtAgenda.Rows.Count; j++)
                    {
                        Paragraph paragraph = new Paragraph(" ");
                        pdfDocument.Add(paragraph);

                        pdfDocument.Add((PDFUtilities.PrintCompanyLogo()));

                        Paragraph para = new Paragraph("REGD & ADMIN OFFICE, KARUR");
                        para.Alignment = Element.ALIGN_CENTER;
                        pdfDocument.Add(para);

                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));

                        PdfPTable table = new PdfPTable(2);
                        table.DefaultCell.Border = 0;
                        table.WidthPercentage = 100;
                        table.SetWidths(new float[] { 60, 40 });
                        table.HorizontalAlignment = 0;

                        string CommitteeName = "Note to the " + dtAgenda.Rows[j]["CommitteeName"].ToString();
                        table.AddCell(PDFUtilities.CreateCell(CommitteeName, 0, 0, 1));

                        string AgendaNo = "Agenda No : " + dtAgenda.Rows[j]["AgendaNo"].ToString().Split('-').GetValue(2).ToString();
                        table.AddCell(PDFUtilities.CreateCell(AgendaNo, 0, 0, 1));

                        string SubjectType = " "; // "(" + dtAgenda.Rows[j]["SubjectTypeName"].ToString() + ")";
                        table.AddCell(PDFUtilities.CreateCell(SubjectType, 0, 0, 1));

                        string MeetingNo = "Meeting No : " + dtAgenda.Rows[j]["MeetingNo"].ToString();
                        table.AddCell(PDFUtilities.CreateCell(MeetingNo, 0, 0, 1));

                        string EmptyString = "";
                        table.AddCell(PDFUtilities.CreateCell(EmptyString, 0, 0, 1));

                        string DepartmentName = "Department : " + dtAgenda.Rows[j]["DepartmentName"].ToString();
                        table.AddCell(PDFUtilities.CreateCell(DepartmentName, 0, 0, 1));

                        table.AddCell(PDFUtilities.CreateCell(EmptyString, 0, 0, 2));

                        pdfDocument.Add(table);

                        pdfDocument.Add(new Paragraph(Environment.NewLine));

                        string htmlText = dtAgenda.Rows[j]["ShortText"].ToString();
                        PDFUtilities.AddHTMLText(pdfDocument, htmlText);

                        pdfDocument.Add(new Paragraph(Environment.NewLine));

                        if (dtAgenda.Rows[j]["AgendaType"].ToString() == "Entry")
                        {
                            htmlText = dtAgenda.Rows[j]["AgendaText"].ToString();
                        }
                        else
                        {
                            string fileName = "..\\Files\\AgendaText\\" + dtAgenda.Rows[j]["AgendaTextPath"].ToString();
                            htmlText = WordUtilities.ReadWordDocument(fileName);
                        }
                        PDFUtilities.AddHTMLText(pdfDocument, htmlText);

                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph("Proposed Resolution : "));

                        htmlText = dtAgenda.Rows[j]["ProposedResolution"].ToString();
                        PDFUtilities.AddHTMLText(pdfDocument, htmlText);

                        pdfDocument.Add(new Paragraph(Environment.NewLine));
                        pdfDocument.Add(new Paragraph(Environment.NewLine));


                        //htmlText = UserMgr.GetCompanySecretary();

                        //if (htmlText != string.Empty)
                        //    PDFUtilities.AddHTMLText(pdfDocument, "(" + htmlText + ")");

                        //htmlText = "Company Secretary";
                        //PDFUtilities.AddHTMLText(pdfDocument, htmlText);

                        _sNo += 1;

                        pdfDocument.NewPage();
                    }

                    pnlAgendaDetailsDownload.Visible = true;
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

        #region btnCreatePDF_Click
        protected void btnCreatePDF_Click(object sender, EventArgs e)
        {
            CreatePDF();
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
            if (ddlCommittee.SelectedIndex <= 0)
            {
                ddlMeeting.Items.Clear();
                pnlAgendaDetailsDownload.Visible = false;
                pnlPrintReport.Visible = false;
                pnlViewReport.Visible = false;
            }
            if (ddlCommittee.SelectedIndex > 0)
            {
                LoadMeeting(Convert.ToInt32(ddlCommittee.SelectedValue));
                pnlPrintReport.Visible = false;
                pnlViewReport.Visible = false;
                pnlAgendaDetailsDownload.Visible = false;
            }
        }
        #endregion

        #region ddlMeeting_SelectedIndexChanged
        protected void ddlMeeting_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (ddlMeeting.SelectedIndex <= 0)
            {
                pnlPrintReport.Visible = false;
                pnlViewReport.Visible = false;
                pnlAgendaDetailsDownload.Visible = false;
            }
            else
            {
                pnlPrintReport.Visible = true;
                pnlViewReport.Visible = false;
                pnlAgendaDetailsDownload.Visible = false;

                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByMeetingId(int.Parse(ddlMeeting.SelectedValue));

                ViewState["dtMeeting"] = dtMeeting;

                txtMeetingVenue.Text = dtMeeting.Rows[0]["Venue"].ToString();
                txtMeetingDate.Text = Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy");
                txtMeetingTime.Text = dtMeeting.Rows[0]["MeetingTime"].ToString();

                rdoViewFormat_SelectedIndexChanged(this, e);
            }
        }
        #endregion

        #region rdoViewFormat_SelectedIndexChanged
        protected void rdoViewFormat_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (ddlMeeting.Items.Count >= 1)
                if (ddlMeeting.Text != "0")
                {
                    if (rdoViewFormat.Text == "View")
                    {
                        pnlViewReport.Visible = true;
                        pnlPrintReport.Visible = false;

                        DataTable dtAgenda = new DataTable();
                        dtAgenda = GetAgendaDetails();
                        ViewState["dtAgenda"] = dtAgenda;

                        grvAgendaDetails.DataSource = dtAgenda;
                        grvAgendaDetails.DataBind();

                    }
                    if (rdoViewFormat.Text == "Print")
                    {
                        pnlViewReport.Visible = false;
                        pnlPrintReport.Visible = true;
                    }
                }

        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtAgenda"] = BMMSBAL.Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtAgenda"]);

                BindGridView();
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "grvRecord_Sorting", ex);
            }
        }
        #endregion

        #region BindGridView
        private void BindGridView()
        {
            DataTable dtAgenda = (DataTable)ViewState["dtAgenda"];

            grvAgendaDetails.DataSource = dtAgenda;
            grvAgendaDetails.DataBind();

        }
        #endregion

        #region GetAgendaDetails
        private DataTable GetAgendaDetails()
        {
            int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());

            DataTable dtAgenda = new DataTable();
            dtAgenda = AgendaMgr.GetAgendaByMeetingId(MeetingId);
            ViewState["dtAgenda"] = dtAgenda;

            return dtAgenda;

        }
        #endregion
    }
}
