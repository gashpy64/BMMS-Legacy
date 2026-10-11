using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web;
using System.Web.Caching;
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
    ///      SMTPServerConfig, ViewReport, ReportPrint).
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

            // --- 1. must be logged in -------------------------------------------------
            string userName = ctx.Session == null ? null : ctx.Session["UserName"] as string;
            if (string.IsNullOrEmpty(userName))
            {
                RedirectToLogin(app, ctx);
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

        private static void RedirectToLogin(HttpApplication app, HttpContext ctx)
        {
            string url = VirtualPathUtility.ToAbsolute("~/Default.aspx");

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
            ctx.Response.Write(
                "<html><body style=\"font-family:Arial,sans-serif;margin:40px\">" +
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

        // Written to App_Data, which IIS/ASP.NET never serves to browsers.
        private static void Log(HttpContext ctx, string action, string page, string role, string reason)
        {
            try
            {
                string dir = ctx.Server.MapPath("~/App_Data");
                Directory.CreateDirectory(dir);
                string user = ctx.Session == null ? string.Empty : Convert.ToString(ctx.Session["UserName"]);
                string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "\t" + action + "\t" + user + "\t" + role +
                              "\t" + page + "\t" + reason + Environment.NewLine;
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
