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
            // ViewReport.aspx?pdf=1: the PDF report (Agenda Summary, Agenda Details) built by Generate
            if (Request.QueryString["pdf"] == "1")
            {
                SendStoredPdf();
                return;
            }

            ltrlViewReport.Text = Session["ViewReport"].ToString();
        }

        #region SendStoredPdf
        // Streams the PDF that Generate kept in Session["ReportPdf"], inline, and clears it: nothing is
        // written to ~/Files/PDF (step 25)
        private void SendStoredPdf()
        {
            byte[] pdf = Session["ReportPdf"] as byte[];
            string name = Session["ReportPdfName"] as string;

            Session.Remove("ReportPdf");
            Session.Remove("ReportPdfName");

            Response.Clear();

            if (pdf == null || pdf.Length == 0)
            {
                Response.ContentType = "text/html";
                Response.Write("<html><head><title>Report</title></head><body><p>The report is no longer available. Close this window and click Generate again.</p></body></html>");
            }
            else
            {
                Response.ContentType = "application/pdf";
                Response.AddHeader("Content-Disposition", "inline; filename=" + (string.IsNullOrEmpty(name) ? "Report" : name) + ".pdf");
                Response.BinaryWrite(pdf);
            }

            Response.End();
        }
        #endregion

        protected void btnExportToPdf_Click(object sender, EventArgs e)
        {
            // Tamil or Hindi text: no PDF; Export to Word and Print show it (step U1b). The report name is kept
            // for Export to Word.
            if (PdfFonts.HasIndicText(Session["ViewReport"].ToString()))
            {
                divPdfMessage.InnerText = PdfFonts.IndicTextMessageFor("use Export to Word or Print");
                divPdfMessage.Visible = true;
                return;
            }

            // Built in memory from the report HTML and sent as a download; no file on disk (step 25)
            string name = Session["ViewReportName"] as string;
            Session.Remove("ViewReportName");

            byte[] pdf = PDFUtilities.HtmlReportToPdf(Session["ViewReport"].ToString());

            Response.Clear();
            Response.ContentType = "application/pdf";
            Response.AddHeader("Content-Disposition", "attachment; filename=" + (string.IsNullOrEmpty(name) ? "Report" : name) + ".pdf");
            Response.BinaryWrite(pdf);
            Response.End();

            //Application.Lock();
            //Application["ctrl"] = pnlReport;

            //Control ctrl = (Control)Application["ctrl"];
            //Application.Remove("ctrl");
            //Application.UnLock();
            //WordUtilities.ExportToPdf(ctrl);
            //ctrl.Dispose();
        }

        #region WordDocument
        // The report HTML as a document Word opens as HTML (step 25). The report HTML is a fragment
        // (<div>, <style> ...); Word shows a fragment without a table as plain text, so it is wrapped in a
        // full HTML document with the Office namespaces and UTF-8. HTML that already starts with <html>
        // (or a doctype) is not wrapped again. The logo is linked by its file path, as before; when that
        // file is missing the image is left out.
        public static string WordDocument(string ReportHtml, string LogoFilePath)
        {
            string strHTML = ReportHtml == null ? string.Empty : ReportHtml;

            string logoSrc = "src='" + OrganisationDetails.LogoReportSrc + "'";
            if (!string.IsNullOrEmpty(LogoFilePath) && System.IO.File.Exists(LogoFilePath))
                strHTML = strHTML.Replace(logoSrc, "src='" + LogoFilePath + "'");
            else
                strHTML = strHTML.Replace("<img " + logoSrc + " />", string.Empty);

            strHTML = strHTML.Replace("<o:p>", "");
            strHTML = strHTML.Replace("</o:p>", "");

            string start = strHTML.TrimStart();
            if (start.StartsWith("<html", StringComparison.OrdinalIgnoreCase)
                || start.StartsWith("<!doctype", StringComparison.OrdinalIgnoreCase))
                return strHTML;

            return "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">"
                 + "<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word'"
                 + " xmlns='http://www.w3.org/TR/REC-html40'>"
                 + "<head><meta http-equiv='Content-Type' content='text/html; charset=utf-8' /><meta charset='utf-8' />"
                 + "<title>Report</title></head><body>"
                 + strHTML
                 + "</body></html>";
        }
        #endregion

        protected void btnExportToWord_Click(object sender, EventArgs e)
        {
            string strHTML = WordDocument(Session["ViewReport"].ToString(), OrganisationDetails.LogoFilePath);

            string name = Session["ViewReportName"] as string;

            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/msword";
            HttpContext.Current.Response.Charset = "utf-8";
            HttpContext.Current.Response.ContentEncoding = System.Text.Encoding.UTF8;
            HttpContext.Current.Response.AddHeader("Content-Disposition", "attachment; filename=" + (string.IsNullOrEmpty(name) ? "Report" : name) + ".doc");
            HttpContext.Current.Response.Write(strHTML);
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
