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
        // The error page shows a fixed text only (step E2): no exception message in the session and no text in
        // the address; the exception is in the error log. Its Exit button returns to the page that failed
        // (Session["ErrorReturnPage"], step E2b).
        public static void GoToErrPage(string ClassName, string MethodName, Exception ErrMsg)
        {
            WriteErrorLog(ClassName, MethodName, DescribeForLog(ErrMsg));
            RememberErrorReturnPage();
            HttpContext.Current.Response.Redirect(@"~/Error/ErrorPage.aspx", false);
        }
        #endregion

        #region ErrorReturnPage
        // The page Exit on Error/ErrorPage.aspx returns to (step E2b): the app-relative path of the page that
        // failed plus its original query string (~/Report/Reports.aspx?rc=minutes); no error text. Exit no longer
        // uses Session["PageURL"], which can be stale or (Department) wrong.
        public const string ErrorReturnPageKey = "ErrorReturnPage";

        // Stored only for a normal .aspx page; any other request clears it, so Exit goes to the Dashboard
        private static void RememberErrorReturnPage()
        {
            try
            {
                HttpContext context = HttpContext.Current;
                if (context.Session == null)
                    return;

                string path = context.Request.AppRelativeCurrentExecutionFilePath;
                if (IsReturnablePage(path))
                    context.Session[ErrorReturnPageKey] = path + context.Request.Url.Query;
                else
                    context.Session.Remove(ErrorReturnPageKey);
            }
            catch (Exception)
            {
            }
        }

        // A page Exit may return to: starts with ~/, a non-empty file name ending in .aspx, never the error page,
        // and nothing that could point to another site (// or \ or :). The error page also checks that the file
        // exists. AppRelativePath is without the query string.
        public static bool IsReturnablePage(string AppRelativePath)
        {
            if (string.IsNullOrEmpty(AppRelativePath) || !AppRelativePath.StartsWith("~/", StringComparison.Ordinal))
                return false;

            string rest = AppRelativePath.Substring(2);
            if (rest.Contains("//") || rest.Contains("\\") || rest.Contains(":") || rest.StartsWith("/", StringComparison.Ordinal))
                return false;

            string fileName = rest.Substring(rest.LastIndexOf('/') + 1);
            if (fileName.Length <= ".aspx".Length || !fileName.EndsWith(".aspx", StringComparison.OrdinalIgnoreCase))
                return false;

            return !string.Equals(AppRelativePath, "~/Error/ErrorPage.aspx", StringComparison.OrdinalIgnoreCase);
        }
        #endregion

        #region LogUnhandledError
        // Set on HttpContext.Items once an unhandled error of the request is in the log, so Application_Error
        // does not write a second entry for an error the E1 handler already logged (step E2)
        public const string ErrorLoggedKey = "BMMS.ErrorLogged";

        // An unhandled error (Application_Error, step E2; the E1 handler): one error log entry with the exception,
        // the page path (no query string) and the user id when a session exists. Form values (passwords, the mail
        // password) are never written; a request-validation value is replaced (DescribeForLog). Never throws:
        // it must not replace the error it reports.
        public static void LogUnhandledError(HttpContext Context, string ClassName, string MethodName, Exception Error)
        {
            try
            {
                string userId = (Context.Session != null && Context.Session["UserId"] != null)
                    ? Context.Session["UserId"].ToString() : "(none)";

                WriteErrorLog(ClassName, MethodName,
                    DescribeForLog(Error) + " | Page: " + Context.Request.Path + " | UserId: " + userId);

                Context.Items[ErrorLoggedKey] = true;
            }
            catch (Exception)
            {
            }
        }
        #endregion

        #region DescribeForLog
        public const string RedactedValue = "(value not logged)";

        // The text written to the error log for an exception: Exception.ToString(), except when request
        // validation refused a value. Its message quotes what the user typed
        // (... from the client (ctl00$ContentPlaceHolder1$txtUserName="<x").), so each message of the chain keeps
        // the field name and loses the value, and only types, messages and stack traces are written (step E2).
        private static string DescribeForLog(Exception Error)
        {
            if (Error == null)
                return "(no exception)";

            bool validation = false;
            for (Exception e = Error; e != null; e = e.InnerException)
                if (e is HttpRequestValidationException)
                    validation = true;

            if (!validation)
                return Error.ToString();

            StringBuilder text = new StringBuilder();
            for (Exception e = Error; e != null; e = e.InnerException)
            {
                if (text.Length > 0)
                    text.Append(Environment.NewLine + " ---> ");
                text.Append(e.GetType().FullName + ": " + RedactValidationValue(e.Message));
                if (e.StackTrace != null)
                    text.Append(Environment.NewLine + e.StackTrace);
            }
            return text.ToString();
        }

        // "... from the client (name="value")." -> "... from the client (name="(value not logged)")."
        private static string RedactValidationValue(string Message)
        {
            if (Message == null)
                return string.Empty;

            int start = Message.IndexOf("=\"", StringComparison.Ordinal);
            if (start < 0)
                return Message;

            return Message.Substring(0, start + 2) + RedactedValue + "\").";
        }
        #endregion

        #region LogAsyncPostBackError
        // What the browser gets instead of the exception text (ScriptManager.AsyncPostBackErrorMessage, step E1)
        public const string AsyncPostBackErrorMessage = "The action could not be completed. The error is in the error log.";

        // An unhandled error during an UpdatePanel postback (OnAsyncPostBackError of the masters and the login
        // page, step E1): one error log entry with the exception, the page path (no query string), the control
        // that posted and the user id (LogUnhandledError: no form values, request-validation values replaced).
        // The exception text goes to the log only. Never throws: it must not replace the error it reports.
        public static void LogAsyncPostBackError(System.Web.UI.Page Page, Exception Error, string SourceElementId)
        {
            try
            {
                // The code-behind class (BMMS.Master.Committee), not the generated ASP.* class
                string className = Page.GetType().BaseType.FullName;

                LogUnhandledError(HttpContext.Current, className, "AsyncPostBack " + (SourceElementId ?? string.Empty), Error);
            }
            catch (Exception)
            {
            }
        }
        #endregion

        #region WriteErrorLog
        // One writer at a time within the application: two requests can fail at the same moment
        private static readonly object ErrorLogLock = new object();

        // Never throws: a logging failure must not hide the caller's own error. File.AppendText creates the
        // file when it is missing; the File.Create used before left a stream open on the new file, so the
        // first entry of each day was lost (step 28)
        public static void WriteErrorLog(string ClassName, string MethodName, string ErrorMessage)
        {
            try
            {
                lock (ErrorLogLock)
                {
                    if (!Directory.Exists(AppDomain.CurrentDomain.BaseDirectory + "Log"))
                        Directory.CreateDirectory(AppDomain.CurrentDomain.BaseDirectory + "Log");

                    string _FileName = DateTime.Now.ToString("yyyy_MM_dd") + "_ErrorLog";
                    string _FilePath = AppDomain.CurrentDomain.BaseDirectory + "Log\\" + _FileName + ".txt";

                    using (StreamWriter SW = File.AppendText(_FilePath))
                    {
                        string _LineRow = "-".PadRight(125, '-');
                        SW.WriteLine(_LineRow);
                        SW.WriteLine("Date & Time : " + DateTime.Now.ToLongDateString() + " " + DateTime.Now.ToLongTimeString());
                        SW.WriteLine("Class  Name : " + ClassName);
                        SW.WriteLine("Method Name : " + MethodName);
                        SW.WriteLine("Description : " + ErrorMessage);
                        SW.WriteLine(_LineRow);
                    }
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = ex.Message;
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
        // Result 1: reset; Result 0: refused, nothing changed (Reason 8 acting user missing or inactive,
        // 4 not an Admin, 3 not the name of the current database). An error has rolled everything back.
        public static MeetingChangeResult ResetDatabase(int ActingUserId, string ConfirmDatabaseName)
        {
            return MeetingChangeResult.FromTable(UtilitiesDB.ResetDatabase(ActingUserId, ConfirmDatabaseName));
        }
        #endregion

        #region GetDatabaseName
        public static string GetDatabaseName()
        {
            return UtilitiesDB.GetDatabaseName();
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

        #region App settings (BMMS-Fix-MeetingLocks-Step16.sql)
        public const string AgendaControllerBypass = "AgendaControllerBypass";

        public static DataTable GetAppSetting(string SettingCode)
        {
            return UtilitiesDB.GetAppSetting(SettingCode);
        }

        public static MeetingChangeResult SetAppSetting(string SettingCode, string SettingValue, int ActingUserId)
        {
            return MeetingChangeResult.FromTable(UtilitiesDB.SetAppSetting(SettingCode, SettingValue, ActingUserId));
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
