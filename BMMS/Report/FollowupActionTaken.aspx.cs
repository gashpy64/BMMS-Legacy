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
    public partial class FollowupActionTaken : System.Web.UI.Page
    {
        private string className = "FollowupActionTaken";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                LoadDropDownList();
                rdoMeatingNoSearch.SelectedIndex = 0;
                lblMeetingNo.Visible = false;
                ddlMeetingNoTo.Visible = false;
                rdoSubjectNoSearch.SelectedIndex = 0;
                rdoSubjectNoSearch.Enabled = true;
                ddlSubjectNoFrom.Enabled = false;
                ddlSubjectNoTo.Enabled = false;
            }
        }
        #endregion

        #region btnSendMail_Click
        protected void btnSendMail_Click(object sender, EventArgs e)
        {
            MsgHide();
            DataTable dtFollowup = new DataTable();
            dtFollowup = GetFollowup();

            if (dtFollowup.Rows.Count <= 0)
            {
                MsgDisplay(Session["NoRecord"].ToString());
                ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
            }
            else
            {
                CreatePDF(dtFollowup);
                pnlFollowupDownload.Visible = true;
                CreateBodyText();
                MsgDisplay("Mail was sent to all members.");
            }
        }
        #endregion

        #region CreateBodyText
        private void CreateBodyText()
        {
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);
            int MeetingId = int.Parse(ddlMeetingNoFrom.SelectedValue);

            DataTable dtCommitteeMember = new DataTable();
            dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByCommitteeId(CommitteeId, MeetingId);

            DataTable dtCompanySecretary = UserMgr.GetCompanySecretary(int.Parse(ddlMeetingNoFrom.SelectedValue.ToString()));
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
                ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
            }
            else
            {
                try
                {
                    string ToMailId = string.Empty;

                    int UserId = Convert.ToInt16(Session["UserId"].ToString());
                    UserBAL userBal = UserMgr.GetUserByUserId(UserId);
                    ToMailId = userBal.EmailId.ToString();

                    string Bcc = string.Empty;

                    for (int i = 0; i < dtCommitteeMember.Rows.Count; i++)
                    {
                        if (i == dtCommitteeMember.Rows.Count - 1)
                            Bcc += dtCommitteeMember.Rows[i]["EmailId"].ToString();
                        else
                            Bcc += dtCommitteeMember.Rows[i]["EmailId"].ToString() + ", ";
                    }

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
                    BodyText += "Date : " + System.DateTime.Now.ToString("dd-MM-yyyy");
                    BodyText += "</td>";
                    BodyText += "</tr>";

                    BodyText += "<tr>";
                    BodyText += "<td colspan='2' style='text-align:left'>";
                    BodyText += "Dear Sir/Madam,<br />";
                    BodyText += "<br />";
                    BodyText += "<b>Subject : " + ViewState["MailSubject"].ToString() + "</b><br />";
                    BodyText += "<br />";
                    BodyText += "Please find attached the Followup for the meeting as given below.";
                    BodyText += "<br />";
                    BodyText += "<br />";
                    BodyText += "Committee Name : " + ddlCommittee.SelectedItem.Text.Trim();
                    BodyText += "<br />";

                    if (rdoMeatingNoSearch.SelectedValue.ToString() == "0")
                    {
                        BodyText += "Meeting No : " + ddlMeetingNoFrom.SelectedItem.Text.Trim();
                        BodyText += "<br />";
                        if (rdoSubjectNoSearch.SelectedValue.ToString() == "1")
                        {
                            BodyText += "Subject No : " + ddlSubjectNoFrom.SelectedItem.Text.Trim();
                            BodyText += " to " + ddlSubjectNoTo.SelectedItem.Text.Trim();
                            BodyText += "<br />";
                        }
                    }
                    if (rdoMeatingNoSearch.SelectedValue.ToString() == "1")
                    {
                        BodyText += "Meeting No : " + ddlMeetingNoFrom.SelectedItem.Text.Trim();
                        BodyText += " to " + ddlMeetingNoTo.SelectedItem.Text.Trim();
                        BodyText += "<br />";
                    }
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

                    string Subject = ViewState["MailSubject"].ToString();
                    string AttachFileName = Server.MapPath("~/Files/PDF") + "\\Followup.pdf";
                    Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, AttachFileName, Bcc);

                    
                }
                catch (Exception ex)
                {
                    throw ex;
                }
                finally
                {

                }
            }
        }
        #endregion

        #region CreatePDF
        protected void CreatePDF(DataTable dtFollowup)
        {
            string sFilePDF = Server.MapPath("~/Files/PDF") + "\\Followup.pdf";

            Document pdfDocument = new Document(PageSize.A4, 100f, 75f, 50f, 50f);

            try
            {

                PdfWriter writer = PdfWriter.GetInstance(pdfDocument, new
                    FileStream(sFilePDF, FileMode.Create));

                pdfDocument.Open();

                string htmlTxt = string.Empty;

                Paragraph paragraph = new Paragraph(" ");
                pdfDocument.Add(paragraph);

                PDFUtilities.AddHTMLText(pdfDocument, Session["FollowupHTML"].ToString());

            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                pdfDocument.Close();
            }

            ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(825,500,'" + sFilePDF + "','Followup Report');", true);

        }
        #endregion

        #region btnCreatePDF_Click
        protected void btnCreatePDF_Click(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                DataTable dtFollowup = new DataTable();
                dtFollowup = GetFollowup();

                if (dtFollowup.Rows.Count <= 0)
                {
                    MsgDisplay(Session["NoRecord"].ToString());
                    ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
                }
                else
                {

                    Session["ViewReport"] = CreateReportHTML(dtFollowup);
                    pnlFollowupDownload.Visible = true;
                    //CreatePDF(dtFollowup);
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(825,500,'ViewReport.aspx','Followup Report');", true);
                }
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "btnCreatePDF_Click", ex);
            }
        }
        #endregion

        #region CreateReportHTML
        private string CreateReportHTML(DataTable dtFollowup)
        {
            int MeetingNoFrom = int.Parse(ddlMeetingNoFrom.SelectedItem.Text.Trim());
            int MeetingNoTo = MeetingNoFrom;

            if (rdoMeatingNoSearch.SelectedValue.ToString() == "1")
                MeetingNoTo = int.Parse(ddlMeetingNoTo.SelectedItem.Text.Trim());

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            CommitteeBAL commiteeBal = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);
            bool IsBoard = false;
            if (commiteeBal.Board == 1)
                IsBoard = true;

            string htmlTxt = string.Empty;

            try
            {
                DataTable dtMeeting = MeetingMgr.GetMeetingList();

                htmlTxt += "<style>";
                htmlTxt += "@media print";
                htmlTxt += "{";
                htmlTxt += "spana {page-break-after:always}";
                htmlTxt += "}";
                htmlTxt += "</style>";
                
                htmlTxt += "<div style='float:left; width: 650px;'>";

                htmlTxt += "<div style='float:left; width:100%; text-align:center;'><img src='../Images/report_banner-top.jpg' /></div>";
                //htmlTxt += "<div style='float:left; width:100%; text-align:center;'><img src='" + strReportBanner.ToString() + "' /></div>";

                htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:13pt; padding-top:10px;'>THE LAKSHMI VILAS BANK LIMITED., REGD & ADMIN OFFICE, KARUR - 6</div>";

                htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:11pt;'><br /></div>";

                htmlTxt += "<table cellpadding='0' cellspacing='0' border='1px' style='float:left; width:100%;'>";

                htmlTxt += "<tr>";
                htmlTxt += "<th style='width:10%'>M.No.";
                htmlTxt += "</th>";
                htmlTxt += "<th style='width:10%'>&Date";
                htmlTxt += "</th>";
                htmlTxt += "<th style='width:10%'>Sub.No";
                htmlTxt += "</th>";
                htmlTxt += "<th style='width:70%'>Subject";
                htmlTxt += "</th>";
                htmlTxt += "</tr>";

                for (int i = 0; i < dtMeeting.Rows.Count; i++)
                {


                    dtFollowup = (DataTable)ViewState["dtFollowup"];
                    DataTable dtFollowupFilter = new DataTable();

                    DataView dv = new DataView(dtFollowup);

                    dv.RowFilter = "MeetingId = " + int.Parse(dtMeeting.Rows[i]["MeetingId"].ToString());

                    dtFollowupFilter = dv.ToTable("dtFollowup");


                    if (dtFollowupFilter.Rows.Count > 0)
                    {
                        htmlTxt += "<tr>";
                        htmlTxt += "<td>";
                        htmlTxt += dtFollowupFilter.Rows[0]["MeetingNo"].ToString();
                        htmlTxt += "</td>";
                        htmlTxt += "<td>";
                        htmlTxt += Convert.ToDateTime(dtFollowupFilter.Rows[0]["MeetingDate"].ToString()).ToString("dd/MM/yyyy");
                        htmlTxt += "</td>";
                        htmlTxt += "<td>";
                        htmlTxt += "</td>";
                        htmlTxt += "<td>";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";

                        for (int j = 0; j < dtFollowupFilter.Rows.Count; j++)
                        {

                            htmlTxt += "<tr>";
                            htmlTxt += "<td>";
                            htmlTxt += "</td>";
                            htmlTxt += "<td>";
                            htmlTxt += "</td>";
                            htmlTxt += "<td>";
                            htmlTxt += dtFollowupFilter.Rows[j]["SubjectNo"].ToString();
                            htmlTxt += "</td>";
                            htmlTxt += "<td>";
                            htmlTxt += dtFollowupFilter.Rows[j]["ShortText"].ToString();
                            htmlTxt += "</td>";
                            htmlTxt += "</tr>";                            
                        }
                    }
                }
                htmlTxt += "</table><br />";
                htmlTxt += "<spana style='color:white'>.</spana>";
                htmlTxt += "</div>";

            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {

            }

            return htmlTxt;

        }
        #endregion

        #region LoadMeeting
        public void LoadMeeting(int CommitteeId)
        {
            DataTable dtMeeting = new DataTable();
            dtMeeting = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);

            if (dtMeeting.Rows.Count <= 0)
            {
                ddlMeetingNoFrom.Enabled = false;
                ddlMeetingNoTo.Enabled = false;
            }
            else
            {
                Common.LoadDropdownlist(ddlMeetingNoFrom, dtMeeting, "MeetingNo", "MeetingId", true);
                Common.LoadDropdownlist(ddlMeetingNoTo, dtMeeting, "MeetingNo", "MeetingId", true);
                //ddlMeetingNoFrom.SelectedIndex = ddlMeetingNoFrom.Items.Count - 1;
                //ddlMeetingNoTo.SelectedIndex = ddlMeetingNoTo.Items.Count - 1;
            }
        }
        #endregion

        #region LoadDropDownList
        public void LoadDropDownList()
        {
            DataTable dtCommittee = new DataTable();
            dtCommittee = CommitteeMgr.GetCommitteeList(1);

            Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);

            DataTable dtDepartment = new DataTable();
            dtDepartment = DepartmentMgr.GetDepartmentList(1);

            Common.LoadDDLwithAll(ddlDeparment, dtDepartment, "DepartmentName", "DepartmentId", true);

            UserBAL userBal = new UserBAL();
            userBal = UserMgr.GetUserByUserId(int.Parse(Session["UserId"].ToString()));

            if (Session["RoleCode"].ToString() == "manager")
            {
                ddlDeparment.Text = userBal.DepartmentId.ToString();
                ddlDeparment.Enabled = false;
            }
            else
            {
                ddlDeparment.Text = "All";
                ddlDeparment.Enabled = true;
            }
        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();
            if (ddlCommittee.SelectedIndex <= 0)
            {
                ddlMeetingNoFrom.Items.Clear();
                ddlMeetingNoTo.Items.Clear();
                pnlPrintReport.Visible = false;
                pnlViewReport.Visible = false;
                pnlFollowupDownload.Visible = false;
            }
            if (ddlCommittee.SelectedIndex > 0)
            {
                LoadMeeting(Convert.ToInt32(ddlCommittee.SelectedValue));
                pnlPrintReport.Visible = false;
                pnlViewReport.Visible = false;
                pnlFollowupDownload.Visible = false;
            }
        }
        #endregion

        #region ddlMeetingNoFrom_SelectedIndexChanged
        protected void ddlMeetingNoFrom_SelectedIndexChanged(object sender, EventArgs e)
        {
            BindSubjectNo();
        }
        #endregion

        #region ddlMeetingNoTo_SelectedIndexChanged
        protected void ddlMeetingNoTo_SelectedIndexChanged(object sender, EventArgs e)
        {
            BindSubjectNo();
        }
        #endregion

        #region MeetingNoChanged
        private bool MeetingNoChanged()
        {
            bool result = false;
            MsgHide();
            if (ddlMeetingNoFrom.SelectedIndex <= 0 || ddlMeetingNoTo.SelectedIndex <= 0)
            {
                pnlPrintReport.Visible = false;
                pnlViewReport.Visible = false;
                pnlFollowupDownload.Visible = false;
                result = false;
            }
            //else
            //{
            //if (CheckFollowup())
            //{
            //    pnlPrintReport.Visible = true;
            //    pnlViewReport.Visible = false;
            //    pnlFollowupDownload.Visible = false;

            //    int MeetingNoFrom = int.Parse(ddlMeetingNoFrom.SelectedItem.Text.Trim());
            //    int MeetingNoTo = int.Parse(ddlMeetingNoTo.SelectedItem.Text.Trim());

            //    DataTable dtMeeting = new DataTable();
            //    dtMeeting = MeetingMgr.GetMeetingByMeetingNoFromTo(MeetingNoFrom, MeetingNoTo);

            //    ViewState["dtMeeting"] = dtMeeting;

            //    txtMeetingVenue.Text = dtMeeting.Rows[0]["Venue"].ToString();
            //    txtMeetingDate.Text = Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy");
            //    txtMeetingTime.Text = dtMeeting.Rows[0]["MeetingTime"].ToString();

            //    result = true;
            //}
            //}
            return result;
        }
        #endregion

        #region ddlDeparment_SelectedIndexChanged
        protected void ddlDeparment_SelectedIndexChanged(object sender, EventArgs e)
        {
            BindSubjectNo();
        }
        #endregion

        #region BindSubjectNo
        private void BindSubjectNo()
        {
            MsgHide();

            ddlSubjectNoFrom.Items.Clear();
            ddlSubjectNoTo.Items.Clear();

            if (rdoMeatingNoSearch.SelectedValue.ToString() == "0")
            {

                int MeetingNoFrom = int.Parse(ddlMeetingNoFrom.SelectedValue.ToString().Trim());

                int DepartmentId = -1;
                if (ddlDeparment.SelectedValue != "All")
                    DepartmentId = int.Parse(ddlDeparment.SelectedValue.ToString());

                DataTable dtFollowup = new DataTable();

                dtFollowup = ActionItemMgr.GetActionItemByMeetingId(MeetingNoFrom, DepartmentId);

                ViewState["dtFollowup"] = dtFollowup;

                if (dtFollowup.Rows.Count <= 0)
                {
                    ddlSubjectNoFrom.Enabled = false;
                    ddlSubjectNoTo.Enabled = false;
                }
                else
                {
                    ddlSubjectNoFrom.Enabled = true;
                    ddlSubjectNoTo.Enabled = true;

                    ddlSubjectNoFrom.DataSource = dtFollowup;
                    ddlSubjectNoFrom.DataBind();

                    ddlSubjectNoTo.DataSource = dtFollowup;
                    ddlSubjectNoTo.DataBind();

                    ddlSubjectNoFrom.SelectedIndex = 0;
                    ddlSubjectNoTo.SelectedIndex = ddlSubjectNoTo.Items.Count - 1;

                    ddlSubjectNoFrom.Enabled = false;
                    ddlSubjectNoTo.Enabled = false;
                }
            }
        }
        #endregion

        #region rdoMeatingNoSearch_SelectedIndexChanged
        protected void rdoMeatingNoSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (rdoMeatingNoSearch.SelectedValue == "0")  // 0 for Particular
            {
                lblMeetingNo.Visible = false;
                ddlMeetingNoTo.Visible = false;
                rdoSubjectNoSearch.SelectedIndex = 0;
                rdoSubjectNoSearch.Enabled = true;
                ddlSubjectNoFrom.Enabled = false;
                ddlSubjectNoTo.Enabled = false;
            }
            if (rdoMeatingNoSearch.SelectedValue == "1")  // 1 for Between 
            {
                lblMeetingNo.Visible = true;
                ddlMeetingNoTo.Visible = true;
                rdoSubjectNoSearch.SelectedIndex = 0;
                rdoSubjectNoSearch.Enabled = false;
                ddlSubjectNoFrom.Enabled = false;
                ddlSubjectNoTo.Enabled = false;
            }
        }
        #endregion

        #region rdoSubjectNoSearch_SelectedIndexChanged
        protected void rdoSubjectNoSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (rdoSubjectNoSearch.SelectedValue == "0")  // 0 for All
            {
                ddlSubjectNoFrom.Enabled = false;
                ddlSubjectNoTo.Enabled = false;
                BindSubjectNo();
            }
            if (rdoSubjectNoSearch.SelectedValue == "1")  // 1 for Between 
            {
                ddlSubjectNoFrom.Enabled = true;
                ddlSubjectNoTo.Enabled = true;
            }
        }
        #endregion


        #region CheckValidataion
        private bool CheckValidataion()
        {
            bool result = true;

            try
            {
                if (ddlCommittee.SelectedValue.ToString() == "0")
                {
                    MsgDisplay("Select committee name.");
                    ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                    result = false;
                }
                else if (rdoMeatingNoSearch.SelectedValue.ToString() == "0")
                {
                    int MeetingId = int.Parse(ddlMeetingNoFrom.SelectedValue.ToString().Trim());

                    DataTable dtFollowup = ActionItemMgr.GetActionItemByMeetingId(MeetingId, 0);

                    if (dtFollowup.Rows.Count <= 0)
                    {
                        MsgDisplay("Followup not generated for this meeting.");
                        ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
                        result = false;
                    }
                }
                else if (rdoMeatingNoSearch.SelectedValue.ToString() == "1")
                {
                    int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString().Trim());
                    int MeetingNoFrom = int.Parse(ddlMeetingNoFrom.SelectedItem.Text.Trim());
                    int MeetingNoTo = int.Parse(ddlMeetingNoTo.SelectedItem.Text.Trim());

                    DataTable dtFollowup = ActionItemMgr.GetActionItemByMeetingIdDeptId(CommitteeId, MeetingNoFrom, MeetingNoTo, -1);

                    if (dtFollowup.Rows.Count <= 0)
                    {
                        MsgDisplay("Followup not generated for this meeting.");
                        ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
                        result = false;
                    }
                }
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "CheckValidataion", ex.ToString());
            }
            return result;
        }
        #endregion

        #region btnSubmit_Click
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            pnlFollowupDownload.Visible = false;
            pnlViewReport.Visible = false;
            pnlPrintReport.Visible = false;

            if (CheckValidataion())
            {
                if (rdoViewFormat.Text == "View")
                {
                    pnlViewReport.Visible = true;
                    pnlPrintReport.Visible = false;

                    DataTable dtFollowup = new DataTable();
                    dtFollowup = GetFollowup();
                    //ViewState["dtFollowup"] = dtFollowup;

                    grvFollowup.DataSource = dtFollowup;
                    grvFollowup.DataBind();

                }
                if (rdoViewFormat.Text == "Print")
                {
                    pnlFollowupDownload.Visible = false;
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
                ViewState["dtFollowup"] = BMMSBAL.Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtFollowup"]);

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
            DataTable dtFollowup = (DataTable)ViewState["dtFollowup"];

            grvFollowup.DataSource = dtFollowup;
            grvFollowup.DataBind();

        }
        #endregion

        #region GetFollowup
        private DataTable GetFollowup()
        {
            DataTable dtFollowup = new DataTable();
            DataTable dtFollowup1 = new DataTable();

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

            int DepartmentId = -1;
            if (ddlDeparment.SelectedValue != "All")
                DepartmentId = int.Parse(ddlDeparment.SelectedValue.ToString());

            int MeetingNoFrom = int.Parse(ddlMeetingNoFrom.SelectedItem.Text.Trim());
            int MeetingNoTo = int.Parse(ddlMeetingNoFrom.SelectedItem.Text.Trim());

            if (rdoMeatingNoSearch.SelectedValue.ToString() == "1")
                MeetingNoTo = int.Parse(ddlMeetingNoTo.SelectedItem.Text.Trim());

            dtFollowup = ActionItemMgr.GetActionItemByMeetingIdDeptId(CommitteeId, MeetingNoFrom, MeetingNoTo, DepartmentId);

            ViewState["dtFollowup"] = dtFollowup;

            try
            {
                DataView dv = new DataView(dtFollowup);

                if (rdoSubjectNoSearch.SelectedIndex.ToString() == "1")
                {
                    if (dtFollowup.Rows.Count > 0)
                    {
                        dv.RowFilter = "SubjectNo >= " + ddlSubjectNoFrom.SelectedValue
                            + " AND SubjectNo <= " + ddlSubjectNoTo.SelectedValue;
                    }
                }

                dtFollowup1 = dv.ToTable("dtFollowup");

            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "CheckValidataion", ex.ToString());
            }

            return dtFollowup1;

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
