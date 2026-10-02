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

namespace BMMS.Report
{
    public partial class EventCalendar : System.Web.UI.Page
    {
        private string className = "EventCalendar";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                txtFromDate.Text = System.DateTime.Now.ToString("dd-MMM-yyyy");
                txtToDate.Text = System.DateTime.Now.ToString("dd-MMM-yyyy");
                BindEventCalendar();
            }

        }


        #region BindEventCalendar
        private void BindEventCalendar()
        {
            try
            {
                DataTable dtMonths = new DataTable();
                dtMonths.Columns.Add("Date");
                dtMonths.Columns.Add("EventName");
                dtMonths.Columns.Add("CommitteeName");
                dtMonths.Columns.Add("MeetingNo");
                dtMonths.Columns.Add("MeetingDate");
                dtMonths.Columns.Add("MeetingTime");

                DateTime startDate = Convert.ToDateTime("01-Oct-2010");
                DateTime endDate = startDate.AddMonths(1);

                for (DateTime date = startDate; date < endDate; date.AddDays(1))
                {
                    DataRow dr = dtMonths.NewRow();

                    dr["Date"] = "";
                    dr["EventName"] = "";
                    dr["CommitteeName"] = "";
                    dr["MeetingNo"] = "";
                    dr["MeetingDate"] = "";
                    dr["MeetingTime"] = "";
                    //dr[""] = "";
                    //dr[""] = "";
                    //dr[""] = "";
                }



                DataTable dtEventCalendar = new DataTable();

                dtEventCalendar.Columns.Add("Sunday");
                dtEventCalendar.Columns.Add("Monday");
                dtEventCalendar.Columns.Add("Tuesday");
                dtEventCalendar.Columns.Add("Wednesday");
                dtEventCalendar.Columns.Add("Thursday");
                dtEventCalendar.Columns.Add("Friday");
                dtEventCalendar.Columns.Add("Saturday");

                int j = 0;
                for (int week = 1; week <= 6; week++)
                {
                    DataRow dr = dtEventCalendar.NewRow();

                    for (int dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++)
                    {
                        string strMon = "-";
                        if (j < dtMonths.Rows.Count)
                            strMon = Convert.ToDateTime(dtMonths.Rows[j]["AttendanceDate"].ToString()).DayOfWeek.ToString();

                        if (dtEventCalendar.Columns[dayOfWeek].Caption == strMon)
                        {

                            dr[dayOfWeek] = "<br />" +
                                Convert.ToDateTime(dtMonths.Rows[j]["AttendanceDate"].ToString()).ToString("dd-MMM-yyyy") +
                                "<br /><br /><b>" +
                                dtMonths.Rows[j]["ShiftName"].ToString() + "</b><br />";

                            j += 1;
                        }
                        else
                        {
                            dr[dayOfWeek] = "-";
                            if (week == 4 || week == 5)
                            {
                                dr[dayOfWeek] = "-";
                                week = 7;
                            }
                        }
                    }
                    dtEventCalendar.Rows.Add(dr);
                }

                grvEventCalendar.DataSource = dtEventCalendar;
                grvEventCalendar.DataBind();

            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindEventCalendar", ex);
            }
            finally
            {

            }
        }
        #endregion

        

        #region btnSubmit_Click
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            grvEventCalendar.Visible = true;
            BindEventCalendar();
        }
        #endregion
    }
}
