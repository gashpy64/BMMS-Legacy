using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Web;
using System.Data;
using iTextSharp.text.pdf;
using iTextSharp.text;
using iTextSharp.text.html.simpleparser;
using System.Collections;
using iTextSharp.text.html;
using System.Xml;
using PDFBuilder;

namespace BMMSBAL
{
    public class PDFUtilities
    {

        #region CreateCell
        public static PdfPCell CreateCell(string TextValue, float BorderWidth, int AlignText, int ColSpan)
        {
            PdfPCell cell = new PdfPCell(new Phrase(TextValue));
            cell.Colspan = ColSpan;

            cell.BorderWidth = BorderWidth;

            cell.HorizontalAlignment = AlignText; //0=Left, 1=Centre, 2=Right
            return cell;
        }
        #endregion

        #region CreateDesignCell
        public static PdfPCell CreateDesignCell(string TextValue, float BorderWidth, int AlignText, int ColSpan, Font fnt)
        {
            PdfPCell cell = new PdfPCell(new Phrase(TextValue, fnt));
            cell.Colspan = ColSpan;

            cell.BorderWidth = BorderWidth;

            cell.HorizontalAlignment = AlignText; //0=Left, 1=Centre, 2=Right
            return cell;
        }
        #endregion

        #region AddHTMLText
        public static void AddHTMLText(Document Pdf_Document, string HTML_Text)
        {
            ArrayList lt = HTMLWorker.ParseToList(new StringReader(HTML_Text), null);

            for (int l = 0; l < lt.Count; ++l)
            {

                try
                {
                    Pdf_Document.Add((IElement)lt[l]);
                }
                catch
                {
                }
            }

        }
        #endregion

        #region PrintCompanyLogo
        public static iTextSharp.text.Image PrintCompanyLogo()
        {
            string imageFilePath = HttpContext.Current.Server.MapPath("~/Images") + "\\logo.jpg";
            iTextSharp.text.Image logo = iTextSharp.text.Image.GetInstance(imageFilePath);

            logo.ScaleToFit(500f, 260f);

            //Give space before image
            logo.SpacingBefore = 30f;

            //Give some space after the image
            logo.SpacingAfter = 1f;
            logo.Alignment = Element.ALIGN_CENTER;

            return logo;


        }
        #endregion

        #region GenerateHTMLPdf
        public static void GenerateHTMLPdf(string fName, string fCSSName)
        {
            //Page sizes are found in iTextSharp.text.PageSize
            HtmlToPdfBuilder builder = new HtmlToPdfBuilder(PageSize.LETTER);

            HtmlPdfPage first = builder.AddPage();
            //also found at builder[0]

            HtmlPdfPage second = builder.AddPage();

            first.AppendHtml("<h1>Hello World</h1>");

            //you can also use params for formatting
            second.AppendHtml("<h1>{0}</h1><span>{0}</span>", "Hello Second Page", "Another Param");

            //add individual styles
            builder.AddStyle("H1", "color:#F00");
            builder.AddStyle("p", "font-weight:bold;text-decoration:underline;");

            //import an entire sheet
            builder.ImportStylesheet(fCSSName);

            byte[] file = builder.RenderPdf();
            File.WriteAllBytes(fName, file);

        }
        #endregion

        #region AddHeaderPageNo
        public static void AddHeaderPageNo(Document Pdf_Document)
        {

            HeaderFooter header = new HeaderFooter(new Phrase("Page No: "), true);
            header.Border = Rectangle.NO_BORDER;
            header.Alignment = Element.ALIGN_RIGHT;
            Pdf_Document.Header = header;

        }
        #endregion

        #region AddFooterPageNo
        public static void AddFooterPageNo(Document Pdf_Document)
        {

            HeaderFooter footer = new HeaderFooter(new Phrase("Page No: "), true);
            footer.Border = Rectangle.NO_BORDER;
            footer.Alignment = Element.ALIGN_RIGHT;
            Pdf_Document.Footer = footer;

        }
        #endregion

        #region AddAgendaText
        public static void AddAgendaText(Document pdfDocument, PdfWriter writer, string fileName)
        {

            int rotation;
            PdfContentByte cb = writer.DirectContent;
            PdfImportedPage page;

            PdfReader reader = new PdfReader(fileName);
            int n = reader.NumberOfPages;
            int i = 0;

            while (i < n)
            {
                i++;
                pdfDocument.SetPageSize(reader.GetPageSizeWithRotation(i));

                //PDFUtilities.AddFooterPageNo(pdfDocument);
                pdfDocument.NewPage();

                page = writer.GetImportedPage(reader, i);
                rotation = reader.GetPageRotation(i);
                if (rotation == 90 || rotation == 270)
                {
                    cb.AddTemplate(page, 0, -1f, 1f, 0, 0, reader.GetPageSizeWithRotation(i).Height);
                }
                else
                {
                    cb.AddTemplate(page, 1f, 0, 0, 1f, 0, 0);
                }
                n = reader.NumberOfPages;
            }

            //PDFUtilities.AddFooterPageNo(pdfDocument);
            pdfDocument.NewPage();


        }
        #endregion

        #region AddParagraph
        public static void AddParagraph(Document pdfDocument, string strMessage, Font fntFormat, int intAlign)
        {
            Paragraph para = new Paragraph(strMessage, fntFormat);
            para.Alignment = intAlign;
            pdfDocument.Add(para);
        }
        #endregion

        #region GeneratePayRollStatement(DataTable dt)
        public static void GeneratePayRollStatement(DataTable dt)
        {

            string XMLFileName = HttpContext.Current.Server.MapPath(@"~/ReportXML/PayRollStatement.xml");

            XmlDocument xmlDocument = null;
            XmlNode xmlNode = null;

            string sFilePDF = HttpContext.Current.Server.MapPath(@"~/Downloads/PDF/PayRollStatement.pdf");

            Document document = new Document(PageSize.A4.Rotate(), 10, 10, 10, 10);

            try
            {
                xmlDocument = new XmlDocument();

                xmlDocument.Load(XMLFileName);

                PdfWriter writer = PdfWriter.GetInstance(document,
                                 new FileStream(sFilePDF, FileMode.Create));
                PdfPTable datatable = null;

                document.Open();

                Font fontCompanyName = FontFactory.GetFont(FontFactory.HELVETICA, 12, Font.BOLD);
                Font fontAddress = FontFactory.GetFont(FontFactory.HELVETICA, 8, Font.NORMAL);
                Font fontTitle = FontFactory.GetFont(FontFactory.HELVETICA, 10, Font.BOLD);
                Font fontHeadBold = FontFactory.GetFont(FontFactory.HELVETICA, 7, Font.BOLD);
                Font fontInnerNormal = FontFactory.GetFont(FontFactory.HELVETICA, 7, Font.NORMAL);
                Font fontInnerBold = FontFactory.GetFont(FontFactory.HELVETICA, 7, Font.BOLD);
                Font fontWhite = FontFactory.GetFont(FontFactory.HELVETICA, 10, Font.BOLD, Color.WHITE);

                xmlNode = xmlDocument.SelectSingleNode("PayRollStatement");
                foreach (XmlNode xmlNode1 in xmlNode)
                {
                    if (xmlNode1.Name == "MySetting")
                    {
                        foreach (XmlNode childNode in xmlNode1)
                        {

                            string strColSpan = childNode.Attributes["ColSpan"].Value;
                            string strName = childNode.Attributes["Name"].Value;
                            string strAddress = childNode.Attributes["Address"].Value;
                            string strLogoUrl = childNode.Attributes["LogoUrl"].Value;
                            string strLogoVisible = childNode.Attributes["LogoVisible"].Value;
                            string strPeriodname = childNode.Attributes["Periodname"].Value;
                            string strGrade = childNode.Attributes["Grade"].Value;

                            datatable = new PdfPTable(1);
                            datatable.DefaultCell.Padding = 3;
                            datatable.WidthPercentage = 100; // percentage
                            datatable.DefaultCell.BorderWidth = 0.0f;
                            datatable.DefaultCell.HorizontalAlignment = Element.ALIGN_CENTER;
                            datatable.DefaultCell.VerticalAlignment = Element.ALIGN_MIDDLE;

                            datatable.AddCell(new Phrase(strName, fontCompanyName));
                            datatable.AddCell(new Phrase(strAddress, fontAddress));
                            datatable.AddCell(new Phrase("", fontHeadBold));
                            datatable.AddCell(new Phrase("PayRoll Statement for the period of " + strPeriodname, fontTitle));

                            datatable.DefaultCell.HorizontalAlignment = Element.ALIGN_LEFT;
                            datatable.DefaultCell.VerticalAlignment = Element.ALIGN_MIDDLE;
                            datatable.AddCell(new Phrase("Grade : " + strGrade, fontHeadBold));

                            document.Add(datatable);
                        }
                    }
                }


                int NumColumns = dt.Columns.Count;

                Table table = new Table(NumColumns);

                table.Padding = 2;
                table.Spacing = 0;

                int valCol = NumColumns - 7;
                float valWidth = 65 / valCol;

                float[] headerwidths = new float[NumColumns]; // = { 9, 4, 8, 10, 8, 11, 9, 7, 9, 10, 4, 10 }; // percentage

                headerwidths[0] = 3.0f;
                headerwidths[1] = 5.0f;
                headerwidths[2] = 8.0f;
                headerwidths[3] = 3.0f;
                headerwidths[4] = 4.0f;
                headerwidths[5] = 4.0f;

                for (int w = 6; w < NumColumns - 1; w++)
                    headerwidths[w] = valWidth;

                headerwidths[NumColumns - 1] = 8;

                table.Widths = headerwidths;
                table.WidthPercentage = 100;

                table.BorderWidth = 0.5f;

                xmlNode = xmlDocument.SelectSingleNode("PayRollStatement/MyFirstHead");
                foreach (XmlNode childNode in xmlNode)
                {
                    string strName = childNode.Attributes["Name"].Value;
                    string strRowSpan = childNode.Attributes["RowSpan"].Value;
                    string strColSpan = childNode.Attributes["ColSpan"].Value;

                    Cell cell = new Cell(new Phrase(strName, fontHeadBold));
                    cell.Header = true;
                    cell.Rowspan = int.Parse(strRowSpan);
                    cell.Colspan = int.Parse(strColSpan);
                    cell.HorizontalAlignment = Element.ALIGN_CENTER;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);
                }

                xmlNode = xmlDocument.SelectSingleNode("PayRollStatement/MySecondHead");
                foreach (XmlNode childNode in xmlNode)
                {
                    string strName = childNode.Attributes["Name"].Value;

                    Cell cell = new Cell(new Phrase(strName, fontHeadBold));
                    cell.Header = true;
                    cell.HorizontalAlignment = Element.ALIGN_CENTER;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);
                }

                table.EndHeaders();

                table.DefaultHorizontalAlignment = Element.ALIGN_CENTER;
                table.DefaultVerticalAlignment = Element.ALIGN_MIDDLE;
                int rowCount = 0;

                xmlNode = xmlDocument.SelectSingleNode("PayRollStatement");
                foreach (XmlNode xmlNode1 in xmlNode)
                {
                    if (xmlNode1.Name == "Myrow")
                    {
                        if (rowCount % 2 == 1)
                        {
                            //table.DefaultCellGrayFill = 0.9f;
                        }

                        foreach (XmlNode childNode in xmlNode1)
                        {

                            string strAlign = childNode.Attributes["Align"].Value;
                            string tableRow = childNode.Attributes["Value"].Value;

                            if (strAlign == "AlignCenter")
                            {
                                Cell cell = new Cell(new Phrase(tableRow, fontInnerNormal));
                                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                                table.AddCell(cell);
                            }
                            if (strAlign == "AlignLeft")
                            {
                                Cell cell = new Cell(new Phrase(tableRow, fontInnerNormal));
                                cell.HorizontalAlignment = Element.ALIGN_LEFT;
                                table.AddCell(cell);
                            }
                            if (strAlign == "AlignRight")
                            {
                                Cell cell = new Cell(new Phrase(tableRow, fontInnerNormal));
                                cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                                table.AddCell(cell);
                            }
                            if (strAlign == "AlignRightBold")
                            {
                                Cell cell = new Cell(new Phrase(tableRow, fontInnerBold));
                                cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                                table.AddCell(cell);
                            }
                            if (strAlign == "AlignSpace")
                            {
                                string strSpace = "_".PadLeft(30, '_');
                                Cell cell = new Cell(new Phrase(strSpace, fontWhite));
                                table.AddCell(cell);
                            }
                        }

                        if (rowCount % 2 == 1)
                        {
                            table.DefaultCellGrayFill = 1.0f;
                        }

                        rowCount += 1;
                    }
                }


                Cell cell1 = new Cell(new Phrase("Total", fontInnerBold));
                cell1.HorizontalAlignment = Element.ALIGN_CENTER;
                cell1.Rowspan = 1;
                cell1.Colspan = 6;
                table.AddCell(cell1);

                xmlNode = xmlDocument.SelectSingleNode("PayRollStatement/MyTotal");
                foreach (XmlNode childNode in xmlNode)
                {
                    string tableRow = childNode.Attributes["Value"].Value;

                    if (tableRow != ".")
                    {
                        Cell cell = new Cell(new Phrase(tableRow, fontInnerBold));
                        cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                        cell.Rowspan = 1;
                        cell.Colspan = 1;
                        table.AddCell(cell);
                    }
                    else
                        table.AddCell(" ");
                }

                document.Add(table);

            }
            catch (Exception ex)
            {
                //VictoryBO.Utilities.GoToErrPage(className, "GeneratePayRollStatement", ex);
            }
            finally
            {
                document.Close();
            }

        }
        #endregion
    }
}
