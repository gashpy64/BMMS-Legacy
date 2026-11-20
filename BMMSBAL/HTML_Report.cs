using System;
using System.Collections.Generic;
using System.Text;
using System.Security.Cryptography;
using System.Web.UI.WebControls;
using System.Data;
using System.Web;
using System.Xml;
using BMMSDAL;
using System.Data.SqlClient;

namespace BMMSBAL
{
    public class HTML_Report
    {

        #region ReplaceRichTextFont
        public static string ReplaceRichTextFont(string givenText)
        {
            //border-width: 1pt; padding: 0in; font-size: 11pt; border-color: windowtext; color: purple; font-family: 'Times New Roman','';

            givenText = givenText.Trim();

            givenText = givenText.Replace("font-family:", "fff:");

            givenText = givenText.Replace("font-size:", "fsss:");

            givenText = givenText.Replace("color:", "ccc:");

            givenText = givenText.Replace("line-height:", "llhh:");


            givenText = givenText.Replace("FONT-FAMILY:", "fff:");

            givenText = givenText.Replace("FONT-SIZE:", "fsss:");

            givenText = givenText.Replace("COLOR:", "ccc:");

            givenText = givenText.Replace("LINE-HEIGHT:", "llhh:");

            givenText = givenText.Replace("<font face=", "<font SSSS=");
            givenText = givenText.Replace("<font size=", "<font ssss=");

            givenText = givenText.Replace("<FONT FACE=", "<font SSSS=");
            givenText = givenText.Replace("<FONT SIZE=", "<font ssss=");

            givenText = givenText.Replace("<FONT face=", "<font SSSS=");
            givenText = givenText.Replace("<FONT size=", "<font ssss=");

            givenText = givenText.Replace("<font FACE=", "<font SSSS=");
            givenText = givenText.Replace("<font SIZE=", "<font ssss=");

            //givenText = givenText.Replace("Trebuchet MS", "Times New Roman");
            //givenText = givenText.Replace("sans-serif", "Times New Roman");
            //givenText = givenText.Replace("serif", "");
            //givenText = givenText.Replace("Century Gothic", "Times New Roman");


            //font-size: 11pt
            return givenText;
        }
        #endregion

        #region HTML_PageBreak
        #region Minutes status mark (step RA1b)
        // The minutes status of a meeting in the every-status reports of the Controller and Management
        // (BMMS-Fix-ReportAccess-Step41.sql gives the mark: Draft (not finalised), Finalised or Confirmed). Plain
        // text, and for a draft also a note in a one-cell table with a border: the PDF export (HTMLWorker) draws a
        // table border but not a div border, so the mark and the note stay in Print, Export to Pdf and Export to
        // Word. Black only, never colour alone.
        public const string DraftMark = "Draft (not finalised)";
        public const string DraftNoteText = "DRAFT - not finalised; this is not the approved text of the minutes.";

        public static bool IsDraftMark(string Mark)
        {
            return Mark == DraftMark;
        }

        public static string MinutesStatusLine(string Mark)
        {
            return "<div style='float:left; width:100%; font-size:12pt; font-weight:bold; padding-top:5px; padding-bottom:5px;'>"
                 + "Minutes status: " + HttpUtility.HtmlEncode(Mark) + "</div>";
        }

        public static string DraftNote()
        {
            return "<table width='100%' border='1' cellspacing='0' cellpadding='6' style='float:left; width:100%; border:2px solid #000000;"
                 + " border-collapse:collapse; margin-top:6px; margin-bottom:6px;'><tr>"
                 + "<td style='text-align:center; font-size:12pt; font-weight:bold;'>" + HttpUtility.HtmlEncode(DraftNoteText) + "</td>"
                 + "</tr></table>";
        }
        #endregion

        public static string HTML_PageBreak()
        {
            //htmlTxt += "<divbreak style='color:white'>.</divbreak>";
            //htmlTxt += "<h1 class='break'>text of Heading 1 on page 2</h1>";
            //htmlTxt += "<style>";
            //htmlTxt += "@media print";
            //htmlTxt += "{";
            //htmlTxt += "divbreak {page-break-after:always}";
            //htmlTxt += "}";
            //htmlTxt += "</style>";

            ////htmlTxt += "<style>";
            ////htmlTxt += ".break { page-break-before: always; }";
            ////htmlTxt += "</style>";

            return "<div style='float:left; page-break-before: always'>&nbsp;</div>";
        }
        #endregion
    }
}
