using System;
using System.Collections.Generic;
using System.Data;
using System.Web;
using System.Web.UI.WebControls;
using BMMSBAL;

namespace BMMS.UserControl
{
    // Step UN6b: the Dashboard's meeting list (spr_GetDashboardMeetings, step 42). The role and the departments of
    // the acting user are read by the procedures from the database; the page sends only the acting user id and the
    // two chosen filter values, which the procedure checks again (Reason 4 when outside the user's scope). Whether
    // the statistics are shown comes from the procedure (StatisticsShown), not from the role table below.
    public partial class MeetingSummary : System.Web.UI.UserControl
    {
        private const string className = "MeetingSummary";

        private const string InactiveMessage = "The meeting list is not available: your account is not active. Sign in again.";
        // Reason 4: the next step names only the filters that are shown (none: the role has no meeting list)
        private const string RefusedRoleMessage = "The meeting list is not shown for your role.";
        private const string RefusedChoiceMessage = "The meeting list is not shown for this choice.";
        private const string FailedMessage = "The meeting list could not be loaded. Reload the page to try again.";
        private const string BusyMessage = "The server is busy and the meeting list could not be loaded. Wait a moment, then reload the page.";

        // Index of the four statistics columns in both grids (Items, Approved, Rejected, last column)
        private const int FirstStatisticsColumn = 4;
        private const int LastStatisticsColumn = 7;

        #region Role table
        // What the page shows per role (owner, UN6b addendum 1, 2026-11-12). The one place to change it.
        //   CommitteeFilter   the Committee drop-down ("All committees" first)
        //   DepartmentFilter  the Department drop-down, shown only when the user has two or more departments
        //   DepartmentTitles  the subtitle "Department: x" / "Departments: x, y" and the card titles with the department
        //   LastColumn        the header of the last statistics column (AC + AMA in every case)
        private sealed class RoleView
        {
            public readonly bool CommitteeFilter;
            public readonly bool DepartmentFilter;
            public readonly bool DepartmentTitles;
            public readonly string LastColumn;

            public RoleView(bool committeeFilter, bool departmentFilter, bool departmentTitles, string lastColumn)
            {
                CommitteeFilter = committeeFilter;
                DepartmentFilter = departmentFilter;
                DepartmentTitles = departmentTitles;
                LastColumn = lastColumn;
            }
        }

        private static readonly Dictionary<string, RoleView> RoleViews = new Dictionary<string, RoleView>(StringComparer.Ordinal)
        {
            { "controller", new RoleView(true, false, false, "Pending") },
            { "manager", new RoleView(true, true, true, "Pending") },
            { "user", new RoleView(false, false, true, "In progress") },
            // Not decided yet (mock-up screens to come): Committee drop-down only, title "Meetings", "Pending"
            { "mgmt", new RoleView(true, false, false, "Pending") },
            { "md_sect", new RoleView(true, false, false, "Pending") },
            { "admin", new RoleView(true, false, false, "Pending") },
        };

        private static readonly RoleView NoView = new RoleView(false, false, false, "Pending");
        #endregion

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
                LoadMeetings(true);
        }
        #endregion

        #region Filter_Changed
        protected void Filter_Changed(object sender, EventArgs e)
        {
            LoadMeetings(false);
        }
        #endregion

        #region Reload
        // Called by the Dashboard after a successful Approve or Reject, so the counts are not stale
        public void Reload()
        {
            LoadMeetings(false);
        }
        #endregion

        #region LoadMeetings
        private void LoadMeetings(bool firstLoad)
        {
            int actingUserId;
            if (Session["UserId"] == null || !int.TryParse(Session["UserId"].ToString(), out actingUserId))
            {
                ShowMessage(InactiveMessage);
                divFilters.Visible = false;
                return;
            }

            try
            {
                // The departments are read again on every load (a Manager or a User only; Reason 4 for the other
                // roles): the drop-down, the subtitle and the titles follow them. A chosen department that is no
                // longer listed falls back to "All my departments" before the meetings are read.
                int departmentReason;
                DataTable dtDepartments = DepartmentMgr.GetDashboardDepartments(actingUserId, out departmentReason);
                if (departmentReason != 0)
                    dtDepartments = null;

                int committeeId = firstLoad ? 0 : SelectedValue(ddlCommittee);
                int departmentId = firstLoad || dtDepartments == null ? 0 : SelectedValue(ddlDepartment);
                if (departmentId > 0 && dtDepartments.Select("DepartmentId = " + departmentId).Length == 0)
                    departmentId = 0;

                int reason;
                bool statisticsShown;
                string roleCode;
                DataTable dtMeetings = MeetingMgr.GetDashboardMeetings(actingUserId, committeeId, departmentId,
                    out reason, out statisticsShown, out roleCode);

                RoleView view;
                if (!RoleViews.TryGetValue(roleCode, out view))
                    view = NoView;

                if (view.CommitteeFilter && ddlCommittee.Items.Count == 0)
                    BindCommittees();
                divCommitteeFilter.Visible = view.CommitteeFilter;

                if (!view.DepartmentTitles)
                    dtDepartments = null;
                bool departmentFilter = view.DepartmentFilter && dtDepartments != null && dtDepartments.Rows.Count >= 2;
                if (departmentFilter)
                    BindDepartments(dtDepartments, departmentId);
                divDepartmentFilter.Visible = departmentFilter;
                divFilters.Visible = view.CommitteeFilter || departmentFilter;

                ShowTitles(view, dtDepartments, departmentFilter ? departmentId : 0);

                if (reason != 0)
                {
                    ShowMessage(reason == 8 ? InactiveMessage : RefusedText(view.CommitteeFilter, departmentFilter));
                    return;
                }

                HideMessage();
                for (int i = FirstStatisticsColumn; i <= LastStatisticsColumn; i++)
                {
                    grvScheduled.Columns[i].Visible = statisticsShown;
                    grvCompleted.Columns[i].Visible = statisticsShown;
                }
                grvScheduled.Columns[LastStatisticsColumn].HeaderText = view.LastColumn;
                grvCompleted.Columns[LastStatisticsColumn].HeaderText = view.LastColumn;

                grvScheduled.DataSource = Rows(dtMeetings, "S");
                grvScheduled.DataBind();
                grvCompleted.DataSource = Rows(dtMeetings, "C");
                grvCompleted.DataBind();
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "LoadMeetings", ex.ToString());
                ShowFailure(Common.IsServerBusy(ex) ? BusyMessage : FailedMessage);
            }
        }
        #endregion

        #region Failure
        // A failed load: the role is not known, so no filter is shown for any role (the markup hides them too),
        // no subtitle and the plain title
        private void ShowFailure(string message)
        {
            divFilters.Visible = false;
            divCommitteeFilter.Visible = false;
            divDepartmentFilter.Visible = false;
            pSubtitle.Visible = false;
            litMeetingsTitle.Text = "Meetings";
            ShowMessage(message);
        }
        #endregion

        #region Titles
        // Subtitle and card title. Department names come from spr_GetDashboardDepartments (the database), and are
        // encoded on output (InnerText, Literal Mode Encode).
        private void ShowTitles(RoleView view, DataTable dtDepartments, int chosenDepartmentId)
        {
            pSubtitle.Visible = false;
            litMeetingsTitle.Text = "Meetings";

            if (!view.DepartmentTitles || dtDepartments == null || dtDepartments.Rows.Count == 0)
                return;

            List<string> names = new List<string>();
            string chosenName = null;
            foreach (DataRow row in dtDepartments.Rows)
            {
                string name = Convert.ToString(row["DepartmentName"]);
                names.Add(name);
                if (Convert.ToInt32(row["DepartmentId"]) == chosenDepartmentId)
                    chosenName = name;
            }

            pSubtitle.Visible = true;
            if (names.Count == 1)
            {
                pSubtitle.InnerText = "Department: " + names[0];
                litMeetingsTitle.Text = "Meetings, " + names[0] + " items";
            }
            else
            {
                pSubtitle.InnerText = "Departments: " + string.Join(", ", names.ToArray());
                litMeetingsTitle.Text = chosenName == null
                    ? "Meetings, items of my departments"
                    : "Meetings, " + chosenName + " items";
            }
        }
        #endregion

        #region Drop-downs
        private void BindCommittees()
        {
            DataTable dtCommittee = CommitteeMgr.GetCommitteeList(1);
            ddlCommittee.Items.Clear();
            ddlCommittee.Items.Add(new ListItem("All committees", "0"));
            foreach (DataRow row in dtCommittee.Rows)
                ddlCommittee.Items.Add(new ListItem(Convert.ToString(row["CommitteeName"]), Convert.ToString(row["CommitteeId"])));
        }

        // Rebuilt from the database on every load; the chosen department stays chosen while it is still listed
        private void BindDepartments(DataTable dtDepartments, int chosenDepartmentId)
        {
            ddlDepartment.Items.Clear();
            ddlDepartment.Items.Add(new ListItem("All my departments", "0"));
            foreach (DataRow row in dtDepartments.Rows)
                ddlDepartment.Items.Add(new ListItem(Convert.ToString(row["DepartmentName"]), Convert.ToString(row["DepartmentId"])));

            ListItem chosen = ddlDepartment.Items.FindByValue(chosenDepartmentId.ToString());
            ddlDepartment.SelectedIndex = chosen == null ? 0 : ddlDepartment.Items.IndexOf(chosen);
        }

        private static int SelectedValue(DropDownList ddl)
        {
            int value;
            if (ddl.SelectedItem == null || !int.TryParse(ddl.SelectedValue, out value) || value < 0)
                return 0;
            return value;
        }
        #endregion

        #region Helpers
        private static DataView Rows(DataTable dt, string listCode)
        {
            // The procedure's order is kept (RowFilter without Sort keeps the table order)
            DataView view = new DataView(dt);
            view.RowFilter = "ListCode = '" + (listCode == "S" ? "S" : "C") + "'";
            return view;
        }

        private static string RefusedText(bool committeeFilter, bool departmentFilter)
        {
            if (committeeFilter && departmentFilter)
                return RefusedChoiceMessage + " Choose All committees or All my departments.";
            if (committeeFilter)
                return RefusedChoiceMessage + " Choose All committees.";
            if (departmentFilter)
                return RefusedChoiceMessage + " Choose All my departments.";
            return RefusedRoleMessage;
        }

        private void ShowMessage(string message)
        {
            pMeetingsMessage.InnerText = message;
            pMeetingsMessage.Visible = true;
            pnlMeetingLists.Visible = false;
        }

        private void HideMessage()
        {
            pMeetingsMessage.Visible = false;
            pnlMeetingLists.Visible = true;
        }

        // The chip class from the state code; only the five known codes give a colour class
        protected static string StateCssClass(object stateCode)
        {
            switch (Convert.ToString(stateCode))
            {
                case "grey": return "wb-chip wb-chip-grey";
                case "red": return "wb-chip wb-chip-red";
                case "green": return "wb-chip wb-chip-green";
                case "orange": return "wb-chip wb-chip-orange";
                case "blue": return "wb-chip wb-chip-blue";
                default: return "wb-chip";
            }
        }

        // The date format used across the application (dd-MMM-yyyy, as DashBoard.aspx.cs FormatDate)
        protected static string FormatDate(object value)
        {
            DateTime date;
            if (value == null || value == DBNull.Value || !DateTime.TryParse(value.ToString(), out date))
                return string.Empty;

            return date.ToString("dd-MMM-yyyy");
        }

        // The meeting time as the earlier list showed it ("10:00 Hrs.")
        protected static string FormatTime(object value)
        {
            string time = value == null || value == DBNull.Value ? string.Empty : value.ToString().Trim();
            return time.Length == 0 ? string.Empty : time + " Hrs.";
        }
        #endregion
    }
}
