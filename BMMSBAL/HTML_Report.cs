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
