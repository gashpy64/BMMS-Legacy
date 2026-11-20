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

        // Step UN6c2b: the meaning of "In progress" (the column header's tooltip, and shown on the In progress card,
        // which keyboard and touch users reach too). Owner, 2026-11-14: the second half only for the Controller and
        // the Manager, the roles that have the "Waiting for me" column; every other role the first half only.
        public const string InProgressMeaning = "Items not yet approved or rejected.";
        public const string InProgressMeaningWaiting = "Items not yet approved or rejected. For a Manager this includes items waiting for someone else; 'Waiting for me' is the part waiting for you.";

        // The sentence for this role (the role the server returned with the meeting list, read from the database)
        private static string InProgressMeaningFor(string roleCode)
        {
            return roleCode == "controller" || roleCode == "manager" ? InProgressMeaningWaiting : InProgressMeaning;
        }
        // Step UN6c2b: a summary count that could not be read (a dash, never 0)
        private const string NoCount = "\u2013";
        private const string SummaryChoiceMessage = "The counts cannot be shown for this choice.";
        private const string SummaryFailedMessage = "The counts could not be loaded. Reload the page to try again.";
        private const string SummaryBusyMessage = "The server is busy and the counts could not be loaded. Wait a moment, then reload the page.";

        // Index of the four statistics columns in both grids (Items, Approved, Rejected, last column)
        private const int FirstStatisticsColumn = 4;
        private const int LastStatisticsColumn = 7;
        // Step UN6c2a: "Waiting for me", the last column of the Scheduled list only
        private const int WaitingColumn = 8;

        #region Role table
        // What the page shows per role (owner, UN6b addendum 1, 2026-11-12; step UN6c2b, 2026-11-14: the User has the
        // Committee drop-down, and the last column says "In progress" for every role). The one place to change it.
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
            { "controller", new RoleView(true, false, false, "In progress") },
            { "manager", new RoleView(true, true, true, "In progress") },
            { "user", new RoleView(true, false, true, "In progress") },
            // Committee drop-down only, title "Meetings"; the statistics come from the server (step UN6c2b: the MD
            // Secretariat has them, read-only, as Management; the Admin has none)
            { "mgmt", new RoleView(true, false, false, "In progress") },
            { "md_sect", new RoleView(true, false, false, "In progress") },
            { "admin", new RoleView(true, false, false, "In progress") },
        };

        private static readonly RoleView NoView = new RoleView(false, false, false, "In progress");

        // Step UN6c2b: the roles the server gives summary cards (spr_GetDashboardSummary); used only to show dashes
        // when the counts could not be read at all, never to decide what is counted
        private static readonly HashSet<string> SummaryRoles = new HashSet<string>(StringComparer.Ordinal) { "controller", "mgmt", "manager", "user" };
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

            // Step UN6c2a: the Dashboard reloads the blocks that follow the filters (the My approvals panel)
            if (FiltersChanged != null)
                FiltersChanged(this, EventArgs.Empty);
        }
        #endregion

        #region Filters for the Dashboard
        // Step UN6c2a: the filters as the last load of the meeting list used them (0 = all). The procedures that take
        // them check them again against the acting user; these values only say what was chosen.
        public event EventHandler FiltersChanged;

        public int CommitteeId
        {
            get { object value = ViewState["CommitteeId"]; return value is int ? (int)value : 0; }
            private set { ViewState["CommitteeId"] = value; }
        }

        public int DepartmentId
        {
            get { object value = ViewState["DepartmentId"]; return value is int ? (int)value : 0; }
            private set { ViewState["DepartmentId"] = value; }
        }

        // Step UN6c2b (owner, 2026-11-15): the hint of a refused choice names only the drop-downs on the page:
        // "Choose All committees." for every role, "... or All my departments." only where the Department
        // drop-down is shown (a Manager with two or more departments)
        public string ChoiceHint
        {
            get { return divDepartmentFilter.Visible ? " Choose All committees or All my departments." : " Choose All committees."; }
        }
        #endregion

        #region Summary cards (step UN6c2b)
        // True once the server has answered that this person has the cards (kept so that a refused filter shows dashes
        // and a message instead of hiding the cards)
        private bool HasSummaryCards
        {
            get { return ViewState["HasSummaryCards"] is bool && (bool)ViewState["HasSummaryCards"]; }
            set { ViewState["HasSummaryCards"] = value; }
        }

        // The Unread alerts card: the unread count the Dashboard's Alerts card read (spr_GetDashboardAlerts, the rule of
        // the header count); null when it could not be read
        public void SetUnreadAlerts(int? count)
        {
            SetCount(litUnread, spanUnreadUnknown, count);
        }

        private static void SetCount(Literal value, System.Web.UI.HtmlControls.HtmlGenericControl unknown, int? count)
        {
            value.Text = count.HasValue ? count.Value.ToString() : NoCount;
            unknown.Visible = !count.HasValue;
        }

        // The two item cards for the filters of this load. itemsOf: "Items", "Credit items", "Items of my departments".
        private void LoadSummary(int actingUserId, int committeeId, int departmentId, string roleCode, string itemsOf, string meaning)
        {
            // Unread alerts comes from the Alerts card's load; when it has not been set (no load ran), a dash
            if (string.IsNullOrEmpty(litUnread.Text))
                SetCount(litUnread, spanUnreadUnknown, null);

            litInProgressLabel.Text = itemsOf + " in progress";
            litRejectedLabel.Text = itemsOf + " rejected";
            string scope = "Scheduled meetings, " + (committeeId > 0 && ddlCommittee.SelectedItem != null ? ddlCommittee.SelectedItem.Text : "all committees");
            litInProgressScope.Text = scope;
            litRejectedScope.Text = scope;
            litInProgressNote.Text = meaning;

            try
            {
                int? inProgress, rejected;
                int reason = AgendaMgr.GetDashboardSummary(actingUserId, committeeId, departmentId, out inProgress, out rejected);

                if (reason == 0)
                {
                    HasSummaryCards = true;
                    divSummaryCards.Visible = true;
                    pSummaryMessage.Visible = false;
                    SetCount(litInProgress, spanInProgressUnknown, inProgress);
                    SetCount(litRejected, spanRejectedUnknown, rejected);
                }
                else if (reason == 4 && HasSummaryCards)
                    ShowSummaryDashes(SummaryChoiceMessage + ChoiceHint);
                else
                    divSummaryCards.Visible = false;   // no cards for this role (4), the system account (12), inactive (8)
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "LoadSummary", ex.ToString());
                if (HasSummaryCards || SummaryRoles.Contains(roleCode ?? string.Empty))
                    ShowSummaryDashes(Common.IsServerBusy(ex) ? SummaryBusyMessage : SummaryFailedMessage);
                else
                    divSummaryCards.Visible = false;
            }
        }

        private void ShowSummaryDashes(string message)
        {
            divSummaryCards.Visible = true;
            if (string.IsNullOrEmpty(litUnread.Text))
                SetCount(litUnread, spanUnreadUnknown, null);
            SetCount(litInProgress, spanInProgressUnknown, null);
            SetCount(litRejected, spanRejectedUnknown, null);
            pSummaryMessage.InnerText = message;
            pSummaryMessage.Visible = true;
        }

        // The header of the last statistics column: the meaning of "In progress" as its tooltip
        private static void SetInProgressTip(GridView grid, string meaning)
        {
            if (grid.HeaderRow != null && grid.HeaderRow.Cells.Count > LastStatisticsColumn)
                grid.HeaderRow.Cells[LastStatisticsColumn].ToolTip = meaning;
        }

        // Who the item cards count, worded as the card titles of the meeting list
        private static string ItemsOf(RoleView view, DataTable dtDepartments, int chosenDepartmentId)
        {
            if (!view.DepartmentTitles || dtDepartments == null || dtDepartments.Rows.Count == 0)
                return "Items";
            if (dtDepartments.Rows.Count == 1)
                return Convert.ToString(dtDepartments.Rows[0]["DepartmentName"]) + " items";
            foreach (DataRow row in dtDepartments.Rows)
            {
                if (Convert.ToInt32(row["DepartmentId"]) == chosenDepartmentId)
                    return Convert.ToString(row["DepartmentName"]) + " items";
            }
            return "Items of my departments";
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

                CommitteeId = committeeId;
                DepartmentId = departmentId;

                int reason;
                bool statisticsShown;
                bool waitingShown;
                string roleCode;
                DataTable dtMeetings = MeetingMgr.GetDashboardMeetings(actingUserId, committeeId, departmentId,
                    out reason, out statisticsShown, out roleCode, out waitingShown);

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

                // Step UN6c2b: the summary cards, with the same filters (the server decides who has them)
                string meaning = InProgressMeaningFor(roleCode);
                LoadSummary(actingUserId, committeeId, departmentId, roleCode, ItemsOf(view, dtDepartments, departmentFilter ? departmentId : 0), meaning);

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
                grvScheduled.Columns[WaitingColumn].Visible = waitingShown;   // step UN6c2a: from the server's answer
                // Step UN6c2b: the meaning of "In progress" in a visible line when the statistics are shown and no
                // summary card carries it (the header tooltip is not reachable by keyboard or touch)
                pInProgressNote.InnerText = "In progress: " + meaning;
                pInProgressNote.Visible = statisticsShown && !divSummaryCards.Visible;

                grvScheduled.DataSource = Rows(dtMeetings, "S");
                grvScheduled.DataBind();
                grvCompleted.DataSource = Rows(dtMeetings, "C");
                grvCompleted.DataBind();
                SetInProgressTip(grvScheduled, meaning);
                SetInProgressTip(grvCompleted, meaning);
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
            // Step UN6c2b: cards that were shown keep their place with dashes (the counts are not known)
            if (HasSummaryCards)
                ShowSummaryDashes(SummaryFailedMessage);
            else
                divSummaryCards.Visible = false;
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
        // Step UN6c2a: the count of items waiting for this person; nothing where none waits
        protected static string WaitingText(object waiting)
        {
            int count;
            if (waiting == null || waiting == DBNull.Value || !int.TryParse(waiting.ToString(), out count) || count <= 0)
                return string.Empty;
            return count.ToString();
        }

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
