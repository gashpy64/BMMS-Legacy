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
    public partial class ViewReport : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            ltrlViewReport.Text = Session["ViewReport"].ToString();
            btnPrint.Attributes.Add("onclick", "javascript:popupDialogHide(1,1,'ReportPrint.aspx','Report Print');");
        }

        protected void btnExportToPdf_Click(object sender, EventArgs e)
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

                PDFUtilities.AddHTMLText(pdfDocument, ltrlViewReport.Text.ToString());

            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                pdfDocument.Close();
            }

            //Application.Lock();
            //Application["ctrl"] = pnlReport;

            //Control ctrl = (Control)Application["ctrl"];
            //Application.Remove("ctrl");
            //Application.UnLock();
            //WordUtilities.ExportToPdf(ctrl);
            //ctrl.Dispose();
        }

        protected void btnExportToWord_Click(object sender, EventArgs e)
        {
            string strReportBanner = Server.MapPath("~/Images") + "\\report_banner-top.jpg";
            strReportBanner = "src='" + strReportBanner + "'";

            string strHTML = Session["ViewReport"].ToString();

            strHTML = strHTML.Replace("src='../Images/report_banner-top.jpg'", strReportBanner);
            strHTML = strHTML.Replace("<o:p>", "");
            strHTML = strHTML.Replace("</o:p>", "");

            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.Write(strHTML);
            HttpContext.Current.Response.ContentType = "application/ms-word";
            HttpContext.Current.Response.AddHeader("Content-Disposition", "inline;filename=temp.doc");
            //HttpContext.Current.Response.Write("<script>window.print();</script>");
            HttpContext.Current.Response.End();

            //////Application.Lock();
            //////Application["ctrl"] = pnlReport;

            //////Control ctrl = (Control)Application["ctrl"];
            //////Application.Remove("ctrl");
            //////Application.UnLock();
            //////WordUtilities.ExportToWord(ctrl);
            ////////WordUtilities.ExportToPdf(ctrl);
            //////ctrl.Dispose();

            
            //Response.Clear();
            //Response.Buffer = true;

            //Response.AddHeader("content-disposition", "attachment;filename=FileName.doc");

            //Response.ContentEncoding = System.Text.Encoding.UTF7;
            //Response.ContentType = "application/vnd.word";
            //System.IO.StringWriter oStringWriter = new System.IO.StringWriter();
            //System.Web.UI.HtmlTextWriter oHtmlTextWriter = new System.Web.UI.HtmlTextWriter(oStringWriter);
            //this.ltrlMinutesExtract.RenderControl(oHtmlTextWriter); //  .GridView1.RenderControl(oHtmlTextWriter);
            //Response.Output.Write(oStringWriter.ToString());
            //Response.Flush();
            //Response.End();
        }

    }
}
