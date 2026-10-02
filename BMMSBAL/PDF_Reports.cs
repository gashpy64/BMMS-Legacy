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
    public class PDF_Reports
    {
        private static string className = "PDF_Reports";
        private static Font font11B = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 11, Font.BOLD);
        private static Font font11N = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 11, Font.NORMAL);
        private static Font font12U = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 12, Font.UNDERLINE);
        private static Font font10B = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 10, Font.BOLD);
        private static Font font10N = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 10, Font.NORMAL);

        #region GenerateSittingFeeIndividual
        public static void GenerateSittingFeeIndividual(DataTable dt, DateTime FromDate, DateTime ToDate, string AuthorityPersion,
            string AuthorityPersionDesign)
        {

            string FinancialYear = FromDate.ToString("yyyy") + "-" + ToDate.ToString("yyyy");
            string DatePeriod = " (" + FromDate.ToString("dd.MM.yyyy") + " to " + ToDate.ToString("dd.MM.yyyy") + ") ";

            string sFilePDF = HttpContext.Current.Server.MapPath("~/Files/PDF") + "\\SFR_Individual.pdf";

            Document document = new Document(PageSize.A4, 50, 50, 30, 30);

            try
            {
                PdfWriter writer = PdfWriter.GetInstance(document,
                                 new FileStream(sFilePDF, FileMode.Create));

                document.Open();
                //Paragraph paragraph = new Paragraph(" ");
                //document.Add(paragraph);

                for (int i = 0; i < dt.Rows.Count; i++)
                {
                    int MemberId = int.Parse(dt.Rows[i]["MemberId"].ToString());
                    double TotalAmount = 0.00;
                    string result = AttendanceMgr.GetTotAmtByMemberId(MemberId, FromDate, ToDate).Rows[0]["TOTAMT"].ToString();

                    if (result != string.Empty)
                        TotalAmount = Convert.ToDouble(result);

                    if (TotalAmount != 0)
                    {
                        DataTable dtMember = MemberMgr.GetMemberDTbyMemberId(MemberId);

                        document.Add((PDFUtilities.PrintCompanyLogo()));

                        string strCert = string.Empty;
                        strCert += "<table style='width:100%; font-family:Times; font-size:12'>";

                        strCert += "<tr><td style='text-align:right;'>";
                        strCert += DateTime.Now.ToString("MMMM dd, yyyy");
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:left;'>";
                        strCert += "To";
                        strCert += "<br />";
                        strCert += "Shri. " + dtMember.Rows[0]["MemberName"].ToString();
                        strCert += "<br />";
                        strCert += dtMember.Rows[0]["DesignationName"].ToString();
                        strCert += "<br />";
                        if (dtMember.Rows[0]["Address1"].ToString().Trim() != string.Empty)
                            strCert += dtMember.Rows[0]["Address1"].ToString() + "<br />";
                        if (dtMember.Rows[0]["Address2"].ToString().Trim() != string.Empty)
                            strCert += dtMember.Rows[0]["Address2"].ToString() + "<br />";
                        if (dtMember.Rows[0]["Address3"].ToString().Trim() != string.Empty)
                            strCert += dtMember.Rows[0]["Address3"].ToString() + "<br />";
                        if (dtMember.Rows[0]["CityName"].ToString().Trim() != string.Empty)
                            strCert += dtMember.Rows[0]["CityName"].ToString();
                        if (dtMember.Rows[0]["PinCode"].ToString().Trim() != string.Empty)
                            strCert += " - " + dtMember.Rows[0]["PinCode"].ToString();
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:left;'>";
                        strCert += "Dear Sir,";
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:center;'>";
                        strCert += "Sub: Certificate of Sitting Fees paid during " + FinancialYear;
                        strCert += "<br />";
                        strCert += "*****";
                        strCert += "</td></tr>";

                        string para = string.Empty;
                        para += "We are enclosing herewith a certificate for Sitting Fees paid to you, during the Financial Year " + FinancialYear + DatePeriod;
                        para += " for attending the Bank's Board / Committee meeting(s) to enable you to file the Tax Return, if any, with the ";
                        para += "Income Tax Department for the previous financial year.";

                        strCert += "<tr><td style='text-align:justify;'>";
                        strCert += para;
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:justify;'>";
                        strCert += "Thanking You,";
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:left;'>";
                        strCert += "Yours faithfully,<br />";
                        strCert += "For The Lakshmi Vilas Bank Ltd.,";
                        strCert += "<br />";
                        strCert += "<br />";
                        strCert += AuthorityPersion;
                        strCert += "<br />";
                        strCert += AuthorityPersionDesign;
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:justify;'>";
                        strCert += "Encl.:  As above (in duplicate)";
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:justify;'>";
                        strCert += "--------------------------------------------------------------------------------------------------------------------------";
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:center;'>";
                        strCert += "<b>The Lakshmi Vilas Bank Limited</b>";
                        strCert += "<br />";
                        strCert += "Regd. & Admn. Office: Salem Road, Kathaparai, Karur - 639 006.";
                        strCert += "<br />";
                        strCert += "<b><u>CERTIFICATE</u></b>";
                        strCert += "</td></tr>";

                        strCert += "<tr><td style='text-align:justify;'>";
                        strCert += "This is to certify that we have paid to Shri. " + dtMember.Rows[0]["MemberName"].ToString() + ", ";
                        strCert += dtMember.Rows[0]["DesignationName"].ToString() + " of our Bank sum of Rs." + TotalAmount.ToString("N0") + "/-";
                        strCert += " toward Sitting Fees during the financial year " + FinancialYear + DatePeriod;
                        strCert += " for attending the Bank's Board / Committee meeting(s).";
                        strCert += "<br /><br />";
                        strCert += "For The Lakshmi Vilas Bank Ltd.,";
                        strCert += "<br />";
                        strCert += "<br />";
                        strCert += AuthorityPersion;
                        strCert += "<br />";
                        strCert += AuthorityPersionDesign;
                        strCert += "<br />";
                        strCert += "_________________________________________________________________________________";
                        strCert += "</td></tr>";
                        strCert += "<tr><td style='text-align:left; font-size:10pt; line-height:12px;'>";
                        strCert += "<b>The Lakshmi Vilas Bank Ltd.,</b> Regd, & Admin. Office, Salem Road, Kathaparai, Karur-639006.";
                        strCert += "<br />Phone: 04324-220051-60 Fax: 223607, E-Mail: secretarial@lvbank.in";
                        strCert += "</td></tr>";

                        strCert += "</table>";

                        PDFUtilities.AddHTMLText(document, strCert);

                        document.NewPage();

                        strCert = string.Empty;
                        strCert += "<table style='width:100%; font-family:Times; font-size:12'>";

                        strCert += "<tr><td style='text-align:center;'>";
                        strCert += "<b>Board & Committee Meeting Sitting Fees - " + FinancialYear + "</b><br /><br />";
                        strCert += "<b>" + dtMember.Rows[0]["MemberName"].ToString() + ", " + dtMember.Rows[0]["DesignationName"].ToString();
                        strCert += "</b><br /><br />";
                        strCert += "</td></tr>";

                        strCert += "</table>";

                        PDFUtilities.AddHTMLText(document, strCert);

                        DataTable dtAttendanceMember = AttendanceMgr.GetAttendanceByMemberId(MemberId, FromDate, ToDate);
                        DataTable dtAttendanceMemberC = new DataTable();
                        DataTable dtAttendanceMemberB = new DataTable();

                        DataView dv1 = new DataView(dtAttendanceMember);
                        dv1.RowFilter = "Board = 0";
                        dtAttendanceMemberC = dv1.ToTable("dtAttendanceMember");

                        DataView dv2 = new DataView(dtAttendanceMember);
                        dv2.RowFilter = "Board = 1";
                        dtAttendanceMemberB = dv2.ToTable("dtAttendanceMember");

                        double committeeTotFee = 0;
                        double boardTotFee = 0;

                        if (dtAttendanceMemberC.Rows.Count > 0)
                            committeeTotFee = BindSitFeeTable("committee", document, dtAttendanceMemberC);

                        Paragraph paragraph = new Paragraph(" ");

                        if (dtAttendanceMemberB.Rows.Count > 0)
                        {
                            paragraph = new Paragraph(" ");
                            document.Add(paragraph);
                            boardTotFee = BindSitFeeTable("board", document, dtAttendanceMemberB);
                        }


                        paragraph = new Paragraph(" ");
                        document.Add(paragraph);

                        Table table = new Table(2);
                        table.Padding = 2;
                        table.Spacing = 0;

                        float[] headerwidths = new float[2]; // = { 9, 4, 8, 10, 8, 11, 9, 7, 9, 10, 4, 10 }; // percentage

                        headerwidths[0] = 50.0f;
                        headerwidths[1] = 50.0f;

                        table.Widths = headerwidths;
                        table.WidthPercentage = 50;

                        Cell cell = new Cell(new Phrase("Board", font10B));
                        cell.Header = false;
                        cell.BorderWidth = 0.5f;
                        cell.HorizontalAlignment = Element.ALIGN_LEFT;
                        cell.VerticalAlignment = Element.ALIGN_CENTER;
                        table.AddCell(cell);

                        cell = new Cell(new Phrase(boardTotFee.ToString("N0"), font10N));
                        cell.Header = true;
                        cell.BorderWidth = 0.5f;
                        cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                        cell.VerticalAlignment = Element.ALIGN_TOP;
                        table.AddCell(cell);

                        cell = new Cell(new Phrase("Committee", font10B));
                        cell.Header = true;
                        cell.BorderWidth = 0.5f;
                        cell.HorizontalAlignment = Element.ALIGN_LEFT;
                        cell.VerticalAlignment = Element.ALIGN_TOP;
                        table.AddCell(cell);

                        cell = new Cell(new Phrase(committeeTotFee.ToString("N0"), font10N));
                        cell.Header = true;
                        cell.BorderWidth = 0.5f;
                        cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                        cell.VerticalAlignment = Element.ALIGN_TOP;
                        table.AddCell(cell);

                        cell = new Cell(new Phrase("Total Sitting Fees paid", font10B));
                        cell.Header = true;
                        cell.BorderWidth = 0.5f;
                        cell.HorizontalAlignment = Element.ALIGN_LEFT;
                        cell.VerticalAlignment = Element.ALIGN_TOP;
                        table.AddCell(cell);

                        double totSitFee = committeeTotFee + boardTotFee;

                        cell = new Cell(new Phrase(totSitFee.ToString("N0"), font10B));
                        cell.Header = true;
                        cell.BorderWidth = 0.5f;
                        cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                        cell.VerticalAlignment = Element.ALIGN_TOP;
                        table.AddCell(cell);

                        document.Add(table);

                        document.NewPage();
                    }
                }

            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "GenerateSittingFeeIndividual", ex);
            }
            finally
            {
                document.Close();
            }

        }
        #endregion

        #region BindSitFeeTable
        private static double BindSitFeeTable(string code, Document document, DataTable dt)
        {
            double totAmt = 0;

            Table table = new Table(4);
            table.Padding = 2;
            table.Spacing = 0;

            float[] headerwidths = new float[4]; // = { 9, 4, 8, 10, 8, 11, 9, 7, 9, 10, 4, 10 }; // percentage

            if (code == "committee")
                headerwidths[0] = 55.0f;
            if (code == "board")
                headerwidths[0] = 20.0f;

            headerwidths[1] = 15.0f;
            headerwidths[2] = 15.0f;
            headerwidths[3] = 15.0f;

            table.Widths = headerwidths;

            if (code == "committee")
                table.WidthPercentage = 80;
            if (code == "board")
                table.WidthPercentage = 60;

            //table.BorderWidth = 0.5f;

            Cell cell = null;

            if (code == "committee")
                cell = new Cell(new Phrase("Name of the Committee", font10B));
            if (code == "board")
                cell = new Cell(new Phrase("Board No.", font10B));
            cell.Header = true;
            cell.BorderWidth = 0.5f;
            cell.HorizontalAlignment = Element.ALIGN_CENTER;
            cell.VerticalAlignment = Element.ALIGN_MIDDLE;
            table.AddCell(cell);

            cell = new Cell(new Phrase("Date", font10B));
            cell.Header = true;
            cell.BorderWidth = 0.5f;
            cell.HorizontalAlignment = Element.ALIGN_CENTER;
            cell.VerticalAlignment = Element.ALIGN_MIDDLE;
            table.AddCell(cell);

            cell = new Cell(new Phrase("Place", font10B));
            cell.Header = true;
            cell.BorderWidth = 0.5f;
            cell.HorizontalAlignment = Element.ALIGN_CENTER;
            cell.VerticalAlignment = Element.ALIGN_MIDDLE;
            table.AddCell(cell);

            cell = new Cell(new Phrase("Rs.", font10B));
            cell.Header = true;
            cell.BorderWidth = 0.5f;
            cell.HorizontalAlignment = Element.ALIGN_CENTER;
            cell.VerticalAlignment = Element.ALIGN_MIDDLE;
            table.AddCell(cell);

            table.EndHeaders();

            for (int r = 0; r < dt.Rows.Count; r++)
            {
                if (code == "committee")
                    cell = new Cell(new Phrase(dt.Rows[r]["CommitteeName"].ToString(), font10N));
                if (code == "board")
                    cell = new Cell(new Phrase(dt.Rows[r]["MeetingNo"].ToString(), font10N));

                cell.Header = false;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_LEFT;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase(Convert.ToDateTime(dt.Rows[r]["MeetingDate"].ToString()).ToString("dd.MM.yyyy"), font10N));
                cell.Header = false;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase(dt.Rows[r]["Place"].ToString(), font10N));
                cell.Header = false;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_LEFT;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase(Convert.ToDouble(dt.Rows[r]["SittingFees"].ToString()).ToString("N0"), font10N));
                cell.Header = false;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                totAmt += Convert.ToDouble(dt.Rows[r]["SittingFees"].ToString());
            }

            cell = new Cell(new Phrase("", font10N));
            cell.Header = false;
            cell.BorderWidth = 0.5f;
            cell.HorizontalAlignment = Element.ALIGN_RIGHT;
            cell.VerticalAlignment = Element.ALIGN_MIDDLE;
            table.AddCell(cell);

            cell = new Cell(new Phrase("", font10N));
            cell.Header = false;
            cell.BorderWidth = 0.5f;
            cell.HorizontalAlignment = Element.ALIGN_RIGHT;
            cell.VerticalAlignment = Element.ALIGN_MIDDLE;
            table.AddCell(cell);

            cell = new Cell(new Phrase("TOTAL", font10B));
            cell.Header = false;
            cell.BorderWidth = 0.5f;
            cell.HorizontalAlignment = Element.ALIGN_RIGHT;
            cell.VerticalAlignment = Element.ALIGN_MIDDLE;
            table.AddCell(cell);

            cell = new Cell(new Phrase(totAmt.ToString("N0"), font10B));
            cell.Header = false;
            cell.BorderWidth = 0.5f;
            cell.HorizontalAlignment = Element.ALIGN_RIGHT;
            cell.VerticalAlignment = Element.ALIGN_MIDDLE;
            table.AddCell(cell);

            document.Add(table);

            return totAmt;

        }
        #endregion

        #region GenerateSittingFeeDesignation
        public static void GenerateSittingFeeDesignation(DataTable dt, DateTime FromDate, DateTime ToDate, string AuthorityPersion,
            string AuthorityPersionDesign)
        {

            double TotalAmount = 0.00;
            string FinancialYear = FromDate.ToString("yyyy") + "-" + ToDate.ToString("yyyy");
            string DatePeriod = " (" + FromDate.ToString("dd.MM.yyyy") + " to " + ToDate.ToString("dd.MM.yyyy") + ") ";

            string sFilePDF = HttpContext.Current.Server.MapPath("~/Files/PDF") + "\\SFR_Designation.pdf";

            Document document = new Document(PageSize.A4, 50, 50, 30, 30);

            try
            {
                PdfWriter writer = PdfWriter.GetInstance(document,
                                 new FileStream(sFilePDF, FileMode.Create));

                document.Open();
                Paragraph paragraph = new Paragraph(" ");
                document.Add(paragraph);

                Font font11B = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 11, Font.BOLD);
                Font font11N = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 11, Font.NORMAL);
                Font font12U = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 12, Font.UNDERLINE);

                document.Add((PDFUtilities.PrintCompanyLogo()));

                paragraph = new Paragraph(new Phrase(DateTime.Now.ToString("MMMM dd, yyyy"), font11N));
                paragraph.Alignment = Element.ALIGN_RIGHT;
                document.Add(paragraph);

                document.Add(new Paragraph(Environment.NewLine));

                document.Add(new Paragraph(new Phrase("To", font11N)));
                document.Add(new Paragraph(new Phrase("The Chief Manager,", font11N)));
                document.Add(new Paragraph(new Phrase("Accounts Department.", font11N)));

                document.Add(new Paragraph(Environment.NewLine));

                document.Add(new Paragraph(new Phrase("Dear Sir,", font11N)));

                paragraph = new Paragraph(new Phrase("Sub : Payment of Sitting Fees of the " + dt.Rows[0]["DesignationName"].ToString() + " during " + FinancialYear + ".", font11N));
                paragraph.Alignment = Element.ALIGN_CENTER;
                document.Add(paragraph);

                paragraph = new Paragraph(new Phrase("*****", font11N));
                paragraph.Alignment = Element.ALIGN_CENTER;
                document.Add(paragraph);

                Table table = new Table(3);
                table.Padding = 2;
                table.Spacing = 0;

                float[] headerwidths = new float[3]; // = { 9, 4, 8, 10, 8, 11, 9, 7, 9, 10, 4, 10 }; // percentage

                headerwidths[0] = 15.0f;
                headerwidths[1] = 60.0f;
                headerwidths[2] = 25.0f;

                table.Widths = headerwidths;

                table.WidthPercentage = 80;

                table.BorderWidth = 0.5f;

                Cell cell = null;

                cell = new Cell(new Phrase("Sl. No.", font10B));
                cell.Header = true;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase("Name of the " + dt.Rows[0]["DesignationName"].ToString() + "(Sarvashree)", font10B));
                cell.Header = true;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase("Amount", font10B));
                cell.Header = true;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                table.EndHeaders();

                double totAmt = 0;

                for (int i = 0; i < dt.Rows.Count; i++)
                {
                    cell = new Cell(new Phrase((i + 1) + ".", font10N));
                    cell.Header = false;
                    cell.BorderWidth = 0.5f;
                    cell.HorizontalAlignment = Element.ALIGN_CENTER;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);

                    cell = new Cell(new Phrase(dt.Rows[i]["MemberName"].ToString(), font10N));
                    cell.Header = false;
                    cell.BorderWidth = 0.5f;
                    cell.HorizontalAlignment = Element.ALIGN_LEFT;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);

                    if (dt.Rows[i]["TOTAMT"].ToString().Trim() != string.Empty)
                        cell = new Cell(new Phrase(Convert.ToDouble(dt.Rows[i]["TOTAMT"].ToString()).ToString("N0"), font10N));
                    else
                        cell = new Cell(new Phrase("", font10N));
                    cell.Header = false;
                    cell.BorderWidth = 0.5f;
                    cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);

                    if (dt.Rows[i]["TOTAMT"].ToString().Trim() != string.Empty)
                        totAmt += Convert.ToDouble(dt.Rows[i]["TOTAMT"].ToString());

                }

                cell = new Cell(new Phrase("", font10N));
                cell.Header = false;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase("TOTAL", font10B));
                cell.Header = false;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase(totAmt.ToString("N0"), font10B));
                cell.Header = false;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                document.Add(table);


                paragraph = new Paragraph(new Phrase("", font11N));
                paragraph.Alignment = Element.ALIGN_JUSTIFIED;
                document.Add(paragraph);

                document.Add(new Paragraph(Environment.NewLine));
                document.Add(new Paragraph(new Phrase("This is for your kind information.", font11N)));
                document.Add(new Paragraph(Environment.NewLine));
                document.Add(new Paragraph(new Phrase("Yours faithfully,", font11N)));
                document.Add(new Paragraph(new Phrase("For The Lakshmi Vilas Bank Ltd.,", font11N)));
                document.Add(new Paragraph(Environment.NewLine));
                document.Add(new Paragraph(Environment.NewLine));
                document.Add(new Paragraph(new Phrase(AuthorityPersion, font11N)));
                document.Add(new Paragraph(new Phrase(AuthorityPersionDesign, font11N)));
                document.Add(new Paragraph(Environment.NewLine));

                document.NewPage();

            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "GenerateSittingFeeDesignation", ex);
            }
            finally
            {
                document.Close();
            }

        }
        #endregion

        #region GenerateSittingFeeConsolidated
        public static void GenerateSittingFeeConsolidated(DataTable dtMeeting, DataTable dtMember, DateTime FromDate, DateTime ToDate, string AuthorityPersion,
            string AuthorityPersionDesign)
        {

            double TotalAmount = 0.00;
            string FinancialYear = FromDate.ToString("yyyy") + "-" + ToDate.ToString("yyyy");
            string DatePeriod = " (" + FromDate.ToString("dd.MM.yyyy") + " to " + ToDate.ToString("dd.MM.yyyy") + ") ";

            string sFilePDF = HttpContext.Current.Server.MapPath("~/Files/PDF") + "\\SFR_Consolidated.pdf";

            Document document = new Document(PageSize.A4.Rotate(), 50, 50, 50, 50);

            try
            {
                PdfWriter writer = PdfWriter.GetInstance(document,
                                 new FileStream(sFilePDF, FileMode.Create));

                document.Open();
                Paragraph paragraph = new Paragraph(" ");
                document.Add(paragraph);

                Font font11B = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 11, Font.BOLD);
                Font font11N = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 11, Font.NORMAL);
                Font font12U = FontFactory.GetFont(FontFactory.TIMES_ROMAN, 12, Font.UNDERLINE);

                document.Add((PDFUtilities.PrintCompanyLogo()));

                paragraph = new Paragraph(new Phrase(DateTime.Now.ToString("MMMM dd, yyyy"), font11N));
                paragraph.Alignment = Element.ALIGN_RIGHT;
                document.Add(paragraph);

                document.Add(new Paragraph(Environment.NewLine));

                document.Add(new Paragraph(new Phrase("Committee / Board Sitting Fees from " + FromDate.ToString("dd.MM.yyyy") + " to " + ToDate.ToString("dd.MM.yyyy"), font11N)));

                document.Add(new Paragraph(Environment.NewLine));

                int ColCount = 3 + dtMember.Rows.Count;

                Table table = new Table(ColCount);
                table.Padding = 2;
                table.Spacing = 0;

                float[] headerwidths = new float[ColCount]; // = { 9, 4, 8, 10, 8, 11, 9, 7, 9, 10, 4, 10 }; // percentage

                headerwidths[0] = 15.0f;
                headerwidths[1] = 10.0f;
                headerwidths[2] = 10.0f;

                for (int i = 0; i < dtMember.Rows.Count; i++)
                    headerwidths[i + 3] = 65.0f / (float.Parse(ColCount.ToString()) - 3.0f);

                table.Widths = headerwidths;

                table.WidthPercentage = 100;

                table.BorderWidth = 0.5f;

                Cell cell = null;

                cell = new Cell(new Phrase("Name of the Committee", font10B));
                cell.Header = true;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase("Date", font10B));
                cell.Header = true;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                cell = new Cell(new Phrase("Place", font10B));
                cell.Header = true;
                cell.BorderWidth = 0.5f;
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                table.AddCell(cell);

                for (int i = 0; i < dtMember.Rows.Count; i++)
                {
                    cell = new Cell(new Phrase(dtMember.Rows[i]["MemberName"].ToString(), font10B));
                    cell.Header = true;
                    cell.BorderWidth = 0.5f;
                    cell.HorizontalAlignment = Element.ALIGN_CENTER;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);
                }


                table.EndHeaders();

                double totAmt = 0;

                for (int i = 0; i < dtMeeting.Rows.Count; i++)
                {
                    int MeetingId = int.Parse(dtMeeting.Rows[i]["MeetingId"].ToString());

                    cell = new Cell(new Phrase(dtMeeting.Rows[i]["CommitteeName"].ToString(), font10N));
                    cell.Header = false;
                    cell.BorderWidth = 0.5f;
                    cell.HorizontalAlignment = Element.ALIGN_LEFT;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);

                    cell = new Cell(new Phrase(Convert.ToDateTime(dtMeeting.Rows[i]["MeetingDate"].ToString()).ToString("dd.MM.yyyy"), font10N));
                    cell.Header = false;
                    cell.BorderWidth = 0.5f;
                    cell.HorizontalAlignment = Element.ALIGN_LEFT;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);

                    cell = new Cell(new Phrase(dtMeeting.Rows[i]["Place"].ToString(), font10N));
                    cell.Header = false;
                    cell.BorderWidth = 0.5f;
                    cell.HorizontalAlignment = Element.ALIGN_LEFT;
                    cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                    table.AddCell(cell);

                    DataTable dtAttendance = AttendanceMgr.GetAttendanceByMeetingId(MeetingId, "C");

                    for (int j = 0; j < dtMember.Rows.Count; j++)
                    {
                        int MemberId = int.Parse(dtMember.Rows[j]["MemberId"].ToString());

                        DataRow[] foundRows;
                        foundRows = dtAttendance.Select("MemberId = " + MemberId);

                        string FeesAmt = "-";
                        if (foundRows.Length > 0)
                            FeesAmt = foundRows[0]["SittingFees"].ToString();

                        cell = new Cell(new Phrase(FeesAmt, font10B));
                        cell.Header = true;
                        cell.BorderWidth = 0.5f;
                        cell.HorizontalAlignment = Element.ALIGN_RIGHT;
                        cell.VerticalAlignment = Element.ALIGN_MIDDLE;
                        table.AddCell(cell);
                    }
                    //if (dt.Rows[i]["TOTAMT"].ToString().Trim() != string.Empty)
                    //    totAmt += Convert.ToDouble(dt.Rows[i]["TOTAMT"].ToString());

                }

                document.Add(table);

                document.NewPage();

            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "GenerateSittingFeeConsolidated", ex);
            }
            finally
            {
                document.Close();
            }

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
