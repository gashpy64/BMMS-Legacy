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

namespace BMMS.Error
{
    public partial class TestPage : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            string sFilePDF = Server.MapPath("~/Files/PDF") + "\\Test.pdf";
            string sFileCSS = Server.MapPath("~/Files/PDF") + "\\pdf.css";

            PDFUtilities.GenerateHTMLPdf(sFilePDF, sFileCSS);

        }
    }
}
