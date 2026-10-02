using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Web;
using System.Web.UI.WebControls;
using System.Data;
using BMMSDAL;
using System.Net;

namespace BMMSBAL
{
    public class Utilities
    {

        #region ConvertOrdinalValue
        public static string ConvertOrdinalValue(int value)
        {
            string strOutput = string.Empty;
            string chkVal = value.ToString().Substring(value.ToString().Length - 1, 1);
            switch (chkVal)
            {
                case "1":
                    strOutput = value.ToString() + "st";
                    break;
                case "2":
                    strOutput = value.ToString() + "nd";
                    break;
                case "3":
                    strOutput = value.ToString() + "rd";
                    break;
                default:
                    strOutput = value.ToString() + "th";
                    break;
            }
            return strOutput;
        }
        #endregion

        #region GoToErrPage
        public static void GoToErrPage(string ClassName, string MethodName, Exception ErrMsg)
        {
            WriteErrorLog(ClassName, MethodName, ErrMsg.ToString());
            HttpContext.Current.Session["ErrMsg"] = ErrMsg.Message;
            string _ErrMsg = Common.GetAppSetting("CommonErrMsg");
            HttpContext.Current.Response.Redirect(@"~/Error/ErrorPage.aspx?Error=" + _ErrMsg, false);
        }
        #endregion

        #region WriteErrorLog
        public static void WriteErrorLog(string ClassName, string MethodName, string ErrorMessage)
        {
            StreamWriter SW = null;
            try
            {
                if (!Directory.Exists(AppDomain.CurrentDomain.BaseDirectory + "Log"))
                    Directory.CreateDirectory(AppDomain.CurrentDomain.BaseDirectory + "Log");

                string _FileName = DateTime.Now.ToString("yyyy_MM_dd") + "_ErrorLog";
                string _FilePath = AppDomain.CurrentDomain.BaseDirectory + "Log\\" + _FileName + ".txt";

                if (!File.Exists(_FilePath))
                    File.Create(_FilePath);

                SW = File.AppendText(_FilePath);
                string _LineRow = "-".PadRight(125, '-');
                SW.WriteLine(_LineRow);
                SW.WriteLine("Date & Time : " + DateTime.Now.ToLongDateString() + " " + DateTime.Now.ToLongTimeString());
                SW.WriteLine("Class  Name : " + ClassName);
                SW.WriteLine("Method Name : " + MethodName);
                SW.WriteLine("Description : " + ErrorMessage);
                SW.WriteLine(_LineRow);
                SW.Close();
            }
            catch (Exception ex)
            {
                ErrorMessage = ex.Message;
            }
            finally
            {
                if (SW != null)
                    SW.Dispose();
            }
        }
        #endregion

        #region GridViewDataTableSorting
        public static DataTable GridViewDataTableSorting(object sender, GridViewSortEventArgs e, DataTable dt)
        {
            GridView gvtemp = (GridView)sender;
            string strSort = string.Empty;

            for (int i = 0; i < gvtemp.Columns.Count; i++)
            {
                if (gvtemp.Columns[i].SortExpression.Equals(e.SortExpression))
                {
                    if (gvtemp.Columns[i].HeaderStyle.CssClass == "ascending")
                    {
                        gvtemp.Columns[i].HeaderStyle.CssClass = "descending";
                        strSort = e.SortExpression + " DESC";
                    }
                    else
                    {
                        gvtemp.Columns[i].HeaderStyle.CssClass = "ascending";
                        strSort = e.SortExpression + " ASC";
                    }
                }
                else
                {
                    gvtemp.Columns[i].HeaderStyle.CssClass = "";
                }
            }

            dt.DefaultView.Sort = strSort;

            e.Cancel = true;

            return dt;
        }
        #endregion

        #region ResetDatabase
        public static int ResetDatabase()
        {
            return UtilitiesDB.ResetDatabase();
        }
        #endregion

        #region GetSMTPMaster
        public static DataTable GetSMTPMaster()
        {
            return UtilitiesDB.GetSMTPMaster();
        }
        #endregion

        #region GetStateMaster
        public static DataTable GetStateMaster()
        {
            return UtilitiesDB.GetStateMaster();
        }
        #endregion

        #region UpdateSMTPMaster
        public static DataTable UpdateSMTPMaster(string SMTPServer, string SMTPServerPort,
            string UserName, string Password, string FromMailId, string Bcc)
        {
            return UtilitiesDB.UpdateSMTPMaster(SMTPServer, SMTPServerPort,
                UserName, Password, FromMailId, Bcc);
        }
        #endregion

        #region AddEditAuditTrialLogin
        public static int AddEditAuditTrialLogin(int UserId)
        {
            return UtilitiesDB.AddEditAuditTrialLogin(UserId);
        }
        #endregion

        #region GetLocalIPAddress
        public static string GetLocalIPAddress()
        {
            string LocalIPAddress = string.Empty;
            string strHostName = Dns.GetHostName();

            // Then using host name, get the IP address list..
            IPHostEntry ipEntry = Dns.GetHostByName(strHostName);
            IPAddress[] addr = ipEntry.AddressList;

            for (int i = 0; i < addr.Length; i++)
            {
                LocalIPAddress = addr[i].ToString();
            }

            return LocalIPAddress;
        }
        #endregion
    }
}
