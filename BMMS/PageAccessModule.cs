using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web;
using System.Web.Caching;
using System.Web.Configuration;
using System.Xml;

namespace BMMS.Security
{
    /// <summary>
    /// Central page-access guard for BMMS.
    ///
    /// Runs on every .aspx request, after session state is available, and applies
    /// the policy in ~/XML/PageAccess.xml:
    ///   1. Public pages (login, logout, error page) are always allowed.
    ///   2. Everything else requires a logged-in user. Anyone else is sent to the
    ///      login page (this also protects the pages that never called
    ///      Common.InitSetup: ResetDatabase, BackupDatabase, ResetPassword,
    ///      SMTPServerConfig, ViewReport).
    ///      Step RA1d: the session must still match the database (spr_GetUserAccessState,
    ///      step 51, read once per request): the user exists and is active, and the role
    ///      and the department set are those taken at sign-in. Otherwise the session ends
    ///      (SESSION-ENDED in the log, Session.Abandon, the session cookie expired) and the
    ///      sign-in page says why with a fixed text. A database error ends nothing: the
    ///      page does not run, the safe error page is shown (SESSION-CHECK-ERROR in the log)
    ///      and the next request checks again.
    ///   3. The user's role (Session["RoleCode"]) must be listed for the page.
    ///      A page that is not in the policy at all is treated as not allowed.
    ///
    /// Mode (attribute on the root element of PageAccess.xml):
    ///   LogOnly - nothing is blocked for role reasons; each request that WOULD be
    ///             denied is written to App_Data\PageAccessLog.txt. Use this first.
    ///   Enforce - denied requests get an "Access denied" page (HTTP 403).
    /// The login requirement in step 2 applies in both modes.
    ///
    /// The policy file is cached and reloaded automatically when it changes.
    /// If it cannot be read, only the login requirement is applied and the
    /// problem is written to the log.
    /// </summary>
    public class PageAccessModule : IHttpModule
    {
        private const string CacheKey = "BMMS.PageAccess.Policy";
        private static readonly object LogLock = new object();

        /// <summary>
        /// Step RA1d: the session key of the department set taken at sign-in (UserAccessState.DepartmentSet),
        /// set by Default.aspx and compared on every checked request.
        /// </summary>
        public const string SessionDepartmentSetKey = "DepartmentSet";

        // Step RA1d: the codes the sign-in page maps to its fixed texts (Default.aspx); never any other value
        public const string StatusInactive = "inactive";
        public const string StatusChanged = "changed";

        // Step RA1d: this request's read of spr_GetUserAccessState (HttpContext.Items), reused by RequireRole and HasRole
        private const string AccessReadKey = "BMMS.PageAccess.AccessState";

        private sealed class AccessRead
        {
            public BMMSBAL.UserAccessState State;   // null: the user is not in View_Users
        }

        private sealed class Policy
        {
            public bool Enforce;
            public string LoadError;
            public readonly HashSet<string> PublicPages = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            public readonly Dictionary<string, string[]> Pages = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
        }

        public void Init(HttpApplication application)
        {
            application.PostAcquireRequestState += OnPostAcquireRequestState;
        }

        public void Dispose() { }

        private void OnPostAcquireRequestState(object sender, EventArgs e)
        {
            HttpApplication app = (HttpApplication)sender;
            HttpContext ctx = app.Context;

            string appPath = ctx.Request.AppRelativeCurrentExecutionFilePath;
            if (appPath == null
                || !appPath.StartsWith("~/", StringComparison.Ordinal)
                || !appPath.EndsWith(".aspx", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            string page = appPath.Substring(2);
            Policy policy = GetPolicy(ctx);

            if (policy.PublicPages.Contains(page))
                return;

            // --- 1. must be logged in: a UserId in the session (step UN2) ---------------
            if (!BMMSBAL.Common.IsLoggedIn())
            {
                RedirectToLogin(app, ctx);
                return;
            }

            // --- 1b. step RA1d: the session still matches the database (status, role, department set) ---------
            AccessRead read = ReadAccessState(ctx);
            if (read == null)
            {
                // Database error (in the error log): fail closed for this request only; the session is kept
                Log(ctx, "SESSION-CHECK-ERROR", page, Convert.ToString(ctx.Session["RoleCode"]),
                    "UserId " + Convert.ToString(ctx.Session["UserId"]) + "; database error; the session is kept");
                BMMS.Global.WriteSafeAnswer(ctx, 500);
                return;
            }

            string endReason, status;
            if (!SessionMatches(ctx, read.State, out endReason, out status))
            {
                EndSession(app, ctx, page, endReason, status);
                return;
            }

            if (policy.LoadError != null)
            {
                Log(ctx, "POLICY-NOT-LOADED", page, "", policy.LoadError);
                return;
            }

            // --- 2. role must be allowed for this page --------------------------------
            string role = ctx.Session["RoleCode"] as string ?? string.Empty;
            string[] allowed;
            bool known = policy.Pages.TryGetValue(page, out allowed);

            if (known && IsAllowed(allowed, role))
                return;

            string reason = known
                ? "role not allowed (allowed: " + string.Join(",", allowed) + ")"
                : "page is not in PageAccess.xml";

            if (!policy.Enforce)
            {
                Log(ctx, "WOULD-DENY", page, role, reason);
                return;
            }

            Log(ctx, "DENIED", page, role, reason);
            Deny(app, ctx);
        }

        /// <summary>
        /// Step RA1a: a second check inside a page (and before an action) that only some roles may use.
        /// The role is read from the database by the session's UserId, not from Session["RoleCode"], so it
        /// also holds when PageAccess.xml is in LogOnly mode, for a session opened before a deployment and
        /// for a role changed during the session. When the user is not an active user with one of the
        /// roles, the request gets the same "Access denied" page (HTTP 403) as the module, is written to
        /// the log as DENIED-PAGE, and ends here (Response.End): no event handler of the page runs.
        /// Call it outside any try/catch, as the first line of Page_Load and of the action handler.
        /// A database error denies (fail closed) and is written to the error log.
        /// </summary>
        public static void RequireRole(params string[] roles)
        {
            HttpContext ctx = HttpContext.Current;
            string role = ReadDatabaseRole(ctx, "RequireRole");

            if (role.Length > 0 && IsAllowed(roles, role))
                return;

            RefuseRequest(ctx, role, "role not allowed by the page (allowed: " + string.Join(",", roles) + ")");
        }

        /// <summary>
        /// Step RA1b: true when the session's user is an active user with one of the roles, read from the
        /// database as RequireRole reads it (not Session["RoleCode"]). It refuses nothing itself: a page
        /// uses it to choose a path (for example the every-status Minutes report). A database error gives
        /// false and is written to the error log.
        /// </summary>
        public static bool HasRole(params string[] roles)
        {
            string role = ReadDatabaseRole(HttpContext.Current, "HasRole");
            return role.Length > 0 && IsAllowed(roles, role);
        }

        /// <summary>
        /// Step RA1b: refuses the current request as RequireRole does (DENIED-PAGE in the log with the
        /// reason given, the "Access denied" page, Response.End), for a request the page itself rejects,
        /// for example an unknown report code. Call it outside any try/catch.
        /// </summary>
        public static void RefuseRequest(string reason)
        {
            HttpContext ctx = HttpContext.Current;
            RefuseRequest(ctx, ReadDatabaseRole(ctx, "RefuseRequest"), reason);
        }

        /// <summary>
        /// Step GM1a: the roles PageAccess.xml allows for a page (application-relative path, for example
        /// "Master/AgendaFinalization.aspx"), read from the same cached policy the module enforces, so the Governance
        /// Matrix shows the rule that is applied and keeps no copy of it. An empty array for a page that is not listed
        /// (not allowed), "*" as written for any signed-in user; null when the policy could not be read.
        /// </summary>
        public static string[] RolesForPage(string path)
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null)
                return null;

            Policy policy = GetPolicy(ctx);
            if (policy.LoadError != null)
                return null;

            string[] roles;
            return policy.Pages.TryGetValue(NormalizePath(path), out roles) ? (string[])roles.Clone() : new string[0];
        }

        private static void RefuseRequest(HttpContext ctx, string role, string reason)
        {
            string page = (ctx.Request.AppRelativeCurrentExecutionFilePath ?? string.Empty).TrimStart('~', '/');
            Log(ctx, "DENIED-PAGE", page, role, reason);
            Deny(ctx.ApplicationInstance, ctx);
            ctx.Response.End();
        }

        // The role code of the session's user when that user is active (Users.AccountStatus = 1), read from the
        // database (View_Users through UserMgr.GetUserDataTableByUserId); "" for no user, an inactive user or a
        // database error (written to the error log under the caller's name).
        // Step RA1d: the module has already read View_Users for this request (spr_GetUserAccessState, the same
        // view and columns) and ended the session if it did not match; that read is reused, so the nine RA1a
        // pages make no second call. Without it (a request the module did not check) the old read is made.
        private static string ReadDatabaseRole(HttpContext ctx, string caller)
        {
            int userId;
            if (!int.TryParse(Convert.ToString(ctx.Session["UserId"]), out userId) || userId <= 0)
                return string.Empty;

            AccessRead read = ctx.Items[AccessReadKey] as AccessRead;
            if (read != null && read.State != null && read.State.UserId == userId)
                return read.State.IsActive ? read.State.RoleCode : string.Empty;

            try
            {
                System.Data.DataTable dt = BMMSBAL.UserMgr.GetUserDataTableByUserId(userId);
                if (dt != null && dt.Rows.Count > 0
                    && dt.Columns.Contains("RoleCode") && dt.Columns.Contains("AccountStatus")
                    && Convert.ToString(dt.Rows[0]["AccountStatus"]) == "1")
                {
                    return Convert.ToString(dt.Rows[0]["RoleCode"]).Trim();
                }
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.WriteErrorLog("PageAccessModule", caller, ex.ToString());
            }
            return string.Empty;
        }

        private static bool IsAllowed(string[] allowed, string role)
        {
            foreach (string r in allowed)
            {
                if (r == "*") return true;
                if (string.Equals(r, role, StringComparison.OrdinalIgnoreCase)) return true;
            }
            return false;
        }

        private static bool IsAjaxPartialPostBack(HttpContext ctx)
        {
            string h = ctx.Request.Headers["X-MicrosoftAjax"];
            return h != null && h.IndexOf("Delta=true", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        // Step RA1d: one call to spr_GetUserAccessState for the session's user, kept in HttpContext.Items for the
        // rest of the request. null on a database error (written to the error log); AccessRead.State null when the
        // user is not in View_Users.
        private static AccessRead ReadAccessState(HttpContext ctx)
        {
            AccessRead read = ctx.Items[AccessReadKey] as AccessRead;
            if (read != null)
                return read;

            read = new AccessRead();
            int userId;
            if (!int.TryParse(Convert.ToString(ctx.Session["UserId"]), out userId) || userId <= 0)
            {
                ctx.Items[AccessReadKey] = read;
                return read;
            }

            try
            {
                read.State = BMMSBAL.UserMgr.GetUserAccessState(userId);
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.WriteErrorLog("PageAccessModule", "SessionCheck", ex.ToString());
                return null;
            }
            ctx.Items[AccessReadKey] = read;
            return read;
        }

        // Step RA1d: true when the session still matches the database. Otherwise the reason for the log
        // (missing / inactive / role X to Y / departments changed) and the code for the sign-in page.
        private static bool SessionMatches(HttpContext ctx, BMMSBAL.UserAccessState state, out string reason, out string status)
        {
            reason = string.Empty;
            status = string.Empty;

            if (state == null)
            {
                reason = "missing";
                status = StatusInactive;
                return false;
            }
            if (!state.IsActive)
            {
                reason = "inactive";
                status = StatusInactive;
                return false;
            }

            string sessionRole = (Convert.ToString(ctx.Session["RoleCode"]) ?? string.Empty).Trim();
            string sessionSet = ctx.Session[SessionDepartmentSetKey] as string;
            bool roleChanged = !string.Equals(sessionRole, state.RoleCode, StringComparison.OrdinalIgnoreCase);
            // A session without the stamp (none survives a deployment: the sessions are InProc) counts as changed
            bool setChanged = sessionSet == null || !string.Equals(sessionSet, state.DepartmentSet, StringComparison.Ordinal);

            if (!roleChanged && !setChanged)
                return true;

            if (roleChanged)
                reason = "role " + sessionRole + " to " + state.RoleCode;
            if (setChanged)
                reason = (reason.Length > 0 ? reason + "; " : string.Empty) + "departments changed";
            status = StatusChanged;
            return false;
        }

        // Step RA1d: ends the session of a user whose access changed. The log line first (it reads the session),
        // then Session.Abandon without Clear, so Global.Session_End still has the UserId and closes the open
        // login rows (Audit_Trial_Login) as at sign-out. The session cookie is expired, so the sign-in page
        // starts with a new session id. Authentication is Windows: there is no forms cookie to clear.
        private static void EndSession(HttpApplication app, HttpContext ctx, string page, string reason, string status)
        {
            Log(ctx, "SESSION-ENDED", page, Convert.ToString(ctx.Session["RoleCode"]),
                "UserId " + Convert.ToString(ctx.Session["UserId"]) + "; " + reason);

            ctx.Session.Abandon();
            RedirectToLogin(app, ctx, "?status=" + status);

            // After the redirect: RedirectToLogin clears the response for an UpdatePanel postback
            HttpCookie expired = new HttpCookie(SessionCookieName(), string.Empty);
            expired.Expires = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            expired.HttpOnly = true;
            expired.Path = "/";
            ctx.Response.Cookies.Add(expired);
        }

        private static string SessionCookieName()
        {
            try
            {
                SessionStateSection section = WebConfigurationManager.GetSection("system.web/sessionState") as SessionStateSection;
                if (section != null && !string.IsNullOrEmpty(section.CookieName))
                    return section.CookieName;
            }
            catch (Exception)
            {
            }
            return "ASP.NET_SessionId";
        }

        private static void RedirectToLogin(HttpApplication app, HttpContext ctx)
        {
            RedirectToLogin(app, ctx, string.Empty);
        }

        private static void RedirectToLogin(HttpApplication app, HttpContext ctx, string query)
        {
            string url = VirtualPathUtility.ToAbsolute("~/Default.aspx") + query;

            if (IsAjaxPartialPostBack(ctx))
            {
                // UpdatePanel request: answer in the ASP.NET AJAX "pageRedirect" format so the
                // browser navigates to the login page instead of showing a script error.
                string encoded = HttpUtility.UrlPathEncode(url);
                ctx.Response.Clear();
                ctx.Response.ContentType = "text/plain";
                ctx.Response.Write("1|#||4|" + encoded.Length + "|pageRedirect||" + encoded + "|");
            }
            else
            {
                ctx.Response.Redirect(url, false);
            }
            app.CompleteRequest();
        }

        private static void Deny(HttpApplication app, HttpContext ctx)
        {
            ctx.Response.Clear();
            ctx.Response.TrySkipIisCustomErrors = true;
            ctx.Response.StatusCode = 403;
            ctx.Response.StatusDescription = "Forbidden";
            ctx.Response.ContentType = "text/html";
            // The colours are copies of the palette (CSS/bmms-colours.css, step B3): page-bg, text, heading,
            // link, link-visited, link-hover, focus. This page loads no file, so it cannot use the variables.
            ctx.Response.Write(
                "<html>" +
                "<head><style>body{background:#F4F6F9;color:#1F2937}h3{color:#111827}a{color:#1E5AA8}a:visited{color:#5B3E96}" +
                "a:hover{color:#174A8C}a:focus{outline:3px solid #2563EB;outline-offset:2px}</style></head>" +
                "<body style=\"font-family:Arial,sans-serif;margin:40px\">" +
                "<h3>Access denied</h3>" +
                "<p>Your role does not have access to this page.</p>" +
                "<p><a href=\"" + VirtualPathUtility.ToAbsolute("~/DashBoard/Dashboard.aspx") + "\">Back to home</a></p>" +
                "</body></html>");
            app.CompleteRequest();
        }

        private static Policy GetPolicy(HttpContext ctx)
        {
            Policy cached = ctx.Cache[CacheKey] as Policy;
            if (cached != null) return cached;

            Policy p = new Policy();
            string file = ctx.Server.MapPath("~/XML/PageAccess.xml");

            try
            {
                XmlDocument doc = new XmlDocument();
                doc.Load(file);
                XmlElement root = doc.DocumentElement;

                p.Enforce = string.Equals(root.GetAttribute("mode"), "Enforce", StringComparison.OrdinalIgnoreCase);

                foreach (XmlNode n in root.SelectNodes("public/page"))
                    p.PublicPages.Add(NormalizePath(((XmlElement)n).GetAttribute("path")));

                foreach (XmlNode n in root.SelectNodes("pages/page"))
                {
                    XmlElement el = (XmlElement)n;
                    string[] roles = el.GetAttribute("roles").Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                    for (int i = 0; i < roles.Length; i++) roles[i] = roles[i].Trim();
                    p.Pages[NormalizePath(el.GetAttribute("path"))] = roles;
                }
            }
            catch (Exception ex)
            {
                p.LoadError = ex.Message;
            }

            if (p.LoadError == null)
                ctx.Cache.Insert(CacheKey, p, new CacheDependency(file));
            else
                ctx.Cache.Insert(CacheKey, p, null, DateTime.UtcNow.AddSeconds(30), Cache.NoSlidingExpiration);

            return p;
        }

        private static string NormalizePath(string path)
        {
            path = (path ?? string.Empty).Trim().Replace('\\', '/');
            while (path.StartsWith("/", StringComparison.Ordinal) || path.StartsWith("~/", StringComparison.Ordinal))
                path = path.StartsWith("~/", StringComparison.Ordinal) ? path.Substring(2) : path.Substring(1);
            return path;
        }

        // The user column of the log (step UN2): "Name (login)"; only the name when the session has no login ID,
        // only the login when the name is blank. The format is the shared one (Common.UserDisplayName, step UN3);
        // a logged-in user is active (an inactive one is sent to the login page), so no " (inactive)".
        private static string LogUser(HttpContext ctx)
        {
            if (ctx.Session == null)
                return string.Empty;

            string name = Convert.ToString(ctx.Session["UserName"]);
            string login = Convert.ToString(ctx.Session["LoginName"]);
            return BMMSBAL.Common.UserDisplayName(name, login, true);
        }

        // Step RA1d: a logged value never holds a control character (tab, line break, ...), so one request is
        // always one line of six columns. A value without one is written as before.
        private static string Clean(string value)
        {
            if (string.IsNullOrEmpty(value))
                return value ?? string.Empty;

            StringBuilder sb = null;
            for (int i = 0; i < value.Length; i++)
            {
                if (char.IsControl(value[i]))
                {
                    if (sb == null) sb = new StringBuilder(value, 0, i, value.Length);
                    sb.Append(' ');
                }
                else if (sb != null)
                {
                    sb.Append(value[i]);
                }
            }
            return sb == null ? value : sb.ToString();
        }

        // Written to App_Data, which IIS/ASP.NET never serves to browsers.
        private static void Log(HttpContext ctx, string action, string page, string role, string reason)
        {
            try
            {
                string dir = ctx.Server.MapPath("~/App_Data");
                Directory.CreateDirectory(dir);
                string user = LogUser(ctx);
                string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "\t" + action + "\t" + Clean(user) + "\t" + Clean(role) +
                              "\t" + Clean(page) + "\t" + Clean(reason) + Environment.NewLine;
                lock (LogLock)
                {
                    File.AppendAllText(Path.Combine(dir, "PageAccessLog.txt"), line, Encoding.UTF8);
                }
            }
            catch
            {
                // Logging must never break a request.
            }
        }
    }
}
