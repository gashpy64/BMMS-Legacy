using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using BMMSBAL;

namespace BMMS.Report
{
    /// <summary>
    /// Step GM1a (BMMS-Fix-GovernanceLog-Step56.sql): the Governance Matrix (who enters, who approves and the
    /// Controllers of every transaction and department, as on a date) and the governance change log. Read only: the
    /// page saves nothing. Admin and Controller: PageAccess.xml and RequireRole (the role read from the database on
    /// every request); the procedures check the acting user and the dates again. Every value is plain text, encoded
    /// by the grids (BoundField) and by the exports.
    /// </summary>
    public partial class GovernanceMatrix : System.Web.UI.Page
    {
        private string className = "GovernanceMatrix";

        private const string LoadFailed = "The governance matrix could not be loaded. Reload the page to try again.";
        private const string LogLoadFailed = "The change log could not be loaded. Reload the page to try again.";
        private const string DateNotValid = "Enter a valid date (dd-MMM-yyyy).";
        private const string RangeDatesNotValid = "Enter valid From and To dates (dd-MMM-yyyy).";

        private static readonly string[] MatrixColumns = { "Transaction", "Department", "WhoEnters", "WhoApproves", "Controllers", "RuleNote" };
        private static readonly string[] MatrixHeaders = { "Transaction", "Department", "Who enters", "Who approves", "Controller(s)", "Rule note" };
        private static readonly string[] LogColumns = { "ChangedOnText", "ChangedByText", "ChangeText", "UserText", "SubjectText", "OldText", "NewText", "SourceText" };
        private static readonly string[] LogHeaders = { "Changed on", "Changed by", "Change", "User", "Department or setting", "Old value", "New value", "Source" };

        // What one Show of the matrix read: the grids and the exports use the same
        private sealed class MatrixData
        {
            public DateTime AsOn;
            public bool IsLive;
            public DataTable Matrix;
            public DataTable Settings;
            public DataTable ReadOnly;
            public List<string> Notes = new List<string>();
        }

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            // Admin and Controller only (role read from the database; ends the request otherwise)
            BMMS.Security.PageAccessModule.RequireRole("admin", "controller");

            Common.InitSetup(className);

            // Owner test 1 (gate B): the browser keeps no copy of this page, so Back or a reload asks the server again and
            // gets the defaults below; the filter fields carry autocomplete="off" so their old values are not put back
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();

            // Owner print test: this page prints landscape. A print-only style in this page's head (not a named page in the
            // shared stylesheet, which forced a page break and left the first sheet blank)
            if (Page.Header != null)
                Page.Header.Controls.Add(new LiteralControl("<style type=\"text/css\" media=\"print\">@page { size: landscape; }</style>"));

            if (!IsPostBack)
            {
                // The breadcrumb names the menu the page is in for the role: Admin's "Admin" menu, the Controller's "Reports"
                litMenuName.Text = BMMS.Security.PageAccessModule.HasRole("admin") ? "Admin" : "Reports";
                MsgHide();

                // Every fresh visit starts from the defaults: As on today, All departments, All transactions, the Matrix
                // view; the change log filters get theirs when that view is first opened (last 30 days, all)
                txtAsOn.Text = DateTime.Today.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture);
                ddlTransaction.Items.Clear();
                ddlTransaction.Items.Add(new ListItem("All transactions", ""));
                foreach (GovernanceMgr.Transaction t in GovernanceMgr.Transactions)
                    ddlTransaction.Items.Add(new ListItem(t.Name, t.Code));
                ddlTransaction.SelectedIndex = 0;
                ddlDepartment.Items.Clear();
                ddlDepartment.Items.Add(new ListItem("All departments", "0"));
                ddlDepartment.SelectedIndex = 0;
                ViewState["LogFiltersLoaded"] = false;
                ShowMatrix();
            }
        }
        #endregion

        #region Tabs
        protected void btnTabMatrix_Click(object sender, EventArgs e)
        {
            MsgHide();
            SetTab(false);
            ShowMatrix();
        }

        protected void btnTabLog_Click(object sender, EventArgs e)
        {
            MsgHide();
            SetTab(true);
            // The filters are read once per visit; a refused or failed read leaves them unloaded, so the next click tries again
            if (!(ViewState["LogFiltersLoaded"] is bool && (bool)ViewState["LogFiltersLoaded"]))
            {
                ddlChangeType.Items.Clear();
                txtFrom.Text = DateTime.Today.AddDays(-30).ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture);
                txtTo.Text = DateTime.Today.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture);
                ddlChangeType.Items.Add(new ListItem("All change types", ""));
                foreach (string c in GovernanceMgr.ChangeTypes)
                    ddlChangeType.Items.Add(new ListItem(GovernanceMgr.ChangeTypeName(c), c));
                if (!LoadLogFilters())
                {
                    ddlChangeType.Items.Clear();
                    return;
                }
                // The defaults of the change log on its first opening in a visit: last 30 days, every user, department, type
                ddlChangeType.SelectedIndex = 0;
                ddlLogUser.SelectedIndex = 0;
                ddlLogDepartment.SelectedIndex = 0;
                ViewState["LogFiltersLoaded"] = true;
            }
            ShowLog();
        }

        private void SetTab(bool Log)
        {
            pnlMatrix.Visible = !Log;
            pnlLog.Visible = Log;
            btnTabMatrix.CssClass = Log ? "wb-btn wb-btn-secondary" : "wb-btn";
            btnTabLog.CssClass = Log ? "wb-btn" : "wb-btn wb-btn-secondary";
            btnTabMatrix.Attributes["aria-pressed"] = Log ? "false" : "true";
            btnTabLog.Attributes["aria-pressed"] = Log ? "true" : "false";
        }
        #endregion

        #region Matrix
        protected void btnShow_Click(object sender, EventArgs e)
        {
            MsgHide();
            ShowMatrix();
        }

        private void ShowMatrix()
        {
            SetTab(false);
            pnlMatrixResult.Visible = false;

            MatrixData data;
            string message;
            if (!ReadMatrix(true, out data, out message))
            {
                if (message != null)
                    MsgDisplay(message, message == LoadFailed ? MessageKind.Error : MessageKind.Warning);
                return;
            }

            litAsOn.Text = HttpUtility.HtmlEncode("As on " + data.AsOn.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture)
                                                  + (data.IsLive ? " (today)" : ", end of the day"));
            StringBuilder notes = new StringBuilder();
            foreach (string n in data.Notes)
                notes.Append("<p class=\"wb-help\">").Append(HttpUtility.HtmlEncode(n)).Append("</p>");
            litMatrixNotes.Text = notes.ToString();

            grvSettings.DataSource = data.Settings;
            grvSettings.DataBind();
            grvMatrix.DataSource = data.Matrix;
            grvMatrix.DataBind();
            grvReadOnly.DataSource = data.ReadOnly;
            grvReadOnly.DataBind();
            pnlMatrixResult.Visible = true;
        }

        // Reads the matrix for the page's filters. False with a message (or null when the message is shown already)
        // when the date is not valid, the database refuses or the read fails. FillDepartments: fill the Department
        // filter with the departments of the day (the choice kept when it is still there).
        private bool ReadMatrix(bool FillDepartments, out MatrixData Data, out string Message)
        {
            Data = null;
            Message = null;

            DateTime asOn;
            if (!ParseDate(txtAsOn.Text, out asOn))
            {
                Message = DateNotValid;
                return false;
            }

            try
            {
                int acting = ActingUserId();
                int reason;
                string detail;

                DataTable settings = GovernanceMgr.GetSettings(acting, asOn, out reason, out detail);
                if (reason != 0)
                {
                    Message = GovernanceMgr.RefusalMessage(reason, detail);
                    return false;
                }
                if (settings.Rows.Count == 0)
                {
                    Utilities.WriteErrorLog(className, "ReadMatrix", "spr_GetGovernanceSettings returned no row although it allowed the read");
                    Message = LoadFailed;
                    return false;
                }

                DataTable departments = GovernanceMgr.GetDepartments(acting, asOn, out reason, out detail);
                if (reason != 0)
                {
                    Message = GovernanceMgr.RefusalMessage(reason, detail);
                    return false;
                }

                DataTable people = GovernanceMgr.GetMatrix(acting, asOn, out reason, out detail);
                if (reason != 0)
                {
                    Message = GovernanceMgr.RefusalMessage(reason, detail);
                    return false;
                }

                if (FillDepartments)
                {
                    string chosen = ddlDepartment.SelectedValue;
                    ddlDepartment.Items.Clear();
                    ddlDepartment.Items.Add(new ListItem("All departments", "0"));
                    foreach (DataRow d in departments.Rows)
                        ddlDepartment.Items.Add(new ListItem(Convert.ToString(d["DepartmentName"])
                            + (Convert.ToInt32(d["IsActive"]) == 1 ? string.Empty : " (inactive)"), Convert.ToString(d["DepartmentId"])));
                    ListItem keep = ddlDepartment.Items.FindByValue(chosen);
                    if (keep != null) ddlDepartment.SelectedValue = chosen;
                }

                DataRow s = settings.Rows[0];
                bool isLive = Convert.ToInt32(s["IsLive"]) == 1;
                DateTime? logFrom = s["LogFrom"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(s["LogFrom"]);
                bool reportingKnown = isLive || (logFrom.HasValue && asOn.Date >= logFrom.Value.Date);

                int deptFilter;
                if (!int.TryParse(ddlDepartment.SelectedValue, out deptFilter)) deptFilter = 0;
                string txFilter = GovernanceMgr.FindTransaction(ddlTransaction.SelectedValue) == null ? string.Empty : ddlTransaction.SelectedValue;

                Func<string, string[]> rolesForPage = BMMS.Security.PageAccessModule.RolesForPage;

                MatrixData data = new MatrixData();
                data.AsOn = asOn.Date;
                data.IsLive = isLive;
                data.Matrix = GovernanceMgr.BuildMatrix(people, departments, s, rolesForPage, deptFilter, txFilter, isLive, reportingKnown);

                data.Settings = new DataTable();
                data.Settings.Columns.Add("Setting", typeof(string));
                data.Settings.Columns.Add("Value", typeof(string));
                data.Settings.Rows.Add(GovernanceMgr.SettingName("DeptNoManagerAction"), GovernanceMgr.DeptRuleText(Convert.ToString(s["DeptNoManagerAction"])));
                data.Settings.Rows.Add(GovernanceMgr.SettingName("AgendaControllerBypass"), GovernanceMgr.BypassText(Convert.ToString(s["AgendaControllerBypass"])));

                List<GovernanceMgr.MenuEntry> menu = null;
                try
                {
                    menu = GovernanceMgr.ReadMenu(File.ReadAllText(Server.MapPath("~/UserControl/MenuUserControl.ascx")));
                }
                catch (Exception ex)
                {
                    Utilities.WriteErrorLog(className, "ReadMenu", ex.ToString());
                }
                data.ReadOnly = GovernanceMgr.BuildReadOnly(people, menu, rolesForPage, isLive);

                if (!isLive)
                {
                    data.Notes.Add("As on " + asOn.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture) + ", end of the day. The rules are those installed now.");
                    data.Notes.Add("Deleted users are not shown; see the change log.");
                    if (!reportingKnown)
                    {
                        string from = logFrom.HasValue ? logFrom.Value.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture) : "the install of this page";
                        data.Notes.Add("Reporting Person not recorded before " + from + ": the route to the Controller is not shown for earlier dates.");
                        data.Notes.Add("Department status not recorded before " + from + ": today's status is shown.");
                    }
                }

                Data = data;
                return true;
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "ReadMatrix", ex.ToString());
                Message = LoadFailed;
                return false;
            }
        }

        protected void btnExcelMatrix_Click(object sender, EventArgs e)
        {
            MsgHide();
            MatrixData data;
            string message;
            if (!ReadMatrix(false, out data, out message))
            {
                ShowMatrixFailure(message);
                return;
            }

            string title = "Governance Matrix as on " + data.AsOn.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture);
            StringBuilder csv = new StringBuilder();
            csv.Append(GovernanceMgr.Csv(title, data.Matrix, MatrixColumns, MatrixHeaders));
            csv.Append("\r\n").Append(GovernanceMgr.Csv("Settings", data.Settings, new[] { "Setting", "Value" }, new[] { "Setting", "Value" }));
            csv.Append("\r\n").Append(GovernanceMgr.Csv("Read-only access", data.ReadOnly, new[] { "Role", "People", "CanRead" }, new[] { "Role", "People", "Can read" }));
            foreach (string n in data.Notes)
                csv.Append(GovernanceMgr.CsvCell(n)).Append("\r\n");

            SendFile(Encoding.UTF8.GetPreamble(), Encoding.UTF8.GetBytes(csv.ToString()), "text/csv; charset=utf-8",
                     "GovernanceMatrix-" + data.AsOn.ToString("yyyyMMdd", CultureInfo.InvariantCulture) + ".csv");
        }

        protected void btnPdfMatrix_Click(object sender, EventArgs e)
        {
            MsgHide();
            MatrixData data;
            string message;
            if (!ReadMatrix(false, out data, out message))
            {
                ShowMatrixFailure(message);
                return;
            }

            byte[] pdf;
            try
            {
                StringBuilder html = new StringBuilder();
                html.Append(OrganisationDetails.ReportBannerHtml());
                html.Append("<p><b>Governance Matrix</b></p><p>").Append(HttpUtility.HtmlEncode("As on "
                    + data.AsOn.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture) + (data.IsLive ? " (today)" : ", end of the day"))).Append("</p>");
                foreach (string n in data.Notes)
                    html.Append("<p>").Append(HttpUtility.HtmlEncode(n)).Append("</p>");
                html.Append(GovernanceMgr.HtmlTable("Settings", data.Settings, new[] { "Setting", "Value" }, new[] { "Setting", "Value" }));
                html.Append(GovernanceMgr.HtmlTable("Who enters and who approves", data.Matrix, MatrixColumns, MatrixHeaders));
                html.Append(GovernanceMgr.HtmlTable("Read-only access", data.ReadOnly, new[] { "Role", "People", "CanRead" }, new[] { "Role", "People", "Can read" }));
                pdf = PDFUtilities.HtmlReportToPdf(html.ToString());
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "btnPdfMatrix_Click", ex.ToString());
                ShowMatrixFailure(LoadFailed);
                return;
            }

            SendFile(null, pdf, "application/pdf", "GovernanceMatrix-" + data.AsOn.ToString("yyyyMMdd", CultureInfo.InvariantCulture) + ".pdf");
        }

        private void ShowMatrixFailure(string Message)
        {
            pnlMatrixResult.Visible = false;
            if (Message != null)
                MsgDisplay(Message, Message == LoadFailed ? MessageKind.Error : MessageKind.Warning);
        }
        #endregion

        #region ChangeLog
        // The user and department filters of the change log; false (message shown) when they cannot be read
        private bool LoadLogFilters()
        {
            try
            {
                int acting = ActingUserId();
                int reason;
                string detail;

                DataTable users = GovernanceMgr.GetLogUsers(acting, out reason);
                if (reason != 0)
                {
                    MsgDisplay(GovernanceMgr.RefusalMessage(reason, string.Empty));
                    pnlLogResult.Visible = false;
                    return false;
                }
                ddlLogUser.Items.Clear();
                ddlLogUser.Items.Add(new ListItem("- All -", "0"));
                foreach (DataRow u in users.Rows)
                {
                    string text = Common.UserDisplayName(Convert.ToString(u["UserName"]), Convert.ToString(u["LoginName"]), true);
                    if (Convert.ToInt32(u["Deleted"]) == 1) text += " (deleted)";
                    else if (Convert.ToInt32(u["IsActive"]) != 1) text += " (inactive)";
                    ddlLogUser.Items.Add(new ListItem(text, Convert.ToString(u["UserId"])));
                }

                DataTable departments = GovernanceMgr.GetDepartments(acting, DateTime.Today, out reason, out detail);
                if (reason != 0)
                {
                    MsgDisplay(GovernanceMgr.RefusalMessage(reason, detail));
                    pnlLogResult.Visible = false;
                    return false;
                }
                ddlLogDepartment.Items.Clear();
                ddlLogDepartment.Items.Add(new ListItem("All departments", "0"));
                foreach (DataRow d in departments.Rows)
                    ddlLogDepartment.Items.Add(new ListItem(Convert.ToString(d["DepartmentName"])
                        + (Convert.ToInt32(d["IsActive"]) == 1 ? string.Empty : " (inactive)"), Convert.ToString(d["DepartmentId"])));
                return true;
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "LoadLogFilters", ex.ToString());
                MsgDisplay(LogLoadFailed, MessageKind.Error);
                pnlLogResult.Visible = false;
                ddlChangeType.Items.Clear();
                return false;
            }
        }

        protected void btnShowLog_Click(object sender, EventArgs e)
        {
            MsgHide();
            ShowLog();
        }

        private void ShowLog()
        {
            SetTab(true);
            pnlLogResult.Visible = false;

            DataTable rows;
            DateTime from, to;
            string message;
            if (!ReadLog(out rows, out from, out to, out message))
            {
                MsgDisplay(message, message == LogLoadFailed ? MessageKind.Error : MessageKind.Warning);
                return;
            }

            litLogRange.Text = HttpUtility.HtmlEncode(LogTitle(from, to, rows.Rows.Count));
            grvLog.DataSource = rows;
            grvLog.DataBind();
            pnlLogResult.Visible = true;
        }

        private static string LogTitle(DateTime From, DateTime To, int Count)
        {
            return "Changes from " + From.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture) + " to "
                   + To.ToString(GovernanceMgr.DateFormat, CultureInfo.InvariantCulture) + ": " + Count.ToString(CultureInfo.InvariantCulture)
                   + (Count == 1 ? " change" : " changes");
        }

        private bool ReadLog(out DataTable Rows, out DateTime From, out DateTime To, out string Message)
        {
            Rows = null;
            Message = null;
            To = DateTime.MinValue;
            if (!ParseDate(txtFrom.Text, out From) || !ParseDate(txtTo.Text, out To))
            {
                Message = RangeDatesNotValid;
                return false;
            }

            try
            {
                int userId, deptId;
                if (!int.TryParse(ddlLogUser.SelectedValue, out userId)) userId = 0;
                if (!int.TryParse(ddlLogDepartment.SelectedValue, out deptId)) deptId = 0;
                string type = Array.IndexOf(GovernanceMgr.ChangeTypes, ddlChangeType.SelectedValue) >= 0 ? ddlChangeType.SelectedValue : string.Empty;

                int reason;
                DataTable dt = GovernanceMgr.GetChangeLog(ActingUserId(), From, To, userId, deptId, type, out reason);
                if (reason != 0)
                {
                    Message = GovernanceMgr.RefusalMessage(reason, string.Empty);
                    return false;
                }

                DataTable view = new DataTable();
                foreach (string c in LogColumns) view.Columns.Add(c, typeof(string));
                foreach (DataRow r in dt.Rows)
                {
                    string changedBy = r["ChangedBy"] == DBNull.Value || r["ChangedByName"] == DBNull.Value
                        ? "(user no longer exists)"
                        : Common.UserDisplayName(Convert.ToString(r["ChangedByName"]), Convert.ToString(r["ChangedByLogin"]), Convert.ToInt32(r["ChangedByActive"]) == 1);
                    string user = r["UserId"] == DBNull.Value ? string.Empty
                        : Common.UserDisplayName(Convert.ToString(r["UserName"]), Convert.ToString(r["UserLogin"]), true);
                    string setting = Convert.ToString(r["SettingCode"]);
                    bool isSetting = setting.Length > 0;
                    view.Rows.Add(
                        Convert.ToDateTime(r["ChangedOn"]).ToString(GovernanceMgr.DateFormat + " HH:mm", CultureInfo.InvariantCulture),
                        changedBy,
                        GovernanceMgr.ChangeTypeName(Convert.ToString(r["ChangeType"])),
                        user,
                        isSetting ? GovernanceMgr.SettingName(setting) : Convert.ToString(r["DepartmentName"]),
                        isSetting ? GovernanceMgr.SettingValueText(setting, Convert.ToString(r["OldValue"])) : Convert.ToString(r["OldValue"]),
                        isSetting ? GovernanceMgr.SettingValueText(setting, Convert.ToString(r["NewValue"])) : Convert.ToString(r["NewValue"]),
                        GovernanceMgr.SourceName(Convert.ToString(r["Source"])));
                }
                Rows = view;
                return true;
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "ReadLog", ex.ToString());
                Message = LogLoadFailed;
                return false;
            }
        }

        protected void btnExcelLog_Click(object sender, EventArgs e)
        {
            MsgHide();
            DataTable rows;
            DateTime from, to;
            string message;
            if (!ReadLog(out rows, out from, out to, out message))
            {
                pnlLogResult.Visible = false;
                MsgDisplay(message, message == LogLoadFailed ? MessageKind.Error : MessageKind.Warning);
                return;
            }

            string csv = GovernanceMgr.Csv("Governance change log. " + LogTitle(from, to, rows.Rows.Count), rows, LogColumns, LogHeaders);
            SendFile(Encoding.UTF8.GetPreamble(), Encoding.UTF8.GetBytes(csv), "text/csv; charset=utf-8",
                     "GovernanceChangeLog-" + from.ToString("yyyyMMdd", CultureInfo.InvariantCulture) + "-" + to.ToString("yyyyMMdd", CultureInfo.InvariantCulture) + ".csv");
        }

        protected void btnPdfLog_Click(object sender, EventArgs e)
        {
            MsgHide();
            DataTable rows;
            DateTime from, to;
            string message;
            if (!ReadLog(out rows, out from, out to, out message))
            {
                pnlLogResult.Visible = false;
                MsgDisplay(message, message == LogLoadFailed ? MessageKind.Error : MessageKind.Warning);
                return;
            }

            byte[] pdf;
            try
            {
                string html = OrganisationDetails.ReportBannerHtml() + "<p><b>Governance change log</b></p><p>"
                              + HttpUtility.HtmlEncode(LogTitle(from, to, rows.Rows.Count)) + "</p>"
                              + GovernanceMgr.HtmlTable(null, rows, LogColumns, LogHeaders);
                pdf = PDFUtilities.HtmlReportToPdf(html);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "btnPdfLog_Click", ex.ToString());
                pnlLogResult.Visible = false;
                MsgDisplay(LogLoadFailed, MessageKind.Error);
                return;
            }

            SendFile(null, pdf, "application/pdf",
                     "GovernanceChangeLog-" + from.ToString("yyyyMMdd", CultureInfo.InvariantCulture) + "-" + to.ToString("yyyyMMdd", CultureInfo.InvariantCulture) + ".pdf");
        }
        #endregion

        #region Helpers
        private static bool ParseDate(string Text, out DateTime Value)
        {
            return DateTime.TryParseExact((Text ?? string.Empty).Trim(), new[] { "dd-MMM-yyyy", "d-MMM-yyyy" }, CultureInfo.InvariantCulture,
                                          DateTimeStyles.None, out Value);
        }

        private int ActingUserId()
        {
            int id;
            return int.TryParse(Convert.ToString(Session["UserId"]), out id) ? id : 0;
        }

        // Sends a file as a download and ends the request (outside any try/catch: Response.End stops the thread)
        private void SendFile(byte[] Preamble, byte[] Body, string ContentType, string FileName)
        {
            Response.Clear();
            Response.ContentType = ContentType;
            Response.AddHeader("Content-Disposition", "attachment; filename=\"" + FileName + "\"");
            Response.AddHeader("X-Content-Type-Options", "nosniff");
            if (Preamble != null && Preamble.Length > 0)
                Response.BinaryWrite(Preamble);
            Response.BinaryWrite(Body);
            Response.End();
        }

        private void MsgDisplay(string errMsg)
        {
            MsgDisplay(errMsg, MessageKind.Warning);
        }

        private void MsgDisplay(string errMsg, MessageKind kind)
        {
            divErrLogin.Attributes.Add("class", Common.MessageCss(kind));
            spanErrLogin.InnerHtml = HttpUtility.HtmlEncode(errMsg);
        }

        private void MsgHide()
        {
            divErrLogin.Attributes.Add("class", "divErrorHide");
        }
        #endregion
    }
}
