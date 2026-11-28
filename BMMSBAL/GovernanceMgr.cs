using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using BMMSDAL;

namespace BMMSBAL
{
    #region GovernanceMgr
    /// <summary>
    /// Step GM1a (BMMS-Fix-GovernanceLog-Step56.sql): the Governance Matrix and the governance change log, read only.
    /// The people come from the database (spr_GetGovernanceMatrix: today the functions the software uses, an earlier
    /// day their dated versions); the rules that are page rules come from PageAccess.xml (the caller passes
    /// PageAccessModule.RolesForPage); the Read-only access block comes from PageAccess.xml and the menu
    /// (MenuUserControl.ascx). This class only arranges them for the page and the exports.
    /// </summary>
    public class GovernanceMgr
    {
        // Reasons of the step 56 procedures (8 and 4 as everywhere)
        public const int ReasonBeforeHistory = 32;
        public const int ReasonDateNotValid = 33;
        public const int ReasonRangeNotValid = 34;

        public const string DateFormat = "dd-MMM-yyyy";

        #region Roles
        public static readonly string[] AllRoles = { "admin", "controller", "manager", "user", "mgmt", "md_sect" };

        public static string RoleName(string RoleCode)
        {
            switch ((RoleCode ?? string.Empty).Trim())
            {
                case "admin": return "Admin";
                case "controller": return "Controller";
                case "manager": return "Manager";
                case "user": return "User";
                case "mgmt": return "Management";
                case "md_sect": return "MD Secretariat";
                default: return RoleCode;
            }
        }
        #endregion

        #region Transactions
        /// <summary>One transaction of the matrix: a rule of the database (Rule) or of a page (PagePath).</summary>
        public class Transaction
        {
            public string Code;
            public string Name;
            public bool PerDepartment;
            public string PagePath;       // a page rule: the roles of PageAccess.xml for this page do it
            public string[] ReadOnlyRoles; // roles the page lets in that only read there (the procedures refuse them)
        }

        public static readonly Transaction[] Transactions =
        {
            new Transaction { Code = "AGU", Name = "Agenda entry by a User", PerDepartment = true },
            new Transaction { Code = "AGM", Name = "Agenda entry by a Manager", PerDepartment = true },
            new Transaction { Code = "APM", Name = "Manager approval or rejection", PerDepartment = true },
            new Transaction { Code = "AGC", Name = "Agenda entry by the Controller" },
            new Transaction { Code = "APC", Name = "Controller approval or rejection" },
            new Transaction { Code = "AF", Name = "Agenda finalisation", PagePath = "Master/AgendaFinalization.aspx" },
            new Transaction { Code = "MU", Name = "Minutes update", PagePath = "Master/MinutesUpdate.aspx" },
            new Transaction { Code = "MF", Name = "Minutes finalisation", PagePath = "Master/MinutesFinalization.aspx" },
            new Transaction { Code = "MC", Name = "Minutes confirmation", PagePath = "Master/MinutesConfirmation.aspx" },
            new Transaction { Code = "FU", Name = "Followup save, confirm and reopen", PagePath = "Master/Followup.aspx", ReadOnlyRoles = new[] { "md_sect" } },
            new Transaction { Code = "AIR", Name = "Action items: who receives them" },
            new Transaction { Code = "AIS", Name = "Action items: who can open them (Dashboard)", PerDepartment = true },
            new Transaction { Code = "MM", Name = "Meeting create and update", PagePath = "Master/Meeting.aspx" },
            new Transaction { Code = "CM", Name = "Committee create and update", PagePath = "Master/Committee.aspx" },
            new Transaction { Code = "AT", Name = "Attendance", PagePath = "Master/Attendance.aspx" },
            new Transaction { Code = "UM", Name = "User Master (roles, departments, Reporting Person)", PagePath = "Master/User.aspx" },
            new Transaction { Code = "DM", Name = "Department Master", PagePath = "Master/Department.aspx" },
            new Transaction { Code = "SS", Name = "System Settings", PagePath = "Master/SystemSettings.aspx" }
        };

        public static Transaction FindTransaction(string Code)
        {
            foreach (Transaction t in Transactions)
                if (t.Code == Code) return t;
            return null;
        }
        #endregion

        #region Reads
        public static DataTable GetMatrix(int ActingUserId, DateTime AsOn, out int Reason, out string Detail)
        {
            return GovernanceDB.GetMatrix(ActingUserId, AsOn, out Reason, out Detail);
        }

        public static DataTable GetSettings(int ActingUserId, DateTime AsOn, out int Reason, out string Detail)
        {
            return GovernanceDB.GetSettings(ActingUserId, AsOn, out Reason, out Detail);
        }

        public static DataTable GetDepartments(int ActingUserId, DateTime AsOn, out int Reason, out string Detail)
        {
            return GovernanceDB.GetDepartments(ActingUserId, AsOn, out Reason, out Detail);
        }

        public static DataTable GetChangeLog(int ActingUserId, DateTime From, DateTime To, int UserId, int DepartmentId, string ChangeType, out int Reason)
        {
            return GovernanceDB.GetChangeLog(ActingUserId, From, To, UserId, DepartmentId, ChangeType, out Reason);
        }

        public static DataTable GetLogUsers(int ActingUserId, out int Reason)
        {
            return GovernanceDB.GetLogUsers(ActingUserId, out Reason);
        }
        #endregion

        #region Messages
        /// <summary>The page's text for a refusal of the matrix or the change log (plain text; the page encodes it).</summary>
        public static string RefusalMessage(int Reason, string HistoryStart)
        {
            switch (Reason)
            {
                case ReasonBeforeHistory:
                    DateTime start;
                    string shown = DateTime.TryParseExact(HistoryStart, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out start)
                        ? start.ToString(DateFormat, CultureInfo.InvariantCulture) : HistoryStart;
                    return "History starts on " + shown + ". Choose that date or a later one.";
                case ReasonDateNotValid:
                    return "The As-on date cannot be after today. Choose today or an earlier date.";
                case ReasonRangeNotValid:
                    return "Choose a From date that is not after the To date, and a To date that is not after today.";
                case 8:
                    return "Your account is not active. Sign in again.";
                default:
                    return "You are not allowed to see this page.";
            }
        }

        public static string ChangeTypeName(string Code)
        {
            switch ((Code ?? string.Empty).Trim())
            {
                case "UA": return "User added";
                case "RC": return "Role changed";
                case "HC": return "Home department changed";
                case "DA": return "Manager department added";
                case "DR": return "Manager department removed";
                case "RP": return "Reporting Person changed";
                case "UV": return "Activated";
                case "UD": return "Deactivated";
                case "UX": return "Deleted";
                case "KA": return "Department activated";
                case "KD": return "Department deactivated";
                case "ST": return "Setting changed";
                default: return Code;
            }
        }

        public static readonly string[] ChangeTypes = { "UA", "RC", "HC", "DA", "DR", "RP", "UV", "UD", "UX", "KA", "KD", "ST" };

        public static string SourceName(string Source)
        {
            if (Source == "History") return "From history";
            if (Source == "AuditTrail") return "From audit trail";
            return "Recorded";
        }

        public static string SettingName(string SettingCode)
        {
            if (SettingCode == "DeptNoManagerAction") return "Department without an active Manager";
            if (SettingCode == "AgendaControllerBypass") return "Controller changes the agenda after finalisation";
            return SettingCode;
        }

        public static string DeptRuleText(string Value)
        {
            return Value == "controller" ? "Sent to the Controller" : (string.IsNullOrEmpty(Value) ? "Refused (not set: the default)" : "Refused");
        }

        public static string BypassText(string Value)
        {
            return Value == "0" ? "Not allowed" : (string.IsNullOrEmpty(Value) ? "Allowed (not set: the default)" : "Allowed");
        }

        /// <summary>A setting value of the change log as words (the code stays in the log).</summary>
        public static string SettingValueText(string SettingCode, string Value)
        {
            if (SettingCode == "DeptNoManagerAction") return DeptRuleText(Value);
            if (SettingCode == "AgendaControllerBypass") return BypassText(Value);
            return Value;
        }
        #endregion

        #region BuildMatrix
        private sealed class Person
        {
            public string Text;
            public string Sort;
        }

        private static string PersonText(DataRow r, bool IsLive)
        {
            string text = Common.UserDisplayName(Convert.ToString(r["UserName"]), Convert.ToString(r["LoginName"]), true);
            if (Convert.ToInt32(r["IsSystem"]) == 1)
                text += " (system account)";
            if (!IsLive && Convert.ToInt32(r["ActiveNow"]) != 1)
                text += " (inactive now)";
            return text;
        }

        private static string Join(List<Person> People)
        {
            if (People == null || People.Count == 0)
                return string.Empty;
            People.Sort(delegate(Person a, Person b) { return string.Compare(a.Sort, b.Sort, StringComparison.OrdinalIgnoreCase); });
            List<string> parts = new List<string>();
            foreach (Person p in People)
                if (!parts.Contains(p.Text)) parts.Add(p.Text);
            return string.Join(", ", parts.ToArray());
        }

        /// <summary>
        /// The rows of the matrix grid: Transaction, Department, WhoEnters, WhoApproves, Controllers, RuleNote (plain text),
        /// with TransactionCode and DepartmentId for the filters. People: the database rows; departments: the database rows
        /// as on the day; settings: the row of spr_GetGovernanceSettings; RolesForPage: PageAccessModule.RolesForPage (null
        /// when the policy cannot be read). DepartmentId 0 and TransactionCode "" = all.
        /// </summary>
        public static DataTable BuildMatrix(DataTable People, DataTable Departments, DataRow Settings, Func<string, string[]> RolesForPage,
                                            int DepartmentFilter, string TransactionFilter, bool IsLive, bool ReportingKnown)
        {
            DataTable dt = new DataTable();
            dt.Columns.Add("TransactionCode", typeof(string));
            dt.Columns.Add("DepartmentId", typeof(int));
            dt.Columns.Add("Transaction", typeof(string));
            dt.Columns.Add("Department", typeof(string));
            dt.Columns.Add("WhoEnters", typeof(string));
            dt.Columns.Add("WhoApproves", typeof(string));
            dt.Columns.Add("Controllers", typeof(string));
            dt.Columns.Add("RuleNote", typeof(string));

            // People of a rule: (code|department|column) -> people; people of a role: role -> people
            Dictionary<string, List<Person>> rule = new Dictionary<string, List<Person>>();
            Dictionary<string, List<Person>> role = new Dictionary<string, List<Person>>();
            foreach (DataRow r in People.Rows)
            {
                Person p = new Person { Text = PersonText(r, IsLive), Sort = Convert.ToString(r["UserName"]) + "|" + Convert.ToString(r["LoginName"]) };
                string kind = Convert.ToString(r["Kind"]);
                string key = kind == "P"
                    ? Convert.ToString(r["TransactionCode"]) + "|" + Convert.ToString(r["DepartmentId"]) + "|" + Convert.ToString(r["Col"])
                    : Convert.ToString(r["RoleCode"]).Trim();
                Dictionary<string, List<Person>> map = kind == "P" ? rule : role;
                if (!map.ContainsKey(key)) map[key] = new List<Person>();
                map[key].Add(p);
            }

            string deptRule = Settings == null ? string.Empty : Convert.ToString(Settings["DeptNoManagerAction"]);
            string bypass = Settings == null ? string.Empty : Convert.ToString(Settings["AgendaControllerBypass"]);

            foreach (Transaction t in Transactions)
            {
                if (!string.IsNullOrEmpty(TransactionFilter) && t.Code != TransactionFilter)
                    continue;

                if (t.PerDepartment)
                {
                    foreach (DataRow d in Departments.Rows)
                    {
                        int id = Convert.ToInt32(d["DepartmentId"]);
                        if (DepartmentFilter > 0 && id != DepartmentFilter)
                            continue;
                        bool active = Convert.ToInt32(d["IsActive"]) == 1;
                        string name = Convert.ToString(d["DepartmentName"]) + (active ? string.Empty : " (inactive)");
                        AddRuleRow(dt, t, id, name, active, rule, deptRule, bypass, ReportingKnown);
                    }
                }
                else if (t.PagePath == null)
                {
                    AddRuleRow(dt, t, 0, "All departments", true, rule, deptRule, bypass, ReportingKnown);
                }
                else
                {
                    string[] roles = RolesForPage == null ? null : RolesForPage(t.PagePath);
                    DataRow row = dt.NewRow();
                    row["TransactionCode"] = t.Code;
                    row["DepartmentId"] = 0;
                    row["Transaction"] = t.Name;
                    row["Department"] = "All departments";
                    if (roles == null)
                    {
                        row["WhoEnters"] = string.Empty;
                        row["RuleNote"] = "The page rules (PageAccess.xml) could not be read.";
                    }
                    else
                    {
                        List<string> names = new List<string>();
                        List<string> parts = new List<string>();
                        foreach (string rc in ExpandRoles(roles))
                        {
                            if (t.ReadOnlyRoles != null && Array.IndexOf(t.ReadOnlyRoles, rc) >= 0)
                                continue;
                            names.Add(RoleName(rc));
                            List<Person> ps;
                            string people = role.TryGetValue(rc, out ps) ? Join(ps) : string.Empty;
                            parts.Add(RoleName(rc) + ": " + (people.Length == 0 ? "nobody" : people));
                        }
                        row["WhoEnters"] = string.Join("; ", parts.ToArray());
                        string note = "Rule of the page: " + (names.Count == 0 ? "nobody" : string.Join(", ", names.ToArray())) + ".";
                        if (t.ReadOnlyRoles != null)
                        {
                            List<string> ro = new List<string>();
                            foreach (string rc in t.ReadOnlyRoles)
                                if (Array.IndexOf(ExpandRoles(roles), rc) >= 0) ro.Add(RoleName(rc));
                            if (ro.Count > 0)
                                note += " " + string.Join(", ", ro.ToArray()) + " can open the page to read only.";
                        }
                        row["RuleNote"] = note;
                    }
                    row["WhoApproves"] = string.Empty;
                    row["Controllers"] = string.Empty;
                    dt.Rows.Add(row);
                }
            }
            return dt;
        }

        public static string[] ExpandRoles(string[] Roles)
        {
            List<string> list = new List<string>();
            foreach (string r in Roles)
            {
                if (r == "*") return (string[])AllRoles.Clone();
                foreach (string a in AllRoles)
                    if (string.Equals(a, r, StringComparison.OrdinalIgnoreCase) && !list.Contains(a)) list.Add(a);
            }
            return list.ToArray();
        }

        private static string People(Dictionary<string, List<Person>> Rule, string Code, int DepartmentId, string Col)
        {
            List<Person> ps;
            return Rule.TryGetValue(Code + "|" + DepartmentId.ToString(CultureInfo.InvariantCulture) + "|" + Col, out ps) ? Join(ps) : string.Empty;
        }

        private static void AddRuleRow(DataTable dt, Transaction t, int DepartmentId, string DepartmentName, bool Active,
                                       Dictionary<string, List<Person>> Rule, string DeptRule, string Bypass, bool ReportingKnown)
        {
            DataRow row = dt.NewRow();
            row["TransactionCode"] = t.Code;
            row["DepartmentId"] = DepartmentId;
            row["Transaction"] = t.Name;
            row["Department"] = DepartmentName;
            string enters = string.Empty, approves = string.Empty, controllers = string.Empty;
            List<string> note = new List<string>();

            switch (t.Code)
            {
                case "AGU":
                    enters = People(Rule, "AGU", DepartmentId, "E");
                    approves = People(Rule, "AGU", DepartmentId, "A");
                    controllers = People(Rule, "AGU", DepartmentId, "C");
                    if (approves.Length > 0)
                    {
                        approves = "Any one of: " + approves;
                        note.Add("A Manager approves first, then a Controller.");
                    }
                    else
                        note.Add(DeptRule == "controller"
                            ? "No active Manager: new items of Users go to the Controllers (System Settings)."
                            : "No active Manager: new items of Users are refused (System Settings).");
                    string routeC = People(Rule, "AGU", DepartmentId, "R");
                    if (routeC.Length > 0)
                        note.Add("Straight to the Controller (their Reporting Person is a Controller): " + routeC + ".");
                    string refused = People(Rule, "AGU", DepartmentId, "I");
                    if (refused.Length > 0)
                        note.Add("New items refused (their Reporting Person is inactive): " + refused + ".");
                    if (!ReportingKnown)
                        note.Add("Reporting Person not recorded for this date: the route to the Controller is not shown.");
                    break;
                case "AGM":
                    enters = People(Rule, "AGM", DepartmentId, "E");
                    controllers = People(Rule, "AGM", DepartmentId, "C");
                    note.Add("Saved as approved by the Manager; a Controller approves. The other Managers of the department are alerted.");
                    break;
                case "APM":
                    approves = People(Rule, "APM", DepartmentId, "A");
                    if (approves.Length > 0) approves = "Any one of: " + approves;
                    note.Add("Never the item's own creator; only until the meeting date.");
                    break;
                case "AGC":
                    enters = People(Rule, "AGC", 0, "E");
                    note.Add("Saved as approved by the Controller. After the agenda is finalised: "
                             + (Bypass == "0" ? "not allowed" : "allowed until the minutes are finalised") + " (System Settings).");
                    break;
                case "APC":
                    controllers = People(Rule, "APC", 0, "C");
                    note.Add("Approves or rejects the items a Manager approved; may also reject an item still waiting for a Manager.");
                    break;
                case "AIR":
                    enters = People(Rule, "AIR", 0, "E");
                    note.Add("Rows written at Minutes Finalisation: every active user except the Admin role. A followup decided after the finalisation: a row for the item's creator only (an inactive creator: the active Controllers).");
                    break;
                case "AIS":
                    enters = People(Rule, "AIS", DepartmentId, "E");
                    note.Add("Controller and Management: every item. Managers and Users of the department: once the minutes are finalised.");
                    break;
            }

            if (!Active && (t.Code == "AGU" || t.Code == "AGM"))
                note.Add("Department inactive: no new agenda items.");

            row["WhoEnters"] = enters;
            row["WhoApproves"] = approves;
            row["Controllers"] = controllers;
            row["RuleNote"] = string.Join(" ", note.ToArray());
            dt.Rows.Add(row);
        }
        #endregion

        #region ReadOnlyAccess
        /// <summary>One menu entry: its title, the page (application-relative, no query) and the roles that see it.</summary>
        public class MenuEntry
        {
            public string Title;
            public string Page;
            public List<string> Roles = new List<string>();
        }

        private static readonly Regex MenuToken = new Regex(
            @"<%--.*?--%>" +
            @"|<%\s*if\s*\((?<cond>.*?)\)\s*\{\s*%>" +
            @"|<%\s*\}\s*%>" +
            @"|<ul\s+id=""(?<ul>\w+)""" +
            @"|</ul>" +
            @"|<a\s+href=""#""\s+rel=""(?<rel>\w+)""\s*>" +
            @"|<a\s+href=""(?<href>[^""#]+)""\s*>(?<title>[^<]+)</a>",
            RegexOptions.Singleline | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

        private static readonly Regex RoleEq = new Regex(@"==\s*""(?<r>\w+)""", RegexOptions.CultureInvariant);
        private static readonly Regex RoleNe = new Regex(@"!=\s*""(?<r>\w+)""", RegexOptions.CultureInvariant);

        private static List<string> ConditionRoles(string Condition)
        {
            List<string> roles = new List<string>();
            MatchCollection eq = RoleEq.Matches(Condition);
            if (eq.Count > 0)
            {
                foreach (Match m in eq) if (!roles.Contains(m.Groups["r"].Value)) roles.Add(m.Groups["r"].Value);
                return roles;
            }
            List<string> not = new List<string>();
            foreach (Match m in RoleNe.Matches(Condition)) not.Add(m.Groups["r"].Value);
            foreach (string r in AllRoles) if (!not.Contains(r)) roles.Add(r);
            return roles;
        }

        private static List<string> Intersect(List<string> A, List<string> B)
        {
            List<string> c = new List<string>();
            foreach (string x in A) if (B.Contains(x)) c.Add(x);
            return c;
        }

        /// <summary>
        /// The links of the menu control (MenuUserControl.ascx) with the roles that see each: the roles of the
        /// "if (Session["RoleCode"] ...)" blocks around it and, for a drop-down entry, of the top-level link that opens
        /// that drop-down. Commented-out markup is left out. Null when the text has no link.
        /// </summary>
        public static List<MenuEntry> ReadMenu(string MenuText)
        {
            List<MenuEntry> entries = new List<MenuEntry>();
            Dictionary<string, List<string>> dropDownRoles = new Dictionary<string, List<string>>();
            Stack<List<string>> blocks = new Stack<List<string>>();
            string currentUl = null;
            List<string> all = new List<string>(AllRoles);

            foreach (Match m in MenuToken.Matches(MenuText ?? string.Empty))
            {
                string v = m.Value;
                List<string> now = all;
                foreach (List<string> b in blocks) now = Intersect(now, b);

                if (v.StartsWith("<%--", StringComparison.Ordinal))
                    continue;
                if (m.Groups["cond"].Success)
                {
                    blocks.Push(ConditionRoles(m.Groups["cond"].Value));
                    continue;
                }
                if (v.StartsWith("<%", StringComparison.Ordinal))
                {
                    if (blocks.Count > 0) blocks.Pop();
                    continue;
                }
                if (m.Groups["ul"].Success) { currentUl = m.Groups["ul"].Value; continue; }
                if (v.StartsWith("</ul", StringComparison.OrdinalIgnoreCase)) { currentUl = null; continue; }
                if (m.Groups["rel"].Success)
                {
                    string rel = m.Groups["rel"].Value;
                    if (!dropDownRoles.ContainsKey(rel)) dropDownRoles[rel] = new List<string>();
                    foreach (string r in now) if (!dropDownRoles[rel].Contains(r)) dropDownRoles[rel].Add(r);
                    continue;
                }
                if (m.Groups["href"].Success)
                {
                    List<string> roles = now;
                    if (currentUl != null)
                        roles = dropDownRoles.ContainsKey(currentUl) ? Intersect(now, dropDownRoles[currentUl]) : new List<string>();
                    string page = m.Groups["href"].Value.Trim();
                    while (page.StartsWith("../", StringComparison.Ordinal)) page = page.Substring(3);
                    int q = page.IndexOf('?');
                    string pagePath = q >= 0 ? page.Substring(0, q) : page;
                    MenuEntry e = new MenuEntry { Title = HttpUtility.HtmlDecode(m.Groups["title"].Value.Trim()), Page = pagePath };
                    e.Roles.AddRange(roles);
                    entries.Add(e);
                }
            }
            return entries.Count == 0 ? null : entries;
        }

        private const string DashboardPage = "DashBoard/DashBoard.aspx";

        // Roles that see the Dashboard's action items but cannot save them (fn_DashboardActionItemScope lists the items
        // for Management; spr_SaveDashboardActionText accepts the Controller, Manager and User only)
        private static readonly string[] DashboardReadOnlyRoles = { "mgmt" };

        /// <summary>
        /// Gate B (GM1a): the name of an entry of the Read-only access block, by its page, so that a report and a page
        /// with the same menu title cannot be confused: the Dashboard ("(read only)" for a role that sees its action
        /// items without saving them), a page under Report/ "[title] report", any other page "[title] page", with
        /// "(read only)" when the transaction of that page lists the role as one that only reads there.
        /// </summary>
        public static string ReadOnlyEntryName(string Page, string Title, string RoleCode)
        {
            if (string.Equals(Page, DashboardPage, StringComparison.OrdinalIgnoreCase))
                return "Dashboard" + (Array.IndexOf(DashboardReadOnlyRoles, RoleCode) >= 0 ? " (read only)" : string.Empty);

            if (Page.StartsWith("Report/", StringComparison.OrdinalIgnoreCase))
                return Title + " report";

            foreach (Transaction t in Transactions)
                if (t.PagePath != null && t.ReadOnlyRoles != null
                    && string.Equals(t.PagePath, Page, StringComparison.OrdinalIgnoreCase)
                    && Array.IndexOf(t.ReadOnlyRoles, RoleCode) >= 0)
                    return Title + " page (read only)";

            return Title + " page";
        }

        /// <summary>
        /// The Read-only access block (M6, C2): for Management and MD Secretariat, the people of the role on the day and
        /// what the role can read: the menu entries the role sees whose page PageAccess.xml allows for the role, and the
        /// Dashboard (every role lands there after signing in). Columns Role, People, CanRead (plain text).
        /// </summary>
        public static DataTable BuildReadOnly(DataTable People, List<MenuEntry> Menu, Func<string, string[]> RolesForPage, bool IsLive)
        {
            DataTable dt = new DataTable();
            dt.Columns.Add("Role", typeof(string));
            dt.Columns.Add("People", typeof(string));
            dt.Columns.Add("CanRead", typeof(string));

            foreach (string rc in new[] { "mgmt", "md_sect" })
            {
                List<Person> ps = new List<Person>();
                foreach (DataRow r in People.Rows)
                    if (Convert.ToString(r["Kind"]) == "H" && Convert.ToString(r["RoleCode"]).Trim() == rc)
                        ps.Add(new Person { Text = PersonText(r, IsLive), Sort = Convert.ToString(r["UserName"]) + "|" + Convert.ToString(r["LoginName"]) });

                string canRead;
                if (Menu == null || RolesForPage == null)
                    canRead = "The menu or the page rules could not be read.";
                else
                {
                    List<string> items = new List<string>();
                    string[] dash = RolesForPage(DashboardPage);
                    if (dash != null && Array.IndexOf(ExpandRoles(dash), rc) >= 0)
                        items.Add(ReadOnlyEntryName(DashboardPage, "Dashboard", rc));
                    foreach (MenuEntry e in Menu)
                    {
                        if (!e.Roles.Contains(rc)) continue;
                        string[] allowed = RolesForPage(e.Page);
                        if (allowed == null || Array.IndexOf(ExpandRoles(allowed), rc) < 0) continue;
                        string title = ReadOnlyEntryName(e.Page, e.Title, rc);
                        if (!items.Contains(title)) items.Add(title);
                    }
                    canRead = items.Count == 0 ? "Nothing" : string.Join(", ", items.ToArray());
                }

                DataRow row = dt.NewRow();
                row["Role"] = RoleName(rc);
                row["People"] = ps.Count == 0 ? "Nobody" : Join(ps);
                row["CanRead"] = canRead;
                dt.Rows.Add(row);
            }
            return dt;
        }
        #endregion

        #region Exports
        /// <summary>A CSV cell: quoted; a cell that begins with = + - @, a tab or a carriage return gets a leading ' so
        /// that a spreadsheet does not read it as a formula (C4).</summary>
        public static string CsvCell(string Value)
        {
            string v = Value ?? string.Empty;
            if (v.Length > 0 && "=+-@\t\r".IndexOf(v[0]) >= 0)
                v = "'" + v;
            return "\"" + v.Replace("\"", "\"\"") + "\"";
        }

        /// <summary>The CSV text of a table: a title line, then the header and the rows of the columns given.</summary>
        public static string Csv(string Title, DataTable Table, string[] Columns, string[] Headers)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append(CsvCell(Title)).Append("\r\n");
            for (int i = 0; i < Headers.Length; i++)
                sb.Append(i == 0 ? string.Empty : ",").Append(CsvCell(Headers[i]));
            sb.Append("\r\n");
            foreach (DataRow r in Table.Rows)
            {
                for (int i = 0; i < Columns.Length; i++)
                    sb.Append(i == 0 ? string.Empty : ",").Append(CsvCell(Convert.ToString(r[Columns[i]])));
                sb.Append("\r\n");
            }
            return sb.ToString();
        }

        /// <summary>A simple HTML table for the PDF (every value encoded; border='1' without a unit for HTMLWorker).</summary>
        public static string HtmlTable(string Heading, DataTable Table, string[] Columns, string[] Headers)
        {
            StringBuilder sb = new StringBuilder();
            if (!string.IsNullOrEmpty(Heading))
                sb.Append("<p><b>").Append(HttpUtility.HtmlEncode(Heading)).Append("</b></p>");
            sb.Append("<table border='1' cellpadding='3' width='100%'><tr>");
            foreach (string h in Headers)
                sb.Append("<th>").Append(HttpUtility.HtmlEncode(h)).Append("</th>");
            sb.Append("</tr>");
            foreach (DataRow r in Table.Rows)
            {
                sb.Append("<tr>");
                foreach (string c in Columns)
                    sb.Append("<td>").Append(HttpUtility.HtmlEncode(Convert.ToString(r[c]))).Append("</td>");
                sb.Append("</tr>");
            }
            sb.Append("</table>");
            return sb.ToString();
        }
        #endregion
    }
    #endregion
}
