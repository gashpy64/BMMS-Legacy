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

namespace BMMS.UserControl
{
    public partial class MeetingSummary : System.Web.UI.UserControl
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            DataTable dtMeetingScheduled = new DataTable();
            dtMeetingScheduled = MeetingMgr.GetScheduleMeet("Scheduled");

            if (dtMeetingScheduled.Rows.Count <= 0)
                dtMeetingScheduled = CreateEmptyMeet();

            grvMeetSchedule.DataSource = dtMeetingScheduled;
            grvMeetSchedule.DataBind();
            


            DataTable dtMeetingCompleted = new DataTable();
            dtMeetingCompleted = MeetingMgr.GetScheduleMeet("Completed");

            if (dtMeetingCompleted.Rows.Count <= 0)
                dtMeetingCompleted = CreateEmptyMeet();

            grvCompleteMeet.DataSource = dtMeetingCompleted;
            grvCompleteMeet.DataBind();
        }


        private DataTable CreateEmptyMeet()
        {
            DataTable dt = new DataTable();
            dt.Columns.Add("CommitteeName");
            dt.Columns.Add("MeetingNo");
            dt.Columns.Add("MeetingId");
            dt.Columns.Add("MeetingDate");
            dt.Columns.Add("MeetingTime");

            DataRow dr = dt.NewRow();
            dr["CommitteeName"] = "";
            dr["MeetingNo"] = "";
            dr["MeetingId"] = "0";
            dr["MeetingDate"] = "";
            dr["MeetingTime"] = "";

            dt.Rows.Add(dr);

            return dt;
        }
    }
}