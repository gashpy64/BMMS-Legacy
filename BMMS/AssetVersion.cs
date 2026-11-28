using System;
using System.Collections.Concurrent;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.HtmlControls;

namespace BMMS
{
    // Step UN6e (R30): every link to a local stylesheet gets ?v=<stamp>, the first 8 hex characters of the SHA-256 of
    // the file, so a browser fetches a stylesheet again after it changed and keeps it in its cache otherwise.
    // The stamp is computed once per file and kept for the life of the application (a changed file gets its new
    // stamp when the application restarts, as it does on every deployment). A file that is missing or cannot be
    // read keeps its link without ?v=: no error, no log line. Used by both master pages and the sign-in page.
    public static class AssetVersion
    {
        // Physical path -> stamp; null for a file that is missing or cannot be read (cached too, once per file)
        private static readonly ConcurrentDictionary<string, string> Stamps =
            new ConcurrentDictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        // Stamps the stylesheet links of the page's header and of the given containers (the content of a master
        // page's ContentPlaceHolder), just before the page renders.
        public static void Register(Page page, params Control[] containers)
        {
            if (page == null)
                return;

            page.PreRenderComplete += delegate
            {
                if (page.Header != null)
                    StampLinks(page.Header);
                if (containers != null)
                    foreach (Control container in containers)
                        if (container != null)
                            StampLinks(container);
            };
        }

        // The <link runat="server"> stylesheets that are direct children of the control. In the header ASP.NET makes
        // them HtmlLink controls, in a page's content HtmlGenericControl ones; both keep the address in the attribute
        // href (HtmlLink.Href reads and writes that attribute).
        private static void StampLinks(Control parent)
        {
            foreach (Control control in parent.Controls)
            {
                HtmlControl link = control as HtmlControl;
                if (link == null || !string.Equals(link.TagName, "link", StringComparison.OrdinalIgnoreCase) || !IsStylesheet(link))
                    continue;

                string href = link.Attributes["href"];
                if (!IsLocalCss(href))
                    continue;

                string stamp = StampFor(link, href);
                if (stamp != null)
                    link.Attributes["href"] = href + "?v=" + stamp;
            }
        }

        private static bool IsStylesheet(HtmlControl link)
        {
            return string.Equals(link.Attributes["rel"], "stylesheet", StringComparison.OrdinalIgnoreCase);
        }

        // A relative or application path to a .css file, without a query, a fragment or a host
        private static bool IsLocalCss(string href)
        {
            if (string.IsNullOrEmpty(href))
                return false;
            if (href.IndexOf('?') >= 0 || href.IndexOf('#') >= 0 || href.IndexOf(':') >= 0 || href.StartsWith("//", StringComparison.Ordinal)
                || href.IndexOf('\\') >= 0)
                return false;
            return href.EndsWith(".css", StringComparison.OrdinalIgnoreCase);
        }

        private static string StampFor(Control owner, string href)
        {
            string physical;
            try
            {
                // Relative to the file that holds the link (the master page, the content page or the sign-in page)
                physical = HttpContext.Current.Server.MapPath(owner.ResolveUrl(href));
            }
            catch (Exception)
            {
                // Outside the application or not a valid path: the link stays as it is
                return null;
            }

            return Stamps.GetOrAdd(physical, ComputeStamp);
        }

        private static string ComputeStamp(string physical)
        {
            try
            {
                if (!File.Exists(physical))
                    return null;

                byte[] hash;
                using (FileStream stream = File.OpenRead(physical))
                using (SHA256 sha = SHA256.Create())
                    hash = sha.ComputeHash(stream);

                StringBuilder hex = new StringBuilder(8);
                for (int i = 0; i < 4; i++)
                    hex.Append(hash[i].ToString("x2"));
                return hex.ToString();
            }
            catch (Exception)
            {
                return null;
            }
        }
    }
}
