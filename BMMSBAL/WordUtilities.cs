using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Web;
using System.Web.UI.WebControls;
using System.Data;
using System.Collections;
using System.Runtime.InteropServices.ComTypes;
using System.Web.UI;
using System.Web.UI.HtmlControls;
using iTextSharp.text;
using iTextSharp.text.pdf;
using iTextSharp.text.html.simpleparser;
using iTextSharp.text.html;

namespace BMMSBAL
{
    public class WordUtilities
    {

        #region ReadWordDocument
        public static string ReadWordDocument(string fileName)
        {
            //object file = "G:\\PendingTasks.doc";
            //fName = "~/Files/AgendaText/" + txtAgendaNo.Text + "-AgendaText.Doc";
            string fNameWithPath = HttpContext.Current.Server.MapPath(fileName);

            //string strPath = "G:\\PendingTasks.docx"; // Request.PhysicalApplicationPath + "\\document\\Test.doc";

            FileStream fStream = new FileStream
                       (fNameWithPath, FileMode.Open, FileAccess.Read);
            StreamReader sReader = new StreamReader(fStream);
            string readText = sReader.ReadToEnd();
            sReader.Close();
            return readText;
        }
        #endregion

        #region ExportToWord
        public static void ExportToWord(Control ctrl)
        {
            StringWriter stringWrite = new StringWriter();
            System.Web.UI.HtmlTextWriter htmlWrite = new System.Web.UI.HtmlTextWriter(stringWrite);
            if (ctrl is WebControl)
            {
                Unit w = new Unit(100, UnitType.Percentage);
                ((WebControl)ctrl).Width = w;

            }
            Page pg = new Page();
            pg.EnableEventValidation = false;

            HtmlForm frm = new HtmlForm();
            pg.Controls.Add(frm);
            frm.Attributes.Add("runat", "server");
            frm.Controls.Add(ctrl);
            pg.DesignerInitialize();
            pg.RenderControl(htmlWrite);
            string strHTML = stringWrite.ToString();
            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.Write(strHTML);
            HttpContext.Current.Response.ContentType = "application/ms-word";
            HttpContext.Current.Response.AddHeader("Content-Disposition", "inline;filename=temp.doc");
            //HttpContext.Current.Response.Write("<script>window.print();</script>");
            HttpContext.Current.Response.End();

        }
        #endregion

        #region ExportToPdf
        public static void ExportToPdf(Control ctrl)
        {
            StringWriter stringWrite = new StringWriter();
            System.Web.UI.HtmlTextWriter htmlWrite = new System.Web.UI.HtmlTextWriter(stringWrite);
            if (ctrl is WebControl)
            {
                Unit w = new Unit(100, UnitType.Percentage);
                ((WebControl)ctrl).Width = w;

            }
            Page pg = new Page();
            pg.EnableEventValidation = false;

            HtmlForm frm = new HtmlForm();
            pg.Controls.Add(frm);
            frm.Attributes.Add("runat", "server");
            frm.Controls.Add(ctrl);
            pg.DesignerInitialize();
            pg.RenderControl(htmlWrite);
            string strHTML = stringWrite.ToString();

            HtmlForm form = new HtmlForm();
            form.Controls.Add(ctrl);
            StringWriter sw = new StringWriter();
            HtmlTextWriter hTextWriter = new HtmlTextWriter(sw);
            form.Controls[0].RenderControl(hTextWriter);
            string html = sw.ToString();

            string strHTMLpath = HttpContext.Current.Server.MapPath("MyHTML.html");

            string strPDFpath = HttpContext.Current.Server.MapPath("MyPDF.pdf");

            Document document = new Document();

            PdfWriter.GetInstance(document, new FileStream(strPDFpath, FileMode.Create));

            document.Open();

            //string strHTML = strHTML;


            Paragraph P = new Paragraph("hi", FontFactory.GetFont("Arial", 10));

            Chunk ch = new Chunk("super", FontFactory.GetFont("Arial", 6));

            P.Add(ch);
            document.Add(P);
            System.Xml.XmlTextReader xmlReader = new System.Xml.XmlTextReader(new StringReader(html));
            HtmlParser.Parse(document, xmlReader);

            document.Close();


            //HttpContext.Current.Response.Clear();
            //HttpContext.Current.Response.Write(strHTML);
            //HttpContext.Current.Response.ContentType = "application/pdf";
            //HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=report.pdf");
            ////HttpContext.Current.Response.Write("<script>window.print();</script>");
            //HttpContext.Current.Response.End();

            //Document document = new Document();
            //MemoryStream ms = new MemoryStream();
            //PdfWriter writer = PdfWriter.GetInstance(document, ms);
            //StringReader se = new StringReader(strHTML);

            //HTMLWorker obj = new HTMLWorker(document);
            //document.Open();
            //obj.Parse(se);
            //// step 5: we close the document
            //document.Close();

            ////document.Open();

            ////Paragraph P = new Paragraph(strHTML, FontFactory.GetFont("Arial", 10));

            ////Chunk ch = new Chunk(strHTML, FontFactory.GetFont("Arial", 6));

            ////P.Add(ch);

            ////document.Add(P);

            ////document.Close(); 

            //HttpContext.Current.Response.Clear();
            //HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=report.pdf");
            //HttpContext.Current.Response.ContentType = "application/pdf";
            //HttpContext.Current.Response.Buffer = true;
            //HttpContext.Current.Response.OutputStream.Write(ms.GetBuffer(), 0, ms.GetBuffer().Length);
            //HttpContext.Current.Response.OutputStream.Flush();
            //HttpContext.Current.Response.End();

        }
        #endregion

        public static void CreateWord(String HtmlFile)
        {



            object filename1 = HtmlFile;

            object oMissing = System.Reflection.Missing.Value;


            object oFalse = false;

            Microsoft.Office.Interop.Word.Application oWord = new
            Microsoft.Office.Interop.Word.Application();

            Microsoft.Office.Interop.Word.Document oDoc = new
            Microsoft.Office.Interop.Word.Document();

            oDoc = oWord.Documents.Add(ref oMissing, ref oMissing, ref oMissing, ref oMissing);

            oWord.Visible = false;

            oDoc = oWord.Documents.Open(ref filename1, ref oMissing,
            ref oMissing, ref oMissing, ref oMissing, ref oMissing, ref oMissing,
            ref oMissing, ref oMissing, ref oMissing, ref oMissing, ref oMissing,
            ref oMissing, ref oMissing, ref oMissing, ref oMissing);

            filename1 = @"S:\Report.doc";

            object fileFormat =
            Microsoft.Office.Interop.Word.WdSaveFormat.wdFormatDocument;

            oDoc.SaveAs(ref filename1, ref fileFormat, ref oMissing,
            ref oMissing, ref oMissing, ref oMissing, ref oMissing, ref oMissing,
            ref oMissing, ref oMissing, ref oMissing, ref oMissing, ref oMissing,
            ref oMissing, ref oMissing, ref oMissing);

            oDoc.Close(ref oFalse, ref oMissing, ref oMissing);

            oWord.Quit(ref oMissing, ref oMissing, ref oMissing);



        }

    }
}
