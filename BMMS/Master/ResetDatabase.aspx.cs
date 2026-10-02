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

namespace BMMS.Master
{
    public partial class ResetDatabase : System.Web.UI.Page
    {
        private string className = "MinutesFinalization";

        protected void Page_Load(object sender, EventArgs e)
        {
            
        }

        protected void btnResetDatabase_Click(object sender, EventArgs e)
        {
            Utilities.ResetDatabase();

            Response.Redirect(@"~/Default.aspx", false);
        }

    }
}
