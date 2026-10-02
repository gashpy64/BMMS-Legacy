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
    public partial class ReportPrint : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (Session["ViewReport"] != null)
                ltrlReportPrint.Text = Session["ViewReport"].ToString();
            else
                ltrlReportPrint.Text = "--------------------";
        }
    }
}
